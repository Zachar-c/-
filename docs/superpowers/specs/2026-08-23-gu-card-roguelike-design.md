# 蛊虫构筑与战斗行动卡组设计

## 状态

状态：已确认，等待实施计划与逐项 TDD 落地。

本设计为《南疆凡人》的 Roguelike 战斗与构筑方向。它以蛊师的用、炼、养为长期经营核心，以抽取式行动卡组组织每场战斗；不把蛊虫简化为普通卡牌，也不改变既有 ActionCard 预览-结算架构。

## 范围

- 玩家正常可玩范围为凡人一至五转。
- 六至九转、仙窍、仙蛊、灾劫仅保留内容数据模型与终局展示，不提供常规玩家升仙或可玩渡劫循环。
- 单局是永久死亡 Roguelike。死亡后销毁全部 RunState 临时内容；MetaProgress 仅保留图鉴、解锁与统计，不保留任何数值成长或开局资源。
- 首个纵切片以基础蛊虫、战斗、事件、黑市、养护和合蛊证明闭环，不提前量产完整高转内容池。

## 架构边界

以下接口和职责不可改变：

```text
ActionPreviewService.preview_actions(run, context, catalog) -> ActionCard[]
ActionPreviewService.preview_battle_actions(battle, run, catalog) -> ActionCard[]

UI -> { type: "action_card", action_id, state_version }

ActionResolver / BattleResolver.apply(run, command, catalog)
  -> { state, actualChanges, nextAvailableActions }
```

- Preview 只读：不修改 RunState、不写事件日志、不消耗资源、不执行 RNG，也不读取原始种子。
- Resolver 是唯一可信结算源：重新读取 RunState、重建或查找当前行动、校验版本与前置条件，再执行确定或随机结算。
- UI 不构造领域命令，不传递卡牌、奖励、骰点、敌人配置或交易结果等业务对象。
- 所有重要变化通过 RunState.append_event() 进入不可变结构化事件日志。
- Preview 只展示确定成本、公开成功率、已知风险和可观察线索；隐藏后手、滞后反噬和未知奖励仅以模糊提示表达。

## 单局循环

```text
新局
  -> Resolver 用本局种子确定分叉地图和节点内容
  -> 选择可达节点
  -> 战斗 / 秘境事件 / 黑市商店 / 休整
  -> 获得、炼化、交易、合炼或失去蛊虫
  -> 节点养护结算
  -> Boss
  -> 胜利或死亡
  -> 从事件日志结算图鉴、解锁和统计
```

地图节点固定为 `combat`、`event`、`shop`、`rest`、`boss`。地图生成及节点内容抽取仅在 Resolver 中完成，UI 只消费已生成的公开节点、可达连接与雾区。

## 数据归属

| 实体 | 归属 | 说明 |
| --- | --- | --- |
| RunState | 单局临时 | 地图、人物、空窍、蛊虫、资源、遗物、战斗、事件日志 |
| MetaProgress | 全局永久 | 图鉴、配方知识、事件/遗物解锁、挑战统计 |
| Cultivator | RunState | 修为、资质、生命、寿元、魂魄与状态 |
| CaveAperture | RunState | 真元池、真元恢复、已炼化蛊虫的存放容器 |
| GuInstance | RunState | 本局获得的蛊虫实例与炼化、忠诚、喂养状态 |
| GuRecipe | 内容数据 | 固定蛊方和自由乱合规则 |
| KillMove | 内容数据与本局组合记录 | 多蛊顺序、条件与衍生卡蓝图 |
| CardDefinition | 内容数据 | 单蛊或多蛊衍生行动卡定义 |
| CardInstance | BattleState | 单场战斗的抽牌堆、弃牌堆、手牌临时视图 |
| RelicDefinition | 内容数据 | 单局被动规则修改器 |
| MapNode | RunState | 本局生成的节点实例与完成/可见状态 |
| GameEvent | RunState | 已抽定的秘境事件实例与已选分支 |
| ShopDeal | RunState | 本局黑市报价、风险与剩余次数 |
| BattleState | RunState | 单场战斗状态，结束时清空 |
| Inheritance | RunState 与 MetaProgress 图鉴 | 本局传承效果，结局时仅记入已见知识 |
| ImmortalCave / Disaster | 内容数据 | 六转以上展示数据，首轮不提供可玩流程 |

MetaProgress 严禁存储 `health`、`lifespan`、`soul`、`stone`、`gu_instances`、`relic_ids`、`battle_state`、`map_nodes`、`event_log` 或任一本局卡组数据。

## 蛊师与空窍

### Cultivator

```text
Cultivator
  reincarnation: int       # 1-9
  stage: int               # 0 初阶，1 中阶，2 高阶，3 巅峰
  aptitude: jia | yi | bing | ding | wu
  health / max_health: int
  lifespan: int
  soul / soul_max: int
  soul_control_limit: int
  statuses: Dictionary
```

全局修为顺序为：

```text
total_order = (reincarnation - 1) * 4 + stage
```

寿元或魂魄降至零均为立即死亡。低魂魄会降低炼化成功率、提高反噬风险并压低同时操控额度。

### CaveAperture

```text
CaveAperture
  essence: int
  essence_max: int
  essence_regen_per_turn: int
  aperture_integrity / aperture_integrity_max: int
  stored_gu_instance_ids: Array[String]
```

空窍是蛊虫唯一存放与炼化容器，但不定义 `gu_capacity`、`gu_slot_limit` 或任何持蛊数量上限字段。已炼化且存于空窍、未死亡或逃离的蛊虫才可以操控。

```text
essence_max = rank_base_essence[reincarnation] + aptitude_essence_bonus[aptitude]
essence_regen_per_turn = rank_base_regen[reincarnation] + aptitude_regen_bonus[aptitude]
```

固定一转丙等开局的目标值为 `essence_max = 4`、`essence_regen_per_turn = 2`。

## 蛊虫资产与维护

```text
GuInstance
  instance_id / definition_id: String
  rank: int
  path_tags: Array[String]
  state: wild | unrefined | refined | contracted | weakened | dead | escaped
  loyalty: int
  durability: int
  feeding_need: Dictionary[String, int]
  feeding_interval: node | battle_round
  feeding_debt: int
  activation_cost: { essence, lifespan, soul, blood, material_id, material_count }
  minimum_reincarnation: int
  backlash_profile_id: String
  card_blueprint_ids: Array[String]
  mutation_tags: Array[String]
```

蛊虫数量没有硬上限，但囤积并非免费：

| 约束 | 限制对象 | 效果 |
| --- | --- | --- |
| 真元 | 催发频率与高费行动 | 每回合恢复有限，卡牌可同时消耗真元 |
| 魂魄 | 同时激活、维持或参与杀招的不同蛊虫数 | 超限由 Resolver 结算魂魄反噬 |
| 养护 | 持有蛊虫总量与品质 | 节点离开时汇总结算，断喂造成衰弱、逃离或死亡 |

养护默认在离开地图节点时自动汇总。资源不足时蛊虫先进入 `weakened`，效果降低但仍占养护；持续断喂时由 Resolver 根据种子、忠诚和状态结算逃离或死亡。Preview 只显示下一次已知养护需求与缺口，不能预演具体逃离结果。

## 蛊虫到卡牌的映射

蛊虫是长期资产，卡牌是单场战斗的衍生视图：

```text
所有存活、已炼化、存于空窍的 GuInstance
  -> 按 card_blueprint_ids 读取 CardDefinition
  -> 叠加 gu_card_overrides 的删除/升级/复制规则
  -> Resolver 生成 BattleState.draw_pile
  -> 洗牌、抽牌、消耗真元打出

战斗结束
  -> 销毁所有 CardInstance 和 BattleState 抽牌区
  -> 保留空窍内 GuInstance、忠诚、损伤、喂养与生成覆盖规则
```

```text
删除行动卡：只写 gu_card_overrides[card_key].disabled_for_run = true
销毁或舍弃蛊虫：移除 GuInstance，后续战斗不再生成其任何卡牌
复制行动卡：增加该卡在未来战斗中的生成数量，不复制蛊虫
升级行动卡：改变该卡的生成覆盖，不改变来源蛊转数或养护成本
```

多蛊杀招由 `KillMove` 定义来源蛊、顺序和条件。其衍生卡必须记录全部 `source_gu_instance_ids`，并在结算时逐个校验来源蛊、真元、魂魄操控和修为要求。

## 战斗

```text
BattleState
  battle_id: String
  phase: player | enemy | finished
  turn: int
  energy / energy_max: int
  draw_pile / discard_pile / hand / exhausted_cards: Array[CardInstance]
  active_gu_instance_ids: Array[String]
  active_effect_registry: Dictionary[String, DurationEffect]
  enemy_states: Array[Dictionary]
  enemy_visible_intents: Array[Dictionary]
  observed_enemy_clues: Array[String]
```

基础节奏：

```text
回合开始：恢复真元、获得行动能量、抽牌、公开敌方意图
  -> 玩家打出一至多张手牌
  -> Resolver 结算真元、寿元、魂魄、伤害、防御、状态与反噬
  -> 玩家收势
  -> 敌方执行公开意图和合法反应
  -> 持续效果递减、死亡检查、进入下一回合
```

`DurationEffect` 至少记录：

```text
effect_instance_id
source_gu_instance_ids
remaining_turns
tick_phase
occupies_soul_slots
soul_occupancy_gu_ids
```

持续防御、召唤、控制和持续杀招占用魂魄操控。效果到期后，Resolver 必须递减来源蛊的引用计数，归零后才从 `active_gu_instance_ids` 移除。

敌人意图由 Preview 输出，只含当前倾向、公开类别、已知征兆和可见状态，绝不暴露完整敌方蛊虫配置、隐藏反制、内部 RNG 或尚未观察到的事实。

## 炼化、合蛊与反噬

炼化需要真元、目标蛊存在、必要修为和可用空窍。常规失败会损伤真元、魂魄，且目标蛊可能逃走；契约蛊可以进入 `contracted` 状态，后续仍会按忠诚判定是否反叛。

```text
GuRecipe
  recipe_id
  kind: fixed | free_mix | upgrade | reverse
  input_gu_requirements
  material_cost
  essence_cost / lifespan_cost
  output_gu_definition_id
  minimum_reincarnation
  public_success_rate
  failure_outcomes: destroy_inputs | mutation | explosion
```

合蛊输入至少两只蛊虫。固定配方展示公开成功率与确定成本；自由乱合只展示公开输入、已知成本与模糊风险。成功产物直接进入空窍，无数量上限，随即增加后续养护压力。

示例链：

```text
moonlight_gu + small_light_gu + small_light_gu -> moon_glow_gu
moon_glow_gu + phantom_dust_material + small_light_gu -> phantom_moon_gu
phantom_moon_gu + moonlight_gu + shadow_silk_material -> moon_shadow_gu
```

低修为强行催发高转蛊依 `BacklashProfile` 计算。首轮基础公式：

```text
rank_gap = max(0, gu.rank - cultivator.reincarnation)
health_damage = ceil((1 + rank_gap) * condition_multiplier * aptitude_health_factor)
soul_damage = ceil((1 + rank_gap * 2) * condition_multiplier * aptitude_soul_factor)
```

`condition_multiplier` 由衰弱和低忠诚提高；资质越高，减免系数越强。真元、寿元、魂魄、空窍完整度任一必要代价不能支付时，由 Resolver 拒绝或按蛊定义触发反噬，不能由 UI 绕过。

## 黑市、事件、遗物与传承

```text
ShopDeal
  deal_id
  kind: purchase | risk_trade | barter
  public_cost
  public_gain
  public_risks
  hidden_reward_pool_id
  prerequisites
  remaining_uses
```

黑市支持普通购买、寿元/魂魄/精血代价交易、交蛊换未知蛊。诡诈交易必须有可观察线索和明确已知成本；隐藏契约、滞后反噬和未知产物只由 Resolver 在对应时点决定与公开。

```text
GameEvent
  event_instance_id
  template_id
  public_clues
  option_ids
  hidden_outcome_pool_id
  resolved_option_id
  hidden_outcome_id
```

传承是一组合蛊虫方向、蛊方与经验。单局内可即时提供内容；结局时只把图鉴和已解锁配方知识写入 MetaProgress。

遗物例子：

```text
jade_cicada_shell：每场战斗首回合额外获得 1 点行动能量。
hungry_vine_token：获得一只随机基础蛊，但每离开节点额外增加养护需求。
```

## 六转以上展示模型

```text
ImmortalCave
  cave_id
  essence_type: immortal_essence
  stability
  required_environment_tag
  immortal_material_stock

Disaster
  disaster_id
  required_defense_tags
  destroys_resources
  failure_result: immortal_aperture_collapse
```

示例 `ash_ward_immortal_gu` 为六转仙蛊，需要仙元和仙材。其数据只在击败最终 Boss 后的叙事展示和图鉴出现，不向凡人主流程提供操控入口。

## 首个可玩切片

1. 固定一转丙等散修，基础凡蛊 `small_light_gu`、`stone_shell_gu`、`moonlight_gu` 自动生成开局战斗卡组。
2. 雾地图至少包含 `combat`、`event`、`shop`、`rest`、`boss`，只显示可达层与前方有限层数。
3. 战斗实现真元、手牌、抽牌、弃牌、敌人意图、护身与中毒。
4. 演示删除卡不毁蛊、毁蛊后续不生卡、超魂魄操控上限反噬、蛊越多养护越重。
5. 实现月光合蛊链的首段固定配方与一个自由乱合失败分支。
6. 实现一个高收益滞后代价事件、一个普通购买、一个寿元交易、一个交蛊换未知蛊的黑市场景。
7. 实现一件正向遗物与一件双刃遗物。

## TDD 验收契约

```text
test_aperture_has_no_gu_storage_limit_and_feeding_scales_with_count
test_aperture_essence_uses_reincarnation_and_aptitude
test_soul_control_limit_applies_backlash_to_multi_gu_kill_move
test_duration_effect_releases_soul_occupancy_after_expiry
test_refinement_failure_can_damage_soul_and_make_gu_escape
test_recipe_refinement_success_consumes_inputs_and_adds_output
test_free_mix_failure_destroys_inputs_or_applies_mutation_or_explosion
test_force_activating_higher_rank_gu_applies_backlash_profile
test_unfed_gu_becomes_weakened_then_dies_or_escapes_deterministically
test_basic_refined_gu_generate_opening_battle_deck
test_deleting_battle_card_does_not_destroy_source_gu
test_destroying_gu_removes_future_card_generation
test_shop_lifespan_trade_can_cause_terminal_death
test_deceptive_trade_preview_hides_late_penalty_but_resolver_applies_it
test_map_and_shop_actions_do_not_invalidate_current_battle_hand
test_death_discards_all_run_state_but_preserves_only_meta_discoveries
test_preview_is_read_only_and_never_uses_rng
test_stale_or_duplicate_action_card_submission_is_rejected_atomically
```

每个测试均须先观察失败，再实现最小逻辑；固定种子必须使炼化、乱合、黑市未知奖励、断喂结果和隐藏反噬可重放。
