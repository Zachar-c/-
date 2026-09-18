# 领域-表现层接口契约（spec-v4 第一阶段提取稿）

> 日期：2026-09-02
> 用途：第九批"接口契约 → UI 规范 → 前端生成"流程的第一步产出。本档从**已完成的后端代码**提取真实暴露面，是后续 UI 规范与前端生成的唯一依据来源；前端不得使用本档之外的状态字段或命令。
> 提取范围：`master @ 480183a`（阶段一至八合入）。阶段八的 `BloodQiRules` / `SoulRules` 已于本版补齐。
> 提取纪律：本档只描述后端**已有**的接口；`[T9 计划]`/`[T10 计划]` 占位已在阶段九/十全部落地为实际键/命令/映射（2026-09-02 终审清零），前端生成以本档现行为准。

---

## 1. 分层与数据流

```text
UI (scenes + scripts/ui)
  -> RunController.submit_command(type, fields)        [scripts/presentation/run_controller.gd]
     -> 命令面三层：
        A. Resolver 全局/节点命令       [scripts/domain/resolver.gd _dispatch，~45 种 type]
        B. 战斗命令（V1 facade）        [scripts/domain/battle_command_facade.gd]
        C. 命令规格预检（freshness）    [scripts/domain/command_spec_registry.gd]
     -> RunState.append_event            [不可变事件日志；返回新 RunState]
  -> RunSnapshotBuilder.for_screen(screen, controller)   [UI 只读快照，逐屏构建]
  -> 规则模块（纯静态、确定性，供命令面与快照调用）
```

铁律（UI 生成时必须遵守）：

1. UI 只读快照、只提交命令；**禁止**直接改 `RunState`/`current_battle` 等领域状态。
2. 所有预检与执行同源（§17.3）；拒绝原因走 `_REJECTION_TEXT` 中文映射（见 §5）。
3. 事件日志条目 append 后不可改写；`_` 前缀键是旁路信息，不落状态、存档跳过。
4. 版本戳：命令必须携带 `state_version`（= `event_log.size()`）或 `hand_version`，过期一律拒绝（见 §5.1）。

---

## 2. 快照契约（`RunSnapshotBuilder.for_screen`）

按屏分发，返回只读 Dictionary。既有 10 屏：

| screen | 构建函数 | 关键键（现状） |
| --- | --- | --- |
| `Title` | `hall()` | 大厅进度/图鉴/开始入口、`selected_school`/`selected_school_name`（选中流派中文名，`_school_display_name`） |

大厅主界面快照（v8 线框稿还原，2026-09-07）：`run_summary` 携带 `route`（当前节点名，`_run_route_label`）、`rank`（中文转数，如「四转」）、`hp`（气血数值）、`lifespan`（`cultivator.lifespan - lifespan_debt`，如「41年」）、`gu_count`（`gu_ids.size()` 持有数，**不显示伪造分母**——项目红线：持有数量无通用硬上限）、`node_count`（`route_progress.size()`）、`curse_count`（`cultivator.statuses` 中 `layers>0` 条目数，语义近似参考图「N只诅咒蛊」）、`build_label`（固定「BUILD 0.9.0 · LOCAL」）。另含 `hall_epoch`（「今世·第N劫」，N=node_count+1 中文数字）、`prev_life`（「上一世止于：<route>」，读档场景即当前世上次退出节点；无存档为「—」）、`prev_note`（「札记新得：<最新手记标题>」，取自 `journal` 末条，无则为「—」）。UI 只消费以上只读键，不得反写领域。
| `Map` | `map()` | `nodes[]`（`id/type/label/layer/row/next_ids/reachable/visited/current/visibility`）、可达集、当前层、`inventory`、**`build_goal`（Playable Core Loop Phase 2，2026-09-15：当前构筑目标只读投影；键见下）**、每节点 **`build_relevance`**（`{code, text}`，`code ∈ advance/execute/trade/none/unknown`；只表达「可能推进 / 可执行 / 无直接关系」，不承诺掉落、未揭示节点一律 `unknown`）、每节点 **`threat`（D7 精英节点显性化，2026-09-16：`""` \| `"elite"`）** |
| `Encounter` | `encounter()` | 遭遇会话、`node_actions[]`（含 `cost/executable/block_reason/remedy_hints`） |
| `Battle` | `battle()` | `enemies[]`（`id/name/hp/max_hp/shield/statuses[]/intent/alive/counter_revealed`）、`player`、`hand`（卡含 `school_label` 中文流派名）、`piles`、`actions`、`default_target_id`、`kill_moves`、`flee_available`、`synthesis`、`dda_boss_hint`、`first_battle`、`inventory`、`hand_version`、`sword_intent`（Q7 阶段 A 2026-09-12：剑意层数 int，跨回合存续、回合末减半，`≥0`，无剑意时 `0`）、`intent.damage_intent`（Q8 Step 4 2026-09-12：敌意图语义属性 bool，H3 门禁依据，非伤害意图为 `false`）、`intent_weaken`（Q8 Step 4：每敌 int，下一次 damage intent 减免额，消费或回合结束清零，`≥0`）、`statuses.sealed`（Q8 Step 4：敌方封门禁标记，下一次 damage intent 被门禁后消费清除）、`delayed_effects`（Q8 Step 5 2026-09-12：延迟效果表 Array，元素含 `effect`/`school`/`due_turn`/`source_id`，battle 生命周期内到期自动结算，战斗结束销毁，随存档序列化） |
| `Shop` | `shop()` | **`offers[]` = 本次货架（E7，2026-09-10）**：只列 `Resolver.shop_stock(state, catalog)` 内的货（`4 + ⌊层/2⌋` 件 → 层 1/2/3/4/5 = 4/5/5/6/6，每架保底 1 件本层最高档），以及**常驻服务**（`resource_trade` 黑市兑换 / `wash_notoriety` / `recipe_unlock` / `soul_boost`）；每项含 `id/name/kind/price/desc/quality/curse_warning/will_emergency_pay`。货架由 `(局种子, 节点模板 id)` 确定性派生，**同店反复进出不变、不新增存档字段**。命令面同源：`shop_purchase` 对不在货架上的**货**返回 `shop_offer_not_in_stock`（`npc_trade` 走 NPC 自己的 `npc.stock`，不受此限）；既有 `shop_tier_locked` / `insufficient_stone` 语义不变，判定顺序为 阶 → 架 → 钱。 |
| `Rest` | `rest()` | `choices[]`（`heal/upgrade_card/remove_card/remove_imprint/remove_curse/skip` 域全集，外加节点允许的 `wash`）、`upgrade_targets` / `remove_card_targets` / `imprint_targets` / `curse_targets`、每个 `choice.disabled/reason/curse_warning/requires_confirm`、`mode_groups`（E4b 三选一，2026-09-09：`修炼[]`/`炼蛊[]` 两组动作卡，卡含 `id/label/detail/cost/disabled/reason`；`meditate` 走 encounter `action_card` 信封、`cultivate` 映射 `cultivate_rank_two`、`refine/free_pair` 为会话内子屏导航不发领域命令；快照无此键时 UI 整行隐藏，旧存档兼容。E4a 起 `rest/refinement/cultivation` 三类节点统一由 travel 分发进本屏） |
| `Refine` | `refine()` | 炼蛊台状态、投入位、候选、`from_rest`（E4a 子屏语境：经休息屏「炼蛊」卡进入时为 true，「离开」按钮文案变「返回休整」且不发 `leave_encounter`，仅退回休息屏）、`initial_channel`（子屏预选通道 id，如 `free_pair`；用户手动切 Tab 后前端本地态优先，不再覆盖）、**`build_goal` 与 `goal_recipe_id`（Phase 4，2026-09-15）**；`recipes[]` 每条新增 **`recipe_kind` / `is_goal` / `executable` / `materials[{id,name,owned,required,complete}]` / `missing[]` / `missing_summary` / `stone_owned` / `stone_required` / `input_gu_id` / `input_gu_name` / `input_owned`** —— 成本与缺失项**点击前即可见**；配方按「目标配方 → 同流派 promotion 链 → 其他可执行 → 不可执行」稳定排序；**`attune_candidates[]`（Stage 1 缺口 2，2026-09-17）**：蛊仓 `state=wild` 的野生蛊候选，每条含 `id/name/rank/essence_cost/essence_owned/executable/block_reason/note`，代价与「炼化后改由真元喂养」点击前可见；通道列表新增 `attune`（标签「炼化野生蛊」），与合炼通道分离 |
| `Reward` | `reward()` | 普通路线战后奖励列表、**`build_progress`（Phase 3，2026-09-15：本场产出 → 当前构筑目标的连接；键见下）**；M0 模式另带 `m0_mode`、`choice_rewards[]`、`choice_selected`，三选一选择前不得离开 |
| `Npc` | `npc()` | NPC 交涉/交易 |
| `ContentError` | `content_error()` | 目录校验错误（`ContentCatalog.validate` 非空时的兜底屏） |
| 调试 | `debug()` | 保底计数/池排除/种子/事件数/DDA 分位（只读，§16.22） |

流派中文名透出（C2 2026-09-05 起，UI 不裸显英文 school id；统一 `_school_display_name(catalog, school_id)`，源 `schools.json` v2）：大厅选中流派 `selected_school_name`；图鉴/书库蛊条目与休整升级候选等携带 `school`（英文 id）+ `school_name`（中文）；battle 手牌卡携带 `school_label`（中文，供卡面 tooltip 拼接）。

**Playable Core Loop 只读投影（2026-09-15，任务 `Q8-Playable-Core-Loop-Vertical-Slice`）**：
把「玩家当前想做什么 / 还缺什么 / 去哪里推进」做成三屏共用的只读投影，**不新增成长线、不改命令面、不写 RunState**。
生成入口：`scripts/presentation/snapshots/build_goal_projection.gd`（纯函数，确定性、可测试）。

- **`build_goal`**（Map / Refine 携带）：
  `available` / `school` / `title` / `recipe_id` / `recipe_kind` / `recipe_name` /
  `input_gu_id` / `input_gu_name` / `input_instance_id` / `input_gu_ready` /
  `output_gu_id` / `output_name` /
  `materials[{id,name,owned,required,complete}]` / `stone_owned` / `stone_required` /
  `missing_materials[]` / `missing_stone` / `ready` / `missing_summary` /
  `recommended_node_types[]` / `progress_text` / `chain_index` / `chain_length`。
  **目标选择规则（固定优先级、纯函数）**：① 本流派 promotion 链中第一条「尚未完成」（产出蛊未持有）的配方，
  按 `input_min_rank` 升序、`id` 升序；② 链已走完时回退到「已解锁、输入蛊在手的关键炼蛊配方」（fixed/advance）；
  ③ 都没有时 `available=false`，`title="暂无可执行构筑目标"`。
  **信息纪律**：不含任何内部保底计数（`loot_pity` / `material_pity_by_tier`）；不承诺掉落；
  未揭示节点不得反推内容（`build_relevance.code == "unknown"`）。
- **`build_progress`**（Reward 携带，仅在本场有**已入账** loot 时 `available=true`）：
  `available` / `title` / `recipe_id` / `lines[{id,name,gained,owned_before,owned_after,required,complete}]` /
  `stone_gained` / `stone_before` / `stone_after` / `stone_required` /
  `ready_before` / `ready_after` / `became_ready` / `next_step_text`。
  `before` 值由「当前库存 − 本场入账」反推（`loot.material_ids` 计数、`loot.stone_reward`），
  **不重抽、不改领域状态**；输入蛊若正是本场掉落的蛊，则 `before` 记为未持有。

开局 Buff 透出（S2 2026-09-06 起）：大厅快照 `available_buffs`（`id`/`name`/`summary`，源 `data/buffs.json`，目录校验 effect 种类与产物引用）与 `selected_buffs`（已选 id 数组）；命令 `toggle_buff(id)` 切换多选（未知 id 忽略）；`new_run` 增第四参 `buff_ids`，run 创建时一次性结算——`grant_stones` 加元石、`grant_gu` 注入蛊实例入洞天（均落 `run_buffs_applied` 事件）、`enemy_hp_one_except_boss` 由 `BattleCommandFacade.start` 消费（非 Boss 敌 hp/max_hp=1）。

局内公共快照同时携带以下只读键：

- `inventory{materials[],gu_instances[],loot[],intel[]}`：材料仅含 `id/name/quantity`；蛊虫实例含 `id/definition_id/name/state/rank/quality`；收获与情报仅投影已结算结果和 `known_facts`。UI 不得据此反写库存或推断未知信息。
- `hand_version`（仅 Battle 屏）：`= event_log.size()`，与 `use_gu` 命令 `state_version` 同源。`battle_screen_view.mount_snapshot` 仅在 `hand_version` 变化时清空已提交卡/目标去重缓存；相同版本重挂载（刷新/重渲染）不得解除防重复提交保护。
- **战斗手牌卡（第三阶段 Task 3，2026-09-17）**：Battle 屏 `hand[]` / `kill_moves[]` 每张卡携带十键契约 `{id, type, executable, block_reason, costs, target_type, valid_target_ids, command, state_version, expected_phase}`，全部取自 `ActionPreviewService.preview_battle_actions`（唯一门禁来源，`battle_snapshot` 只透传）。UI 新路径**只提交 `command`**（经 `RunCommandBuilder.for_screen("Battle").submit_command`），并按本屏交互态补 `target_id`；`play_card` 仅为按 ID 组装的兼容包装。杀招卡 `command.confirmed=false`，确认框通过后补 `true`（T16）。终局/撤离后预览不产出卡片，卡面一律置灰。
- **战斗核心独立审查（2026-09-17）**：`F-01`（撤离预览与执行门禁漂移）与 `F-02`（命令新鲜度闭环）的修复均已落地并有回归守卫，独立复验二次结论已于 2026-09-18 回收，两项判定 **CLOSED**（证据：可写 `user://` 下全量 unit **1581/1581** / integration **56/56**，见审查报告 §9）。已落地事实：撤离门禁唯一来源 `BattleCommandFacade.retreat_gate`（Boss → 地形/追击 → 元石），预览只转呈结论、执行复用同一纯门禁；Gu / 基础攻击 / 杀招 / 结束回合 / 撤离的命令全部带 `state_version` + `expected_phase`，`RunController.submit_command` 的 V1 战斗路径经 `CommandSpecRegistry` preflight。详见 `docs/superpowers/reports/2026-09-17-battle-core-audit.md`；`F-03`～`F-06` 仍为 P2 技术债。
- `death_lines{health,shouyuan,hunpo,backlash}`：用于危险预警、操作预检与死因信息；其中气血、寿元、魂魄任一 `remaining <= 0` 的终局判定仍完全由领域层执行。`death_lines` 不授权常驻独立数值面板。

`[T9.1 已落地]` 快照 v2 按 §17.2 八组扩容（增量键，逐键与规则模块同源，`RunSnapshotBuilder.transparency_v2(controller)`，返回八个分组键；`_` 前缀旁路键不进快照）。所有真实 `for_screen(screen, controller)` 快照经 `_with_v2` 保守合并带入八组（同屏键优先）：

1. `group1_gu_ledger`：`active / phase / thoughts_left / thought_used / reserved / gu_used{} / actions_used{move,strike,dodge,grapple} / maintained[] / ongoing[]`——**从权威 `RunState.battle2_ledger` 只读直投影**；无战斗（账本为空）时投影 `active:false` 的空惰态形状，**不伪造 fresh 满念头账本**；
2. `group2_core`：`confirmed_instance / depth(common_core|hub_core) / hub_evidence{branch_recipes,exclusive_refine} / tilt_suggestions{pool->boosted[]}`（`CoreGuRules` 直调用）；
3. `group3_recipes`：每条配方的 `id/kind/product_rule/aux_core_warning` + 可选 `identity_requirements / allow_substitute / stages / candidate_pool`（`RecipeRules.resolve_candidates` 直投影，声明序）；
4. `group4_feeding`：`preview{will_hunger,will_die} / budget_report{affordable_gu_count,sustainable_at_half,hard_rejection:false}`（`FeedingRules.preview_settle / budget_report`）；
5. `group5_market`：`t1_base / rank3_value / resale_50 / low_liquidity_30 / demand_quote / gu_public_1 / gu_recycle_1 / gu_estimate_1 / blood_trade_public_reason`（`MarketRules` 全价目 + `BloodQiRules.trade_gate` 拒收原因）；
6. `group6_body`：`safe_strength / actual_strength / outward_damage / overload_self_damage / lethal_confirm_required / death_cause`（`Battle2BodyRules.strike_preflight` 等，力量/承载来自 `CultivatorRules.body`）；
7. `group7_action`：`distances / conflict_order / reaction_check / disengage_open / strike_only_at_contact`（`Battle2ActionResolver` 直投影）；
8. `group8_soul`：`snapshot / composure / beast_sight / float_above_capacity / growth_forecast`（`SoulRules` 直投影）。

---

## 3. 命令契约

### 3.1 全局/节点命令（`resolver.gd _dispatch`，`{"type": ..., ...}`）

现役 type 全集（参数见 resolver 对应 `_xxx` 函数；均为 `state, command, catalog` 三元签名）：

`travel(node_id)`、`resolve_contact`、`complete_node`、`buy_gu`、`sell_gu`、`exchange_gu`、`refine_gu`、`attune_gu`（Stage 1 缺口 2，2026-09-17：野生蛊 → 已炼化；载荷 `input_instance_ids:[instance_id]`，只扣真元 `4+2*(rank-1)`，拒绝原因 `attune_target_missing` / `attune_target_not_wild` / `insufficient_essence`；首只炼化事件 reason=`first_gu_attuned`，与 `refine_gu` 合炼语义分离）、`cultivate_rank_two`、`breakthrough`、`settle_feeding`、`settle_node_feeding`、`disable_card`、`upgrade_card`、`copy_card`、`destroy_gu`、`remove_card`、`remove_imprint`、`spend_lifespan`、`accept_debt`、`use_gu`、`buy_opportunity`、`take_body_imprint`、`choose_action`、`retreat`、`attempt_ascension`、`close_run`、`gain_relic`、`shop_purchase`、`shop_lifespan_deal`、`shop_barter`、`npc_trade`、`scavenge`、`sell_material`、`use_material`、`raise_aptitude`、`record_neutral_npc_kill`、`wash_notoriety`、`record_boss_defeated`、`record_layer_boss_defeated`、`rest`（`mode ∈ {heal,upgrade_card,remove_card,remove_imprint,remove_curse,skip}`，覆盖 `_rest_skip` 在内的领域全集）、`gain_force_power`、`accept_event`、`gain_curse`、`remove_curse`、`swear_contracts`、`m0_reward_take`（仅 M0，控制器注入当前选项 `option` 后经 Resolver 结算）。

统一返回：`{"ok": bool, "reason": str?, "feedback"?: str, ...}`；`ok=false` 时 `reason` 必须能命中 §5 的中文映射。`load_run`/`save_run` 由 controller 层直接处理（v4 拒载契约见 §7）。

- **卖出中央计价（2026-09-04）**：`sell_gu` 价格 = `GuBalance.gu_value(definition, instance_rank, catalog) = max(定义 value 字面量, balance.gu_value_by_rank[实例转数])`；实例转数取同名全部 refined 实例的最高值（`GuInstance.max_refined_rank`）。`balance.gu_value_by_rank` 为 1..5 转全覆盖正整数表；`gen_*` 批量蛊的 `value` 字面量由 `ContentCatalog.validate` 强制等于表值（手写跨转字面量拒绝），手工蛊字面量保留为下限。

`[T9.2 已落地]` 新命令全集（分派于 `resolver.gd _dispatch` → 薄委托 `V2Commands`；`destroy_gu` 保持既有 resolver 实现，`settle_layer` 接通 `RunState.settle_layer` 大层唯一入口，同层幂等）：

`confirm_core`（→`CoreGuRules.confirm`，写回 core_state + `core_confirmed` 事件）、`replace_core`（→`replace_core`，硬上限 `replace_limit_reached`，`node_flags.core_replace_count` 计数，`core_replaced` 事件）、`feed_instance`（→`FeedingRules.layer_settle` 单例结算，`feed_instance` 事件，饿死经 `_feeding_<id>` 旁路键）、`settle_layer`（→`RunState.settle_layer`，`layer_feeding` 事件）、`collect_surviving`（→`LootRules.collect_surviving_gu`，幸存蛊入账 + `gu_collected` 事件）、`release_gu`（→`release_gu`，`gu_released` 事件带 `consequences`）、`sell_info`（→`MarketRules.sell_info`，`info_sold` 事件，买家重复付费 `buyer_already_paid`）、`enact`（→`Battle2TurnEngine.enact`；**T10.1-6：ledger 已迁入权威领域状态 `RunState.battle2_ledger`**——战斗开始 new_turn 创建、enact 推进、事件经 `_battle2_ledger` 旁路键追溯、快照只读投影，命令不再携带 ledger，`battle2_enact` 事件）、`dodge` / `grapple` / `respond`（→`Battle2BodyRules`+`ActionResolver.reaction_allowed`，`battle2_dodge/battle2_grapple/battle2_respond` 事件）、`refine_up_material`（→`MaterialRules.refine_up`，`material_refined` 事件）、`bloodlet`（→`BloodQiRules.self_bleed`，`bloodlet` 事件；致死返回 `lethal_confirm_required`+`cause:"self_bleed"` 且**不自动执行**）、`absorb_soul`（→`SoulRules.collect_soul`+`strengthen_soul`，`soul_absorbed` 事件；`no_means_declared`/`means_capacity_full`/`soulless_target`/`soul_yield_zero` 拒绝）。

### 3.2 战斗命令（V1 facade，现状）

controller 收 `use_gu / use_inheritance / end_turn / retreat / basic_attack / basic_dodge / refine / play_kill_move`（`run_controller.gd:200`），经 `BattleCommandFacade.apply_turn` 转为 V1 内部动作（`play_gu(slot_index)/basic_attack/end_turn/play_kill_move`）；敌方回合 `apply_enemy_pre_turn`。撤退门唯一来源 `BattleCommandFacade.retreat_gate`（Boss → 地形/追击 → 元石）：预览只转呈结论、执行复用同一纯门禁，禁止第二份判定（F-01，2026-09-17）。

- **收官抉择（2026-09-15 用户裁定，**语义变更**）**：`pacing.ending_after_stage` 从
  「打掉该层关底即**强制**收官」改为「自该层起，收官成为**玩家可选**」。击败该层
  （`node_flags["boss_defeated_L<n>"]`，由 `record_layer_boss_defeated` 落账、随存档持久化）
  后 `close_run` 持续可用：玩家可继续深入，也可随时主动收官。
  - 命令 `close_run`（无参）：判据单一来源 `SocialCommandRules.closure_available(state, catalog)`；
    不可用时拒绝 `closure_not_available`（中文「尚未平定收官层，暂时无法收官。」），**不落事件、不改终局态**。
    可用时落不可变事件 `action:"close_run"`（`reason:"player_closure_layer_<n>"`），
    `terminal_state → success`，控制器切入 Ending。
  - 快照键（仅 Map 屏）：`closure_available`（bool，与领域同判据）、`closure_hint`（String，
    层名取自 `pacing.layers[<index>].title`，如「「青茅山外圍」已平定——可继续深入，或就此收官了结本局。」）。
  - UI：`map_screen_view` 的 `map_close_run_button`（`scenes/ui/screens/map_screen.tscn`）
    仅在 `closure_available and commands.has("close_run")` 时可见，否则隐藏（不留可点装饰）。
  - **不改动**：`attempt_ascension`（冲仙）是另一条结局路径，本键不参与其判定。
- **一转一突破（2026-09-15 用户裁定：聚焦剑道、打造局内成长空间，**新增命令**）**：
  `aptitude.json.cultivation_factor = {1:1,2:3,3:9,4:27,5:81}` 与 `pacing.layers[N].enemy_rank_max = 1..5`
  早已把 1→5 曲线设计完，但领域只实现了硬编码二转（且 `>= 2` 直接拒绝）⇒ 转数永久封顶 2，
  门禁 `can_activate(cultivation >= gu_rank)` 让全库 52% 的蛊（rank ≥3）**永远无法催动**。
  - 命令 `breakthrough`（可选 `target_rank`，缺省 = 当前转数 + 1）：须在休息类节点；**逐档推进**
    （跳档 → `cultivation_step_too_far`）；上限 5 转（`cultivation_already_max`）；
    元石不足 → `insufficient_stone`；**一次探访只取一份收益**（`rest_visit_already_used`，
    领域侧自查 `RestRules.rest_visit_consumed`，不再只靠快照禁用卡片）。
  - 成本单一来源 `RefineCommandRules.cultivate_stone_cost(catalog, rank)`，读 `balance.json` 的
    `cultivate_rank_{two,three,four,five}_stone_cost`（5 / 12 / 20 / 30）。
  - 结算：`after.cultivation` = 目标档；`after.essence_capacity` 与 `cave_aperture.essence_max`
    均取 `max(现值, EssenceCapacity.essence_max_for(state, catalog, target))`（**不得回落**）；
    事件 `action:"breakthrough"`，`reason:"rank_<n>_breakthrough"`。
  - 快照：Rest 屏 `mode_groups.修炼` 的 `cultivate` 卡 `label` 为「冲击{N}转」，`cost` 为对应档位元石数；
    `ActionPreviewService` 的修炼卡 `id` 为 `cultivate.rank_<n>`，`command` 带 `target_rank`。
  - 境界中文名单一来源 `RefineCommandRules.cultivation_label(rank)`（领域层拥有；
    表现层不得反向依赖 `DisplayText`，其 `DisplayText.cultivation` 已移除）。
  - 兼容：旧命令 `cultivate_rank_two` 保留为薄包装（等价目标 2 转），旧存档与既有测试不受影响。
- `use_gu` 命令携带可选 `target_id`（`gu.<instance_id>` 点击的目标敌人 id）；经 facade 的 `play_gu(slot_index, target_id)` 贯穿到 `V1BattleResolver`（`_strike_enemy`/`_apply_enemy_status` 按目标解析，空/无效回退首个存活敌人）。多敌战斗中点选第 N 个敌人必须命中该敌人。
- `use_gu` 成功结算写入 `battle_v1` 事件；`info.effect` 含 `kind/amount/target`，并按类别补 `name`（status/buff）、`heal`（heal_and_strike）、`target_id`（**实际命中敌人 id**：resolver 结算后把命中者写回 battle 的 `last_effect_target`，facade 以它为准——空/无效请求回退首个存活敌人时日志记录真实命中者而非空/原始值）；`amount` 默认值与 resolver 结算一致（status/buff/shift 默认 1，其余 0）。
- **转数门禁（2026-09-03，spec §11.2）**：`can_play_gu` 前置校验 `CultivatorRules.can_activate(player.cultivation, slot.rank, slot.low_rank_exception)`；拒绝 reason `insufficient_qi_quality`（中文「真元质量不足，无法催动此转数的蛊虫」，走 `_v1_reject_text`）。`gu_slots[]` 新增 `rank`（实例与定义转数取较高者，同名升阶计入）与 `low_rank_exception`（gu 定义可声明 `low_rank_exception: true` 例外，对应 §11.2 珍稀蛊低转催动条款）；`player` 新增 `cultivation`（数值转数）。拒绝零消耗。杀招（`play_kill_move`）暂不做同款校验，与既有行为一致。
- **T16 残锋降转（2026-09-15，规格 `docs/superpowers/specs/2026-09-12-sword-p2-t15-t16-spec.md` §2，D16-4 已修正为 b）**：
  - 快照键扩容（仅 Battle 屏）：`gu_slots[]` 新增 `rank_held`（持有转数，含同名升阶）、`sword_downgrades`（质变次数）、`dao_marks`（距下次质变的剩余逆炼次数，旧存档缺键按 `v1_battle.sword_dao_marks_init` 读取）、`dao_marks_per_downgrade`（质变阈值）、`sword_mark_cost`（该蛊是否吃残锋）。**语义变更**：`gu_slots[].rank` 现在是**等效转数**（`max(1, rank_held - sword_downgrades)`）；未降转实例 `rank == rank_held`，与改动前逐值一致。
  - `kill_moves[]` 新增 `dangerous`（bool）与 `known_risk`（Array[String]）：本次释放若耗尽道痕触发质变则为真，文案含「永久降 1 转（不可逆，无法回复）」。`cost` 字符串在配方含残锋蛊时追加 `残锋 N`。**UI 义务**：`dangerous` 为真时必须在提交前弹确认（`battle_screen_view._release_kill_move` → `_pending_kill_move` → `GuConfirmDialog`）。
  - 命令：`play_kill_move` 携带可选 `confirmed`（bool，缺省 `false`）。未确认且本次会触发质变 → 领域侧拒绝 `sword_mark_confirm_required`，**不扣余量、不执行**（红线「禁止静默惩罚」）。判据唯一来源 `SwordMarkRules.pending_downgrade`，快照与引擎共用。
  - 事件：逆炼落 `action: "sword_erosion"`（`source: "sword_mark_rules"`，`info.spent[]` / `info.downgraded[]`，`after.gu_instances`）；结算挂在 `BattleCommandFacade.settle_sword_marks`（resolver 只见 battle，跨战斗的永久消耗必须落在 `RunState.gu_instances`）。
- **转数与效果展示（2026-09-04）**：`hand[]` 蛊卡 `summary` 带转数前缀（`N转·<效果文本>（<状态注记>）`；`basic_attack` 拳脚卡除外）。图鉴（`hall()` → `codex.gu[]`）条目新增 `rank`（整数转数，UI 渲「转数：N转」）与 `effect`（效果中文文本：显式 `v1_effect` 优先，缺省走 `V1BattleResolver.default_v1_effect` role 兜底，与战斗口径一致）。
- **战斗命令新鲜度（2026-09-17 接线，F-02）**：`use_gu / basic_attack / end_turn / play_kill_move / retreat` 与 `action_card` 信封一律必须携带 `state_version`（= `state.event_log.size()`）与 `expected_phase`（= `battle.phase`，V1 缺省 `"player_action"`）。`RunBattleFlow.submit_battle_command` 在进入 `BattleCommandFacade.apply_turn` **之前**过 `CommandSpecRegistry.preflight`（`type=="action_card"` 或 `action_id` 以 `battle.` 开头 → `battle.action_card`；其余 `is_battle_command` → `battle.turn`；非战斗命令直接放行）；**门面自身不判新鲜度**。缺字段 → `command_context_missing`；过期 → `battle_action_stale` / `battle_hand_stale` / `battle_phase_stale`。卡片顶层与嵌套 `command` 两处同源补齐（`ActionPreviewService` 与 `RunCommandBuilder`）；UI 只转呈，不得重算领域规则。
- **拒绝的可见性与零副作用（2026-09-17，F-01/F-02 复验）**：预检拒绝与领域拒绝（facade `_rejected`）都必须在 `_show_battle()` **之前**写入 `RunController.last_feedback`（中文文案取 `rejection_text.gd`），随 Battle 快照的 `feedback` 键送达 `battle_screen_view._refresh_feedback` → `_feedback_toast`。拒绝信封同形：`accepted=false` / `ok=false` / `reason` / `feeds=[reason]` / `finished=false`；拒绝**不接管** `state` 与 `current_battle`（原对象原样返回），不落事件、不写 `battle_finished`。
  **UI 义务**：收到 `accepted=false`（或 `ok=false`）时不得播放 `battle_card_play` / `concept_ink_spread` 音效与墨迹动效、不得进入 `play_success` 态，并须释放该卡的去重键（拒绝文案要求「重试」，键不释放就永远重试不了）。
- **旧 `play_card` 兼容包装的 id 形状**：`battle_screen_view` 在卡片无 `command` 键时回退 `play_card(action_id, target_id, confirmed)`，由 `RunCommandBuilder._battle_card_command` 组装同一份带上下文的命令。可识别的现行卡 id 为 `gu.<instance_id>` / `basic_attack` / `kill_move.<id>` / `battle.end_turn` / `battle.retreat`（**不含 battle_id 段**，见 `ActionPreviewService.preview_battle_actions`）；执行侧 `BattleCommandFacade._action_card_passthrough` 必须**同时**识别该形状与含 `battle_id` 段的旧信封。

预检规格（`CommandSpecRegistry`，**V1 战斗路径已于 2026-09-17 接线**，见上）：

| spec_id | freshness_kind | 必填字段 |
| --- | --- | --- |
| `encounter.action_card` | `event_log` | `action_id, state_version, node_id, session_node_id` |
| `battle.action_card` | `battle_hand` | `action_id, state_version, expected_phase`（`target_id` 按卡片 `target_type=single_enemy` 校验） |
| `battle.turn` | `event_log` | `type, state_version, expected_phase` |
| `battle.enemy_pre_turn` | `internal` | — |

`[T9.2 已落地]` battle2 编排命令已接入 `enact`/`dodge`/`grapple`/`respond`（proposal 形状 `{"kind": "activate_gu"|"basic_action"|"maintain", ...}`）；拒绝 reason 集合达产：`maintenance_blocks_activation / gu_already_used_this_turn / insufficient_thought / action_already_used_this_turn / unknown_action / unknown_proposal_kind / parallel_group_repeats_action / parallel_group_repeats_instance / no_thought / window_closed / dodge_not_allowed / grappled_blocks_dodge / bound_blocks_dodge / terrain_restricted / not_at_contact / not_stronger / no_reserved_thought / not_a_legal_reaction`；跨回合续投：`start_turn(turn, capacity, continue_ids)`（ongoing 条目携带稳定 `"id"`）。

### 3.3 M0 控制器命令（表现层入口，领域结算仍走 `Resolver.apply`）

- `new_m0_run`：仅由 `Title` 大厅的「M0 · 四战试炼」按钮提交，调用 `RunController.start_m0_run(seed)`；完整运行的 `new_run` 同时保留。
- `m0_reward_take`：仅由 M0 `Reward` 屏的三选一按钮提交，载荷为 `{"type":"m0_reward_take","reward_id":"..."}`。控制器先校验当前 Reward 会话的选项池与一次性门禁，再把选项交给 `Resolver.apply` 的同名领域 handler；领域层写入 `m0_reward_chosen` 事件并返回新状态。
- M0 `Reward` 快照：`m0_mode: bool`、`choice_rewards[]`（`id/kind/title/description`，蛊选项另含 `gu_id`，资源选项另含 `amount`）、`choice_selected: bool`。普通路线仍只消费自动入账 `rewards`。

### 3.4 对话分支命令（Dialogue Gateway，`run_controller` 入口）

- `dialogue_branch`：`{"type":"dialogue_branch","branch_id":"...","state_version":<event_log.size>,"context":{...}}` → `_submit_dialogue_branch` → `DialogueManagerAdapter.apply_branch`（`command_for_branch` 把 `accept/accept_event/take/investigate → accept_event`、`leave/decline/reject → leave_node`，未知返回空并中文拒绝 `unknown_dialogue_branch`；`state_version` 过期拒绝 `action_preview_stale`；`used_action_ids` 去重拒绝 `dialogue_branch_used`）。event 节点的 `action_card` 由 controller 包装为 `dialogue_branch`（branch_id=`action_id`）走同一路径。
- branch_id 两种形状（`command_for_branch` 均可解析）：点分 `event.echo_cave.accept` / `echo_cave.accept`（模板/测试）；下划线 `echo_cave_accept` / `gu_rot_pact_leave`（Dialogue Manager 插件 title 禁止 `.`，`rfind("_")` 拆 event_id 与分支，`gu_rot_pact_accept` → event_id=`gu_rot_pact`）。
- `submit_dialogue_selection(title)`：Dialogue Manager balloon 选择桥接公开入口（P1-1）。插件/UI 在标题变化（非入口 title，如 `echo_cave.accept`）时调用，等价于提交 `{"type":"dialogue_branch","branch_id":title,"state_version":event_log.size()}`；空 title 拒绝 `empty_dialogue_selection`。
- 运行时接线（P1-B）：`_travel_to` 对 event 节点调 `begin(...)` 后，`DialogueManagerAdapter.set_branch_selection_callback(Callable(self,"submit_dialogue_selection"))`；adapter `begin` 连接 DialogueManager 全局单例的 `passed_title` 信号 → 玩家点 balloon 选项（title 跳转）即回调 `submit_dialogue_selection(title)` 走领域结算。回调为绑定 Callable，controller 释放后自动失效。
- 事件入口 title 路由（P1-2）：`_travel_to` 对 event 节点调 `begin(event_id, node.dialogue_title or "start")`；节点未声明 `dialogue_title` 时打开默认 `start`（echo_cave），声明专属 title（如 `gu_rot_pact`）的事件打开对应入口，不再全部从 start 打开。数据侧：`nodes.json` 的 event 节点可声明 `event_id`（缺省回退 `id`）与 `dialogue_title`（缺省 `start`）；`data/dialogues/events.dialogue` 的 title 与入口一一对应，选项 `=> title` 跳转的 title 即 branch_id 下划线形式。

### 3.5 规则模块公开函数（供命令面/快照薄委托；UI 不得绕过命令直调）

- **GuBalance**：`rank_multiplier(rank,cat) / standard_gu_power / beast_scale / fixed_defense / human_standard_heal / actual_cost_percent(native,gu_rank,cultivator_rank,cat) / natural_recovery(aptitude_percent,cat) / unarmed_raw_damage / overload_self_damage`。
- **CultivatorRules**：`can_activate(cultivator_rank,gu_rank,low_rank_exception) / thought_capacity(_cultivator,catalog) / body(_cultivator,cat)`（折算与恢复是 GuBalance 薄委托）。
- **GuInstance**：`new_instance / normalize / refine_state / validate_instance / to_save_data / from_save_data`；实例字典键白名单 `SAVE_KEYS`（§6）。
- **MaterialRules**：`downscale_equivalent / downscale_feed / named_diet_allowed / refine_up`。
- **RecipeRules**：`known_fixed_success(recipe,inputs_ready,unlocked,interrupted) / resolve_candidates / check_identity(...,offered_media)`（拒绝 reason：`recipe_locked / inputs_incomplete / interrupted / named_gu_not_offered / dao_tag_not_offered / named_material_missing / min_rank_not_met / media 系列同构`）。
- **FeedingRules**：`feed_cost / mixed_replacement / resolve_need / can_activate(instance) / layer_settle / preview_settle / budget_report`（`RunState.settle_layer(state,new_layer,pantry,catalog,options)` 是大层切换唯一入口，同层幂等）。
- **LootRules**：`is_persistent_loot_kind / budget_profile(enemy_composition,scene,cat)`（生成专用，签名上就拿不到幸存物）/ `collect_surviving_gu / release_gu / destroy_gu`。
- **MarketRules**：`t1_material_base_price / rank_standard_price / public_resale / low_liquidity_resale / demand_quote / advance_demand / gu_public_price / gu_recycle_price / gu_estimate / exchange_screen / info_value / sell_info`。
- **CoreGuRules**：`can_confirm / confirm / core_depth / hub_evidence / tilt_pool / grant_replacement_token / can_replace / replace_core`（硬上限 `REPLACE_HARD_LIMIT=1`；拒绝 reason：`core_already_confirmed / too_early_first_layer / instance_missing / replace_limit_reached / guarantee_replaced_with_peer_reward / no_token_on_node`）。
- **Battle2**：`TurnEngine`（§3.2 所列）、`ActionResolver`（`move_one_band / strike_possible / strike_resolution / disengage_window / reaction_allowed / conflict_speed / conflict_order / resolve_damage / beast_stats`）、`BodyRules`（`dodge_resolution / grapple_preflight / grapple_contest / hold_state / strike_preflight -> lethal_confirm_required`）、`CombatConstants`（`BASIC_ACTIONS / DISTANCES / DISENGAGE_REACTIONS`）。
- **BloodQiRules**（血气道）：`claim_inventory(materials,id,amount,path)`（血/气两道争用同一 `RunState.materials` 库存的唯一扣取口；拒绝 `insufficient_inventory`）、`blood_yield(target_health,target_rank,death_multiplier,means,cat)`（`means="deep"` 附加 `time_cost/tool_required/blood_trail`）、`self_bleed(cultivator_health,cultivator_rank,target_rank,amount,cat)`（拒绝 `bleed_rank_exceeds_cultivator / insufficient_health`；致死返回 `lethal_confirm_required` + `cause:"self_bleed"`）、`consume_blood_qi(materials,id,amount,use_effect)`（旧 use_material "+N 气血"语义的纯函数接管版，携带 `effect_events`）、`trade_gate(material,channel,cat)`（公开渠道拒绝 `refused_public_channel`；秘密渠道返回 `requires:"secret_market_gate"` + 后果声明 `attack_risk/pursuit_risk/faction_hostility`）、`accumulate_qi(inputs,effect_curve)`（无声明曲线拒绝——禁止万能伤害换算）。
- **SoulRules**（魂道）：`snapshot(cultivator)`（五量只读投影：`soul_magnitude / soul_safe_capacity / soul_calm(0-100) / soul_nature / beast_nature`，与遗留 `soul/soul_max/soul_control_limit` 零耦合）、`set_nature / validate_nature`（魂性单一，赋值即替换）、三操作 `strengthen_soul / refine_soul / calm_soul`（成本/效率由调用方手段声明）、`collect_soul(target,means,cultivator)`（拒绝 `soulless_target / no_means_declared / means_capacity_full`——无手段或容量满**永不产生库存**；产量 = `soul_weight × efficiency × (1-loss)`）、`float_above_capacity`（虚浮标记）、`soul_growth_forecast(cultivator,growth)`（膨胀致死 → `lethal_confirm_required` + `cause:"soul_burst"`）、`composure_layers`（安分分层：emotional/beast_emerging/soul_departure_risk）、`beast_sight`（兽念阈值 + keep/use/purify 三选项声明）、`bestiality_endpoint_check`（兽化只返回触发标记 + 确认要求，任何阈值不静默终局）。

---

## 4. 事件日志契约（§17.3）

条目形状（`RunState._normalized_event`，append 后浅共享不可改写）：

```json
{
  "id": "event_%04d",       // 稳定递增
  "stage": "...",           // 所属阶段
  "time": <int>,            // 逻辑时钟 = 事件序号，非墙钟
  "node_id": "...",
  "action": "...",          // 动作词（下方词表）
  "before": {...},          // 字段级前像（STATE_FIELDS 子集）
  "after": {...},           // 字段级后像；"_x" 前缀键=旁路信息，不落状态
  "reason": "...",
  "source": "...",
  "targets": [...]
}
```

已知 action 词表（前端可据此做事件流渲染/结局归因）：`run_ended`、`layer_feeding`（含 `_feeding_<instance_id>` 旁路键，`gu_starved` 死因带 `_snapshot`）、`battle_finished`、`state_change`、`core_confirmed`、`core_replaced`、`swear_contracts` 等 resolver 各命令的动作词，以及 T9.2 新增：`feed_instance / gu_collected / gu_released / gu_destroyed / info_sold / battle2_enact / battle2_dodge / battle2_grapple / battle2_respond / material_refined / bloodlet / soul_absorbed`、M0 新增 `m0_battle_completed / m0_boss_defeated / m0_reward_chosen`、V1 战斗 `battle_v1`、对话分支元事件 `dialogue_branch`（`after{branch_id,event_id,outcome}`，`source=dialogue_manager_adapter`，由 `DialogueManagerAdapter.apply_branch` 成功路径写入，供结局归因/回放；`stage`/`time` 不硬编码——省略键由 `RunState._normalized_event` 规范化到当前阶段与事件序号，后期分支不会被误归入 stage `"one"`/time 0）。§17.3 全清单（催蛊/炼蛊/核心确认更换/喂养/交易/收取/释放/采血/收魂/魂魄变化/战斗结算）已逐项落账。

## 5. 预检与拒绝契约

### 5.1 过期判据

- `event_log` freshness：`state_version == event_log.size()`；
- `battle_hand` freshness：`state_version == battle.hand_version` 且 `expected_phase == battle.phase`；
- 拒绝 reason：`action_preview_stale / encounter_context_stale / battle_hand_stale / battle_phase_stale / battle_action_stale / battle_target_invalid / action_not_executable / battle_action_unavailable / unknown_action_card`（附 `remedy_hints` 中文提示）。

> 2026-09-17 接线后（F-02）：`RunController.submit_command` 的 V1 战斗路径先过本表的预检，再由 `RunBattleFlow.submit_battle_command` 交给 `BattleCommandFacade.apply_turn`。本表是**已执行的运行时门禁**，不再是目标语义。
> 拒绝必须可见（`last_feedback` + 快照 `feedback` 键）且零副作用。独立复验提出的缺口已全部修复并有回归守卫：验收驱动命令缺上下文、旧 `play_card` id 形状未路由、**命令面单行 lambda 吞掉拒绝信封**（`RunCommandBuilder` 的 `submit_command` / `play_card` 必须显式 `return`，否则战斗屏把拒绝当「未转呈」而放行成功动效）、**两代卡 id 形状统一**（唯一映射点 `BattleCommandFacade.canonical_action_card_id`：`battle.<battle_id>.<card>` 与现行 `battle.<card>` 都经 controller preflight）。`F-01` / `F-02` 已于 2026-09-18 判定 `CLOSED`（独立复验二次结论已回收；可写 `user://` 下 unit 1581/1581、integration 56/56）。

### 5.2 通用拒绝中文映射（`run_controller._REJECTION_TEXT`，39 条现役）

`insufficient_stone / insufficient_lifespan / insufficient_soul / insufficient_material / unknown_shop_offer / npc_stock_missing / npc_not_present / unknown_npc / npc_missing / contract_locked / contract_sworn / contract_soft_cap / deck_capacity(待废) / gu_slot_full(待废) / refine_input_missing / refine_slot_invalid / refine_recipe_locked / retreat_forbidden / invalid_action / invalid_action_card / stale_state_version / not_enough_essence / no_actions_left / dodge_exhausted / not_enough_hp / lifespan_trade_warning / already_completed / invalid_node_completion / unknown_contact / invalid_contact_approach / unknown_command / unknown_gu / unknown_card / unknown_node / node_not_reachable / unknown_material / material_not_usable / no_material_to_use / material_use_lethal / m0_reward_choice_required / m0_reward_not_available / m0_reward_already_chosen / m0_reward_unknown / m0_reward_unknown_gu / m0_reward_rejected`。

`[T9.2 已落地]` 每条新命令的拒绝路径已入该映射（现役 71 条，含 `too_early_first_layer / core_already_confirmed / instance_missing / replace_limit_reached / guarantee_replaced_with_peer_reward / no_token_on_node / buyer_already_paid / insufficient_thought / gu_already_used_this_turn / maintenance_blocks_activation / action_already_used_this_turn / unknown_action / unknown_proposal_kind / parallel_group_repeats_action / parallel_group_repeats_instance / no_thought / window_closed / dodge_not_allowed / grappled_blocks_dodge / bound_blocks_dodge / terrain_restricted / not_at_contact / not_stronger / no_reserved_thought / not_a_legal_reaction / insufficient_health / bleed_rank_exceeds_cultivator / soulless_target / no_means_declared / means_capacity_full / soul_yield_zero`；`test_command_rejections_v2` 钉死"拒绝不改状态"）。

## 6. 核心数据形状契约

- **gu_instance**（`GuInstance.SAVE_KEYS`，v4 白名单）：`instance_id / definition_id / rank / state("refined"|"contracted"|"weakened") / core_state{} / hunger_phase / next_feed_need{} / lifecycle / uses_left? / loyal / ferocity / parasitic / flee / sealed / modifications[{kind,source,...}]`。
- **cultivator**：现役键 `stage/cultivation/speed/aptitude/...`；五量键已声明（`soul_magnitude / soul_safe_capacity / soul_calm(0-100) / soul_nature / beast_nature`，`SoulRules.snapshot` 是唯一只读投影）；遗留 `soul/soul_max/soul_control_limit` 属 T10.1 废止范围，前端不得渲染为新魂魄面。
- **battle2 ledger**（T9.1 快照直接投影）：`phase("declare"|"instant"|"quick"|"standard"|"windup"|"end") / thoughts_left / thought_used / reserved / gu_used{} / actions_used{move,strike,dodge,grapple} / maintained[] / ongoing[{id,kind,action,instance_id,thought,turns_left}]`。
- **balance.json 键全集**（Schema 守卫）：`rank_step_ratio / standard_hit_ratio / human_base_health / human_base_strength / human_base_body_capacity / thought_base_capacity / unarmed_damage_ratio / standard_activation_cost / light_cost_ratio / heavy_cost_ratio / natural_recovery_cost_ratio / aptitude_recovery_multiplier / reaction_multiplier / material_refine_efficiency / feed_tier / fixed_defense_ratio / stone_per_t1_material / public_buyback_ratio / low_liquidity_ratio / demand_price_tiers / dragon_fish_replacement / quick_substitute_cap / base_speed / speed_min / speed_max / gu_estimate_ratio / blood_yield_ratio / deep_blood_multiplier`。
- **存档**：`SaveRepository` v4；Run 存档 `user://nanjiang_smoke_save.json`、大厅档 `..._meta.json`；v3 Run 拒载返回 `{"ok":false,"reason":"schema_v4_required","message":"规则版本已升级…已保留。"}`；实例只存 id 与数值。

## 7. 页面流转与控制器状态（现状）

- 屏集合：`Title → Map ⇄ Encounter/Battle/Shop/Rest/Refine/Reward/Npc`；`ContentError` 为目录校验失败兜底屏。`Title` 另有 M0 独立入口；M0 `m0_mode` 标记存于既有 `RunState.node_flags`，跟随 v4 Run 存档恢复。
- `RunController` 持有 `state(RunState) / current_battle{} / current_session{} / current_node{} / route[] / last_feedback / last_load_diagnosis`。`last_feedback` 由 `submit_command` 统一维护（每条命令先清空、产生反馈则重填），是**唯一**的玩家可见拒绝/反馈文本来源；战斗命令的拒绝也走它（见 §3.2、§5.1），不得由战斗屏自建第二套文案。
- 载入：`load_saved_run()` -> `diagnose_run_file()` 失败即 `_save_load_feedback`（v3 显示"已保留"文案）；`_restore_game` 以 `has("state")` 判成功。
- 结局：`terminal_state != "active"` 即终局（`run_ended` 事件清空局内资源）；非死亡结局与致死确认统一走二次确认命令面（已落地：`bloodlet` 致死标记 `lethal_confirm_required`、`SoulRules.soul_growth_forecast`、兽化门 `bestiality_endpoint_check`——标记随命令结果返回，UI 层执行前强制确认）。

---

## 8. 本档维护约定

1. ~~阶段八交付后：追加 `BloodQiRules` / `SoulRules` 两节~~ 已完成（2026-09-02）。
2. ~~阶段九 T9.1/T9.2 每个提交落地后回写占位~~ 已完成（2026-09-02）：T9.1 快照八组、T9.2 命令/词表/拒绝映射、T10.1/10.2 删除族均已回写；本档为随代码维护的活文档。
3. 前端生成只允许消费本档列出的键与命令；发现需要新键时，走"快照键 + 同源测试"流程，不得在 UI 层拼私有数据。
