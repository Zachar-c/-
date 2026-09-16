# 模块接口：战斗结算（v1_battle_resolver + battle_command_facade）

> 契约层级：领域层。本页是 Agent 接入战斗的唯一入口约定，禁止绕过 facade 直接操作 battle 字典。
> 仓库路径：`scripts/domain/v1_battle_resolver.gd`、`scripts/domain/battle_command_facade.gd`

## 职责

推进蛊行动制战斗的状态机：`player_action`（出蛊/拳脚/杀招/结束回合/撤退）→ 结算 → `victory|defeat|player_action`，不持有任何表现层引用。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `Facade.start(encounter, state, catalog)` | encounter: `{enemy_kind}` / `{enemy_kinds}` / **`{enemy_roll}`**；state: RunState | `{battle, enemies, result}` | 构建战斗字典；Boss 战写 `flags.boss_battle=true`。**敌人来源优先级：`enemy_roll` > `enemy_kinds` > `enemy_kind`**（E6，2026-09-10）：地图生成期已按层抽好时用 `enemy_roll`；锚点/关底台/旧存档无该键时回退。单敌遭遇（`enemy_roll` 长度 1）同时落顶层 `battle.enemy_kind`（死亡报告与敌方台词按该键取专属文案） |
| `Facade.apply_turn(battle, state, command, catalog)` | command: `{type, instance_id, target_id, ...}` | `{battle, state, result, accepted, feeds, finished}` | **唯一合法行动入口**；`finished=true` 即战斗结束（victory/defeat/retreat） |
| `Facade.apply_enemy_pre_turn(battle, state, catalog)` | battle | `{battle}` | 回合前敌方结算（未接入主流程则保持空实现） |
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
- 旗标：`flags = {}`（Dictionary，非 Array；Boss 战含 `boss_battle`）

## 信号

无（纯函数式 domain 模块；表现层经 `run_controller` 轮询 `finished/result`）。

## 依赖

- `content_catalog.gd`（load_all 提供蛊定义/敌人/数值）；`run_state.gd`（RunState 投影）
- `data/balance.json`（撤退/转阶成本）；`data/enemies.json`（敌人基础值）
- `action_points.gd`（每回合行动数）；`cultivator_rules.gd`（转阶门禁）；`seeded_roll.gd`

## 强制规则（Agent 生成代码必读）

1. 战斗任何状态变更必须经 `Facade.apply_turn`；表现层不得改写 battle 字典键。
2. 新增行动类型必须三处同步：`Facade.apply_turn` 的 command 路由、`V1.player_action` 的 action 路由、`docs/contracts/2026-09-02-domain-ui-contract.md` 命令面。
3. 战斗结束（victory/defeat/retreat）后任何 action 必须返回 `battle_over` 拒绝（`player_action` 入口已强制）。
4. 效果数值只经 `v1_effect`/`effect` 字典表达，禁止在 resolver 内硬编码成本/伤害。
5. **残锋只减不增**：唯一允许写 `dao_marks` / `sword_downgrades` 的模块是 `SwordMarkRules`（经 `Facade.settle_sword_marks`）；任何回复路径违规。
6. 回合末 `_settle_marks`（T15 刻痕）只读 `statuses.marked`，独立伤害通道不吃护盾；写 `mark_scratch` 事件日志。
