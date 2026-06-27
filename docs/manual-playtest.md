# Manual Playtest Guide

## Purpose

This document records the expected player-facing flow for the Tetris app. Read this before changing gameplay UI, input handling, settings, pause behavior, SpriteKit rendering, or game-loop timing.

Automated tests protect core rules, but UI regressions can still happen when buttons, overlays, or SpriteKit rendering stop matching the state model. Use these scenarios as steering checks during development.

## Core Stories

### 1. Launch and Standby

Expected flow:

- The app opens to the Home screen.
- Status shows `STANDBY`.
- Time stays at `00:00`.
- No active piece, ghost piece, or predetermined Next queue is visible before Start.
- The randomizer, active piece, and Next queue are created only after Start.
- Start is available from Home.
- Settings opens as a dedicated screen, not as a panel inside the playfield layout.

Manual checks:

- Wait 3 seconds before pressing Start.
- Time must remain `00:00`.
- No active piece or Next queue should appear before Start.
- Pressing movement, rotation, Hold, or Hard Drop before Start must not change gameplay state.
- Press Settings, then Back, and confirm the app returns to Home without starting a game.

### 2. Start Game

Expected flow:

- Pressing Start from Home begins play.
- Status changes to `PLAY`.
- The Home screen is replaced by the play screen.
- The active piece and Next queue are generated at this point.
- The right dashboard shows Pause and Restart controls.
- Time starts increasing.
- The active piece remains visible while falling.
- The ghost piece appears after Start.
- Pressing Start again by keyboard during play must not reset the board, active piece, or Next queue.

Manual checks:

- Press Start and wait 2 seconds.
- Confirm the active piece has moved downward and is still visible.
- Confirm the timer advanced.
- Confirm the event bar shows `GO`.
- Press Return again and confirm the game does not reset or return to Home.

### 3. Basic Gameplay Input

Expected flow:

- Left / Right moves the active piece.
- Holding Left / Right moves once immediately, then repeats after the configured hold delay.
- Horizontal hold movement continues even when rotation, Hold, Soft Drop, Hard Drop, or Pause inputs are pressed.
- Down moves the active piece down.
- Space hard drops and locks the active piece.
- Up or X rotates clockwise.
- Z rotates counter-clockwise.
- C or Shift performs Hold once per piece.
- I piece uses SRS-style kicks.
- Non-I pieces rotate in place while airborne when possible, and can use SRS wall kicks near the screen edge when in-place rotation is blocked.
- Grounded pieces can still use kick movement near the floor, walls, and blocks.
- Grounded T pieces can use a nearby one-cell spin-fit when it creates a valid T-Spin style placement.

Manual checks:

- Move left and right after Start and confirm the active piece follows.
- Hold Left or Right, rotate repeatedly, and confirm horizontal movement continues.
- Rotate both directions and confirm the active piece remains visible.
- Rotate J/L/S/Z/T pieces in open air and confirm they rotate in place when unobstructed.
- Rotate J/L/S/Z/T pieces near the left and right edges and confirm legal SRS wall kicks keep rotation responsive.
- Rotate grounded pieces near the floor or blocks and confirm legal kicks still work.
- Press Shift and confirm Hold updates.
- Hard Drop and confirm a new active piece spawns.

### 4. Pause Flow

Expected flow:

- Pressing Esc during play opens a pause overlay.
- Status shows `PAUSE`.
- Time stops.
- Gravity, Lock Delay, and gameplay inputs stop.
- Resume closes the pause overlay and continues play.
- Restart resets to Standby.
- Settings can be opened from the pause menu.

Manual checks:

- Start the game, wait until the timer advances, then press Esc.
- Wait 3 seconds.
- Time must not advance while paused.
- The active piece must not fall while paused.
- Press Resume or Esc and confirm play continues.
- Press Settings from Pause and confirm a dedicated Settings screen opens.
- Press Back from Settings and confirm the Pause overlay is shown again.

### 5. Settings Flow

Expected flow:

- Settings opens as a dedicated screen from Home.
- During play, Settings is reachable through the Pause menu and the game remains paused while Settings is open.
- Language can be switched from Settings.
- Localized strings are loaded from `Sources/TetrisApp/Resources/Localizations/{language}.json`.
- Localization keys use a `screen/feature/name` style, such as `home/buttons/start` and `settings/tuning/gravity`.
- Move Hold multiplier can be set from `1.0x` to `2.0x`.
- Horizontal hold delay can be tuned in milliseconds.
- Horizontal repeat interval can be tuned in milliseconds.
- Gravity multiplier can be set from `1.0x` to `2.0x`.
- Tuning and key binding changes are saved and restored on the next launch.
- Key binding buttons enter a `Press...` capture state.
- Pressing a key assigns it to that action.
- Back returns to Home when Settings was opened from Home.
- Back returns to the paused game when Settings was opened from Pause.

Manual checks:

- Open Settings from Home and confirm no playfield or game controls are visible.
- Switch Language between English and Japanese and confirm Home, Settings, Pause, dashboard labels, key config labels, and event bar status text update.
- Set Horizontal Hold Delay lower and confirm held movement starts sooner.
- Set Horizontal Move Interval lower and confirm held movement repeats faster.
- Change Gravity to `2.0x`, Back, Start, and confirm falling is faster.
- Change Move Hold to `2.0x` and confirm horizontal repeat is faster.
- Rebind Pause, then restore it to Esc.
- Quit and relaunch the app, then confirm tuning and key bindings remain changed.

### 6. Clear Event Effects

Expected flow:

- Score gains appear only inside the Score panel as a temporary `+N` readout.
- Score gains do not cover the playfield and do not appear in the bottom event bar.
- Hard drops, line clears, and level-ups play lightweight sound effects.
- T-Spin, Tetris, B2B, and REN names can still appear in the bottom event bar.
- Falling speed increases as the level rises.

Manual checks:

- Use Hard Drop to play until a line clear occurs.
- Confirm the playfield is not covered by a score popup.
- Confirm the Score panel briefly shows the gained points.
- Confirm the bottom event bar does not show raw `+N` score text.
- Confirm falling becomes faster after reaching a higher level.

## Regression Watchlist

Check these whenever UI layout or game-loop code changes:

- Start must gate time and gravity.
- Active piece must be visible after Start.
- SpriteKit scene must rerender as the active piece falls.
- Button labels must fit inside their controls.
- Settings must not cover critical playfield information unless intentionally opened.
- Pause must freeze game time, gravity, and Lock Delay.
- Restart must return to Standby, not immediately start play.
- Hold and Score belong in the right dashboard.
- The app must remain playable with keyboard only.
- Return must start only from Home and must not reset an active game.
- Settings must be a dedicated route, not an inline panel inside the play screen.
- Language switching must not start, restart, pause, resume, or otherwise mutate gameplay state.

## Suggested Verification Commands

```bash
swift build
swift test
```

After these pass, run the app and perform the Launch, Start, Pause, Settings, and Basic Gameplay stories above.
