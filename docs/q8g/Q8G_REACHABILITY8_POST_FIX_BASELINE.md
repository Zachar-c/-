# Q8-G / R8：start 泄漏修复后的真实基线（2026-09-13）

> 性质：**玩家可见规则 bug fix（已提交）** + 修复后 measurement-only 语料重建。
> 本文件不构成任何 G1 / M / G / T 经济施工许可。
> 生产规则（pity / E6 / pacing / battle / loot）在本轮**零修改**。

---

## 1. 修改文件

| 文件 | 改动 |
| --- | --- |
| `data/nodes.json` | 删除 `neutral_wanderer` 与 `ridge_caravan` 两个模板的 `start` 字段（−2 行） |
| `tests/unit/test_five_layer_map_contract.gd` | 新增 2 个回归守卫（+49 行） |

提交：

```text
29286071  fix(map): drop legacy start flag from neutral_wanderer and ridge_caravan templates
          data/nodes.json                            |  2 --
          tests/unit/test_five_layer_map_contract.gd | 49 ++++++++
```

改动面核对（逐字段 diff HEAD 与工作树）：37 个模板 id 集合一致，**唯一差异**就是这两个模板少了 `start`；
其余 35 个模板逐字段完全一致。

未修改（按裁定）：`map_generator.gd`、其他节点、连边、pacing、敌人、loot、pity、RunState、事件、存档、UI。

新增的两个守卫：

```text
test_node_templates_do_not_carry_legacy_start_field
    数据层断言：任何节点模板都不得声明 start
test_start_flag_is_confined_to_layer_one_entry_row
    绝对契约：每个 start 节点必须在 layer==1 && row==0，且每张图至少 1 个入口
    （原 test 只断言 reachable == is_start，镜像同一 flag，对泄漏零分辨力）
```

---

## 2. 验收命令与结果

PowerShell 沙箱会拦截/吞掉 Godot 子进程，`tools/test.ps1` / `tools/check.ps1` 在工具沙箱内
1 秒即返回（rc=1，非真实结果）。以下命令改为在 Bash 中按 `check.ps1` 的**同一条流水线逐段执行**，
退出码为 Godot 原生退出码。

| 阶段（对应 `check.ps1` 顺序） | 命令 | 退出码 | 结果 |
| --- | --- | --- | --- |
| guitkx_build | `-s scripts/guitkx_build.gd` | 0 | `compiled=0 errors=0 held=0 total=16` |
| unit | `-s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2` | 0 | **Tests 1441 / Passing 1441 / Failing 0**（Asserts 47737） |
| integration | `... -gdir res://tests/integration ...` | 0 | **Tests 32 / Passing 32 / Failing 0** |
| 启动探针 | `--headless --path . --quit-after 3` | 0 | OK |
| 契约漂移 | `-s tools/check_contract_drift.gd` | 0 | `contract drift: ok (168 identifiers resolved)` |
| `git diff --check` | — | 0 | 无空白错误 |
| R8 B1 地图审计 | `-s tools/q8g_reachability8_b1_map_audit.gd` | 0 | 见 §3 |

### 2.1 未通过的包装层判定（**既有问题，非本次引入**）

`tools/run_gut_checked.ps1` 除原生退出码外还会扫描 `Parse Error / Ignoring script / Nothing was run / SCRIPT ERROR`。
unit 日志命中 **2 条 `SCRIPT ERROR`**，因此包装层会把 unit 判为 FAIL（→ `check.ps1` 会在 unit 段 exit 1）。

两条 `SCRIPT ERROR` 的来源与本修复无关：

```text
[1] test_slay_gu_final_chapter.gd:149  test_slay_gu_catalog_entry_is_test_only
    Trying to assign value of type 'float' to a variable of type 'Dictionary'
    成因：工作树未提交的 data/loot_tables.json 新增顶层键 school_material_resonance=5；
    Godot JSON 解析把数字一律读成 float，而该测试遍历 loot_tables 根对象所有 value
    并赋给 var table: Dictionary。该测试与 data/nodes.json 无任何耦合（不构建地图）。

[2] battle_screen_view.gd:941  BattleScreenView._clear
    Attempted to free a locked object（经 test_wenzhen_card_fsm.gd 触发）
    成因：既有 UI 生命周期问题，与地图/start 无关。
```

两个来源文件（`data/loot_tables.json`、`battle_screen_view.gd`、`test_slay_gu_final_chapter.gd`）
都不在本次允许修改范围内，**未做任何改动**。GUT 自身判定为 1441/1441 全通过、0 失败。

---

## 3. R8 B1 地图审计（修复后）

```
非 L1 起手的种子数: 0 / 16           （修复前 15/16）
起手层直方图: { 1: 22 }              （修复前 {1:40, 2:8, 3:8, 4:16, 5:15}）
起点总数 22，其中 L1 以外 0 (0%)      （修复前 47/87 = 54%）
契约违规起点数: 0  => start_contract=OK
确定性自检: seed 606/11/33 fingerprint identical=true => determinism=OK
```

每 seed 起点明细：16 个 seed 全部含 `L1R0N0`；其中 6 个 seed（202 / 303 / 606 / 909 / 1212 / 1313）
的 row 0 有 2 个节点，故同时含 `L1R0N1`。两者都满足 `layer==1 && row==0`，是生成器契约内的合法入口，
**不是**泄漏残留。

审计工具本轮增强（未提交，仍为实验工具）：新增 `row` 采集与「起点绝对断言」段，
以及每 seed 起点明细，使 22 vs 16 的差异可逐条对账。

---

## 4. 32 局真实基线（PRE 污染语料 vs POST 修复语料）

两组语料同 seed、同流派、同协议（`PLAYTHROUGH_FULL=1`、`PLAYTHROUGH_COMBAT_FIRST=1`、
`PLAYTHROUGH_E6_TIER_AUDIT=1`，`--mode=play`）。
污染语料已保留在 `%TEMP%/gu-zhenrens-r5-logs-PRE_START_FIX/`；新语料写入 `%TEMP%/gu-zhenrens-r5-logs/`（32/32 退出码 0）。

### 4.1 起手层

```text
PRE  entry layer histogram: {1:18, 2:2, 3:2, 4:10}   非 L1 起手 14/32
POST entry layer histogram: {1:32}                   非 L1 起手  0/32
POST 起手节点: 32/32 全部为 L1R0N0
```

### 4.2 战斗数量与分层分布

```text
                      PRE      POST
battles total         484      619
min / median / max    3/16/24  5/20/29
short runs (<15)      14       5
battles by layer      {1:68, 2:98, 3:100, 4:115, 5:103}   {1:145, 2:165, 3:148, 4:98, 5:63}
battles by tier       {unsettled:174, elite:150, boss:79, common:81}
                      {unsettled:225, elite:151, boss:88, common:155}
```

tier 份额：

```text
common  81/484 = 16.7%  ->  155/619 = 25.0%
elite  150/484 = 31.0%  ->  151/619 = 24.4%   （绝对场次 150 -> 151，未下降）
boss    79/484 = 16.3%  ->   88/619 = 14.2%
```

**关键事实：Elite 绝对暴露没有下降（150 → 151）。** 份额下降只是因为总战斗数变多。
这直接冲击 G1 K=2 的前提——G1 的全部代价就是「买 Common 机会，花掉 Elite 暴露」。

### 4.3 时序、撤退与漏斗

```text
                                    PRE    POST
retreats total                      348    450
refinement visits                    90     98
common before first refinement       14     73
common after last refinement          9      8
f1_zero runs                          8      2
f1_count total                       43     63
mat_ready / full_ready            70 / 42  88 / 70
attempts / successes             47 / 47  72 / 72
gate_b PASS runs                      9     15
gate_c PASS runs                      4      8
```

### 4.4 f1=0 局的逐个变化

```text
PRE  f1=0（8 局）: force/1111, force/1212, force/20260927, force/909,
                   sword/11, sword/1212, sword/33, sword/606
POST f1=0（2 局）: force/20260927（13 场）, force/303（20 场）

修复：7 局转为 f1>0（含 B1 审计预测的 6 个 L3/L4 泄漏入口局全部转正）
新增：1 局（force/303）由 f1>0 变为 f1=0
净变化：8 -> 2
```

`force/20260927` 是 B1 审计预测「L1 入口、仍会失败」的两局之一，修复后确实仍失败；
另一局 `force/1111` 转为通过。新增失败的 `force/303` 有 20 场战斗，**不是短局**。

### 4.5 短局人口

```text
PRE  (<15 场) 14 局: force/11(12), force/1212(9), force/33(8), force/606(3), force/808(12),
                    force/909(9), sword/11(9), sword/1212(9), sword/202(12), sword/20260927(13),
                    sword/33(8), sword/606(7), sword/808(12), sword/909(8)
POST (<15 场)  5 局: force/20260927(13), force/11(12), force/707(13), sword/202(12), sword/55(5)
```

PRE 的 14 个短局里，`force/1212`、`force/33`、`force/606`、`force/808`、`force/909`、`sword/11`、
`sword/1212`、`sword/33`、`sword/606`、`sword/808`、`sword/909` 共 11 局起手在 L2–L4——
即旧「短局人口」主要由 start 泄漏制造，而非真实地图产出。

POST 剩余 5 个短局中，只有 `force/20260927` 同时是 f1=0；`sword/55` 只有 5 场（最低值），
但其 f1 不为 0。

---

## 5. 结论（仅陈述事实，不作 A/B/C/D 裁定）

1. start 泄漏已修复并加守卫：16 seed 全部从 L1R0 起手，契约违规 0，确定性 OK。
2. 「短局人口」是被泄漏污染出来的：14 → 5，且旧短局 11/14 起手在 L2–L4。
3. f1=0 局从 8 → 2，其中 B1 预测的 6 个泄漏入口局全部转正；这不是经济参数调整的结果，
   而是数据 bug 修复的直接后果。
4. Common 机会同时改善数量与时序：绝对场次 81 → 155，且「首次 refinement 之前的 Common 胜场」
   从 14 → 73。R6/R7 的 S2/S4 结论（数量与时序是两个独立变量、堆量但时序错仍然失败）
   在新基线上需要重新测量。
5. **Elite 绝对暴露未下降（150 → 151）**，因此 G1 K=2 原本用来交换 Elite 的代价基础已不成立；
   其「条件接受边界」（§25）建立在污染基线上，按 §27 裁定已作废，需在新基线上重新评估是否仍有产品价值。
6. 新基线仍存在 2 个 f1=0 局，其中 `force/303` 为 20 场长局、`force/20260927` 为 13 场短局，
   两者性质不同；同时 `force/303` 是修复引入的新失败局，属未被解释的波动，需单独复核。

## 6. 未完成项与阻塞

```text
1. tools/test.ps1 / tools/check.ps1 的包装层判定在 unit 段为 FAIL：
   命中 2 条既有 SCRIPT ERROR（data/loot_tables.json 的 school_material_resonance 顶层键
   + battle_screen_view.gd 的 locked object）。两者都在本次允许范围之外，未修改。
   需要单独裁定：是修测试兼容（loot_tables 根键遍历）、还是把新键移到子对象。
2. PowerShell 沙箱无法真实执行 tools/*.ps1（1 秒 rc=1，Godot 子进程被拦截），
   本轮改用等价 Bash 命令逐段复现；如需包装层原生结果，需要在沙箱外执行。
3. S1-α 仍只是设计方向，未实现；原 S1（整局 combat 节点数）已作废。
4. G1 / M / G / T 的经济数值全部需要在 POST 语料上重新测量后才能谈。
5. force/303 的新增失败需要逐场重演解释（本轮未做）。
```

## 7. 复现命令

```bash
# 地图审计
"$GODOT" --headless --path . -s tools/q8g_reachability8_b1_map_audit.gd

# 32 局语料重建（等价于 tools/q8g_reachability5_tier_audit.ps1 的四批合并）
# 每局：PLAYTHROUGH_FULL=1 PLAYTHROUGH_COMBAT_FIRST=1 PLAYTHROUGH_E6_TIER_AUDIT=1
#       PLAYTHROUGH_SCHOOL=<school> PLAYTHROUGH_SEED=<seed>
#       "$GODOT" --headless --path . -s scripts/acceptance_driver.gd -- --mode=play
bash "$TEMP/q8g_rebuild_corpus.sh"

# PRE/POST 对照
node tools/q8g_reachability8_corpus_compare.mjs
```
