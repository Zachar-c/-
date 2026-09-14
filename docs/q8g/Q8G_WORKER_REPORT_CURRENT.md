# Q8-G Worker Report（当前）：Reachability-5 / E6 Loot-Tier Opportunity Audit + A/B/C/D 报告层对比

> - **Worker**：ZCode；**Inbox**：`docs/q8g/Q8G_HANDOFF_CURRENT.md` §14 + §15 白名单（2026-09-13）。
> - **状态**：✅ R5 审计 + 白名单后续任务（A/B/C/D 报告层对比）完成，待 Luna 审查。本报告不含产品裁定。
> - **历史**：Reachability-4 报告要点已由 inbox §13 复核结论收档；实验数据保留于 `Q8G_REACHABILITY4_F1_OPPORTUNITY_SIM.md`。

## 1. 实际修改文件

| 文件 | 变更 |
|---|---|
| `scripts/acceptance_driver.gd` | opt-in 只读审计分支（`PLAYTHROUGH_E6_TIER_AUDIT=1`，独立于 R4 开关）：逐场 `R-5 battle:` 记录（模板敌/实际敌/实际结算 tier/grade/rank/层 rank 区间/生效 weights/材料/f1_hit/school）、`R-5 summary:` 终局汇总（inbox §14 全部字段 + `visit_marks` 探访时点标记） |
| `tools/q8g_reachability5_tier_audit.ps1` | 新建 8-seed sweep（逐场日志落 `$env:TEMP/gu-zhenrens-r5-logs/`）；首次运行发现 worker Bug（gates 正则依赖已关闭的 R4 输出行），修复后重跑 exit 0 |
| `tools/q8g_reachability5_abcd_comparison.mjs` | 新建 A/B/C/D 报告层 hypothetical 对比工具（Node 无依赖；读 R5 日志 + `loot_tables.json`；调试中修复正则/捕获组两处解析 Bug，ACTUAL 与驱动器 f1 计数逐局一致作交叉验证） |
| `docs/q8g/Q8G_REACHABILITY5_E6_LOOT_TIER_AUDIT.md` | 实验记录（新建）：8-seed 汇总 + H1–H6 假设分析 + Gate 自评 + §7 A/B/C/D 对比 |
| `docs/q8g/Q8G_WORKER_REPORT_CURRENT.md` | 本报告（更新） |

R4 工具与文档未覆盖、历史结果保留。`.codex/`、`$TEMP/gu-zhenrens-r5-logs/` 为未跟踪实验产物。

## 2. 未修改但审阅过的文件

`scripts/domain/**`（loot_resolver/run_state/enemy_catalog/map_generator/dda_resolver）、`data/enemies.json`、`data/pacing.json`、`data/loot_tables.json`、`data/balance.json`、`tests/**`、`scripts/presentation/**`、`scenes/**`——`git status` 确认本任务零触碰。

## 3. 关键测量结果（完整版见实验记录）

- **实际掉落池 tier 份额与名义倒挂**：86 场已结算 = common 18（20.9%）/ elite 46（53.5%）/ boss 22（25.6%）vs 名义 75/25/0。
- **主因（H2）**：common 候选敌全部集中在 rank 0–2，层 rank 区间逐层上移将其结构性清空——**L5 rank[3,5] 内 common 候选 = 0（全主题），L4 faction = 0**；L3 起多数主题份额已降至 50–80%。
- **H3**：多敌战斗（`battle.enemy_kind` 为空）按 LootResolver 兜底 common，是 common-table 战斗的主力通道（force 55 的 4 场 common 全部是多敌战斗）；faction 主题 common 候选仅 1 个（r1），L3 起 100% 落 elite 池。
- **H4 时序**：8 局全部 `common_before_first_refinement=0`（caveat：驱动器 refine-first 寻路）；6/8 局 `common_after_last_refinement=0`。f1=0 三局的窗口错位各有解释：sword 11/33 唯一窗口在 streak 达标前（第 2/3 场）；force 20260927 唯一窗口在 L5 末段（streak=9，达标但晚于全部 4 次探访）。
- **H5**：单敌战斗被少数 elite 敌主导（`thunder_crown_wolf` 占 force 55 的 27%，`clan_elder` 出现于 8/8 局）。
- **H6 敏感性（hypothetical）**：若有效份额回到名义 75%，f1=0 三局的兑现窗口将大量落在末次探访之前——**Common opportunity 的量与时序需同时修复才有效**（置信度中等，未逐场重抽）。

## 4. 验收命令与退出码

| 命令 | 退出码 | 结果 |
|---|---|---|
| `tools/q8g_reachability5_tier_audit.ps1`（8 局 sweep） | 0（修复后） | summary/gates 齐全，日志落 TEMP |
| 无污染验证：seed 55 force 关开关 vs 基线 | 0 | 漏斗/promotion/Gate 逐字一致 |
| 零行为差验证：开/关开关对比 | 0 | Gate/漏斗/promotion 完全相同 |
| 确定性验证：同配置复跑 | 0 | `R-5 summary` 完全相同 |

## 5. Gate 自评（inbox §14）+ 对比结论（§15 白名单）

Gate A 数据来源 PASS；Gate B 分布可解释 PASS；Gate C 时序可解释 PASS；Gate D 不污染行为 PASS。

A/B/C/D 报告层对比（数据见实验记录 §7，全部 hypothetical）：

- **C（全战斗累计）单独无效**——复现 R4：8 局仅 1 兑现且晚于全部探访；
- **B（crude w1 挂 elite）强度不足**——8 局仅 1 次提前一个战斗位；
- **D（共享计数器回退）对 f1 有害**——f1 交付 8 局 ≈ 0–1，劣于现状；
- **A（恢复 Common opportunity）是唯一实质性收敛方向**——f1=0 三局修复 2 局、交付全部落在探访窗口内；sword 33（8 场短局）未触发，提示 A 需配合短局下限考量。

## 6. 未完成项、阻塞项与遗留

- 未完成项：无（inbox §14 范围全部完成）。
- 阻塞项：无。
- 遗留 1（既有失败，与本任务无关）：`--mode=smoke` NPC 屏断言失败（`acceptance_driver.gd:1392`，本轮及 Reachability-2/3/4 均未触碰该区域），待单独裁定是否修复。
- 遗留 2：R4/R5 的 driver 测量代码为一次性实验件；产品方向裁定后若不再需要可整体移除。
- 遗留 3（来自 inbox §13）：sweep 日志 harness 依赖（原 `user://logs` 占用问题）已由 TEMP 目录方案绕开，harness 本身的修复仍挂账。
- 按 inbox 要求，A/B/C/D 方向选择等待 Luna 裁定；本报告只陈述数据、因果证据与剩余不确定性。

---

# 增补：Reachability-6 / Common Opportunity Intervention Preflight（inbox §16 批准）

## 实际修改文件

| 文件 | 变更 |
|---|---|
| `tools/q8g_reachability6_preflight.mjs` | 新建四变量 preflight 工具（复用 R5 解析器；abcd 工具加 main 守卫使其可被导入） |
| `tools/q8g_reachability5_abcd_comparison.mjs` | 加导出与 main 守卫（供 preflight 导入；standalone 行为不变，已回归验证） |
| `docs/q8g/Q8G_REACHABILITY6_PREFLIGHT.md` | 实验记录（新建） |
| `docs/q8g/Q8G_WORKER_REPORT_CURRENT.md` | 本增补 |

生产代码/数据零触碰（`scripts/domain/**`、`data/**`、`presentation/**`、`tests/**` 均未动）。

## 四变量结果（全部 hypothetical，逐一独立）

| 变量 | 关键读数 |
|---|---|
| S1 rank-filter | **L4+L5=0.75 是修复全部 f1=0 的最小组合**（3/3）；单层放宽只能 2/3 |
| S2 effective-weight | 份额 ≥0.6 单调改善；0.75 时 inWindow 7/8；0.21 档的 3/3 是重采样方差（已标注） |
| S3 fallback 统计 | common-table 胜利的 **50% 来自多敌 fallback**（9/18） |
| S4 timing | 数量不变下：聚簇时序 0/3 完全失效，均匀分布 3/3 完全成功——时序是独立变量 |

综合读数：A 方向若立项，有效形态是"恢复各层 Common 候选覆盖且分布均匀"；单层/单点/聚簇修补均被数据排除；短局（sword 33 型）在覆盖不足时仍会漏。

## 验证与遗留

- 全部模拟为报告层推演，生产代码/数据零触碰；天然命中率样本 18 场、重采样方差已如实标注，建议多种子重复给置信区间。
- 无阻塞项；等待 Luna 对 Reachability-6 结果的产品裁定。

---

# 增补 2：多种子置信度批次（inbox §17 白名单 1-4，2026-09-13）

## 实际修改文件

| 文件 | 变更 |
|---|---|
| `tools/q8g_reachability5_tier_audit.ps1` | 加 `-Batch2` 开关（新种子 101/202/303/404 × force/sword；默认行为不变） |
| `tools/q8g_reachability6_preflight.mjs` | 重写为多种子版：glob 全部 R5 日志、COVERAGE/SHARE 互斥边际、短局边界分析、天然时序统计（inbox §17 第 1/2/3/4 项全覆盖） |
| `docs/q8g/Q8G_REACHABILITY6_PREFLIGHT.md` | 追加"多种子置信度批次"章节 |
| `docs/q8g/Q8G_WORKER_REPORT_CURRENT.md` | 本增补 |

生产代码/数据零触碰。新增逐场日志：`$TEMP/gu-zhenrens-r5-logs/`（batch2 同目录、按种子命名无冲突）。

## 关键结果（16 局 = batch1 8 + batch2 8）

1. **f1=0 呈种子聚集**：batch1 3/8、batch2 0/8 → 合并 3/16（19%）；f1 断档是特定种子/路线形态产物，不是均匀随机。
2. **天然时序修正**：4/16 局存在 common 战斗早于首次探访（batch1 读数 0/8 系种子聚集，非普遍规律）——回应 inbox §17 第 4 项。
3. **COVERAGE 边际**：+L5 单独或 +L4+L5 均 3/3 修复且短局零遗留；单扩 L4 为 1/3（n=16 方差）。
4. **SHARE 边际**：份额 ≥0.6 即 3/3 修复、短局零遗留；0.75 时交付落窗 15/16。
5. **短局边界**（回应第 2 项）：三个 f1=0 局全部是短局（<15 战斗、仅 1 个 L4/L5 窗口）——短局修复条件 = 窗口数量或份额，pity 语义无法覆盖。

## 验证与遗留

- batch2 sweep exit 0；preflight 输出与 16 局记录一致；生产代码/数据零触碰。
- 置信度声明：16 局、单 RNG 路径、点估计；建议立项后以 32+ 局收紧。
- 无阻塞项；等待 Luna 对 A 方向形态（覆盖 vs 份额）的产品裁定。

---

# R8 / B1 start 泄漏修复 + 真实基线重建（2026-09-13）

> Inbox：`Q8G_HANDOFF_CURRENT.md` §27 裁定一 + 用户本轮施工指令。
> 报告全文：`docs/q8g/Q8G_REACHABILITY8_POST_FIX_BASELINE.md`。

## 1. 实际修改文件（已提交 `29286071`）

| 文件 | 变更 |
|---|---|
| `data/nodes.json` | 删除 `neutral_wanderer` / `ridge_caravan` 两个模板的 `start` 字段（−2 行） |
| `tests/unit/test_five_layer_map_contract.gd` | +2 回归守卫：模板不得声明 `start`；每个 `start` 必须在 `layer==1 && row==0` |

逐字段 diff：37 个模板 id 集合一致，唯一差异即上述两处 `start`。`map_generator.gd`、其他节点、连边、pacing、
敌人、loot、pity、RunState、事件、存档、UI 均未修改。

## 2. 未修改但审阅过的文件

`scripts/domain/map_generator.gd`（`duplicate(true)` 传播链、`reachable_nodes` 无层过滤）、
`tests/unit/test_five_layer_map_contract.gd`（原 `reachable == is_start` 镜像断言，对泄漏零分辨力）、
`scripts/acceptance_driver.gd`（P1-a `refine_leading` 放大器，未改）、
`tools/q8g_reachability8_b1_map_audit.gd`（增强：新增 `row` 采集 + 起点绝对断言段 + 每 seed 明细）。

## 3. 验收命令与退出码

| 阶段 | 退出码 | 结果 |
|---|---|---|
| `scripts/guitkx_build.gd` | 0 | `compiled=0 errors=0 held=0 total=16` |
| unit（GUT） | 0 | Tests 1441 / Passing 1441 / Failing 0 |
| integration（GUT） | 0 | Tests 32 / Passing 32 / Failing 0 |
| 启动探针 `--quit-after 3` | 0 | OK |
| `tools/check_contract_drift.gd` | 0 | 168 identifiers resolved |
| `git diff --check` | 0 | 无空白错误 |
| R8 B1 地图审计 | 0 | 非 L1 起手 0/16、契约违规 0、determinism OK |
| 32 局语料重建 | 0 | 32/32 退出码 0，R-5 summary 全部生成 |

包装层遗留：`run_gut_checked.ps1` 的 `SCRIPT ERROR` 扫描使 unit 判定 FAIL（`tools/check.ps1` 会在 unit 段 exit 1），
两条命中分别来自未提交的 `data/loot_tables.json` 顶层新键 `school_material_resonance`（JSON 数字→float）
与既有 `battle_screen_view.gd:941`，均在本任务范围外、未修改。PowerShell 沙箱拦截 Godot 子进程，
`tools/*.ps1` 在沙箱内不可信，故改用等价 Bash 逐段复现。

## 4. 修复前后 32 局对照

```text
                               PRE        POST
非 L1 起手局                  14/32      0/32
battles total                 484        619（min/med/max 3/16/24 -> 5/20/29）
short runs (<15)              14         5
battles by layer              {1:68,2:98,3:100,4:115,5:103}  ->  {1:145,2:165,3:148,4:98,5:63}
common / elite / boss         81 / 150 / 79  ->  155 / 151 / 88
retreats / refine visits      348 / 90   ->  450 / 98
common before first refine    14         73
common after last refine      9          8
f1_zero runs                  8          2
f1_count total                43         63
mat_ready / full_ready        70 / 42    88 / 70
attempts / successes          47 / 47    72 / 72
gate_b / gate_c PASS runs     9 / 4      15 / 8
```

f1=0 逐局：PRE 8 局 → POST 2 局（`force/20260927` 13 场、`force/303` 20 场）。
7 局转正（B1 预测的 6 个 L3/L4 泄漏入口局全部转正），`force/303` 为修复引入的新失败局。

## 5. 与 Reachability-3~7 的差异

- R7B–R7E 的全部 effect size / 效率前沿 / 区间化报告建立在被污染人口上，**已作废**，不得继续引用。
- 「短局 = 战斗数 <15」这一操作性定义下的人口由 14 → 5，旧短局 11/14 起手在 L2–L4。
- **Elite 绝对暴露未下降（150 → 151）**，G1 K=2 的代价基础消失；其 §25 条件接受边界作废。
- Common 机会数量与时序同时改善，R6 的 S2（份额）/S4（时序）需在新基线上重测才能重新排序。

## 6. 未完成项与阻塞

```text
1. 包装层 unit 判定受既有 SCRIPT ERROR 影响（loot_tables 根键遍历 / battle_screen_view 生命周期），
   需单独裁定修法，未自行处理。
2. force/303 由 f1>0 变为 f1=0，属修复引入的未解释波动，需逐场重演复核。
3. S1-α 仍仅为设计方向，未实现；原 S1 已作废。
4. G1 / M / G / T 需在 POST 语料上重新测量，本轮未做。
```

## 7. 复现命令

```bash
"$GODOT" --headless --path . -s tools/q8g_reachability8_b1_map_audit.gd
bash "$TEMP/q8g_rebuild_corpus.sh"                 # 32 局重建
node tools/q8g_reachability8_corpus_compare.mjs    # PRE/POST 对照
```

本报告不含 A/B/C/D 产品裁定。
