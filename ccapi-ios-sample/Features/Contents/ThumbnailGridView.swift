import SwiftUI

// MARK: - サムネイルグリッド画面

/// 指定ディレクトリ配下のファイル URL リストを受け取り、サムネイル画像をグリッド表示する
struct ThumbnailGridView: View {
    // MARK: - 入力

    let storage: String
    let directory: String
    let fileURLs: [String]

    // MARK: - レイアウト

    /// 1 列あたりの最小幅 (pt)。大きくすると 1 行のセル数が減り、同時ロード対象も減る
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 6)]

    // MARK: - 本体

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(fileURLs, id: \.self) { fileURL in
                    if let fileName = URL(string: fileURL)?.lastPathComponent {
                        ThumbnailCell(
                            storage: storage,
                            directory: directory,
                            fileName: fileName
                        )
                    }
                }
            }
            .padding(6)
        }
        .navigationTitle(directory)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - サムネイルセル

/// 1 ファイル分のサムネイル取得・表示セル。出現時に共有 `ThumbnailLoader` 経由でロード
struct ThumbnailCell: View {
    // MARK: - 入力

    let storage: String
    let directory: String
    let fileName: String

    // MARK: - 環境・状態

    @Environment(\.ccapiClient) private var client
    @Environment(\.thumbnailLoader) private var loader

    @State private var image: UIImage?
    @State private var failed = false

    // MARK: - 本体

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.1))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                overlayContent
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .task {
                await load()
            }
    }

    // MARK: - サブビュー

    @ViewBuilder
    private var overlayContent: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if failed {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } else {
            ProgressView()
        }
    }

    // MARK: - Private メソッド

    private func load() async {
        guard image == nil, !failed else { return }
        do {
            image = try await loader.loadThumbnail(
                client: client,
                storage: storage,
                directory: directory,
                file: fileName
            )
        } catch is CancellationError {
            // View 破棄等によるキャンセル時は失敗扱いしない (新規 View で再ロードされる想定)
            return
        } catch {
            failed = true
        }
    }
}

#Preview {
    let settings = AppSettings()
    return NavigationStack {
        ThumbnailGridView(
            storage: "sd",
            directory: "100__TSB",
            fileURLs: []
        )
        .environment(settings)
        .environment(\.ccapiClient, CCAPIClient(settings: settings))
    }
}
