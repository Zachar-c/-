# 问真最小蒸馏 Wiki Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不建设数据库或检索运行时的前提下，创建一个可被 AI、Codex 和人直接阅读的《蛊真人》Markdown 蒸馏 Wiki 首批切片。

**Architecture:** 现有原文和读书笔记继续作为不可改动的来源；`wenzhen-lore/wiki/` 是人工可读、AI 可导航的蒸馏产物；Git 负责历史，`rg` 负责原文回查。首批页面只从当前仓库已有事实索引和记忆库提取，并在页面中保留章节或现有资料定位。

**Tech Stack:** UTF-8 Markdown、少量 YAML frontmatter、Git、PowerShell、ripgrep；不新增 Python 依赖、数据库、向量索引、图数据库或 Web runtime。

## Global Constraints

- 原文 `gu-zhenren-editor/分支：六卷精编版/蛊真人-clean.txt` 和《人祖传》继续作为来源，不复制整部正文到新目录。
- 不修改 `gu-zhenren-editor/` 下的游戏运行时代码、`data/`、`scenes/` 或现有 `lore_engine`。
- Wiki 页面只使用 `type`、`name`、`aliases`、`sources` 四个 frontmatter 字段。
- 事实与解读分开写在正文的 `原著明确内容`、`分析与解读`、`待核对` 区块中。
- 没有现成来源定位的内容不得写成原著事实；可写入分析区或待核对区。
- 文件名使用稳定 ASCII slug，页面标题和正文使用中文；页面间使用相对 Markdown 链接。
- 本次交付只建立最小可用骨架和首批种子页面；Quartz 只作为未来展示层，不在本次引入。

---

### Task 1: 建立 Wiki 根目录与来源说明

**Files:**
- Create: `wenzhen-lore/README.md`
- Create: `wenzhen-lore/AGENTS.md`
- Create: `wenzhen-lore/index.md`
- Create: `wenzhen-lore/log.md`
- Create: `wenzhen-lore/source/README.md`
- Create: `wenzhen-lore/source/chapter-index.md`

**Interfaces:**
- Produces the navigation and editing contract used by all later Wiki pages.
- Source paths resolve from the repository root to the existing `gu-zhenren-editor/` materials.

- [ ] **Step 1: 写入根目录说明**

创建 README，明确 Wiki-first 工作流、来源优先级、`rg` 回查命令和后续升级条件。

- [ ] **Step 2: 写入 Agent 编辑约定**

创建 AGENTS.md，规定页面格式、事实/解读分区、链接命名、来源标注和禁止复制整部正文。

- [ ] **Step 3: 写入根索引、日志和来源索引**

`index.md` 只做渐进式导航；`log.md` 记录本次初始化；`source/` 只记录现有原文、读书笔记和事实索引的路径，不复制原文。

- [ ] **Step 4: 用文件存在性检查验证根目录**

Run: `Test-Path wenzhen-lore/README.md; Test-Path wenzhen-lore/AGENTS.md; Test-Path wenzhen-lore/index.md; Test-Path wenzhen-lore/source/README.md`

Expected: 四个结果全部为 `True`。

### Task 2: 建立分类索引与页面最小模板

**Files:**
- Create: `wenzhen-lore/wiki/characters/index.md`
- Create: `wenzhen-lore/wiki/gu/index.md`
- Create: `wenzhen-lore/wiki/events/index.md`
- Create: `wenzhen-lore/wiki/world/index.md`
- Create: `wenzhen-lore/wiki/themes/index.md`

**Interfaces:**
- Each directory index links only to pages that exist in the same change.
- All concept pages use the four-field frontmatter defined in `wenzhen-lore/AGENTS.md`.

- [ ] **Step 1: 创建五类目录索引**

每个索引包含类别说明、首批页面链接和“未整理内容不代表原著不存在”的边界说明。

- [ ] **Step 2: 检查链接目标**

Run: `rg -n '\]\([^)]*\.md\)' wenzhen-lore/wiki`

Expected: 每个链接目标都是本次创建或已存在的相对 Markdown 文件。

### Task 3: 从现有资料创建世界规则种子页

**Files:**
- Create: `wenzhen-lore/wiki/world/cultivation-system.md`
- Create: `wenzhen-lore/wiki/world/aptitude-and-aperture.md`
- Create: `wenzhen-lore/wiki/world/primeval-essence.md`
- Create: `wenzhen-lore/wiki/world/gu-care-and-refinement.md`
- Create: `wenzhen-lore/wiki/world/south-jiang.md`

**Interfaces:**
- Pages cite `gu-zhenren-editor/docs/lore/canon-index.md` and the source paths/line ranges recorded there.
- Pages distinguish direct canon facts from implementation interpretation.

- [ ] **Step 1: 录入修炼、资质和元海规则**

只使用事实索引已有的转数、小境界、资质和真元内容；每条事实保留 `CAN-*` ID 和原文行号。

- [ ] **Step 2: 录入养蛊、炼蛊和南疆环境规则**

只使用已有 `CAN-GU-*`、`CAN-NANJIANG-*` 和 `CAN-ECONOMY-*` 条目；没有证据的细节放入 `待核对`。

- [ ] **Step 3: 把世界规则页加入 `world/index.md`**

只添加实际存在的页面链接，并按“修炼 / 蛊 / 地域”顺序排列。

- [ ] **Step 4: 用来源关键词检查事实页**

Run: `rg -n 'CAN-|蛊真人-clean|原文明确内容|待核对' wenzhen-lore/wiki/world`

Expected: 每个世界规则页面都包含来源标识，并且正文有事实与未确认内容的边界。

### Task 4: 从现有资料创建实体、事件和主题种子页

**Files:**
- Create: `wenzhen-lore/wiki/characters/fang-yuan.md`
- Create: `wenzhen-lore/wiki/characters/bai-ning-bing.md`
- Create: `wenzhen-lore/wiki/characters/he-lou-lan.md`
- Create: `wenzhen-lore/wiki/gu/small-light-gu.md`
- Create: `wenzhen-lore/wiki/gu/moonlight-gu.md`
- Create: `wenzhen-lore/wiki/gu/spring-autumn-cicada.md`
- Create: `wenzhen-lore/wiki/events/qing-mao-mountain.md`
- Create: `wenzhen-lore/wiki/events/three-kings-mountain.md`
- Create: `wenzhen-lore/wiki/events/reverse-flow-river.md`
- Create: `wenzhen-lore/wiki/themes/ren-zu-zhuan.md`

**Interfaces:**
- Character, Gu, event and theme pages link to world pages or other pages only when the target exists.
- Existing memory-bank notes are treated as secondary navigation aids; canon claims still point to the primary text or the canon index.

- [ ] **Step 1: 创建三个角色页**

使用现有 `gu-zu/分支：六卷精编版/记忆库/02-人物弧光.md`、`gu-zu/分支：六卷精编版/记忆库/06-角色台账.md` 和 `gu-zhenren-editor/分支：六卷精编版/读书笔记/` 作为整理来源；不把重写项目的创作计划误写成原著事实。

- [ ] **Step 2: 创建三个蛊虫页**

小光蛊使用事实索引中的直接证据；月光蛊与春秋蝉只写当前资料能支持的最小事实，其余列入 `待核对`。

- [ ] **Step 3: 创建三个事件页**

事件页先采用“参与者 / 关键转折 / 后续影响 / 原著依据”结构；未完成完整事件复盘的部分明确标为待整理。

- [ ] **Step 4: 创建《人祖传》主题页**

明确区分世界内典籍内容与客观原著事实，并链接到现有 `记忆库/04-人祖传-隐喻索引.md`。

- [ ] **Step 5: 更新五个分类索引与根索引**

所有新页面都必须能从 `wenzhen-lore/index.md` 经过不超过两次链接到达。

### Task 5: 完成只读验收

**Files:**
- Modify: `wenzhen-lore/log.md`

**Interfaces:**
- Produces a human-readable record of the initial seed batch and verification commands.

- [ ] **Step 1: 检查 Markdown 文件与 frontmatter**

Run: `rg --files wenzhen-lore | Sort-Object`; then inspect each Wiki page for the four required keys.

Expected: 所有概念页以 `---` 开头，包含 `type`、`name`、`aliases`、`sources`。

- [ ] **Step 2: 检查断链**

Run: `rg -n '\[\[[^]]+\]\]' wenzhen-lore/wiki`

Expected: 每个 Wiki 链接都对应一个已创建页面或在同页明确标记为待整理的目标；不存在拼写不一致的核心页面链接。

- [ ] **Step 3: 检查工作区变更范围**

Run: `git status --short -- wenzhen-lore`

Expected: 只出现 Wiki 文档和本计划涉及的文件，不出现 `data/`、`scenes/`、游戏脚本或原文修改。

- [ ] **Step 4: 记录初始化结果**

把页面数量、来源范围和验证命令写入 `wenzhen-lore/log.md`，不引入新的运行时或数据库。
