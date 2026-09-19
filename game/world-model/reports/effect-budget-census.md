# Effect Budget Census (P3-A, read-only)

> All numbers computed by `game/world-model/tools/audit_effect_budget.py` from upstream data. No hardcoded constants. No PASS/FAIL verdicts — inversion criteria await L1 ruling.

- gu total 802 / handwritten 61 / fallback 741
- ranks: {1: 220, 2: 157, 3: 180, 4: 97, 5: 147, 10: 1}
- roles: {'attack': 379, 'defense': 100, 'movement': 92, 'healing': 80, 'recon': 78, 'logistics': 73}
- handwritten kinds: {'strike': 28, 'heal': 11, 'shield': 7, 'shift': 6, 'sword_intent': 5, 'status': 2, 'heal_and_strike': 1, 'weaken_intent': 1}

## 1. Fallback curve vs Rank Power Budget

Budget (balance.json): r1=40, r2=80, r3=160, r4=320, r5=640 (r5/r1 = 16.0x).
Rank-scaled kinds (v1_battle_resolver.gd): ['strike', 'shield', 'heal']. Rule: `amount = base + (rank-1)`; `support_bonus` same; `shift`/`status` flat.

| role | kind | r1..r5 | r5/r1 | budget r1..r5 | gap r5 (budget/fallback) |
|---|---|---|---|---|---|
| attack | strike | 2,3,4,5,6 | 3.0x | 40,80,160,320,640 | 106.7x |
| defense | shield | 3,4,5,6,7 | 2.3x | 40,80,160,320,640 | 91.4x |
| healing | heal | 2,3,4,5,6 | 3.0x | 40,80,160,320,640 | 106.7x |
| logistics | heal | 1,2,3,4,5 | 5.0x | 40,80,160,320,640 | 128.0x |
| movement | shift | 1,1,1,1,1 | 1.0x | 40,80,160,320,640 | 640.0x |
| recon | status | 1,1,1,1,1 | 1.0x | 40,80,160,320,640 | 640.0x |

- attack/strike, defense/shield, healing/heal scale +1/rank (3.0x / 2.3x / 3.0x); logistics/heal base 1 scales 1..5 (5.0x); movement/shift and recon/status flat 1.0x.
- recon base carries `support_school: self` + `support_bonus: 1`, also +1/rank (r1..r5 = 1..5), injected as the gu school at resolve time.
- Budget grows 16x while fallback grows 1.0x–5.0x: fallback is a flat survival floor, not a budget share. Any per-rank share formula is L1's call.

## 2. Handwritten coverage matrix (role, kind) x rank

| role | kind | rank | n | min | max | ids |
|---|---|---|---|---|---|---|
| attack | heal_and_strike | 1 | 1 | 1 | 1 | blood_bat_gu |
| attack | strike | 1 | 8 | 1 | 4 | blood_atk_1_08_gu, blood_droplet_gu, blood_farewell_gu, force_gu, moonlight_gu, small_light_gu, sword_atk_1_05_gu, sword_atk_1_06_gu |
| attack | strike | 2 | 12 | 3 | 4 | fire_atk_2_01_gu, moon_glow_gu, moon_ray_gu, sword_atk_2_12_gu, sword_atk_2_13_gu, sword_atk_2_19_gu, sword_atk_2_20_gu, sword_atk_2_26_gu, sword_atk_2_27_gu, sword_atk_2_33_gu, sword_atk_2_34_gu, sword_atk_2_40_gu |
| attack | strike | 3 | 1 | 2 | 2 | water_atk_3_05_gu |
| attack | strike | 4 | 1 | 5 | 5 | sword_atk_4_01_gu |
| attack | strike | 5 | 5 | 6 | 8 | blood_atk_5_02_gu, qi_atk_5_02_gu, sword_atk_5_02_gu, sword_atk_5_03_gu, sword_atk_5_04_gu |
| attack | strike | 10 | 1 | 999 | 999 | test_slay_gu |
| attack | weaken_intent | 3 | 1 | 2 | 2 | wisdom_atk_3_13_gu |
| defense | shield | 1 | 3 | 3 | 3 | blood_def_1_21_gu, stone_shell_gu, sword_def_1_07_gu |
| defense | shield | 3 | 4 | 5 | 5 | sword_def_3_14_gu, sword_def_3_21_gu, sword_def_3_28_gu, sword_def_3_35_gu |
| defense | status | 2 | 1 | 1 | 1 | soul_def_2_10_gu |
| healing | heal | 1 | 2 | 2 | 2 | bear_strength_gu, sword_heal_1_09_gu |
| healing | heal | 4 | 4 | 5 | 5 | sword_heal_4_16_gu, sword_heal_4_23_gu, sword_heal_4_30_gu, sword_heal_4_37_gu |
| logistics | heal | 1 | 5 | 1 | 1 | sword_log_1_11_gu, sword_log_1_18_gu, sword_log_1_25_gu, sword_log_1_32_gu, sword_log_1_39_gu |
| movement | shift | 1 | 2 | 1 | 1 | blood_mov_1_22_gu, sword_mov_1_08_gu |
| movement | shift | 3 | 4 | 1 | 1 | sword_mov_3_15_gu, sword_mov_3_22_gu, sword_mov_3_29_gu, sword_mov_3_36_gu |
| recon | status | 1 | 1 | 1 | 1 | wisdom_rec_1_20_gu |
| recon | sword_intent | 1 | 1 | 1 | 1 | sword_rec_1_10_gu |
| recon | sword_intent | 5 | 4 | 2 | 2 | sword_rec_5_17_gu, sword_rec_5_24_gu, sword_rec_5_31_gu, sword_rec_5_38_gu |

- r3: 180 gu, 10 handwritten; `strike` only `water_atk_3_05_gu` (amount=2) — matches L2 note.
- Empty ranks are fallback-only: e.g. defense r2/r4/r5, healing r2/r3/r5, logistics r2–r5, movement r2/r4/r5, recon r2–r4, attack r4 has 1 handwritten.

## 3. Inversion candidates (two cost apertures, listed separately)

Coarse aperture — group by (role, kind), compare per-rank amount maxima:

- attack/strike: r3 max 2 < r1 max 4 (curve {1: 4, 2: 4, 3: 2, 4: 5, 5: 8, 10: 999})

Fine aperture — same check inside exact cost-structure groups (value/essence_cost/true_qi_cost/feeding_cost, MISS = field absent, never 0):

- none

- Only-coarse (vanish under same-cost grouping): [('attack', 'strike', 3, 1)]
- Only-fine (appear only under same-cost grouping): none
- Cost-field absence in handwritten 61: {'value': 0, 'essence_cost': 50, 'true_qi_cost': 58, 'feeding_cost': 47}; in all 802: {'value': 0, 'essence_cost': 786, 'true_qi_cost': 799, 'feeding_cost': 783}
- D7 requires same-position + same-cost-structure; L1 to rule which aperture is executable.

## 4. v1_effect field census (61 handwritten)

| field | n | non-scaling dim? | ids |
|---|---|---|---|
| amount | 61 | - | bear_strength_gu, blood_atk_1_08_gu, blood_atk_5_02_gu, blood_bat_gu, blood_def_1_21_gu, blood_droplet_gu, blood_farewell_gu, blood_mov_1_22_gu, fire_atk_2_01_gu, force_gu, moon_glow_gu, moon_ray_gu, moonlight_gu, qi_atk_5_02_gu, small_light_gu, soul_def_2_10_gu, stone_shell_gu, sword_atk_1_05_gu, sword_atk_1_06_gu, sword_atk_2_12_gu, sword_atk_2_13_gu, sword_atk_2_19_gu, sword_atk_2_20_gu, sword_atk_2_26_gu, sword_atk_2_27_gu, sword_atk_2_33_gu, sword_atk_2_34_gu, sword_atk_2_40_gu, sword_atk_4_01_gu, sword_atk_5_02_gu, sword_atk_5_03_gu, sword_atk_5_04_gu, sword_def_1_07_gu, sword_def_3_14_gu, sword_def_3_21_gu, sword_def_3_28_gu, sword_def_3_35_gu, sword_heal_1_09_gu, sword_heal_4_16_gu, sword_heal_4_23_gu, sword_heal_4_30_gu, sword_heal_4_37_gu, sword_log_1_11_gu, sword_log_1_18_gu, sword_log_1_25_gu, sword_log_1_32_gu, sword_log_1_39_gu, sword_mov_1_08_gu, sword_mov_3_15_gu, sword_mov_3_22_gu, sword_mov_3_29_gu, sword_mov_3_36_gu, sword_rec_1_10_gu, sword_rec_5_17_gu, sword_rec_5_24_gu, sword_rec_5_31_gu, sword_rec_5_38_gu, test_slay_gu, water_atk_3_05_gu, wisdom_atk_3_13_gu, wisdom_rec_1_20_gu |
| kind | 61 | - | bear_strength_gu, blood_atk_1_08_gu, blood_atk_5_02_gu, blood_bat_gu, blood_def_1_21_gu, blood_droplet_gu, blood_farewell_gu, blood_mov_1_22_gu, fire_atk_2_01_gu, force_gu, moon_glow_gu, moon_ray_gu, moonlight_gu, qi_atk_5_02_gu, small_light_gu, soul_def_2_10_gu, stone_shell_gu, sword_atk_1_05_gu, sword_atk_1_06_gu, sword_atk_2_12_gu, sword_atk_2_13_gu, sword_atk_2_19_gu, sword_atk_2_20_gu, sword_atk_2_26_gu, sword_atk_2_27_gu, sword_atk_2_33_gu, sword_atk_2_34_gu, sword_atk_2_40_gu, sword_atk_4_01_gu, sword_atk_5_02_gu, sword_atk_5_03_gu, sword_atk_5_04_gu, sword_def_1_07_gu, sword_def_3_14_gu, sword_def_3_21_gu, sword_def_3_28_gu, sword_def_3_35_gu, sword_heal_1_09_gu, sword_heal_4_16_gu, sword_heal_4_23_gu, sword_heal_4_30_gu, sword_heal_4_37_gu, sword_log_1_11_gu, sword_log_1_18_gu, sword_log_1_25_gu, sword_log_1_32_gu, sword_log_1_39_gu, sword_mov_1_08_gu, sword_mov_3_15_gu, sword_mov_3_22_gu, sword_mov_3_29_gu, sword_mov_3_36_gu, sword_rec_1_10_gu, sword_rec_5_17_gu, sword_rec_5_24_gu, sword_rec_5_31_gu, sword_rec_5_38_gu, test_slay_gu, water_atk_3_05_gu, wisdom_atk_3_13_gu, wisdom_rec_1_20_gu |
| support_bonus | 7 | - | blood_atk_1_08_gu, small_light_gu, sword_atk_1_05_gu, sword_atk_1_06_gu, sword_atk_2_20_gu, sword_atk_2_33_gu, wisdom_rec_1_20_gu |
| support_school | 7 | - | blood_atk_1_08_gu, small_light_gu, sword_atk_1_05_gu, sword_atk_1_06_gu, sword_atk_2_20_gu, sword_atk_2_33_gu, wisdom_rec_1_20_gu |
| name | 2 | - | soul_def_2_10_gu, wisdom_rec_1_20_gu |
| aoe | 1 | YES | test_slay_gu |
| condition | 1 | YES | blood_farewell_gu |
| consume_status | 1 | YES | water_atk_3_05_gu |
| delay | 1 | YES | fire_atk_2_01_gu |
| heal | 1 | - | blood_bat_gu |

- `amount` x61: small_light_gu=1; moonlight_gu=3; moon_glow_gu=4
- `kind` x61: small_light_gu='strike'; moonlight_gu='strike'; moon_glow_gu='strike'
- `support_bonus` x7: small_light_gu=2; blood_atk_1_08_gu=1; sword_atk_1_05_gu=1
- `support_school` x7: small_light_gu='light'; blood_atk_1_08_gu='blood'; sword_atk_1_05_gu='sword'
- `name` x2: soul_def_2_10_gu='sealed'; wisdom_rec_1_20_gu='marked'
- `aoe` x1: test_slay_gu=True
- `condition` x1: blood_farewell_gu={'type': 'self_hp_below', 'threshold': 0.5}
- `consume_status` x1: water_atk_3_05_gu={'name': 'marked', 'per_stack': 1}
- `delay` x1: fire_atk_2_01_gu={'turns': 1}
- `heal` x1: blood_bat_gu=1
- Non-rank-scaling dims (`aoe`/`delay`/`condition`/`consume_status`): binary/shape modifiers, not magnitudes — L1 to decide how they grow (slots? tiers? gates?).
- `name` (2: status names) and `heal` (1: heal_and_strike sub-amount) are payload labels, not independent dims.

## 5. Exemption paths (bypass 1-5 rank semantics)

- `test_slay_gu`: rank 10, v1_effect {'kind': 'strike', 'amount': 999, 'aoe': True}, tags ['test'], low_rank_exception True.
- buffs.json `slay_gu_ten`: gu_id='test_slay_gu' (S2 opening buff carrier).
- Catalog rank-cap lines: content_catalog.gd:12: # 十转杀蛊 test_slay_gu）以 low_rank_exception: true 豁免上界，供天梯验收夹具使用。; content_catalog.gd:13: const GU_RANK_MAX := 5; content_catalog.gd:462: elif int(gu["rank"]) > GU_RANK_MAX and not _gu_rank_exempt(gu):; content_catalog.gd:463: errors.append("gu %s rank %d exceeds the %d-turn cap (test-only gu needs low_rank_exception)"; content_catalog.gd:464: % [gu["id"], int(gu["rank"]), GU_RANK_MAX]); content_catalog.gd:1707: ## 以 low_rank_exception 显式声明，突破 1..5 转门禁而不污染生产数据语义。; content_catalog.gd:1709: if bool(gu.get("low_rank_exception", false)):
- Grammar pipeline aoe line: `##   - 遗留兼容：effect.aoe == true 等价 selector "enemy_all"（test_slay_gu 现状）。` (aoe==true resolves as selector enemy_all).
- rank>5 gu: [('test_slay_gu', 10)]; low_rank_exception gu: ['test_slay_gu']; tags=test gu: ['test_slay_gu']
- can_activate: `low_rank_exception or cultivator_rank >= gu_rank` (cultivator_rules.gd:28-29). DO NOT delete test_slay_gu (S2 slay_gu_ten carrier).

## Reproduce

```
python game/world-model/tools/audit_effect_budget.py --report game/world-model/reports/effect-budget-census.md
```
