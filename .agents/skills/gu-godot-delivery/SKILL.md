---
name: gu-godot-delivery
description: Deliver cross-cutting Godot 4.7.2 changes for Gu Lu Qiu Sheng while preserving its data-driven, deterministic domain boundary and validating real presentation output.
---

# Gu Godot Delivery

Use this skill for cross-cutting work in this repository that spans Godot runtime setup, domain and presentation boundaries, release/debug separation, or end-to-end verification. For a focused change, also use the more specific skill when it applies:

- `gu-domain-change` for `scripts/domain/` rules or new gameplay commands.
- `gu-ui-flow-verify` for `ui/`, `scenes/`, `assets/theme/`, or `scripts/presentation/` work.
- `gu-data-content` for `data/*.json` content and schema changes.

## Read The Current Authority

Before changing behavior, read `AGENTS.md`, `docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`, and the closest code, tests, and data records. The current repository state and the user's latest instruction override older design documents and external prompt material.

Treat the external Godot prompt that originated this skill as historical guidance only. In particular, do not reintroduce its outdated engine target, dark-theme direction, CSV requirement, fixed 1280x720 layout, or its restriction against exercising engineering judgment.

## Project Shape

- Target Godot 4.7.2 with GDScript. Run Godot through `tools/godot.ps1`; use `--headless` for automated checks. Do not leave a GUI Godot process running while tests need the project lock.
- Keep game rules in pure, testable domain code. Presentation renders snapshots and submits commands through the existing controller/command boundary; it never mutates run state, catalog data, persistence, RNG, or results directly.
- Treat the current `RunState` as the per-run owner even where specifications use the intended name `RunData`. Preserve immutable event-log history, command-version replay protection, seeded rolls, and the rule precedence chain: contracts, per-run meta rules, DDA, gu effects, enemy AI.
- Keep player-facing costs and lethal risks explicit before the command mutates state. Ending text and player knowledge must be derived from structured events and known facts, not presentation guesses.
- Maintain data-driven content. JSON IDs, code identifiers, test names, and commits are ASCII; player-facing Chinese may be UTF-8. Route new fields and cross-table constraints through `ContentCatalog` validation and tests.

## Presentation And UI

- Edit `.guitkx` source files, not generated `ui/**/*.gd`. The RUI toolkit compiles headlessly; its generated siblings remain ignored output.
- Follow the active Wen Zhen visual tokens in `scripts/presentation/gu_style.gd`: paper and ink surfaces, hairline rules, restrained 4px radii, cinnabar danger, jade recovery, blue contracts, and yellow DDA anomalies. Do not revive the retired dark UI by using compatibility aliases in new work.
- Work with the existing RUI component hierarchy and snapshot data. Use containers and responsive constraints for layout; do not create presentation-owned gameplay state or force UI shapes through positional hacks.
- Verify visual changes with the repository's real capture path, not a hypothetical Godot MCP. `scripts/smoke_render.gd` covers headless RUI compilation and component mounting. `scripts/ui_capture.gd` produces real-renderer capture evidence under `.superpowers/ui_captures/wenzhen/`.
- For each changed flow, preserve information transparency: numeric enemy intentions; separate health and shield; confirmation plus preflight for dangerous actions; visible shop limits/inflation; distinct contract and anomaly areas; no undo/reload path; unified ending route.

## Delivery Loop

1. State the invariant and inspect the closest tests before editing. Add the smallest test or executable acceptance check that can fail for the requested behavior.
2. Make the narrowest change consistent with the existing module boundary. Do not alter `vendor/` or read-only corpus/design-data directories unless the user explicitly asks.
3. Run the focused test with `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test <test-path>`, then the affected suite. Run `powershell -ExecutionPolicy Bypass -File tools/check.ps1` for shared boundaries, lifecycle/persistence, catalogs, controllers, navigation, or broad changes.
4. For `.guitkx` or visual work, run `scripts/smoke_render.gd` through `tools/godot.ps1` when applicable, then run the relevant `scripts/ui_capture.gd` batch and inspect captures at the requested viewport sizes. Check containment, clipping, overlap, focus/disabled states, and danger feedback.
5. Finish with `git diff --check` and `git diff --ignore-cr-at-eol`. This worktree can show widespread autocrlf-only modifications; preserve user changes and distinguish real content edits from line-ending noise before reporting scope.

## Release Boundary

Developer tools are development-build only. A release build must not merely hide a debug panel: it must exclude debug commands and shortcuts. Debug actions may mutate only the current run via normal validation and must leave an auditable event. Do not use debug shortcuts as evidence for balance or ordinary player flow.
