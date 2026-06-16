import Foundation

// MARK: - イベントポーリングのレスポンス

/// `GET /ccapi/ver100/event/polling?continue=off` のレスポンスから新規撮影検知に必要な
/// `addedcontents` のみを取り出すモデル。
/// レスポンスはカメラ全状態の大きな JSON だが, 新規撮影検知に使うのは追加ファイル URL の配列のみ。
/// (無変化時は `{}` が返り `addedContents` は nil になる)
struct CameraEvent: Decodable, Equatable {
    /// 前回ポーリング以降に追加されたコンテンツの URL 配列 (撮影された画像など)
    let addedContents: [String]?

    enum CodingKeys: String, CodingKey {
        case addedContents = "addedcontents"
    }
}
