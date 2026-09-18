# 《問眞》文档体系标准与维护规范

- 日期：2026-08-28
- 状态：待用户裁决（按本日问询结果：方案 A，仅新增规范与待修清单，不原地治理）
- 范围：本仓库所有人手写的 Markdown 设计文档（`AGENTS.md` 除外，仅作为被引用基线）；不含 README/THIRD_PARTY_NOTICES、供应商自带（`addons/`、`vendor/`）、原始语料（`分支：六卷精编版/`、`肉鸽设计-原始数据/`）。
- 作品名：现行名统一为《問眞》；历史/技术语境的别名仅在引用上下文出现，详见 §3。
- 落地原则：规范只定义"以后怎么写、怎么挂、怎么索引"，不替回改旧文——历史漂移另由 `2026-08-28-doc-grooming-backlog.md` 列项。

## 0. 设计目的与边界

本仓库经历了多轮并行会话（UI 重设计、机制锁死、调试台融合、问眞浅色主题等），文档分散在四套目录（`docs/lore/`、`docs/superpowers/specs|plans|reports|sdd-archive/`、`.superpowers/sdd/`、`docs/knowledge-base/`）以及顶层 `AGENTS.md`、`README.md`、`项目决策浓缩对话.md`、`visual-reference-index.md`，且作品名在《蛊路求生》《問眞》《问眞》之间漂移，日期格式与"状态/基线/分支"元数据也未统一。

本文档只为后续创作提供唯一标准，不强制清洗存量文档；历史漂移仅在 §6 与《待治理清单》中如实记录，等待独立裁决。

不在本文档范围：

- 代码、GDScript、注释规范——参见 `AGENTS.md` 与既有 ADR/技能。
- 数据表（`data/*.json`）字段契约——已由 `scripts/domain/content_catalog.gd` 等模块守住。
- 美术、音频资产命名——另行规范。

## 1. 文档分层与权威关系

### 1.1 权威链（任何引用冲突按此裁决）

```
Tier 0  AGENTS.md                          工作流/约束最高基线（用户实时裁定）
Tier 1  机制先行锁死规格书                  《問眞》设计/实现的机制权威基线
        docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md
Tier 2  当前生效设计规格                    docs/superpowers/specs/<日期>-<topic>-design.md（状态=生效/已批准）
Tier 3  实施计划与验收报告                  docs/superpowers/plans/  +  docs/superpowers/reports/
Tier 4  主题文档                            docs/superpowers/specs/ 中专题/批处理规格（如 R14.5/R14.6 DDA）
Tier 5  知识/语料                           docs/lore/（canon-index / adaptation-register / game-rule / content-source）
Tier 6  索引与对话摘要                      README.md、项目决策浓缩对话.md、visual-reference-index.md
```

裁决链（与机制先行规格书 §0 同源）：`AGENTS.md` 用户最新裁定 > 机制先行规格书 > Tier 2 当前生效规格 > Tier 3 实施/报告 > Tier 5 知识语料。当且仅当用户最新指令显式覆盖时，可下沉/上调。

### 1.2 目录职责

| 目录 | 职责 | 不收 | 维护方 |
| --- | --- | --- | --- |
| `docs/superpowers/specs/` | 设计规格：游戏机制、UI、批处理口径 | 已下沉的实现细节、对话记录 | 主代理/用户审批 |
| `docs/superpowers/plans/` | 实施计划（任务分解、TDD 步骤） | 设计哲学、UI 概念稿 | 控制器/任务代理人 |
| `docs/superpowers/reports/` | 验收报告：测试通过、视觉签收、批处理复盘 | 临时 `git log` 输出 | 验收会话 |
| `docs/superpowers/sdd-archive/` | 已完成 SDD 任务简报/报告归档（topic 不再活跃） | 新增活跃任务 | 自动归档或控制台 |
| `.superpowers/sdd/` | 进行中 SDD 任务简报/报告 | 已结案任务 | 当前任务代理 |
| `docs/lore/` | 原著事实索引、改编条目、规则登记、内容来源契约 | 设计哲学、实现计划 | 内容/世界观代理 |
| `docs/knowledge-base/` | **当前未使用**（见待治理清单 §1.2），保留作为未来跨项目知识入口预留位 | 任何与游戏设计直接耦合的规格 | 待指定 |
| `docs/项目决策浓缩对话.md` | 历史交接摘要（Tier 6） | 任何新决策的唯一落点 | 用户/主代理 |
| `docs/visual-reference-index.md` | AI 参考图 → 工程约束（视觉裁决） | 设计规格 | UI/视觉会话 |
| `docs/open-rpg-audit.md` | 第三方审计（一次性） | 任何新增依赖审计 | 控制台（按需） |
| `README.md`、`AGENTS.md` | 项目门面/工作流基线 | 详细规格 | 用户 |
| `addons/`, `vendor/`, `分支：六卷精编版/`, `肉鸽设计-原始数据/` | 第三方/原始语料 | 任何改写 | 受 `AGENTS.md` 工作边界约束 |

### 1.3 与 `.superpowers/` 的关系

- `.superpowers/sdd/` 是活动 SDD 任务台（brief + report 一对一）；
- `docs/superpowers/sdd-archive/` 是已结案 SDD 归档；
- `docs/superpowers/progress.md` 与 `.superpowers/sdd/progress.md` 不重复维护：前者记批处理，后者记单任务。

## 2. 文件命名

### 2.1 规格/计划/报告

`YYYY-MM-DD-<topic>-<kind>.md`，其中：

- 日期=首次起草日期（UTC+8）；同主题延续用同日期。
- `kind ∈ {design, plan, report, brief, ledger}`；spec 用 `design`。
- `topic` 全小写、ASCII，使用连字符；中文名以别名/副标题形式出现在 H1。

样例（与现有规范保持一致）：

- `docs/superpowers/specs/2026-08-28-p0-1-wenzhen-theme-migration-design.md`
- `docs/superpowers/plans/2026-08-28-p0-1-wenzhen-theme-migration.md`

### 2.2 索引/对话/视觉参考

- `index.md`/`README.md`：在各自目录充当门牌；只写职责与导航，不写规则细节。
- `visual-reference-index.md`：锁定项目唯一一份，所有视觉参考追加到末尾章节（§1 表格），不另起文件。

### 2.3 SDD 任务

`task-<short-id>-brief.md` / `task-<short-id>-report.md`，外加 `progress.md` 总账。

短 ID 规范（已使用）：`p0-1`、`p1a`、`p2a`、`l1`、`c1min`、`n1`、`t5a..t6e`、`dbg1`、`dbg-fusion`。新增短 ID 前在 `.superpowers/sdd/progress.md` 登记。

## 3. 作品名口径（2026-08-28 用户裁决）

| 场景 | 用名 |
| --- | --- |
| 设计/UI/视觉 | **《問眞》**（横排繁体；问眞仅作简体别名，不另立文件） |
| 工作流、AGENTS.md、README 标题 | 《問眞》（主名）/ 《蛊路求生》（仅作副名/旧名） |
| 第三方许可声明 | 使用对方文档原名 |
| 内部代码标识符、JSON 键、ASCII 文本 | `wenzhen`（现行）/ `nanjiang_smoke`（仅在旧基线残留别名表出现一次） |

任何新写文件在 H1 首次出现作品名时使用《問眞》；若需引用《蛊路求生》，紧跟一句"前称《蛊路求生》/旧名 Nanjiang Smoke"。**禁止**在文件名、目录名、代码标识符中使用中文作品名。

## 4. 元数据模板

任何 `docs/superpowers/{specs,plans,reports}/**` 文件首屏（≤ 8 行）应至少包含：

```markdown
# <中文标题>

- 日期：YYYY-MM-DD
- 状态：草案 | 待评审 | 已批准 | 生效基线 | 已归档
- 范围：<一句话职责/边界>
- 替代关系（如有）：<取代哪份、与哪份共存>
```

状态字典：

| 状态 | 含义 |
| --- | --- |
| 草案 | 写作中，不接受外部引用 |
| 待评审 | 提交评审，未通过 |
| 已批准 | 评审通过，可作下游引用 |
| 生效基线 | 已成为当前机制/UI 权威基线 |
| 已归档 | 被新文档取代，仅作历史 |
| CHANGES_REQUESTED | 视觉验收驳回，需返工（仅视觉报告使用） |

`AGENTS.md` 不要求该模板，但其内部"当前状态"段落承担同等作用。

## 5. 链接、引用、版本

- 内部链接使用仓库相对路径（`docs/...`），不使用绝对路径；跨分支引用附 `branch=<name>`，例如 `(../specs/2026-08-25-mechanics-first-lockdown-design.md@master)`。
- 引用日期时优先引用具体 spec 路径；只在概览段落写"2026-08-25 机制规格书"等指代。
- "基线 commit" 用 7 位短 SHA 表达，不写长 SHA；同一份文档内多次出现同 SHA 后续可省略为"<前文 SHA>"。
- 视觉参考图锚点必须落在 `docs/visual-reference-index.md` 表格的 `#` 锚点上，不在文档正文内嵌图片 URL。
- `docs/superpowers/specs/` 内仅保留状态 = 已批准/生效基线/已归档 的文档；草案落在作者 worktree，分支合入时再迁入。

## 6. 与现有文档的对照（口径变化记录）

> 以下是当前 `docs/` 现实与本规范的偏差记录；**不强制回改**，仅作待治理清单的索引。

| 现状 | 应为 | 影响 |
| --- | --- | --- |
| `docs/项目决策浓缩对话.md` 引用 `GDD.md` | 改为引用机制先行规格书或具体生效 spec | 链接失效（已扫） |
| `docs/项目决策浓缩对话.md` 仍在多处使用《蛊路求生》 | 现行名《問眞》，旧名括注 | 作品名漂移 |
| `docs/knowledge-base/` 目录为空 | 待定（保留作跨项目知识入口，或转为 `docs/lore/` 索引） | 空目录 |
| `addons/reactive_ui_toolkit/CHANGELOG.md` 引用的 `MIGRATION-0.x.md` 缺失 | 由该 addon 上游维护，本规范不强制约束 | 第三方域，不在本文档治理范围 |
| `.superpowers/sdd/` 与 `docs/superpowers/sdd-archive/` 角色边界 | 见 §1.3；归档时机需控制台定期迁移 | 归档不清 |
| 多份 spec/plan 缺首屏元数据 | 模板（§4） | 元数据不齐 |
| 多份文件名仍带 `nanjiang-roguelite-...` | 旧基线快照保留即可，新文件不再沿用 | 命名漂移，仅历史 |

具体行项、修复建议、责任与优先级见 `2026-08-28-doc-grooming-backlog.md`。

## 7. 维护检查表（新建/合并时自检）

- [ ] H1 含作品名并符合 §3。
- [ ] 首屏元数据齐全（§4）；状态字段合法值。
- [ ] 文件名符合 §2.1。
- [ ] 内部链接全部存在；引用基线优先 Tier 1/2（§1.1）。
- [ ] 不复制粘贴 Tier 1/2 段落，必要时只引用。
- [ ] 未引入 Tier 0 之外的"约束新规则"——若需，提到 `AGENTS.md` 用户裁定落点。
- [ ] 若取代旧文档：旧文档状态改为"已归档"，并在 H1 副标题或 §"替代关系"段落写明。
- [ ] 若产生新 SDD 短 ID：在 `.superpowers/sdd/progress.md` 登记一行。

## 8. 维护节奏

- **写入即登记**：新文档合入 master 时，本批次的控制器在 `AGENTS.md` 末尾"已完成的批次"段落追加一行（含日期、目录、关键改动）。
- **季度治理**：控制台每季度（暂设每年 3/6/9/12 月末）对照 §6 维护一份《待治理清单》增量；非紧急，不做原地修复。
- **归档时机**：任务状态从"进行中"→"已结案"的次日，由控制台把 `.superpowers/sdd/task-<id>-*.md` 移到 `docs/superpowers/sdd-archive/`，并在 `.superpowers/sdd/progress.md` 留指针行。
- **作品名变更**：作品名变更需用户裁决；通过后，更新 §3 表格、`README.md`、`AGENTS.md` "项目定位"段，并扫一遍 `docs/superpowers/` 历史文档替换 H1 标题（仅 H1，正文不动）。

## 9. 风险与未决项

- `docs/knowledge-base/` 空目录是否保留作为未来跨项目知识入口，**待用户裁决**（待治理清单 §1.2 标记）。
- 历史文档的原地回改需逐文件评估影响（例如 `项目决策浓缩对话.md` 一旦改写会改变历史交接语义），建议只在合入新版摘要时附"勘误表"。
- 《問眞》作为视觉/UI 现行名，若未来重做品牌，§3 流程应回写一份"作品名迁移规范"，避免再次漂移。
