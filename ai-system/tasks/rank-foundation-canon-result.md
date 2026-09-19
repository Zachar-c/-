# Caveman Review Packet

```text
TASK rank-foundation-canon
PHASE 原文依据→建wiki（设计工作流第1–2步）
STATUS READY_FOR_REVIEW
TYPE content
ASK L1能否以“原文给形状不给倍数”为前提设计1–5转数值曲线；Q1唯一性边界与Q3资质表述是否可用作全局约束

GOAL
1–5转原文依据挖全挖准 + 系统验证有无量化表述；CONFIRMED条目蒸馏进修炼体系页；不做数值建议
范围外：魂道、游戏数值、6转以上灾劫周期（仅维持既有条目）

DELTA
+ game/world-model/reports/rank-foundation-canon.md（新建，Q1–Q8证据报告）
+ lore/wiki/world/cultivation-system.md 原著明确内容追加5条（凡仙分界/五档真元/比例与资质/流通身份/蛊师蛊关系）+ 待核对追加1条（颜色销项+四项NOT_FOUND留待）
= 既有内容零改写（diff vs HEAD仅有的2个删除行是开工前在途改动的魂道相关页面链接，非本批）
= 未新建wiki页、未改index、未碰game/data与ai-system其他文件

STATE
OpenCode + Muse Spark 1.3 | Wiki/知识工程 VERIFIED | 原文检索工具仅标准库+rg语义（Python 3.13.12直读clean txt）

FILES
game/world-model/reports/rank-foundation-canon.md — 新建证据报告
lore/wiki/world/cultivation-system.md — 追加6条（5事实+1待核对）
ai-system/tasks/rank-foundation-canon-result.md — 本结果包

TEST
focused: pwsh -NoProfile -File lore/wiki/tools/check.ps1 → ALL CHECKS PASSED（check1 34/34，check2 96/124 WARN28 FAIL0，check3 29/29，check4 444/444，check5/6/7 PASS；WARN全是source/本地缺失的已知项，非本批引入）
relevant: git diff -- lore/wiki/world/cultivation-system.md → 本批0删除（2删除行是在途魂道链接改写，开工前已存在）
full: BLOCKED（本批只读+2文件，不跑Godot全量；无容量做）
diff-check: PASS（新增文件1个 untracked，clean txt未进status）

WORKER
OpenCode + opencode/muse-spark-1.3-contributor-free
core patch: NO
tests: YES
protocol: YES
Codex takeover: NONE
independent: YES

RISK
L2行号两处出入已纠正：唯一性定义句实为69622非69624；1:10比例句实为4258非3608–3613。影响：后人按L2旧行号查不到，下游引用须用本报告行号。pre-existing。
1358甲等元海比例处`**成`清洗占位符，数字缺失，引用时须注明。pre-existing。
转数词频occurrence口径复算与L2完全一致（671/696/1077/1050/1388/1583/2604/4451/1021），无风险。
UNPROVEN NONE（NOT_FOUND结论均附检索式，可独立复算）

GIT
status: M lore/wiki/world/cultivation-system.md（在途+本批追加）；?? rank-foundation-canon.md（本批）；?? rank-foundation-canon-result.md（本包）；clean txt未出现；其余M/??均为开工前在途，未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 接受“原文无通用转数倍数表，L1按形状设计曲线” | recommend YES | Q4八组检索式全跑，通用表0命中，孤立比例句已逐条定为个案
D2 把Q3资质上限表用作全局约束 | recommend NO | 该表是古月师学堂口吻+倾向措辞（往往/通常/甚至），甲等到五转无“最高”限定，须L1裁决
D3 仙蛊唯一按“同种同时一只、可再生”理解 | recommend YES | 76284神游转定仙游例为直接证据

NEXT
L2送L1评审量化曲线妥协方案
Wiki颜色待核对销项（本批已附语句）
STOP

EVIDENCE
game/world-model/reports/rank-foundation-canon.md（Q1–Q8行号+短引+检索式）
lore/wiki/tools/check.ps1输出见本包TEST
```

FACT 凡仙分界：1–5转为凡、6–9转成仙，五处复述无例外（50192/60582/16276/20672/70034）；仙蛊同种同时唯一、可转化再生（69622/76284）。source:蛊真人-clean.txt
FACT 五档真元：一青铜二赤铁三白银（3612/4258），四黄金（8536/50312），五紫晶分四小阶（70356），全称对照87532；舍利蛊同五档且无仙品（86506）。source:蛊真人-clean.txt
FACT 比例与资质：赤铁抵十份青铜、白银抵十份赤铁仅限1–3转（4258）；丁1–2/丙2/乙3–4/甲5转倾向表述（1358/1360，甲等`**成`残缺）。source:蛊真人-clean.txt
FACT 流通身份：四转难买、五转不流通、仙蛊唯一（69304）；金/紫舍利蛊严苛管禁（86508/65440/65444/333200）；三转家老/四转族长/五转山主跨寨通则（4958–4960/7120/1392）。source:蛊真人-clean.txt
FACT 蛊师蛊关系：同转配用常态，越级催动惨重代价+喂养不起（1474–1478/21664）；寿元与境界无直接帮助（90602/140256）。source:蛊真人-clean.txt
ANALYSIS 原文给阶梯形状（材质/资质上限/稀缺/身份）不给通用实力倍数；Q4所列“耐用三倍/月芒三倍/上百倍”等全是个案比较或文学比喻，不可拼成转数公式。通用倍数表/常规破境成本表/分转价格表/分级越级后果四项NOT_FOUND本身即L1设计前提。
UNCHECKED 七转以上灾劫周期；吞窍取道痕边界；灾劫-道痕数量流派精确对应；资质表能否升为全局约束待L1裁决。
