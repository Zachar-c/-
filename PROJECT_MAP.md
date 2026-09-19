# PROJECT_MAP.md

> 根导航：先读本文件，再进入一个目标目录的首读文件。迁移执行计划见 `docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`，来源登记见 `MIGRATION.md`，已知债务见 `docs/debt.md`。
>
> **本文件只是导航地图，不是产品权威。**《问真》产品权威链以根 `AGENTS.md` 的「文档权威链」一节为准：
> `docs/PRODUCT_REQUIREMENTS_v1.0.md`（第 1 层）为最高。

## 导航约定

- 入口顺序：`AGENTS.md` → `PROJECT_MAP.md` → 目标目录 `README.md` / `AGENTS.md`。
- 一次只进一个目录；没有理由不扫描全仓。
- 已完成导入的目标目录（`lore/`、`editorial/`、`fortune/`、`ai-system/`、`game/`）是当前入口；旧 `gu-zhenren-editor/` 的受版本内容已删除（Task 7），残留本地恢复材料不作为入口。

## 目标目录

### `lore/research/`（Task 5 已导入）

- 用途：`gu-zu` 研究、读书资料、设定和设计原始材料的完整资料包；首次迁移不拆分内部研究/设定/游戏设计边界。
- 首读文件：`lore/research/README.md`。
- 当前入口：`lore/research/`（导入提交 `072aa6e`，206 文件；旧 `gu-zu/` 的受版本内容已删除）。
- 权威来源：`https://github.com/Zachar-c/gu-zu.git`（`master`，基线 `84b8ce8`）。
- 可修改范围：仅目录导入、来源路径登记、债务登记；不改写研究语义。

### `lore/wiki/`（Task 5 已迁移）

- 用途：AI 可读的《蛊真人》蒸馏知识层（原 `wenzhen-lore`），按批次持续更新。
- 首读文件：`lore/wiki/README.md`、`lore/wiki/index.md`、`lore/wiki/AGENTS.md`。
- 当前入口：`lore/wiki/`（旧 `wenzhen-lore/` 已移除）。
- 权威来源：父仓库 `5f3fbfc` 快照；现以 `lore/wiki/` 为准。
- 可修改范围：按 `lore/wiki/AGENTS.md` 编辑约定增补与修订页面；事实必须可追溯到 `source/`、读书笔记、记忆库或 `canon-index:` 条目，游戏数值与改编不写入原著事实区。

### `editorial/`（Task 6 已导入）

- 用途：GitHub `gu-zhenren-editor` 项目（《蛊真人》编辑部资料库、分卷精编流水线与 epub 构建脚本）。
- 首读文件：`editorial/README.md`。
- 当前入口：`editorial/`（导入提交 `0cbce85`，183 文件）。
- 权威来源：`https://github.com/Zachar-c/gu-zhenren-editor.git`（`main`，基线 `dbf6615`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。
- 注意：本目录与旧根目录 `gu-zhenren-editor/` 同名但不同项目；后者是 Gitee Godot 游戏工程快照，Task 7 已迁移为 `game/`，旧快照受版本内容已删除。

### `game/`（Task 7 已导入）

- 用途：当前 Gitee Godot 游戏工程（最后迁移，保留工程结构、UID、资源路径和测试入口）。
- 首读文件：`game/AGENTS.md`、`game/world-model/governance/CONSTRAINTS-V2.md`。
- 当前入口：`game/`（导入提交 `ebb7f81`，744 提交、1904 文件，另有本地带过提交 `db34873`；旧 `gu-zhenren-editor/` 的受版本内容已删除）。
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

- 用途：GitHub `my-ai-production-system` 项目 + 本仓库的 AI 执行环境约定（Worker 协议、模型链、任务包）。
- 首读文件：`ai-system/AGENTS.md`、`ai-system/README.md`。
- 当前入口：`ai-system/`（导入提交 `479145d`，1 文件）。
- 权威来源：`https://github.com/Zachar-c/my-ai-production-system.git`（`main`，基线 `fbe67e2`）。
- 可修改范围：仅目录导入与导航更新；不改产品逻辑。
- **命名消歧（2026-09-20）**：`ai-system/PRD.md` 是上述镜像项目的文档（`MyAIProductionSystem`，Vue3/FastAPI/Chroma），
  自 2026-09-18 起已标注为历史设计记录。**它不是《问真》的 PRD**，不得作为产品权威读；
  《问真》PRD 见 `docs/PRODUCT_REQUIREMENTS_v1.0.md`。该文件属镜像上游内容，**不得改名**（改名会破坏镜像映射）。

### `docs/`

- 用途：**《问真》权威协议层**、项目计划、设计说明与债务清单。
- 首读文件：
  - `docs/PRODUCT_REQUIREMENTS_v1.0.md`（**第 1 层 PRD，《问真》唯一产品权威**）
  - `docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md`（第 2 层：L0/L1/L2/Worker 职责与文档优先级）
  - `docs/CHANGE_CONTROL_PROTOCOL_v1.0.md`（第 2 层：变更控制与优先级阶梯）
  - `docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`（执行计划）、`docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md`（设计）、`docs/debt.md`（债务）
- 权威来源：本仓库。
- 可修改范围：迁移记录、债务登记、验收记录；协议层只由 L0 修订。
- 注意：`docs/` 与 `game/docs/` 同名但不同层——`game/docs/` 属 `game/` 内部文档，层级不高于本目录协议。

### `archive/`

- 用途：历史资料保留位置，不得作为当前入口。
- 首读文件：`archive/README.md`。
- 权威来源：本仓库。
- 可修改范围：仅保留规则说明；不新增有效入口。

## 本地-only 位置（不进入 Git）

- `source/`：本地共享原始资料位置，被根 `.gitignore` 的 `/source/` 规则排除；完整原文只保留在这里。
- `**/.git-nested-backup/`、`**/.worktrees/`：本地恢复材料，被根规则排除，不进入 Monorepo。
