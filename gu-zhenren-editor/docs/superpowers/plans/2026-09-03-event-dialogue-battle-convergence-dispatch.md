# Event Dialogue and Battle Convergence Agent Dispatch Plan

> **For agentic workers:** Each implementation agent must use the repository's domain/UI skill, add or update a focused GUT test first, and commit only the files listed in its task. The review agent does not modify implementation files unless the primary agent explicitly assigns a follow-up fix.

**Goal:** Finish the approved event dialogue migration and battle input convergence without introducing a second state owner, resolver, or event-log implementation.

**Architecture:** `DialogueManagerAdapter` is a narrative-only gateway. It resolves authored branch IDs to existing `Resolver`/`EncounterSessionResolver` commands and returns visible feedback. `BattleCommandFacade -> V1BattleResolver` remains the only battle execution path; the presentation layer only builds commands from the current snapshot and refreshes after acceptance or rejection.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, GUT 9.6.1, optional `nathanhoad/godot_dialogue_manager` MIT at audited commit `8a49e8001a9021e1982b6e31a10066b41eac2fd2`.

## Baseline Already Complete

- Route closure: `scripts/domain/map_generator.gd`, `tests/unit/test_first_run_route.gd`; commits `fb987cf`.
- Data-backed starter Gu effects: `data/gu.json`, `scripts/domain/v1_battle_resolver.gd`, `scripts/domain/battle_command_facade.gd`, `scripts/presentation/run_snapshot_builder.gd`, `tests/unit/test_gu_roles_and_starter_attack.gd`; commits `4be06a4`, `204ab5d`, `0ebb588`.
- Do not revert or reformat these changes. The worktree also contains unrelated user edits; preserve them.

## Global Constraints

- `RunState` is the only owner of run state; UI and Dialogue Manager never mutate it directly.
- Reuse `Resolver`, `EncounterSessionResolver`, `ResultFeed`, `EffectResolver`, and `ContentCatalog`; do not duplicate them.
- Commands carry the displayed event-log version and stale submissions must reject without mutation.
- Every accepted or rejected event/battle action exposes a Chinese `last_feedback`/`feedback` message.
- Edit hand-written `.gd` and `.guitkx` sources only; never edit generated `ui/**/*.gd`.
- No new card draw/discard/hand availability rules. A Gu card is executable when the snapshot says it is executable.

---

## Agent A: Dialogue Branch Adapter and Event Feedback

**Scope:** Implement the narrative gateway and connect event choices to existing domain commands. Do not change battle code or map generation.

**Files:**

- Create: `scripts/domain/dialogue_manager_adapter.gd`
- Create: `data/dialogues/events.dialogue`
- Modify: `scripts/domain/events.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Test: `tests/unit/test_dialogue_gateway.gd`

**Required interfaces:**

- `DialogueManagerAdapter.respond(context: Dictionary) -> Dictionary`
- `DialogueManagerAdapter.begin(event_id: String, title: String = "start") -> Dictionary`
- `DialogueManagerAdapter.command_for_branch(branch_id: String, context: Dictionary = {}) -> Dictionary`
- `DialogueManagerAdapter.apply_branch(state: RunState, session: Dictionary, branch_id: String, catalog: Dictionary, node: Dictionary = {}, context: Dictionary = {}) -> Dictionary`
- Unknown branches return `{ok: false, reason: "unknown_dialogue_branch", state: same_state, feedback: Chinese text}` and append no event.

**Implementation steps:**

- Add a failing test for one authored branch mapping to `accept_event`, one leave branch mapping to `leave_node`, and an unknown branch preserving `RunState` identity and event-log size.
- Add a failing test for missing Dialogue Manager plugin/template data returning visible Chinese fallback text.
- Route accepted branches through the existing encounter/resolver path. The adapter may return a command and result, but must not call `RunState` mutators directly.
- Ensure `run_controller.gd` copies the adapter result into the existing result feed and `last_feedback` path before navigation. A successful branch must not silently leave the encounter; a rejected branch must keep the current screen/session.
- Keep `.dialogue` branch IDs stable and ASCII (`echo_cave.accept`, `echo_cave.leave`, `gu_rot_pact.accept`, `gu_rot_pact.leave`). Player-facing prose may be UTF-8 Chinese.

**Verification:**

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_dialogue_gateway.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v2_first_slice_flow.gd
```

**Commit:** `feat(dialogue): route event branches through narrative adapter`

**Do not touch:** `scripts/presentation/widgets/gu_battle_hand_view.gd`, `scripts/presentation/screens/battle_screen_view.gd`, `scripts/presentation/run_command_builder.gd`, `scripts/domain/v1_battle_resolver.gd`.

---

## Agent B: Battle Mouse Command Contract

**Scope:** Make every visible Gu card clickable through the current command boundary and preserve target/confirmation/stale-snapshot semantics. Do not add or change battle rules.

**Files:**

- Modify: `scripts/presentation/run_command_builder.gd`
- Modify: `scripts/presentation/widgets/gu_battle_hand_view.gd`
- Modify: `scripts/presentation/screens/battle_screen_view.gd`
- Test: `tests/unit/test_battle_command_facade.gd`

**Required behavior:**

- Clicking `gu.<instance_id>` produces `{"type":"use_gu","instance_id":instance_id,"state_version":current_log_size}`.
- Single-target cards retain the selected `target_id` until command construction and submit exactly once.
- A stale state or hand version is rejected by the existing facade, then the screen refreshes from the new snapshot.
- Card buttons and their descendants do not intercept mouse input (`mouse_filter = IGNORE` where appropriate); the card body remains the clickable control.
- Repeated clicks with the same card/target key are ignored only at the presentation boundary and do not create a second domain command.
- Disabled cards remain visible with a Chinese block reason and do not call `play_card`.

**Implementation steps:**

- Add focused tests for Gu ID conversion, target preservation, duplicate suppression, disabled-card no-op, and stale version rejection.
- Verify the existing `BattleCommandFacade.apply_turn` path still receives the exact command shape; do not call `V1BattleResolver` from UI code.
- Fix hover handling so tooltip refresh does not rebuild the button under the pointer before `pressed` is emitted.
- Fix target-select cancellation and dangerous-card confirmation so cancellation clears only local interaction state and never mutates `RunState`.
- On facade rejection, clear the local submitted-key cache when the mounted snapshot version changes, then show the returned Chinese feedback.

**Verification:**

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd
```

**Commit:** `fix(battle-ui): complete Gu card mouse command contract`

**Do not touch:** `scripts/domain/battle_command_facade.gd`, `scripts/domain/v1_battle_resolver.gd`, `scripts/domain/run_state.gd`, `scripts/domain/effect_resolver.gd`.

---

## Agent C: Effect-Fact Audit (Read-Only Review)

**Scope:** Review the starter-Gu event facts added by the previous task. Do not redesign status/position lifecycle or introduce a new logger.

**Files to inspect:** `scripts/domain/battle_command_facade.gd`, `scripts/presentation/run_snapshot_builder.gd`, `tests/unit/test_gu_roles_and_starter_attack.gd`.

**Review questions:**

- Does each `v1_effect` record enough immutable fields to reconstruct the actual result (`kind`, `amount`, target, status `name`, and `heal` for `heal_and_strike`)?
- Are nested dictionaries copied before appending to the event log?
- Do effect facts remain compatible with the existing ending/journal attribution and snapshot projection?

**Deliverable:** A review report at `.superpowers/sdd/task-2-effect-fact-review.md` listing findings with file/line references and focused test commands. If a P1/P2 issue is found, provide a minimal patch suggestion for the primary agent; do not edit implementation files in the review pass.

**Verification commands:**

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_gu_roles_and_starter_attack.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
```

---

## Primary Agent Review Gate

After Agents A and B report completion:

- Inspect each commit and `git diff --check`; reject changes outside declared files or any direct UI/domain state mutation.
- Run the focused tests from both agents, then `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`.
- Run `powershell -ExecutionPolicy Bypass -File tools/check.ps1` and, for UI changes, `powershell -ExecutionPolicy Bypass -File tools/smoke_render.ps1`.
- Confirm event and battle rejection paths leave state/event-log size unchanged and show Chinese feedback.
- Confirm route closure and starter-Gu regressions remain green.
- Only after these checks, decide whether to request a narrow follow-up fix from the owning agent.

## Integration Commands

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_dialogue_gateway.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_gu_roles_and_starter_attack.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_first_run_route.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit
powershell -ExecutionPolicy Bypass -File tools/check.ps1
git diff --check
```
