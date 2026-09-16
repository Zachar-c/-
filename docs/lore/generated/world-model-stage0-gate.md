# World Model Stage 0 Gate

- Result: **NO_GO**
- Exact command: `tools/lore.ps1 world-model-0 --config lore_engine/config/world-model-stage0.json --out docs/lore/generated`
- Deterministic repeated output: `true`
- Provenance verified: `true`

## Source hashes

- `gu_zhenren_main`: `bf78d41427e28bb8b64f1ad6d93b971d1a77458abf273e554aabe7f27a155d34`
- `ren_zu_zhuan`: `e6a6a6187ec69d36957defac0aa644cec494fe2c1b2d2e6c13969fe460b9cab8`

## Output hashes

- `world-model-baseline-v1.json`: `033aa5246fddcd8882c7ad2c1865d0994473fa1d4cc9715b7b3371fdb71530a7`
- `world-model-baseline-v1.md`: `7f2639f7cbfdbce195413f2f25936f969c61265cc436b81578693b80227a110a`

## Claim coverage

- Target topics represented: `24/24`
- High-impact claims with complete P0 references: `0`
- Total baseline rows: `24`

## Unresolved items

- `aptitude_capacity`
- `body_and_blood`
- `cultivator_aperture`
- `dao_marks`
- `economy_and_primeval_stones`
- `force_and_social_order`
- `gu_activation`
- `gu_feeding`
- `gu_is_independent_entity`
- `gu_is_life`
- `gu_ownership`
- `gu_recipe`
- `gu_refinement`
- `information_leak`
- `inheritance`
- `kill_move`
- `lifespan`
- `mortal_immortal_boundary`
- `natal_gu`
- `primeval_essence`
- `rank_and_subrank`
- `soul`
- `tribulation_or_ascension`
- `world_scope_and_compression`
- Unresolved P0 conflicts: None.
- Non-blocking deferred claims: None.

## Legacy dispositions

- `f1_pity` -> `audit_only`: F1 Pity is historical implementation context and cannot authorize Stage 0 production behavior.
- `promotion_economy` -> `defer`: Promotion economy remains deferred until source evidence and the later economy slice are adjudicated.
- `promotion_materials` -> `defer`: Promotion materials remain deferred until source evidence and the later refinement slice are adjudicated.
- `q8g_promotion_chain` -> `audit_only`: Q8-G is retained only as an audit trail and is not a production-ready world rule.
- `school_promotion` -> `defer`: School promotion remains deferred while school-as-class semantics are under review.

## Production boundary

- Changed forbidden paths: None.
- Gate blockers: high-impact complete references 0 < 20; high-impact claims missing complete P0 references: aptitude_capacity, body_and_blood, cultivator_aperture, dao_marks, economy_and_primeval_stones, force_and_social_order, gu_activation, gu_feeding, gu_is_independent_entity, gu_is_life, gu_ownership, gu_recipe, gu_refinement, information_leak, inheritance, kill_move, lifespan, mortal_immortal_boundary, natal_gu, primeval_essence, rank_and_subrank, soul, tribulation_or_ascension, world_scope_and_compression; unresolved high-impact claims: aptitude_capacity, body_and_blood, cultivator_aperture, dao_marks, economy_and_primeval_stones, force_and_social_order, gu_activation, gu_feeding, gu_is_independent_entity, gu_is_life, gu_ownership, gu_recipe, gu_refinement, information_leak, inheritance, kill_move, lifespan, mortal_immortal_boundary, natal_gu, primeval_essence, rank_and_subrank, soul, tribulation_or_ascension, world_scope_and_compression

## Forbidden follow-up actions before Gate approval

- Do not modify `data/`, `scripts/`, or `scenes/` from Stage 0 findings.
- Do not implement or restore Q8-G promotion or F1 Pity behavior.
- Do not migrate saves, remove legacy fields, or silently preserve deprecated behavior.
- Do not start the vertical-slice production implementation until this Gate is reviewed and approved.
