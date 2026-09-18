# 蛊虫、炼蛊、养蛊、经济与战斗总规格 · 实施计划

> 日期：2026-09-01
> 权威规格：[2026-09-01-gu-system-economy-combat-design.md](../specs/2026-09-01-gu-system-economy-combat-design.md)（用户已批准的权威机制基线）
> 执行纪律：**10 个阶段、20 个独立提交任务**；每个任务先写可失败的测试（先红后绿），再做最小实现，跑验收命令，独立提交。阶段之间设退出条件，未达退出条件不开下一阶段。
> 反目标：**不再把新规则塞进 `resolver.gd`（2457 行）与 `battle_resolver.gd`（1516 行）两个上帝文件**。全部新规则落在独立纯领域模块；两个 resolver 只保留编排职责并在阶段十收缩。

## 0. 全局不变量（每一批都必须守住）

1. **命令边界**：UI 只读快照、只提交命令；领域规则是可测试的纯 GDScript（AGENTS 实现约定）。
2. **事件日志**：§17.3 全清单动作（催蛊/炼蛊/核心确认与更换/喂养/交易/收取/释放/采血/收魂/魂魄变化/战斗结算）写入不可变结构化事件日志；条目 append 后浅共享不可原地改写（既有守卫）。
3. **确定性**：所有 roll 经 `SeededRoll`/`PoolManager` 唯一入口；已知蛊方、普通炼化、确定性闪避不得偷偷随机（§17.3）。
4. **预检同源**：预检与执行同一函数源；拒绝时不改状态、不耗实体资源。
5. **resolver 增长门禁**：`resolver.gd ≤ 2457` 行、`battle_resolver.gd ≤ 1516` 行（T1.2 落守卫测试，常驻全量回归）。
6. **测试基线只增不回退**：当前 864 unit（+1 既有 risky）+ integration；每任务提交后 `tools/test.ps1 -Suite all` 必须全绿。
7. **同一 Run 不混用两套真值**（§18 迁移纪律）：新领域字段只进 v4 Run 存档；旧 v3 Run 由 T1.1 门禁拒载，不存在新旧并存的进行中 Run。
8. **源代码标识符 ASCII，玩家可见中文 UTF-8**；调参一律 JSON + Schema 校验（§16.22）。

---

## 阶段一：存档门禁与地基

### T1.1 存档版本门禁 v4（提交 1）

- **固定接口**：`scripts/domain/save_repository.gd`：`SAVE_VERSION = 4`；v3 进行中 Run 载入返回 `{"ok": false, "reason": "schema_v4_required", "message": "规则版本已升级，旧进行中冒险无法继续；大厅进度、蛊方图鉴与已解锁信息已保留。"}`；大厅档迁移字段 `codex / recipes_unlocked / contract_unlocked / stats` 逐字段保留（§0.1）。
- **先红后绿**：新增 `tests/unit/test_save_gate_v4.gd`：断言 v3 Run 拒载且文案可理解、大厅三字段迁移零丢失、v4 Run 读写 round-trip。先在 v3 现状下红（SAVE_VERSION 仍为 3）。
- **最小实现**：只改 `save_repository.gd` 版本号、拒载分支与大厅迁移保留逻辑；不触碰任何领域规则。
- **验收命令**：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test "tests/unit/test_save_gate_v4.gd"`；再跑 `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`。
- **退出条件**：全量绿；`tools/crash_recovery_check.ps1` 若依赖存档版本需同步更新并 PASS。

### T1.2 中央数值模块骨架 + resolver 增长门禁（提交 2）

- **固定接口**：新增 `data/balance.json`（§17.1 中央平衡配置全清单键：`rank_step_ratio=2.0`、`standard_hit_ratio=0.2`、`human_base_health=100`、`unarmed_damage_ratio=0.2`、`standard_activation_cost=0.1`、`light_cost_ratio=0.5`、`heavy_cost_ratio=2.0`、`natural_recovery_cost_ratio=0.1`、`material_refine_efficiency=0.5`、`feed_tier`（small 0.5/standard 1.0/large 2.0）、`fixed_defense_ratio=0.2`、`stone_per_t1_material=10`、`public_buyback_ratio=0.5`、`low_liquidity_ratio=0.3`、`demand_price_tiers=[0.8,1.0,1.2]`、`dragon_fish_replacement`（50/70/80/90/95）、`quick_substitute_cap=0.5`）+ 新增 `scripts/domain/gu_balance.gd`（`class_name GuBalance`，静态纯函数：`rank_multiplier(rank)`、`standard_gu_power(rank)`、`beast_scale(rank)`、`fixed_defense(rank)`、`human_standard_heal(rank)`、`actual_cost_percent(native, gu_rank, cultivator_rank)`、`natural_recovery(aptitude)`，全部从 balance.json 取参，不写死数组）。
- **先红后绿**：新增 `tests/unit/test_resolver_growth_gate.gd`（断言两个 resolver 行数 ≤ 基线，现状绿、作为常驻门禁）+ `tests/unit/test_gu_balance_schema.gd`（balance.json 缺键/负值/越界红）。Schema 校验接入 `ContentCatalog.validate` 生产路径（终结 §16.22"生产零调用"P2 项）。
- **最小实现**：`data/balance.json` + `gu_balance.gd` + ContentCatalog Schema 键；不改任何现有行为。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_gu_balance_schema.gd"` + `-Test "tests/unit/test_resolver_growth_gate.gd"` + 全量。
- **退出条件**：门禁测试常驻全量回归；balance.json 单一真值成立（全仓 grep 无第二处写死 `2.0` 倍率表挂账阶段十复核）。

---

## 阶段二：中央数值实装

### T2.1 数值公式与锚点（提交 3）

- **固定接口**：`GuBalance` 六个导出函数按 §10.1/§10.2/§10.3/§10.5/§14.2/§14.3 实装并出锚点数值。
- **先红后绿**：新增 `tests/unit/test_central_numbers.gd`，逐数断言：`rank_multiplier(1..5)=1/2/4/8/16`；`standard_gu_power=40/80/160/320/640`；固定防御 `4/8/16/32/64/128`；治疗 `20/40/60/80/100`；`beast_scale` 气血/力量/承载 `100..3200`、同级重击 `20..640`、固定防御 `4..128`；徒手 `100*0.2=20`；超载公式（§14.2）；自然恢复 `0.7/1.0/1.5`（§11.4）。
- **最小实现**：仅 `gu_balance.gd` 函数体 + balance.json 参考值复核。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_central_numbers.gd"` + 全量。
- **退出条件**：锚点数值与规格 §10/§14 表逐位一致；**挂接验收 #14**（蛊师 100 尺度、野兽独立倍增肉身——数值半边）。

### T2.2 内容数据档位化（提交 4）

- **固定接口**：`gu.json`、`enemies.json`、`loot_tables.json`、`shops.json` 条目改声明 `rank / power_tier / cost_tier / feed_tier / value_tier` + 例外 `override_reason`（§17.1 末段）；`ContentCatalog` Schema：非 override 条目出现跨转数值字面量（如敌人直接写 `3200` 气血）即拒绝。
- **先红后绿**：新增 `tests/unit/test_content_tier_schema.gd`：先造一条写死数值的假条目红，修数据后绿；同时更新 `test_content_catalog.gd`。
- **最小实现**：Schema 键 + 现有表逐条补 tier 字段（数值仍由 GuBalance 导出，暂不改行为——行为切换在 T4.x/T10.1）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_content_tier_schema.gd"` + 全量。
- **退出条件**：全量内容表过 Schema；无内容对象复制中央最终值（§17.1）。

---

## 阶段三：蛊虫实例与蛊师模型

### T3.1 蛊虫实例实体（提交 5）

- **固定接口**：新增 `scripts/domain/gu_instance.gd`（`class_name GuInstance`，纯数据 + 工厂）：§2.1 全字段（definition_id / instance_id / rank / refine_state / core_state / hunger_phase / next_feed_need / lifecycle（一次消耗/有限次数/长期）/ 忠主、凶性、寄生、逃遁、封存 / 实例级改造及来源）；`instance_id` 全局唯一，同名蛊是不同实体。`RunState` 新增 `gu_instances`（v4 存档序列化只存 id 与数值）。
- **先红后绿**：新增 `tests/unit/test_gu_instance_model.gd`：同名两实例 id 不同、§2.1 字段齐备、序列化 round-trip 不含引擎对象（复用既有序列化守卫断言风格）。
- **最小实现**：实例模型 + RunState 字段；不动旧 deck/cards 字段（阶段十清退）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_gu_instance_model.gd"` + 全量。
- **退出条件**：v4 Run 可携带实例列表；旧字段无引用变更（零行为漂移）。

### T3.2 蛊师模型：真元海、念头、肉身（提交 6）

- **固定接口**：新增 `scripts/domain/cultivator_rules.gd`（`class_name CultivatorRules`）：`can_activate(cultivator_rank, gu_rank, low_rank_exception)`（§11.2 低转不能催普通高转；珍稀蛊 `low_rank_exception` 豁免）、`actual_cost_percent`（高转真元向下折算公式，仅 cultivator_rank ≥ gu_rank 时适用）、`natural_recovery`、念头容量 `3 + 智道蛊加成`（§12.1，与魂魄彻底分离）、肉身 `health=100 尺度 / strength / body_capacity`（§14.1，升转零自动增长）。
- **先红后绿**：新增 `tests/unit/test_cultivator_rules.gd`——**挂接验收 #5**（升转后念头/气血/承载逐字段不变）、**#6**（低转催高转拒绝；折算公式逐位断言，如 2 转蛊师催 1 转 10% 蛊 = `0.1*2/4=5%`、1 转催 2 转拒）、**#14 数值半边**（100 尺度）。
- **最小实现**：纯规则模块 + RunState 字段；旧真元行动点路径不动（T10.1 删）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_cultivator_rules.gd"` + 全量。
- **退出条件**：#5/#6 绿；soul_capacity.gd 旧上限逻辑标记待删（阶段十）。

---

## 阶段四：离散回合战斗核心

### T4.1 回合阶段与使用权账本（提交 7）

- **固定接口**：新增 `scripts/domain/battle2/turn_engine.gd`（`class_name Battle2TurnEngine`）：§12.4 阶段序列（声明动作与敌方意图→瞬时→快速（含反应窗口）→标准→蓄势→回合结束）、念头池（每回合清零、主动维持先占用、§12.1/§12.2 复杂度 1/2/3）、使用权账本（§12.3：每实例每回合一次、四基础动作各一次、并行组去重、跨回合动作占下一回合使用权）、`can_enact()` 预检。
- **先红后绿**：新增 `tests/unit/test_battle2_turn_ledger.gd`——**挂接验收 #4**（同实例同动作回合内重复拒绝；同名两实例分别催动通过；并行组重复拒绝；跨回合占用）。
- **最小实现**：纯模块；不接 UI、不动 battle_resolver.gd。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_battle2_turn_ledger.gd"` + 全量 + resolver 门禁。
- **退出条件**：#4 绿；账本无任何随机调用（grep 断言模块不 import SeededRoll 之外入口）。

### T4.2 基础动作、距离与防御结算（提交 8）

- **固定接口**：新增 `scripts/domain/battle2/action_resolver.gd`：四基础动作（§13.1 各 1 念头）、四级距离带（§13.3）、动作完成时点结算（§13.2）、脱离接触反应窗口（§13.4）、速度冲突 `conflict_speed`（§13.5，速度不增动作数/命中随机）、防御结算顺序（§10.4：临时防护→固定防御→比例减免→统一气血；固定防御可至 0 无强制最低伤；每效果声明 `stack_group`/叠加方式/上限）、野兽 `beast_scale` 接入（§14.3，表值由 GuBalance 生成）。
- **先红后绿**：新增 `tests/unit/test_battle2_actions_defense.gd`——**挂接验收 #13**（固定防御把伤害降到 0；耐久防护被多次攻击逐步消耗）、**#14 行为半边**（同转野兽独立量级接战）、**#16 部分**（距离带、速度冲突、脱离接触全部离散回合结算，无连续时间单位）。
- **最小实现**：纯模块；敌方意图池与 battle_resolver 的对接挂阶段九。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_battle2_actions_defense.gd"` + 全量 + resolver 门禁。
- **退出条件**：#13/#14/#16 部分 绿；`battle_resolver.gd` 行数不增。

### T4.3 确定性闪避、擒抱与力量超载（提交 9）

- **固定接口**：新增 `scripts/domain/battle2/body_rules.gd`：确定性闪避（§13.6：攻击声明开放窗口+玩家预留 1 念头+未被擒抱/束缚→确定避开，无随机命中）、确定性擒抱（§13.7：接触距离发起、力量对抗、平手利于防守、维持 1 念头/回合、挣脱再对抗、不自动禁催蛊）、力量超载（§14.2：`unarmed_raw_damage`、`safe_strength`、`overload_self_damage`；预计直接死亡强制二次确认）。
- **先红后绿**：新增 `tests/unit/test_battle2_dodge_grapple_overload.gd`——**挂接验收 #15**（超载只按超出承载部分自伤；普通气血损失不降低承载）、**#16 收口**（闪避/擒抱全部离散规则、确定性无随机检定）。
- **最小实现**：纯模块；预检文案入 T9.1 快照。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_battle2_dodge_grapple_overload.gd"` + 全量。
- **退出条件**：#15/#16 绿；死亡可预见红线断言（预计致死必须二次确认路径存在）在位。

---

## 阶段五：炼蛊与蛊材

### T5.1 蛊材统一表与升炼（提交 10）

- **固定接口**：新增 `data/materials.json`（§6.1 统一蛊材 1-9 转：rank / dao_tags（开放集合 §0.1）/ diet_tags / is_common / is_exclusive / divisible / public_liquidity / reference_value；食料并入蛊材）+ 新增 `scripts/domain/material_rules.gd`：`downscale_feed(material, need_rank)`（§6.2 高转向下折算：可分割精确扣取、不可分割余量浪费不退库、点名专属食料不可凭价值替代）、`refine_up(input_value)`（§6.3 `×0.5` 逐转、相邻转 2.0 → 等效 4:1、跨多转逐级结算）。
- **先红后绿**：新增 `tests/unit/test_material_rules.gd`——**挂接验收 #9**（高转可分割向下喂养精确扣取余量；不可分割余量浪费且不退回）。
- **最小实现**：先摸底现有材料引用点（use_material / loot_tables / shops），统一迁入 materials.json 或扩展既有表；Schema 接 ContentCatalog。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_material_rules.gd"` + 全量。
- **退出条件**：#9 绿；材料表单一来源（materials.json 或既有表扩展，不并存两份真值）。

### T5.2 蛊方统一与替代身份（提交 11）

- **固定接口**：`refinement_recipes.json` 蛊方 Schema 扩展（§5.1-§5.4）：`identity_requirements`（点名蛊/蛊材/道标签/转数/媒介）、`allow_substitute`（明示替代关系及代价变化）、`stages`（每阶段念头/真元/耗时/打断点/失败条件——跨回合炼制每回合续占念头 §5.3）、`candidate_pool`（标签蛊方人工候选池，2-3 选一 §5.2）、产物=主蛊改造语义（主辅蛊原形消失、核心作辅蛊强警告二次确认）；新增 `scripts/domain/recipe_rules.gd`：`known_fixed_success`（已知普通蛊方确定成功，无随机吞料）、`resolve_candidates`（只从人工池出产）、`check_identity`（等值蛊材与元石不可替代点名要求）。
- **先红后绿**：新增 `tests/unit/test_recipe_rules.gd`——**挂接验收 #7**（已知蛊方确定成功；标签蛊方只从人工候选池出产）、**#8**（等值材料/元石不能替代身份要求）。
- **最小实现**：Schema + 规则模块；随机失败路径只保留给盲炼/禁忌（旧随机炼化路径挂 T10.1 删）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_recipe_rules.gd"` + 全量；`grep -n "SeededRoll\|roll" scripts/domain/recipe_rules.gd` 应零命中（§17.3 确定性）。
- **退出条件**：#7/#8 绿；`resolver.gd` 的 refine 命令改薄委托 recipe_rules（或挂 T10 收缩，本批不动行为）。

---

## 阶段六：喂养、交易与战利品

### T6.1 喂养、饥饿与替代公式（提交 12）

- **固定接口**：新增 `scripts/domain/feeding_rules.gd`：`layer_settle(instances, pantry)`（每大层统一结算 §7.1，食量档位 ×0.5/1.0/2.0 ×rank 倍率；未炼化/封存不免除）、通用替代确定性公式（§7.4 `mixed_replacement = Σ(amount_i*rate_i)/Σ(amount_i)`、`universal_fulfilled = min(Σamount, need*mixed)`、匹配缺口必须补足；应急替代上限 50%；龙鱼表 50-95%）、两阶段饥饿（§7.2：未喂→饥饿下大层禁催动→再未喂死亡；结算界面主动排序+预览 #11）、经济软上限审计（§7.3，50% 剩余资源养 4-5 只标准蛊的预算口径）。
- **先红后绿**：新增 `tests/unit/test_feeding_rules.gd`——**挂接验收 #3**（无限持有不触发槽位拒绝——断言无 deck_capacity 拒绝路径介入喂养链；软上限仅经预算报告）、**#9 关联**（向下喂养余量走 material_rules）、**#10**（低品质混入拉低混合替代率、堆叠不突破上限）、**#11**（首次未喂饥饿、二次死亡；未炼化与封存蛊照常结算）。
- **最小实现**：纯模块 + 大层结算钩子挂 RunState 层切换点（不进 resolver）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_feeding_rules.gd"` + 全量。
- **退出条件**：#3/#9/#10/#11 绿；deck_capacity.gd 不被任何新代码引用。

### T6.2 四类战利品与幸存蛊（提交 13）

- **固定接口**：新增 `scripts/domain/loot_rules.gd`：四类分类（蛊虫/蛊材/元石/信息 §8.1）、总价值预算+世界内来源分配（§8.2，不写死普通/精英/Boss 掉落组合）、`collect_surviving_gu`（§8.3：幸存蛊收取+炼化残意；高转可持有不可催动；凶性/忠主/寄生/绑定条件战前可侦察 §8.4；战后不临时判定"不掉"）、`release_gu`（释放=世界内处置，后果公开 §8.5）、`destroy_gu`（灭蛊不固定返还，按蛊种/死亡方式/手段提取）、**幸存蛊不被战后预算裁剪（#12）**、普通同转低转蛊安全炼化确定性无随机失败。
- **先红后绿**：新增 `tests/unit/test_loot_rules.gd`——**挂接验收 #12**。
- **最小实现**：纯模块；loot_tables.json 固定组合退役挂 T10.1。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_loot_rules.gd"` + 全量。
- **退出条件**：#12 绿；预算只用于生成敌人与场景，不触碰真实幸存物（断言在测试内）。

### T6.3 元石市场与信息（提交 14）

- **固定接口**：新增 `scripts/domain/market_rules.gd`：元石单一数量刻度（§9.1 一份一转普通蛊材买价 10 元石、公开回收 50%、低流动性 30%、危险/秘密蛊材可拒收）、需求收购档 80/100/120%（§9.2，满足后消失或降档防套利）、蛊虫买卖价（常用基础蛊=4 份材料价值、回收=1 份 §9.3、估值≠可购买）、换蛊身份门槛（§3.3 不机械折算、可拒性质不符、交易前展示永久失去项）、信息对象（§9.4：可验证具体事实、出售保留玩家知识、独占价值随传播衰减、每买方同事实一次付费）、大层消费节奏口径（每层约一次基础蛊级自由消费）。
- **先红后绿**：新增 `tests/unit/test_market_rules.gd`——**挂接验收 #18**（信息出售保留知识、降低独占价值、同买方重复付费拒绝）。
- **最小实现**：纯模块；NPC 收购接线（npcs.json stock 既有）改走需求档，行为切换挂 T9.2 命令面。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_market_rules.gd"` + 全量。
- **退出条件**：#18 绿；元石无品质/面额字段（Schema 断言）。

---

## 阶段七：核心蛊与构筑倾斜

### T7.1 核心确认与权益倾斜（提交 15）

- **固定接口**：新增 `scripts/domain/core_gu_rules.gd`：`confirm_core(inst)`（每局一只、第一大层中段起、可推迟、系统不自动确认 §1.1）、`core_depth` 标记（通用核心 / 传承枢纽蛊：枢纽额外声明分支蛊方或专属异炼，快照展示差异 **#1**）、池倾斜（§1.2：提高相容蛊/蛊材/蛊方候选分布，不保证毕业、不直给数值）、通用升阶保留原蛊身份。
- **先红后绿**：新增 `tests/unit/test_core_gu_confirm.gd`——**挂接验收 #1**。
- **最小实现**：纯模块 + school_pools.json 倾斜键；确认入口挂炼蛊台/传承节点（T9.2 命令面暴露）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_core_gu_confirm.gd"` + 全量。
- **退出条件**：#1 绿；倾斜不触碰任何基础数值（断言倾斜前后 GuBalance 输出不变）。

### T7.2 核心更换凭证（提交 16）

- **固定接口**：`core_gu_rules.gd` 增：`grant_replacement_token`（第二/三大层重大构筑节点保证一次；与异炼/稀有蛊竞争；随机机缘可小概率提前/替代但不绕过单局成功次数上限；已随机更换则保证节点改发同级收益 §1.3）、`replace_core(old, new)`（移除旧核心专属改造、旧蛊保留转数与普通身份、新核心从当前状态起步不继承路线/改造/已消费成长资源；代价来源提前公开）。
- **先红后绿**：新增 `tests/unit/test_core_gu_replace.gd`——**挂接验收 #2**。
- **最小实现**：纯模块 + nodes.json 节点 `core_replacement_token` 授予键（数据驱动接线，参照 ascension_grants 既有模式）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_core_gu_replace.gd"` + 全量。
- **退出条件**：#2 绿；一局成功次数硬上限有拒绝路径。

---

## 阶段八：道途特例

### T8.1 血气道与聚量（提交 17）

- **固定接口**：新增 `scripts/domain/blood_qi_rules.gd`：血气双标签共享真实库存（§15.1，两道争用同一份）、产量公式（目标血量/转数/死亡方式/采血手段）、主动放血（凝炼不高于自身转数；血气+2 气血类旧 use_material 语义由本模块统一接管）、深度采血代价（时间/工具/血腥踪迹）、血道秘密交易门槛与势力后果、气道聚量（§15.2：由蛊效声明曲线/上限/最低单位，不自动换万能伤害）。
- **先红后绿**：新增 `tests/unit/test_blood_qi_path.gd`。
- **最小实现**：纯模块 + materials.json 血气条目（divisible=true 双标签）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_blood_qi_path.gd"` + 全量。
- **退出条件**：血气库存单源（同一实例被两道扣取时数值一致，断言在测试内）。

### T8.2 魂道与魂魄五量（提交 18）

- **固定接口**：新增 `scripts/domain/soul_rules.gd`：魂魄量级（连续人魂当量）/安全承载/安分 0-100/魂性单一/兽性独立积累（§15.4）、三操作（壮魂/炼魂/安魂）、收魂手段声明（容量/效率/损耗；普通魂魄无手段不入库 **#17**）、虚浮与膨胀（超承载继续壮大→直接死亡二次确认）、兽念阈值提前展示（保留/利用/净化）、兽化=非死亡特殊结局走 §16.10 主动二次确认。
- **先红后绿**：新增 `tests/unit/test_soul_rules.gd`——**挂接验收 #17**（无魂目标零收益；无收取手段的普通魂魄不得进入库存）。
- **最小实现**：纯模块；`soul_capacity.gd` 旧"魂魄派生操作上限"逻辑标记待删（T10.1）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_soul_rules.gd"` + 全量。
- **退出条件**：#17 绿；虚浮致死与兽化结局均有二次确认路径断言。

---

## 阶段九：UI 命令面与快照切换

### T9.1 快照透明面 v2（提交 19 前半，与 T9.2 同阶段分两个提交则顺延编号）

- **固定接口**：`scripts/presentation/run_snapshot_builder.gd` 按 §17.2 八组真实结果扩快照：蛊虫真元百分比/念头/回合使用权/维持状态；核心类型/倾斜/异炼/更换损失；蛊方身份/阶段成本/成功条件/风险/产物；喂养需求/匹配比例/替代率/饥饿与死亡预测；买卖价/需求条件/参考估值/不可公开原因；安全力量/实际力量/对外伤害/超载自伤/死亡警告；敌方意图/反应窗口/距离/速度冲突/准备状态；魂魄五量与失控阈值。
- **先红后绿**：新增 `tests/unit/test_snapshot_transparency_v2.gd`：逐键断言存在且数值与对应规则模块同源（预检=执行同一来源 §17.3）。
- **最小实现**：快照键 + 中文文案经 `DisplayText`；§16.5 既有约束不回退（tooltip 数值写死禁模糊文案的旧守卫继续生效）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_snapshot_transparency_v2.gd"` + 全量。
- **退出条件**：17.2 八组逐项绿；快照只读（无 setter 路径）。

### T9.2 命令面扩容与契约守卫（提交 19/20 中的收口提交）

- **固定接口**：`scripts/domain/command_spec_registry.gd` 注册新命令全集：`confirm_core`、`replace_core`、`feed_instance`、`settle_layer`、`collect_surviving`、`release_gu`、`destroy_gu`、`sell_info`、`enact编排`（声明动作/编排串行并行/反应预留）、`dodge`、`grapple`、`respond`、`refine_up_material`、`bloodlet`、`absorb_soul` 等；每命令三件套：预检（reason 进 `_REJECTION_TEXT` 中文映射）→ 执行 → 事件日志条目（§17.3 全清单）。
- **先红后绿**：扩展既有 `tests/unit/test_command_contract.gd`（builder 全 type 字面量扫描自动覆盖新命令，幽令清单钉死）+ 新增 `tests/unit/test_command_rejections_v2.gd`（每条新命令至少一条拒绝路径断言"拒绝不改状态"）。
- **最小实现**：命令 spec + resolver 命令分派薄委托（规则体在阶段一至八模块内，resolver 只做编排分派，**不新增规则行数**——resolver 门禁在此批最关键）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_command_contract.gd"` + `-Test "tests/unit/test_command_rejections_v2.gd"` + 全量。
- **退出条件**：幽令零复发；事件日志清单动作全落账（审计 grep：17.3 动作词表逐项有对应日志写入测试）。

---

## 阶段十：旧系统清退与迁移收尾

### T10.1 §18 废止清单逐条删除（提交 19/20 的清退提交）

- **固定接口**：逐条删除旧代码与测试假设，映射如下：
  1. 蛊槽硬上限/扩容/槽满替换/卡组=持有上限 → 删 `deck_capacity.gd` 相关拒绝路径（喂养软上限替代）；
  2. 抽牌/手牌/弃牌堆/洗牌 → 删 `deck_builder.gd` 与 battle 抽牌流（卡牌=实例操作界面）；
  3. 魂魄派生催蛊/炼蛊并发上限 → 删 `soul_capacity.gd` 操作上限（念头账本替代）；
  4. 升转自动加气血/肉身/承载/速度/念头/资质/真元槽 → 删对应 rankup 增益路径；
  5. 真元每回合重置行动点 → 删旧 action-point 重置（跨战斗百分比资源替代）；
  6. 连续时间单位/速度倍率换算/小数进度/全场排序 → 删 battle_resolver 对应段；
  7. 身体部位/部位血量/结构伤势 → 删（若存在实现残留）；
  8. 普通炼化随机失败/吞料/战后裁剪幸存蛊 → 删随机失败与裁剪路径；
  9. 等值自动替代/灭蛊固定返还 → 删旧替代与固定返还；
  10. 固定掉落组合/无来源抽象永久改造 → 删 loot_tables 固定组合与抽象服务；
  11. 五道封闭枚举 → schools.json 保留首批内容，删"枚举即全部"的校验假设（道标签开放集合）；
  12. 杀招强制统一沉重代价 → 删自动附加惩罚，成本由组成蛊+杀招规则决定。
- **先红后绿**：新增 `tests/unit/test_legacy_abolition.gd`：断言旧符号（DeckCapacity 拒绝、draw_pile、soul_ops_cap、action-point reset、部位字段…）在代码与数据中不存在。先红（旧码在），删完绿。
- **最小实现**：只删不改；删除后同步收缩 `resolver.gd`/`battle_resolver.gd` 行数（门禁基线在 T10.2 末下调一次，单向只降不升）。
- **验收命令**：`tools/test.ps1 -Test "tests/unit/test_legacy_abolition.gd"` + 全量。
- **退出条件**：全量绿；两个 resolver 行数低于删除前基线；`AGENTS.md` §16.1/§16.2/§16.19/§16.17 等旧约束段落同步改写（旧实现记录不再作为规范依据，§18 迁移纪律）。

### T10.2 迁移收尾与 18 条验收矩阵（提交 20）

- **固定接口**：`save_repository.gd` 大厅迁移最终形态固化；旧 Run 拒载文案终审；`AGENTS.md` 同步本规格为权威基线。
- **先红后绿**：新增 `tests/integration/test_spec_v4_acceptance.gd`：**§17.4 十八条逐条复验**（E2E：开局→战斗→喂养结算→炼蛊→交易→核心确认与更换→层推进），任一条红即阻断。
- **最小实现**：只写集成测试 + 修迁移文案；不动领域逻辑（发现缺陷回对应任务补丁，另开小提交）。
- **验收命令**：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`；`powershell -ExecutionPolicy Bypass -File tools/check.ps1`；`tools/crash_recovery_check.ps1`（v4 存档下复跑 PASS）。
- **退出条件**：18 条矩阵全绿 + 全量回归绿 + 崩溃恢复 PASS + resolver 行数报告（应低于 2457/1516 基线）。

---

## §17.4 验收矩阵 → 任务挂接（18 条全覆盖）

| # | 验收条目 | 主挂任务 | 协同 |
| --- | --- | --- | --- |
| 1 | 任意战斗蛊可确认核心；通用/枢纽显示差异 | T7.1 | T9.1 快照 |
| 2 | 更换核心移除旧专属改造、不继承路线、次数受控 | T7.2 | T9.2 |
| 3 | 无限持有不触发槽位拒绝；喂养预算软上限 | T6.1 | T10.1(删蛊槽) |
| 4 | 同实例同动作回合不重复；同名异实例可分别催动 | T4.1 | T9.2 |
| 5 | 念头与魂魄独立；升转不自动加念头/气血/承载 | T3.2 | T10.1(删升转增益) |
| 6 | 低转不能催高转；高转真元向下折算正确 | T3.2 | T2.1 |
| 7 | 已知蛊方确定成功；标签蛊方只出人工候选池 | T5.2 | T10.1(删随机失败) |
| 8 | 蛊方身份要求不可被等值材料/元石替代 | T5.2 | — |
| 9 | 高转可分割/不可分割向下喂养余量分别正确 | T5.1 | T6.1 |
| 10 | 龙鱼混用低品质拉低替代能力 | T6.1 | — |
| 11 | 首次未喂饥饿、二次死亡；未炼化/封存不免除 | T6.1 | — |
| 12 | 幸存蛊不被战后裁剪；安全炼化无随机失败 | T6.2 | T5.2 |
| 13 | 固定防御可降至 0；耐久防护可被多次消耗 | T4.2 | — |
| 14 | 蛊师 100 气血尺度；同转野兽独立倍增肉身 | T2.1(数值)+T4.2(行为) | T3.2 |
| 15 | 超载只按超出承载自伤；气血损失不降承载 | T4.3 | T9.1 预检面 |
| 16 | 闪避/擒抱/脱离/速度纯离散回合结算 | T4.2+T4.3 | T10.1(删连续时间) |
| 17 | 无魂目标零收益；无手段魂魄不入库 | T8.2 | — |
| 18 | 信息出售保留知识、降独占、防同买方重复付费 | T6.3 | — |

## §18 废止清单 → 任务挂接（12 条全覆盖）

| # | 废止项 | 执行任务 |
| --- | --- | --- |
| 1 | 蛊槽硬上限族 | T10.1-①（新软上限 T6.1 先行） |
| 2 | 抽牌/手牌/弃牌/洗牌 | T10.1-② |
| 3 | 魂魄派生操作上限 | T10.1-③（念头账本 T4.1 先行） |
| 4 | 升转自动加属性 | T10.1-④（零增长模型 T3.2 先行） |
| 5 | 真元行动点重置 | T10.1-⑤（真元海 T3.2 先行） |
| 6 | 连续时间单位族 | T10.1-⑥（离散回合 T4.x 先行） |
| 7 | 身体部位族 | T10.1-⑦ |
| 8 | 随机炼化/吞料/战后裁剪 | T10.1-⑧（确定成功 T5.2/T6.2 先行） |
| 9 | 等值替代/灭蛊固定返还 | T10.1-⑨（身份规则 T5.2 先行） |
| 10 | 固定掉落/抽象永久改造 | T10.1-⑩（预算制 T6.2 先行） |
| 11 | 五道封闭枚举 | T10.1-⑪（道标签开放 T2.2/T5.1 先行） |
| 12 | 杀招统一沉重代价 | T10.1-⑫（成本规则 T5.2 先行） |

## 执行顺序与依赖

阶段一→二→三→四为硬序（地基→数值→实体→战斗）；阶段五→六为硬序（材料先于喂养）；阶段七、八依赖阶段三/五/六但相互独立可并行；阶段九依赖全部前序规则模块；阶段十最后。**任何阶段未达退出条件，不开下一阶段；发现跨阶段缺陷，回对应任务开小补丁提交，不在当前任务内夹带。**

## 提交信息约定

`feat(spec-v4): T{n}.{m} <一句话范围>` / `test(spec-v4): T{n}.{m} 先红测试`；每个任务独立提交，禁止跨任务混合提交。
