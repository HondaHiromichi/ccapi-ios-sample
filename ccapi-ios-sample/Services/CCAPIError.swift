import Foundation

// MARK: - CCAPI エラー型

enum CCAPIError: Error {
    case invalidURL
    case httpStatus(code: Int, body: Data?)
    case decoding(Error)
    case transport(Error)
}

extension CCAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL の組み立てに失敗しました"
        case .httpStatus(let code, _):
            return "HTTP エラー (\(code))"
        case .decoding:
            return "レスポンスのデコードに失敗しました"
        case .transport(let error):
            return "通信エラー: \(error.localizedDescription)"
        }
    }
}
