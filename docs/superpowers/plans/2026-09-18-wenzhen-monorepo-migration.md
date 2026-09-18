# 问真 Monorepo Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** 将当前《蛊真人》项目代码、设定、读书笔记和 Wiki 纳入同一个父 Git 仓库，同时排除原著全文、嵌套 Git 历史、工作树和本地临时产物。

**Architecture:** 保留现有根目录结构，避免修改 Wiki 与读书笔记中的路径引用。父仓库管理 gu-zhenren-editor/、gu-zu/、wenzhen-lore/ 和项目文档；两个子目录原有的 .git 元数据改名为本地备份并被父仓库忽略，父仓库成为统一版本边界。原著全文只保留本地来源路径，不进入公开仓库。

**Tech Stack:** Git、PowerShell、ripgrep、UTF-8 Markdown；不引入 Git LFS、数据库或新的构建运行时。

## Remote baseline

迁移前已执行远程抓取并核对当前基线：

- `gu-zhenren-editor/` 对齐 Gitee `chen-dong-s/gu-zhenrens-pigeon-meat` 的 `master`。
- `gu-zu/` 对齐 GitHub `Zachar-c/gu-zu` 的 `master`。
- 父仓库对齐 GitHub `Zachar-c/-` 的 `master`。
- `gu-zu/` 中名为 `gitee` 的远程实际指向编辑器项目，不作为第三个资料仓库合并；两个子仓库的完整 Git 元数据保存在本地备份目录中。

## Global Constraints

- 保留 gu-zhenren-editor/、gu-zu/、wenzhen-lore/ 的现有路径，不进行大规模目录搬迁。
- 不提交 gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt。
- 不提交 gu-zhenren-editor/分支：六卷精编版/《人祖传》.txt。
- 不提交任何 .worktrees/、嵌套 .git 或 .git-nested-backup/ 内容。
- 不提交 map_test_result.txt、备份文件、临时日志和生成缓存。
- 不删除嵌套仓库历史；只将其 .git 目录改名为可恢复的本地备份。
- 提交前确认暂存区只包含项目文件，提交后推送 master 到 origin。

---

### Task 1: 建立父仓库的 Monorepo 规则

**Files:**
- Create: README.md
- Create: .gitignore
- Create: docs/superpowers/plans/2026-09-18-wenzhen-monorepo-migration.md

**Interfaces:**
- README.md 说明四个主要目录的职责和公开仓库不包含原著全文的边界。
- .gitignore 排除嵌套仓库备份、工作树、原著全文和本地临时产物。

- [x] **Step 1: 写入父仓库 README**

README 必须列出 gu-zhenren-editor/、gu-zu/、wenzhen-lore/、docs/，并说明原文在本地来源路径中维护，不随公开 monorepo 分发。

- [x] **Step 2: 写入父仓库忽略规则**

至少包含以下规则：

~~~gitignore
**/.git-nested-backup/
**/.worktrees/
gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt
gu-zhenren-editor/分支：六卷精编版/《人祖传》.txt
/map_test_result.txt
**/*.bak-*
**/gate_sabotage.log
~~~

- [x] **Step 3: 检查忽略规则命中目标**

Run:

~~~powershell
git check-ignore -v "gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt" "gu-zhenren-editor/分支：六卷精编版/《人祖传》.txt" "gu-zu/.worktrees/codex/nanjiang-smoke-prototype" "map_test_result.txt"
~~~

Expected: 每个路径都输出对应的 .gitignore 规则。

### Task 2: 保留子仓库历史并切换父仓库管理

**Files:**
- Rename: gu-zhenren-editor/.git → gu-zhenren-editor/.git-nested-backup
- Rename: gu-zu/.git → gu-zu/.git-nested-backup

**Interfaces:**
- 子项目工作树内容保持不变。
- 原有 Git 元数据以本地备份保留，不进入父仓库。

- [x] **Step 1: 确认备份目标不存在**

Run:

~~~powershell
Test-Path "gu-zhenren-editor/.git-nested-backup"
Test-Path "gu-zu/.git-nested-backup"
~~~

Expected: 两个结果都是 False。

- [x] **Step 2: 改名保存嵌套历史**

Run:

~~~powershell
Move-Item -LiteralPath "gu-zhenren-editor/.git" -Destination "gu-zhenren-editor/.git-nested-backup"
Move-Item -LiteralPath "gu-zu/.git" -Destination "gu-zu/.git-nested-backup"
~~~

Expected: 两个 .git-nested-backup 目录存在，原 .git 路径不存在，项目普通文件未改变。

- [x] **Step 3: 确认父仓库能够看到子项目文件**

Run:

~~~powershell
git status --short -- gu-zhenren-editor gu-zu wenzhen-lore docs
~~~

Expected: 显示普通文件路径，而不是 gu-zhenren-editor/ 或 gu-zu/ 的 gitlink。

### Task 3: 预览并审计 Monorepo 暂存区

**Files:**
- Modify: parent Git index only

**Interfaces:**
- 暂存区包含项目内容和 Wiki，不包含全文原文、嵌套 Git 备份、工作树和临时产物。

- [x] **Step 1: 暂存父仓库范围内的所有可提交内容**

Run:

~~~powershell
git add --all
~~~

- [x] **Step 2: 审计暂存路径**

Run:

~~~powershell
git diff --cached --name-only
git diff --cached --stat
~~~

Expected: 路径来自 gu-zhenren-editor/、gu-zu/、wenzhen-lore/ 和 docs/；不存在蛊真人-clean.txt、《人祖传》.txt、.worktrees/、.git-nested-backup/ 或 map_test_result.txt。

- [x] **Step 3: 检查暂存区没有敏感文件名和行尾空白**

Run:

~~~powershell
git diff --cached --check
git diff --cached --name-only | rg "(^|/)(\.env|.*secret.*|.*credential.*|.*token.*|id_rsa|.*\.pem)$"
~~~

Expected: 新增的根 README、忽略规则和迁移计划通过 `git diff --cached --check`；导入的既有子项目文件可能保留历史 trailing whitespace，本次迁移不做无关的全仓格式化。敏感文件名检查无输出。

### Task 4: 重新验证 Wiki 和 monorepo 边界

**Files:**
- Read: wenzhen-lore/wiki/**/*.md

**Interfaces:**
- Wiki 的四字段 frontmatter、来源路径、相对链接和主题索引继续通过原有验收。

- [x] **Step 1: 运行 Wiki 结构验收**

检查所有知识页仍包含 type、name、aliases、sources，所有 source/notes/memory 路径存在，所有相对 .md 链接可解析。

- [x] **Step 2: 运行 monorepo 内容边界验收**

检查父仓库暂存区不包含两个原著全文、任何 .worktrees、任何 .git-nested-backup 和根目录临时文件。

### Task 5: 提交并推送统一仓库

**Files:**
- Commit: all audited staged project files

**Interfaces:**
- 产生一个描述清晰的 monorepo 批次提交。
- master 推送到 origin/master。

- [ ] **Step 1: 创建 monorepo 提交**

Run:

~~~powershell
git commit -m "chore: consolidate Gu Zhenren project into monorepo"
~~~

- [ ] **Step 2: 推送父仓库**

Run:

~~~powershell
git push origin master
~~~

- [ ] **Step 3: 推送后核验**

Run:

~~~powershell
git log -1 --oneline --decorate
git branch -vv
git ls-remote origin refs/heads/master
git diff --stat origin/master..HEAD
git status --short
~~~

Expected: 本地 HEAD 与 origin/master 指向同一提交；差异为空；未跟踪内容只可能是被明确保留在本地的嵌套历史备份和未纳入的原文/临时资料。
