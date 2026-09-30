# 更新记录

本文件从本次目录规范开始记录可核对的变更；更早历史见 Git 日志与 [迁移记录](MIGRATION.md)。不补造版本号或发布记录。

## 未发布

### 2026-10-01（Wiki 工作区保存）

- 保存 10 kind 分类、Wiki 网站源代码及分类导航/详情/窄屏修复；网站构建产物不入库，远程 Site 未发布。
- 撤回叙事知识层任务包；前20章新增内容作为待审产物保存，不声明内容质量验收，不继续批量执行。Issue #6 保持未完成。

### 2026-09-30（Wiki 连续执行修正）

- 按 L0 最新要求停止每簇出题/答题/评分收口，转为连续章节补全叙事知识层和直接原文复核；修正 Wiki 执行约定，新增[卷一连续任务包](ai-system/tasks/2026-09-30-wiki-narrative-layer.md)，不扩大目录或 schema。

### 2026-09-30（全库盲测缺口补库）

- 10 窗 20 题独立盲测总分 6/40；按缺口批量补库：开门蛊/关门蛊与盗天真传验证链、春秋蝉/真阳楼/意志条件、示现七转与四旬子误判、冰晶×鲛人胁迫赌约（`east-sea`）、卷六经营期 EVT-FMK-171–178（升仙大潮/盗天机/衍化野生/元始均势/双尊压制）。
- Q16 内患口径裁定为两层：直接＝万灭雷森，深层＝红莲暗算三千天道道痕（禁止两说并存当已核）。
- 心理/判断层：人物页「判断与动机」+ 事件页「角色判断过程」（JRTC-01 / JQMS-01·02 / JFMK-01）。
- 全库结论见 `ai-system/tasks/2026-09-30-wiki-full-corpus-conclusion.md`；门禁 194 页 / 3951 链 / 21126 E-ID 全绿。

### 2026-09-30（人向 Wiki 目录与导航）

- 根入口改为「给人用的总入口」：五条阅读路径（五分钟世界 / 跟方源 / 同人作者 / 查设定 / 做问真）+ 分类人话描述；AI 使用说明降为次要小节。
- 分类索引人向重构：`gu/`（用途·流派·转数·剧情四维）、`world/`（七组+同人限制）、`events/`+`characters/`（叙事弧/地域/主题）、`rules/`+`themes/`；每条链接带一句说明。
- 新增 `lore/wiki/paths/` 五条完整路径页与 `web/README.md` 网站窗口说明；超长机制页补导读/TOC；导航断链清零（`tools/nav-audit-20260930.md`）。
- 门禁：`check.ps1` ALL PASS（链接 3884）；`docs-lint` FAIL 0。未改知识事实正文。

### 2026-09-30（Wiki 知识缺口分批 B1–B7）

- 按盲测失败点补条件因果与检索入口：常极右试验（Q03/Q04）、疯魔窟审讯（Q11/Q12）、光阴长河避侦查/避年兽（Q09/Q10）、血狂蛊→千里地狼蛛失控与被迫骑乘（Q01）、古月博十绝体误认（Q02）、商乖离/柴火熊战死拆分（Q07）、白凝冰与黑楼兰战力对照（Q08）、暗渡「忽略」vs 星雾掩「模糊」。
- 纠正三处归因：307 次痛晕≠死亡；古月博「识破」改为条件句误认（后文证伪）；盲测 Q07 混误两场相邻战死。
- 只读 Wiki 复验 10/10 可答；`check.ps1` 九项全绿（21122 E-ID）。分批方案见 `ai-system/tasks/2026-09-30-wiki-knowledge-gap-batches.md`。跟踪 [GitHub #6](https://github.com/Zachar-c/-/issues/6)。全库 IA 迁移仍不批准。

### 2026-09-30（星雾掩 Wiki 复核）

- 在星念蛊页补齐星雾掩用途、初版与改良版区别、角色筹资陈述、改良缘由及改良版防御/持续条件；本主题局部新旧原文对照未发现语义差异。
- 视觉页、杀招名录与相关事件页增加机制页导航；事件因果与历史锚保持原样。

### 2026-09-30（EPUB 正文接入）

- Wiki runtime 改用 [EPUB 规范正文](source/蛊真人-epub-canon.txt)标识与哈希，保留旧 E-ID 和行号；生成 [EPUB 定位表](lore/runtime/evidence-locators.json)，未决项定位留空。
- 口径 v4（`context_window` 5→12，只扩大搜索范围、不降低唯一定位判据）经 L1 追认；live 6,515 个 E-ID = 6,405 `auto_verified` + 15 `human_approved` + 95 `blocked`；runtime 使用 1,997 个 = 1,979 + 15 + **3 未决**（`unresolved_evidence_count = 3`）。
- 已知源缺口：一段·第七十七节「阴差阳错」、六段·第六百七十七节在原 EPUB 的 spine 与目录中即不存在（原件 SHA-256 `be1c357f…`，与 `epub_sha256` 一致），相关锚点只保留旧行号回查，不建旧 TXT 回退。
- 单点修复 2 页（`soul-atk-5-01-gu.md`、`heaven-atk-5-07-gu.md`）；全链门禁 G0/G1/canon_pack 通过。剩余 95 条 live `blocked` 由 [GitHub #13](https://github.com/Zachar-c/-/issues/13) 跟踪；Godot GUT 145 项为既有失败，不在本次范围。

### 2026-09-28（GitHub Issues 状态对账）

- 将明确仍有效的 WOPT-06/07/08、Phase 8 L1 阻塞、当前 GAME_GENERATION_READY 链、Wiki/Runtime/Rank 模型债务与 v1_battle Godot 迁移登记到 GitHub；相应 TODO、债务行和旧计划补上 issue 链接。已完成、跳过或仅待新裁决的历史记录未批量建单。现有 Web 临时 Markdown 孤儿对应 [GitHub #1](https://github.com/Zachar-c/-/issues/1)。

### 2026-09-28（拉取后的文档偏移核对）

- 合并 `AGENTS.md`、`TODO.md` 与 Wiki 索引、日志的本地文档冲突；当前阶段状态以较新的远端裁定和验收为准，保留本地历史计划入口。
- 将本地血道、光道、力道取证中远端页面未覆盖的事实与适用边界并入对应 Wiki 页；在 `ai-system/README.md` 补四份本地评审资料的入口。
- G0 文档门禁、G1 lore Wiki 门禁、G2 game Wiki 门禁均通过；剩余 8 个 Web 临时过程记录孤儿登记在 [债务清单](docs/debt.md)。代码与数据冲突仍待单独处理。

### 2026-09-28（原著蛊组构筑核验）

- 应用户“先搭配现有库存，不扩蛊库”要求，新增[现有库存关系图](docs/design/rank1-9-model/inventory-combinations.md)与[可机检关系数据](docs/design/rank1-9-model/inventory-relations.json)：69 蛊中 20 蛊连出 17 条关系（含 1 条显式标记的角色计划）；缺件只登记不新增，另标注通用动作槽与血滴子、木魅蛊、月影蛊语义冲突。同步把九叶生机草本体改回原文二转，并区分其一转生机叶产物。
- 按用户补充的“特性恰好适配”原则，将上述 17 条关系记录与配对白名单区分（其中 10 条已核、4 条已核但库存缺件、2 条规则串接推导、1 条角色计划）；在同一数据中另记 4 条基于蛊虫作用的游戏适配假设。小光辅助其他光性效果仅作候选，不冒充原著普适增幅，也不预设倍率。
- 收紧“完整构筑”口径并同步研究入口、库存、力道、流派审计与复核页：严格 69 蛊库存内为 0 套；方源力道是原著可支撑、现库存缺件的 1 套战斗构筑样本；龙公变化/气道是完整杀招体系的功能样本，组成蛊虫未逐只核全。burst/balanced/sustain 改称数值测试配置；血神子晋升方向已核但完整蛊方与获取链未知。
- 用户指出“力道样本不能外推各流派”；新增[流派机制差异审计](docs/design/rank1-9-model/path-mechanics-audit.md)，核对 Wiki 41 个流派页，区分 14 派机制候选、11 派具体实例或外部代价、16 派证据不足，并将三套旧构筑降格为数值压力测试样本。
- 依据商家城至三王传承阶段的原文，补齐[力道蛊组构筑研究](docs/design/rank1-9-model/strength-build-study.md)及 Wiki [蛊虫协同关系](lore/wiki/gu/gu-relations.md)：区分肉身承载、兽力存量、调用、受伤增幅、治疗、位移与远程载体，并标明真元和时机约束。
- 依据宿命大战的原文，补充[龙公](lore/wiki/characters/dragon-duke.md)变化道与气道两套互补战斗体系；三气归来保留元始仙尊布置与使用窗口的边界。
- 修正研究蛊库中自力更生蛊和全力以赴蛊的“效果未核”表述；现有模拟器仍不能执行完整依赖图，不把研究关系冒充已实现玩法。

### 2026-09-27（一至九转数值研究）

- 新增 [一至九转数值模型](docs/design/rank1-9-model/README.md)：从 Wiki / Canon 事实独立推导转数、真元/仙元、道痕、战斗构筑、供养、炼蛊、升仙、灾劫、成尊和跨局蛊方规则，未覆盖现有游戏数据。
- 提供独立参数与可执行计算器、21项规则检查、13500场战斗、24300场敏感性对照、810条完整预算路线、90000次炼制采样；实际结果及限制见 [验证报告](docs/design/rank1-9-model/validation.md)。独立 L1 和玩家实测仍未完成，不宣称正式平衡。
- 新研究入口已挂接 docs hub 与项目地图；原著缺口、模型与生产边界及校准风险登记至债务清单。
- 同日 v0.2 集成扩展：新增 [原著蛊库与三套数值测试配置](docs/design/rank1-9-model/gu-library.md)（69 只蛊、15 条配方/约束、逐条证据标注）、[供应模型与三场景](docs/design/rank1-9-model/supply-model.md)、战斗载体与灾劫实战口径及 [引擎终审记录](docs/design/rank1-9-model/engine-v02.md)；验证器 21→29 项检查，测试配置×供应全臂与灾劫两口径对照入验证报告。
- 两项模型修订待 L1 追认（未赋能动作回落占位口径、凡人蛊赋能动作乘小境界进度系数），已登记债务清单；当前完成率为 v0.2-draft 参数下的研究发现，非平衡结论，不为结果调参。

### 2026-09-27（文档治理推广与存量收口）

- 新增 [docs/DOCUMENTATION_GOVERNANCE.md](docs/DOCUMENTATION_GOVERNANCE.md)：LLM Wiki 文档治理推广到全仓（分层、引用、失源、词表、G0–G2 门禁、**入库即治理 §4**）；`lore/wiki` 与 `game/docs/wiki` 双库保持分离，只统一规范口径。
- 新增 [tools/docs-lint.mjs](tools/docs-lint.mjs)（G0）：全仓 Markdown 断链 / 编译层孤儿 / frontmatter 日期 / 脚注路径 / mermaid 卫生。
- **存量治理**：源层/历史/过程记录归入 G0 豁免；新建 [docs/README.md](docs/README.md)、[game/docs/README.md](game/docs/README.md)；module-interfaces / lore / wenzhen-web-lab / editorial / ai-system hub 补真实链接。其他孤儿 221→1。
- 修正断链与脚注路径：战斗 HUD 场景 README 相对层级、runtime pack 相对路径、`GDD.md` 历史悬空引用、game wiki 三处脚注全路径（L1 D2）、ai-system 视觉报告魂道链接。
- 根 `AGENTS.md`、`PROJECT_MAP.md`、`DEVELOPMENT.md`、`README.md` 与双库维护文档接入治理与入库清单。

### 2026-09-25（评审修复）

- 主行动坞镜像紧凑化：地图节点 / 战后三选一卡片按钮改为单行文案（「前往：X」/「选择：X」）转发点击，不再整卡克隆进 dock 撑坏布局。
- NORMAL_RUN 败局用例补回归锁：终局后走大厅「重新开局」须 `journey.started=true` 且重绘出的道路卡真实可点。
- `#spine` 补 `role="region"` 使 `aria-label` 生效；移除 `draw()` 内冗余的 `typeof syncDock` 防御。
- 评审复核：`act.startRun` 换局渲染经 `wrappedAct` 统一 `commit()`（draw + persist）兜底，无面板失步问题；候选修复经红-绿验证后撤回。

### 2026-09-24（会话收敛）

- `git pull` 快进至 `866d4b3`，并入 Phase 8 研究请求、Web 硬性约束盘点与 Gate 8 测试。
- 合并远程实验分支 `codex/wenzhen-visual-pass`（fast-loop 战斗意图与月晶美术实验）；本地 `main` 领先远程 1 个 merge commit，未推送。
- 进度快照对齐构筑分叉计划：Phase 0–7 与批A 完成，批B 真元曲线仍阻塞于 L1。
- 检索关闭：仓库内不存在 gpt6sol 所撰「敌人与蛊虫插件化」计划；结论写入会话收敛归档，不另造计划文件。
- `TODO.md` 将 `saveCompatibilityVersion` 更正为 `lab-run-v2`，并补当前玩法主线入口。

### 2026-09-24

- 补齐根目录的规格、架构、设计、组件、页面、开发、分发、部署和进度文档入口。
- README 增加技术栈、快速开始与文档索引，修正过时的迁移待办表述。
- 产品需求与协议继续保留原路径，标准入口不复制成新的权威来源。
- 明确独立官网、组件分发及 Cloudflare 配置的未确认状态；本次仅修改文档。
- 收缩 AI 常驻上下文：根 `AGENTS.md`、`ai-system/AGENTS.md` 与 `ai-system/WORKER_PROTOCOL.md` 改为短边界和按需入口；历史事故复盘、重复模板和模型状态不再每次注入。
- 精简本机 `codex-api` 技能：保留 Anthropic API 路由与安全不变量，移除固定模型、固定思维/流式策略、强制联网和跨提供商拦截。
- 按 L0 最新方向，将《问真》目标明确为完整长线产品：Godot 工程为主实现，Web 版本保留为探索材料，美术不受旧素材约束。
- L0 随后更正产品载体：完整长线游戏以 Web 版 `lab.html` 为目标；Godot 工程作为成熟规则与共享数据来源，Web 不再作为历史探索材料。
- 补齐五层地图节点描述，异闻池由 12 条扩为 24 条，为尚未收录的三类结局补上可解锁札记；所有新增事件沿用现有结算效果。
- 内容 JSON 与引用结构已检查；未运行游戏或整局验收。Web 数据镜像刷新会因 `contentVersion` 变化使存档不兼容，故本轮未发布该快照，兼容策略列入待办。
