# ECC Adoption

## Source

This project uses a small project-local subset of Everything Claude Code (ECC):

- Repository: https://github.com/affaan-m/ECC
- Checked source path during setup: `/tmp/everything-claude-code`
- License: MIT

## Loading Method

The project uses Codex project-local loading instead of a global ECC install.

- `AGENTS.md` provides project instructions.
- `.codex/config.toml` enables project-local Codex agent roles.
- `.codex/agents/*.toml` provides read-only explorer, reviewer, and docs researcher role configs.
- `.agents/skills/<skill>/SKILL.md` provides directly loadable Codex skills.

Important constraints:

- Skills must be direct children of `.agents/skills/`.
- Skills are not nested under `.agents/skills/ecc/`.
- The full ECC sync script was not applied to `~/.codex`.
- ECC global git hooks were not enabled.
- ECC MCP servers were not enabled.
- The Codex plugin marketplace path was not used because ECC documents current plugin-mode skill loading as fragile for repo marketplaces.

## Enabled Skill Subset

The enabled subset is intentionally focused on this Swift/SpriteKit project:

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

## Implementation Skill Additions

The implementation-focused additions support the next phase of the project:

- `hexagonal-architecture`: keep Tetris rules independent from SpriteKit, SwiftUI, storage, and app lifecycle code.
- `error-handling`: define robust typed errors and user-facing failure behavior.
- `git-workflow`: support commit and branch hygiene once implementation begins.
- `architecture-decision-records`: capture major decisions such as SpriteKit adoption or architecture changes.
- `design-system`: guide visual consistency for menus, settings, result screens, and game UI polish.
- `ios-icon-gen`: generate Apple/Xcode-compatible icon assets when app assets are needed.

## Why Not Full Install

The full ECC repository includes many hooks, prompts, MCP definitions, agents, commands, skills, and cross-harness integrations. This Tetris project currently needs only local guidance for Swift, SwiftUI, TDD, verification, and review. Keeping the install project-local avoids duplicate global behavior and keeps the repository easy to reason about.
