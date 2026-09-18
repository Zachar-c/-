# MIGRATION.md

> Monorepo 迁移来源登记。执行计划：`docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`；设计：`docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md`。

## Baseline

- 设计提交基线：`5f3fbfc6d303ad2885175a896e4218036f99230e`（`docs: define lean monorepo migration design`）。**更正**：此前本节曾误将其标注为 `origin/master`；事实是 `master` / `origin/master` 现为 `072a818`，`5f3fbfc` 只是设计提交，不可作为同步门禁值。
- 迁移分支起点：`master` / `origin/master` = `072a818fa718b80c28d6761bce483ba1e946d9c8`（`docs: add monorepo migration implementation plan`）；迁移分支 `codex/gu-zhenren-monorepo-migration` 自此分出。
- Task 2 提交：`951ec282d55fd583a89238922fbad0446b86a6b6`（`chore: establish monorepo migration controls`）；Task 3 执行时父仓库 `HEAD` 即此值，工作区干净（见 Task 3 Verification Log）。
- 远程基线状态（Task 3 Step 2 以 `git ls-remote` 实测，无漂移，与计划观测短 SHA 一致）：
  - `gu-zu`（`master`）观测 `84b8ce8` → 实测 `84b8ce8090716880e70cdba7ea76488d248f2e1f`
  - Gitee 游戏（`master`）观测 `c982fe9` → 实测 `c982fe9a122dc247f4f84009c8b0b5e9c3dd8243`
  - GitHub `gu-zhenren-editor`（`main`）观测 `dbf6615` → 实测 `dbf6615b1721cae42ef520c3898f9921c0409723`
  - `fortune-app`（`master`）观测 `a039639` → 实测 `a039639df6b55eac177c3b485d50398f63610583`
  - `fortune-server`（`main`）观测 `6a5eed2` → 实测 `6a5eed23fd1185b5cd1ef130b882be71c397a850`
  - `my-ai-production-system`（`main`）观测 `fbe67e2` → 实测 `fbe67e2b16b5d474f3eed463050b319a63da56f9`

## Repository Mapping

| 当前来源 | URL | 来源分支 | 目标目录 | 迁移方式 | 过滤参数 | 阶段提交 |
|---|---|---|---|---|---|---|
| `gu-zu` | `https://github.com/Zachar-c/gu-zu.git` | `master` | `lore/research/` | 过滤历史后 subtree 导入；保留完整资料包 | Task 4：`*蛊真人-clean.txt`、`*《人祖传》.txt`（`--invert-paths`，以前缀由 `git subtree add --prefix` 提供，不用 `--to-subdirectory-filter`） | 待 Task 5 |
| 当前 `wenzhen-lore/` | 父仓库 `5f3fbfc` 快照（本地） | — | `lore/wiki/` | `git mv` 扁平移动；只做机械路径更新 | 不适用（工作树移动；原文候选按 Task 3 清单排除） | 待 Task 5 |
| GitHub `gu-zhenren-editor` | `https://github.com/Zachar-c/gu-zhenren-editor.git` | `main` | `editorial/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| `fortune-app` | `https://github.com/Zachar-c/fortune-app.git` | `master` | `fortune/app/` | 过滤历史后 subtree 导入；不带外层本地包装目录 | 同上 Task 4 过滤组 | 待 Task 6 |
| `fortune-server` | `https://github.com/Zachar-c/fortune-server.git` | `main` | `fortune/server/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| `my-ai-production-system` | `https://github.com/Zachar-c/my-ai-production-system.git` | `main` | `ai-system/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| Gitee 游戏 | `https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git` | `master` | `game/` | 最后过滤历史后 subtree 导入；保留 Godot 工程结构 | 同上 Task 4 过滤组 | 待 Task 7 |

- 历史保留方式：外部仓库先在临时镜像中过滤禁止原文路径，再以不带 `--squash` 的 `git subtree add --prefix` 导入，保留作者、日期和提交历史；临时镜像不进入父仓库。
- 已发布历史不重写：`master` / `origin/master` 不被改写；各阶段提交只落在 `codex/gu-zhenren-monorepo-migration`。
- 回退信息：每阶段提交前均可 `git status --short` 核对；回退即 revert 对应阶段提交，不改写已发布历史。

## Source Namespace Mapping

Wiki 当前 frontmatter 中的 `source:`、`notes:`、`memory:` 是逻辑来源命名空间，不是名为 `source/notes/memory` 的目录。迁移采用以下机械映射（Task 5 执行）：

```text
source:gu-zhenren-editor/...  -> source:source/...
notes:gu-zhenren-editor/...   -> notes:game/...
memory:gu-zhenren-editor/...  -> memory:game/...
notes:gu-zu/...               -> notes:lore/research/...
memory:gu-zu/...              -> memory:lore/research/...
```

- `lore/wiki/source/README.md` 和 `lore/wiki/source/chapter-index.md` 使用新的仓库相对路径 `source/...`、`game/...` 和 `lore/research/...`。
- 完整原文只保留在本地 `source/`；公开克隆校验允许标记为 `LOCAL_ONLY`，本地完整资料校验必须在 `source/` 存在时解析通过。

## Task 3 Audit Record（`951ec28` 上执行，未迁移目录、未导入仓库）

- 临时审计目录：`C:/Users/Zachary/AppData/Local/Temp/gu-zhenren-monorepo-migration-20260918/`（新建；含 `parent-head.txt`、`parent-status.txt`、`remote-baselines.txt`、`local-sources-status.txt`、`wenzhen-lore-sha256.txt`、`original-candidates.txt`、`duplicate-sha256.txt`；不进入 Git 树）。
- 本地来源干净：`C:/Users/Zachary/DevEnv/06_个人项目/fortune-app/fortune-app`（`master`）、`C:/Users/Zachary/DevEnv/06_个人项目/fortune-server`（`main`）、`C:/Users/Zachary/DevEnv/06_个人项目/MyAIProductionSystem`（`main`）及父仓库工作区均无未提交改动。
- Wiki 基线：`wenzhen-lore/` 共 35 个文件，均已生成 SHA-256（清单仅存临时目录，不提交）；`wenzhen-lore/` 内无原文候选。
- 原文候选（只登记，不提交、不复制、不删除）：
  - `gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt`（23,172,557 字节，被根 `.gitignore` 忽略，未被 Git 跟踪）与 `gu-zu/.worktrees/...` 内同名副本 SHA-256 不同 → 登记 REVIEW，Task 7 不得自动二选一覆盖。
  - `gu-zhenren-editor/分支：六卷精编版/《人祖传》.txt`（151,392 字节，忽略、未跟踪）与 `.worktrees/` 内同名副本 SHA-256 不同 → 同上 REVIEW。
  - `.worktrees/` 内 `分支：六卷精编版/` 与 `豆包/` 的两对同名 `.txt` 各自同 SHA（同一份本地副本的两次存放），且整个 `.worktrees/` 被 `gu-zu/.gitignore` 与根 `**/.worktrees/` 规则排除。
  - `git ls-files` 全树无 `蛊真人-clean` / `人祖传` 跟踪记录；`source/` 尚不存在，待 Task 7 按本清单创建。
  - `04-人祖传-隐喻索引.md`（三处，各约 6KB，SHA 互异）是研究派生索引，非完整原文，随资料包正常迁移，不按原文过滤。
- 远程历史：工作树内无嵌套 `.git`、无 gitlink；`.git-nested-backup/`（`gu-zu/`、`gu-zhenren-editor/` 下）为本地恢复材料，已被根规则忽略。`gu-zu` 备份配置含 `gitee` 远程指向 Gitee 游戏 URL——导入时只从 `gu-zu` 镜像单源导入，不另作第三个仓库处理（债务见 `docs/debt.md`）。
- 过滤路径（Task 4 用）：`*蛊真人-clean.txt`、`*《人祖传》.txt`（`--invert-paths`）。

## Task 4 Filtered Mirrors（`0ee9a59` 上执行，未导入仓库、未改工作树结构）

- 任务专用虚拟环境：`C:/Users/Zachary/AppData/Local/Temp/gu-zhenren-monorepo-migration-20260918/venv/`（新建；`py -3 -m venv` 创建，`pip install git-filter-repo` 安装 `git-filter-repo 2.47.0`，`git_filter_repo --version` → `a40bce548d2c`；不修改系统 Python）。
- 镜像根目录：`C:/Users/Zachary/AppData/Local/Temp/gu-zhenren-monorepo-migration-20260918/mirrors/`（新建；六个 `--mirror` 克隆，不在父仓库下生成 `.git` 或 worktree）。
- 执行前复核远程基线：六条 `git ls-remote <url> refs/heads/<ref>` 实测 SHA 与本文件 Baseline 小节完全一致，无漂移；各镜像 `refs/heads/<ref>` tip 与基线逐一比对一致（`gu-zu/master=84b8ce8…f2e1f`、`editorial/main=dbf6615…09723`、`fortune-app/master=a039639…10583`、`fortune-server/main=6a5eed2…7a850`、`ai-system/main=fbe67e2…56f9`、`game/master=c982fe9…d8243`）。
- 过滤前审计（`git -c core.quotePath=false --git-dir=<mirror> log --all --name-only --format=` 去重后全文检索；注：默认 `core.quotePath=true` 会把中文路径输出为八进制转义，直接 grep UTF-8 会漏检，已改用 `quotePath=false` 复核）：
  - `gu-zu.git`：`分支：六卷精编版/蛊真人-clean.txt`、`分支：六卷精编版/《人祖传》.txt`、`豆包/蛊真人-clean.txt`、`豆包/《人祖传》.txt`（4 条完整原文路径，需过滤）；`分支：六卷精编版/记忆库/04-人祖传-隐喻索引.md`、`旧稿归档_不采用/重写稿/记忆库/04-人祖传-隐喻索引.md`（研究派生索引，非完整原文，保留）。
  - `editorial.git`：`蛊真人-clean.txt`（仓库根，1 条，需过滤）；`scripts/clean_full_source.py`、`working/source-clean-candidates.tsv` 为处理脚本与候选清单，非完整原文，保留。
  - `fortune-app.git` / `fortune-server.git` / `ai-system.git`：无 `蛊真人-clean` / `人祖传` 相关路径。
  - `game.git`：`分支：六卷精编版/蛊真人-clean.txt`、`分支：六卷精编版/《人祖传》.txt`（2 条，需过滤）；`分支：六卷精编版/记忆库/04-人祖传-隐喻索引.md`（派生索引，保留）；`docs/superpowers/{plans,reports,specs}/2026-08-2*-novel-to-game-*.md` 为 novel-to-game 设计文档，非完整原文，保留。
  - 无无法判定是否为完整原文的文件，无新增 REVIEW。
- 过滤命令（六个镜像逐一执行，同一组参数，未使用 `--to-subdirectory-filter`，目标前缀由后续 `git subtree add --prefix` 提供）：
  - `<venv>/Scripts/python.exe -m git_filter_repo --force --path-glob '*蛊真人-clean.txt' --path-glob '*《人祖传》.txt' --invert-paths`
  - 解析提交数：`gu-zu` 9、`editorial` 85、`fortune-app` 21、`fortune-server` 1、`ai-system` 1、`game` 749；全部 `exit=0`。
- 过滤后验证（计划 Step 4 原命令的 bash 直译，精确模式 `grep -F -e '蛊真人-clean' -e '《人祖传'`，该模式天然不命中无书名号的派生索引文件名）：
  - 六个镜像 `git log --all --name-only --format=` 检索均无输出（PASS）。
  - 加检 `git rev-list --objects --all | grep -E '蛊真人-clean\.txt|《人祖传》\.txt'` 六个镜像均无输出（PASS）。
  - 派生索引与工具文件保留抽查通过（`gu-zu` 2 条索引、`game` 1 条索引、`editorial` 2 个工具文件仍存在于历史路径清单）。
  - 分支完整性：镜像保留全部远端分支（含 `game` 的 `chore-w11-resolver-split`、`chore/w11-resolver-split`、`master-clean`、`push-master`，`--all` 已覆盖）；过滤后提交计数 `gu-zu=8`（解析 9，1 个提交因仅触及被过滤文件而被清除）、`editorial=85`、`fortune-app=21`、`fortune-server=1`、`ai-system=1`、`game=749`。
- 与计划的偏差：计划 Step 1 预期“安装失败时转入快照导入”，实际安装一次成功，无需替代方案；计划 powershell 代码块均直译为 bash 执行（`py -3 -m venv`、`pip`、`git clone --mirror`、`git log`、`grep`），语义一致；用户指令明确本 Task 不创建 `source/` 副本，未创建。

## Verification Log

- Task 2（本提交）：根边界验证，命令见计划 Task 2 Step 5：
  - `Set-Content -LiteralPath 'source\probe.txt' -Value 'local-only'` → `git check-ignore -v` 命中根 `/source/` 规则 → `Remove-Item` 删除探针。
  - `git diff --check`（根文档无行尾空白）。
  - `git status --short`（只出现本 Task 预期修改）。
  - 输出见 Task 2 worker 报告；本节在后续 Task 追加阶段提交、验证命令、失败原因和回退方式。
- Task 3（审计基线与来源边界；bash 直译执行，无嵌套 powershell）：
  - `git status --short --branch` → 仅 `## codex/gu-zhenren-monorepo-migration`，工作区干净；`git rev-parse HEAD` → `951ec28…`；`master` / `origin/master` → `072a818…`；`git log --oneline --decorate -5` 确认 `5f3fbfc` 为设计提交。
  - 六条 `git ls-remote <url> refs/heads/<ref>` 全部解析成功，短 SHA 与计划观测值一致（全文见本文件 Baseline）。
  - 三个本地来源 `git status --short --branch` 均仅输出分支头（`master` / `main` / `main`），无改动。
  - `find wenzhen-lore -type f | sort` + `sha256sum` → 35 行清单存临时目录。
  - `find gu-zhenren-editor gu-zu -type f ( -name '*蛊真人-clean*' -o -name '*人祖传*' )` → 11 条候选；`git ls-files | grep -E '蛊真人-clean|人祖传'` → 无输出（Git 树无原文）；`git check-ignore -v` 确认两处正文被忽略。
  - `sha256sum` 六份正文：游戏侧与 `.worktrees/` 副本 SHA 互异（REVIEW），`.worktrees/` 内两对同名副本各自同 SHA。
  - `git diff --check`（本次文档修改无行尾空白，提交前复核）。
- Task 4（过滤镜像；bash 直译执行，详见本文件 Task 4 Filtered Mirrors 小节）：
  - Step 1：`py -3 -m venv` 新建任务专用 venv，`pip install git-filter-repo`（2.47.0）一次成功。
  - Step 2：六个 `git clone --mirror` 成功；执行前 `git ls-remote` 六基线无漂移，镜像分支 tip 与基线逐一一致。
  - Step 3：`quotePath=false` 下审计出 7 条完整原文历史路径（`gu-zu` 4、`editorial` 1、`game` 2），同一组 `--invert-paths` 过滤全部 `exit=0`；派生索引与工具文件保留，无 REVIEW。
  - Step 4：精确模式 `log --all --name-only` 六镜像均无输出，`rev-list --objects --all` 加检均无输出。
  - Step 5：`git diff --check` 通过，`git status --short` 仅 `MIGRATION.md` 一处修改，随后独立提交。
