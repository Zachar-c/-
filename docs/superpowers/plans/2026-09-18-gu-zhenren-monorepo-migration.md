# Gu Zhenren Monorepo Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前《蛊真人》相关项目迁移为个人开发者可维护的单一 Monorepo，保留可审计历史、冻结 Wiki 语义、排除原著正文，并让 AI 能通过根导航进入正确项目。

**Architecture:** 以当前父仓库 5f3fbfc 为不可重写的历史基线；外部 Git 仓库先在临时镜像中清除禁止进入版本库的原文路径，再通过不使用 --squash 的 git subtree 导入目标目录以保留作者、日期和提交历史。现有 gu-zu 完整进入 lore/research/，现有 wenzhen-lore 扁平迁移到 lore/wiki/，当前 Gitee 游戏最后进入 game/；原文只进入被根规则忽略的本地 source/。

**Tech Stack:** Git 2.x、Git LFS 3.7.1（仅用于检查现有对象）、Git subtree、临时 Python 虚拟环境中的 git-filter-repo、PowerShell、ripgrep、Godot 4.7.2、OpenCode CLI 1.18.4。

## Global Constraints

- 个人开发者优先；不新增数据库、RAG、知识图谱、registry、任务队列或复杂 schema。
- gu-zu 首次作为完整资料包进入 lore/research/，不提前拆分研究、设定和游戏设计文件。
- lore/wiki/ 只允许目录移动、文件重命名、相对链接更新和来源路径更新；不得改写事实、分析、主题结论或知识范围。
- 完整原始小说和《人祖传》不进入当前 Git 树，也不进入任何新导入历史；本地原文统一放在被根 .gitignore 排除的 source/。
- 远程仓库的 .git、worktree、缓存、构建产物和临时输出不进入 Monorepo；不删除本地历史备份。
- 不重写父仓库已经发布的 master 历史；不修改产品行为，不以迁移为由修复产品 Bug。
- MIGRATION.md 记录每个来源的 URL、分支、基线提交、目标目录、过滤路径、来源映射和回退信息；docs/debt.md 只记录债务。
- OpenCode worker 使用截图所示的 Union Alpha Free；只有当 opencode models 能解析出唯一的真实 provider/model 标识时才启动 worker，不猜测标识，也不静默替换为其他免费模型。
- worker 必须先读取本计划、设计说明和当前 gu-zhenren-editor/AGENTS.md 及其 active governance contract；Task 2 创建根导航后重新读取 AGENTS.md、PROJECT_MAP.md 和 MIGRATION.md；处理 game/ 时重新读取 game/AGENTS.md 和 game/world-model/governance/CONSTRAINTS-V2.md。game/docs/contracts/2026-09-12-agent-ownership-contract.md 已被项目当前约束明确降级为历史档案，不作为执行契约。
- worker 不自动推送远程；最终推送在所有验收通过并经用户确认后执行。

---

## Target Mapping

执行时把以下映射写入 MIGRATION.md，并以实际抓取到的基线提交为准：

| 当前来源 | 来源分支 | 目标目录 | 迁移方式 |
|---|---|---|---|
| gu-zu / https://github.com/Zachar-c/gu-zu.git | master | lore/research/ | 过滤历史后 subtree 导入；保留完整资料包 |
| 当前 wenzhen-lore/ | 父仓库 5f3fbfc 的快照 | lore/wiki/ | git mv 扁平移动；只做机械路径更新 |
| https://github.com/Zachar-c/gu-zhenren-editor.git | main | editorial/ | 过滤历史后 subtree 导入 |
| https://github.com/Zachar-c/fortune-app.git | master | fortune/app/ | 过滤历史后 subtree 导入 |
| https://github.com/Zachar-c/fortune-server.git | main | fortune/server/ | 过滤历史后 subtree 导入 |
| https://github.com/Zachar-c/my-ai-production-system.git | main | ai-system/ | 过滤历史后 subtree 导入 |
| https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git | master | game/ | 最后过滤历史后 subtree 导入；保留 Godot 工程结构 |

当前已观测的远程基线用于执行前复核：gu-zu=84b8ce8、Gitee 游戏=c982fe9、GitHub gu-zhenren-editor=dbf6615、fortune-app=a039639、fortune-server=6a5eed2、my-ai-production-system=fbe67e2。如果远程在实际执行前变化，必须以重新执行 git ls-remote 得到的提交替换这些值，并把变化写入 MIGRATION.md。

## Source Namespace Mapping

Wiki 当前 frontmatter 中的 source:...、notes:...、memory:... 是逻辑来源命名空间，不是名为 source/notes/memory 的目录。迁移后采用以下机械映射：

~~~text
source:gu-zhenren-editor/...  -> source:source/...
notes:gu-zhenren-editor/...   -> notes:game/...
memory:gu-zhenren-editor/...  -> memory:game/...
notes:gu-zu/...               -> notes:lore/research/...
memory:gu-zu/...              -> memory:lore/research/...
~~~

完整原文的路径只保留在本地 source/，因此公开克隆校验允许标记为 LOCAL_ONLY；本地完整资料校验必须在 source/ 存在时解析通过。lore/wiki/source/README.md 和 lore/wiki/source/chapter-index.md 使用新的仓库相对路径 source/...、game/... 和 lore/research/...。

## Worker Contract

OpenCode worker 从父仓库根目录运行，不从 game/ 的项目级 opencode.json 启动。该文件当前的 Godot MCP 配置包含另一台机器的绝对路径，只能作为历史配置参考；本次迁移不依赖该 MCP。

worker 的固定启动前置文件为（在目录移动前使用旧游戏路径，移动后使用新游戏路径）：

~~~text
docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md
docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md
gu-zhenren-editor/AGENTS.md
gu-zhenren-editor/world-model/governance/CONSTRAINTS-V2.md
AGENTS.md（Task 2 创建后）
PROJECT_MAP.md（Task 2 创建后）
MIGRATION.md（Task 2 创建后）
game/AGENTS.md（Task 7 完成后）
game/world-model/governance/CONSTRAINTS-V2.md（Task 7 完成后）
~~~

worker 的行为契约：

1. 先核对当前阶段、目标目录、基线提交和工作区状态，再执行任何移动或删除。
2. 只做目录迁移、来源路径替换、忽略规则、迁移记录和验证；不得顺手改产品逻辑、数据数值、游戏契约或 Wiki 语义。
3. 任何递归移动、删除或历史过滤前先解析并验证绝对目标路径；禁止 git reset --hard、强制覆盖未核对目录和自动推送。
4. 每个阶段完成后运行该阶段的验收命令，生成独立提交，并报告路径、提交、过滤和剩余债务。
5. 发现来源内容不一致、历史原文无法完整排除、旧路径语义不明或远程基线漂移时停止该阶段并登记 REVIEW，不得自行选择权威版本。

---

### Task 1: 建立 OpenCode worker 前置门禁

**Files:**
- Read: C:/Users/Zachary/.config/opencode/opencode.jsonc
- Read: C:/Users/Zachary/.config/opencode/opencode.json
- Read: C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/AGENTS.md
- Read: C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/world-model/governance/CONSTRAINTS-V2.md
- Read: C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md

**Interfaces:**
- Consumes: OpenCode CLI 1.18.4、截图中的显示名称 Union Alpha Free、当前父仓库 5f3fbfc。
- Produces: 一个唯一的 $workerModel 值和一个确认干净的迁移工作区；模型未解析时不产生任何迁移修改。

- [ ] **Step 1: 验证 OpenCode 和模型目录**

Run from C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren:

~~~powershell
opencode --version
$modelMatches = @(opencode models 2>&1 | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -match '(?i)union.*alpha|alpha.*union' })
if ($modelMatches.Count -ne 1) {
    throw "Union Alpha Free 未解析为唯一 provider/model；当前输出为: $($modelMatches -join ', ')。停止，不得猜测模型或替换免费模型。"
}
$workerModel = $modelMatches[0]
Write-Output "WORKER_MODEL=$workerModel"
~~~

Expected: 输出 WORKER_MODEL=<provider/model>；如果输出为空，先在 OpenCode 中刷新/登录提供该模型的 provider，或由用户提供精确 provider/model，不得进入后续任务。

- [ ] **Step 2: 验证父仓库基线和未提交改动**

~~~powershell
git status --short --branch
git rev-parse HEAD
git rev-parse origin/master
if ((git status --porcelain)) { throw '父仓库存在未提交改动，停止迁移' }
if ((git rev-parse HEAD) -ne (git rev-parse origin/master)) { throw '父仓库未与 origin/master 同步，停止迁移' }
~~~

Expected: 工作区为空，当前分支为 master，两个提交值均为 5f3fbfc6d303ad2885175a896e4218036f99230e。

- [ ] **Step 3: 创建迁移专用分支**

~~~powershell
if (git branch --list 'codex/gu-zhenren-monorepo-migration') { throw '迁移分支已存在，先人工检查其状态' }
git switch -c codex/gu-zhenren-monorepo-migration
~~~

Expected: 当前分支为 codex/gu-zhenren-monorepo-migration，工作树仍干净，master 和 origin/master 不被改写。

- [ ] **Step 4: 以 OpenCode build agent 启动 worker，但只在门禁通过后执行**

~~~powershell
$modelMatches = @(opencode models 2>&1 | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -match '(?i)union.*alpha|alpha.*union' })
if ($modelMatches.Count -ne 1) { throw 'Union Alpha Free 未解析为唯一 provider/model，停止启动 worker' }
$workerModel = $modelMatches[0]
$repoRoot = 'C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren'
$workerPrompt = @'
执行 C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md。
先读取计划、设计说明和当前 gu-zhenren-editor/AGENTS.md 及其 active governance contract；Task 2 创建根导航后重新读取根文档，Task 7 完成后重新读取 game/ 下的同名契约；当前任务是 Monorepo 迁移，不是产品功能开发。
每次只完成一个 Task，先运行该 Task 的前置核验，再修改，再运行验收，再提交；禁止推送。
若发现基线、来源内容、历史过滤或目标路径与计划不一致，停止当前 Task，写入 MIGRATION.md/docs/debt.md 的 REVIEW 记录并报告，不得自行改架构或选择权威版本。
'@
opencode run --dir $repoRoot --agent build --model $workerModel --title 'Gu Zhenren Monorepo Migration' --prompt $workerPrompt
~~~

Expected: worker 在父仓库根目录创建任务会话并遵守本计划；如果 OpenCode 要求模型授权或权限确认，保留确认步骤，不使用未知模型继续。

### Task 2: 建立根导航、迁移记录和公开边界

**Files:**
- Create: AGENTS.md
- Create: PROJECT_MAP.md
- Create: MIGRATION.md
- Create: docs/debt.md
- Create: archive/README.md
- Modify: README.md
- Modify: .gitignore
- Modify: docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md，在文件首部标记其已被本计划取代

**Interfaces:**
- Consumes: docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md 的目标树、边界、债务类型和完成条件。
- Produces: 后续 worker 可独立读取的根规则、目标映射、来源登记、债务格式和原计划弃用标记。

- [ ] **Step 1: 写入根忽略边界**

在 .gitignore 保留现有规则，并增加以下根规则；不删除旧路径规则，直到所有迁移阶段完成：

~~~gitignore
# Local-only source bundle; never stage or push it.
/source/

# Nested repositories and worktrees remain local recovery material.
**/.git-nested-backup/
**/.worktrees/
~~~

同时保留当前原文、map_test_result.txt、备份文件、gate_sabotage.log 和 tools/_*.txt 的现有忽略规则。不要使用宽泛的 *.txt 规则，因为项目中仍有合法脚本夹具和许可证文本。

- [ ] **Step 2: 写入根 AGENTS.md 和 PROJECT_MAP.md**

AGENTS.md 不超过 100 行，只包含：先读 PROJECT_MAP.md、当前迁移阶段、禁止提交 source/ 和原文、Wiki 只做机械迁移、每阶段先验收再提交、worker 不自动推送。

PROJECT_MAP.md 必须列出以下目标目录、首读文件、权威来源和可修改范围：lore/research/、lore/wiki/、editorial/、game/、fortune/app/、fortune/server/、ai-system/、docs/、archive/。对 game/ 明确链接到 game/AGENTS.md 和 game/world-model/governance/CONSTRAINTS-V2.md，并标注旧 Agent Ownership 契约为历史文件。

- [ ] **Step 3: 写入 MIGRATION.md 和 docs/debt.md**

MIGRATION.md 建立四个固定小节：Baseline、Repository Mapping、Source Namespace Mapping、Verification Log。Repository Mapping 使用本计划的 Target Mapping 表，追加实际 URL、分支、基线 SHA、过滤参数、目标目录和阶段提交。

docs/debt.md 使用设计规定的五列格式：

~~~text
路径 | 类型 | 现状 | 处理 | 权威/理由
~~~

首批登记至少包括：旧根目录入口、wenzhen-lore/source/README.md 的旧相对路径、重复原文候选、嵌套 Git 备份、OpenCode 配置中的机器绝对路径、无法自动判定的来源冲突。类型只使用 KEEP、MOVE、MERGE、ARCHIVE、EXCLUDE、REVIEW。

- [ ] **Step 4: 更新根 README 并标记旧计划**

根 README.md 改为指向新目标树，并明确完整原文只在本地 source/；旧的 docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md 只加一段历史说明，指向本计划，不重新执行其中“保留旧根目录结构”的方案。

- [ ] **Step 5: 验证根边界**

~~~powershell
Set-Content -LiteralPath 'source\probe.txt' -Value 'local-only'
git check-ignore -v 'source\probe.txt'
Remove-Item -LiteralPath 'source\probe.txt'
git diff --check
git status --short
~~~

Expected: source\probe.txt 命中根 /source/ 规则；根文档无行尾空白；只出现本 Task 预期修改。

- [ ] **Step 6: Commit**

~~~powershell
git add AGENTS.md PROJECT_MAP.md MIGRATION.md docs/debt.md archive/README.md README.md .gitignore docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md
git commit -m 'chore: establish monorepo migration controls'
~~~

### Task 3: 冻结基线并审计来源、重复内容和远程历史

**Files:**
- Modify: MIGRATION.md
- Modify: docs/debt.md
- Read-only sources: gu-zu/、gu-zhenren-editor/、wenzhen-lore/、C:/Users/Zachary/DevEnv/06_个人项目/fortune-app/fortune-app/、C:/Users/Zachary/DevEnv/06_个人项目/fortune-server/、C:/Users/Zachary/DevEnv/06_个人项目/MyAIProductionSystem/
- Temporary output: C:/Users/Zachary/AppData/Local/Temp/gu-zhenren-monorepo-migration-20260918/

**Interfaces:**
- Consumes: Task 2 的来源登记格式和根忽略规则。
- Produces: 固定远程基线、Wiki 内容哈希清单、原文候选清单、重复文件 SHA-256 比对结果和可回退的临时审计目录。

- [ ] **Step 1: 创建任务专用临时目录并记录父仓库基线**

~~~powershell
$migrationTemp = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918'
if (Test-Path -LiteralPath $migrationTemp) { throw "临时目录已存在，先人工检查: $migrationTemp" }
New-Item -ItemType Directory -Path $migrationTemp | Out-Null
git rev-parse HEAD | Set-Content -LiteralPath (Join-Path $migrationTemp 'parent-head.txt')
git status --short --branch | Set-Content -LiteralPath (Join-Path $migrationTemp 'parent-status.txt')
~~~

Expected: 临时目录是新建的，parent-head.txt 为执行时父仓库提交，工作区仍干净。

- [ ] **Step 2: 抓取并记录所有远程基线**

~~~powershell
$remotes = @{
    'gu-zu' = @{ Url = 'https://github.com/Zachar-c/gu-zu.git'; Ref = 'master' }
    'editorial' = @{ Url = 'https://github.com/Zachar-c/gu-zhenren-editor.git'; Ref = 'main' }
    'fortune-app' = @{ Url = 'https://github.com/Zachar-c/fortune-app.git'; Ref = 'master' }
    'fortune-server' = @{ Url = 'https://github.com/Zachar-c/fortune-server.git'; Ref = 'main' }
    'ai-system' = @{ Url = 'https://github.com/Zachar-c/my-ai-production-system.git'; Ref = 'main' }
    'game' = @{ Url = 'https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git'; Ref = 'master' }
}
foreach ($name in $remotes.Keys) {
    $item = $remotes[$name]
    $sha = (git ls-remote $item.Url "refs/heads/$($item.Ref)" | ForEach-Object { ($_ -split [char]9)[0] })
    if (-not $sha) { throw "无法解析 $name 的 $($item.Url) $($item.Ref)" }
    "$name | $($item.Url) | $($item.Ref) | $sha" | Add-Content -LiteralPath (Join-Path $migrationTemp 'remote-baselines.txt')
}
Get-Content -Raw (Join-Path $migrationTemp 'remote-baselines.txt')
~~~

Expected: 六行唯一的 URL、分支和 SHA；把同样内容追加到 MIGRATION.md 的 Baseline 小节。

- [ ] **Step 3: 检查本地来源工程是否干净**

~~~powershell
git -C 'C:\Users\Zachary\DevEnv\06_个人项目\fortune-app\fortune-app' status --short --branch
git -C 'C:\Users\Zachary\DevEnv\06_个人项目\fortune-server' status --short --branch
git -C 'C:\Users\Zachary\DevEnv\06_个人项目\MyAIProductionSystem' status --short --branch
git status --short --branch
~~~

Expected: 本地副本无未提交改动；如果存在改动，只记录到 REVIEW 并停止复制该来源，不覆盖用户文件。

- [ ] **Step 4: 生成 Wiki 基线清单**

~~~powershell
$wikiManifest = Join-Path $migrationTemp 'wenzhen-lore-sha256.txt'
Get-ChildItem -LiteralPath 'wenzhen-lore' -Recurse -File | Sort-Object FullName | ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    $relative = $_.FullName.Substring((Resolve-Path '.').Path.Length + 1)
    "$hash  $relative"
} | Set-Content -LiteralPath $wikiManifest -Encoding utf8
~~~

Expected: 35 个当前 Wiki 文件都有 SHA-256；清单只用于证明迁移前后内容等价，不提交到公开仓库。

- [ ] **Step 5: 审计当前工作树中的禁止原文候选**

同时对当前工作树执行：

~~~powershell
Get-ChildItem -LiteralPath 'gu-zhenren-editor','gu-zu' -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '蛊真人-clean|《人祖传》' } |
    Select-Object FullName,Length
~~~

Expected: 所有候选都有明确的本地 source/ 去向或 EXCLUDE 处理，不把原文候选复制进目标 Git 目录。

- [ ] **Step 6: 计算重复候选 SHA-256 并登记权威路径**

对相同文件名和内容候选使用 Get-FileHash -Algorithm SHA256；同 SHA 的文件只保留一份本地 source/ 副本，其他来源记录原路径和替代路径；不同 SHA 的文件一律登记 REVIEW，不得自动合并。

- [ ] **Step 7: Commit**

~~~powershell
git add MIGRATION.md docs/debt.md
git commit -m 'docs: record migration baselines and source boundaries'
~~~

### Task 4: 准备过滤镜像并保留远程提交历史

**Files:**
- Temporary repositories: C:/Users/Zachary/AppData/Local/Temp/gu-zhenren-monorepo-migration-20260918/mirrors/
- Modify: MIGRATION.md only after each mirror passes its audit

**Interfaces:**
- Consumes: Task 3 的远程 URL、分支、SHA 和禁止路径清单。
- Produces: 六个不含禁止原文路径的临时 Git 镜像，供无 squash subtree 导入；临时镜像不进入父仓库。

- [ ] **Step 1: 在任务专用虚拟环境安装 git-filter-repo**

~~~powershell
$migrationTemp = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918'
$venv = Join-Path $migrationTemp 'venv'
py -3 -m venv $venv
& (Join-Path $venv 'Scripts\python.exe') -m pip install --disable-pip-version-check git-filter-repo
& (Join-Path $venv 'Scripts\python.exe') -m git_filter_repo --version
~~~

Expected: 过滤工具安装在任务专用目录，不修改系统 Python；如果安装失败，不用未过滤的 git subtree 替代，转入快照导入并在 MIGRATION.md 记录原因。

- [ ] **Step 2: 为每个远程创建临时镜像**

~~~powershell
$migrationTemp = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918'
$mirrorRoot = Join-Path $migrationTemp 'mirrors'
New-Item -ItemType Directory -Path $mirrorRoot | Out-Null
git clone --mirror 'https://github.com/Zachar-c/gu-zu.git' (Join-Path $mirrorRoot 'gu-zu.git')
git clone --mirror 'https://github.com/Zachar-c/gu-zhenren-editor.git' (Join-Path $mirrorRoot 'editorial.git')
git clone --mirror 'https://github.com/Zachar-c/fortune-app.git' (Join-Path $mirrorRoot 'fortune-app.git')
git clone --mirror 'https://github.com/Zachar-c/fortune-server.git' (Join-Path $mirrorRoot 'fortune-server.git')
git clone --mirror 'https://github.com/Zachar-c/my-ai-production-system.git' (Join-Path $mirrorRoot 'ai-system.git')
git clone --mirror 'https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git' (Join-Path $mirrorRoot 'game.git')
~~~

Expected: 六个镜像目录都存在，且没有在父仓库下生成 .git 或 worktree。

- [ ] **Step 3: 审计并移除每个镜像中的所有历史原文路径**

先对每个镜像运行 git log --all --name-only --format=，筛选 蛊真人-clean.txt、 《人祖传》.txt、同义改名和原文目录；把完整清单追加到 MIGRATION.md 的 Filtered Paths。若出现无法判定是否为完整原文的文件，登记 REVIEW 并暂停历史导入。确认清单后，在每个镜像目录中执行同一组过滤：

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
$filterPython = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\venv\Scripts\python.exe'
$filterArgs = @('--force', '--path-glob', '*蛊真人-clean.txt', '--path-glob', '*《人祖传》.txt', '--invert-paths')
foreach ($mirror in Get-ChildItem -LiteralPath $mirrorRoot -Directory) {
    Push-Location $mirror.FullName
    try {
        & $filterPython -m git_filter_repo @filterArgs
    } finally {
        Pop-Location
    }
}
~~~

Expected: 六个镜像过滤后 git log --all --name-only --format= 不再出现完整原文路径；不使用 --to-subdirectory-filter，因为目标前缀由后续 git subtree add --prefix 提供。

- [ ] **Step 4: 验证过滤后的镜像可以导入**

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
foreach ($mirror in Get-ChildItem -LiteralPath $mirrorRoot -Directory) {
    $names = git --git-dir=$mirror.FullName log --all --name-only --format= |
        Select-String -Pattern '蛊真人-clean|《人祖传'
    if ($names) { throw "镜像仍含禁止原文路径: $($mirror.Name)" }
}
~~~

Expected: 六个镜像均无输出；如果任一镜像失败，停止所有 subtree 导入。

- [ ] **Step 5: Commit**

~~~powershell
git add MIGRATION.md
git commit -m 'chore: prepare filtered migration mirrors'
~~~

### Task 5: 导入 lore/research/ 并机械迁移冻结 Wiki

**Files:**
- Create by move: lore/research/ from filtered gu-zu history
- Create by move: lore/wiki/ from wenzhen-lore/
- Delete after verification: old gu-zu/、wenzhen-lore/
- Modify mechanically: lore/wiki/index.md、lore/wiki/README.md、lore/wiki/AGENTS.md、lore/wiki/log.md、lore/wiki/source/README.md、lore/wiki/source/chapter-index.md、lore/wiki/**/*.md
- Modify: MIGRATION.md、docs/debt.md

**Interfaces:**
- Consumes: Task 3 Wiki SHA-256 清单、Task 4 gu-zu 过滤镜像、Source Namespace Mapping。
- Produces: lore/research/ 完整资料包、lore/wiki/ 扁平 Wiki、无语义变更的来源/链接路径和可复核的迁移前后差异。

- [ ] **Step 1: 将过滤后的 gu-zu 历史 subtree 导入 lore/research/**

~~~powershell
$migrationTemp = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918'
git subtree add --prefix='lore/research' (Join-Path $migrationTemp 'mirrors\gu-zu.git') master -m 'chore: import gu-zu into lore research'
~~~

Expected: 新目录包含完整资料包，提交历史可通过 git log --follow -- lore/research/README.md 追溯；不使用 --squash。

- [ ] **Step 2: 对比现有 gu-zu/ 快照和导入结果**

使用 git diff --no-index 比较当前 gu-zu/ 与 lore/research/，忽略已在 Task 3 登记的原文、.worktrees/ 和嵌套 Git 元数据。内容一致时执行 git rm -r -- gu-zu 删除旧快照的受版本控制内容；内容不一致时登记差异并停止，不覆盖任何一侧。被忽略的本地恢复材料不随 git rm 删除。

- [ ] **Step 3: 扁平移动 wenzhen-lore**

~~~powershell
New-Item -ItemType Directory -Path 'lore' -Force | Out-Null
git mv 'wenzhen-lore\wiki' 'lore\wiki'
git mv 'wenzhen-lore\AGENTS.md' 'lore\wiki\AGENTS.md'
git mv 'wenzhen-lore\README.md' 'lore\wiki\README.md'
git mv 'wenzhen-lore\index.md' 'lore\wiki\index.md'
git mv 'wenzhen-lore\log.md' 'lore\wiki\log.md'
git mv 'wenzhen-lore\source' 'lore\wiki\source'
~~~

Expected: lore/wiki/characters/、gu/、events/、world/、themes/ 直接位于 lore/wiki/ 下；不存在 lore/wiki/wiki/ 或残留 wenzhen-lore/。

- [ ] **Step 4: 只做允许的 Wiki 路径替换**

只替换以下精确字符串，不修改正文句子、frontmatter 字段名、事实、分析和主题结论：

~~~text
wenzhen-lore/wiki/ -> lore/wiki/
wiki/characters/   -> characters/
wiki/gu/           -> gu/
wiki/events/       -> events/
wiki/world/        -> world/
wiki/themes/       -> themes/
gu-zhenren-editor/ -> game/
gu-zu/             -> lore/research/
~~~

lore/wiki/source/README.md 的原文行改为 source/...，游戏整理资料改为 game/...，研究资料改为 lore/research/...；lore/wiki/source/chapter-index.md 中的仓库相对路径同样使用 game/... 或 lore/research/...。

- [ ] **Step 5: 验证 Wiki 语义等价和路径完整性**

~~~powershell
rg -n 'wenzhen-lore/|gu-zhenren-editor/|gu-zu/' lore/wiki
rg -n '\]\([^)]*\.md[^)]*\)' lore/wiki
git diff --check
~~~

逐个解析所有相对 .md 链接；对 frontmatter 的 source:、notes:、memory: 按 Source Namespace Mapping 检查。将迁移前 SHA-256 与迁移后内容逐文件比对，允许差异仅来自上述路径替换。source/ 缺失时只在公开模式标记 LOCAL_ONLY，不把它误报成 Wiki 语义变更。

- [ ] **Step 6: 验证后清理旧空目录并登记债务**

删除前先确认旧路径已经没有受版本控制的文件。被根规则忽略的 .git-nested-backup、.worktrees、.godot 或其他本地恢复材料不得删除；它们保留在原目录或移入已登记的本地恢复目录：

~~~powershell
foreach ($old in @('gu-zu','wenzhen-lore')) {
    if (@(git ls-files -- $old).Count -gt 0) { throw "旧路径仍含受版本控制内容: $old" }
    if (Test-Path -LiteralPath $old) {
        $ignored = @(git status --short --ignored -- $old)
        if ($ignored.Count -eq 0) { Remove-Item -LiteralPath $old -Recurse -Force }
    }
}
~~~

将旧路径和有意保留的历史资料写入 docs/debt.md。

- [ ] **Step 7: Commit**

~~~powershell
git add -A
git commit -m 'chore: import research and freeze wiki under lore'
~~~

### Task 6: 导入 editorial、fortune 和 AI system

**Files:**
- Create by subtree: editorial/
- Create by subtree: fortune/app/
- Create by subtree: fortune/server/
- Create by subtree: ai-system/
- Modify: MIGRATION.md、PROJECT_MAP.md、docs/debt.md

**Interfaces:**
- Consumes: Task 4 的过滤镜像和 Task 2 的根导航。
- Produces: 四个独立目标目录，保留各远程仓库的作者/日期/提交历史；不把 fortune-app/ 外层本地包装目录带入。

- [ ] **Step 1: 导入 GitHub gu-zhenren-editor 到 editorial/**

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
git subtree add --prefix='editorial' (Join-Path $mirrorRoot 'editorial.git') main -m 'chore: import editorial project'
~~~

Expected: editorial/ 的根内容来自 GitHub main，不会与当前 Gitee 游戏工程混淆。

- [ ] **Step 2: 导入 fortune 两个远程仓库**

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
git subtree add --prefix='fortune/app' (Join-Path $mirrorRoot 'fortune-app.git') master -m 'chore: import fortune app'
git subtree add --prefix='fortune/server' (Join-Path $mirrorRoot 'fortune-server.git') main -m 'chore: import fortune server'
~~~

Expected: fortune/app/ 和 fortune/server/ 均可从各自远程历史追溯；不复制 C:/Users/Zachary/DevEnv/06_个人项目/fortune-app/ 外层目录。

- [ ] **Step 3: 导入 AI system**

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
git subtree add --prefix='ai-system' (Join-Path $mirrorRoot 'ai-system.git') main -m 'chore: import AI production system'
~~~

Expected: ai-system/PRD.md 等内容存在，远程提交历史可追溯。

- [ ] **Step 4: 更新导航并扫描旧路径**

~~~powershell
rg -n --hidden --glob '!**/.git/**' --glob '!**/.git-nested-backup/**' --glob '!**/.godot/**' 'gu-zu/|wenzhen-lore/|gu-zhenren-editor/|fortune-app/fortune-app/' AGENTS.md PROJECT_MAP.md MIGRATION.md README.md docs editorial fortune ai-system
~~~

Expected: 只剩 MIGRATION.md 的历史映射和明确债务记录；导航入口全部使用新目标目录。

- [ ] **Step 5: Commit**

~~~powershell
git add editorial fortune ai-system PROJECT_MAP.md MIGRATION.md docs/debt.md
git commit -m 'chore: import editorial fortune and AI projects'
~~~

### Task 7: 最后迁移 Godot game 并复核资源边界

**Files:**
- Create by subtree: game/
- Delete after verification: gu-zhenren-editor/
- Modify mechanically if required: game/ 内引用旧仓库根路径的配置/文档
- Modify: .gitignore、MIGRATION.md、PROJECT_MAP.md、docs/debt.md
- Preserve read-only: game/AGENTS.md、game/world-model/governance/CONSTRAINTS-V2.md、game/docs/contracts/**

**Interfaces:**
- Consumes: Task 4 的 Gitee 游戏过滤镜像、当前 gu-zhenren-editor/ 快照、游戏项目的原有验证命令。
- Produces: game/project.godot、脚本、资源、UID 和测试入口均可从新目录定位；不改变 Godot 逻辑和契约内容。

- [ ] **Step 1: 复制本地原文到根 source/ 并验证哈希**

只对 Task 3 已确认的完整原文执行复制；目标路径固定为 source/蛊真人-clean.txt 和 source/《人祖传》.txt。若多个副本 SHA-256 不同，停止并登记 REVIEW，不得覆盖。

- [ ] **Step 2: 导入过滤后的 Gitee 游戏历史**

~~~powershell
$mirrorRoot = 'C:\Users\Zachary\AppData\Local\Temp\gu-zhenren-monorepo-migration-20260918\mirrors'
git subtree add --prefix='game' (Join-Path $mirrorRoot 'game.git') master -m 'chore: import Godot game project'
~~~

Expected: game/ 根目录包含 project.godot、tools/、tests/ 和原有资源目录；历史不含完整原文路径。

- [ ] **Step 3: 比较旧快照和新游戏目录**

对当前 gu-zhenren-editor/ 的受版本控制文件与 game/ 导入树执行差异核对，排除 Task 3 登记的原文和本地生成物。只有完全一致或差异已在 MIGRATION.md 中逐项解释时，才执行 git rm -r -- gu-zhenren-editor 删除旧快照的受版本控制内容；不得用新远程快照覆盖未审计的本地差异。被忽略的本地恢复材料不随 git rm 删除。

- [ ] **Step 4: 验证 Godot 入口和资源路径**

从父仓库根目录运行：

~~~powershell
godot --headless --path game --editor --quit
pwsh -NoProfile -File game\tools\test.ps1 -Suite unit
pwsh -NoProfile -File game\tools\test.ps1 -Suite integration
~~~

Expected: Godot 可打开 game/project.godot；已有 unit/integration 入口可定位并运行。检查 .godot/、导入缓存、构建产物仍被忽略；检查 .uid、res://、project.godot 和场景资源引用没有指向旧根目录。若 Godot 仅因环境缺失失败，记录命令、退出码和环境原因，不修改产品代码。

- [ ] **Step 5: 检查游戏契约没有被迁移改写**

~~~powershell
git diff -- game/AGENTS.md game/world-model/governance/CONSTRAINTS-V2.md game/docs/contracts
git diff --check -- game
~~~

Expected: 只有路径迁移相关文档变更；当前生效的是 CONSTRAINTS-V2.md 的六条可执行约束，旧 Agent Ownership 文件仍是历史参考。

- [ ] **Step 6: 清理旧游戏路径并登记 OpenCode 绝对路径债务**

确认 git ls-files -- gu-zhenren-editor 无输出后，旧路径不得再作为当前入口；被忽略的 .git-nested-backup、.worktrees、.godot 和本地工具输出不得删除，可保留为已登记的本地恢复材料。将 game/opencode.json 仍指向其他机器的 Godot 路径登记为 REVIEW，不为了本次 Monorepo 迁移擅自替换 MCP 配置。

- [ ] **Step 7: Commit**

~~~powershell
git add -A
git commit -m 'chore: import Godot game as final monorepo project'
~~~

### Task 8: 汇总债务并执行完整边界验收

**Files:**
- Modify: AGENTS.md、README.md、PROJECT_MAP.md、MIGRATION.md、docs/debt.md、archive/README.md
- Read-only: lore/wiki/**/*.md、lore/research/、editorial/、game/、fortune/、ai-system/

**Interfaces:**
- Consumes: Task 5--7 的目标树、各阶段提交和验证记录。
- Produces: 可从根目录导航、来源边界可审计、Wiki 机械等价、Git 树无禁止内容、各项目入口可定位的最终迁移状态。

- [ ] **Step 1: 验证目标根目录和旧路径消失**

~~~powershell
$expected = @('AGENTS.md','PROJECT_MAP.md','MIGRATION.md','README.md','source','lore','editorial','game','fortune','ai-system','docs','archive')
foreach ($name in $expected) { if (-not (Test-Path -LiteralPath $name)) { throw "缺少目标路径: $name" } }
foreach ($old in @('gu-zu','wenzhen-lore','gu-zhenren-editor')) { if (@(git ls-files -- $old).Count -gt 0) { throw "旧路径仍存在于 Git 树: $old" } }
~~~

Expected: 目标树存在，三个旧根目录不存在；本地 source/ 可以存在但必须被忽略。

- [ ] **Step 2: 验证 Git 树边界**

~~~powershell
git ls-files | Select-String -Pattern '(^|/)(\.git|\.git-nested-backup|\.worktrees)(/|$)'
git ls-files | Select-String -Pattern '蛊真人-clean\.txt|《人祖传》\.txt'
git ls-files | Select-String -Pattern '(^|/)(\.godot|__pycache__|map_test_result\.txt|gate_sabotage\.log)(/|$)'
git diff --check
~~~

Expected: 三个路径扫描均无输出，git diff --check 无输出。再用 git rev-list --objects --all 扫描历史对象名，确认禁止原文路径也不在本次导入的历史中。

- [ ] **Step 3: 验证 Markdown 链接和来源命名空间**

从仓库根目录运行以下检查，相对 Markdown 链接必须解析到 lore/wiki/ 中的文件；frontmatter 的 source:、notes:、memory: 必须匹配 Source Namespace Mapping。公开模式允许 source: 目标标记 LOCAL_ONLY；本地模式要求根 source/ 存在时全部可解析。

~~~powershell
$repoRoot = (Resolve-Path '.').Path
$brokenLinks = @()
Get-ChildItem -LiteralPath 'lore/wiki' -Recurse -Filter '*.md' -File | ForEach-Object {
    $file = $_
    $text = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($text, '\]\(([^)#?\s]+\.md)(?:#[^)]*)?\)')) {
        $link = $match.Groups[1].Value
        if ($link -match '^(https?:|mailto:)') { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $link))
        if (-not (Test-Path -LiteralPath $target)) { $brokenLinks += "$($file.FullName): $link" }
    }
}
if ($brokenLinks.Count -gt 0) { $brokenLinks | ForEach-Object { Write-Error $_ }; throw '存在无法解析的 Wiki Markdown 链接' }
if (rg -n -P 'source:(?!source/)|notes:(?!game/|lore/research/)|memory:(?!game/|lore/research/)' lore/wiki) { throw '存在未迁移的 Wiki 来源命名空间' }
~~~

- [ ] **Step 4: 验证 AI 三步导航**

从 AGENTS.md 能到 PROJECT_MAP.md，从 PROJECT_MAP.md 能到每个目标目录的首读 README/AGENTS，且 README.md、旧迁移计划和 MIGRATION.md 不再把旧根目录作为当前入口。

- [ ] **Step 5: 汇总 docs/debt.md 和 MIGRATION.md**

每条已知债务必须有处理结论；有意保留的旧内容标为 ARCHIVE 或 KEEP；未能自动判断的内容保留 REVIEW 和明确理由。MIGRATION.md 追加阶段提交、验证命令、失败原因和回退方式。

- [ ] **Step 6: 运行最终可定位性检查**

~~~powershell
rg -n --hidden --glob '!**/.git/**' --glob '!**/.git-nested-backup/**' --glob '!**/.godot/**' '(gu-zhenren-editor/|gu-zu/|wenzhen-lore/)' AGENTS.md PROJECT_MAP.md MIGRATION.md README.md docs lore editorial game fortune ai-system
git status --short --branch
git log --oneline --decorate -8
~~~

Expected: 旧路径只出现在 MIGRATION.md 的历史记录或 docs/debt.md 的债务记录；工作区只包含本阶段预期文档或已提交状态。

- [ ] **Step 7: Commit**

~~~powershell
git add AGENTS.md README.md PROJECT_MAP.md MIGRATION.md docs/debt.md archive/README.md
git commit -m 'docs: finalize monorepo map and migration debt'
~~~

### Task 9: 交付审阅和推送准备

**Files:**
- Read: Tasks 2--8 创建的全部提交
- No automatic remote write

**Interfaces:**
- Consumes: Task 8 的完整验收结果、OpenCode worker 的阶段报告和所有提交。
- Produces: 待用户确认的分支、审阅摘要和推送命令；不改变远程状态。

- [ ] **Step 1: 生成最终审阅摘要**

~~~powershell
git status --short --branch
git diff --stat origin/master..HEAD
git log --oneline --decorate origin/master..HEAD
~~~

Expected: 所有迁移提交都在当前工作分支，工作区干净；摘要包含目标目录、过滤的原文路径、Wiki 等价结果、Godot 验证结果和剩余 REVIEW 债务。

- [ ] **Step 2: 等待用户确认后再推送**

~~~powershell
git push --set-upstream origin codex/gu-zhenren-monorepo-migration
~~~

只有用户明确确认推送时才运行；不直接推送 master，不强推，不删除远程分支。

---

## Self-Review Checklist

- [ ] 设计说明第 1--2 节的目标、非目标和个人开发者边界已写入 Global Constraints 与 Task 2。
- [ ] 设计说明第 3 节的目标目录和 gu-zu 完整资料包已写入 Target Mapping、Task 5--7。
- [ ] 设计说明第 4 节的三步 AI 导航已写入 Task 2 和 Task 8。
- [ ] 设计说明第 5--6 节的 Wiki 冻结、共享数据流和来源命名空间已写入 Source Namespace Mapping、Task 5 和 Task 8。
- [ ] 设计说明第 7 节的历史保留、原文历史过滤和父历史不重写已写入 Task 3--4。
- [ ] 设计说明第 8 节的六类债务已写入 Task 2、Task 3、Task 8。
- [ ] 设计说明第 9 节的迁移顺序已落实为 research/wiki → editorial/fortune/AI → game。
- [ ] 设计说明第 10 节的完成条件已落实为 Task 8 的边界、链接、导航和入口检查。
- [ ] 计划没有把已废止的 Agent Ownership 契约当作当前约束。
- [ ] 计划没有猜测 Union Alpha Free 的 API 标识，也没有静默替换成其他免费模型。
