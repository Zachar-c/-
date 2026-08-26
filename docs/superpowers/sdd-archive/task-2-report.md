# Task 2 Report: Rare Pity Counter (保底计数器)

Status: DONE
Commit: `834c6f8` — `feat: add rare pity counter forcing non-common loot after three commons (p0 t2)`
Branch: `task1-vendor-open-rpg` (worktree `.worktrees/game-impl`, not pushed)

## Scope

Implemented lockdown spec R13.1 adventure-drop rare pity exactly as briefed:

- `RunState.loot_pity: int = 0` — consecutive common-producing adventure-drop counter.
- After **3** consecutive common-producing gated drops, the next gu rarity roll is forced onto non-common buckets only: weights renormalized excluding `common`, salt `"loot.gu.rarity.forced.<tier>"` (replaces the normal `"loot.gu.rarity.<tier>"` roll entirely; chance gate and bucket-pick salts unchanged).
- Rare/epic/legendary drop → counter resets to 0; common → +1. The new value rides the `loot_gu_gained` event's `after` payload under key `"loot_pity"` and is applied via the `_apply_after` whitelist (no direct field assignment), so replays reproduce it.
- Chance-gate failures never touch the counter. Shop purchases bypass it by construction (fixed offers never call `_roll_gu`; documented in a resolver comment per brief).
- Forced roll can never grant legendary beyond what table weights allow: if no non-common weight exists, forcing is a no-op fallback to the normal roll.
- NOT implemented (deferred per brief): "elite guaranteed epic" clause (P1⑪), pity UI display / settlement statistics.

## Files touched

| File | Change |
|---|---|
| `scripts/domain/run_state.gd` | Added `var loot_pity`; wired into `to_save_data()`, `_copy()`, `_apply_after` whitelist |
| `scripts/domain/loot_resolver.gd` | `PITY_THRESHOLD=3`, `PITY_CLEARING_RARITIES` consts; `_roll_gu` now returns `{gu_id, rarity}` and applies forced weights/salt; `_next_loot_pity()` helper; pity threaded through `settle_victory` → `_apply_loot` → `_gain_gu` into event `after` payload; shop-bypass comment |
| `scripts/domain/save_repository.gd` | `_state_from_save_data` restores `loot_pity` (required by the round-trip requirement) |
| `tests/unit/test_loot_pity.gd` | New GUT test file (7 tests) |

No other files modified. `vendor/` untouched.

## Tests added (`tests/unit/test_loot_pity.gd`)

- `test_fourth_consecutive_common_drop_is_forced_rare_or_better` — drives `settle_victory` on 20 seeds × 60 elite fights; asserts every post-3-commons gated drop is non-common and that state counter tracks streak at every gated drop; ≥1 forced scenario observed.
- `test_forced_rarity_roll_excludes_common_bucket` — direct `_roll_gu` with gate raised to 100 across 40 seeds; never empty, never common; rare and epic both reachable under renormalized weights.
- `test_counter_resets_to_zero_after_rare_or_better_drop`
- `test_gate_failure_does_not_advance_the_counter`
- `test_gu_loot_event_payload_carries_new_pity`
- `test_loot_pity_survives_save_round_trip` — `serialize_run` → `load_run_from_data`
- `test_same_seed_replays_identical_loot_and_pity_sequence` — full loot+pity sequence and event log deep-equal for seeds 11 and 424242

## Verification

Commands run (from worktree root):

```
$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all -Test tests/unit/test_loot_pity.gd   # red first, then green
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all
```

TDD red phase confirmed before implementation: `0/7 passed` (all failing on missing `loot_pity`). After implementation, new-file run tail:

```
Tests                 7
Passing Tests         7
Asserts             385
---- All tests passed! ----
Exiting with code 0
```

Full suite tails:

```
unit:         Scripts 61 | Tests 336 | Passing Tests 336 | Asserts 2326 ---- All tests passed! ----
integration:  Scripts  3 | Tests   6 | Passing Tests   6 | Asserts   23 ---- All tests passed! ----
```

Baseline preserved: 329 unit + 6 integration green, plus 7 new unit = 336 unit. One pre-existing unit-run warning (`title_view.gd` leaked children in an existing UI test) is unrelated to this task.

## Self-review findings

- Whitelist / `_copy` / `to_save_data` wiring all present for `loot_pity`; load path restored in `save_repository.gd` (needed so `_has_valid_event_log`'s last-event-vs-state check passes after round trips).
- During implementation I initially mis-placed the `to_save_data` edit into `_initial_event`'s `after` (ambiguous `"stone": stone,` anchor); caught via failing round-trip test + temporary probe, reverted, re-applied correctly. No residue left (probe files deleted).
- RNG purity: only seeded salts via `_pick_from`; unforced path consumes the identical salt sequence as pre-change code (byte-identical behavior when pity < threshold), verified by existing determinism tests staying green.
- Counter increments only on gated drops that actually produce a gu (bucket non-empty); gate failures return before any pity logic.
- ASCII identifiers/comments throughout; comments limited to non-obvious invariants plus the brief-mandated shop-bypass note.
- Deferred items untouched: no elite-guaranteed-epic, no UI/settlement statistics.
