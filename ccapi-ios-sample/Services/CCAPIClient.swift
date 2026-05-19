import Foundation

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
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public メソッド

    /// 指定エンドポイントへ GET し、JSON を `T` にデコードして返す
    func fetch<T: Decodable>(_ endpoint: CCAPIEndpoint, as type: T.Type = T.self) async throws -> T {
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

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CCAPIError.decoding(error)
        }
    }
}
