# Gu Zhenren Monorepo Migration Design v1.0

状态：审阅通过；迁移已在 `master` 执行完成（2026-09-18）。本文是迁移期设计基线，不是仓库的长期定位说明。

## 1. 目标

把同一台个人电脑上由多个 Agent/LLM 协作维护的《蛊真人》项目统一到一个 Git 仓库。仓库统一的是数据、上下文和版本边界；各产品仍保留自己的代码和入口。

本次重构的直接目标是：让 AI 能先找到正确入口，再进入正确项目；同时借迁移机会登记并处理明显的文档、路径、重复资料和临时文件债务。

## 2. 非目标

- 不把仓库建设成企业级平台。
- 不新增数据库、RAG、知识图谱、registry、任务队列或复杂 schema。
- 不重写稳定的业务代码，不顺手清洗全仓格式。
- 不改变 `wenzhen-lore` 的语义内容、事实结论或分析结论。
- 不把完整原始小说提交到 Monorepo。

## 3. 目标目录

```text
gu-zhenren/
├── AGENTS.md
├── PROJECT_MAP.md
├── MIGRATION.md
├── source/                    # 本地原始资料，根 .gitignore 排除
├── lore/
│   ├── research/              # gu-zu：研究、读书资料、设定和设计原始材料
│   └── wiki/                  # wenzhen-lore：AI 可读蒸馏 Wiki
├── editorial/                 # GitHub gu-zhenren-editor
├── game/                      # 当前 Gitee 游戏工程
├── fortune/
│   ├── app/                   # GitHub fortune-app
│   └── server/                # GitHub fortune-server
├── ai-system/                 # GitHub my-ai-production-system
├── docs/
│   └── debt.md                # 简单技术债清单
└── archive/
    └── README.md              # 历史资料保留规则
```

`source/` 是本地共享原始资料位置，不进入远程仓库。迁移 Wiki 时允许机械更新相对链接和来源路径，但不改变页面语义。

第一次迁移不强行拆散 `gu-zu` 内部的研究、设定和游戏设计文件；它作为一个完整资料包进入 `lore/research/`，并在 README 中注明内部边界。只有出现真实维护痛点时，才单独把游戏设计移动到 `game/`，避免为了“看起来整齐”制造复制和断链。

## 4. AI 导航约定

根目录只增加三层必要入口：

```text
AGENTS.md → PROJECT_MAP.md → 目标目录 README.md
```

- `AGENTS.md`：不超过 100 行，只写项目目标、简单原则、当前阶段和禁止事项，不写具体任务。
- `PROJECT_MAP.md`：列出每个目录的用途、首读文件、当前入口、权威来源和可修改范围。
- 各项目保留自己的 README；只有缺少入口时才补充，不复制其他项目的完整规则。

AI 的默认行为是先读地图，再按任务进入一个目录；没有理由时不扫描整个仓库。

## 5. Wiki 冻结边界

> 本节是迁移期约束：冻结只为保证迁移期间语义不变，不构成本仓库的长期定位。迁移完成后 `lore/wiki/` 已解冻，当前编辑约定见 `lore/wiki/AGENTS.md`，续作计划见 `docs/superpowers/plans/2026-09-18-wenzhen-lore-wiki-continuation.md`。

`lore/wiki/` 在本次迁移中视为冻结资产：

- 允许：目录移动、文件重命名、相对链接更新、来源路径更新。
- 禁止：补写事实、改写分析、重新蒸馏、调整主题结论、扩充知识范围。
- 迁移后必须验证所有 Markdown 链接和 `source/notes/memory` 来源路径。

## 6. 共享数据流

```text
source/（本地原始资料）
        ↓
lore/research/（研究与整理）
        ↓
lore/wiki/（AI 可读蒸馏知识，按批次持续更新）
        ↓
game / editorial / fortune / ai-system
```

产品可以读取共享资料，但不在各自目录复制一份完整原文。产品专属的实现数据仍留在产品目录中。

来自不同远程的同一份原始文本只保留一个本地 `source/` 副本；远程仓库中的原文文件在导入时排除，并在 `MIGRATION.md` 中记录原路径和替代位置。

## 7. 历史迁移策略

- 新纳入的远程仓库优先在临时克隆中使用 `git filter-repo --to-subdirectory-filter` 或等价的 `git subtree` 方式导入，以保留作者、日期和提交历史。
- 不把远程仓库的 `.git` 目录或 worktree 带入父仓库。
- 已经提交到当前父仓库的快照不重写已发布历史；原子仓库 URL、分支、基线提交和过滤内容记录在 `MIGRATION.md`。
- Git 历史保留不能成为迁移失败的理由；如果工具或远程历史不适合合并，保留来源记录并导入可审计快照。

## 8. 债务审计

审计结果只记录在 `docs/debt.md`，不另造管理系统。每项使用：

```text
路径 | 类型 | 现状 | 处理 | 权威/理由
```

类型只使用：

- `KEEP`：当前有效。
- `MOVE`：有效但目录职责错误。
- `MERGE`：重复内容，需要选择权威版本。
- `ARCHIVE`：历史有效，但不得作为当前入口。
- `EXCLUDE`：原文、缓存、构建产物、临时输出或嵌套 Git。
- `REVIEW`：存在冲突，暂不自动判断。

本次只优先处理会误导 AI 或破坏迁移的债务：重复入口、同名项目、断链、来源失效、重复原始资料、缓存和明显废弃目录。普通代码重构和产品 Bug 留在对应项目内单独处理。

## 9. 迁移阶段

1. 创建根 `AGENTS.md`、`PROJECT_MAP.md`、`MIGRATION.md`、`docs/debt.md` 和 `archive/README.md`。
2. 迁移 `gu-zu` 与冻结 Wiki，机械修复路径并验证来源。
3. 迁移 GitHub `gu-zhenren-editor` 与 `my-ai-production-system`。
4. 将 `fortune-app` 与 `fortune-server` 收入 `fortune/`。
5. 最后迁移 Godot `game/`，检查导入文件、UID、资源路径和测试入口。
6. 汇总债务清单，完成根导航、路径和边界验证后提交推送。

每个阶段只改变目录、入口和必要路径，不同时改变产品行为。

## 10. 完成条件

- 所有纳入的远程仓库都有明确目标目录和来源记录。
- 根导航能在三步内把 Agent 带到目标入口。
- `lore/wiki/` 语义内容无变化，链接和来源路径全部可解析。
- Git 树中没有嵌套 `.git`、worktree、完整原文或临时构建产物。
- `docs/debt.md` 已记录已知烂账及“有意保留”的旧内容。
- 各项目原有可运行入口和已有验证命令仍可定位；不以本次迁移为由声称产品功能已修复。
