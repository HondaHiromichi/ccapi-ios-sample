import Foundation

// MARK: - 画像メタデータ

/// `GET /ccapi/ver100/contents/sd/{dir}/{file}?kind=info` のレスポンス
/// 例:
/// ```json
/// {
///   "filesize": 123456789,
///   "protect": "enable",
///   "archive": "disable",
///   "rotate": "0",
///   "rating": "off",
///   "lastmodifieddate": "Wed, 04 Jul 2018 12:34:56 GMT",
///   "playtime": 123
/// }
/// ```
struct ImageMetadata: Decodable, Equatable {
    /// ファイルサイズ (バイト)
    let filesize: Int64
    /// プロテクト状態 (`enable` / `disable`)
    let protect: String
    /// アーカイブ属性 (`enable` / `disable`)
    let archive: String
    /// 回転角度 (`0` / `90` / `180` / `270`)
    let rotate: String
    /// レーティング (`off` / `1` 〜 `5`)
    let rating: String
    /// 最終更新日時 (RFC 1123 形式の文字列)
    let lastmodifieddate: String
    /// 再生時間 (秒)。動画以外は null
    let playtime: Int?
}
