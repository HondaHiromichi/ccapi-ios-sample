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
    @Environment(ConnectionMonitor.self) private var connectionMonitor
    @Environment(\.ccapiClient) private var client

    @State private var deviceInfo: DeviceInformation?
    @State private var batteryStatus: BatteryStatus?
    @State private var storageStatus: StorageStatus?
    @State private var directoryListings: [DirectoryListing] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    // MARK: - 内部型

    /// 1 フォルダ分の取得結果
    private struct DirectoryListing: Identifiable {
        let id = UUID()
        let name: String
        let fileURLs: [String]

        var fileNames: [String] {
            fileURLs.compactMap { URL(string: $0)?.lastPathComponent }
        }
    }

    // MARK: - 本体

    var body: some View {
        // body で state を読むことで, ツールバー内バッジの @Observable 追従を確実にする
        let connectionState = connectionMonitor.state
        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("CCAPI 接続テスト")
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    placeholderOrError
                    deviceInfoCard
                    batteryCard
                    storageCard
                    contentsCard

                    Spacer(minLength: 0)

                    Button {
                        Task { await loadAllStatus() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("カメラ情報を取得")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)
                }
                .padding()
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusBadge(state: connectionState)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
        }
    }

    // MARK: - サブビュー (プレースホルダ / エラー)

    @ViewBuilder
    private var placeholderOrError: some View {
        if let message = errorMessage {
            Text(message)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if !hasAnyData {
            Text("ボタンを押すとカメラから各種情報を取得します")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    private var hasAnyData: Bool {
        deviceInfo != nil || batteryStatus != nil || storageStatus != nil || !directoryListings.isEmpty
    }

    // MARK: - サブビュー (デバイス情報カード)

    @ViewBuilder
    private var deviceInfoCard: some View {
        if let info = deviceInfo {
            card(title: "デバイス情報") {
                row("メーカー", info.manufacturer)
                row("製品名", info.productName)
                row("ファームウェア", info.firmwareVersion)
                row("シリアル番号", info.serialNumber)
                row("MAC アドレス", info.macAddress)
                row("GUID", info.guid)
            }
        }
    }

    // MARK: - サブビュー (バッテリカード)

    @ViewBuilder
    private var batteryCard: some View {
        if let battery = batteryStatus {
            card(title: "バッテリ") {
                row("種別", batteryKindLabel(battery.kind))
                row("名称", battery.name)
                row("残量", batteryLevelLabel(battery))
                row("品質", batteryQualityLabel(battery))
            }
        }
    }

    // MARK: - サブビュー (ストレージカード)

    @ViewBuilder
    private var storageCard: some View {
        if let storage = storageStatus {
            card(title: "ストレージ") {
                ForEach(Array(storage.storageList.enumerated()), id: \.offset) { _, item in
                    row("名称", item.name)
                    row("総容量", formatBytes(item.maxSize))
                    row("空き容量", "\(formatBytes(item.spaceSize)) (\(spacePercent(item))%)")
                    row("撮影枚数", "\(item.contentsNumber) 枚")
                    row("アクセス権", item.accessCapability)
                }
            }
        }
    }

    // MARK: - サブビュー (コンテンツカード)

    @ViewBuilder
    private var contentsCard: some View {
        if !directoryListings.isEmpty {
            card(title: "コンテンツ (JPEG)") {
                row("フォルダ数", "\(directoryListings.count)")

                ForEach(directoryListings) { listing in
                    Divider().padding(.vertical, 4)

                    NavigationLink {
                        ThumbnailGridView(
                            storage: "sd",
                            directory: listing.name,
                            fileURLs: listing.fileURLs
                        )
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("📁 \(listing.name)")
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)
                                Text("\(listing.fileURLs.count) ファイル")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 汎用カードビルダー

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - フォーマッタ

    private func batteryKindLabel(_ kind: String) -> String {
        switch kind {
        case "battery": return "バッテリー"
        case "ac_adapter": return "AC アダプタ"
        case "dc_coupler": return "DC カプラ"
        case "batterygrip": return "バッテリーグリップ"
        case "not_inserted": return "未挿入"
        case "unknown": return "非認証電池"
        default: return kind
        }
    }

    /// バッテリ残量を日本語に変換。空文字の場合は給電源 (AC アダプタ等) を示す文言を返す
    private func batteryLevelLabel(_ battery: BatteryStatus) -> String {
        if battery.level.isEmpty {
            return nonBatteryStateText(for: battery.kind)
        }
        switch battery.level {
        case "low": return "空手前"
        case "quarter": return "残量少"
        case "half": return "残量中"
        case "high": return "残量多"
        case "full": return "残量フル"
        case "unknown": return "非認証電池"
        case "charge": return "充電中"
        case "chargestop": return "充電停止"
        case "chargecomp": return "充電完了"
        default: return battery.level
        }
    }

    /// バッテリ品質を日本語に変換。空文字の場合は給電源を示す文言を返す
    private func batteryQualityLabel(_ battery: BatteryStatus) -> String {
        if battery.quality.isEmpty {
            return nonBatteryStateText(for: battery.kind)
        }
        switch battery.quality {
        case "bad": return "劣化大 (要交換)"
        case "normal": return "劣化小"
        case "good": return "正常"
        case "unknown": return "非認証電池"
        default: return battery.quality
        }
    }

    /// 残量・品質が取得できない場合の補足テキスト (給電源別)
    private func nonBatteryStateText(for kind: String) -> String {
        switch kind {
        case "ac_adapter": return "(AC 駆動中)"
        case "dc_coupler": return "(DC カプラ駆動中)"
        case "batterygrip": return "(バッテリーグリップ使用中)"
        case "not_inserted": return "(電池未挿入)"
        default: return "—"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func spacePercent(_ storage: StorageStatus.Storage) -> Int {
        guard storage.maxSize > 0 else { return 0 }
        let ratio = Double(storage.spaceSize) / Double(storage.maxSize) * 100
        return Int(ratio.rounded())
    }

    // MARK: - Private メソッド

    private func loadAllStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            deviceInfo = try await client.fetch(.deviceInformation)
            batteryStatus = try await client.fetch(.batteryStatus)
            storageStatus = try await client.fetch(.storageStatus)

            // ストレージ配下のディレクトリ一覧
            let storageContent: ContentURLList = try await client.fetch(
                .storageContents(storage: "sd")
            )
            let directoryNames = storageContent.lastPathComponents

            // 各ディレクトリの JPEG ファイル一覧を全ページ分順次取得
            var listings: [DirectoryListing] = []
            for directory in directoryNames {
                let fileURLs = try await client.fetchAllDirectoryFileURLs(
                    storage: "sd",
                    directory: directory,
                    type: .jpeg
                )
                listings.append(DirectoryListing(name: directory, fileURLs: fileURLs))
            }
            directoryListings = listings
        } catch {
            resetAllData()
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func resetAllData() {
        deviceInfo = nil
        batteryStatus = nil
        storageStatus = nil
        directoryListings = []
    }
}

#Preview("iPad Pro 11-inch") {
    ContentView()
        .environment(AppSettings())
        .environment(ConnectionMonitor(settings: AppSettings()))
}

#Preview("iPhone 17") {
    ContentView()
        .environment(AppSettings())
        .environment(ConnectionMonitor(settings: AppSettings()))
}
