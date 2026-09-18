# 《蛊真人》精编项目知识库

本目录是编辑工作时的快速查证入口，内容从 `outlines/`、`notes/`、`index/` 现有资产提炼，不产生新的权威数据。

## 使用规则

- 权威数据源是 `notes/` 下的台账（人物、伏笔、资源、时间线、事实争议）与 `outlines/` 下的纲目；本知识库只做汇总与索引。
- 知识库与资产不同步时，以台账和纲目为准，并在 `05-review-and-open-issues.md` 登记偏差。
- 每完成一批精编（正文、细纲或台账更新），顺带刷新本知识库对应章节。

## 文件索引

| 文件 | 内容 |
| --- | --- |
| [01-project-overview.md](01-project-overview.md) | 项目性质、目录结构、工作流、脚本命令 |
| [02-editorial-rules.md](02-editorial-rules.md) | 编辑规则速查：修改分级、信息释放、证据引用、争议处理 |
| [03-world-lore.md](03-world-lore.md) | 世界观知识：六部结构、力量体系、全书硬设定与 A 级统一项 |
| [04-characters-and-forces.md](04-characters-and-forces.md) | 人物与势力档案：第一部核心人物 + 全书主要势力 |
| [05-review-and-open-issues.md](05-review-and-open-issues.md) | 评审结论、已知问题清单、待核争议（FD）与全书 A 级设定任务 |

## 快速状态

- 进度：第一部《魔性不改》199 节正文精编与逐节细纲全部完成并回修；EPUB（001-199）已按回修重建；第二部已由 vol2-sec001.edited.txt（黄龙江竹筏）开局。
- 规范：`AGENTS.md` 为唯一完整规范源（开工前必读）；卷级裁决入 `notes/vol1-decision-register.md`。
- 台账：5 本基础 CSV + 卷一级专项台账 7 本 + 全书核证登记表 `notes/full-book-audit-register.md`（FB-001~016）。
- 数据源：仓库根目录 `蛊真人.txt`（授权基准源，tracked；CP936/GBK，437060 行；`working/*.cp936.txt` 为本地临时底稿，已 gitignore，91-199 底稿已补齐）。
- 校验命令：`powershell -NoExecutionPolicy Bypass -File scripts/validate_editorial_assets.ps1 -Phase final`（已通过）。

## 变更记录

- 2026-08-08（拉取 b57f821 后）：上游建立 AGENTS.md、卷 1 七本专项台账、FB 核证表、细纲 121-199、正文 121-199 回修与 vol2 开局；本会话完成 R4 编辑说明补写、R6 EPUB 重建与 uid 参数化、R7 修正，并同步本知识库（详见 05 文件）。
