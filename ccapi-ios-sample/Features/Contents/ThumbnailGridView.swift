import SwiftUI

// MARK: - サムネイルグリッド画面

/// 指定ディレクトリ配下のファイルをグリッド表示する。
/// 各セルが独立して画像キャッシュ (メモリ/ディスク/ダウンロード) を解決し, 取得でき次第表示する。
/// ダウンロードは `ImageCache` 経由で行われ, 同時数は共有ゲートの上限に従う。
struct ThumbnailGridView: View {
    // MARK: - 入力

    let storage: String
    let directory: String

    // MARK: - 環境・状態

    @Environment(\.ccapiClient) private var client

    @State private var fileURLs: [String]
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    // MARK: - 初期化

    init(storage: String, directory: String, fileURLs: [String]) {
        self.storage = storage
        self.directory = directory
        self._fileURLs = State(initialValue: fileURLs)
    }

    // MARK: - レイアウト

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 6)]

    // MARK: - 本体

    var body: some View {
        ScrollView {
            if let errorMessage {
                errorBanner(errorMessage)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                // 新しい写真 (ファイル番号が大きい) を先頭に表示する
                ForEach(fileURLs.reversed(), id: \.self) { fileURL in
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
                    }
                }
            }
            .padding(6)
        }
        .refreshable {
            await reload()
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

    /// ファイル一覧を再取得する (画像自体は各セルがキャッシュ経由で取得する)
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

/// 1 ファイル分のセル。出現時に `ImageCache` 経由で画像を取得し, 取得でき次第表示する。
struct ThumbnailCell: View {
    // MARK: - 入力

    let storage: String
    let directory: String
    let fileName: String

    // MARK: - 環境・状態

    @Environment(\.imageCache) private var imageCache

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

    private func load() async {
        guard image == nil else { return }
        failed = false
        do {
            // グリッドはサムネ (約 7KB) で高速表示する
            if let loaded = try await imageCache.image(storage: storage, directory: directory, fileName: fileName, kind: .thumbnail) {
                image = loaded
            } else {
                failed = true
            }
        } catch is CancellationError {
            // セル再利用等のキャンセルは失敗扱いしない (再出現時に再ロード)
        } catch {
            failed = true
        }
    }
}
