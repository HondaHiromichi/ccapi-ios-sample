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
