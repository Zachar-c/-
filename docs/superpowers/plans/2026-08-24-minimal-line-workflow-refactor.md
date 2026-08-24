# 出版级精编·极简线重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 gu-zhenren-editor 的多分支、多台账、多会话并行流程收敛为一条单人极简管线：净化源文 → 批次细纲 → 逐节编辑 → 验证 → 审阅 → 单提交，唯一台账，一页规范。

**Architecture:** 只做前向迁移（git mv + 新文件 + 少量引用修正），不改写历史、不动卷一卷二成品正文的任何字节。历史资料全部进 `*/_archive/` 或 `archive/` 冻结目录，可查不可依赖。

**Tech Stack:** PowerShell 5.1 + Python 3（现有脚本）、git、pytest（tests/，基线 33 passed）。

## 用户已拍板的三个决定

1. 卷一卷二已完成成品与 epub **一字不动**。
2. 台账（战力/资源/时间/信息/人物/裁决）**保留并合并成一份**。
3. 王庭压缩版等实验分支产物**归档**（不删除）。

## Global Constraints

- 不修改 `volumes/01-*`、`volumes/02-*` 下任何文件内容（新增 README 标记除外）。
- 不使用 reset / 强制检出 / 历史改写；全部前向提交。
- 中文路径命令一律加引号。
- 每个 Task 结束运行该任务的验证命令并独立提交；提交前跑 `py -3 scripts/check_remote_base.py`（远程基准校准沿用现行强制规则）。
- 工作区当前有 staged 未提交内容（王庭实验 17 文件 + working 报告）与 unstaged 删除（`蛊真人-clean.txt`）；Task 0 专门处理，后续任务不得混入。

---

### Task 0: 工作区前置清理

**Files:**
- Restore: `蛊真人-clean.txt`（worktree 内被删，git 有跟踪版本）
- Modify: `.gitignore`（追加 working/ 忽略）
- Move: `working/*.md`、`working/vol3-121-150-source-extract.txt` → `working/archive-2026-08/`

**Interfaces:**
- Produces: 干净的 index（除本任务自身提交外无 staged 内容），供后续所有任务使用。

- [ ] **Step 1: 记录当前 staged 清单备查**

```powershell
git diff --cached --name-only | Out-File working/pre-refactor-staged-list.txt -Encoding utf8
Get-Content working/pre-refactor-staged-list.txt
```
Expected: 17 行左右（docs/superpowers 两个 2026-08-10 文档、volumes/03-*-王庭压缩版 5 文件、03-*-王庭现场保留版 3 文件、working 5 个报告/brief）。此文件仅存工作区，不提交。

- [ ] **Step 2: 恢复蛊真人-clean.txt**

```powershell
git checkout -- "蛊真人-clean.txt"
Test-Path "蛊真人-clean.txt"
```
Expected: True。（外层 `gu3\蛊真人-clean.txt` 是同一净版的共享副本；仓库内副本是 config/editorial-volumes.json 第 2 行白名单与 gen_brief 净版优先逻辑的依赖，必须保留。）

- [ ] **Step 3: working/ 移入既有归档并解除暂存**

```powershell
git reset HEAD -- working/
Move-Item working\vol3-001-030-r2-report.md,working\vol3-061-090-report.md,working\vol3-091-120-brief.md,working\vol3-091-120-report.md,working\vol3-091-120-source.tmp.txt,working\vol3-121-150-brief.md,working\vol3-121-150-source-extract.txt working\archive-2026-08\
```

- [ ] **Step 4: working/ 整体入 .gitignore**

在 `.gitignore` 末尾追加一行：

```
working/
```

对已被 git 跟踪的 working 文件取消跟踪：

```powershell
git rm -r --cached working/
git status --short
```
Expected: working/ 下所有条目变为不在 index；`D` 标记只出现在 cached 区。

- [ ] **Step 5: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add .gitignore
git commit -m "chore: 重构前置清理——恢复净化源文、working目录转入本地不入库"
```

- [ ] **Step 6: 验证测试基线不破**

```powershell
python -m pytest tests -q
```
Expected: 33 passed。

---

### Task 1: 归档王庭压缩版实验产物

**Files:**
- Create: `volumes/_archive/README.md`
- Move: `volumes/03-魔头乱世-王庭压缩版/` → `volumes/_archive/wangting-compression/`
- Move: `volumes/03-魔头乱世-王庭现场保留版/` → `volumes/_archive/wangting-live-preserved/`
- Move: `docs/superpowers/specs/2026-08-10-vol3-post-wangting-compression-design.md`、`docs/superpowers/plans/2026-08-10-vol3-post-wangting-compression-plan.md` → `docs/archive/`

**Interfaces:**
- Consumes: Task 0 的干净 index（这些文件此刻仍在 index 的旧路径上）。
- Produces: `volumes/_archive/` 目录约定；config 的 `directoryPattern: "03-魔头乱世"` 为精确匹配不受影响。

- [ ] **Step 1: 先查看远端 workflow-refactor 分支有无现成方案**

```powershell
git fetch origin
git log origin/workflow-refactor --oneline -8
```
若包含与本计划同目的且更新的重构成果，停止本计划并向用户报告差异；否则继续。

- [ ] **Step 2: 创建归档目录与说明**

`volumes/_archive/README.md`：

```markdown
# volumes/_archive

实验性分支产物冻结区。王庭压缩版 / 现场保留版是第三卷王庭段落的两种编辑路线试验，
已于 2026-08-24 由用户裁决归档；主线正文只在 `volumes/03-魔头乱世/`。
本目录内文件不得被任何脚本写入或作为后续批次依据。
```

- [ ] **Step 3: git mv 两组实验目录**

```powershell
New-Item -ItemType Directory -Force volumes\_archive | Out-Null
git mv "volumes/03-魔头乱世-王庭压缩版" "volumes/_archive/wangting-compression"
git mv "volumes/03-魔头乱世-王庭现场保留版" "volumes/_archive/wangting-live-preserved"
```

- [ ] **Step 4: 归档实验设计文档**

```powershell
New-Item -ItemType Directory -Force docs\archive | Out-Null
git mv docs/superpowers/specs/2026-08-10-vol3-post-wangting-compression-design.md docs/archive/
git mv docs/superpowers/plans/2026-08-10-vol3-post-wangting-compression-plan.md docs/archive/
git add volumes/_archive/README.md
```

- [ ] **Step 5: 验证结构与配置无碰撞**

```powershell
py -3 scripts/validate_editorial_assets.py -Phase detail
python -m pytest tests/test_check_remote_base.py -q
```
Expected: validate 通过（config 按 `03-魔头乱世` 精确匹配，_archive 不被扫描为 vol3）；测试通过。

- [ ] **Step 6: 提交**

```powershell
py -3 scripts/check_remote_base.py
git commit -m "chore: 归档王庭压缩版/现场保留版实验产物至volumes/_archive与docs/archive（用户裁决归档）"
```

---

### Task 2: 冻结标记卷一卷二

**Files:**
- Create: `volumes/01-魔元大陆/README.md`、`volumes/02-魔临城山/README.md`（目录名以实际为准，用通配定位）

**Interfaces:**
- Produces: 成品冻结的显式声明，供 AGENTS.md 引用。

- [ ] **Step 1: 确认实际目录名**

```powershell
Get-ChildItem volumes -Directory | Select-Object -ExpandProperty Name
```

- [ ] **Step 2: 在两卷目录各新建 README.md**

内容模板（替换 `<卷>` 为实际卷名）：

```markdown
# 冻结成品

<卷> 精编正文与 epub 已完成并通过用户审阅，自 2026-08-24 起冻结：
任何脚本、会话不得修改本目录内 *.edited.txt 与 *.epub。
勘误一律记入 notes/ledger.md 勘误小节，随下一卷批次落地，不回改本卷。
```

- [ ] **Step 3: 验证成品字节未动**

```powershell
git diff --stat -- volumes/01-* volumes/02-*
```
Expected: 仅两个新 README，无 .edited.txt/.epub 出现在 diff。

- [ ] **Step 4: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add volumes/*/README.md
git commit -m "docs: 卷一卷二成品冻结标记（用户裁决不动成品）"
```

---

### Task 3: 新建唯一台账骨架并迁移卷一活约束

**Files:**
- Create: `notes/ledger.md`
- Read-only 来源: `notes/vol1-decision-register.md`、`vol1-combat-ledger.md`、`vol1-resource-audit.md`、`vol1-information-ledger.md`、`vol1-chronology-geography.md`、`vol1-character-state-ledger.md`、`vol1-structural-surgery.md`

**Interfaces:**
- Produces: `notes/ledger.md` 六段式结构，Task 4/5 向其中追加；最终被新 AGENTS.md 与 gen_brief 台账命中功能引用。

- [ ] **Step 1: 写入台账骨架**

`notes/ledger.md` 全文：

```markdown
> 台账状态行：最后落地批次：迁移初始化；最后更新：2026-08-24。新记录只追加到对应小节底部，禁止重写中部历史行。

# 唯一台账

全书唯一活台账。只收录仍约束后续编辑的内容；历史流水在 notes/archive/ 可查。

每条记录格式：`[来源: 原<文件>#<行ID>] <内容>`；勘误在条目前加 `[勘误]` 并注明原行 ID。

## 1. 冻结裁决与勘误

（卷一/卷二/卷三冻结裁决、勘误，按卷分小节）

### 卷一

### 卷二

### 卷三

## 2. 战力规则

## 3. 经济与资源

## 4. 时间与地理

## 5. 信息与调查边界

## 6. 人物状态锚点

（仅记进行中卷的当前锚点：谁、在哪、修为/蛊组/伤势、资源水位）

## 7. 全书待核问题

（原 full-book-audit-register 中未关闭项；关闭后整行划掉并注日期）
```

- [ ] **Step 2: 通读卷一 7 个来源文件**

逐个 Read，按以下判据筛选"活约束"：
1. 明确标注冻结/已裁决的条目 → 第 1 节卷一小节。
2. 世界观硬规则（战力对照、经济尺度、时间地理成本、信息边界）→ 第 2–5 节。
3. 卷一终态人物锚点（方正被带走时各人状态）→ 第 6 节，标注"卷一终态"。
4. 纯过程流水、已兑现的批内状态 → 不迁，留归档。

- [ ] **Step 3: 追加迁移内容**

每条带 `[来源: vol1-combat-ledger#V1-CBT-xxx]` 式溯源；预期总量 30–80 条，宁缺毋滥。

- [ ] **Step 4: 抽验溯源**

随机抽 3 条，按来源文件行 ID 回查原文条目，确认语义一致无篡改。

- [ ] **Step 5: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add notes/ledger.md
git commit -m "feat: 新建唯一台账ledger.md并迁移卷一活约束（含溯源ID）"
```

---

### Task 4: 迁移卷二活约束

**Files:**
- Modify: `notes/ledger.md`
- Read-only 来源: `notes/vol2-*.md` 7 个文件 + `notes/vol2-section-source-map.csv`（后者仅确认性质，不迁移）

- [ ] **Step 1:** 同 Task 3 Step 2 判据通读卷二 7 文件。
- [ ] **Step 2:** 向 ledger.md 对应小节追加卷二条目；第 6 节记"卷二终态（第206节）"锚点。
- [ ] **Step 3:** 抽验 3 条溯源。
- [ ] **Step 4: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add notes/ledger.md
git commit -m "feat: ledger.md迁移卷二活约束（含溯源ID）"
```

---

### Task 5: 迁移卷三与全书级活约束

**Files:**
- Modify: `notes/ledger.md`
- Read-only 来源: `notes/vol3-*.md` 7 文件、`full-book-audit-register.md`、`full-book-editorial-review-2026-08-08.md`（仅议题来源）、`character-ledger.csv`、`resource-ledger.csv`、`timeline-ledger.csv`、`foreshadowing-ledger.csv`、`editorial-notes.md`、`logic-issues.md`

- [ ] **Step 1:** 通读卷三 7 文件，按 Task 3 判据迁移；第 6 节记"卷三当前锚点（截至最新批次 211-244）"。
- [ ] **Step 2:** 通读 audit-register，未关闭条目迁入第 7 节并保留编号（如 `AUD-xxx`）。
- [ ] **Step 3:** 通读 4 个全局 CSV 与 editorial-notes/logic-issues：仍是未决事实争议的并入第 7 节或第 1 节勘误；已解决的丢弃。
- [ ] **Step 4:** 抽验 3 条溯源。
- [ ] **Step 5: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add notes/ledger.md
git commit -m "feat: ledger.md迁移卷三与全书级活约束（含溯源ID）"
```

---

### Task 6: 归档旧台账并接通脚本引用

**Files:**
- Move: notes/ 下除 `ledger.md`、`fact-disputes.csv`、`vol2-section-source-map.csv`、`vol3-section-source-map.csv` 外的全部文件 → `notes/archive/`
- Modify: 引用了旧台账路径的脚本（如有）

**Interfaces:**
- Consumes: Task 3–5 的 ledger.md（迁移完成才允许归档旧账）。
- Produces: notes/ 四文件终态；validate 对 `notes/fact-disputes.csv` 的必需检查继续成立（该文件保留原地）。

- [ ] **Step 1: 确认 ledger.md 无空节遗留**

```powershell
Select-String -Path notes\ledger.md -Pattern "^（.*$"
```
Expected: 占位括号行已全部被真实内容替换或显式标注"（无）"。

- [ ] **Step 2: 归档移动**

```powershell
New-Item -ItemType Directory -Force notes\archive | Out-Null
git mv notes/vol1-character-state-ledger.md notes/vol1-chronology-geography.md notes/vol1-combat-ledger.md notes/vol1-decision-register.md notes/vol1-information-ledger.md notes/vol1-resource-audit.md notes/vol1-structural-surgery.md notes/archive/
git mv notes/vol2-character-state-ledger.md notes/vol2-chronology-geography.md notes/vol2-combat-ledger.md notes/vol2-decision-register.md notes/vol2-information-ledger.md notes/vol2-resource-audit.md notes/vol2-structural-surgery.md notes/archive/
git mv notes/vol3-character-state-ledger.md notes/vol3-chronology-geography.md notes/vol3-combat-ledger.md notes/vol3-decision-register.md notes/vol3-information-ledger.md notes/vol3-resource-audit.md notes/vol3-structural-surgery.md notes/archive/
git mv notes/full-book-audit-register.md notes/full-book-editorial-review-2026-08-08.md notes/batch-report.md notes/editorial-notes.md notes/logic-issues.md notes/character-ledger.csv notes/resource-ledger.csv notes/timeline-ledger.csv notes/foreshadowing-ledger.csv notes/archive/
```

- [ ] **Step 3: 找出并修正脚本中的旧路径引用**

```powershell
rg -l "notes/(vol[123]-|full-book|character-ledger|resource-ledger|timeline-ledger|foreshadowing)" scripts/ config/
```
已知基线：`scripts/validate_editorial_assets.py:152` 引用 `notes/fact-disputes.csv`（保留文件，无需改）。若出现其他命中，将路径字面量改为 `notes/ledger.md` 或从扫描列表移除；改动须同步补/改 tests/ 对应用例。

- [ ] **Step 4: 三件套冒烟**

```powershell
py -3 scripts/gen_brief.py -Volume vol3 -Batch 211-244
py -3 scripts/validate_editorial_assets.py -Phase detail
python -m pytest tests -q
```
Expected: gen_brief 正常输出（台账命中可为空但不报错）；validate 通过；33 passed。

- [ ] **Step 5: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add -A notes/ scripts/ tests/
git commit -m "refactor: 旧台账28件归档notes/archive，唯一台账接线完成"
```

---

### Task 7: 脚本收敛

**Files:**
- Create: `scripts/_archive/README.md`
- Move（候选归档，逐一核实后执行）: `add_batch_summary.py`、`create_edited_baseline.py/.ps1`、`create_volume_baselines.py/.ps1`、`normalize_source_index.py/.ps1`、`split_volume_boundary.py/.ps1`、`build_index.ps1`、`gen_brief.ps1`、`gen_report.ps1`、`validate_editorial_assets.ps1`、其余 .ps1
- Keep: `clean_full_source.py`、`extract_batch.py`、`gen_brief.py`、`gen_report.py`、`water_scan.py`、`scan_candidates.py`、`audit_candidates.py`、`validate_editorial_assets.py`、`check_remote_base.py`、`build_epub.py`、`build_index.py`、`gu_tools.py`、`__init__.py`、tests/

- [ ] **Step 1: 逐一核实归档候选**

```powershell
foreach ($f in Get-ChildItem scripts -Filter *.ps1) { Write-Output "== $($f.Name)"; Get-Content $f.FullName -TotalCount 3 }
```
确认为纯转发壳（内容形如 `py -3 %~dp0同名.py %*`）方可归档；若某 ps1 含独立逻辑，保留并在提交信息注明。

- [ ] **Step 2: 归档移动**

`scripts/_archive/README.md`：

```markdown
# scripts/_archive

一次性建库/拆分/规范化脚本的冻结区（初版底稿、索引重建、卷界拆分等），
主线流程不再调用。ps1 为 py 脚本的转发壳，随 py 版一并归档。
恢复使用前必须先审计其路径假设是否仍成立。
```

```powershell
git mv scripts/add_batch_summary.py scripts/create_edited_baseline.py scripts/create_edited_baseline.ps1 scripts/create_volume_baselines.py scripts/create_volume_baselines.ps1 scripts/normalize_source_index.py scripts/normalize_source_index.ps1 scripts/split_volume_boundary.py scripts/split_volume_boundary.ps1 scripts/build_index.ps1 scripts/gen_brief.ps1 scripts/gen_report.ps1 scripts/validate_editorial_assets.ps1 scripts/_archive/
git add scripts/_archive/README.md
```
（若 Step 1 发现任一脚本非壳或有活跃调用方，把它从上面命令剔除。）

- [ ] **Step 3: 全量回归**

```powershell
python -m pytest tests -q
py -3 scripts/validate_editorial_assets.py -Phase detail
```
Expected: 33 passed；validate 通过。

- [ ] **Step 4: 提交**

```powershell
py -3 scripts/check_remote_base.py
git commit -m "refactor: 脚本收敛至极简线12件，一次性工具归档scripts/_archive"
```

---

### Task 8: 重写 AGENTS.md 为一页 + README 同步

**Files:**
- Move: `AGENTS.md` → `docs/archive/AGENTS-v2-full-2026-08-24.md`
- Create: `AGENTS.md`（新版全文见下）
- Modify: `README.md`（同步目录、工具表、并行章节删除）

**Interfaces:**
- Consumes: Task 1–7 产出的终态目录结构。
- Produces: 唯一规范源新版本；所有会话开工阅读入口不变（仍是仓库根 AGENTS.md）。

- [ ] **Step 1: 归档旧规范**

```powershell
git mv AGENTS.md docs/archive/AGENTS-v2-full-2026-08-24.md
```

- [ ] **Step 2: 写入新 AGENTS.md，全文如下**

```markdown
# 《蛊真人》出版级精编 Agent 规范（极简线）

## 定位

基于授权原文的出版级精编：统一世界观，校准战力、经济、时间与信息边界，提高语言准确度与文学表现力。不是续写、同人、摘要。"精编≠缩写"，无字数指标；30 节只是用户审阅检查点。单人单批次串行推进，不做多会话并行分工。

## 权威层级

用户最新明确裁决 > 本文件 > `notes/ledger.md` 已冻结裁决 > 当前批次细纲 > 完本稳定设定 > 全书因果推导 > 早期孤立表述。

## 内容边界（未经用户批准不可改）

核心人格、人物弧线与终局；主线方向、大事件与结局；全书级伏笔及其揭露时机；主题张力；关键战斗的过程、反转与代价；关键爽点、压迫感与章末推进力。不新增万能道具、工具人或事后大段解释来修补矛盾。

## 编辑判据

- **A 高潮守护（默认）**：名场面、命运翻转、长铺垫的情感兑现——只修错字、病句、硬设定冲突；保留信息遮蔽、揭露顺序、句群节奏、蓄势重复、微动作与情绪余韵；不提前点破谜底。
- **B 人物处境重铸**：说教、现实怨怼或重复宣判挤占人物经历时等值重铸——用现场压力、资源权力关系、具体代价托住黑暗命题；保住锋芒，不把方源中立化。
- **C 分层压缩**：仅限无状态变化的机械围观、招式复述、重复环境与同一结论反复论证；确认不承担伏笔/递进/留白后方可压缩。
- 口诀：**高潮守住原作的火；说教段把火放回人物手里。**凡删除超过一个自然段，必须写明其功能由何处承接。
- 每节至少标一次 A/B/C/保留。

## 世界观硬规则（速查）

- 百兽王≈二转、千兽王≈三转、万兽王≈四转、兽皇≈五转；"≈"须计入伤势、真元、克制、地形、阵势与数量。
- 夜狼首领时间线：第086节前方源麾下最高四转夜狼万兽王（郑家战死）；086 节购得老迈带伤的五转夜狼皇，此后方可称皇。
- 万元级资金必须交代来源、调拨、账目与政治代价；不同经济尺度不得混写。
- 角色认知 ≠ 叙述者事实 ≠ 官方历史；直觉只能指方向，定罪靠物证与记录。
- 修炼、炼蛊、疗伤、旅行必占时间；第一卷止于第199节方正被带走。
- 完整推导链见 `notes/archive/`（冻结旧账）与 `docs/knowledge-base/`。

## 单人单批次流程

1. `py -3 scripts/gen_brief.py -Volume <卷id> -Batch <节范围> -WriteState` 恢复上下文（简报含批次进度、逐节标题、台账命中、Git 状态）。
2. 读 `outlines/detail/<卷id>-sec<范围>.md` 细纲与 `notes/ledger.md` 相关小节；核对上一批尾状态。
3. 对照原文逐节编辑 `volumes/<卷目录>/<卷id>-sec<范围>.edited.txt`；批内进度记 `working/` 状态卡（本地临时，不入库）。
4. 验证：`py -3 scripts/validate_editorial_assets.py -Phase detail` + `git diff --check` + 章节标题数量顺序核对。
5. `py -3 scripts/gen_report.py -Volume <卷id> -Batch <节范围>` 生成审阅简报，补全"关键裁决及理由""遗留问题"两节后交用户审阅；通过后单批次一提交。

## 台账

唯一台账 `notes/ledger.md`，追加式维护：新记录只加对应小节底部并带 `[来源: …]` 溯源；勘误注明原行 ID；批末更新状态行的最后落地批次与日期。`fact-disputes.csv` 维持事实争议队列。旧台账一律在 `notes/archive/`，只读。

## 提交保护

- 每次 commit/push 前 `py -3 scripts/check_remote_base.py`；clone 或 worktree 初始化一次 `git config core.hooksPath .githooks`。
- 禁止跳过 hook、强制推送、改写历史。未经用户要求不自行提交推送。
- commit message 含批次范围 + 裁决要点，末尾标 `（R<N>，待审阅/用户审阅通过）`。
```

- [ ] **Step 3: 同步 README.md**

按节修改：
1. 「目录」一节替换为：

```markdown
- `volumes/`：分卷精编正文；卷一卷二已冻结，实验产物在 `volumes/_archive/`。
- `outlines/detail/`：批次细纲。
- `notes/`：唯一台账 `ledger.md` + 事实争议队列 + 工具索引 CSV；历史台账在 `notes/archive/`。
- `scripts/`：极简线工具 12 件；退役脚本在 `scripts/_archive/`。
- `docs/knowledge-base/`：世界观与审查知识库；`docs/archive/`：历史规范与实验设计。
```

2. 删除「多对话并行」整节，替换为一行：`单人单批次串行推进；并行协作规则已在 2026-08-24 极简线重构中移除，如需恢复见 docs/archive/AGENTS-v2-full-2026-08-24.md。`
3. 「提效工具」表只保留：gen_brief.py、gen_report.py、water_scan.py/scan_candidates.py/audit_candidates.py、clean_full_source.py、validate_editorial_assets.py、build_epub.py、check_remote_base.py。
4. 「Git 同步保护」「30节交付门槛」两节保留原文。

- [ ] **Step 4: 链接完整性冒烟**

```powershell
rg -o "notes/[a-zA-Z0-9_\-]+\.(md|csv)|scripts/[a-z_]+\.py" AGENTS.md README.md
```
Expected: 所有命中路径都实际存在（结合 Task 6/7 终态人工比对一遍）。

- [ ] **Step 5: 提交**

```powershell
py -3 scripts/check_remote_base.py
git add -A
git commit -m "docs: AGENTS.md重写为一页极简规范，README同步终态目录（旧规范归档docs/archive）"
```

---

### Task 9: 分支清理与收尾全量验证

**Files:**
- Delete: 已合并的陈旧本地分支（经用户确认的清单）

- [ ] **Step 1: 生成分支清单交用户确认**

```powershell
git branch --merged main
git branch -vv
```
预期候选：`edit/vol2-foundation`、`integrate/main-sync`、`push-sync-9688770`、`push-vol2-001-060`、`safety/pre-vol2-091-120-rebase-5b891b5`。**逐个列出给用户勾选，未确认不删。**

- [ ] **Step 2: 删除用户确认的分支**

```powershell
git branch -d <确认的分支名...>
```
Expected: 全部 `-d`（非 `-D`）成功；若有拒绝合并状态的分支，单独报告不强删。

- [ ] **Step 3: 收尾全量验证**

```powershell
python -m pytest tests -q
py -3 scripts/validate_editorial_assets.py -Phase detail
git diff --check
git status --short
py -3 scripts/gen_brief.py -Volume vol3
```
Expected: 33 passed；validate 通过；diff --check 干净；status 干净（working/ 已忽略）；vol3 进度简报正常输出。

- [ ] **Step 4: 最终汇报**

向用户输出：迁移前后目录对比、ledger.md 条目统计（各节条数）、归档文件总数、验证结果汇总。**不自动推送**，推送由用户决定。

---

## Self-Review 记录

- 覆盖核对：三个用户决定 → Task 2（成品不动）、Task 3–6（台账合一）、Task 1（实验归档）；AGENTS/README 收敛 → Task 8；脚本收敛 → Task 7；分支残留 → Task 9。
- 类型一致性：`notes/ledger.md` 七节结构在 Task 3 定义、Task 4/5 复用、Task 8 引用；`_archive` 命名在 volumes/scripts/docs 三处一致采用 `archive` 语义（volumes/_archive、scripts/_archive、notes/archive、docs/archive）。
- 风险提示：gen_brief/gen_report 的台账命中若按文件名 glob `notes/vol*-*.md` 实现，Task 6 Step 3 会暴露；届时改读 `notes/ledger.md` 并同步测试夹具。
