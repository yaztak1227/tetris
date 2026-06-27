# Tetris Project Agent Instructions

## Communication

- 日本語で話すときは、フレンドリーでやわらかく、落ち着いた丁寧さを保つ。
- 技術的な説明では、結論、理由、次の行動をわかりやすく伝える。

## Project Goal

Mac ネイティブの Swift + SwiftUI + SpriteKit 製 Tetris アプリを作る。
Tetris Online Poland / Tetris Online Japan 系の操作感に寄せ、SRS、Hold、Next、T-Spin、Back-to-Back、REN、Lock Delay を重視する。

## ECC Loading

This project uses a project-local subset of Everything Claude Code (ECC).

- Project instructions are loaded from this `AGENTS.md`.
- Codex project settings are loaded from `.codex/config.toml`.
- Codex agent roles are loaded from `.codex/agents/`.
- ECC skills are loaded from direct children of `.agents/skills/`.
- Do not nest skills under `.agents/skills/ecc/`; each skill directory must be a direct child.
- Do not also run the full ECC global installer for this project unless the user explicitly asks for a machine-wide install.
- Do not enable ECC global hooks or MCP servers unless the user explicitly asks for them.

Enabled ECC skill subset:

- `coding-standards`
- `tdd-workflow`
- `verification-loop`
- `security-review`
- `swiftui-patterns`
- `swift-protocol-di-testing`
- `swift-concurrency-6-2`
- `swift-actor-persistence`
- `hexagonal-architecture`
- `error-handling`
- `git-workflow`
- `architecture-decision-records`
- `design-system`
- `ios-icon-gen`

## Engineering Workflow

- Plan before implementing substantial changes.
- Prefer TDD for production code: write or update tests first, confirm RED where practical, then implement, then refactor.
- Keep game logic independent from SpriteKit and SwiftUI so it can be tested directly.
- Use hexagonal/ports-and-adapters style boundaries where useful: Domain/Core inward, SpriteKit/SwiftUI/storage outward.
- Use many focused files rather than large mixed-responsibility files.
- Prefer Swift value types for domain models. Use classes only where identity, reference semantics, or framework integration requires them.
- Prefer `let` over `var`.
- Use clear names and small functions.

## Swift/SpriteKit Guidance

- Domain layer must not depend on SpriteKit, SwiftUI, or AppKit.
- SpriteKit owns playfield rendering, block layers, ghost piece, and lightweight effects.
- SwiftUI owns menus, settings, records, result screens, and app chrome.
- Tetris rules such as SRS, Lock Delay, T-Spin detection, scoring, REN, and B2B belong in testable core logic.
- Input handling must prioritize responsiveness over animation or persistence work.

## Verification

- Before marking implementation work complete, run the most relevant project-native tests.
- Before committing, inspect staged changes for personal information, local absolute paths, credentials, tokens, and other secrets.
- When Xcode project files exist, prefer `xcodebuild test` or the repository's documented test command.
- Core logic tests should cover 7-bag, collision, line clear, Hold, SRS, Lock Delay, T-Spin, scoring, REN, and B2B.
- When changing gameplay UI, SpriteKit rendering, input handling, settings, localization, rotation, pause, or game-loop timing, read `docs/manual-playtest.md` and `docs/gameplay-implementation-notes.md`, then verify the relevant player stories manually in addition to automated tests.
- Security-sensitive changes require checking for hardcoded secrets and unsafe external input handling.
- Record important architecture choices as ADRs under `docs/adr/` when the user agrees or explicitly asks.

## Codebase Knowledge Graph

If codebase-memory-mcp is available for this project, prefer its graph tools for code discovery:

1. `search_graph`
2. `trace_path`
3. `get_code_snippet`
4. `query_graph`
5. `get_architecture`

Fall back to `rg`/file reads when the graph is unavailable, incomplete, or when searching docs/config/string literals.
