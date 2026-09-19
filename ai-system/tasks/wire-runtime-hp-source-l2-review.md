# L2 Review · P2.1 接通 game runtime 开局气血真源

```text
REVIEW STATUS: PASS WITH FOLLOW-UP（1 项加固建议，不阻塞）
REVIEWER: L2 Orchestrator
SUBJECT: ai-system/tasks/wire-runtime-hp-source-result.md（OpenCode + Muse Spark 1.3）
DATE: 2026-09-19
```

## 1. 目标达成（L2 独立复核）

漂移已闭合：runtime 开局气血不再自持数值，改为读唯一配置。

| 检查项 | 结论 | L2 独立证据 |
| --- | --- | --- |
| 4 处裸 80 清除 | PASS | `run_state.gd:18/19/117/118` 改用 `const START_HP_FALLBACK := 100`；文件内 `rg` 已无 `= 80`/`: 80`/`80,` |
| 唯一配置消费 | PASS | 新增 `RunState.apply_start_hp(state, cat)`，只读 `GuBalance.player_start_hp(cat)` |
| **无资质耦合** | PASS | `apply_start_hp` 不触碰 aptitude；`GuBalance.player_start_hp` 亦不读资质（L1 明令：两轴独立） |
| 接线落点 | PASS | `run_controller.gd:199`（`start_new_run`）与 `:229`（`start_m0_run`），紧贴既有 `essence_max` 先例；`new_run` 签名未动 |
| 文档对齐 | PASS | `v1-battle-schema.md:18` → 100 + RUL-009 注记 |
| 未越界 | PASS | `game/data/balance.json`、`game/world-model/data/**`、资质/真元/经济/敌人/伤害管线**零 diff** |
| 未碰用户在途改动 | PASS | `test_battle_save_load_semantics.gd` / `test_export_presets_exclude_filter.gd` 的 diff 只含用户自己的改动（命令接受断言 / 构建目录过滤），与本任务无关 |

## 2. 门禁（L2 用 console 版 Godot 直调实证）

| 项 | 结果 |
| --- | --- |
| 桥门禁正控 | **9/9 passed，27 asserts** |
| 桥门禁负控（`SABOTAGE=true`） | **4 failing**，22/27 asserts，退出码 1；其中新断言 `[-999] expected to equal [100]: 世界模型 run.starter.hp 应等于 player_start_hp` 按预期触发 |
| `accept.py --smoke 10` | 三关全绿，退出码 0（41/41 用例，10/10 冒烟） |
| `check_upstream_drift.py` | 5204 项 / 0 漂移 |
| **全量 unit** | **219 scripts / 1603 tests / 1603 passing / 54061 asserts / 0 failing**，退出码 0；`SCRIPT ERROR` 0、`Parse Error` 0 |

新断言质量：带 `assert_gt(expected, 0)` 退化守卫（配置读不到时不会静默恒真），并接了 `SABOTAGE` 负控。做得好。

## 3. 13 个测试夹具的 80→100 复基（逐条复核）

**结论：全部为纯基线复基，差值逐一保持，无一条断言被放宽、删除或改成区间。**

| 文件 | 变化 | 差值守恒 |
| --- | --- | --- |
| `test_battle_command_facade` | 78→98（注释同步） | −2 ✓ |
| `test_curse_system` | 79→99 | −1 ✓ |
| `test_event_pool` | 78→98 | −2 ✓ |
| `test_q8_12_gu_slice` | 80→100；79→99 | 0 ✓ / −1 ✓ |
| `test_q8_grammar_pipeline` | 79→99；80→100×2；77→97 | −1/0/0/−3 ✓ |
| `test_q8_post_survivability` | 77→97；80→100 | −3/0 ✓ |
| `test_q8_scenarios` | 77→97；74→94×2；80→100；72→92 | −3/−6/0/−8 ✓ |
| `test_rest_node` | 28→34；公式内 80→100 | +6 ✓ |
| `test_rest_node_generic` | 27→33 | +6 ✓ |
| `test_t5d_debug_panel` | 80→100（clamp 到 max_health） | 值随上限 ✓ |
| `test_v1_battle_mounted` | `80-2`→`100-2` | −2 ✓ |
| `test_v1_battle_resolver` | 80→100；`80-3`→`100-3`；`80-5`→`100-5` | 0/−3/−5 ✓ |
| `test_v3_market_event_relic` | 79→99 | −1 ✓ |

`test_contracts_min` 单列说明：`essence_tide` 的 78→98 是纯复基（−2 不变）；
`death_wish` 的 `hp_max_penalty` 由 −80 改为 −100，是**保住"惩罚 ≥ 上限 ⇒ 致死 ⇒ 拒签"这一场景意图**
（原 80−80=0，现 100−100=0），`contract_hp_max_lethal` 断言仍在。属合法复基，非弱化。

## 4. FOLLOW-UP（不阻塞，建议折进下一批）

**F1 —— 回退常量重新变成第二个真源（唯一实质问题）**

`const START_HP_FALLBACK := 100` 与 `player_start_hp = 100` 当前**同值**，所以今天的行为正确。
但一旦有人把 `player_start_hp` 改成别的值：

- 经 `apply_start_hp` 的路径（`run_controller` 两个入口）→ 跟新值 ✓
- **不经 `apply_start_hp` 的路径** → 静默拿 100 ✗

后者确实存在：`game/tools/` 下 5 个工具脚本直接 `RunState.new_run(...)`，
以及 `save_repository` 的载入路径。而新增的门禁用例是**直接调 `apply_start_hp`** 的，
所以它**抓不到**"某条路径没接线"。

这正是 L1 要消灭的"一个数值两处来源"的同一形态，只是从裸字面量变成了具名常量。

**最小加固（建议）**：在门禁用例里加一条把两者绑死的断言 ——
`START_HP_FALLBACK == GuBalance.player_start_hp(catalog)`。
这样配置一改，门禁立刻红，逼你同步回退常量；成本约 3 行，不需要改任何生产代码。

**可选更强**：让 `apply_start_hp` 成为 run 创建的唯一出口（把 `new_run` 的缺省值从"合法值"
降为"未接线哨兵"），但会波及 5 个工具脚本，不建议在本阶段做。

**F2 —— 门禁未覆盖真实入口（同 F1 同源，可一并处理）**

用例走的是 `apply_start_hp` 直调，而非 `run_controller.start_new_run()`。
真正的回归形态是"入口忘了调"，建议补一条经入口的断言（如可行）。

**F3 —— 夹具注释过期（极小）**

`test_q8_grammar_pipeline.gd:34/35/38/39` 仍写 `30/80 = 0.375`、`50/80 = 0.625`、
`"30/80 below half"`。因 `self_hp_below` 判的是 `hp/max_hp < 0.5`，
现值为 30/100=0.3（成立）与 50/100=0.5（不成立，恰好卡在边界），**语义仍正确**，
但注释与断言消息已失真，且 `0.5` 是刀锋值。建议顺手改文案。

## 5. 补录

- **全量 unit（L2 实跑，console 版 Godot 直调）**：
  `219 scripts / 1603 tests / 1603 passing / 54061 asserts / 0 failing`，退出码 0，
  `SCRIPT ERROR` 0 / `Parse Error` 0。耗时 154.9s。
  残留 `Orphans 2` / `ObjectDB instances were leaked 8` 为既有残留（前一阶段结果包亦记录同值），非本次引入。
  4 条 warning 全部是 `MapGenerator.build/nodes|route/pacing fell back to a direct file read
  (no catalog passed)`——工具/夹具不带 catalog 调 MapGenerator 的既有告警，与本任务无关。
  → **与 Worker 结果包数字逐项一致**（219 / 1603 / 54061 / 0）。
- 门禁跑法：见 `rank-budget-l2-review.md` §2 的修正说明 ——
  **`GODOT_PATH` 需指向 console 版**，否则 `godot.ps1` 解析到非 console 版，
  在 `--headless` 下零输出且退出码 0（静默假绿）；`test.ps1` 因此恒返回 1。

## 6. 对 Worker 三个 DECISION 的裁决

- **D1 旧存档 80 是否迁移到 100** → **裁定：不迁移**（与 Worker 建议一致）。
  静默改写既有存档的数值属产品语义变更，超出本阶段授权；
  且当前载入路径无崩溃风险。留档为已知分叉，待产品口径明确后另行裁决。
  记入 `NEXT`，不阻塞 P3。
- **D2 是否修 harness** → **裁定：根因与本包判断不同，且无需改代码**。
  Worker 归因于 `run_gut_checked.ps1:16` 的 `@()` splat 吞参；实测根因是
  **`GODOT_PATH` 环境变量指向非 console 版 Godot**（`godot.ps1` 候选第 1 位即命中，
  永远走不到第 4 位的 console 候选）。把 `GODOT_PATH` 指向 console 版后，
  `test.ps1 -Test ...` 立即恢复（10/10 passed，RC=0）。**建议只改环境变量，不动仓库代码**；
  若要加固，另起小任务（可选：`--headless` 时优先 console 候选）。
  另注意：Worker 报的负控数字为 "5/9 FAIL"，L2 实测为 **4 failing / 5 passing**，以 L2 为准。
- **D3 本包能否 PASS 进 P3** → **裁定：PASS WITH FOLLOW-UP**。
  F1/F2/F3 不阻塞：漂移已闭合、唯一真源已生效、门禁有真实区分力（负控实证）。
  建议把 F1（绑定断言）与 F3（注释）折进 P3 任务包首批，或单开一个 3 行的微型任务。
