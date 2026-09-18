# 垂直切片 UI 与交互修订实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Godot 4.7.2 垂直切片上修复地图旅行可达性、移除三死线常驻展示、补齐行囊快照与视图，并验证战斗卡牌真实鼠标操作不致卡关。

**Architecture:** 领域层继续以 `RunState` 和 `Resolver` 为唯一状态转换入口；`RunSnapshotBuilder` 增加只读行囊投影，屏幕只消费快照并通过 `RunController` 提交命令。顶栏只保留层次、元石、气血/魂魄/寿元状态栏及契约/异变，材料与蛊虫/收获/情报迁移到局内行囊面板；战斗卡牌本体保留交互，详情统一经共享 tooltip。

**Tech Stack:** Godot 4.7.2、GDScript、RUI `.guitkx`、JSON、GUT、PowerShell。

## Global Constraints

- UI 只渲染快照并提交命令，禁止直接修改 `RunState`。
- 死亡条件仍由领域层判定：气血、寿元、魂魄任意一项 `<= 0`。
- 不新增抽牌、弃牌、蛊槽或跨局战力规则。
- 生成脚本 `ui/**/*.gd` 不手工编辑；优先修改 `.guitkx` 与 `scripts/presentation/`、`scripts/ui/`。
- 所有可达地图节点必须在当前视口内可见、可选、可真实点击；不可达节点不得提供旅行命令。
- 所有新增 UI 数据必须来自快照键，并保持结构化事件日志与确定性。

## 文件与接口地图

| 责任 | 文件 | 变更 |
| --- | --- | --- |
| 快照投影 | `scripts/presentation/run_snapshot_builder.gd` | 新增 `inventory`/`pouch` 只读字段，保留现有资源与死亡判定投影兼容性 |
| 顶栏 | `scripts/presentation/widgets/gu_top_bar_view.gd`, `scenes/ui/widgets/gu_top_bar.tscn`, `ui/widgets/gu_top_bar.guitkx` | 删除 DeathHost/GuDeathLineWarning 与 material chip；保留已有资源状态栏入口 |
| 行囊 | `scripts/presentation/widgets/gu_inventory_view.gd`, `scenes/ui/widgets/gu_inventory.tscn`, `ui/widgets/gu_inventory.guitkx` | 新增只读材料、蛊虫、收获、情报视图 |
| 屏幕装配 | `scripts/presentation/screens/map_screen_view.gd`, `scripts/presentation/screens/battle_screen_view.gd`, 对应 `.guitkx`/`.tscn` | 挂载行囊；移除死线传递与死亡线 UI；保持 tooltip/确认链路 |
| 地图布局 | `scripts/presentation/screens/map_screen_view.gd`, `scenes/ui/screens/map_screen.tscn` | 以视口尺寸计算节点位置，确保 reachable 节点几何可见且按钮点击可达 |
| 交互测试 | `tests/unit/test_vertical_slice_ui_remediation.gd`（新建）及现有 UI 测试 | 真实鼠标事件、tooltip、旅行、顶栏、行囊和死亡条件回归 |

### Task 1: 为四项修订建立失败测试

**Files:**
- Create: `tests/unit/test_vertical_slice_ui_remediation.gd`
- Modify: `tests/unit/test_wenzhen_battle_screen.gd`（如需补充真实事件断言）

- [ ] 写测试：快照包含 `inventory.materials/gu_instances/loot/intel`；顶栏场景不存在 `DeathHost`、`GuDeathLineWarning` 和材料 chip；地图所有 `reachable=true` 节点的 `global_rect` 与 camera 相交；鼠标点击卡牌后只调用一次命令；单目标选择和危险确认通过真实 `InputEventMouseButton` 完成。
- [ ] 运行 `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_vertical_slice_ui_remediation.gd`，确认因字段/节点/布局缺失失败。

### Task 2: 增加统一行囊快照

**Files:**
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Test: `tests/unit/test_vertical_slice_ui_remediation.gd`

- [ ] 增加 `static func _inventory(state, catalog) -> Dictionary`，返回：材料按 id/名称/数量；蛊虫实例按 instance id、定义、状态、品质；最近战斗/节点收获；已知情报（只投影已知事实）。
- [ ] 在 `_gui_state()` 注入 `inventory`，不把估算值或 `_` 前缀旁路键渲染为玩家信息。
- [ ] 运行聚焦测试，确认行囊快照结构和来源稳定。

### Task 3: 移除三死线常驻 UI，迁移材料展示

**Files:**
- Modify: `scripts/presentation/widgets/gu_top_bar_view.gd`
- Modify: `scenes/ui/widgets/gu_top_bar.tscn`
- Modify: `ui/widgets/gu_top_bar.guitkx`
- Modify: 所有调用顶栏的屏幕脚本与 `.guitkx`（由 `rg "death_lines|GuTopBar"` 定位）
- Test: `tests/unit/test_vertical_slice_ui_remediation.gd`

- [ ] 删除顶栏 `DEATH_KINDS`、`DeathHost`、死亡行回调及 `death_lines` 参数依赖；`set_data()` 保持向后兼容时忽略旧参数，避免旧屏调用崩溃。
- [ ] 从顶栏节点树删除 `ChipMaterial` 与 `GuDeathLineWarning` 引用；材料仅由行囊视图展示。
- [ ] 保留气血、魂魄、寿元现有状态栏样式和危险反馈路径；死亡死因只在结算/死亡说明层显示。
- [ ] 运行顶栏与死亡领域 focused tests，确认任一 `health/lifespan/soul <= 0` 仍走领域终局。

### Task 4: 新增并装配行囊视图

**Files:**
- Create: `scripts/presentation/widgets/gu_inventory_view.gd`
- Create: `scenes/ui/widgets/gu_inventory.tscn`
- Create: `ui/widgets/gu_inventory.guitkx`
- Modify: `scripts/presentation/screens/map_screen_view.gd`, `scripts/presentation/screens/battle_screen_view.gd`
- Modify: `ui/screens/map_screen.guitkx`, `ui/screens/battle_screen.guitkx`
- Test: `tests/unit/test_vertical_slice_ui_remediation.gd`

- [ ] 实现 `GuInventoryView.bind(snapshot: Dictionary)`，只读整体重建四个分区：材料、蛊虫、收获、已知情报；空分区显示明确空态，不生成假按钮。
- [ ] 将组件挂到地图和战斗局内布局的固定侧栏/底部区域，设置 `mouse_filter = IGNORE`（除非折叠按钮明确需要交互），避免遮挡地图节点和卡牌。
- [ ] 组件不 preload 领域脚本，不保存 `RunState` 引用；所有文本由快照提供或经 `DisplayText` 投影。
- [ ] 运行渲染 smoke，检查窄视口下文本换行、侧栏不覆盖可达节点和战斗手牌。

### Task 5: 修复地图可达节点几何与真实旅行点击

**Files:**
- Modify: `scripts/presentation/screens/map_screen_view.gd`
- Modify: `scenes/ui/screens/map_screen.tscn`
- Test: `tests/unit/test_vertical_slice_ui_remediation.gd`, `tests/integration/test_wenzhen_ui_flow.gd`

- [ ] 用 camera 的实际 `size`/`get_rect()` 计算当前层、下一层和前瞻层节点坐标，保留固定拓扑但禁止依赖超出裁剪区域的 `CANDIDATE_Y/FUTURE_Y/CURRENT_Y`。
- [ ] 为每个节点建立稳定矩形和 `mouse_filter`，reachable 节点启用选择与旅行按钮，不可达/前瞻节点仅检视且不暴露旅行命令。
- [ ] 真实构造 `InputEventMouseButton` 点击第一个 reachable 节点，断言 controller 只提交一次 `travel`，且进入对应屏幕；重复点击不重复提交。
- [ ] 运行地图 focused/integration tests 和 `git diff --check`。

### Task 6: 收紧战斗卡牌真实鼠标链路

**Files:**
- Modify: `scripts/presentation/widgets/gu_battle_hand_view.gd`（仅必要的 mouse_filter/命令去重修复）
- Modify: `scripts/presentation/screens/battle_screen_view.gd`
- Modify: `ui/screens/battle_screen.guitkx`
- Test: `tests/unit/test_wenzhen_battle_screen.gd`, `tests/unit/test_vertical_slice_ui_remediation.gd`

- [ ] 验证卡牌本体可接收鼠标，内部摘要节点保持 `MOUSE_FILTER_IGNORE`；禁用卡牌 hover 仍展示 `block_reason`。
- [ ] 真实鼠标点击卡牌、选择唯一敌人、打开危险确认并确认，命令仅调用一次；取消后不残留选中态或 tooltip。
- [ ] 保持共享 tooltip 包含名称、品质、效果、联动、代价、不可用原因和咒/风险提示；删除任何独立详情面板。
- [ ] 运行 UI focused tests、完整 GUT、`tools/check.ps1`，并用 `tools/play.ps1` 或现有 capture 脚本完成一次随机种子冒烟试玩（玩家局无教学/固定种子；连续进入的两局地图必须不同，结局结算后大厅回到「开始此世」）。

## 完成门槛

- `tools/test.ps1` 聚焦测试与全量测试通过，输出无 parse/ignored/script error。
- `tools/check.ps1`、`git diff --check` 通过。
- 地图 reachable 节点全部可见可点；顶栏无三死线和材料数值 chip；行囊同时展示材料、蛊虫、收获、情报；战斗鼠标点击可完成出牌/选敌/危险确认。
- 未验证的真实渲染风险在交付说明中明确列出。
