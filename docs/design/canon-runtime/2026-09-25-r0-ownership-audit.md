# R0 全仓 Ownership / Authority 审计（Canon-driven 重构）

> 日期：2026-09-25。快照：main @ `65da8da2`。
> 任务：L0 换基裁定 `RUL-2026-09-25-001` 生效后的 R0 只读审计——回答一个问题：**一个《蛊真人》原著事实，要经过哪几层，最终才合法地变成 Web 游戏中的真实行为？**
> 本报告只读，不改生产代码、数据、Wiki 与裁定。每个重要判断附 file:line。配套登记：`docs/debt.md` 新增 4 条 REVIEW。
> 审计方法：三路只读探索（Godot 主链 / Web Lab 与数据 / 裁定与 Canon 链）+ 主线对关键引用逐条回读复核；条目计数用脚本解析 JSON 实测。

## 0. Inputs & Snapshot

- HEAD：`65da8da2`（`docs(debt): 休眠资产收口——A 档落地、B/C 档登记、L1 换基评审件`）。
- 生效裁定：`game/world-model/rulings/RUL-2026-09-25-001.json`，status=RULED（:76）。本审计不重新评审裁定，只核实实现差距。裁定关键定位：
  - frozen_invariants 五条（:20-26），含「曲线单真源」（:24）与「No Silent Fallback」（:25）；
  - GATE＝GAME_GENERATION_READY 六条件（:31）；Q1-A'（:36）、Q2（:41）、Q3（:46）、Q4（:51）、PRIO P0–P5（:56）；
  - supersedes `RUL-2026-09-19-010` 的「Godot = Canonical、Web = Disposable Prototype」（:18）。
- Effect Grammar 地位：`game/docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md:3-6` 已注记撤销「唯一权威/全局操作集冻结」；执行语义升级为 Web Effect Execution Contract，5 操作降为 V1 最小 verb 集。
- 产品载体：浏览器 Web 版是《问真》完整长线产品，入口 `game/wenzhen-web-lab/lab.html`；Godot 为规则与数据来源（`docs/PRODUCT_REQUIREMENTS_v1.0.md:16`）。
- 本轮只输出本报告 + debt 登记；Game Semantics 选址与实现属 P2。

## 1. L1 Plan Verification

对 Canon-driven 重构计划逐条核对（格式：计划假设 → 仓库现实 → 证据 → 修正）：

| Plan assumption | Repository reality | Evidence | Correction |
|---|---|---|---|
| 「建立最小 Canon IR（新增或复用 lore/runtime）」 | `lore/runtime` 已存在且超出第一版范围：entities 156 / rules 74（43 CAN + 31 页内）/ relations 2 / packs 2 | `lore/runtime/manifest.json` counts 节 | **扩展现有 Canon Runtime**，不新建；扩展点是四处配置（RULE_PAGES/RELATION_SOURCES/entity_pages/PACKS，`compile_runtime.py:42-89,354`） |
| 「game/world-model 成为唯一 Canon→Gameplay 翻译层」 | 该目录 2026-09-20 清理后仅剩 governance/、rulings/、reports/；Game Semantics 层不存在 | `PROJECT_MAP.md:64` | R0 只确认**Game Semantics 缺失**；目录选址属 P2，本轮不创建 |
| 「role=attack→strike 只能作为 Legacy fallback」 | 它是**现行生产路径**：Web 生成链用 `default_effect_by_role` + 生成期 `(rank-1)` 缩放产出蛊战斗效果；Godot 同构消费 | `build_data.mjs:100-107`；`v1_battle.json` default_effect_by_role；`v1_battle_resolver.gd:41` | 不是"存在 fallback"，是"约 740/802 全量消费 fallback"（见 §6 风险 1） |
| 「不要一次重写 800+ 蛊」 | gu.json 实测 802 条，仅 62 条带 `v1_effect` | 脚本计数 2026-09-25；`PROJECT_WORLD_MODEL_AUDIT.md` §25.1（旧快照 48 条，现为 62） | 数字修正：802 / 62 / 约 740；Legacy 迁移按 P5 批量 |
| 「Web Lab 必须明确身份，如发现 Web 重新实现同一能力则登记」 | 已登记：战斗不合并代码——Godot `v1_battle_resolver.gd` 与 Web `mvp_logic.js` 并行 | `EXISTING_CAPABILITY_MAP.md:98-107` | 无需"发现"；现状已登记，处置按裁定基准反转（Web=生产执行器，Godot=reference asset） |
| 「recipe=[A,B] damage=8 视为 Legacy」 | kill_moves 26 条多数带结构化 `effect` 对象；少数裸 damage 手填且带 override_reason 登记待迁移 | `v1_battle.json` kill_moves（26 条，脚本计数）；`km_force_avalanche` damage:8 + override_reason 引 `RUL-2026-09-21-010` | 定性为**半结构化**而非纯 Legacy |
| 「drop rate / balance value 不属于 Wiki」 | 边界已代码化：runtime 输出硬禁游戏数值键；lore_engine 禁写 game/data | `compile_runtime.py:91-92` BANNED_KEYS；`lore_engine/cli.py:30` MANDATORY_PRODUCTION_DENYLIST | 确认；无需新防线 |
| 「蛊师敌人应使用与玩家相同的力量模型」 | enemies.json 45 只全部是 hp+intent 型（damage/speed/cooldown/seal/soul_drain/essence_burn），无 gu_instances/essence/杀招结构 | 脚本计数 + 字段扫描 2026-09-25 | 确认为缺口（见 §6 风险 2），属 P4/P5 改造对象 |

## 2. Current Architecture

### 2.1 Lore 链（已建成）

```text
source/蛊真人-clean.txt（本地 only，不入 Git；原文 hash 变化则编译拒绝输出）
  ↓ 人工蒸馏（E:V / EVT / ST / CAN 证据链，schema v2.1 冻结）
lore/wiki/（约 78 页，AI 可读蒸馏层）
  ↓ py -3 lore/wiki/tools/compile_runtime.py（生成物，禁人工维护）
lore/runtime/（entities 156 / rules 74 / relations 2 / packs 2）
```

- 编译器校验：E-ID 段↔行号区间（`compile_runtime.py:207`）、BANNED_KEYS 数值禁入（:91-92）、关系引用实体必须存在；RELATION_SOURCES 现硬编码 3 条（:42-69）。
- 既有设计底稿：`docs/design/canon-runtime/2026-09-25-p0-audit.md`（多头维护与断点）、`2026-09-25-p1-ir.md`（IR v0.1 定义）。

### 2.2 Game Data → Web 链（唯一生成管线）

```text
game/data/*.json（15 个源文件）
  ↓ game/wenzhen-web-lab/tools/build_data.mjs（:12-24 读源清单）
js/data.js（7,570 行生成物；contentVersion = 全载荷 sha256，:7569；saveCompatibilityVersion = 'lab-run-v2'，:552→data.js:4）
  ↓ lab.html:81-101 顺序加载 21 个 JS 模块
Web Runtime
```

### 2.3 Web Runtime（生产执行器，21 模块约 16,600 行）

- 壳：`lab.html` 115 行，仅做脚本加载（:81-101）。
- 主链：`main.js`（2,004 行，run state/回合/落账，玩家效果落账 :794-870、敌方回合 :600-657）→ `mvp_logic.js`（640 行，CombatCore）→ `gu_rules.js`（802 行，effectPlan→applyPart :253-316、杀招组件合成 :320-356）→ `balance.js`（468 行，WORLD→LAB 投影 + `deriveEnemyHp` :267-272）→ `run_flow.js`/`journey.js`（节点与流程）→ `lab_save.js`（存档信封 :54-60）。
- **Canon 桥头堡（当前唯一自动消费链）**：`build_data.mjs` 从 `lore/runtime` 注入 `DATA.canon` → `js/canon.js`（只读查询层，:1-40，DATA.canon 为 null 时全部降级为空）→ `tests/canon_runtime.test.mjs:26-56` 三断言（contentVersion 绑定 committed manifest / 实体形状白名单防数值倒灌 / verified 转数漂移门）。
- 测试：`game/wenzhen-web-lab/tests/` 13 文件 4,472 行（node --test）。

### 2.4 Godot（reference asset，单实现）

```text
RunState(scripts/domain/run_state.gd:1) → submit_command(presentation/run_controller.gd:254)
  → Resolver.apply(scripts/domain/resolver.gd:114，_dispatch :123-228) → RunSnapshotBuilder(presentation/run_snapshot_builder.gd:1) → UI(只读快照+Command)
SaveRepository(save_repository.gd:9，SAVE_VERSION=4)；SeededRng(rng.gd:16，Lehmer LCG，domain 内无旁路随机)
```

- 132 个 .gd（domain 63 / presentation 67）；`game/lore_engine/` 是 Python 原著抽取工具链，`cli.py:30` 明确禁写 `data/`，不是游戏运行时。
- 三代战斗栈叠置与收敛裁决见 `game/MODULE-INVENTORY.md:52-60`（D2-D5 已裁决退役/收敛进 V1）。

### 2.5 ai-system 边界

- `game/` 全部 .gd 与 web-lab JS grep `ai-system` 零命中；`game/project.godot:18-20` [autoload] 仅 `AudioManager`。
- 结论：ai-system 是开发工具与裁定载体（裁定经 `adjudicated_via: ai-system/RESEARCH-REQUEST-*`，`RUL-2026-09-25-001.json:6`），产品 Runtime 零依赖。

### 2.6 冻结实验线

- `game/wenzhen-web-lab/experiments/FROZEN.md`：fast-loop 自带战斗/炼蛊/商店/掉落/存档，定性 **DUPLICATE**，禁当规则 Owner，产品入口唯一 `../lab.html`。

## 3. Authority Matrix

> 列定义：SOURCE_OF_TRUTH＝唯一真源；RUNTIME_EXECUTOR＝生产执行器；PROJECTION＝显式投影/派生；VERIFIER＝自动校验；REFERENCE/LEGACY/DUPLICATE＝参考资产/遗留/重复。Web 是正式产品载体（PRD:16），故不再使用「Godot = OWNER / Web = PROJECTION」旧口径。

| Capability | Source of Truth | Runtime Executor | Projection | Verifier | Reference/Legacy/Duplicate | Problem |
|---|---|---|---|---|---|---|
| Canon / Lore | `lore/wiki/`（schema v2.1 冻结，`lore/wiki/AGENTS.md:94`） | —（非运行时） | `lore/runtime/`（生成物） | compile_runtime 校验 + `lore/wiki/tools/check.ps1` | `game/docs/lore/canon-index.md`（43 CAN，L4 登记视图）；`gu_lore.json`（断头投影） | relations 仅 2；114 只裸名（manifest coverage_notes）；敌人 canon 库位置偏离（debt.md:45） |
| 蛊定义 | `game/data/gu.json`（802 条）+ rank canon 源页 `lore/wiki/gu/roster-3.md` | content_catalog.gd（Godot）；`DATA.gu`（Web） | `build_data.mjs` guView/_effect | `canon_runtime.test.mjs:45-55` 转数漂移门 | — | 62/802 有 v1_effect；rank 生效值 vs 原文 18 处 L0 改判 + blood_bat_gu 悬置（debt.md:41） |
| 蛊实例 | 运行时 state（Web `main.js:8-27` owned；Godot RunState） | CombatCore/`mvp_logic.js` | — | `tests/*.mjs` | 实例/定义分离原则（`PROJECT_WORLD_MODEL_AUDIT.md` §27） | Web 实战实例仅 4 只 MVP profile 手写（`mvp_content.js:144-152`） |
| 杀招 | 游戏预设：`v1_battle.json` kill_moves（26）；原著规则：`lore/wiki/rules/killer-moves.md` KM-* | `gu_rules.js:320-356` 组件合成（Web）；`v1_battle_resolver.gd`（Godot，reference） | — | `gu_rules.test.mjs:104-122` | `km_` 前缀撞 `KM-*`（debt.md:44，运行时用 `canon:KM-*` 区分） | 半结构化：少数裸 damage 手填（km_force_avalanche） |
| 炼蛊 | `refinement_recipes.json`（469：advance 377/promotion 76/fixed 15/free_mix 1）+ 原著规则 `lore/wiki/rules/refinement.md` REF-001..022 | `refine_command_rules.gd`（Godot）；Web 炼蛊入口 | — | `game/tools/verify_recipe_coverage.py` | GAME-GU-REFINEMENT-001..005 重述（三套口径，debt.md:43） | `moon_glow_fixed` retired:true（:14-15）被 moonlight_glow 严格支配；失败倾向纯 RNG |
| 战斗 | 语义/数据真源：`game/data` + 现行裁定 | **Web `mvp_logic.js`(CombatCore) + `gu_rules.js`＝生产执行器** | `balance.js` WORLD→LAB 投影（:25-49） | `tests/` 13 文件；C1–C5 待建（仅 1 条投影断言，`balance.test.mjs:83-85`） | Godot `v1_battle_resolver.gd`＝REFERENCE/RULE ASSET（RUL supersedes :18） | 未知 verb 静默 no-op（`gu_rules.js:297-298`，违反 invariant :25）；Effect Golden Cases 缺 |
| 敌人 | `enemies.json`（45 只，origin+origin_ref 43/45 带行号） | `main.js:600-657` 敌方回合 | 4 只 MVP profile 走 `hpFor`（`mvp_content.js:141-152`） | `check_balance.mjs` 仅覆盖 4 profile | — | hp/intent 型，无持蛊/真元/杀招；其余敌手写 hp 不走 derive、不被 checker 覆盖 |
| 掉落 | `loot_tables.json`（materials 7/pity/loot，**非** tier→reward 模式） | —（Web 无材料循环） | — | — | L0 裁定：Web 不保留独立材料循环（PRD:16） | Web 侧掉落系统已随 Phase 移除；敌人掉落语义（夺蛊/毁蛊/兽材）无处承载，属 P4/P5 |
| 商店/经济 | `shops.json`（38 offers）+ `balance.json` | `shop_command_rules.gd`（Godot）；Web 商店 | `LAB_EXCHANGE_RATE` 1:2（`balance.js:109`，代码常量） | — | — | 兑换投影硬编码，未走 projections.json 显式父子 |
| Rank | `balance.json` rank_power_budget 40/80/160/320/640（:17-23）+ `RUL-2026-09-19-008/011` | —（上游约束） | `LAB_BUDGET_PROJECTION=20`（`balance.js:49`） | `balance.test.mjs:83-88` | — | Q2 的 `effect_budget.default_amount_by_role` 30 值 **0/30 落地**；事实曲线在 `build_data.mjs:100-107` |
| 真元 | `v1_battle.json` true_qi_cost；舍利映射 `build_data.mjs:66-81` SARI_BY_RANK | CombatCore | `playerQi 12`（`balance.js:108`） | `l1_boundaries.test.mjs:60-69`（crossRankQiCost 0.65） | 原著口径 PE-*（runtime rules，domain=true-qi） | 真元品阶 5 处重述（P0 audit §1#8） |
| 念头 | kill_moves thought_cost；thought_base_capacity=3（`balance.js:107` 注释） | `thoughtsPerTurn=2` 硬编码（`balance.js:106`） | 同左（PROJECTION 注释级） | 无独立断言 | — | thought 真源未进数据文件；projections.json 有条目但运行时不消费 |
| 状态 | `buffs.json` + v1_battle status（marked/sealed） | `gu_rules.js:281-282` status；main.js 落账 | — | 部分测试 | sealed 待实现（`GU_EFFECT_GRAMMAR_V2_FINAL.md:47`） | consume_status 原子结算已定义（GRAMMAR:74-79）但 verb 集仅 V1 最小集 |
| 存档 | Web 信封 `{schemaVersion, contentVersion, state}`（`lab_save.js:54-60`） | `lab_save.js` + 版本迁移（`main.js:169-173`） | — | `lab_save.test.mjs:88-92` | Godot SaveRepository（SAVE_VERSION=4） | 双存档体系按载体分离（可接受）；生成物曾被手改（boss 蛊池），再生丢失风险（`docs/2026-09-25-l0-phase0-gate0-handoff.md:127`） |
| 地图 | `nodes.json` | `run_flow.js:166` pickEnemyIds（Web）；map_generator（Godot） | — | — | — | 节点=类型格子；「世界事件生成节点」属长期方向（L1 计划 §13） |
| Web Lab | —（产品载体，非真源） | `lab.html` + 21 模块（正式产品 Runtime） | `js/data.js`（生成物） | 13 测试文件 | fast-loop＝DUPLICATE 冻结（FROZEN.md） | 生成物手改风险（同存档行） |
| AI-system | — | — | — | — | 开发工具（任务包/评审/研究请求） | 无（产品零依赖，§2.5 已证明） |

## 4. Duplicate / Legacy Matrix

只登记影响 Canon-driven 重构的项：

| # | 项 | 现状 | 证据 | 目标 | 处置方向 |
|---|---|---|---|---|---|
| 1 | **role 曲线第二规则源** | `build_data.mjs:100-107` `defaultBattleEffect` 以 v1_battle `default_effect_by_role` 为基数 + 生成期 `(rank-1)` 缩放（attack 2/3/4/5/6 等），与裁定目标 30 值（attack 4/6/8/11/16 等）全面不一致 | `build_data.mjs:100-107`；`RUL:41` | `balance.json effect_budget.default_amount_by_role` 单真源 → projection policy → build_data 纯映射 | P2（Q2 落地）；debt 已登记 |
| 2 | **v1_battle.json 数值第二真源** | 除 role→kind 外仍持有 amount（:8-36）、aptitude_mult（:2-7）、regen_pct（:37-42）、stage_base（:43-49）、boss_layer_mult、26 条杀招效果量 | 本审计 §3 | 只存 role→default semantic kind，数值迁 balance.json/语义层 | P2 |
| 3 | **双战斗 Runtime** | Godot `v1_battle_resolver.gd`（reference asset）与 Web `mvp_logic.js`+`gu_rules.js`（生产执行器）并行，**手工同步面**＝counter token 白名单（`l1_boundaries.test.mjs:16-51` 把 Godot 源码当 token 来源之一）+ role fallback mirror 断言（`gu_rules.test.mjs:125-130`） | `EXISTING_CAPABILITY_MAP.md:98-107` | 语义规则单源（Game Semantics），Godot 只作参考资产；Web 不与 Godot 逐行为同步 | P2 建语义层后逐步缩小手工同步面 |
| 4 | **Kill Move 半结构化** | recipe 已结构化，但少数条目裸 damage 手填（km_force_avalanche + override_reason 登记待组件化迁移） | `v1_battle.json` kill_moves | 效果＝组件+结构规则+投影参数，杀招本体不脱离组件手填 | P2/P4 |
| 5 | **gu_lore.json 断头** | 270 条人工投影，web-lab 与 Godot 均不读取 | P0 audit §2（`docs/design/canon-runtime/2026-09-25-p0-audit.md`） | 改为编译产物或归档 | P1/P5 |
| 6 | **projections.json 消费面不足** | schema 达标（parents/policy/validation/forbidWriteBack，:6-57 四条）且被 `tools/check_projection.mjs:38,55` 校验，但运行时仅 rank budget 走数据（`balance.js:71-78`）；thoughtsPerTurn=2 / playerHp=24 / 兑换 1:2 是代码常量（`balance.js:106-109`、`mvp_content.js:20-27`） | 本审计 §3 | 投影差异全部经 projections.json 显式父子消费 | P2/P3 |

## 5. Wiki → Game 断点

```text
lore/wiki ──GENERATE──> lore/runtime ──?????????──> game/data ──GENERATE──> js/data.js ──EXECUTE──> Web Runtime
                                   ▲
                    问号 ＝ Game Semantics / Binding（当前缺失）
```

- 唯一现存自动链：`DATA.canon` 只读注入 + 转数漂移门（§2.3），只做查询/校验，不生成 Gameplay。
- 覆盖量化（2026-09-25）：entities 156/270（rank 编译口径；114 只仅有蛊名无 id，未编译，`lore/runtime/manifest.json` coverage_notes）；rules 74；relations 2（月光系 supports + 月芒 refinement）；packs 2（`south_border_rank1_combat`、`rank1_refinement`，消费方为零）；RULES 簇独立出题首测 **24.5/50 FAIL**、24 项缺口登记于 `lore/wiki/tools/benchmark-rules.md`（`lore/wiki/log.md` A 线条目）。

### GAME_GENERATION_READY 六条件逐项（按裁定 GATE :31）

| # | 条件 | 状态（月光切片口径） | 依据 |
|---|---|---|---|
| ① | 独立 Wiki-only benchmark ≥45/50 | **PARTIAL** | ZYL 簇 48.5/50 达标（`benchmark-zyl.md` 登记表）；月光相关簇未独立出题复测；RULES 簇 24.5/50 FAIL |
| ② | 关键 Canon Rule/Entity/Relation 已编译进 Canon Runtime | **PASS（切片内）** | moonlight_gu/small_light_gu 实体页 merge（`compile_runtime.py:321`）+ roster-3 rank；relations 2 条全部属于本切片；REF/KM 规则已编入 |
| ③ | 切片关键字段无 UNKNOWN/裸名占位 | **PARTIAL** | 三蛊在 gu.json 均有 v1_effect 非裸名（gu.json:3/:48/:88）；但效果值来源＝手填 + ADP 登记（ADP-SMALL-LIGHT-001），未走 Semantics binding |
| ④ | Canon→Game Semantics binding 明确 | **FAIL** | 层不存在（§1 核对行 2） |
| ⑤ | Runtime conformance 全通过 | **FAIL** | C1–C5 仅 C3 一条存在（`balance.test.mjs:83-85`）；C2 Golden Cases、C4 fail-fast、C5 provenance 均无 |
| ⑥ | 切片核心玩法不依赖 legacy_role_fallback | **FAIL** | 生成链仍以 role fallback 曲线为基底（`build_data.mjs:100-107`），效果量来自 `default_effect_by_role` 而非 Canon projection |

结论：月光切片当前 **KNOWLEDGE_READY（部分）/ SEMANTICS_READY FAIL / GAME_GENERATION_READY FAIL**。P0–P4 就是把 ①→⑥ 逐条转绿的最短链。

## 6. 换皮风险 Top 5（按产品风险排序）

1. **约 740/802 蛊依赖 role fallback 同质化**——名字不同、行为趋同（attack→strike、defense→shield…），`PROJECT_WORLD_MODEL_AUDIT.md` §25.1 早已列为最高风险，现状未变（§1 核对行 3/4）。
2. **敌人仍由 hp/intent/damage 定义**——敌人身份不决定持蛊、真元、杀招、资源与掉落；45 只全部 hp+intent 型（§1 核对行 8）。「敌人是什么人决定他怎么打」目前无承载结构。
3. **Kill Move 半结构化**——组件 recipe 存在，但最终效果仍有手填裸值；「杀招=组件+结构规则+投影参数」未成立（§4#4）。
4. **Canon Runtime 关系密度不足**——entities 156 但 relations=2、packs 消费方为零；实体多而世界关系不足以驱动 Gameplay（§5 量化）。
5. **未知 Effect Verb 静默 no-op**——`gu_rules.js:297-298` `default: break`：Canon 新机制看似进入数据，Runtime 实际什么都不做，且无任何告警。这是最危险的一条，直接违反裁定 frozen_invariant :25。

`km_` vs `KM-*` 命名冲突不进 Top 5，已入 debt（debt.md:44）。

## 7. Authority Map

```text
                      CANON AUTHORITY（游戏不可反写）
                 source/蛊真人-clean.txt（本地 only，hash 锁版本）
                              │ 人工蒸馏（E:V/EVT/ST/CAN 证据链）
                              ▼
                         lore/wiki ＝ SOURCE_OF_TRUTH（schema v2.1 冻结）
                              │ GENERATE（py -3 lore/wiki/tools/compile_runtime.py）
                              ▼
                        lore/runtime ＝ 生成物（156/74/2/2）
                              │ PROJECT（当前唯一自动消费：DATA.canon 只读 + 转数漂移门）
                              ▼
                  Game Semantics ＝ [MISSING]（P2 选址与实现）
                              │ COMPILE
                              ▼
                        game/data ＝ 语义/数据真源层（balance/gu/v1_battle/…）
                              │ GENERATE（tools/build_data.mjs，唯一生成管线）
                              ▼
                js/data.js ＝ 生成物（contentVersion=sha256；不得人工手改）
                              │ EXECUTE
                              ▼
              Web Runtime（lab.html + 21 模块）＝ 生产执行器（不是数据真源）
                              │
                              ▼
                             UI（只读快照 + 提交 Command）

  Godot domain（RunState→Resolver→Snapshot→SaveRepository）
      └── REFERENCE / RULE ASSET：成熟规则与已验证设计来源；
          不作 Web 行为上游，不要求与 Web 逐行为同步（RUL supersedes RUL-010，:18）

  人工同步链（当前全部漂移风险所在，标注 MANUAL SYNC / DRIFT RISK）：
      ① lore 事实 → 人读原文定值 → 手写 game/data（唯一活跃 lore 通路，P0 audit §2）
      ② Godot v1_battle_resolver.gd ↔ Web gu_rules.js/mvp_logic.js 手工同步
         （counter token / role fallback mirror 断言锁的是现状而非机制）
      ③ build_data.mjs 内嵌 role 曲线与 SARI_BY_RANK（Q2 落地后收敛为纯映射）
      ④ canon-index / adaptation-register / game-rule-register 人工登记层
         （43 CAN / 8 ADP / 31 GAME-*，无代码链路，靠纪律对齐）
```

读法：能**编辑**的只有 lore/wiki（人工蒸馏）与 game/data（语义真源）；`lore/runtime` 与 `js/data.js` 只能**生成**；Web Runtime 只**执行**；Godot 只**参考**；四条人工同步链是 P1–P3 要逐条消除的对象。

## 8. 最小月光垂直切片（审计定义，不实现）

资源确认：

- `moonlight_gu`（gu.json:48，rank1，v1_effect strike 3 + ignoreEvasion + synergy_hooks [light_combo]）、`small_light_gu`（:3，rank1，strike 1 + support_school:light + support_bonus:2 + inspect）、`moon_glow_gu`（:88，rank2，strike 4 + suppress）。
- 炼方：`moon_glow_fixed`（refinement_recipes.json:4-15）＝月光×1+小光×2→月芒，**retired:true**（「L0 2026-09-25 Phase 4：被 moonlight_glow 严格支配（同产出、多投入）」）；替代方在同文件 promotion/fixed 段。
- 杀招：`km_light_converge`（v1_battle.json kill_moves，月光系组件合成）。
- Canon Runtime：两实体页 + roster-3 rank 已编译；relations 2 条＝本切片；REF-001..022/KM-001..018 规则在 runtime rules；packs 2 个含 south_border_rank1_combat。
- 已有测试：`tests/canon_runtime.test.mjs:26-56`（manifest 绑定 / 形状白名单 / 转数漂移门）+ 月光+双小光→月芒古方断言（:65-80）。

切片缺口清单（11 项）：

| 项 | 状态 | 说明 |
|---|---|---|
| Canon Entity | PASS | 三蛊 rank 已编译/可编译（roster-3 + 实体页） |
| Canon Relation | PASS | relations 2 条即 supports + refinement，全部属于本切片 |
| Canon Rule | PARTIAL | REF/KM 已编入；月刃消耗等缺口题不可答（debt.md:46，IR v0.2 输入） |
| Game Semantic Binding | FAIL | 层缺失；小光增幅靠 ADP-SMALL-LIGHT-001 人工登记，无 binding 对象 |
| Effect Runtime | PARTIAL | V1 verb 集已实现（gu_rules.js:253-300）；consume_status 原子/事务纪律未全落地；unknown verb no-op |
| Kill Move Composition | PARTIAL | km_light_converge 走组件合成（:320-356）；库里仍有裸 damage 手填条目 |
| Refinement Binding | PARTIAL | moon_glow_fixed retired，替代方与 canon 输入一致；kind 枚举三套口径未统一（debt.md:43） |
| Enemy Usage | FAIL | 45 只敌 hp/intent 型，无持蛊敌可验证「敌人失去某蛊后打法改变」 |
| Derived Loot | FAIL | Web 无材料循环（PRD:16）；夺蛊/毁蛊/兽材掉落无处承载 |
| Context Pack | PARTIAL | 2 个 pack 已生成，消费方为零（无 Runtime/Agent 实际读取） |
| Conformance | PARTIAL | canon 三断言 + 1 条投影断言；C1/C2/C4/C5 缺 |

## 9. 执行序：P0–P5（沿裁定 PRIO :56，不新增 R1–R9 编号）

- **P0 Knowledge Ready**：补 RULES 簇独立 benchmark 缺口（`lore/wiki/tools/benchmark-rules.md` 24 项），目标独立 Wiki-only ≥45/50。不补 114 只裸名蛊。
- **P1 Canon Runtime Ready**：扩展现有 `lore/runtime`，只针对月光 slice——relations（月刃/增幅链）、实体页 merge 扩到 moon_glow_gu、pack 对齐切片；`compile_runtime.py` 四处配置驱动（:42-89）。禁止批量长尾。
- **P2 Semantics Ready**（架构批，届时定 Game Semantics 物理目录）：Effect Execution Contract 落地（`GU_EFFECT_GRAMMAR_V2_FINAL.md:25-102` 事务纪律为契约）；Q2 落地——`balance.json` 增 `effect_budget.default_amount_by_role` 30 值、`v1_battle.json` 瘦身至 role→kind、`build_data.mjs` 降为纯映射/投影、`gu_rules.js` unknown verb fail-fast；MVP 四蛊 explicit_projection_exception（有 parent/policy/forbidWriteBack）。
- **P3 Conformance Ready**：C1–C5 进现有 node --test——C1 数据生成一致（月光切片 source→generated）、C2 效果 Golden Cases、C3 WORLD→LAB 投影（40/80/160/320/640→2/4/8/16/32）、C4 删 binding 必失败、C5 canon_driven_v1 无 ref 必失败。
- **P4 Game Generation Ready**：月光 Rank1 切片六条件全绿；核心玩法不依赖 legacy_role_fallback；换皮测试（名称→ID 仍可辨认机制）。
- **P5 Scale Out**：批量补长尾（114 只裸名蛊、敌人持蛊化、配方、杀招、Context Packs）。coverage 填表不得插在架构闭环之前。

## 10. Do Not Change

- **Godot 主链（单实现、确定性、纯函数，有稳固地基）**：RunState（`run_state.gd:1`）、Resolver（`resolver.gd:114,123-228`）、SeededRng（`rng.gd:16`）、EventLog（`run_state.gd:63` + `events.gd`）、RunSnapshotBuilder（`run_snapshot_builder.gd:1`）、SaveRepository（`save_repository.gd:9`）。除非独立证据证明问题，否则不碰。
- **Wiki**：Schema v2.1 冻结（`lore/wiki/AGENTS.md:94`）；不要 v3、新 frontmatter、GraphRAG/Neo4j/Qdrant、全文 embedding 驱动 Gameplay。
- **Lore Engine**：保持 deny write to game/data（`lore_engine/cli.py:30`）。
- **AI-system**：保持开发工具定位，不进产品 Runtime（§2.5）。
- **fast-loop**：保持冻结 DUPLICATE（`experiments/FROZEN.md`），不删除素材页面，不复活为 Runtime。
- **裁定与其 effects 注记**：`RUL-2026-09-25-001` 及其对 `GU_EFFECT_GRAMMAR_V2_FINAL.md`/`ai-system/tasks/p3b1-role-curves.md`/`RUL-2026-09-19-010` 的注记不再改动。

## 11. 风险与回滚

- **存档兼容**：改变在途状态结构须提升 `saveCompatibilityVersion`（现 `lab-run-v2`，`build_data.mjs:552`）并提供迁移/拒绝策略；`contentVersion` 为全载荷 sha256，仅作快照追溯（`data.js:7569`）。
- **生成物纪律**：`js/data.js` 不得手改（已有手改丢失前科，handoff :127）；再生成必须从 `game/data` 真源出发。
- **Canon/Game 边界**：新增 Gameplay 语义须走 ADP-* 登记（`game/docs/lore/adaptation-register.md`，现 8 条）；runtime 侧 BANNED_KEYS（`compile_runtime.py:91-92`）与 web 侧实体形状白名单（`canon_runtime.test.mjs:34-43`）双向防倒灌，扩字段时同步维护。
- **门禁**：Wiki 侧 benchmark ≥45/50（必要非充分）+ GATE 六条件（RUL :31）+ Q2 批 B 五条验收（RUL :41）。
- **回滚方式**：P2/P3/P5 各自独立提交、独立回滚；Semantics、Conformance、Migration 不得混入一个大提交；行为变更前先落Verifier（测试）再动数据，失败即 revert 单个提交。

## 12. 层链答案

一个原著事实合法变成 Web 行为的完整路径：

```text
原著 → Wiki Canon → Canon Runtime → Game Semantics → Game Data
     → Generated Web Data → Web Runtime
```

其中：Canon 不可被游戏反写（BANNED_KEYS + 形状白名单双向锁）；generated 文件不作规则真源；Runtime Executor 不偷偷创造世界规则（无隐藏 Rank 倍率、unknown verb fail-fast）；Godot 作为成熟规则资产来源存在；Web 作为正式产品 Runtime 存在；两者不再依赖人工双线同步——人工同步链（§7 ①—④）由 Game Semantics 层与编译链逐条吸收，这正是 P0–P5 的全部内容。
