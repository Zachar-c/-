# Q8-G Reachability-4 / F1 Opportunity Pity Simulation（实验记录）

> - **性质**：measurement-only hypothetical 模拟；inbox = `Q8G_HANDOFF_CURRENT.md`（2026-09-13）。
> - **回答的问题**：若 f1 缺失计数跨**所有**有材料的战斗胜利累计，但强制兑现仍只发生在当前 Common loot pool，能否减少 F1 gap？
> - **状态**：✅ 测量完成；**Gate C 有效性 FAIL**（详见 §4）。不含任何 A/B/C/D 产品裁定。

## 1. 实现摘要

全部模拟状态只存在于 `scripts/acceptance_driver.gd` 的驱动器本地变量，opt-in 开关 `PLAYTHROUGH_F1_OPPORTUNITY_PITY=1`：

- `simulated_f1_absence_streak`：victory 且有材料且无合法 f1 → +1；命中合法 f1 → 清零；空材料不变；
- 合法 f1 = 本派 promotion chain ∩ 当前 Common material_pool ∩ `quality_band == crude`（force/sword 局实测均为 `mat_force_1` / `mat_sword_1`）；
- 兑现判定：本场实际结算 tier == `common`（从 `loot_stone_gained` 事件 targets 反读真实结算 tier）且结算前 streak ≥ threshold(3) 且候选非空 → 仅记录 hypothetical forced，不改正式 loot/state/event_log/save；
- 实际结算 tier 分布、`candidate_empty`、逐场 streak trace 均落报告。

来源说明：driver 内模拟代码与 sweep 脚本最初来自被主动终止的 codex worker 遗留实现，经 ZCode 审计后补完（调用点接线、tier 分布统计、summary 扩展、sweep 日志落盘）并全量验证。

## 2. 验证（inbox §6 确定性 + 无污染）

| 检查 | 方法 | 结果 |
|---|---|---|
| 关开关无污染 | seed 55 force 不设开关 vs R5 基线 | 漏斗/promotion/Gate 逐字一致 ✅ |
| 开开关零行为差 | seed 55 force 设开关 | 漏斗/promotion/Gate 与关开关完全一致 ✅ |
| 确定性 | 同配置复跑两次 | `R-4 SIM summary` 完全相同 ✅ |

## 3. 8-seed 结果（`tools/q8g_reachability4_f1_pity_sweep.ps1`，逐场日志（driver stdout；sweep 默认写入 `$env:TEMP/gu-zhenrens-r4-logs/`））

| seed | 派 | f1 实际 | hypothetical 强制 | common 战斗 | 终局 streak | tier 分布 (e/b/c) | Gate B/C（实际，与 R3 一致） |
|---|---|---|---|---|---|---|---|
| 20260927 | force | 0 | **1** | 1 | 2 | 7/4/1 | FAIL/FAIL |
| 11 | force | 2 | 0 | 2 | 4 | 7/2/2 | FAIL/FAIL |
| 33 | force | 1 | 0 | 1 | 3 | 2/2/1 | FAIL/FAIL |
| 55 | force | 3 | 0 | 4 | 6 | 9/4/4 | PASS/FAIL |
| 20260927 | sword | 1 | 0 | 4 | 8 | 5/2/4 | FAIL/FAIL |
| 11 | sword | 0 | 0 | 1 | 6 | 3/2/1 | FAIL/FAIL |
| 33 | sword | 0 | 0 | 1 | 5 | 2/2/1 | FAIL/FAIL |
| 55 | sword | 3 | 0 | 4 | 10 | 11/4/4 | PASS/PASS |

### 3.1 实际五段漏斗逐局（与模拟无关）

| seed | 派 | 探访 | gu_ready | mat_ready | full_ready | 尝试 | 成功 | Gate B/C |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 20260927 | force | 4 | 4 | 3 | 0 | 0 | 0 | FAIL/FAIL |
| 11 | force | 1 | 1 | 0 | 0 | 0 | 0 | FAIL/FAIL |
| 33 | force | 2 | 2 | 1 | 1 | 1 | 1 | FAIL/FAIL |
| 55 | force | 5 | 5 | 4 | 3 | 3 | 3 | PASS/FAIL |
| 20260927 | sword | 4 | 4 | 3 | 2 | 1 | 1 | FAIL/FAIL |
| 11 | sword | 2 | 2 | 2 | 0 | 0 | 0 | FAIL/FAIL |
| 33 | sword | 2 | 2 | 1 | 0 | 0 | 0 | FAIL/FAIL |
| 55 | sword | 5 | 5 | 5 | 4 | 4 | 4 | PASS/PASS |
## 4. trace 分析（三个 f1=0 局逐一解释）

1. **force 20260927（唯一兑现局）**：唯一 common 战斗在第 **16** 场（L5R6N1，多敌空 `enemy_kind` 兜底 common），结算前 streak=9 ≥ 3 → hypothetical 兑现 1 块 f1。但该局 **4 次 refinement 探访全部发生在第 16 场之前**（L1R4N0 / L2R4N1 / L3R5N1 / L4R4N1），此后到终局（第 19 场）再无探访——**兑现的 f1 来不及改变任何 promotion 结果**。
2. **sword 11**：唯一 common 战斗在第 **3** 场（结算前 streak=2 < 3）→ 不兑现；此后 6 场战斗再无 common → f1 终局仍 0。
3. **sword 33**：唯一 common 战斗在第 **2** 场（streak=1）→ 不兑现；此后再无 common → f1 终局仍 0。

## 5. 测量结论（非裁定）

- **Gate A 合法性 PASS**：所有 hypothetical f1 均为本派、Common 池、crude 的 promotion 材料；无跨派/跨池/凭空生成。
- **Gate B 触发准确性 PASS**：仅 streak≥3 且 common 结算时兑现；正式 loot/state/event_log/save 零改动（Gate 结果与关开关逐局一致）。
- **Gate C 有效性 FAIL**：8 局仅 **1 次**兑现；3 个 f1=0 局中 1 局兑现但时点晚于全部探访、2 局因 common 战斗过早（streak 未达标）且终局前无第二次 common 战斗而无法兑现；**0 局 promotion 结果因此改善**。
- 结构性原因（与 Reachability-3 §5 根因一致并加深受）：common 池战斗不仅稀缺（1–4 场/局），且时点分布两极（要么极早、要么 L5 末端），"threshold=3 + Common 唯一兑现窗口"的组合在单局时标内几乎必然失效。
