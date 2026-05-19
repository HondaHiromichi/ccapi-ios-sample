import Foundation

// MARK: - URL リスト共通レスポンス

/// `{ "url": [...] }` 形式のレスポンスを表現する共通型。
/// ストレージ配下のディレクトリ URL 一覧、ディレクトリ配下のファイル URL 一覧の
/// いずれも同じ形なので両方で使う。
struct ContentURLList: Decodable, Equatable {
    let url: [String]

    /// 各 URL の末尾パスコンポーネント (ディレクトリ名 / ファイル名) を取り出す
    var lastPathComponents: [String] {
        url.compactMap { URL(string: $0)?.lastPathComponent }
    }
}
