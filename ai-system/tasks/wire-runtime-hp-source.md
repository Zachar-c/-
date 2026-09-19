# P2.1 · 接通 game runtime 开局气血真源（清除裸 80）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → P3（统一 Effect 管线）

PROJECT GOAL
把《蛊真人》做成游戏。经 L1 架构裁决，「1–5 转」是综合层级轴；资质/真元与肉身/HP 是
两条**必须独立**的成长轴。

CURRENT PHASE
P1（转数语义）+ P2（Rank Power Budget，RUL-2026-09-19-008）已完成。
L1 于 2026-09-19 就「开局气血」重裁：**取 100**，论证改为「保持资质轴与肉身轴语义独立」，
权威文本 `world-model/rulings/RUL-2026-09-19-009.json`（修订 008 的 D11）。
**本任务是给 P2 收尾的一个小任务：把 game runtime 的开局气血接到唯一真源。**

TASK PURPOSE
P2 之后世界模型侧已全线 100，而**可玩 Godot 游戏仍是 80**，构成**实现漂移**
（不是两个合法真源）。本任务把这处漂移闭合，让「玩家实际跑的气血」与
「所有平衡结论依据的基准」一致。

TASK

**A. 定位并清除 runtime 侧的开局气血裸字面量**

已由 L2 逐行核实，清单如下（**这是完整清单，L1 口述的「3 处」系近似，请以本清单为准**）：

| 位置 | 现状 | 处置 |
| --- | --- | --- |
| `game/scripts/domain/run_state.gd:16` | 注释 `# …、80 气血、` | 更新为 100 并说明基准口径 |
| `game/scripts/domain/run_state.gd:18` | `var health: int = 80` | 不得再是裸字面量 |
| `game/scripts/domain/run_state.gd:19` | `var max_health: int = 80` | 同上 |
| `game/scripts/domain/run_state.gd:112` | `"health": 80,`（`new_run` 内 `state.cultivator`） | 同上 |
| `game/scripts/domain/run_state.gd:113` | `"max_health": 80,` | 同上 |

目标：**开局气血从「唯一配置」读取 100**，而不是在 runtime 里再写一次数。
唯一配置已由 P2 建好，直接用现成访问点：

- `GuBalance.player_start_hp(cat)` —— P2 已新增（`game/scripts/domain/gu_balance.gd`）
- `CultivatorRules.player_start_hp(cat)` —— P2 已新增的薄委托

**B. 接线方式**

`RunState.new_run()` **没有** catalog 参数；`run_controller` 已有现成的接线先例可照抄：

```gdscript
# game/scripts/presentation/run_controller.gd:196-198
state = RunState.new_run(seed_value, meta)
state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
```

请采用**与上例同构**的最小写法，在 run 创建处把开局气血从 catalog 写入 state
（`state.health` / `state.max_health` / `state.cultivator["health"]` / `state.cultivator["max_health"]`）。

**重要约束：`new_run(run_seed, meta)` 的签名尽量不动。** 它的调用点很多：

```text
生产 2 处：game/scripts/presentation/run_controller.gd:196, :224
工具 5 处：game/tools/{q8f_f8_simulate,verify_rest_headless,verify_stage1_slice×4}.gd
测试 20+ 个文件：game/tests/unit/**、game/tests/integration/**
```

因此：
- **首选**：保持签名不变，新增一个显式的「应用开局气血」步骤（静态函数或 run_controller 内联），
  由 run 创建的两个入口调用。
- **次选**：`new_run` 加**可选**第三参（默认空 → 回退到具名常量），保证既有调用点零改动。
- 若你判断必须改签名并波及 **>5 个调用点** → **停止并上报**，不要大面积改测试。

若最终仍需一个回退常量，它必须是**具名的、单处声明的**（例如 `const START_HP_FALLBACK`），
**不得留裸字面量**，且其值必须等于 100 并在注释里指明它与 `player_start_hp` 的关系。

**C. 文档对齐（spec 与 runtime 不得互相打脸）**

`game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md:18` 现写：

```jsonc
"hp": 80, "max_hp": 80,        // 出身气血（cultivator.health，随重做 80）
```

请同步为 100 口径并注明依据（`RUL-2026-09-19-009`）。

**D. 加一条「runtime ↔ 模型」一致性断言**

现在没有任何断言把 runtime 的开局气血与配置绑在一起——这正是漂移能存在的原因。
请在 `game/tests/unit/test_world_model_bridge.gd` 增加断言，使三处**必须相等**：

```text
RunState.new_run(<seed>).health  ==  GuBalance.player_start_hp(catalog["balance"])
                                 ==  world-model 派生镜像 run.starter.hp
```

注意：`WorldModelBridge` **目前没有** starter 访问点（现有 API 只有 gu/enemy/recipe/shop/balance-economy）。
你需要新增一个最小只读访问点（如 `WorldModelBridge.starter()`），命名与既有风格一致。
该断言必须**能被负控触发**：临时把任一侧改坏，测试必须失败（照 `SABOTAGE` 的既有做法，
若沿用 SABOTAGE，注意 `test_gate_is_not_left_sabotaged` 的存在）。

SCOPE
只读：`game/data/**`、`game/world-model/**`、`game/scripts/**`、`game/tests/**`、`game/docs/**`
可写（**仅这些**）：
- `game/scripts/domain/run_state.gd`（清除裸字面量）
- `game/scripts/presentation/run_controller.gd`（接线，两个 run 创建入口）
- `game/scripts/domain/world_model_bridge.gd`（新增 starter 只读访问点）
- `game/tests/unit/test_world_model_bridge.gd`（新增一致性断言）
- `game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md`（文档对齐）
- **仅因本改动而失败的测试**（见 ACCEPTANCE 的分类要求）
- `ai-system/tasks/wire-runtime-hp-source-result.md`（结果包）

DO NOT
- **禁止改任何其他数值**：气血恢复/静养、敌人、伤害、真元、经济、掉落、难度一律不动
- **禁止改 `game/data/balance.json`**（P2 已定稿，本任务只消费）
- **禁止手改 `game/world-model/data/**`**（派生镜像，改了会被构建器覆盖并触发漂移告警）
- **禁止为「让测试变绿」而批量 sed 替换测试里的 80**——必须先分类（见 ACCEPTANCE）
- **禁止引入「资质 → HP」的任何耦合**（L1 明令：资质与肉身是独立轴；
  `player_start_hp` 就是独立常量，**不要**写成 `100 × 资质系数`）
- 禁止 commit / push / merge / stash / reset
- 禁止新增依赖

DECISION AUTHORITY
可自行决定：接线函数的具体形态与命名、新访问点的命名、测试写法、失败测试中「夹具值」的更新方式。
**不可自行决定**：开局气血的值（已裁定 100）、是否让 `player_start_hp` 依赖资质、
是否改动 `new_run` 的既有调用点语义。

ESCALATE WHEN
- 接线必须改 `new_run` 签名并波及 >5 个调用点
- 某测试失败**不是夹具写死 80**，而是反映了对 80 的**真实语义依赖**（例如某条规则假定
  玩家气血低于标准一转）→ 停止并上报，不要改测试去迁就
- **存档兼容**：旧存档里 health/max_health 是 80。载入旧档时该给 80 还是迁移到 100？
  L2 未获授权代决 → **只调查、写下现状与风险，在结果包 QUESTIONS 里上报，不要自行加迁移逻辑**
- 发现除 `run_state.gd` 之外还有第三处 runtime 开局气血来源

DELIVERABLE
1. `run_state.gd` 裸字面量清除 + runtime 接线
2. `test_world_model_bridge.gd` 新增 runtime↔模型一致性断言（含负控证据）
3. `v1-battle-schema.md` 文档对齐
4. **`ai-system/tasks/wire-runtime-hp-source-result.md`**（Caveman Review Packet）

ACCEPTANCE
- `python game/world-model/tools/accept.py --smoke 10` 退出码 0（**应当不受影响**——sim 侧本来就是 100；
  若它变了，说明你误改了模型侧，停下来上报）
- `python game/world-model/tools/check_upstream_drift.py` 退出码 0
- Godot 桥门禁：`pwsh -File game/tools/test.ps1 -Test tests/unit/test_world_model_bridge.gd`
  通过；**且负控打开时必须失败**（否则门禁失效）
  > 跑法坑（L2 实测）：**裸 `-gtest` 会挂死**，必须走 `game/tools/test.ps1`。
  > 依据 `game/docs/wiki/entities/verification-toolchain.md:27`
- Godot 全量 unit 通过：`pwsh -File game/tools/test.ps1 -Suite unit`
  （全量约 2 分钟，建议后台跑；`test.ps1` 的参数是 `-Suite unit|integration|all` 或 `-Test <相对路径>`）
- **测试失败分类清单**：逐个列出因本次改动而失败的测试，并标注
  「夹具写死 80（已更新为 100/读配置）」或「真实语义依赖（已上报）」。禁止无差别替换。
- `rg` 证据：`game/scripts/` 下不再有开局气血的裸 `80`
- **不得出现**「资质 → HP」的耦合代码
- `git status --porcelain` 只显示本 SCOPE 内文件
- 结果包写入 `ai-system/tasks/wire-runtime-hp-source-result.md`

STATUS TARGET
READY_FOR_RUNTIME_HP_REVIEW
```

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 重裁原文 | `game/world-model/rulings/RUL-2026-09-19-009.json`（L1 逐字文本在 `decisions[D11-REVISED].ruling_verbatim`） |
| 008 D11 已标记修订 | `RUL-2026-09-19-008.json` 的 `decisions[10].revised_by = RUL-2026-09-19-009` |
| 上游唯一配置 | `game/data/balance.json`：`standard_human_hp=100`、`player_start_hp=100`、`player_start_hp_ratio=1.0`、`hp_note_zh` |
| 派生镜像 | `game/world-model/data/balance.json` → `entities[0].run.starter.hp = 100`，`hp_source = "player_start_hp"` |
| 经济资源上限 | `game/world-model/data/economy.json` health `start_value/hard_cap` 已 = 100（P2 已改） |
| 现成访问点 | `GuBalance.player_start_hp(cat)` / `GuBalance.standard_human_hp(cat)`；`CultivatorRules.player_start_hp(cat)`（薄委托） |
| 接线先例 | `run_controller.gd:197`（`essence_max` 从 catalog 写入 state） |
| 接线入口 | `run_controller.gd:196`（`start_new_run`）、`:224`（`start_m0_run`）；`_ensure_catalog_loaded()` 在两者之前已调用 |
| 平衡副作用（已量化，勿重复测量） | 80→100：通关率 68.0%→70.0%（同种子 200 局）、气血耗尽死 3→0、终局气血均值 66.8→87.6；其余指标基本不动 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台 gb2312，**必须** `PYTHONIOENCODING=utf-8` |
| 本仓 `.ps1` 必须纯 ASCII | PS 5.1 按 ANSI 解析无 BOM 文件；跑 `.ps1` 用 `pwsh` |

## GIT（执行前必读）

工作树有**大量未提交改动**，多数不属于本任务，禁止触碰或回滚：

```
 M AGENTS.md / PROJECT_MAP.md / ai-system/PRD.md
 M game/AGENTS.md                              (L2 已写：转数语义 + 开局气血基准两条不变量)
 M game/data/balance.json                      (P2 产出)
 M game/scripts/domain/{gu_balance,cultivator_rules}.gd   (P2 产出)
 M game/world-model/{data/balance.json,data/economy.json,data/manifest.json,
                     tools/build_world_model.py,tools/validate_world_model.py,
                     tests/run_tests.py,reports/*}
 M game/export_presets.cfg / game/scripts/domain/loot_resolver.gd
 M game/tests/unit/test_battle_save_load_semantics.gd / test_export_presets_exclude_filter.gd
 M lore/wiki/**   (多个页面在途，与游戏无关)
?? game/world-model/rulings/RUL-2026-09-19-00{4..9}.json
?? ai-system/**、docs/superpowers/plans/2026-09-19-rank-foundation-implementation.md
```

`game/scripts/domain/run_state.gd` **当前是干净的**（未修改）——本任务将首次改它。
执行前跑 `git status --porcelain` 自查；与上述不符或与本 SCOPE 冲突则停止上报。

## Execution rules

- Worker class: `normal`。
- 改 `game/scripts/` 与 `game/world-model/` 前先 `python game/world-model/tools/snapshot.py take runtime-hp`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/wire-runtime-hp-source-result.md`**。
