import Foundation

// MARK: - バッテリ状態レスポンス

/// `GET /ccapi/ver100/devicestatus/battery` のレスポンス
/// 例: `{"kind":"ac_adapter","name":"DR-E17","quality":"","level":""}`
struct BatteryStatus: Decodable, Equatable {
    /// 電源種別 (`battery` / `ac_adapter` 等)
    let kind: String
    /// 電源装置名 (例: `LP-E17` / `DR-E17`)
    let name: String
    /// バッテリ品質 (`full` / `normal` / `degraded` 等)。AC アダプタ接続時は空文字
    let quality: String
    /// バッテリ残量 (`full` / `high` / `half` / `quarter` / `low` / 数値文字列等)。AC アダプタ接続時は空文字
    let level: String
}
