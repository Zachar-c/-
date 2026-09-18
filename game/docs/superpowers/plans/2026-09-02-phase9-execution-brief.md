# 阶段九执行交接单：UI 命令面与快照切换（T9.1 + T9.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §17.2（UI 透明八组）、§17.3（领域与日志：预检同源、事件全清单）、§16.5（tooltip 数值精度既有约束）。**另须通读三份契约文档**（见下），本批的每一项产出都以"回写契约"为收尾动作。
> 仓库约束：遵守 `AGENTS.md` 全部条款——注意 `权威资料` 节已新增三份契约文档与其回写义务。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `480183a`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至八全部合入。阶段八审查结论：**通过**（1 个 P3 调参常量问题，见任务 0）。全量 `-Suite all` 退出码 0、零失败（unit 1097/1096 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。
- 行数门禁：`resolver.gd` **2452 / cap 2457（余量仅 5 行）**、`battle_resolver.gd` **1514 / cap 1516（余量 2 行）**——**本批是全程门禁最紧张的一批**，见 §3 特殊纪律。
- **必读契约（本批的需求来源与回写对象）**：
  - `docs/contracts/2026-09-02-domain-ui-contract.md`——接口契约：`[T9 计划]` 占位项在本批全部落地并回写为实际键/命令/映射；
  - `docs/contracts/2026-09-02-frontend-global-constraints.md`——UI 全局约束：新增组件登记表更新义务；
  - `docs/contracts/2026-09-02-page-inventory-requirements.md`——页面清单：每屏 `[T9]` 占位的落地对照表。
- **可复用规则模块**（阶段一至八全部就位，本批只做编排分派与快照投影，零新规则）：`GuBalance / CultivatorRules / GuInstance / MaterialRules / RecipeRules / FeedingRules / LootRules / MarketRules / CoreGuRules / BloodQiRules / SoulRules / Battle2TurnEngine / Battle2ActionResolver / Battle2BodyRules / Battle2Constants`。

---

## 任务 0：阶段八收尾补丁（1 个小提交）

### P0.1 魂道调参常量入 balance.json（提交 A，必做，P3）

- `soul_rules.gd` 有五处代码内写死调参数值：膨胀线 `capacity * 2.0`、安分分层 `40 / 25 / 10`、兽性显现 `0.5`、兽念阈值 `1.0`。规格未给数值但 AGENTS 红线要求调参落 JSON 过 Schema。
- 修法：新增键 `soul_burst_capacity_ratio`(2.0)、`soul_calm_emotional_below`(40)、`soul_calm_beast_below`(25)、`soul_calm_departure_below`(10)、`beast_nature_emerging_above`(0.5)、`beast_nature_threshold`(1.0) + Schema 正数/范围守卫 + config-following 测试（沿用 T2.1 风格）。
- `CoreGuRules.FIRST_LAYER_MIDPOINT_NODES = 4` 属结构性规则（层内进度裁定，阶段七审查已接受），保留但确认注释已声明裁定来源。
- 验收：`tools/test.ps1 -Test "tests/unit/test_soul_rules.gd"` + `-Suite all`。

---

## T9.1 快照透明面 v2（提交 B，可按八组拆 2-3 个提交）

- **范围**：`scripts/presentation/run_snapshot_builder.gd` 按 §17.2 八组扩快照键。**本批不生成新页面**——页面生成是 T9.2 验收后的独立前端批；本批交付的是页面生成所依赖的键。
- **八组键与同源模块**（每组键必须从对应规则模块投影，逐键同源测试）：
  1. **蛊虫真元/念头/回合使用权/维持状态**：`Battle2TurnEngine` ledger 投影（`thoughts_left/thought_used/reserved/gu_used/actions_used/maintained/ongoing`，形状见契约 §6）；
  2. **核心类型/倾斜/异炼/更换损失**：`CoreGuRules.core_depth / hub_evidence / tilt_pool` + `replace_core` 预检的 `cost_sources`；
  3. **蛊方身份/阶段成本/成功条件/风险/产物**：`RecipeRules.check_identity / resolve_candidates / known_fixed_success` 投影（`named_materials/named_media/dao_tags/min_rank` 逐项满足态、`stages[]`、`candidate_pool` 声明序）；
  4. **喂养需求/匹配比例/替代率/饥饿与死亡预测**：`FeedingRules.feed_cost / resolve_need / preview_settle / budget_report`；
  5. **买卖价/需求条件/参考估值/不可公开原因**：`MarketRules` 全部价目函数 + `trade_gate` 拒收原因；
  6. **安全力量/实际力量/对外伤害/超载自伤/死亡警告**：`Battle2BodyRules.strike_preflight / safe_strength / unarmed_strike_damage / overload_self_damage`；
  7. **敌方意图/反应窗口/距离/速度冲突/准备状态**：`Battle2ActionResolver`（距离带/`conflict_order`/`reaction_allowed`）；
  8. **魂魄五量与失控阈值**：`SoulRules.snapshot / composure_layers / beast_sight / float_above_capacity / soul_growth_forecast`。
- **先红后绿**：新增 `tests/unit/test_snapshot_transparency_v2.gd`——逐键断言存在**且数值与对应规则模块同源**（快照里取值 = 直接调模块取值，逐键相等断言；§17.3 预检=执行同源在快照层的落实）。
- **约束**：中文文案经 `DisplayText`；§16.5 既有约束不回退（数值禁模糊）；快照只读——测试断言 builder 无 setter/无状态写入路径；`_` 前缀旁路键不进快照。
- 验收：`tools/test.ps1 -Test "tests/unit/test_snapshot_transparency_v2.gd"` + `-Suite all`。
- 退出条件：八组逐项绿；快照只读断言绿；**契约回写完成**（`[T9 计划]` 八组占位 → 实际键清单）。

## T9.2 命令面扩容与契约守卫（提交 C，可按命令族拆 2-3 个提交）

- **范围**：`scripts/domain/command_spec_registry.gd` 注册新命令全集，`run_controller/resolver` 做**薄委托分派**——规则体全部在阶段一至八模块内，分派层只做：预检（reason 进 `_REJECTION_TEXT` 中文映射）→ 执行 → 事件日志条目。
- **新命令全集与委托目标**：
  - 核心：`confirm_core`→`CoreGuRules.confirm`、`replace_core`→`replace_core`（预检含硬上限/代价来源）；
  - 喂养/结算：`feed_instance`→`FeedingRules`、`settle_layer`→`RunState.settle_layer`（接通 `run_controller` 大层切换——唯一入口，同层幂等）；
  - 战利品：`collect_surviving`/`release_gu`/`destroy_gu`→`LootRules`；
  - 市场：`sell_info`→`MarketRules.sell_info`；
  - 战斗编排：`enact`（activate_gu/basic_action/maintain 三 proposal → `Battle2TurnEngine.enact`）、`dodge`/`grapple`/`respond`→`Battle2BodyRules`（ongoing 条目必须携带稳定 `"id"`，`start_turn(continue_ids)` 消费）；
  - 炼蛊/血魂：`refine_up_material`→`MaterialRules.refine_up`；`bloodlet`→`BloodQiRules.self_bleed`、`absorb_soul`→`SoulRules`（致死路径全部携带 `lethal_confirm_required` + 死因，命令面绝不吞标记）。
- **每命令三件套硬要求**：①预检（拒绝 reason 进 `_REJECTION_TEXT` 中文映射——前端由此渲染）；②执行（薄委托）；③事件日志条目（§17.3 全清单动作落账：催蛊/炼蛊/核心确认与更换/喂养/交易/收取/释放/采血/收魂/魂魄变化/战斗结算）。
- **先红后绿**：
  - 扩展既有 `tests/unit/test_command_contract.gd`（builder 全 type 字面量扫描自动覆盖新命令，幽令清单钉死）；
  - 新增 `tests/unit/test_command_rejections_v2.gd`——每条新命令至少一条拒绝路径，断言**"拒绝不改状态"**（执行前后 `RunState` 快照逐字段相等）。
- **双轨期裁定（重要）**：V1 战斗命令（`battle.action_card` 等）原样保留，battle2 编排命令作为**新增命令面**并行注册；V1→battle2 运行时切换与旧路径删除是 T10.1-⑥/T10.2 的事，本批不做运行时切换。若发现两者语义冲突点，记录到报告并回上级计划，不在本批擅自裁定。
- 验收：`tools/test.ps1 -Test "tests/unit/test_command_contract.gd"` + `-Test "tests/unit/test_command_rejections_v2.gd"` + `-Suite all`。
- 退出条件：幽令零复发；事件日志 §17.3 动作词逐项有"日志写入"测试（审计 grep 入报告）；`_REJECTION_TEXT` 新增映射逐条到位；**契约回写完成**（命令 type、预检 reason、事件词表三处）。

---

## §3 特殊纪律（本批特有）

1. **门禁保卫战**：`resolver.gd` 仅 5 行余量、`battle_resolver.gd` 仅 2 行。T9.2 的分派/预检增长**必然超限**——处理顺序：先把 resolver 内可纯搬迁的非规则段抽成独立模块（照 `ffe3aa6` economy_rules 先例，纯移动零行为变化）腾出行数，再加分派；**禁止静默上调门禁**，任何门禁基线调整必须在提交信息与报告中给出理由与账目（搬走多少行、新增多少行）。
2. **契约回写是每个提交的收尾动作**（AGENTS 新增义务）：T9.1 落地后回写接口契约快照键；T9.2 落地后回写命令 type/reason 映射/事件词表；新增公共组件时回写前端约束 §2.2 登记表。契约与代码漂移视同验收失败。
3. **零新规则**：本批发现规则缺口（模块没覆盖的规则）时，回对应阶段模块开小补丁，不在快照/分派层临时实现规则。
4. resolver 门禁、禁区目录、先红后绿、EOF 守卫等既有纪律照旧。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；八组快照键的逐组键清单（前端生成的直接输入）；新命令三件套对照表（type → 预检 reason → 事件 action 词）；resolver/battle_resolver 行数账目（搬迁与新增明细）；门禁基线是否变动及理由；`_REJECTION_TEXT` 新增条目清单；契约三文档的回写 diff 摘要；`-Suite all` 最终数字；双轨期语义冲突记录（如有）；未验证风险与遗留问题。

## 后续预告（非本批）

T9.2 验收后启动**前端页面生成批**：按页面清单 §5 顺序（基础组件 → 低风险屏 → 中风险屏 → Refine/Battle 改造 → LayerSettle 新屏），以接口契约 + 前端全局约束 + 本批落地的真实键为唯一依据。
