# 文档治理规范（LLM Wiki 方法论 · 仓库级）

> 适用范围：全仓 Markdown。目标是让文档**可追溯、可门禁、可维护**，而不是再加一套知识库。  
> 方法论来源：lucasastorian/llmwiki（Apache 2.0，提取副本见 `game/docs/wiki/references/llmwiki-guide-extract.md`）；本仓双库判决见 `game/docs/wiki/l1-quality-ruling-2026-09-26.md`。

## 1. 分层（谁是事实，谁是编译，谁是导航）

| 层 | 职责 | 典型落点 | 权限 |
|---|---|---|---|
| 源层 | 唯一事实层：规格、计划、报告、裁定、原文 | `docs/PRODUCT_REQUIREMENTS_v1.0.md`、`docs/superpowers/**`、`game/docs/contracts/**`、`game/world-model/rulings/**`、本地 `source/` | 只读消费；修订须有任务与裁定 |
| 编译层 | 对源层的持续重构综合；读时综合，ingest 是 refactor | `lore/wiki/`（L0–L5 原著）、`game/docs/wiki/`（L6 转译+工程） | Agent 撰写维护；双库分离（L1 D4） |
| 导航层 | 入口、地图、状态，不承载长文权威 | 根 `README.md`、`PROJECT_MAP.md`、`AGENTS.md`、各目录 `README.md`/`index.md` | 随结构变化同步更新 |
| 镜像/导入层 | 外部项目快照 | `editorial/`、`fortune/`、`ai-system/` | 只做导入与导航；不改产品语义 |

规则：低层文档不得改写高层意图。产品权威链仍以根 `AGENTS.md` 为准；本文件只管**文档卫生与治理流程**，不新增产品权威。

## 2. 全仓统一约定

1. **相对链接必须可解析**：`[text](path)` 指向的文件必须存在；锚点链接（`#...`）与外链除外。新增链接前先确认目标。
2. **路径引用写仓库根相对全路径**（L1 D2）：`game/AGENTS.md`、`docs/superpowers/plans/...`、`lore/wiki/...`。不在仓库内的外部标识（如 `lucasastorian/llmwiki`）仅作备注。
3. **失源显式降级**（L1 D3）：源文件灭失时用 `[失源] <原名>（说明）` 标注，并在对应 `plan.md`/债务清单登记；优先重锚到现存权威，禁止静默删主张、禁止把失源升格为无引用事实。
4. **标注词表**（L1 D1，实践正典）：原著锚点/原著真源 · 游戏裁定/差异声明 · 游戏压缩（须三件套：原著锚点＋压缩维度＋projection/ruling 依据）· 纯游戏/纯实现 · 显式分析/推断。不使用 `[FACT]/[DESIGN]/[INFERRED]` 硬标签。
5. **L0–L5 与 L6 严格分离**：原著事实、角色观点、传闻、游戏数值不得混写；game wiki 不重新发明世界观，lore wiki 不写游戏数值。
6. **frontmatter 按层要求，不全仓一刀切**：
   - `game/docs/wiki/**`：`title` / `description` / `date`（YYYY-MM-DD）/ `tags`（≥2）
   - `lore/wiki/**` 概念页：`type` / `name` / `aliases` / `sources`（schema v2 另加 `description`/`date`/`tags`/`schema`）
   - 源层与导航层：不强制 frontmatter；若写了 `date` 则须为 `YYYY-MM-DD`
7. **孤儿页**：编译层页面必须至少被一页链入（hub 除外）；其他目录孤儿记 WARN，不阻断。
8. **可视化按需**：≥3 状态/事件/复杂关系时提供表格或 mermaid；单事实页不强配图。mermaid 节点标签含括号须加引号，避免 `$`。

## 3. 门禁模型（本地唯一，可复跑）

| 门禁 | 命令 | 范围 | 职责 |
|---|---|---|---|
| G0 全仓结构 | `node tools/docs-lint.mjs` | 全仓 Markdown（见豁免） | 断链、孤儿、frontmatter 日期、脚注路径形状、mermaid 卫生 |
| G1 lore 内容 | `pwsh -NoProfile -File lore/wiki/tools/check.ps1` | `lore/wiki/` | 来源路径、canon-index ID、E-ID、schema 字段 |
| G2 game wiki 内容 | `node game/docs/wiki/lint.mjs` | `game/docs/wiki/` | frontmatter 四字段、脚注源、可视化、链接 |

约定：

- **本地 G0–G2 是唯一 Wiki 内容质量门禁**（L1 D6）；外部 skill（`wiki-lint`/`kb-review` 等）只读建议，不得替代门禁、不得自动改 wiki、不得强加外部 schema。
- Wiki 门禁绿 **≠** 实现正确；Canon→Game 落地仍需 Runtime/Conformance 门禁（`game/tools/check.ps1`、GUT、`compile_runtime.py` 等）。
- 触碰 wiki 页后至少跑对应内容门禁；跨目录或改导航后跑 G0。
- 普通工程问题直接闭环；方法论多解走 L1。

## 4. 入库即治理（新文档 / 新变更）

**新 Markdown 进入本仓或既有文档实质修订时，同批完成治理，不事后补票。**

| 步骤 | 动作 | 门禁 |
|---|---|---|
| 1. 定层 | 先判定落入哪一层（源 / 编译 / 导航 / 镜像）；源层写清权威与日期，编译层写进对应 wiki | — |
| 2. 入口 | 更新父目录 hub（`README.md` / `index.md` / `PROJECT_MAP.md`）中的**真实 Markdown 链接**，不用反引号文件名冒充索引 | G0 孤儿 |
| 3. 引用 | 相对链接可解析；脚注/路径写仓库根相对全路径；失源用 `[失源]` | G0 |
| 4. 字段 | 编译层按 §2.6 补 frontmatter；源层若写 `date` 须 `YYYY-MM-DD` | G0 / G1 / G2 |
| 5. 跑门禁 | `node tools/docs-lint.mjs`；触碰 wiki 再跑 G1/G2 | 退出码 0 |
| 6. 登记 | 有缺口/冲突/待裁定写 `docs/debt.md` 或对应 `plan.md`；CHANGELOG 记可核对变更 | — |

禁止：

- 孤儿投放：只落盘、不挂 hub、不改引用。
- 反引号目录清单冒充链接（索引用 `[name](path)`）。
- 把游戏数值写进 lore、把原著事实写成无锚点断言。
- 用外部 wiki 工具自动改写本仓页面。

例行提示词（可调度）：

> 读 `docs/DOCUMENTATION_GOVERNANCE.md`。自上次以来 `git log --diff-filter=A/M -- '*.md'` 找变更；**对每个新增/修订文档执行 §4 入库清单**；更新受影响编译层与导航；跑 `node tools/docs-lint.mjs` 及对应 wiki 门禁；登记 plan/债务。

## 5. 维护流程

1. 新源文档落入源层后，用导航 hub 定位受影响编译层页面（通常 5–15 页）。
2. 更新页面 → 回查反向链接 → 更新 hub 的 Key Findings/导航（仅当范围/结论/结构变化）。
3. 在对应 `plan.md`（或 `CHANGELOG.md`/`docs/debt.md`）登记 What/Why。
4. 跑 G0；触碰 wiki 时再跑 G1/G2。
5. 双库同步：lore → game **按需触发**（L1 D5），只更新受影响的 L6/Game Semantics，不做页面镜像。

## 6. 豁免（不参与 G0 链接/孤儿检查）

- `archive/**`（历史保留，不作入口）
- `**/references/**`（规范提取副本，按原文保留）
- `source/**`、`**/.git-nested-backup/**`、`**/.worktrees/**`、`**/node_modules/**`、`**/.godot/**`
- 镜像层中**上游只读**且本仓约定不改的路径（若产生误报，在债务清单登记，不放宽规则本身）

## 7. 边界

- 本规范不替代 `docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md`、`docs/CHANGE_CONTROL_PROTOCOL_v1.0.md` 与产品 PRD。
- 不为治理新增数据库、GraphRAG 或第二套 Wiki。
- 已知缺口、失源与例外一律进 `docs/debt.md` 或对应 `plan.md`，不静默消化。
