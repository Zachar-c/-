# PONYTAIL-DEBT

> 本清单收集所有打了 `ponytail:` 标记的刻意简化。每行命名上限与升级触发，
> 让延期不能悄悄变成永久。新增债务时：代码里加 `ponytail: <上限>, <升级触发>`
> 注释，同时在下表登记一行。复核命令：`grep -rn "ponytail:" scripts/ --include='*.gd'`。

## 台账

| 位置 | 简化了什么 | 上限 | 升级触发 |
|---|---|---|---|
| `scripts/domain/v1_battle_resolver.gd:130` | ~200 个 legacy 蛊走 role fallback 效果，无回合到期语义 | 执行 `effect_reason` / 预览过滤双护栏已兜住 | 某个蛊进 slice 或需要精确效果/到期时，逐个迁显式 `v1_effect` |
| `scripts/domain/*_command_rules.gd`（rest/shop/refine/social，见 resolver.gd:4） | 命令族拆模块后单文件增长护栏 1200 | 各命令族模块当前 237--945 行 | 任一 domain 文件撞 1200 行门限时继续按命令族抽模块 |
| `game/tools/verify_interaction_loop.gd`（已删除） | 全屏 `dead/no_ui_click/occluded` 扫描改为按屏 GUT 真实点击断言 | 当前只覆盖代表性战斗屏与各屏渲染契约 | 新的“接线齐全但点不到”缺陷逃过 GUT 时，补对应屏断言或重建最小扫描器 |

## 已清账（备忘）

- 手牌拖拽交互：现役组件 `GuTallFanHandView`（旧 `gu_battle_hand_view` 已随 `6c96623` 迁移删除）——按住拖拽出影卡 / 指向卡出瞄准弧箭，battle_screen `_input` 全局手势分流，松手命中敌方卡即按该目标出牌（危险卡进确认流）。回归锁：`test_drag_card_onto_enemy_submits_with_that_target` / `test_drag_release_off_enemies_does_not_submit`，以及竖长卡批新增的 `test_drag_proxy_is_opaque_and_larger_than_source_card` / `test_aim_line_is_a_curved_arrow_from_card_top` / `test_tooltip_anchors_above_card_and_hides_during_drag`。
- 旧 UI 并行栈（`scripts/ui` card_view/hand_panel + 场景 + 4 守卫测试 + `gu_theme.tres`）：已在 `a36bcf3` 退役。
- resolver 资源交易结算：已迁 `EconomyRules.resource_trade_plan`（`6a30cde`），resolver 回到门限内。
- resolver 命令族拆分：rest/shop/refine/social 四模块落地（W11 m3，A2--A5，2026-09-10），resolver 1182→261 行纯路由核心；公开 API 全部一行转发保留，dispatch 改指模块，行为零改动（unit 1167/1167）。
