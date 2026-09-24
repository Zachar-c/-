# 《问真》Web 硬性约束盘点（供 L0 逐条审核）

> 日期：2026-09-24。本文是约束索引，不是新权威，不覆盖或删除任何来源。范围为当前《问真》Web 产品及会影响 Web 的上位/跨目录规则；不盘点 lore、editorial、fortune 等无关子项目的领域约束，也不把 Godot 专属规则自动套到 Web。
>
> 当前统计：**14 条在用约束/裁定、19 条需审核或校准的疑点、6 条已失效或仅属历史/其他范围的约束记录，共 39 个审核条目**。同一段落可能含多个子规则，按审核主题分组；计数不是仓库中所有“必须/禁止”词句的机械总数。
>
> 审核前保持原状。对 R 项可回复 `R01 保留`、`R02 删除 Web 约束`、`R03 改写为……`；删除约束时只移除其当前执行效力，历史证据可留档并标注“已失效”。

## A. 当前生效：14 条

| ID | 约束 | 当前权威/来源 | 当前理解 |
|---|---|---|---|
| A01 | 《问真》当前完整长线产品载体为浏览器 Web，入口 `game/wenzhen-web-lab/lab.html`；Godot 规则与数据按需复用。 | `docs/PRODUCT_REQUIREMENTS_v1.0.md` §当前方向；`PROJECT_MAP.md` 的 `game/`、`game/wenzhen-web-lab/` | 产品平台/入口约束。 |
| A02 | 单局目标 3–5 小时、200–300 个有效节点，覆盖完整成长弧。 | PRD §五 | 目标现行，但“有效节点”口径未定义，见 R01。 |
| A03 | Web 单机、离线可玩，保留五层修行路线与多种结局。 | PRD §六 | 现行产品范围。 |
| A04 | Web 不设材料掉落、交易、库存或材料合炼投入；修行成本由真元、蛊虫、元石、时间、风险和机会承担。 | PRD 当前方向；`game/wenzhen-web-lab/README.md` | 现行硬边界；与 9 月 25 日文件冲突，见 R02。 |
| A05 | 能力应有来源、条件、消耗、限制和风险；不凭空造技能；体验重视选择、代价、情报和反制。 | PRD §二至§四 | 核心体验约束，不等于每个能力都必须具备每一种代价。 |
| A06 | 当前非目标：完整剧情复刻、五域地图、天庭战争、完整仙道体系、与核心循环无关的外围系统。 | PRD §七 | 现行范围边界。 |
| A07 | 核心体验/系统、阶段范围、平台变化须由 L0 批准；低层文件不能推翻 PRD/协议。 | 根 `AGENTS.md`；`docs/CHANGE_CONTROL_PROTOCOL_v1.0.md`；PRD | 现行治理约束。 |
| A08 | 新局不选主道；血、魂、光、力可混搭。 | L0 2026-09-24 对话；`docs/superpowers/plans/2026-09-24-wenzhen-web-optimization-tasks.md` §当前边界 | 现行范围决定，不代表四道均已完整可玩。 |
| A09 | 暂不扩展魂魄的“获得、投入、守护”；魂道当前不作为完整可玩道。 | L0 2026-09-24 对话；WOPT 计划 §当前边界 | 现行暂缓决定。 |
| A10 | WOPT-04 长局可靠性专项不要求，跳过；不得把测试或发行冒烟冒充成 WOPT-04 验收。 | L0 2026-09-24 对话；WOPT 计划 WOPT-04 行 | 对该专项的明确豁免，不改变游戏正常存档功能。 |
| A11 | 进行中存档使用兼容版本判断；新增内容不应无故打断长局，改变存档结构/规则须设计兼容或拒绝策略。 | `PROJECT_MAP.md` 的 Web 范围；Web `README.md` §存档 | 现行体验/兼容约束。当前 `saveCompatibilityVersion` 为 `lab-run-v3`。 |
| A12 | `game/data/` 是共享源数据；Web 镜像经现有生成工具更新，不把生成的 `js/data.js` 当独立真源。 | `PROJECT_MAP.md` 的 `game/` / Web 范围；`game/wenzhen-web-lab/README.md` | 现行数据边界。 |
| A13 | 真实可玩性结论需要普通局可见操作证据；fixture、规则单测和短剧本各有证明边界。 | WOPT 计划；Web `docs/lab-runtime-contract.md` §6 | 验收纪律仍适用；测试与领域状态写入边界见 R15。 |
| A14 | 转数是综合层级轴，不是所有伤害、经济、真元和 Boss 数值共用的万能倍率。 | `game/world-model/rulings/RUL-2026-09-19-008.json`；`game/AGENTS.md` | 共享数值原则；Web 的投影与 Godot 精确数值关系见 R06。 |

## R. 供 L0 审核：19 条

### P0：可能改变当前产品范围或阻断快速迭代

| ID | 约束/冲突 | 来源及证据 | 建议 L0 决定 |
|---|---|---|---|
| R01 | “200–300 个有效节点”是硬性产品门槛还是目标？“有效”按单局访问节点、全图候选节点，还是内容单位计算？ | PRD §五；WOPT-06 测得 easy/normal/hard 全图候选/必经分别为 `230/80`、`155/55`、`80/30`，见 WOPT 计划 WOPT-06。 | 保留并明确口径 / 改为区间目标 / 删除该数量约束。3–5 小时是否仍是硬性验收目标也请一并裁定。 |
| R02 | Web 是否仍永久禁用材料循环？9 月 24 日 PRD 明确禁止；9 月 25 日 L0 决策文件把材料定位为炼蛊配方钥匙，并允许祭品/临时耗材，直接冲突。 | `docs/PRODUCT_REQUIREMENTS_v1.0.md` 当前方向；`docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md` §四、§七；`docs/superpowers/plans/2026-09-25-build-fork-rebuild.md` 头部注记。该决策文件日期晚于本盘点基准日期。 | 确认 9 月 25 日文件是否为有效的较新 L0 裁决。若是，应正式修订 PRD；在此之前，按权威链仍执行 PRD 的无材料循环边界。 |
| R03 | “只允许 inspect / suppress / armorBreak|pierce / ignoreEvasion 进入 live chain，其余 vertical 冻结”适用于哪个阶段，是否仍有效？ | `docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md` §二；同样晚于盘点基准日期。 | 确认该冻结的生效日期、结束条件和是否覆盖 9 月 24 日 Web 迭代。 |
| R04 | 9 月 25 日“构筑分叉与完整力量循环”阶段目标及 `APPROVED_FOR_EXECUTION` 是否已经生效，还是历史/未来文件？ | `docs/superpowers/plans/2026-09-25-build-fork-rebuild.md` 状态头与任务正文；与 9 月 24 日 WOPT 当前计划并存。 | 确认当前唯一执行入口；过期计划应标注历史，不应和 WOPT 并列派发。 |

### P1：宽泛、阶段性或跨项目套用风险

| ID | 约束/冲突 | 来源及证据 | 建议 L0 决定 |
|---|---|---|---|
| R05 | `MAP BEFORE MODIFY · NO NEW DOMAIN IMPLEMENTATION` 可被读成 Web 永远不得新增玩法实现，与“完整长线游戏持续打磨”不相容。 | `game/wenzhen-web-lab/EXISTING_CAPABILITY_MAP.md` 头部第 5 行；该文件范围是 2026-09-24 Integration First 盘点。 | 删除全局禁令 / 窄化为“先核对已有能力；新增核心系统另走 L0”。 |
| R06 | “Godot v1 是战斗 OWNER、Web 是并行实现/投影”容易与 Web 为完整产品载体混淆；规则数据复用不等于代码必须由 Godot 拥有。 | `EXISTING_CAPABILITY_MAP.md` Rank/战斗 Owner 表与 §3；`PROJECT_MAP.md` 明确 Godot 规则与数据可复用，Web 为产品。 | 将“数据/规则来源”与“运行时实现 Owner”分开定义，架构取舍交 L1；是否维持 Godot 代码 Owner 由 L0 确认产品层含义。 |
| R07 | Integration Sprint 的“只连这一条”“一次只连一个概念”“依赖图是唯一允许补的 GAP”等局部限制可能在该 Sprint 已完成后继续误当长期禁令。 | `EXISTING_CAPABILITY_MAP.md` §5–§8；其中刀 1–5 已标完成。 | 标为已结束的 Sprint 约束 / 删除其对后续 Web 任务的强制力。 |
| R08 | Godot 4.7.2 Demo、全量材料规则、蛊虫海量配方、LLM 永久搁置等目标容易从 `game/AGENTS.md` 泄漏到 Web 产品范围。 | `game/AGENTS.md` §目标、技术约定、核心业务红线；`PROJECT_MAP.md` 将其标为 Godot 工程入口。 | 明确这些是 Godot 子工程专属约束；Web 只继承经 PRD/裁定确认的规则。不要删除仍适用于 Godot 的约束。 |
| R09 | `CONSTRAINTS-V2` 的“任何新规则必须写测试/脚本，不然不许存在”等规则若被理解为全仓产品规则，会把 Godot 工程治理套到 Web。 | `game/world-model/governance/CONSTRAINTS-V2.md` §三 R1–R6；文件自身声明其不得凌驾 PRD/协议。 | 标注仅适用于 `game/` 数据/运行时约束，不能取代 Web 的体验/产品需求。 |
| R10 | 固定 Worker 流程（设计链末尾必须 Worker 实施）与本轮 L0 指令“无需 Worker，由 Codex 或子代理完成”冲突。 | 根 `AGENTS.md` 设计流程；`docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md` L2/Worker 章节；本轮 L0 对话已覆盖当前 WOPT 工作。 | 确认这是本轮 WOPT 的一次性豁免，还是 Web 后续任务默认也允许 Codex/子代理直接实施；不自动改全仓 AI 协议。 |
| R11 | `lab-runtime-contract.md` 将 `materials`、`materialPityByTier` 列为可存档状态，与 PRD 和当前迁移代码相反。 | `game/wenzhen-web-lab/docs/lab-runtime-contract.md` §2.2；当前 `js/lab_save.js` 明确迁移并删除旧材料字段，README 声明 `lab-run-v3`。 | 这两项是过期状态描述，不需要产品裁定即可在后续文档修订中删除；请确认是否授权整理整份契约的过期字段。 |
| R12 | “脚本顺序禁止改序不报备”把当前依赖顺序写成永久流程门禁；“本阶段不改 Godot `.gd`”也有明显阶段限定。 | `lab-runtime-contract.md` §1、§7。 | 保留实际依赖顺序和单一战斗核；把汇报门禁/阶段限制改为当前任务事实，不作为永久硬约束。 |
| R13 | “复写运行时的任何模拟器输出永久不得作为平衡、验收或产品证据”过宽：探索性模拟可用于找问题，关键是不能冒充真实玩家轨迹或单独定案。 | `game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md` §1，标题注明“永久”；日期/依据为 2026-09-25 Phase 0，晚于盘点基准日期。 | 删除“永久不得”或改成证据分级：模拟可用于探索，不单独作为玩家可得性/可玩性结论。 |
| R14 | Web `balance/**` 冻结规则的有效边界不够醒目，容易被扩大成“Web 不得做任何数值/玩法维护”。 | `game/wenzhen-web-lab/balance/FROZEN.md`；规则本意是冻结实验模型目录，不成为第三套 Rank/定价/战斗引擎。 | 保留目录局部冻结；加注不限制正式 `game/data/`、现行 Web 运行时或经 L0/L1 批准的改动。 |
| R15 | `lab-runtime-contract.md` 将 `act` 写成唯一状态写入口、禁止 UI/测试直接改 state；测试证据又限制 fixture。两者目的不同，若无例外可阻碍合法测试/工具。 | `lab-runtime-contract.md` §3、§6；现有 `tests/helpers/lab_browser.mjs` 使用可见控件。 | 保留“玩家链需经领域动作”与证据分级；明确测试可用 fixture 检验规则但不得将其冒充正常局证据。 |
| R16 | “Web 不做材料”与“Godot 数据必须投影 Web”若被混读可能导致材料字段又进入 Web，或反过来要求删 Godot 源数据。 | `PROJECT_MAP.md` `game/`；Web README；`EXISTING_CAPABILITY_MAP.md` Web 边界。 | 保持清晰边界：Godot 源数据可存在；是否投影到 Web 由 PRD/裁定决定。 |
| R17 | `WOPT-06/07/08` 的单批顺序和验收前置是本轮执行计划，不应升级成永久开发制度；WOPT-04 已豁免。 | `2026-09-24-wenzhen-web-optimization-tasks.md` §任务顺序。 | 保留本计划的交付顺序；不要复制成全仓硬约束。 |

### P2：事实漂移，适合在批准后由 L2 清理

| ID | 约束/记录 | 来源及证据 | 建议处理 |
|---|---|---|---|
| R18 | Web README 当前称“杀招暂未开放”，但运行时契约列有杀招命令/面板代码，需确认普通新局玩家链究竟能否取得和使用。 | `game/wenzhen-web-lab/README.md` §操作；`docs/lab-runtime-contract.md` §3；`js/battle.js` / `js/journey.js`。 | 这属于状态事实核对，不是 L0 数值裁定；核实后同步 README/契约。 |
| R19 | `docs/debt.md` 的 Web 行仍记 `lab-run-v2`、并写近期整局/重载证据未复核；当前 README 已为 `lab-run-v3`，WOPT-03 已记录五层胜局，WOPT-08 已测一次刷新续玩。 | `docs/debt.md` Web REVIEW 行；Web README；WOPT 计划 WOPT-03/08。 | 按当前证据修订债务状态；仍须保留 WOPT-04 被跳过的边界。 |

## H. 不再作为当前 Web 约束：6 条历史/作用域记录

| ID | 记录 | 处理状态 |
|---|---|---|
| H01 | 临时新局单光道 `playableSchool: light`。 | WOPT-02 已按 L0 撤销；只保留兼容/审计记录，不再作为新局约束。 |
| H02 | 2026-09-22 G07 “缺少真实胜局”。 | WOPT-03 的 2026-09-24 空档五层胜局已补证；旧报告保留历史时间点，不再代表当前 G07。 |
| H03 | Phase 5 材料循环及旧 Phase 6/7 材料任务。 | 已由当前 PRD 覆盖；WOPT 计划明确不再派发。若 R02 改变，需由新裁定重开，不自动复活。 |
| H04 | W1/W2 以前“没有存档/没有打包工具”等状态。 | 当前 Web README、`js/lab_save.js` 和 `tools/package_lab.mjs` 已有实现；旧状态仅作历史。 |
| H05 | `game/AGENTS.md` 中 Stage 0 生产冻结令、旧 Agent Ownership 五步协议。 | 文件注明已由 `CONSTRAINTS-V2`/RUL-2026-09-17-003 作废；不得再执行旧门禁。 |
| H06 | `docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-decision-v1.md` 的待 L0 问题。 | 文件头已写明由 `2026-09-20-wenzhen-visual-positioning-v1-approved.md` supersede；不再是未决硬约束。 |

## 审核顺序建议

先审 **R01–R04** 的产品范围和生效顺序，再审 **R05–R17** 的工程/流程限制，最后让 L2 根据 **R18–R19** 修正文档事实。A 组在 L0 修改前继续按当前权威执行；H 组不复活。
