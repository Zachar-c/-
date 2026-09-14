# Q8-G Reachability-5 / E6 Loot-Tier Opportunity Audit（实验记录）

> - **性质**：measurement-only 因果调查；inbox = `Q8G_HANDOFF_CURRENT.md` §14（2026-09-13）。
> - **回答的因果链**：E6 实际敌人抽取 → 实际 `battle.enemy_kind` → resolved loot tier → Common 战斗数量与时序 → f1 材料可达性。
> - **状态**：✅ 测量完成。Gate A/B/C/D 自评见 §5。不含 A/B/C/D 产品裁定。

## 1. 实现摘要

- `scripts/acceptance_driver.gd`：opt-in 开关 `PLAYTHROUGH_E6_TIER_AUDIT=1`（独立于 R4 开关），驱动器本地只读变量；逐场输出 `R-5 battle:` 行（stage/node/模板敌/battle.enemy_kind/battle.enemy_kinds/resolved tier/grade/rank/层 rank 区间/生效 weights/材料/实际 tier 的 material_ids/f1_hit/school/outcome），终局输出 `R-5 summary:` 行（inbox §14 全部字段）。
- `resolved_enemy_tier` 以正式结算同源为准：`battle.enemy_kind` 查 `enemy_by_id`；空/未知（多敌战斗）按 LootResolver 口径兜底 `common`——与实际 loot 表选择完全一致。
- `tools/q8g_reachability5_tier_audit.ps1`（新建）：8-seed sweep，逐场日志落 `$env:TEMP/gu-zhenrens-r5-logs/`。未触碰 R4 工具与文档。
- 诚实记录：首次 sweep 脚本有一处 worker Bug（复用了仅在 R4 开关开启时存在的 `R-4 actual gates` 行做正则）→ 首例即 throw；修复为从 `R-5 summary` 行尾 ASCII `gate_b/gate_c` 解析后重跑，exit 0。

## 2. 验证（Gate D：不污染行为）

| 检查 | 方法 | 结果 |
|---|---|---|
| 关开关无污染 | seed 55 force 不设开关 vs R5 前基线 | 漏斗/promotion/Gate 逐字一致 ✅ |
| 开开关零行为差 | seed 55 force 设开关 | Gate/漏斗/promotion 与关开关完全一致 ✅ |
| 确定性 | 同配置复跑 | `R-5 summary` 完全相同 ✅ |
| sweep | 8 局 | exit 0，summary/gates 齐全 ✅ |

## 3. 8-seed 汇总

| seed | 派 | 战斗 | 已结算 c/e/b | 未结算 | common 层位 | common 序号 | 首探前 | 末探后 | visits | f1 | f1_zero | mat/full_ready | 尝试/成功 | Gate B/C |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20260927 | force | 19 | 1/7/4 | 7 | [5] | [16] | 0 | 1 | 4 | 0 | **yes** | 3/0 | 0/0 | FAIL/FAIL |
| 11 | force | 12 | 2/7/2 | 1 | [4,5] | [3,8] | 0 | 2 | 1 | 2 | no | 0/0 | 0/0 | FAIL/FAIL |
| 33 | force | 8 | 1/2/2 | 3 | [4] | [2] | 0 | 0 | 2 | 1 | no | 1/1 | 1/1 | FAIL/FAIL |
| 55 | force | 22 | 4/9/4 | 5 | [1,2,3,3] | [3,4,10,13] | 0 | 0 | 5 | 3 | no | 4/3 | 3/3 | PASS/FAIL |
| 20260927 | sword | 13 | 4/5/2 | 2 | [2,2,2,2] | [1,3,4,5] | 0 | 0 | 4 | 1 | no | 3/2 | 1/1 | FAIL/FAIL |
| 11 | sword | 9 | 1/3/2 | 3 | [4] | [3] | 0 | 0 | 2 | 0 | **yes** | 2/0 | 0/0 | FAIL/FAIL |
| 33 | sword | 8 | 1/2/2 | 3 | [4] | [2] | 0 | 0 | 2 | 0 | **yes** | 1/0 | 0/0 | FAIL/FAIL |
| 55 | sword | 23 | 4/11/4 | 4 | [1,2,3,3] | [3,4,10,13] | 0 | 0 | 5 | 3 | no | 5/4 | 4/4 | PASS/PASS |

合计已结算 86 场：**common 18（20.9%）/ elite 46（53.5%）/ boss 22（25.6%）**——与名义权重 75/25/0 严重倒挂。

## 4. 假设分析（H1–H6，报告层对照，不改生产配置）

### H1 名义 75/25 vs 实际有效分布 —— 不一致，倒挂

名义 `enemy_weights` common:elite = 75:25（3:1）；实际已结算为 1:2.6。见 §3 合计。

### H2 rank 区间过滤结构性削弱 Common 候选 —— **证实，主因**

common 候选敌全部集中在 rank 0–2，而层 rank 区间逐层上移（L1[0,1]→L5[3,5]），把 common 候选逐层清空：

| 层 | rank 区间 | 各主题有效 common 份额 |
|---|---|---|
| L1 | [0,1] | 全主题 100%（elite 候选 0） |
| L2 | [0,2] | 多数 100%；faction 50%（1 common vs 3 elite） |
| L3 | [1,3] | beast 80%；faction 50%；cultivator/anomaly 75%；neutral 100% |
| L4 | [2,4] | **faction 0%**；beast/cultivator 60%；anomaly 75% |
| L5 | [3,5] | **全主题 0%**（common 候选不存在，最高 common rank=2） |

即：L5 的单敌战斗**数学上不可能**滚出 common 敌人 → L5 的 common-table 战斗只能来自多敌兜底（`enemy_kind=""`）。

### H3 theme 池与 fallback 的偏移 —— 证实两个通道

1. **多敌兜底是 common-table 的主力**：多敌战斗 `battle.enemy_kind` 为空 → LootResolver 兜底 common。force 55 的 4 场 common 全部是多敌战斗（`by_actual` 中 `""`=4）；sword 20260927 的 4 场 common 同理（by_layer 全是 L2，`[1,3,4,5]`）。
2. theme 侧：faction 主题 common 候选仅 1 个（`clan_warden` r1），L3 起即被 rank 过滤 → faction 战斗从 L3 起 100% 落 elite 池。

### H4 Common 战斗时序 —— 稀缺 + 两极，且全部不在首次探访前

- 8 局全部 `common_before_first_refinement=0`（驱动器 refine-first 寻路使首次探访极早——测量口径 caveat）。
- `common_after_last_refinement` 6/8 局为 0：common 窗口集中在**探访之间**的中段；例外是 force 11（2 场在末探后）与 force 20260927（1 场，L5 末段）。
- f1=0 三局的窗口错位各不相同：sword 11/33 的唯一 common 窗口在 streak 达标前（第 2/3 场）；force 20260927 的唯一窗口在 L5 末段（streak=9，达标但已在全部探访之后）。

### H5 单一高频敌人主导 —— 证实

`thunder_crown_wolf`（elite，r3）在 force 55 的 22 场中实际出现 6 次（27%）；`clan_elder`（elite）、`thunder_crown_wolf`、boss 类 `miasma_vein_lord`/`blood_vein_bishop` 在 7–8/8 局中出现。单敌战斗被少数 elite/boss 敌主导，多敌战斗则成为 common-table 的唯一稳定来源。

### H6 敏感性（hypothetical，报告层，不写回任何配置）

若各层有效 common 份额回到名义 75%（即 common 候选在 rank 区间内不被清空），按 R4 的 streak+兑现逻辑逐局对照：f1=0 三局的 streak 均在中段（第 4–9 场）越过 3，而 75% 份额下每约 4 场即出现一个 common 兑现窗口——窗口将大量落在中段、即 **末次 refinement 探访之前**（当前实测 0–1 个），三局的 f1 均应在后续探访前被兑现。方向性结论：**Common opportunity 的量与时机同时修复才有效**，只修时序（如 R4 的全战斗累计）或只修单点窗口都不够。此为报告层推演，未做逐场重抽验证，置信度中等。

## 5. Gate 自评（inbox §14）

- **Gate A 数据来源正确：PASS**——resolved tier 与正式结算同源（battle.enemy_kind + enemy_by_id，空 kind 兜底 common）；逐场行可对账模板敌/实际敌/层区间/权重。
- **Gate B 分布可解释：PASS**——common 稀缺的机制=rank 区间把 common 候选逐层清空（L5 为 0）+ 主题池 common 候选稀薄 + 单敌 roll 被 elite 主导；实测份额 21% vs 名义 75%。
- **Gate C 时序可解释：PASS**——common 窗口集中于探访之间的中段（首探前恒 0；末探后 6/8 局为 0）；三局 f1=0 各有明确的窗口错位解释（§3/§4-H4）。
- **Gate D 不污染行为：PASS**——开关三验 + 确定性复跑全过（§2）。

## 6. 剩余不确定性

1. 主题池构成按"层 rank 区间 ∩ theme"静态计算，未逐节点重现 E6 的 salt 序列（报告层对照，非逐场重演）；份额为期望值。
2. H6 敏感性为确定性推演（非逐场重抽），未验证"converted battles 的实际材料内容"。
3. `common_before_first_refinement=0` 受驱动器 refine-first 寻路影响（measurement harness），真实玩家探访时序可能不同。

## 7. A/B/C/D 报告层 hypothetical 对比（inbox #15 白名单任务）

工具：`tools/q8g_reachability5_abcd_comparison.mjs`（Node，无依赖；读 R5 日志 + `loot_tables.json`，纯报告层模拟）。指标：`deliveries`=全程 f1 交付数（自然命中 + hypothetical 兑现）、`first`=首次交付战斗序号、`inWindow`=首次交付发生在末次探访之前。

假设（已写死在脚本头）：B 的 elite 天然 f1 机会由 elite 池 crude 权重份额 ×2 次材料 roll 推得（约 6%/场）；A 的 common 天然命中率取实测值（common 战斗 f1 命中 10/18 ≈ 55%）；A 按 75% 概率把非 boss 结算重采样为 common（种子化 RNG）；D 为 R3 时代共享计数器语义（任意带段目标命中重置）。

| run（实际 f1） | ACTUAL | C 全战斗累计 | B crude挂elite | A 名义份额 | D 共享计数器 |
|---|---|---|---|---|---|
| force 20260927 (0) | 0 | 1（#16，末探后） | 1（#15，末探后） | **5（#8，inWindow）** | 0 |
| force 11 (2) | 2 | 2 | 2 | **7（#1，inWindow）** | 0 |
| force 33 (1) | 1 | 1 | 1 | **3（#1，inWindow）** | 0 |
| force 55 (3) | 3 | 3 | 3 | **8（#1，inWindow）** | 1（#4） |
| sword 20260927 (1) | 1 | 1 | 1 | 2（#4，inWindow） | 0 |
| sword 11 (0) | 0 | 0 | 0 | **2（#1，inWindow）** | 0 |
| sword 33 (0) | 0 | 0 | 0 | 0 | 0 |
| sword 55 (3) | 3 | 3 | 3 | **7（#2，inWindow）** | 0 |

交叉验证：ACTUAL 与驱动器实际 f1 计数逐局相同；C 复现 R4 的唯一兑现（force 20260927 #16）。

对比结论（测量性）：

1. **C 单独无效**（R4 已证，本轮复现）：唯一兑现发生在全部探访之后。
2. **B（w1 挂 elite）在 8 局中几乎不触发**（仅 1 次提前一个战斗位）——w1 级别的通道强度不足。
3. **D（共享计数器回退）对 f1 是有害的**：f2/f3/f4 命中不断重置共享计数，8 局 f1 交付 ≈ 0–1，比现状更差。
4. **A 是唯一实质性收敛方向**：f1=0 三局中 2 局被修复且交付落在探访窗口内；sword 33 因战斗总数过少（8 场）+ RNG 未触发，提示 A 还需配合"short run 下限"考量。
5. 诚实声明：A/B 的材料内容为假设（未逐场重抽 loot），B 的池份额、A 的命中率来自实测统计；工具调试过程（正则 weights 空格、捕获组错位）已修复，修复前后差异仅影响解析完整性。
