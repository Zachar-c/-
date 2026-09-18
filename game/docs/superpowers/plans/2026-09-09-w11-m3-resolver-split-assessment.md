# W11 措施 3 执行评估：resolver.gd 切分路线（2026-09-09 侦察定稿）

> 来源：本文件基于对 `scripts/domain/resolver.gd`（2407 行）的全量静态侦察。
> 目的：给「resolver.gd 按命令族切分、主文件保留路由」这一工单目标提供
> 结构证据、可行路线与首批候选，供执行会话直接照办，避免重复侦察。
> 状态：**待用户路线决策（A 渐进 / B 硬切）**，未执行代码改动。

## 1. 结构事实（侦察基线）

- `apply()`（L69）→ `_handler_for()`（L81）惰性静态字典 → 各命令 handler。
- dispatch 覆盖 **49 命令**；其中 **14 个 v2 命令已薄转发**到
  `RunCommandsScript`（confirm_core/replace_core/feed_instance/settle_layer/
  collect_surviving/release_gu/sell_info/enact/dodge/grapple/respond/
  refine_up_material/bloodlet/absorb_soul）——历次重构已确立「resolver 收
  窄 = 命令族外迁到规则模块」的既定模式。
- 剩余 **65 个 static func** 按命令族聚类（行号 = 侦察时点）：

| 命令族 | 代表函数 | 近似行数 |
|---|---|---|
| 炼蛊/合成 | `_refine_gu` `_apply_combine_recipe` `_apply_fixed_recipe` `_apply_free_mix` `recipe_unlocked` `_cultivate_rank_two` | ~300 |
| 商店/交易 | `_buy_gu` `_sell_gu` `_exchange_gu` `_shop_*` `service_*` `_offer` `_raise_aptitude` `_npc_trade` | ~450 |
| 休整 | `_rest` `_rest_*` `_consume_rest_visit*` `_is_rest_node` | ~280 |
| 卡/蛊操作 | `_disable_card` `_upgrade_card` `_copy_card` `_destroy_gu*` `_use_gu` | ~170 |
| 社交/事件/诅咒 | `_choose_action` `apply_social_action` `_npc_*` `_accept_event` `_gain/_remove_curse_command` `_swear_contracts` `_gain_force_power` | ~450 |
| 进程/结算 | `_complete_node` `_settle_feeding` `_settle_node_feeding` `_finalize_if_dead` `_spend_lifespan` `_accept_debt` `_record_*` `_travel` | ~350 |
| 升仙/继承 | `_attempt_ascension` `_ascension_*` `_claim_inheritance` `_take_body_imprint` | ~200 |
| 共享查询门面 | `notoriety` `roll_chance` `price_for` `sell_price_for` `scavenge_pending_recipes` `service_*`（public，外部消费） | — |

## 2. 关键障碍：共享私有 helper 纠缠（切分不便宜的根因）

抽验商店族（最"自包含"候选）依赖面：函数体内高频引用
`_rejected` / `_event` / `_accepted` / `_layer_price` / `_legacy_gu_projections` /
`_gu_instance_id` 等全局共享 helper。这些 helper 被全库 65 函数复用，且
`_legacy_gu_projections`/`_gu_instance_id` 牵涉 **GuInstance 同步铁律**
（获得/失去蛊必须同步 gu_instances + cave_aperture，见项目 MEMORY）。
即：**按命令族搬移 ≠ 自包含搬移**——每族外迁必须携带其私有依赖集，
连锁移动后仍是「新模块间互相 import」，只把 2407 行摊成多个文件，
不降低耦合；且 GDScript 无跨文件私有，搬移即公开化，破坏封装假象。

另一面：历次能外迁成功的模块（soul_capacity/curse_registry/synthesis/
contract/economy/shop_rules/run_command_rules/dda）都是**规则自包含、
不依赖 resolver 私有态**的模块——这反证 resolver 剩余部分是「编排+结算
紧耦合核心」，恰恰是最难切的部分。

## 3. 安全网缺口（先补再切的必要条件）

W4 快照契约只钉 `RunSnapshotBuilder.for_screen` 输出键，**不覆盖命令
语义**。resolver 是确定性状态机核心（append_event / 死亡校验 / rest 访问
消耗门禁），切分引入的行为回归无法被 W4 捕获。切分前须先立
「命令语义红灯」：对迁移命令族补聚焦契约测试（输入 state + command →
断言 state 关键字段/事件日志尾项），迁移前后同一套测试必须全绿。

## 4. 两条路线（待用户裁决）

### 路线 A——渐进减压（建议，低险）
不追求 <1200 行硬指标，改为：
1. 继续「薄转发」模式：把整族命令迁到新规则模块（如
   `rest_command_rules.gd` 收 休整族 280 行、`shop_command_rules.gd` 收
   商店族），主文件 `_dispatch` 只留一行转发（先例：v2 命令族 14 条）。
2. 共享 helper（`_rejected/_accepted/_event`）原地不动——主文件保留它们，
   外迁模块改调 resolver 的 public 版（GDScript 无私有，等于现状公开化，
   但**单一真值不动**，行为零变化）。
3. 每族一个 worktree 批次（2-4h/批），迁移前后跑该族契约测试 + 全量。
4. 目标从「<1200 行」改为「**主文件 ≤ 1700 行 + 命令面契约测试全覆盖**」，
   视后续演进继续收窄。
风险：低-中。行为零变化靠「纯搬移不重构 + 同测试双跑」。

### 路线 B——硬切到 <1200（照工单原验收，高成本）
按 8 族分批搬移（4-6 个 worktree 批次，每批携带私有依赖集），
每批后全量验证；最终 resolver ≈ dispatch + 共享 helper + 门面。
风险：高。共享 helper 连锁搬移易破坏 GuInstance 同步与 rest 门禁；
预估 8h+ 且中途任一行为回归排查成本大。收益仅为行数指标。

## 5. 建议

**走路线 A**，理由：(1) 与历次成功外迁模式一致；(2) 行为零变化、
可逐族验收；(3) 避免为行数指标承担确定性状态机的回归风险；(4)
<1200 行硬指标不服务任何玩家可见质量。首批候选 = **休整族**
（边界最清晰：`rest`/`upgrade_card`/`remove_card`/`remove_imprint`/
`remove_curse`/`wash` 门禁与 `_consume_rest_visit` 自洽，且休整节点 UI
契约已有专门约束）。

## 6. 首批执行清单（路线 A，休整族，worktree）

1. 补契约测试 `tests/unit/test_resolver_rest_command_contract.gd`：
   六命令各自 state 前置（fresh/已访问）→ 断言 ok/拒绝原因 + 事件日志尾项。
2. 建 `scripts/domain/rest_command_rules.gd`：`execute_rest(state, command,
   catalog)` + 族内函数纯搬移（不改逻辑），私有常量（REST_* / BODY_IMPRINTS
   依赖项）随迁或引主文件 public 化。
3. resolver `_dispatch` 的 `rest` 族 6 条改一行转发；主文件删族内函数。
4. 迁移前后双跑契约测试 + 全量 unit/integration 同基线。
5. 合入 master 后按同法推进商店族。
