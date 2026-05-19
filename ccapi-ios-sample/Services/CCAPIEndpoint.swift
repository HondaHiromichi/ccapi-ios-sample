import Foundation

// MARK: - CCAPI バージョン

enum CCAPIVersion: String {
    case v100 = "ver100"
    case v110 = "ver110"
    case v130 = "ver130"
}

// MARK: - CCAPI エンドポイント

/// CCAPI のエンドポイント定義 (Phase 1 実機検証で確認したパスのみ集約)
///
/// R100 では `/contents` のサブパス操作 (ディレクトリ・ファイル一覧) は ver130 を直接
/// 叩くと 404 となり、実際には ver100 パスを使う必要があった (ver130 ルートは ver100
/// パスへのワイルドカード参照になっているため)。
enum CCAPIEndpoint {
    case deviceInformation
    case batteryStatus
    case storageStatus

    /// ストレージ配下のディレクトリ URL 一覧取得
    /// 例: `GET /ccapi/ver100/contents/sd`
    case storageContents(storage: String)

    /// ディレクトリ配下のファイル URL 一覧取得
    /// 例: `GET /ccapi/ver100/contents/sd/100__TSB?type=jpeg&page=1`
    case directoryContents(
        storage: String,
        directory: String,
        type: ContentType? = nil,
        page: Int? = nil
    )

    /// 個別ファイルの取得 (本体・サムネイル・表示用・情報など)
    /// 例: `GET /ccapi/ver100/contents/sd/100__TSB/IMG_0001.JPG?kind=thumbnail`
    case fileContent(
        storage: String,
        directory: String,
        file: String,
        kind: ContentKind? = nil
    )

    case eventPolling(continueWait: Bool)

    // MARK: - Path 構築

    var path: String {
        switch self {
        case .deviceInformation:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/deviceinformation"
        case .batteryStatus:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/devicestatus/battery"
        case .storageStatus:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/devicestatus/storage"
        case .storageContents(let storage):
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/contents/\(storage)"
        case .directoryContents(let storage, let directory, let type, let page):
            var query: [URLQueryItem] = []
            if let type {
                query.append(URLQueryItem(name: "type", value: type.rawValue))
            }
            if let page {
                query.append(URLQueryItem(name: "page", value: String(page)))
            }
            let base = "/ccapi/\(CCAPIVersion.v100.rawValue)/contents/\(storage)/\(directory)"
            if query.isEmpty {
                return base
            }
            var components = URLComponents()
            components.queryItems = query
            return base + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
        case .fileContent(let storage, let directory, let file, let kind):
            let base = "/ccapi/\(CCAPIVersion.v100.rawValue)/contents/\(storage)/\(directory)/\(file)"
            if let kind {
                return "\(base)?kind=\(kind.rawValue)"
            }
            return base
        case .eventPolling(let continueWait):
            let flag = continueWait ? "on" : "off"
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/event/polling?continue=\(flag)"
        }
    }

    // MARK: - 補助型

    /// `directoryContents` の type クエリ値
    enum ContentType: String {
        case all
        case jpeg
        case cr2
        case cr3
        case wav
        case mp4
        case mov
    }

    /// `fileContent` の kind クエリ値
    enum ContentKind: String {
        /// 本体データ (デフォルト)
        case main
        /// サムネイル画像
        case thumbnail
        /// 表示用画像
        case display
        /// 埋め込み画像 (RAW のみ)
        case embedded
        /// ファイル情報 (JSON)
        case info
    }
}
