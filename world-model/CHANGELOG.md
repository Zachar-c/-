# 变更记录（CHANGELOG）

本文件只记录 `world-model/` 子项目自身的变更。格式遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 风格，版本遵循语义化版本。

> `world-model/` 是仓库**新增的独立子目录**，它没有修改仓库既有文件（`data/` / `scripts/` /
> `scenes/` / `addons/` / `tests/` / `tools/` / `docs/` / `build/` / `project.godot` 全部保持只读）。
> 因此本文件只描述新增，不描述对既有模块的修改。

---

## [1.0.0] — 2026-09-17

首个交付版本：**可机读世界模型 + 可运行底座**。

### 新增

#### 统一 schema

- `schema/world-model.schema.json`：draft-07 风格统一 JSON Schema；`$defs` 定义 10 类实体
  （`realm` / `path` / `gu` / `economy` / `faction` / `region` / `event` / `loot` / `balance` / `manifest`）
  与 11 个嵌套结构（`recipe_edge` / `shop_offer` / `npc` / `node_template` / `enemy` / `resource` /
  `exchange_rate` / `relation_level` / `event_option` / `material` / `manifest_entry`）。
- `schema/mini_schema.py`：只用 Python 标准库的迷你校验器，支持 `$ref` / `allOf` / `anyOf` / `oneOf` /
  `not` / `if-then-else` / `type`（含类型数组）/ `enum` / `const` / `required` / `properties` /
  `additionalProperties`（bool 与 schema）/ `patternProperties` / `items` / `minItems` / `maxItems` /
  `uniqueItems` / `minProperties` / `maxProperties` / `minimum` / `maximum` / `exclusiveMinimum` /
  `exclusiveMaximum` / `multipleOf` / `minLength` / `maxLength` / `pattern`；提供 `validate()` 与
  `validate_document()`（后者把 envelope 的 `entity_type` 绑定到对应 `$defs`）。
- `schema/README.md`：逐字段说明表（字段名 / 类型 / 取值范围 / 是否必填 / 含义 / 是否可调参），
  外加关键公式表、实体计数表与异常约定表。

#### 机读数据（10 个文件，全部由构建脚本派生）

- `data/realms.json`（36）：1–9 转 × 初/中/高/巅峰。一至五转带原著真元品阶
  （青铜/赤铁/白银/黄金/紫晶）；**六转以上 `essence_tier` 留空**，不臆造原著未明确的内容。
- `data/paths.json`（20）：道途/流派，含 `dao_tags`（开放集合）、起始蛊、蛊池、冲突流派、
  兼修罚值、蛊材共振。
- `data/gu.json`（**802**）：全部蛊虫。每只带 `rank` / `rarity` / `school` / `role` / `value` /
  `tags` / `activation_cost`（含来源标记）/ `feeding` / `effect` / **`effect_source`**
  （`explicit` 57 / `combat_effects` 3 / **`role_default` 742**）/ `low_rank_exception` /
  `refine_as_output`（配方边，含 `input_gu_ids`）/ `refine_as_input` / `shop_offer_ids` / `drop_tiers`。
  `test_slay_gu`（rank 10）标记 `is_test_entity` 并排除出内容池。
- `data/economy.json`（1）：8 种资源（含产出/消耗渠道）、价格锚、37 条商店报价全表、
  5 层预算、通胀参数、5 条黑市汇率、80 种蛊材参考价、仙元石占位（`in_launch_scope: false`）。
- `data/factions.json`（6）：青茅山寨、丹霞商队（原著依据）+ 拾骨帮、瘴蛊教（原创）+ 兽潮压力源 +
  全局恶名轴；每势力 5 档关系阈值与路线/交易/追杀影响。
- `data/regions.json`（7）：南疆宏观区域（内嵌 **32 敌人名册 / 37 节点模板 / 5 NPC / 分类抽取池**）
  + 5 层（行数、宽度、分类权重、锚点、Boss 席位与池、敌人池、预算、商店加价）
  + 升仙之窗。
- `data/events.json`（12）：12 条事件 + 3 条诅咒池；每条含 `options[]`（`accept` 带
  `precheck_required` 与预检文案、`decline` 零效果）、收益/代价/延迟代价/诅咒绑定。
- `data/loot.json`（1）：7 种核心蛊材 + 73 种派生蛊材 + 2 件遗物 + 3 档掉落表 + 保底 +
  按层递变的稀有度权重 + 回购比。
- `data/balance.json`（1）：**集中参数表**。分组 `growth` / `run` / `economy` / `loot` /
  `combat_gate` / `faction`，外加 `formulas`（9 条关键公式的书面记录）。
- `data/manifest.json`（1）：10 个文件的 sha256 / 字节数 / 实体数、版本、生成时间、
  零第三方依赖声明、只读上游清单与 `upstream_write_policy: "read_only"`。

#### 规则与公式层（`engine/`）

- `engine/errors.py`：`WorldModelError` 基类 + `DataMissingError` / `DataFormatError` /
  `SaveCorruptError` / `ResourceExhausted` / `NumericOverflow` / `GuBacklash` / `MetaProgressError` /
  `InputError`，各带 `code` / `message` / `detail` / `as_dict()`。
- `engine/rng.py`：与 `scripts/domain/rng.gd` **位级一致**的 Lehmer LCG
  （`state = state*48271 % 2147483647`）、64 位回绕的 `salt_hash`、`mixed_seed` / `mixed_seed_int`、
  `SeededRng.next_index` / `discard`、无状态 `index()`、有状态 `Stream`（层号进 salt、
  `tick` = 流位置、`chance` / `pick` / `weighted_pick` / `shuffled`）。
- `engine/model.py`：加载 10 个文件 + envelope 结构校验 + schema 校验 + 只读访问器
  （`gu_def` / `realm` / `region` / `material` / `layers` / `all` / `by_id` / `maybe`）、
  `b(*path)` 参数读取（支持内存覆盖）、`data_digest`（所有数据文件的 sha256 聚合）。
- `engine/rules.py`：
  - 修炼：`essence_max` / `essence_max_battle` / `essence_regen_per_turn` / `natural_recovery_rate` /
    `stone_to_essence` / `can_cultivate_to`（丙等三转硬门槛）/ `cultivation_cost`；
  - 蛊虫：`gu_instance` / `gu_value` / `feeding_bill` / `settle_feeding`（欠账→降阶+扣血）/
    `activate_gu`（`strict` 零副作用预检 + `strict=False` 强催反噬）/ `resolve_effect` /
    `refine_gu` / `free_mix` / `backlash_preview`；
  - 战斗：`enemy_profile`（层倍率 + 回合膨胀 + 难度旋钮）/ `_normalize_phases` /
    `resolve_player_action` / `enemy_turn`（相位切换 + 意图冷却 + 封蛊/摄魂/折寿/焚元）/ `check_death`（三轴）；
  - 掉落：`loot_weights` / `normalize_material_pool` / `battle_stone_reward` / `roll_loot`（保底按档独立）；
  - 继承：`apply_ending`（**只返回本局新增**的图鉴/配方；`numeric_growth` 非空即抛 `NumericOverflow`）。
- `engine/run.py`：`Run` 状态机。开局构建、地图生成（行/宽度/分类权重/锚点/强制休整/Boss 席）、
  行内选点、12 类节点结算、回合制战斗、阶段总账、僵局保护、结算与 Meta 继承，
  以及脚本化自动决策器（`auto_step` / `_auto_pick_node` / `_auto_node_choice` / `_auto_battle`）。
  台账 `content_sha256` / `state_digest` 用于可复现性验证。
- `engine/persistence.py`：原子写（tmp → `os.replace` + `fsync`）、信封（版本 + `sha256` 校验和）、
  Run 存档与大厅存档、台账写入（header + 逐事件行，header 带 `content_sha256`）、
  台账比对（`compare_ledgers`）、损坏隔离恢复（`recover_run` → `*.corrupt.json`）。

#### 可玩运行器（`runner/cli.py`）

- 交互式（stdin 逐行）、`--auto`、`--replay`、`--status`、`--seed`、`--seed-count`、`--quiet`。
- 大厅流程：检测进行中存档 → 提示「开新局会放弃这份存档」→ 新局 / 恢复。
- 任意非法输入回显明确提示（`InputError` 等全部被捕获），不抛未捕获异常。

#### 工具

- `tools/build_world_model.py`：从**只读**上游 `../data/*.json` 派生 10 个数据文件。
- `tools/build_mapping_table.py`：从 `data/*.json` 生成 `docs/原著要素映射表.md`（966 行映射）。
- `tools/validate_world_model.py`：5 大类 **64,556 条**断言，报告写入 `reports/validation-report.md`。
- `tools/simulate_balance.py`：批量模拟 + 灵敏度扫描，报告写入 `reports/balance-simulation.md`，
  自动产出「结论 / 待确认项」。

#### 测试

- `tests/run_tests.py`：**39 个断言式用例**，只用标准库，退出码 0/1，支持名称过滤。

#### 文档

- `docs/世界模型总纲.md`、`docs/原著要素映射表.md`、`docs/肉鸽运行结构.md`、
  `docs/数值与成长曲线.md`、`README.md`、`HANDOFF.md`、`RISK_REGISTER.md`、
  `REVIEW_CHECKLIST.md`、`CHANGELOG.md`、`VERSION`、`.gitignore`。

### 修复（世界模型内部发现并修掉的问题）

- **RNG tick 语义**：任务描述里的旧口径（tick 仿射混入种子）会产生等差阶梯。本版本采用仓库
  `scripts/domain/rng.gd` 在 2026-09-10 修正后的「tick = 流位置（`discard`）」语义，
  并用断言守住（相邻抽取差值集合必须 > 1）。详见 `RISK_REGISTER.md` RISK-12。
- **战斗僵局**：原型口径下敌人所有意图同时处于 cooldown 时双方可能都无法终结战斗。
  新增原创规则 `run.max_battle_rounds = 40` + `stalemate_rule: retreat_with_cost`
  （超限即撤退，付元石，不足则付气血 10%），日志记 `battle_stalemate`。详见 RISK-11。
- **战斗死亡漏记**：原型只写 `battle_enemy:death` 而不写标准 `death` 事件，导致死因统计为空。
  本版本在战斗路径补写标准 `death` 事件（含 `axis` / `cause_zh` / 三轴读数）。
- **台账泄漏全局状态**：`run_end` 记录最初包含大厅累计图鉴数，导致同种子台账随玩家已玩局数变化，
  破坏可复现性。改为只记录**本局新增**（`run_codex_gu` / `run_recipes`），
  并加测试 `ledger_is_independent_of_hall_progress` 守住。
- **节点重复结算**：最初节点动作不推进行号，导致自动决策器在同一节点死循环（实测把元石刷到 99836）。
  改为「一行一节点，动作后自动推进」，`advance_row` 是唯一推进点。
- **升炼图边方向**：`refine_as_output` 是按**输出蛊**索引的，最初把持有者 id 当作边起点，
  导致升炼图恒为空。改为从 `input_gu_ids` 取起点，图论事实变为 88 节点 / 97 边 / 0 环 / 最长链 5 步。
- **校验器顺序依赖**：引用完整性检查在同一个循环里既构建 `recipe_ids` 又查询它，
  导致 67 条误报。改为两趟（先收集全部配方 id，再校验反向引用）。

### 已知限制（不视为缺陷，已登记）

- 742 只蛊只有角色兜底效果（RISK-05）。
- 兽骨占配方材料 96%（RISK-07）。
- 黑市双向汇率不对称约 100 倍（RISK-06）。
- 终局 Boss `miasma_vein_lord` 数值倒挂（RISK-09，上游问题）。
- 双套 `regen_pct` 并存（RISK-08，上游既有差异，本包拆名保留）。
- 本机无 Godot，未做运行时对拍（RISK-04）。

---

## 版本升级约定

| 变更类型 | 版本位 |
| --- | --- |
| schema 不兼容变更（删除字段、改字段类型、改 envelope 形状） | `MAJOR` |
| 改世界规则（增删实体、改实体语义、加新数据文件） | `MINOR` |
| 只调参数（`balance.json` 数值、权重、成本） | `PATCH` |

改版本号只需改 `world-model/VERSION` 并重跑 `tools/build_world_model.py`，
`data/*.json` 的 `world_model_version` 与 `manifest.json` 的 `version` 会自动同步。
