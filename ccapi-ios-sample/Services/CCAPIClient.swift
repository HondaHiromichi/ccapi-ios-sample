import Foundation

// MARK: - CCAPI クライアント

/// CCAPI を叩く URLSession ラッパー。認証なし、ベース URL 固定で動作する
final class CCAPIClient {
    // MARK: - 定数

    /// カメラアクセスポイントモードでの R100 の固定 IP/ポート (Phase 1 実機検証で確認)
    static let defaultBaseURL = URL(string: "http://192.168.1.2:8080")!

    // MARK: - フィールド

    private let baseURL: URL
    private let session: URLSession

    // MARK: - 初期化

    init(baseURL: URL = defaultBaseURL) {
        self.baseURL = baseURL

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
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
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
