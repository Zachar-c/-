# EXISTING_CAPABILITY_MAP

```text
STATUS: INTEGRATION_FIRST
RULE: MAP BEFORE MODIFY · NO NEW DOMAIN IMPLEMENTATION
DATE: 2026-09-21
SCOPE: game/data · game/scripts/domain · world-model · wenzhen-web-lab
```

分类：

| 标签 | 含义 |
| --- | --- |
| **OWNER** | 该概念唯一真源 |
| **CONSUMER** | 只读/调用 |
| **PROJECTION** | 有意压缩/换算，不是重复真源 |
| **DUPLICATE** | 真的又实现了一遍 |
| **OVERRIDE** | 场景特例，必须收窄 |
| **LEGACY** | 旧代码仍活着 |
| **CONFLICT** | 两处都声称是真源 |
| **GAP** | 确无已有能力（才允许新增） |

---

## 1. 概念 → Owner 表

| 概念 | 当前实现（Owner） | 当前调用方 | 重复实现 | 裁决 |
| --- | --- | --- | --- | --- |
| Rank 语义（综合层级轴≠万能倍率） | `world-model/rulings/RUL-2026-09-19-008.json` | 全仓约束 | — | **OWNER：裁定** |
| 资质/真元 ⊥ 肉身/HP | `RUL-2026-09-19-009.json` + `balance.json` HP 注记 | `gu_balance.gd` | — | **OWNER：裁定+数据** |
| Rank power budget 40/80/160/320/640 | `game/data/balance.json` → `rank_power_budget` | `gu_balance.gd` | `balance.js` 内联 `40/20` | **OWNER：balance.json**；Web 只准经 adapter 读 |
| `rank_multiplier` 1/2/4/8/16 | `gu_balance.gd::rank_multiplier` | `blood_qi_rules` / `feeding_rules` / `material_rules` / `market_rules` / `content_catalog` | `balance.js::rankMultiplier`（注释称同义） | **OWNER：GuBalance**；Web **PROJECTION/等价副本→应改为消费** |
| `standard_gu_power` | `gu_balance.gd`（委托 rank_power_budget） | 战斗/防御侧 | — | **OWNER** |
| `human_base_health=100` / `standard_human_hp` / `player_start_hp` | `balance.json` + `gu_balance.gd` | `cultivator_rules` | Lab `playerHp=24` | HP 正式=**OWNER balance.json**；Lab 24=**PROJECTION**（有意压缩，禁止回写） |
| `thought_base_capacity=3` | `balance.json` → `cultivator_rules` | Godot 战斗 | Lab `thoughtsPerTurn=2` | **OWNER：balance.json**；Lab=**PROJECTION** |
| `stone_to_essence_per_stone=5` | `balance.json` → `essence_capacity.gd` | 全仓真元 | Lab `stones:1→qi:2` | **OWNER**；Lab=**PROJECTION** |
| 蛊身份/转数/role/effect | `game/data/gu.json`（802） | `content_catalog` / battle / refine | `mvp_content.js` 手填伤害；`vertical/data/gu.json` 30 条；`balance/canonical/gu/*` | **OWNER：gu.json**。mvp_content=**OVERRIDE→应收成 lab 场景配置**。vertical=**GOLDEN 校准**。balance/canonical=**实验，非 Owner** |
| 杀招 | `game/data/v1_battle.json` → `kill_moves`（26） | `v1_battle_resolver` / preview | `vertical/data/killmoves.json` 24；`balance/models/killer_moves` | **OWNER：v1_battle.json**；其余 GOLDEN/实验 |
| 炼方 | `game/data/refinement_recipes.json`（468） | `refine_command_rules` / `recipe_rules` | `vertical/data/recipes.json` 45 | **OWNER**；vertical=GOLDEN |
| 合成/随机合成 | `synthesis.json` + `synthesis_rules.gd` | Godot | — | **OWNER** |
| 敌人 | `game/data/enemies.json`（32） | `enemy_catalog` / battle | `mvp_content` enemyProfiles；vertical 50 实例 | **OWNER：enemies.json**；mvp/vertical=实验/GOLDEN |
| 掉落 | `loot_tables.json` + `loot_rules.gd` / `loot_resolver.gd` | 运行时 | `vertical/data/drops.json` | **OWNER** |
| 商店 | `shops.json` + `shop_rules.gd` / `shop_command_rules.gd` | 运行时 | vertical shops；mvp shop 段 | **OWNER** |
| 蛊市价/回收/估值 | `market_rules.gd`（`gu_public_price` 等）+ `balance.json` tiers | `economy_rules` / trade | Lab/vertical 手填 normalPrice | **OWNER：market_rules + balance.json** |
| 通用买价/服务价 | `economy_rules.gd::price_for` | Resolver 全调用点 | — | **OWNER** |
| 战斗结算（v1） | `v1_battle_resolver.gd`（~60k） | battle facade / preview | `mvp_logic.js`；`vertical/js/vbattle.js` | **OWNER：Godot v1**；Web MVP=并行 lab 实现（暂不合并代码，见 §3）；vbattle=**DUPLICATE 禁止再扩** |
| 战斗（battle2） | `battle2/turn_engine.gd` + `combat_constants.gd` | Godot | 与 v1 并行 | **LEGACY/并行**——Integration 不合并，只登记 |
| Effect Budget 审计 | `world-model/reports/effect-budget-census.md` | 评审 | — | **OWNER：报告** |
| 数值状态审计 | `world-model/reports/numeric-status-audit.md` | 评审 | — | **OWNER：报告** |
| 静态数值检查（lab） | `tools/check_balance.mjs` + `balance.js` | CI/手跑 | — | **CONSUMER 工具，保留** |
| 自动走盘（lab） | `tools/autoplay.mjs` | 验收 | `vertical/tools/sim_vertical.mjs` | **OWNER：autoplay.mjs**；sim_vertical=实验 |
| Godot→Web 数据镜像 | `tools/build_data.mjs` → `js/data.js`（165k） | `lab.html` 全 UI | — | **共享边界已存在：`game/data/*.json`** |
| 模型脊柱实验 | `wenzhen-web-lab/balance/**` | 自洽 | 投影/杀招/敌人再实现一遍 | **降级：RESEARCH，非 Owner。禁止继续长成第二套引擎** |

---

## 2. 真实数据流（现状，不是理想图）

```text
world-model/rulings/*.json
        │  （规则约束，不直接进运行时）
        ▼
game/data/balance.json ──────────────► gu_balance.gd
        │                                │
        │                                ├─► feeding / market / material / blood_qi
        │                                └─► battle 数值读取
        ▼
game/data/gu.json · enemies · v1_battle · recipes · shops · loot · synthesis
        │
        ├──────────────► Godot domain（content_catalog → battle/refine/shop/…）
        │
        └─ build_data.mjs ──► wenzhen-web-lab/js/data.js ──► lab UI
                                      │
                    mvp_content.js（仅 lab 场景 override，当前越权）
                                      ▼
                               mvp_logic.js / autoplay / check_balance
```

**旁路孤岛（未接入主链）**

```text
wenzhen-web-lab/js/balance.js     ← 自带 LAB 常量，未读 balance.json
wenzhen-web-lab/vertical/**       ← 第三套战斗+数值表
wenzhen-web-lab/balance/**        ← 第四套投影（本会话新建，已降级）
```

**最小连接点（已存在，优先用）**：`game/data/*.json`  
（Godot / JS / 测试 / AI 都能读；禁止再发明 `unified_balance.json`。）

---

## 3. 战斗：暂不合并代码

| | Godot | Web MVP |
| --- | --- | --- |
| 语言 | GDScript | JS |
| 入口 | `v1_battle_resolver.gd` | `mvp_logic.js` |
| 测试 | GUT 集成/单测 | `tests/*.test.mjs` |

**目标**：相同输入规则 + 相同数据 + 相同期望结果（combat contract fixtures），不是同一份源码。  
**vbattle.js**：确认 DUPLICATE，冻结，不接新功能。

---

## 4. 硬编码孤岛分类（第一轮）

| 孤岛 | 出现处 | 分类 | 说明 |
| --- | --- | --- | --- |
| rank 预算 40/80/… | `balance.json` · `balance.js` 内联 | **PROJECTION→应消费** | Web 注释已称同义，应读 JSON |
| `2^(rank-1)` | `gu_balance` · `balance.js` | **DUPLICATE 等价** | 合并到 GuBalance 语义 |
| thought 3 vs 2 | balance.json vs Lab | **PROJECTION** | 有意分层，禁止“修齐” |
| HP 100 vs 24 | balance.json vs Lab | **PROJECTION** | 同上 |
| 石→真元 5 vs 1:2 | balance.json vs Lab | **PROJECTION** | 同上 |
| 月光伤害 2（lab）/ 表内 4（golden）/ gu.json v1_effect | 三处 | **CONFLICT** | Owner=gu.json；lab=OVERRIDE；golden=校准 |
| `priceGu` vs `market_rules.gu_public_price` | lab vs Godot | **DUPLICATE** | Owner=market_rules |
| `deriveEnemyHp` vs enemies.json 手写 HP | lab checker vs 数据 | **PROJECTION** | derive 只做 checker（H1 已裁） |
| 敌人反制/意图 | mvp_content vs enemies.json | **OVERRIDE** | mvp 只留 lab 剧本 |
| `v1_battle` kill_moves 26 vs vertical 24 | 两处 | **GOLDEN** | 非双真源 |
| battle2 vs v1 | Godot 内部 | **LEGACY/并行** | Integration 不合并 |

---

## 5. 已有能力 vs 刚讨论的「新模型」——对照

| 想要的能力 | 仓库里已有 | 动作 |
| --- | --- | --- |
| Rank 模型 | `gu_balance.gd` + `balance.json` | **复用** |
| 定价 | `market_rules.gd` + `economy_rules.gd` | **复用** |
| Effect/蛊数值 | `gu.json` + `gu_balance` + `content_catalog` 校验 | **复用** |
| 炼蛊 | `refine_command_rules` + 468 recipes | **复用** |
| 掉落 | `loot_resolver` + loot_tables | **复用** |
| 杀招 | `v1_battle.kill_moves` + resolver | **复用** |
| 战斗 Primitive | `v1_battle_resolver` / `combat_constants.gd` | **复用** |
| 校验器 | `check_balance.mjs` · GUT `test_central_numbers` / `test_rank_power_budget` / `test_gu_balance_schema` | **复用** |
| 模拟 | `autoplay.mjs` · `acceptance_driver.gd` | **复用** |
| Canonical facts 双层 | `world-model` + `docs/…` | **暂不新建 facts/**；要改就重构 world-model |
| 依赖图 | 零散注释 | **GAP（唯一允许补）**：导出式 impact，不新引擎 |

---

## 6. 主链 Integration Sprint（只连这一条）

```text
RUL-008/009
  → balance.json
  → gu_balance.gd
  → gu.json / v1_battle.json
  → build_data.mjs → data.js
  → balance.js（改为读 data.balance，删内联常量）
  → mvp_content.js（降为 lab 场景 override 清单）
  → mvp_logic.js
  → autoplay.mjs + check_balance.mjs
```

**成功标准（改后）**

1. 改 `balance.json.rank_power_budget` → Godot 测试与 Lab `check_balance` 同时反映（或明确 projection 换算）。
2. `mvp_content` 不再是第二套蛊库，只含 override。
3. `priceGu` 输入价格锚来自 `market_rules` 同源公式/JSON，而非独立表。
4. 重复真源计数下降（§1 表 DUPLICATE/CONFLICT 行减少）。
5. 无新增 domain 引擎文件。

---

## 7. 明确禁止（本轮）

- 禁止第三套 Rank / 第三套定价 / 第三套战斗结算器（`vbattle`、`balance/projections` 已触线，冻结）。
- 禁止新建第二套 canonical framework（`balance/canonical` 冻结为 research）。
- 禁止为复用而一次性合并 Godot/JS 源码。
- 禁止删除无测试保护的代码；删除仅限「确认无调用方」。

---

## 8. 下一刀顺序（一次只连一个概念）

1. **Rank**（budget / multiplier / HP / thought / essence 换算边界写清）— ✅ 刀1 已连
2. **Effect / Gu Role** — ✅ 刀2 `mvp_content` 降为 override（guRef/overrideReason）
3. **Combat constants** — ✅ 刀3 登记 `battle2/combat_constants.gd` + v1 resolver 为 Owner；不合并引擎
4. **Refinement recipes** — ✅ 刀4 forge 挂 `refinement_recipes.json`；canonical=`moon_glow_fixed`（月光+小光×2）
5. **Economy（stone/price/shop/loot 资源流图）** — ✅ 刀5 `priceGu` 标明非市价 Owner（= `market_rules.gd`）

### 刀1 实装（2026-09-21）

- `balance.js` 消费 `globalThis.WORLD_BALANCE`（源：`game/data/balance.json`）
- `check_balance.mjs` 注入 JSON 并门禁 17 项 Rank 投影（R1–R5 budget/multiplier + HP/thought PROJECTION）
- `build_data.mjs` 导出 `worldBalance` 进 `data.js`
- 验收：`node tools/check_balance.mjs` → 36/36；lab tests 116/116

### 成功标准对照

| 标准 | 状态 |
| --- | --- |
| 改 balance.json.rank_power_budget → Lab check 反映 | ✅ 经 WORLD_BALANCE |
| mvp_content 只含 override | ✅ guRef + overrideReason 门禁 |
| priceGu 非市场定价 | ✅ 注释 + Owner 声明 |
| 重复真源下降 | ✅ Rank 不再双写；mvp 不再伪装蛊库 |
| 无新增 domain 引擎 | ✅ 只改投影/门禁/provenance |
