import SwiftUI

// MARK: - 設定画面

/// CCAPI 接続先 (ホスト・ポート) の編集 UI。`AppSettings` をバインドして即時反映する
struct SettingsView: View {
    // MARK: - 状態

    @Environment(AppSettings.self) private var settings
    @Environment(\.imageCache) private var imageCache

    @State private var didClearCache = false

    // MARK: - 本体

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                TextField("ホスト (IP)", text: $settings.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("ポート", value: $settings.port, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
            } header: {
                Text("カメラ接続先")
            } footer: {
                Text("インフラモードでは DHCP 割り当ての IP を入力してください。AP モード時は下のプリセットをご利用ください。")
            }

            Section("プリセット") {
                Button {
                    settings.host = AppSettings.defaultHost
                    settings.port = AppSettings.defaultPort
                } label: {
                    Label("AP モード (\(AppSettings.defaultHost):\(AppSettings.defaultPort))",
                          systemImage: "antenna.radiowaves.left.and.right")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await imageCache.clearAll()
                        didClearCache = true
                    }
                } label: {
                    Label("画像キャッシュをクリア", systemImage: "trash")
                }
            } header: {
                Text("メンテナンス")
            } footer: {
                Text(didClearCache
                     ? "キャッシュを削除しました。"
                     : "ダウンロード済みのサムネイル/オリジナル画像をすべて削除します。")
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppSettings())
    }
}
