# 开源参考调研 + 一项实测缺陷（2026-09-10）

> 目的：为「敌人按层随机（E6）」与「商店上架/保底（E7）」找优质开源参考，分析其实现思路与设计模式，并落到本项目。
> 附：调研过程中对**本项目自身随机数实现**做的对照实测，发现一项已生效的缺陷（§6），影响面大于本次两个需求。

---

## 1. 调研方法与限制（如实说明）

| 项 | 情况 |
|---|---|
| GitHub 连接器（MCP） | 状态显示 `connected`，但实际调用返回 `{"error":"unauthorized"}`，**不可用** |
| `gh` CLI | 未登录（`You are not logged into any GitHub hosts`） |
| 最终采用的通道 | 直连 `api.github.com`（未认证，60 次/小时），逐文件走 contents 接口取源码 |
| `raw.githubusercontent.com` | **被网络阻断**（`http=000`），故不能直接拉 raw 文件 |
| 许可核对 | 逐个查 `license.spdx_id`（见 §2，其中一个是**传染性许可**，已标注） |

> 结论：本次分析基于**真实源码**（共取回 11 个文件、约 60KB），不是 README 转述。取回的源码存放于 `~/gh_src/`（仓库外，未入库）。

---

## 2. 参考项目清单（按相关性排序）

| 项目 | Star | 许可 | 最近推送 | 相关性 |
|---|---|---|---|---|
| **DesirePathGames/Slay-The-Robot** | 277 | **MIT** | **2026-09-10（今天）** | ★★★ 主参考。Godot 4 肉鸽构筑框架，含命名随机轨道、权重表、池取、软保底、拦截器 |
| guladam/deck_builder_tutorial | 449 | **MIT** | 2024-10-16（停更） | ★★ 对照参考。商店/遗物/事件池实现，GDScript 同语言，可直接比对 |
| db0/godot-card-game-framework | 1388 | **AGPL-3.0** | 2025-05-20 | ⚠️ **仅看思路，禁止搬代码**（AGPL 传染，会让整个项目被要求以 AGPL 开源） |

被筛掉的对象（records for completeness）：`gacha pity system` 类仓库 star 全在 0–14，属玩具项目；`weighted random selection library` 类 0–2 star。**不给它们凑数。**

---

## 3. 参考 A（主）：Slay-The-Robot 深读

### 3.1 命名随机轨道（`autoload/Random.gd` + `data/prototype/PlayerData.gd`）

它把随机切成 **26 条命名轨道**（注释里明确列出）：`rng_world_generation` / `rng_events` / `rng_event_pool` /
`rng_shuffle` / `rng_card_drafting` / `rng_reward_card_drafts` / `rng_reward_money` / `rng_shops` /
`rng_enemy_spawning` / `rng_enemy_health` / `rng_targeting` / `rng_attack_damage` ……

**切分粒度是"按消费语义"，不是按系统。** 这是关键设计判断：新增一处无关抽取（比如加个特效随机）不会移动别的抽取的序列。

```gdscript
func get_player_rng(rng_name: String) -> RandomNumberGenerator:
	if player_rng.has(rng_name):
		return player_rng[rng_name]
	var rng := RandomNumberGenerator.new()
	rng.seed = player_run_seed          # ← 所有轨道同种子
	player_rng[rng_name] = rng
	return rng
```

> **它的瑕疵**：所有轨道用**同一个种子**，只有"已消费次数"不同。因此两条轨道在**同等消费次数**下会产生相同序列——存在隐蔽相关性。
> **本项目已经更正确**：`SeededRoll.mixed_seed(seed, salt, tick)` 把 salt 混进种子，不同轨道（不同 salt）天然去相关。
> **可借鉴的只有"轨道命名与切分粒度"**，实现不要抄。→ 落到 T1/T2：给商店、敌人各用独立 salt 字符串即可（本就是设计）。

### 3.2 权重表枚举 + 单一抽取函数（`Random.gd:123-151`）

```gdscript
enum CARD_DRAFT_TABLE_TYPES {STANDARD, MINIBOSS, BOSS, SHOP}
const CARD_DRAFT_RARITY_WEIGHTS := {
	CARD_DRAFT_TABLE_TYPES.STANDARD: {COMMON: 55, UNCOMMON: 43, RARE: 2},
	CARD_DRAFT_TABLE_TYPES.MINIBOSS: {COMMON: 50, UNCOMMON: 40, RARE: 10},
	CARD_DRAFT_TABLE_TYPES.BOSS:     {COMMON: 0,  UNCOMMON: 0,  RARE: 100},
	CARD_DRAFT_TABLE_TYPES.SHOP:     {COMMON: 55, UNCOMMON: 40, RARE: 5},
}
```

三个可直接吸收的点：

1. **用"权重 0"表达"不出"**（BOSS 表），比在代码里写 `if is_boss:` 特判干净得多。
2. **商店用独立权重表**（`SHOP` 表与 `STANDARD` 不同），而不是在抽取函数里加分支。
3. **商店显式关掉保底**：`generate_rarity_weighted_card_draft(rng_shop, COUNT, SHOP, false)` ——
   第 4 参 `use_pity_system = false`。**保底只给"白给的奖励"，商店不给**。这是有价值的设计判断（见 §7.4）。

### 3.3 软保底 / pity system（`Random.gd:167-208`）

```gdscript
var player_rare_card_modifier_current: int  # float 累计量，每抽到非稀有 +1.5
loot_table[rare]   = loot_table[rare]   + player_rare_card_modifier_current
loot_table[common] = loot_table[common] - player_rare_card_modifier_current
```

**不是"第 N 次必出"的硬台阶，而是"越抽不到、概率越高"**（软保底）：曲线平滑、没有计数器的机械感。

> **它的瑕疵（必须避免）**：`loot_table[common]` 没有 `max(0, ...)` 保护，**可能变负**；
> 而它的 `get_weighted_selection` 用累加桶、未处理负权重 → 桶区间会错乱。
> 借鉴时**必须 clamp 到 ≥0**。

### 3.4 "洗牌取前 N"（`shuffle_slice_array`）

```gdscript
var new_array = Random.shuffle_array(rng, array)
new_array = new_array.slice(0, clamp(index, 0, len(new_array)))
```

比"加权抽 N 次 + 去重循环"更好：**天然不重复**、无需去重、O(N)。
（参考 B 的商店也用同一手法：`RNG.array_shuffle(available); .slice(0, 3)` —— **两个独立项目共识模式**，可信度高。）

### 3.5 池数据模型：id 列表 + **显式 fallback**（`data/readonly/EventPoolData.gd`）

```gdscript
@export var event_pool_event_object_ids: Array[String] = []
@export var event_pool_fallback_event_object_id: String = ""   # 池空时的兜底
```

**池空必须有兜底 id，而不是返回空。** 这是"池"这层抽象里最容易被漏掉的一环。

### 3.6 池取（pool pull）通用函数（`PlayerData.gd:447`）

```gdscript
func get_next_artifacts_from_pool(artifact_count, artifact_rarities,
        use_rarity_ordering := false, from_back := false, mutate_artifact_pool := true)
```

一个函数里把四个维度参数化：
- `from_back`：**商店从池尾取、Boss 从池首取** —— 同一池按来源分端消费，减少互相干扰；
- `use_rarity_ordering=true`：**穷尽该稀有度，找不到再回退其它稀有度** —— 这就是"通用保底"；
- `mutate_artifact_pool=false`：**预览不消耗池**（为 UI 预览与实取分离）；
- `artifact_rarities`：按稀有度集合过滤来源（商店专用档 / Boss 专用档）。

### 3.7 层（Act）声明"难度分池"（`data/readonly/ActData.gd:19-32`）

```gdscript
@export var act_easy_combat_event_pool_object_id: String = ""
@export var act_hard_combat_event_pool_object_id: String = ""
@export var act_non_combat_event_pool_object_id: String = ""
@export var act_miniboss_event_pool_object_id: String = ""
@export var act_boss_event_pool_object_id: String = ""
```

配合 `ActionGenerateAct.gd`：生成地点时**只抽"池 id"**：

```gdscript
location.location_event_pool_object_id = act_data.act_easy_combat_event_pool_object_id
...
if rng_world_generation.randf() < location_non_combat_event_rate:
	location.location_event_pool_object_id = act_data.act_non_combat_event_pool_object_id
```

**节点不写死具体敌人，只写"属于哪个难度池"**；具体内容进入时才抽。
它靠 `location_obfuscation_rate`（迷雾率）回避"地图预览必须准确"的压力 —— **与本项目已有的"未知类迷雾"是同一思路**。

### 3.8 商店库存：一次性闸门 + 可拦截投放（`ShopData.gd:51` / `ActionShopPopulateItems.gd`）

```gdscript
func visit_shop() -> void:
	if not shop_is_visited:
		var rng_shop := Global.player_data.get_player_rng("rng_shop")
		var cards := Random.generate_rarity_weighted_card_draft(rng_shop, GENERATED_CARD_COUNT, SHOP, false)
		var artifact_ids := Global.player_data.get_next_shop_standard_artifacts_from_pool(...)
		... 价格也各走一次 rng_shop ...
		ActionGenerator.generate_populate_shop_items(...)   # ← 投放是"可拦截动作"
		shop_is_visited = true
```

两点：
- `shop_is_visited` **一次性闸门**：进店生成一次、之后固定 —— 正是本项目要的"同节点货架固定"。
- 生成（算库存）与投放（放进店）**分离**，投放走**拦截器管线**，于是遗物能改店内容/价格
  （对应 STS 的会员卡 / 信使）。本项目有 `Resolver` 命令族模块，这个"修饰点集中在一处"的思路值得对齐。

---

## 4. 参考 B（对照）：deck_builder_tutorial 的正反两面

**反面（印证本项目现有方向是对的）**：

- `global/rng.gd` 全书只有**一个全局 RNG 实例**，所有抽取共用一条流；
- `EventRoomPool.get_random()` 直接 `event_rooms.pick_random()` —— **走 Godot 全局随机，不受种子控制** →
  同种子局面的事件房**不可复现**；
- `array_pick_random` 用 `instance.randi() % array.size()` —— **模偏差**（与参考 A 同一问题）。

**正面（可借鉴）**：

- **内容自述可见性**：`relic.can_appear_as_reward(char_stats)` + `relic_handler.has_relic(relic.id)`
  用**谓词过滤候选**，把"能不能出现"的规则放在内容对象自己身上。
- **遗物挂钩子改店价**：`CouponsRelic.add_shop_modifier(self)` → 买下即改全店价格。
- 商店同样是 `shuffle + slice(0, 3)`，证明 §3.4 是社区共识做法。

---

## 5. 参考 C 的许可警告

`db0/godot-card-game-framework`（1388★，最大牌的那个）是 **AGPL-3.0**。
**AGPL 是强传染许可**：拷贝其代码会使整个项目受 AGPL 约束（含网络分发条款）。
→ **只可看设计思路，不可搬运代码。** 这也是本轮没有深入扒它的原因。

---

## 6. ⚠️ 本项目实测发现：`SeededRoll` 的 tick **不产生随机性，而是等差阶梯**

> 这一项由本次调研对照触发（三个参考项目都用 Godot 内置 RNG，本项目是手写 LCG；对照后决定实测）。

### 6.1 根因（三行代码的连锁）

1. `SeededRoll.mixed_seed(seed, salt, tick) = seed*1000003 + tick*97 + salt_hash(salt)`
   → **tick 以线性方式进入种子**；
2. `SeededRng._init` → `abs(seed) % 2147483647`；`next_index` → **只走一步** LCK：
   `state = (state * 48271) % M`；
3. 仿射变换下，**连续 tick 的中间状态恒差一个常数** `97 * 48271 mod M = 4,682,287`。

于是 `index(bound, seed, salt, tick)` 在连续 tick 上**恒差 `4,682,287 mod bound`**：

| bound | 每 tick 的固定偏移 |
|---|---|
| 4 | +3 |
| 7 | +1 |
| 100 | +87（等价 −13） |

**`tick` 这个本该"去相关"的参数，实际让相邻抽取变得最大相关。**

### 6.2 实测证据（复刻真实调用路径）

```
roll_chance(100, seed, salt="loot:hazard_toll", bound=35) 逐次判定：
  百分点: [15, 2, 89, 76, 63, 50, 37, 24, 11, 98, 85, 72, 59, 46, 33, 20, 7, 94, ...]
  命中  :  1  1  0   0   0   0   0   1   1   0   0   0   0   0   1   1   1   0 ...
```

- 百分点每次**恰好 −13（mod 100）** —— 一眼可见的阶梯；
- 命中序列是刚性循环：`1100000 1100000 1110000 …`（可肉眼读出周期）；
- 400 次判定的"连续命中/未命中"游程：`[2,5,2,5,3,5,3,5,2,5,3,5,3,5,3,5,2,5,...]`
  —— **只出现 2/3/5，没有 1、没有 4+**（真实二项分布必然出现长度 1 与长串）；
- **命中率 34.5%，期望 35%** —— 平均值是对的，**这正是它一直没被发现的原因**。

对照（同一 LCG 但**连续推进**、不让 tick 等差）序列正常：`[15,78,85,57,6,0,34,37,71,41,...]`。

### 6.3 影响面（已生效，非潜伏）

`SeededRoll.index(..., tick = state.event_log.size())` 已在 **3 处生产代码**：

| 位置 | 用途 |
|---|---|
| `scripts/domain/loot_resolver.gd:274` | 掉落抽取 |
| `scripts/domain/economy_rules.gd:54` | **概率判定 `roll_chance`** |
| `scripts/domain/dda_resolver.gd:148` | 动态难度换牌 |

`tick = event_log.size()` ⇒ **每次事件 +1** ⇒ 就是"连续 tick"。
另 `scripts/domain/map_generator.gd:44` 用的是"单实例连续推进"（**实测正常**），故已落地的地图生成不受此缺陷影响。

**为什么测试没抓到**：现有测试只断言**确定性**（`test_same_seed_same_category_route` 之类），
从不断言**分布/独立性**。平均值正确 + 可复现 = 测试全绿。

### 6.4 修复选项（未实施，等你定）

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（最小）** | 让 tick **非线性**进入：先对 tick 做一次混合（如 `splitmix` 式 finalizer 或复用 `salt_hash` 打散）再相加 | 保留现有公式常数与 API；**所有既有种子的抽取结果会变**，需重跑依赖固定结果的测试 |
| **B（不用 tick）** | 每 `(seed, salt)` 建一个 `SeededRng` 并**连续推进** t 次（已验证该路径健康） | 调用方需持有实例或重放 t 步（t 很小，O(t) 可接受） |
| **C（换引擎 RNG）** | 用 Godot 内置 `RandomNumberGenerator`（PCG64）以 `mixed_seed` 为种子，`randi_range` 取值 | 统计质量最好、顺带消除模偏差；同样会改变既有结果；与三个参考项目做法一致 |

> 三种都会**改变现有种子的产出**（地图布局 / 掉落 / 概率判定），因此这是一次**需要你拍板的基线变更**，
> 不能顺手做。同时建议补一条**分布/独立性测试**（如 2-gram 卡方），否则同类问题还会再溜过。

---

## 7. 对已排出任务卡的修订建议

### 7.1 T1（E6 敌人按层随机）

| 原方案 | 修订 | 理由 |
|---|---|---|
| 抽取用 `SeededRoll.index(..., tick)` | **先修 §6 或改用方案 B**，否则"随机"会是等差阶梯 | §6 |
| 点位敌人池 = 现有的单点指定 | 采纳 §3.7：**点位写"难度/主题池 id"，由层决定难度档**；池来源参考 §3.5 的"列表 + fallback" | 参考 A |
| 抽取 = 加权重采样（允许重复） | **保持**。敌人允许重复，加权重采样是对的（商店才需要"不重复"） | §3.4 的适用边界 |
| 无兜底 | 池空/候选不足时**取 fallback 并告警**，不静默返回空 | 参考 A §3.5 |

### 7.2 T2（E7 商店上架）

| 原方案 | 修订 | 理由 |
|---|---|---|
| 加权抽 N 次 | 改 **`shuffle → slice(0, N)`**（两个项目共识），天然不重复 | §3.4 |
| 未提"同架不重复" | **补上**（洗牌天然解决） | 参考 A 的 `card_ids_in_draft.has()` 去重循环 |
| 保底 = 硬补一件本层最高档 | 见 §7.4 决策 | — |
| 权重表内嵌 | **按用途分表**（商店一张、战斗奖励一张），不在代码里加 `if` | §3.2 |
| 池取可选 | 若要"跨店不重复"，用 §3.6 的 pool pull + **从 run 状态推导游标**（如按已访问商店次数），仍然不占存档字段 | §3.6 |

### 7.3 通用（两个任务都适用）

- 权重动态调整**必须 clamp ≥0**（参考 A 的负权重隐患）。
- 断言里补**分布类**检查（不只确定性），否则刚修好的东西会再退化。

### 7.4 需要你拍板的新增项

| # | 问题 | 我的建议 |
|---|---|---|
| **D-G** | 是否先修 §6 的随机数缺陷？用 A / B / C 哪个方案？ | **方案 B**（改调用方式、不改公式常数，影响面最小）；或 **C**（质量最好，接受结果变化） |
| **D-H** | 商店要不要保底 | **要硬保底**（本层最高档）。理由：本项目商店是"有限的 4–6 件货架"，抽不出像样的这次就白来；而参考 A 是"固定 N 个卡位 + 商店专用权重表"，情况不同。软保底记为后续增强（它需要跨店累积状态，与"不占存档字段"冲突） |
| **D-I** | 敌人池的组织方式 | 给敌人与点位加**主题标签**成池（此前已提的默认），叠加参考 A 的"层决定难度档" |

---

## 8. 结论

1. 两个需求的**技法**在开源里有成熟答案：`shuffle→slice(N)`、权重表枚举、池 + fallback、
   层→难度分池、一次性访问闸门、软保底，**都能直接落到 T1/T2**。
2. 但更重要的是：**对照三个参考项目后实测出本项目随机数的一处真实缺陷**（§6），
   它已经在掉落 / 概率判定 / 换牌三处生效，且测试结构性地抓不到。
   **先修它，再做 E6/E7**；否则两个新功能的"随机"会建立在等差阶梯上。
3. 参考 C 是 AGPL，**只可看思路**。
