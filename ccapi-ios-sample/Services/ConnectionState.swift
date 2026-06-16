import Foundation

// MARK: - 接続状態

/// カメラとの接続状態 (UI 上に常時明示する 3 値)。
/// `ConnectionMonitor` がカメラへの軽量リクエストの応答で判定する。
enum ConnectionState: Equatable {
    /// カメラが応答している
    case connected
    /// 応答が単発で失敗 (一時的な不安定。連続失敗で disconnected に遷移)
    case unstable
    /// カメラに到達できない (連続失敗 / 経路喪失)
    case disconnected
}
