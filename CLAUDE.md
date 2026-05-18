# CLAUDE.md

このファイルは Claude Code がリポジトリで作業する際の指針を示す。
グローバル規約 (`~/.claude/CLAUDE.md`) の内容を前提とし、本プロジェクト固有の方針のみ記述する。

## プロジェクト概要

Canon EOS R100 と iPad を Wi-Fi 接続し、CCAPI (Camera Control API) 経由で画像転送・カメラ制御を行う iOS / Swift サンプル。
個人の試験的リポジトリ。

## 技術スタック

- **言語**: Swift (最新安定版)
- **UI**: SwiftUI
- **永続化**: SwiftData
- **ターゲット**: iPadOS 17 以上
- **依存管理**: Swift Package Manager

## アーキテクチャ方針

### CCAPI クライアントレイヤー

- `URLSession` を直接使用 (SDK 依存なし)
- HTTP 通信はラッパー型を介して行い、エンドポイント定義と通信処理を分離する
- 認証・セッション管理は専用の責務として切り出す
- API バージョン (例: `ver100` / `ver110` 等) は実機検証で確認した上で集約定数として保持する

### URLSession 設定の基本値

```swift
config.timeoutIntervalForRequest = 15
config.timeoutIntervalForResource = 60
config.waitsForConnectivity = false
config.httpMaximumConnectionsPerHost = 2
```

### 接続管理

- Bluetooth 常時ペアリング -> Wi-Fi 自動昇格をアプリから制御
- `NWPathMonitor` で経路監視
- 切断検知時は指数バックオフ (2s -> 4s -> 8s -> 16s) で自動再接続
- 接続状態 (接続中 / 不安定 / 切断) を常に UI 上に明示

### 転送キュー

- 撮影イベントは CCAPI のイベント通知機構 (具体的なエンドポイント・方式は Phase 1 で確認) でポーリング/購読
- 未取得画像 ID を SwiftData にキューとして永続化
- 画像ごとに状態を管理: `pending` / `downloading` / `done` / `failed`
- アプリ強制終了に備えて永続化を維持
- 部分転送された画像は破棄して最初からやり直し

### リトライ戦略

- HTTP 5xx -> 指数バックオフで最大 3 回再試行
- HTTP 4xx -> ユーザー通知 (カメラ側の状態異常の可能性)
- タイムアウト -> 接続状態を再評価してから再試行

### 画像サイズ階層化

- 通常運用では中サイズ (数百 KB〜1MB) で即時転送
- オリジナルは必要時にユーザー操作で取得
- RAW 撮影時はサムネ / 中サイズのみをデフォルト取得

## コーディング規約

グローバル規約の「iOS Swift コーディング規約」に準拠する。本プロジェクトでの補足事項:

- `// MARK: -` のセクション名は日本語で記述する
- View / ViewModel / Service / Model のレイヤー分離を意識する
- SwiftUI の `@Observable` (iOS 17+) を優先し、`ObservableObject` は新規実装で避ける
- CCAPI のエンドポイント文字列はリテラル直書きせず、enum または定数で集約する

## ファイル構成 (想定)

```
ccapi-ios-sample/
├── README.md
├── CLAUDE.md
├── .gitignore
├── ccapi-ios-sample.xcodeproj/
└── ccapi-ios-sample/
    ├── App/                  # アプリエントリ、AppRouter
    ├── Features/             # 画面単位の機能 (View + ViewModel)
    ├── Services/             # CCAPIClient, TransferQueue, ConnectionMonitor 等
    ├── Models/               # データモデル (SwiftData @Model 含む)
    ├── Resources/            # アセット、Info.plist
    └── Extensions/           # 型拡張
```

## 開発フェーズと現在地

- [x] Phase 0: プロジェクト初期セットアップ (本リポジトリ作成)
- [ ] Phase 1: 実機検証 (CCAPI 有効化、エンドポイント疎通、API 仕様の確定)
- [ ] Phase 2: MVP (画像一覧取得・ダウンロード、シンプル UI)
- [ ] Phase 3: 安定化 (転送キュー、自動再接続)
- [ ] Phase 4: 機能拡張

## Phase 1 で確認すべき CCAPI 仕様

実機検証で確定させ、確認次第このドキュメントを更新する:

- 利用可能な API バージョン (`/ccapi/ver100/`, `/ccapi/ver110/` 等)
- 画像一覧・取得のエンドポイントとレスポンス構造
- ライブビューのレスポンス形式 (multipart 等)
- 撮影イベントの通知方式 (ポーリング / SSE / その他)
- 同時接続クライアント数の制約
- 認証・セッション維持の有無

## 既知の制約 (公式マニュアル確認済み)

- R100 の Wi-Fi は 2.4GHz のみ (5GHz 非対応)。混線対策が安定性の鍵
- R100 の Bluetooth は 4.2 LE
- Bluetooth では画像転送は実用にならない。Wi-Fi をデータチャネルとして使う前提
- CCAPI 有効化は Canon Developer Community 配布の Activation Tool で実施 (macOS 版あり)
