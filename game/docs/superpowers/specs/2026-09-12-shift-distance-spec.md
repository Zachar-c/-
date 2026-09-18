# 位移（shift）机制规格 —— 让「拉开距离」真正有意义

> ## ⚠️ 已被用户裁定推翻（2026-09-12 Q8）
>
> 「位移同比转化为防御力——目前不实现闪避、位移、攻击距离，通通转译为防御实现。」
> shift 结算已改为等量护盾（v1_battle_resolver shift 分支），position 不再推进，
> 本规格的距离减伤/敌人追击因 distance 恒 0 自动失效（死路径已于 2026-09-12 Q7 批次删除：_distance_adjusted_damage/_enemy_pursuit 及 cfg 三键）。
> 卡牌文字已改「退守：护盾 +N」。落位记录：plans/2026-09-12-shop-recipe-support-landing.md。

日期：2026-09-12
触发：真机验收反馈「那个位移一格，现在有什么实际意义吗？我感觉没有作用」
状态：待用户批准实施

## 1. 现状：位移是死数据

`v1_battle_resolver` 里 `player.position` 只有**写入**，全仓**无任何读取点**：

| 位置 | 行为 |
|---|---|
| `v1_battle_resolver.gd:77` | 战斗初始化 `"position": 0` |
| `v1_battle_resolver.gd:410` | `shift` 效果：`position += amount` |

配套事实：

- **敌人没有 position 字段**（`_build_enemies` 只出 id/label/hp/intent/shield/statuses），
  `enemies.json` 32 条敌人也**没有 range/distance 之类的字段**。
- `default_effect_by_role.movement = {"kind": "shift", "amount": 1}` —— 兜底就是 1 格，
  剑道 5 只 movement 蛊（1 转及 3 转）`amount` 全为 1，**不随转数放大**。
- 权威规格（`2026-09-01-gu-system-economy-combat-design.md`、`2026-08-25-mechanics-first-lockdown-design.md`）
  里**检索不到 movement / shift / 位移的定位描述** —— 这个效果当初只落了数据结构，
  没有落玩法语义。

⇒ 结论：玩家的观察完全正确。位移目前不产生任何结算后果。

## 2. 设计目标

1. 位移要有**可感知的战术收益**，但不是"无脑按"。
2. 收益必须**可被敌人抵消**，否则玩家一直 shift 就能无限减伤，破坏平衡。
3. 改动面可控：不新增敌人字段、不改存档结构、不动蛊虫数值。

## 3. 设计：拉开距离 = 本回合减伤，敌人回合末逼近

### 3.1 语义

`player.position` = **玩家相对交战点的距离**（带符号；正数表示拉开了 N 格）。
敌人视为固守在 0（不新增敌人 position 字段，保持最小改动）。

### 3.2 敌方攻击的距离减伤

敌人 `intent.damage` 结算前，按当前距离削减：

```
distance      = abs(player.position)
floor_damage  = ceil(base * (100 - shift_damage_reduction_cap_pct) / 100)
effective     = max(floor_damage, base - distance * shift_damage_reduction_per_step)
```

- `shift_damage_reduction_per_step`（默认 **1**）：每拉开 1 格减 1 点伤害。
- `shift_damage_reduction_cap_pct`（默认 **60**）：减伤封顶 60%，
  保证**任何距离下敌人仍能造成至少 40% 伤害** —— 距离是可拖延，不是免伤。

### 3.3 敌人追击（抵消）

敌人回合结束后，`player.position` 向 0 收敛 `enemy_pursuit_per_turn`（默认 **1**）格：

- 玩家 shift 1 格 → 距离 1 → 本回合减伤 1；
- 回合末敌人逼近 1 格 → 距离归 0；
- 想持续减伤，就得**每回合都投入念头**出一支 movement 蛊。

⇒ 位移蛊的定位变成：**用念头换减伤的战术位**，与 defense 蛊（护盾，不耗持续投入）
形成区分：护盾是一次性大额，位移是小额但可叠加、需要维持。

### 3.4 不影响的部分（明确边界）

- 只影响**敌人对玩家的攻击**（`intent.kind == "attack"`）；
  `seal` / `soul_drain` / `life_cost` 类意图**不吃距离**（封印与摄魂不靠近身）。
- 玩家自己的蛊虫攻击**不受距离影响**（否则位移会变成纯负面）。
- T15 刻痕通道是独立通道，与距离无关，互不干扰。

## 4. 决策点（建议默认值）

| # | 决策 | 建议 | 理由 |
|---|---|---|---|
| D1 | 减伤是**线性每格**还是**每格百分比** | **线性每格 1 点** | 线性对低伤敌人更友好、可预期；百分比会让高伤敌人收益畸高 |
| D2 | 减伤是否封顶 | **封顶 60%** | 避免"拉开距离 = 无敌" |
| D3 | 敌人是否追击 | **追击 1 格/回合** | 否则玩家一路 shift 即可永久减伤 |
| D4 | 是否给敌人加 position | **不加** | 最小改动；敌人固守 0，语义由玩家单侧位移表达 |
| D5 | 非 attack 意图是否吃距离 | **不吃** | 封印/摄魂/寿元损耗属"接触之外"的手段，吃距离会让位移过强 |
| D6 | 玩家攻击是否受距离惩罚 | **不受** | 否则位移蛊变成双刃剑，与"战术收益"目标冲突 |
| D7 | 是否随转数放大 shift amount | **本批不动** | movement 蛊 amount 全为 1 是既有数据口径，改它要同步改 T1 数值表 |

## 5. 实施落点

| 项 | 文件 |
|---|---|
| 配置键 | `data/v1_battle.json`：`shift_damage_reduction_per_step` / `shift_damage_reduction_cap_pct` / `enemy_pursuit_per_turn` |
| 减伤 | `scripts/domain/v1_battle_resolver.gd::_resolve_enemy_intent`（attack 分支，读 `battle.cfg`） |
| 追击 | `scripts/domain/v1_battle_resolver.gd::end_turn`（敌人意图结算后、刻痕结算前） |
| 测试 | `tests/unit/test_sword_school_gu.gd`（剑道 movement 蛊吃这套机制）+ 独立契约用例 |

## 6. 验收

1. 距离 0：伤害 = 原值（**行为保持红线**：未使用位移时逐点不变）。
2. 距离 N：伤害 = `max(ceil(base*0.4), base - N)`。
3. 距离拉到极大：伤害不低于 `ceil(base*0.4)`（封顶生效）。
4. 回合末距离自动 -1（敌人追击）。
5. 非 attack 意图（seal / soul_drain / life_cost）不受距离影响。
6. 玩家蛊虫伤害不受自身距离影响。
7. 全局回归：25 seed 扫 `reached_l5` / `entered_ending` 不退化；unit / integration 全绿。

## 7. 风险

| 风险 | 说明 | 应对 |
|---|---|---|
| 全局平衡偏移 | 所有流派都能用 movement 蛊减伤 | 减伤封顶 60% + 追击；25 seed 扫回归 |
| 位移蛊过强 | 只需 1 念头换 1 点减伤，可能不如护盾 | 与 defense 蛊对比：护盾 r3=5 一次到位；位移需持续投入 —— 定位不同，不必强行等价 |
| 与已有状态叠加 | 护盾、TRIGGER_COST、DDA 都在 `_damage_player` 路径上 | 减伤只改**传入的 amount**，不动 `_damage_player` 内部，避免叠加面扩散 |
| UI 不可见 | 玩家看不到"距离" | 建议后续在战斗快照暴露 `distance` 与减伤预览（本批先做领域层，UI 另开） |
