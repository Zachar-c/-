# L2 Review · SIDE-FIX 敌人运行时补线 + data→runtime 契约测试

> 状态：**代码层 Review 已完成**；结果包（`side-fix-enemy-runtime-result.md`）与测试实跑证据**尚未到达**，
> 到达后补 §4/§5 再出终审。
> 被审对象：`ai-system/tasks/side-fix-enemy-runtime.md` 的产出。
> 上游裁定：`RUL-2026-09-19-010`（SIDE-FIX: phases GO / essence_burn GO / sparked 有明确语义才 GO /
> 新增最小 data→runtime contract test）。

---

## 1. 交付物清点（对照任务包 DELIVERABLE）

| # | 要求 | 现状 | 判定 |
|---|---|---|---|
| 1 | `phases` 运行时（选阶段 / 冷却门禁 / 切换记录） | `v1_battle_resolver.gd` 新增 `active_phase_index` / `_intent_ready` / `select_enemy_intent` / `_merge_phase_intent`，并接入 `_resolve_enemy_intent` | 已交付 |
| 2 | `essence_burn` 接线 + 结算 | facade 白名单补齐；resolver 扣玩家真元并记 `essence_burn` 日志 | 已交付，见 §3.2 一处语义瑕疵 |
| 3 | `sparked` 取证结论 | 契约测试里以 `EXEMPT_VALUES` 登记「全仓零语义定义，待 L1 裁决，禁止臆造」 | 已交付 |
| 4 | data→runtime 契约测试（含负控 + 豁免表） | `test_enemy_data_runtime_contract.gd`（196 行） | 已交付，见 §3.1 一处口径问题 |
| 5 | 结果包 | **未到达** | 待 |

---

## 2. L2 已独立核验为「对」的部分

### 2.1 cooldown 语义与数据自带说明逐条一致

数据里唯一写了语义的字段是 `data/enemies.json → miasma_vein_lord._phases_note`，原文：

> cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of
> the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds
> (until_hp_ratio) descend strictly in data order.

实现 `_intent_ready` = `turn >= last_fired + max(cooldown,0) + 1`，与「T+n+1」一致；
全冷却时返回 `{}` 并记 `cooldown_wait`、该回合不做任何事，与原文一致；
`active_phase_index` 取「数据顺序中最后一个 `until_hp_ratio >= 当前血量比`」，与「严格递减」一致。**无偏离。**

### 2.2 选阶段的初值不会产生伪 `phase_shift`

`_build_enemies` 在建敌时即把 `phase_index` 置为当前血量比对应阶段，满血即 0。
因此首回合不会刷一条「转入第 1 阶段」的伪记录。这是正确决定（任务包只要求「切换要有可观测记录」，
未要求首回合必须记一条）。

### 2.3 焚元扣减的位置正确

焚元结算被放在 **sealed 门禁之后**（`_resolve_enemy_intent` 里 sealed 分支 `return next` 早退），
所以「被 sealed 吞掉的意图不触发焚元」成立，与代码注释一致。扣减下限 0，写日志，未改任何数值。

### 2.4 本轮没有越界改数据

`git status` 显示 `game/data/**` 零改动；`game/wenzhen-web-lab/**` 零改动；改动只落在
`v1_battle_resolver.gd`、`battle_command_facade.gd` 与两个新增测试文件上。**符合 SCOPE。**

### 2.5 曲线不存在的地方没有自行发明

`sparked` 的语义没有被臆造（测试里显式断言 preview/resolver 源码**不含** `sparked` 字样），
符合 L1「有明确语义才 GO」与任务包「禁止发明语义」。**这是本批最值得肯定的判断。**

---

## 3. 发现的问题

### 3.1 `phase.reactions` 被记为「有消费点」，但运行时并不读它 —— FIX

契约测试的 `COVERAGE` 表把 `phase.reactions` 的消费点写成
`enemy_catalog._validate_phases schema (structural container)`。

**那是 schema 校验器，不是运行时消费点。** 实测（本轮全仓检索）：

- `phases` 在 `game/scripts/` 下只有两类读取：
  ① `enemy_catalog.gd` 的 `_validate_phases`（校验形状）；
  ② `v1_battle_resolver.gd` 的 `active_phase_index` / `select_enemy_intent` 读 **`phases[].intents`**。
- **`phases[].reactions` 在 `game/scripts/` 下零读取。** 反击链路读的是敌人**顶层** `reactions`。

即：`phases[].intents` 这轮接通了，`phases[].reactions` **没有接通**——两者是同一个数据设计的两半。

**当前是否在爆：不在。** 实测 5 个带 `phases` 的 Boss，**每一个阶段的 `reactions` 都与顶层逐字相同**
（`miasma_vein_lord` / `blood_vein_bishop` / `clan_patriarch` / `blue_fur_jiangshi` 各 1 条、
`thunder_crown_sovereign` 两份都是空），所以行为上暂时无差异。属**潜在缺口**。

**为什么算 FIX 而不算「可接受」**：这份契约测试的存在意义就是抓「数据声明了但没接线」。
把一条**确实没接线**的字段登记成「已覆盖」，正好让它失效在最该生效的地方；
而且它会给未来的人一个错误的安全感——一旦有人写出「阶段 1 换个反击」的数据，测试会报绿。

**要求的修法（二选一，推荐前者）**：
- 把 `phase.reactions` 从 `COVERAGE` 移到豁免表，原因写明真实情况，例如
  「runtime 只读顶层 `reactions`；每阶段反应表未接线。当前 5 个 Boss 的每阶段表与顶层逐字相同，
  故为潜在缺口，非在爆 bug；接线需先裁『阶段反应表是替换还是追加』，属设计问题」。
- 或者把它真正接上——**但**「替换还是追加」数据没写，属设计裁决，**Worker 不得自行决定**，
  若选此路先停下上报。

### 3.2 `essence_burn` 的守卫与注释不一致 —— FIX（小）

代码：

```gdscript
var burn := int(intent.get("essence_burn", 0))
if is_damage_intent and burn > 0:
    next["player"]["true_qi"] = maxi(0, int(next["player"]["true_qi"]) - burn)
    _log(next, "essence_burn", str(enemy["id"]))
```

注释写「**意图实际发出即扣**玩家真元」，但守卫是 `is_damage_intent`；且这段代码整体位于
`match kind:` 的 `"attack"` 分支内。**后果**：一个 `kind` 非 `attack` 的意图即使声明了
`essence_burn`，也会被**静默丢弃**——正是本任务要消灭的那类「数据声明、无人消费」。

**当前是否在爆：不在。** 数据里只有 `thunder_crown_sovereign.phases[1].intents[1]`（`paralyzing_howl`）
带 `essence_burn: 2`，它没有 `kind` 字段 → 缺省按 `attack` 处理 → 能正常结算。属潜在缺口。

**要求的修法**：让代码与注释二者一致，并用测试钉住，二选一：
- （推荐）把焚元结算移出 `"attack"` 分支、放到「意图确实执行」的位置（仍在 sealed 门禁之后），
  使其对任何 kind 生效，并补一条合成夹具（`kind: "seal"` + `essence_burn`）证明它仍扣；
- 或保留 `is_damage_intent` 守卫、把注释改成与之一致，并补一条测试钉死「非伤害意图不焚元」。

`essence_burn` 的实现结构属 Worker 权限（任务包 DECISION AUTHORITY），故本条只需二者自洽 + 有测试。

### 3.3 既有夹具的改动是**合法**的（已核）

`test_battle_command_facade.gd:570` 的 `test_layer_boss_scaling_rounds_floors_and_preserves_nonattack_intents`
被改了：它用 `assert_eq(mapped_intent, {...})` 对意图字典做**整字典相等**断言，
而 facade 这轮确实多透传了 `id` / `cooldown` / `essence_burn`，所以期望值必须同步。

**这不是「改测试使其变绿」，是契约变了、期望值跟着变**，改动只加了三个键、未删任何断言。

L2 另核了这条形状变化对存档的影响：`test_battle_save_load_semantics.gd` 用的是
「两次快照 `JSON.stringify` 相等」的**自比对**（`:128`），不是固定夹具，故新增键不会破坏它；
战斗存档是快照而非带 schema 版本的 delta，加键是兼容的。**结论：安全。**

### 3.4 观察（不改，仅记录）

- **阶段切换当回合即使用新阶段意图**：`phase_shift` 记录与按新阶段选招发生在同一回合。
  与 Web 原型（本轮唯一已验证参照）一致，但数据没写这条语义。记录备查，不改。
- **多意图优先级取数据顺序**：数据未写明，任务包已授权取数据顺序并要求标注为原型口径。
  结果包需确认已标注。
- **契约测试的负控强度**：`test_negative_control_erased_coverage_is_caught` 是「复制 COVERAGE、
  抹掉一个键、调 `_check`」——它证明的是**检查器**有效，不是**真实流水线**有效。
  较强的那条是 `test_consumption_markers_exist_in_sources`（真读源码文件断言消费点标记存在）：
  临时删掉 facade 白名单里的 `essence_burn`，这条会红。**结果包需给出后者的实做负控证据**
  （任务包 ACCEPTANCE 要求「去掉一个消费点 → 测试必须失败（附输出片段）」）。

---

## 4. 测试实跑证据（L2 亲自复跑，不依赖结果包）

### 4.1 逐项对账

| 项 | Worker 报 | L2 实测 | 结论 |
|---|---|---|---|
| `test_enemy_phases_runtime` | 8/8, 31 asserts | **8/8, 31 asserts** | 一致 |
| `test_enemy_data_runtime_contract` | 7/7, 31 asserts | **7/7, 31 asserts** | 一致 |
| 全量 unit | 221 scripts / 1619 tests / 54126 asserts 全过 | **221 / 1619 / 54126 全过**（142.06s，GUT 原文 "All tests passed!"，RC=0） | 一致 |
| `accept.py` | 64635 checks / 0 fail, exit 0 | `validation-report.md` 64635 / 0 | 一致 |
| `check_upstream_drift.py` | exit 0（**204** items） | exit 0，**检查项 5204｜漂移项 0** | 结论对，**数字错一位** |
| `game/data/**` 零改动 | 是 | `git status` 证实零改动 | 一致 |
| `wenzhen-web-lab/**` 未动 | 是 | 23:35 后无文件被改（该目录**未被 git 跟踪**，故只能按 mtime 判，非 git 证明） | 一致 |
| SABOTAGE 已复原 | 是 | `test_world_model_bridge.gd` 无未提交改动，即处于提交态 | 一致 |

**本轮 Worker 的数字全部可信**，仅漂移项计数少了一位（5204 报成 204，属抄写错误，
不影响结论）。已要求其在结果包更正（见 FIX 包 C）。

### 4.2 关键命令（可复核）

```powershell
# 必须用 console 版——本机 GODOT_PATH 仍指向非 console 版，直接用 test.ps1 会静默假绿
$g = & ./game/tools/godot.ps1 -Console
& ./game/tools/run_gut_checked.ps1 -CommandPath $g -CommandArguments @(
  '--headless','--path','<repo>\game','-s','addons/gut/gut_cmdln.gd',
  '-gdir','res://tests/unit','-gexit','-glog=2')
```

### 4.3 副作用说明

`game/world-model/reports/validation-report.md` 是被跟踪文件，跑验收就会重写它；
本次 diff 仅一行时间戳（23:20:22 → 23:50:04），非 Worker 交付物，提交时随代码带上即可。

---

## 5. 终审

**REVIEW STATUS: FIX REQUIRED**（已派 `ai-system/tasks/side-fix-enemy-runtime-fix.md`）

代码层的两处问题（§3.1、§3.2）都已开成小返工包，均属**同一类病**——数据声明了但没人消费——
正是本任务存在的理由。除此之外：

- `phases` 与 `essence_burn` 的接线**做对了**（cooldown 语义与 `_phases_note` 逐条一致，
  焚元扣减位于 sealed 门禁之后）
- `sparked` 的「不臆造、登记待裁」判断**做对了**（L2 独立复核确认全仓无语义定义）
- 既有夹具的改动**合法**（契约变了、期望值跟着变，只加键未删断言）
- 全部数字**经 L2 亲自复跑证实**，与结果包一致
- 派生镜像未见漂移，`game/data` 零改动，Web 线未碰

修完即可提交（连同 `RUL-2026-09-19-010/011`、`game/AGENTS.md` 不变量、两份 RR 与任务包）。
提交后 P3-B1 才可开工——它与本批改同一个文件。

---

## 6. FIX 轮（2026-09-20 00:04）— 已复审通过

返工包：`ai-system/tasks/side-fix-enemy-runtime-fix.md`

### 6.1 两处都改对了

**§3.1 `phase.reactions`** —— 已从 `COVERAGE` 移入 `EXEMPT_FIELDS`，原因写明三点且与 L2 的取证一致：
运行时只读顶层 `reactions`（引了 `action_preview_service.gd:338/:1056` 两处读取点）、
`phases[i].reactions` 零读取（resolver 只碰 `until_hp_ratio`/`intents`）、
5 个 Boss 的每阶段表与顶层逐字相同故为潜在缺口、
接线前须先裁「替换 vs 追加」。**未自行接线**，符合裁决纪律。

**§3.2 焚元守卫** —— 选了推荐路径：结算移出 `match kind:` 的 `"attack"` 分支，
放到 `_resolve_enemy_intent` 末尾，守卫只剩 `if burn > 0`。
L2 核对了两条早退确实在它之前：`cooldown_wait`（`select_enemy_intent` 返回空即 `return next`）
与 `sealed` 门禁（`return next`）。所以「能走到这里 = 意图确实发出」成立，注释与代码自洽。

行为上对现有数据**零漂移**（唯一带 `essence_burn` 的 `paralyzing_howl` 无 `kind`，缺省 attack），
但语义变成「任何 kind 发出的意图都焚元」——这正是注释原先声称的语义。

### 6.2 L2 独立复跑

| 项 | Worker 报 | L2 实测 |
|---|---|---|
| contract | 7/7, 31 asserts | **7/7, 31 asserts** |
| phases | 9/9, 33 asserts | **9/9, 33 asserts**（新增 `test_seal_kind_phase_intent_settles` 断言 seal 类意图也焚元） |
| 全量 unit | 未重跑（任务只要求聚焦） | 见 §6.3 |

**负控的论证方式补充说明**：Worker 报「临时删掉 resolver 里 `essence_burn` 字样 →
`test_consumption_markers_exist_in_sources` 变红」。L2 未重做这次文件变异
（被改文件带未提交改动，变异+还原有风险），改为**按构造论证**：
该测试断言 `FileAccess.get_file_as_string(RESOLVER_PATH)` 非空且
`source.contains("essence_burn")` 为真；测试整体通过 ⇒ 两条断言都真的执行且成立
⇒ 一旦源码里的 `essence_burn` 被删，该断言必然失败。结论与 Worker 一致。

### 6.3 全量回归（L2 亲自跑，console 版）

```
Scripts             221
Tests              1620
Passing Tests      1620
Asserts           54128
Time              182.033s
---- All tests passed! ----
RC=0
```

与返工前（221 / 1619 / 54126）相比：**+1 用例、+2 断言**，正是新增的
`test_seal_kind_phase_intent_settles`，无其它变化 ⇒ 焚元移位**未波及任何既有用例**。

结尾的 `8 ObjectDB instances were leaked` / `2 resources still in use` 为**既有**残留噪声
（返工前同样存在，`game/AGENTS.md` 已记为已知残余风险），非本批引入。

### 6.4 复审结论

**REVIEW STATUS: PASS**（两处 FIX 均按要求完成，且未越界：`game/data/**` 零改动、
Web 线未碰、本轮已通过的行为未动）。

仍待上抛（不阻塞提交）：
1. `phases[].reactions` 的「替换 vs 追加」语义 → 设计裁决
2. `sparked` 的语义 → L1（现已以豁免登记，测试会一直提醒）
3. 焚元 2 被每回合回复吃掉（机制通、威胁为零）→ 平衡问题，非实现问题
