# 项目最小原子模块清单（2026-09-05）

> 用途：供逐模块裁决「保留 / 裁剪 / 待定」。建议列只是基于引用关系的初判，最终以你的裁决为准。
> 用法：直接回复编号结论，例如「A 全留；D2、D4 裁；H7 待定」。裁决后再统一执行删除与测试迁移。
> 本文件只做盘点，不改任何代码；当前工作树的未提交改动（拖拽批次、shop_rules.gd 等）原样保留。
> 执行以主计划为准：`docs/superpowers/plans/2026-09-05-architecture-refactor-master-plan.md`（视觉先行 DAG + 可派发工单）。

## 用户需求裁决（2026-09-05，已录入）

- **核心玩法支柱**：①玩家自由组装杀招；②蛊虫海量合成配方。所有游戏目标围绕这两个支柱展开。
- **存档**：无感自动保存；续玩恢复离开前进度；新开局须提示放弃进行中存档。
- **LLM 相关功能永久搁置**：仅保留离线模板与接入接口（I1 冻结，不删除不开发）。
- **冻结（不再开发、暂不删除）**：F1 恶名、F2 契约、F3 遗物、F4 诅咒、F5 DDA、F6 继承。
- **F7 流派：活跃**。蛊虫流派标签已全量入数据（`data/gu.json` 214/214 条带 `school`），但快照/UI 不展示、领域规则不消费，属"死数据"，需功能化（道标签开放集合红线不变）。
- **2026-09-05 二轮裁决**：D2/D3/D5 收敛进 V1，只保留一个战斗引擎（代码纯净性）；D4 迁移退役；H7 不归档——它是新视觉架构，**全部旧屏幕迁移到该模型**；J2 冒烟驱动瘦身；J3 guitkx 链保留并承载屏幕迁移；J4 待归属（用途见 J4 行）。

## 事实基线（影响裁决的引用关系，已核实）

- `scripts/domain/battle_command_facade.gd:11` 仍预载旧引擎 `battle_resolver.gd`；V1 是唯一 start 路径，旧引擎只服务「旧信封路径 + 存量测试」（`action_preview_service.gd:99` 注释亦印证）。
- `scripts/domain/battle2/turn_engine.gd` 被 V1 路径用作每战斗行动账本（`battle_command_facade.gd:198-201`、`run_controller.gd:901-905`）；`battle2/action_resolver.gd`、`body_rules.gd` 无 V1 引用。
- `scripts/domain/content_catalog.gd:38,49` 仍加载 `data/cards.json` 与 `data/deck.json`；`resolver.gd` 活用 `deck.json` 的配置键（`remove_card_cost`、`imprint_capacity`、`meta_rule_cap` 等，resolver.gd:713,956,961）。
- `scenes/ui_masters/*.tscn` + `ui/*.guitkx` + `wenzhen_battle/map_master.gd` 未被 main/run_controller 挂载，仅 master.tscn 自引与 `test_wenzhen_master_theme.gd` 引用。
- `addons/beckett` 全仓（scripts/scenes/project.godot/tools）零引用。
- 正式 UI 屏（scenes/ui/screens/*.tscn）未检出 reactive_ui 节点引用；reactive_ui_toolkit 仅编辑器插件启用 + guitkx 工具链使用。

## A 骨架与状态

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| A1 | RunState 纯数据 + 事件日志 + 种子随机 | scripts/domain/run_state.gd, events.gd, result_feed.gd, action_points.gd, rng.gd, seeded_roll.gd | ~540 行 | 单一 RunData、确定性、不可变事件日志（红线） | 核心 |
| A2 | 中央规则机 resolver | scripts/domain/resolver.gd, resolver_helpers.gd | ~260 | 所有命令唯一规则入口 | 核心（W11 m3 已拆分：rest/shop/refine/social 四命令族模块承载 handler，resolver 剩路由核） |
| A3 | 命令规格注册 | scripts/domain/command_spec.gd, command_spec_registry.gd | ~205 | 命令面契约 | 核心 |
| A4 | RunController 编排 | scripts/presentation/run_controller.gd | 1519 | UI↔领域唯一边界、视图流转、存档触发 | 核心 |
| A5 | 快照构建 | scripts/presentation/run_snapshot_builder.gd | 2129 | 领域→UI 只读快照（契约文档对应物） | 核心（可按屏拆分） |
| A6 | 中文文案与命令行构建 | scripts/presentation/display_text.gd, run_command_builder.gd | ~743 | 快照中文投影、UI 命令行 | 核心 |

## B 蛊与炼蛊

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| B1 | 蛊实例模型 + 核心蛊 | scripts/domain/gu_instance.gd, core_gu_rules.gd | ~385 | 实例制、核心蛊、无卡槽（红线） | 核心 |
| B2 | 炼蛊/喂养/蛊材/合成 | scripts/domain/feeding_rules.gd, recipe_rules.gd, material_rules.gd | ~453 | 三蛊炼蛊、随机合成杀招切片（支柱：海量合成配方） | 核心（支柱） |
| B3 | 蛊数据表 | data/gu.json | 7981 | 全蛊定义 + v1_effect | 核心 |
| B4 | 炼方数据 | data/refinement_recipes.json, data/synthesis.json | ~2390 | 炼方图鉴（唯一允许的跨局解锁）；注：synthesis.json 的 battle_recipes 仍用旧卡模 temp_card_id，并入杀招支柱时收敛 | 核心（支柱） |
| B5 | 血气/魂魄/念头/真元 | scripts/domain/blood_qi_rules.gd, soul_rules.gd, soul_capacity.gd, essence_capacity.gd | ~331 | 独立可支付资源系统 | 核心（待办：essence 公式统一） |

## C 经济

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| C1 | 经济/市场/商店 | scripts/domain/economy_rules.gd, market_rules.gd, shop_rules.gd（未提交新文件）, data/shops.json, data/balance.json | ~610 | 交易、黑市、商队、中央定价 | 核心 |
| C2 | 掉落 | scripts/domain/loot_resolver.gd, loot_rules.gd, data/loot_tables.json | ~666 | 战利品、保底、稀有度 | 核心 |

## D 战斗（重点裁决区：三代引擎叠置）

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| D1 | V1 战斗（现行唯一） | scripts/domain/v1_battle_resolver.gd, battle_command_facade.gd, action_preview_service.gd, data/v1_battle.json | ~2290 | 蛊槽制战斗、行动预检、杀招（支柱：自由组装杀招）、Boss 倍率 | 核心（支柱） |
| D2 | 旧战斗引擎 | scripts/domain/battle_resolver.gd | 1514 | 无（仅旧信封 + 存量测试） | 已裁决：收敛进 V1，facade 移除旧引擎预载与旧信封分发后删除 |
| D3 | battle2 包 | scripts/domain/battle2/turn_engine.gd, action_resolver.gd, body_rules.gd, combat_constants.gd | ~540 | turn_engine 是 V1 账本（活） | 已裁决：账本用法内联/保留，action_resolver、body_rules、combat_constants 随旧引擎删除 |
| D4 | 旧卡组数据与构建器 | data/cards.json, data/deck.json, scripts/domain/deck_builder.gd | ~3480 | 212 蓝图被 gu.json 100% 引用；活消费点仅 content_catalog 校验（`_is_data_driven_card_linked`）与 deck_builder；V1 战斗零消费 | 已裁决：迁移退役——设计蓝图层退出路径，deck.json 活配置键迁 balance.json |
| D5 | v2 命令信封 | scripts/domain/v2_commands.gd | 271 | resolver 仍引用（旧信封兼容） | 已裁决：随 D2 收敛删除 |

## E 地图与节点

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| E1 | 地图生成 | scripts/domain/map_generator.gd | 348 | 五层 L1--L5 图 | 核心 |
| E2 | 节点会话/遭遇 | scripts/domain/encounter_session_resolver.gd, data/events.json, data/nodes.json, data/pacing.json, data/names.json, data/first_run.json | ~900 | 200--300 有效节点节奏 | 核心 |
| E3 | NPC | data/npcs.json + social_command_rules.gd NPC 分支 | ~55 | NPC 个人库存/情报 | 核心 |
| E4 | 休整/交易节点分支 | rest_rules.gd（休整全集红线）、shop_command_rules.gd（交易死亡预检） | — | rest 全集红线、交易死亡预检 | 核心 |

## F 规则包

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| F1 | 恶名 | data/reputation.json + social_command_rules.gd / resolver `gain_notoriety` | 19 | 恶名有效路径 | 冻结（2026-09-05 裁决） |
| F2 | 契约 | scripts/domain/contract_rules.gd, data/contracts.json | ~101 | 契约路径 | 冻结（2026-09-05 裁决） |
| F3 | 遗物 | scripts/domain/relic_hook_resolver.gd, data/relics.json | ~220 | 遗物钩子 | 冻结（2026-09-05 裁决） |
| F4 | 诅咒 | scripts/domain/curse_registry.gd, data/curse.json | ~131 | 诅咒系统 | 冻结（2026-09-05 裁决；与合成失败/强弃反噬的既有耦合保持原样） |
| F5 | DDA | scripts/domain/dda_resolver.gd, data/dda.json, data/aptitude.json | ~250 | 难度自适应开关 | 冻结（2026-09-05 裁决） |
| F6 | 继承 | scripts/domain/inheritance_resolver.gd, data/inheritances.json | ~69 | 开局继承 | 冻结（2026-09-05 裁决） |
| F7 | 流派 | scripts/domain/school_rules.gd, data/schools.json, data/school_pools.json, data/gu.json `school` 字段 | ~128 | 开局流派 + 蛊流派标签功能化（选择屏有空渲染缺陷未修） | 核心（活跃缺口：school 已 214/214 入库，但 UI 不展示、规则不消费） |

## G 存档与大厅

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| G1 | 存档仓库 | scripts/domain/save_repository.gd | 282 | 大厅存档 + Run 存档、版本门；新需求：无感自动保存（现 `save_run` 为地图手动按钮，map_screen_view.gd:138） | 核心 |
| G2 | 跨局元进度与设置 | scripts/domain/meta_progress.gd, app_settings.gd | ~306 | 图鉴/蛊方解锁/显示设置 | 核心 |
| G3 | 游记/图鉴 | scripts/domain/journal_builder.gd, data/journal.json | ~318 | 结局归因、图鉴展示 | 核心 |

## H 表现层 UI

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| H1 | 屏幕视图 ×11 | scripts/presentation/screens/*.gd + scenes/ui/screens/*.tscn | ~3600 | 页面清单契约（hall/map/battle/npc/shop/rest/refine/reward/encounter/ending/content_error） | 核心（可逐屏再裁） |
| H2 | 公共组件库 | scripts/presentation/widgets/gu_*.gd + scenes/ui/widgets/*.tscn（约 15 组件） | ~1100 | 公共组件约定 | 核心 |
| H3 | 主题与风格 | scripts/presentation/wenzhen_master_theme.gd, gu_style.gd, resource_icon.gd, resource_vocabulary.gd, gu_orb.gd, screen_transition.gd | ~600 | 视觉统一 | 核心 |
| H4 | 手牌拖拽交互 | gu_battle_hand_view.gd 拖拽段 + battle_screen_view.gd `_input`/`_enemy_at`/`_on_card_drag_start` | ~150 | 卡→敌拖放（当前真窗 bug 未修，改动未提交） | 待定（你裁决是否保留此交互形态；不保留则退化为点击选卡） |
| H5 | 调试面板 | scripts/presentation/widgets/debug_panel_view.gd, scripts/domain/debug_actions.gd, data/debug.json | ~475 | 开发跳转/快进（Release 裁剪红线） | 核心 |
| H6 | 死亡报告/确认层 | widgets/gu_death_cause_overlay_view.gd, gu_confirm_dialog_view.gd, scripts/domain/death_report_builder.gd | ~156 | 不静默致死、二次确认红线 | 核心 |
| H7 | wenzhen 视觉模型（新 UI 架构） | scenes/ui_masters/*.tscn, ui/*.guitkx + ui/screens, ui/widgets, scripts/presentation/wenzhen_battle_master.gd, wenzhen_map_master.gd, wenzhen_asset_manifest.gd, addons/reactive_ui_toolkit(+editor), scripts/guitkx_build.gd, tools/guitkx_build.ps1 | ~1200+addon | 2026-09-04 视觉方向 spec；**已裁决：这是新视觉架构，全部旧屏幕迁移到该模型，旧屏幕届时退役** | 核心（目标架构；迁移大工程另行排期） |

## I 文本与对话

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| I1 | Dialogue Manager 栈 | addons/dialogue_manager, scripts/domain/dialogue_manager_adapter.gd, dialogue_gateway.gd, template_dialogue_gateway.gd, data/dialogues/events.dialogue, data/dialogue_templates.json | ~500+addon | 事件文本；LLM 路线未实装，仅离线模板（invalid UID 遗留） | 冻结：LLM 永久搁置，仅保留离线模板与接入接口 |

## J 工具与基建

| ID | 模块 | 文件 | 规模 | 需求锚点 | 建议 |
|----|------|------|------|----------|------|
| J1 | Godot 脚本入口 | tools/godot.ps1, import.ps1, export.ps1, test.ps1, check.ps1, play.ps1, run_gut_checked.ps1, crash_recovery_check.ps1 | — | 全部验证/导出命令 | 核心 |
| J2 | 统一验收驱动 | scripts/acceptance_driver.gd | ~2800 | 验收基建（原 smoke_render/ui_capture/playthrough_smoke/crash_recovery_driver/integration_smoke/render_probe 六驱动于 B3 收编，`--mode=smoke/capture/play/render/crash`） | 已裁决：B3 瘦身完成 |
| J3 | guitkx 构建链 | scripts/guitkx_build.gd, tools/guitkx_build.ps1, tools/verify_codex_render.gd | ~160 | 服务 H7（新视觉架构的唯一构建链） | 已裁决：保留，承载屏幕迁移 |
| J4 | 蛊目录生成器 | tools/generate_gu_catalog.py | 265 | 确定性目录扩充器：从词频语料批量生成 蛊/卡/名，把每流派补到 40 只（common24/rare12/epic4），支撑「海量」支柱；cards.json 退役后需同步改造（去掉出卡） | 建议保留改造（待你归属） |
| J5 | GUT 测试框架 | addons/gut | — | 测试基建 | 核心 |
| J6 | 导出配置 | export_presets.cfg, build/win | — | Demo 导出 | 核心 |

## K 测试（约 150 单测 + 10 集成；随宿主模块同进退）

| ID | 范围 | 代表文件 | 建议 |
|----|------|----------|------|
| K1 | 现行契约测试 | test_wenzhen_*（ui/battle/map/hall/theme/visual）、test_v1_*、test_battle_command_facade、test_action_preview_service、test_rest_*、test_save_*、test_v1_five_layer_clear、test_run_state 等 | 随宿主核心保留 |
| K2 | 旧栈测试 | test_battle_resolver、test_v2_*、test_v3_battle_*、test_battle2_*、test_b3/b4/b5_*、test_action_card_row_migration、test_deck_capacity（仅剩 .uid） | 已裁决：随 D2--D5 收敛删除或迁移到 V1 |
| K3 | 集成测试 | test_drive_to_ending（有未提交改动）、test_wenzhen_ui_flow、test_first_run_flow、test_five_schools_smoke、test_long_run_soak、test_spec_v4_acceptance、test_smoke_outcomes、test_v3_roguelike_vertical_slice、test_debug_actions_flow、test_battle2_lifecycle | 已裁决：battle2/v3 垂直切片随旧栈退役，其余保留 |

## L 外围目录（只读 / 不入库）

| ID | 范围 | 说明 | 建议 |
|----|------|------|------|
| L1 | 分支：六卷精编版/, 肉鸽设计-原始数据/ | AGENTS 保护只读语料 | 保留不动 |
| L2 | vendor/godot-open-rpg | 未审计，AGENTS 禁止耦合 | 保留现状（是否移除由你决定） |
| L3 | THIRD_PARTY_NOTICES.md | 许可合规 | 核心 |
| L4 | MEMORY.md, memory/, .claude/, .claude-drive-sweep.log, godot_gui.log, opencode.json | 会话/本地痕迹 | 不入库 |
| L5 | docs/ | 权威规格 + 契约 + 计划 | 核心 |
| L6 | DEMO.md, README.md, AGENTS.md, PONYTAIL-DEBT.md | 运行手册与台账 | 核心 |

## 已知遗留（与本清单相关的未修项，不随裁决自动消失）

- ~~`resolver.gd` 超行数门限~~：W11 m3（2026-09-10）已拆分，resolver 261 行（AGENTS 待办同批清理）。
- Dialogue Manager invalid UID（待办 #6）。
- 流派选择屏空渲染（未入 AGENTS，缺陷在 H1/流派屏）。
- 小光蛊真窗拖拽 bug：排查中断，暂缓（H4 待你裁决交互形态后再定是否继续修）。
- ObjectDB/RID 泄漏专项（冻结列表）。
- 25-seed 平衡专项（冻结列表）。
