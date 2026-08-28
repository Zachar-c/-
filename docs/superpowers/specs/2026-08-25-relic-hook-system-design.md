# 《問眞》遗物钩子系统设计（数据驱动枚举效果，已归档）

> 日期：2026-08-25
> 状态：已归档
> 范围：遗物钩子系统的历史设计；保留用于实现追踪。
> 权威基线：[机制先行锁死规格书](./2026-08-25-mechanics-first-lockdown-design.md)
> 替代关系：当前被动组件规则由机制先行锁死规格书及其后续生效规格取代。


> 南疆冒烟切片的遗物从"硬编码扁平被动字段"升级为"数据驱动枚举效果 + 固定触发器"。目标：让遗物能响应战斗生命周期（战斗开始/抽卡/出牌/受击）和养护估算，同时保持领域规则纯 GDScript、确定性、可复现、可测试；不引入通用脚本求值系统。

## 1. 问题背景

当前两条遗物是被动扁平字段，且消费点硬编码：

```json
[
  { "id": "jade_cicada_shell", "first_turn_energy": 1 },
  { "id": "hungry_vine_token", "extra_upkeep_feed_points": 1 }
]
```

- `battle_resolver.start()` 手写累加 `first_turn_energy`，但**该字段从不被消费**（死代码，设计文档 `2026-08-23-gu-card-roguelike-design.md` 明示其应为首回合 +1 行动能量，从未实现）。
- `run_state.estimate_feeding_materials()` 手写累加 `extra_upkeep_feed_points`。
- 每加一个遗物效果都要改消费点，且无法表达"抽卡时""出牌后""受击前"这类触发时点。
- 南疆冒烟切片的策略目标（计划约束：资源/情报/人情/交易/撤退/伪装/设局/战斗都可用）需要遗物能接入战斗时机，而不只是数值被动。

## 2. 决策

1. **数据驱动枚举效果（模型 A）**：遗物在 JSON 里声明 `hooks`，每个 hook 由固定枚举的 `trigger` + `effect.kind` 组成；每种 effect kind 一个纯 GDScript 固定函数。不建通用脚本求值系统（遵循 `2026-08-23-gu-card-roguelike-implementation.md` Task 7 约束 "do not create a generic script-evaluation system"）。
2. **状态变更走不可变事件日志**：凡影响 `RunState` 的钩子效果都经 `RunState.append_event` 落账；battle 内部状态（旗标/手牌/能量计数）在 battle dict 内更新并 bump 相关版本号。
3. **顺修存量**：让 `jade_cicada_shell` 的 `first_turn_energy` 真正生效（首回合 +1 行动能量）；把 `hungry_vine_token` 的养护被动并入同一效果源。
4. **无遗物时全程 no-op**：`state.relic_ids` 为空或 catalog 中钩子缺失时，行为与现状完全一致，保证既有 159 unit + 6 integration 全绿。

## 3. 数据模型

`data/relics.json` 每个遗物：

```json
{
  "id": "jade_cicada_shell",
  "hooks": [
    { "trigger": "on_battle_start", "effect": { "kind": "grant_first_turn_energy", "amount": 1 } }
  ]
},
{
  "id": "hungry_vine_token",
  "hooks": [
    { "trigger": "on_estimate_feeding", "effect": { "kind": "add_feeding_points", "amount": 1 } }
  ]
}
```

- `hooks` 为数组；同一遗物可有多个 hook。
- 字段全部 ASCII。

### 触发器（trigger）枚举

| trigger | 触发点 | 说明 |
| --- | --- | --- |
| `on_battle_start` | `battle_resolver.start` 构造战斗后、返回前 | 可加首回合能量/初始旗标 |
| `on_draw_card` | 抽牌/补牌入手的时点 | 可额外抽卡 |
| `on_play_card` | 一张手牌命令解析成功后 | 可回真元/追加效果 |
| `on_take_damage` | 敌方意图结算、对主角造成伤害前 | 可减伤 |
| `on_estimate_feeding` | `estimate_feeding_materials` 估算养护时 | 只读查询，返回附加养护 |

### 效果 kind 枚举

| kind | 用法 | 落账方式 |
| --- | --- | --- |
| `grant_first_turn_energy` | battle 首回合额外行动能量 | battle dict `first_turn_energy` 累加，并由 player 阶段消费 |
| `draw_extra_card` | 额外抽 N 张 | battle dict 手牌 + 版本号 |
| `gain_essence_on_play` | 出牌后真元 +N | RunState `append_event` |
| `reduce_incoming_damage` | 受击伤害 -N（最小 0） | 伤害修正列计入 battle 日志，最终健康变化经 `_end_turn` 单次落账 |
| `add_feeding_points` | 养护估算 +N | 只读，不入事件日志（估算本身是查询） |

初始只实现上述 5 种；额外 kind 后续按需在 resolver 加分支并在 `ContentCatalog.validate` 白名单内注册。

## 4. 领域模块

新文件 `scripts/domain/relic_hook_resolver.gd`（`class_name RelicHookResolver`，纯 RefCounted 静态工具，无 UI 依赖）：

```gdscript
static func apply_battle_start(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary
# -> { "battle": Dictionary, "state": RunState, "feeds": Array[String] }
static func apply_draw_card(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary
static func apply_play_card(battle: Dictionary, state: RunState, catalog: Dictionary, definition: Dictionary) -> Dictionary
static func apply_take_damage(battle: Dictionary, state: RunState, catalog: Dictionary, damage: int) -> Dictionary
# -> { "battle": Dictionary, "state": RunState, "damage": int, "feeds": Array[String] }
static func feeding_extra(state: RunState, catalog: Dictionary) -> int
```

内部：
- `_hooks_for(state, catalog, trigger) -> Array[Dictionary]`：按 `state.relic_ids` + `catalog.relic_by_id` 收集该 trigger 的 hook，按遗物 id 的字符串序稳定排序（确定性）。
- 每种 effect kind 一个私有 static 函数，返回 `{battle?, state?, ...}` 增量，由调用方合并。
- `state` 经 `append_event` 返回新实例；battle dict 用 `duplicate(true)` 后修改。
- 未知 kind：`ContentCatalog.validate` 已拒；运行时遇到仍安全跳过（防御）。

## 5. 消费点改造

### 5.1 `battle_resolver.start`

删除手写 `first_turn_energy` 累加循环，改为：

```gdscript
var hook_result := RelicHookResolver.apply_battle_start(battle_dict, state, catalog)
battle_dict = hook_result["battle"]
state = hook_result["state"]
```

`grant_first_turn_energy` 累加进 `battle["first_turn_energy"]`。

**如何让 `first_turn_energy` 真正生效**：player 阶段结算出牌/收势前的行动能量 = `first_turn_energy` 首回合可用。实现：battle dict 新增 `action_energy` 字段，战斗开始时 `action_energy = first_turn_energy`；首回合 player 阶段打出卡时，`action_energy` 可抵扣 1 点真元消耗，或直接作为"当回合可多花真元"的预算。为保持与现有 `_use_gu` 的 `state.essence` 校验兼容，采用**简单直接**口径：`on_battle_start` 挂 `grant_first_turn_energy` 时，将等量点数加入 `battle["first_turn_energy"]`，而 player 阶段第一个出牌动作（或收势前）把该能量折算为真元预算：`available_essence = state.essence + battle.first_turn_energy`（仅首回合；首回合结束后清零，计入 battle 日志）。

> 说明：此口径由实现时以测试锁定（TDD），保证确定性；展示层只读 `battle["first_turn_energy"]` 作 HUD 提示。

### 5.2 抽卡/补牌（`start` 抽牌与 `_refill_hand_after_turn`）

在把卡移入手牌后调用 `apply_draw_card`；`draw_extra_card` 效果额外抽 N 张并 bump `hand_version`。

### 5.3 出牌后（`_resolve_card_instance` 成功路径）

用解析出的 `definition` 调 `apply_play_card`；`gain_essence_on_play` 落事件日志。

### 5.4 受击前（`_end_turn`）

在用旗标计算 `damage` 后、写健康事件前，调 `apply_take_damage` 得到修正 damage；`reduce_incoming_damage` 最小扣到 0。健康变化只由 `_end_turn` 写一次事件。最终一击 `final_blow` 判定用修正后的 damage。

### 5.5 `run_state.estimate_feeding_materials`

删除手写 relic 循环，改为 `totals["feed_points"] += RelicHookResolver.feeding_extra(state, catalog)`。

### 5.6 `content_catalog.validate`

- 校验每个 hook 的 `trigger` 在枚举白名单。
- 校验每个 effect `kind` 在 effect 白名单、`amount` 存在且为非负整数（`_is_integral` 归一）。
- 报错文案 ASCII：`relic <id> hook <i> references unknown trigger <t>` / `unknown effect kind <k>` / `effect amount must be a non-negative integer`。

## 6. 测试计划（TDD）

新文件 `tests/unit/test_relic_hook_resolver.gd`，先写失败再实现：

1. `test_battle_start_grant_first_turn_energy_sets_energy_and_logs`：持 `jade_cicada_shell` 开局，`battle.first_turn_energy == 1`，首回合出牌可多花 1 真元，回合内日志可追踪。
2. `test_draw_card_extra_draw_increases_hand`：合成遗物 `{trigger:on_draw_card, kind:draw_extra_card, amount:1}`，补牌后手牌比无遗物多 1 张，`hand_version` 递增。
3. `test_play_card_gain_essence_returns_refund_to_state`：`gain_essence_on_play amount:2` 出牌后 `state.essence` 增加且事件日志出现对应 reason。
4. `test_take_damage_reduction_never_below_zero`：`reduce_incoming_damage amount:5` 对 2 点意图伤害，最终 `state.health` 不变（0 伤害），`final_blow` 不触发。
5. `test_feeding_extra_adds_to_estimate`：`hungry_vine_token` 使 `estimate_feeding_materials(...)[feed_points] == 2`（现有测试语义保持）。
6. `test_no_relics_is_noop`：无遗物时 battle/state 与现有基线一致，`feeds` 为空。
7. `test_validate_rejects_unknown_trigger_and_effect`：注入坏遗物，`ContentCatalog.validate` 返回对应错误。
8. `test_multiple_relics_stable_order`：多遗物同 trigger 时效果按遗物 id 稳定排序（确定性）。

既有测试不破坏；全量 `tools\test.ps1` 保持 159 unit + 6 integration 绿。

## 7. 范围边界（不做）

- 不做通用脚本求值 / 任意 Lua / 每遗物独立 GDScript 回调注册（模型 C 被否）。
- 不做遗物背包容量/卖出（那是另一个决策点）。
- 不做局外解锁 MetaProgress 层面的遗物获取（`MetaProgress` 严禁存 `relic_ids`，沿用现规）。
- 不动 `vendor/godot-open-rpg/`。

## 8. 提交粒度

- 提交 1：spec 文档（本文档）。
- 提交 2：测试 + `relic_hook_resolver.gd` + 消费点接线 + `relics.json` 迁移 + validate 扩展（一个功能提交，先失败测试后实现，保持小而聚焦）。
