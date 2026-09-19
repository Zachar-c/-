# Caveman Review Packet — visual-archaeology

```text
TASK visual-archaeology
PHASE L3 取证批（设计工作流第 1 步）
STATUS READY_FOR_L2_REVIEW
TYPE content
ASK L2 确认：① 26 母题/栅格/词表是否达标验收 ② M3 章节标记偏离上报是否接受（等距窗口替代）③ E2 稀疏缺口是否需补采

GOAL
从原著直接采集视觉母题，不做归纳不做裁决；交付 corpus + 本 packet

DELTA
+ ai-system/tasks/visual-archaeology-corpus.md（30KB，四部分+栅格+词表+自检）
+ ai-system/tasks/visual-archaeology-result.md（本文件）
= 蛊真人-clean.txt 未跟踪状态未动；lore/wiki 只读未碰；game 未碰

STATE
OpenCode + Muse Spark 1.3 / Godot 软件工程 PARTIALLY VERIFIED；Wiki/知识工程 VERIFIED

FILES
ai-system/tasks/visual-archaeology-corpus.md — 新增，取证报告正文
ai-system/tasks/visual-archaeology-result.md — 新增，本 packet

TEST
focused: python 逐条校验 82 短引 → 82/82 exact 子串命中，0 超 60 字 → PASS
relevant: 行号时代分布 A16/B19/C13/D16/E13（77 行号锚点），每时代 ≥10 案例 → PASS
full: BLOCKED（本任务纯只读，无代码测试入口；验收=文本核验，已做）
diff-check: PASS（git status 仅 SCOPE 内两个新文件，无其他改动）

WORKER
normal-class L3 Visual Research Worker
core patch: NO
tests: YES（文本核验）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
M3 章节标记偏离：`^第.{1,8}节` 686 命中全在 426–126684 行，D/E 章节头为"章节目录 "前缀，
  任务书 M3 机制证伪；已改用等距窗口执行，时代边界最终认定留给 L2/L1（pre-existing 任务书缺陷，非本包引入，不阻塞）
UNPROVEN E2 窗口（379266–379565 荒漠行商段）视觉命中仅 5 处；判为真实稀疏非采样失误，但 E 时代整体仍有 13 案例（NONE 需编造）

GIT
status: 仅 ?? ai-system/tasks/visual-archaeology-corpus.md + ?? visual-archaeology-result.md（其余为执行前已存在改动，未触碰）
commit: NONE
merge: NONE
push: NO

DECISION
D1 接受 M3 偏离与等距窗口替代 | recommend YES | 30 窗口实测覆盖全书，栅格可复核
D2 E2 不补采、如实标稀疏 | recommend YES | E 时代总量达标，编造填坑违反 ESCALATE 条款

NEXT
L2 做视觉规律归纳（第 2 步），证据只从 corpus 行号短引取
STOP

EVIDENCE
ai-system/tasks/visual-archaeology-corpus.md（采样栅格表、关键词词表、26 母题、验收自检）
```

FACT 原著 437060 行/23609617 字节；686 裸`第X节`标记止于 126684 行，后续为"章节目录 "前缀（320986 行起可验证）；坊市 0 命中/宗门 5 命中/村落 1 命中；灯火 A24→E0；狼 B2097 峰值；冰 6661 全书最高频视觉词
ANALYSIS 视觉总轴四条：体内窍海→聚落→洞天→长河；暖点光→通天光→推算霞→混彩潮；虫→兽→魂→拼合体；尸体终点→魂魄续刑→取窍→逆命进度条
UNCHECKED 五时代区间为任务书笔记级导航未逐段核验；`story-arc-overview.md` 各弧边界仍为约数；E2 稀疏是段落性质还是窗口位置效应未做第二轮对照采样
