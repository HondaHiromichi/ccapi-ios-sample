//
//  ccapi_ios_sampleApp.swift
//  ccapi-ios-sample
//
//  Created by Honda Hiromichi on 2026/05/18.
//

import SwiftUI

@main
struct ccapi_ios_sampleApp: App {
    // MARK: - 状態

    /// アプリ全体で共有する設定 (CCAPI 接続先など)
    @State private var settings: AppSettings

    /// アプリ全体で共有する CCAPI クライアント (内部の URLSession もアプリ内 1 つに集約)
    private let client: CCAPIClient

    /// 画像キャッシュ (メモリ/ディスク, ダウンロード付き)
    private let imageCache: ImageCache

    /// カメラへの到達性を監視し接続状態を公開する共有モニタ
    private let connectionMonitor: ConnectionMonitor

    /// 撮影イベントをポーリングして新規画像を検知する共有ポーラー (メイン画面の新着情報用)
    private let eventPoller: EventPoller

    // MARK: - 初期化

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let client = CCAPIClient(settings: settings)
        self.client = client

        self.imageCache = ImageCache(client: client)
        self.connectionMonitor = ConnectionMonitor(settings: settings)
        self.eventPoller = EventPoller(client: client)
    }

    // MARK: - シーン

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(connectionMonitor)
                .environment(eventPoller)
                .environment(\.ccapiClient, client)
                .environment(\.imageCache, imageCache)
        }
    }
}
