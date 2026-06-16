import SwiftUI

// MARK: - サムネイルグリッド画面

/// 指定ディレクトリ配下のファイル URL リストを受け取り、サムネイル画像をグリッド表示する。
/// 右上のリロードボタン / プルダウンで一覧の再取得と全セルの再ロードが可能。
struct ThumbnailGridView: View {
    // MARK: - 入力

    let storage: String
    let directory: String

    // MARK: - 環境・状態

    @Environment(\.ccapiClient) private var client

    @State private var fileURLs: [String]
    /// セル id に付与して、リロード時に全セルを新規 View として再生成するためのカウンタ
    @State private var refreshNonce = 0
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    // MARK: - 初期化

    init(storage: String, directory: String, fileURLs: [String]) {
        self.storage = storage
        self.directory = directory
        self._fileURLs = State(initialValue: fileURLs)
    }

    // MARK: - レイアウト

    /// 1 列あたりの最小幅 (pt)。大きくすると 1 行のセル数が減り、同時ロード対象も減る
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 6)]

    // MARK: - 本体

    var body: some View {
        ScrollView {
            if let errorMessage {
                errorBanner(errorMessage)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(fileURLs, id: \.self) { fileURL in
                    if let fileName = URL(string: fileURL)?.lastPathComponent {
                        NavigationLink {
                            ImageDetailView(
                                storage: storage,
                                directory: directory,
                                fileName: fileName
                            )
                        } label: {
                            ThumbnailCell(
                                storage: storage,
                                directory: directory,
                                fileName: fileName
                            )
                        }
                        .buttonStyle(.plain)
                        .id("\(fileURL)#\(refreshNonce)")
                    }
                }
            }
            .padding(6)
        }
        .refreshable {
            // .refreshable のタスクはインジケータ消滅時等にキャンセルされ得る。
            // 全ページ取得は複数リクエストで時間がかかるため、非構造化タスクに切り離して
            // 途中キャンセルで一覧更新が失われるのを防ぐ (スピナーは .value 待ちで維持)
            await Task { await reload() }.value
        }
        .navigationTitle(directory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                reloadToolbarButton
            }
        }
    }

    // MARK: - サブビュー

    @ViewBuilder
    private var reloadToolbarButton: some View {
        if isRefreshing {
            ProgressView()
        } else {
            Button {
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("再読み込み")
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 6)
            .padding(.top, 6)
    }

    // MARK: - Private メソッド

    private func reload() async {
        isRefreshing = true
        defer { isRefreshing = false }
        errorMessage = nil

        do {
            fileURLs = try await client.fetchAllDirectoryFileURLs(
                storage: storage,
                directory: directory,
                type: .jpeg
            )
            refreshNonce += 1
        } catch {
            // .refreshable / Task のキャンセルは無視 (ユーザー操作で正常)
            if isCancellation(error) { return }
            errorMessage = "再読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// CancellationError / URLError.cancelled / CCAPIError.transport ラップ済みのいずれかを判定
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        if let ccapiError = error as? CCAPIError, case .transport(let underlying) = ccapiError {
            if underlying is CancellationError { return true }
            if let urlError = underlying as? URLError, urlError.code == .cancelled { return true }
        }
        return false
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
