# L2 Review · P2 Rank Power Budget

```text
REVIEW STATUS: PASS WITH FOLLOW-UP —— 但带 1 项 BLOCKING（HP 80/100 半应用，见 §3）
REVIEWER: L2 Orchestrator
SUBJECT: ai-system/tasks/rank-budget-result.md（Worker: OpenCode + Muse Spark 1.3）
DATE: 2026-09-19
```

## 1. 结构部分：PASS（L2 独立复算，不采信 Worker 自述）

| 检查项 | 结论 | L2 独立证据 |
| --- | --- | --- |
| 唯一真源 `rank_power_budget` | PASS | `game/data/balance.json:14-22`：`rank1_budget=40`，`budget_by_rank={1:40,2:80,3:160,4:320,5:640}`＝40×2^(r-1)，零漂移 |
| 与旧 `standard_gu_power` 恒等 | PASS | 旧式 `100×0.2×2^r` → 40/80/160/320/640；新式 `rank1×2^(r-1)` 同值；`r=0` 两式均 20。`gu_balance.gd:standard_gu_power` 已改为委托 |
| 六曲线归位标注 | PASS | `rank_axis_annotations` 8 条；`standard_gu_power`→`source_of_truth`，真元两条→`essence_budget`，`gu_value_by_rank`→`economy`，boss 层→敌人/关卡，进阶奖励→进度，`beast_scale`→`parallel_reference` |
| 范围外数值未动 | PASS | 展平 old/new JSON 逐键比对：仅新增 `rank_axis_annotations.*` 子树与 rank budget 子树有 diff；`gu_value_by_rank`/`boss_layer_mult`/`advance_bonus_by_rank`/`beast_scale` 值全同 |
| 派生镜像非手改 | PASS | `world-model/data/balance.json` 由 `build_world_model.py` 重生成；`entities[0].run.starter.hp=100` 且带 `hp_source: "player_start_hp"` |
| 断言可执行（R5） | PASS | `validate_world_model.py: §6 check_rank_budget` 27 断言 |
| 上游漂移 | PASS | `check_upstream_drift.py` → 5204 项 / 0 漂移（L2 实跑） |
| 一键验收 | PASS | `accept.py --smoke 10` → 三关全绿，退出码 0（L2 实跑：校验 0.6s / 测试 41-41-0 / 冒烟 10/10） |

## 2. Godot 侧门禁（L2 实跑）

- **跑法修正（2026-09-19 二次核实，推翻本节初版）**：本节初版称单文件测试"必须走
  `game/tools/test.ps1`"，并且把"harness 退出码 1"当作"失败被正确传播"的证据。
  **这两条都错了。**
  实测：`game/tools/test.ps1 -Test tests/unit/test_dda_resolver.gd`（**未改动的文件**）
  → 退出码 1，输出只有 2 行 Godot 横幅，**GUT 根本没跑**。
  即该 harness 在本机**恒返回 1**，与测试结果无关，不具备区分能力。
- **根因**：`game/tools/godot.ps1` 不带 `-Console` 时解析到**非 console 版** Godot，
  该二进制在 `--headless` 下不向 stdout 输出任何内容且退出码为 0；
  `run_gut_checked.ps1` 靠文本解析判定"是否真的跑了"（line 24/26-30），
  拿不到输出即判失败 → 恒 RC=1。
  对照：直接用 **console 版** `Godot_v4.7.2-stable_win64_console.exe` 跑同一文件
  → 40 行正常输出、10/10 passed、RC=0。
- **危险的一面**：直接跑 `godot.ps1`（非 console 版）会得到 **RC=0 + 零输出**的
  静默假绿。**"测试通过"必须以真实 GUT 文本输出为准，不能只看退出码。**
- 正控（console 版直调）：`test_world_model_bridge.gd` → **8/8 passed，20 asserts**。
- **负控**（console 版直调）：`const SABOTAGE := true` → **3 tests failed，16/20 asserts**
  （`test_gate_is_not_left_sabotaged` / `test_gu_table_matches_production_gu` /
  `test_shop_offers_match_production_shops`），退出码 **1**。
  → 门禁内容本身不是空转。已还原 `SABOTAGE := false`，该文件零内容 diff。

## 3. BLOCKING —— HP 80/100 是半应用状态

**现象**：世界模型侧已全线 100，可玩 Godot 侧仍是 80，同一条数值两个真源。

| 位置 | 值 | 说明 |
| --- | --- | --- |
| `game/data/balance.json:9-11` | `standard_human_hp=100` / `player_start_hp=100` / `ratio=1.0` | P2 新增，唯一真源 |
| `game/world-model/data/balance.json` | `run.starter.hp=100` | 派生镜像，随构建器 |
| `game/world-model/data/economy.json:129-130` | `health.start_value=100` / `hard_cap=100` | P2 由 80 改 100 |
| **`game/scripts/domain/run_state.gd:18-19`** | **`var health: int = 80`** | **未动** |
| **`game/scripts/domain/run_state.gd:112-113`** | **`"health": 80, "max_health": 80`** | **未动（存档序列化）** |

后果：世界模型冒烟（70.0% 通关率、终局气血均值 87.6）**不代表可玩游戏的实际情况**；
玩家实际仍以 80 血开局。P2 全部平衡结论对"游戏本体"暂时不成立。

**并且 L1 的裁决前提与实际不符**：RUL-2026-09-19-008 D11 写「80 只是构建脚本中的孤立字面量，
无设计依据」。实测 80 是**文档化的「出身气血」**，至少三处：

- `game/scripts/domain/run_state.gd:16`：`# 2026-08-31 数值重做：出身丙等满真元 20（10×丙等2×一转1）、80 气血、60 年寿元、魂魄底蕴 1`
- `game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md:18`：`"hp": 80, "max_hp": 80,  # 出身气血（cultivator.health，随重做 80）`
- `game/world-model/reports/numeric-status-audit.md:373`（C9 条目，本会话早前已独立认定该分叉）

补充口径：与 80 相伴的 **真元 20 有显式推导公式**（10×丙等2×一转1）；
**80 气血无任何推导公式**，只有注释记录。即：80 有出处（文档化），但无设计推导。

**L1 同一段裁决其实已预先授权该组合**：
> 「玩家开局可以为 80，但必须变成**显式设计**：`standard_human_hp = 100` 与 `player_start_hp = 80`
> 各自独立配置并说明『玩家开局是标准一转肉身的 80%』。」

即 L1 真正的要求是「**显式成对、不许藏裸字面量**」；P2 已把结构做对（成对 + `hp_source` + 注释），
只是填了 `100/100` 而非 `100/80`。

## 4. 处置 —— L0 已裁定：挂起，只回抛 L1

**这是产品意图问题（丙等出身是否即「弱小开局」），属 L0 权限，L2 不自行改。**
L0 于 2026-09-19 裁定：**不改任何 HP 值，只写更正件回抛 L1 重裁**。

已交付：`ai-system/RESEARCH-REQUEST-2026-09-19-hp-baseline-correction.md`
（自足稿，内嵌 D11 原文 + 三处 80 的出处 + 半应用分叉表 + 已知取舍，L1 无需访问仓库）。

两份可能的出路（等 L1 回答后二选一）：

- **A 保持 100**（照 L1 `action_now` 字面执行）：需另开小任务把 `run_state.gd` 3 处 80 接到
  `GuBalance.player_start_hp`。可玩游戏气血 80→100，是真实平衡变动（L1 D11 已接受，
  Worker 已量化：通关率 68.0%→70.0%）。
- **B 改回 80**（照 L1 已授权的显式对 + 仓库既有出身气血）：`player_start_hp=80`、
  `player_start_hp_ratio=0.8`，并回滚 `world-model/data/economy.json` health 80。
  可玩游戏行为零变化。

**P3（统一 Effect 管线）在基准统一前不开**——所有效果数值都会继承这个 HP 基准。

### 4.0 L1 重裁回执（2026-09-19，已收到）

L1 裁定 **100**，但**撤回**原 D11 论证句「80 只是构建脚本中的孤立字面量，无设计依据」，
论证改写为「保持**资质/真元**与**肉身/HP**两条成长轴语义独立」。
逐字文本已录入 `game/world-model/rulings/RUL-2026-09-19-009.json`；
`RUL-2026-09-19-008` 的 `decisions[10]` 已加 `revised_by` 标记。

L1 对 Q2/Q3 的口径：**丙等 ≠ 弱肉身**；若未来产品明令弱肉身开局，
`player_start_hp = 80` 可直接作为有产品语义的设计常量，**不需要伪造资质系数公式**。
L1 并接受 L2 的 §4.1 事实更正（moot 了「+2/+6」那条错误前提）。

结论落地：L1 定性该分叉为**实现漂移**，指令派小任务接通 runtime HP source。
→ 已派 L3：`ai-system/tasks/wire-runtime-hp-source.md`。
`game/AGENTS.md` 已登记新不变量（资质/肉身/魂魄独立轴 + 禁止「丙等 → HP ×0.8」默认规则）。

### 4.1 L2 自查发现的自身错误（已更正）

本会话给 L1 的转数 RR（Q11）中曾写「气血每回合还有 `+2`、上限 `+6` 的增长规则」。
**该陈述错误**：`run.turn_scaling.hp_add_per_turn=2 / hp_cap_bonus=6` 是**敌人在单场战斗内**
的回合膨胀（作用于敌人数值块），与玩家气血无关。
玩家侧无逐回合气血增长，只有休整节点静养恢复上限 30%（`run.rest_heal_pct=30`）。
已在原 RR 就地加更正块，并在更正件 §3 说明。
→ 教训：跨文件概括数值规则时，必须回到**应用点**（此处 `world-model/engine/rules.py:395-413`）确认作用对象，
不能只读键名。

## 5. 顺手留档

- P2 未新增裸字面量：`build_world_model.py` 中原 `"hp": 80` 已改为读 `player_start_hp`。
- Worker 协议、测试、既有 `git diff --check` 均正常；未 commit / 未 push（符合 worker 纪律）。
