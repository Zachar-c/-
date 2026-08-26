# Task C1 Brief: Gu Catalog Expansion to 200

You are implementing Task C1 of the five-school expansion batch in a Godot 4.7.2 / GDScript card roguelike. Branch `p0-batch-continuation`, worktree root = your working directory.

## Global Constraints (binding — full list in docs/superpowers/plans/2026-08-25-five-school-expansion-plan.md, read it)

- ASCII identifiers/keys/test names/commit messages; Chinese allowed in `name_zh`/`summary` only.
- TDD; verify with `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`; baseline 382 unit + 6 integration green must hold plus new tests.
- Never mutate the existing 20 gu / 19 card entries (only append).
- Rarity distribution targets per school across ALL its entries: common 24 / rare 12 / epic 4 (existing entries already counted). Legendary forbidden this batch.
- Deterministic generator committed to `tools/generate_gu_catalog.py` (stdlib only); re-running it on a clean tree produces byte-identical output.
- Do not touch `vendor/`, `.worktrees/game-impl` (user's dirty worktree), or push.

## Requirements (from plan Task C1 — authoritative)

1. Curate manifest `data/gu_name_manifest.json`: curated Chinese names → {school, rarity} assignments reaching exactly 40 entries per school (blood/qi/force/soul/refine), counting existing 20 toward quota.
   - Harvest source (read-only): C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren\gu-zhenren-editor\.superpowers\sdd\gu-name-harvest.txt
   - Noise rules: drop names containing 仙蛊 / 道蛊 / 道仙蛊 suffixes (generic tier talk), drop leading verb fragments (转|的|购|算|算|么|到|过|些|为|少|易|炼|杀|命|搭配|催动|加大|成为|改良|上古|六转|四转|七面|八转 etc. prefixes are noise UNLESS the remaining name still reads as a distinct gu), dedupe against existing zh names.
   - Idiom-names ARE canon gu in this novel (自力更生蛊、全力以赴蛊、扬眉吐气蛊 are real) — keep them when frequency ≥3.
   - School keyword heuristic from the harvest buckets; leftovers redistributed to short schools.
   - Names not found in harvest may be composed as `<school-flavored char>_<existing pattern>` variants ONLY if quota cannot be met otherwise; mark those `"source": "game_new"`.
2. Generator `tools/generate_gu_catalog.py`: appends new entries to `data/gu.json` and `data/cards.json`.
   - CRITICAL: before writing any card JSON, READ `battle_resolver._resolve_card_instance` (scripts/domain/battle_resolver.gd) and enumerate the exact effect keys/values it executes (damage amounts, block, draw, essence gain, status applications, kill_move_sequence, duration_turns semantics...). New cards may ONLY use effects that function actually implements. Reuse existing cards' field patterns (read several entries of data/cards.json as templates).
   - New gu entry fields follow existing gu.json schema exactly (rank, feeding_cost, feeding_need, card_blueprint_ids, value, essence_cost, slot_role, combat, field_actions, synergy_hooks, tags, school, role, rarity). Sensible mortal-tier values; feeding needs reference existing material ids only (beast_blood/beast_bone/venom_sac/moon_dew/feed_points).
   - id scheme: prefer short meaningful ASCII (`soul_wolf_gu` style); uniqueness enforced by your script + catalog validation.
3. Catalog validation additions (`content_catalog.gd`): duplicate gu ids; duplicate card ids; every gu has ≥1 blueprint; no orphan cards (card.source_gu_ids all exist AND some gu lists the card in card_blueprint_ids — bidirectional integrity for NEW entries; keep legacy entries exempt from bidirectionality to avoid churning old data).
4. Tests `tests/unit/test_catalog_expansion.gd`: total gu == 200; each school == 40; rarity distribution within ±5% of per-school targets; zero duplicate ids anywhere; every new gu has exactly one card; smoke battle using a deck of generated commons completes (drive battle_resolver.start/take_turn with a scripted command sequence like existing battle tests do).
5. Update legacy tests that hard-code pool sizes ONLY where they break; log each change in your report.

## Ambiguity resolutions (binding)

- "总量 200" includes the existing 20.
- Cards-per-gu is exactly 1 for new entries; total cards ≥ 219 after batch (19 legacy + 200)? NO — legacy has 19 cards for 20 gu; you add 180 gu → target total cards == 199 (19 + 180). Do not add extra legacy cards.
- If curated real names run short for a school, compose variants by prefixing school chars (e.g., 血爪蛊→血牙蛊 style single-char substitution) marked game_new rather than importing idioms below frequency 3.
- The manifest file IS part of the deliverable (committed).

## Report contract

Full report to `.superpowers/sdd/task-c1-report.md` (scope, counts table school×rarity×role, files touched, test names, verification commands + tail output, self-review findings including noise-filter judgment calls). Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns if any.
