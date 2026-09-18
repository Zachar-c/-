# PROJECT_MAP.md

> 根导航：先读本文件，再进入一个目标目录的首读文件。迁移执行计划见 `docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`，来源登记见 `MIGRATION.md`，已知债务见 `docs/debt.md`。

## 导航约定

- 入口顺序：`AGENTS.md` → `PROJECT_MAP.md` → 目标目录 `README.md` / `AGENTS.md`。
- 一次只进一个目录；没有理由不扫描全仓。
- 已完成导入的目标目录（`lore/`、`editorial/`、`fortune/`、`ai-system/`）是当前入口；`gu-zhenren-editor/` 仍是当前游戏快照，Task 7 迁移前不手动拆散。

## 目标目录

### `lore/research/`（Task 5 已导入）

- 用途：`gu-zu` 研究、读书资料、设定和设计原始材料的完整资料包；首次迁移不拆分内部研究/设定/游戏设计边界。
- 首读文件：`lore/research/README.md`。
- 当前入口：`lore/research/`（导入提交 `072aa6e`，206 文件；旧 `gu-zu/` 的受版本内容已删除）。
- 权威来源：`https://github.com/Zachar-c/gu-zu.git`（`master`，基线 `84b8ce8`）。
- 可修改范围：仅目录导入、来源路径登记、债务登记；不改写研究语义。

### `lore/wiki/`（Task 5 已迁移）

- 用途：冻结的 AI 可读 Wiki（原 `wenzhen-lore`），只读知识。
- 首读文件：`lore/wiki/README.md`、`lore/wiki/index.md`、`lore/wiki/AGENTS.md`。
- 当前入口：`lore/wiki/`（旧 `wenzhen-lore/` 已移除）。
- 权威来源：父仓库 `5f3fbfc` 快照；现以 `lore/wiki/` 为准。
- 可修改范围：只允许目录移动、文件重命名、相对链接更新、来源路径更新；禁止补写事实、改写分析、调整主题结论、扩充知识范围。

### `editorial/`（Task 6 已导入）

- 用途：GitHub `gu-zhenren-editor` 项目（《蛊真人》编辑部资料库、分卷精编流水线与 epub 构建脚本）。
- 首读文件：`editorial/README.md`。
- 当前入口：`editorial/`（导入提交 `0cbce85`，183 文件）。
- 权威来源：`https://github.com/Zachar-c/gu-zhenren-editor.git`（`main`，基线 `dbf6615`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。
- 注意：本目录与旧根目录 `gu-zhenren-editor/` 同名但不同项目；后者是 Gitee Godot 游戏工程快照，Task 7 迁移为 `game/`。

### `game/`（待 Task 7 导入）

- 用途：当前 Gitee Godot 游戏工程（最后迁移，保留工程结构、UID、资源路径和测试入口）。
- 首读文件：`game/AGENTS.md`、`game/world-model/governance/CONSTRAINTS-V2.md`（导入后）。
- 当前入口：`gu-zhenren-editor/`（旧快照，当前游戏位置；`game/` 建立前不挪动它）。
- 权威来源：`https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git`（`master`）。
- 可修改范围：仅目录导入、旧根路径配置/文档的机械引用更新、忽略规则；不改 Godot 逻辑、数据数值与契约内容。
- 约束说明：当前生效约束以 `game/world-model/governance/CONSTRAINTS-V2.md` 为准；`game/docs/contracts/2026-09-12-agent-ownership-contract.md` 已被该约束明确降级为历史档案，不作为执行契约。

### `fortune/app/`（Task 6 已导入）

- 用途：GitHub `fortune-app` 项目。
- 首读文件：`fortune/app/PRD.md`（该仓库无 README）。
- 当前入口：`fortune/app/`（导入提交 `6603115`，36 文件；未复制本地外层包装目录 `fortune-app/fortune-app/`）。
- 权威来源：`https://github.com/Zachar-c/fortune-app.git`（`master`，基线 `a039639`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。

### `fortune/server/`（Task 6 已导入）

- 用途：GitHub `fortune-server` 项目。
- 首读文件：`fortune/server/FortuneServer.java` 与 `fortune/server/start-fortune-server.sh`（该仓库无 README）。
- 当前入口：`fortune/server/`（导入提交 `0240567`，3 文件）。
- 权威来源：`https://github.com/Zachar-c/fortune-server.git`（`main`，基线 `6a5eed2`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。

### `ai-system/`（Task 6 已导入）

- 用途：GitHub `my-ai-production-system` 项目。
- 首读文件：`ai-system/PRD.md`（该仓库当前只有这一个文件）。
- 当前入口：`ai-system/`（导入提交 `479145d`，1 文件）。
- 权威来源：`https://github.com/Zachar-c/my-ai-production-system.git`（`main`，基线 `fbe67e2`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。

### `docs/`

- 用途：项目计划、设计说明与债务清单。
- 首读文件：`docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`（执行计划）、`docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md`（设计）、`docs/debt.md`（债务）。
- 权威来源：本仓库。
- 可修改范围：迁移记录、债务登记、验收记录；不写新业务规格。

### `archive/`

- 用途：历史资料保留位置，不得作为当前入口。
- 首读文件：`archive/README.md`。
- 权威来源：本仓库。
- 可修改范围：仅保留规则说明；不新增有效入口。

## 本地-only 位置（不进入 Git）

- `source/`：本地共享原始资料位置，被根 `.gitignore` 的 `/source/` 规则排除；完整原文只保留在这里。
- `**/.git-nested-backup/`、`**/.worktrees/`：本地恢复材料，被根规则排除，不进入 Monorepo。
