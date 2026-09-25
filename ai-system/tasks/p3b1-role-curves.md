# P3-B1 · 把 L1 的六条 role 转数曲线落进兜底表

> **2026-09-25 休眠资产登记（A 档，见 [docs/dormant-registry.md](../../../docs/dormant-registry.md)）**：
> 数值前提（RUL-2026-09-19-008/011、P2 预算曲线）仍现行；本包内「Godot = Canonical」前提已被
> L0 2026-09-24 Web 载体裁定取代。批B 解锁时以本包为任务底稿，数值落点改为 Web 侧
> （`game/wenzhen-web-lab/js/balance.js` 与 `game/data/balance.json`）。

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → P3-B2（一致性断言，依赖 L1 补充定义）

PROJECT GOAL
把《蛊真人》做成游戏。当前阶段经 L1 裁决：Godot = Canonical（唯一规则权威源），
Web = Disposable Prototype（RUL-2026-09-19-010）。

CURRENT PHASE
P3 统一 Effect 管线。P3-A（普查）已交付；P3-B 的数值已由 L1 裁定
（RUL-2026-09-19-011，B1–B6 可执行）。
本任务是 P3-B 中**唯一已完全指定、无歧义**的那一块。

TASK PURPOSE
现行兜底表（802 只蛊里 741 只走的路径）是**线性 +1/转**：五转只有一转的 1.0–5.0 倍，
而冻结的 Rank Power Budget 是 ×16。两者不同源，且 D7 列的 11 个可投维度里
现行只用了 1 个。L1 已裁定默认主标量改按 sqrt(Budget) 增长（R1→R5 约 ×4），
本任务就是把这条裁决变成数据 + 一处读取点。

TASK

## A. 数据：`game/data/v1_battle.json` 的 `default_effect_by_role` 改存转数曲线

六个 role 各把标量 `amount` 换成按转数索引的数组 `amount_by_rank`（顺序 = 一转…五转），
取值**照抄** L1（RUL-2026-09-19-011 B3，**不得自行调整任何一个数字**）：

| role | kind | `amount_by_rank` |
|---|---|---|
| attack | strike | `[4, 6, 8, 11, 16]` |
| defense | shield | `[4, 6, 8, 11, 16]` |
| healing | heal | `[3, 4, 6, 8, 12]` |
| logistics | heal | `[2, 3, 4, 6, 8]` |
| movement | shift | `[1, 1, 2, 2, 3]` |
| recon | status | `[1, 1, 1, 1, 1]` |

其余键（`kind` / `name` / `support_school` / `support_bonus`）**原样保留**，不改。

**只改 `default_effect_by_role` 这一个对象。`v1_battle.json` 的其它键一律不动**
（`regen_pct`、`stage_base`、`aptitude_mult`、`kill_moves`、`boss_layer_mult` 等）。

## B. 读取点：`game/scripts/domain/v1_battle_resolver.gd`

1. `default_v1_effect()`：删掉 `amount = base + (rank-1)` 的线性缩放，
   改为按 rank 索引 `amount_by_rank`。
   - **索引口径照现状**：用 `definition.get("rank", 1)`（**不要**改成实例的 effective_rank）。
     现状即按定义转数取，本批**不改变取哪一转**——换曲线与换取数源是两件事，后者单独评审。
   - rank 超出 1..5 时钳到 5（`gu.json` 有 1 只 rank 10 的 `test_slay_gu`，它显式声明了
     `v1_effect` 永不走兜底；钳位是防御，不改变它的行为）。
   - `RANK_SCALED_KINDS` **保留**：它仍被 `_build_gu_slots` 的降转下调逻辑使用
     （`v1_battle_resolver.gd:205`）。但**不要**再让它参与兜底的 amount 计算。
   - **`support_bonus` 的缩放原样保留**（仍是 `base + (rank-1)`）。L1 尚未裁它，
     改它就是自行发明（见「DO NOT」）。
2. **防重复扣减**：`_build_gu_slots` 里 `if downgrades > 0 and RANK_SCALED_KINDS.has(kind):
   amount = maxi(1, amount - downgrades)` **保持不动**。因为取数源没变（仍是定义转数），
   这里不会双重扣减。若你发现任何双重扣减路径，**停下上报**，不要自行取舍。
3. `role_default_table()` 不改。

## C. 消灭第二份规则权威源（本任务的重点，别漏）

`game/world-model/tools/audit_effect_budget.py:70-72` 目前是**用正则去 GDScript 源码里
抠 `RANK_SCALED_KINDS`，再自行套 `b + (r-1)`** 来重建曲线的——即「审计工具里躺着第二份规则」。
照 RUL-2026-09-19-010 W3（一份 Effect 语义 / 一份数据真源），改成**直接读数据里的
`amount_by_rank`**，删掉那个正则抠源码的 `scaled` 逻辑。

改完后 `audit_effect_budget.py` 报出的六条曲线必须与上面 A 的表逐值相同——
把它的输出片段放进结果包。

## D. 派生镜像必须重生成（**写法待裁，见下**）

`game/world-model/tools/build_world_model.py:315-316` 把兜底 effect 内嵌进镜像的每条蛊记录，
所以本改动会让镜像与上游漂移。

- 跑 `python game/world-model/tools/check_upstream_drift.py` 确认它**确实报漂移**（这是正控）。
- 然后按该工具的既有做法重生成镜像（**不要**手改 `game/world-model/data/**`）。
- 再跑一次确认漂移归零。

### ⚠️ 但镜像怎么写，L2 已上抛、尚未裁 —— 见下（这条决定你能不能开工）

L2 在派工前检查发现一个耦合，已写进
`ai-system/RESEARCH-REQUEST-2026-09-19-p3b-addendum.md` §4：

**镜像里的 `effect` 不只是展示数据，它被世界模型引擎当规则读。**

`game/world-model/engine/rules.py:254 resolve_effect(wm, effect, gu_rank, state)` 直接读
`effect.get("amount", 0)`，而且**把它收到的 `gu_rank` 参数完全不用**。
741 只走兜底的蛊，其镜像记录的 `effect` 就是兜底表的那份字典。

所以把兜底表从标量改成 `amount_by_rank` 后，`resolve_effect` 会读不到 `amount` → **取 0**
→ 世界模型引擎里 741 只蛊的效果**静默归零**。

L2 已确认**本批不存在零漂移拆法**（新曲线的一转基准值本身就变了：attack 2→4 等），
故镜像的写法（P1 已解析标量 / P2 保留曲线并让引擎按 rank 索引 / P3 只写一转基准）
**必须由 L1 裁决后再实施**。

**开工条件**：L1 回复 P1/P2/P3 之一。在此之前本任务**不派工**。
A/B/C/E 四节的实现细节已就绪，届时直接照做即可；D 按裁决结果执行。

## E. 测试

1. 更新因曲线变化而过期的既有用例（至少 `game/tests/unit/test_q7_role_defaults.gd`；
   自己全仓跑一遍确认没有遗漏）。预期新值：
   - logistics：r1=2 / r2=3 / r3=4 / r4=6 / r5=8（现行断言是 r2=2、r4=4、r3=3）
   - recon：六转恒 1（不变）
2. 新增用例，钉住 A 表的**全部 30 个值**（六 role × 五转），一条断言一个格子。
   这是本批唯一直接承载 L1 裁决的东西，必须逐值可查。
3. 新增用例，钉住 **rank 10 的钳位行为**（用 `test_slay_gu` 或合成夹具）：
   走兜底时取到 r5 的值而不是崩。
4. 新增用例，钉住 **降转下调不与新曲线双重扣减**：一个显式 `strike` 实例降 1 次，
   其 amount 只被减 1。

SCOPE
可写：
- `game/data/v1_battle.json`（**仅** `default_effect_by_role` 一个对象）
- `game/scripts/domain/v1_battle_resolver.gd`（仅 `default_v1_effect` 的 amount 计算）
- `game/scripts/domain/content_catalog.gd`（仅 `_validate_v1_battle_role_defaults`：
  `amount` 正整数校验改为 `amount_by_rank` 是长度 5、每项 ≥1 的整数数组）
- `game/world-model/tools/audit_effect_budget.py`（改为读数据）
- `game/world-model/tools/build_world_model.py`（**仅当**重生成确实需要改它）
- `game/world-model/data/**`（**仅通过重生成工具**写入）
- `game/tests/unit/**`（更新过期用例 + 新增用例）
- `ai-system/tasks/p3b1-role-curves-result.md`（结果包）

只读：其余一切。

DO NOT
- **禁止自行决定派生镜像怎么写**（P1/P2/P3 未裁前，§D 不得实施）——
  镜像的 `effect` 被 `game/world-model/engine/rules.py` 当规则读，写错会让 741 只蛊静默归零。
- **禁止自行调整 A 表里的任何数字**，也禁止顺手「优化」成 sqrt 公式——
  L1 给的 movement `[1,1,2,2,3]` 与 recon 恒 1 是**有意偏离** sqrt 的，写成公式就表达了它。
- **禁止实施 R5 一致性断言**（预算总量 85%–115%）——它的两个定义还缺，
  已在 `ai-system/RESEARCH-REQUEST-2026-09-19-p3b-addendum.md` 上抛 L1，等回复。
- **禁止改 `support_bonus` 的缩放**（L1 未裁）。
- **禁止把兜底的取数转数从 `definition.rank` 改成 effective_rank**（单独评审）。
- **禁止改 `game/data/gu.json`**（802 只蛊的个体数值一个都不动）。
- **禁止改 `game/data/v1_battle.json` 里除 `default_effect_by_role` 外的任何键**。
- **禁止改 `game/wenzhen-web-lab/**`**（已冻结）。注意：该原型读的是自己生成的
  `js/data.js`，本批不要求同步它；它是 Disposable Prototype，形状漂移属已知且可接受，
  在结果包里提一句即可，**不要去改它**。
- **禁止改敌人的 hp/damage/regen/cooldown 等任何战斗平衡数值**。
- 禁止 commit / push / merge / stash / reset；禁止新增第三方依赖；
  禁止 `--no-verify` 绕过任何门禁。

DECISION AUTHORITY
可自行决定：`amount_by_rank` 的读取实现细节、校验器的报错文案、
重生成镜像的具体命令、测试的组织方式。
**不可自行决定**：曲线数值、取数转数、`support_bonus` 缩放、R5 断言、任何其它键的数值。

ESCALATE WHEN
- 有测试的失败**不是**「夹具值是旧线性值」而是反映真实语义冲突
- 重生成镜像引入了 A 表之外的数据变化
- `check_upstream_drift.py` 在重生成后仍报漂移，且原因是本批改动之外的东西
- 发现兜底表还有本包未列出的第三个读者

DELIVERABLE
1. 改后的 `default_effect_by_role`（六条曲线）
2. 改后的 `default_v1_effect()`（按转数索引）
3. `audit_effect_budget.py` 改为读数据（并给出它的曲线输出）
4. 重生成的派生镜像 + 漂移归零证据
5. 测试：更新的过期用例 + 30 个值的逐值断言 + 钳位 + 降转不双扣
6. **`ai-system/tasks/p3b1-role-curves-result.md`**（Caveman Review Packet）

ACCEPTANCE
- `python game/world-model/tools/accept.py --smoke 10` 退出码 0
- `python game/world-model/tools/check_upstream_drift.py` 退出码 0
- `game/data/gu.json` **零改动**（`git status` 证明）
- `game/data/v1_battle.json` 的 diff **只落在 `default_effect_by_role` 内**
- `game/wenzhen-web-lab/**` 零改动
- `game/scripts/domain/` 的 diff 只落在本包列出的两个函数的范围内
- Godot 全量 unit 通过（**必须 console 版**：`GODOT_PATH` 指向
  `…Godot_v4.7.2-stable_win64_console.exe`；**判定通过只看真实 GUT 文本
  （Passing/Failing/Asserts），不看退出码**——非 console 版 headless 零输出且退 0）
- 结果包写入 `ai-system/tasks/p3b1-role-curves-result.md`

STATUS TARGET
READY_FOR_P3B1_REVIEW
```

## 技术事实（L2 已核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 裁定原文 | `game/world-model/rulings/RUL-2026-09-19-011.json`（B1–B6 可执行，B7 缺定义） |
| 现行兜底曲线 | `default_effect_by_role` = attack 2 / defense 3 / healing 2 / logistics 1 / movement 1 / recon 1，配 `amount + (rank-1)` 线性律 |
| 线性律位置 | `v1_battle_resolver.gd:174`（`if RANK_SCALED_KINDS.has(kind)`） |
| `RANK_SCALED_KINDS` | `v1_battle_resolver.gd:29` = `["strike","shield","heal"]`；另用于 `:205` 降转下调 |
| 兜底表校验器 | `content_catalog.gd:1191-1228` `_validate_v1_battle_role_defaults`（现断言 `amount` 是正整数） |
| 兜底表读取点 | `v1_battle_resolver.gd:41` `role_default_table()`；消费者 `:186` `_build_gu_slots`、`hall_snapshot.gd:230` |
| 审计工具里的第二份规则 | `game/world-model/tools/audit_effect_budget.py:70-72`（正则抠 `RANK_SCALED_KINDS` + 自套 `b+(r-1)`） |
| 镜像内嵌兜底 | `build_world_model.py:315-316`（`role_default.get(g["role"])` 写进每条蛊记录） |
| 覆盖规模 | 802 只蛊中 741 只（92%）无手写 `v1_effect`，走兜底 |
| 现行曲线倍数 | attack 3.0x / defense 2.3x / healing 3.0x / logistics 5.0x / movement 1.0x / recon 1.0x（对 40/80/160/320/640 的 16.0x） |
| **Godot 跑法坑** | 非 console 版 headless **零输出且退 0**（静默假绿）；判定只看 GUT 文本 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台 gb2312，**必须** `PYTHONIOENCODING=utf-8` |
| `.ps1` 必须纯 ASCII | 跑 `.ps1` 用 `pwsh` |

## 执行前置条件（**两条都满足才能开工**）

**① L1 必须先裁镜像写法（P1/P2/P3）。**
见 §D 与 `ai-system/RESEARCH-REQUEST-2026-09-19-p3b-addendum.md` §4。
未裁前本任务**不派工**——D 节的产物（派生镜像）是本改动的必经产物，
镜子写法未定就无法产出可验收的结果。

**② 工作树必须干净。**
`game/scripts/domain/v1_battle_resolver.gd` 上另有在途改动（SIDE-FIX 敌人运行时补线 + 其返工）。
开工前跑 `git status --porcelain`：**若该文件仍有未提交改动，停下来上报**，不要在其上叠加。

## Execution rules

- Worker class: `normal`。
- 改 `game/` 下任何文件前先 `python game/world-model/tools/snapshot.py take p3b1-role-curves`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/p3b1-role-curves-result.md`**。
