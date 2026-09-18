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
| `gu-zu` | `https://github.com/Zachar-c/gu-zu.git` | `master` | `lore/research/` | 过滤历史后 subtree 导入；保留完整资料包 | Task 4：`*蛊真人-clean.txt`、`*《人祖传》.txt`（`--invert-paths`，以前缀由 `git subtree add --prefix` 提供，不用 `--to-subdirectory-filter`） | Task 5：导入 `072aa6e` + 本次冻结提交（见 Task 5 小节） |
| 当前 `wenzhen-lore/` | 父仓库 `5f3fbfc` 快照（本地） | — | `lore/wiki/` | `git mv` 扁平移动；只做机械路径更新 | 不适用（工作树移动；原文候选按 Task 3 清单排除） | Task 5：本次冻结提交（见 Task 5 小节） |
| GitHub `gu-zhenren-editor` | `https://github.com/Zachar-c/gu-zhenren-editor.git` | `main` | `editorial/` | 过滤历史后 subtree 导入 | Task 6 修正组：仅 `蛊真人.txt`（Task 4 组漏检，见 Task 6 小节） | Task 6：导入 `0cbce85`（83 提交） |
| `fortune-app` | `https://github.com/Zachar-c/fortune-app.git` | `master` | `fortune/app/` | 过滤历史后 subtree 导入；不带外层本地包装目录 | 同上 Task 4 过滤组 | Task 6：导入 `6603115`（21 提交） |
| `fortune-server` | `https://github.com/Zachar-c/fortune-server.git` | `main` | `fortune/server/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | Task 6：导入 `0240567`（1 提交） |
| `my-ai-production-system` | `https://github.com/Zachar-c/my-ai-production-system.git` | `main` | `ai-system/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | Task 6：导入 `479145d`（1 提交） |
| Gitee 游戏 | `https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git` | `master` | `game/` | 最后过滤历史后 subtree 导入；保留 Godot 工程结构 | 同上 Task 4 过滤组 | Task 7：导入 `ebb7f81`（744 提交、1904 文件）+ 本地带过提交 `db34873`（`game/wenzhen-web/` 10 文件） |

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

## Task 5 Research Import + Frozen Wiki（`6b88b1f` 上执行，bash 直译）

- Step 1（subtree 导入）：`git subtree add --prefix='lore/research' <mirrors/gu-zu.git> master -m 'chore: import gu-zu into lore research'` → `072aa6e`。第二父提交 `724a372`（过滤后 `gu-zu` 镜像 tip），8 个历史提交完整保留，未使用 `--squash`；`git ls-files -- lore/research` 共 206 个文件；`git log 072aa6e^2 -- README.md` 可追溯。
- Step 2（快照对比）：`gu-zu/`（206）与 `lore/research/`（206）受版本文件清单逐行 `diff` 一致；`git show HEAD:gu-zu/<p>` 与 `git show 072aa6e:lore/research/<p>` 逐文件 `cmp`，206/206 blob 一致。工作树直接 `cmp` 有 196 处差异，经 `xxd` 取证全部是换行符差异（旧快照工作树 LF，新检出受 `core.autocrlf=true` 为 CRLF；`tr -d '\r'` 后一致），无内容分歧，符合“一致则删除旧快照”条件。`git rm -r -- gu-zu` 删除 206 个受版本文件；仅删除真正为空的子目录（`find -empty -delete`，排除 backup/worktrees 路径），保留 `gu-zu/.git-nested-backup/` 与 `gu-zu/.worktrees/`（其下 531 个被忽略文件原样保留，`git ls-files -- gu-zu` 已为 0）。
- Step 3（扁平移动）：`mkdir -p lore` + 6 条 `git mv`（`wiki`、`AGENTS.md`、`README.md`、`index.md`、`log.md`、`source`）。`lore/wiki/{characters,gu,events,world,themes}/` 直接落地，无 `lore/wiki/wiki/`；`wenzhen-lore/` 内无被忽略文件，确认后 `rmdir` 移除。
- Step 4（机械替换）：frontmatter 按顺序 `source:gu-zhenren-editor/→source:source/`、`notes:gu-zhenren-editor/→notes:game/`、`memory:gu-zhenren-editor/→memory:game/`、`notes:gu-zu/→notes:lore/research/`、`memory:gu-zu/→memory:lore/research/`；相对链接 `wiki/characters|gu|events|world|themes/→characters|gu|events|world|themes/`（`wenzhen-lore/wiki/` 全树零命中）。`source/README.md` 逐行分类：原文 2 行→`source/...`、游戏整理 3 行→`game/...`、研究 2 行→`lore/research/...`；`chapter-index.md` 读书笔记前缀→`game/...`（11 处，无前缀简写 `D2-...` 不动）；`README.md` 代码块反斜杠路径→`game\...`、来源优先级 3 行→`game/...`；`AGENTS.md` 链接示例→`gu/...`+`` `characters/` ``、`` `gu-zu/` ``→`` `lore/research/` ``、更新方式命令 `-- wenzhen-lore`→`-- lore/wiki`、`notes:` 短 ID 示例按新命名空间补全为真实值（`notes:game/分支：六卷精编版/读书笔记/A2a-00001-15500-补读.md`，与 `fang-yuan.md` 实值一致）。`log.md:12` 是 2026-09-18 当日验收命令的历史记录，有意保留原文（改动日志等于改写历史）。
- Step 5/6（验证，真实输出见 Verification Log 的 Task 5 条目）：旧字符串/PCRE 零输出；229 个相对 `.md` 链接逐个 resolve，0 损坏；Task 3 SHA-256 清单 35/35 与基线 blob 一致，且“旧 blob + 本节替换程序”重建新文件 35/35 字节一致（差异仅来自路径替换与目录移动）；Git 树无禁止原文/嵌套元数据；`source/` 未创建。
- 与计划的偏差：powershell 直译 bash；Task 5 自然产生 2 个提交（subtree 导入 `072aa6e` + 本次冻结提交，均为 `git subtree` 机制与计划 Step 7 所要求）；`AGENTS.md:67` 与 `:14` 的两处更新如上，属“目录移动/来源路径更新”允许范围；`log.md:12` 保留属有意为之（见债务 REVIEW 行：`README.md` 小说正文示例指向 `game/`，而正文最终落地 `source/`，待 Task 7/8 裁定）。

## Task 6 Editorial / Fortune / AI Import（`1d022ac` 上执行，bash 直译）

- 执行基线：Task 5 完成提交 `1d022ac`，工作区干净。
- 第一次尝试（本地提交 `3afe2dd`，未推送）：把 `mirrors/editorial.git` 的 `main` 原样导入 `editorial/`，结果把仓库根 23.5 MB 的完整原文底稿 `蛊真人.txt` 一并带入。发现后停止导入并提交用户裁定，未推送、未继续 Task 7。
- 用户裁定（2026-09-18，原文顺序）：「其实不用排除，去重就行」→「排除成书，保留研究延伸」→「我犯了一个错误，除了蛊真人和人祖传以外的成书都是项目的精编产出，不应该排除」→ 选择方案 1。
  - 最终口径：只排除完整原文 `蛊真人.txt` 与 `《人祖传》.txt`；`volumes/**/*.edited.txt`（24 条精编分节）、`volumes/01-魔性不改/蛊真人-第一部-魔性不改-第001-199节.epub`、`working/archive-2026-08/read-*.txt`（9 条）、`round3-*.txt`（3 条）、`working/*.cp936.txt`（9 条）均属项目精编产出与工作副本，保留。
- 修正动作（重建过滤镜像）：以 `git filter-branch --index-filter` + `--prune-empty`（不重写初始提交）从 `mirrors/editorial.git` 重建工作克隆 `editorial-final`，只删除路径 `蛊真人.txt`；`git rev-list --count` 85 → 83；`refs/original/*` 已清理；`editorial-final` 上 `git log --all --name-only` 与 `git rev-list --objects --all` 均不再出现 `蛊真人.txt`。旧提交 `3afe2dd` 只留在本地 reflog，未推送，本分支以重建后的导入提交取代。
- Step 1（editorial）：`git subtree add --prefix=editorial <editorial-final> main` → `0cbce85`，第二父 `cf2cb48`（83 个历史提交完整保留，无 `--squash`）。`git ls-tree -r` 路径清单 183/183 与 `editorial-final` 一致；`editorial-final` 与 `mirrors/editorial.git` 的路径清单差集恰好只有 `蛊真人.txt`，两侧共有 183 条路径的 blob 183/183 完全一致。`editorial/` 与旧根目录 `gu-zhenren-editor/` 同名但不同项目，后者是 Gitee 游戏快照。
- Step 2（fortune）：`fortune/app` ← `mirrors/fortune-app.git` `master` → `6603115`，第二父 `a039639`（21 提交），36 文件；`fortune/server` ← `mirrors/fortune-server.git` `main` → `0240567`，第二父 `6a5eed2`（1 提交），3 文件。两个前缀的路径清单与各自镜像 tip 逐行一致。
- Step 3（AI system）：`ai-system` ← `mirrors/ai-system.git` `main` → `479145d`，第二父 `fbe67e2`（1 提交），1 文件（`PRD.md`）。路径清单与镜像 tip 一致。
- Step 4（导航与旧路径扫描）：`rg -n --hidden --glob '!**/.git/**' --glob '!**/.git-nested-backup/**' --glob '!**/.godot/**' 'gu-zu/|wenzhen-lore/|gu-zhenren-editor/|fortune-app/fortune-app/' AGENTS.md PROJECT_MAP.md MIGRATION.md README.md docs editorial fortune ai-system` → 导入内容 `editorial/`、`fortune/`、`ai-system/` 零命中；剩余命中只在 `MIGRATION.md`（历史映射与本节）、`docs/debt.md`（债务与裁定）、`docs/superpowers/plans|specs/`（计划与设计自身引用旧路径）。根导航三件套已改为只描述新目标目录，`gu-zhenren-editor/` 仅作为 Task 7 待迁移的当前游戏快照保留说明。
- 工具教训（补记 Task 4 审计缺口）：`git ls-tree` 默认 `core.quotePath=true`，中文路径会输出成八进制转义并用双引号包裹，任何 `\.epub$`、`\.edited\.txt$` 这类行尾锚定 grep 都会整片漏检；本节一律显式加 `-c core.quotePath=false` 复核。Task 4 审计把 `editorial.git` 的原文写成 `蛊真人-clean.txt` 也属同类转写错误，实际路径名是 `蛊真人.txt`。
- 与计划的偏差：计划 Step 1 写的是直接从 `mirrors/editorial.git` 导入，实际改为从重建后的 `editorial-final` 导入（用户裁定后覆盖原文，见上）；`AGENTS.md`、`README.md` 同时做了事实性导航更新，属计划 Task 6 Step 4「导航入口全部使用新目标目录」范围。

## Task 7 Godot Game Import（收尾执行于 `db34873` 上；导入 `ebb7f81` + 带过 `db34873`）

- Step 1（本地 `source/`，前期会话执行，本会话复核）：`source/蛊真人-clean.txt`（23,172,557 字节，SHA-256 `95cd0b13…7647`）、`source/《人祖传》.txt`（151,392 字节，SHA-256 `acc3ec34…d9155`），被根 `.gitignore` 的 `/source/` 规则忽略（`git check-ignore -v` 命中两条）。两份候选剥离 `\r` 后 SHA-256 相同，游戏侧 LF 版本被采用：`.worktrees/` 副本 raw SHA 为 `bf78d414…` / `e6a6a618…`（与 Task 3 记录一致），`tr -d '\r'` 后与 `source/` 双份 SHA 完全一致；`source/` 内零 CR（`grep -c $'\r'` 为 0）。
- Step 2（subtree 导入，前期会话执行）：`git subtree add --prefix='game' <mirrors/game.git> master -m 'chore: import Godot game project'` → `ebb7f81`，第二父为过滤后 `game.git` 镜像 tip（`git rev-list --count ebb7f81^2` = 744，历史提交完整保留，无 `--squash`）；`git -c core.quotePath=false ls-tree -r --name-only ebb7f81 -- game` 共 1904 个文件。完整原文路径已在 Task 4 过滤（`game/` 受版本树内 `分支：六卷精编版/` 下仅 24 个记忆库/读书笔记文件，无正文 txt）。
- Step 3（本地新文件带过，前期会话执行）：本地 `gu-zhenren-editor/wenzhen-web/` 比远程 master 新的 10 个文件，按用户裁定以独立提交 `db34873`（`chore: carry local wenzhen-web work into game`）带进 `game/wenzhen-web/`，逐 blob 与旧快照一致；`game/` 文件数 1904 → 1909（`git show --stat db34873`：10 files changed，含 3 个新增二进制 asset）。
- Step 4（Godot 验证，前期会话执行）：`godot --headless --path game --editor --quit` 成功打开 `game/project.godot`，exit 0。
- Step 5（契约检查，本会话执行）：`git diff -- game/AGENTS.md game/world-model/governance/CONSTRAINTS-V2.md game/docs/contracts` 无输出（exit 0）；`git diff --check -- game` 无输出（exit 0）。游戏契约未被迁移改写。
- Step 6（根忽略规则，本会话执行）：根 `.gitignore` 新增 3 条（保留既有 `gu-zhenren-editor/...` 3 条）：`game/分支：六卷精编版/蛊真人-clean.txt`、`game/分支：六卷精编版/《人祖传》.txt`、`game/tools/_*.txt`；`git diff --check` 通过（仅 autocrlf 换行提示，无空白错误）。
- Step 7（删旧快照并提交，本会话执行）：收尾前 `git -c core.quotePath=false ls-files -- gu-zhenren-editor` = 1758，`-- game` = 1909；`git rm -r -- gu-zhenren-editor`（exit 0）后前者为 0。被忽略的 `.git-nested-backup/`、`.worktrees/`、`.godot/`、两份本地原文 txt（151,392 / 23,172,557 字节，与 Task 3 一致）、10 个 `tmp*/` 目录均保留在磁盘。文档更新（本文件、`PROJECT_MAP.md`、`docs/debt.md`、`README.md`）后以 `chore: import Godot game as final monorepo project` 提交；未推送。
- 与计划的偏差：
  1. Step 3 不是纯 subtree：本地超前文件以独立提交 `db34873` 带过（用户裁定），`game/` 内容 = 过滤后远程历史 + 10 个本地文件。
  2. `game/tools/_*.txt`（`game/tools/` 下 10 个）随导入历史已在 Git 树内，原样保留（KEEP，见 `docs/debt.md`）；新增根忽略只阻止未来新增，不改写历史。
  3. 旧快照自带的嵌套 `.gitignore`（含 `.godot/`、`.workbuddy/`、`.zcode/` 等规则）随 `git rm` 离开 Git 树后，残留本地缓存显示为 `?? gu-zhenren-editor/`（约 4500 个未跟踪文件，全在 `.godot/`、`.workbuddy/` 等本地工具目录内）；收尾提交改用精确路径 `git add`（`.gitignore` + 四个文档，已暂存的 1758 个删除不受影响），未使用 `git add -A`，未把缓存带入提交。Task 8 可视需要补根忽略规则或保留现状。

## Task 8 Final Acceptance（执行于 `6c087c2` 上；`docs: finalize monorepo map and migration debt` 待提交）

- Step 0（残留忽略，前置）：根 `.gitignore` 末尾新增一节 `/gu-zhenren-editor/` 整目录忽略（既有 `分支：六卷精编版/...` 2 条与 `tools/_*.txt` 保留）。`git status --short --branch` 由 `?? gu-zhenren-editor/` 变为仅 `M .gitignore`；`git ls-files -- gu-zhenren-editor` 为 0；`git check-ignore -v gu-zhenren-editor/` 命中新规则；`git diff --check` 通过（仅 autocrlf 提示）。
- Step 1（目标树/旧路径）：12 个期望路径全部存在；`git ls-files -- gu-zu / wenzhen-lore / gu-zhenren-editor` 均为 0；`source/` 存在并被 `/source/` 忽略（内含 `蛊真人-clean.txt`、`《人祖传》.txt`）。
- Step 2（Git 树边界）：嵌套元数据扫描、原文名扫描、缓存扫描均无输出（grep rc=1）；`git diff --check` 通过；`git -c core.quotePath=false rev-list --objects --all | grep -E '蛊真人-clean\.txt|《人祖传》\.txt'` 无输出。注：`editorial/蛊真人.txt` 的首次误导入提交 `3afe2dd` 只在本地 reflog，不在任何 ref 可达历史内（`--all` 已覆盖全部 ref）。
- Step 3（Wiki 链接/命名空间）：计划 pwsh 脚本经脚本文件方式执行（内联 `$` 被 bash 转义，语义等价）→ 35 文件、0 损坏；`rg -n -P 'source:(?!source/)|notes:(?!game/|lore/research/)|memory:(?!game/|lore/research/)' lore/wiki` 无输出（rc=1）。
- Step 4（AI 三步导航）：`AGENTS.md`→`PROJECT_MAP.md` 可达；9 个目标目录首读文件全部存在（逐项 `ls` 通过）；`README.md` 只作历史陈述、`MIGRATION.md` 只作历史映射、旧计划已有取代头，均不把旧根目录当当前入口。发现 `AGENTS.md` 当前阶段行仍写 Task 7 未做（过期），已更新为 Task 7 完成 + 残留说明（导航类机械修正）。
- Step 5（债务汇总）：`docs/debt.md` 逐行复核——全部行均有处理结论；`Task 4 审计模式缺口` 与 `lore/wiki/README.md 正文示例` 两行 REVIEW 本 Task 闭合（见下）；其余 REVIEW 行保留并有明确理由（`game/opencode.json`、`origin` URL 待用户、`editorial` 精编切片水印待用户复核、`gitee` 远程已确认为单源）；新增 `旧路径本地残留` EXCLUDE 行。
  - 审计缺口闭合证据（均 `-c core.quotePath=false`）：`rev-list --objects --all` 中 `clean\|人祖传` 仅命中工具脚本与两处派生索引；`.epub` 仅命中 `editorial/` 精编产出与构建脚本（用户裁定 KEEP），`game` 历史零 `.epub`；`verify-pack` 最大 blob 151,477 字节（包总量 549,587 字节；另有 49 个零散对象共 71 KB），23 MB 原文无藏匿可能。
  - README 裁定：`game/分支：六卷精编版/蛊真人-clean.txt` 在树与盘上均不存在（Task 4 过滤 + Task 7 只放 `source/`），属悬空引用；按 Source Namespace Mapping「原文→`source/`」机械修正 `lore/wiki/README.md` 3 行指向 `source/…`（读书笔记行与 `game/docs/lore/canon-index.md` 行经核对存在，未动）。
- Step 6（可定位性）：旧路径引用只出现在 `MIGRATION.md` 历史记录、`docs/debt.md` 与计划/归档旧文档及 `game/` 内随历史导入的产品文档中（后者原样保留，不改写产品文档）；根导航三件套均不把旧路径当当前入口。`git status` 另有 9 个 `?? game/wenzhen-web/assets/*.import`（本地 Godot 生成，见下），故非全干净。
- 失败与回退：本 Task 内零失败；`AGENTS.md`/`lore/wiki/README.md` 若需回退即 revert 本次提交，不影响 Task 2—7 历史。
- Task 9 收口（用户 2026-09-18 裁定四项全部认可）：9 个 `game/wenzhen-web/assets/*.import` 入库（提交 `1d8a7b3`），`docs/debt.md` 对应行由 REVIEW 改 KEEP；`game/opencode.json` 机器绝对路径保留 REVIEW（不改 MCP 配置）；`editorial/working/` 水印切片维持 KEEP（用户既有裁定）。推送 `codex/gu-zhenren-monorepo-migration` → `origin` 由协调方在验收后执行。
- 新增 REVIEW（`docs/debt.md`）：9 个 `game/wenzhen-web/assets/*.import` 未跟踪——`db34873` 本地 asset 缺侧车文件，本地编辑器运行后生成；全树惯例跟踪 `.import`（221 个），Task 8 不加宽泛忽略、不删除、不代提交，交用户在 Task 9 前裁定。
- 独立复核（协调方，2026-09-18 于 `a3bcc99`）：三个旧根 `git ls-files` 均为 0；嵌套元数据 / 原文名 / 缓存三类扫描 0 命中；`rev-list --objects --all` 无禁止原文；`lore/wiki` 35 个 Markdown 文件相对链接 0 断链；命名空间正则 `source:(?!source/)|notes:(?!game/|lore/research/)|memory:(?!game/|lore/research/)` 0 命中；`git diff --check` 干净。以上均独立复现本小节结论。

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
- Task 5（导入 `lore/research/` + 冻结 `lore/wiki/`；bash 直译执行，详见本文件 Task 5 小节）：
  - Step 1：`git subtree add --prefix='lore/research' <mirrors/gu-zu.git> master` → `072aa6e`（第二父 `724a372`，8 提交保留，无 `--squash`）。
  - Step 2：清单 `diff` 206/206 一致，blob 级 `cmp` 206/206 一致；工作树 196 处差异经 `xxd`/`tr -d '\r'` 取证全系 CRLF 换行符 artifact；`git rm -r -- gu-zu` 后 `git ls-files -- gu-zu` 为 0，仅删真正空目录，`.git-nested-backup/`、`.worktrees/` 原样保留。
  - Step 3：6 条 `git mv` 扁平落地 `lore/wiki/`，无 `lore/wiki/wiki/`；空 `wenzhen-lore/` 经 `find`+`git status --ignored` 确认后 `rmdir`。
  - Step 4：frontmatter 五规则按顺序全局替换；`wiki/` 五前缀替换；`source/README.md`、`chapter-index.md`、`README.md`、`AGENTS.md` 逐项分类替换（`log.md:12` 历史记录保留）。
  - Step 5/6：`grep -rn 'wenzhen-lore/\|gu-zhenren-editor/\|gu-zu/' lore/wiki` 无输出（rc=1）；`grep -rnP 'source:(?!source/)|notes:(?!game/|lore/research/)|memory:(?!game/|lore/research/)' lore/wiki` 无输出（rc=1；中途唯一的 1 处命中 `AGENTS.md:14` 短 ID 示例已按命名空间补全为真实值后重跑通过）；venv Python 逐个 resolve 35 文件 229 个相对 `.md` 链接，0 损坏；Task 3 `wenzhen-lore-sha256.txt` 35/35 与 `HEAD` blob 一致，“旧 blob + 替换程序”重建 35/35 字节一致；`git ls-files | grep -E '蛊真人-clean\.txt|《人祖传》\.txt'` 无输出，嵌套元数据扫描无输出，`source/` 未创建；`git diff --check` 通过（仅 autocrlf 提示，无空白错误）。
- Task 6（导入 `editorial/`、`fortune/app/`、`fortune/server/`、`ai-system/`；bash 直译；详见本文件 Task 6 小节）：
  - `git status --short --branch` → 干净；起点 `git rev-parse HEAD` → `1d022ac`；随后依次产生 `0cbce85`（editorial）、`6603115`（fortune/app）、`0240567`（fortune/server）、`479145d`（ai-system）四个 subtree 导入提交，均无 `--squash`。
  - 路径清单一致性：`git -c core.quotePath=false ls-tree -r --name-only HEAD -- <prefix>` 去掉前缀后与各镜像 `refs/heads/<ref>` 逐行一致（editorial 183、fortune/app 36、fortune/server 3、ai-system 1）。
  - `editorial-final` 对照 `mirrors/editorial.git`：路径差集仅 `蛊真人.txt`；共有 183 条路径 blob 183/183 完全一致；提交数 83（镜像 85，被裁掉的两条只触及被过滤文件）。
  - 边界复核：`git -c core.quotePath=false ls-tree -r --name-only HEAD -- editorial` 不含 `蛊真人.txt`；`git log --oneline --all -- editorial/蛊真人.txt` 无输出；`editorial-final` 的 `rev-list --objects --all` 无该路径。
  - Step 4 旧路径扫描：`rg … 'gu-zu/|wenzhen-lore/|gu-zhenren-editor/|fortune-app/fortune-app/'` 在 `editorial/`、`fortune/`、`ai-system/` 零命中；剩余命中仅在 `MIGRATION.md`、`docs/debt.md` 与 `docs/superpowers/{plans,specs}/`（自身引用旧路径）。
  - `git diff --check` 通过（仅 autocrlf 提示，无空白错误）。
- Task 7（导入 `game/` 并删除旧快照；bash 执行，详见本文件 Task 7 Godot Game Import 小节）：
  - Step 1：`source/` 双份 SHA 与游戏侧一致（`95cd0b13…` / `acc3ec34…`），零 CR；`.worktrees/` 副本剥离 `\r` 后一致，游戏侧 LF 版本被采用；`git check-ignore -v source/*` 命中根 `/source/` 规则。
  - Step 2：`git subtree add --prefix='game' <mirrors/game.git> master` → `ebb7f81`（第二父 744 提交，无 `--squash`；`game/` 1904 文件）。
  - Step 3：本地 `wenzhen-web/` 10 文件以独立提交 `db34873` 带进 `game/wenzhen-web/`（用户裁定，逐 blob 一致）；`game/` 1904 → 1909 文件。
  - Step 4：`godot --headless --path game --editor --quit`，exit 0（前期会话）。
  - Step 5：`git diff -- game/AGENTS.md game/world-model/governance/CONSTRAINTS-V2.md game/docs/contracts` 无输出（exit 0）；`git diff --check -- game` 无输出（exit 0）。
  - Step 6：根 `.gitignore` +3 行（`game/分支…` 2 条 + `game/tools/_*.txt` 1 条），旧 `gu-zhenren-editor/...` 3 条保留；`git diff --check` 通过。
  - Step 7：`ls-files` 计数 `gu-zhenren-editor=1758`、`game=1909`；`git rm -r -- gu-zhenren-editor`（exit 0）后前者为 0；五类本地受保护路径磁盘保留；`game/opencode.json` 含另一台机器绝对路径（`C:/Users/90877/...`）已登记 REVIEW；精确路径 `git add`（未用 `git add -A`，残留本地缓存未入提交）。
  - 偏差：Step 3 独立带过提交 `db34873`（用户裁定）；`game/tools/_*.txt` 为随历史入库的既有内容（KEEP）；嵌套 `.gitignore` 离开后残留显示为 `??`（见 Task 7 小节偏差 3）。
  - Step 4（Godot 入口与测试；2026-09-18 由协调方在 `a3bcc99` 上补跑，原 Task 7 未执行）：`game/tools/test.ps1 -Suite unit`（缓存预热后）exit 0 —— Scripts 216 / Tests 1581 / Passing 1581 / Asserts 52673 / Orphans 2，`SCRIPT ERROR`、`Parse Error`、`Ignoring script`、`Nothing was run` 均 0 条；`game/tools/test.ps1 -Suite integration` exit 0 —— Scripts 12 / Tests 56 / Passing 56 / Asserts 1723。退出期 `WARNING: 8 ObjectDB instances were leaked at exit` 与 `ERROR: 2 resources still in use at exit` 在迁移前基线克隆上逐字重现，非迁移引入。冷缓存首跑不稳定：迁移后首次 `-Suite unit` 返回 rc=1 但 GUT 仍 1581/1581 全过；迁移前基线克隆首次冷缓存 `-Suite unit` 直接崩溃（0xC0000005），单独 `--import` 预热后正常 —— 判定为既有环境/缓存现象，不改产品代码。
  - Step 4 迁移保真度对照（基线 = 镜像 `game.git` 的 master 克隆，1904 文件）：`git ls-tree -r` 逐路径比对 —— 1904 条共有路径中 1899 条 blob 完全一致，5 条为 `db34873` 用户裁定的本地较新 `wenzhen-web` 文件，0 条缺失；`game/` 另多 5 个新文件（同提交新增），1909 = 1904 + 5。`game/AGENTS.md`、`game/world-model/governance/CONSTRAINTS-V2.md`、`game/docs/contracts/`（13 文件）与基线 SHA-256 逐一一致。
- Task 8（完整边界验收；bash + pwsh 脚本文件方式，详见本文件 Task 8 Final Acceptance 小节）：
  - Step 0：根 `.gitignore` +4 行（`/gu-zhenren-editor/` 整目录忽略）；`git status` 不再出现 `??`，`ls-files` 为 0。
  - Step 1：12 路径全存在；三旧路径 `ls-files` 全 0；`source/` 被忽略且含双份原文。
  - Step 2：三扫描 + `rev-list --objects --all` 全无输出；`git diff --check` 通过。`3afe2dd` 不在 ref 可达历史内。
  - Step 3：35 文件 0 损坏；来源命名空间零命中。pwsh 内联改脚本文件执行（语义等价）。
  - Step 4：9 目标首读文件全存在；旧入口引用只剩历史语境；`AGENTS.md` 过期阶段行已更新。
  - Step 5：债务全行有结论；闭合 2 行 REVIEW（审计缺口、README 示例），新增 1 行 EXCLUDE（残留忽略）；`lore/wiki/README.md` 机械修正 3 行 `game/→source/`。
  - Step 6/7：可定位性结论见 Task 8 小节（含 9 个 `.import` 未跟踪的 REVIEW 说明）；显式路径暂存（另加机械修正的 `lore/wiki/README.md`，`README.md`/`PROJECT_MAP.md`/`archive/README.md` 无改动不暂存），未用 `git add -A`。
