# AGENTS.md

> 《蛊真人》Monorepo 根入口。先读 `PROJECT_MAP.md`，再进入一个目标目录。没有理由不扫描全仓。

## 目标

- 把《蛊真人》相关项目统一到一个 Git 仓库：统一数据、上下文和版本边界，各产品保留自己的代码和入口。
- 让 AI 先找到正确入口，再进入正确项目。

## 原则

- 先读地图：`AGENTS.md` → `PROJECT_MAP.md` → 目标目录 `README.md` / `AGENTS.md`。
- 一次只进一个目录；不复制其他项目的完整规则。
- 只做目录迁移、来源路径替换、忽略规则、迁移记录和验证。

## 当前阶段

- Monorepo 迁移已完成：`master` 即当前基线，执行记录见 `MIGRATION.md`，目标目录与来源映射见 `PROJECT_MAP.md`，已知债务见 `docs/debt.md`。
- 已导入目标目录：`lore/research/`、`lore/wiki/`、`editorial/`、`fortune/app/`、`fortune/server/`、`ai-system/`、`game/`；各目录首读文件见 `PROJECT_MAP.md`。
- `gu-zu/`、`wenzhen-lore/`、`gu-zhenren-editor/` 的受版本内容均已删除；旧 `gu-zhenren-editor/` 磁盘残留只有本地恢复材料与缓存（根 `.gitignore` 的 `/gu-zhenren-editor/` 规则已忽略，不进入 Git 树），当前游戏入口为 `game/`。
- 设计依据见 `docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md`；执行计划 `docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md` 是历史记录，不再作为待办清单。

## 禁止事项

- 禁止提交 `source/`：本地原始资料只在本地 `source/`，不进入 Git 树，不推送。
- 禁止提交完整原始小说和《人祖传》全文：只保留本地 `source/` 副本。
- `lore/wiki/` 只做机械迁移：允许目录移动、重命名、相对链接和来源路径更新；禁止补写事实、改写分析、调整主题结论。
- 不改产品逻辑、数据数值、游戏契约或 Wiki 语义。
- 每阶段先运行验收命令，再做独立提交。
- worker 不自动推送；推送只在全部验收通过并经用户确认后执行。
- 禁止 `git reset --hard`、强制覆盖未核对目录；递归移动或删除前先解析并验证绝对路径。
- 发现计划与实际不一致时停止并报告，不自行改架构。
