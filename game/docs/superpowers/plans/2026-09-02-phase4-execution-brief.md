# 阶段四执行交接单：离散回合战斗核心（T4.1 + T4.2 + T4.3）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §10.4（防御结算顺序）、§12.1-§12.6（念头、使用权、回合阶段、跨回合、反应窗口）、§13.1-§13.7（基础动作、距离、脱离、速度、闪避、擒抱）、§14.1-§14.3（肉身、超载、野兽）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `e9a048a`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至三已合入。阶段三审查结论：**通过**。全量 `-Suite all` 退出码 0、零失败（unit 996/995 + 1 个 pre-existing risky `test_no_duplicate_ids_in_real_catalog`；integration 13/12 + 1 个 pre-existing pending `test_drive_to_ending`）。
- 行数门禁：`resolver.gd` 2452 ≤ 2457、`battle_resolver.gd` 1514 ≤ 1516。
- 可复用的领域模块（**必须薄委托，禁止第二份实现**）：
  - `GuBalance`（`gu_balance.gd`）：`beast_scale(rank, cat)`、`fixed_defense(rank, cat)`、`unarmed_raw_damage(strength, action_multiplier, cat)`、`overload_self_damage(strength, capacity, cat)`、`human_standard_heal`——战斗数值全部从这里出；
  - `CultivatorRules`（`cultivator_rules.gd`）：`thought_capacity(_cultivator, catalog)`（§12.1 念头容量，与魂魄零耦合）、`can_activate`；
  - `GuInstance`（`gu_instance.gd`）：实例字典的唯一形状拥有者。
- **架构边界**：本批新建 `scripts/domain/battle2/` 目录下的**纯领域模块**，不接 UI、不改 `battle_resolver.gd`（旧连续时间战斗在阶段九对接快照/命令面、阶段十 T10.1-⑥ 才删除）。battle2 模块之间以及对外都**不得引入任何随机调用**（确定性红线 §17.3）。

---

## 任务 0：阶段三收尾微补丁（1 个小提交，先于 T4.1）

- `scripts/domain/gu_instance.gd` 与 `scripts/domain/cultivator_rules.gd` 缺 EOF 换行（连续第二批新建文件漏换行，建议执行 agent 在提交钩子里自查）。
- 提交信息：`fix(spec-v4): phase-3 eof newlines`。验收：`git diff --check` 干净 + 全量绿。

### 挂账（不在本批处理，写进完成报告即可）

- `CultivatorRules.wisdom_bonus(catalog)` 目前统计的是**全目录**智道蛊数量而非玩家**持有**的智道蛊——当前 `gu.json` 无智道标签蛊（已核实 bonus 恒为 0，注释已声明占位）。智道内容批次落地时必须改为按 `RunState.gu_instances` 统计，届时 `thought_capacity` 签名要接 cultivator。
- `GuInstance.SAVE_KEYS` 含 `uses_left` 但工厂不产默认值——等"有限次数"生命周期内容落地时补。

---

## T4.1 回合阶段与使用权账本（提交 B）

- **固定接口**：新增 `scripts/domain/battle2/turn_engine.gd`（`class_name Battle2TurnEngine`，纯静态/纯数据）：
  1. **回合阶段序列**（§12.4）：`声明动作与敌方意图 -> 瞬时 -> 快速（含反应窗口）-> 标准 -> 蓄势开始或完成 -> 回合结束`；双方同阶段各维护动作序列、逐轮对齐结算；互不冲突同时生效，仅同阶段同轮直接冲突才比速度；一方耗尽后另一方继续；前置失败/目标死亡/距离失效自动停依赖动作；打断条件逐动作声明（无全局"受伤必打断"）。
  2. **念头池**（§12.1/§12.2）：每回合开始已耗念头清零、重置为 `CultivatorRules.thought_capacity`；**主动维持先占用**；复杂度档位 1/2/3（由操控复杂度决定，与转数无关）；瞬时催动结算后不持续占用但已耗不返还；自持/主动维持持续占用；预留念头可作反应。
  3. **使用权账本**（§12.3）：每回合每实例最多主动催动一次（同名两实例各一次）；四基础动作（移动/徒手攻击/闪避/擒抱）每回合各一次；主动维持中的蛊本回合不可再催动；并行组去重（同组不得重复动作种类或重复实例）；跨回合动作续推进时占用当回合对应使用权；仅明确声明的分身/额外实体可突破实例唯一性。
  4. `can_enact()` 预检：同一函数源供预检与执行（§17.3 预检同源红线），拒绝时给结构化 reason。
- **先红后绿**：新增 `tests/unit/test_battle2_turn_ledger.gd`——**挂接验收 #4**：同实例同动作回合内重复拒绝；同名两实例分别催动通过；并行组重复（动作种类/实例）拒绝；跨回合动作占用下一回合使用权；维持中蛊再催动拒绝；念头池每回合清零且维持先占用；复杂度 1/2/3 扣减正确。
- **最小实现**：纯模块 + 纯数据战场字典（battle2 自己的状态形状，本批自定义，阶段九对接快照时再统一）；**不接 UI、不动 `battle_resolver.gd`**。
- 验收：`tools/test.ps1 -Test "tests/unit/test_battle2_turn_ledger.gd"` + `-Suite all`。
- 退出条件：#4 绿；**账本零随机**（测试内断言模块源码不含 `SeededRoll`/`roll`/`rand` 调用，`grep` 审计写入报告）；resolver 行数不增。

## T4.2 基础动作、距离与防御结算（提交 C）

- **固定接口**：新增 `scripts/domain/battle2/action_resolver.gd`：
  1. 四基础动作（§13.1）：移动/徒手攻击/闪避/擒抱各耗 1 念头；等待、取消、预留是回合指令不是动作。
  2. 四级距离带（§13.3）：`接触/近距/中距/远距`；基础移动一次一档；徒手攻击仅接触距离发起并命中；结算前目标离开接触则攻击停止（念头不返还、实体资源不扣）。
  3. 动作完成时点结算（§13.2）：徒手攻击完成时造成伤害。
  4. 脱离接触反应窗口（§13.4）：接触→近距开放一次反应窗口；无免费攻击；对方须预留念头且有合法反应才能拦截/擒抱；成功则移动停止，移动先成立则接触类反应失去条件。
  5. 速度冲突（§13.5）：`conflict_speed = current_speed + action_speed_modifier`；仅同阶段同轮直接冲突时比较；快者先结算且可破坏慢者条件；相同则同时结算（可同归于尽）；阶段优先于速度；速度不加动作数/念头/命中率；普通人基础速度 3、常见范围 1-5、修正 -1/0/+1（进 balance.json：`base_speed`、`speed_min`、`speed_max`，Schema 同步）。
  6. 防御结算顺序（§10.4）：`攻击原值 -> 临时防护吸收 -> 身体固定防御 -> 比例减免 -> 统一气血`；固定防御可降至 0、无强制最低伤；每效果声明 `stack_group`/叠加方式/上限，同机制递减受中央上限约束。
  7. 野兽 `beast_scale` 接入（§14.3）：气血/天然力量/承载 = `GuBalance.beast_scale(rank)`，同级重击 = 力量 × `unarmed_damage_ratio`，天然固定防御 = `GuBalance.fixed_defense(rank)`——**表值全部经 GuBalance 投影，禁止写死**。
- **先红后绿**：新增 `tests/unit/test_battle2_actions_defense.gd`——**挂接验收 #13**（固定防御把伤害降到 0；耐久防护被多次攻击逐步消耗、单次可耗尽）、**#14 行为半边**（同转野兽以独立量级接战：同转人兽对抗按 §14.3 表结算）、**#16 部分**（距离带、速度冲突、脱离接触全部离散回合结算，无连续时间单位/小数进度）。
- **最小实现**：纯模块；敌方意图池与 `battle_resolver` 的对接挂阶段九。
- 验收：`tools/test.ps1 -Test "tests/unit/test_battle2_actions_defense.gd"` + `-Suite all`。
- 退出条件：#13/#14/#16 部分 绿；`battle_resolver.gd` 行数不增；数值无第二实现点（drift 门禁通过）。

## T4.3 确定性闪避、擒抱与力量超载（提交 D）

- **固定接口**：新增 `scripts/domain/battle2/body_rules.gd`：
  1. **确定性闪避**（§13.6）：攻击声明是否允许基础闪避并开放窗口；玩家预留并支付 1 念头；闪避在快速阶段完成且未被擒抱/束缚/场地限制 → **确定避开**；不改变距离带；范围/追踪/封锁空间攻击可明确禁止；**无随机命中率检定**，失败只来自条件不满足或直接冲突失败。
  2. **确定性擒抱**（§13.7）：仅接触距离发起、1 念头、默认标准阶段；目标可在反应窗口闪避；未避开则力量对抗——目标不投入念头抵抗即成立；抵抗时双方声明实际力量（`CultivatorRules.body` 投影 + 蛊效修正），发起者更高才成立，**平手利于防守方**；双方可主动超承载并各自按 `GuBalance.overload_self_damage` 结算；成立后保持接触、被擒抱者普通移动不能拉开距离、**不自动禁催蛊**；维持者每回合占 1 念头 + 擒抱使用权，停止即松开；挣脱用擒抱动作再对抗。
  3. **力量超载**（§14.2）：`safe_strength = body_capacity`；对外原始伤害 `GuBalance.unarmed_raw_damage`；自伤只按超出承载部分 = `GuBalance.overload_self_damage`；**预计直接死亡必须走强制二次确认路径**（预检返回可预见死因标记，供快照/命令面展示；红线：不允许静默致死）。
- **先红后绿**：新增 `tests/unit/test_battle2_dodge_grapple_overload.gd`——**挂接验收 #15**（超载只按超出承载部分自伤；普通气血损失不降低承载/力量/速度）、**#16 收口**（闪避/擒抱/脱离/速度全部离散确定性规则，断言无随机检定）；平手利于防守方；被擒抱不禁催蛊；维持断供即松开；预计致死二次确认标记存在。
- **最小实现**：纯模块；预检文案（含死因标记）挂阶段九 T9.1 快照。
- 验收：`tools/test.ps1 -Test "tests/unit/test_battle2_dodge_grapple_overload.gd"` + `-Suite all`。
- 退出条件：#15/#16 绿；死亡可预见红线断言在位；resolver 行数不增。

---

## 全局纪律（每一批）

1. 每任务独立提交：`feat(spec-v4): T4.x ...` / `test(spec-v4): T4.x 先红测试`；补丁提交 `fix(spec-v4): ...`。
2. 先红后绿：新测试先在现状下失败（battle2 模块不存在时测试应加载失败或断言失败），证据写进提交说明。
3. battle2 是**纯领域**：不 preload UI/presentation；不写 `RunState` 之外的共享可变状态；模块间经参数传值；零随机（`SeededRoll` 也不得用——战斗结算在规格下是确定性的，随机只在敌人生成等池管理场景，若确需必须先在报告里给裁定理由并经确认）。
4. resolver 门禁：`resolver.gd` ≤ 2457（当前 2452）、`battle_resolver.gd` ≤ 1516（当前 1514）；T4.x 不触碰这两个文件。
5. 禁区目录只读；标识符 ASCII、玩家文案 UTF-8；调参进 `balance.json` 过 Schema。
6. 测试基线只增不回退；发现跨阶段缺陷记录报告，不夹带。
7. 新文件一律带 EOF 换行。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；battle2 战场状态字典的形状说明（阶段九快照对接要用）；零随机审计 grep 输出；`battle_resolver.gd` 行数前后对比；`-Suite all` 最终数字；挂账项确认；未验证风险与遗留问题。
