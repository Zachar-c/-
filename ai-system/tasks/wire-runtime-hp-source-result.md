# Caveman Review Packet

```text
TASK P2.1 wire-runtime-hp-source
PHASE P2 收尾
STATUS READY_FOR_RUNTIME_HP_REVIEW
TYPE implementation
ASK L2 裁决三事：① 存档兼容（旧档 80 留 80 还是迁移 100）；② test.ps1 系 harness 在 pwsh 7.6 是否修（不修则门禁命令长期 RC=1）；③ 本包 PASS 可否进 P3。

GOAL
runtime 开局气血接唯一真源（player_start_hp=100），闭合“模型 100 / 可玩 80”漂移。范围外：一切其他数值、balance.json、派生镜像、资质→HP 耦合（均未动）。

DELTA
+ RunState.apply_start_hp(state, cat)：读 GuBalance.player_start_hp 写 health/max_health/cultivator 双键
+ WorldModelBridge.starter()：balance entities[0].run.starter 只读访问点
+ test_runtime_start_hp_matches_config_and_world_model：三处相等断言 + SABOTAGE 负控
+ const START_HP_FALLBACK := 100（具名回退，注释绑 player_start_hp 与 RUL-009）
~ run_controller 双入口（start_new_run:196 / start_m0_run:224）各加一行 apply_start_hp；new_run 签名不动
~ v1-battle-schema.md:18 → hp 100 + RUL-009 注记
~ 13 个测试文件 27 处夹具 80→100 系（分类见 EVIDENCE，零真实语义依赖）
= balance.json / world-model/data/** / 资质·真元·经济·敌人·伤害管线：未动
- run_state.gd 5 处裸 80（含注释）：清零

STATE
OpenCode + Muse Spark 1.3 / Godot PARTIALLY VERIFIED（本任务内：接线+门禁实证通过）

FILES
game/scripts/domain/run_state.gd — 裸字面量清除 + apply_start_hp
game/scripts/presentation/run_controller.gd — 双入口接线（+2 行）
game/scripts/domain/world_model_bridge.gd — starter() 访问点（+15 行）
game/tests/unit/test_world_model_bridge.gd — 一致性断言 + _wm_starter 负控
game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md — 100 口径对齐
13× game/tests/unit/*.gd — 仅失败夹具值更新（清单见 EVIDENCE）

TEST
focused: GUT直调 test_world_model_bridge.gd → 9/9 PASS，27 asserts（含新断言 7×100==100）
focused: GUT直调 test_contracts_min.gd → 16/16 PASS
full: GUT直调 tests/unit 全量 → 219 scripts / 1603 tests / 54061 asserts / 0 FAIL / SCRIPT ERROR 0
relevant: GUT直调 tests/integration → 12 scripts / 56 tests / 1723 asserts / 0 FAIL / SCRIPT ERROR 0
python: accept.py --smoke 10 → 退出码 0（校验+41用例+10局冒烟全绿）；check_upstream_drift.py → 5204 项 / 0 漂移
diff-check: rg裸80（= 80 / : 80 / 80,）于 run_state/run_controller/bridge 三文件 → 0 命中；apply_start_hp 不读 aptitude
negative: SABOTAGE=true → 5/9 FAIL（含 [-999] vs [100] starter.hp）；复位 false → 9/9 PASS；文件中 SABOTAGE=false 已确认

WORKER
OpenCode + Muse Spark 1.3（normal）
core patch: YES
tests: YES
protocol: YES（快照 runtime-hp 已 take；零 commit/push/stash/reset）
Codex takeover: NONE
independent: YES

RISK
1. test.ps1 系 harness 在本机失效（pre-existing，非本任务引入）：run_gut_checked.ps1:16 的 @() splat 使 --headless 等参数被吞，GUT 零输出 RC=1；同法跑未动文件 test_dda_resolver.gd 同样失败。pwsh 7.6.6。以上 Godot 结论均由与 harness 等价的 Godot 直调命令取得（参数逐字一致，仅绕开 splat）。是否修 harness 属基础设施变更，未动，请 L2 裁决。new/pre-existing = pre-existing；阻塞官方验收命令 = YES（内容等价验证已做）。
2. 旧存档兼容（调查完毕，未加迁移逻辑）：_state_from_save_data 以存档值覆盖，旧档 80 载入仍是 80，新开局 100。同档混跑无崩溃风险，但数值语义分叉。DECISION 需 L2/用户裁决。BLOCKED = NO（任务明令只调查上报）。
UNPROVEN NONE（starter.hp=100 已由 accept 链与门禁双重实证；除 run_state.gd 外无第三 runtime 来源已由 rg 全 scripts 确认，v1_battle_resolver 只读 run_state.max_health）。

GIT
status: 对比执行前，仅本 SCOPE 文件新增 M（6 任务文件 + 13 失败夹具测试）；其余 M/?? 均为执行前已存在（P2 产出与在途 wiki）。world-model/reports 两文件内容系 accept.py 验收副产物刷新，无新增路径。
commit: NONE
merge: NONE
push: NO

DECISION
D1 旧存档 80 是否迁移 100 | recommend NO（默认） | 新开局已 100；静默改旧档数值属产品语义变更，超出 Worker 授权；且当前载入路径无崩溃
D2 是否修 run_gut_checked.ps1 splat 缺陷 | recommend YES（另起任务） | 否则官方门禁命令在本机永远 RC=1，P3 验收受累；修法仅限 harness 传参，不碰测试语义
D3 本包能否 PASS 进 P3 | recommend YES | 漂移闭合 + 三处相等门禁 + 全量 unit/integration 绿

NEXT
1. L2 裁决 D1–D3
2. 若修 harness：另起 infra 任务验证 test.ps1 全链 RC=0（含负控 FAIL）
3. 进 P3 统一 Effect 管线
STOP

EVIDENCE
- 真源：game/data/balance.json player_start_hp=100；镜像 game/world-model/data/balance.json entities[0].run.starter.hp=100/hp_source=player_start_hp
- 接线先例同构：run_controller.gd:197 essence_max / :199 apply_start_hp；:227 / :229 同理
- 夹具分类（全 夹具写死80，无真实语义依赖；dmg/代价算式语义不变，仅基线 80→100）：
  battle_command_facade:114/179 78→98（敌2伤）；contracts_min:211-213 78→98（essence_tide -2），:222 -80→-100（保致死场景意图）+:232 80→100；curse_system:233 79→99（代价-1）；event_pool:52 78→98（代价-2）；q8_12:105 80→100（sealed 门禁零伤），:116 79→99（3-2=1）；grammar:165 79→99，:187/:205 80→100，:286 77→97；survivability:28 77→97，:41 80→100；scenarios:49 77→97，:63 74→94，:106 80→100，:120 74→94，:137 72→92；rest_generic:45 27→33（3+30%×100）；rest:24 28→34（4+30%×100），:39 公式内 80→100；t5d:229-230 80→100（clamp 上限）；mounted:60 表达式 80-2→100-2；resolver:23 80→100，:179/:186 表达式 80-3/80-5→100 系；v3_relic:52 79→99（代价-1）
- 日志：bridge_green.log（9/9）、sabotage.log（5/9 FAIL，starter.hp [-999]vs[100] 在列）、unit_all2.log（1603/1603）、integration.log（56/56）、accept/drift 控制台（0/0）
- 快照：game/world-model/.snapshots/20260919T222953-runtime-hp（51 文件）
```
