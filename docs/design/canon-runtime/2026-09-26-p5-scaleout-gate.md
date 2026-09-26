# P5 判定：批量扩展第一批（B1–B4）落地

> 日期：2026-09-26。依据：RUL-2026-09-25-001 PRIO P5「先证明知识能够变成规则，再扩大知识数量」+ P4 判定的解锁清单。
> 本批范围：①敌人持蛊化（P4 显式非目标转正）②lab 白名单蛊曲线收敛 ③月芒蛊实体页（P4 挂账转正）④Context Pack 口径修复与扩容队列。
> 每批按 C1–C6 + 换皮测试门禁走；P4 冻结切片（月光三蛊、km_light_converge、MVP 覆写）数值零改动。

## 批次与证据

### B1 敌人持蛊化（换皮风险 #2 收口）

- **世界数据**（`game/data/enemies.json`）：45 敌全部分类——21 只蛊修/异动 `attackSource:"gu"`（装载 `guRefs` 含辅蛊），24 只兽/凡人/尸魔/冰矛守卫 `attackSource:"innate"`；伤害杀招逐 intent 声明组件 `guRefs`（如血脉主教 vein_whip=[血滴子]、族长 clan_wrath=[月光+剑纹刃] 双蛊杀招）；crimson_feast（血宴迸发）、talisman_ignite（符箓）按原著语义判 intent 级 innate（凡兵/天生手段）。
- **显式投影**：`projections.json` 新增 `PROJ-LAB-ENEMY-ATTACK-001`（childKey lab.enemyAttackAmountByGuRank = {1:2,2:3,3:3,4:4,5:4}，parent=balance.effect_budget.default_amount_by_role，forbidWriteBack）——敌方 DPR≈玩家 1/4 是遭遇窗口压缩投影，非第三规则源。
- **构建期校验**（`build_data.mjs`）：Σ 压缩投影 == intent.damage 逐 intent fail-fast；装载/组件蛊 id 可解析性 fail-fast；压缩不变量（≤lab attack 曲线、单调不减）。
- **运行期**（`mvp_logic.js` `enemyIntentDamage`，CombatCore 同源执行器）：attackSource=gu 的 intent 伤害由装载蛊合成（缺索引/投影 fail-fast），innate 走 authored；`resolveEnemyAction`/`previewEnemyDamage` 统一走该解析器；battle.js 敌人面板新增持蛊 chip / 天生手段 chip。
- **断言**：conformance C6-1（31 个伤害杀招合成全覆盖 + attackSource 枚举合法）、C6-2（压缩不变量）；skin-test 换皮-5（改名不变、换组件即变、innate 走 authored、预制 damage 不驱动）。
- **平衡零漂移**：check_balance 49/49（四遭遇窗口不变——lab 三兽 innate、侦察兵唯一伤害意图为凡兵弩）。

### B2 lab 白名单蛊曲线收敛（Derived Content Ratio 玩家面清零）

- 白名单 38 蛊中 11 只战斗蛊由 role 兜底转为**显式 effect**：kind=canon 语义（原著回查），amount 走曲线投影（amount-less，真源唯一）或在库 combat_effects 先例（玉皮 3/白玉 5）。
- **canon_driven_v1（6，带 E:V 锚点）**：玉皮蛊 shield E:V1-009654、白玉蛊 shield E:V1-009986、青藤蛊 strike E:V1-016788（藤鞭甩劈撩扫）、月影蛊 shift E:V1-002648/026794（最擅隐藏+压制真元）、生机草蛊 heal E:V1-017128、自己蛊 inspect E:V3-120396/120404（人祖传：审视内心/另辟新路——role attack→recon canon 刷新）。
- **school_derived 显式（5）**：血针蛊 heal、骨蛊 strike、气纹霭蛊 inspect、浪蛊 strike（名 0 命中，source novel→school_derived 修正）、硬气蛊 shield E:V2-058640（"动用杀招防御下降，此蛊弥补短板"——role attack→defense canon 刷新）。
- **机制**：`build_data.mjs` `resolveEffectAmount`——amount-less 显式效果按 kind→role 曲线投影补 amount（strike→attack、shield→defense、heal→healing、shift→movement；inspect 无量），无映射且缺 amount fail-fast；存量手填 amount（P4 冻结）原样保留。
- **结果**：玩家可触达战斗蛊 100% 显式分类 + provenance 嵌出（DATA.gu[].sourceClass/canonAnchors）；C1-2 升级为"测试端独立复算投影预期"。
- 诚实边界：骨蛊/血针蛊/气纹霭蛊/浪蛊原著无机制依据，按 school_derived 显式声明不冒领 canon（C5-2 兼容）。

### B3 月芒蛊实体页（P4 GATE-③ 注记转正）

- 新建 `lore/wiki/gu/moon-glow-gu.md`（schema v2：5 状态 ST-MOONGLOW-01..05 + 3 事件 EVT-MGLOW-001..003，锚点 E:V1-015710/017052/017144/017148/017316/017470/017502）。
- runtime 重编译：entities 156（moon_glow_gu 合并专页：description + 5 states + provenance）、entity_states 11→16、content_version 82cf2af674eb5877…。
- 门禁：check.ps1 ALL PASSED（check9 1784 E-ID）、check_runtime_benchmark 通过（54 条目无死重）、canon_runtime/canon_pack 14/14、data.js 重刷。
- **独立盲测 3/3**：独立答题代理仅读 `south_border_rank1_combat.json`，三题（合炼配方/三倍与增量不叠加/首炼失败）全对，引用 ST-MOONGLOW-02/03/04 + REL-REFINE-MOONGLOW + CAN-SMALL-LIGHT-001/002；主持人对照判分。

### B4 Context Pack 口径修复与扩容队列

- **根因修复**：并行批 778db228 新增的 PE-008（仙元阶位·六转以上）经 true-qi 域漏入 `south_border_rank1_combat`（凡人一转包）；`compile_runtime.py` `rule_exclude_ids` 补 PE-008 排除（与既有 PE-006/007 同口径），canon_pack「仙域内容不进一转包」测试补 PE-008 断言常驻防回归。
- **扩容登记**（GEN-3 队列）：敌人装载蛊 21 只中仅 8 只有 runtime 实体；pack 实体扩容按死重规则必须与基准题轮换联动——登记为 GEN-3 批（新 pack 或 combat pack 扩实体 + 独立出题），不与本批捆绑。

## 门禁汇总

| 门禁 | 结果 |
|---|---|
| Web 全量 node --test | 259 测试 258 过（唯一失败=P4 时已存在的 B 线在途 data.js 节点标签项，scope 外） |
| check_projection.mjs | 53/53（含 PROJ-LAB-ENEMY-ATTACK-001 端到端） |
| check_balance.mjs | 49/49（遭遇窗口零漂移） |
| lore/wiki/tools/check.ps1 | ALL PASSED（check9 1784 E-ID 段号校验） |
| check_runtime_benchmark.py | 通过（54 pack 条目、19 计分题、无死重） |
| canon_runtime + canon_pack | 14/14 |
| conformance C1–C6 + skin-test | 22/22（C6/换皮-5 为本批新增） |
| 独立 Pack-Only 盲测（月芒蛊新增知识） | 3/3 |

## Derived Content Ratio（P4 基线 → P5 更新）

- 玩家面：lab 白名单 38 蛊——战斗蛊 31/31 显式（17 存量手填 + 11 本批 canon/school 收敛 + 3 P4 切片），support 7 只设计上无战斗效果；白名单内 role 兜底清零。
- 敌人面：45 敌全部分类显式（21 gu + 24 innate），伤害杀招 31 个全部组件合成校验。
- 全库：802 蛊中显式 effect 73（62 存量 + 11 本批）；非白名单广度蛊（loot/shop 池 ~725 只）仍走兜底曲线，收敛随 GEN-3+ 批次推进——本指标持续登记，不作门禁。

## 长尾队列（P5 后续批次，按 C1–C6 门禁逐批走）

1. **GEN-3 基准轮换批**：pack 实体扩容（敌人装载蛊入包）+ 独立出题/答题；月光切片实体页 Wiki-Only 基准（P4 队列项一并处理）。
2. **740 长尾蛊**：非白名单广度蛊的 canon 收敛依赖 roster/wiki 覆盖面扩充（roster-3 未覆盖 id 的证据回查），按池分批。
3. **冰道蛊缺口**：bai_ice_warden frost_javelin 暂判 innate（白名单无冰道蛊）；冰道蛊入池后转 gu 杀招。
4. **P4 遗留非目标**：世界实体派生掉落、节点世界事件生成、Godot legacy 曲线收敛（debt 登记中）。

## 维持条件

本批触及 enemies.json/projections/生成链/语义层契约——月光切片相关任何变更已重跑 C1–C6 + skin-test + check_balance（全过）；P4 GATE 状态维持有效（切片数值零改动，仅分类/provenance 增厚）。

---

# P5 第二批（GEN-3）：敌方装载蛊入包与独立盲测（2026-09-26）

> 兑现本文件 B4 队列项：「pack 实体扩容与基准出题轮换联动」。

## 批次内容

1. **roster-3 补蒸馏**：新增「原文有据·转数未言」段 4 行（熊力蛊/青藤蛊/月痕蛊/骨蛊——存在与机制带 E:V 锚点、转数原文未明言）；熊力/青藤/月痕自「转数未核」名单移账（65→63、9→8），骨蛊系名单漏登补录（统计 270→271）；compile_runtime 新增 `rank_unstated` 状态（豁免 web 漂移门禁，canon_runtime 白名单测试同步扩展）。
2. **四张 mini 实体页**：bear-strength-gu / moon-ray-gu / bone-atk-1-08-gu / wood-atk-1-05-gu（schema v2，各 2 状态行；description 使 Pack-Only 可答）。
3. **pack 扩容**：south_border_rank1_combat 实体 4→8；体积 16601→18968 字符（预算 20000 内，余量 1032）；runtime entities 156→160、entity_states 16→24。
4. **GEN-3 题集**：新增 G 组 4 题（Q20–23，判分依据=新实体+状态行），门槛更新 ≥16/19 → ≥20/23（比例 ≥84% 不变）。

## 门禁

| 门禁 | 结果 |
|---|---|
| check_runtime_benchmark | 通过（66 条目、23 计分题、被引用 53、无死重） |
| check.ps1 | ALL PASSED（check8 55/55 页、check9 1859 E-ID） |
| web 全量 | 259 测试 258 过（唯一失败仍为 B 线预存项） |
| canon_pack 体积/子集/仙域排除 | 通过（18968 < 20000；rank_unstated 豁免漂移门禁） |
| **独立 Pack-Only 盲测（GEN-3）** | **6/6**（新 4 题 + 老题回归 Q1/Q13，负查询无违例） |

## 诚实边界与 GEN-4 队列

- 硬气蛊/自己蛊（canon 有据、非敌人装载）：实体页与入包留 GEN-4。
- 血针蛊/气纹霭蛊/浪蛊/雨蛊/剑纹锋蛊/剑纹刃蛊/古剑蛊：原著 0 命中，维持 pack 外（school_derived 游戏内容），不伪造 canon 身份。
- pack 余量仅 1032 字符：GEN-4 扩容前需评估瘦身（evidence_raw 精简）或拆包（第二 pack + checker 多包校验扩展）。
- 熊力蛊 game 侧 healing 定位 vs "力"名语义属原著到游戏妥协建模，待 L1 评审（bear-strength-gu.md 已登记）。

---

# P5 第三批（GEN-4）：canon 有据蛊入包、pack 瘦身与双盲测（2026-09-26）

## 批次内容

1. **pack 瘦身**：`evidence_raw` 出包（外科式——仅对有 evidence IDs 或 source_line_refs 的规则裁剪，溯源不断；runtime rules.json 全量保留）。pack 18968→18509 字符（10 实体），预算余量恢复到 1491。
2. **硬气蛊/自己蛊入包**：roster-3「原文有据·转数未言」4→6 行；两张 mini 实体页（qi-atk-1-01-gu / human-atk-1-01-gu，即 P5-B2 canon 刷新两蛊的取证落点页）；转数未核 1转 63→61。
3. **冰道谱系落盘**（queue#3 前提）：roster.md 新增「冰道系」——冰道优势在防御明文（原文 50250）；霜妖蛊/冰晶蛊（三转，白凝冰 28000 元石购得）、冰肌蛊（三转防御卓绝、一经练成无须真元支持）、雪女蛊、玄冰蛊/冰墙蛊合炼材。**bai_ice_warden 转化维持挂账**：冰道蛊入游戏池需新增 game 侧 ice school/gu（schools/pools/loot 联动），属产品数据决策，待 L1/L0。
4. **双独立盲测**：
   - runtime 基准四测（Pack-Only）：**4/4**（Q24 硬气蛊联动 KM-003、Q25 自己蛊、回归 Q3/Q4）。
   - **切片实体页 Wiki-Only 基准**（兑现 P4 GATE ① 队列注记，新文件 benchmark-slice-entities.md）：**4/4**（增幅双口径区分、三步+十米、双晋升线取舍、印记变迁）。

## 门禁

| 门禁 | 结果 |
|---|---|
| check_runtime_benchmark | 通过（78 条目、25 计分题、无死重） |
| check.ps1 | ALL PASSED（check8 57/57、check9 1875 E-ID） |
| web 全量 | 259 测试 258 过（唯一失败仍为 B 线预存项） |
| pack 体积/子集/仙域排除 | 通过（18509 < 20000） |
| 独立盲测 ×2 | 4/4 + 4/4 |

## GEN-5 队列

- 独立出题升级（切片基准与 pack 基准的出题代理分离）。
- 冰道蛊游戏池扩展（需 L1/L0：新 gu id + ice school 联动）→ bai_ice_warden 转 gu 杀招。
- pack 实体继续扩容前先做 evidence/source_line_refs 精简评估。

---

# P5 第四批（谱系批）：canon 杀招 10 条与炼蛊晋升线入 lab（2026-09-26）

## 批次内容

1. **杀招 provenance**：26 条 kill_moves 审计——10 条 origin=canon（剑痕索命×4 / 五指拳心剑×3 / 万剑劫×3）全部 canon_driven_v1 化，canon_anchors 原文回读核验（剑痕索命 E:V5-194470/194498 道痕刻印机制、五指拳心剑 E:V4-160166、万剑劫 E:V5-192506 以一化万）+ 剑痕索命家族 canon_refs=[KM-016]（熟练度个案，runtime 可解析）；canon_note 登记仙级→game 转数压缩适配。km_force_avalanche 空 effect 补齐 legacy 展示位（strike 8，与 damage 声明对齐；prefab 不驱动结算，数值收敛仍按 RUL-2026-09-21-010 Q1-B 留待迁移批）。
2. **白名单扩容**：COMBAT_GU_ICON += 10 只剑蛊（全部存量显式 effect，无新数值）；lab gu 77→85。
3. **杀招入 lab**：DATA.killMoves 5→**17**（10 条 canon 杀招全量 + 双刃剑 family + 凝光/血烬/石光壁垒）。
4. **炼蛊线入 lab**：DATA.recipes 4→**7**（月芒/月痕/白玉[canon E:V1-009986]/熊力四线 + 古剑/断剑/匕蛊晋升线）。
5. **断言**：conformance C7-1（canon 杀招 provenance 全量校验）/ C7-2（谱系入 lab 数量门）。
6. **冰道蛊 L1 提案**：`2026-09-26-l1-review-ice-path.md`（新 ice school + 冰肌蛊/霜妖蛊 game 实体 + bai_ice_warden 转化 A/B 选项，待 L1）。

## 门禁

| 门禁 | 结果 |
|---|---|
| web 全量 | 261 测试 260 过（唯一失败仍为 B 线预存项） |
| check_projection / check_balance / progression | 53/53 / 49/49 / OK（平衡零漂移：kit 不变，新增杀招/配方不进开局 kit） |
| conformance C1–C7 | 19/19 |

## 说明

- 新增杀招不进开局装备（state.equipped 不变），玩家在 killmove 页/战斗中按组件可见可用——行为面通过 check_progression_loop 验证。
- 剩余 9 条 kill_moves（qi_surge/myriad_shadows family）组件含 sword_heal/mov 系蛊，留下一批按需扩容。

---

# P5 第五批（冰道裁决 A' 落地）：数据入池、语义显式挂起（2026-09-26）

## L0 裁决执行面

- **批准并落地**：`ice` school（schools.json/school_pools.json，不挂靠 water）；`bing_ji_gu`/`shuang_yao_gu` 入 gu.json（rank 3、拼音 id、E:V1-023066/023222/023110/023148 锚点、names.json 中文名）；bai_ice_warden `guRefs` 登记持有双蛊 + `gu_note` 裁决注记。
- **否决面执行**：两蛊**不设 v1_effect**（`semantics_pending:"ice_path"` 显式标记，shield/strike 标准 verb 被否决为最终语义，role fallback 无从伪造——两蛊不进 lab 白名单，DATA.gu 无实例）；intent.damage 1 维持不动；`attackSource` 维持 `innate`。
- **语义债务显式化**：effect-execution-contract.md 新增 §9「待实现语义（冰道）」——冰肌蛊=持续/被动防御（无需持续真元，shield 一次落账不覆盖）、霜妖蛊=变身+破特定防御+自爆可后置；verb 扩展按 §4 路径；**完成门禁=敌人真实使用核心差异机制后 attackSource 方可 innate→gu（重跑 C6+balance+换皮）**。debt.md 新增 REVIEW 行。

## 门禁

| 门禁 | 结果 |
|---|---|
| build_data | 85 gu / 7 recipes / 17 killMoves 稳定（ice 双蛊正确不进 lab 数据） |
| web 全量 | 261 测试 260 过（唯一失败仍为 B 线预存项） |
| check_balance / check_projection | 49/49 / 53/53（零漂移） |

## 语义实现验收清单（未来批次）

1. 被动护甲 verb（冰肌蛊）+ 变身/破防/后置自爆语义（霜妖蛊）按 §4 路径落 verb + Golden Case。
2. bai_ice_warden 杀招改由装载蛊驱动 → attackSource innate→gu。
3. C6 合成校验 + check_balance 窗口 + 换皮测试全绿后，本债务行关闭。

---

# P5 第六批（冰道语义落地）：被动护甲入承伤语法、破防表达（2026-09-26）

## 落地面（L0 裁决 A'⑥ 执行）

1. **冰肌蛊被动护甲（语义完整落地）**：`passive_effect:{kind:"armor",amount:2}`（amount 沿用库内 armorValue 先例）——新 `gu_rules.carriedGuPassiveArmor`：持有蛊常驻护甲并入 `resolveProblemHit` 承伤语法（**任意轴生效**、可被 armorBreak 破、与 armorValue 叠加；guRefs 非空+索引缺失 fail-fast）。canon：冰肌一经练成无须真元支持=常驻体质变化，不是催动 effectPlan——故在 passive_effect 而非 v1_effect。source_class 升 canon_driven_v1。
2. **霜妖蛊破防（部分落地）**：`v1_effect:{kind:"strike",armorBreak:2}`（amount-less，消费方接入时走曲线投影）；变身/自爆后置维持 pending（semantics_pending 不撤）。
3. **结算索引完备化**：build_data 嵌出 `DATA.guSemanticsById`（敌人 guRefs 引用蛊全量语义索引——21 只，含不进白名单的冰道双蛊）；main.js 合并进 GU_BY_ID。消除"warden 未来入 lab 即 fail-fast"的地雷；battle 上下文必须携带完整蛊索引成为架构约束。
4. **断言**：C8-1（被动护甲减伤/破甲/叠加/无 guRefs 零变化/未知蛊 fail-fast 五案）、C8-2（霜妖破防表达+数据形状锁死+冰肌分类）。
5. **warden 转化门禁未过**（变身/自爆 pending）：attackSource 维持 innate，debt 行更新进度。

## 门禁

| 门禁 | 结果 |
|---|---|
| web 全量 | 263 测试 262 过（唯一失败仍为 B 线预存项） |
| check_balance | 49/49（零漂移——冰道双蛊不进 lab 数据，护甲语法对现有敌人零变化） |
| conformance C1–C8 | 21/21 |

## 验收点（本批）

- 持冰肌蛊的敌人被 strike 3 打 → 伤 1（armor_tax）；armorBreak 2 → 伤 3（pierce_armor）——护甲真实改变承伤语法。
- 无 guRefs 敌人行为逐位不变（回归零风险）。

---

# P5 第七批（收尾批）：掉落派生入世、Godot 迁移清单、节点事件挂起理由（2026-09-26）

## 1. 世界实体派生掉落（P4 遗留 #2 落地）

- **机制**：`LootRules.rollGuChoices` 新增 `carriedPool`——被击败敌人的装载蛊（P5-B1 的 `guRefs`）在 `gu_chance` 命中后成为首选候选（夺蛊=原著标准战利品语义，adaptation 机制不冒领 canon）；候选池并入装载蛊+原表蛊；rarity 跟被夺蛊自身走。池空（innate 敌人）/装载蛊不在册 → 原表流程逐位不变。
- **接线**：main.js rollVictoryLoot 传 `carriedPool = battle.enemies.flatMap(guRefs)`。
- **门禁**：loot_rules 4/4（20 种子首选必在装载池+原表蛊在候选+不在册回退+空池回退+rarity 跟蛊走）；web 263/264（唯一失败=B 线预存）；check_balance 49/49；progression OK。
- **语义边界**：这是"从世界实体派生"（敌人实体驱动掉落），不是 canon 事实断言——原著夺蛊是普遍行为但具体掉率/候选构造属游戏设计。

## 2. Godot 收敛：迁移清单（代码面维持锁定）

无 Godot 二进制，resolver 改动不可验证——本轮只落盘**精确迁移清单**（debt 行同步），二进制到位后机械执行：

| 字段组 | 消费点 | 迁移目标 |
|---|---|---|
| default_effect_by_role（role→kind+amount） | v1_battle_resolver.gd:45（role 基础动作兜底表） | kind 留守（Q2 指定真源）；amount 改读 balance.effect_budget.default_amount_by_role |
| aptitude_mult | v1_battle_resolver.gd:56 | 迁 balance.json（资质修正属世界数值） |
| boss_layer_mult | battle_command_facade.gd:125 | 迁 balance.json（Boss 层倍率属世界数值） |
| stage_base | content_catalog.gd:1161-1166（校验+分层） | 迁 balance.json（对齐 rank_power_budget） |
| kill_moves amount/effect 预制 | v1_battle_resolver.gd:245/284（legacy_declared_effect） | 对齐 Web 模式：结算=组件合成、prefab 降为展示 |
| regen_pct | content_catalog.gd:359（aptitude.json 消费，非 v1_battle——R0 审计勘误） | 随 aptitude.json 保持，不属本迁移 |

## 3. 节点世界事件生成（P4 遗留 #3）：挂起理由

现有 event 节点（2/41）为手写场景（summary/choices/nextIds 静态接线）。"生成"需要先回答 L1 设计题：事件内容从哪个 canon 源派生（CAN-NANJIANG 规则？实体 clues/reactions？Context Pack 驱动的生成时流程？）、事件对 run 状态的写面（真元/蛊/旗标）。无设计就做生成器=无据内容生产，违背"先知识后数量"原则——登记 debt，待 L1 设计题立案。

## 门禁

web 263/264 · check_balance 49/49 · progression OK · loot_rules 4/4
