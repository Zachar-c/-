# Caveman Review Packet

```text
TASK canon-soul-verification
PHASE RUL-2026-09-19-005 canon verification
STATUS READY_FOR_CANON_REVIEW
TYPE content
ASK L2 裁决 6 条 L0 主张复核表是否可接受，并转交 L1（魂道闭环设计）与 L0（数值裁定）

GOAL
只读核验原文魂道 8 问，行号+短引+判定，不做数值/设计建议
范围外：游戏数据修改、wiki 蒸馏、数值方案

DELTA
+ game/world-model/reports/soul-canon-verification.md（核验报告，Q1-Q8+名词表+L0 复核表）
+ ai-system/tasks/canon-soul-verification-result.md（本包）
~ NONE
- NONE
= L2 预检数字全部复算一致（bare/lines 双口径互洽）

STATE
OpenCode + Muse Spark 1.3 | Wiki/知识工程 VERIFIED；Godot PARTIALLY VERIFIED（本任务纯文本检索，无代码改动）

FILES
game/world-model/reports/soul-canon-verification.md — 新增核验报告
ai-system/tasks/canon-soul-verification-result.md — 新增本包

TEST
focused: quote-budget check → PASS（133 条「」0 超 60 字，合计 1439 字 ≤3000）
relevant: recount script → PASS（魂魄底蕴 187/百人魂 44/千人魂 30/万人魂 62/狼魂蛊 50/落魄谷 380/挡尸蛊 0/撞魂 0/兽魂蛊 0/落魄蛊 1）
full: BLOCKED（Godot 全量与 accept.py 不适用：本任务零代码改动，未运行）
diff-check: PASS（除 2 新文件外零改动；蛊真人-clean.txt 未被追踪）

WORKER
OpenCode + Muse Spark 1.3（L3 Worker）
core patch: NO
tests: YES（计数复算+引用预算）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
R1 挡尸蛊/撞魂零命中：L0 主张#1 悬空，pre-existing（记忆偏差疑），BLOCKED→需 L1 裁决
R2 落魄蛊=地名误读：数据 soul_atk_1_05_gu 名实不符，pre-existing，不阻塞本报告
R3 **占位符遮蔽「迷惘/迷魂」二字：已三处互证解码，残留风险低
UNPROVEN 换魂仙蛊 74 处仅抽查；荒魂后期体系未展开；未读未清洗版蛊真人.txt

GIT
status: 仅 +2 untracked 新文件；预存改动（AGENTS.md/lore wiki/game 等 M 项）未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 接受 6 条复核判定（3 CONFIRMED/1 校准 CONFIRMED/1 NOT_FOUND/1 CONTRADICTED）| recommend YES | 每条有行号证据
D2 Q1 地基成立（魂=可增长存量，12 处跨章节）| recommend YES | 无反向表述

NEXT
1. L2 审阅 soul-canon-verification.md
2. L1 取用：凝魂名录 15 只 + 狼魂蛊链 + 三首选做闭环输入
3. L0 裁定主张 #1（挡尸蛊）去留
STOP

EVIDENCE
game/world-model/reports/soul-canon-verification.md（Q1-Q8 行号+短引；名词表；L0 复核表）
复算：$env:PYTHONIOENCODING="utf-8"; python C:\Users\90877\AppData\Local\Temp\opencode\q.py D
行号法：split('\n') 后 1 起始枚举；原文 437061 行 / 8587697 字 / 23609617 字节
```

FACT 方源靠胆识蛊+落魄谷增长魂魄底蕴至百万人魂级（L182808/L273656）；狼人魂改造需 9 只三转狼魂蛊（L81838/L81920）；炼魂=迷惘雾松散+落魄风切割（L78238）；安魂汤=迷魂湖水（L332474/L369026）；净魂为万我核心（L123194）；命牌/魂灯置武家宗祠（L227566/L250478）
ANALYSIS 魂可成长地基成立；凝魂是目标非第四法；兽魂蛊系概括误记；数据落魄蛊系地名误读；36 只魂蛊无着落方向与 L2 一致
UNCHECKED 未清洗版未读；魂压/荒魂体系未展开；换魂 74 处仅抽查；wiki 魂道蒸馏缺失
