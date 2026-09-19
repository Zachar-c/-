# Caveman Review Packet

```text
TASK visual-v2-batch1-library
PHASE 批次 1 素材库
STATUS READY_FOR_REVIEW
TYPE content
ASK L2 确认素材库可进批次 2（专题/母题/Top30），或打回补采

GOAL
建《蛊真人》视觉素材库：五阶段 ≥103 对象，六字段齐全，
行号 + ≤60 字短引可 grep 复核，事实/转译/评级三层可辨，
无画风结论。范围外（专题、母题、Top30）全部留批次 2。

DELTA
+ ai-system/tasks/visual-library-v2.md（103 对象 + 66 窗栅格 + 关键词词表）
+ ai-system/tasks/visual-v2-batch1-result.md（本包）
= 其余全未动；game/**、lore/wiki/** 零触碰

STATE
OpenCode + Muse Spark 1.3 | Godot: PARTIALLY VERIFIED | Wiki/知识工程: VERIFIED
本任务纯文本采集，只用 VERIFIED 能力（读原文、写 markdown、跑校验脚本）

FILES
ai-system/tasks/visual-library-v2.md — 新增，1467 行，103 对象
ai-system/tasks/visual-v2-batch1-result.md — 新增，本包

TEST
focused: vis_check.py → PASS（103 对象 / 103 短引原文命中 / 0 超 60 字 /
  事实-转译-评级 103-103-103 / 原文未提供 444 / 禁词 0 / 栅格 66 行）
relevant: vis_build.py 内断言（短引原文子串 + ≤60 字）→ PASS，103/103
full: 无代码改动，无测试套件可跑 → BLOCKED（decisive reason：本批 READ ONLY，
  不产代码；校验脚本即验收）
diff-check: PASS（见 GIT）

WORKER
normal Worker（L3 Visual Lore Research）
core patch: NO
tests: YES（校验脚本，非项目测试套件）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
1. E 窗九转/命运各只 1 对象（窗内命中本来就少：九转 7、命运 4），
   后期尊者主题欠账仍在 → pre-existing（采样覆盖所致），不阻塞本批，
   批次 2 可定向加窗。
2. 16 个对象名 fallback（窗口对象·行 N），多为抽象议论行 → 已知弱项，
   不阻塞（行号 + 短引照样可验），批次 2 专题分析时可剔换。
3. 字段为机械切片（分句 ± 截断），措辞糙但零想象补全 → 不阻塞，
   符合「先保数量与均衡」预算令。
UNPROVEN NONE（★ 评级是明示判断，非事实断言；无风格结论）

GIT
status: 本任务只新增 SCOPE 内 2 个 untracked .md；执行前已脏的工作树
  （game/**、ai-system/RESEARCH-REQUEST* 等 M/??）全部原样保留，未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 103 对象进批次 2 | recommend YES | 五阶段配额全达标，
  短引 103/103 可复核，无禁词，栅格齐全
D2 E 九转/命运单薄是否打回 | recommend NO | 窗内命中本就稀少，
  强行加采会打破 66 窗栅格口径；留批次 2 定向处理

NEXT
1. L2 抽查短引 grep（抽 10 条即可）
2. PASS 后开批次 2（专题/母题/Top30）
3. 缺口（九转/命运）进批次 2 加窗清单
STOP

EVIDENCE
ai-system/tasks/visual-library-v2.md（§0 栅格，§A–E 对象，§2 配额自检）
校验脚本：C:\Users\90877\AppData\Local\Temp\opencode\vis_check.py（仓外，不进 Git）
复核命令：grep -n -E "^第.{1,8}节|^章节目录 " 蛊真人-clean.txt（2345 标记）
```

FACT 原著 437060 行（`蛊真人-clean.txt`，未跟踪）；66 窗 ≈ 19800 行约 4.5%；C 锚点 144602/176006/238200/313540/357768，D 北原/西漠/东海各 5 锚点；短引 103/103 为原文子串且 ≤60 字；`中洲` 2232、`北原` 2404、`西漠` 813、`东海` 1611 次命中（L2 台账，本批未重算）
ANALYSIS 机械切片保诚实但色形材三栏常同源（原文一句多义）；C 中洲味足（主题词 61），D 三地域词 19/15/12 均衡，E 尊者/天庭/仙蛊屋/杀招齐、九转/命运各 1 系窗内稀少所致；星级 16/37/28/18/4 呈纺锤形，★★★★★ 全部由短引内月光蛊/光阴长河/天庭举证
UNCHECKED 地域词命中数与章节 2345 系沿用 L2 台账值，未重跑；E 窗外九转/命运富集区位置未知，待批次 2 定向定位
