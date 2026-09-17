# 模块接口：战斗结算（v1_battle_resolver + battle_command_facade）

> 契约层级：领域层。本页是 Agent 接入战斗的唯一入口约定，禁止绕过 facade 直接操作 battle 字典。
> 仓库路径：`scripts/domain/v1_battle_resolver.gd`、`scripts/domain/battle_command_facade.gd`

## 职责

推进蛊行动制战斗的状态机：`player_action`（出蛊/拳脚/杀招/结束回合/撤退）→ 结算 → `victory|defeat|player_action`，不持有任何表现层引用。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `Facade.start(encounter, state, catalog)` | encounter: `{enemy_kind}` / `{enemy_kinds}` / **`{enemy_roll}`**；state: RunState | `{battle, enemies, result}` | 构建战斗字典；Boss 战写 `flags.boss_battle=true`。**敌人来源优先级：`enemy_roll` > `enemy_kinds` > `enemy_kind`**（E6，2026-09-10）：地图生成期已按层抽好时用 `enemy_roll`；锚点/关底台/旧存档无该键时回退。单敌遭遇（`enemy_roll` 长度 1）同时落顶层 `battle.enemy_kind`（死亡报告与敌方台词按该键取专属文案） |
| `Facade.start_session(encounter, state, catalog)` | 同 `start` | `{battle, state, result:"ongoing"}` | **会话边界**（第三阶段 Task 2，2026-09-17）：构建 battle 并初始化 `state.current_battle2_ledger`；表现层开局只准走这里 |
| `Facade.apply_turn(battle, state, command, catalog)` | command: `{type, instance_id, target_id, ...}` | `{battle, state, result, accepted, feeds, finished}` | **唯一合法行动入口**；`finished=true` 即战斗结束（victory/defeat/retreat）；拒绝一律 `{accepted:false, finished:false, feeds:[原因]}` |
| `Facade.finalize_session(battle, state, outcome)` | outcome: `victory` / `death` / `retreat` | `{state, ledger}` | **会话收口**（第三阶段 Task 2）：交出一次账本快照并清空 `state.current_battle2_ledger`；由生命周期层写进唯一的 `battle_finished` 事件 |
| `Facade.apply_enemy_pre_turn(battle, state, catalog)` | battle | 同 `apply_turn` 信封 | **敌人先手与玩家主动结束回合同一条结算路径**（第三阶段 Task 2）：等价于 `apply_turn(..., {"type":"end_turn"})`，同样结算敌意、落一条 `battle_v1` 并推进账本 |
| `Facade.settle_sword_marks(battle, state, catalog)` | battle 上一次性名单 `sword_mark_spent` | RunState | **T16 残锋回写**（2026-09-15）：resolver 只见 battle，跨战斗永久消耗由门面侧读名单后调 `SwordMarkRules.apply_erosion` 落 `RunState.gu_instances`，并消费式抹键防重复扣 |
| `V1.player_action(battle, action)` | action: `{type: play_gu/basic_attack/play_kill_move/end_turn}` | `{battle, result:{ok, reason, changes}}` | 底层原语；**表现层不得直呼**，仅守卫测试使用。`play_kill_move` 可选 `confirmed`（T16）：未确认且会触发质变 → 拒绝 `sword_mark_confirm_required`，不扣余量、不执行 |
| `V1.end_turn(battle)` | battle | `{battle, result}` | 敌方意图结算 + 新回合；内部检查 `_is_over` |
| `Facade.boss_blocks_retreat(battle)` | battle | bool | Boss 战禁止撤退 |

## 关键数据契约（battle 字典）

- 玩家区：`player.{hp, max_hp, shield, life_time, soul, true_qi, thoughts, used_this_turn, buffs{force/yi_zhang}, position, cultivation}`
- 敌区：`enemies[] = {id, label, hp, max_hp, shield, alive, intent{kind, damage, seal_turns, soul_drain, life_cost}, statuses{}, counter_revealed, counter_hidden}`
- 蛊槽：`gu_slots[] = {instance_id, definition_id, rank, rank_held, sword_downgrades, dao_marks, dao_marks_per_downgrade, sword_mark_cost, used_this_turn, is_sealed, consumed, true_qi_cost, thought_cost, durability_mode, v1_effect, effect}`
  - **`rank` = 等效转数**（`max(1, rank_held - sword_downgrades)`）；`rank_held` 为持有转数（含同名升阶）。未降转实例 `rank == rank_held`（T16，2026-09-15）。
  - `dao_marks` = 距下次质变的剩余逆炼次数（旧存档缺键按 `v1_battle.sword_dao_marks_init` 读取）。
- 杀招区：`kill_moves[] = {id, label, tag, recipe, true_qi_cost, thought_cost, life_cost, damage, effect, reveals, dangerous?, sword_mark_recipe?, known_risk?}`；
  `reveals` 是**用后置位**的"已泄密"标记（初始 false，用过一次即 true）；`revealed_to[]` = 本场洞悉了该杀招的敌人 id（T14，2026-09-12）。
  杀招以 `tag` 作为流派归属，故与蛊**共用** `turn_supports` 支援通道（同回合先出的同流派支援蛊会加成后续杀招）。
  带残锋的杀招额外：`dangerous` / `sword_mark_recipe`（配方中吃逆炼的蛊 id）/ 预览风险文案；出招成功后 resolver 在 battle 上留一次性 `sword_mark_spent`，由 `Facade.settle_sword_marks` 落地实例。
- 阶段：`phase ∈ {player_action, victory, defeat}`；`result = {outcome, cause}`（cause ∈ hp/life_cost/soul）
- 旗标：`flags = {}`（Dictionary，非 Array；Boss 战含 `boss_battle`，撤离收场含 `session_closed=true`）
- 会话账本：`state.current_battle2_ledger`，由门面 `start_session` 建立、每次被接受的进行中行动扣 1 念头、`finalize_session` 取快照后清空。**表现层不得自行 `Battle2TurnEngine.new_turn()/consume()`**

## 信号

无（纯函数式 domain 模块；表现层经 `run_controller` 轮询 `finished/result`）。

## 依赖

- `content_catalog.gd`（load_all 提供蛊定义/敌人/数值）；`run_state.gd`（RunState 投影）
- `data/balance.json`（撤退/转阶成本）；`data/enemies.json`（敌人基础值）
- `action_points.gd`（每回合行动数）；`cultivator_rules.gd`（转阶门禁）；`seeded_roll.gd`

## 强制规则（Agent 生成代码必读）

1. 战斗任何状态变更必须经 `Facade.apply_turn`；表现层不得改写 battle 字典键。
2. 新增行动类型必须三处同步：`Facade.apply_turn` 的 command 路由、`V1.player_action` 的 action 路由、`docs/contracts/2026-09-02-domain-ui-contract.md` 命令面。
3. 战斗结束（victory/defeat/retreat）后任何 action 必须返回 `battle_over` 拒绝：victory/defeat 由 `phase` 判定，retreat 由 `flags.session_closed` 判定，门面在 `apply_turn` 入口统一拦截（拒绝不得改动 battle 或事件日志）。**收口事件不属门面**：victory/retreat/death 的唯一 `battle_finished` 由生命周期层 `RunBattleFlow.finish_battle_in_session` 追加（见 08 页）。
4. `state.current_battle2_ledger` 的生命周期只属门面：`start_session` 建、`apply_turn` 推进、`finalize_session` 收口清空；表现层只准消费 `finalize_session` 返回的 `ledger` 快照。
5. 效果数值只经 `v1_effect`/`effect` 字典表达，禁止在 resolver 内硬编码成本/伤害。
6. **残锋只减不增**：唯一允许写 `dao_marks` / `sword_downgrades` 的模块是 `SwordMarkRules`（经 `Facade.settle_sword_marks`）；任何回复路径违规。
7. 回合末 `_settle_marks`（T15 刻痕）只读 `statuses.marked`，独立伤害通道不吃护盾；写 `mark_scratch` 事件日志。
