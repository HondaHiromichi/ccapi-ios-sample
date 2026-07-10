import Foundation
import SwiftUI

// MARK: - CCAPI クライアント

/// CCAPI を叩く URLSession ラッパー。接続先は `AppSettings` から動的に取得する (認証なし)
final class CCAPIClient {
    // MARK: - フィールド

    private let settings: AppSettings
    private let session: URLSession
    /// 一過性エラー時の最大再試行回数 (初回を除く)
    private let maxRetries = 3

    // MARK: - 初期化

    init(settings: AppSettings) {
        self.settings = settings

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        // iOS デフォルト (4〜6) 相当。複数セルが並列に画像取得する際の待ち時間を短縮する
        config.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public メソッド

    /// 指定エンドポイントへ GET し、JSON を `T` にデコードして返す
    func fetch<T: Decodable>(_ endpoint: CCAPIEndpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await fetchData(endpoint)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CCAPIError.decoding(error)
        }
    }

    /// ディレクトリ配下の全ファイル URL を取得して結合する。
    /// CCAPI は 1 ページ最大 100 件で返すため、`kind=number` で総ページ数を得てから
    /// 全ページを順次取得する (1 ページ目のみだと 101 件以上のフォルダで新写真が欠落する)
    func fetchAllDirectoryFileURLs(
        storage: String,
        directory: String,
        type: CCAPIEndpoint.ContentType? = nil
    ) async throws -> [String] {
        let info: DirectoryContentsNumber = try await fetch(
            .directoryContentsNumber(storage: storage, directory: directory, type: type)
        )
        guard info.pageNumber > 0 else { return [] }

        var fileURLs: [String] = []
        for page in 1...info.pageNumber {
            let list: ContentURLList = try await fetch(
                .directoryContents(storage: storage, directory: directory, type: type, page: page)
            )
            fileURLs.append(contentsOf: list.url)
        }
        return fileURLs
    }

    /// 指定エンドポイントへ GET し、生の `Data` を返す
    /// 画像 (`image/jpeg`) や動画など非 JSON のレスポンスを取得する用途に使う。
    ///
    /// リトライ方針 (アプリ全体で共通):
    /// - HTTP 5xx / タイムアウト等の一過性エラー -> 指数バックオフで最大 `maxRetries` 回再試行
    /// - HTTP 4xx / デコード不能 / URL 不正 -> 再試行せず即 throw (呼び出し側でユーザー通知)
    /// - キャンセル (`URLError.cancelled` / `CancellationError`) -> 再試行せず伝播
    func fetchData(_ endpoint: CCAPIEndpoint) async throws -> Data {
        guard let baseURL = settings.baseURL,
              let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw CCAPIError.invalidURL
        }

        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                let data = try await performRequest(url)
                // リトライ診断ログ (リトライ発生時のみ出力。正常時は無音)
                if attempt > 0 {
                    print("[CCAPIClient] recovered after \(attempt) retry(ies): \(endpoint.path)")
                }
                return data
            } catch {
                guard Self.isRetryable(error), attempt < maxRetries else {
                    // リトライ診断ログ (リトライ発生時のみ出力。正常時は無音)
                    if attempt > 0 {
                        print("[CCAPIClient] gave up after \(attempt) retry(ies): \(endpoint.path) — \(error.localizedDescription)")
                    }
                    throw error
                }
                attempt += 1
                // 指数バックオフ: 0.5s -> 1s -> 2s
                let delayMs = 500 * (1 << (attempt - 1))
                // リトライ診断ログ (リトライ発生時のみ出力。正常時は無音)
                print("[CCAPIClient] retry \(attempt)/\(maxRetries) in \(delayMs)ms: \(endpoint.path) — \(error.localizedDescription)")
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
        }
    }

    // MARK: - Private メソッド

    /// 1 回分の GET リクエスト。非 2xx は `httpStatus`, 通信例外は `transport` に正規化する
    private func performRequest(_ url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw CCAPIError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CCAPIError.httpStatus(code: http.statusCode, body: data)
        }

        return data
    }

    /// 一過性エラー (再試行する価値がある) かどうかを判定する
    private static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case let CCAPIError.httpStatus(code, _):
            // 5xx はカメラ側の一過性異常 (busy 503 等) -> 再試行 / 4xx は再試行しない
            return (500..<600).contains(code)
        case let CCAPIError.transport(underlying):
            if underlying is CancellationError { return false }
            if let urlError = underlying as? URLError, urlError.code == .cancelled { return false }
            // タイムアウト・接続断など通信系は一過性の可能性が高い -> 再試行
            return true
        case CCAPIError.decoding, CCAPIError.invalidURL:
            return false
        default:
            return false
        }
    }
}

// MARK: - Environment 連携

private struct CCAPIClientKey: EnvironmentKey {
    /// デフォルト値は使用時に上書きされる前提。空の AppSettings ベースのクライアントを返す
    @MainActor static let defaultValue = CCAPIClient(settings: AppSettings())
}

extension EnvironmentValues {
    var ccapiClient: CCAPIClient {
        get { self[CCAPIClientKey.self] }
        set { self[CCAPIClientKey.self] = newValue }
    }
}
