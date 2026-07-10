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
- コンテンツ一覧取得 (フォルダ・ファイル数の表示、全ページ取得)
- **画像サムネイルのグリッド表示** (LazyVGrid、メモリ+ディスクキャッシュ、自動リトライ)
- **画像詳細画面** (オリジナル画像 + メタデータ: ファイルサイズ・撮影日時・画像 px サイズ・回転角度・レーティング 等)
- **画像のローカルキャッシュ** (オンデマンド取得: グリッド=サムネ / 詳細=オリジナル。ディスク保持でアップロードにも再利用)
- **接続状態の監視・自動再接続** (到達性ベース、指数バックオフ、接続中/不安定/切断を UI 表示)
- **撮影イベント検知** (ポーリング。新着件数をメイン画面に表示)
- 接続先 IP/ポートの設定画面 (AP / インフラモード両対応、AP モードプリセット付き) + 画像キャッシュのクリア

### 実装予定

- 画像オリジナルのアップロード (キャッシュ済みオリジナルを外部へ送信)
- リモート撮影 (`POST /ccapi/ver100/shooting/control/shutterbutton` 等)
- ライブビュー (POST 開始 → GET 取得の二段階構成)
- カメラ設定の取得・変更 (シャッター速度、絞り、ISO 等)
- リトライ戦略の全体適用 (5xx / 4xx / タイムアウトの方針統一)

## 開発環境

| 項目 | 内容 |
|------|------|
| 言語 | Swift (最新安定版) |
| UI フレームワーク | SwiftUI |
| データ永続化 | UserDefaults (設定) / Documents 配下の画像ディスクキャッシュ |
| ターゲット | iPadOS / iOS |
| 最小サポート OS | iOS / iPadOS 17 以上 |
| 依存関係管理 | Swift Package Manager |

## 開発フェーズ

- **Phase 0** (完了): プロジェクト初期セットアップ
- **Phase 1** (完了): 実機検証 (CCAPI 有効化、エンドポイント疎通、API バージョン・仕様の確定)。詳細は `CLAUDE.md` を参照
- **Phase 2** (完了): MVP — カメラ情報表示、コンテンツ一覧、サムネイルグリッド、画像詳細
- **Phase 3** (完了): 安定化 — 接続監視・自動再接続、イベントポーリング、画像のオンデマンド二段キャッシュ、リトライ戦略の全体適用 (`CCAPIClient` に集約)
- **Phase 4**: 機能拡張 (アップロード、リモート撮影、設定変更、ライブビュー等)

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

## FAQ

### Q. 他の Canon カメラでも動作しますか?

CCAPI 対応機種であれば基本的なエンドポイント (`/deviceinformation` 等) は動作する見込みです。ただし `/contents` のサブパスは機種・ファームウェアにより API バージョンの対応状況が異なります。本実装は R100 で実機検証した結果に基づき ver100 パス前提となっており、R5・R3 等の上位機種では ver110 / ver130 のネイティブパスへの調整が必要になる場合があります。汎用化するには起動時に `GET /ccapi/` を叩いて利用可能エンドポイント一覧を取得し、動的にバージョン選択するのが本来の作法です。

### Q. Sony / Nikon / Fujifilm 等の他社カメラでも動きますか?

動きません。CCAPI は Canon 専用 API です。各メーカーは独自のプロトコルを持ちます:

- Sony: Camera Remote SDK / Imaging Edge
- Nikon: SnapBridge / NX MobileAir
- Fujifilm: Cam Remote API / X Acquire
- OM System: OI.Share API
- Panasonic: LUMIX Sync

エンドポイント・認証・データ構造のいずれも別物のため、本実装をそのまま流用することはできません。

### Q. AP モードとインフラモードのどちらを使うべきですか?

用途次第です:

- **AP モード**: カメラと iPad を直接接続。最大スループット・最小遅延、外部ネットワーク混線の影響なし。ただし iPad のインターネット接続が切れる (cellular 対応 iPad なら回線併用で回避可能)
- **インフラモード (ルーター経由)**: カメラと iPad を同じ Wi-Fi ルーターに参加させる。Wi-Fi 切り替え不要・インターネット併用可。ただしルーター経由のホップによる若干の性能低下と、会場 Wi-Fi 混線時の影響を受ける可能性あり

本アプリは設定画面で IP/ポートを切り替え可能なので、シーンに応じて使い分けられます。

### Q. なぜバッテリの残量が「(AC 駆動中)」と表示されるのですか?

R100 に AC アダプタ (DR-E17 等) を接続している間、CCAPI のバッテリ API は `level` と `quality` を空文字で返す仕様です (Canon 側の挙動)。バッテリ (LP-E17) で駆動すれば、残量「残量フル」「残量多」等と表示されます。

### Q. iOS の ATS で HTTP 通信が遮断されないのですか?

`Info.plist` で `NSAppTransportSecurity > NSAllowsLocalNetworking = true` を設定し、ローカルネットワーク (192.168.x.x 等のプライベート IP) への HTTP 通信を許可しています。CCAPI は HTTPS をサポートしていないため、この設定が必須です。

### Q. CCAPI のアクティベーションは何回必要ですか?

カメラ 1 台につき 1 回のみです。一度有効化すれば、ファームウェア更新後も再有効化は不要です。複数台所有している場合は各カメラに対して個別に実施する必要があります。

## ライセンス

個人の試験的リポジトリ。ライセンスは未定。
