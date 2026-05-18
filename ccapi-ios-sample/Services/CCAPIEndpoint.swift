import Foundation

// MARK: - CCAPI バージョン

enum CCAPIVersion: String {
    case v100 = "ver100"
    case v110 = "ver110"
    case v130 = "ver130"
}

// MARK: - CCAPI エンドポイント

/// CCAPI のエンドポイント定義 (Phase 1 実機検証で確認したパスのみ集約)
enum CCAPIEndpoint {
    case deviceInformation
    case batteryStatus
    case storageStatus
    case contentsRoot
    case eventPolling(continueWait: Bool)

    var path: String {
        switch self {
        case .deviceInformation:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/deviceinformation"
        case .batteryStatus:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/devicestatus/battery"
        case .storageStatus:
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/devicestatus/storage"
        case .contentsRoot:
            return "/ccapi/\(CCAPIVersion.v130.rawValue)/contents/sd"
        case .eventPolling(let continueWait):
            let flag = continueWait ? "on" : "off"
            return "/ccapi/\(CCAPIVersion.v100.rawValue)/event/polling?continue=\(flag)"
        }
    }
}
