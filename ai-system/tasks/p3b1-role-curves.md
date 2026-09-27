# P3-B1 · 批B 剩余面：换基激活 + Enemy HP envelope 重推导 + ⑤ encounter 窗口验收

> **2026-09-26 收敛改写**（L2）：本包原 §A–§D（改 v1_battle.json、Godot resolver、审计工具、
> 派生镜像）已随 `RUL-2026-09-25-001` Q2 作废——真源迁移、投影机制、MVP 例外登记、30 值断言
> 均已随 2026-09-25/26 P2 批落地（debt.md:53/55，COORDINATION「批B 五条全过」为零漂移口径）。
> 本包只剩批B 的**行为换基面**：把 lab 投影从旧基线换到 Q2 公式投影，重推导敌方侧，
> 让 ⑤「换基后代表性 encounter 落目标回合区间」有实义。历史版本见 git 历史（≤6523e481）。

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → 记录回写（debt.md / COORDINATION 批B 段）

PROJECT GOAL
把《蛊真人》做成游戏。当前产品载体=浏览器 Web 版 lab（game/wenzhen-web-lab/lab.html，
contentVersion lab-run-v2）；基准关系=game/data / Game Semantics → generated Web data →
Web Runtime（RUL-2026-09-25-001）；Godot=参考实现，本包零 Godot 改动。

CURRENT PHASE
L0 优先级链（RUL-2026-09-25-001 PRIO）：P2 批A 已过、P3 Conformance 已过、P4 月光切片
GATE 已过、P5 多批已落地——全程跑在 lab 旧基线曲线（attack [2,3,4,5,6]）上。
本任务=批B 收敛后的唯一剩余面：换基激活与随之的敌方侧重推导、窗口验收。

TASK PURPOSE
Q2 批B 验收五条中 ①30 值单真源/②无第二份曲线/③投影可断言/④MVP 例外有父引用 已随 P2 批
落地；⑤「代表性 encounter 落目标回合区间」的「换基后」前提——lab 投影值激活——尚未发生：
PROJ-LAB-ROLE-CURVE-001 仍是 policy=legacy_lab_fallback_baseline_pending_l1 的旧基线表。
本任务把换基做完，并按 ANSWER Q2 纪律（「新 kit → 重新推导 target encounter envelope，
不因此手调全部敌人」）重推导敌方侧，使窗口/威胁门在新曲线下重新成立。

## 执行前置条件（**两条都满足才能开工**）

**① L1 公式投影 policy——已答复（2026-09-26，`game/world-model/rulings/RUL-2026-09-26-001.json`，RULED）。**
答复对象：[RESEARCH-REQUEST-2026-09-26-lab-role-curve-projection.md](../RESEARCH-REQUEST-2026-09-26-lab-role-curve-projection.md)。
本包 TASK 各节的公式、30 值、policy 名与 rationale 均照抄该裁定，Worker 不得改数。

**② 工作树干净（就本包触及面）。**
开工前 `git status --porcelain`：若 `game/wenzhen-web-lab/data/projections.json`、
`tools/build_data.mjs`、`js/mvp_content.js`、`game/data/enemies.json`、`js/data.js` 任一
仍有未提交改动，停下上报，不要在其上叠加。

TASK

## T1 · 换基激活：PROJ-LAB-ROLE-CURVE-001 公式投影化（RUL-2026-09-26-001 Q1/Q2）

- 公式（裁定原文）：`raw_lab_amount(role, rank) = world_amount(role, rank) / sqrt(20)`；
  `lab_amount = max(1, ceil(raw))`。缩放的是主标量量纲，不是 Rank 万能倍率。
- 换基后的六条 LAB 曲线（逐值，Worker 不得改数）：

  | role | LAB |
  |---|---|
  | attack | `[1, 2, 2, 3, 4]` |
  | defense | `[1, 2, 2, 3, 4]` |
  | healing | `[1, 1, 2, 2, 3]` |
  | logistics | `[1, 1, 1, 2, 2]` |
  | movement | `[1, 1, 1, 1, 1]` |
  | recon | `[1, 1, 1, 1, 1]` |

- `game/wenzhen-web-lab/data/projections.json` 的 PROJ-LAB-ROLE-CURVE-001：
  `policy = "sqrt_budget_scalar_projection_v1"`；value 按上表重写；rationale 照抄裁定
  给定文本（下块）；`parents`（balance.effect_budget.default_amount_by_role）与
  `forbidWriteBack=true` 不动。

  ```text
  LAB role amounts are a one-way projection of the WORLD
  default role curves. WORLD rank power budget is projected
  to LAB at 1/20, while default primary effect scalars follow
  sqrt(Budget); therefore scalar amounts project by
  sqrt(1/20) = 1/sqrt(20).

  For each role and rank:
  raw = world_amount / sqrt(20)
  lab_amount = max(1, ceil(raw))

  The projection never writes back to WORLD. LAB PP weights
  are validation/pricing weights applied after amount
  projection and are not an independent source for role
  curves. Movement and recon use the same formula; their flat
  LAB amounts are an intentional consequence of small-integer
  projection, with higher-rank differentiation expected from
  effect semantics rather than hidden scalar inflation.
  ```

- `tools/check_projection.mjs` 新增断言组（RUL AUTOACCEPT）：world curve → formula →
  exact LAB curve 由 parent **复算**比对（30 值逐值）；parent 指向正确；policy 不含独立
  手写 curve（无内嵌 fallback 曲线）；forbidWriteBack=true；generated data 无旧 baseline
  silent fallback。
- 重跑 `node tools/build_data.mjs`（在 game/wenzhen-web-lab/ 下）重生成 `js/data.js`；
  构建期 fail-fast（缺曲线/缺 role/长度≠5）必须全绿。
  **注意顺序依赖**：换基后旧压缩表 `{1:2,…}` 的 rank1=2 > 新 attack 曲线 rank1=1，
  压缩不变量校验会**故意** fail——这是正控。所以本步与 T2（压缩表重基）必须同批完成后再
  重跑构建；单独跑 T1 时构建失败属预期，如实记录即可，不得为过构建回退曲线。
- 旧基线 `[2,3,4,5,6]` 只允许出现在迁移前后报告里，不得留在任何 Runtime 消费路径。

## T2 · 敌方攻击压缩表重基：PROJ-LAB-ENEMY-ATTACK-001（RUL-2026-09-26-001 Q3）

- 裁定方向：**改伤随表**——数据链为「装备/能力 → projected effect → 敌人实际 action →
  intent.damage」；不反向锚定。威胁是 encounter-level target，**无固定 1/4 公式**；
  handleRate/survivalRate/targetTurns 继续作为 envelope 约束。
- 旧表 `{1:2,2:3,3:3,4:4,5:4}` 已**解冻**（legacy projection calibration），随新 LAB
  attack 曲线 `[1,2,2,3,4]` 重新生成或校验；不得手工维护另一张永久攻击曲线。
- 两条硬不变量保留（build_data.mjs 构建期校验）：`Σ 实际被该 intent 激活的 projected
  attack effects == intent.damage`；`single projected attack ≤ 对应 LAB attack role
  envelope`；表值单调不减。
- 敌方与玩家同蛊需要不同量纲时，必须走显式 enemy projection policy 表达，禁止另藏
  Rank 表；不得为命中 DPR 偷偷修改某只蛊的投影值。

## T3 · Enemy HP envelope 重推导（RUL-2026-09-26-001 Q4 + ANSWER Q2 纪律）

- 顺序（裁定指定）：MVP kit 换基（T6）→ new projected kit → new refDpr →
  `deriveEnemyHp(...)` → 新代表性敌 HP → 验证冻结窗口。
- 参考层（`js/mvp_content.js:129-146`）：refKit/refDpr/hpFor 机制已是推导式——换基后
  **先读它自动算出的新 envelope**，不要手改 hpFor/targetTurns/margin/minHp（窗口
  battle_1 3–5 / battle_2 4–6 / elite 4–6 / boss 6–9 与中值 4/5/5/7.5 是 L1 V4.1 冻结）。
- 真实敌池（`game/data/enemies.json` 45 只 hp）：OWNER 不变；以新 envelope 校对每只，
  按裁定三档处置：
  1. 自动推导入窗 → PASS；
  2. 偏差 ≤20% 且有明确世界/遭遇原因 → `balanceReport.overrideReasons` 登记
     （现位置 `tools/check_balance.mjs:115` 消费）；
  3. **大量代表性敌人需要 override** → 判定 projection policy 与 envelope 不兼容，
     **不手调敌人群**，停下重新上抛模型冲突（ESCALATE）。
- **禁止无推导依据的手调**；`game/data/enemies.json` 的 diff 必须能逐行给出推导依据。
- 敌人 intent.damage 因 T2「改伤随表」变化的，同批更新并保留 Σ==damage 构建校验通过。

## T4 · ⑤ 窗口验收（硬门禁）

全部真实输出，不看退出码标签：

```powershell
cd game/wenzhen-web-lab
node tools/check_balance.mjs        # 四窗口 battle_1[3,5]/battle_2[4,6]/elite[4,6]/boss[6,9]
                                    # + H1 偏差门 + 威胁窗 全 PASS
node tools/check_projection.mjs     # 全绿，含新公式断言
node --test tests/                  # 全量测试通过（semantics/conformance/balance 等既有断言
                                    # 若因换基过期，按新曲线更新期望值——期望值更新逐处注明依据）
```

## T5 · 真实整局证据（记录项，非单项硬门禁——RUL Q2 明确）

用 `node tools/acceptance_lab.mjs --seed 103 --difficulty normal --policy gu_first --shots <dir>`
跑一局真实浏览器整局（victory 或 defeat 均可接受为有效轨迹；softlock 与 console error
必须为零）。结果 JSON 与截图随结果包归档。若节奏显著劣化（如战斗回合数系统性越窗），
作为 T4 的窗口证据上报，不静默调参。

## T6 · MVP 例外重基（RUL-2026-09-26-001 Q4）

- 裁定：**机制保留，数值随新公式重基**——`new projected baseline + explicit semantic
  exception = MVP final amount`。旧 pinned 值不因「历史上校准过」自动继承；
  「为了维持旧 V4.1 数值」不是充分理由。
- 每条例外登记五字段：`parentProjection`、`baselineValue`（=新公式对该 role/rank 的
  投影值）、`overrideValue`、`overrideReason`（独立产品/语义理由）、`forbidWriteBack=true`；
  登记 form 落 `mvp_content.js`（guRef+五字段）并在 `PROJ-LAB-MVP-GU-EXCEPTION-001`
  rationale 同步说明。
- `overrideValue == 旧值` 的例外必须证明为何在新 baseline 下仍应保持；证明不了就回到
  baseline。
- 重基后 refDpr 与代表性敌 HP envelope 随之重算（衔接 T3）；T5 的真实整局证据在重基后
  采集。
- `priceGu`/kitDpr 等 balance.js 检测层零改动（PP 只做 projection 之后的核算/定价校验，
  禁止反向成为 role amount 真源——RUL frozen invariants）。

SCOPE
可写：
- `game/wenzhen-web-lab/data/projections.json`（两条 PROJ 条目）
- `game/wenzhen-web-lab/tools/build_data.mjs`（仅当校验/映射需要）
- `game/wenzhen-web-lab/tools/check_projection.mjs`（仅公式断言）
- `game/wenzhen-web-lab/js/mvp_content.js`（仅 overrideReasons/envelope 联动面）
- `game/data/enemies.json`（仅 hp/intent.damage 按推导更新）
- `game/wenzhen-web-lab/js/data.js`（仅经 build_data 重生成）
- `game/wenzhen-web-lab/tests/**`（过期期望值更新 + 新增换基断言）
- `ai-system/tasks/p3b1-role-curves-result.md`（结果包）

只读：其余一切（balance.json、v1_battle.json、gu.json、js/balance.js、js/run_rules.js、
Godot 全侧、lore/**）。

DO NOT
- **禁止改 `game/data/balance.json`**（30 值真源与全部已登记投影常量零改动）。
- **禁止改 Godot 侧任何文件**（参考实现，无二进制无法验证）。
- **禁止改 `game/data/v1_battle.json`**（role→kind 已瘦身的消费面不动）。
- **禁止改 `js/balance.js`**（LAB_BUDGET_PROJECTION/PP 权重/威胁预算是已冻结锚点）。
- **禁止手调全部敌人 hp**——只允许 envelope 推导或 override_reason 登记两条路（ANSWER Q2）。
- **禁止动 MVP 例外登记结构**（guRefs/forbidWriteBack/父引用）。
- **禁止偏离 `RUL-2026-09-26-001` 的公式、30 值与 policy 名自行发明任何数值**。
- 禁止 commit / push / merge / stash / reset；禁止新增第三方依赖；禁止 `--no-verify`。

DECISION AUTHORITY
可自行决定：测试组织方式、结果包结构、推导表格的呈现形式。
**不可自行决定**：曲线公式与数值（L1 答复为准）、窗口/威胁预算常量、MVP 例外关系、
锚定方向（Q3）、任何 WORLD 侧数值。

ESCALATE WHEN
- L1 答复的公式与「窗口 + 威胁预算」数学不可兼容（如实上报，附推导）。
- Σ==damage 锚定方向与压缩不变量出现冲突路径。
- 真实敌池出现系统性出窗且无法用 envelope+override 纪律覆盖。
- 发现兜底曲线还有本包未列出的第三个读者。

DELIVERABLE
1. 新投影条目 diff（含 policy 陈述登记）+ check_projection 全绿输出
2. 新压缩表 + Σ==damage 校验输出
3. enemies.json 逐行推导依据表（envelope 值 / 实际值 / 偏差 / 处置）
4. check_balance 四窗口 + H1 + 威胁窗全绿输出
5. tests 全绿输出（过期期望值更新的逐处依据）
6. 真实整局证据（acceptance JSON + 截图）
7. `ai-system/tasks/p3b1-role-curves-result.md`（Caveman Review Packet）

ACCEPTANCE
- `node tools/check_balance.mjs` 全 PASS（含四窗口）
- `node tools/check_projection.mjs` 全 PASS
- `node --test tests/` 全 PASS
- `git status` 证明：balance.json / v1_battle.json / js/balance.js / Godot 侧零改动
- enemies.json diff 逐行有推导依据
- 结果包落盘

STATUS TARGET
READY_FOR_P3B1_REVIEW

## 技术事实（L2 已核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| WORLD 真源 30 值 | `game/data/balance.json` effect_budget.default_amount_by_role（Q2 裁定值） |
| lab 投影当前=旧基线 | `game/wenzhen-web-lab/data/projections.json:59-77`（policy=legacy_..._pending_l1） |
| 投影消费点（纯映射） | `tools/build_data.mjs:25-33,161-192`（defaultBattleEffect/resolveEffectAmount，rank 钳位 1-5） |
| 压缩表不变量校验 | `tools/build_data.mjs:44-53`（≤attack 曲线、单调不减）+ Σ==intent.damage |
| 参考吞吐与敌 HP 推导 | `js/mvp_content.js:129-146`（refKit/refDpr/targetTurns 4/5/5/7.5/hpFor=deriveEnemyHp margin 1.08） |
| 窗口与 H1 门 | `tools/check_balance.mjs:92-136`（四窗口 + 偏差>20% 需 override_reason） |
| 威胁预算 | `js/balance.js:284-303`（THREAT_V1 + deriveEnemyDamagePerTurn）+ check_balance.mjs:145-171 |
| override 登记位置 | `balanceReport.overrideReasons`（check_balance.mjs:115 消费） |
| MVP 例外 | `projections.json` PROJ-LAB-MVP-GU-EXCEPTION-001 + `mvp_content.js` overrideReason 行 |
| 真实整局驱动 | `tools/acceptance_lab.mjs`（2026-09-26 新增，四项验收一次覆盖） |
| Python/编码坑 | 无 Python 依赖；node ≥20；控制台 gb2312，必要时 `PYTHONIOENCODING=utf-8` |

## Execution rules

- Worker class: `normal`。
- 改 `game/` 下任何文件前先 `python game/world-model/tools/snapshot.py take p3b1-role-curves-rebase`
  （工具不可用时在结果包注明并手工 git diff 备底）。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/p3b1-role-curves-result.md`**。
