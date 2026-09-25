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
