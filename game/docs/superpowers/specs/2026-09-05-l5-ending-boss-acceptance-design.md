# 待办 4：L5 / Ending 验收与层级 Boss 设计

> 审阅：✅ 2026-09-06 用户审订通过（定稿）

## 目的

落实 `AGENTS.md` 待办 4：固定 25-seed 验收中，大部分运行抵达 L5，且超过一半进入统一 `Ending`；一至五层 Boss 只按对应层级形成数值考验，不以玩家当前修为作为进入或作战的硬门槛。

本设计建立在现有 V1 战斗契约和固定 25-seed 驱动之上，不恢复旧 deck / hand / discard 模型，不绕过 `RunController.submit_command()`。

## 当前基线

固定种子为：

```text
1, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41,
43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
```

当前实测结果：

- 22/25 抵达 L5 并进入 `Ending`。
- 43、73、79 在 L3 极端敌对商队停滞：会话为 `offers_fight=true`，驱动却尝试离场并收到 `feud_no_escape`。
- 三个失败不是 Boss 数值造成的。
- `data/v1_battle.json` 已定义 `boss_layer_mult`，但当前没有代码消费该配置。
- `BattleCommandFacade.start()` 经 `_v1_enemies()` 是当前 V1 敌人定义转战斗条目的统一入口。
- 地图越层只要求对应 `boss_defeated_L{n}`，当前没有玩家修为入场判断。
- 高阶蛊仍受 `CultivatorRules.can_activate()` 约束；这不是 Boss 硬门槛，必须保留。

## 验收口径

1. **抵达 L5**：驱动从控制器当前节点或战斗记录中直接观察到 layer 5。
2. **进入 Ending**：驱动实际观察到 `current_view_name() == "Ending"`，不能从 terminal 状态或事件倒推。
3. **发布阻断下限**：25 个种子中至少 13 个抵达 L5，且至少 13 个进入 `Ending`。
4. **基线回归目标**：本次修改后两项均不得低于当前 22/25；如未来有明确且经批准的平衡调整，才可显式更新基线常量。
5. 13/25 只表达待办文字的最低发布门槛，不把“略高于一半”当作期望质量目标，也不要求追求25/25。

## 设计范围

### 本次落实

1. 修复验收驱动对不可逃敌对商队的动作选择。
2. 在 V1 敌人统一构造路径中应用 `boss_layer_mult`。
3. 在现有 trace 上补充 L5 / Ending 聚合字段与断言。
4. 在现有 `tests/unit/test_battle_command_facade.gd` 中增加最小倍率与无硬修为门槛覆盖。
5. 全部验收通过后，在完成清单中更新 `AGENTS.md` 待办 4。

### 明确不做

1. 不改变 `extreme_hostile` 的 `feud_no_escape` 领域规则。
2. 不取消高阶蛊的修为品质限制。
3. 不自动升转，也不因击败 Boss 直接改变修为。
4. 不散改 `data/enemies.json` 中各 Boss 的独立数值。
5. 不直接写运行状态、不调用领域 resolver、不注入必杀蛊来提高验收结果。
6. 不新增独立 trace 导出器、报告文件、嵌套逐层日志 schema 或持久化诊断系统。
7. 不修改无关视觉规格、视觉资产、`MEMORY.md`，也不处理 Dialogue Manager UID 警告。

## 实现设计

### 1. 层级 Boss 数值缩放

负责文件：`scripts/domain/battle_command_facade.gd`

`BattleCommandFacade.start()` 在调用 `V1BattleResolver.start()` 前，根据 `encounter.layer_boss` 从 `v1_battle.boss_layer_mult` 读取 `one` 至 `five` 的倍率，并在现有 `_v1_enemies()` 直接调用链中缩放：

- 敌人初始 `hp`；
- 攻击意图的 `damage`。

普通遭遇不缩放。倍率缺失、层号无效或字段缺失时回退 `1.0`。最终整数使用确定性四舍五入，并保持以下边界：

- 原 HP 大于 0 时，结果至少为 1；
- 原伤害为 0 时仍为 0；
- 原伤害大于 0 时，结果至少为 1。

缩放只依赖 Boss 层号和中央配置，不读取 `state.cultivation`。非攻击意图的其他字段保持原样。

### 2. 敌对商队驱动

负责文件：`tests/integration/test_drive_to_ending.gd`

`_step_shop()` 在购买逻辑和离场前检查当前会话：

1. 当 `offers_fight=true` 且会话不允许离场时，从 `ActionPreviewService.preview_actions()` 取得可执行的 fight 动作。
2. 复用动作卡已有命令封装，经 `RunController.submit_command()` 提交。
3. 进入 Battle 或命令成功时继续运行。
4. 若会话要求接战却没有可执行 fight 动作，返回包含节点和拒绝原因的明确契约错误，不循环、不篡改 stance、不直接启动战斗。
5. 没有必须处理的战斗时，维持原有购买和离场流程。

### 3. 最小验收统计

复用现有 `boss_pre_states`、`battle_turns`、`_record_battle_turn()`、`_footprint` 和 `DRIVE_SWEEP` 输出，不建立第二套追踪结构。

每个 trace 只新增：

- `max_layer`；
- `reached_l5`；
- `entered_ending`。

更新规则：

- 每轮从控制器当前节点或当前战斗直接更新 `max_layer`；
- `max_layer >= 5` 时置 `reached_l5=true`；
- 只有实际观察到 `Ending` 视图时置 `entered_ending=true`。

现有 Boss 快照与回合记录仅作失败诊断；成功 seed 不新增完整持久化历史。失败时输出 seed、最高层、玩家 HP、敌人 HP、intent、最后拒绝原因以及已有 Boss 前快照。只有现有信息仍不足以定位固定种子失败时，才考虑补充更细追踪。

聚合测试同时断言：

```text
reached_l5_count >= 13
entered_ending_count >= 13
reached_l5_count >= 22
entered_ending_count >= 22
```

前两项是规格下限，后两项是当前基线回归保护。`leave_blocked`、`no_route`、`steps_cap` 等软锁不能算作合法终局；固定种子不得再以 `leave_blocked:feud_no_escape` 结束。

## 无硬修为门槛

“Boss 不作硬性 cultivation gate”定义为：

1. 玩家修为低于 Boss 层级时，仍可创建该 Boss 战。
2. 战斗创建不得因修为差而拒绝。
3. 玩家可执行该修为本来允许的基础行动和低阶蛊行动。
4. 越层仍只依赖 Boss 胜利旗标，不要求玩家达到同层修为。
5. 超出玩家品质能力的高阶蛊仍返回 `insufficient_qi_quality`。

本次不新增任何 `player.cultivation < layer_boss` 形式或等价的准入判断。

## 最小测试覆盖

统一复用 `tests/unit/test_battle_command_facade.gd`，不新增只有少量用例的第二个 facade 测试文件。

### Boss 倍率

以四类测试覆盖：

1. 普通战斗不缩放。
2. 参数化验证 L1 至 L5 的 HP / attack damage 对应中央倍率。
3. 缺失配置和非法层号回退 `1.0`。
4. 验证确定性取整、最小 HP、零伤害与最小正伤害边界。

### 无修为硬门槛

一个最小回归用例验证：

1. 正常一转状态可创建高层 Boss 战，并得到 Boss 标记。
2. `basic_attack` 被接受。
3. 一个超出修为品质的高阶蛊仍返回 `insufficient_qi_quality`。

不扩展为新的 cultivation 测试套件，不要求一转角色击杀五层 Boss，也不重复测试升转或完整五层通路。

### 25-seed 集成验收

1. L5 与 Ending 均达到 13/25 发布下限。
2. L5 与 Ending 均不低于 22/25 当前基线。
3. 不出现由驱动错误产生的 `leave_blocked:feud_no_escape`。
4. 非成功结果保留明确分类。
5. seed 101 的既有死路回归继续通过。

## 数值调整原则

先接通现有倍率并运行完整 25-seed：

1. 若达到发布下限和 22/25 基线，不为追求 25/25 自动削弱 Boss。
2. 若不达标，先区分 Boss 战败、普通战斗战败、路线软锁和驱动策略失败。
3. 只有 Boss 数值确实导致回归时，才调整 `data/v1_battle.json` 的 `boss_layer_mult`。
4. 不在多个敌人定义中复制倍率。
5. 每次调整后重跑同一固定种子集；任何基线变更必须明确记录，而不是静默放宽断言。

## 数据流

```text
地图选择 Boss 节点
  -> RunController._start_battle()
  -> encounter.layer_boss
  -> BattleCommandFacade.start()
  -> _v1_enemies() 构造并按中央配置缩放敌人
  -> V1BattleResolver.start()
  -> RunController.submit_command() 驱动作战
  -> 胜利记录 boss_defeated_L{n}
  -> MapGenerator 允许前往下一层
```

链路中不存在玩家修为与 Boss 层号的准入比较。

## 完成标准

1. 中央 Boss HP / damage 倍率在统一权威路径中实际生效。
2. 低修为玩家可创建并操作高层 Boss 战，高阶蛊品质限制保持有效。
3. 固定 25-seed 的 L5 与 Ending 数量均至少为 13，且不低于当前 22/25 基线。
4. 敌对商队不再因驱动错误选择离场而软锁。
5. 精简后的 facade 单元测试、25-seed 集成验收和 seed 101 回归通过。
6. 相关更广测试未出现由本改动造成的回归。
7. 上述证据成立后更新 `AGENTS.md` 待办 4。

## 预计修改文件

- `scripts/domain/battle_command_facade.gd`
- `tests/unit/test_battle_command_facade.gd`
- `tests/integration/test_drive_to_ending.gd`
- `data/v1_battle.json`（仅在完整实测证明需要调参时）
- `AGENTS.md`（仅在全部完成标准满足后）

不提交或推送，除非用户另行要求。
