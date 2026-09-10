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

- 手牌拖拽交互：`gu_battle_hand_view` 补 `_gui_input` 左键抬起回传落点，battle_screen `_on_card_release` 命中敌方卡即按该目标出牌（危险卡进确认流），测试 `test_drag_card_onto_enemy_submits_with_that_target` / `test_drag_release_off_enemies_does_not_submit` 锁住。
- 旧 UI 并行栈（`scripts/ui` card_view/hand_panel + 场景 + 4 守卫测试 + `gu_theme.tres`）：已在 `a36bcf3` 退役。
- resolver 资源交易结算：已迁 `EconomyRules.resource_trade_plan`（`6a30cde`），resolver 回到门限内。
- resolver 命令族拆分：rest/shop/refine/social 四模块落地（W11 m3，A2--A5，2026-09-10），resolver 1182→261 行纯路由核心；公开 API 全部一行转发保留，dispatch 改指模块，行为零改动（unit 1167/1167）。
