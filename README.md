# 问真·《蛊真人》项目 Monorepo

这个仓库统一管理《蛊真人》相关的游戏开发、资料整理与 AI 协作资产。AI 先读 `AGENTS.md`，再读 `PROJECT_MAP.md`，再进入一个目标目录。

## 目标目录

- [`lore/research/`](lore/research/)：研究、读书资料、设定和设计原始材料（已从 `gu-zu` 完整导入）。
- [`lore/wiki/`](lore/wiki/)：面向 AI 使用的《蛊真人》蒸馏 Markdown Wiki，按批次持续更新（已从 `wenzhen-lore` 扁平迁移）。
- [`editorial/`](editorial/)：GitHub `gu-zhenren-editor` 编辑部资料库与分卷精编流水线（已导入）。
- [`game/`](game/)：Gitee Godot 游戏工程（Task 7 已导入）。
- [`fortune/app/`](fortune/app/)、[`fortune/server/`](fortune/server/)：`fortune-app` 与 `fortune-server` 项目（已导入）。
- [`ai-system/`](ai-system/)：`my-ai-production-system` 项目（已导入）。
- [`docs/`](docs/)：项目计划、设计说明与债务清单（`docs/debt.md`）。
- [`archive/`](archive/)：历史资料保留位置，不作为当前入口。

`gu-zu/`、`wenzhen-lore/` 与 `gu-zhenren-editor/` 的受版本迁移已完成；旧 `gu-zhenren-editor/` 的受版本内容已删除，当前游戏入口为 `game/`。各目录的当前入口与可修改范围见 `PROJECT_MAP.md`，来源登记见 `MIGRATION.md`。

## 资料边界

本仓库不提交《蛊真人》原文或《人祖传》全文。完整原文只在本地 `source/`（被根 `.gitignore` 的 `/source/` 规则排除，不进入 Git 树，不推送），用于必要时回查；Wiki 页面只记录整理后的知识、分析和来源定位。

以下内容也不进入版本库：子项目历史 Git 元数据、Git worktree、缓存、临时日志和本地测试输出。子项目原有 Git 元数据已保存在各自的 `.git-nested-backup/` 目录中，并由根目录规则忽略，便于需要时恢复。

## 迁移状态

- 执行计划：`docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`；旧的 `docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md` 已被取代，仅作历史参考。
- 当前阶段：Task 5 已完成 `lore/research/`、`lore/wiki/`，Task 6 已完成 `editorial/`、`fortune/app/`、`fortune/server/`、`ai-system/`，Task 7 已完成 `game/` 导入与旧快照删除；剩余 Task 8（边界终验）、Task 9（推送准备）。

## 协作原则

1. 原著事实、分析解读和游戏设计分层保存。
2. 能用 Markdown 和 Git 解决的问题，不提前引入数据库或自研知识引擎。
3. 需要核验时回查本地原始资料，不把读书笔记或 AI 摘要自动升级为原著事实。
4. 新内容先放入对应子目录，再通过父仓库统一提交和审阅。
