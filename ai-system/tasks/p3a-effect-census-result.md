# Caveman Review Packet

```text
TASK p3a-effect-census
PHASE P3-A (P3 preparation, pre-L1-ruling)
STATUS READY_FOR_P3A_REVIEW
TYPE implementation (census tooling + report) + bugfix (F1/F2/F3 test hardening)
ASK L2 确认普查数字可直接喂 L1 裁定，并把 F1/F2/F3 收入 P2.1 关账

GOAL
P3 数值公式等 L1 回复前，只摆事实：Effect 预算普查器 + 五节报告；
叠加 P2.1 三个 follow-up（F1 回退常量绑死 / F2 真实入口断言 / F3 夹具文案）。
范围外：任何效果数值、兜底表、archetype、分配系数、倒挂判据一律未动。

DELTA
+ game/world-model/tools/audit_effect_budget.py（只读普查器，标准库 only，可复用升级成 CONSTRAINTS-V2 R5 断言）
+ game/world-model/reports/effect-budget-census.md（五节齐全，数字全由脚本实算）
~ game/tests/unit/test_world_model_bridge.gd（F1 +1 断言，F2 +1 用例）
~ game/tests/unit/test_q8_grammar_pipeline.gd（F3 仅注释/断言消息，值不动）
= game/data/** 零改动（M 的 balance.json 是 P2 预存改动，非本任务引入）

STATE
OpenCode + Muse Spark 1.3 / Godot 软件工程 PARTIALLY VERIFIED（低风险任务可用；本包经 console 版实测 + L2 级负控）

FILES
game/world-model/tools/audit_effect_budget.py — 新增只读分析器（--report/--json，退出码只反映 IO/解析错）
game/world-model/reports/effect-budget-census.md — 新增报告（①兜底vs预算 ②覆盖矩阵 ③双口径倒挂 ④字段面 ⑤豁免路径）
game/tests/unit/test_world_model_bridge.gd — F1: START_HP_FALLBACK==player_start_hp 绑死；F2: start_new_run 入口断言 health/max_health
game/tests/unit/test_q8_grammar_pipeline.gd — F3: 30/80→30/100、50/80→50/100，显式标注 50/100 卡 0.5 刀锋值（有意保留边界覆盖）

TEST
focused bridge: console 直调 -gtest res://tests/unit/test_world_model_bridge.gd → 10/10 passed, 30 asserts, exit 0（P2.1 基线 9/9+27；+1 用例 F2，+3 断言 F1/F2）
sabotage 负控（SABOTAGE=true 临时开→跑→已还原 false）: 4 failing / 6 passing, 25/30 asserts, exit 1 → 门禁真有区分力
focused q8: test_q8_grammar_pipeline.gd → 21/21 passed, 75 asserts, exit 0
relevant: accept.py --smoke 10 → 三关全绿 exit 0（校验/测试 41-41-0/冒烟 10/10）；check_upstream_drift.py → 5204 项/0 漂移 exit 0
full: -gdir res://tests/unit → 219 scripts / 1604 tests / 1604 passing / 54064 asserts / 0 failing, exit 0, SCRIPT ERROR 0, Orphans 2 / leaked 8（与 L2 记录的既有残留同值）
diff-check: PASS（game/data/** 无本任务改动；快照 p3a-census 已取）
stability: 普查器连跑两次输出逐字节一致

WORKER
OpenCode + Muse Spark 1.3 (worker class normal)
core patch: NO（零生产代码改动，纯测试+工具+报告）
tests: YES
protocol: YES（预读 AGENTS/PROJECT_MAP/目标规则/交接模板；git status 先行；禁碰用户在途两文件）
Codex takeover: NONE
independent: YES

RISK
pre-existing: 全量 Orphans 2 / ObjectDB leaked 8，既有残留非本任务引入，不阻塞
pre-existing: game/data/balance.json 的 M 是 P2 预存（28 行 rank budget），本任务叠加上游未重算其内容
UNPROVEN NONE（倒挂判据、分配公式明确留待 L1，报告内零裁决语句）

GIT
status: 本任务足迹仅 SCOPE 内 4 文件（2 改 2 新增）+ 本结果包；其余 M/?? 均为会前已存在的他方改动，未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 普查器口径（coarse 1 候选 attack/strike r3 max2<r1 max4；同代价分组后 0 候选；代价缺失 essence 50/true_qi 58/feeding 47 只）是否如实可用 | recommend YES | 双口径分别列出+缺失统计，L1 可直接判定同代价口径
D2 F3 保留 50/100 刀锋值（只改文案）而非挪开边界 | recommend YES | 严格小于在等值处的语义正是边界覆盖，挪值反丢用例
D3 test_slay_gu 豁免清点不动数据 | recommend YES | S2 slay_gu_ten 载体，删改禁令遵守

NEXT
1. L2 把本包数字转交 L1 作 Effect Budget 裁定依据
2. L1 回复后把 audit_effect_budget.py 升级成 CONSTRAINTS-V2 R5 可执行断言（P3-B）
3. 关账后由用户确认再 commit（worker 不推）
STOP

EVIDENCE
game/world-model/reports/effect-budget-census.md（§1–§5 + Reproduce 命令）
game/world-model/tools/audit_effect_budget.py（census()/md() 纯函数，判据未定时只输出事实）
GUT 原始输出：bridge.txt / bridge_sab.txt / q8.txt / fullunit.txt（C:\\Users\\90877\\AppData\\Local\\Temp\\opencode\\）
快照：game/world-model/.snapshots/20260919T230735-p3a-census
Godot 跑法：Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64_console.exe --headless（非 console 版静默假绿，已避开）
```
