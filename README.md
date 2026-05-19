# ccapi-ios-sample

Canon CCAPI (Camera Control API) を iOS / Swift から扱うサンプル実装。

## 概要

**Canon EOS R100** と **iPad** を Wi-Fi 接続し、CCAPI 経由で画像転送・リモート撮影・カメラ設定変更等を行う iOS アプリケーションのサンプル。
カメラアクセスポイントモード (カメラが AP として振る舞う直接接続) と、アクセスポイント経由 (家庭/オフィスのルーターに参加するインフラストラクチャ接続) の **両モードに対応** し、特別な SDK に依存せず HTTP ベースで実装する構成を試す。

## アーキテクチャ

```
[EOS R100] <-Wi-Fi 2.4GHz-> [iPad (Swift App)]
              |
              ↑ いずれのモードでも CCAPI は同じ HTTP API
              |
        ┌─────┴─────┐
        ▼           ▼
    AP モード     インフラモード (ルーター経由)
    192.168.1.2   DHCP 割り当ての IP
```

- **接続方式**: カメラ AP モード / インフラモードの双方をアプリ設定で切替可能
- **通信プロトコル**: Canon CCAPI (HTTP/1.1 + JSON、SDK 不要、認証なし)
- **対応機種**: Canon EOS R100 ほか CCAPI 対応機種

## R100 の無線仕様 (Canon 公式マニュアルより)

- Wi-Fi: IEEE 802.11b/g/n、**2.4GHz 帯のみ** (5GHz 非対応)
- Bluetooth: 4.2 Low Energy

## 主要機能

### 実装済み

- カメラ情報取得 (デバイス情報 / バッテリ / ストレージ)
- コンテンツ一覧取得 (フォルダ・ファイル数の表示)
- 接続先 IP/ポートの設定画面 (AP / インフラモード両対応、AP モードプリセット付き)

### 実装予定

- 画像サムネイルのグリッド表示
- 画像中サイズ・オリジナルのダウンロード
- リモート撮影 (`POST /ccapi/ver100/shooting/control/shutterbutton` 等)
- ライブビュー (POST 開始 → GET 取得の二段階構成)
- カメラ設定の取得・変更 (シャッター速度、絞り、ISO 等)
- 撮影イベントの通知 (ポーリング。R100 は SSE 非対応のためポーリング前提)
- 転送キューの永続化 (SwiftData)
- 自動再接続 (指数バックオフ)

## 開発環境

| 項目 | 内容 |
|------|------|
| 言語 | Swift (最新安定版) |
| UI フレームワーク | SwiftUI |
| データ永続化 | UserDefaults (現状) / SwiftData (将来) |
| ターゲット | iPadOS / iOS |
| 最小サポート OS | iOS / iPadOS 17 以上 |
| 依存関係管理 | Swift Package Manager |

## 開発フェーズ

- **Phase 0** (完了): プロジェクト初期セットアップ
- **Phase 1** (完了): 実機検証 (CCAPI 有効化、エンドポイント疎通、API バージョン・仕様の確定)。詳細は `CLAUDE.md` を参照
- **Phase 2** (進行中): MVP
  - [x] CCAPI クライアント基盤、設定画面、カメラ情報表示、コンテンツ一覧取得
  - [ ] サムネイルグリッド UI、画像詳細・ダウンロード
- **Phase 3**: 安定化 (リトライ、接続監視、自動再接続、転送キュー永続化)
- **Phase 4**: 機能拡張 (リモート撮影、設定変更、ライブビュー、アップロード等)

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

### カメラのモード設定

- **AP モード**: メニュー → 無線通信設定 → Camera Control API → Add connection → Add with wizard → **Camera access point mode** を選択。アプリ設定の「AP モードプリセット」で IP `192.168.1.2:8080` をワンタップ適用可能
- **インフラモード**: 同様の流れで **Access point mode** を選択し、家のルーターに接続。カメラ画面に表示される DHCP IP をアプリの設定画面に入力する

## 参考リンク

- Canon Developer Community: https://developercommunity.usa.canon.com/
- CCAPI 対応機種リスト: https://developercommunity.usa.canon.com/s/article/CCAPI-Supported-Cameras
- CCAPI リリースノート (Canon Asia): https://asia.canon/en/campaign/developerresources/camera/cap/camera-control-api-release-note
- R100 マニュアル (Wi-Fi/Bluetooth): https://cam.start.canon/en/C015/manual/html/UG-08_Wi-Fi_0030.html

## ライセンス

個人の試験的リポジトリ。ライセンスは未定。
