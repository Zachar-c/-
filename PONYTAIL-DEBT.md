# PONYTAIL-DEBT

> 本清单收集所有打了 `ponytail:` 标记的刻意简化。每行命名上限与升级触发，
> 让延期不能悄悄变成永久。新增债务时：代码里加 `ponytail: <上限>, <升级触发>`
> 注释，同时在下表登记一行。复核命令：`grep -rn "ponytail:" scripts/ --include='*.gd'`。

## 台账

| 位置 | 简化了什么 | 上限 | 升级触发 |
|---|---|---|---|
| `scripts/domain/v1_battle_resolver.gd:130` | ~200 个 legacy 蛊走 role fallback 效果，无回合到期语义 | 执行 `effect_reason` / 预览过滤双护栏已兜住 | 某个蛊进 slice 或需要精确效果/到期时，逐个迁显式 `v1_effect` |
| `scripts/domain/*_command_rules.gd`（rest/shop/refine/social，见 resolver.gd:4） | 命令族拆模块后单文件增长护栏 1200 | 各命令族模块当前 237--945 行 | 任一 domain 文件撞 1200 行门限时继续按命令族抽模块 |
| `scripts/guitkx_build.gd:4` | `.guitkx` 生成层仍服务非战斗屏，双渲染路径并存 | 战斗屏已原生 `.tscn` 化 | 新屏一律 `.tscn`；旧屏触碰到时逐个退役生成层 |

## 已清账（备忘）

- 手牌拖拽交互：现役 `GuTallFanHandView`（`scripts/presentation/widgets/gu_tall_fan_hand_view.gd`）以卡按钮 `button_down` + `gui_input` 驱动拖拽/瞄准，命中敌方卡经 `card_chosen(card_id, target_id)` 冒泡出牌（危险卡进确认流），敌人高亮由宿主订阅 `aim_target_changed` 施加（`battle_screen_view.gd:_set_drop_hot`）。回归：`tests/unit/test_wenzhen_card_fsm.gd` 的 `test_drag_card_onto_enemy_submits_with_that_target` / `test_drag_release_off_enemies_does_not_submit` 锁原行为；2026-09-10 手牌改造新增三条——`test_drag_proxy_is_opaque_and_larger_than_source_card`（影卡不透明放大）/ `test_aim_line_is_a_curved_arrow_from_card_top`（弧箭起点与转色）/ `test_tooltip_anchors_above_card_and_hides_during_drag`（解释栏不挡卡）。
- 旧 UI 并行栈（`scripts/ui` card_view/hand_panel + 场景 + 4 守卫测试 + `gu_theme.tres`）：已在 `a36bcf3` 退役。
- resolver 资源交易结算：已迁 `EconomyRules.resource_trade_plan`（`6a30cde`），resolver 回到门限内。
- resolver 命令族拆分：rest/shop/refine/social 四模块落地（W11 m3，A2--A5，2026-09-10），resolver 1182→261 行纯路由核心；公开 API 全部一行转发保留，dispatch 改指模块，行为零改动（unit 1167/1167）。
