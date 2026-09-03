# Task 2 Report: Data-backed Starter Gu Effects

## Result

Implemented the starter combat Gu effect slice through the existing
`BattleCommandFacade -> V1BattleResolver` path. No UI rule logic or second
battle rules entry point was added.

## Changes

- Added a focused GUT test covering the seven starter combat Gu definitions.
  Each Gu must expose a non-empty `v1_effect`, be accepted by `use_gu`, and
  change observable battle state.
- Added data-backed `v1_effect` entries in `data/gu.json`:
  - `trail_eye_gu`: `status/marked`
  - `blood_moss_gu`: `heal_and_strike`
  - `thorn_whip_gu`: `status/bound`
  - `mist_step_gu`: `shift`
  - `venom_thread_gu`: `status/poison`
  - `stone_shell_gu`: `shield`
- Extended `V1BattleResolver` with minimal handlers for `heal`,
  `heal_and_strike`, `status`, and `shift`. Healing is capped at max HP;
  statuses are stacked on the current enemy; movement updates the existing
  player position field. The existing `strike`, `shield`, and `buff` handlers
  remain unchanged.

## Verification

- `tools/test.ps1 -Test tests/unit/test_gu_roles_and_starter_attack.gd`: 6/6
  tests passed, 243 assertions.
- `tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd`: 11/11
  tests passed, 39 assertions.
- `git diff --check`: passed.

## Remaining concerns

- The new status and position fields are intentionally battle-local. They do
  not yet add turn-expiry or downstream status behavior; this task only makes
  starter Gu actions observable and playable through the current V1 boundary.
- Full repository validation was not run because the worktree contains broad
  unrelated user changes; the focused battle tests and parser/build checks
  passed.
