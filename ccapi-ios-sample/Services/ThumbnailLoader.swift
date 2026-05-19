import Foundation
import SwiftUI
import UIKit

// MARK: - サムネイルローダー

/// CCAPI からサムネイル画像を取得し、メモリキャッシュを管理する。
///
/// 並列度は URLSession の接続プール (`CCAPIClient` 側で `httpMaximumConnectionsPerHost = 6`) に
/// 委ねる方針。リトライは行わず、失敗時は上位 (`ThumbnailCell`) が失敗状態を表示し、ユーザー
/// 操作 (リロードボタン) で再試行する。
///
/// 取得済みサムネイルは `NSCache` でメモリ保持し、スクロール往復・リロード時の再取得を防ぐ。
actor ThumbnailLoader {
    // MARK: - フィールド

    private let cache = NSCache<NSString, UIImage>()

    // MARK: - Public メソッド

    /// 指定ファイルのサムネイルを取得する。キャッシュがあれば即時返却、なければ HTTP 取得
    func loadThumbnail(
        client: CCAPIClient,
        storage: String,
        directory: String,
        file: String
    ) async throws -> UIImage {
        let key = "\(storage)/\(directory)/\(file)"
        let nsKey = key as NSString

        if let cached = cache.object(forKey: nsKey) {
            return cached
        }

        let data = try await client.fetchData(
            .fileContent(
                storage: storage,
                directory: directory,
                file: file,
                kind: .thumbnail
            )
        )
        guard let image = UIImage(data: data) else {
            throw CCAPIError.decoding(ThumbnailDecodeError())
        }
        cache.setObject(image, forKey: nsKey)
        return image
    }

    // MARK: - エラー型

    struct ThumbnailDecodeError: Error {}
}

// MARK: - Environment 連携

private struct ThumbnailLoaderKey: EnvironmentKey {
    static let defaultValue = ThumbnailLoader()
}

extension EnvironmentValues {
    var thumbnailLoader: ThumbnailLoader {
        get { self[ThumbnailLoaderKey.self] }
        set { self[ThumbnailLoaderKey.self] = newValue }
    }
}
