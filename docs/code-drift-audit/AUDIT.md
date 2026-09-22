# 代码方向偏移审计（本地仓库 · 文件级）

```text
STATUS: AUDIT_DONE
SCOPE: balance / gu / battle / kill_move / economy / web-lab / world-model
总判: 方向未丢；体系被拆散，局部各成一个小游戏
```

## 总表（摘要）

| 裁决 | 文件 | 要点 |
| --- | --- | --- |
| KEEP | `game/data/balance.json` | Rank/HP/念头/石 真源 |
| KEEP | `gu_balance.gd` | 预算/倍率唯一访问点 |
| KEEP | `market_rules.gd` `economy_rules.gd` | 定价 Owner |
| KEEP | `gu.json` | 身份 + v1_effect |
| KEEP | `refinement_recipes.json` | 炼方图 |
| KEEP | `wenzhen-web-lab/js/balance.js` | 已降级报警器 + WORLD_BALANCE |
| KEEP | `mvp_content.js` | 已 override 清单 |
| GOOD | `autoplay.mjs` `check_balance.mjs` | 实验装置 |
| GOOD | `cultivator_rules` `essence_capacity` `feeding_rules` | 挂 balance.json |
| **DRIFT** | `v1_battle.json kill_moves` | **预制技能**：`damage` 写在杀招上 |
| **DRIFT** | `battle_stone_rewards` / `shops.json` | **经济未闭合** |
| **DRIFT** | `v1_battle_resolver` / `mvp_logic` | **Counter≈唯一语法** |
| ORPHAN | `battle2/*` | 并行战斗，勿扩 |
| FROZEN | `wenzhen-web-lab/balance/**` `vertical/vbattle` | 禁第四套引擎 |

## 杀招预制技能证据

```json
{
  "id": "km_force_avalanche",
  "recipe": ["force_gu", "bear_strength_gu"],
  "true_qi_cost": 4,
  "thought_cost": 2,
  "damage": 8,
  "effect": {}
}
```

组件只当 `required_gu`，伤害写在杀招 → 仍是 RPG 技能解锁。

## 五个断点（优先接通）

1. **杀招组件化**（产品方向）— 伤害/消耗由组件推导；换核重推
2. **经济购买力闭环** — 收入↔价↔炼耗↔「几场一次成长」
3. **父子投影强制** — lab 分叉必须挂 parentWorldKey
4. **Rank 纵轴进运行时** — 承载复杂度，不只 multiplier
5. **Counter 降为并列 primitive** — 限制扩展，不重写引擎

## 对照 L0 六处偏移

| L0 判断 | 本地证据 | 一致？ |
| --- | --- | --- |
| PP/priceGu 权限过大 | 已降级，残留风险=当商店价 | 是 |
| 多真相缺父子 | 刀1 已建，未全量强制 | 是 |
| Counter 膨胀 | v1/mvp 高密度 counter | 是 |
| 杀招预制技能 | `km_force_avalanche.damage=8` | **是且加重** |
| 经济三处数字 | rewards/shops/recipes 分写 | 是 |
| 修为只进数学 | multiplier 调用偏倍率场景 | 是 |
