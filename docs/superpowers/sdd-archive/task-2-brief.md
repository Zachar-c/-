# Task 2 Brief: Rare Pity Counter (保底计数器)

You are implementing Task 2 of the P0 lockdown batch in a Godot 4.7.2 / GDScript card roguelike. Branch `task1-vendor-open-rpg`, worktree root is your working directory.

## Global Constraints (binding)

- ASCII identifiers, JSON keys, test names, commit messages; Chinese only in `name_zh`/narrative fields.
- TDD: failing test first, then minimal implementation.
- Verify: `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
- Full suite must stay green: baseline is 329 unit + 6 integration (plus your new tests).
- Domain purity: no RNG outside seeded salts derived from `RunState.seed`; UI never mutates state; state changes go through immutable `RunState.append_event`.
- New RunState fields MUST be wired into `_apply_after` whitelist, `_copy`, AND `to_save_data`.
- Do not touch `vendor/`. Do not push. Commit style: `feat:` with concise body.
- Spec context: lockdown spec R13.1 — "连续 3 次冒险掉落未出稀有及以上，下一次必出稀有及以上；获得即清零，轮回重置。只抬品质不指名具体蛊，禁止直给传说；商店购买不推进也不消耗计数。" Known deferral: the separate R13.1 clause "精英必掉史诗" is scheduled for P1⑪ and must NOT be implemented here.

## Requirements

1. `scripts/domain/run_state.gd`: add `var loot_pity: int = 0`. Wire into `to_save_data()`, `_copy()`, and the `_apply_after` whitelist key list.
2. `scripts/domain/loot_resolver.gd` `_roll_gu(table, state, tier)`:
   - A gu drop roll that passes the chance gate counts as one adventure drop.
   - BEFORE the rarity roll: if `state.loot_pity >= 3`, force the rarity roll over non-common buckets only — renormalize weights excluding `common`, use salt `"loot.gu.rarity.forced.<tier>"` instead of `"loot.gu.rarity.<tier>"`. Never force legendary beyond what forced weights allow (weights come from data; early layers have zero legendary weight, which naturally holds the "不直给传说" rule).
   - AFTER producing a gu: rarity in ["rare", "epic", "legendary"] → new pity = 0; "common" → new pity = old + 1. The new pity value rides the loot event's `after` payload under key `"loot_pity"` so replays reproduce it (`_apply_after` applies it because of the whitelist).
   - Chance-gate failures do not touch the counter. Shop purchases are fixed offers today and never call `_roll_gu` — add a one-line comment in the resolver stating shop purchases bypass the counter by construction (spec R13.1).
3. Tests in a NEW file `tests/unit/test_loot_pity.gd` (GUT, follow existing test style):
   - Forced rare+ on the 4th consecutive common-producing elite drop across several distinct seeds (construct states, drive `settle_victory` repeatedly; where chance gate randomness interferes, either pick seeds empirically in-test via a loop until enough gated drops occur, or call the internal `_roll_gu` directly through free function access — prefer driving `settle_victory` with seeds you verify locally to produce gated drops; keep the test deterministic).
   - Counter resets to 0 after a rare-or-better drop.
   - Counter persists through `SaveRepository.serialize_run` → `load_run_from_data` round-trip.
   - Determinism: same seed and same event position → identical loot sequence including pity evolution.

## Interfaces from Task 1 (already landed)

- `data/gu.json` entries carry `"rarity"` ∈ common/rare/epic/legendary; `ContentCatalog.RARITY_IDS` exists.
- `data/loot_tables.json` tiers use `gu_pool: {weights: {rarity: int}, by_rarity: {rarity: [gu_id]}}`; elite tier = `{common:60, rare:35, epic:5}` with buckets; legendary absent.
- `LootResolver._pick_from(bound, state, salt)` derives a seeded rng from `state.seed * 1000003 + state.event_log.size() * 97 + salt_hash` — event-log length participates, so pity updates that append events shift subsequent salts deterministically (that is fine; tests must account via full-sequence determinism rather than fixed gu ids per seed).
- Elite tier has `gu_chance_pct: 30`; common/boss tiers have 0.

## Ambiguity resolutions (binding)

- "冒险掉落" counter increments only when the chance gate passes AND a gu is actually produced (i.e., bucket non-empty). Gate failures are not drops.
- The forced roll replaces the normal rarity roll entirely on that call (no double roll).
- Do NOT add pity display/UI or settlement statistics in this task (later batch); the event payload is sufficient evidence.

## Report contract

Write your full report to `.superpowers/sdd/task-2-report.md` (implementation scope, files touched, test names added, exact verification commands run and their tail output, self-review findings). Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns if any.
