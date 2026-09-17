# 过期代码、数据、文档归档与项目瘦身 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** 在不误删当前玩法、World Model Stage 0 证据和原始资料的前提下，把本地工作区中的可重建产物、过期工作树、重复素材和历史文档移出项目目录，并建立可复查、可回滚的归档流程。

**Architecture:** 采用“盘点 → 外部归档/哈希 → 隔离观察 → 验证 → 再清理”的两阶段策略。项目目录只保留可运行源代码、当前数据、当前契约和必要素材；归档放在 C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\，按 gu-zhenren-editor、gu-zu、manifests 分层。Git 历史不做重写。

**Tech Stack:** Git 2.x、PowerShell、rg、Godot 4.7.2、现有 GUT/项目验证脚本、SHA-256 文件清单。

## Global Constraints

- 只读原文与设定资料 gu-zhenren-editor/分支：六卷精编版/、gu-zhenren-editor/肉鸽设计-原始数据/、gu-zu/分支：六卷精编版/、gu-zu/豆包/、gu-zu/旧稿归档_不采用/、gu-zu/重写稿/ 在哈希和引用核对前不得删除。
- gu-zhenren-editor/world-model/ 当前是未跟踪的 Stage 0 相关工作，不得按“未跟踪文件”归档或删除。
- 已登记的 gu-zu/.worktrees/codex/nanjiang-smoke-prototype 是活跃工作树；在分支未交付前不得清理。
- 不执行 git reset --hard、git checkout --、git gc --prune=now 或 git filter-repo；本计划只处理工作区和外部归档。
- 第一次处理全部使用 Copy-Item、哈希校验和可逆 Move-Item；观察期结束前不使用 Remove-Item。
- 任何候选项若被 project.godot、场景、脚本、测试、工具脚本或当前契约引用，必须保留或先改引用并通过验证。
- 移动文件只减少工作区占用；当前 gu-zhenren-editor/.git 的 pack 约 349 MB，不通过本计划改变 Git 历史体积。

---

## 现状基线（2026-09-17）

当前主工程是 gu-zhenren-editor，master 工作树有 1877 个已跟踪文件和以下未跟踪项：

- generated/_shortlist_spec.txt
- tests/unit/test_enemy_roll.gd.local-bak
- tools/_tmp_contact_probe.gd
- world-model/ 全目录

资料仓库 gu-zu 有 210 个已跟踪文件，并登记了 codex/nanjiang-smoke-prototype 工作树。

| 路径 | 当前大小 | 初步结论 |
| --- | ---: | --- |
| gu-zhenren-editor/.git.broken-20260916/ | 546.9 MB | 损坏 Git 副本，独立外部归档，禁止与当前 .git 混淆 |
| gu-zhenren-editor/build/ | 256.6 MB | Windows 导出物，可从源码重建 |
| gu-zhenren-editor/.godot/ | 105.9 MB | Godot 导入缓存，可重建 |
| gu-zhenren-editor/.preview/ | 76.8 MB | 预览和输出，可重建 |
| gu-zhenren-editor/.claude/ | 45.3 MB | 含 Agent 工作树，逐项确认后处理 |
| gu-zhenren-editor/.worktrees/ | 25.1 MB | 未出现在当前 Git worktree 列表，逐项检查 |
| gu-zu/.worktrees/ | 60.6 MB | 含已登记活跃工作树，不能整体清理 |
| 重复小说正文 | 每份约 22.5 MB | 先 SHA-256 去重，保留一份 canonical source |

第一轮候选上限约 1.0 GB；实际释放量以工作树状态、哈希结果和验证结果为准。assets 约 152.3 MB、data 约 0.6 MB、world-model、代码和当前文档不作为默认清理对象。

## 归档判定规则

### A 类：验证后可直接外移

- build/、.godot/、.preview/、.pytest_cache/、各类 tmp* 临时目录。
- tools/*.log、docs/q8f/_*.txt 等明确标记为可再生成的运行输出。
- 已完成且无登记 worktree、无未提交改动的历史 Agent/临时工作树。

### B 类：需要人工确认后外移

- .git.broken-20260916/：先检查 refs、LFS 对象和损坏事件报告，再作为恢复用快照归档。
- .claude/worktrees/agent-a38b6deee28736beb/、.worktrees/docs-archive-pass/、.worktrees/vol2-foundation/：确认没有进程或未交付改动后再归档。
- generated/_shortlist_spec.txt、tests/unit/test_enemy_roll.gd.local-bak、tools/_tmp_contact_probe.gd：按 untracked 变更逐项裁定，不能因名字含 _tmp 自动删除。
- docs/q8/、docs/q8f/、docs/q8g/ 和早期 docs/superpowers/reports/：先做引用扫描和状态标注。
- gu-zu 中的资料目录：哈希去重、保留来源说明后再外移重复副本。

### C 类：默认保留

- scripts/、scenes/、ui/、lore_engine/、world-model/、data/、当前 assets/、vendor/。
- AGENTS.md、README.md、当前权威 specs、docs/contracts/、docs/lore/、当前交接和验收报告。
- 原始文本与设定资料的唯一规范副本，以及 vendor/ 的许可证和上游信息。

---

### Task 1: 冻结现状并生成归档清单

**Files:**
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\workspace-status.txt
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\files-sha256.txt
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\candidate-list.tsv

**Interfaces:**
- Consumes: 两个仓库的当前工作树、Git 状态、worktree 列表。
- Produces: 带时间、路径、大小、SHA-256、分类和处理决策的候选清单。

- [ ] **Step 1: 记录 Git 状态和工作树。**

Run:

~~~powershell
git -C gu-zhenren-editor status --short --branch
git -C gu-zhenren-editor worktree list
git -C gu-zu status --short --branch
git -C gu-zu worktree list
~~~

Expected: 明确当前分支、未跟踪项和已登记 worktree；gu-zu/.worktrees/codex/nanjiang-smoke-prototype 被标为 ACTIVE。

- [ ] **Step 2: 生成候选文件清单。**

Run:

~~~powershell
rg --files -g '!**/.git/**' -g '!**/.godot/**' -g '!**/build/**' gu-zhenren-editor gu-zu | Sort-Object | Set-Content 'C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\candidate-list.tsv'
~~~

Expected: 清单覆盖两个仓库的工作区文件，但不把 Git 内部对象和 Godot 导入缓存当作业务源码。

- [ ] **Step 3: 为 A/B 类候选生成 SHA-256 和大小。**

Run:

~~~powershell
$roots=@(
  'gu-zhenren-editor\build',
  'gu-zhenren-editor\.godot',
  'gu-zhenren-editor\.preview',
  'gu-zhenren-editor\.git.broken-20260916',
  'gu-zhenren-editor\.worktrees',
  'gu-zhenren-editor\.claude\worktrees',
  'gu-zhenren-editor\generated\_shortlist_spec.txt',
  'gu-zhenren-editor\tests\unit\test_enemy_roll.gd.local-bak',
  'gu-zhenren-editor\tools\_tmp_contact_probe.gd',
  'gu-zu\.worktrees',
  'gu-zu\豆包',
  'gu-zu\分支：六卷精编版'
)
$files=$roots | ForEach-Object {
  if(Test-Path -LiteralPath $_){
    if((Get-Item -LiteralPath $_).PSIsContainer){Get-ChildItem -LiteralPath $_ -File -Recurse -Force}
    else{Get-Item -LiteralPath $_}
  }
}
$files | Get-FileHash -Algorithm SHA256 | Export-Csv -NoTypeInformation 'C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\files-sha256.txt'
~~~

Expected: 每个候选都有稳定哈希；缺失路径不会被静默当成已归档。

---

### Task 2: 隔离可重建产物并验证主工程

**Files:**
- Move after hash verification: gu-zhenren-editor/build/
- Move after hash verification: gu-zhenren-editor/.godot/
- Move after hash verification: gu-zhenren-editor/.preview/
- Move after hash verification: gu-zhenren-editor/.pytest_cache/ 和明确为空的 tmp* 目录
- Modify: gu-zhenren-editor/.gitignore

**Interfaces:**
- Consumes: Task 1 的哈希清单。
- Produces: 空缓存的可运行工作区和重建验证结果。

- [ ] **Step 1: 确认 Godot 与测试命令可用。**

Run before moving caches:

~~~powershell
godot --version
godot --headless --path gu-zhenren-editor --editor --quit
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite unit
~~~

Expected: Godot 版本为 4.7.x，编辑器无致命错误，unit suite 通过；若失败，停止本批次并保留原目录。

- [ ] **Step 2: 复制 A 类目录到外部归档并复核哈希。**

Run:

~~~powershell
$archive='C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\gu-zhenren-editor\rebuildable'
New-Item -ItemType Directory -Force -Path $archive | Out-Null
Copy-Item -LiteralPath 'gu-zhenren-editor\build' -Destination (Join-Path $archive 'build') -Recurse -Force
Copy-Item -LiteralPath 'gu-zhenren-editor\.godot' -Destination (Join-Path $archive '.godot') -Recurse -Force
Copy-Item -LiteralPath 'gu-zhenren-editor\.preview' -Destination (Join-Path $archive '.preview') -Recurse -Force
~~~

Expected: 外部副本存在，files-sha256.txt 中的哈希与工作区原文件一致。

- [ ] **Step 3: 可逆地移出已复核目录。**

只对复制和哈希检查通过的精确目录执行：

~~~powershell
Move-Item -LiteralPath 'gu-zhenren-editor\build' -Destination $archive -Force
Move-Item -LiteralPath 'gu-zhenren-editor\.godot' -Destination $archive -Force
Move-Item -LiteralPath 'gu-zhenren-editor\.preview' -Destination $archive -Force
~~~

Expected: 项目目录瘦身，外部归档仍可完整恢复；被占用或复制不完整的目录留在原位并记录原因。

- [ ] **Step 4: 重建缓存并回归。**

Run:

~~~powershell
godot --headless --path gu-zhenren-editor --editor --quit
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite unit
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite integration
git -C gu-zhenren-editor status --short
~~~

Expected: Godot 能重建 .godot，unit/integration 通过；没有数据表、场景或脚本被意外修改。

- [ ] **Step 5: 增加精确忽略规则。**

在 gu-zhenren-editor/.gitignore 末尾添加，不能用宽泛的 *.txt 规则覆盖有效资料：

~~~gitignore
# Local recovery and verification leftovers
.git.broken-*/
.codex-verification-temp/
.local-lore-test-temp/
.review-temp/
.review-test-temp/
.tmp-test-env/
tmp*/
*.local-bak
tools/_tmp_*
~~~

Expected: 后续验证临时目录不再出现在 git status，而分支：六卷精编版/、肉鸽设计-原始数据/ 等资料仍可被保留。

---

### Task 3: 处理损坏 Git 副本和未注册历史工作树

**Files:**
- Move after manual approval: gu-zhenren-editor/.git.broken-20260916/
- Move after manual approval: gu-zhenren-editor/.worktrees/docs-archive-pass/
- Move after manual approval: gu-zhenren-editor/.worktrees/vol2-foundation/
- Move after manual approval: gu-zhenren-editor/.claude/worktrees/agent-a38b6deee28736beb/
- Inspect only: gu-zu/.worktrees/codex/nanjiang-smoke-prototype/
- Inspect only: worktree-leftovers-backup/

**Interfaces:**
- Consumes: Task 1 worktree 列表、每个候选目录的 Git 状态和哈希。
- Produces: 恢复快照归档、活跃工作树清单，以及无误删结论。

- [ ] **Step 1: 对未注册目录检查 Git 状态和最近修改。**

Run:

~~~powershell
foreach($p in @(
  'gu-zhenren-editor\.worktrees\docs-archive-pass',
  'gu-zhenren-editor\.worktrees\vol2-foundation',
  'gu-zhenren-editor\.claude\worktrees\agent-a38b6deee28736beb'
)){
  if(Test-Path -LiteralPath $p){
    Write-Output "[$p]"
    git -C $p status --short --branch
    git -C $p log -1 --oneline --decorate
  }
}
~~~

Expected: 只有已交付、无未提交改动且不在任何 git worktree list 中的目录才进入可归档名单。

- [ ] **Step 2: 单独封存 .git.broken-20260916/。**

复制到 C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\gu-zhenren-editor\git-recovery\.git.broken-20260916\，记录 refs、LFS 对象大小和 docs/q8g/GIT_CORRUPTION_INCIDENT_6.md 的关联；不得替换当前 .git，也不得运行 prune。

Expected: 当前 gu-zhenren-editor 的 git status 和 git log 仍正常，恢复副本可独立保留。

- [ ] **Step 3: 归档已确认的未注册工作树。**

按目录逐一执行 Copy-Item、哈希复核和 Move-Item 到 C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\gu-zhenren-editor\worktrees\；发现未提交代码时停止移动并等待人工裁定。

- [ ] **Step 4: 不清理活跃 gu-zu worktree。**

只有在 codex/nanjiang-smoke-prototype 已合并或明确废弃后，才另开批次执行 git -C gu-zu worktree remove；本计划不自动执行该命令。

---

### Task 4: 去重原始数据和文本资料

**Files:**
- Inspect and possibly move: gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt
- Inspect and possibly move: gu-zu/分支：六卷精编版/蛊真人-clean.txt
- Inspect and possibly move: gu-zu/豆包/蛊真人-clean.txt
- Inspect and possibly move: 同目录下的《人祖传》.txt
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\gu-zu\source-dedup\README.md

**Interfaces:**
- Consumes: Task 1 SHA-256 清单、lore_sources/manifest.json、当前 lore/world-model 文档引用。
- Produces: canonical source 对照表和可恢复的重复资料归档。

- [ ] **Step 1: 对同名文本做哈希核对。**

Run:

~~~powershell
$paths=@(
  'gu-zhenren-editor\分支：六卷精编版\蛊真人-clean.txt',
  'gu-zu\分支：六卷精编版\蛊真人-clean.txt',
  'gu-zu\豆包\蛊真人-clean.txt',
  'gu-zhenren-editor\分支：六卷精编版\《人祖传》.txt',
  'gu-zu\分支：六卷精编版\《人祖传》.txt',
  'gu-zu\豆包\《人祖传》.txt'
)
$paths | Where-Object { Test-Path -LiteralPath $_ } | Get-FileHash -Algorithm SHA256
~~~

Expected: 相同哈希的副本归为一组；不同哈希不得凭文件名判断等价。

- [ ] **Step 2: 确认 canonical source。**

默认把 gu-zhenren-editor/分支：六卷精编版/ 作为游戏工程引用的 canonical source，把 gu-zu 中完全相同的副本复制到外部 source-dedup/，并记录原路径、SHA-256 和归档日期。若脚本明确依赖 gu-zu 路径，则保留该副本并归档 editor 副本。

- [ ] **Step 3: 重跑 lore/world-model 读取链。**

Run:

~~~powershell
pwsh -NoProfile -File gu-zhenren-editor\tools\lore.ps1 world-model-0
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite unit
~~~

Expected: 归档重复文本不改变 source manifest、证据解析或 Stage 0 门禁结果；若变化，立即恢复原路径。

---

### Task 5: 压缩历史文档，但保留当前决策入口

**Files:**
- Inspect: gu-zhenren-editor/docs/q8/
- Inspect: gu-zhenren-editor/docs/q8f/
- Inspect: gu-zhenren-editor/docs/q8g/
- Inspect: gu-zhenren-editor/docs/superpowers/reports/
- Preserve: gu-zhenren-editor/docs/contracts/
- Preserve: gu-zhenren-editor/docs/lore/
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\gu-zhenren-editor\docs-history\README.md

**Interfaces:**
- Consumes: AGENTS.md 权威资料索引、rg 引用结果、文档最后修改时间。
- Produces: 历史文档索引；工作区只保留当前规范、契约、活跃交接和必要审计结论。

- [ ] **Step 1: 扫描文档引用和当前权威入口。**

Run:

~~~powershell
rg -n --hidden -g '!**/.git/**' -g '!**/.godot/**' -g '!**/build/**' "docs/(q8|q8f|q8g)|Q8G_|Q8F_|docs/superpowers/reports" gu-zhenren-editor
~~~

Expected: 得到仍被 AGENTS.md、脚本、测试或当前报告引用的文件列表；被当前最高设计宪章引用的历史材料不得仅因日期旧而移除。

- [ ] **Step 2: 按当前规范、历史证据、可再生成输出给文档打标。**

历史证据保留在外部归档并写摘要；可再生成的 _*.txt、仿真输出和临时 review pack 不在工作区保留；docs/contracts/、docs/lore/、当前 Stage 0 报告和 AGENTS.md 保留。

- [ ] **Step 3: 外移已确认历史文档并建立索引。**

索引至少包含：原路径、标题、最后修改时间、哈希、取代它的当前文档、是否可再生成、恢复命令。恢复时只能按索引把单个文件放回原路径，不能把整个历史目录复制回项目。

- [ ] **Step 4: 验证文档入口未断。**

Run:

~~~powershell
rg -n "docs/(contracts|lore|superpowers/specs)|world-model" gu-zhenren-editor\AGENTS.md gu-zhenren-editor\README.md gu-zhenren-editor\docs
git -C gu-zhenren-editor diff --check
~~~

Expected: 当前入口均可定位；没有死链、乱码或 Markdown 空白错误。

---

### Task 6: 完成验收、观察期和回滚

**Files:**
- Create: C:\Users\Zachary\Archives\gu-zhenren\2026-09-17\manifests\archive-log.md
- Verify: gu-zhenren-editor/project.godot
- Verify: gu-zhenren-editor/tools/test.ps1
- Verify: gu-zhenren-editor/docs/contracts/

**Interfaces:**
- Consumes: Tasks 1–5 的归档清单、哈希、测试结果和人工裁定。
- Produces: 可交付的瘦身结果、恢复说明和 14 天观察结论。

- [ ] **Step 1: 执行全量回归。**

Run:

~~~powershell
godot --headless --path gu-zhenren-editor --editor --quit
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite unit
pwsh -NoProfile -File gu-zhenren-editor\tools\test.ps1 -Suite integration
git -C gu-zhenren-editor diff --check
git -C gu-zhenren-editor status --short
~~~

Expected: 已有回归门通过；git status 只显示本次明确批准的 .gitignore、计划/索引和原有未跟踪项，不出现数据表、场景或脚本意外修改。

- [ ] **Step 2: 做一次恢复演练。**

从外部归档恢复一个小目录或一个已归档文档，按 manifest 哈希确认，再移回临时路径验证可读性；演练完成后把临时恢复物移回归档，不污染项目目录。

- [ ] **Step 3: 设置 14 天观察期。**

从 2026-09-17 起保留归档，不删除任何外部副本；期间若运行、测试、审查或新任务需要某文件，按 manifest 单文件恢复并记录调用方。14 天后只删除可重建产物和哈希确认的完全重复副本；历史资料、损坏 Git 副本和原始文本永久保留。

- [ ] **Step 4: 写入恢复说明。**

archive-log.md 记录每批的日期、操作者、源路径、归档路径、SHA-256、释放空间、验证命令、验证结果、回滚命令和最终保留期限。缺少这些字段的候选保持在原位。

## 完成判据

- [ ] 工作区至少移出并验证 build/、.godot/、.preview/ 和无效临时目录；预期释放约 439 MB 以上，不含需人工裁定的 .git.broken-20260916/。
- [ ] .git.broken-20260916/ 已独立封存并有恢复说明，不影响当前 .git。
- [ ] 活跃 gu-zu smoke prototype 未被移动；所有未提交改动已被记录。
- [ ] 重复文本已用 SHA-256 确认，至少保留一个 canonical source 和来源映射。
- [ ] 历史文档归档有索引，当前 contracts/lore/Stage 0 入口完整。
- [ ] Godot editor、unit、integration、git diff --check 均通过。
- [ ] 14 天观察期内无未解释回归；归档目录可按 manifest 单文件恢复。

## 回滚策略

1. 测试失败：停止当前批次，按 archive-log.md 的源路径和哈希把最近一批目录移回原路径。
2. 数据或 lore 结果变化：恢复对应 canonical source，不恢复整个资料仓库；重新运行 source manifest 和 Stage 0 门禁。
3. 发现未提交代码：不覆盖任何文件，保留外部副本并把候选标回 B 类，等待人工裁定。
4. 归档目录损坏：根据 files-sha256.txt 校验；若哈希不符，保留原项目副本，禁止删除原件。
5. 只有在观察期结束且用户明确确认后，才删除可重建缓存或完全重复副本；原始资料、历史文档、恢复用 Git 副本不进入自动删除队列。
