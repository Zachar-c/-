# 模块接口：领域动作路由（resolver + loot + economy）

> 契约层级：领域层。非战斗动作（商店/休整/遗葬/炼蛊/战利品/经济）的唯一路由；UI 提交命令 → resolver 返回新状态。
> 仓库路径：`scripts/domain/resolver.gd`（路由）、`scripts/domain/loot_resolver.gd`（战利品）、`scripts/domain/economy_rules.gd`（经济）

## 职责

把命令字典解析为领域动作：先校验，再执行，返回 `{ok, state, changes, feeds}`；战利品按层/敌人档次表结算，经济规则（资源换算/预算）集中于此。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `Resolver.apply(state, command, catalog)` | 状态 + 命令 | `{ok, state, result, reason, feeds, changes}` | **非战斗动作唯一入口** |
| `Resolver.recipe_unlocked(state, recipe)` | 配方 | bool | 配方解锁判定（图鉴/预检用） |
| `LootResolver.settle_victory(battle, state, catalog)` | 战斗字典（victory 态）+ 状态 | `{state, loot{material_ids[], gu_id}, cost?}` | 胜利战利品结算（材料/蛊/元石，含保底；elite 绑定单一种子代价） |
| `EconomyRules.*`（模块内各规则函数） | 资源参数 | 数值/判定 | 资源预算/换算（元石/寿元/魂魄上限等） |

## 关键数据契约

- 命令：`{type, ...}`；`type` 全集与 `docs/contracts/2026-09-02-domain-ui-contract.md` 一致
- resolver 内部 handler：`_buy_gu/_sell_gu/_exchange_gu/_refine_gu/_apply_combine_recipe/_apply_free_mix/_cultivate_rank_two/_rest_*/_inheritance_*` 等
- 战利品表：`data/loot_tables.json`（按 tier+layer），保底参数在 `balance.json`
- 返回契约：`feeds` = 给 UI 的文本反馈数组；`changes` = 变更摘要（`_summarize_changes` 消费）

## 信号

无（纯函数式 domain 模块）。

## 依赖

- `content_catalog.gd`（商店/配方/战利品/数值表）、`run_state.gd`（状态）、`gu_instance.gd`/`synthesis_rules.gd`（合炼）
- `data/shops.json`、`data/loot_tables.json`、`data/balance.json`、`data/refinement_recipes.json`

## 强制规则（Agent 生成代码必读）

1. 非战斗命令只经 `Resolver.apply` 路由；禁止在 UI/controller 直接改状态模拟商店/合成效果。
2. 新命令 handler 命名 `_<verb>_<noun>` 并在 `_handler_for` 登记，返回结构必须含 `{ok, state, result}`。
3. 战利品只经 `settle_victory` 结算，保底/权重配置在 JSON，不在代码硬编码。
4. 资源扣减/入账统一走 resolver 内 `_spend_*`/`_grant_*` 辅助，禁止散落各处直接改状态键。
