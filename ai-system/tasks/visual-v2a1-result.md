# Caveman Review Packet

```text
TASK visual-v2a1-qingmao
PHASE V2 需求重构 / 视觉素材二次采集 · 子包 2a1（青茅山 A 阶段）
STATUS READY_FOR_REVIEW
TYPE content
ASK L2 复核 27 对象可用性，确认后放行 2a2（商家城·南疆）

GOAL
只做 A 阶段 12 窗 × 150 行，≥18 对象，边读边写落盘
范围外：B 阶段南疆、中洲/北原西漠东海、任何画风结论零输出

DELTA
+ ai-system/tasks/visual-library-v2a1.md：27 对象 + 12 窗采样栅格
+ ai-system/tasks/visual-v2a1-result.md：本包
= 蛊真人-clean.txt 未动；lore/wiki 只导航未改；他任务文件未碰

STATE
OpenCode + Muse Spark 1.3 | Godot PARTIALLY VERIFIED，Wiki VERIFIED，本内容任务沿用读窗手采

FILES
ai-system/tasks/visual-library-v2a1.md — 新增 27 对象（A01:3 A02:2 A03:3 A04:2 A05:3 A06:1 A07:2 A08:2 A09:3 A10:3 A11:2 A12:1）
ai-system/tasks/visual-v2a1-result.md — 新增本包

TEST
focused: 短引 exact 命中 `蛊真人-clean.txt` → PASS 31/31
relevant: 占位名 `行\d+/·行` → PASS 0；转述去重 → PASS 27/27 唯一；短引 ≤60 字 → PASS 0 超限；三层齐全 → PASS 54 事实/27 转译/27 评级；风格词 → PASS 0
full: BLOCKED（V2 阶段禁开发，无代码可跑；内容自查即验收）
diff-check: PASS（新增仅本 SCOPE 两文件，未碰他人在途文件）

WORKER
L3 Visual Lore Research Worker（READ ONLY）
core patch: NO
tests: YES（内容自查）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
A06/A12 各仅 1 对象（会盟坡/猴王单点，窗内余者多为议论无视觉描写，pre-existing，非阻塞）
A10–A12 行号已出青茅山地理（江岸/白骨山/商路），但属任务书 A 阶段采样栅格内，L2 定夺是否划归 2a2（new，不阻塞）
UNPROVEN NONE（全部条目来自已读窗口文字，无外推）

GIT
status: 新增仅 visual-library-v2a1.md + visual-v2a1-result.md；余下未跟踪/修改皆他人在途工作未碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 27 对象先行入库 v2a1，2a2 开工 | recommend YES | 配额 18 超额 50%，自查全绿
D2 A10–A12 地理外溢三窗是否保留本包 | recommend YES | 任务书栅格内采到即有效，归属由 L2 集成时裁

NEXT
L2 grep 抽查短引行号
L2 派发 2a2（商家城·南疆）
STOP

EVIDENCE
ai-system/tasks/visual-library-v2a1.md（栅格 + 27 条目）
```

FACT 行号 28018「一朵蓝白相间的花骨朵儿，在泉水中悠然飘荡」（天元宝莲，八片半莲叶，source 蛊真人-clean.txt:28018）；行号 31782 血湖「面积比山寨还要大」（source 同文件:31782）；行号 39370 肉囊秘阁「密室上下左右的墙壁，都是肉壁」（source 同文件:39370）
ANALYSIS 青茅山视觉地基三层可读：寨居烟火（竹楼/酒肆/会盟坡/墓地）→ 修行内视（空窍/元泉/天元宝莲）→ 地底恐怖（血湖/刀翅血蝠/肉囊秘阁）；蛊形多为可数小物（弯月/龟壳/微鳄/仙人球），着甲多走纹身化/光罩化
UNCHECKED A12 猴王掰手腕是否算商家城商路母题前置，待 L2 集成定夺；月轮（A03:9234）是否与后文月道仙蛊意象同源，未核对
