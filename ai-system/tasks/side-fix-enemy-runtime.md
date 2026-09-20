# SIDE-FIX · 敌人运行时补线（phases / essence_burn）+ data→runtime 契约测试

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → P3-B

PROJECT GOAL
把《蛊真人》做成游戏。当前阶段经 L1 裁决：**Godot = Canonical（唯一规则权威源）**，
Web = Disposable Prototype（RUL-2026-09-19-010）。

CURRENT PHASE
P3 的数值分配公式仍在等 L1（`RESEARCH-REQUEST-2026-09-19-p3-effect-budget.md` 未回复），
故 P3-B 未开。本任务是 L1 同批裁定的**旁支修复**，与 P3 数值无关，可立即执行。

TASK PURPOSE
本项目当前最大的质量缺口不在引擎能力，而在**数据 ↔ 规则的接线**。
实测证据（L2 已逐条复算）：敌人数据里设计完备、甚至写了严格 schema 校验的东西，
**运行时根本没有消费点**，导致「AI 很呆」、反击永不可解。
L1 已裁定：`phases` GO、`essence_burn` GO、`sparked` 有明确语义才 GO，
并**新增一条最小 data→runtime contract test** —— 本任务就是把这四项落地。

TASK

## A. `phases` 运行时（L1: GO）

**数据现状**：32 个敌人中 5 个带 `phases`
（`miasma_vein_lord` / `thunder_crown_sovereign` / `blood_vein_bishop` / `clan_patriarch` / `blue_fur_jiangshi`）。
`game/scripts/domain/enemy_catalog.gd` 已为它写了**严格 schema 校验**
（`until_hp_ratio` 落在 `(0,1]`、严格递减、`intents` 非空、`cooldown` 合法）。
但 `until_hp_ratio` 在 `game/scripts/` 下**只出现在那个校验文件里**——没有任何运行时按血量比选阶段。
后果：这 5 个 Boss 打起来与单意图杂兵完全一样。

**数据形状**（`thunder_crown_sovereign`，节选）：

```json
"phases": [
  { "until_hp_ratio": 1.0, "intents": [ {"id":"crown_bolt","label":"雷冠贯落","damage":4,"speed":2,"cooldown":1} ], "reactions": [] },
  { "until_hp_ratio": 0.5, "intents": [ {"id":"crown_bolt",...}, {"id":"paralyzing_howl","label":"麻痹长嗥","damage":0,"speed":2,"essence_burn":2,"cooldown":2} ], "reactions": [] }
]
```

**要实现的三条语义**（照 `game/wenzhen-web-lab/js/rules.js:46/63/71` 的 `activePhase` /
`intentReady` / `selectIntent`，那是本轮唯一已验证的参照实现；**只读参照，禁止 import**，
Web 是 Disposable Prototype，不得成为第二规则权威源）：

1. **选阶段**：当前阶段 = 数据顺序中**最后一个 `until_hp_ratio >= 当前血量比`** 的阶段
   （阈值按数据顺序严格递减）。
2. **选意图（含冷却门禁）**：`cooldown: n` 表示第 T 回合发出后，**最早 T+n+1 回合**才能再选。
   当前阶段所有意图都在冷却时，该回合敌方**什么都不做**（`cooldown_wait`）。
   多意图之间的优先级**数据未写明** → 取**数据顺序**，并在结果包里标注这是原型口径。
3. **阶段切换要有可观测记录**（战报 / 事件日志），供表现层呈现。

**语义说明的作者出处**：`data/enemies.json` 里 `miasma_vein_lord._phases_note` 是**唯一**写了
语义的字段（其余 4 个 Boss 没写）。以它为准；若它与上面的三条冲突，**停止并上报**。

## B. `essence_burn` 结算（L1: GO）

**现状**：`essence_burn` 在 `game/scripts/` 下**零命中**。
`game/scripts/domain/battle_command_facade.gd:171-180` 复制敌人意图字段时，白名单里带了
`kind` / `damage` / `label` / `speed` / `seal_turns` / `soul_drain` / `life_cost` / `counter_tag`，
**唯独漏掉 `essence_burn`** —— 焚元意图在 Godot 侧被静默丢弃。

**要做**：把 `essence_burn` 补进字段白名单，并在结算侧扣玩家真元（下限 0，写进战报/事件）。

**不要做**：**不要调平衡数值**。Web 原型实测过一个观察：焚元 2 被每回合回复 5 点完全吃掉，
机制通了但没有威胁——那要先改 `regen_pct` 或焚元数值，属平衡问题，**不在本任务范围**。
把它写进结果包的观察项即可。

## C. `sparked`（L1: 有明确语义才 GO）

**现状**：敌人 `thunder_crown_wolf` 的反击 `thunder_reflex`（「雷甲反噬」）声明
`counter_status: "sparked"`。全仓实测：`game/scripts/` 与 `game/docs/` **零命中**，
仅 `data/enemies.json` 这一处声明。运行时读取点
`game/scripts/domain/action_preview_service.gd:330-348` 的 `_live_counter_labels`
只枚举 `bound` / `guarded`，所以这条反击**在 Godot 侧永远算生效，且没有任何机制能解除它**。
（分布实测：`guarded` 24 / `bound` 11 / `sparked` 1。）

**要做**：
1. 先取证——数据注释、源码、`game/docs/`、`lore/wiki/` 里是否存在 `sparked` 的**语义定义**
   （例如它该由什么触发、由什么解除、持续多久）。
2. **若找到且唯一明确** → 按该语义实现，并写测试。
3. **若找不到或存在多种合理解释** → **不要实现，不要发明语义**，
   把它登记进 D 的豁免表并注明「语义未定义，待 L1 裁决」，在结果包 QUESTIONS 里上报。

## D. 最小 data→runtime contract test（L1 明令新增）

新增一个测试，断言：**敌人数据（`intents` / `reactions`，含 `phases[].intents/reactions`）里
声明的每个字段，在 runtime 都有消费点，或显式登记在豁免表里（附原因）。**

- 位置：`game/tests/unit/`（文件名你定，命名与既有风格一致）。
- **必须能抓到本次这三条**：`sparked`（无消费点）、`essence_burn`（补线前无消费点）、
  `phases`（补线前无运行时）。请在设计时自检这一点。
- **必须有负控**：临时去掉一个消费点（或往数据里加一个无人消费的字段）→ 测试必须失败。
  把负控证据写进结果包。这是 `CONSTRAINTS-V2` **R5「写不进脚本的规则不许存在」**的落地。
- 豁免表要**带原因**，不能是一个可以无限塞东西的垃圾桶；空表或全豁免要让测试失败。

SCOPE
只读：`game/data/**`、`game/scripts/**`、`game/tests/**`、`game/docs/**`、
`game/wenzhen-web-lab/**`（**只读参照**，如 `js/rules.js`）
可写（**仅这些**）：
- `game/scripts/domain/v1_battle_resolver.gd`、`game/scripts/domain/battle_command_facade.gd`
  （phases 运行时 + essence_burn 接线；落点你可按实际结构微调，但**不得改数据**）
- 其他 `game/scripts/` 下确有必要改的消费点（如反击状态判定）——**改前先在结果包里说明理由**
- `game/tests/unit/**`（新增契约测试 + 相关用例）
- `ai-system/tasks/side-fix-enemy-runtime-result.md`（结果包）

DO NOT
- **禁止改 `game/wenzhen-web-lab/**` 任何文件**（已冻结；只读参照）
- **禁止新建 Web↔Godot 共享规则基础设施**（L1 明令：`不要新建共享规则基础设施`）
- **禁止发明 `sparked` 的语义**（无明确语义就不实现，登记 + 上报）
- **禁止改 `game/data/**` 任何数值**（含 `regen_pct`、敌人 hp/damage、`until_hp_ratio`）
- **禁止调平衡**（焚元被回复吃掉是已知观察，不是本任务）
- **禁止碰 P3 范围的蛊效果数值**（`gu.json` 的 `v1_effect`、兜底表）
- **禁止改 `game/wenzhen-web-lab/` 之外任何 Web 线代码**
- 禁止 commit / push / merge / stash / reset
- 禁止新增第三方依赖

DECISION AUTHORITY
可自行决定：phases/essence_burn 的实现结构、事件记录的字段与文案、契约测试的字段清单与豁免表结构、
测试写法。
**不可自行决定**：`sparked` 的语义、任何平衡数值、多意图优先级口径（数据未写 → 取数据顺序并在结果包里
明确标注为原型口径）。

ESCALATE WHEN
- `sparked` 找到不止一种合理解释，或找到的语义与现有 `bound`/`guarded` 抑制规则冲突
- `miasma_vein_lord._phases_note` 与 `js/rules.js` 的参照实现冲突
- 接线必须修改 `game/data/**` 才能成立（数据已由 schema 校验钉住）
- 发现除敌人 `intents`/`reactions` 之外还有「数据声明但无消费点」的字段
  （这本身是 D 要抓的目标，但若超出敌人数据范围，先上报再决定是否扩表）
- phases 接线导致既有战斗测试大面积失败，且失败反映的是**真实语义冲突**而非夹具过期

DELIVERABLE
1. `phases` 运行时（选阶段 / 冷却门禁 / 切换记录）
2. `essence_burn` 字段接线 + 结算
3. `sparked` 的取证结论（实现 或 豁免登记 + 上报）
4. data→runtime 契约测试（含负控证据与豁免表）
5. **`ai-system/tasks/side-fix-enemy-runtime-result.md`**（Caveman Review Packet）

ACCEPTANCE
- `python game/world-model/tools/accept.py --smoke 10` 退出码 0
- `python game/world-model/tools/check_upstream_drift.py` 退出码 0
- `game/data/**` **零改动**（`git status` 必须证明）
- `game/wenzhen-web-lab/**` **零改动**
- Godot 桥门禁通过 + `SABOTAGE` 负控打开时失败
- Godot 全量 unit 通过
- **新增契约测试的负控**：去掉一个消费点 → 测试必须失败（附输出片段）
- **跑 Godot 必须用 console 版**：`GODOT_PATH` 指向 `…Godot_v4.7.2-stable_win64_console.exe`，
  或直接调该 exe。**判定通过只看真实 GUT 文本输出（Passing/Failing/Asserts），不看退出码**
- 结果包写入 `ai-system/tasks/side-fix-enemy-runtime-result.md`

STATUS TARGET
READY_FOR_SIDE_FIX_REVIEW
```

## 技术事实（L2 已核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 裁定原文 | `game/world-model/rulings/RUL-2026-09-19-010.json`（W1/W2/W3 + SIDE-FIX） |
| 带 `phases` 的敌人 | 5 / 32：`miasma_vein_lord`、`thunder_crown_sovereign`、`blood_vein_bishop`、`clan_patriarch`、`blue_fur_jiangshi` |
| phases 校验位置 | `game/scripts/domain/enemy_catalog.gd` 的 `_validate_phases`（`until_hp_ratio` 在 `(0,1]`、严格递减、`intents` 非空、`cooldown` 合法） |
| phases 唯一语义说明 | `data/enemies.json` → `miasma_vein_lord._phases_note`（其余 4 个 Boss 未写） |
| `essence_burn` 唯一出现 | `data/enemies.json`（如 `thunder_crown_sovereign` 的 `paralyzing_howl`，值 2）；`game/scripts/` 零命中 |
| 意图字段白名单 | `game/scripts/domain/battle_command_facade.gd:171-180`（漏 `essence_burn`） |
| `sparked` 唯一出现 | `data/enemies.json` → `thunder_crown_wolf` 的 `thunder_reflex`（「雷甲反噬」）；scripts/docs 零命中 |
| 反击判定读取点 | `game/scripts/domain/action_preview_service.gd:330-348` `_live_counter_labels`（只枚举 `bound`/`guarded`） |
| counter_status 分布 | `guarded` 24 / `bound` 11 / `sparked` 1 |
| 参照实现（只读） | `game/wenzhen-web-lab/js/rules.js:46` `activePhase`、`:63` `intentReady`、`:71` `selectIntent` |
| **Godot 跑法坑** | 非 console 版 headless **零输出且退 0**（静默假绿）；判定只看 GUT 文本 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台 gb2312，**必须** `PYTHONIOENCODING=utf-8` |
| `.ps1` 必须纯 ASCII | 跑 `.ps1` 用 `pwsh` |

## GIT（执行前必读）

工作树**干净**（上一批已提交并推送，`origin/main` 与本地同步）。
执行前跑 `git status --porcelain` 自查；若不是干净状态则停下来上报。

**注意**：仓库有有效的 pre-commit / pre-push 门禁（`.githooks/`，`core.hooksPath` 已指向它）。
本任务**不 commit**，所以不会触发；但**不要用 `--no-verify` 绕过任何门禁**。

## Execution rules

- Worker class: `normal`。
- 改 `game/scripts/`、`game/tests/` 前先 `python game/world-model/tools/snapshot.py take side-fix-enemy`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/side-fix-enemy-runtime-result.md`**。
