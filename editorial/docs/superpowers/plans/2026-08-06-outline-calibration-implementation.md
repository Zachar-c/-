# 《蛊真人》完本精编纲目校准体系实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 依据已经完结的完整原文，建立六部总纲、主要篇章分纲、前二十节细纲和事实争议校准台账，并用细纲重新核验现有精编正文。

**Architecture:** 原始 CP936 / GBK 文本留在仓外，只通过章节索引和证据定位参与编辑。`outlines/` 保存三层纲目，`notes/` 保存人物、伏笔、资源、时间和事实争议台账，`volumes/` 保存精编正文，PowerShell 校验脚本验证文件、编码、章节、噪声和版本边界。总纲先建立全书视角，分纲再拆解目标—阻力—选择—代价—结果链，细纲最后约束正文删改边界。

**Tech Stack:** PowerShell 5+/7、UTF-8 Markdown、UTF-8 CSV、Git；源文件 `C:\DevEnv\05_Downloads\蛊真人.txt` 使用 CP936 / GBK 且不进入 Git。

## Global Constraints

- 完整原文是事实基线；总纲、分纲、细纲和台账不得创造原文没有的剧情、动机、力量体系或世界真相。
- 精编目标是出版级清理、润色、校正和必要结构整理，不以固定比例压缩原文，不把正文改造成剧情摘要。
- 编辑内部纲目可以包含全书剧透；精编正文必须遵守原书的信息释放顺序，不提前解释后文才揭示的答案。
- 主要心理转折、高潮前铺垫、高潮中的现场过程、高潮后的不可逆后果和关键伏笔必须保留。
- 无法由完整原文、后文回收或多处印证确认的数字、时间、称谓和因果，先进入事实争议台账，不强行统一。
- 正文输出和新增台账使用 UTF-8；默认使用 ASCII 编写脚本，只有路径或正文内容需要时使用中文。
- 完整原文、仓外源路径和临时抽取文件不得加入 Git；每个阶段通过独立提交保存，完成阶段后推送 `origin main`。

## File Map

| Path | Responsibility |
| --- | --- |
| `index/chapter-headings.csv` | 当前原始章节扫描结果，保留作追溯，不覆盖 |
| `index/chapter-headings-normalized.csv` | 去除明显抓取噪声、标出重复和连续性状态的候选章节索引 |
| `index/chapter-number-summary-normalized.csv` | 归一化后的章节号、出现次数、间断和候选范围摘要 |
| `index/source-audit.json` | 源文件编码、字节数、解码字符数、用户申报字数、标题统计和审计时间 |
| `index/source-audit.md` | 对源文件与当前索引差异的人工审计结论 |
| `outlines/README.md` | 纲目目录、字段规范、证据引用格式和正文校准规则 |
| `outlines/00-full-book-outline.md` | 六部总纲、全书主线、人物弧线、主题线和高潮地图 |
| `outlines/volumes/01-魔性不改.md` 至 `06-魔尊永生.md` | 六部篇章分纲 |
| `outlines/arcs/00-transition-map.md` | 主要高潮之间的过渡篇章和承接关系 |
| `outlines/arcs/01-青茅山.md` 至 `10-疯魔窟大战.md` | 用户指定主要高潮与大战的分纲 |
| `outlines/detail/vol1-sec001-010.md` | 第一部第 1—10 节细纲 |
| `outlines/detail/vol1-sec011-020.md` | 第一部第 11—20 节细纲 |
| `notes/fact-disputes.csv` | 跨全书事实冲突、证据等级、暂定处理和最终决议 |
| `scripts/normalize_source_index.ps1` | 从仓外完整原文生成候选归一化章节索引和源审计报告 |
| `scripts/validate_editorial_assets.ps1` | 分阶段验证纲目、台账、正文、编码、章节连续性和 Git 边界 |

---

### Task 1: 审计完整原文并建立归一化章节索引

**Files:**
- Create: `scripts/normalize_source_index.ps1`
- Create: `index/chapter-headings-normalized.csv`
- Create: `index/chapter-number-summary-normalized.csv`
- Create: `index/source-audit.json`
- Create: `index/source-audit.md`
- Read only: `index/chapter-headings.csv`, `index/chapter-number-summary.csv`, `C:\DevEnv\05_Downloads\蛊真人.txt`

**Interfaces:**
- Consumes: CP936 / GBK source path and the existing raw heading index.
- Produces: normalized candidate headings with original line numbers, section numbers, titles, duplicate groups, sequence status, and source metrics. Later outline tasks must use this index for citations，不直接凭文件行数猜测篇章范围。

- [ ] **Step 1: Record the current source/index discrepancy before changing the parser**

Run:

```powershell
Get-Content -Raw -Encoding UTF8 index/source-metadata.json
Get-Content -Encoding UTF8 index/chapter-headings.csv | Measure-Object -Line
Get-Content -Encoding UTF8 index/chapter-number-summary.csv | Measure-Object -Line
git ls-files | Select-String -SimpleMatch '蛊真人.txt'
```

Expected: the current metadata, raw index row counts, and the absence of a tracked `蛊真人.txt` are recorded in the task notes; the raw index is not overwritten.

- [ ] **Step 2: Implement the index normalizer with an explicit source audit output**

Implement the script interface:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$RawIndexPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)
```

The script must:

- read the source with `[Text.Encoding]::GetEncoding(936)`;
- recognize only lines matching a complete `第<中文数字或阿拉伯数字>节` heading with a title;
- exclude page markers, URL/HTML lines, author notes, collection prompts, and headings embedded in non正文 noise;
- retain every candidate's original source line, parsed numeric section, raw title and noise flags;
- group repeated section numbers without silently deleting any raw occurrence;
- select a canonical candidate sequence only when the surrounding numbers are monotonically increasing and the candidate is not marked as page/site noise;
- write duplicate groups and gaps to the audit report instead of silently resolving uncertain cases;
- preserve both the computed decoded character count and the user-stated `14,577,005` count as separate metadata fields.

The normalized CSV must contain at least:

```text
source_line,section_number,section_text,title,noise_flags,duplicate_group,sequence_status,canonical_candidate
```

- [ ] **Step 3: Run the normalizer against the real source and inspect the report**

Run:

```powershell
pwsh -File scripts/normalize_source_index.ps1 `
  -SourcePath 'C:\DevEnv\05_Downloads\蛊真人.txt' `
  -RawIndexPath 'index\chapter-headings.csv' `
  -OutputDirectory 'index'
```

Expected files: `chapter-headings-normalized.csv`, `chapter-number-summary-normalized.csv`, `source-audit.json`, and `source-audit.md`. The audit must explicitly list duplicate section numbers, non-monotonic ranges, heading gaps, raw versus candidate counts, and the difference between computed and user-stated character counts.

- [ ] **Step 4: Manually approve the canonical ranges used by later outlines**

Read `index/source-audit.md` and compare every proposed volume/arc boundary against the source headings. Do not remove duplicate rows from the normalized index. Record the chosen candidate by setting `canonical_candidate=true` only when the surrounding sequence and source context support it; leave unresolved candidates marked `review_required`.

- [ ] **Step 5: Validate and commit the source baseline**

Run:

```powershell
Import-Csv index/chapter-headings-normalized.csv | Measure-Object
Get-Content -Raw -Encoding UTF8 index/source-audit.json | ConvertFrom-Json | Format-List
git diff --check
git status --short
```

Expected: the normalized CSV imports successfully, the audit JSON parses, no whitespace errors appear, and the source file remains untracked. Commit:

```powershell
git add scripts/normalize_source_index.ps1 index/chapter-headings-normalized.csv index/chapter-number-summary-normalized.csv index/source-audit.json index/source-audit.md
git commit -m "建立完本原文归一化索引与源审计"
git push origin main
```

---

### Task 2: Establish the outline schema, fact-dispute ledger, and staged validator

**Files:**
- Create: `outlines/README.md`
- Create: `notes/fact-disputes.csv`
- Create: `scripts/validate_editorial_assets.ps1`

**Interfaces:**
- Consumes: normalized source index, existing `notes/*.csv`, edited volume files, and repository root.
- Produces: reusable Markdown templates, initial cross-book dispute records, and a validator with `baseline`, `outline`, `detail`, and `final` phases.

- [ ] **Step 1: Define the Markdown and CSV contracts before filling content**

Write `outlines/README.md` with these required section names:

```markdown
# 纲目与正文校准规范
## 目录结构
## 证据引用格式
## 总纲字段
## 分纲字段
## 细纲字段
## 信息释放规则
## 正文修改分级
## 批次提交与校验
```

Use this exact CSV header for `notes/fact-disputes.csv`:

```csv
id,scope,issue,evidence_level,source_locations,conflict_or_question,interim_policy,final_decision,status,reviewed_at
```

Populate the initial rows with the six already identified issues: 花酒行者死因、前二十节元石流水、开篇“千万”与“数十万”数量口径、重生至开窍及寻宝时间链、十六岁继承与自立门户制度、当前源文件字数与索引统计差异。 Each row must state its current evidence level and interim policy rather than leaving an unqualified assertion.

- [ ] **Step 2: Implement the staged validator**

Implement this interface:

```powershell
param(
    [ValidateSet('baseline', 'outline', 'detail', 'final')]
    [string]$Phase = 'baseline',

    [string]$RepoRoot = (Get-Location).Path
)
```

The validator must return exit code `0` only when all checks for the selected phase pass, and return exit code `1` with file-specific errors otherwise. Checks must include:

- strict UTF-8 decoding for Markdown, CSV, and edited正文 files;
- successful `Import-Csv` for every tracked CSV;
- required outline files for the selected phase;
- continuous section headings 1—20 in the two detail files;
- absence of `**` conversion residue and site-promotion markers in edited正文;
- absence of tracked `蛊真人.txt` or other complete-source copy;
- no duplicate detail section IDs;
- no missing referenced outline file paths.

- [ ] **Step 3: Run the baseline validator before any outline content is added**

Run:

```powershell
pwsh -File scripts/validate_editorial_assets.ps1 -Phase baseline -RepoRoot (Get-Location).Path
```

Expected: exit code `0`; the existing first-twenty正文 and current台账 pass baseline checks. If a check fails, fix the validator's path or parsing logic before proceeding; do not weaken the check to hide a repository problem.

- [ ] **Step 4: Commit the schema and validator**

```powershell
git add outlines/README.md notes/fact-disputes.csv scripts/validate_editorial_assets.ps1
git commit -m "建立纲目模板与事实争议校验"
git push origin main
```

---

### Task 3: Write the six-volume master outline

**Files:**
- Create: `outlines/00-full-book-outline.md`
- Read: `index/chapter-headings-normalized.csv`, `index/source-audit.md`, and the complete source through the normalized ranges

**Interfaces:**
- Consumes: approved canonical section ranges and the full completed novel.
- Produces: one spoiler-permitted internal master outline that later volume, arc, and detail outlines cite by stable heading names.

- [ ] **Step 1: Create the master-outline skeleton**

Use these required headings:

```markdown
# 《蛊真人》全书总纲
## 使用边界
## 六部结构总览
## 全书主因果链
## 方源阶段性弧线
## 主要人物弧线
## 主要势力与关系变化
## 力量、资源与身份升级
## 主题线
## 高潮与伏笔总图
## 信息释放与终局回看
## 事实争议引用
```

- [ ] **Step 2: Fill the six-part structure from the completed source**

For each of the six parts, record exactly these subheadings:

```markdown
### 第一部：魔性不改
#### 进入状态
#### 核心目标与主冲突
#### 主要篇章和转折
#### 高潮
#### 不可逆变化
#### 对下一部的推动
```

Repeat for `魔子出山`、`魔头乱世`、`魔君纵横`、`魔王雄霸` and `魔尊永生`. Use normalized section numbers and source line references, not guessed chapter ranges. Summaries must explain causality and state changes without copying long source passages.

- [ ] **Step 3: Add cross-book protagonist, character, faction, resource, and theme maps**

The master outline must explain how the following change across the six parts: 方源的阶段目标与限制、方正的弧线、白凝冰及关键同盟/对手关系、主要势力的升降、修为与资源边界、长生/自由/宿命/人性主题。 Each claim must identify whether it is an explicit fact, a later-recovered interpretation, or a multi-location synthesis.

- [ ] **Step 4: Add climax/foreshadowing map without changing disclosure order**

List the named high points and their consequences, but distinguish `editorial knowledge` from `reader-at-the-time knowledge`. A later revelation may be recorded in the master outline while the corresponding earlier正文 entry remains marked `有意悬念` in `notes/fact-disputes.csv` or `notes/foreshadowing-ledger.csv`.

- [ ] **Step 5: Validate the master outline**

Run:

```powershell
rg -n '^### (第一部|第二部|第三部|第四部|第五部|第六部)' outlines/00-full-book-outline.md
rg -n '^#### (进入状态|核心目标与主冲突|主要篇章和转折|高潮|不可逆变化|对下一部的推动)$' outlines/00-full-book-outline.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase outline -RepoRoot (Get-Location).Path
git diff --check
```

Expected: six volume headings are present, each required subsection is present once, and the outline phase validator passes. Commit:

```powershell
git add outlines/00-full-book-outline.md
git commit -m "建立蛊真人全书六部总纲"
git push origin main
```

---

### Task 4: Write volume outlines for the first three parts

**Files:**
- Create: `outlines/volumes/01-魔性不改.md`
- Create: `outlines/volumes/02-魔子出山.md`
- Create: `outlines/volumes/03-魔头乱世.md`

**Interfaces:**
- Consumes: `outlines/00-full-book-outline.md`, normalized source ranges, character/foreshadow/resource/timeline ledgers.
- Produces: three volume-level causal maps. Arc and detail documents must cite these files using the exact volume headings.

- [ ] **Step 1: Apply the shared volume template to each file**

Each file must contain:

```markdown
# 《蛊真人》第一部：魔性不改
## 本部定位
## 进入与离开状态
## 阶段目标
## 主要势力与人物状态
## 篇章顺序
## 目标—阻力—选择—代价—结果链
## 高潮与余波
## 伏笔状态
## 资源与时间边界
## 正文精编边界
## 证据引用
```

Use the corresponding part title for the other two files. `篇章顺序` must list every canonical篇章 range assigned to the part, including transition material; it must not list only the named battles.

- [ ] **Step 2: Fill the first volume with the first-twenty trial context**

For `魔性不改`, explicitly connect the first twenty sections to the larger volume arc: self-detonation and rebirth, the Qing Mao Mountain starting cage, aptitude reversal, inheritance pressure, flower-wine legacy, and the first reappearance of Spring Autumn Cicada. Preserve unresolved items such as the exact flower-wine death cause and the yuan-stone accounting dispute.

- [ ] **Step 3: Fill the second and third volume causal maps**

For `魔子出山` and `魔头乱世`, record the complete-source state transitions rather than only their climaxes: changes in identity, resources, cultivation, allies, opponents, and the consequences that force the next volume. Do not use later spoilers as if they were knowledge available to characters in earlier scenes.

- [ ] **Step 4: Validate and commit the first three volume outlines**

Run:

```powershell
rg -n '^# 《蛊真人》' outlines/volumes/01-魔性不改.md outlines/volumes/02-魔子出山.md outlines/volumes/03-魔头乱世.md
rg -L '^## (本部定位|进入与离开状态|阶段目标|主要势力与人物状态|篇章顺序|目标—阻力—选择—代价—结果链|高潮与余波|伏笔状态|资源与时间边界|正文精编边界|证据引用)$' outlines/volumes/*.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase outline -RepoRoot (Get-Location).Path
git diff --check
```

Expected: all three files have the required sections and the outline validator passes. Commit:

```powershell
git add outlines/volumes/01-魔性不改.md outlines/volumes/02-魔子出山.md outlines/volumes/03-魔头乱世.md
git commit -m "建立前三部篇章分纲"
git push origin main
```

---

### Task 5: Write volume outlines for the last three parts

**Files:**
- Create: `outlines/volumes/04-魔君纵横.md`
- Create: `outlines/volumes/05-魔王雄霸.md`
- Create: `outlines/volumes/06-魔尊永生.md`

**Interfaces:**
- Consumes: the approved master outline, normalized source ranges, and the same shared volume schema used in Task 4.
- Produces: the remaining three volume-level causal maps, including the terminal-state and final thematic consequences needed to re-read early伏笔.

- [ ] **Step 1: Create the three files with the shared volume headings**

Use the exact template from Task 4 and the correct part title in each H1. Do not invent chapter ranges before confirming them in `index/chapter-headings-normalized.csv`.

- [ ] **Step 2: Write the late-book state and consequence maps**

For each volume, record how the preceding volume's unresolved goals become the current volume's conflicts, how major battles change the world state, and what remains unresolved until the final volume. Explain the relationship between personal survival, long-term immortality, fate, human agency, and the final state without converting thematic interpretation into a claimed in-world fact.

- [ ] **Step 3: Validate and commit the last three volume outlines**

Run:

```powershell
rg -L '^## (本部定位|进入与离开状态|阶段目标|主要势力与人物状态|篇章顺序|目标—阻力—选择—代价—结果链|高潮与余波|伏笔状态|资源与时间边界|正文精编边界|证据引用)$' outlines/volumes/*.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase outline -RepoRoot (Get-Location).Path
git diff --check
```

Expected: all six volume files pass the same schema check. Commit:

```powershell
git add outlines/volumes/04-魔君纵横.md outlines/volumes/05-魔王雄霸.md outlines/volumes/06-魔尊永生.md
git commit -m "建立后三部篇章分纲"
git push origin main
```

---

### Task 6: Write early and central climax outlines plus the transition map

**Files:**
- Create: `outlines/arcs/00-transition-map.md`
- Create: `outlines/arcs/01-青茅山.md`
- Create: `outlines/arcs/02-三王山.md`
- Create: `outlines/arcs/03-前王庭福地大战.md`
- Create: `outlines/arcs/04-后王庭福地大战.md`
- Create: `outlines/arcs/05-义天山大战.md`
- Create or modify: `outlines/arcs/index.md`

**Interfaces:**
- Consumes: the six volume outlines and normalized source ranges.
- Produces: arc-level causal documents. Each arc file is referenced by `outlines/arcs/index.md` and by the applicable volume file.

- [ ] **Step 1: Create the transition-map and arc index**

`outlines/arcs/index.md` must list all ten named arcs, their volume, canonical section range, and links to their files. `00-transition-map.md` must list the unnamed or lower-intensity material between major climaxes and state what goal, resource, relationship, or information it carries forward.

- [ ] **Step 2: Apply the shared arc template**

Each named arc file must contain:

```markdown
# 篇章：...
## 范围与定位
## 开端状态
## 方源目标
## 其他势力目标
## 关键资源与限制
## 冲突升级
## 中段转折
## 高潮与关键决断
## 代价与不可逆后果
## 人物弧线变化
## 伏笔与信息释放
## 与前后篇章的承接
## 正文精编边界
## 证据引用
```

- [ ] **Step 3: Fill the Qing Mao Mountain and Three Kings Mountain arcs**

Track the starting-world rules, identity and aptitude changes, inheritance and legacy pressure, competing inheritance objectives, Bai Ning Bing relationship changes, resource constraints, and the consequences that make the next stage unavoidable. Do not reduce either arc to “方源获得传承并提升实力”.

- [ ] **Step 4: Fill the two Imperial Court Blessed Land war arcs**

Separate pre-war accumulation, battlefield escalation, key reversals, climax decision, and post-war political/resource consequences. Record the different functions of the earlier and later war instead of treating “王庭福地大战” as one repeated event.

- [ ] **Step 5: Fill the Yi Tian Mountain arc**

Record the factional conflict, shadowed long-term objectives, identity and information asymmetry, decisive resource transformations, climax cost, and the aftermath that feeds into the fate-related and Ghost Soul-related arcs. Mark every interpretation that depends on later disclosure.

- [ ] **Step 6: Validate the early/central arc set and commit**

Run:

```powershell
Get-ChildItem outlines/arcs -Filter '*.md' | Sort-Object Name | Select-Object Name
rg -L '^## (范围与定位|开端状态|方源目标|其他势力目标|关键资源与限制|冲突升级|中段转折|高潮与关键决断|代价与不可逆后果|人物弧线变化|伏笔与信息释放|与前后篇章的承接|正文精编边界|证据引用)$' outlines/arcs/0[1-5]-*.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase outline -RepoRoot (Get-Location).Path
git diff --check
```

Expected: all five arc files pass the shared schema, the index links resolve, and the transition map names every gap between them. Commit:

```powershell
git add outlines/arcs/00-transition-map.md outlines/arcs/index.md outlines/arcs/01-青茅山.md outlines/arcs/02-三王山.md outlines/arcs/03-前王庭福地大战.md outlines/arcs/04-后王庭福地大战.md outlines/arcs/05-义天山大战.md
git commit -m "建立前中期高潮与过渡分纲"
git push origin main
```

---

### Task 7: Write late climax outlines and complete the arc map

**Files:**
- Create: `outlines/arcs/06-逆流河炼蛊.md`
- Create: `outlines/arcs/07-前宿命大战.md`
- Create: `outlines/arcs/08-后宿命大战.md`
- Create: `outlines/arcs/09-幽魂追逐战.md`
- Create: `outlines/arcs/10-疯魔窟大战.md`
- Modify: `outlines/arcs/index.md`
- Modify: `outlines/arcs/00-transition-map.md`

**Interfaces:**
- Consumes: late-volume outlines, the early/central arc map, and full-source evidence.
- Produces: late-book arc documents that explain climax preparation, world-state changes, final thematic convergence, and the consequences that validate earlier伏笔.

- [ ] **Step 1: Create the five late-arc files with the exact shared template**

Use every heading from Task 6. Do not replace the five arcs with one late-book summary; each must have its own start state, escalation, decision, cost, and aftermath.

- [ ] **Step 2: Fill the Reverse Flow River Gu Refinement arc**

Describe the objective, rule/ability constraints, action sequence, risk accumulation, psychological and strategic cost, and the change in what Fang Yuan can or cannot do afterward. Keep the process itself visible in the outline so the eventual正文 does not collapse the炼蛊 into a result sentence.

- [ ] **Step 3: Fill the pre- and post-Fate War arcs**

Distinguish the two Fate War arcs by their different strategic conditions, information states, combat objectives, alliances, decisive turning points, and aftermath. Record how fate, human agency, and the protagonist's long-term objective are reframed between them.

- [ ] **Step 4: Fill the Ghost Soul pursuit and Crazy Demon Cave arcs**

Track pursuit logic, competing objectives, the relationship between personal survival and world-level stakes, the final resource/knowledge exchanges, and the terminal consequences of the Crazy Demon Cave arc. Mark later explanations as editorial hindsight rather than earlier character knowledge.

- [ ] **Step 5: Complete links and validate the full arc map**

Run:

```powershell
rg -n '^\- \[[^]]+\]\(' outlines/arcs/index.md
rg -L '^## (范围与定位|开端状态|方源目标|其他势力目标|关键资源与限制|冲突升级|中段转折|高潮与关键决断|代价与不可逆后果|人物弧线变化|伏笔与信息释放|与前后篇章的承接|正文精编边界|证据引用)$' outlines/arcs/0[1-9]-*.md outlines/arcs/10-*.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase outline -RepoRoot (Get-Location).Path
git diff --check
```

Expected: all ten named arc links resolve, all arc files pass the schema, and the transition map covers all intervals not represented by a named climax. Commit:

```powershell
git add outlines/arcs/index.md outlines/arcs/00-transition-map.md outlines/arcs/06-逆流河炼蛊.md outlines/arcs/07-前宿命大战.md outlines/arcs/08-后宿命大战.md outlines/arcs/09-幽魂追逐战.md outlines/arcs/10-疯魔窟大战.md
git commit -m "完成后期高潮分纲与全书战役地图"
git push origin main
```

---

### Task 8: Write detailed outlines for sections 1—20

**Files:**
- Create: `outlines/detail/vol1-sec001-010.md`
- Create: `outlines/detail/vol1-sec011-020.md`
- Read: `working/vol1-sec001-010.cp936.txt`, `working/vol1-sec011-020.cp936.txt`, current edited正文, the first-volume outline, Qing Mao Mountain arc outline, and relevant ledgers

**Interfaces:**
- Consumes: approved master/volume/arc outlines plus the complete source's later evidence.
- Produces: section-level instructions that state what must remain in the prose, what can be compressed, what must stay unresolved, and how each section changes state.

- [ ] **Step 1: Create the detail-file template**

Each section entry must use these headings:

```markdown
### 第 X 节：标题
#### 所属篇章与定位
#### 场景、时间与进入状态
#### 本节叙事功能
#### 事件与因果链
#### 方源目标、阻力与选择
#### 人物心理与关系变化
#### 读者信息、人物信息与隐藏信息
#### 伏笔、资源与时间状态
#### 必须保留
#### 可以压缩
#### 只能润色、不可削弱
#### 不得提前揭示
#### 逻辑与设定核验
#### 证据引用
#### 本节结束状态与下一节牵引
```

- [ ] **Step 2: Fill sections 1—10 with whole-book hindsight and original disclosure order**

Record the self-detonation/rebirth opening, five-hundred-year experience, Qing Mao Mountain setting, Fang Zheng contrast, opening ceremony and aptitude reversal, hope-gu story, inheritance pressure, Shen Cui trap, Moonlight Gu cultivation, and the flower-wine search as complete narrative functions. For every entry, distinguish what the editor knows from what Fang Yuan and the reader know at that point.

- [ ] **Step 3: Fill sections 11—20 with full causal and resource tracking**

Record the Shen Cui trap, lodging and family conflict, Jiang Ya pressure, wine search, cave discovery, historical image, flower-wine legacy, resource search, Fang Zheng rupture, Wine Gu refinement, Spring Autumn Cicada recurrence, and school elder misrecognition as distinct state changes. Preserve the flower-wine death question as an unresolved/qualified item, and keep the yuan-stone conflict in the fact-dispute ledger rather than forcing a number in the detail outline.

- [ ] **Step 4: Validate section coverage and references**

Run:

```powershell
rg -n '^### 第' outlines/detail/vol1-sec001-010.md outlines/detail/vol1-sec011-020.md
pwsh -File scripts/validate_editorial_assets.ps1 -Phase detail -RepoRoot (Get-Location).Path
rg -n '花酒行者|元石|春秋蝉|方正|沈翠' outlines/detail/vol1-sec001-010.md outlines/detail/vol1-sec011-020.md notes/fact-disputes.csv
git diff --check
```

Expected: exactly twenty unique section entries appear, all required detail headings pass validation, and the known cross-book disputes are referenced rather than silently resolved. Commit:

```powershell
git add outlines/detail/vol1-sec001-010.md outlines/detail/vol1-sec011-020.md
git commit -m "建立前二十节正文校准细纲"
git push origin main
```

---

### Task 9: Recalibrate the first-twenty edited正文 against the detail outlines

**Files:**
- Modify as evidence requires: `volumes/01-魔性不改/vol1-sec001-010.edited.txt`
- Modify as evidence requires: `volumes/01-魔性不改/vol1-sec011-020.edited.txt`
- Modify: `notes/editorial-notes.md`
- Modify: `notes/logic-issues.md`
- Modify: `notes/character-ledger.csv`
- Modify: `notes/foreshadowing-ledger.csv`
- Modify: `notes/resource-ledger.csv`
- Modify: `notes/timeline-ledger.csv`
- Modify: `notes/fact-disputes.csv`

**Interfaces:**
- Consumes: both detail documents, original batch底稿, current正文, and full-book evidence.
- Produces: a正文 revision whose high-risk edits are traceable to the detail outline and whose uncertain issues remain qualified.

- [ ] **Step 1: Build a line-level review checklist before editing**

For each of the twenty sections, record four outcomes in a temporary review table outside Git or in the editorial notes: `保留`, `压缩`, `润色`, `待核`. Check the following in order: event completeness, psychological transition, foreshadowing, resource/time continuity, information release, atmosphere/现场感, and chapter ending pull.

- [ ] **Step 2: Review the opening and first batch without weakening voice**

Confirm that the opening retains the determined lines “群敌环伺，早已经没有了生路”“大局已定，今日必死无疑”; the self-detonation remains an active choice; Fang Zheng's pre-adoption address remains “舅父舅母”; and the first-batch psychological buildup is not replaced by summary judgments. Apply only evidence-backed language or continuity changes.

- [ ] **Step 3: Review the second batch without closing later mysteries early**

Confirm that the flower-wine scene retains the Moon Shadow Gu restriction and wounded retreat while not stating an unverified death cause; the image and skeleton preserve the historical reversal; the resource pressure remains visible without choosing between conflicting yuan-stone totals; the Spring Autumn Cicada recurrence retains its bodily and strategic consequences; and the school elder's misrecognition remains a consequence of the preceding state rather than an isolated joke.

- [ ] **Step 4: Record every high-risk decision**

For each changed paragraph, add a concise entry to `notes/editorial-notes.md` with section, modification level, evidence location, and reason. For every unresolved issue, update `notes/fact-disputes.csv` with the evidence level and interim policy. Do not add a definitive final decision while the full-source evidence remains contradictory.

- [ ] **Step 5: Run the detail-phase and prose checks**

Run:

```powershell
pwsh -File scripts/validate_editorial_assets.ps1 -Phase detail -RepoRoot (Get-Location).Path
git diff --check
rg -n '\*\*|站点|作者按语|打赏|推荐票|月票|请收藏|手机用户' volumes --glob '*.edited.txt'
```

Expected: the validator exits `0`, `git diff --check` is clean, and the noise search returns no hits. If no正文 change is justified, keep the existing text and record the no-op review in `editorial-notes.md` rather than manufacturing edits.

- [ ] **Step 6: Commit the calibrated first-twenty batch**

```powershell
git add volumes/01-魔性不改/vol1-sec001-010.edited.txt volumes/01-魔性不改/vol1-sec011-020.edited.txt notes/editorial-notes.md notes/logic-issues.md notes/character-ledger.csv notes/foreshadowing-ledger.csv notes/resource-ledger.csv notes/timeline-ledger.csv notes/fact-disputes.csv
git commit -m "依据细纲校准前二十节精编正文"
git push origin main
```

---

### Task 10: Update project documentation and run the final asset verification

**Files:**
- Modify: `README.md`
- Modify: `notes/editorial-notes.md`
- Read: all new `outlines/`, `notes/`, `index/`, and `volumes/` files

**Interfaces:**
- Consumes: all outputs from Tasks 1—9.
- Produces: a repository whose current progress, source boundary, outline coverage, and validation commands are discoverable from `README.md`.

- [ ] **Step 1: Update README progress and directory documentation**

Add the following repository areas to `README.md`:

```markdown
- `outlines/`：全书总纲、六部篇章分纲、主要高潮分纲和批次细纲
- `notes/fact-disputes.csv`：跨全书事实争议与编辑决议
- `index/`：原文索引、归一化章节索引和源文件审计
```

Update progress to state that the six-volume master outline, named climax map, and first-twenty detail outline exist, while later正文 batches remain unprocessed unless their files are present.

- [ ] **Step 2: Add the completed calibration record**

Append to `notes/editorial-notes.md` a dated record naming the outline files used, the first-twenty validation scope, the unresolved disputes preserved, and the exact commit that contains the calibration. Do not claim a dispute is solved merely because it is documented.

- [ ] **Step 3: Run the full verification set**

Run:

```powershell
pwsh -File scripts/validate_editorial_assets.ps1 -Phase final -RepoRoot (Get-Location).Path
git diff --check
git status --short --branch
git ls-files | Select-String -SimpleMatch '蛊真人.txt'
git log --oneline -5
```

Expected: final validation exits `0`, diff check is clean, the working tree is clean after commit, no complete source file is tracked, and the latest commits show each major deliverable. Commit and push:

```powershell
git add README.md notes/editorial-notes.md
git commit -m "完成纲目校准体系首轮文档接入"
git push origin main
```

---

## Verification Matrix

| Requirement | Verification |
| --- | --- |
| 完整原文不入 Git | `git ls-files \\| Select-String -SimpleMatch '蛊真人.txt'` returns no rows |
| 源文件编码和统计可追溯 | `index/source-audit.json` parses and `source-audit.md` records raw/candidate/user-stated counts |
| 六部总纲完整 | six required H3 headings and `-Phase outline` pass |
| 六部篇章分纲完整 | six files contain the shared volume headings and linked canonical ranges |
| 主要高潮分纲完整 | ten named arc files plus transition map are linked from `outlines/arcs/index.md` |
| 前二十节细纲完整 | exactly twenty unique section headings and `-Phase detail` pass |
| 心理/铺垫/伏笔保留 | each detail entry contains `必须保留`, `只能润色、不可削弱`, and `不得提前揭示` |
| 争议不被擅自统一 | `notes/fact-disputes.csv` has evidence level, interim policy, and status for each open issue |
| 正文无连载噪声 | validator and `rg` noise search return no hits |
| 编码和格式有效 | strict UTF-8, `Import-Csv`, and `git diff --check` pass |
| 修改可回退 | every major task has a separate Git commit pushed to `origin main` |

## Execution Order and Checkpoints

Tasks must run in order because later outline ranges depend on the normalized source index, detail sections depend on volume/arc outlines, and正文 calibration depends on detail sections. Safe review checkpoints are after Task 1, Task 2, Task 3, Task 5, Task 7, Task 8, Task 9, and Task 10. At each checkpoint, inspect the generated files and push the commit before starting the next dependent task.

## Self-Review Against the Approved Design

- The plan establishes a full-source baseline before any正文 rewrite.
- The plan separates total outline, volume/arc outline, section detail, and factual dispute tracking.
- The plan explicitly preserves information release order and does not let editorial hindsight leak into正文.
- The plan gives psychological transitions, atmosphere, foreshadowing, resources, time, and chapter-end state explicit fields.
- The plan treats existing yuan-stone, flower-wine death, time, inheritance, and body-count discrepancies as evidence-tracked issues rather than automatic corrections.
- The plan includes independent validation and Git checkpoints for every major deliverable.
- The plan does not add a fixed compression ratio, a new plot, or a complete-source copy to the repository.
