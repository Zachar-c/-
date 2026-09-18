# 阶段六执行交接单：喂养、交易与战利品（T6.1 + T6.2 + T6.3）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §7.1-§7.5（结算节奏、两阶段饥饿、经济软上限、替代公式、食道定位）、§8.1-§8.5（战利品四类、预算、幸存蛊、携带与损毁、释放灭蛊）、§9.1-§9.4（元石、需求价、蛊价、信息）、§3.3（换蛊身份门槛）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `03d0cb9`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至五已合入。阶段五审查结论：**通过**。全量 `-Suite all` 退出码 0、零失败（unit 1043/1042 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。行数门禁：`resolver.gd` 2452、`battle_resolver.gd` 1514。
- **可直接复用的模块（薄委托，禁第二份实现）**：
  - `MaterialRules`（`material_rules.gd`）：`downscale_feed`（§6.2 可分割精确扣取/不可分割余量浪费）、`downscale_equivalent`、`refine_up`、`named_diet_allowed`——T6.1 的向下喂养**必须**走它；
  - `GuInstance`：实例已有 `hunger_phase` / `next_feed_need` / `lifecycle` / `sealed` / `loyal` / `ferocity` / `parasitic` / `flee` 字段（§2.1），T6.1/T6.2 直接读写这些键，不新增平行字段；
  - `GuBalance`：`feed_tier`（0.5/1.0/2.0）与 `rank_multiplier` 已在 balance.json + Schema；`dragon_fish_replacement=[50,70,80,90,95]`、`quick_substitute_cap=0.5`、`stone_per_t1_material=10`、`public_buyback_ratio=0.5`、`low_liquidity_ratio=0.3`、`demand_price_tiers=[0.8,1.0,1.2]` **全部已在 balance.json 就位**，T6.x 直接取用；
  - `deck_capacity.gd` 仍存在但属废止清单 T10.1-①；**T6.x 任何新代码不得引用它**（验收 #3 硬条件）。
- **现状摸底**：
  - `RunState.materials` 扁平计数 Dictionary（`feed_points` 是运行级计数器；其"物化"为真材料在 T6.1 裁定）；大层状态：`RunState.stage`（"one"…）与 `current_node_layer`；`add_materials` 聚合在 `run_state.gd:224` 附近。
  - `loot_resolver.gd` 已有战利品发放路径（工厂入 `gu_instances`）；`loot_tables.json` 的 `loot.boss` 等固定组合仍在被 `resolver.gd:2277/2298` 读取——**固定组合退役是 T10.1-⑩，本批不动**。
  - `shops.json` 有 `material_purchase` 等报价；NPC 收购走 `resolver` 既有 sell 路径——T6.3 只做纯规则，NPC 接线的行为切换挂 T9.2 命令面。
  - `recipe_rules` 的 `check_identity` 尚未检查"特定媒介"（§5.4.1 的 medium）——任务 0 补。

---

## 任务 0：阶段五收尾补丁（1 个小提交，先于 T6.1）

### P0.1 check_identity 补媒介身份检查（提交 A）

- `recipe_rules.gd` 的 `check_identity` 已覆盖 `named_gu_ids / dao_tags / named_materials / min_rank`，缺 §5.4.1 的**特定媒介**（`identity_requirements.named_media`）。补上：点名媒介必须实际在投入中出现，`allow_substitute.media` 可声明替代关系，语义与 materials 一致。
- 先红后绿：`test_recipe_rules.gd` 补一节（点名媒介缺失被拒；声明替代后放行并随 `cost_change`）。同步给 `moon_ray_staged` 或新样例补一条带 `named_media` 的声明供测试。
- 验收：`tools/test.ps1 -Test "tests/unit/test_recipe_rules.gd"` + `-Suite all`。

### 备忘（无需提交，写进完成报告）

- `turn_engine.start_turn(continue_ids)` 按 ongoing 条目的 `"id"` 键匹配；T6.1 的跨回合炼制（§5.3 每回合续占念头）在 T9.2 对接时必须保证条目携带稳定 id——此处留档即可。
- `material_rules.downscale_feed` 的可分割路径返回**分数比例**，而 `RunState.materials` 是整数计数——T6.1 实装喂养扣库时必须裁定计量单位（建议：可分割材料以"份"为最小计量的定点/有理数表示，或以 reference_value 分割粒度取整并在预览中显示），裁定与理由写入报告。

---

## T6.1 喂养、饥饿与替代公式（提交 B）

- **固定接口**：新增 `scripts/domain/feeding_rules.gd`（`class_name FeedingRules`，纯静态、确定性）：
  1. **大层统一结算**（§7.1）：`layer_settle(instances, pantry, options)`——每大层结束一次；标准蛊每大层消耗 `1 份同转匹配蛊材当量 × feed_tier（small 0.5 / standard 1.0 / large 2.0）`，实际转数决定需求价值（**低转蛊师持高转蛊按高转全额**）；未炼化（未入 `refined_instances()` 口径的活物）与封存蛊**照常结算**（封存只防逃逸不免税量）；特殊休眠/节食降食量必须来自具体声明（本批只留数据入口）。结算输出**完整预览结构**：每只蛊的需求、缺口、将进入饥饿/死亡的预测（§7.2 玩家主动排序的前提）。
  2. **替代公式**（§7.4，全部确定性，数值取 balance.json）：匹配食料正常当量；普通不匹配蛊材仅应急替代且**基础上限 50%**（`quick_substitute_cap`）；通用食料替代率属于食料自身（龙鱼表 `dragon_fish_replacement` 50-95%，按品质对应）；混用公式 `mixed_replacement = Σ(amount_i×rate_i)/Σ(amount_i)`、`universal_fulfilled = min(Σamount, need×mixed)`、`matching_required = need − universal_fulfilled`；低品质投入必然拉低混合率；堆叠不突破混合率；替代率 95% 的剩余 5% 仍必须匹配/点名食料；点名专属走 `MaterialRules.named_diet_allowed`。
  3. **两阶段饥饿**（§7.2）：本层未喂足 → `hunger_phase = 1`（饥饿，下一大层**禁催动**——催动预检挂 T9.2，本批先落状态与判定函数）；下一层结算仍未补足 → 蛊虫死亡（**死亡必须产生结构化事件日志条目并显示精准死因**，不允许静默）；玩家在结算选项中主动决定喂养顺序（options 参数承载排序）。
  4. **经济软上限审计**（§7.3）：`budget_report(assets, feeding_plan, cat)`——口径：约 50% 剩余可支配资源价值可维持 4-5 只标准食量同转蛊；**只产出报告，不做硬性拒绝**。
- **大层结算钩子**：把 `layer_settle` 挂到 RunState 的大层切换点（先摸清 `stage` 推进的唯一入口并写入报告；不得进 resolver 的命令分派）。结算动作写入不可变事件日志（§17.3 喂养条目）。
- **先红后绿**：新增 `tests/unit/test_feeding_rules.gd`——
  - **验收 #3**：大量持有蛊（如 20 只）结算不触发任何槽位拒绝；喂养链路与 `deck_capacity` 零引用（测试内断言源码）；软上限仅经 `budget_report` 呈现；
  - **#9 关联**：高转材料向下喂养走 `MaterialRules.downscale_feed`（可分割精确扣取、不可分割浪费不退）；
  - **#10**：混入低替代率食料拉低 `mixed_replacement`；额外堆叠不突破混合率上限；95% 剩余 5% 必须匹配补足；
  - **#11**：首次未喂 → hunger_phase=1；二次未补 → 死亡事件；未炼化与封存蛊照常结算；结算前预览可预测哪些蛊饥饿/死亡。
- 验收：`tools/test.ps1 -Test "tests/unit/test_feeding_rules.gd"` + `-Suite all`。
- 退出条件：#3/#9/#10/#11 绿；`deck_capacity.gd` 不被任何新代码引用（grep 审计入报告）；resolver 行数不增。

## T6.2 四类战利品与幸存蛊（提交 C）

- **固定接口**：新增 `scripts/domain/loot_rules.gd`（`class_name LootRules`，纯静态）：
  1. **四类分类**（§8.1）：蛊虫/蛊材/元石/信息；服务与机会是行动，持久收获归四类。
  2. **总价值预算 + 世界内来源**（§8.2）：`budget_profile(enemy_composition, scene, cat)` 只用于**生成敌人与场景**时的预算口径；明确函数边界：预算数据**不得触碰战后真实幸存物**。
  3. **收取幸存蛊**（§8.3）：`collect_surviving_gu(survivors, state, cat)`——收取 + 炼化残意两步；安全且时间充足时**普通同转及低转蛊确定性炼化**（只耗时间与真元，无随机、不吞料——衔接 RecipeRules.known_fixed_success 语义）；高于玩家转数可收取持有但不可催动（`can_activate` 资格边界，T9.2 预检用）；凶性/忠主/寄生/绑定/逃遁蛊必须满足战前已声明的额外收取条件（§8.4：性质战前可侦察，**战后不得临时判定"不掉"**）。
  4. **释放与灭蛊**（§8.5）：`release_gu(instance, state)`——世界内处置不是删除按钮；返回后果声明（逃逸/暴露/回归原主/后续节点再现），后果在释放前公开；普通无害蛊可简单释放；`destroy_gu(instance, method, means)`——**不固定返还**，按蛊种/死亡方式/手段声明提取物（数据驱动声明，炼道/食道可提高利用率）。
  5. **幸存蛊不被战后预算裁剪**（#12）：结算函数的输出与预算数据完全解耦。
- **先红后绿**：新增 `tests/unit/test_loot_rules.gd`——**挂接验收 #12**（战后幸存蛊全额入账、预算数值不参与裁剪——测试内断言预算函数输出与收取结果无数据通路）；安全炼化确定性无随机（源码审计）；释放后果在结果中公开返回；灭蛊返还按声明而非固定比例。
- **最小实现**：纯模块；`loot_resolver` 既有发放路径不动（对接挂 T9.2），固定组合退役 T10.1-⑩。
- 验收：`tools/test.ps1 -Test "tests/unit/test_loot_rules.gd"` + `-Suite all`。
- 退出条件：#12 绿；resolver 行数不增。

## T6.3 元石市场与信息（提交 D）

- **固定接口**：新增 `scripts/domain/market_rules.gd`（`class_name MarketRules`，纯静态、确定性）：
  1. **元石刻度**（§9.1）：唯一一般等价物，只有数量无品质/面额；一份一转普通蛊材标准买价 `stone_per_t1_material=10`；高转标准价值经 `GuBalance.rank_multiplier` 导出；公开流通回收 `public_buyback_ratio=0.5`；`low_liquidity_ratio=0.3` 仅用于低流动性物品；危险/秘密/禁忌蛊材可被拒收（数据标记）。
  2. **需求收购**（§9.2）：`demand_quote(demand, offer, cat)`——档位 `demand_price_tiers`（80%/100%/120%）；需求限定对象与数量；**满足后消失或降档**（防套利核心规则，要有状态推进函数）；高价值蛊/绝迹蛊方/禁忌物走换蛊或秘密交易，不进普通收购表。
  3. **蛊虫价格**（§9.3）：常用基础蛊公开售价 ≈ 4 份同转普通蛊材价值；回收 ≈ 1 份；**估值 ≠ 可购买**（估值与买卖价分开的两个函数）；大层自由消费节奏口径（约一次基础蛊级消费）写入预算口径注释。
  4. **换蛊身份门槛**（§3.3）：不机械折算（无"差价补元石自动成交"）；可拒性质不符（凶性/寄生/绑定等按声明拒）；交易前输出**永久失去项清单**（供 UI 二次确认）。
  5. **结构化信息**（§9.4）：信息对象记录可验证具体事实（敌人弱点/携带物/准备状态、NPC 需求/库存/底价/暗号/关系等类别）；`sell_info(info, buyer, spread_count)`——出售后玩家**保留知识**；独占价值随传播次数衰减（确定性衰减函数）；**每个买方对同一事实只付费一次**；不得汇总成万能情报点数。
- **先红后绿**：新增 `tests/unit/test_market_rules.gd`——**挂接验收 #18**（出售保留知识、传播降低独占价值、同买方重复付费拒绝）；需求满足后消失/降档；回收 50%/低流动性 30%/档位 80/100/120 逐数断言（全部读 balance.json，改键投影随动）；元石无品质字段（Schema 断言材料不得新增 quality/face-value 键）。
- **最小实现**：纯模块；NPC 收购与商店报价的接线走 T9.2 命令面，本批不改 shops/npcs 行为。
- 验收：`tools/test.ps1 -Test "tests/unit/test_market_rules.gd"` + `-Suite all`。
- 退出条件：#18 绿；元石无品质/面额字段（Schema 断言在位）；resolver 行数不增。

---

## 全局纪律（每一批）

1. 每任务独立提交：`feat(spec-v4): T6.x ...` / `test(spec-v4): T6.x 先红测试`；补丁提交 `fix(spec-v4): P0.x ...`。
2. 先红后绿：红证据写进提交说明。
3. resolver 门禁：`resolver.gd` ≤ 2457（当前 2452）、`battle_resolver.gd` ≤ 1516（当前 1514）；T6.x 不触碰这两个文件。
4. **`deck_capacity.gd` 不得被任何新代码引用**；feeding/loot/market 的扣库与入账走 `RunState` 统一入口（append_materials/add_materials 既有聚合），不散落全局状态。
5. 死亡与不可逆成本红线：饥饿死亡、灭蛊、释放后果、交易永久失去项都必须结构化预检 + 事件日志，不允许静默。
6. 禁区目录只读；标识符 ASCII、玩家文案 UTF-8；调参全在 balance.json（本批基本不需要新键——所需键已就位，若确需新增须过 Schema 并说明）。
7. 测试基线只增不回退；跨阶段缺陷记录报告，不夹带；EOF 换行已有 `test_domain_hygiene.gd` 常驻守卫。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；大层切换点的定位（文件/函数/行号）与 `layer_settle` 挂接方式；可分割材料计量单位的裁定与理由；`deck_capacity` 零引用 grep 输出；loot/market 与预算数据解耦的断言说明；`-Suite all` 最终数字；挂账项延续记录；未验证风险与遗留问题。
