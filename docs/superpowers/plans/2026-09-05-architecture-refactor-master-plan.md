# 架构重构主计划（2026-09-05，可派发）

> 用途：本文件是唯一派发依据。每张工单可原样派发给一个实现 Agent；控制器负责验收、聚焦提交与回写状态。
> 需求发现记录：两轮结构化问答（2026-09-05），用户逐项裁定；与 `MODULE-INVENTORY.md`、`AGENTS.md` 同源，冲突时以本文为准。

## 0. 需求基线（已锁定，不再讨论）

- **核心玩法支柱**：①自由组装杀招；②海量合成配方。所有游戏目标围绕支柱展开。
- **本版范围**：杀招组合**推迟**（用户裁定：需求复杂，本版不实现），但数据地基（流派/转阶/配方结构）必须按杀招语义预留。
- **流派 = 道痕元素体系**（用户 2026-09-05 阐明）：蛊真人世界以基本元素/道痕划分，**20+ 种道痕各对应一个流派（开放集合）**；蛊虫富含所属道痕（光道蛊含光道道痕，辅助型光道蛊也是光道蛊）。
  - 杀招语义：不同蛊的效果互相辅助成就（月光蛊单独 1x，小光蛊辅助后 2x）。
  - 合炼语义：按「流派标签 + 转阶」表达配方。例：1转月光蛊 ×1 + 1转小光蛊 ×2 → 2转月芒蛊（继承组合威力）；3转血月蛊需 2转血道蛊 + 2转光道蛊。
- **转阶体系**：5 转封顶，与 L1--L5 地图层一一对应，每层 Boss 即该转量级考验。
- **存档**：无感自动保存（玩家无体感）；续玩恢复离开前进度；新开局检测到进行中存档必须提示放弃确认。
- **LLM**：永久搁置，仅保留离线模板与接入接口（I1 冻结）。
- **冻结（不开发、不删除）**：恶名、契约、遗物、诅咒、DDA、继承（F1--F6）。诅咒与合成失败/强弃反噬的既有耦合保持原样。
- **执行顺序（用户裁定：视觉先行）**：全屏幕视觉迁移 → 地基收敛 → 流派体系 → 配方体系 → 自动存档 → 里程碑验收。
- **本版验收（重构里程碑 = 最小回归切片，见 §0.5）**：第一层封闭切片全流程真实窗口可玩（流派→Buff→地图→协同战斗→商店→遗葬→2 转合炼→Boss 收官）+ 视觉迁移完成 + 流派标签可见 + 无感自动存档；杀招只留数据地基与协同效果。

## 0.5 最小回归切片规格（第一层封闭验证，用户 2026-09-05 口述流程固化）

目的：先用一个最小封闭切片验证全部功能通路，通过后再铺大（5 层、5 转、海量配方）。

1. **大厅 → 新开局**。
2. **流派选择**：每流派固定 4 只 1 转初始蛊；首发光道 = 月光蛊、小光蛊、石皮蛊、生机草蛊。流派纯倾向方向，**无任何数值加成**。（注：石皮蛊名字现被生成蛊 `gen_soul_attack_120_gu` 占用，S1 落地时以策展条目定校。）
3. **开局 Buff（多选，本切片无限量）**：表驱动（`data/buffs.json`），首批 3 条——①除 Boss 外全部敌人 1 血；②开局获得 10 转杀蛊（群体 999 伤害）；③开局获得 2000 元石（= 现有 `yuanstone`）。后续 Buff 由用户续填。
4. **地图**：仅 L1；玩家在可见节点中选路径。
5. **战斗（回合制）**：蛊按序使用产生元素协同——小光蛊效果「本回合使用的月光系蛊伤害 +2」，随后使用月光蛊即享受加成。这是杀招语义（效果互相成就）的最小验证；正式杀招系统仍推迟。
6. **商店**：可卖出持有的蛊虫/材料得元石；可买入蛊虫、材料、蛊方（`recipe_unlock` 已有）、线索；线索是部分节点的进入凭证。
7. **遗葬节点（新建；局内事件传承，与冻结 F6 无关）**：三选项——
   - 选项一：拥有与遗葬等级同转阶的侦察蛊（2转遗葬 → 2转侦察蛊）→ 发现传承秘地 → 继承；
   - 选项二：持有传承信物（商店购得）→ 感应 → 继承；
   - 选项三：离开。
   传承产出按遗葬等级随机（种子化）分 4 档：残破（1--2 只蛊）、普通（3--4 只蛊 + 1--2 份蛊方）、稀有（5--8 只蛊 + 3--4 份蛊方）、超级（暂不实现）。
8. **合炼**：本切片配方只做 1 转、2 转；更高转阶后续铺大。
9. **结束**：击败 L1 Boss 即结算收官；死亡走死亡结算。
10. **全程无感自动存档**。

## 1. 目标架构终态

1. **战斗**：仅 V1 一个引擎（`v1_battle_resolver` + `battle_command_facade` + `action_preview_service`）。旧 `battle_resolver.gd`、`v2_commands.gd`、`battle2/action_resolver|body_rules|combat_constants` 删除；`turn_engine` 账本用法内联或保留为独立小模块。
2. **卡层退役**：`cards.json`、`deck_builder.gd` 删除；`card_blueprint_ids` 蓝图层退出（V1 零消费已证实，活消费点仅目录校验与 deck_builder）；`deck.json` 活配置键迁 `balance.json`。
3. **流派数据模型**：`schools.json` 扩为 20+ 道痕流派（开放集合 Schema）；`gu.json` 每只蛊 `school` 指向道痕流派；快照/UI 透出流派；配方按 `(school, rank)` 表达。
4. **配方**：`refinement_recipes` 以用户提供的配方源结构化落表，Schema 校验，生成器（`generate_gu_catalog.py`）改造支持。
5. **UI**：wenzhen 视觉模型（guitkx/reactive_ui_toolkit）是唯一 UI 架构；11 个旧屏幕全部迁移后退役；guitkx 构建链保留。
6. **存档**：命令通过后自动静默保存；Run 结束删档、新开局放弃确认流程完整。
7. **验收基建**：冒烟/截图驱动收敛为单一验收驱动；UI 验收一律真实窗口键鼠复现（AGENTS AI 契约）。

## 2. 执行 DAG（视觉先行）

```
A 视觉迁移 ──────────────┐
C1 道痕清单提炼（只读语料，可与 A 并行）─→ [U1] ─→ C2 存量映射 ─→ [U2] ─→ C3 转阶落表
                          │
                          ↓
B 地基收敛（B1 引擎收敛 → B2 卡层退役 → B3 冒烟瘦身）
                          ↓
D 配方体系（切片内只做 1--2 转）←── [U3 用户提供配方源]
                          ↓
S 切片内容组装（S1 流派初始蛊 → S2 Buff → S3 遗葬传承 → S4 元素协同 → S5 商店卖出 → S6 L1 封闭）
                          ↓
E 自动存档
                          ↓
F 里程碑验收（切片全流程真实窗口走查）
```

并行规则：A 与 C1 可双 Agent 并行（文件零交集）；B 必须在 A 合入后开工（同文件冲突面：run_controller）；D 阻塞于 U3。

## 3. 工单（逐张可派发）

### Phase A 视觉迁移（旧屏 → wenzhen）

**A1 挂载 wenzhen battle/map 双 master，退役对应旧屏**
> 状态：⛔ 2026-09-05 回退——挂载未适配蛊卡**拖动**既有交互（`drag card onto enemy` 属既有功能，d81e89a），缺真实窗口键鼠验收；已 `git revert` 原验收测试。**待重做**：挂载 + 拖动适配 + 真实窗口走查（AGENTS AI 契约）。
- 前置：无。
- 目标：`main.tscn`/`run_controller` 的 Battle/Map 视图改挂 `scenes/ui_masters/wenzhen_battle_master.tscn`、`wenzhen_map_master.tscn`（经 `ui/screens/battle_screen.gd`、`map_screen.gd`），数据仍来自 `RunSnapshotBuilder` 快照、命令仍走 `RunController.submit_command()`。
- 范围：`scripts/presentation/run_controller.gd`、`scenes/ui_masters/*`、`ui/screens/battle_screen.gd`、`ui/screens/map_screen.gd`。
- 禁改：领域层、快照键语义（新增键须同步三份契约文档）。
- 验收：真实窗口键鼠走通「进入战斗→放蛊→结算→回图→跳层」；headless 仅回归门。`tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd` 等 wenzhen 系测试绿。
- 完成：旧 `battle_screen.tscn`/`map_screen.tscn` 不再被 main 路径引用（文件删除放到 A6）。

**A2 hall/encounter/reward/ending 四屏迁移**
- 前置：A1 模式定型。
- 目标：为四屏各建 wenzhen master（guitkx 源在 `ui/`），挂载并替代旧屏；结算/图鉴数据链路不变。
- 验收：真实窗口走通「新开局→签约→遭遇→奖励→结局归因」全流程。

**A3 npc/shop/rest/refine 四屏迁移**
- 前置：A2。
- 目标：同模式迁移；休整屏必须保持 AGENTS「rest 全集 + skip 兜底」红线；炼蛊屏按现有领域命令面。
- 验收：真实窗口走通交易/休整/炼蛊各节点命令全集。

**A4 content_error + 调试面板迁移**
- 前置：A2。
- 目标：目录错误屏、调试面板（含真实窗口拖拽验收）迁新栈；调试面板保留 Release 裁剪路径。
- 验收：内容损坏注入测试绿 + 真实窗口拖动调试面板。

**A5 旧屏退役**
- 前置：A1--A4 全绿。
- 目标：删除 `scenes/ui/screens/*.tscn`、`scripts/presentation/screens/*`、孤儿 widgets 中不再被引用者；`ui_capture`/`smoke_render` 相关旧路径同步。
- 验收：`tools/check.ps1` 绿；全仓无死引用。

### Phase B 地基收敛（A 合入后开工）

**B1 战斗引擎收敛为纯 V1**
- 目标：`battle_command_facade.gd` 移除 `battle_resolver.gd` 预载与旧信封分发（`start` 始终 V1 已成立）；`resolver.gd` 去 `v2_commands.gd` 引用；删除 `battle_resolver.gd`、`v2_commands.gd`、`battle2/action_resolver.gd`、`body_rules.gd`、`combat_constants.gd`；`turn_engine` 账本用法保留（可内联为 `run_state` 小函数）。顺带统一 V1 与 `EssenceCapacity` 的 essence/capacity 公式。
- 测试迁移：`test_battle_resolver`、`test_v2_*`、`test_battle2_*`（除账本语义）、`test_v3_battle_*`、`test_b3/b4/b5_*`、`test_action_card_row_migration` 等逐个判定：测旧行为→删；测存续行为→迁 V1 契约。`test_legacy_abolition` 改为守护「无旧引擎引用」。
- 验收：`tools/test.ps1 -Suite unit` 与 `-Suite integration` 全绿；`rg "battle_resolver|v2_commands" scripts/` 零命中。

**B2 卡层退役**
- 前置：B1。
- 目标：设计并落地蓝图层退出：`content_catalog` 校验改写（`_is_data_driven_card_linked` 移除，改为校验 `v1_effect` 完备）；`gu.json` 去 `card_blueprint_ids`（如 UI 需要「操作界面」语义，改由快照按 `v1_effect`/`slot_role` 投影）；删 `cards.json`、`deck_builder.gd`；`deck.json` 的 `remove_card_cost/remove_imprint_cost/imprint_capacity/meta_rule_cap` 迁 `balance.json`；`generate_gu_catalog.py` 去掉出卡逻辑。
- 验收：目录启动校验绿；`rg "cards.json|deck_builder|card_blueprint" scripts/ tools/` 零命中；相关单测更新绿。

**B3 冒烟驱动瘦身**
- 前置：B1（驱动引用的旧路径已清理）。
- 目标：`smoke_render/ui_capture/playthrough_smoke/crash_recovery_driver/integration_smoke/render_probe`（~2840 行）收敛为单一 `scripts/acceptance_driver.gd` + 一个入口参数（模式：smoke/capture/soak），保留崩溃恢复检查。
- 验收：`tools/test.ps1 -Suite integration` 与 `tools/check.ps1` 绿；删除文件无残留引用。

### Phase C 流派体系（C1 可与 A 并行）

**C1 道痕清单提炼（只读） → 门 U1**
> 状态：✅ 2026-09-05 完成——产出 `docs/superpowers/specs/2026-09-05-dao-mark-school-list-draft.md`：26 条道痕 + 14 条存疑线索；红线六道（血/气/力/魂/炼/光）全覆盖。**门 U1：✅ 2026-09-05 用户认可；C2/C3 可开工。**
- 目标：从 `分支：六卷精编版/` 只读语料提炼 20+ 道痕/流派清单初稿（id、中文名、一句话界定、代表蛊例），整理成 `docs/superpowers/specs/2026-09-XX-dao-mark-school-list-draft.md`。
- 禁改：语料目录只读；不改任何数据表。
- 完成：初稿交用户审订（门 U1），锁定后 Schema 按开放集合落地。

**C2 存量 214 蛊流派映射 → 门 U2**
- 前置：U1 锁定清单。
- 目标：按蛊名/效果/现有表现生成全量映射表（含 `small_light_gu`→光道 这类修正），输出可审 diff 文档；用户审订（门 U2）后一次性落 `gu.json` + `schools.json` v2，`content_catalog` 校验同步，快照与卡面/tooltip/图鉴透出流派。
- 验收：目录校验绿；真实窗口任意蛊卡可见流派标签；wenzhen 系 UI 测试绿。

**C3 转阶落表**
- 前置：U2。
- 目标：rank 语义扩为 1--5 转（5 转对 L1--L5），rarity 与转阶解耦说明落 Schema 注释；`content_catalog` 校验 1--5；Boss 量级挂钩核对（中央倍率 `data/v1_battle.json`）。
- 验收：校验绿 + `test_v1_five_layer_clear` 等层级测试绿。

### Phase D 配方体系（阻塞于 U3）

**D1 配方源结构化落表 → 数据**
- 前置：**U3 用户提供配方源材料**（文本/表格/原著摘录均可）。
- 目标：配方 Schema v2：`{id, output_gu_id, output_rank, inputs: [{school, rank, count}], optional_materials, source}`，按用户模型表达（1转月光蛊×1+1转小光蛊×2→2转月芒蛊；3转需 2转+2转 跨流派）；落 `data/refinement_recipes.json` v2 + Schema 校验；杀招组合字段（synergy）只预留不实现。
- 验收：目录校验绿；每条配方可被领域校验通过。

**D2 合炼玩法接线**
- 前置：D1 + A3（新炼蛊屏）。
- 目标：领域合炼命令（现 `refine` 命令面扩展为配方驱动：按配方消耗对应蛊实例与材料，成功/反噬沿用现有结算与预检红线）；新炼蛊屏展示配方、材料齐备度与风险预览。
- 验收：真实窗口完成一次「按配方合炼出高转蛊」全流程；不可逆成本预检可见。

**D3 杀招数据地基（不实现玩法）**
- 目标：仅在数据层预留杀招组合描述结构（蛊效果互补的 synergy 键），快照不透出、无 UI、无战斗逻辑；文档记录月光蛊+小光蛊=2x 的目标语义为下一版规格输入。
- 验收：Schema 校验绿；`rg "kill_move" scripts/presentation/` 零命中（确认无越界实现）。

### Phase S 切片内容组装（第一层封闭验证的实体工单）

**S1 流派与初始蛊**
- 前置：U1（光道入道痕清单）。
- 目标：schools.json 调整为每流派 4 只 1 转初始蛊；新增光道流派；落实石皮蛊（名字现被生成蛊 `gen_soul_attack_120_gu` 占用——新建策展条目 `stone_skin_gu` 或改派，冲突在 C2 映射审订同步定校）；开局流派选择仅定倾向与初始蛊，无加成；快照/UI 按新视觉呈现。
- 验收：新开局选定光道后拥有且仅拥有 4 只初始蛊；真实窗口可走通。

**S2 开局 Buff 系统**
- 前置：A（新 UI 开局流程）。
- 目标：`data/buffs.json` 表驱动，首批 3 条（除 Boss 外敌人 1 血；开局 10 转杀蛊群体 999；开局 2000 元石）；领域在 run 创建时结算 Buff，多选、本切片无限量；开局流程流派选择后进入 Buff 多选；杀蛊按蛊实例入包。
- 验收：三种 Buff 各自真实结算且可叠加；同种子同结果；后续 Buff 用户续填只改表。

**S3 遗葬节点与局内传承**
- 前置：S1、商店信物可购（S5）。
- 目标：新节点类型遗葬（带等级字段）；三选项门控——同转阶侦察蛊发现 / 传承信物感应 / 离开；传承产出表 `data/inheritance_sites.json`：遗葬等级 × 品质（残破 1--2 蛊；普通 3--4 蛊 + 1--2 蛊方；稀有 5--8 蛊 + 3--4 蛊方；超级不做），种子化随机；与冻结 F6 无关。
- 验收：三条路线各走通一次；同种子同产出；关键选择落不可变事件日志；真实窗口可用。

**S4 元素协同战斗效果**
- 前置：B1（单引擎）。
- 目标：`v1_effect` 新增支援类效果——小光蛊「本回合月光系蛊伤害 +2」，战斗按序结算生效；预检/快照可见（透明度红线）；杀招正式系统不实现。
- 验收：真实窗口小光蛊→月光蛊连用伤害 +2；单测覆盖结算与预览。

**S5 商店卖出与信物**
- 前置：A3（新商店屏）。
- 目标：商店支持卖出持有蛊虫/材料换元石（中央定价走 economy_rules）；买入面已支持蛊方（`recipe_unlock`）与线索，补传承信物商品项。
- 验收：卖买循环真实窗口走通；价格全部落表。

**S6 第一层封闭**
- 前置：S1--S5、C3（1--2 转数值）。
- 目标：地图配置为 L1 单层；L1 Boss 击败 → 胜利结算收官；死亡 → 死亡结算；两条路径均遵守存档删除与结局归因红线。
- 验收：集成套件新增切片端到端测试；真实窗口完整一局。

### Phase E 自动存档

**E1 无感自动保存**
- 前置：A 全部合入、S1--S6 完成（切片新内容进存档）。
- 目标：`submit_command` 接受命令后自动 `SaveRepository.save_run`（静默，无 UI 提示），节流策略（如每命令/每视图流转）落常量；地图屏手动保存按钮移除；「继续游戏」读档流程保持；新开局检测到进行中 Run 存档 → 二次确认放弃（`gu_confirm_dialog`）。
- 验收：真实窗口「玩到任意节点→关进程→重开→继续游戏→进度一致」；新开局确认弹窗真实可见；`test_save_repository` 系绿。

### Phase F 里程碑验收

**F1 重构里程碑验收**
- 前置：A--E 全部完成。
- 验收清单：`tools/test.ps1 -Suite unit`、`-Suite integration`、`tools/check.ps1` 全绿；**切片全流程真实窗口走查**（大厅 → 光道 4 蛊开局 → Buff 多选 → L1 地图 → 小光蛊+月光蛊协同战斗 → 商店卖买/蛊方/线索 → 遗葬三路线 → 2 转合炼 → Boss 收官，另验死亡支线与存档连续性）；全屏走查（11 类页面全部新栈、无死按钮/溢出/遮挡）；`data/v1_battle.json` Boss 倍率与转阶量级核对报告。产出验收记录文档。

## 4. 用户审订门汇总

| 门 | 内容 | 阻塞 |
|----|------|------|
| U1 | 20+ 道痕流派清单初稿审订 — ✅ 2026-09-05 用户认可 | C2/C3（已放行） |
| U2 | 214 蛊流派全量映射审订 | C2 落库/C3/D1 |
| U3 | 合炼配方源材料提供 | D1/D2 |

## 5. 派发规约（每张工单的 Agent brief 附加规则）

- 开工先 `git status --short --branch`；阅读本文件对应工单 + `AGENTS.md` 红线 + 相关契约文档。
- 先写可失败测试或定义可复现验收命令，再实现最小完整改动。
- Godot 一律 headless 或仓库脚本，禁止裸启动 GUI（防挂起）；UI 工单必须加做真实窗口键鼠验收。
- 完成后报告格式：DONE / DONE_WITH_CONCERNS + 改动文件 + 验证命令与结果 + 未验证风险；控制器聚焦提交（消息 ASCII）。
- 提交排除：`.claude/`、未验证的 `data/enemies.json`、无关的 `data/dialogues/events.dialogue` 本地修改。
