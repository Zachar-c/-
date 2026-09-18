# 债务清单

> 格式：`路径 | 类型 | 现状 | 处理 | 权威/理由`。类型只使用 `KEEP`、`MOVE`、`MERGE`、`ARCHIVE`、`EXCLUDE`、`REVIEW`。本文件只记录债务，不做管理系统。

| 路径 | 类型 | 现状 | 处理 | 权威/理由 |
|---|---|---|---|---|
| `gu-zu/`（旧根目录入口） | MOVE | 当前快照仍在旧根目录，职责应为目标 `lore/research/` | Task 5 以过滤后 subtree 导入 `lore/research/`，核对后 `git rm` 旧快照受版本内容 | 计划 Target Mapping：完整资料包进入 `lore/research/` |
| `wenzhen-lore/`（旧根目录入口） | MOVE | 当前 Wiki 快照仍在旧根目录，职责应为目标 `lore/wiki/` | Task 5 以 `git mv` 扁平迁移到 `lore/wiki/`，只做机械路径更新 | 计划 Target Mapping；设计 Wiki 冻结边界 |
| `gu-zhenren-editor/`（当前 Gitee 游戏工程快照） | MOVE | 当前游戏快照仍在旧根目录，职责应为目标 `game/`；不要与 GitHub 同名 `editorial/` 来源混淆 | Task 7 最后以过滤后 subtree 导入 `game/`，核对后删除旧快照受版本内容 | 计划 Target Mapping：最后迁移 Godot `game/` |
| `wenzhen-lore/source/README.md` 的旧相对路径 | MOVE | 仍引用 `wenzhen-lore/wiki/...`、`gu-zhenren-editor/...`、`gu-zu/...` 等旧仓库相对路径 | Task 5 按 Source Namespace Mapping 机械替换为 `source/...`、`game/...`、`lore/research/...` | `MIGRATION.md` Source Namespace Mapping |
| `wenzhen-lore/source/chapter-index.md` 的旧相对路径 | MOVE | 同上，章节索引仍使用旧仓库相对路径 | Task 5 同步机械替换为新仓库相对路径 | `MIGRATION.md` Source Namespace Mapping |
| 完整原文候选（`蛊真人-clean.txt`、`《人祖传》.txt` 及同义改名） | EXCLUDE | 工作树与远程历史中存在完整原文候选；公开树不得包含 | Task 3 审计全部候选去向，Task 4 以 `git-filter-repo --invert-paths` 从导入历史过滤；本地只保留一份 `source/` 副本 | `CONSTRAINTS-V2` §2：不复制原著正文（法律边界）；计划 Global Constraints |
| `**/.git-nested-backup/` | EXCLUDE | 子项目历史 Git 元数据的本地备份 | 保留在本地作恢复材料；不进入 Git 树（根规则已忽略） | 计划 Global Constraints：远程 `.git` 不进入 Monorepo |
| `**/.worktrees/` | EXCLUDE | 本地工作副本 | 保留在本地；不进入 Git 树（根规则已忽略） | 计划 Global Constraints：worktree 不进入 Monorepo |
| `map_test_result.txt`、`**/*.bak-*`、`**/gate_sabotage.log`、`**/generated/_shortlist_spec.txt`、`tools/_*.txt` | EXCLUDE | 本地测试输出、备份、调试日志与生成短名单 | 已被根 `.gitignore` 排除；不提交 | 计划 Task 2 Step 1：保留现有忽略规则 |
| `gu-zhenren-editor/opencode.json`（迁移后为 `game/opencode.json`）中的机器绝对路径 | REVIEW | Godot MCP 配置包含另一台机器的绝对路径 | Task 7 登记为 REVIEW，不为迁移擅自替换 MCP 配置；仅作历史配置参考 | 计划 Worker Contract：迁移不依赖该 MCP |
| `gu-zu` 中名为 `gitee` 的远程指向编辑器项目 | REVIEW | 同一份上游被两个本地来源引用，存在重复导入风险 | Task 3 登记 REVIEW，不作为第三个资料仓库重复导入 | 旧计划 Remote baseline 记录；待 Task 3 复核 |
| 多副本原文 SHA-256 未比对 | REVIEW | 相同文件名但内容是否一致未知，不得自动合并或覆盖 | Task 3 以 `Get-FileHash -Algorithm SHA256` 比对；不同 SHA 一律 REVIEW | 计划 Worker Contract 行为契约 5 |
| `docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md` | ARCHIVE | 主张“保留旧根目录结构”的旧迁移计划，已被本计划取代 | Task 2 仅加历史说明头指向本计划，不再执行其方案 | 计划 Task 2 Step 4 |
| `docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md` | KEEP | 当前迁移设计依据（v1.0，待审阅） | 作为 Task 2—8 的边界依据保留 | 设计 §1—§10 |
| `game/docs/contracts/2026-09-12-agent-ownership-contract.md`（迁移后路径） | ARCHIVE | 已被 `CONSTRAINTS-V2` 明确作废的旧协作契约 | 保留作历史参考，不作为执行契约 | `CONSTRAINTS-V2` §1 F 组；计划 Global Constraints |
