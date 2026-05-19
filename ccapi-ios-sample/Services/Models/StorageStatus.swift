import Foundation

// MARK: - ストレージ状態レスポンス

/// `GET /ccapi/ver100/devicestatus/storage` のレスポンス
/// 例: `{"storagelist":[{"name":"sd","url":"...","accesscapability":"readwrite","maxsize":63992496128,"spacesize":62670110720,"contentsnumber":118}]}`
struct StorageStatus: Decodable, Equatable {
    let storageList: [Storage]

    enum CodingKeys: String, CodingKey {
        case storageList = "storagelist"
    }

    // MARK: - ストレージ要素

    struct Storage: Decodable, Equatable {
        /// ストレージ名 (例: `sd`)
        let name: String
        /// コンテンツ URL のベース
        let url: String
        /// アクセス権 (`readwrite` / `readonly` 等)
        let accessCapability: String
        /// 総容量 (バイト)
        let maxSize: Int64
        /// 空き容量 (バイト)
        let spaceSize: Int64
        /// 撮影済みコンテンツ数
        let contentsNumber: Int

        enum CodingKeys: String, CodingKey {
            case name
            case url
            case accessCapability = "accesscapability"
            case maxSize = "maxsize"
            case spaceSize = "spacesize"
            case contentsNumber = "contentsnumber"
        }
    }
}
