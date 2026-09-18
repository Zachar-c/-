# 债务清单

> 格式：`路径 | 类型 | 现状 | 处理 | 权威/理由`。类型只使用 `KEEP`、`MOVE`、`MERGE`、`ARCHIVE`、`EXCLUDE`、`REVIEW`。本文件只记录债务，不做管理系统。

| 路径 | 类型 | 现状 | 处理 | 权威/理由 |
|---|---|---|---|---|
| `gu-zu/`（旧根目录入口） | MOVE | Task 5 已完成：过滤后 subtree 导入 `lore/research/`（`072aa6e`，206 文件，blob 级 206/206 一致）；旧快照 206 个受版本文件已 `git rm`，仅删真正空目录；残留空壳 `gu-zu/` 下只有被忽略的本地恢复材料 | 保留残留 `gu-zu/.git-nested-backup/`、`.worktrees/` 作本地恢复（根规则已忽略，不进入 Git 树）；Task 8 最终验收时复核 | 计划 Target Mapping；Task 5 Verification Log |
| `wenzhen-lore/`（旧根目录入口） | MOVE | Task 5 已完成：35 文件以 `git mv` 扁平迁移到 `lore/wiki/`，只做机械路径更新（旧 blob + 替换程序重建 35/35 字节一致）；旧目录已确认无被忽略文件后 `rmdir` 移除 | 关闭 | 计划 Target Mapping；设计 Wiki 冻结边界 |
| `gu-zhenren-editor/`（当前 Gitee 游戏工程快照） | MOVE | 当前游戏快照仍在旧根目录，职责应为目标 `game/`；不要与 GitHub 同名 `editorial/` 来源混淆 | Task 7 最后以过滤后 subtree 导入 `game/`，核对后删除旧快照受版本内容 | 计划 Target Mapping：最后迁移 Godot `game/` |
| GitHub `gu-zhenren-editor`（与上行同名但不同来源） | MOVE | Task 6 已完成：过滤后 subtree 导入 `editorial/`（`0cbce85`，183 文件、83 提交；`editorial-final` 与 `mirrors/editorial.git` 共有路径 blob 183/183 一致，路径差集只有 `蛊真人.txt`） | 关闭。本行来源是编辑部资料库，上行是 Gitee 游戏快照，两者不可互相覆盖 | 计划 Target Mapping；`MIGRATION.md` Task 6 小节 |
| `fortune/app/`、`fortune/server/`、`ai-system/` | MOVE | Task 6 已完成：三个过滤镜像分别 subtree 导入 `fortune/app`（`6603115`，36 文件、21 提交）、`fortune/server`（`0240567`，3 文件、1 提交）、`ai-system`（`479145d`，1 文件、1 提交）；路径清单与各自镜像 tip 逐行一致；未复制 `fortune-app/fortune-app/` 外层包装目录 | 关闭 | 计划 Target Mapping；`MIGRATION.md` Task 6 小节 |
| `editorial/蛊真人.txt`（仓库根完整原文底稿，23.5 MB） | EXCLUDE | Task 6 首次原样导入时随本地提交 `3afe2dd` 进入本地历史（未推送）；用户裁定后以 `filter-branch` 重建 `editorial-final` 并重新导入，`0cbce85` 及其后历史均不含该路径 | 已闭合于公开边界：当前分支与后续提交不含完整原文。`3afe2dd` 只留本地 reflog；是否需要清理本地悬空对象由用户决定，worker 不自行处理 | 用户 2026-09-18 裁定；根 `AGENTS.md` 禁止事项 |
| `editorial/volumes/**/*.edited.txt`、`editorial/volumes/*/*.epub`、`editorial/working/archive-2026-08/read-*.txt`、`round3-*.txt`、`working/*.cp936.txt` | KEEP | 用户 2026-09-18 裁定：除《蛊真人》《人祖传》原始成书外，其余成书均为本项目精编产出，不应排除；`working/` 内是同一批资料的工作副本 | 保留在 `editorial/`，不再按原文排除。**遗留边界复核点**：`working/read-*`、`round3-*`、`cp936` 是带盗版站水印的原始章段切片，合起来接近完整原文，与根 `AGENTS.md`「禁止提交完整原始小说」存在张力，Task 8 终验时提请用户复核 | 用户 2026-09-18 裁定；根 `AGENTS.md` 禁止事项 |
| Task 4 审计模式缺口（`蛊真人.txt` 精确名、`*.epub`、大 blob、`core.quotePath` 转义） | REVIEW | Task 4 审计只覆盖 `蛊真人-clean\|《人祖传`，且未加 `-c core.quotePath=false`，导致 `editorial.git` 的 `蛊真人.txt` 漏检、路径名还被转写成 `蛊真人-clean.txt`；`fortune/app`、`fortune/server`、`ai-system` 三个镜像已在 Task 6 用补齐模式复检通过 | Task 7 导入 `game` 前必须用补齐模式复检 `game.git`：`-c core.quotePath=false` + 模式含 `蛊真人`、`人祖传`、`epub`，并附大 blob 排名核对 | Task 6 实测；`MIGRATION.md` Task 4 与 Task 6 小节 |
| `wenzhen-lore/source/README.md` 的旧相对路径 | MOVE | Task 5 已按分类机械替换完毕：原文 2 行→`source/...`、游戏整理 3 行→`game/...`、研究 2 行→`lore/research/...` | 关闭 | `MIGRATION.md` Source Namespace Mapping |
| `wenzhen-lore/source/chapter-index.md` 的旧相对路径 | MOVE | Task 5 已替换完毕：读书笔记前缀→`game/...`（11 处），无前缀简写不动 | 关闭 | `MIGRATION.md` Source Namespace Mapping |
| `lore/wiki/README.md` 小说正文示例指向 `game/` | REVIEW | Task 5 按“裸 `gu-zhenren-editor/`→`game/`”机械替换后，来源优先级 1–2 行与 `rg` 代码块示例指向 `game/分支：六卷精编版/...clean.txt`；但完整正文按计划最终落地本地 `source/`（Task 7），`game/` 历史已被过滤不含正文 | Task 7 放置 `source/` 时或 Task 8 终验时裁定这两处示例改指 `source/` 还是保留指向游戏侧整理路径；Task 5 内不做语义裁定 | Task 5 机械替换记录；计划 Task 7 Step 1 |
| 完整原文候选（`蛊真人-clean.txt`、`《人祖传》.txt` 及同义改名） | EXCLUDE | 工作树与远程历史中存在完整原文候选；公开树不得包含。Task 3 已审计：`git ls-files` 全树无跟踪记录；两处正文均被忽略；本地 `source/` 尚不存在 | Task 4 以 `git-filter-repo --invert-paths` 从导入历史过滤；本地只保留一份 `source/` 副本；游戏侧与 `.worktrees/` 副本 SHA 互异，Task 7 不得自动二选一（见 REVIEW 行） | `CONSTRAINTS-V2` §2：不复制原著正文（法律边界）；计划 Global Constraints |
| `**/.git-nested-backup/` | EXCLUDE | 子项目历史 Git 元数据的本地备份 | 保留在本地作恢复材料；不进入 Git 树（根规则已忽略） | 计划 Global Constraints：远程 `.git` 不进入 Monorepo |
| `**/.worktrees/` | EXCLUDE | 本地工作副本 | 保留在本地；不进入 Git 树（根规则已忽略） | 计划 Global Constraints：worktree 不进入 Monorepo |
| `map_test_result.txt`、`**/*.bak-*`、`**/gate_sabotage.log`、`**/generated/_shortlist_spec.txt`、`tools/_*.txt` | EXCLUDE | 本地测试输出、备份、调试日志与生成短名单 | 已被根 `.gitignore` 排除；不提交 | 计划 Task 2 Step 1：保留现有忽略规则 |
| `gu-zhenren-editor/opencode.json`（迁移后为 `game/opencode.json`）中的机器绝对路径 | REVIEW | Godot MCP 配置包含另一台机器的绝对路径 | Task 7 登记为 REVIEW，不为迁移擅自替换 MCP 配置；仅作历史配置参考 | 计划 Worker Contract：迁移不依赖该 MCP |
| `gu-zu` 中名为 `gitee` 的远程指向编辑器项目 | REVIEW | Task 3 已核对本地证据：`gu-zu/.git-nested-backup/config` 含 `[remote "gitee"] url = https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git`；工作树内无嵌套 `.git`，不存在重复导入入口 | Task 5/7 只从各自镜像单源 subtree 导入，不把该远程当作第三个资料仓库；导入前复核镜像来源 URL | 备份配置实测；计划 Target Mapping（单源导入） |
| 多副本原文 SHA-256 未比对 | REVIEW | Task 3 已比对（清单仅存临时审计目录，不提交）：`蛊真人-clean.txt` 游戏侧 `95cd0b13…` ≠ `.worktrees/` 内两份 `bf78d414…`（后两者同 SHA）；`《人祖传》.txt` 游戏侧 `acc3ec34…` ≠ `.worktrees/` 内两份 `e6a6a618…`（后两者同 SHA）；三处 `04-人祖传-隐喻索引.md`（约 6KB 派生索引，非正文）SHA 互异 | 不同 SHA 一律不自动合并、不覆盖；Task 7 复制 `source/` 前若仍多 SHA 并存则停止并登记，由用户指定权威副本 | 计划 Worker Contract 行为契约 5；实测 SHA 见临时 `duplicate-sha256.txt` |
| 父仓库 `origin` URL 形如 `https://github.com/Zachar-c/-.git` | REVIEW | Task 3 实测 `git remote -v` 双方均为该值；本次任务不推送，不影响审计与基线登记 | Task 9 推送前由用户核对远端地址与分支策略；worker 不自动推送、不改远端配置 | 实测输出；计划 Task 9（用户确认后推送） |
| `docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md` | ARCHIVE | 主张“保留旧根目录结构”的旧迁移计划，已被本计划取代 | Task 2 仅加历史说明头指向本计划，不再执行其方案 | 计划 Task 2 Step 4 |
| `docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md` | KEEP | 当前迁移设计依据（v1.0，待审阅） | 作为 Task 2—8 的边界依据保留 | 设计 §1—§10 |
| `game/docs/contracts/2026-09-12-agent-ownership-contract.md`（迁移后路径） | ARCHIVE | 已被 `CONSTRAINTS-V2` 明确作废的旧协作契约 | 保留作历史参考，不作为执行契约 | `CONSTRAINTS-V2` §1 F 组；计划 Global Constraints |
