# Handoff · Web parity slice 07 · Shop stock

```text
TASK web-parity-slice-07
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 Godot 黑市货架规则迁入 Web：按层货架、确定性洗牌、最高档保底、流派蛊保底与层价。

DELTA
+ js/shop_rules.js：移植 shop_slot_count / shop_goods_pool / seeded shuffle / shop_stock / shop_layer_price / shop_offer_is_stocked。
+ tests/shop_rules.test.mjs：覆盖货/服务分流、数量、确定性、保底、层价、生成数据引用完整性，以及首局节点的 Godot 64 位 seed 流对照。
~ js/journey.js：坊市改为“本层货架 + 蛊方柜台”；服务不占货架位；非蛊方服务不再展示或可购买；展示价与实收价统一走层价。
~ js/main.js：购买按层价扣元石，并把实际成本写入事件日志。
~ js/describe.js：补木道中文名。
~ tools/build_data.mjs：只导出 purchase / material_purchase / gu_fang_unlock 共 28 条 shop offers；清理 NPC 货架中的旧服务引用；机制覆盖清单更新。
~ js/data.js：重新生成。

VERIFY
data: node tools/build_data.mjs → gu 65 / enemies 14 / shopOffers 28
      唯一漂移：thunder_crown_wolf counter_status="sparked" 尚无规则实现（既有问题）
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs tests/rules.test.mjs tests/shop_rules.test.mjs
result: PASS 32/32
syntax: node --check main / journey / shop_rules / rules / run_rules / battle / build_data → PASS
diff-check: git diff --check -- game/wenzhen-web-lab → PASS
godot-parity: seed 101 + node beast_swarm_pass + layer 1
  Godot: ["purchase_jade_skin_gu","purchase_stone_shell","purchase_boar_king_tusk","purchase_mending_grass"]
  Web:   same
browser: PASS；第 1 层显示 4 件货架物品与蛊方服务，货架顺序与 Godot 一致，青藤蛊显示木道，控制台 0 error

RISK
1. L0 裁决（2026-09-20）：除蛊方服务外，不继承 Godot 的服务型系统与动态难度；资源交换、寿元交易、以物易物、洗恶名、补魂丹与配方解锁均未接入。
2. 未接 notoriety / revisit / contract 三类价格修正；当前层价只含 pacing.layers.shop_price_pct。
3. 工作树包含此前未提交改动，未 commit / push。

NEXT
1. 按 L0 指定范围继续移植下一批 Web parity 模块；服务型系统与动态难度不进入实现。
```
