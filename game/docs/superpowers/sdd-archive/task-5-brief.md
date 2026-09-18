# Task 5 Brief: Dual Removal Channels (移除双渠道)

You are implementing Task 5 (final P0 task) in a Godot 4.7.2 / GDScript card roguelike. Branch `p0-batch-continuation`, worktree root is your working directory.

## Global Constraints (binding)

- ASCII identifiers, JSON keys, test names, commit messages; Chinese only in `name_zh`/narrative fields.
- TDD: failing test first, then minimal implementation.
- Verify: `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
- Baseline: 368 unit + 6 integration green — must stay green plus your new tests.
- Domain purity: no RNG outside seeded salts from `RunState.seed`; UI never mutates state; every state change goes through immutable `RunState.append_event` with before/after.
- Do not touch `vendor/`. Do not push. Commit style: `feat:` concise body.

## Requirements

1. **Service limits** in `data/deck.json`: `"service_limits": {"remove_card": 2, "remove_imprint": 2, "remove_curse": 2}` — validated as positive integers by `ContentCatalog.validate` (mirror existing deck checks). Per-run usage counters live in `RunState.node_flags` under keys `svc_used_remove_card` etc. (string values like existing node flags — follow however node_flags stores values today).
2. **Black-market removal commands** in `scripts/domain/resolver.gd::apply`:
   - `remove_card`: payload `{type:"remove_card", instance_id}` — destroys one gu instance (reuse `_destroy_gu` internals or share logic) at price base **120** stone × M5-style uplift per prior use of that service (`price_for` pattern), capped per spec §16.2 (+100%). Reject beyond limit with `service_limit_exceeded`; reject insufficient stone with `insufficient_stone`.
   - `remove_imprint`: payload `{type:"remove_imprint", relic_id}` — removes a NON-meta-grade relic from `relic_ids` (base price **150**). Reject removing meta-grade with `meta_rule_not_removable` (R4.8 contracts-tier rules are not droppable items).
   - `remove_curse`: Task 3 already added this command with `price_for`-based cost — refactor it to consume the SAME shared limit pool and uplift accounting as the other two services (one counter family), keeping its existing tests passing.
   - All three write immutable events (action strings `svc_remove_card` / `svc_remove_imprint` / `svc_remove_curse`) and increment usage counters via the event `after`.
3. **Rest-node removal** (R8.1 二选一): extend the rest command to accept optional `"mode"`:
   - absent/`"heal"` → current behavior unchanged;
   - `"remove_card"` / `"remove_imprint"` / `"remove_curse"` with target id → performs that removal for FREE but consumes the visit; a second rest-mode use on the same node is rejected with `rest_mode_already_used`. Rest removal does NOT touch service usage counters (opportunity cost instead of money, R8.1).
   - Existing rest tests must keep passing (absent mode = heal).
4. **can_direct_drop guard** (§16.15): gu definitions may carry `"can_direct_drop": false`. `_destroy_gu` (and any direct destroy path) on such a gu is rejected with reason `cursed_gu_not_directly_droppable` AND appends a backlash consequence event: gain one layer of configured curse `gu_erosion` via the Task 3 registry (source `"forced_drop"`). Mark exactly one existing cursed-flavored gu in `data/gu.json` with `"can_direct_drop": false` so the path is real-data exercisable. Add the field to catalog validation as optional boolean.
5. **Presentation**: `display_text.gd` gains two distinct Chinese strings clarifying 【移除（从蛊囊删除这只）】 vs 【池排除（本局不再刷出，尚未实装）】— expose as constants/functions with a trivial test asserting both exist and differ (placeholder-friendly for the future exclusion feature).
6. Tests in NEW file `tests/unit/test_removal_channels.gd`: each channel removes its object type and logs events; price escalation across repeated uses; limit rejection; rest mutual exclusion + free removal; can_direct_drop guard triggers curse gain; insufficient stone rejection.

## Interfaces / facts you need

- Task 3 landed: `data/curse.json`, `scripts/domain/curse_registry.gd` (`gain_curse(state, curse_id, source)` appends its own event), resolver command `{type:"remove_curse", curse_id}` charging via `price_for`. Read those first; your job for remove_curse is unifying accounting, not re-implementing.
- Task 4 landed: imprint capacity/meta gates consolidated in `Resolver._can_gain_relic(state, catalog)`; meta-grade relics recorded in `state.meta_rules`. Removal of imprints must also clean `meta_rules` entry when applicable.
- M5 pricing precedent: `price_for(catalog, state, base)` applies market revisit uplift; service uplift keyed by usage count may need a sibling helper — reuse style, don't conflate market-revisit state with service-use counters.
- `node_flags` values are stored as strings today (e.g., `boss_defeated: "true"`); keep counters consistent ("1", "2"...).
- Deck capacity enforcement precedent: `_reject_deck_full` / `deck_capacity.gd`.

## Ambiguity resolutions (binding)

- Removing an imprint that is referenced nowhere else requires no extra cleanup beyond `relic_ids` + `meta_rules` (hooks resolve dynamically).
- Removing a card-bearing gu destroys its cards implicitly (existing destroy semantics govern).
- Service limits are shared between black-market and any future source; rest-channel removal bypasses counters entirely (its own node-flag guard suffices).

## Report contract

Write your full report to `.superpowers/sdd/task-5-report.md` (scope, files touched, test names, verification commands + tail output, self-review findings). Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns if any.
