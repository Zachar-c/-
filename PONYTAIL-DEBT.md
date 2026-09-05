# PONYTAIL-DEBT

> 本清单收集所有打了 `ponytail:` 标记的刻意简化。每行命名上限与升级触发，
> 让延期不能悄悄变成永久。新增债务时：代码里加 `ponytail: <上限>, <升级触发>`
> 注释，同时在下表登记一行。复核命令：`grep -rn "ponytail:" scripts/ --include='*.gd'`。

## 台账

| 位置 | 简化了什么 | 上限 | 升级触发 |
|---|---|---|---|
| `scripts/presentation/screens/battle_screen_view.gd:300` | 手牌拖拽回调（on_drag/on_release）未接线，仅点击出牌可用 | 点击链路完整可用 | 实际需要拖拽交互时给 `gu_battle_hand_view` 补 `_gui_input` |
| `scripts/domain/v1_battle_resolver.gd:130` | ~200 个 legacy 蛊走 role fallback 效果，无回合到期语义 | 执行 `effect_reason` / 预览过滤双护栏已兜住 | 某个蛊进 slice 或需要精确效果/到期时，逐个迁显式 `v1_effect` |
| `scripts/domain/resolver.gd:4` | resolver.gd 行数贴着 2430 门限（2422/2430） | T1.2 增长门限单向向下 | 下个功能撞门限时把 `_shop_barter` 或 rest 簇迁入独立模块（先例：`resource_trade_plan -> economy_rules.gd`） |
| `scripts/guitkx_build.gd:4` | `.guitkx` 生成层仍服务非战斗屏，双渲染路径并存 | 战斗屏已原生 `.tscn` 化 | 新屏一律 `.tscn`；旧屏触碰到时逐个退役生成层 |

## 已清账（备忘）

- 旧 UI 并行栈（`scripts/ui` card_view/hand_panel + 场景 + 4 守卫测试 + `gu_theme.tres`）：已在 `a36bcf3` 退役。
- resolver 资源交易结算：已迁 `EconomyRules.resource_trade_plan`（`6a30cde`），resolver 回到门限内。
