//
//  ContentView.swift
//  ccapi-ios-sample
//
//  Created by Honda Hiromichi on 2026/05/18.
//

import SwiftUI

struct ContentView: View {
    // MARK: - 状態

    @State private var deviceInfo: DeviceInformation?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let client = CCAPIClient()

    // MARK: - 本体

    var body: some View {
        VStack(spacing: 24) {
            Text("CCAPI 接続テスト")
                .font(.title2)
                .bold()

            deviceInfoSection

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
        } else {
            Text("ボタンを押すとカメラからデバイス情報を取得します")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }

    // MARK: - Private メソッド

    private func loadDeviceInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            deviceInfo = try await client.fetch(.deviceInformation)
        } catch {
            deviceInfo = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
