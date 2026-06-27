# Gameplay Implementation Notes

## Purpose

This note records player-facing implementation decisions so another Codex thread can continue from the same assumptions.

The project targets a Mac native Swift + SwiftUI + SpriteKit Tetris app with a Tetris Online Poland / Tetris Online Japan style feel.

## Screen Flow

- The app launches to Home, not directly into the playfield.
- No active piece, ghost piece, or Next queue is generated before Start.
- Start creates the randomizer, active piece, and Next queue.
- Pressing Start or Return after the game has already started must not reset the board.
- Settings is a dedicated screen, not an inline panel inside the playfield.
- Settings can be opened from Home.
- During play, Settings is reached from the Pause menu. The game remains paused while Settings is open.
- Back from Settings returns to Home if opened from Home, or to the paused game if opened from Pause.
- Esc pauses during play and resumes from the pause overlay.

## Localization

- Localization files live under `Sources/TetrisApp/Resources/Localizations/`.
- Current files:
  - `en.json`
  - `ja.json`
- Keys use a `screen/feature/name` style:
  - `home/buttons/start`
  - `settings/tuning/gravity`
  - `settings/tuning/horizontalDelay`
  - `game/labels/score`
- `AppLocalizer` loads the selected language from the SwiftPM resource bundle and falls back to English before returning the raw key.
- The language selection is controlled in Settings and persisted with `@AppStorage("app.language")`.

## Horizontal Movement

Horizontal movement is modeled as held input state, not only as OS key repeat.

- A fresh Left or Right press moves once immediately.
- Holding Left or Right then uses two settings:
  - `horizontalAutoShiftDelayMilliseconds`: DAS-like delay before hold movement starts.
  - `horizontalAutoRepeatIntervalMilliseconds`: ARR-like interval between repeated horizontal moves.
- Rotation, Hold, Soft Drop, Hard Drop, Pause, and other inputs must not cancel the active horizontal hold.
- Releasing the currently held horizontal direction clears only that direction's hold timing.
- Pressing the opposite horizontal direction resets the horizontal hold timing and moves once immediately.

The Settings screen exposes:

- `MOVE HOLD`: multiplier retained for compatibility with older repeat-step code.
- `DAS DELAY` / `長押し判定`: lower values make the app recognize hold sooner.
- `MOVE INTERVAL` / `横移動間隔`: lower values make held horizontal movement faster.
- Tuning values and key bindings are persisted in `UserDefaults` through `UserDefaultsGameSettingsStore`.

## Score Feedback and Sound

- Score gains are shown in the right dashboard Score panel as a temporary `+N` value.
- Score gains are not shown as a central playfield popup and are not shown as raw `+N` text in the bottom event bar.
- Hard drops, line clears, and level-ups play lightweight AppKit system sounds.
- Level affects gravity in addition to the settings gravity multiplier; higher levels reduce the fall interval.

## Rotation

Rotation is handled in the testable `TetrisCore` domain layer.

- I piece keeps SRS-style kicks because its rotation center and feel require special handling.
- Non-I pieces prioritize in-place rotation.
- Non-I pieces can use normal SRS wall kicks while airborne when in-place rotation is blocked by the playfield edge or blocks.
- Grounded pieces also use normal SRS kicks.
- T pieces get an extra grounded nearby-fit search within one cell after regular SRS kicks fail. This supports T-Spin-style slots where the piece can rotate into a nearby cavity.
- ViewModel no longer adds an extra manual left/right movement after rotation. The rotation system owns all rotation displacement.

## SpriteKit Rendering

- `TetrisScene` is stored as `@State` so SwiftUI does not recreate the scene unexpectedly.
- The SpriteKit view requests a render on appear to avoid a blank or gray board during screen transitions.
- Scene rendering hides active, ghost, and Next gameplay state before Start.

## Manual Regression Stories

Use these stories before calling gameplay/input/UI work complete:

- Launch, wait, and confirm no piece or Next queue appears before Start.
- Open Settings from Home, switch language, and return to Home without starting a game.
- Press Return from Home and confirm a piece and Next queue are generated only then.
- Press Return again during play and confirm the game does not reset.
- Hold Left or Right, rotate repeatedly, and confirm horizontal movement continues.
- Tune DAS Delay and Move Interval in Settings and confirm held horizontal movement changes speed.
- Relaunch after changing Settings and confirm tuning and key bindings persist.
- Press Esc during play, open Settings, then Back, and confirm the pause overlay and board return correctly.
- Hard Drop and line clear while confirming score gains stay inside the Score panel.
- Reach a higher level or start from a higher-level test state and confirm gravity is faster.
- Rotate non-I pieces in open air and confirm they rotate in place when unobstructed.
- Rotate non-I pieces near the left and right edges and confirm legal SRS wall kicks keep rotation responsive.
- Rotate grounded pieces near blocks and confirm wall/ground kick behavior remains possible.
- Build and test with:

```bash
swift build
swift test
```
