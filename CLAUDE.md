# CLAUDE.md

このファイルは Claude Code がリポジトリで作業する際の指針を示す。
グローバル規約 (`~/.claude/CLAUDE.md`) の内容を前提とし、本プロジェクト固有の方針のみ記述する。

## プロジェクト概要

Canon EOS R100 と iPad を Wi-Fi 接続し、CCAPI (Camera Control API) 経由で画像転送・カメラ制御を行う iOS / Swift サンプル。
個人の試験的リポジトリ。

## 技術スタック

- **言語**: Swift (最新安定版)
- **UI**: SwiftUI
- **永続化**: `UserDefaults` (接続先設定) + Documents 配下の画像ディスクキャッシュ。SwiftData は転送キュー用に検討したが不採用
- **ターゲット**: iPadOS 17 以上
- **依存管理**: Swift Package Manager

## アーキテクチャ方針

### CCAPI クライアントレイヤー

- `URLSession` を直接使用 (SDK 依存なし)
- HTTP 通信はラッパー型を介して行い、エンドポイント定義 (`CCAPIEndpoint`) と通信処理 (`CCAPIClient`) を分離
- **認証は不要** (Phase 1 実機検証で確認済み)
- ベース URL は **`AppSettings` から動的取得** (host/port を `UserDefaults` に永続化)。AP モード固定 IP / インフラモード DHCP IP の両方に対応
- API バージョンは `CCAPIVersion` enum で集約 (`v100` / `v110` / `v130`)
- **`CCAPIClient` はアプリ全体で 1 インスタンス共有** (Environment 経由で注入)。URLSession の接続プールを集約し、`httpMaximumConnectionsPerHost = 6` で並列度を確保
- **R100 固有の事情**: `/contents` のサブパス (ディレクトリ・ファイル一覧等) は **ver100 で叩く**。ver130 はストレージ一覧ルート (`/ccapi/ver130/contents`) のみ有効で、サブパス (`/ccapi/ver130/contents/sd` 等) は 404 を返す

### 画像取得・キャッシュ (`ImageCache`)

- **画像取り込み方針は「オンデマンド」**。撮影後に自動一括ダウンロードはせず、ユーザーが開いた画面の分だけ取得・キャッシュする
- `ImageCache` (actor) がメモリ (`NSCache`) + ディスク (`Documents/ImageCache/{kind}/{storage}/{directory}/{file}`) のキャッシュを集中管理。無ければカメラから取得して保存
- **二段構成 (kind 出し分け)**:
  - グリッド表示 = `thumbnail` (約 7KB) で高速表示
  - 詳細表示 / 将来のアップロード = `main` (オリジナル) をディスク保持
- フェッチ失敗時は **最大 3 回まで自動リトライ** (500ms バックオフ)
- `CancellationError` / `URLError.cancelled` は失敗扱いせず、View 再生成時の再ロードに任せる
- 並列度は URLSession の接続プール (6) に委ねる。グリッドはサムネ (小) のため並列でも軽い
- ディスクキャッシュは Settings の「画像キャッシュをクリア」で削除可能

### URLSession 設定の基本値

```swift
config.timeoutIntervalForRequest = 15
config.timeoutIntervalForResource = 60
config.waitsForConnectivity = false
config.httpMaximumConnectionsPerHost = 2
```

### 接続管理 (`ConnectionMonitor`, 実装済み)

- **到達性ベースで判定** (`NWPathMonitor` の経路有無だけではカメラのスリープ/SSID 切断を検知できないため)。軽量エンドポイント (`deviceinformation`) を定期的に叩き、HTTP 応答有無で接続状態を決める
- 切断時は指数バックオフ (2s -> 4s -> 8s -> 16s) で再チェック間隔を広げて自動再接続
- 接続状態 (接続中 / 不安定 / 切断) を常に UI 上に明示 (`ConnectionStatusBadge`)
- `NWPathMonitor` は経路全喪失の即時切断と復帰時の即時再チェックに併用
- Bluetooth -> Wi-Fi 自動昇格は iOS のサンドボックス制約によりスコープ外

### 撮影イベント検知 (`EventPoller`, 実装済み)

- 撮影イベントは **`GET /ccapi/ver100/event/polling?continue=off`** でポーリング取得 (R100 は SSE 非対応)
- レスポンスはカメラ全状態の大きな JSON。差分の `addedcontents` から新規撮影を検知
- 検知結果は **メイン画面の新着情報表示のみ**に使う。オンデマンド方針のため自動ダウンロードはしない (ダウンロードはグリッド/詳細を開いた時)

### ライブビュー

- 取得は二段階構成: **POST** `/ccapi/ver100/shooting/liveview` で開始 → **GET** `/ccapi/ver100/shooting/liveview/flip` で取得
- 開始前に GET すると `503 Live view not started` が返るため、起動シーケンスをクライアント側で管理する
- 別途 `/ccapi/ver100/shooting/liveview/rtp` (RTP モード) も存在。MVP では `flip` を採用予定

### リトライ戦略 (`CCAPIClient` に集約, 実装済み)

- 全 CCAPI 呼び出しは `CCAPIClient.fetchData` の共通リトライを通る
- HTTP 5xx / タイムアウト等の一過性エラー -> 指数バックオフ (0.5s / 1s / 2s) で最大 3 回再試行
- HTTP 4xx / デコード不能 / URL 不正 -> 再試行せず即 throw (呼び出し側でユーザー通知。カメラ側の状態異常の可能性)
- キャンセル (`URLError.cancelled` / `CancellationError`) -> 再試行せず伝播
- 「タイムアウト時に接続状態を再評価してから再試行」はバックオフ再試行で代替 (`ConnectionMonitor` との密結合を避けた簡略化)
- `ConnectionMonitor` のヘルスチェックは対象外 (速い単発プローブを維持するため)

### 画像サイズ階層化

- **R100 は `kind=display` (中サイズ) 非対応** (400 Illegal query parameter, 実機確認済み)。使えるのは `thumbnail` (約 7KB) と `main` (オリジナル, 数百 KB〜) の 2 段のみ
- グリッド表示 = `thumbnail` / 詳細・アップロード用 = `main`
- `main` はオリジナルの実ファイルなので、キャッシュしたものをそのままアップロードに使える

## コーディング規約

グローバル規約の「iOS Swift コーディング規約」に準拠する。本プロジェクトでの補足事項:

- `// MARK: -` のセクション名は日本語で記述する
- View / ViewModel / Service / Model のレイヤー分離を意識する
- SwiftUI の `@Observable` (iOS 17+) を優先し、`ObservableObject` は新規実装で避ける
- CCAPI のエンドポイント文字列はリテラル直書きせず、enum または定数で集約する

## ファイル構成 (現在)

```
ccapi-ios-sample/
├── README.md
├── CLAUDE.md
├── Info.plist                                 # ATS 設定 (HTTP 許可)
├── .gitignore
├── ccapi-ios-sample.xcodeproj/
└── ccapi-ios-sample/
    ├── ccapi_ios_sampleApp.swift              # App エントリ (各サービス注入)
    ├── ContentView.swift                      # メイン画面 (接続状態 / 新着 / カメラ情報・コンテンツ一覧)
    ├── Assets.xcassets/
    ├── Features/
    │   ├── Settings/
    │   │   └── SettingsView.swift             # 接続先設定 + 画像キャッシュクリア
    │   ├── Connection/
    │   │   └── ConnectionStatusBadge.swift    # 接続状態バッジ
    │   └── Contents/
    │       ├── ThumbnailGridView.swift        # サムネイルグリッド + セル (ImageCache 経由)
    │       └── ImageDetailView.swift          # 画像詳細 (オリジナル画像 + メタデータ)
    └── Services/
        ├── AppSettings.swift                  # @Observable 設定モデル
        ├── CCAPIClient.swift                  # URLSession ラッパー (アプリ全体で共有)
        ├── CCAPIEndpoint.swift                # エンドポイント enum
        ├── CCAPIError.swift                   # 共通エラー型
        ├── ImageCache.swift                   # actor: 画像のメモリ+ディスクキャッシュ + ダウンロード
        ├── ConnectionState.swift              # 接続状態 enum
        ├── ConnectionMonitor.swift            # @Observable: 到達性ベースの接続監視 + 自動再接続
        ├── EventPoller.swift                  # @Observable: 撮影イベントポーリング (新着検知)
        └── Models/
            ├── BatteryStatus.swift
            ├── CameraEvent.swift              # event/polling の addedcontents
            ├── ContentURLList.swift           # { "url": [...] } レスポンス
            ├── DeviceInformation.swift
            ├── DirectoryContentsNumber.swift  # ?kind=number (総ページ数)
            ├── ImageMetadata.swift            # ?kind=info レスポンス
            └── StorageStatus.swift
```

## 開発フェーズと現在地

- [x] Phase 0: プロジェクト初期セットアップ
- [x] Phase 1: 実機検証 (CCAPI 有効化、エンドポイント疎通、API 仕様の確定) — 同時接続挙動は Phase 2 で実用範囲を確認 (`httpMaximumConnectionsPerHost = 6`、6 並列で十分実用)
- [x] Phase 2: MVP (完了)
  - [x] Xcode プロジェクト雛形
  - [x] CCAPI クライアント基盤 (`CCAPIClient` / `CCAPIEndpoint` / `CCAPIError`)
  - [x] ATS 設定 (`NSAllowsLocalNetworking`)
  - [x] 接続先 IP/ポート可変化 (`AppSettings` + `SettingsView`)
  - [x] デバイス情報・バッテリ・ストレージ表示
  - [x] コンテンツ一覧取得・表示 (フォルダ・ファイル数)
  - [x] 画像サムネイルグリッド UI (`ThumbnailGridView`)
  - [x] 画像詳細画面 (`ImageDetailView`: オリジナル画像 + メタデータ)
- [x] Phase 3: 安定化 (完了)
  - [x] 接続監視 + 自動再接続 (`ConnectionMonitor`, 到達性ベース, 指数バックオフ)
  - [x] イベントポーリング (`EventPoller`, 新着検知)
  - [x] 画像取り込みを **オンデマンド + 二段キャッシュ** に確定 (`ImageCache`)。当初の「自動取り込み + SwiftData 転送キュー」は不採用
  - [x] リトライ戦略の全体適用 (`CCAPIClient` に集約: 5xx/タイムアウト→指数バックオフ最大3回 / 4xx→即通知 / キャンセル→伝播)
- [ ] Phase 4: 機能拡張 (画像オリジナルのアップロード / リモート撮影 / カメラ設定 / ライブビュー / 診断 / 複数カメラ)

## Phase 1 検証結果 (R100 firmware 1.1.0)

| 項目 | 値 |
|---|---|
| プロトコル | HTTP/1.1、`application/json` |
| 認証 | 不要 |
| 利用可能バージョン | `ver100` がメイン / `ver110` は `highframerate` 設定のみ / `ver130` は `/contents` ルートのみ (サブパスは ver100) |
| デバイス情報 | `GET /ccapi/ver100/deviceinformation` |
| バッテリ | `GET /ccapi/ver100/devicestatus/battery` |
| ストレージ | `GET /ccapi/ver100/devicestatus/storage` |
| ディレクトリ一覧 | `GET /ccapi/ver100/contents/{storage}` |
| ファイル一覧 | `GET /ccapi/ver100/contents/{storage}/{directory}?type={jpeg/cr2/mp4/...}&page=N` |
| イベント通知 | `GET /ccapi/ver100/event/polling?continue={on/off}` (ポーリングのみ、SSE 非対応) |
| ライブビュー | `POST /ccapi/ver100/shooting/liveview` で開始 → `GET .../shooting/liveview/flip` で取得 |
| リモート撮影 | `POST /ccapi/ver100/shooting/control/shutterbutton` 等 |
| 設定取得・変更 | `/ccapi/ver100/shooting/settings/{av,tv,iso,exposure,wb,...}` GET/PUT |

## 未確定項目 (Phase 2 以降で追検)

- **同時接続挙動**: Phase 1 検証では `ver110/devicestatus/battery` を 2 本並列で叩いて両方 404 となり結論が出ず。`ver100` で再検証する。実装段階では並行リクエストを避け、シーケンシャル fetch でしのいでいる

## 既知の制約 (公式マニュアル確認済み)

- R100 の Wi-Fi は 2.4GHz のみ (5GHz 非対応)。混線対策が安定性の鍵
- R100 の Bluetooth は 4.2 LE
- Bluetooth では画像転送は実用にならない。Wi-Fi をデータチャネルとして使う前提
- CCAPI 有効化は Canon Developer Community 配布の Activation Tool で実施 (macOS 版あり)
- HTTP 通信のため iOS の ATS で遮断される。`NSAppTransportSecurity > NSAllowsLocalNetworking = true` を `Info.plist` で許可している
