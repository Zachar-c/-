# Q8-G 当前 Worker Inbox：Reachability-4 / F1 Opportunity Pity Simulation

> 更新时间：2026-09-13
> 文档性质：零集成文档握手的当前任务入口。
> 本文件只描述已批准的任务边界，不代表 Reachability-4 已通过。

## 1. 主控裁定

Reachability-3 的按 tier 独立计数器实现语义通过，但 F1 可达性目标未通过：R5 sweep Gate B 回落至 2/8，仍有 3 局 f1=0。

当前根因假设：Common 战斗机会偏少，Common-only pity 很难达到 threshold=3。下一步只允许对“全战斗 f1 缺失累计、Common 池兑现”的 hypothetical 方案做测量。

禁止把本任务解释为已批准的正式规则变更。

## 2. 本次任务

执行：`Reachability-4 / F1 Opportunity Pity Simulation`

目标：在不改变正式游戏行为的前提下，回答：

> 如果 f1 缺失计数跨所有有材料的战斗胜利累计，但强制兑现仍只发生在当前 Common loot pool，是否能减少 F1 gap？

## 3. 允许修改范围

只允许修改：

- `scripts/acceptance_driver.gd`：仅增加显式 opt-in 的 measurement-only 分支，默认运行行为必须不变；
- `tools/` 下的 sweep、解析或汇总工具；
- `docs/q8g/` 下的 Reachability-4 实验记录。

如果已有未跟踪的 Reachability-4 工具或文档，先审阅，不要覆盖或重复创建。

## 4. 禁止修改范围

本任务禁止修改：

- `scripts/domain/**`
- `data/**`
- `scripts/presentation/**`
- `tests/**`
- `scripts/domain/run_state.gd`
- 正式 `material_pity` / `material_pity_by_tier` 规则
- `enemies.json` tier
- `pacing.json` / enemy weights
- `balance.json`
- promotion、starter、商店、Soul、战斗或 UI 契约

不得回退共享计数器，也不得通过调整产量解决可达性。

## 5. Hypothetical 规则

维护只存在于测量侧的临时计数：

```text
simulated_f1_absence_streak
```

每场实际 victory：

1. 使用真实 `battle.enemy_kind` 和实际结算 tier；
2. 使用实际材料结果，不重抽正式 loot；
3. 有材料且没有合法 f1 目标：模拟计数 +1；
4. 命中合法 f1：模拟计数清零；
5. 空材料：计数不变；
6. 没有合法 f1 候选：不强制，记录 `candidate_empty`；
7. 当本场实际 tier 为 `common`，且结算前模拟计数 >= pity threshold，且 Common 池存在合法 f1 候选时，仅记录 hypothetical forced f1，不修改正式状态。

合法 f1 必须满足：

```text
当前 school 的 promotion chain
∩ 当前 Common material_pool
∩ quality_band == crude
```

强制结果不得跨学派、跨 tier、跨池或凭空生成。

## 6. 确定性要求

相同以下输入必须得到相同模拟报告：

- seed
- school
- route
- 实际 battle sequence
- 实际 event positions

模拟不得写入：

- `RunState`
- `event_log`
- save
- 正式 loot
- promotion 结果

正常未设置模拟开关时，验收驱动器行为必须与当前基线一致。

## 7. 验收样本

使用：

```text
force: 20260927, 11, 33, 55
sword: 20260927, 11, 33, 55
```

环境：

```text
PLAYTHROUGH_FULL=1
PLAYTHROUGH_COMBAT_FIRST=1
PLAYTHROUGH_F1_OPPORTUNITY_PITY=1
```

每局报告至少包含：

```text
actual_f1_count
simulated_forced_f1_count
actual_common_battle_count
candidate_empty_count
actual 5-stage funnel
actionable Gate B/C
battle tier distribution
simulated streak trace
```

## 8. 验收 Gate

### Gate A：合法性

所有 hypothetical f1 必须是当前学派、当前 Common 池、`crude` 带段的 promotion 材料。

### Gate B：触发准确性

只在模拟计数达到 threshold 后触发；只能在 Common 结算兑现；不得修改正式 loot。

### Gate C：有效性

与 Reachability-3 同 seed 对比，统计：

- f1=0 的局是否减少；
- hypothetical f1 是否出现在后续 refinement 机会之前；
- material_ready / full_ready 是否改善；
- 是否有新拒因；
- 是否出现额外的非 pity 资源增益。

Gate B/C 仍是报告指标，不得因为 hypothetical 结果改善就宣称 Batch 1 Final Gate 通过。

## 9. 停止条件

出现任一情况立即停止，不自行改设计：

- 需要改 `data/**` 或 `scripts/domain/**` 才能完成模拟；
- 需要改变当前分 tier pity 语义；
- 模拟结果不能区分实际和 hypothetical 状态；
- 产生非法材料；
- 需要修改 enemy tier、pacing、产石、promotion cost 或 Soul；
- 不确定下一步应选择 A/B/C/D。

## 10. Worker 交付格式

完成后写入或更新：

```text
`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`
```

报告必须包括：

1. 实际修改文件；
2. 未修改但审阅过的文件；
3. 模拟规则实现摘要；
4. 8-seed 逐局结果；
5. 验收命令与退出码；
6. 与 Reachability-3 的差异；
7. 未完成项和阻塞项；
8. 不得自行给出 A/B/C/D 产品裁定。

## 11. 参考资料

- `AGENTS.md`
- `docs/q8g/Q8G_HANDOFF_2026-09-13.md`
- `docs/q8g/Q8G_REACHABILITY3_F1_PITY.md`
- `docs/q8g/Q8G_BATCH1_FOLLOWUP_REACHABILITY2.md`
- `docs/contracts/2026-09-12-agent-ownership-contract.md`

## 12. 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：允许开始 measurement-only simulation
正式生产规则：禁止修改
最终裁定：等待 Luna 审查 worker report
```

---

# 13. Reachability-4 复核结论（2026-09-13）

Reachability-4 / F1 Opportunity Pity Simulation 已完成复核：

```text
Gate A 合法性：PASS
Gate B 触发准确性：PASS
Gate C 有效性：FAIL
```

8-seed 结果：

```text
hypothetical forced f1：1 次
promotion 改善：0 局
```

唯一一次 hypothetical f1 发生在所有 refinement 探访之后。全战斗 f1 缺失累计不能解决当前单局内的真实断点。

Reachability-4 不进入正式生产实现。不得把 hypothetical 计数写入 RunState，也不得改变当前 `material_pity_by_tier` 生产语义。

复核证据：

- 8 个 seed 使用显式 `--log-file` 等价命令全部退出码 0；
- `guitkx-build`：`compiled=0 errors=0 held=0 total=16`；
- 模拟开关开/关时，force/55 的实际 promotion、漏斗和 Gate 结果一致；
- `tools/q8g_reachability4_f1_pity_sweep.ps1` 默认依赖 `user://logs`，当前机器有 Godot GUI 日志占用问题，后续应修复 harness，但不能把它当成生产规则问题。

---

# 14. 当前任务：Reachability-5 / E6 Loot-Tier Opportunity Audit

## 任务性质

只做 measurement-only 因果调查，不修改正式游戏规则。

目标：解释并量化 Common loot opportunity 稀缺与时序问题，回答：

```text
E6 实际敌人抽取
→ 实际 battle.enemy_kind
→ resolved loot tier
→ Common 战斗数量与时序
→ f1 材料可达性
```

## 允许修改

只允许修改：

- `scripts/acceptance_driver.gd`：仅增加 opt-in、只读测量字段；
- `tools/` 下的分析、汇总或日志解析工具；
- `docs/q8g/` 下的 Reachability-5 实验记录；
- 如确有必要，可新增临时测量脚本，但必须不进入正式运行路径。

已有未跟踪的 Reachability-4 工具和文档不得覆盖；先保留其历史结果。

## 禁止修改

本任务禁止修改：

- `scripts/domain/**`；
- `data/**`；
- `scripts/presentation/**`；
- `tests/**`；
- `scripts/domain/run_state.gd`；
- `data/enemies.json`；
- `data/pacing.json`；
- `data/balance.json`；
- `data/loot_tables.json`；
- 正式 pity、掉落、敌人 tier、E6 权重、战斗、商店、Soul 或 promotion 规则。

不得因为测量结果直接实施 A/B/C/D 任一产品修复。

## 必须记录的数据

每场实际战斗记录：

```text
stage
node_id
node_template_enemy_kind
battle.enemy_kind
battle.enemy_kinds
resolved_enemy_tier
resolved_enemy_grade
resolved_enemy_rank
pacing.enemy_rank_min
pacing.enemy_rank_max
effective_tier_weights
material_pool_tier
material_ids
actual_f1_hit
current school
```

每局汇总：

```text
battle_count_by_resolved_tier
battle_count_by_node_layer
battle_count_by_template_enemy
battle_count_by_actual_enemy
common_battle_indices
common_battle_layers
common_battle_before_first_refinement
common_battle_after_last_refinement
f1_count
f1_zero
refinement_visits
material_ready
full_ready
promotion_attempts
promotion_successes
Gate B
Gate C
```

关键要求：`resolved_enemy_tier` 必须以正式 loot 结算实际使用的 `battle.enemy_kind` 为准，不得只读节点模板。

## Hypothesis 分析

只允许做离线或报告层对照，不改变生产配置：

1. 当前 root `enemy_weights` 的名义值与实际有效分布是否一致；
2. rank 区间过滤后 Common 候选是否被结构性削弱；
3. `theme` 池和 fallback 是否导致实际 tier 偏移；
4. Common 战斗是稀缺、过早、过晚，还是 refinement 之后才出现；
5. 是否存在单个高频敌人主导 tier 分布；
6. 如果只在报告层模拟不同有效 tier 分布，Common opportunity 是否足以改变 f1 gap。

可做敏感性模拟，但必须标记为 hypothetical，且不得把模拟值写回 `pacing.json` 或 `enemies.json`。

## 验收样本

继续使用同一组 8 seed：

```text
force: 20260927, 11, 33, 55
sword: 20260927, 11, 33, 55
```

统一设置：

```text
PLAYTHROUGH_FULL=1
PLAYTHROUGH_COMBAT_FIRST=1
```

使用真实当前规则跑出 trace，再做报告层统计。不得更换 seed、寻路策略、撤退口径或生产配置。

## Gate

### Gate A：数据来源正确

实际 tier、敌人、节点模板和 loot pool 的来源关系可逐场对账。

### Gate B：分布可解释

能解释 Common/Elite/Boss 的实际数量和层位分布，特别是 Common 战斗为何只有 1–4 场。

### Gate C：时序可解释

能判断 Common 战斗是否发生在 refinement 探访之前、之后，或根本没有后续兑现窗口。

### Gate D：不污染行为

测量开关开/关时，实际 loot、RunState、event_log、promotion、漏斗和 Gate 完全一致。

## 停止条件

出现以下任一情况必须停止并回报，不自行修复：

- 需要修改 `enemies.json` tier；
- 需要修改 `pacing.json` 或 E6 权重；
- 需要把 f1 挂入 Elite 池；
- 需要改变 `material_pity_by_tier` 语义；
- 需要改变 battle stone、Elite cost 或战斗难度；
- 数据来源仍无法区分节点模板敌人与实际战斗敌人；
- 不确定是否应进入 A/B/C/D 产品批次。

## Worker 回写

完成后更新：

```text
`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`
```

并新增：

```text
`docs/q8g/Q8G_REACHABILITY5_E6_LOOT_TIER_AUDIT.md`
```

报告不得自行选择 A/B/C/D，只报告数据、因果证据、测试结果和剩余不确定性。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：允许开始 measurement-only E6 opportunity audit
正式生产规则：禁止修改
```

---

# 15. Reachability-5 复核结论（2026-09-13）

Reachability-5 / E6 Loot-Tier Opportunity Audit 已完成独立复核。

## 复核结果

```text
Gate A 数据来源正确：PASS
Gate B tier 分布可解释：PASS
Gate C Common 时序可解释：PASS
Gate D measurement-only 不污染行为：PASS
```

同一组 8 seed 使用显式 `--log-file` 方式重跑，8/8 局退出码为 0，`R-5 summary` 均生成。

已结算战斗合计 86 场：

```text
common：18（20.9%）
elite：46（53.5%）
boss：22（25.6%）
```

名义 enemy weights 为 common/elite = 75/25，但实际结算分布倒挂，主要原因不是 `settle_victory` 取错来源，而是 E6 候选池经过 rank 区间过滤后，Common 候选在深层逐渐消失：

- L5 `[3,5]` 内所有主题的 Common 候选为 0；
- L4 faction 的 Common 候选为 0；
- Common loot pool 的稳定来源主要是多敌战斗 `battle.enemy_kind == ""` 的 Common fallback；
- `thunder_crown_wolf` 等高频实际敌人为 elite，不能仅因可达性问题直接改 tier。

## 关键时序事实

- 8 局均没有 Common 战斗发生在第一次 refinement 探访之前；
- 6/8 局没有 Common 战斗发生在最后一次 refinement 探访之后；
- f1=0 的三局均有明确解释：Common 窗口过早且未达 threshold，或 Common 窗口出现在全部 refinement 探访之后；
- Reachability-4 的“全战斗 f1 缺失累计”因此不具备足够的兑现机会。

## 当前产品裁定

本报告只证明了机会分布根因，不批准以下任何生产改动：

- 修改 `data/enemies.json` 的 tier；
- 修改 `data/pacing.json` 或 E6 enemy weights；
- 将 f1/crude 挂入 Elite loot pool；
- 修改 `material_pity_by_tier` 语义；
- 回退共享 pity counter；
- 修改战斗元石、Elite 代价、战斗难度或 promotion 规则。

A/B/C/D 必须另行形成方案并由 Luna 裁定，worker 不得从审计结果自行进入施工。

## 当前任务状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，测量完成
生产规则：冻结
下一步：等待新的产品方向裁定或 measurement-only intervention comparison
```

## Worker 回写要求

ZCode 下一步不得修改生产代码或数据。若继续工作，只能进行：

- A/B/C/D 的报告层 hypothetical comparison；
- 不同 Common opportunity 分布的敏感性模拟；
- H6 逐场重演以提高置信度；
- 现有审计工具的日志参数修复；
- 文档和报告更新。

若需要改变 `scripts/domain/**`、`data/**`、`RunState`、正式 pity、E6、pacing 或 battle 规则，必须先停止并等待新的明确裁定。

---

# 16. Reachability-5 A/B/C/D 报告层对比复核（2026-09-13）

ZCode 已完成并回写 A/B/C/D 的 measurement-only hypothetical comparison；我已独立运行：

```text
node tools/q8g_reachability5_abcd_comparison.mjs
```

输出与报告一致。

## 对比结论

### C：全战斗 f1 缺失累计

```text
8 局中仅 1 次 hypothetical 兑现
```

兑现仍发生在全部 refinement 探访之后，不能解决 promotion 转化问题。

### B：将 crude/f1 以小权重挂入 Elite 池

报告层假设下只产生极少提前交付，强度不足，不能作为当前主方案。

### D：回退共享计数器

在当前报告层模型中对 f1 交付没有改善，且会重新引入跨 tier 耦合；不批准回退。

### A：恢复 Common opportunity

A 是目前唯一显示出实质性收敛的方向：在报告层假设下，f1=0 的 3 局中修复 2 局，并且交付时点落在 refinement 探访窗口内。

但 A 当前仍只是候选方向，原因：

- A 同时可能涉及 E6 effective tier distribution、rank 过滤、pacing 或敌人 tier；
- 报告层 A 使用名义 75% Common 份额重采样，尚未逐场重演真实 enemy roll、loot roll、stone reward 和 Elite cost；
- sword/33 在假设 A 下仍未触发，短局边界尚未解决；
- 修改 `enemies.json` 或 `pacing.json` 会影响多个系统，不能直接由这份敏感性分析授权。

## 当前裁定

```text
A：CONDITIONAL，仅批准继续做拆变量的 measurement-only preflight
B：不批准生产实现
C：不批准生产实现
D：不批准回退
```

不得把 A 的 hypothetical 结果写成“Gate B/C 已通过”，也不得直接修改任何生产数据。

## 下一阶段建议

如继续执行，只能立项：

```text
Reachability-6 / Common Opportunity Intervention Preflight
```

其任务必须拆成独立变量并只做报告层模拟：

1. rank-filter sensitivity：只模拟放宽 Common 候选的层位覆盖，不改数据；
2. effective enemy-weight sensitivity：只模拟 Common/Elite 有效份额变化，不改配置；
3. fallback-channel sensitivity：只统计多敌 fallback Common 的贡献，不改 fallback 规则；
4. timing sensitivity：只模拟 Common 机会提前到 refinement 探访前的效果，不改地图拓扑。

每个变量单独报告，禁止把多个假设打包成 A 综合修复。

## 当前任务状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与 hypothetical 对比完成
A：唯一候选方向，但尚未批准生产施工
生产规则：冻结
下一步：等待 Reachability-6 measurement-only preflight 或新的产品裁定
```

Worker 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 17. Reachability-6 复核结论（2026-09-13）

Reachability-6 / Common Opportunity Intervention Preflight 已完成独立复核：

```text
四个单变量报告层模拟：均运行成功
生产代码/数据：零修改
```

独立验证命令：

```text
node tools/q8g_reachability6_preflight.mjs
```

输出为 `8 runs`、`f1_zero runs = 3`，且与 `Q8G_REACHABILITY6_PREFLIGHT.md` 记录一致。

## 结果

### S1：rank-filter sensitivity

```text
baseline：1/3 f1=0 局被修复
L4 单独放宽：2/3
L5 单独放宽：2/3
L4 + L5 放宽：3/3
L3 + L4 + L5 放宽：3/3
```

结论：单层修补不足；L4+L5 是报告层模型中修复全部 f1=0 局的最小组合。该结果不能直接授权修改敌人 tier、rank 区间或 E6 规则。

### S2：effective enemy-weight sensitivity

统一 Common 份额扫描显示：

```text
0.21：结果受重采样方差影响，不代表现状已修复
0.40：2/3
0.60：2/3
0.75：3/3，7/8 局首次交付在 refinement 窗口内
0.90：3/3，7/8 局首次交付在 refinement 窗口内
```

`0.75` 是报告层中较稳定的有效份额目标，但这只是敏感性参数，不是批准写入 `pacing.json` 的数值。

### S3：fallback-channel sensitivity

实际 Common-table 胜利来源：

```text
多敌 fallback：9/18（50%）
单敌滚出 Common：9/18（50%）
```

多敌 fallback 已承担一半 Common opportunity；不能在没有新证据的情况下删除或改变该通道。

### S4：timing sensitivity

保持 Common 数量不变时：

```text
全部聚簇在首次探访之前：0/3 f1=0 局修复
从第 1 场均匀分布：3/3 f1=0 局修复，7/8 局窗口内交付
```

结论：数量和时序是独立变量；“堆量但集中在错误时点”仍然失败。

## 当前裁定

```text
A：CONDITIONAL，继续允许 measurement-only 拆变量验证
B：不批准生产实现
C：不批准生产实现
D：不批准回退
```

A 的有效形态现在收敛为：

```text
恢复 L4/L5 的 Common 候选覆盖
+ 保持 Common opportunity 在 refinement 之前/期间均匀出现
+ 处理短局边界
```

但以下内容仍未获批准：

- 修改 `data/enemies.json` 的 tier；
- 修改 `data/pacing.json` 的 rank 区间或 enemy weights；
- 修改 E6 的正式抽取语义；
- 将 `0.75` 写成正式平衡数值；
- 直接增加 refinement 节点或调整地图拓扑；
- 修改正式 pity、战斗元石、Elite cost 或 promotion 规则。

## 下一步允许范围

如果继续工作，只能开展新的 measurement-only 预审，重点为：

1. 多 seed 重复 R6，给 `0.60/0.75/0.90` 和 L4/L5 覆盖组合提供置信区间；
2. 对 sword/33 型短局做单独短局边界分析；
3. 把 S1 的 rank 覆盖与 S2 的有效份额拆成互斥实验，避免把两种机制混成一个 A 包；
4. 评估现有路线下 Common opportunity 是否天然能落在 refinement 之前/期间；
5. 继续保留现有 R4/R5/R6 工具为实验工具，不写入正式规则。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：四变量 preflight 完成，A 仍为 CONDITIONAL
生产规则：冻结
下一步：等待新的产品裁定或多 seed measurement-only 置信度批次
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 18. Reachability-6 多种子置信度批次复核（2026-09-13）

ZCode 已完成 inbox §17 允许的多种子 measurement-only 扩展；我已独立运行：

```text
node tools/q8g_reachability6_preflight.mjs
```

输出：

```text
16 runs（batch1 8 + batch2 8）
f1_zero runs = 3
short runs (<15 battles) = 6
natural timing：4/16 局存在 Common 战斗早于首次 refinement 探访
```

## 结果

### COVERAGE 边际

```text
actual：2/3 f1_zero 局修复，short_zero_unresolved=1
+L4：1/3，short_zero_unresolved=1
+L5：3/3，short_zero_unresolved=0
+L4+L5：3/3，short_zero_unresolved=0
+L3+L4+L5：3/3，short_zero_unresolved=0
```

报告层模型中，`+L5` 已经达到与 `+L4+L5` 相同的 f1=0 修复数；但这仍是基于当前单一 RNG 路径和观测战斗序列的 hypothetical coverage，不授权直接改动 L5 rank 过滤。

### SHARE 边际

```text
share=0.21：2/3，short_zero_unresolved=1
share=0.40：2/3，short_zero_unresolved=1
share=0.60：3/3，short_zero_unresolved=0
share=0.75：3/3，short_zero_unresolved=0，15/16 窗口内交付
share=0.90：3/3，short_zero_unresolved=0，15/16 窗口内交付
```

`0.60` 是报告层首次消除短局遗留的阈值区间，`0.75` 提供更高的窗口内交付比例；两者都不是批准写入生产配置的数值。

### 短局边界

16 局中 6 局少于 15 场战斗。两个 f1=0 短局（sword/11、sword/33）都只有 1 个 Common 战斗且位于 L4；这说明 pity 语义无法单独覆盖短局的 opportunity 不足。

### 置信度限制

当前样本仍为：

```text
16 局
单一 RNG 路径
报告层点估计
```

因此结果可用于方向排序，不足以证明最终平衡数值或生产规则。

## 当前产品裁定

```text
A：CONDITIONAL，允许进入“候选形态设计”
B：不批准
C：不批准
D：不批准
```

A 的候选形态优先级更新为：

1. 优先研究 `L5 Common opportunity coverage`；
2. 其次研究全非 Boss 有效 Common 份额至少 `0.60` 的方式；
3. `0.75` 仅作为 sensitivity reference，不是正式目标值；
4. 任何方案必须单独处理 sword/33 型短局与 refinement 时序；
5. 不允许把 rank 覆盖、enemy weight、fallback、地图时序一次性打包修改。

## 下一步

下一阶段允许立项：

```text
Reachability-7 / A-Shape Design Preflight
```

仍为 measurement-only，目标是比较以下候选的副作用，不改生产配置：

- `A1 L5-only coverage`：只模拟 L5 Common 候选恢复；
- `A2 effective-share floor`：只模拟非 Boss Common 份额下限，建议扫描 `0.60/0.75`；
- `A3 short-run guard`：只模拟短局的 Common opportunity 下限或前置窗口；
- `A4 timing-only`：只模拟 Common 机会在 refinement 前/期间的移动；
- `A5 combined`：暂不运行，除非 A1–A4 单变量结果完成并另行批准。

Reachability-7 必须同时报告：

```text
f1=0 修复率
首次交付是否在 refinement 窗口内
短局遗留数
总材料件数变化（hypothetical 只计分布，不得增加固定产量）
元石/Elite cost 的潜在影响标记
```

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A 仍为 CONDITIONAL
Reachability-7：允许开始 measurement-only A-shape design preflight
生产规则：冻结
```

ZCode 不得在 Reachability-7 阶段修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 19. Reachability-7 复核结论（2026-09-13）

Reachability-7 / A-Shape Design Preflight 已完成独立复核：

```text
性质：measurement-only
生产代码/数据：零修改
独立命令：node tools/q8g_reachability7_ashape_preflight.mjs
```

## 关键发现

### 1. L4/L5 是份额悬崖，不是零覆盖

16 局 R5 复现流的 settled non-boss Common 份额：

```text
L1：50.0%
L2：51.6%
L3：37.9%
L4：15.4%
L5：12.5%
```

五层均存在非零 Common 通道，因此不能把问题描述为“L4/L5 没有 Common 候选”。A1 实际上是提高 L5 现有通道的 magnitude，而不是打开一个不存在的 on/off 通道。

### 2. Pity 单独无法覆盖当前 f1=0 短局

3 个 f1=0 局各只有 1 个 Common 胜场；当前 pity 至少需要第 4 个 Common 胜场才能兑现。因此仅修改 pity 计数语义不能解决这三局。

### 3. 单变量 hypothetical 结果

```text
OBSERVED：事实上的 f1=0 局为 0/3
MODEL ACTUAL：64 个确定性复现流的均值为 1.55/3
A1 L5 coverage：约 1.84–2.28/3，视 coverage 份额而定
A2 share floor 0.60：约 2.50/3
A2 share floor 0.75：约 2.78/3
```

`A2@0.75` 的 hypothetical 结果最好，但会使 elite 暴露显著下降约 71.6%，同时降低 Elite Gu 期望和 Elite cost 暴露；不能直接视为平衡目标。

### 4. 生产数量红线未被 hypothetical 触碰

所有形状的材料件数均为 `214`，差值为 `+0`。这是分布转换，不是固定掉落产量增加；但品质带段、Gu 掉率和 Elite cost 暴露发生变化，必须单独评估。

### 5. A1 与 A2 不再视为两个独立机制

A1（L5 coverage）和 A2（全层 Common share floor）都属于：

```text
提高 Common opportunity 的有效份额
```

区别只是作用范围，不应在正式批次中作为两个互不相关的机制同时打包。

A3（短局人口/机会下限）与 A4（时序调整）才是与 Common 份额正交的变量。

### 6. 样本与模型限制

```text
16 局真实审计语料
64 个确定性复现流
报告层模型
单一 RNG 路径来源
天然 f1 命中率使用 pooled 观测值 0.556
```

该结果足够用于方向排序和副作用排序，但不足以批准正式平衡数值、敌人 tier、pacing、E6 权重或地图改动。

## 当前裁定

```text
A：CONDITIONAL，仅批准候选形态设计，不批准生产施工
B：不批准
C：不批准
D：不批准
```

A 的候选形态收敛为：

```text
提高 Common opportunity 份额
+ 明确是否只作用于 L5 或所有深层
+ 单独处理短局 opportunity 下限
+ 单独处理 refinement 前后的时序
```

禁止把以下内容直接作为正式参数：

```text
0.60
0.75
L4/L5 rank 放宽
任何 enemy tier 重分类
任何 pacing 或 E6 weights 修改
```

## 下一阶段

下一步只允许形成新的设计预审或候选方案文档，不进入生产施工：

1. 明确 A 的作用对象：只改 L5、L4+L5，还是全层 share floor；
2. 明确 A 的副作用接受度：Elite cost 暴露、Gu 期望、材料品质带段；
3. 设计短局 guard 的候选，但仅做 hypothetical，不增加固定产量；
4. 设计 refinement 时序候选，但不增加节点或修改正式地图；
5. 为候选方案准备 32+ 局重复验证计划；
6. 继续保留 A5 combined 为未批准状态。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
生产规则：冻结
下一步：等待 A 方向产品裁定或新的 32+ 局 measurement-only 设计预审
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 20. Reachability-7B 复核结论（2026-09-13）

Reachability-7B / A-Shape Design Preflight 已完成独立复核：

```text
独立命令：node tools/q8g_reachability7b_design_preflight.mjs
结果：32 runs，输出完整
性质：measurement-only，生产代码/数据零修改
```

## 核心事实

### 1. f1=0 局本质是 Common opportunity 饥饿

32 局中：

```text
f1_zero：8 局
short (<15 battles)：14 局
```

8 个 f1=0 局的 Common 胜场数为：

```text
3, 0, 1, 0, 1, 0, 1, 0
```

现行 pity threshold 为 `3`，没有自然命中时需要第 4 个 Common 胜场才能兑现。因此 8/8 个 f1=0 局都无法靠 pity 单独修复。

### 2. A1 与 A2 是同一机制的不同作用域

在同一总 Common opportunity 的配对比较中：

- L5-only、L4+L5、全层的 f1 修复结果接近；
- L5-only 的最大 Common 上限为 `104`（实际 81 + 可转换 23），存在硬上限；
- 全层 share floor 在同等总量下并非独立机制，只是作用范围更广。

因此正式设计不能把“L5 coverage”和“全层 share floor”当作两个可以同时叠加的独立修复。

### 3. 短局 guard 是目前最强的独立杠杆

报告层 32 局、64 复现流结果：

```text
baseline：f1zero_fix 约 2.72/8，shortZero 约 4.92
G1 floor K=2：f1zero_fix 约 6.20/8，shortZero 约 1.44
G2 floor K=4：f1zero_fix 约 7.13/8，shortZero 约 0.52
```

但 guard 会减少 Elite 战斗暴露：

```text
G1：elite 150 → 138
G2：elite 150 → 123
```

这意味着它会同时减少 Elite Gu 期望、诅咒/恶名成本暴露和高阶材料来源，不能只看 f1 修复率。

### 4. 时序-only 不是 F1 主修复

数量守恒的时序前移：

```text
f1zero_fix：2.72/8 → 2.72/8
inWindow：增加约 1.65
```

它只能改善“已获得 f1 是否来得及进入 refinement 窗口”，不能解决“根本没有足够 Common 机会”的问题。

### 5. 固定产量红线保持

所有候选形状：

```text
material pieces = 389.0
```

没有固定材料件数增加；但品质带段、Gu 期望、Elite 暴露和 Elite cost 发生变化，必须显式评估。

## 置信度与限制

```text
32 局真实审计语料
64 个确定性复现流
报告层模型
pooled natural f1 rate = 0.556
```

仍属于方向和副作用排序证据，不足以直接确定正式生产参数。

## 当前裁定

```text
A：CONDITIONAL，仅允许继续方案设计和测量
B：不批准
C：不批准
D：不批准
A5 combined：未批准、未运行
```

A 的候选结构现在应拆成两个正交维度：

```text
M：Common opportunity magnitude / scope
G：short-run opportunity guard
T：refinement timing redistribution
```

其中：

- `M` 负责增加或恢复 Common opportunity 的有效份额；
- `G` 负责短局最低 Common opportunity；
- `T` 只负责把已有机会移入 refinement 窗口。

不得将 `M + G + T` 直接打包为生产修复。

## 下一阶段允许范围

下一步只能做 measurement-only 的候选设计比较：

1. 为 `M` 建立统一目标：总 Common opportunity、Elite 暴露、Gu 期望和材料带段的可接受区间；
2. 分开比较 `L5-only`、`L4+L5`、全层 share floor，不混淆作用域与总量；
3. 比较 `G1 K=2` 与 `G2 K=4` 的短局收益/代价；
4. 对 `M+G` 组合暂不运行，除非获得单独批准；
5. 对 `T` 仅报告窗口改善，不把它当作 F1 供给修复；
6. 继续扩大至 48 局前，先处理模型假设与样本选择效应；
7. 任何正式施工前必须重新经过产品裁定和 Ownership 协议。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
生产规则：冻结
下一步：等待 M/G/T 候选边界裁定或继续 measurement-only 样本扩展
```

ZCode 不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 21. Reachability-7B 复核结论（2026-09-13）

Reachability-7B / A-Shape Design Preflight 已完成独立复核：

```text
node tools/q8g_reachability7b_design_preflight.mjs
```

结果：

```text
32 runs
f1_zero = 8
short runs = 14
measurement-only
生产代码/数据零修改
```

## 核心事实

### 1. 8 个 f1=0 局都是 opportunity starvation

8 个失败局的 Common 胜场数：

```text
3, 0, 1, 0, 1, 0, 1, 0
```

pity 在没有自然 f1 命中的情况下需要第 4 个 Common 胜场；因此 `0/8` 个 f1=0 局能靠 pity 单独修复。

结论：主断点是每局 Common opportunity 数量不足，而不是 pity 计数器语义。

### 2. 作用域比较必须固定总量

在相同 Common 总 opportunity 下比较：

- `L5-only`；
- `L4+L5`；
- 全层 share floor；

三者 f1 修复结果接近。L5-only 还有硬上限：实际 81 个 Common 加可转换 23 个，最多约 104 个。

因此不能把“作用域”和“总 Common 数量”混成一个变量。

### 3. 短局 guard 是有效但有代价的杠杆

报告层 64 个复现流：

```text
baseline：f1zero_fix 约 2.72/8，shortZero 约 4.92
G1 K=2：f1zero_fix 约 6.20/8，shortZero 约 1.44，elite 150→138
G2 K=4：f1zero_fix 约 7.13/8，shortZero 约 0.52，elite 150→123
```

G2 更强，但减少 Elite 暴露约 18%，会同步减少 Elite Gu 期望及诅咒/恶名成本机会。不能只按 f1 修复率裁定。

### 4. 时序-only 只能改善转化窗口

数量守恒的 timing-only 方案：

```text
f1zero_fix：2.72/8 → 2.72/8
inWindow：约 +1.65
```

时序无法为机会饥饿局创造第 4 个 Common 胜场，只能改善已有 f1 是否赶上 refinement。

### 5. 固定产量不变，但构成发生变化

候选方案材料件数恒为：

```text
389.0
```

没有增加固定材料产量；但 Common/Elite 转换会改变：

- crude/plain/refined/prized 带段；
- Gu 期望；
- Elite cost 暴露；
- 诅咒和恶名机会。

## 当前裁定

```text
A：CONDITIONAL，仅允许候选设计和 measurement-only 比较
B：不批准
C：不批准
D：不批准
A5 combined：未批准、未运行
```

当前把 A 拆成三个正交变量：

```text
M = Common opportunity magnitude / scope
G = short-run opportunity guard
T = refinement timing redistribution
```

语义边界：

- `M` 影响 Common opportunity 的数量/作用范围；
- `G` 影响短局最低 opportunity；
- `T` 只移动已有 Common opportunity 的时点；
- 不得在没有新裁定的情况下运行 `M+G`、`M+T` 或 `M+G+T` 组合。

## 下一步允许范围

1. 为 `M` 建立可接受边界：Common 总量、Elite 暴露、Gu 期望、材料带段；
2. 独立比较 `G1 K=2` 与 `G2 K=4`；
3. 将 `T` 作为 refinement 转化率辅助指标，不当作 F1 供给修复；
4. 若扩大样本，优先处理 natural f1 pooled-rate 假设和选择效应；
5. 任何正式施工前，必须重新完成产品裁定、Shared ownership 声明和独立验证。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
生产规则：冻结
下一步：等待 M/G/T 边界裁定或继续 measurement-only 验证
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 22. Reachability-7C 复核结论（2026-09-13）

Reachability-7C / M-G-T Boundary Analysis 已完成独立复核：

```text
独立命令：node tools/q8g_reachability7c_mgt_analysis.mjs
结果：32 runs、64 个确定性复现流
性质：measurement-only
M+G / M+T / M+G+T：均未运行
```

## M：Common opportunity magnitude 边界

前沿扫描显示：

```text
实际 Commons：81
M 的有效收益峰值附近：101
明显收益停滞：131
收益死区：149–202
Common 天花板：231，但 elite 暴露归零
```

在 `149 → 202` Common 区间内：

```text
f1zero_fix：约 6.61/8，基本不变
elite：82 → 29
```

这段是明确的“只损失 Elite 内容、收益不变”死区，不应成为候选生产边界。

`101` 左右是报告层边际效率最高的区域，但仍只是 sensitivity reference，不是正式数值。

## G：short-run guard 边界

独立对比：

```text
BASELINE：f1zero_fix 2.67/8，elite 150
G1 K=2：f1zero_fix 6.00/8，elite 138
G2 K=4：f1zero_fix 7.02/8，elite 123
```

效率：

```text
G1：0.2773 次修复 / 每减少 1 场 Elite
G2：0.1609 次修复 / 每减少 1 场 Elite
```

G1 比 G2 更具成本效率；G2 的最后一步只增加约 `1.02` 次修复，却额外减少 `15` 场 Elite 暴露。

## T：refinement timing

T 只作为转化窗口指标：

```text
供给变化：0.00
转化率：87.7% → 93.7%
f1zero_fix：2.67/8 → 2.67/8
```

因此 T 不提供 F1 供给修复，只能改善已有 f1 的 refinement 转化，不应被列为主修复。

## natural f1 rate 选择效应

报告层观察：

```text
pooled：43/81 = 0.5309
f1=0 局自身：0/6
non-zero 局：43/75 = 0.5733
```

失败局自身观测率为 0，不能用来预测失败局未来自然命中；属于选择效应。LOO 与 pooled 结果一致，当前允许继续使用 pooled rate，但所有绝对收益必须标注为模型依赖值。

## 当前裁定

```text
A：CONDITIONAL，仅允许继续候选边界分析
B：不批准
C：不批准
D：不批准
A5 combined：未批准、未运行
```

候选排序更新为：

1. 优先评估 `G1 K=2`，因为单位 Elite 代价效率高于 G2；
2. M 若继续研究，应避开 `149–202` Common 的收益死区，并同时报告 Elite/Gu/品质带段代价；
3. T 仅作为转化率辅助项，不作为 F1 主修复；
4. 不允许运行任何 M/G/T 组合，除非获得单独产品裁定。

## 下一步

允许的下一阶段只能是 measurement-only：

- 为 `G1 K=2` 定义可接受的 Elite/Gu/材料带段边界；
- 为 M 选择不落入收益死区的候选点，继续报告副作用；
- 对 pooled natural f1 rate 使用区间/收缩估计而非单点绝对承诺；
- 继续保持 `A5 combined` 未批准；
- 任何正式施工前必须重新完成产品裁定、Shared ownership 声明和独立验证。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
Reachability-7C：M-G-T 边界分析完成，A CONDITIONAL
生产规则：冻结
下一步：等待 G1/M 边界裁定或继续 measurement-only 验证
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 23. Reachability-7D 复核结论（2026-09-13）

Reachability-7D / G1 Boundary + M Candidate Points + Interval Reporting 已完成独立复核：

```text
独立命令：node tools/q8g_reachability7d_g1_m_boundary.mjs
结果：32 runs、64 个确定性复现流
性质：measurement-only
组合 M/G/T：未运行
```

## G 边界

短局 guard 扫描结果：

```text
BASELINE：f1zero_fix 2.67/8，elite 150
G K=1：f1zero_fix 4.94/8，elite 146
G K=2：f1zero_fix 6.00/8，elite 138
G K=3：f1zero_fix 7.02/8，elite 128
G K=4：f1zero_fix 7.02/8，elite 123
```

`K=3` 与 `K=4` 的修复率和短局遗留相同，但 `K=4` 额外损失 5 场 Elite，因此：

```text
K=4 被 K=3 支配
```

`G K=2` 的边界代价相对基线：

```text
Elite 暴露：−8.0%
Gu 期望：−5.8%
材料件数：0.0% 变化
crude：+11.6 件
```

短局阈值从 `<12`、`<15` 到 `<18` 时 `G K=2` 结果不变，说明该结果对操作性短局定义不敏感；`<21` 才出现轻微偏移。

## M 候选点

M 的候选点应位于既有收益死区 `149–202 Common` 之外：

```text
81 / 91 / 101 / 111 / 120 / 131 / 141
```

报告层结果显示：

- `101` 附近是较高边际效率点；
- `141` 仍有收益，但已接近成本快速上升区；
- `149–202` 是 Common 增加而 f1 修复基本不动的死区；
- `231` 时 Elite 内容完全消失，不可接受为默认方向。

## 区间化报告

natural f1 pooled rate 与收缩估计的区间结果：

```text
BASELINE：1.61–2.67 / 8
G K=2：4.92–6.00 / 8
G K=4：6.05–7.02 / 8
M@101：3.95–4.92 / 8
M@141：6.23–6.61 / 8
```

`G K=2` 与 `G K=4` 区间不相交，G2 的更高修复效果具有稳健方向；但 `G K=4` 被 `K=3` 的同等收益、较低 Elite 代价进一步支配。

所有绝对修复数必须继续写成模型区间，不得当作正式承诺。

## 当前裁定

```text
A：CONDITIONAL，仅允许继续设计预审
B：不批准
C：不批准
D：不批准
A5 combined：未批准、未运行
```

当前候选排序：

1. G `K=2`：成本效率较高，适合作为首个 G 候选；
2. G `K=3`：修复效果更高，但需接受约 14.7% Elite 暴露下降；
3. G `K=4`：淘汰，因被 K=3 支配；
4. M：优先考虑 `101–141` 之间的点，避开 `149–202` 死区，并继续报告副作用；
5. T：保留为转化率辅助，不进入 F1 主修复排序。

以上只是测量结果和候选排序，不构成生产施工许可。

## 下一步允许范围

只允许继续：

- 明确 G1/G3 的产品可接受代价边界；
- 明确 M 的目标 Common 区间和 Elite/Gu/品质带段预算；
- 使用 pooled + shrink 区间报告，不再使用单点绝对收益；
- 继续扩展样本或复核短局边界；
- 在获得独立产品裁定前，不运行任何 M/G/T 组合；
- 不修改正式代码、数据、pity、E6、pacing、战斗或地图。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
Reachability-7C：M-G-T 边界分析完成，A CONDITIONAL
Reachability-7D：G/M 边界与区间分析完成，A CONDITIONAL
生产规则：冻结
下一步：等待 G1/G3 与 M 边界裁定
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 24. Reachability-7E 复核结论（2026-09-13）

Reachability-7E / G1·G3 Cost Boundary + M Budget Specification 已完成独立复核：

```text
独立命令：node tools/q8g_reachability7e_boundary_spec.mjs
结果：32 runs、64 个确定性复现流
性质：measurement-only
M/G/T 组合：未运行
A5 combined：未批准
```

## G 的产品代价应按“谁承担”表达

基线每局约：

```text
Elite 4.69
Gu 1.56
诅咒 2.34
恶名 4.69
```

### G K=2

```text
f1zero 修复区间：4.92–6.00 / 8
Elite：4.69 → 4.31 / 局
Gu：1.56 → 1.47 / 局
诅咒：2.34 → 2.16 / 局
恶名：4.69 → 4.31 / 局
材料件数：0% 变化
```

代价不是平均摊给所有局：

```text
短局 Elite：3.14 → 2.29 / 局
长局 Elite：5.89 → 5.89 / 局
受影响局数：9/32
单局最大损失：2 场 Elite
```

### G K=3

```text
f1zero 修复区间：5.92–7.02 / 8
Elite：4.00 / 局
受影响局数：12/32
单局最大损失：3 场 Elite
```

G 的代价主要集中在短局，而长局玩家不受影响。这比“全局 Elite −8%/−14.7%”更适合作为产品裁定口径。

## M 的预算边界

M 的代价摊在所有局：

```text
M@101：Elite −0.63/局（约 −13%），Gu −0.15/局
M@120：Elite −1.22/局（约 −26%），Gu −0.29/局
M@141：Elite −1.88/局（约 −40%），Gu −0.45/局
```

品质带段变化：

```text
M@101：crude +0.61/局，plain −0.45/局，refined −0.15/局
M@120：crude +1.19/局，plain −0.87/局，refined −0.31/局
M@141：crude +1.82/局，plain −1.34/局，refined −0.47/局
```

因此：

- `M@101` 是较轻的候选点；
- `M@141` 的 F1 效果更强，但会显著削弱 plain/refined 供给；
- `149–202 Common` 死区仍排除；
- M 的代价不是短局定向补偿，而是所有局都可能失去高阶战斗内容。

## 短局边界

32 局中 8 个 f1=0 局：

```text
短局 6 个
长局 2 个
```

长局失败局不受 G 影响，因此：

> G 的产品定位应是“改善短局体验”，而不是“消灭全部 f1=0”。

若目标是消灭全部 f1=0，必须另有覆盖长局的变量；这将涉及 M 或新的机制，组合仍未批准。

## 当前候选排序

```text
G K=2：优先候选，代价集中且边界较轻
G K=3：更强但代价更高，需明确是否接受短局少 2–3 场 Elite
G K=4：不考虑，已被 K=3 支配
M@101：轻量 M 候选，但修复区间较低
M@120：中等候选，代价明显增加
M@141：强效果候选，但品质带段和 Elite/Gu 代价显著
T：仍仅为转化率辅助项
```

## 当前裁定

```text
A：CONDITIONAL，仅提供产品边界依据
B：不批准
C：不批准
D：不批准
A5 combined：未批准、未运行
```

本批次仍没有生产施工许可。任何正式施工前必须重新完成：

1. 产品裁定；
2. `run_state.gd` 等 Shared 文件 Ownership 声明；
3. 受影响测试计划；
4. 独立验证；
5. 单独 commit 纪律。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
Reachability-7C：M-G-T 边界分析完成，A CONDITIONAL
Reachability-7D：G/M 边界与区间分析完成，A CONDITIONAL
Reachability-7E：代价边界与预算规格完成，A CONDITIONAL
生产规则：冻结
下一步：等待 G K=2/G K=3 与 M 预算的产品裁定
```

ZCode 仍不得修改：

```text
scripts/domain/**
data/**
scripts/presentation/**
tests/**
RunState
正式 pity / E6 / pacing / battle 规则
```

---

# 25. 产品裁定：G 短局 guard 与目标口径（2026-09-13）

## 裁定一：短局每局少 1–2 场 Elite 是否可接受？

```text
条件接受 G K=2；不接受 G K=3 作为首个生产方案。
```

理由：

- `G K=2` 的代价集中在短局，不影响长局；
- 9/32 局受影响，单局最多损失 2 场 Elite；
- 短局 Elite 约从 3.14 降到 2.29 / 局；
- 汇总 Gu 期望下降约 5.8%，材料件数不变；
- `G K=3` 虽然修复更高，但会使 12/32 局受影响、单局最多损失 3 场 Elite；
- `G K=4` 已被 `K=3` 支配，不进入候选。

“条件接受”不是立即施工许可。实现前必须把以下作为正式验收边界：

```text
短局 guard 只作用于短局；
长局 Elite / Gu / 材料产量不得下降；
单局 Elite 最大损失不得超过 2 场；
材料固定件数不得增加或减少；
新增短局补偿不得引入 Soul、商店、地图或第二成长线。
```

## 裁定二：G 的目标是什么？

```text
目标是“改善短板”，不是“消灭全部 f1=0”。
```

理由：

- 32 局中 8 个 f1=0 局里有 6 个短局、2 个长局；
- G 的作用域是短局，因此结构上不可能修复那 2 个长局；
- 若把目标定成消灭全部 f1=0，就会强迫 G 越界到长局，或偷偷引入未经批准的 M/G 组合；
- 这会把一个短局体验修复任务扩大成全局经济改造，不符合“一个变量优先”。

因此 G 的验收目标应改写为：

```text
提高短局的 F1 opportunity 与 promotion 转化机会；
不承诺所有 Run 都完成 F1；
不承诺 Batch 1 Final Gate B/C 通过；
长局失败另由 M 轴单独处理。
```

## G K=2 候选验收线

正式施工前必须重新确认：

```text
f1zero 修复：以 pooled + shrink 区间报告，不使用单点承诺；
shortZero：相对基线显著下降；
受影响局：只限短局；
长局：Elite / Gu / 材料件数不下降；
材料件数：恒等守恒；
新增 f1：必须是当前合法 Common / school / crude 候选；
事件、存档、pity、RunState：若不改变则明确保持不变；
确定性：同 seed / school / route 结果一致。
```

## 本裁定批准的下一批次

```text
Reachability-8 / G1 K=2 Implementation Preflight
```

性质：先做实现前预审与施工计划，不直接扩大到 M/G 组合。

允许 worker 准备：

- G1 K=2 的正式语义草案；
- 受影响文件清单；
- RunState / event / save 是否需要变化的判断；
- 测试矩阵；
- 32 局或更大样本的回归命令；
- 回滚条件和 Shared ownership 声明草案。

在我确认 Reachability-8 计划前，禁止：

- 修改 `data/**`；
- 修改 `scripts/domain/**`；
- 修改 `RunState`；
- 修改正式 pity / E6 / pacing / battle 规则；
- 运行 M+G、M+T 或 M+G+T 组合；
- 直接提交生产代码。

## 当前状态

```text
Reachability-3：实现语义 PASS，目标效果 FAIL
Reachability-4：Gate A/B PASS，Gate C FAIL，历史保留
Reachability-5：Gate A/B/C/D PASS，审计与对比完成
Reachability-6：16 局 preflight 完成，A CONDITIONAL
Reachability-7：A-shape preflight 完成，A CONDITIONAL
Reachability-7B：32 局设计预审完成，A CONDITIONAL
Reachability-7C：M-G-T 边界分析完成，A CONDITIONAL
Reachability-7D：G/M 边界与区间分析完成，A CONDITIONAL
Reachability-7E：代价边界与预算规格完成，A CONDITIONAL
Reachability-8：已批准准备 implementation preflight，尚未批准生产施工
生产规则：冻结
下一步：准备 G1 K=2 implementation preflight
```

---

# 26. 产品裁定：批准 B1 澄清 + B2 选择 S1（2026-09-13）

> 本节由 ZCode 代录：用户本轮已下达裁定，但会话工作区只读、写回被拒，故由 ZCode 读取后写入 inbox。

## 决定一：批准 B1 澄清

```text
批准 B1，但仅限只读地图产物审计或 measurement-only 埋点重跑。
```

必须确认：

- `trailhead` 到首个实际访问节点的完整路线；
- 首节点落在 L3/L4 是否是合法地图生成结果；
- 是否存在旧存档续玩、路线指针错误、驱动器跳层或地图生成退化；
- 32 局中起手层、路线战斗节点数、实际战斗数、撤退行为之间的关系；
- `force_606` 等异常样本是否可复现。

输出必须明确归类为：`合法地图产出` / `驱动器测量偏差` / `真实地图/路线 bug`。

在 B1 澄清前，不得继续沿用：

```text
9/32 受影响局
单局最多损失 2 场 Elite
短局 <15 场
```

这些数字必须重新标定。

## 决定二：选择 S1

```text
B2 选择 S1：路线战斗节点数。
```

暂定定义：

```text
生成后的可达路线中，combat 节点数量 < N
→ 该路线获得 G1 K=2 的 Common opportunity 保护
```

选择理由：生成阶段可观察；不需要把未来战斗结果写入 `RunState`；不需要结算期重抽敌人 tier；不会把正式敌人 tier 与"最终是否短局"强行割裂；比 S3 更少固化当前样本中的 L3/L4 起手相关性。

不选择 S2（已打过场次）：敌人 tier 已在地图生成时确定，要让 S2 生效需延迟抽取、运行期状态或结算期重抽，超出当前最小改动范围。

不选择 S3（层 + 场次复合）：会把尚未证实的"L3/L4 起手导致短局"直接写成规则。

## 下一步顺序（固定）

```text
B1 只读地图审计
→ S1 surrogate 重新测量
→ 重新标定 G1 影响范围与 Elite 损失
→ 再审 G1 正式施工计划
→ Shared Ownership 声明
→ 明确施工许可
→ 才能修改生产代码
```

```text
Reachability-8：7 项 implementation preflight 已形成
G1 K=2：条件接受
生产施工：未批准
B1：批准只读核查（本轮已执行，见 §27）
B2：选择 S1 route combat-node surrogate
```

在有新裁定前，ZCode 不得运行任何 M/G/T 组合，也不得修改正式代码或数据。

---

# 27. Reachability-8 / B1 只读地图审计结果（2026-09-13）

**报告全文**：`docs/q8g/Q8G_REACHABILITY8_B1_MAP_AUDIT.md`
**工具**：`tools/q8g_reachability8_b1_map_audit.gd`（新增，只读，确定性可复现）

## 归类结论

```text
B1 = 真实地图/路线 bug（data/nodes.json 残留 start:true）
     + 驱动器优先级放大（非起因）
```

## 机制链

```text
① data/nodes.json 的 neutral_wanderer(contact) / ridge_caravan(caravan) 带 "start": true
② map_generator.gd:90  instance = template.duplicate(true)   ⇒ start 复制到任意层实例
③ map_generator.gd:110 生成器自身只对 layer==1 && row==0 设 start
④ map_generator.gd:328 注释自述「旧模板自带双入口 start 契约已移除」⇒ ①是未清理遗留
⑤ map_generator.gd:355 reachable_nodes(trailhead) 返回【全图所有 start 节点】，无层过滤
⑥ run_travel_flow.gd:14 travel 用 reachable_nodes 校验 ⇒ 跨层 travel 合法通过
⑦ social_command_rules.gd:549 _travel 域层【无可达性校验】
⑧ acceptance_driver.gd:2534 P1-a refine_leading 优先于 others ⇒ 系统性选中 L3–L5 起点
```

测试漏检原因：`tests/unit/test_five_layer_map_contract.gd:125-131` 只断言 `reachable == is_start`——**镜像同一个 flag，对泄漏零分辨力**。

## 证据

```text
非 L1 起手的种子数：15 / 16
起点层直方图：L1=40  L2=8  L3=8  L4=16  L5=15   （L1 以外 47/87 = 54%）
实测首节点落在该图起点集内：16 / 16（100%）
同 seed 地图构建确定性：OK（fingerprint 逐字节一致）
```

入口层 ↔ 实测战斗数（单调）：

```text
入口 L1 → 12–24 场 | 入口 L2 → 15–18 场 | 入口 L3 → 9 场 | 入口 L4 → 3–12 场
```

入口节点的前向 combat 数几乎精确框住实测战斗数（例：`606` → `5..10` vs 实测 `3/7`）。

## 排除项

```text
旧存档续玩      — 排除（--mode=play 走 start_new_run，日志「开局 seed=NNN | 起点=trailhead」）
路线指针错误    — 排除（首节点由 reachable_nodes 正常返回，无「行至被拒」）
驱动器跳层      — 非起因；travel 经 run_travel_flow 校验（放大器）
地图生成退化    — 排除（每 seed 5 层齐全，148–190 节点，确定性 OK）
步数预算截断    — 排除（上限 900，实测最高 401）
force_606 复现  — 排除不可复现（同 seed fingerprint 相同）
撤退是起因      — 否（下游后果；L1 入口局撤退 6–13 次仍能打 19–24 场）
```

## 连带风险（产品级，未深挖）

泄漏起点跳过所有关底台 ⇒ 存在跨层入口与关底门禁绕过。例：`seed 55` 可 `trailhead → L5R4N4`。建议单独立项核对。

## S1 口径复核 → 退化

```text
A) 全图 combat/pursuit 节点数        : 69–105   ⇒ 与阈值 15 差一个数量级，永不触发
B) DAG min-path combat 数            : 1–17     ⇒ 16 个 seed 中 15 个触发，无分辨力
C) DAG max-path combat 数            : 32–45    ⇒ 永不触发
D) 实测入口节点前向 combat 数        : 5–43     ⇒ 与入口层耦合；修 start 后退化回 A
```

根因：每局都生成完整 5 层扇图（各层 combat 15.9–19.6），大层接缝单向连通 ⇒「可达路线 combat 数」≈ 全图 combat 数。

⇒ **S1 的选择理由成立，但它识别不了「短局」——按 S1 字面口径每局都是长局。**

重定义建议：**S1-α（推荐）＝把保护绑定到「层」而非整局**（对 L4/L5 在生成期提高 Common tier 权重），生成期可观察且与运行长度解耦。

## 作废清单

```text
9 / 32 受影响局          ← 无效
单局最多损失 2 场 Elite   ← 无效
短局 = 战斗数 < 15        ← 无效
R7B–R7E 全部效应量 / 效率前沿 / 区间化报告 ← 全部作废（population 受污染）
```

## 修复预期收益（远超任何 G/M/T 变体）

8 个 f1=0 局中 **6 个是 L3/L4 入口**（`force/1212`=L3、`force/909`=L4、`sword/11`=L4、`sword/1212`=L3、`sword/33`=L4、`sword/606`=L4），只有 2 个是 L1 入口（`force/1111`、`force/20260927`）。

对照：`G K=3`/`K=4` 最好修复 **7.02/8**（vs 基线 +4.35），代价 22–27 名精英。
⇒ **一次数据修复（删 2 个模板的 `start` 字段）预期直接触及 6/8，且不消耗任何精英暴露。**

```text
🔴 最高价值动作是数据修复，不是 G1。
   G1 K=2 的裁定（§25）建立在受污染基线上，建议修复后重新评估是否仍需要。
```

修复后所有局从 L1R0 起手（前向 combat 14–43），但 L1 入口局实测仅 12–24 场 ⇒ **f1=0 不会归零**，基线整体右移，需在重建语料上重测。

## 新增阻塞（需新裁定）

修 `start` 泄漏的三个方案**都会越过冻结区**：

```text
(a) 删 data/nodes.json 中 2 个模板的 "start" 字段   → data/** 属冻结区
(b) 生成器侧 instance.erase("start")                → scripts/domain/** 属冻结区
(c) 环境门控的 measurement-only 覆盖                → 仍需改生成器
```

**建议**：把 (a) 作为**独立 bug fix** 单独裁定、单独 commit，**先于**任何 G1 施工。理由：修正的是玩家可见的规则漏洞（非平衡调整）；改动面最小（2 行 JSON）；是其余一切测量的前置；修完先跑全量测试确认无回归，再重建语料。

## 当前状态

```text
Reachability-8：7 项 implementation preflight 已形成
                B1 只读审计完成 → 归类「真实地图/路线 bug」
                B2 的 S1 口径判定为退化，需重定义
G1 K=2：条件接受，但建议在 start 泄漏修复后重新评估
生产施工：未批准
新增阻塞：start 泄漏修复需新裁定（越过 data/** 冻结区）
生产规则：冻结
下一步：等待 (1) start 泄漏修复裁定；(2) S1 口径重定义裁定
```

---

# 27. Reachability-8 B1 复核与新裁定（2026-09-13）

## B1 独立复核

已独立运行：

```text
tools/q8g_reachability8_b1_map_audit.gd
```

结果：

```text
非 L1 起手 seed：15/16
起点总数：87
L1 以外 start 节点：47（54%）
实测首节点落在 start 集：16/16
同 seed 地图 fingerprint：一致
```

根因确认：

```text
data/nodes.json
  neutral_wanderer.contact  -> start=true
  ridge_caravan.caravan     -> start=true

map_generator.gd
  template.duplicate(true)  -> start 字段复制到实例

reachable_nodes(trailhead)
  -> 返回所有 start=true 实例
```

这不是旧存档、路线指针、步数预算或随机不确定性问题，而是玩家可见的跨层入口漏洞。P1-a 的 `refine_leading` 只是放大器，不是根因。

## 作废范围

B1 污染了“短局”人口，因此以下结果全部不得继续作为有效产品边界：

```text
R7B–R7E 的全部 effect size
9/32 受影响局
单局最多损失 2 场 Elite
短局 <15 战斗
G K=2 的条件接受边界
G K=3 / K=4 的比较边界
M/G/T 的既有绝对修复区间
```

历史文档保留，但必须标记为“受 start 泄漏人口污染的历史测量”，不得继续引用为生产依据。

## 新产品裁定一：允许独立修复 start 泄漏

```text
批准方案 A：删除 data/nodes.json 中两个模板的 start=true 字段。
```

这是独立的玩家可见规则 bug fix，不是经济平衡调整。要求：

- 只删除 `neutral_wanderer` 和 `ridge_caravan` 两个模板的 `start` 字段；
- 不修改其他节点、节点权重、地图连边或 pacing；
- 不修改 `map_generator.gd`，避免把数据 bug 与生成器行为混成一个变量；
- 不修改 RunState、事件、存档、loot、pity、E6、战斗或 UI；
- 单独 commit，不与 G1、M、G、T 或其他审计工具混提。

### Bug fix 验收

修复后必须重新运行：

```text
R8 B1 map audit
地图起点绝对断言：只有 layer=1,row=0 的正式入口节点可带 start
16 seed 确定性 fingerprint
地图层接缝与 Boss 门禁测试
tools/test.ps1 -Suite unit
tools/test.ps1 -Suite integration
tools/check.ps1
```

在修复后的新基线生成前，不得运行或解释 G1/M/G/T 经济效果。

## 新产品裁定二：原 S1 作废，暂不实施 S1-α

原定义：

```text
整条可达路线 combat 节点数 < N
```

裁定为退化，因为完整地图本身包含约 `69–105` 个 combat 节点，无法识别实际短局。

暂定替代方向：

```text
S1-α：按层绑定 opportunity 保护，而不是按最终整局战斗数绑定。
```

但 S1-α 目前只批准为设计方向，不批准实现。修复 start 泄漏后必须重新测量：

- 起手是否统一回到 L1；
- 实际路线/战斗数量分布；
- L4/L5 保护是否必要；
- 保护对真实玩家路线是否可观测；
- 是否误伤长局、Boss 和锚点；
- Common、Elite、Boss、Gu、材料带段与 Elite cost 的变化。

## Reachability-8 新执行顺序

```text
1. 独立提交 start 泄漏数据 bug fix
2. 跑地图审计、unit、integration、check
3. 重建 32 局真实基线语料
4. 重新统计起手层、路线长度、战斗数、撤退分布
5. 重新判定短局人口是否存在
6. 重新设计并测量 S1-α（若仍需要）
7. 重新评估 G1 K=2 是否还有产品价值
8. 重新评估 M/G/T 与 Final Gate
```

任何第 7 步之前的 G1 数值均视为失效历史数据。

## 当前状态

```text
Reachability-8：B1 审计完成，发现真实 start 泄漏 bug
Start leak fix：批准独立数据 bug fix，尚未施工
原 S1：作废
S1-α：仅批准设计方向，尚未实现
G1 K=2：原条件接受边界作废，等待修复后重测
M/G/T：既有人口污染，等待新基线
生产施工：仅允许 start leak 独立 bug fix
经济规则：冻结
```

ZCode 当前只允许：

```text
修改 data/nodes.json 中两个 start 字段
相关地图审计与回归验证
文档/报告更新
```

仍禁止：

```text
scripts/domain/** 的规则修改
除上述两字段外的 data/** 修改
RunState / save / event 修改
正式 pity / E6 / pacing / battle 修改
G1 / M / G / T 经济施工
```

---

# 28. R8 / start 泄漏修复施工完成 + 真实基线重建（2026-09-13）

**报告全文**：`docs/q8g/Q8G_REACHABILITY8_POST_FIX_BASELINE.md`

## 已施工并提交

```text
29286071  fix(map): drop legacy start flag from neutral_wanderer and ridge_caravan templates
          data/nodes.json                            |  2 --
          tests/unit/test_five_layer_map_contract.gd | 49 ++++++++
```

按 §27 裁定一执行：只删两个模板的 `start` 字段，`map_generator.gd` 未动。
经用户确认，本 commit 同时纳入两个回归守卫（数据层「模板不得声明 start」+ 绝对契约「start 必须在 L1/R0」），
它们是 §27 验收项「地图起点绝对断言」的落地点。逐字段 diff 确认 37 个模板中只有这两个模板少了 `start`。

## 验收结果

```text
guitkx_build        rc=0  compiled=0 errors=0 held=0 total=16
unit                rc=0  Tests 1441 / Passing 1441 / Failing 0
integration         rc=0  Tests 32 / Passing 32 / Failing 0
启动探针            rc=0
契约漂移            rc=0  contract drift: ok (168 identifiers resolved)
git diff --check    rc=0
R8 B1 地图审计      rc=0  非 L1 起手 0/16，契约违规 0，determinism OK
```

### 包装层既有失败（非本次引入）

`tools/run_gut_checked.ps1` 的 `SCRIPT ERROR` 扫描会把 unit 判为 FAIL，故 `tools/check.ps1`
会在 unit 段 exit 1。命中来源与本修复无关：

```text
test_slay_gu_final_chapter.gd:149  <- 未提交的 data/loot_tables.json 新增顶层键
                                      school_material_resonance（JSON 数字被解析为 float，
                                      而该测试把 loot_tables 根对象每个 value 赋给 Dictionary）
battle_screen_view.gd:941          <- 既有 locked object 生命周期问题
```

两个来源文件都在允许范围之外，未修改。另：PowerShell 沙箱会拦截 Godot 子进程，
`tools/*.ps1` 在沙箱内 1 秒返回 rc=1（非真实结果），本轮改为按 `check.ps1` 同一条流水线在 Bash 中逐段复现。

## 修复后的 32 局真实基线（PRE 污染语料 → POST 修复语料）

```text
                               PRE        POST
非 L1 起手局                  14/32      0/32（32/32 全部 L1R0N0）
battles total                 484        619
short runs (<15)              14         5
common / elite 场次           81 / 150   155 / 151     <- Elite 绝对暴露未下降
common before first refine    14         73
f1_zero runs                  8          2
f1_count total                43         63
mat_ready / full_ready        70 / 42    88 / 70
attempts / successes          47 / 47    72 / 72
gate_b PASS runs              9          15
gate_c PASS runs              4          8
```

f1=0 逐局：

```text
PRE （8）: force/1111, force/1212, force/20260927, force/909,
           sword/11, sword/1212, sword/33, sword/606
POST（2）: force/20260927（13 场）, force/303（20 场）
7 局转正（B1 预测的 6 个 L3/L4 泄漏入口局全部转正）；force/303 为修复引入的新失败局
```

## 关键含义

1. 旧「短局人口」主要是 start 泄漏制造的：14 → 5，旧短局 11/14 起手在 L2–L4。
2. f1=0 从 8 → 2，**不是经济参数调整的结果**，是数据 bug 修复的直接后果。
3. **Elite 绝对暴露未下降（150 → 151）**，G1 K=2 用来交换 Elite 的代价基础已不成立。
4. Common 机会数量与时序同时改善（81→155、首次 refinement 前 14→73），
   R6/R7 的 S2/S4 结论需在新基线上重测。

## 当前状态

```text
Start leak fix：已提交 29286071，地图审计 + 回归全绿（包装层 unit 判定受既有 SCRIPT ERROR 影响）
R8 B1：修复完成，非 L1 起手 0/16
32 局真实基线：已重建（POST 语料 = %TEMP%/gu-zhenrens-r5-logs，污染语料保留于 ...-PRE_START_FIX）
原 S1：作废
S1-α：仍仅为设计方向，未实现
G1 K=2：原条件接受边界作废；Elite 代价基础消失，需重新评估是否仍有产品价值
M/G/T：历史效应量全部作废，等待在新基线上重新测量
生产施工：仅 start 泄漏修复已完成；其余经济施工未批准
经济规则：冻结
下一步：等待 (1) 包装层 SCRIPT ERROR 的单独裁定；(2) force/303 新失败的复核口径；
        (3) 是否在新基线上重开 G1 / S1-α 的产品裁定
```

ZCode 仍不得修改：

```text
scripts/domain/** 的规则修改
除已提交两字段外的 data/** 修改
RunState / save / event 修改
正式 pity / E6 / pacing / battle 修改
G1 / M / G / T 经济施工
```
