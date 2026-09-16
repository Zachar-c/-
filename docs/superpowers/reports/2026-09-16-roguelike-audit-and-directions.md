# 《蛊路求生》肉鸽要素系统调研 + 改造方向对比

> 日期：2026-09-16 · 性质：**只读调研**，本轮不修改任何生产文件。
> 证据标注：【实测】= 跑工具/解析数据得到；【代码】= 静态阅读确认；【推断】= 由前两者推导，待验证。
> 数值口径：`gu.json` 11746 行 / `refinement_recipes.json` 6720 行 / `enemies.json` 784 行，均为当前工作树。

---

# 一、现状梳理

## 1.0 总览：一眼看清哪里厚、哪里薄

| 肉鸽维度 | 现状强度 | 关键数字 | 判定 |
|---|---|---|---|
| 随机地图拓扑 | **强** | 5 层 × 8–11 行 × 2–6 节点，连边随机 | 已达标 |
| 随机敌人 | **中** | 32 敌人（common 13 / elite 12 / boss 7），E6 按层抽 | 池够，重抽已通 |
| 随机掉落 | **中** | 保底阈值 3（第 4 胜交付），按 tier 独立计数 | 机制在，物件维度薄 |
| 随机事件 | **极弱** | `events.json` **2 条** | **最大内容缺口** |
| 局内构筑（蛊） | **纸面强 / 实际中** | 802 蛊、468 配方、20 流派 | 维度被 5 role 默认值压平 |
| 局内构筑（杀招） | **弱** | **26 条固定配方**，非自由组装 | 支柱未兑现 |
| 局内构筑（遗物） | **极弱** | `relics.json` **2 个** | 几乎不存在 |
| 单局循环 | **强** | 5 层 → 关底 Boss → 升仙窗口 → 结局 | 结构完整 |
| 失败惩罚 | **强** | 死亡即清档，删进行中存档 | 标准硬惩罚 |
| 局外永久成长 | **零战力** | 图鉴/契约/手记/统计，无战力读点 | 符合红线，但无留存抓手 |

---

## 1.1 随机生成

### 1.1.1 关卡 / 地图拓扑

- **实现位置**：`scripts/domain/map_generator.gd`（393 行，纯静态类，无状态）
- **数据**：`data/pacing.json`（362 行，5 层裁定表）+ `data/nodes.json`（641 行，37 模板）
- **每局随机项【代码】**：层行数 8–11、每行节点数 2–6、入口数 1–2、连边（每节点 1–2 条）、
  非锚点槽的分类抽取与模板抽取
- **每局恒定项【代码】**：层数量 5、`category_weights`、anchors 模板与行位、
  rest 模板交替顺序、**关底 Boss 身份**、石预算、loot 权重、`shop_price_pct`
- **实测方差【实测】**（40 种子，E5a 门禁输出）：
  - 每层随机槽 battle 占比 σ ≈ 0.073，均值 0.553–0.594
  - **整局 battle 占比 σ 仅 0.032**（均值 0.577）——五层独立抽样把方差按 ≈√5 平均掉了

> ⚠️ **核心结论**：层内有方差、整局没有。任何只做「每层独立抖动」的改造都会被 √5 平均掉，
> 必须引入 **run 级相关分量**才能传导到体感。

- **耦合度：★★☆ 中**。上游被 `content_catalog.gd` 校验（1547 行，pacing 段），
  下游喂 `run_state.route` → 存档 → 地图快照。自身是纯函数、无状态，改动边界清晰；
  但 10 个测试文件调用 `MapGenerator.build`，回归面宽。

### 1.1.2 敌人

- **实现位置**：`scripts/domain/enemy_catalog.gd`（178 行）+ `map_generator._roll_enemy_for`
- **机制【代码】**：E6——战斗节点**且非锚点**时，按 `enemy_theme` + 层 `enemy_rank_min/max`
  重抽敌人；用 `mixed_seed` **独立派生流**，不消耗主 rng
- **权重**：`pacing.enemy_weights = {common 75, elite 25, boss 0}`
- **边界【代码】**：`instance_anchor == true` 的节点**免抽** ⇒ **5 个关底 Boss 台完全不参与随机**
- **耦合度：★☆☆ 低**。纯数据 + 单点注入，E6 已验证「加入后既有种子布局不变」。

### 1.1.3 掉落

- **实现位置**：`scripts/domain/loot_resolver.gd`（403 行，**唯一权威结算者**）+ `loot_rules.gd`
- **数据**：`data/loot_tables.json`（2535 行）
- **保底【实测】**：`pity.threshold = 3` ⇒ 计数 ≥3 时交付，即**第 4 个 Common 胜场**。
  `material_pity` 按 tier 独立计数（state.`material_pity_by_tier`）
- **材料带段【实测】**：`common → [crude]`、`elite → [plain, refined]`、`boss → [prized]`
  ⇒ elite↔common 互换**件数不变，变的是品质带段与蛊掉率**（6% vs 30%）
- **耦合度：★★★ 高**。`LootResolver` 是全局唯一结算出口，被战斗/探索/商店/事件共同依赖；
  Reachability 轨道明确把它列为红线对象。

### 1.1.4 事件

- **实现位置**：`data/events.json`（**19 行 / 2 条**）→ `dialogue_manager_adapter.gd`（187 行）
  → `action_preview_service.gd`（1110 行）
- **内容**：`gu_rot_pact`（带 `event_id`、`curse_bargain` 分支），`echo_cave`
- **校验骨架已存在【代码】**：`content_catalog.gd:180-199` 已校验 `kind` / `delayed_trigger` /
  `curse_bargain` / curse 引用 ⇒ **扩容的通路是通的，缺的只是内容**
- **地图接入**：unknown 分类池 13 个模板中仅 2 个是 `type: "event"`，其余是
  hazard / inheritance / earth_vein / wild_gu / seclusion
- **耦合度：★☆☆ 低**（数据侧）。新增事件 = 加 JSON + 过 catalog 白名单 + 领域层结算分支。

---

## 1.2 局内成长与构筑（Build）

### 1.2.1 蛊 + 合成（最厚的一层）

- **实现位置**：`refine_command_rules.gd`（799 行）、`synthesis_rules.gd`（170 行）、
  `gu_instance.gd`、`gu_balance.gd`；配方数据 `refinement_recipes.json`
- **规模【实测】**：蛊定义 **802**；合成配方 **468**，covering **440** 个不同产出蛊；
  流派 **20**（blood/qi/force/soul/refine/light/wisdom/dream/luck/sword/wood/fire/water/wind/gold/earth/slave/heaven/human/bone）
- **rank 分布【实测】**：1→220、2→157、3→180、4→97、5→147（+1 个异常 rank 10）

> ⚠️ **纸面厚度 ≠ 实际维度**。802 个蛊里**只有 57 个（7.1%）声明了显式 `v1_effect`**。
> 其余蛊并非不能打，而是走 `v1_battle.json` 的 `default_effect_by_role`【代码】：
> attack→strike 2 / defense→shield 3 / healing→heal 2 / movement→shift 1 / recon→marked 1。
> ⇒ **战斗效果的实际自由度被压到 5 个 role 默认值 + 57 个显式特例**，
> 而 `v1_effect` 的操作集在 Q8 已被**冻结为 5 种**（strike/shield/heal/status/weaken_intent）。
> 【推断】玩家感知到的"800 种蛊"在战斗层面远小于 800 种差异。

- **耦合度：★★★ 高**。Q8 Grammar V2 冻结区（"未来项禁令"：新操作/新 Buff/新触发器
  **不实现不预留**）。改蛊效果 = 撞冻结；改蛊数值 = 纯数据，安全。

### 1.2.2 杀招（核心支柱，未兑现）

- **实现位置**：`data/v1_battle.json` 的 `kill_moves`（**26 条**）；
  屏 `scripts/presentation/screens/kill_screen_view.gd`（176 行）；
  存档 `run_state.saved_combos`
- **结构【代码】**：每条杀招是**固定配方** —— `{id, label, tag, recipe: [蛊A, 蛊B], true_qi_cost,
  thought_cost, life_cost, damage, effect}`
- **UI【代码】**："研习录 3 卡 + 战斗栏位 3 槽"，只读快照、写走 commands
- **落差**：AGENTS.md 把「玩家自由组装杀招」列为**核心玩法支柱**，但当前杀招是
  **26 条写死的配方**，玩家是"解锁/装配"而非"组装"

> ⚠️ 这是**规格与实现的明确背离**。领域层没有 `kill_move_*_rules.gd`，
> `saved_combos` 只在 `run_state.gd:49` 和 `save_repository.gd:227` 出现 —— 无独立规则模块。

- **耦合度：★★★ 高**。改动会同时撞 Q8 冻结语法、战斗结算、杀招屏 UI、平衡。

### 1.2.3 遗物

- **实现位置**：`data/relics.json`（**只有 2 个**：`jade_cicada_shell`、`hungry_vine_token`）、
  `scripts/domain/relic_hook_resolver.gd`（166 行）
- **机制【代码】**：hook 制（`on_battle_start` / `on_estimate_feeding`），骨架已通
- **判定**：roguelike 构筑的三大支柱（卡/遗物/经济）里，**遗物这一维几乎不存在**
- **耦合度：★★☆ 中**。hook 骨架在，缺的是"获取途径"（掉落/商店/事件都要接）

### 1.2.4 流派 / 传承 / 诅咒

- `school_rules.gd`（86）、`inheritance_claim_rules.gd`（128）、`curse_registry.gd`（104）、
  `contract_rules.gd`（33）
- 剑道（sword）是当前重点：`sword_mark_rules.gd`（93）。~~T16 残锋降转未完工~~ **已落地（2026-09-15）**，见 `specs/2026-09-12-sword-p2-t15-t16-spec.md` §5；本文该行写作时点早于落地。

---

## 1.3 单局循环结构

- **骨架【代码】**：`MapGenerator.LAYER_ORDER = one..five` → 每层末行为关底台
  → `boss_defeated_L{n}` 门禁解锁下一层 → L5 末 `final_boss_stand` → `ascension_window`
  （升仙窗口，唯一结局入口）
- **节点类型【实测】**：37 个模板，type 分布 combat 10 / hazard 3 / inheritance 3 /
  earth_vein 3 / contact 2 / caravan 2 / market 2 / event 2 / rest 2 / 其余 8 类各 1
- **分类权重【实测】**：battle 82→74（L1→L5）、rest 恒 6、unknown 9→13、trade 4→8
- **节奏保障【代码】**：`REST_ROW_STRIDE = 2`，每两行强制插一个休整锚点
  （2026-09-08 因"战斗占比一度 82%"从 3 收紧到 2）
- **规模**：5 层 × 8–11 行 × 2–6 节点 ⇒ 单局约 150–250 节点，对齐 AGENTS.md 的 200–300 目标
- **存档**：无感自动保存（`save_repository`，SAVE_VERSION 4，tmp+rename + XOR 校验）；
  **整张 route 序列化进存档**（`save_repository.gd:68`）⇒ 读档不重新生成地图
- **耦合度：★★☆ 中**。结构稳定、有门禁；但结局/升仙链路跨 presentation 多文件
  （`run_ending_flow`、`ending_screen_view`、`run_snapshot_builder`）

---

## 1.4 失败惩罚与继承

- **惩罚【代码】**：死亡 → run 结束 → **删除进行中 Run 存档**；局内资源与构筑清空
- **结局类型【代码】**：`success` / `death` / `retreat` / `survived_failure` /
  `surrendered` / `abandoned`（`run_ending_flow.gd:34-49`、`run_controller.gd:361/775`）
- **死因呈现**：`death_report_builder.gd`（31 行）+ `gu_death_cause_overlay_view.gd`
- **继承（唯一通道）**：`MetaProgress.record_run_end()` —— 见 §1.5
- **耦合度：★☆☆ 低**（惩罚侧）。清档是单向写入，无回环。

---

## 1.5 局外永久成长（Meta）

- **实现位置**：`scripts/domain/meta_progress.gd`（206 行）
- **持久化字段**：`gu_codex_ids` / `recipe_codex_ids` / `relic_codex_ids` /
  `inheritance_codex_ids` / `unlocked_content_ids` / `unlocked_random_outcomes` /
  `contracts_unlocked` / `journal_unlocked` / `hall_material_bonus_accrued` /
  `dda_state_adaptive_enabled` / `statistics`
- **解锁来源【代码】**：炼蛊成功、拾荒解锁配方、获得遗物、契约（按 ending 精确匹配）、
  手记（按 ending 或事件日志 route marker：`boss_defeated` / `sworn_contracts` /
  `ascension_attempted` / `shop_barter` / `notoriety_gte_5` / `rest_curse_removed`）

> 🔴 **硬事实【代码】**：`hall_material_bonus_accrued` 是全仓唯一"看起来像战力"的字段，
> 但它在 `meta_progress.gd:26` 定义、`:138` 累加、`:226` 存盘 —— **没有任何消费点**
> （全仓 grep 仅 4 处命中，全在 meta_progress 自身 + 1 处 catalog 白名单）。
> 源码注释亦自陈 "Display-only ledger ... never grants in-run power"。
> ⇒ **当前局外成长对战力贡献严格为 0。**

- **合规性**：符合 AGENTS.md 红线 ——「蛊方图鉴是唯一明确允许的跨局内容解锁；
  不得新增其他跨局战力成长」
- **代价**：**没有任何留存抓手**。玩家死 10 次和死 1 次，下一局的起始强度完全一样。
- **耦合度：★★☆ 中**。结构独立，但任何"加战力"的改动直接撞 AGENTS.md 红线。

---

## 1.6 耦合度总表

| 系统 | 主实现 | 数据 | 耦合度 | 关键约束 |
|---|---|---|---|---|
| 地图生成 | `map_generator.gd` 393 | `pacing.json` `nodes.json` | ★★☆ | 10 个测试调用；E5a/E5b 双门禁 |
| 敌人抽取 (E6) | `enemy_catalog.gd` 178 | `enemies.json` | ★☆☆ | 派生流先例可用；锚点免抽 |
| 掉落 | `loot_resolver.gd` 403 | `loot_tables.json` | ★★★ | **唯一权威结算者**；Reachability 红线 |
| 事件 | `dialogue_manager_adapter.gd` | `events.json` **2 条** | ★☆☆ | catalog 校验骨架已通 |
| 蛊 / 合成 | `refine_command_rules.gd` 799 | `gu.json` 802 / 配方 468 | ★★★ | **Q8 Grammar V2 冻结** |
| 杀招 | `v1_battle.json.kill_moves` 26 | 同左 | ★★★ | 撞冻结语法 + 战斗结算 + UI |
| 遗物 | `relic_hook_resolver.gd` 166 | `relics.json` **2 个** | ★★☆ | 缺获取途径 |
| 战斗结算 | `v1_battle_resolver.gd` 851 | `v1_battle.json` | ★★★ | 冻结区核心 |
| Meta 成长 | `meta_progress.gd` 206 | 大厅存档 | ★★☆ | **AGENTS 红线：禁加战力** |
| 存档 | `save_repository.gd` 260 | — | ★★★ | SAVE_VERSION 4；route 整体序列化 |

**Shared 单写者区**（`docs/contracts/2026-09-12-agent-ownership-contract.md`）：
`run_controller` / `run_snapshot_builder` / `resolver` / `run_state` / `save_repository` /
`main.tscn` / `project.godot` / `docs/contracts`。
⇒ 上表中 **`save_repository` 属 Shared**，其余主实现文件**不在** Shared 列表（但爆炸半径大）。

---

# 二、改造方向对比

## 2.1 候选方向清单

| ID | 方向 | 一句话 |
|---|---|---|
| **D1** | **关底 Boss 随机化** | 每层 2–3 候选按种子抽 1，7 个 boss 全部归位 |
| D2 | 层性向（节点构成抖动） | run 级 + 层级零和权重抖动（已出预审） |
| D3 | 遗物系统扩容 | 2 → 12+，接入掉落/商店/事件 |
| D4 | 事件池扩容 | 2 → 12–16 条，提权进 unknown 池 |
| D5 | 杀招自由组装 | 26 条固定配方 → 玩家可组装 |
| D6 | 局外加战力成长 | 解锁型永久增益 |
| D7 | 精英节点显性化 | 地图标记 elite 战斗，显化风险决策 |
| D8 | 开局随机三选一 | 开局蛊/流派/遗产三选一 |

## 2.2 三维度横向对比

> 收益：★★★ = 直接拉动重开率；★★☆ = 改善体验；★☆☆ = 锦上添花
> 改动量：★★★ = 跨模块大工程；★★☆ = 中等；★☆☆ = 小（数据 + 单点注入）

| ID | 玩法收益 | 改动量 | 涉及模块 | 依赖与前置条件 | 风险 |
|---|---|---|---|---|---|
| **D1** | ★★★ | **★☆☆** | `nodes.json` + `map_generator.gd`(~20 行) + `content_catalog` 校验 | ①绕过 `instance_anchor` 免抽；②**需分层强度带校准**（7 boss / 5 层 ⇒ 必然复用或补内容）；③节点上挂 `core_replacement_token` 需迁到 boss 定义 | 中低：Boss 强度不齐会破坏平衡 |
| D2 | ★★☆ | ★★☆ | `pacing.json` + `map_generator` + `content_catalog` + 参数网格搜索 | ①**触碰 Reachability「不改 pacing」红线**；②作废 f1 32 局语料；③须重跑 E5a/E5b | 中：门禁均值 0.577 距上界仅 0.023 |
| D3 | ★★★ | ★★★ | 新增获取途径 × 掉落 + 商店 + 事件；`relic_hook_resolver`；装备栏 UI；契约文档 | ①`LootResolver` 红线；②商店 `offers` 结构；③契约回写（Shared） | 高：横切三大系统 |
| D4 | ★★☆ | ★★☆ | `events.json` + catalog 白名单 + 每条事件的领域结算分支 | ①现有 2 条已跑通（低风险证据）；②需写 12+ 条内容（内容工作量，非代码） | 中低：内容为主 |
| D5 | ★★★ | ★★★ | `v1_battle.json.kill_moves` + 战斗结算 + 杀招屏 + 平衡 | ①**Q8 Grammar V2 冻结**（新操作/新 Buff 禁实现）；②战斗结算冻结区 | **高：撞冻结** |
| D6 | ★★☆ | ★★☆ | `meta_progress` + 消费点 + 大厅 UI | ①**AGENTS.md 红线：禁新增跨局战力** | **红线，需改规格才可做** |
| D7 | ★☆☆ | ★☆☆ | 快照字段 + 地图 UI | ①`docs/contracts` 更新（Shared 区） | 低 |
| D8 | ★★☆ | ★★☆ | `run_opening_flow.gd` + 新快照 + 可能新屏 | ①需定义开局池；②契约回写 | 中 |

## 2.3 收益 / 代价散点（定性）

```
收益 ★★★ │ D1 ●      D3 ●        D5 ●
         │
收益 ★★☆ │      D8 ●   D4 ●   D2 ●   D6 ✕(红线)
         │
收益 ★☆☆ │ D7 ●
         └────────────────────────────────
            ★☆☆        ★★☆       ★★★
            小改动      中改动     大改动
```

---

# 三、最终结论

## 3.1 最优解：**D1 关底 Boss 随机化**

**收益最大、改动最小**，且是唯一同时满足以下五条的候选：

1. **零内容新增成本** —— 7 个 boss 已有完整定义（含美术：`enemy_thunder_crown_sovereign.png`
   等资产在库），其中 **2 个从未上场**。改的是"选哪个"，不是"做什么"。
2. **感知位置最优** —— 关底 Boss 是每层的情绪高点。玩家对"这局 Boss 是谁"的记忆强度
   远高于"这局战斗占比 57% 还是 62%"。**D2 改的是节奏方差（弱感知），D1 改的是内容（强感知）。**
3. **技术先例现成** —— E6 已验证「派生流注入、不消耗主 rng、既有种子布局不变」的模式，
   直接复用即可。
4. **不触碰任何红线** —— 不动 `pacing`、不动 `LootResolver`、不动掉落/商店/战斗结算、
   不改 `category_weights` ⇒ **不触发 Reachability 红线、不作废 f1 语料**。
   相比 D2 需要请求"红线覆盖"裁定 + 重建语料，D1 的前置成本几乎为零。
5. **改动面单点** —— 只碰 `nodes.json`（数据）+ `map_generator.gd` 关底台分支（~20 行）
   + `content_catalog` 校验。不涉及 Shared 单写者区、不涉及契约文档。

### 与上一轮决策的关系（重要修正）

上一轮在「方向选型」时我基于**单维度诊断**（整局方差被 √5 平均掉）推荐了 D2 并出了预审。
本次做**全系统调研**后，结论应当修正：

> **D1 的收益/代价比显著优于 D2**。D2 的问题是"花中等改动 + 红线覆盖 + 语料重建的代价，
> 换一个玩家弱感知的节奏方差"；而 D1 用更小的代价拿到更强的感知。
> 建议 **D1 优先、D2 降级为第二阶段**（D2 的预审已出，可随时执行）。

## 3.2 拆分后的最小改动范围（D1）

**Step 1 — 数据层（零代码）**
- `data/nodes.json`：5 个 `layer_boss_stand_N` 节点，各自改为声明
  `boss_pool: ["id_a", "id_b"]`（分层强度带内的 2–3 个候选）
- 把 `core_replacement_token` 等**跟 Boss 走的奖励从节点迁到 boss 定义**
  （否则换 Boss 后奖励错位）

**Step 2 — 生成器（~20 行）**
- `map_generator.gd`：关底台分支（`row == row_count - 1`）改为从 `boss_pool` 用
  **独立派生流**抽取：`SeededRng.new(mixed_seed(seed_value, "boss_L%d" % layer, 0))`
  - ⚠️ 层号进 **salt** 不是 `tick`（`seeded_roll.gd:43` 记录 tick 是仿射混入）
  - ⚠️ 保持不消耗主 rng ⇒ 拓扑/连边/锚点逐位不变
- 抽中的 boss id 写入实例 `enemy_kind`

**Step 3 — 校验**
- `content_catalog.gd`：`boss_pool` 内 id 必须存在于 `enemies.json` 且 `tier == "boss"`；
  池大小 ≥2

**Step 4 — 门禁与回归**
- 新增 `tools/verify_boss_variety.gd`：40 种子上断言
  ①每个 boss 至少出现一次（**反空转 canary：全 0 即 FAIL**）
  ②同一 (seed, layer) 两次生成结果相同（确定性）
  ③拓扑与基线快照逐位相等（证明主 rng 未被消耗）
- 回归：`test_category_route` / `test_map_generator` / `test_map_network` /
  `test_map_anchor_guards` / `test_map_catalog_config` / E5a / E5b

**验收指标**：5 层 × 40 种子 = 200 个 Boss 席位，覆盖 ≥5 个不同 boss；
每层候选分布均匀（χ² 或简单极差检查）。

## 3.3 需要规避的高风险改动点

| # | 高风险点 | 为什么 | 规避方式 |
|---|---|---|---|
| 1 | **改 `LootResolver` / 掉落表** | 全局唯一结算出口，Reachability 明确红线；改动作废 32 局语料 | D1 完全不碰 |
| 2 | **改 `pacing.json` 任何既有键** | 触碰「不改 pacing」红线；且当前聚合均值 0.577 距门禁上界仅 0.023 | D1 只加 `boss_pool` 到 `nodes.json`，不动 pacing |
| 3 | **动 Q8 Grammar V2 冻结语法** | 「新操作/新 Buff/新触发器不实现不预留」 | D1 不改任何蛊效果 |
| 4 | **给 MetaProgress 加战力读点** | AGENTS.md 红线：唯一允许的跨局解锁是图鉴 | 本轮不做 |
| 5 | **改 `_pick_category_template` 签名** | `test_category_route.gd:63` 直接静态调用且无 seed 参数，改签名即编译失败 | D1 不触及 |
| 6 | **把层号放进 `mixed_seed` 的 tick** | tick 是仿射混入，连续层号会退化（`seeded_roll.gd:43`） | 层号进 salt，tick 恒 0 |
| 7 | **Boss 强度未经分层就随机** | 7 boss 跨 5 层，L5 boss 出现在 L1 会直接劝退 | 候选池必须**按层强度带**声明，禁止全池随机 |
| 8 | **与剑道 T16 / 美术在途改动混 commit** | 爆炸半径叠加，回滚困难 | ⚠️ **实际未能规避**（2026-09-16）：施工时工作树已含 T16「一脉一突破」等在途改动，且 `action_preview_service` / `content_catalog` / `social_command_rules` 三文件与本轮改动**逐行混编**，文件级不可分离。详见交接文档 §2 |
| 9 | **用 `tools/*.ps1` 判测试成败** | 沙箱下 stdout 不转发 ⇒ rc=1 + 0 行输出，**不是测试结论** | 直连 Godot 二进制；判据同时看 SCRIPT ERROR / Orphans / ObjectDB |
| 10 | **相信 GUT 汇总行** | `.gutconfig.json` 把 engine 类错误排除在 Failing 外 ⇒ "全过"与"36 失败"可同时为真 | 见上 |

## 3.4 D1 执行记录（2026-09-16 已落地）

### 原文调研阶段发现（决定了方案形状）

| 事实 | 出处 | 影响 |
|---|---|---|
| 7 个 boss 的 `rank`/`hp` 为：miasma 3/14、crag 4/15、marrow 4/16、thunder 5/18、clan 5/19、blood 5/20、blue_fur 5/20 | `enemies.json`【实测】 | **rank 只有 3/4/5**，无 rank 1/2 ⇒ 无法按 rank 严格分层 |
| **终局 Boss 强度倒挂**：`miasma_vein_lord`（rank 3 / hp 14）是全场最弱，却守 L5 | 同上 | 有效 HP（×`boss_layer_mult`）对比：L3=21.6、L4=27、**L5=21** |
| **最强的两个 boss 从未上场**：`clan_patriarch`(19)、`blue_fur_jiangshi`(20) | `nodes.json`【实测】 | 随机化的直接收益就是把它们放进场 |
| `core_replacement_token` 由 `core_gu_rules.gd:136` 从 **node** 读取，且 `content_catalog:555` 校验的是 node 的 **stage** | 【代码】 | ⇒ 换 Boss 不影响该 token，**报告 §2.2/§3.2 里"需迁移到 boss 定义"的风险项被证伪，撤回** |
| `boss_layer_mult` 按 stage 缩放 hp/damage（1.0→1.5） | `v1_battle.json`【实测】 | 分层必须按**有效强度**（hp × 层倍率）而非裸 hp |

### 落地方案（滑动窗口 + 相邻层不重复）

| 层 | boss_pool | 有效 HP（hp × 层倍率） |
|---|---|---|
| L1 | crag_serpent_matriarch, marrow_gu_adept | 15.0 / 17.6 |
| L2 | marrow_gu_adept, thunder_crown_sovereign | 17.6 / 21.6 |
| L3 | thunder_crown_sovereign, clan_patriarch | 21.6 / 22.8 |
| L4 | clan_patriarch, blood_vein_bishop, blue_fur_jiangshi | 25.7 / 27.0 / 27.0 |
| L5 | **固定** miasma_vein_lord（不随机化） | 21.0 |

- 池是**按 hp 排序的滑动窗口**：层内 hp 差 ≤2，层间单调递增；原关底 Boss 恒在池内（连续性）
- **相邻层不重复**：`_roll_boss_for` 排除上一层的 Boss；排除后无候选才放弃排除
- **L5 不随机化的理由**：`final_boss_stand` 的 summary「瘴脉尽头，蛊主把守升仙窗口」与
  miasma_vein_lord 叙事绑定；且它的有效强度（21）显著低于 L4 候选（27），
  与任何 rank 5 Boss 同池都会造成终局难度跳变。留作第二阶段（见 §3.6）

### 改动清单

| 文件 | 改动 |
|---|---|
| `data/nodes.json` | 4 个 `layer_boss_stand_N` 各加 `boss_pool`（纯数据） |
| `scripts/domain/map_generator.gd` | +`prev_boss_id` 追踪；关底台分支注入；新增 `_roll_boss_for`（派生流 `mixed_seed(seed, "boss_stand_"+instance_id, 0)`） |
| `scripts/domain/content_catalog.gd` | 新增 `boss_pool` 校验（只许关底台 / ≥2 / 成员存在且 tier==boss / 无重复） |
| `tests/unit/test_boss_pool_variety.gd` | 新增 5 用例 175 断言 |
| `tools/verify_boss_variety.gd` | 新增 40 种子门禁（B0 canary / B1 覆盖 / B2 确定性 / B3 相邻不重复 / B4 终局固定 / B5 拓扑冻结） |

### 门禁实测结果

```
stand slots seen: 200 (expected 200)
  [pool] crag_serpent_matriarch    seen=21
  [pool] marrow_gu_adept           seen=27
  [pool] thunder_crown_sovereign   seen=38
  [pool] clan_patriarch            seen=36
  [pool] blood_vein_bishop         seen=21
  [pool] blue_fur_jiangshi         seen=17
  [fixed] miasma_vein_lord         seen=40
topology_mismatch=0  adjacency_repeat=0
R9 PASS
```

**7 个 boss 全部上场**（改动前 5 个，clan_patriarch / blue_fur_jiangshi 恒为 0 次）。

**B5 拓扑冻结自证**：同一份代码下，带 catalog（E6 + Boss 随机全开）与不带 catalog
（两者皆关）两条路径产出的 `(id, template_id, layer, row, next_ids)` **40 种子逐位相同**
⇒ 证明抽取确实未消耗共享 rng，既有地图拓扑/连边/锚点零变化。

### 回归

| 测试 | 结果 |
|---|---|
| `test_boss_pool_variety`（新） | 5/5，175 断言 |
| `test_category_route` | rc=0，341 断言 |
| `test_map_generator` | rc=0，6361 断言 |
| `test_map_network` | rc=0，6549 断言 |
| `test_map_anchor_guards` | rc=0，162 断言 |
| `test_map_catalog_config` | rc=0，3 断言 |
| `test_data_driven_guard` | rc=0，12 断言 |
| `test_core_gu_replace` | 7/7（核心蛊 token 不受换 Boss 影响，已验证） |
| `test_runtime_seed_policy` | 4/4 |

无 SCRIPT ERROR、无 Orphans。（判据按 `.workbuddy/memory/MEMORY.md` §二：GUT 汇总不可全信，
已另抓 `Passing Tests` / `All tests passed` 原文确认。）

### 回滚

删除 4 个节点上的 `boss_pool` 键即回到今日行为（`_roll_boss_for` 遇到无 `boss_pool`
或空 catalog 返回空字典，调用方保持模板 `enemy_kind`）。单点开关，无需回滚代码。

## 3.5 D1 第二阶段（未做）

1. **L5 终局随机化** —— 需先解决 `miasma_vein_lord` 强度倒挂（rank 3 / hp 14 守终局）。
   要么抬它的数值（平衡改动，需产品裁定），要么为终局另立叙事中性的候选。
2. **Boss 掉落差异化** —— 当前所有 Boss 共用 `LootResolver` 的 boss tier 规则；
   换 Boss 后掉落不变。让不同 Boss 带不同掉落会显著放大构筑差异，但要碰红线对象。

---

## 3.6 建议执行顺序

```
D1 Boss 随机化          ✅ 已落地（2026-09-16，见 §3.4）
   ↓
D4 事件池扩容           ✅ 已落地（2026-09-16，见 §3.7）
   ↓
D7 精英节点显性化        ← 下一步（改动极小，提升决策可读性）
   ↓
D2 层性向               ← 预审已出，待 pacing 红线裁定后执行
   ↓
D3 遗物扩容 / D5 杀招组装 ← 大工程，需独立立项
```

> ⚠️ **D2 与 D4 的频率提升共用同一个前置**：D4 只买到"种类"多样性，事件频率仍 ≈2.3 个/局，
> 因为 `pacing.json` 全程未动。想让事件真正成为肉鸽支柱，必须先进 pacing 红线裁定，
> 两者应当合并裁定。

---

## 3.7 D4 执行记录（2026-09-16 已落地）

完整报告：`2026-09-16-d4-event-pool-expansion.md`（含原文考据频次表与被推翻的先验）。

| 事实 | 出处 | 影响 |
|---|---|---|
| `_append_event_cards(cards, state, catalog)` **不接收 node**，遍历 events 全表 | `action_preview_service.gd:814`【代码】 | 池子=2 时看不出来，扩到 12 会铺满 12 张卡 ⇒ **扩容的硬前置**，已改 node-aware |
| 已有 2 条事件**只有代价、没有发放**，但 `expected_gain` 写着"取得回声允诺的机缘" | `social_command_rules.gd:129-150`【代码】 | 承诺不实；本轮补 `stone_gain` 真实结算 |
| 事件节点只有 **2 个** `type=="event"` 模板，都挂在 `category_pools.unknown` | `nodes.json` + `pacing.json`【实测】 | 事件**频率**由 pacing 决定 ⇒ 本轮只能买到"种类"多样性 |
| DM 是真 autoload（`project.godot:20`）⇒ 事件主界面是**对话气球**，遭遇卡是次界面 | `project.godot`【代码】 | 新增事件必须补 `~ <event_id>` 对话块，否则气球点了悬空（E4 门禁守） |
| `kind` 字段只做白名单校验，`_accept_event` 不读它 | `content_catalog.gd:47` + resolver【代码】 | 惰性字段；本轮**刻意不加**新枚举值 |

**落地**：`events.json` 2 → 12 条（`遗藏`/`兽潮`/`赌斗`/`斗蛊`/`契约`/`认主`/`秘境`/`血脉` 母题，
全部落在原文高频词上）；事件节点加 `event_pool`，宿主事件按种子用**独立派生流**抽
（与 E6/R9 同构，主 rng 零消耗）；卡片文案由数值杠杆**派生**，与结算同源。

**验证**：门禁 `tools/verify_event_variety.gd` 40 种子 PASS（12/12 覆盖、`topology_mismatch=0`、
93 个事件槽）；`test_event_pool.gd` 10/10 通过、99 断言。**`pacing.json` 全程未动**。

---

## 附录：本次调研产生的证据文件

**探针脚本（可复现）**

- `tools/measure_category_variance.py` — 方差测量（M1 每层 / M2 整局；基线上 M2 正确报 FAIL ⇒ 非空转）
- `tools/_probe_build_space.py` — 局内构筑空间探针（802 蛊 / 468 配方 / 仅 57 个显式 `v1_effect`）
- `tools/_probe_boss_defs.py` — 7 个 boss 的 rank/hp/tier 导出（§3.4 表格来源）

**测量产物**

- `tools/_baseline_e5a_40seeds.txt` — E5a 门禁 40 种子原始输出（**改动前**基线，D2 预审依据）
- `tools/_measure_out.md` — 方差解析结论
- `tools/_probe_build_space.md` / `tools/_probe_boss_defs.md` — 上述探针输出

**门禁与回归原始输出**

- `tools/_r9_out.txt` — D1 Boss 多样性门禁 40 种子完整输出（`R9 PASS`）
- `tools/_d4_out.txt` — D4 事件多样性门禁 40 种子完整输出（`D4 PASS`）
- `tools/_gut_d4_summary.txt` — D4 后全量 unit 套件汇总（1514/1514、51598 断言、SCRIPT ERROR 0）
- `tools/_gut_r9.txt` / `tools/_gut_full.txt` — D1 回归批次输出

**规格**

- `docs/superpowers/specs/2026-09-16-rogue-layer-temperament-spec.md` — D2 层性向预审（已出，待 pacing 红线裁定）
