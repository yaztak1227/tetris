# Basic Design

## 目的

要件定義と技術要件をもとに、SpriteKit + SwiftUI で実装するための基本設計を定義する。操作感は Tetris Online Poland / Tetris Online Japan 系の現代的なプレイ感に寄せ、SRS、Hold、Next、T-Spin、Back-to-Back、REN、ロック遅延を基本機能として扱う。

## 基本方針

- 初期実装は macOS ネイティブの 1 人用アプリとする。
- プレイ画面は SpriteKit、メニュー・設定・記録画面は SwiftUI で構成する。
- Domain 層は Swift の純粋な型で実装し、SpriteKit や SwiftUI に依存させない。
- TOP/TOJ 風の操作感を重視し、接地後も短時間は移動・回転で調整できるようにする。
- 高速プレイで入力が抜けないよう、入力処理は描画や演出より優先する。

## アプリ構成

```text
TetrisApp
  AppLifecycle
  RootView
  ModeSelectView
  GameView
    SpriteKit GameScene
  ResultView
  SettingsView
  RecordsView

Core
  GameEngine
  GameState
  Board
  Piece
  RotationSystem
  Randomizer
  LockController
  Scoring
  GarbageCalculator
  RecordsStore
  SettingsStore
```

## ゲーム状態

```text
GameStatus
  booting
  title
  modeSelect
  ready
  playing
  paused
  lineClear
  gameOver
  completed
  result
```

```text
GameState
  status
  mode
  board
  activePiece
  holdPiece
  holdUsed
  nextQueue
  gravity
  lock
  score
  level
  totalClearedLines
  combo
  backToBack
  elapsedTime
  lastAction
  lastClearEvent
```

## ゲーム進行

### 起動からプレイ開始

1. macOS アプリとして起動する。
2. 設定とローカル記録を読み込む。
3. 前回モードまたはモード選択画面を表示する。
4. モードを選択する。
5. 盤面、ミノ列、スコア、タイマーを初期化する。
6. 最初のミノをスポーンし、プレイ状態に入る。

### 1 フレームの処理

1. 入力イベントを収集する。
2. DAS/ARR/SDF を考慮してゲームアクションへ変換する。
3. 移動、回転、Hold、Hard Drop を適用する。
4. 経過時間に応じて自然落下を適用する。
5. 接地状態とロック遅延を更新する。
6. ロック条件を満たした場合、ミノを固定する。
7. T-Spin 判定を行う。
8. ライン消去を行う。
9. スコア、REN、Back-to-Back、攻撃量を更新する。
10. 次ミノをスポーンする。
11. SpriteKit へ表示状態を渡す。

## レベルと落下速度

ライン消去数に応じてレベルを上げる。基本は 10 ラインごとに 1 レベル上昇とする。

```text
level = floor(totalClearedLines / 10) + 1
```

推奨 gravity interval:

| Level | 自然落下間隔 |
| ---: | ---: |
| 1 | 1000 ms |
| 2 | 900 ms |
| 3 | 800 ms |
| 4 | 700 ms |
| 5 | 600 ms |
| 6 | 500 ms |
| 7 | 400 ms |
| 8 | 300 ms |
| 9 | 220 ms |
| 10 | 160 ms |
| 11+ | 120 ms から段階的に短縮 |

Marathon ではレベル上昇を有効にする。40 Lines では TOP 系の高速練習感に寄せるため、固定速度または開始速度を設定可能にする。

## 接地とロック遅延

ミノが下方向へ移動できない状態を接地とする。接地した瞬間には固定せず、ロック遅延を開始する。

推奨値:

| 項目 | 値 |
| --- | ---: |
| Lock Delay | 500 ms |
| Lock Delay Reset 上限 | 15 回 |
| 接地解除 | ミノが 1 マス以上浮いた場合 |
| Hard Drop | 遅延なしで即時固定 |

### ロック遅延の更新

```text
if activePiece can move down:
  grounded = false
  lockElapsed = 0
else:
  grounded = true
  lockElapsed += deltaTime

if grounded and successful move/rotate:
  if resetCount < maxResetCount:
    lockElapsed = 0
    resetCount += 1

if hardDrop or lockElapsed >= lockDelay or resetCount >= maxResetCount and still grounded:
  lock piece
```

### 接地後の移動/回転

- 接地後も左右移動、回転、180 度回転を受け付ける。
- 成功した移動/回転はロック遅延をリセットできる。
- SRS キックにより、床・壁・固定ブロックに接した状態でも回転可能にする。
- ロック遅延のリセット回数が上限に達した後は、成功操作があっても固定を先延ばししない。
- Hard Drop は常に即時固定し、T-Spin 判定では最後の成功操作が回転である場合のみ T-Spin を認める。

## 入力設計

初期キー割り当て:

| 操作 | キー |
| --- | --- |
| 左移動 | Left |
| 右移動 | Right |
| ソフトドロップ | Down |
| ハードドロップ | Space |
| 右回転 | Up / X |
| 左回転 | Z |
| 180 度回転 | A |
| Hold | Shift / C |
| Pause | Esc |
| Restart | R |

設定値:

| 項目 | 初期値 |
| --- | ---: |
| DAS | 120 ms |
| ARR | 16 ms |
| SDF | 20x |
| Next 表示数 | 5 |

OS のキーリピートには依存せず、ゲーム側で DAS/ARR を制御する。

## ミノ生成

- 7-bag を採用する。
- 1 袋に I, O, T, S, Z, J, L を 1 個ずつ含める。
- 袋をシャッフルして Next キューへ追加する。
- Next キューは常に表示数 + 1 個以上を維持する。
- Practice では固定シード、固定ミノ列、盤面プリセットを使えるようにする。

## Hold

- 1 ミノにつき 1 回だけ Hold できる。
- Hold 後は `holdUsed = true` にする。
- ミノがロックされ、次ミノがスポーンしたら `holdUsed = false` に戻す。
- Hold ミノはスポーン位置・初期回転で再登場する。

## 回転

- SRS 相当の回転システムを採用する。
- 回転成功時は `lastAction = rotate` とし、回転方向、使用キック、回転前後を記録する。
- 回転失敗時は `lastAction` を更新しない。
- T-Spin 判定は最後に成功した操作が T ミノの回転であることを条件にする。
- 180 度回転は入力として用意し、キックテーブルは設定可能にする。

## T-Spin

T ミノがロックされた時点で以下を満たす場合、T-Spin とする。

- 現在ミノが T である。
- 最後に成功した操作が回転である。
- T ミノ中心の四隅のうち 3 箇所以上が、固定ブロックまたはフィールド外で埋まっている。

ライン消去数により以下へ分類する。

| 消去ライン | 表示 |
| ---: | --- |
| 0 | T-SPIN |
| 1 | T-SPIN SINGLE |
| 2 | T-SPIN DOUBLE |
| 3 | T-SPIN TRIPLE |

Mini 判定は初期実装では任意とし、後から切り替えられるようにする。

## ライン消去とスコア

ロック後、埋まったラインを検出して消去する。複数ラインは同時消去として扱う。

スコア計算は以下を入力にする。

- 消去ライン数
- T-Spin 種別
- Back-to-Back 状態
- REN 数
- Soft Drop / Hard Drop の落下セル数
- 現在レベル

レベル倍率は初期実装では `scoreDelta * level` とする。

## REN / Combo

- 1 ライン以上消去したロックが連続した場合、REN を増やす。
- ライン消去がないロックで REN を -1 または 0 にリセットする。表示上は 1 以上から出す。
- REN はスコアと将来のガベージ攻撃量に反映する。

## Back-to-Back

B2B 対象:

- Tetris
- T-Spin Single
- T-Spin Double
- T-Spin Triple

B2B 対象のライン消去が連続した場合、B2B を継続する。Single / Double / Triple など B2B 対象外のライン消去を行った場合は B2B を解除する。

## モード別基本設計

### Marathon

- 消去ライン数に応じてレベルと自然落下速度が上がる。
- ゲームオーバーまで継続する。
- スコア、ライン数、レベル、T-Spin 回数、最大 REN を記録する。

### 40 Lines

- 40 ライン消去までのタイムを競う。
- レベル上昇は使わず、開始速度と入力設定を重視する。
- 完了時にベストタイムを更新する。

### Challenge / Score Attack

- 制限時間内のスコアを競う。
- レベル上昇あり。
- スコア、T-Spin 回数、最大 REN、B2B 継続数を記録する。

### Practice

- 重力、Lock Delay、ミノ列、盤面プリセットを変更できる。
- T-Spin 練習プリセットを提供する。
- 記録更新より再現性と反復を優先する。

## 永続化

保存対象:

- キー設定
- DAS / ARR / SDF
- Lock Delay
- Next 表示数
- モード別記録
- Practice プリセット

設定は UserDefaults、記録やプリセットは JSON file とする。

## テスト観点

- レベルが 10 ラインごとに上がる。
- レベル上昇で自然落下間隔が短くなる。
- 接地直後に即ロックされない。
- 接地中の左右移動成功で Lock Delay がリセットされる。
- 接地中の回転成功で Lock Delay がリセットされる。
- Lock Delay Reset 上限に達すると固定される。
- Hard Drop は Lock Delay を無視して即固定する。
- SRS キックで床際・壁際回転が成立する。
- T-Spin Double が検出される。
- B2B と REN が正しく更新される。
