import Foundation
import SwiftUI

// MARK: - CCAPI クライアント

/// CCAPI を叩く URLSession ラッパー。接続先は `AppSettings` から動的に取得する (認証なし)
final class CCAPIClient {
    // MARK: - フィールド

    private let settings: AppSettings
    private let session: URLSession

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
    /// 画像 (`image/jpeg`) や動画など非 JSON のレスポンスを取得する用途に使う
    func fetchData(_ endpoint: CCAPIEndpoint) async throws -> Data {
        guard let baseURL = settings.baseURL,
              let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw CCAPIError.invalidURL
        }

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
