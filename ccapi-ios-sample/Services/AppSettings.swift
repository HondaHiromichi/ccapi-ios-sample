import Foundation
import Observation

// MARK: - アプリ設定

/// CCAPI 接続先 (ホスト・ポート) を管理する設定。値変更時に `UserDefaults` へ自動保存する
@Observable
final class AppSettings {
    // MARK: - 定数

    /// AP モード時のカメラ固定 IP
    static let defaultHost = "192.168.1.2"
    /// CCAPI のデフォルトポート
    static let defaultPort = 8080

    // MARK: - プロパティ

    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: Key.host) }
    }

    var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: Key.port) }
    }

    // MARK: - 初期化

    init(userDefaults: UserDefaults = .standard) {
        self.host = userDefaults.string(forKey: Key.host) ?? Self.defaultHost
        self.port = (userDefaults.object(forKey: Key.port) as? Int) ?? Self.defaultPort
    }

    // MARK: - 派生プロパティ

    /// 現在の host/port から組み立てたベース URL。形式不正なら nil
    var baseURL: URL? {
        URL(string: "http://\(host):\(port)")
    }

    // MARK: - Private 定数

    private enum Key {
        static let host = "ccapi.host"
        static let port = "ccapi.port"
    }
}
