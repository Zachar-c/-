# V1 战斗 Schema（唯一契约，2026-09-01 定稿）

> 范围：`V1BattleResolver` 产出的战斗状态是**唯一**领域契约；`BattleCommandFacade`
> 是唯一命令入口；`RunSnapshotBuilder.battle()` 是唯一 UI 投影；战斗屏只读快照、
> 通过命令边界提交。本文档钉死字段与各层职责，禁止出现第二套战斗形状。

## 1. 领域状态（resolver / facade 共写，controller 持有）

`current_battle` 为普通 `Dictionary`，由 `V1BattleResolver.start()` 构建，
每次动作 `duplicate(true)` 后写回（纯函数式）。

```gdscript
{
  "turn": 1,                       # int，回合计数（敌人回合结算后 +1）
  "phase": "player_action",        # "player_action" | "victory" | "defeat"
  "cfg": {...},                    # data/v1_battle.json 原样
  "player": {
    "hp": 80, "max_hp": 80,        # 出身气血（cultivator.health，随重做 80）
    "life_time": 60,               # 寿元，归零即死
    "soul": 1,                     # 当前魂魄底蕴（死亡判定 + 行动分档输入）
    "aptitude": "bing", "stage": "one", "stage_base": 10,
    "true_qi": 20, "true_qi_max": 20,   # 真元：境界基础 × 资质倍率
    "regen": 5,                    # 每回合回复 = 上限 × 资质百分比（向上取整）
    "thoughts": 2,                 # 本回合剩余念头（行动点），每次行动耗 1
    "used_this_turn": 0,           # 本回合已用行动数
    "shield": 0, "buffs": {"force": 0, "yi_zhang": 0}
  },
  "enemies": [{
    "id": "ridge_hound", "label": "ridge_hound",  # label=名称（缺省回退 kind，呈现层翻译）
    "hp": 3, "max_hp": 3, "alive": true, "shield": 0, "statuses": {},
    "intent": {"kind": "attack", "damage": 2, "label": "伏肩扑咬", "speed": 0,
               "seal_turns": 0, "soul_drain": 0, "life_cost": 0, "counter_tag": ""},
    "counter_revealed": [], "counter_hidden": []
  }],
  "gu_slots": [{                   # 非战斗蛊已过滤（combat 空/"none" 不入场）
    "instance_id": "gu_001", "definition_id": "small_light_gu",
    "is_sealed": false, "seal_turns": 0, "used_this_turn": false,
    "true_qi_cost": 1, "thought_cost": 1, "life_cost": 0,
    "is_permanent": false, "durability_mode": "",
    "trigger_qi_cost": 0, "trigger_block": 0, "maintain_qi_cost": 0,
    "duration_turns": 0, "effect": {"kind": "strike", "amount": 1},
    "consumed": false
  }],
  "active_permanents": [],         # 数组，存常驻蛊 instance_id
  "kill_moves": [{                 # 战斗外配方组装，配方蛊都在袋才出现
    "id", "label", "tag", "recipe": [instance_id...],
    "true_qi_cost", "thought_cost", "life_cost", "damage", "effect", "reveals"
  }],
  "log": [],                       # 战斗内日志（turn/reason/target）
  "flags": {},                     # ⚠️ Dictionary！Boss 战用 {"boss_battle": true}
  "result": null,                  # 终结时 {"outcome": "victory|death", "cause"?: "hp|life_cost|soul"}
  # facade 透传（不在 resolver 内产生）：
  "enemy_kind", "kill_source", "terrain", "layer", "first_mover", "enemy_kinds",
  "loot", "cost"                   # victory 结算后写入
}
```

### 禁止字段（旧卡牌引擎残留，任何层都不再读取/写入）
`draw_pile` / `discard_pile` / `exhausted_cards` / `hand` / `hand_version` /
`actions_max` / `actions_left` / `visible_intent` / `player_block` /
`temp_power` / `final_blow` / `clues` / `revealed_reactions` / Array 型 `flags`。

## 2. 行动点（念头）统一

2026-08-31 裁定：念头/行动点/一心多用共用一张分档表，唯一实现在
`scripts/domain/action_points.gd`：

| 魂魄底蕴 | 每回合行动数（念头） |
|---|---|
| <10（含 1） | 2 |
| 10–99 | 3 |
| 100–999 | 4 |
| 1000–9999 | 5 |
| ≥10000 | 6 |

- 每次行动（蛊/拳脚/杀招）耗 1 念头；`used_this_turn` 计已用。
- 回合开始念头回满 = `ActionPoints.per_turn(soul)`；敌人 `soul_drain` 先扣
  soul 再于下回合降档。
- 门禁：`can_play_gu()` / `basic_attack_reason()` / `kill_move_reason()` 是
  唯一可执行性来源，UI 不得自算。

## 3. 命令契约（唯一入口）

`BattleCommandFacade.apply_turn(battle, state, command, catalog)`：

| 命令 | 载荷 | 行为 |
|---|---|---|
| `use_gu` | `instance_id` | 路由 `play_gu`（按 slot） |
| `basic_attack` | – | 肉体搏斗 |
| `play_kill_move` | `kill_move_id` | 预制杀招 |
| `end_turn` | – | 敌人回合结算 + 玩家回合开始 |
| `retreat` | – | 直接结算为 retreat（Boss 由 `boss_blocks_retreat` 禁撤） |
| `action_card` | 旧信封 | 仅透传 basic.punch / end_turn / retreat（兼容，不新增） |

`run_controller.submit_command` 对以上类型一律走 `_submit_battle_command`。

## 4. 快照契约（唯一 UI 投影）

`RunSnapshotBuilder.battle()` 只读搬运，字段：

- `enemies[]`：`id/name/hp/max_hp/shield/statuses/intent{type,value,detail,speed}/alive/counter_revealed`
  - `name`：`label` 为原始 kind 时经 `DisplayText.enemy()` 翻译；自定义 label 直通。
  - `intent.type` 直映 V1 `kind`（attack/seal/soul_drain/life_cost/counter），
    `value` 对应 damage/seal_turns/soul_drain/life_cost。
- `player`：`hp/max_hp/shield/primordial(=true_qi)/primordial_max/soul/life_time/
  thoughts/used_this_turn/statuses(由 buffs 投影)/buffs`
- `actions`：`{max: ActionPoints.per_turn(soul), left: max-used, used}`
- `hand[]`：蛊槽卡（id `gu.<instance_id>`）+ 拳脚（id `basic_attack`）；
  `executable` 取自 V1 门禁，`block_reason` 中文化。
- `kill_moves[]`：配方蛊名拼接 + `executable`（`kill_move_reason`）。
- `piles`：恒空 `{}`（V1 无牌库）。
- `flee_available`：`not BattleCommandFacade.boss_blocks_retreat(battle)`
  （flags Dictionary 判定）。
- 其余（resources/contracts/anomalies/death_lines/dda_boss_hint/first_battle/feedback）与各屏共用。

## 5. 存档

`RunState` 不保存战斗（战斗随节点结算）；事件日志 `battle_v1` 只记
`after.battle_turn`。档案存储层面无 V1 字段，无需迁移。

## 6. 验证锚点（全绿基线）

- `test_v1_battle_resolver.gd`（20/20）：引擎纯函数规则
- `test_battle_command_facade.gd`（10/10）：命令路由与结算
- `test_v3_ui_sync.gd`（14/14）：快照投影
- `test_v1_battle_mounted.gd`（1/1）：真实挂载战斗（tscn 挂载 + 实跑命令至 victory）
- 战斗线路 walker：`test_moonlight_full_route`（3/3）、`test_v2_first_slice_flow`
  （7/7）、`test_slay_gu_final_chapter`（2/2）
- `test_command_contract.gd`（10/10）：命令字面量契约（含 play_kill_move）
- 渲染：`smoke_render` EXIT=0；`render_probe` 主场景 VERDICT=OK（UNIQUE=304）

## 7. 消费方清单（全部走本契约）

| 层 | 文件 |
|---|---|
| 引擎 | `scripts/domain/v1_battle_resolver.gd` |
| 行动点 | `scripts/domain/action_points.gd`（旧引擎 `battle_resolver.actions_per_turn` 委托同一张表） |
| 门面 | `scripts/domain/battle_command_facade.gd` |
| 快照 | `scripts/presentation/run_snapshot_builder.gd` |
| 命令组装 | `scripts/presentation/run_command_builder.gd`（gu. / basic_attack / kill_move. 映射） |
| UI | `scenes/ui/screens/battle_screen.tscn` + `scripts/presentation/screens/battle_screen_view.gd` |
| 死神报告 | `scripts/domain/death_report_builder.gd`（容忍 V1 缺旧字段，仅作结算文案） |

## 8. 五层通关 / Boss 推进 / 升仙链（2026-09-01 追加）

- **Boss 身份透传**：`RunController._start_battle()` 把当前节点 `layer_boss` 写入
  encounter；`BattleCommandFacade.start()` 依据 `layer_boss > 0` 或任一敌方定义
  `tier == "boss"` 落 `flags.boss_battle = true`（V1 flags 为 Dictionary）。
- **撤退门禁**：`apply_turn("retreat")` 在 Boss 战返回 `retreat_forbidden`（rejected）；
  UI 的 `flee_available` 与 playthrough bot 共用 `boss_blocks_retreat()`，全链生效。
- **战后立场归位**：`_finish_battle_in_session()` 结算后把 session 立场设为
  neutral 并清 reputation 旗标——`feud_no_escape` 只应阻止「战前不战而逃」，
  打赢 Boss 后被锁在场等同永久软锁。
- **血仇无仗可打放行**：`EncounterSessionResolver.start()` 固化 `offers_fight`
  （choices 含 fight 或 caravan 特例）；extreme_hostile 时预览层与 `_leave`
  同语义：有仗必须打，无仗可打允许离开（修复 wild_gu/market/rest 等节点的硬死锁）。
- **真实五层验收**：`tests/unit/test_v1_five_layer_clear.gd`——固定种子
  （20260831；运行路径已不设教学/固定种子，101 与其他种子一样走生成式大图，
  见 2026-09-03 垂直切片「种子策略」）经真实 MapGenerator route 走完五层：
  `boss_defeated_L1..L5` 只作层级通关旗标，不改变修为或真元；Boss 战斗数值由
  中央倍率与层级曲线统一投影；全局 `boss_defeated` + 升仙窗
  `attempt_ascension` 结局评价 + 统一结算 Ending；多种子（4242/20260831/77/9/5150）
  无软锁且同种子复跑结局/事件数/旗标可复现。
