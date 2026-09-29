# AGENTS.md

《蛊真人》Monorepo 根入口。先读 `PROJECT_MAP.md`，再按任务进入目标目录的 `README.md` / `AGENTS.md`；跨目录时按需扩展范围。

## 项目与文档边界

- 本仓库统一《蛊真人》相关项目的数据、上下文和版本边界，各产品保留自己的代码与入口。
- 新增或移动来源时，同步更新 `PROJECT_MAP.md` 与 `docs/debt.md`。
- 产品权威是 `docs/PRODUCT_REQUIREMENTS_v1.0.md`；协议是 `docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md` 与 `docs/CHANGE_CONTROL_PROTOCOL_v1.0.md`。阶段契约、设计、计划、代码依次从属，低层不得推翻高层。
- `ai-system/PRD.md` 属于 `my-ai-production-system` 镜像项目，不是《问真》PRD。目录来源、入口及当前项目状态见 `PROJECT_MAP.md`。
- 本文件和各目录的 `AGENTS.md` / `README.md` 是导航与执行约定，不是产品权威；第 3 层及以下不得声明自身凌驾 PRD 或协议。

## 变更与决策

- 按 `docs/CHANGE_CONTROL_PROTOCOL_v1.0.md` 执行变更控制。核心体验、核心系统、阶段范围或开发平台变更须由 L0（用户）批准；新想法不得直接进入代码，在途任务按协议继续。
- L2（Codex）不得自行改变核心玩法、产品方向或阶段目标。产品意图与重大取舍上报 L0；数值、架构判定及多方向建模上报 L1（ChatGPT）；仓库内可验证的问题由 L2 处理。
- 设计类任务遵循固定顺序：原文取证 → 核验并蒸馏到 Wiki → L1 评审原著到游戏的改造 → 计划 → Worker 实施。前 3 步未完成，不得实施依赖该结论的工作。
- 原文依据从根目录 `蛊真人-clean.txt` 取证（带行号，单条引文不超过 60 字）；不得把 `game/data/` 直接当作原著证据。Wiki 事实须可追溯，分析须与事实区分，“待核对”不得当作原著事实。

## 执行入口与范围

- 文档卫生与治理流程见 `docs/DOCUMENTATION_GOVERNANCE.md`；触碰 Markdown 后运行 `node tools/docs-lint.mjs`，触碰 Wiki 时另跑对应内容门禁 `lore/wiki/tools/check.ps1` 或 `game/docs/wiki/lint.mjs`。
- 涉及 AI 规划、Worker 或模型选择时，先读 `ai-system/AGENTS.md`、`ai-system/WORKER_PROTOCOL.md`、`ai-system/config/common.json`、`ai-system/config/model-rules.json`。具体角色流程、任务包和结果格式以这几份文件为准，本文件不重复维护模板。
- 禁止把 `source/`、完整原始小说或《人祖传》全文提交到 Git；仅在本地 `source/` 保留原文。**例外（2026-09-29 用户裁决）：EPUB 派生规范全文 `source/蛊真人-epub-canon.txt` 允许入库推送**，作为新 Canonical Novel Source 候选；其余原文底稿仍一律不入库。
- 不擅自改产品逻辑、数据数值、游戏契约或 Wiki 语义。Wiki 按 `lore/wiki/AGENTS.md` 编辑。
- Worker 默认不 commit、merge 或 push；推送须在验收通过并经用户确认后进行。阶段验收后独立提交。
- 不运行 `git reset --hard`，不强制覆盖未核对内容。递归移动或删除前，解析并验证目标绝对路径。
- 计划与仓库事实不符时，停止相关工作、报告并修正计划文件；不得自行扩展范围或改架构。

## 验证与上抛纪律

以下规则来自已发生的验收与审查事故，适用于所有相关任务：

1. **验收看真实输出，不只看退出码。** 声称通过时附可复核输出；零输出不代表通过。
2. **独立复核 Worker 结果的代码、数字和根因归因。** 一项准确不能证明其他项准确。
3. **数值与架构判定上报 L1；产品意图、重大取舍和技术路线变更上报 L0。** 不自行补造数值或替 L0 选择合理但未批准的方向。
4. **Research Request 必须自足。** 证据、数值、短引文写入请求；数值论断回到应用点确认实际作用对象。
5. **计划被证伪时就地修正计划并留痕。** 只口头说明不执行，不足以避免后续照旧执行。
6. **不能语义无漂移拆批时，明确等待裁决。** 不为开工而假设存在安全结构批。

## 工作原则

核心体验变化、新增核心系统、阶段范围变化和更换开发平台属于重大变更，先按 `docs/CHANGE_CONTROL_PROTOCOL_v1.0.md` 取得 L0 决定。新想法可以记录，但不应打断在途任务或直接变成代码。冲突时优先保证核心体验验证，再处理产品问题、玩家体验、内容、技术和装饰。

## AI 任务

只有任务确实需要 Worker、模型选择或 AI 执行环境时，才读取：

- `ai-system/AGENTS.md`
- `ai-system/WORKER_PROTOCOL.md`
- 与当前任务相关的 `ai-system/config/*.json`

不要为普通代码、文档或只读检查加载整套 AI 协议。默认执行链、候选模型和可用性以 `ai-system/` 当前配置为准，不在本文件重复模型细节，也不新增 Router、Provider 或 Agent 抽象。

派 Worker 时使用 `ai-system/WORKER_HANDOFF_TEMPLATE.md`，只提供本任务所需的上下文。Worker 默认不 commit、merge 或 push；若前提与实际冲突、需要扩大范围或无法满足验收，返回证据并暂停该批次。

## 数据与安全边界

- 不把 `source/`、完整原始小说或《人祖传》全文提交到 Git；本地原始资料只用于必要回查。**例外（2026-09-29 用户裁决）：`source/蛊真人-epub-canon.txt`（EPUB 派生规范全文）允许入库推送。**
- 不覆盖用户未提交的改动，不使用 `git reset --hard`、强制检出或未经核对的递归删除/移动。
- 不提交密钥、缓存、构建产物、嵌套仓库或本地工作树。
- 不改变产品逻辑、数据数值、游戏契约或 Wiki 语义，除非任务明确且上游决定已生效。
- 验收看真实输出和可复核证据，不只看退出码或“PASS”标签；代码改动、数字和根因分别复核。

## 设计与 Lore

只有任务涉及玩法、数值、关卡、美术方向或原著事实时，才走设计顺序：

1. 从本地原文或已有 Wiki 取证；`game/data/` 是游戏数据，不自动等于原著事实。
2. 将核验后的事实按 `lore/wiki/AGENTS.md` 蒸馏，区分事实、分析和待核对内容。
3. 涉及原著到游戏的妥协、数值或架构模型时，交由 L1 评审后再实施。

纯工程修复、文档整理和测试不需要套用这套设计流程。

## 实施与复核

- 先检查 `git status` 和相关 diff，确认目标路径与既有改动。
- 新增或实质修订 Markdown 时执行文档入库清单（`docs/DOCUMENTATION_GOVERNANCE.md` §4）：挂 hub 链接、引用合规、跑 `node tools/docs-lint.mjs`。
- 选择最小可行改动，优先复用现有入口和数据 Owner，不因为“更漂亮”重写系统。
- 运行与改动直接相关的测试或验收，并报告命令、真实输出、未验证项和既有失败。
- 完成后由 L2 检查范围、行为、数字、测试与剩余风险；普通任务在仓库内闭环。

当前目录、来源映射和子项目入口见 `PROJECT_MAP.md`；产品定义、阶段规格、计划和债务保持在各自原路径。历史文件不自动成为当前约束。
- 本项目优先可交付、稳定、清晰与可维护；复用已有工具，不建设缺少真实痛点支撑的 Router、平台或基础设施。
- 当前入口、已完成迁移、来源映射与债务以 `PROJECT_MAP.md` 为准；不要在本文件复制其项目清单或历史记录。

## Issue tracking

GitHub Issues 是未完成工作的持久状态源。开始任务前运行 `gh issue list --state open --limit 1000` 检查 open issues。发现明确的 bug、需求或技术债时，先用 `gh issue list --state open --search "关键词"` 查重，再按 `bug`、`enhancement`（requirement）或 `debt` 标签创建。修复已有 issue 时在 commit / PR 中关联 `Fixes #N`；只有实现完成且验证通过后才关闭。未完成事项不得只记在阶段总结中。
