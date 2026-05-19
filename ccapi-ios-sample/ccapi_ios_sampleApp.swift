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
    @State private var settings = AppSettings()

    // MARK: - シーン

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}
