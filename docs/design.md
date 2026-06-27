# Tetris Design

## 設計方針

実装はゲームロジックと表示/UI を分離する。T-Spin、SRS、スコア、ガベージ計算は描画に依存しない純粋なロジックとして扱い、単体テストで検証できる構造にする。

プレイ画面の 2D 描画は SpriteKit を採用し、メニュー、設定、記録画面などのアプリ UI は SwiftUI で構成する。

初期リリースではローカル 1 人用を完成させる。対戦機能は後続フェーズで追加できるよう、ライン消去結果から攻撃量を算出するイベントモデルを先に定義しておく。

## モジュール構成

```text
src/
  app/
    mac-shell
    app-lifecycle
  core/
    board
    pieces
    randomizer
    rotation
    game-state
    scoring
    garbage
  modes/
    marathon
    time-attack
    challenge
    practice
    vs-com
  ui/
    renderer
    input
    screens
    effects
  storage/
    records
```

## コア責務

### app

- macOS ネイティブアプリとしての起動、ウィンドウ生成、アプリライフサイクルを担当する。
- Finder、Dock、Launchpad から `.app` として起動できる配布形態を提供する。
- ゲームロジックには直接依存せず、UI と `game-state` を接続する外枠として扱う。
- オフラインでも 1 人用モードを開始できるよう、初期画面と必要アセットをアプリ内に同梱する。

### board

- 固定ブロックの 2D グリッドを管理する。
- 衝突判定、ライン消去、スポーン可否判定を提供する。
- 表示領域 10x20 と、スポーン用の上部非表示行を区別する。

### pieces

- 7 種類のテトリミノ定義を持つ。
- 各ミノは種類、回転状態、中心座標、構成セルを持つ。
- T-Spin 判定のため、T ミノ中心と四隅の座標を取得できるようにする。

### randomizer

- 7-bag 方式でミノ列を生成する。
- Next キューが指定数を下回らないよう補充する。
- Practice 用に固定シードまたは固定ミノ列を扱えるようにする。

### rotation

- SRS 相当の回転とキックテーブルを担当する。
- 回転成功時に、使用したキック、回転前後の状態、対象ミノを `lastAction` に記録する。
- 180 度回転は別テーブルを持てる設計にする。初期実装で正式対応しない場合も、入力とイベント型は予約する。

### game-state

- 現在ミノ、Hold、Next、盤面、スコア、コンボ、B2B、経過時間、ゲーム状態を保持する。
- 入力を受け取り、ゲーム状態を 1 ステップ進める。
- ロック、ライン消去、スコア計算、イベント発火の順序を制御する。

### scoring

- ライン消去結果と T-Spin 判定結果からスコアを計算する。
- B2B とコンボの状態更新を担当する。
- スコア値は設定として差し替え可能にする。

### garbage

- 対戦・VS COM 用の攻撃量を算出する。
- 受信ガベージキュー、相殺、穴位置生成を扱う。
- 初期の 1 人用では未使用でも、ライン消去イベントから呼べる形にしておく。

## 状態モデル

```text
GameState
  status: ready | playing | paused | gameOver | completed
  board: Board
  activePiece: Piece
  holdPiece: Piece | null
  holdUsed: boolean
  nextQueue: PieceType[]
  score: number
  level: number
  lines: number
  combo: number
  backToBack: boolean
  lastAction: ActionRecord | null
  lastEvent: ClearEvent | null
  modeState: ModeState
```

```text
ActionRecord
  type: move | softDrop | hardDrop | rotate | hold | lock
  pieceType: I | O | T | S | Z | J | L
  rotationFrom?: 0 | 1 | 2 | 3
  rotationTo?: 0 | 1 | 2 | 3
  kickIndex?: number
  succeeded: boolean
```

```text
ClearEvent
  clearedLines: 0 | 1 | 2 | 3 | 4
  spin: none | tSpin | tSpinMini
  clearName:
    none
    single
    double
    triple
    tetris
    tSpinNoLine
    tSpinSingle
    tSpinDouble
    tSpinTriple
    tSpinMini
    tSpinMiniSingle
    tSpinMiniDouble
  scoreDelta: number
  attack: number
  combo: number
  backToBack: boolean
```

## メインループ

1. 入力を収集する。
2. 入力をゲームアクションへ変換する。
3. アクションを `GameState` に適用する。
4. 重力による落下を進める。
5. ロック条件を満たした場合、現在ミノを盤面に固定する。
6. ライン消去を判定する。
7. T-Spin を判定する。
8. スコア、コンボ、B2B、攻撃量を更新する。
9. 次のミノをスポーンする。
10. UI 表示用のイベントを発行する。

## T-Spin 判定設計

T-Spin 判定は `detectSpin(board, piece, lastAction)` として実装する想定にする。

### 入力

- 固定済み盤面
- ロック直前の T ミノ
- 最後に成功したアクション

### 判定手順

1. ミノ種別が T でない場合は `none`。
2. `lastAction.type` が `rotate` でない場合は `none`。
3. T ミノ中心の対角四隅を取得する。
4. 四隅のうち、フィールド外または固定ブロックで埋まっている数を数える。
5. 埋まり数が 3 未満なら `none`。
6. Mini 判定を有効にしている場合は、正面角とキック情報から `tSpinMini` を返す。
7. それ以外は `tSpin`。

### 四隅の例

T ミノ中心を `(cx, cy)` とする。

```text
(cx - 1, cy - 1)  (cx + 1, cy - 1)
(cx - 1, cy + 1)  (cx + 1, cy + 1)
```

フィールド上端より上の非表示行は、盤面内として扱う。左右端・下端の外側は埋まりとして扱う。

## ロック処理の順序

T-Spin はロック時の盤面状態に依存するため、以下の順序を固定する。

1. 現在ミノを固定済み盤面へ反映する。
2. 固定後の盤面を使って T-Spin を判定する。
3. ライン消去候補を検出する。
4. `spin` と `clearedLines` から `clearName` を決定する。
5. スコアと攻撃量を計算する。
6. ラインを消去する。
7. 次ミノをスポーンする。

## スコア設計

`scoring` は以下を入力として受け取る。

```text
ScoreInput
  spin: none | tSpin | tSpinMini
  clearedLines: number
  hardDropCells: number
  softDropCells: number
  previousCombo: number
  previousBackToBack: boolean
```

出力は以下とする。

```text
ScoreResult
  clearName: ClearEvent.clearName
  scoreDelta: number
  nextCombo: number
  nextBackToBack: boolean
  backToBackBonusApplied: boolean
```

B2B 対象は Tetris、T-Spin Single、T-Spin Double、T-Spin Triple とする。T-Spin No Line は表示対象だが、B2B 継続対象にするかは設定で切り替え可能にする。

## ガベージ設計

`garbage` は `ClearEvent` から攻撃量を計算する。

```text
GarbageResult
  outgoingAttack: number
  canceledIncoming: number
  remainingIncoming: number
```

将来的な Multi では、ローカルの `ClearEvent` をネットワークイベントに変換し、相手側の `incomingGarbageQueue` に積む。

## モード設計

### Marathon

- `lines` と `score` を主指標にする。
- 一定ラインごとに `level` を上げる。
- `level` に応じて gravity interval を短くする。

### Time Attack / 40 Lines

- 40 ライン到達時に `completed` にする。
- スコアよりタイムを主指標にする。
- リスタートを高速に行える UI を用意する。

### Challenge

- 制限時間を持つ。
- タイムアップで `completed` にする。
- スコア、T-Spin 回数、最大 REN を記録する。

### Practice

- 重力、ミノ列、盤面プリセットを設定できる。
- T-Spin 練習プリセットを読み込める。
- 記録更新より反復練習を優先する。

### VS COM

- COM は盤面評価により置き場所を選ぶ。
- 初期 COM はシンプルな評価関数でよい。
- ガベージ送受信は Multi と同じ `garbage` モジュールを使う。

## UI 設計

画面はプレイに必要な情報を常時見える配置にする。

- 中央: メインフィールド
- 左: Hold、モード情報、操作補助
- 右: Next、スコア、ライン数、レベル、B2B、REN
- 下部またはオーバーレイ: 直近イベント表示
- メニュー: モード選択、キー設定、ランキング/記録

T-Spin や B2B はプレイヤーの手応えに直結するため、短いアニメーションまたは強調表示を行う。ただし視認性を妨げない。

## Mac アプリ設計

初期配布ターゲットは macOS とする。アプリは通常の `.app` として起動でき、Finder、Dock、Launchpad からプレイ画面へ遷移できることを前提にする。

### 起動

- アプリ起動時はローカルアセットを読み込み、モード選択または前回選択モードの開始画面を表示する。
- ネットワーク接続がない状態でも Marathon、40 Lines、Practice を開始できる。
- 起動直後にキーボードフォーカスをゲーム画面へ渡し、最初の入力を取りこぼさない。

### ウィンドウ

- macOS 標準の閉じる、最小化、フルスクリーンに対応する。
- リサイズ時もフィールド、Hold、Next、スコア表示の比率を保つ。
- フルスクリーン時は入力遅延を増やさない描画構成にする。

### ライフサイクル

- アプリ非アクティブ化時は自動ポーズできる設定を用意する。
- アプリ終了時はローカル記録と設定を保存する。
- クラッシュや強制終了後も、保存済み記録が破損しにくい形式にする。

## 入力設計

入力はキーイベントからゲームアクションへ変換する。

```text
InputBinding
  moveLeft
  moveRight
  softDrop
  hardDrop
  rotateCw
  rotateCcw
  rotate180
  hold
  pause
  restart
```

DAS/ARR は設定値として保持する。

- DAS: 左右移動の長押し開始までの遅延
- ARR: 長押し中の横移動間隔
- SDF: ソフトドロップ速度倍率

### 操作応答性

- キー入力は描画フレーム待ちに依存させず、入力イベントとして即時キューへ積む。
- ゲームループは 1 フレーム内で入力処理、状態更新、描画の順に実行する。
- 左右移動、回転、ハードドロップ、Hold は、入力を受け取った直後の更新ステップで反映する。
- エフェクト、サウンド、記録保存は入力処理をブロックしない。
- 入力設定はプレイヤーが調整でき、DAS/ARR/SDF の変更はプレイ前に反映される。

## 永続化設計

初期実装ではローカルストレージ相当へ保存する。

```text
Records
  mode
  bestScore
  bestTime
  bestLines
  maxCombo
  maxBackToBack
  tSpinCount
  tSpinDoubleCount
  updatedAt
```

オンライン化する場合も同じ記録モデルを API に送れるようにする。

## テスト方針

必須テスト:

- 7-bag が 1 袋内で 7 種類を重複なく生成する。
- Hold は 1 手 1 回だけ使える。
- ライン消去が正しく行われる。
- SRS キックで壁際回転が成立する。
- T ミノ以外では T-Spin にならない。
- 最後の成功アクションが回転でない場合は T-Spin にならない。
- T 中心四隅の 3 箇所が埋まると T-Spin になる。
- T-Spin Double が通常 Double より高いスコアになる。
- Tetris と T-Spin 系ライン消去で B2B が継続する。
- ライン消去なしでコンボがリセットされる。

## 開発フェーズ

### Phase 1: 仕様固定

- 要件定義
- 設計
- T-Spin 判定仕様の確定
- スコア/ガベージ表の確定

### Phase 2: コアロジック

- Board
- Piece
- 7-bag
- SRS
- Hold/Next
- Lock/Line clear
- T-Spin
- Scoring

### Phase 3: 1 人用 UI

- プレイ画面
- モード選択
- Marathon
- 40 Lines
- ローカル記録
- Mac アプリとしての起動

### Phase 4: 練習機能

- Practice
- ミノ列固定
- 盤面プリセット
- T-Spin 練習

### Phase 5: 対戦拡張

- VS COM
- ガベージ
- Multi 用イベント設計
- ルーム/観戦/ランキング設計
