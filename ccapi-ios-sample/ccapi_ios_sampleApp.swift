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

    /// サムネイル取得をシリアル化・キャッシュする共有ローダー
    private let thumbnailLoader = ThumbnailLoader()

    /// カメラへの到達性を監視し接続状態を公開する共有モニタ
    private let connectionMonitor: ConnectionMonitor

    // MARK: - 初期化

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        self.client = CCAPIClient(settings: settings)
        self.connectionMonitor = ConnectionMonitor(settings: settings)
    }

    // MARK: - シーン

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(connectionMonitor)
                .environment(\.ccapiClient, client)
                .environment(\.thumbnailLoader, thumbnailLoader)
        }
    }
}
