import Foundation
import Network
import Observation

// MARK: - 接続監視

/// カメラへの到達性を監視し, 接続状態を `@Observable` として公開する。
/// アプリ全体で 1 インスタンス共有し, Environment 経由で注入する。
///
/// 判定方針:
/// - 軽量エンドポイント (`deviceinformation`) を短いタイムアウトで定期的に叩き, カメラの
///   HTTP 応答有無で接続状態を決める (`NWPathMonitor` の経路有無だけではカメラのスリープや
///   SSID 切断を検知できないため)
/// - 成功 -> `connected`, 失敗 1 回 -> `unstable`, 連続失敗 -> `disconnected`
/// - `NWPathMonitor` は経路の全喪失を即時に `disconnected` 反映する補助として併用する
@Observable
final class ConnectionMonitor {
    // MARK: - 定数

    /// 健全性チェックの間隔
    private let pollInterval: Duration = .seconds(5)
    /// チェック 1 回あたりのタイムアウト (秒)
    private let checkTimeout: TimeInterval = 4
    /// `disconnected` と判定するまでの連続失敗回数
    private let failureThreshold = 2

    // MARK: - プロパティ

    /// 現在の接続状態。SwiftUI からの参照に備えメインスレッドで更新する
    private(set) var state: ConnectionState = .disconnected

    // MARK: - フィールド

    private let settings: AppSettings
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "ConnectionMonitor.path")
    private var pollingTask: Task<Void, Never>?
    private var consecutiveFailures = 0

    // MARK: - 初期化

    init(settings: AppSettings) {
        self.settings = settings

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = checkTimeout
        config.timeoutIntervalForResource = checkTimeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        // 経路が全喪失したら即座に切断扱い。復帰時は即時に 1 回チェックする
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status != .satisfied {
                self.setState(.disconnected)
            } else {
                Task { await self.checkOnce() }
            }
        }
        monitor.start(queue: pathQueue)

        startPolling()
    }

    deinit {
        monitor.cancel()
        pollingTask?.cancel()
    }

    // MARK: - Private メソッド

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkOnce()
                try? await Task.sleep(for: self?.pollInterval ?? .seconds(5))
            }
        }
    }

    /// カメラへ 1 回だけ軽量リクエストを投げ, 応答で接続状態を更新する
    private func checkOnce() async {
        guard let baseURL = settings.baseURL,
              let url = URL(string: CCAPIEndpoint.deviceInformation.path, relativeTo: baseURL) else {
            setState(.disconnected)
            return
        }

        do {
            let (_, response) = try await session.data(from: url)
            // HTTP 応答が返ればカメラは到達可能 (4xx でもカメラは生きている)
            guard response is HTTPURLResponse else { throw URLError(.badServerResponse) }
            consecutiveFailures = 0
            setState(.connected)
        } catch {
            consecutiveFailures += 1
            setState(consecutiveFailures >= failureThreshold ? .disconnected : .unstable)
        }
    }

    /// 状態をメインスレッドで更新する (SwiftUI の再描画整合のため)
    private func setState(_ newState: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}
