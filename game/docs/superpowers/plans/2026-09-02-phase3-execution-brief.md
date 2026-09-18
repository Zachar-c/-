# 阶段三执行交接单：蛊虫实例与蛊师模型（T3.1 + T3.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)（10 阶段 / 20 提交任务）
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §2.1（蛊虫实体字段清单）、§11.1-§11.4（真元海与成本）、§12.1-§12.2（念头）、§14.1（肉身）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `09e7723`，工作树干净，与 `origin/master` 同步。开工前跑 `git status --short --branch` 确认。
- 阶段一、二已合入。阶段二审查结论：**通过**。全量回归 `tools/test.ps1 -Suite all` 退出码 0、零失败；unit 985/984（1 个 pre-existing pending：`test_drive_to_ending` 因深层战斗平衡挂起，非本批问题）；integration 13/12（同一个 pending）。
- 行数门禁：`resolver.gd` 2454 ≤ 2457（ffe3aa6 已把门禁恢复到计划基线）、`battle_resolver.gd` 1514 ≤ 1516。
- 数值单一真值：`data/balance.json` + `scripts/domain/gu_balance.gd` 为唯一公式源；`actual_cost_percent(native, gu_rank, cultivator_rank, cat)`、`natural_recovery(aptitude_percent, cat)`、`beast_scale(rank, cat)` 均已按规格实装并有锚点测试（`tests/unit/test_central_numbers.gd`）。
- **关键现状：`RunState.gu_instances` 已存在**（`scripts/domain/run_state.gd:47`，9/1 批次引入，Dictionary，键为 instance_id）。现有实例字段只有 `instance_id / definition_id / state（"refined"/"contracted"/"weakened"）/ rank（可选）`，远少于规格 §2.1 清单。约 8 个文件在读写它（`battle_resolver`、`loot_resolver`、`action_preview_service`、`run_snapshot_builder`、`run_controller`、`debug_actions`、`resolver`、`playthrough_smoke`）。**T3.1 是补齐字段 + 抽模型模块，不是从零新建容器**；存量键名不得随意改名，除非同步迁移全部读取方并在报告中说明。

---

## 任务 0：阶段二审查收尾补丁（1-2 个小提交，先于 T3.1）

### P0.1 schema_v4 玩家文案接线（提交 A，必做）

- 问题：阶段二统一了拒载契约（`load_run()` 失败返回拒载字典），但玩家仍然看不到 T1.1 规定的文案。`run_controller.load_saved_run()`（第 424-428 行）先用 `diagnose_run_file()` 短路，`_save_load_feedback(last_load_diagnosis)`（第 430 行）对 v3 显示的是笼统的"上次冒险存档版本不受支持（v3）。"——不含"大厅进度、蛊方图鉴与已解锁信息已保留"的安抚信息。拒载字典里的 message（`save_repository._run_load_rejection`）只存在于领域层。
- 修法（最小改动）：`_save_load_feedback` 对 `kind == "unsupported_version" and version == 3` 的分支改用 `SaveRepository._run_load_rejection(diagnosis)["message"]`（或在 match 外先取拒载字典 message 优先展示）。
- 先红后绿：在 `tests/unit/test_save_gate_v4.gd`（或 run_controller 既有测试）加一条断言：v3 拒载场景下 UI 反馈文本包含"已保留"。
- 验收：聚焦测试 + `-Suite all` 全绿。

### P0.2 阶段二遗留小项（提交 B，可选合并进提交 A 亦可，但不与 T3.x 混合）

1. `scripts/domain/economy_rules.gd` 缺 EOF 换行（上一批刚修完四个文件又漏了它）。
2. `scripts/domain/resolver.gd` 与 `economy_rules.gd` 重复定义 `SERVICE_USE_FLAG_PREFIX`（economy_rules 注释已声明是镜像拷贝）——收敛为单一定义点（如 economy_rules 定义、resolver 引用），防漂移。
3. （可选，涉及面稍大）`balance.json` 键 `aptitude_recovery_base` 与规格 §11.4 参数名 `aptitude_recovery_multiplier` 不一致；值语义相同。若重命名，同步 `gu_balance.gd`、`content_catalog.gd` Schema、`test_central_numbers.gd`、`test_gu_balance_schema.gd`。重命名与否在完成报告里说明理由即可。

---

## T3.1 蛊虫实例实体（提交 C）

- **范围**：新增 `scripts/domain/gu_instance.gd`（`class_name GuInstance`，纯数据 + 工厂 + 校验 + 序列化助手）；补齐 `RunState.gu_instances` 现有字典的 §2.1 字段。**不改任何现有运行时行为**（炼蛊/喂养/战斗的行为切换在 T5/T6/T4 批次）。
- **固定接口**（§2.1 全字段，具体键名以规格为准）：
  - `definition_id`（同名蛊共享）、`instance_id`（全 Run 唯一，沿用 `RunState.next_gu_instance_id` 的确定性分配）、`rank`；
  - `refine_state`（对应现有 `state` 字段的语义——建议保留存量键 `state` 不动，由 GuInstance 提供命名访问器，避免 8 处读取方同步改名；若规格键名强制不同，做键名迁移并在报告列明全部迁移点）；
  - `core_state`（T7.1 会扩展，本批先留默认值字段）、`hunger_phase`、`next_feed_need`、`lifecycle`（一次消耗/有限次数/长期）；
  - `loyal`（忠主）、`ferocity`（凶性）、`parasitic`（寄生）、`flee`（逃遁）、`sealed`（封存）；
  - 实例级改造及来源（列表，条目含来源标识，为 §17.3 事件日志留钩子）。
- **先红后绿**：新增 `tests/unit/test_gu_instance_model.gd`：
  1. 同 `definition_id` 创建两实例，`instance_id` 必不同（对现状红：现工厂只补 3 个字段）；
  2. §2.1 字段清单逐键存在且有合法默认值；
  3. 序列化 round-trip：v4 存档只含 id 与数值/字符串，不含引擎对象（复用 `test_save_gate_v4` 的守卫风格；`run_state.gd:73` 已把 `gu_instances` 纳入序列化清单）；
  4. GuInstance 工厂从既有 `gu.json` 定义 + catalog 构造实例，缺字段不崩溃。
- **最小实现边界**：创建实例的入口（`loot_resolver`、`debug_actions`、`resolver` 等）改走 GuInstance 工厂补齐字段，但**不得改变它们的返回值/事件语义**；存量旧实例（无新字段）经 `GuInstance.normalize()` 补默认值，读取方零感知。
- 验收：`tools/test.ps1 -Test "tests/unit/test_gu_instance_model.gd"` + `-Suite all`。
- 退出条件：v4 Run 可携带完整实例列表；所有既有测试零修改通过（零行为漂移）；旧 `deck`/`cards` 字段不动（阶段十清退）。

## T3.2 蛊师模型：真元海、念头、肉身（提交 D）

- **范围**：新增 `scripts/domain/cultivator_rules.gd`（`class_name CultivatorRules`，纯静态规则）+ `RunState.cultivator` 字典补字段。**不动旧真元行动点路径**（`essence_regen_per_turn` 等由 T10.1-⑤ 清退）。
- **固定接口**：
  - `can_activate(cultivator_rank, gu_rank, low_rank_exception := false)`：低转不能催普通高转蛊；珍稀蛊以 `low_rank_exception` 豁免（§11.2）；
  - `actual_cost_percent(native, gu_rank, cultivator_rank, cat)`：**薄委托 `GuBalance.actual_cost_percent`**，禁止第二份折算实现（drift 门禁会抓）；仅 `cultivator_rank >= gu_rank` 时适用，资格判断在本模块；
  - `natural_recovery(aptitude_percent, cat)`：薄委托 `GuBalance.natural_recovery`；
  - 念头容量：`thought_capacity = 3 + 智道蛊加成`（§12.1；加成来源读 catalog，**与魂魄彻底分离**——不得读 `soul`/`soul_capacity`）；
  - 肉身（§14.1）：`health = 100` 尺度、`strength`、`body_capacity`，均来自 `human_base_*` 锚点投影，**升转零自动增长**。
- **先红后绿**：新增 `tests/unit/test_cultivator_rules.gd`——
  1. **验收 #5**：构造升转前后的 cultivator 状态，断言念头容量/气血/承载/速度逐字段不变；
  2. **验收 #6**：1 转催 2 转拒绝；低转催高转珍稀蛊（`low_rank_exception=true`）放行；折算公式逐位断言（2 转蛊师催 1 转 10% 蛊 = 5%，同转 = 原值）；
  3. **验收 #14 数值半边**：蛊师气血 = `human_base_health = 100` 尺度；
  4. 念头容量与 soul 值无耦合（改 soul 不影响 thought_capacity）。
- `soul_capacity.gd`：仅在文件头加注释标记"旧魂魄派生上限，由念头账本（§12.1）替代，T10.1-③ 删除"——**不改任何逻辑**。
- `RunState.cultivator` 新键（如 `thought_capacity`、`body_capacity`）仅声明与默认值填充，无任何读取方行为切换。
- 验收：`tools/test.ps1 -Test "tests/unit/test_cultivator_rules.gd"` + `-Suite all`。
- 退出条件：#5/#6/#14 数值半边绿；全量绿；resolver/battle_resolver 行数不增；`soul_capacity.gd` 标记在位。

---

## 全局纪律（每一批）

1. 每任务独立提交，禁止跨任务混合：`feat(spec-v4): T3.1 ...` / `test(spec-v4): T3.1 先红测试`；补丁提交用 `fix(spec-v4): P0.x ...`。
2. 先红后绿：每条新测试先在现状下失败，把红的证据写进提交说明。
3. resolver 门禁：`resolver.gd` ≤ 2457（当前 2454，余量 3 行）、`battle_resolver.gd` ≤ 1516；T3.x 不触碰这两个文件的行数。
4. 禁区：`分支：六卷精编版/`、`肉鸽设计-原始数据/`、`豆包/`、`旧稿归档_不采用/`、`重写稿/`、`.worktrees/`、`vendor/` 只读。
5. 标识符 ASCII，玩家可见中文 UTF-8；数值一律进 `balance.json` 过 Schema。
6. 测试基线只增不回退：任务 0 完成后的全量绿是底线。
7. 不夹带：发现跨阶段缺陷记录到完成报告，不在 T3.x 提交内顺手修。
8. 确定性：实例 id 分配、字段默认值不得引入未种子化随机。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与改动文件清单；每条验收命令及结果；`refine_state`/`state` 键名的裁定与迁移点列表（若有）；`gu_instances` 存量实例兼容策略；P0.2 各小项是否执行及理由；`-Suite all` 最终汇总数字（Tests/Passing/Failing/Pending）；未验证风险与遗留问题。
