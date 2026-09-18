# Task S1 Brief: Soul School Mechanics + Starter Set (魂道流派)

Branch `p0-batch-continuation`, worktree root = working directory. Baseline: 389 unit + 6 integration green @ `f0abb36`.

## Global Constraints
Identical to batch plan `docs/superpowers/plans/2026-08-25-five-school-expansion-plan.md` Global Constraints section (read it): TDD, ASCII identifiers, seeded salts only, immutable append_event, no vendor/, no push, suite must stay green plus new tests.

## Requirements

1. **School entry**: `data/schools.json` += `"soul"`: name_zh 魂道, summary 一句（魂魄为薪、超额释蛊、反噬转战力）, `starter_gu_ids` = exactly five existing soul-school gu chosen by role spread — pick deterministically: for each role in [attack, defense, movement, healing, recon] take the FIRST generated soul gu (`id` starts with `gen_soul_`) with that role from data/gu.json order; if a role has none, take any unused soul gu. Document final picks in your report.
2. **Over-channel rule** in `scripts/domain/school_rules.gd` (new static funcs, pure):
   - `is_soul(state) -> bool` (state.school == "soul").
   - `overchannel_cost(level) -> int` = level (soul paid).
   - Mercy: while battle flag `soul_mercy_used` is absent, an over-channel that would drop soul below 1 instead sets soul to 1 and sets that battle flag; with flag present, soul hits 0 normally → existing `_depleted` terminal flow handles death (cause surfaces via journal in Task S4; here ensure the triggering event reason is `"soul_overchannel_death"`).
3. **Activation wiring** in `battle_resolver._use_gu`: after normal effect execution, if `SchoolRules.is_soul(state)` and action payload carries `"overchannel": level` (int ≥1, cap 3):
   - apply benefit by level: level 1 → `_strike` +2; level 2 → +4 and draw +1 next refill (extend pending_extra_draws analog: reuse `RelicHookResolver.apply_draw_card`-style pending mechanism or a battle key consumed by `_refill_hand_after_turn`); level 3 → +6 and enemy_bound flag.
   - pay soul: new_soul = current soul - level; apply mercy rule above; every use appends immutable event `action: "soul_overchannel"` with before/after soul + mercy flag state (R2.3 可预见性：rejection never silent — insufficient soul beyond mercy → reject reason `soul_exhausted` BEFORE mutating anything).
4. **Backlash-to-power conversion (R4.7)**: school-gated multiplier — when `is_soul(state)`, the Task 4 trigger `on_backlash_gained` effect `convert_backlash_to_draw` yields double draws. Implement inside the hook application path (read how Task 4 wired `apply_backlash_gained`; add school check where draws are computed).
5. Tests NEW `tests/unit/test_soul_school.gd`: overchannel L1/L3 benefits; mercy once-then-die sequence with reasons; rejection before mutation when soul insufficient; non-soul school ignores overchannel payload entirely; double-draw conversion fires only for soul school; starter picks exist in catalog with matching school field.

## Interfaces / facts
- `_use_gu` post-match common code applies `after` dict (essence/injury deltas) then logs; place overchannel logic AFTER legacy/data effects so both coexist.
- `cultivator.soul`, `soul_max` persist already; `_depleted()` checks soul <= 0.
- Task 4 hooks: `RelicHookResolver.TRIGGERS` contains `on_backlash_gained`; find `apply_backlash_gained(...)` in relic_hook_resolver.gd and its caller(s) in battle_resolver for the draw computation site.
- Battle-scoped flags precedent: `_add_flag(battle, name)`; battle keys reset naturally per battle via `start()`.
- Rejection style: `_rejected_turn(battle, state, reason)` inside battle context.

## Ambiguity resolutions (binding)
- Overchannel is opt-in per play via explicit payload flag; never automatic.
- Mercy applies ONLY to soul loss from overchannel, not to curse-channel damage or other soul drains this task.
- No UI work; feeds suffice (`soul_overchannel`, `soul_mercy_triggered`).

## Report contract
Full report to `.superpowers/sdd/task-s1-report.md`. Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns.
