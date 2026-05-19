import Foundation
import SwiftUI
import UIKit

// MARK: - サムネイルローダー

/// CCAPI からサムネイル画像を取得し、メモリキャッシュとリトライを管理する。
///
/// シリアル化は行わず、URLSession の接続プール (`httpMaximumConnectionsPerHost = 6`) に
/// 並列度の調整を委ねる。失敗したフェッチは最大 3 回までリトライ (500ms バックオフ) する。
///
/// 取得済みサムネイルは `NSCache` でメモリ保持し、スクロール往復時の再取得を防ぐ。
actor ThumbnailLoader {
    // MARK: - 定数

    private let maxRetryAttempts = 3
    private let retryBackoffMilliseconds: UInt64 = 500

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

        let image = try await fetchWithRetry(
            client: client,
            storage: storage,
            directory: directory,
            file: file,
            attemptsLeft: maxRetryAttempts
        )
        cache.setObject(image, forKey: nsKey)
        return image
    }

    // MARK: - Private メソッド (リトライ付きフェッチ)

    private func fetchWithRetry(
        client: CCAPIClient,
        storage: String,
        directory: String,
        file: String,
        attemptsLeft: Int
    ) async throws -> UIImage {
        do {
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
            return image
        } catch is CancellationError {
            // 呼び出し側のキャンセルは伝播させる (リトライしない)
            throw CancellationError()
        } catch {
            if attemptsLeft > 1 {
                try? await Task.sleep(nanoseconds: retryBackoffMilliseconds * 1_000_000)
                return try await fetchWithRetry(
                    client: client,
                    storage: storage,
                    directory: directory,
                    file: file,
                    attemptsLeft: attemptsLeft - 1
                )
            }
            throw error
        }
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
