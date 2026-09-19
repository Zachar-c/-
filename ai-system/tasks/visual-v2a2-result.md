# Caveman Review Packet · visual-v2a2-nanjiang（商家城·南疆）

```text
TASK visual-v2a2-nanjiang
PHASE V2 视觉重构 / 子包 2a2
STATUS READY_FOR_L2_REVIEW
TYPE content
ASK L2 复核 24 对象可入库，并放行 2b（中洲）

GOAL
B 阶段 12 窗 × 150 行，只收商家城·南疆（行号 45001–135000），≥16 对象

DELTA
+ ai-system/tasks/visual-library-v2a2.md（24 对象 + 12 窗采样栅格）
+ ai-system/tasks/visual-v2a2-result.md（本包）
~ 无
- 无
= 余下仓库未碰；用户在途改动未碰

STATE
OpenCode + Muse Spark 1.3 / Godot 软件工程 PARTIALLY VERIFIED，Wiki/知识工程 VERIFIED；
本包为纯 lore 只读采集，不涉及代码执行器能力

FILES
ai-system/tasks/visual-library-v2a2.md — 新增，24 对象，栅格 3/2/2/1/2/2/2/2/2/2/2/2
ai-system/tasks/visual-v2a2-result.md — 新增，本包

TEST
focused: 短引行号复核（PowerShell，逐条取「」+ 行号，直读蛊真人-clean.txt 共 437060 行，
  校验该行包含该短引且短引 ≤60 字）→ PASS，46/46 命中，长度 0 超标，行号 0 越界
relevant: 结构自查 → PASS，占位名 0（对象名 24 个，无 行N 结尾）／重复转述 0／
  三层齐全 24/24/24（转述/关键词/评级）／风格词 0（适合做成/水墨/黑暗风/赛博/苏鲁/二次元/画风）
full: BLOCKED，非代码任务，无可跑测试；以真实输出文本为准判定通过（V1）
diff-check: PASS，只新增 SCOPE 内两个文件，未改余下仓库

WORKER
L3 Visual Lore Research Worker（READ ONLY）
core patch: NO
tests: YES（自查脚本，见 TEST）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
B07–B12 窗内容实际多为北原/福地情节（王庭会战、真阳楼、宝黄天），B 阶段行号窗与故事地域
  不完全重合；本包按任务书以行号窗为 scope 收录战斗/传承类对象（pre-existing，非阻塞，
  L2 集成时需决定是否划归 2c）
UNPROVEN NONE（全部短引已逐条复核；评级为显式主观判断，未伪装事实）

GIT
status: 仅新增本 SCOPE 两个文件；余下 M/?? 均为他人在途工作，未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 24 对象入库 | recommend YES | 46/46 短引逐行复核命中，零占位名，零重复转述
D2 B07–B12 北原色对象是否留在本包 | recommend 上抛 L2 | 行号 scope 内但故事地域属北原

NEXT
L2 复核入库 → 派发 2b（中洲）
STOP

EVIDENCE
ai-system/tasks/visual-library-v2a2.md（对象条目 + 采样栅格）
```

FACT 商燕飞白袍金边血发垂腰（行 48616）／锦绣食盒蛊洒七彩华光成宴（行 48626）／彪为背生双翅之虎，
  虎力五倍（行 63682–63692）／宝黄天以宝光丈尺验货，万象星君一群二丈三（行 86116–86118）／
  宝黄天空间荡漾柠檬黄光、无天地山川、货物漂浮（行 123744–123746）。source 均为蛊真人-clean.txt 指定行。
ANALYSIS B 窗覆盖商家城家宴/斗蛊/炼蛊/拍卖（宝黄天）/传承（真阳楼/都敏俊/血道皇宫）/商战议价
  （荒兽蝙蝠残尸九块半仙元石）全链条；坊市 0 命中与任务书一致，未收录。
UNCHECKED B04 窗仅产出仇九 1 对象（余为宙道/福地论述，无具体视觉对象）；B 窗北原归属待 L2 裁决。
