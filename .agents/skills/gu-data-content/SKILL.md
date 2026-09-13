---
name: gu-data-content
description: Add or tune Gu Lu Qiu Sheng JSON content such as gu, cards, enemies, pools, recipes, shops, NPCs, events, curses, or pacing without breaking catalog references, seeded progression, or cost visibility.
---

# Gu Data Content

Use this skill whenever changing `data/*.json` or adding data-driven content. Read `AGENTS.md`, the authoritative mechanics specification, the relevant table, and `scripts/domain/content_catalog.gd` before editing. JSON keys and IDs are ASCII; player-visible localized text may be UTF-8.

## Data Is The Rule Surface

- Put game balance and content relationships in the appropriate JSON table. Keep original-source facts, balance values, and any LLM dialogue text separated.
- Use stable, descriptive ASCII IDs. Update every reference deliberately; never depend on display text as an identifier.
- Keep gu, recipes, nodes, NPCs, enemies, shops, reputation, and battle behavior data-driven. Do not work around a missing field by adding a one-off hardcoded behavior unless the task explicitly changes the schema.
- Extend catalog validation and focused GUT coverage whenever a new field or cross-table constraint is introduced.
- Do not change the raw roguelike design-data directory or the read-only reference corpus directory described in `AGENTS.md` without explicit user permission.

## Content Constraints

- The five schools are blood, qi, strength, soul, and refine. Do not weaken their distinct mechanical roles for superficial theme coverage.
- Locked or undiscovered content must not enter ordinary run pools. Reward sources remain isolated; shop acquisition does not advance pity; curses are opt-in and never ordinary drops.
- Pity raises only a quality floor, does not name a specific gu, and never directly grants legendary content. Keep duplicate, empty-pool fallback, hidden-pool, and soft legendary-cap behavior intact.
- Strong gu, recipes, and elite rewards require visible costs. High-tier directed refinement cannot be a zero-risk graduation path; curse inputs cannot be washed clean.
- Keep materials, gu, consumables, and stones run-local. The global codex is read-only in future runs and grants no combat power.
- Ensure player-facing risk and numbers are explicit: enemy intentions include number and effect; costs, backlash, inflation, capacity, and lethal consequences are previewable.

## Change Loop

1. Identify table owners and all ID consumers with `rg`. Read comparable records before choosing fields or values.
2. Write a focused test that loads real content or injects a minimal invalid copy to prove the new constraint.
3. Make the minimal JSON and validator change. Preserve formatting and unrelated table ordering.
4. Run the focused test, then `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd` when catalog behavior changed.
5. Run the closest behavior test and the affected suite. Use `tools/check.ps1` for broad catalog, progression, or cross-system edits.
6. Inspect `git diff --check` and confirm no configuration uses an unknown ID or violates an enforced pool/recipe boundary.

## Useful Anchors

- `scripts/domain/content_catalog.gd`: table loading and cross-table validation.
- `tests/unit/test_content_catalog.gd`: validation style and shipped-table baseline.
- `data/school_pools.json`, `data/loot_tables.json`, and `data/synthesis.json`: pool, reward, and refinement boundaries.
- `data/gu.json`, `data/enemies.json`, `data/shops.json`, and `data/events.json`: primary content tables.
