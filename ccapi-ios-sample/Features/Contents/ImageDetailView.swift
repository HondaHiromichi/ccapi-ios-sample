import SwiftUI

// MARK: - 画像詳細画面

/// 単一画像の表示画面。画像本体 (`display`) とメタデータ (`info`) を取得して表示する
struct ImageDetailView: View {
    // MARK: - 入力

    let storage: String
    let directory: String
    let fileName: String

    // MARK: - 環境・状態

    @Environment(\.ccapiClient) private var client

    @State private var image: UIImage?
    @State private var metadata: ImageMetadata?
    @State private var imageErrorMessage: String?
    @State private var isLoadingImage = false

    // MARK: - 本体

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageSection

                if let metadata {
                    metadataCard(metadata)
                }
            }
            .padding()
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    // MARK: - サブビュー

    @ViewBuilder
    private var imageSection: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let message = imageErrorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .padding()
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func metadataCard(_ meta: ImageMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メタデータ")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            row("ファイル名", fileName)
            row("ファイルサイズ", formatBytes(meta.filesize))
            if let image {
                row("画像サイズ", "\(Int(image.size.width)) × \(Int(image.size.height)) px")
            }
            row("撮影/更新日時", formatDate(meta.lastmodifieddate))
            row("回転角度", "\(meta.rotate)°")
            row("レーティング", ratingLabel(meta.rating))
            row("プロテクト", boolLabel(meta.protect))
            row("アーカイブ", boolLabel(meta.archive))
            if let playtime = meta.playtime {
                row("再生時間", "\(playtime) 秒")
            }
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

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ raw: String) -> String {
        // CCAPI は "Wed, 04 Jul 2018 12:34:56 GMT" 形式 (RFC 1123)
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = inputFormatter.date(from: raw) else {
            return raw
        }
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ja_JP")
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .medium
        return outputFormatter.string(from: date)
    }

    private func ratingLabel(_ raw: String) -> String {
        switch raw {
        case "off": return "なし"
        case "1": return "★"
        case "2": return "★★"
        case "3": return "★★★"
        case "4": return "★★★★"
        case "5": return "★★★★★"
        default: return raw
        }
    }

    private func boolLabel(_ raw: String) -> String {
        switch raw {
        case "enable": return "有効"
        case "disable": return "無効"
        default: return raw
        }
    }

    // MARK: - Private メソッド

    private func load() async {
        async let imageTask: () = loadImage()
        async let metadataTask: () = loadMetadata()
        _ = await (imageTask, metadataTask)
    }

    /// 画像を取得。`display` で失敗したら `main` にフォールバック
    private func loadImage() async {
        isLoadingImage = true
        defer { isLoadingImage = false }

        if let img = await fetchImage(kind: .display) {
            image = img
            return
        }
        if let img = await fetchImage(kind: .main) {
            image = img
            return
        }
        imageErrorMessage = "画像を取得できませんでした"
    }

    private func fetchImage(kind: CCAPIEndpoint.ContentKind) async -> UIImage? {
        do {
            let data = try await client.fetchData(
                .fileContent(
                    storage: storage,
                    directory: directory,
                    file: fileName,
                    kind: kind
                )
            )
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func loadMetadata() async {
        do {
            metadata = try await client.fetch(
                .fileContent(
                    storage: storage,
                    directory: directory,
                    file: fileName,
                    kind: .info
                ),
                as: ImageMetadata.self
            )
        } catch {
            // メタデータ取得失敗は無視 (取得できなければ非表示)
        }
    }
}

#Preview {
    let settings = AppSettings()
    return NavigationStack {
        ImageDetailView(
            storage: "sd",
            directory: "100__TSB",
            fileName: "IMG_0001.JPG"
        )
        .environment(settings)
        .environment(\.ccapiClient, CCAPIClient(settings: settings))
    }
}
