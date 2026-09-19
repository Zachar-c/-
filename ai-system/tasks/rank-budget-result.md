# Caveman Review Packet · P2 Rank Power Budget

```text
TASK rank-power-budget (P2 · RUL-2026-09-19-008 D2/D11/D12)
PHASE P2 Rank Power Budget + HP 基准
STATUS READY_FOR_RANK_BUDGET_REVIEW
TYPE implementation
ASK L2 确认三事：①预算口径与归位标注可合入 ②HP 80→100 平衡变动接受（已知副作用留档）③Godot run_state.gd 残留 80 是否另开任务

GOAL
立唯一 rank_power_budget 真源（40/80/160/320/640 零漂移）+ 六套曲线归位标注 + HP SoT 100。
范围外：蛊效果/真元/经济/敌人/难度数值一律未动；L1 留白四项未碰。

DELTA
+ 上游 rank_power_budget（公式+rank1=40+预算表+轴注）/ HP 显式对（standard 100/player 100/ratio 1.0）
+ 派生 growth.rank_power_budget（构建器按公式重算并交叉核对）/ rank_axis_annotations（8 条）
+ GuBalance.rank_power_budget/rank1_budget/standard_human_hp/player_start_hp 唯一访问点
+ validator 第 6 节 27 断言；py 新增 2 用例；gd 新增 test_rank_power_budget.gd（7 用例）
~ standard_gu_power 改委托 budget（数值恒等）；starter hp/hp_max 80→100（显式派生）；economy health 80→100
= 真元/经济/boss/进阶/兽参照数值全未变；beast_scale 公式未动（只标注）

STATE
OpenCode + Muse Spark 1.3 — Godot 软件工程 PARTIALLY VERIFIED（低风险可用，已过全量 unit，需 Codex Review）

FILES
game/data/balance.json — 上游真源：rank_power_budget + HP 对 + rank_axis_annotations
game/world-model/tools/build_world_model.py — 派生预算/HP（删裸字面量 80，公式重算+交叉核对，中断式防漂移）
game/world-model/data/balance.json — 构建器重生成（含 §6 断言所需字段）
game/world-model/data/economy.json — health 起点/上限 80→100（构建器派生）
game/world-model/data/manifest.json — 随重生成更新哈希（仅 balance/economy 实变，其余文件已用原 generated_at 压回零 diff）
game/scripts/domain/gu_balance.gd — 唯一访问点 + 口径三读法注释（具名表与公式一致时读表，否则公式为准，保调参跟随红线）
game/scripts/domain/cultivator_rules.gd — body 改读 standard_human_hp + player_start_hp 薄委托（零新公式）
game/world-model/tools/validate_world_model.py — §6 可执行断言（预算公式 + 8 轴标注 + HP 对）
game/world-model/tests/run_tests.py — full_run hp 断言跟 starter；新增 budget/axis 2 用例
game/tests/unit/test_rank_power_budget.gd — 新增 7 用例（锚点/恒等/无量纲/跟随配置/上游表/HP）

TEST
focused: python game/world-model/tools/validate_world_model.py → PASS（64635 检查/0 失败，§6 27/27）
focused: python game/world-model/tests/run_tests.py rank_power_budget rank_curves full_run → PASS（3/3）
relevant: python game/world-model/tools/accept.py --smoke 10 → PASS（校验+41/41+冒烟 10/10）
relevant: python game/world-model/tools/check_upstream_drift.py → PASS（5204 项/0 漂移）
relevant: Godot -gtest test_world_model_bridge.gd → PASS（8/8，20 断言）
relevant: Godot -gtest test_rank_power_budget/test_central_numbers/test_gu_balance_schema/test_resolver_growth_gate → PASS
full: Godot 全量 unit → PASS（219 脚本/1602 用例/54054 断言/0 失败；Orphans 2/ObjectDB 8 为既有残留）
diff-check: git diff --check → PASS（零空白错误）
negative-1: 预算 rank3 改 999 → validate_world_model.py FAIL（退出非零，符合预期，已重建恢复）
negative-2: 桥门禁 SABOTAGE=true → FAIL（退出 1，符合预期，已恢复 false，文件零内容 diff）
rg: 转数公式实现仅 gu_balance.gd（含注释），其余为委托消费；build_world_model.py 无 "hp":80 裸字面量

WORKER
OpenCode + Muse Spark 1.3
core patch: YES
tests: YES
protocol: YES
Codex takeover: NONE
independent: YES

RISK
HP 80→100 是真实平衡变动（D11 默认，已按任务要求执行）：同种子 200 局通关率 68.0%→70.0%（136→140 胜），
气血耗尽死 3→0，终局气血均值 66.8→87.6，其余（节点 39.7→40.0/战斗 12.8→13.0/死亡层扁平/魂崩散 61→60）基本不动。
Godot scripts/domain/run_state.gd:112-113 仍有 health/max_health 80 硬编码（SCOPE 外，未碰）——与世界模型 100 分叉，
pre-existing 风险，不阻塞本阶段，需后续任务接线（NEXT-1）。
world-model/reports/*.md（validation/balance-simulation）为验收命令生成物，随验收更新，非手改。
UNPROVEN NONE（预算恒等已由双端断言实证；beast_scale 基数分歧按任务只标注，L1 未裁，未动）

GIT
status: 在途脏文件均为 SCOPE 内（上游 balance/构建器/校验器/GuBalance/测试/派生 data 3 文件/验收报告）；
  预存用户改动（AGENTS/PROJECT_MAP/wiki/loot_resolver 等）零触碰；bridge 测试文件零内容 diff
commit: NONE
merge: NONE
push: NO

DECISION
D1 HP 取 100（D11 默认）| recommend YES | 无产品弱小开局意图，RUL 明令先按 100，副作用已量化留档
D2 beast_scale 基数不动只标注 | recommend YES | L1 未裁，任务明令须改则停止上报——实测无需改即自洽
D3 standard_gu_power 保留为具名委托投影 | recommend YES | 调用方（fixed_defense/战斗）零改动，数值恒等已双端断言

NEXT
1. P3 统一 Effect 管线（L1 最高优先，802 蛊 + 468 配方，建议拆批）
2. 另开小任务把 run_state.gd 80 接到 GuBalance.player_start_hp（含 Godot 冒烟回归）
3. L2 把 §6 断言登记进 CONSTRAINTS-V2（R5 预备）
STOP

EVIDENCE
game/data/balance.json:9-35（真源对）| build_world_model.py:_rank_power_budget（公式重算）
game/world-model/data/balance.json:growth.rank_power_budget/run.starter（hp 100/hp_source）
validate_world_model.py:check_rank_budget（§6）| game/tests/unit/test_rank_power_budget.gd
C:/Users/90877/AppData/Local/Temp/opencode/rank-budget-baseline-before.md（68.0%）/ -after.md（70.0%）
```
