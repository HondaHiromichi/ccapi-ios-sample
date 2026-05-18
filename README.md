# ccapi-ios-sample

Canon CCAPI (Camera Control API) を iOS / Swift から扱うサンプル実装。

## 概要

**Canon EOS R100** と **iPad** を Wi-Fi 無線接続し、CCAPI 経由で画像転送・リモート撮影・カメラ設定変更等を行う iOS アプリケーションのサンプル。
カメラ AP モードと CCAPI を用いて、特別な SDK に依存せず HTTP ベースで実装する構成を試す。

## アーキテクチャ

```
[EOS R100 (Wi-Fi AP)] <-Wi-Fi 2.4GHz-> [iPad (Swift App)]
                                            |
                                  HTTPリクエスト (URLSession)
                                            |
                                  CCAPI (Camera Control API)
```

- **接続方式**: カメラ AP モード (外部ネットワークから物理的に分離)
- **通信プロトコル**: Canon CCAPI (HTTP ベース、SDK 不要)
- **対応機種**: Canon EOS R100 ほか CCAPI 対応機種

## R100 の無線仕様 (Canon 公式マニュアルより)

- Wi-Fi: IEEE 802.11b/g/n、**2.4GHz 帯のみ** (5GHz 非対応)
- Bluetooth: 4.2 Low Energy

## 主要機能 (実装予定)

- 画像一覧の取得・ダウンロード (サイズ選択: サムネ / 小 / 中 / 大 / オリジナル)
- リモート撮影
- ライブビュー (具体的なレスポンス形式は Phase 1 で確認)
- カメラ設定の取得・変更 (シャッター速度、絞り、ISO 等)
- 撮影イベントの通知 (ポーリングまたは SSE、方式は Phase 1 で確認)
- 転送キューの永続化 (SwiftData)
- 自動再接続 (指数バックオフ)

## 開発環境

| 項目 | 内容 |
|------|------|
| 言語 | Swift (最新安定版) |
| UI フレームワーク | SwiftUI |
| データ永続化 | SwiftData |
| ターゲット | iPadOS |
| 最小サポート OS | iOS / iPadOS 17 以上 (SwiftData 利用のため) |
| 依存関係管理 | Swift Package Manager |

## 開発フェーズ

- **Phase 1**: 実機検証 (CCAPI 有効化、エンドポイント疎通確認、API バージョン・仕様の確定)
- **Phase 2**: MVP (CCAPI クライアント、画像一覧取得・ダウンロード、シンプル UI)
- **Phase 3**: 安定化 (転送キュー、自動再接続、エラーハンドリング)
- **Phase 4**: 機能拡張 (画像サイズ選択、診断機能、複数カメラ切り替え)

## セットアップ

### 前提

- macOS + 最新版 Xcode (執筆時点: Xcode 26)
- iPad (iPadOS 17 以上)
- Canon EOS R100 (CCAPI 有効化済み)

### CCAPI の有効化

CCAPI Activation Tool は macOS 版が Canon Developer Community から配布されている (最新は CCAPI v1.4.0 Rev. 1.4 / 2026-03-31 時点、macOS 15.x 対応)。

1. Canon Developer Community に登録し、macOS 版 CCAPI Activation Tool を入手
2. R100 を USB で Mac に接続し、Tool を実行
3. カメラごとに 1 回だけ実施 (再有効化不要)

## 参考リンク

- Canon Developer Community: https://developercommunity.usa.canon.com/
- CCAPI 対応機種リスト: https://developercommunity.usa.canon.com/s/article/CCAPI-Supported-Cameras
- CCAPI リリースノート (Canon Asia): https://asia.canon/en/campaign/developerresources/camera/cap/camera-control-api-release-note
- R100 マニュアル (Wi-Fi/Bluetooth): https://cam.start.canon/en/C015/manual/html/UG-08_Wi-Fi_0030.html

## ライセンス

個人の試験的リポジトリ。ライセンスは未定。
