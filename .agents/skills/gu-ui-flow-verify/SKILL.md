---
name: gu-ui-flow-verify
description: Build, modify, or verify Gu Lu Qiu Sheng Godot/RUI presentation flows while keeping UI as a command boundary and enforcing the game's information transparency and irreversible-run rules.
---

# Gu UI Flow Verify

Use this skill for changes in `ui/`, `assets/theme/`, `scenes/`, or `scripts/presentation/`, especially screen transitions, dialogs, previews, and debug presentation. Read `AGENTS.md` and `docs/superpowers/specs/2026-08-26-ui-sts-redesign-design.md` before editing.

## Presentation Boundary

- Screens render snapshots and submit commands through `RunController` and existing command builders. They do not modify `RunState`, catalog data, saving, RNG, or ending results directly.
- Extend the snapshot/command boundary when a screen needs new facts or actions. Avoid duplicating domain calculations in `.guitkx` or presentation scripts.
- Preserve stale-command handling: commands carry the displayed state version and cannot replay against a changed state.
- Keep generated `ui/**/*.gd` out of manual edits. Edit `.guitkx` sources and hand-written scripts under `scripts/`.
- Keep developer tools development-build only. UI hiding is insufficient: debug operations must remain outside release builds, mutate only run state through normal validation, and create a traceable event.

## Required Player Transparency

- Tooltip format exposes quality, effect, synergy, numeric cost, and curse warning. Dangerous/cursed gu use strong red treatment.
- Enemy intent must show both its number and effect text. Health and shield remain separate.
- Any lifespan, soul, backlash, refinement failure, capacity replacement, finisher, non-death ending, or destructive setting action requires a consequence preview and the required confirmation step.
- Shop services display remaining uses, current price, and inflation. Events preview consequences and offer access to the player's relevant current state.
- Contracts and DDA/per-run anomalies are visibly separated in the persistent top area. Pity is hinted, never exposed as a raw counter.
- There is no reload/undo route. All endings enter the unified ending screen before returning to hall; leaving a run saves it rather than rerolling it.

## Flow Review

For each affected screen, confirm entry condition, available adjustments, exit side effect, return target, and interruption/save behavior. For a new navigation path, update the existing presentation state ownership rather than adding a disconnected local view state.

Pay special attention to these locked paths:

- Hall: continue active run first; new run follows school then contract selection; codex is read-only.
- Map: only reachable nodes can submit travel commands; node resolution returns through the unified map flow.
- Rewards and refinement: full gu capacity never silently overwrites content; empty-pool fallback is visible but non-blocking.
- Ending: every death and voluntary/non-death ending uses the same ending route and clears the active run only in the established completion sequence.

## Change And Verification Loop

1. Trace snapshot fields, callbacks, controller handlers, and the nearest UI or integration test before editing.
2. Add a focused test first where a behavior is observable without pixels: rendered snapshot data, callback command, dialog gating, navigation, or state ownership.
3. Make the smallest source change. For theme-only changes, check all semantic color uses rather than touching unrelated screens.
4. Run the focused test with `tools/test.ps1 -Test <path>`, then the affected test suite.
5. Run `powershell -ExecutionPolicy Bypass -File tools/check.ps1` when shared controller/snapshot/navigation behavior changes.
6. For visual work, run the project or its existing capture/smoke path and inspect the relevant screen at desktop size; check text containment, clipping, overlap, disabled/loading states, and action feedback.
7. Finish with `git diff --check`, preserving unrelated UI edits already present in the worktree.
