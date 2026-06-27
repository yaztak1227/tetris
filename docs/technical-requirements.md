# Technical Requirements

## 採用技術スタック

本プロジェクトでは、Mac ネイティブアプリとして以下の構成を採用する。

```text
Language: Swift
App/UI: SwiftUI
2D Rendering: SpriteKit
Persistence: UserDefaults / JSON file
Testing: XCTest
Build/Package: Xcode / xcodebuild
Distribution: macOS .app bundle
```

## フレームワーク選定

### 採用: Swift + SwiftUI + SpriteKit

この構成を採用する。

理由:

- macOS ネイティブの `.app` として起動しやすい。
- Finder、Dock、Launchpad、フルスクリーン、アプリ終了などの macOS 標準挙動に自然に対応できる。
- SpriteKit は Apple 標準の 2D 描画フレームワークであり、テトリスのような 2D グリッドゲームに適している。
- SwiftUI はメニュー、設定、記録画面、モード選択などのアプリ UI を作りやすい。
- ゲームロジックを Swift の純粋な型として実装し、XCTest で T-Spin、SRS、7-bag、スコアリングを検証しやすい。
- Apple Silicon / Intel Mac 向けの Universal アプリ配布を見据えやすい。

懸念:

- Windows / Linux への移植性は低い。
- Web 版とのコード共有は難しい。
- SpriteKit は高度な 3D や大規模ゲームエンジン用途には向かない。

本プロジェクトは初期ターゲットを macOS に絞っており、Tetris は 2D・低負荷・入力応答性重視のゲームであるため、上記の懸念は許容範囲とする。

## 候補比較

| 候補 | 適性 | 長所 | 懸念 |
| --- | --- | --- | --- |
| Swift + SwiftUI + SpriteKit | 採用 | Mac ネイティブ、低遅延、Apple 標準、テストしやすい | 他 OS への移植性は低い |
| Swift + AppKit + SpriteKit | 適 | 入力やウィンドウ制御を細かく扱える | UI 実装量が増える |
| Swift + Metal | 過剰 | 最高性能の描画が可能 | Tetris には低レベルすぎる |
| Cocos Creator / Cocos2d-x | 条件付きで適 | 2D ゲーム制作機能が豊富、クロスプラットフォームを狙える | Swift 中心の Mac ネイティブ設計とは距離がある |
| Tauri | 条件付きで適 | 軽量な `.app`、Web 技術を使える、将来クロスプラットフォーム化しやすい | WebView 越しの入力/描画設計が必要 |
| Electron | 非推奨 | Web 技術で高速開発できる、実績が多い | アプリサイズとメモリ負荷が大きくなりやすい |
| Godot | 条件付きで適 | ゲーム制作機能が豊富、macOS 書き出し可能 | テトリスのロジックテストやネイティブ UI 連携は別設計が必要 |

## 採用方針

### 採用する

- Swift
- SwiftUI
- SpriteKit
- XCTest
- JSON または UserDefaults によるローカル保存
- Xcode プロジェクトまたは Swift Package を含む構成

### 初期実装では採用しない

- Electron
- WebView 前提のゲーム実装
- Metal 直接描画
- Cocos Creator / Cocos2d-x
- Unity / Unreal Engine
- オンライン対戦用サーバー
- 外部データベース

Cocos 系は 2D ゲームエンジンとして有力な候補だが、本プロジェクトでは Swift 実装、XCTest によるロジック検証、macOS ネイティブ UI との統合を優先するため採用しない。

## アーキテクチャ要件

### レイヤー分離

ゲームロジック、描画、入力、永続化を分離する。

```text
App Shell
  SwiftUI / macOS lifecycle

Presentation
  SwiftUI screens
  SpriteKit scene

Application
  Game loop
  Input mapping
  Mode controller

Domain
  Board
  Piece
  Rotation
  Randomizer
  T-Spin detection
  Scoring
  Garbage calculation

Infrastructure
  Records storage
  Settings storage
```

### Domain

- Swift の純粋な struct / enum / class で構成する。
- SpriteKit、SwiftUI、AppKit に依存しない。
- 単体テストで盤面・ミノ・回転・ロック処理を検証できる。

### Presentation

- SpriteKit はプレイ中のフィールド描画、ミノ描画、エフェクトを担当する。
- SwiftUI はメニュー、設定、リザルト、ランキング、モード選択を担当する。
- Presentation は Domain の状態を読み取り、入力イベントを Application に渡す。

### Application

- ゲームループを管理する。
- 入力をゲームアクションへ変換する。
- モードごとの終了条件、記録更新、ポーズ状態を制御する。

## 操作応答性要件

- 入力イベントは可能な限り発生直後に収集する。
- 1 フレーム内の処理順序は `input -> update -> render` とする。
- 左右移動、回転、ハードドロップ、Hold は次の更新ステップで反映する。
- エフェクト、サウンド、保存処理はゲーム入力をブロックしない。
- DAS、ARR、SDF は設定可能にする。
- キーリピートは OS のキーリピートに依存せず、ゲーム側で制御する。

目標値:

| 項目 | 目標 |
| --- | --- |
| 描画 | 60 FPS |
| 入力反映 | 次フレーム以内 |
| 起動 | ローカル環境で数秒以内 |
| 1 人用プレイ | オフラインで開始可能 |

## Mac アプリ要件

- macOS の `.app` bundle としてビルドできる。
- Finder、Dock、Launchpad から起動できる。
- アプリ起動時にゲーム画面へキーボードフォーカスを渡せる。
- フルスクリーン表示に対応する。
- アプリ非アクティブ化時の自動ポーズを設定できる。
- ローカル記録とキー設定をアプリ終了時に保存できる。
- Apple Silicon と Intel Mac の両方を見据え、Universal build を検討する。

## データ保存要件

初期実装ではローカル保存のみとする。

保存対象:

- キー設定
- DAS / ARR / SDF
- 音量や表示設定
- モード別ベストスコア
- 40 Lines ベストタイム
- T-Spin 回数
- 最大 REN
- 最大 Back-to-Back

保存形式:

- 小さな設定値は UserDefaults。
- 記録やプリセットは JSON file。
- 保存データはバージョン番号を持つ。

## テスト要件

XCTest で Domain 層を重点的に検証する。

必須テスト:

- 7-bag randomizer
- Board collision
- Line clear
- Hold restriction
- SRS wall kick
- T-Spin 3-corner detection
- T-Spin Double scoring
- Back-to-Back update
- Combo update
- Garbage attack calculation
- 40 Lines completion

UI テストは初期段階では最小限にし、重要な起動確認とモード開始確認を対象にする。

## ビルド/開発要件

- Xcode で開発できる。
- `xcodebuild` による CLI ビルドを可能にする。
- テストは CLI から実行できる。
- CI を導入する場合は macOS runner を使用する。
- リリース候補では `.app` を生成する。

## 参考資料

- Apple SwiftUI: https://developer.apple.com/swiftui/
- Apple macOS development: https://developer.apple.com/macos/get-started/
- Apple SpriteKit: https://developer.apple.com/documentation/spritekit
- Apple Game Controller: https://developer.apple.com/documentation/gamecontroller/
- Apple Metal: https://developer.apple.com/metal/
- Tauri macOS application bundle: https://v2.tauri.app/distribute/macos-application-bundle/
- Electron: https://electronjs.org/
- Godot macOS export: https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_macos.html
