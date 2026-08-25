# Five-School Expansion Batch Plan (五流派扩展批)

Branch: `p0-batch-continuation`. Baseline: P0 complete @ `1e5d2c5` (382 unit + 6 integration green).
User rulings in force: total gu count expands to **200** (from 20); run budget 3–5h / 200–300 nodes (R1.4).

## Global Constraints (bind every task)

- ASCII identifiers/keys/tests/commits; Chinese allowed in `name_zh`, `summary`, narrative fields.
- TDD; verify `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`; baseline 382 unit + 6 integration green must hold plus new tests.
- Domain purity: seeded salts only; immutable `append_event` with whitelist/copy/save wiring for any new top-level field.
- Data discipline: 原著事实与游戏数值分离；非原著蛊名标记 `"source": "game_new"`（字段可选，校验接受缺省）。
- Rarity distribution for the expanded pool: common ~60% / rare ~30% / epic ~10% / legendary 0（首版仍锁传说，R4.5 数据口保留）.
- Do not touch `vendor/` or the user's dirty worktree `.worktrees/game-impl`. Do not push.

## Task C1: Gu catalog expansion to 200 (content pipeline)

1. Curate `data/gu_name_manifest.json` from harvest file `.superpowers/sdd/gu-name-harvest.txt` (sibling editor worktree path given at dispatch):
   - Noise filter rules: drop entries ending in `仙蛊`/`道蛊`/`道仙蛊` (generic tier-talk), drop leading verb fragments (转/的/购/算…), drop known idioms that are NOT gu (blacklist maintained in script), dedupe case-insensitively against existing 20 ids' pinyin-free zh names.
   - Assign each curated name to one of five schools by keyword heuristic (blood 血/气 qi incl 风/force 力熊石岩铁骨筋/soul 魂魄幽梦怨/refine 炼炉火淬材合); leftovers go to a `wildcard` list distributed to whichever school is short.
   - Quota: exactly enough names so that per-school totals (existing + new) reach **40** per school → 200 total. Rarity pre-assignment: common 24 / rare 12 / epic 4 per school (existing entries keep their T1 rarity and count toward quota).
2. Generator script `tools/generate_gu_catalog.py` (committed, deterministic, no deps beyond stdlib):
   - Reads manifest + current `data/gu.json`/`data/cards.json`, emits the new entries appended (never mutates existing 20).
   - Mechanical templates × six roles (`attack/defense/movement/healing/logistics/recon`) parameterized by rarity tier; every new gu gets exactly one card blueprint (1:1), card effects drawn from the EXISTING effect vocabulary used by `battle_resolver._resolve_card_instance` — read that function first and reuse its accepted keys/values; do not invent effect kinds the resolver cannot execute.
   - `id` slugs: pinyin-less ASCII scheme `<school>_<role>_<nnn>_gu` acceptable ONLY when no clean romanization exists; prefer short ASCII transliterations. Must be unique.
   - Emits report of counts per school/rarity/role.
3. Catalog validation additions in `content_catalog.gd`: duplicate gu/card id detection across whole table; card blueprint back-reference integrity already exists — extend to assert every NEW gu has ≥1 blueprint and vice versa no orphan cards referencing missing gu.
4. Tests (`tests/unit/test_catalog_expansion.gd`): total gu == 200; per-school == 40; rarity distribution within ±5% of targets; zero duplicate ids; every new gu has exactly one card; resolver smoke: one battle with a deck built entirely from newly generated common cards completes via existing `battle_resolver.start/take_turn` without rejection.
5. Update any legacy tests that hard-code pool size assumptions (document each change in report).

## Task S1: Soul school mechanics + starter set (spec R4.7 soul anchor)

1. `data/schools.json` += `"soul"` entry; starter_gu_ids = 5 soul gu chosen from expanded pool (canon names preferred: 狼魂蛊/马魂蛊/怨魂蛊/梦魂蛊/月魂蛊 family if present in pool).
2. Over-channel rule in `school_rules.gd`: when active school == soul, playing a card may declare `overchannel: true` — pays `soul` cost equal to overcharge level; if resulting soul <= 0 the cultivator survives at soul 1 ONCE per battle (second hit kills, matching R2.3 明示透支); benefit scales with overcharge (extra damage or extra draw, one concrete rule documented in code).
   - Backlash-to-power: soul school gains `on_backlash_gained` hook value — backlash layers convert to draw/damage via existing Task 4 trigger (school-gated multiplier in school_rules).
3. Death cause: soul depletion death routes through terminal flow with precise cause string `death_cause_soul_exhausted` (coordinates with Task S4 but the domain string lands here).
4. Tests: overchannel happy path; once-per-battle mercy; second overkill dies with soul-exhausted cause; school-gated conversion fires only for soul school.

## Task S2: Refine school mechanics + starter set

1. `schools.json` += `"refine"` entry; starter 5 from refine-flavored pool entries.
2. Battle-scoped simple refinement: new card effect kind accepted by `_resolve_card_instance` — `sacrifice_and_empower` (banish another held card this battle, buff a chosen kept card's damage by sacrificed card's cost) and `transmute_junk` (convert a common card in hand into a temporary strike token). Products are battle-local only; never touch `gu_instances`/codex (R10.5).
3. School passive: refine school starts each battle with 1 free transmute charge (school_rules).
4. Tests: sacrifice math, banish semantics, no codex leakage, passive charge once-per-battle.

## Task S3: Materials closure + qi material pity (spec R4.7 qi anchor)

1. Material gains standardized: all material income flows through events tagged `reason: "loot_materials_gained"` (verify existing paths comply; add tag where missing).
2. Qi-school material floor: while active school == qi, if N=3 consecutive elite/victory rolls produce zero materials, next victory guarantees ≥1 material (counter mirrors loot_pity pattern, salt-isolated; counter field `material_pity` on RunState with full wiring).
3. Qi material tilt: qi school also adds +10 weight to material_pool sampling frequency (implement as extra material_count roll chance +10pct, capped).
4. Tests: floor triggers on dry streak for qi school only; non-qi unaffected; persistence round-trip.

## Task S4: Three death-line warnings + precise death cause (spec R2.3)

1. Domain: threshold-crossing detector emits feed strings + event log entries when health/lifespan/soul cross warn lines (health ≤ 25% max, lifespan ≤ 10, soul ≤ 2). Debounced: warn fires on crossing, not continuously.
2. `death_report_builder.gd`: precise cause strings for all three channels — 气血耗尽 / 寿元枯竭 / 魂魄耗尽 (+ existing backlash attribution), each listing the final damaging event id from the log (R2.3 可复盘).
3. Presentation: minimal feed-driven warning hooks (no layout changes; result_feed strings carry the warning text) — avoid colliding with user's UI session.
4. Tests: crossing detection both directions (no re-fire while below), three death causes resolve distinct strings, log references valid event ids.

## Task S5: Closure sweep

1. `ContentCatalog.validate`: exactly five schools present, each starter non-empty and school-owned (all starter gu have matching school field).
2. Smoke matrix: for EACH of five schools — new_run(school) → scripted first battle win → assert run state consistent and journal attributes correctly (parameterized single test × 5).
3. Full suite green; counts report (200 gu / ≥200 cards / 5 schools × 40).
4. Docs sync note for AGENTS.md task entry (controller commits separately on master).

## Final review

Whole-branch review after S5 with focus: content coherence at scale, school mechanic balance levers present, spec R14.3 groundwork (five schools playable end-to-end), performance watch item O(events×state) noted for later rescale batch.
