import Foundation

// MARK: - ディレクトリのコンテンツ数レスポンス

/// `GET /ccapi/ver100/contents/{storage}/{directory}?kind=number` のレスポンス
/// 例: `{"contentsnumber":103,"pagenumber":2}`
/// CCAPI は 1 ページ最大 100 件で返すため、全件取得には `pageNumber` 分のページを順次取得する
struct DirectoryContentsNumber: Decodable, Equatable {
    /// ディレクトリ内の総コンテンツ数 (type 指定時はそのフィルタ後の件数)
    let contentsNumber: Int
    /// 総ページ数 (1 始まり。0 の場合はコンテンツなし)
    let pageNumber: Int

    enum CodingKeys: String, CodingKey {
        case contentsNumber = "contentsnumber"
        case pageNumber = "pagenumber"
    }
}
