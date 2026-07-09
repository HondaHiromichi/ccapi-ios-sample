import Foundation
import Observation

// MARK: - 撮影イベントポーリング

/// `event/polling?continue=off` を一定間隔でポーリングし, 新規撮影 (`addedcontents`) を検知する。
/// R100 は SSE 非対応のためポーリング方式。検知した URL を累積して `@Observable` で公開する。
///
/// 用途は **メイン画面の新着情報表示のみ**。ダウンロードはグリッド画面への遷移時にまとめて行う
/// 設計のため, ここでは自動ダウンロードは行わない。
@Observable
final class EventPoller {
    // MARK: - プロパティ

    /// 検知した新規コンテンツの URL (新しいものを末尾に追加)。SwiftUI 参照のためメインで更新
    private(set) var addedContents: [String] = []

    // MARK: - フィールド

    private let client: CCAPIClient
    /// ポーリング間隔
    private let interval: Duration = .seconds(4)
    private var pollingTask: Task<Void, Never>?

    // MARK: - 初期化

    init(client: CCAPIClient) {
        self.client = client
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Private メソッド

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(for: self?.interval ?? .seconds(4))
            }
        }
    }

    /// 1 回ポーリングし, `addedcontents` があれば累積する
    private func pollOnce() async {
        do {
            let event: CameraEvent = try await client.fetch(.eventPolling(continueWait: false))
            guard let added = event.addedContents, !added.isEmpty else { return }
            await MainActor.run {
                self.addedContents.append(contentsOf: added)
            }
        } catch {
            // 切断中・カメラ未応答時は無視 (接続状態は ConnectionMonitor が UI に示す)
        }
    }
}
