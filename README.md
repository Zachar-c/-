# 问真·《蛊真人》项目 Monorepo

这个仓库统一管理《蛊真人》相关的游戏开发、资料整理与 AI 协作资产。AI 先读 `AGENTS.md`，再读 `PROJECT_MAP.md`，再进入一个目标目录。

## 快速开始与技术栈

《问真》当前目标是完整、可长期游玩的浏览器游戏，产品入口为 [Web 版](game/wenzhen-web-lab/README.md)（`game/wenzhen-web-lab/lab.html`）。既有 Godot 工程保留为成熟规则与内容数据来源，可按需要复用；美术方向可以原创设计。

仓库包含多种技术栈：《问真》当前产品使用 HTML、CSS 与 JavaScript；Godot、GDScript 与 JSON 工程提供成熟规则实现及数据来源。其他子项目各自维护运行环境，不在根目录统一安装或构建。开发命令见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 项目文档树

| 文件 | 职责 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | 项目协作、开发边界与 AI 执行规范 |
| [README.md](README.md) | 项目简介、技术栈、快速开始与索引 |
| [DESIGN.md](DESIGN.md) | 视觉风格、布局与交互规范入口 |
| [CHANGELOG.md](CHANGELOG.md) | 可核对的更新记录 |
| [TODO.md](TODO.md) | 开发计划入口和当前整理进度 |
| [PROJECT-SPEC.md](PROJECT-SPEC.md) | 产品定位、目标与功能范围的权威入口 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 架构、目录与数据组织 |
| [COMPONENT-GUIDELINES.md](COMPONENT-GUIDELINES.md) | 组件、样式、依赖与无障碍状态 |
| [PAGE-STRUCTURE.md](PAGE-STRUCTURE.md) | 页面入口与详情文档结构 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | 开发、验证与发布流程 |
| [REGISTRY.md](REGISTRY.md) | 组件构建、校验与分发状态 |
| [DEPLOYMENT.md](DEPLOYMENT.md) | 本地发行与 Cloudflare 部署状态 |

根文档提供统一入口，详细内容留在所属项目。唯一产品 PRD 和开发协议仍位于 `docs/`，权威链见 [AGENTS.md](AGENTS.md)。来源地图 [PROJECT_MAP.md](PROJECT_MAP.md)、历史记录 [MIGRATION.md](MIGRATION.md) 继续保留。

## 目标目录

- [`lore/research/`](lore/research/)：研究、读书资料、设定和设计原始材料（已从 `gu-zu` 完整导入）。
- [`lore/wiki/`](lore/wiki/)：面向 AI 使用的《蛊真人》蒸馏 Markdown Wiki，按批次持续更新（已从 `wenzhen-lore` 扁平迁移）。
- [`editorial/`](editorial/)：GitHub `gu-zhenren-editor` 编辑部资料库与分卷精编流水线（已导入）。
- [`game/wenzhen-web-lab/`](game/wenzhen-web-lab/)：《问真》当前 Web 完整产品入口与工程。
- [`game/`](game/)：Gitee Godot 游戏工程，保留成熟规则实现、内容数据与参考资料（Task 7 已导入）。
- [`fortune/app/`](fortune/app/)、[`fortune/server/`](fortune/server/)：`fortune-app` 与 `fortune-server` 项目（已导入）。
- [`ai-system/`](ai-system/)：`my-ai-production-system` 项目（已导入）。
- [`docs/`](docs/)：项目计划、设计说明与债务清单（`docs/debt.md`）。
- [`archive/`](archive/)：历史资料保留位置，不作为当前入口。

`gu-zu/`、`wenzhen-lore/` 与 `gu-zhenren-editor/` 的受版本迁移已完成；旧 `gu-zhenren-editor/` 的受版本内容已删除。当前游戏入口为 `game/wenzhen-web-lab/lab.html`；Godot 工程入口为 `game/`。各目录的当前入口与可修改范围见 `PROJECT_MAP.md`，来源登记见 `MIGRATION.md`。

## 资料边界

本仓库不提交《蛊真人》原文或《人祖传》全文。完整原文只在本地 `source/`（被根 `.gitignore` 的 `/source/` 规则排除，不进入 Git 树，不推送），用于必要时回查；Wiki 页面只记录整理后的知识、分析和来源定位。

以下内容也不进入版本库：子项目历史 Git 元数据、Git worktree、缓存、临时日志和本地测试输出。子项目原有 Git 元数据已保存在各自的 `.git-nested-backup/` 目录中，并由根目录规则忽略，便于需要时恢复。

## 迁移状态

- 执行计划：`docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`；旧的 `docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md` 已被取代，仅作历史参考。
- Monorepo 迁移已完成，执行记录见 [MIGRATION.md](MIGRATION.md)。上述迁移计划是历史记录，不再作为待办；遗留边界问题以 [债务清单](docs/debt.md) 为准。

## 协作原则

1. 原著事实、分析解读和游戏设计分层保存。
2. 能用 Markdown 和 Git 解决的问题，不提前引入数据库或自研知识引擎。
3. 需要核验时回查本地原始资料，不把读书笔记或 AI 摘要自动升级为原著事实。
4. 新内容先放入对应子目录，再通过父仓库统一提交和审阅。
