# D4 事件池扩容 —— 实施报告（2026-09-16）

> 工作流：原文调研 → 推理分析 → 执行。本文 §0 是原文考据（含被推翻的先验），
> §1 是代码侧现状，§2 起是设计与实现。
> 上游：`2026-09-16-roguelike-audit-and-directions.md`（D4 的立项依据）。

---

## 0. 原文考据

语料：`分支：六卷精编版/蛊真人-clean.txt`（437061 行，只读）。
方法：先数频次 → 再取语境 → 换一组关键词复检 → 才下结论。

### 0.1 频次基线（第一轮，26 词）

| 词 | 次数 | 判定 |
|---|---|---|
| 元石 | 2027 | 高频，经济主词 |
| 魂魄 | 1917 | 高频核心资源 |
| 真元 | 1650 | 高频核心资源 |
| 秘境 | 368 | 高频母题 |
| 血脉 | 359 | 高频母题 |
| 本命蛊 | 213 | 高频 |
| 赌斗 | 165 | **高频母题** |
| 遗藏 | 144 | **高频母题** |
| 兽潮 | 144 | **高频母题** |
| 寿元 | 109 | 中频 |
| 认主 | 85 | 中频 |
| 毒气 | 64 | 中频（变体） |
| 斗蛊 | 51 | 中频 |
| 子蛊 | 45 | 中频 |
| 瘴气 | 21 | **注意语义，见 0.2** |
| 契约 | 20 | 中低频 |
| 陪葬 | 8 | **注意语义，见 0.2** |
| 黑市 | 4 | 低频 |
| 回声 | 2 | 低频 |
| 蛊契 | **0** | 见 0.3 |
| 残响 | **0** | 见 0.3 |
| 毒瘴 | 0 | 不用 |
| 虫潮 | 0 | 不用 |
| 尸傀 | 0 | 不用 |
| 遗蜕 | 0 | 不用 |
| 借命 | 0 | 不用 |

### 0.2 第二轮复检**推翻**的两条先验（证据强度：高频次 + 语境，高）

1. **`陪葬` 8 次全部是「拖你陪葬」的威胁语义**，不是"墓中陪葬品"。
   原句形态：「临死也要拉着你陪葬」（L11910）、「能有你一齐陪葬，我这人生结束的也挺有趣」（L29310）、
   「我就算死在这里，有你们百家陪葬，也不错了」（L54484）。
   ⇒ **禁止**用"陪葬品 / 墓中陪葬"这一层语义。我的初版设计正是这么用的，已删。
2. **`瘴气` 21 次里多数是「瘴气界壁」**——五域之间的分界（南疆瘴气界壁，L192232/L192524/L192548），
   是**地理屏障**，不是"中毒掉气血"的机制词。×「阻碍」共现 3 次，无 ×「中毒」类共现。
   ⇒ 项目已用「落瘴岭 / 瘴脉深处 / 瘴脉尽头」作层名，属**地域命名**，用法正确；
   **不要**把它写成毒伤来源。

### 0.3 自创词 ≠ 错误（按 corpus-research 陷阱 #4 保留）

`蛊契` 与 `残响` 原文各 **0 次**，但二者已经被本项目内化为机制术语
（节点 `gu_rot_pact`、`data/dialogues/events.dialogue` 文案、`AGENTS.md` 层名叙述）。
判据是"是否已内化为机制术语"，不是"原文有没有" ⇒ **保留现状不改**，
但**不再扩用**这两个词；新增内容一律改用 §0.1 的高频母题。

### 0.4 采用的母题与原文依据（证据强度：频次计数 + 原文原句，高）

| 事件母题 | 词频 | 原文依据 |
|---|---|---|
| 遗藏 | 144 | 「花酒行者遗藏」整条支线：发现遗藏 → **独吞有巨大风险** → 禀告家族 vs 独占（L1334/L1748/L2050/L2060） |
| 兽潮 | 144 | 「每隔一段时间，都有兽潮……蛊师成为守护山寨的中坚力量，每年减员的状况都比较严重」（L4708）；「小型兽潮形成 → 不处理会滚成大型」（L14774） |
| 赌斗 / 斗蛊 | 165 / 51 | 「蛮石不是想激他赌斗吧？要真是斗蛊，说不得还真能剐出一块肥肉来」（L17426）；×「赌注/赢/输/元石」共现 8/16/22/9 |
| 契约 / 认主 | 20 / 85 | 毒誓蛊签订"不容反悔的契约"（L46880/L73414）；强逼认主（L61238/L62024） |
| 秘境 | 368 | 秘境入场受制于守门条件 |
| 血脉 | 359 | 血脉/精血作为可交易资源 |

`遗藏` 的交叉共现：×元石 12、×守护 3、×危险 2、×危机 1、×代价 1、×陷阱 1
⇒ 原文的遗藏本来就是"诱惑 + 风险"结构，与"有代价的收益"设计天然吻合。

---

## 1. 代码侧现状（调研的第二半）

### 1.1 事件是**双通路**，且两条都活着

| 通路 | 入口 | 事实位置 |
|---|---|---|
| Dialogue Manager 气球（**主界面**） | 抵达事件节点 → `begin(event_id, dialogue_title)` | `run_travel_flow.gd:40-49`；DM 是真 autoload（`project.godot:20`）；台词在 `data/dialogues/events.dialogue` |
| 遭遇卡（**次界面**） | `_show_encounter()` → action preview | `action_preview_service.gd:36-37` → `_append_event_cards` |

### 1.2 三个必须先修的既有事实

1. **结构性缺陷（扩容的硬前置）**：`_append_event_cards(cards, state, catalog)` **不接收 node**，
   遍历 `catalog.events` 全表，每张卡都写死"承受回声"话术。
   ⇒ 池子=2 时看不出来；扩到 12 会在每个事件点位铺出 **12 张卡**。所以扩容前必须先改成"只渲染宿主事件"。
2. **已有 2 条事件是纯代价（承诺不实）**：`expected_gain` 写着"取得回声允诺的机缘"，
   但 `_accept_event` 只扣 `health_cost` + 记 `pending_delayed_soul_drain` + 可选挂诅咒，
   **没有任何发放动作**。即：代价真实、收益是空头承诺。
3. **`kind` 字段是惰性的**：`EVENT_KIND_IDS = ["delayed_cost","curse_bargain"]` 只用于白名单校验，
   `_accept_event` 完全不读 `kind`。本文不改它（不加"看起来有意义"的枚举值），仅记录在案。

### 1.3 事件节点是**手工摆在地图拓扑里的模板**

- 全游戏只有 **2 个** `type=="event"` 节点模板（`echo_cave` / `gu_rot_pact`），
  二者都挂在 `pacing.json:category_pools.unknown`（13 个模板里的 2 个）。
- ⇒ 事件**频率**由 `category_weights.unknown`（9→13%）与 unknown 池构成决定；
  **种类**多样性才是本轮可动的变量。
- `echo_cave` 节点没有 `event_id`，靠 `node.id` 回退；`gu_rot_pact` 显式声明了 `event_id` + `dialogue_title`。

---

## 2. 设计

### 2.1 四个**真实**杠杆（全部落在既有结算能力内，不新增红线）

| 杠杆 | 语义 | 既有结算点 |
|---|---|---|
| `health_cost` | 立即损气血 | `_accept_event`（已有） |
| `delayed_soul_cost` + `delayed_trigger: next_travel` | 下次赶路时抽魂魄 | `social_command_rules.gd:580-592`（已有） |
| `curse_id` | 挂一条诅咒（现有 3 条全用上） | `CurseRegistry.gain_curse`（已有） |
| `stone_gain` | **本轮新增**：立即得元石 | 同一条 `accept_event` 日志 |

**为什么只加 `stone_gain`**：元石是唯一不需要新通路就能真实结算的通用收益；
赠蛊要走 GuInstance + `transaction_ledger`，赠材料要撞 `LootResolver` 唯一结算红线，
赠寿元会动摇单局时长基线（3–5h/200–300 节点）。以上三项都**明确不做**。

### 2.2 12 条事件

| id | 标题 | hp | 延后魂魄 | 诅咒 | 元石 |
|---|---|---|---|---|---|
| `echo_cave` | 残响叩穴 | 1 | 1 | – | +2 |
| `gu_rot_pact` | 腐朽蛊契 | 1 | 1 | 元石滞胀 | 0 |
| `huajiu_cache` | 行者遗藏 | 2 | – | – | +5 |
| `tithing_cache` | 献藏换赏 | – | – | – | +2 |
| `small_beast_tide` | 小兽潮 | 2 | 1 | – | +3 |
| `tide_aftermath` | 潮后拾骨 | – | 2 | – | +3 |
| `duel_wager` | 赌斗押注 | 1 | – | – | +4 |
| `duel_loss` | 斗蛊折戟 | 2 | – | 经脉封蛊 | +1 |
| `weird_trade` | 秘境换物 | – | 1 | – | +2 |
| `contract_seal` | 毒誓之契 | 1 | 2 | – | +4 |
| `recognition_toll` | 认主输诚 | – | – | 蛊蚀 | +3 |
| `blood_vein_offering` | 血脉献祭 | 2 | – | 元石滞胀 | +4 |

覆盖：hp 0/1/2 三档（**4 条零即时代价**，保证气血低时点位不空）、3 条诅咒各用一次、
元石 +0…+5。`遗藏` 两条（`huajiu_cache` vs `tithing_cache`）刻意做成
**独吞高风险高回报 / 上交低风险低回报**的对照，正是 §0.4 原文里的取舍结构。

### 2.3 宿主事件按种子抽（独立派生流）

与 E6（敌人）和 R9（关底 Boss）**同构**：`salt = "event_node_" + 实例 id`，`tick` 恒 0，
**不消耗 `_generate_instance_route` 的共享 rng** ⇒ 既有地图拓扑 / 连边 / 锚点行位逐位不变。

> ⚠️ 实例 id 必须进 **salt** 而不是 `tick`：`mixed_seed` 的 tick 是仿射混入，连续 tick 会退化
> （`seeded_roll.gd:43`，R9 已踩过）。

抽中的事件同时写入实例的四个面：
`event_id`（领域日志/结算）、`dialogue_title`（气球标题）、`summary`（地图/遭遇文案）、
`command`（卡片）——四者同源，避免"点位说回声、实际是兽潮"的错位。

### 2.4 预检提示与真实结算**同源**（红线对齐）

卡片上的代价/收益条目**不是再抄一份文案**，而是由数值杠杆派生：

- `known_risk` ← `health_cost` / `delayed_soul_cost` / `curse_id`（诅咒名取自 `curse_by_id.name_zh`）
- `expected_gain` ← `stone_gain` + 数据里的 `flavor_gain`
- `executable` ← 与 `_accept_event` **完全同一判据** `state.health > health_cost`

⇒ 谁只改 JSON 不改正则、或只改文案不改结算，`test_event_pool.gd` 的反漂移守卫会当场炸。
气球侧的选项文本同样内联写明代价（"耗 2 气血，行路时失 1 魂魄"），满足"执行前必须明确提示"。

---

## 3. 改动清单

| 文件 | 改动 |
|---|---|
| `data/events.json` | 2 → **12 条**；新增 `title/summary/flavor_gain/unknown_note/stone_gain` |
| `data/dialogues/events.dialogue` | 每条事件一个 `~ <event_id>` 菜单 + `<id>_accept` / `<id>_leave`；`~ start` 改为中性兜底块 |
| `data/nodes.json` | 2 个事件模板加 `event_pool`（12 条全池）；`summary` 改中性（不再写死回声话术） |
| `scripts/domain/map_generator.gd` | 新增 `_roll_event_for`（派生流）；`_generate_instance_route` 内一段写回 `event_id/dialogue_title/summary` |
| `scripts/domain/action_preview_service.gd` | `_append_event_cards` 改 **node-aware**（只渲染宿主事件）；拆出 `_event_accept_card` + `_curse_label` |
| `scripts/domain/social_command_rules.gd` | `_accept_event` 结算 `stone_gain`，`before/after` 双写 `stone` |
| `scripts/domain/content_catalog.gd` | `_validate_events` 校验 `stone_gain`/文案字段/「至少一个杠杆」；`validate` 校验节点 `event_pool` |
| `tools/verify_event_variety.gd` | **新增**门禁（6 项） |
| `tests/unit/test_event_pool.gd` | **新增** 10 个用例 / 99 断言 |
| `tools/verify_b2_four_screens_render.gd` | 修掉用 hazard id 冒充事件节点的假夹具 |

**回滚**：删掉 2 个节点上的 `event_pool` 键 ⇒ 立即回到"点位固定事件"；
删 `events.json` 里的 `stone_gain` ⇒ 回到纯代价。**都无需回滚代码。**

---

## 4. 验证证据

门禁 `tools/verify_event_variety.gd`（40 种子）**PASS**：

```
event slots seen: 93          （≈2.3 个事件节点/局）
12 / 12 条事件全部至少上场一次（seen=4…14）
dialogue titles parsed=37     （12×(1+2) + start）
topology_mismatch=0           （带 event_pool 与剥掉 event_pool 两条路径逐位相同）
```

6 项门禁全绿：

- **E1 覆盖率** —— 12/12 条至少出现一次
- **E2 确定性** —— 同种子两次生成逐位相同（含 `event_id/dialogue_title/summary`）
- **E3 文案随事件走** —— 实例 `summary` 必须等于目录里该事件的 `summary`
- **E4 对话可解析** —— 每条被抽中的事件都有 `~ <id>` 与 `<id>_accept`/`<id>_leave`
- **E5 拓扑冻结** —— 带/不带 `event_pool` 的 `(id, template_id, layer, row, next_ids)` 逐位相同
- **E0 反空转 canary** —— 目录校验零错、事件槽 > 0、观察到 ≥2 种事件、对话标题解析非空

单元测试 `tests/unit/test_event_pool.gd` **10/10 通过，99 断言，无 SCRIPT ERROR、无 Orphans**。

---

## 5. 边界与遗留（诚实清单）

1. **只买到"种类"多样性，没买"频率"。** `data/pacing.json` **全程未动**（Reachability 轨道的
   "不改 pacing"红线仍在）：事件仍受 `category_weights.unknown`（9→13%）与 unknown 池构成约束，
   实测 ≈**2.3 个事件节点/局**。提高事件频率必须先进 pacing 裁定 —— 与 D2（层性向）是同一个前置。
2. **事件节点只有 2 个模板**，所以每局是"12 选 2–3"。这是当前最直接的多样性上限。
3. **`kind` 字段仍是惰性的**（只做白名单校验）。本轮刻意没有为了"看起来完整"去加枚举值。
4. **元石收益的平衡未标定**：+2…+5 相对分层预算（L1 12 / L5 35）是可感知的量级，
   `stone_gain` 是纯数据旋钮，后续按实测调。本轮只保证"有代价、有收益、数字与提示同源"。
5. **R9 遗留未动**：L5 关底 Boss 固定、`miasma_vein_lord` 有效强度倒挂（21.0 < L3 21.6）。
6. 事件节点 `stage: "two"` ⇒ 只在第 2 层及以后出现（沿用原模板设定，未改）。

---

## 附：方法论沉淀

- **可复用的"拓扑冻结"自证手法**：证明"派生流改动没碰主 rng"不需要重建基线语料 ——
  同一份代码，**开/关新功能两条路径**的 `(id, template_id, layer, row, next_ids)` 在 40 个种子上
  逐位相同即可。R9 用"带/不带 catalog"，D4 用"带/不带 `event_pool`"，后者更精确（只隔离单一变量）。
- **可复用的"反漂移"守卫**：数值杠杆 → 文案的派生关系必须由测试断言，
  否则数据与提示会各自演化。
