# D7 精英节点显性化：实施报告（2026-09-16）

> 上游：`docs/superpowers/reports/2026-09-16-roguelike-audit-and-directions.md` §3.6（建议顺序里 D7 = 下一步）
> 交接：`docs/superpowers/reports/2026-09-16-roguelike-handover.md`
> 性质：**已落地**（含 Shared 区改动，见 §7 声明）

---

## §1 三十秒摘要

| 项目 | 状态 |
|---|---|
| 目标 | 地图上显性化「精英遭遇」，让行路决策看得见风险（D7 原话：**提升决策可读性**） |
| 改动面 | 领域 1 个新函数 + 快照 1 个新键 + 表现层 1 行接线；`pacing.json` / `LootResolver` / `enemy_roll` 生成逻辑**零改动** |
| 门禁 | 全量 unit **1525/1525**（51667 断言）；`tools/verify_map_threat.gd` 40 种子 **PASS**；交互门 15 屏三键全 0 |
| 关键数字 | 40 种子 6500 节点中 **1105** 个精英节点被标记（17.0%）；旧判据只命中 **418** 个 ⇒ 修复后是 **2.6×** |
| 回滚 | 快照删 `threat` 键 + 表现层还原一行；**无数据/存档迁移** |

---

## §2 发现的缺陷（两个互相叠加，导致该功能「写了但从未生效」）

### 2.1 面板层读到的是不存在的键 ⇒ 死分支

`map_screen_view.gd` 早已写好 `ELITE_STYLE`（角标 `險` / 类别 `精英`）分支，判据是：

```gdscript
if ntype == "combat" and str(node.get("enemy_kind", "")).contains("elite"):
    visual = ELITE_STYLE
```

但 `map_snapshot.gd` 的节点字典是**显式 12 键白名单**（`id/type/label/layer/row/next_ids/reachable/
visited/current/visibility/revealed/build_relevance`）——**从来不写 `enemy_kind`**。

⇒ `node.get("enemy_kind", "")` 恒为空串，`.contains("elite")` 恒为 false。**该分支从未执行过。**

### 2.2 判据是 id 子串 ⇒ 即使键到位也会漏判 11/12

`data/enemies.json` 共 32 条，其中 `tier=="elite"` 有 **12** 条：

| 含 "elite" 子串 | 不含（子串判据漏判） |
|---|---|
| `ridge_elite_scout` | `thunder_crown_wolf` `venom_whisker_wolf_king` `sand_lurker_spider` `blood_forest_wolf` `dragon_eagle` `faction_guard` `school_elder` `clan_elder` `demon_path_adept` `slave_path_adept` `roaming_jiangshi` |

子串命中率 **1/12（8.3%）**。真正的判据只能是 `catalog.enemy_by_id[<id>].tier`。

### 2.3 为什么既有测试没抓到（这才是重点）

`tests/unit/test_wenzhen_map_screen.gd:324` 的夹具给节点写了
`"enemy_kind": "resolute_elite"`，于是 `elite_icon.text == "險"` 的断言**一直是绿的**。

但该 id **不在 `enemies.json` 里**（只存在于 `display_text.gd` 的陈旧常量表与
`test_b3_experience_gaps.gd` 的白名单里），而且**真实快照根本不会带 `enemy_kind`**：

> **测试的数据形状与生产数据形状不一致 ⇒ 断言在真实路径上永远为假却一路绿。**
> 这正是项目长期约定里第 2 条坑（「探针/测试的数据形状必须与真实数据一致」）的又一次复现。

另一条同等重要的观察：本轮的**红**不是「断言失败」，而是**文件解析失败被 GUT 静默跳过**——
`node_threat()` 尚不存在时，GUT 仍打印 `Tests 1514 / Passing 1514 / All tests passed`，
只有另抓 `SCRIPT ERROR` 才看得到 9 次 `Static function "node_threat()" not found`。
⇒ 再次印证「GUT 汇总行不可全信」。

---

## §3 落地

### 3.1 领域层：`MapGenerator.node_threat(node, catalog) -> "" | "elite"`

- **判据唯一真源** = `catalog.enemy_by_id[<id>].tier`，不是 id 子串。
- **读键顺序与战斗侧同源**（`run_battle_flow._start_battle` / `BattleCommandFacade.start`）：
  `enemy_roll`（E6 抽取）→ `enemy_kinds` → `enemy_kind`（锚点 / 关底台 / 旧存档）。
  该顺序抽出为 `MapGenerator.encounter_enemy_ids(node)`，避免快照与测试各写一套。
- **多敌遭遇任一精英即标记**：该键回答的是「这条路要不要走」（遭遇风险），
  **不承诺结算 tier**（两者在多敌遭遇上不等价，见 §5）。
- **迷雾纪律**：`revealed == false` 一律返回 `""`，与节点卡「未知 · ?」口径一致；
  非 `combat` 类型返回 `""`。
- 非目录 id（旧存档、手写桩）**不得**被猜成精英。

### 3.2 快照层：`map_snapshot` 每节点新增 `threat`

**只读投影、现算现给**：`threat` **不进 route、不进存档、无迁移成本**，
因此对进行中存档与既有门禁（`topology_mismatch`）零影响。

### 3.3 表现层：接线改为只认快照键

```gdscript
if str(node.get("threat", "")) == "elite":
    visual = ELITE_STYLE
```

`ELITE_STYLE` 本身（角标 `險` / 类别 `精英`）**未改一个像素**——本轮是把早就设计好的
视觉接到真实数据上，而不是新造视觉。

### 3.4 改动清单

| 文件 | 归属 | 内容 |
|---|---|---|
| `scripts/domain/map_generator.gd` | Logic | `+node_threat` `+encounter_enemy_ids`（+56 行，含文档注释） |
| `scripts/presentation/snapshots/map_snapshot.gd` | **Shared** | 节点字典 `+threat` |
| `scripts/presentation/screens/map_screen_view.gd` | Visual | 死分支改接 `threat`（净 -1 行） |
| `tests/unit/test_map_threat_marker.gd` | 新增 | 10 用例 / 64 断言 |
| `tests/unit/test_wenzhen_map_screen.gd` | 改 | 夹具形状改为真实数据形状（`enemy_kind` → `threat`）+ 新回归钉 |
| `tools/verify_map_threat.gd` | 新增 | 40 种子门禁（D0–D6） |
| `docs/contracts/2026-09-02-domain-ui-contract.md` | **Shared** | Map 行 `+threat` |
| `docs/contracts/module-interfaces/03-map-generation.md` | **Shared** | 公开接口 `+node_threat` `+encounter_enemy_ids`；节点契约注明 `threat` 不在 route 上 |

---

## §4 门禁实测

### 4.1 `tools/verify_map_threat.gd`（新增，40 种子）

```
===== D7 map threat projection over 40 seeds =====
nodes scanned: 6500
elite nodes by tier: 1105
  layer 1: 0
  layer 2: 0
  layer 3: 165
  layer 4: 375
  layer 5: 565
legacy id-substring hits: 418
mismatched=0  mislabelled=0
D7 PASS: threat is data-driven, layer-covering, fog-safe and read-only
```

| 门禁 | 内容 | 结果 |
|---|---|---|
| D0 | 反空转 canary（catalog / route / 精英计数非零） | PASS |
| D1 | **独立重算**（不复用被测函数）与 `node_threat` 逐点一致 | `mismatched=0` |
| D2 | L3/L4/L5 每层至少出现一次精英 | 165 / 375 / 565 |
| D3/D4 | 被标记者必须是 `combat` 且 `revealed` | `mislabelled=0` |
| D5 | tier 判据 ≥ 旧子串判据 | 1105 ≥ 418 |
| D6 | 只读性：幂等且不改写入参 | PASS |

> D1 刻意**不复用** `MapGenerator.node_threat` 重算，避免「用被测函数验证被测函数」的同源空转。

### 4.2 回归

| 项目 | 结果 |
|---|---|
| `tools/verify_map_threat.gd` | rc=0，`D7 PASS` |
| 聚焦（威胁投影 + 地图屏） | 25/25，170 断言 |
| 全量 unit（`-gdir res://tests/unit -gexit`） | **1525/1525**，51667 断言，`All tests passed` |
| `SCRIPT ERROR` | 9 条，全部为既有 `Key "tithing_cache"/"tide_aftermath"/"blood_vein_offering" not found`，与本轮无关（改动前同样存在） |
| 交互回归门 `verify_interaction_loop.gd` | 15 屏 `dead=[]`、`no_ui_click=[]`、`occluded=[]`（Rest `scrolled=1` 为既有滚动留痕），`AUDIT_DONE` |
| `pacing.json` / `enemies.json` / `nodes.json` / `loot_tables.json` | **零改动** |

---

## §5 已知不一致（**未修**，需另立任务）

`LootResolver.settle_victory` 只从 `battle["enemy_kind"]` 取 tier，而
`BattleCommandFacade.start` 仅在 `enemy_roll.size() == 1` 时把首个 roll 写进 `enemy_kind`：

| 遭遇形态 | `battle.enemy_kind` | 结算 tier | `threat` |
|---|---|---|---|
| 单敌 roll | `enemy_roll[0]` | 正确 | 一致 |
| **多敌 roll**（`beast_swarm_pass`，2 敌） | `""` | **common**（即使两只都是精英） | `"elite"`（按风险） |

⇒ 多敌遭遇**打得是精英、结算是 common**：既少给奖励，也不触发精英绑定代价。
`beast_swarm_pass` 是当前唯一的多敌模板。

**本轮不修的理由**：修它要动 `LootResolver`（全局唯一结算出口，Reachability 红线对象）
且会改变既有 32 局语料的掉落分布。本报告把它作为**独立缺陷**报出，等口径裁定。

---

## §6 未做 / 待裁定

### 6.1 🔴 L1/L2 结构性地零精英（数据事实，卡在 pacing 红线）

```
layer 1: 0    layer 2: 0    layer 3: 165    layer 4: 375    layer 5: 565
```

根因链（已逐环验证）：

1. 本层能抽到精英的**必要条件**：某主题在本层 `enemy_rank_min..enemy_rank_max` 区间内
   有 `tier=="elite"` 成员。
2. L1 `rank_max=1`、L2 `rank_max=2`；而**除 faction 外所有主题的精英最低 rank 都是 3**
   （beast 3 / cultivator 3 / anomaly 3；neutral 无精英）。
3. ⇒ L1/L2 只有 **faction** 主题能抽到精英（`ridge_elite_scout` / `faction_guard` / `school_elder`，均 rank 2）。
4. 而两个 faction 战斗模板**被 stage 门禁挡住**：`scout_crossing_raid` = `stage three`、
   `faction_guard_checkpoint` = `stage four`；`_pick_category_template` 会剔除
   `layer_index(stage) > layer_number` 的模板。
5. ⇒ L1/L2 的战斗池只剩 beast 主题模板 ⇒ **精英恒为 0**。

**结论**：一局的前 40%（前两个大层）**完全没有精英威胁方差**，肉鸽张力从 L3 才开始。
修它要动 `pacing.json`（`enemy_rank_max` 或锚点/stage），即 §3.1 那条红线 ⇒ **并入 pacing 裁定一起决策**。

### 6.2 `pursuit` 型固定精英不在范围内

`greedy_wanderer` 的 `type` 是 `pursuit`、敌人硬编码 `thunder_crown_wolf`（tier elite），
它是一场**固定**精英战却不被标记。固定敌人属设计常量、非 roguelike 方差，故本轮不纳入
（已用特征化断言 `test_boundary_fixed_enemy_pursuit_nodes_are_out_of_scope_for_now` 锁定边界并注明改法）。

### 6.3 视觉权重可再讨论（未做）

当前精英节点与普通战斗节点的差别是**角标字形 `險` + 类别词 `精英`**，颜色同为 `INK_MAP`。
"显性化"若要做到一眼可辨，可考虑朱砂角标或左侧标记线——但这属视觉设计裁定，本轮原样保留既有 `ELITE_STYLE`。

### 6.4 信息口径

`threat` **只暴露 tier（是不是精英），不暴露敌人身份**；且只对**已揭示**节点暴露。
未新增情报资源旁路，不触碰 `known_facts` / `intel_bonus` 等既有情报链路。

---

## §7 Shared 区修改声明（Agent Ownership 契约 §3 五步）

1. **声明文件**
   - `scripts/presentation/snapshots/map_snapshot.gd`
   - `docs/contracts/2026-09-02-domain-ui-contract.md`
   - `docs/contracts/module-interfaces/03-map-generation.md`
2. **原因**：执行 AGENTS.md 待办第 7 条「D7 精英节点显性化」。
   快照键 = 领域-UI 契约，新增只读键属 Shared 面；契约文档必须同步回写以防漂移。
3. **预期影响**：新增**只读**键 `threat`（`"" | "elite"`），**不删不改任何既有键、不扩命令面**。
   受影响屏：`Map` 一屏（节点角标/类别词）。
   受影响测试：`test_wenzhen_map_screen.gd`（夹具形状）、新增 `test_map_threat_marker.gd`；
   既有快照键消费者（交互门、smoke 门、`verify_b2_four_screens_render.gd`）**按键名读取，不受影响**。
4. **提交前运行**：`tools/verify_map_threat.gd`（40 种子）+ 聚焦（威胁投影 + 地图屏）
   + `-gdir res://tests/unit` 全量 unit + `verify_interaction_loop.gd` 交互门 —— 均已在 §4 记录。
5. **单独 commit**：见 §8。

---

## §8 工作树与回滚

- **回滚**：删 `map_snapshot` 的 `threat` 键 + `map_screen_view` 还原判据行；
  `node_threat` 与 `encounter_enemy_ids` 留着不影响任何既有路径（无人调用即惰性）。
  **无数据改动、无存档字段、无迁移**。
- **提交**：本轮为 Shared 批次，应**单独 commit**（不与其它在途工作流混提）。
  提交信息需分节列出：领域投影 / 快照键 / 表现层接线 / 测试与门禁 / 契约回写。
