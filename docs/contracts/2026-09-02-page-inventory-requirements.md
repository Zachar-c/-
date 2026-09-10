# 页面清单与页面需求（spec-v4 第九批·第三步产出）

> 日期：2026-09-02
> 上游：[接口契约](2026-09-02-domain-ui-contract.md)、[前端全局约束](2026-09-02-frontend-global-constraints.md)。
> 用途：第三步"页面生成"的装配总表——每屏一张需求单，生成与评审逐单过；**只允许消费接口契约列出的键与命令**，`[T9]` 标记为快照 v2 / 命令面 v2 的占位项，落地前只做隐藏占位、禁止假数据。
> 现状基线：`master @ 480183a`（阶段一至八合入；§4 血气/魂魄展示需求的数据源已交付，随 T9.1/T9.2 键落地后可生成）。

---

## 一、页面总览与流转

```text
Hall(Title) ──开始/继续──> Map ◇┬─> Encounter ──冲突──> Battle ──> Reward ─┐
  ▲                             ├─> Shop                                 │
  └────────── 终局归因 ── Ending <┤─> Rest                                 │
                                ├─> Npc     <─── 回到 Map（complete_node）┘
                                ├─> Refine（可从 Map 直达的节点类型）
                                └─> [T9 新增] LayerSettle（大层切换时强制）
任意屏 ──目录校验失败──> ContentError（兜底，只读）
```

- 屏名集合固定为契约 §7 的 10 屏 + `Ending`（现役 `ending_screen`，快照侧由 `run_ended` 终态驱动）。
- 页面切换只经 controller 屏切换；**切换不改领域状态**（`complete_node` 等是显式命令）。
- 大层切换是唯一强制插屏点：`[T9]` `settle_layer` 命令落地后，进新大层必须先过 LayerSettle。

## 二、页面需求单

每单字段：**定位**｜**数据绑定**｜**命令与交互**｜**状态与确认**｜**组件装配**｜**验收要点**。

### P1 Hall（`hall_screen`，快照 `Title/hall()`）

- 定位：大厅永久存档入口；开始新局（选流派开局）、继续进行中 Run、图鉴与已解锁蛊方浏览。
- 数据绑定：`starters[]`（`id/name/starter_gu_ids`）、大厅 meta（`MetaProgress`：codex/recipes_unlocked/contract_unlocked/stats）、`load_run` 诊断（v3 拒载显示"已保留"文案）。
- 命令：开局选择（school starter）、`load_run`（controller 层）、删除无。
- 状态与确认：开局为不可逆入口但属于"新局开始"，无需确认；`load_run` 失败展示 `_save_load_feedback` 全文。
- 组件：`GuPanel`、`GuIcon`、`GuToast`；图鉴列表用 `GuStatBar` 无、列表行通用。
- 验收：v3 存档场景显示契约 §6 的"已保留"完整文案；开始后直达 Map。

### P2 Map（`map_screen`，快照 `Map/map()`）

- 定位：路线决策主屏；节点可达性、当前层、节点类型导航。
- 数据绑定：`nodes[]`（`id/type/label/layer/row/next_ids/reachable/visited/current/visibility`）、当前层、可达集、`inventory{materials,gu_instances,loot,intel}`；`[T9]` 大层切换入口（`settle_layer` 预览键）。
- 命令：`travel(node_id)`（可达校验在领域，`node_not_reachable` 拒绝可见）、`complete_node`、离开确认（现役 `_map_leave_confirm` 模式）。
- 状态与确认：不可达节点禁用 + 原因；`[T9]` 进新大层强制跳 LayerSettle；离开进行中节点走单次确认。
- 组件：`GuTopBar`、`GuInventory`、节点图（现役 HTML 合成式地图，遵守自管页边距成文规则）、`GuToast`；`[T9]` `GuHungerBanner`（若下一切层有饥饿预测）。
- 验收：visited/current/reachable 三态视觉可辨；每个 `reachable=true` 节点的完整点击区域位于当前可视地图内；同一快照中重复点击同一节点只提交一次 `travel`；travel 拒绝文案可见。

### P3 Encounter（`encounter_screen`，快照 `Encounter/encounter()`）

- 定位：非战斗遭遇（交涉/事件/险地）；行动卡决策。
- 数据绑定：`node{title,desc,type}`、`actions[]`（action_id/label/detail/cost/executable/block_reason/remedy_hints）、`intel{weakness,cost}`（已探明才显示）、`player`、`resources`、`contracts`、`anomalies`（DDA 标记）、`death_lines`。
- 命令：`encounter.action_card`（预检 spec：`state_version + node_id + session_node_id`，全部必填）、`resolve_contact`、`choose_action`、离开。
- 状态与确认：`executable=false` 的卡必须展示 `block_reason` + `remedy_hints`；`death_lines` 仅为既有状态栏风险预警与行动预检数据，风险行动升级为确认层级 2/3，不得渲染独立死线行。
- 组件：`GuCommandButton`、`GuCostBreakdown`、`GuPanel`、`GuToast`；情报区只显示 `known_facts` 已有项。
- 验收：每张卡的禁用原因可指出来源键；提交携带完整四字段（缺一即 `command_context_missing`）。

### P4 Battle（`battle_screen`，快照 `Battle/battle()`）——本批改造重点

- 定位：战斗决策主屏。现状为 V1 连续时间模型；`[T9]` 接入 battle2 离散回合命令面与快照 v2。**双轨期约束**：V1 键与 battle2 键分区渲染，切换由命令面落地进度决定，禁止混用两套数值。
- 数据绑定（现役）：`enemies[]`（hp/shield/statuses/intent/alive/counter_revealed）、`player`、`hand`、`piles`、`actions`、`default_target_id`、`kill_moves`、`flee_available`、`synthesis`、`dda_boss_hint`、`death_lines`、`inventory{materials,gu_instances,loot,intel}`。
- 数据绑定（`[T9]` v2 占位）：`GuLedgerBadge`（thoughts_left/thought_used/reserved/maintained/gu_used/actions_used）、`GuDistanceBand`、`GuIntentBadge`（反应窗口开放标记）、安全力量/对外伤害/超载自伤/致死警告（`strike_preflight`）、维持状态列表、敌方准备状态。
- 命令：现役 `use_gu/use_inheritance/end_turn/retreat/basic_attack/basic_dodge/refine/play_kill_move`（全部经 `battle.action_card`/`battle.turn` 预检）；`[T9.2]` 增 `enact`（proposal 三形）、`dodge/grapple/respond`、预留念头。
- 状态与确认：单敌目标自动补 `target_id`（现役规则）；多敌强制选择；撤退受 `boss_blocks_retreat`；致死预检 → 确认层级 3，在确认框中展示精准风险；超载自伤预计死亡同上。`death_lines` 不得在战斗页另建数值/死因覆盖层。
- 组件：`GuBattleHand/HandPanel`、`GuEnemyActor`、`GuStatBar`、`GuInventory`、`GuTooltipView`、`GuIntentBadge`、`[T9]` `GuLedgerBadge`、`GuDistanceBand`、`GuCostBreakdown`。
- 验收：卡牌详情只经共享 hover tooltip 展示（含风险段），不得另建常驻详情卡；单体卡可经鼠标选择敌人，危险卡先确认再提交，且同一快照内相同卡牌/目标组合最多提交一次；手牌过期（`battle_hand_stale`）触发重建；每个操作按钮可指出预检 spec_id；v2 占位区在未落地时整体隐藏。
- 手牌卡形与手势（2026-09-10 竖长卡 + 扇形口径，纯表现层，不新增快照键/命令）：
  - **卡形**：竖长卡 `110×154`（原 168×74 横向卡），由手牌组件 `GuTallFanHandView` 拥有；
    卡面只承载「名称 / 道阶 / 效果 / 费用」四行**文本**，效果行允许折两行（阈值 `FACE_EFFECT_MAX_CHARS`）；
    卡体节点树为 `card_box_<清洗 id>`（Control，承担 position/rotation/scale/pivot）包 `card_body_<清洗 id>`
    （Button，承担 hover/点击）。卡形与排布参数变更须同步更新线框稿与本节。
  - **排布**：底部横向扇形自适应——`t=(i−center)/center` 非线性缓动后给倾角（`MAX_ANGLE_DEG`）、弧高（`ARC_LIFT`、
    中间卡低、两端高，两端上溢不占布局）、边缘透视缩放（`PERSPECTIVE_DROP`）、步进 `clamp(可用宽/(n−1), 卡宽×0.45, 卡宽×1.02)`
    实现负边距重叠；1200px 级屏宽下同屏约 19 张。手牌盒只预留**卡高**，弧高靠两端卡向上溢出（宽度侧为直角区，无控件碰撞）。
  - **手势**（双入口，组件内实现并向上广播信号）：点击与拖拽都只是既有 `play_card(card_id, target_id)` 的入口。
    指向性卡（`target_type == "single_enemy"`）按住拖出**瞄准弧箭**（不出影卡、源卡不压暗；颜色按卡牌性质——
    攻击=朱砂、控制/辅助=青灰；锁定与否由线型与线宽表达——自由态半透明虚线、命中存活敌人转实线加粗），
    松手命中敌方卡即按该目标提交，未命中即取消；无指向卡按住拖出**固定距离**（`DRAG_CAST_DISTANCE_PX`）松手即出牌
    （拖出距离跨阈值时影卡转朱砂「可出牌」态），位移不足则回弹（`REBOUND_TIME`）且不提交；
    位移 < `DRAG_START_THRESHOLD_PX` 视为普通点击，仍走按钮 `pressed` 原路径。
    不可执行卡（`executable == false`）**可悬停但绝不提交**（玩家要看得到 block_reason）。
    影卡（按 `DRAG_PROXY_SCALE` 重建放大、不透明、浮层，节点名 `battle_drag_proxy`）与瞄准弧箭
    （节点名 `battle_aim_line`，挂组件内 `AimLayer` CanvasLayer `layer=90`）均为纯表现层装饰（`mouse_filter=IGNORE`），
    不落事件日志、不进存档；真拖拽手势的抬起事件一律被消耗，防止同一次松手既回弹又触发按钮 `pressed` 双发。
  - **组件与宿主的职责边界**：组件发 `card_chosen(card_id, target_id)` / `hover_changed(card_id)` /
    `aim_target_changed(target_id)` / `cancel_requested` 四个信号；命令提交（含危险卡确认流）、统一解释栏、
    敌人放置高亮（`GuEnemyActorView.set_drop_highlight`）一律由宿主施加。组件不认识领域状态。
  - **悬停**：卡体抬升放大（`HOVER_LIFT` + `HOVER_SCALE`，绕底边 pivot 向上浮）、左右邻居让位、未悬停卡压暗；
    共享解释栏（`battle_hand_tooltip_host`）**锚定悬停卡上方**（不跟鼠标、不盖住卡），抬升量由组件经
    `hover_lift_px()` 提供；拖拽/瞄准期间解释栏一律收起（组件在进入手势时广播 `hover_changed("")`）。
  - **可达性（2026-09-10 真机反馈补充，同日二次返工修订）**：任何可点元素必须**既接线又能点到**。
    透明的纯装饰容器（`HandStage` / `HandMargin` / `battle_hand` / `HandArea` 这类舞台与包装层）
    必须 `mouse_filter = IGNORE`。判定与排错要点：
    - **`PASS` 同样会遮挡，只有 `IGNORE` 让路**。`MOUSE_FILTER_PASS` 的语义是"自己也收，并把事件
      继续交给**父节点**"，它**不会**让给身后被压住的兄弟节点。（首轮只把 `HandStage` 从 `STOP`
      改成 `IGNORE`，漏掉了 `PASS` 的 `HandMargin`——它以 `margin_right = 210` 只让开**卡**，
      容器自身仍是满幅 `0,514 1280x206`，于是右栏三个按钮继续点不到。）
    - **命中顺序**按引擎 `Viewport::_gui_find_control_at_pos`：**子节点逆序**深度优先，先递归子树、
      子树无命中再判自身；`IGNORE` 节点自身不算命中但不阻断其子树。
    - 症状极具误导性：按钮 `disabled=false`、`modulate=1`、父链无压暗、无可见覆盖层，
      但悬停不亮、点了没反应（看起来像"被置灰禁用"）。
    验收：`tools/verify_interaction_loop.gd` 的 `occluded` 必须为空
    （既有未修项见该脚本 `KNOWN_OCCLUDED` 留档表，以 `occluded_known` 计数呈现）；
    回归用例 `test_wenzhen_battle_screen.test_ops_buttons_accept_real_clicks_despite_transparent_hand_containers`
    ——**真的按下+松开**并断言命令被触发（几何判定只是代理指标，代理本身也容易写错）。
  - **取消出口**：指向卡两步确认（点卡 → 点敌人）必须留出口——模式区（`ModeHost`）在 `target_select` 态渲染
    「取消目标」按钮，且卡体上的右键 / Esc 经组件 `cancel_requested` 转发给宿主复位。

### P5 Shop（`shop_screen`，快照 `Shop/shop()`）

- 定位：商店购买/回收/以物易物/寿元交易/服务。
- **货架（E7，2026-09-10）**：每店只摆 `4 + ⌊层/2⌋` 件**货**（层 1/2/3/4/5 = 4/5/5/6/6），
  保底至少 1 件本层最高档；**服务**（黑市兑换 / 洗恶名 / 蛊方解锁 / 真元）常驻，不受货架限制。
  货架由 `(局种子, 节点模板 id)` 确定性派生——同一商店点位反复进出**货架不变**（不能刷货），
  不同点位不同；**不新增存档字段**（可重算，读档后自动一致）。
  验收：不在货架上的**货**调用 `shop_purchase` 必须被领域层拒绝 `shop_offer_not_in_stock`
  （此前只藏 UI、命令面仍可越权购买）；回归用例 `tests/unit/test_shop_roll.gd`。
- 数据绑定：货架报价（`id/kind/gu_id/material_id/price/tier/stock`）、`_shop_services[]`（服务次数/限次/涨价）。
- 命令：`shop_purchase/shop_lifespan_deal/shop_barter/sell_material/buy_gu/sell_gu/exchange_gu`。
- 状态与确认：`npc_stock_missing`（已售空）禁用；寿元交易 → 确认层级 2（`lifespan_trade_warning`）；换蛊 → 确认层级 2 + `GuPermanentLossList`（`[T9]` `exchange_screen` 键：permanent_losses/rejected_natures）；危险/秘密材料拒收提示（`[T9]` MarketRules 拒收口径）。
- 组件：`GuResourceChip`（元石）、`GuCard`、`GuCommandButton`、`GuConfirmDialog`+`GuPermanentLossList`。
- 验收：报价无库存即禁用且有文案；寿元/换蛊确认框列出全部失去物。

### P6 Rest（`rest_screen`，快照 `Rest/rest()`）

- 定位：休整节点：回血、强化蛊卡、移除蛊 / 印记 / 反噬、调资质、放弃收益并离开。
- 数据绑定：`rest_used/rest_mode_used/aptitude_raised`（node_flags 派生）、休整选项（`id/label/detail/cost/disabled/reason/curse_warning/requires_confirm`，id 全集为 `heal/upgrade_card/remove_card/remove_imprint/remove_curse/skip`，`wash` 仅在闭关/传承节点出现）、`upgrade_targets`（每张 `refined_gu_id`）、`remove_card_targets`（每只活蛊实例 + `blocked/reason`）、`imprint_targets`（每枚印记 + `meta_rule` 不可移除原因）、`curse_targets`（每条 `statuses` 诅咒 + 层数）。
- 命令：`rest`（`heal`/`upgrade_card` + `card_key` / `remove_card` + `instance_id` / `remove_imprint` + `relic_id` / `remove_curse` + `curse_id` / `skip`）、`raise_aptitude`。
- 状态与确认：本次已休整全选项禁用 + "本次已休整"；`skip` 在未消费时强制二次确认（`requires_confirm=true`）；诅咒蛊移除被领域拒绝（`blocked` 原因展示）；`curse_warning=true` 的选项升级确认层级 2。
- E4 三选一（2026-09-09，规格 §4）：`rest/refinement/cultivation` 三类节点统一由 travel 分发进本屏；快照 `mode_groups` 携带 `修炼[]`/`炼蛊[]` 两组动作卡（`meditate`→encounter `action_card` 信封、`cultivate`→`cultivate_rank_two`、`refine/free_pair`→打开炼蛊子屏不发领域命令），插在主决策面与移除面板之间；成功执行修炼/炼蛊即消费本次探访（node_flags 落 `used`），离开需玩家显式操作；快照无 `mode_groups` 时整行隐藏（旧存档兼容）。
- 组件：`GuCommandButton`、`GuCard`、`GuToast`、`GuConfirmDialog`。
- 验收：每节点快照必须包含 `heal/upgrade_card/remove_card/remove_imprint/remove_curse/skip` 域全集；`skip` 触发后事件日志落 `rest_skipped`；`leave_node` 在任一选项合法或 skip 已确认后必须放行（`rest_choice_required` 不得成为软锁）；种子 `2/6/8/10/13/15/16/18/33/34/41/49` 回归不得出现无合法选项且无法离开的状态。

### P7 Refine（`refine_screen`，快照 `Refine/refine()`）——本批扩展重点

- 定位：炼蛊台。现状：配方列表（combine/fixed/advance）+ 投入合成；`[T9]` 接入 RecipeRules 透明面 + 核心确认入口。
- E4a 子屏语境（2026-09-09）：经休息屏「炼蛊」卡进入时快照 `from_rest=true`，「离开」按钮文案改「返回休整」，点击仅退回休息屏继续三选一，不发 `leave_encounter`（探访是否结束由休息屏决定）；`initial_channel` 预选通道（如 `free_pair`），用户手动切 Tab 后前端本地选择优先；直连路由（非子屏）语境行为不变。
- 数据绑定（现役）：配方 `id/channel/name/output/rank_note/quality/fail_chance/backlash/curse`（`success_roll_max` 存在的配方显示失败率——T10.1-⑧ 废止后此字段消失，前端不写死依赖）、`recipe_unlocked`。
- 数据绑定（`[T9]` v2）：`identity_requirements`（点名蛊/材/标签/转数/媒介逐项满足态）、`stages[]`（每阶段念头/真元/轮数/打断点）、`candidate_pool`（2-3 选一，声明序）、`allow_substitute` 替代关系与 `cost_change`、`known_fixed_success` 确定成功标识；核心确认面板（`core_state{depth}`、`hub_evidence`、第一层中段门控态）。
- 命令：`refine_gu`（现役）；`[T9.2]` `refine_up_material`、`confirm_core`、跨回合炼制续投（对齐 battle2 ongoing 的 `continue_ids`）。
- 状态与确认：未解锁配方禁用 + `refine_recipe_locked`；投入不足禁用 + `refine_input_missing`；核心蛊作辅蛊 → 确认层级 2（`aux_core_warning` 强警告）；跨回合炼制中断 → 展示已发生结果与损失。
- 组件：`GuCard`（投入位）、`GuCommandButton`、`GuCostBreakdown`、`[T9]` `GuCoreBadge`、候选池选择控件（单选，声明序展示）、`GuConfirmDialog`。
- 验收：随机失败率文案只对带 `override_reason` 的存量配方出现；点名材料缺项时缺哪味可见；`[T9]` 区未落地时隐藏。

### P8 Reward（`reward_screen`，快照 `Reward/reward()`）

- 定位：战后收获入账清单。
- 数据绑定：`last_battle_loot`（material_ids/gu_id/stone/info）逐项 `name/kind/quality/effect/cost`、`last_battle_cost`（战斗代价）。
- 命令：入账为已发生事实（自动），继续/离开；`[T9.2]` 战后幸存蛊收取确认（`collect_surviving_gu`：held_only 与 refined 分态展示、战前声明条件未满足的 `not_collected` 原因可见）。
- 状态与确认：`[T9]` 收取幸存蛊 → 确认层级 1（条件/结局说明）；释放/灭蛊入口从此屏进（确认层级 2，展示 `release_gu` 后果 / `destroy_gu` 声明提取物）。
- 组件：`GuCard`、`GuResourceChip`、`[T9]` `GuCommandButton`、`GuConfirmDialog`。
- 验收：入账项与 `loot_rules` 收取结果一一对应；无预算裁剪痕迹（#12 透明）。

### P9 Npc（`npc_screen`，快照 `Npc/npc()`）

- 定位：NPC 交涉与交易（含情报购买）。
- 数据绑定：NPC 名（`DisplayText` 派生）、行动卡（`node.negotiate/deceive/fight/retreat/leave/probe/trade/work/harvest/buy_information/cross/meditate/...`，`label/detail/cost`）、库存与需求。
- 命令：`resolve_contact`、`npc_trade`、`[T9.2]` `sell_info`（出售保留知识/传播衰减/同买方一次付费的展示）。
- 状态与确认：交涉失败的敌对后果（`hostile` 分支）就地提示；`[T9]` 需求档收购展示 80/100/120% 与"满足后消失/降档"提示（防套利透明）。
- 组件：`GuCommandButton`、`GuToast`、`[T9]` `GuCostBreakdown`（信息价 `info_value`）。
- 验收：行动卡四字段完整；情报买卖的独占衰减值来自 `MarketRules`（`[T9]`）。

### P10 Ending（`ending_screen`，快照 `run_ended` 终态 + `debug()` 归因段）

- 定位：终局结算与归因。
- 数据绑定：`terminal_state`、终局原因（死亡死因来自 `gu_starved`/战斗/超载等事件死因）、事件流（归因视图）、`stats` 回写大厅。
- 命令：返回大厅（重建大厅存档读取）。
- 状态与确认：Run 结束后局内资源已清空（`run_ended` 事件 `after` 全空）；归因列表只消费事件日志（`GuEventFeed`），禁渲染 `_` 前缀键本体。
- 组件：`GuEventFeed`、`GuPanel`、`GuDeathCauseOverlay`（死亡类结局）。
- 验收：归因每条可指出事件 id；回到 Hall 后进行中 Run 存档已删除。

### P11 ContentError（`content_error_screen`，快照 `ContentError/content_error()`）

- 定位：目录校验失败兜底，只读错误列表（`ContentCatalog.validate` 输出），无命令。
- 验收：任何键缺失/越界导致进此屏时，错误行原文可见。

## 三、新增页面需求（spec-v4 扩容）

### N1 LayerSettle（新屏/强制插屏，`[T9.2]` `settle_layer` 落地后启用）

- 定位：大层切换的喂养结算：预览 → 玩家排序 → 提交。
- 数据绑定：`FeedingRules.preview_settle`（`will_hunger[]/will_die[]`）、逐蛊 `feed_cost`、库存当量与匹配/通用/应急三通道余量、`budget_report`（软上限报告只展示不拦截）。
- 命令：`settle_layer(state,new_layer,pantry,catalog,options{feeding_order,...})`；排序即命令参数。
- 状态与确认：死亡预测蛊 → 单次确认列出"将死亡"名单与死因（二次未喂）；提交后展示 `gu_starved`/`layer_feeding` 事件结果。
- 组件：`GuHungerBanner`、`GuCostBreakdown`、排序列表（拖拽或上移/下移）、`GuConfirmDialog`。
- 验收：不排序直接提交 = 默认顺序生效（领域层接受）；预览与结算结果一致（同源断言）。

### N2 核心确认/更换入口（归属 Refine 屏面板，非独立屏）

- `confirm_core`：面板显示候选实例（全部战斗蛊）、深度标记（common/hub + hub_evidence 可枚举）、确认门状态（第一层中段前禁用 + 原因）；确认 → 事件。
- `replace_core`：凭证持有态 + 候选新核心 + `cost_sources` 结构化展示 + 硬上限拒绝文案；确认层级 2（永久失去项 = 旧核心专属改造清单）。

## 四、血气道与魂道展示需求（规则模块已交付，快照键随 T9.1/T9.2 落地）

- 血气道：血气双标签芯片（`GuResourceChip` 扩展 blood/qi 双计数同源显示）、放血命令确认（致死标记）、秘密交易门槛提示、血腥踪迹状态显示。
- 魂道：魂魄五量面板（量级/承载/安分/魂性/兽性条）、收魂手段与容量展示、虚浮警告、兽念阈值三选项（保留/利用/净化）、兽化结局确认入口。
- 规则模块（`BloodQiRules` / `SoulRules`）已交付并有契约条目（接口契约 §3.3）；快照键落地前该区块保持隐藏占位，禁止假数据。

## 五、生成顺序建议（第三步执行序）

1. 基础组件先行：`GuCommandButton` → `GuEventFeed` → `GuCostBreakdown` → `GuConfirmDialog` 扩展（永久失去项/死因模式）——它们是所有屏的依赖。
2. 低风险屏改造：Rest / Reward / Hall / ContentError（现役键即可完整验收）。
3. 中风险屏：Shop / Npc / Map（现役键 + 少量 `[T9]` 占位）。
4. 高风险屏：Refine（`[T9]` 面板大）→ Battle（双轨改造）→ 新增 LayerSettle。
5. 每屏交付 = 生成 + `test_ui_rules_guard` 全绿 + 真实渲染核对 + 本单验收要点逐条过。
