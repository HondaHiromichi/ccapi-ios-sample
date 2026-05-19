//
//  ContentView.swift
//  ccapi-ios-sample
//
//  Created by Honda Hiromichi on 2026/05/18.
//

import SwiftUI

struct ContentView: View {
    // MARK: - 定数

    /// iPad で広がりすぎないように内容の最大幅を制限する (pt)
    private let contentMaxWidth: CGFloat = 600

    // MARK: - 状態

    @Environment(AppSettings.self) private var settings

    @State private var deviceInfo: DeviceInformation?
    @State private var errorMessage: String?
    @State private var isLoading = false

    // MARK: - 本体

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("CCAPI 接続テスト")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                deviceInfoSection

                Spacer(minLength: 0)

                Button {
                    Task { await loadDeviceInfo() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("デバイス情報を取得")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)
            }
            .padding()
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - サブビュー

    @ViewBuilder
    private var deviceInfoSection: some View {
        if let info = deviceInfo {
            VStack(alignment: .leading, spacing: 8) {
                row("メーカー", info.manufacturer)
                row("製品名", info.productName)
                row("ファームウェア", info.firmwareVersion)
                row("シリアル番号", info.serialNumber)
                row("MAC アドレス", info.macAddress)
                row("GUID", info.guid)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let message = errorMessage {
            Text(message)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text("ボタンを押すとカメラからデバイス情報を取得します")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Private メソッド

    private func loadDeviceInfo() async {
        isLoading = true
        errorMessage = nil
        let client = CCAPIClient(settings: settings)
        do {
            deviceInfo = try await client.fetch(.deviceInformation)
        } catch {
            deviceInfo = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview("iPad Pro 11-inch") {
    ContentView()
        .environment(AppSettings())
}

#Preview("iPhone 17") {
    ContentView()
        .environment(AppSettings())
}
