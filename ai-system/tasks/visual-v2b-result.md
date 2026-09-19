# Caveman Review Packet

```text
TASK visual-v2b-central-plain
PHASE V2 visual-lore C-central-plain
STATUS PARTIAL
TYPE content
ASK L2 裁决：(1) C02/C03 六对象（北原场景）去留；(2) 纯中洲19对象是否接受为PARTIAL交付，或另开补采窗口

GOAL
中洲地域簇15窗×120行=1800行，≥25对象，每窗≤3，边读边写

DELTA
+ ai-system/tasks/visual-library-v2b.md（25对象+15窗栅格）
+ ai-system/tasks/visual-v2b-result.md（本件）
~ NONE
- NONE
= 用户在途改动未碰；2a/2c文件未碰；w2a目录未碰

STATE
OpenCode + Muse Spark 1.3 | Godot PARTIALLY VERIFIED, Wiki VERIFIED（本任务为只读lore采集，用Wiki VERIFIED侧）

FILES
ai-system/tasks/visual-library-v2b.md — 新增，25对象，栅格15窗（含5个0窗）
ai-system/tasks/visual-v2b-result.md — 新增，本结果包

TEST
focused: w2b_selfcheck.py → PASS（对象25/占位名0/重复转述0/短引27条exact命中27/≤60字100%/三层齐全/风格词0）
relevant: 窗内关键词计数脚本 → PASS（C01/C07零命中落空有据；C06仙蛊屋11均为南疆语境）
full: BLOCKED（本任务READ ONLY，无代码测试可跑；L2 grep复核留待复核）
diff-check: PASS（git status仅新增本SCOPE两文件，用户改动未动）

WORKER
L3 Visual Lore Research Worker（OpenCode + Muse Spark）
core patch: NO
tests: YES（自查脚本）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
配额差6：纯中洲19/25，5个异域/落空窗（C01/C06/C07/C08/C09记0）所致，非采集松懈。new，不阻塞L2复核，阻塞2c前quota结算。
C02/C03六对象场景实为北原王庭福地（中洲各仅1顺带命中），已标⚠️待裁决；若L2判删，总量19。pre-existing任务设计假设（锚点±400行必落中洲正文）被证伪，见EVIDENCE。
UNPROVEN NONE（转述均出自已读窗口文字；一缺抱憾亭一处转述曾脑补，已自删，见文件史无残留——注：本轮已修正）

GIT
status: 仅新增visual-library-v2b.md + visual-v2b-result.md；其余M/??均为用户原有在途工作，未碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 C02/C03六对象是否计入中洲配额 | recommend NO（场景北原，仅尽处余晖主为中洲古派可单议）| 地域归属看对象所属势力，场景定位北原
D2 是否接受19纯中洲PARTIAL交付 | recommend YES | 炼蛊大会/天庭/人道杀招核心靶子已覆盖（蝎针门/归一派/藏龙窟/万众一心/星宿棋盘/白日星现），缺口纯由异域窗造成

NEXT
L2复核短引抽查+地域裁决；需补采由L2另开锚点（建议炼蛊大会/帝君城纵深）
STOP

EVIDENCE
ai-system/tasks/visual-library-v2b.md（栅格+25条目）；自查脚本C:\Users\90877\AppData\Local\Temp\opencode\w2b_selfcheck.py；窗口文件w2b/C01–C15.txt；关键词计数w2b_check.py
```

FACT 中洲锚点三窗落空有据：C01（144202起）/C07（237800起）窗内`中洲/天庭/仙蛊屋/正道/监天塔`零命中；C06窗`仙蛊屋`11命中皆指南疆义天山语境。source：`蛊真人-clean.txt`行号+脚本计数。
FACT 炼蛊大会中洲：蝎针门爆炸（行号313172）、归一派报名大殿被上古年兽压塌（行号313188/313220）、分赛场洪易叶凡托蛊（行号313944）。source同上。
FACT 天庭核心：监天塔宿命壁画半壁模糊（行号175608/175612）、星宿棋盘悬浮自转（行号358250）、白日星现照耀天地（行号358262）、万众一心全洲光晕（行号357836/357840）。source同上。
ANALYSIS 第一锚点簇（144k–145k）实为北原王庭福地之战、中洲仅顺带提及；238k簇实为北原逆流河争夺、中洲群仙为参战方：`中洲`分位锚点≠中洲场景，L2"窗口必落中洲正文"假设在8/15窗上不成立（C01/C06/C07/C08/C09零收，C02/C03待裁）。
UNCHECKED C02/C03六对象地域归属待L2裁决；帝君城本轮仅名无 visual 描述（行号358216），未收；龙纹/地沟等藏龙窟条目视觉转述限于本窗文字，未跨窗补考据。
