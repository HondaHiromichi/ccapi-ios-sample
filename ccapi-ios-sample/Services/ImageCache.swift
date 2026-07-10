import UIKit
import SwiftUI

// MARK: - 画像キャッシュ (ダウンロード付き)

/// 画像をローカルキャッシュ (メモリ + ディスク) で提供する。
/// キャッシュに無ければカメラから指定サイズ (`kind`) を取得して保存する。
///
/// 二段構成:
/// - グリッド表示は `thumbnail` (約 7KB) を使い高速に並べる
/// - 詳細表示やアップロードは `main` (オリジナル) を使う
///
/// サイズごとに別パス/別キーでキャッシュするため, サムネとオリジナルは共存する。
/// R100 は負荷時に一時的な失敗を返すことがあるため最大 `maxRetries` 回までバックオフ再試行する。
/// 呼び出し元 (セル) のキャンセル時は `CancellationError` を投げ, 失敗扱いしない。
actor ImageCache {
    private let client: CCAPIClient
    private let memory = NSCache<NSString, UIImage>()

    init(client: CCAPIClient) {
        self.client = client
    }

    /// 指定ファイル・指定サイズの画像を返す。メモリ -> ディスク -> ダウンロード(再試行付き)の順。
    /// キャンセル時は `CancellationError` を投げる
    func image(
        storage: String,
        directory: String,
        fileName: String,
        kind: CCAPIEndpoint.ContentKind
    ) async throws -> UIImage? {
        let relativePath = Self.relativePath(storage: storage, directory: directory, fileName: fileName, kind: kind)
        let key = relativePath as NSString

        // 1. メモリキャッシュ
        if let cached = memory.object(forKey: key) {
            return cached
        }

        // 2. ディスクキャッシュ
        let fileURL = Self.documentsURL(for: relativePath)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key)
            return image
        }

        // 3. ダウンロード (再試行は CCAPIClient に集約済み)
        do {
            let data = try await client.fetchData(
                .fileContent(storage: storage, directory: directory, file: fileName, kind: kind)
            )
            try? Self.save(data: data, to: fileURL)
            guard let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: key)
            return image
        } catch {
            // キャンセルは失敗扱いしない (呼び出し元セルが再ロードに任せる)
            if Self.isCancellation(error) {
                throw CancellationError()
            }
            return nil
        }
    }

    // MARK: - キャッシュ操作

    /// メモリ + ディスクのキャッシュを全消去する
    func clearAll() {
        memory.removeAllObjects()
        Self.clearDiskCache()
    }

    /// ディスク上のキャッシュディレクトリを削除する (旧 Transfers も併せて掃除)
    nonisolated static func clearDiskCache() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for name in ["ImageCache", "Transfers"] {
            try? FileManager.default.removeItem(at: documents.appendingPathComponent(name))
        }
    }

    // MARK: - 判定ヘルパー

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        if let ccapiError = error as? CCAPIError, case .transport(let underlying) = ccapiError {
            if underlying is CancellationError { return true }
            if let urlError = underlying as? URLError, urlError.code == .cancelled { return true }
        }
        return false
    }

    // MARK: - パスヘルパー (純粋関数のため非隔離)

    /// キャッシュ相対パス。kind/storage/directory で衝突を避ける
    nonisolated static func relativePath(
        storage: String,
        directory: String,
        fileName: String,
        kind: CCAPIEndpoint.ContentKind
    ) -> String {
        "ImageCache/\(kind.rawValue)/\(storage)/\(directory)/\(fileName)"
    }

    nonisolated static func documentsURL(for relativePath: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(relativePath)
    }

    nonisolated static func save(data: Data, to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Environment 連携

private struct ImageCacheKey: EnvironmentKey {
    @MainActor static let defaultValue = ImageCache(client: CCAPIClient(settings: AppSettings()))
}

extension EnvironmentValues {
    var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
