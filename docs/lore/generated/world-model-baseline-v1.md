# World Model Baseline v1

- 生成时间（显式 UTC）：`2026-09-16T08:20:35Z`
- 生成器：`lore_engine.reports@1`
- 实现审计：`3375` 条，规范化 SHA-256 `2392a2b42b0f7742ce5377fb6213d16884fde520a6ebf0e31ee3aa98d01eeca1`
- 本报告只保存证据 ID 与定位，不复制原文段落；详细登记见 [适配登记](../adaptation-register.md)、[正典索引](../canon-index.md) 与 [规则登记](../game-rule-register.md)。

| Claim | 已核验事实 | Evidence IDs | Source locations | 偏差候选 | 冲突与未知 | 当前实现映射 | 玩家后果 | 迁移/废止说明 |
|---|---|---|---|---|---|---|---|---|
| aptitude_capacity | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 83 findings | No aptitude-derived capacity or recovery rule is authorized. | Defer production work and record the verified scope before proposing a model. Do not promote current aptitude fields into world truth. |
| body_and_blood | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 0 findings | No new body, bloodline, or injury rule is authorized. | Defer production work pending source verification. Do not infer rules from current data labels. |
| cultivator_aperture | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 0 findings | No aperture rule change is authorized by Stage 0. | Defer production work and collect exact P0 support, conditions, and counter-evidence. Keep current behavior unchanged while evidence is unresolved. |
| dao_marks | 未核验 | — | — | remove | verified P0 support is not yet available | 16 findings | If approved later, players will not receive unsupported universal dao-mark experience for routine actions. | Mark generalized mortal dao-mark progression for deprecation; do not delete fields or migrate saves in Stage 0. Exact P0 exceptions must be preserved before any later removal. |
| economy_and_primeval_stones | 未核验 | — | — | revise | verified P0 support is not yet available | 42 findings | If verified later, players can buy ordinary goods but must use relationships, knowledge, or risk for non-fungible assets. | Keep promotion economy audit-only and defer any pricing or inventory migration. Do not change shops, prices, materials, or saves in Stage 0. |
| force_and_social_order | 未核验 | — | — | revise | verified P0 support is not yet available | 54 findings | If verified later, coercion and status choices leave visible future protection, hostility, or pursuit consequences. | Audit existing NPC and faction outcomes only; defer production changes. One-off current outcomes do not prove the proposed model. |
| gu_activation | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 806 findings | No activation-cost or fallback change is authorized. | Defer production work and verify support plus exceptions. Do not treat role fallbacks as source facts. |
| gu_feeding | 未核验 | — | — | revise | verified P0 support is not yet available | 152 findings | If verified later, upkeep choices expose specific food, timing, and failure consequences. | Audit feeding fields only; defer any data or runtime migration. Promotion materials remain deferred. |
| gu_is_independent_entity | 未核验 | — | — | retain | verified P0 support is not yet available | 0 findings | If verified later, ownership, transfer, feeding, and loss remain attached to individual Gu. | Audit instance identity only; make no production change before P0 verification. Do not infer independence from existing instance fields. |
| gu_is_life | 未核验 | — | — | retain | verified P0 support is not yet available | 0 findings | If verified later, players must treat Gu as maintained living entities rather than disposable skill tokens. | Audit current lifecycle behavior only; make no production change before P0 verification. Existing implementation is not evidence for retention. |
| gu_ownership | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 0 findings | No ownership or transfer behavior changes are authorized. | Defer and gather P0 support, conditions, and counterexamples. Current inventory representation is observation only. |
| gu_recipe | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 0 findings | No recipe unlock or execution rule change is authorized. | Defer and verify source-backed knowledge and execution boundaries. Current recipe data cannot prove the world rule. |
| gu_refinement | 未核验 | — | — | revise | verified P0 support is not yet available | 577 findings | If verified later, players can distinguish knowledge-backed refinement from explicitly risky experimentation. | Audit current refinement paths; defer production redesign and migration. Do not modify recipes, materials, or success logic in Stage 0. |
| information_leak | 未核验 | — | — | defer | verified P0 support is not yet available | 0 findings | No leak, secrecy, or enemy-learning mechanic is authorized yet. | Defer until exact support, conditions, and representative cases are recorded. Do not infer a mechanic from design prose alone. |
| inheritance | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 0 findings | No inheritance reward or access rule change is authorized. | Defer and verify P0 support and exceptions. Current reward rooms are not authoritative. |
| kill_move | 未核验 | — | — | revise | verified P0 support is not yet available | 36 findings | If verified later, players must acquire, prepare, and expose a combination instead of pressing an unexplained universal action. | Audit existing kill-move surfaces only; defer production redesign. Do not modify combat runtime in Stage 0. |
| lifespan | 未核验 | — | — | revise | verified P0 support is not yet available | 76 findings | If verified later, lifespan spending is exceptional, previewed, and irreversible rather than routine shopping currency. | Audit lifespan payment surfaces only; defer runtime and economy migration. No production price or cost changes in Stage 0. |
| mortal_immortal_boundary | 未核验 | — | — | defer | verified P0 support is not yet available | 0 findings | No ascension boundary or immortal-stage production behavior is authorized. | Defer until exact P0 evidence and conditions are complete. Do not approximate the boundary from rank fields. |
| natal_gu | 未核验 | — | — | remove | verified P0 support is not yet available | 0 findings | If later approved, players will not choose a consequence-free core slot detached from cultivation history. | Deprecate the arbitrary-slot hypothesis in future design; preserve current saves and runtime until a separately approved migration exists. No production field or save migration occurs in Stage 0. |
| primeval_essence | 未核验 | — | — | revise | verified P0 support is not yet available | 110 findings | If verified later, players see combat cost as a view of one world resource rather than two unrelated currencies. | Audit dual-resource semantics only; defer any migration until evidence and a later slice are approved. Do not alter essence or true-qi runtime state in Stage 0. |
| rank_and_subrank | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 1008 findings | No new rank gate, multiplier, or promotion rule is authorized. | Collect exact support and exceptions before adjudicating progression semantics. F1 and Q8-G remain audit-only. |
| soul | 未核验 | — | — | needs_evidence | verified P0 support is not yet available | 147 findings | No soul-derived action-point or capacity rule is authorized. | Defer and collect exact P0 support, conditions, and counterexamples. Current soul fields are implementation observations only. |
| tribulation_or_ascension | 未核验 | — | — | defer | verified P0 support is not yet available | 0 findings | No tribulation, ascension, or boss-gate production rule is authorized. | Defer until exact P0 evidence and a later-stage design are approved. Do not equate current boss gates with ascension. |
| world_scope_and_compression | 未核验 | — | — | retain | verified P0 support is not yet available | 268 findings | Players receive a finite run structure without being told that compressed layers are literal world geography or universal law. | Retain as an audit hypothesis only; defer production authorization until source boundaries are verified. Five-layer structure is not source evidence. |

## 已核验事实

当前 24 条高影响 claim 均无已核验 P0 坐标；不得将候选陈述视为事实。

## 偏差候选

| Claim | Preliminary | Effective | Confidence |
|---|---|---|---|
| `aptitude_capacity` | needs_evidence | needs_evidence | unknown |
| `body_and_blood` | needs_evidence | needs_evidence | unknown |
| `cultivator_aperture` | needs_evidence | needs_evidence | unknown |
| `dao_marks` | remove | needs_evidence | unknown |
| `economy_and_primeval_stones` | revise | needs_evidence | unknown |
| `force_and_social_order` | revise | needs_evidence | unknown |
| `gu_activation` | needs_evidence | needs_evidence | unknown |
| `gu_feeding` | revise | needs_evidence | unknown |
| `gu_is_independent_entity` | retain | needs_evidence | unknown |
| `gu_is_life` | retain | needs_evidence | unknown |
| `gu_ownership` | needs_evidence | needs_evidence | unknown |
| `gu_recipe` | needs_evidence | needs_evidence | unknown |
| `gu_refinement` | revise | needs_evidence | unknown |
| `information_leak` | defer | needs_evidence | unknown |
| `inheritance` | needs_evidence | needs_evidence | unknown |
| `kill_move` | revise | needs_evidence | unknown |
| `lifespan` | revise | needs_evidence | unknown |
| `mortal_immortal_boundary` | defer | needs_evidence | unknown |
| `natal_gu` | remove | needs_evidence | unknown |
| `primeval_essence` | revise | needs_evidence | unknown |
| `rank_and_subrank` | needs_evidence | needs_evidence | unknown |
| `soul` | needs_evidence | needs_evidence | unknown |
| `tribulation_or_ascension` | defer | needs_evidence | unknown |
| `world_scope_and_compression` | retain | needs_evidence | unknown |

## 冲突与未知

- `aptitude_capacity`：未知：verified P0 support is not yet available
- `body_and_blood`：未知：verified P0 support is not yet available
- `cultivator_aperture`：未知：verified P0 support is not yet available
- `dao_marks`：未知：verified P0 support is not yet available
- `economy_and_primeval_stones`：未知：verified P0 support is not yet available
- `force_and_social_order`：未知：verified P0 support is not yet available
- `gu_activation`：未知：verified P0 support is not yet available
- `gu_feeding`：未知：verified P0 support is not yet available
- `gu_is_independent_entity`：未知：verified P0 support is not yet available
- `gu_is_life`：未知：verified P0 support is not yet available
- `gu_ownership`：未知：verified P0 support is not yet available
- `gu_recipe`：未知：verified P0 support is not yet available
- `gu_refinement`：未知：verified P0 support is not yet available
- `information_leak`：未知：verified P0 support is not yet available
- `inheritance`：未知：verified P0 support is not yet available
- `kill_move`：未知：verified P0 support is not yet available
- `lifespan`：未知：verified P0 support is not yet available
- `mortal_immortal_boundary`：未知：verified P0 support is not yet available
- `natal_gu`：未知：verified P0 support is not yet available
- `primeval_essence`：未知：verified P0 support is not yet available
- `rank_and_subrank`：未知：verified P0 support is not yet available
- `soul`：未知：verified P0 support is not yet available
- `tribulation_or_ascension`：未知：verified P0 support is not yet available
- `world_scope_and_compression`：未知：verified P0 support is not yet available

## 当前实现映射

以下仅为只读实现观察，不构成世界事实。每条 claim 最多展示 12 个定位；完整审计由上方规范化哈希冻结。

- `aptitude_capacity`：83 条；data/balance.json#/aptitude_recovery_multiplier<br>docs/lore/adaptation-register.md#line:14<br>docs/lore/canon-index.md#line:20<br>docs/lore/canon-index.md#line:21<br>docs/lore/canon-index.md#line:22<br>docs/lore/content-source-schema.md#line:82<br>docs/lore/content-source-schema.md#line:83<br>docs/lore/content-source-schema.md#line:90<br>docs/wiki/concepts/resource-model.md#line:19<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_preview_service.gd#line:1079<br>scripts/domain/action_preview_service.gd#line:1080（另省略 71 条）
- `body_and_blood`：0 条；—
- `cultivator_aperture`：0 条；—
- `dao_marks`：16 条；scripts/domain/blood_qi_rules.gd#line:7<br>scripts/domain/content_catalog.gd#line:14<br>scripts/domain/content_catalog.gd#line:26<br>scripts/domain/content_catalog.gd#line:39<br>scripts/domain/content_catalog.gd#line:870<br>scripts/domain/core_gu_rules.gd#line:87<br>scripts/domain/cultivator_rules.gd#line:16<br>scripts/domain/gu_instance.gd#line:28<br>scripts/domain/soul_rules.gd#line:5<br>scripts/domain/sword_mark_rules.gd#line:103<br>scripts/domain/sword_mark_rules.gd#line:110<br>scripts/domain/sword_mark_rules.gd#line:116（另省略 4 条）
- `economy_and_primeval_stones`：42 条；docs/lore/content-source-schema.md#line:55<br>docs/lore/game-rule-register.md#line:19<br>docs/lore/game-rule-register.md#line:20<br>docs/lore/game-rule-register.md#line:21<br>docs/wiki/concepts/economy.md#line:5<br>docs/wiki/concepts/gameplay-loop.md#line:38<br>scripts/domain/action_preview_service.gd#line:401<br>scripts/domain/action_preview_service.gd#line:409<br>scripts/domain/action_preview_service.gd#line:976<br>scripts/domain/blood_qi_rules.gd#line:89<br>scripts/domain/blood_qi_rules.gd#line:90<br>scripts/domain/blood_qi_rules.gd#line:92（另省略 30 条）
- `force_and_social_order`：54 条；docs/lore/content-source-schema.md#line:183<br>docs/lore/content-source-schema.md#line:67<br>docs/wiki/concepts/world-model-translation.md#line:26<br>scripts/domain/action_preview_service.gd#line:384<br>scripts/domain/action_preview_service.gd#line:398<br>scripts/domain/action_preview_service.gd#line:409<br>scripts/domain/action_preview_service.gd#line:420<br>scripts/domain/content_catalog.gd#line:1033<br>scripts/domain/content_catalog.gd#line:1034<br>scripts/domain/content_catalog.gd#line:121<br>scripts/domain/content_catalog.gd#line:1363<br>scripts/domain/content_catalog.gd#line:1365（另省略 42 条）
- `gu_activation`：806 条；data/gu.json#/0/v1_effect<br>data/gu.json#/1/v1_effect<br>data/gu.json#/10/role<br>data/gu.json#/100/role<br>data/gu.json#/101/role<br>data/gu.json#/102/role<br>data/gu.json#/103/role<br>data/gu.json#/104/role<br>data/gu.json#/105/role<br>data/gu.json#/106/role<br>data/gu.json#/107/role<br>data/gu.json#/108/role（另省略 794 条）
- `gu_feeding`：152 条；data/gu.json#/0/feeding_cost<br>data/gu.json#/0/feeding_need<br>data/gu.json#/1/feeding_cost<br>data/gu.json#/1/feeding_need<br>data/gu.json#/10/feeding_cost<br>data/gu.json#/10/feeding_need<br>data/gu.json#/11/feeding_cost<br>data/gu.json#/11/feeding_need<br>data/gu.json#/12/feeding_cost<br>data/gu.json#/12/feeding_need<br>data/gu.json#/13/feeding_cost<br>data/gu.json#/13/feeding_need（另省略 140 条）
- `gu_is_independent_entity`：0 条；—
- `gu_is_life`：0 条；—
- `gu_ownership`：0 条；—
- `gu_recipe`：0 条；—
- `gu_refinement`：577 条；data/balance.json#/material_refine_efficiency<br>data/balance.json#/stone_per_t1_material<br>docs/lore/content-source-schema.md#line:102<br>docs/lore/content-source-schema.md#line:114<br>docs/lore/content-source-schema.md#line:13<br>docs/lore/content-source-schema.md#line:23<br>docs/lore/content-source-schema.md#line:51<br>docs/lore/content-source-schema.md#line:94<br>docs/lore/content-source-schema.md#line:99<br>docs/lore/game-rule-register.md#line:27<br>docs/lore/game-rule-register.md#line:28<br>docs/lore/game-rule-register.md#line:29（另省略 565 条）
- `information_leak`：0 条；—
- `inheritance`：0 条；—
- `kill_move`：36 条；docs/lore/adaptation-register.md#line:13<br>docs/lore/game-rule-register.md#line:10<br>docs/lore/game-rule-register.md#line:11<br>docs/lore/game-rule-register.md#line:8<br>docs/lore/game-rule-register.md#line:9<br>docs/wiki/concepts/combat-system.md#line:41<br>docs/wiki/concepts/combat-system.md#line:5<br>docs/wiki/concepts/gameplay-loop.md#line:15<br>docs/wiki/concepts/gameplay-loop.md#line:30<br>docs/wiki/concepts/gameplay-loop.md#line:38<br>docs/wiki/concepts/gu-and-synthesis.md#line:38<br>docs/wiki/concepts/gu-and-synthesis.md#line:42（另省略 24 条）
- `lifespan`：76 条；docs/wiki/concepts/resource-model.md#line:29<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_preview_service.gd#line:1086<br>scripts/domain/action_preview_service.gd#line:1089<br>scripts/domain/action_preview_service.gd#line:1097<br>scripts/domain/action_preview_service.gd#line:635<br>scripts/domain/action_preview_service.gd#line:636<br>scripts/domain/action_preview_service.gd#line:637<br>scripts/domain/action_preview_service.gd#line:638<br>scripts/domain/action_preview_service.gd#line:646<br>scripts/domain/action_preview_service.gd#line:647<br>scripts/domain/action_preview_service.gd#line:656（另省略 64 条）
- `mortal_immortal_boundary`：0 条；—
- `natal_gu`：0 条；—
- `primeval_essence`：110 条；data/balance.json#/stone_to_essence_per_stone<br>data/gu.json#/0<br>data/gu.json#/0/essence_cost<br>data/gu.json#/1<br>data/gu.json#/1/essence_cost<br>data/gu.json#/10/essence_cost<br>data/gu.json#/11/essence_cost<br>data/gu.json#/12/essence_cost<br>data/gu.json#/13/essence_cost<br>data/gu.json#/14/essence_cost<br>data/gu.json#/15/essence_cost<br>data/gu.json#/2/essence_cost（另省略 98 条）
- `rank_and_subrank`：1008 条；data/balance.json#/rank_step_ratio<br>data/gu.json#/0/rank<br>data/gu.json#/1/rank<br>data/gu.json#/10/rank<br>data/gu.json#/100/rank<br>data/gu.json#/101/rank<br>data/gu.json#/102/rank<br>data/gu.json#/103/rank<br>data/gu.json#/104/rank<br>data/gu.json#/105/rank<br>data/gu.json#/106/rank<br>data/gu.json#/107/rank（另省略 996 条）
- `soul`：147 条；data/balance.json#/soul_burst_capacity_ratio<br>data/balance.json#/soul_calm_beast_below<br>data/balance.json#/soul_calm_departure_below<br>data/balance.json#/soul_calm_emotional_below<br>docs/wiki/concepts/combat-system.md#line:31<br>docs/wiki/concepts/resource-model.md#line:27<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_points.gd#line:11<br>scripts/domain/action_points.gd#line:14<br>scripts/domain/action_points.gd#line:15<br>scripts/domain/action_points.gd#line:16<br>scripts/domain/action_preview_service.gd#line:4（另省略 135 条）
- `tribulation_or_ascension`：0 条；—
- `world_scope_and_compression`：268 条；data/schools.json#/blood/starter_gu_ids<br>data/schools.json#/bone/starter_gu_ids<br>data/schools.json#/dream/starter_gu_ids<br>data/schools.json#/earth/starter_gu_ids<br>data/schools.json#/fire/starter_gu_ids<br>data/schools.json#/force/starter_gu_ids<br>data/schools.json#/gold/starter_gu_ids<br>data/schools.json#/heaven/starter_gu_ids<br>data/schools.json#/human/starter_gu_ids<br>data/schools.json#/light/starter_gu_ids<br>data/schools.json#/luck/starter_gu_ids<br>data/schools.json#/qi/starter_gu_ids（另省略 256 条）

## 玩家后果

- `aptitude_capacity`：No aptitude-derived capacity or recovery rule is authorized.
- `body_and_blood`：No new body, bloodline, or injury rule is authorized.
- `cultivator_aperture`：No aperture rule change is authorized by Stage 0.
- `dao_marks`：If approved later, players will not receive unsupported universal dao-mark experience for routine actions.
- `economy_and_primeval_stones`：If verified later, players can buy ordinary goods but must use relationships, knowledge, or risk for non-fungible assets.
- `force_and_social_order`：If verified later, coercion and status choices leave visible future protection, hostility, or pursuit consequences.
- `gu_activation`：No activation-cost or fallback change is authorized.
- `gu_feeding`：If verified later, upkeep choices expose specific food, timing, and failure consequences.
- `gu_is_independent_entity`：If verified later, ownership, transfer, feeding, and loss remain attached to individual Gu.
- `gu_is_life`：If verified later, players must treat Gu as maintained living entities rather than disposable skill tokens.
- `gu_ownership`：No ownership or transfer behavior changes are authorized.
- `gu_recipe`：No recipe unlock or execution rule change is authorized.
- `gu_refinement`：If verified later, players can distinguish knowledge-backed refinement from explicitly risky experimentation.
- `information_leak`：No leak, secrecy, or enemy-learning mechanic is authorized yet.
- `inheritance`：No inheritance reward or access rule change is authorized.
- `kill_move`：If verified later, players must acquire, prepare, and expose a combination instead of pressing an unexplained universal action.
- `lifespan`：If verified later, lifespan spending is exceptional, previewed, and irreversible rather than routine shopping currency.
- `mortal_immortal_boundary`：No ascension boundary or immortal-stage production behavior is authorized.
- `natal_gu`：If later approved, players will not choose a consequence-free core slot detached from cultivation history.
- `primeval_essence`：If verified later, players see combat cost as a view of one world resource rather than two unrelated currencies.
- `rank_and_subrank`：No new rank gate, multiplier, or promotion rule is authorized.
- `soul`：No soul-derived action-point or capacity rule is authorized.
- `tribulation_or_ascension`：No tribulation, ascension, or boss-gate production rule is authorized.
- `world_scope_and_compression`：Players receive a finite run structure without being told that compressed layers are literal world geography or universal law.

## 迁移/废止说明

- `aptitude_capacity`：Defer production work and record the verified scope before proposing a model. Do not promote current aptitude fields into world truth.
- `body_and_blood`：Defer production work pending source verification. Do not infer rules from current data labels.
- `cultivator_aperture`：Defer production work and collect exact P0 support, conditions, and counter-evidence. Keep current behavior unchanged while evidence is unresolved.
- `dao_marks`：Mark generalized mortal dao-mark progression for deprecation; do not delete fields or migrate saves in Stage 0. Exact P0 exceptions must be preserved before any later removal.
- `economy_and_primeval_stones`：Keep promotion economy audit-only and defer any pricing or inventory migration. Do not change shops, prices, materials, or saves in Stage 0.
- `force_and_social_order`：Audit existing NPC and faction outcomes only; defer production changes. One-off current outcomes do not prove the proposed model.
- `gu_activation`：Defer production work and verify support plus exceptions. Do not treat role fallbacks as source facts.
- `gu_feeding`：Audit feeding fields only; defer any data or runtime migration. Promotion materials remain deferred.
- `gu_is_independent_entity`：Audit instance identity only; make no production change before P0 verification. Do not infer independence from existing instance fields.
- `gu_is_life`：Audit current lifecycle behavior only; make no production change before P0 verification. Existing implementation is not evidence for retention.
- `gu_ownership`：Defer and gather P0 support, conditions, and counterexamples. Current inventory representation is observation only.
- `gu_recipe`：Defer and verify source-backed knowledge and execution boundaries. Current recipe data cannot prove the world rule.
- `gu_refinement`：Audit current refinement paths; defer production redesign and migration. Do not modify recipes, materials, or success logic in Stage 0.
- `information_leak`：Defer until exact support, conditions, and representative cases are recorded. Do not infer a mechanic from design prose alone.
- `inheritance`：Defer and verify P0 support and exceptions. Current reward rooms are not authoritative.
- `kill_move`：Audit existing kill-move surfaces only; defer production redesign. Do not modify combat runtime in Stage 0.
- `lifespan`：Audit lifespan payment surfaces only; defer runtime and economy migration. No production price or cost changes in Stage 0.
- `mortal_immortal_boundary`：Defer until exact P0 evidence and conditions are complete. Do not approximate the boundary from rank fields.
- `natal_gu`：Deprecate the arbitrary-slot hypothesis in future design; preserve current saves and runtime until a separately approved migration exists. No production field or save migration occurs in Stage 0.
- `primeval_essence`：Audit dual-resource semantics only; defer any migration until evidence and a later slice are approved. Do not alter essence or true-qi runtime state in Stage 0.
- `rank_and_subrank`：Collect exact support and exceptions before adjudicating progression semantics. F1 and Q8-G remain audit-only.
- `soul`：Defer and collect exact P0 support, conditions, and counterexamples. Current soul fields are implementation observations only.
- `tribulation_or_ascension`：Defer until exact P0 evidence and a later-stage design are approved. Do not equate current boss gates with ascension.
- `world_scope_and_compression`：Retain as an audit hypothesis only; defer production authorization until source boundaries are verified. Five-layer structure is not source evidence.

Legacy dispositions:

- `f1_pity` → `audit_only`：F1 Pity is historical implementation context and cannot authorize Stage 0 production behavior.
- `promotion_economy` → `defer`：Promotion economy remains deferred until source evidence and the later economy slice are adjudicated.
- `promotion_materials` → `defer`：Promotion materials remain deferred until source evidence and the later refinement slice are adjudicated.
- `q8g_promotion_chain` → `audit_only`：Q8-G is retained only as an audit trail and is not a production-ready world rule.
- `school_promotion` → `defer`：School promotion remains deferred while school-as-class semantics are under review.

## Stage 0 Gate

- 结果：**NO_GO**
- Claims：24（high impact: 24）
- 未解决高影响项：24
- Blockers：high-impact complete references 0 < 20<br>high-impact claims missing complete P0 references: aptitude_capacity, body_and_blood, cultivator_aperture, dao_marks, economy_and_primeval_stones, force_and_social_order, gu_activation, gu_feeding, gu_is_independent_entity, gu_is_life, gu_ownership, gu_recipe, gu_refinement, information_leak, inheritance, kill_move, lifespan, mortal_immortal_boundary, natal_gu, primeval_essence, rank_and_subrank, soul, tribulation_or_ascension, world_scope_and_compression<br>unresolved high-impact claims: aptitude_capacity, body_and_blood, cultivator_aperture, dao_marks, economy_and_primeval_stones, force_and_social_order, gu_activation, gu_feeding, gu_is_independent_entity, gu_is_life, gu_ownership, gu_recipe, gu_refinement, information_leak, inheritance, kill_move, lifespan, mortal_immortal_boundary, natal_gu, primeval_essence, rank_and_subrank, soul, tribulation_or_ascension, world_scope_and_compression
- 生产改动授权：否。Stage 0 未通过前不得将候选裁定写入运行时代码或数据。
