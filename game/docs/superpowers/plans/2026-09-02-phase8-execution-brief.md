# 阶段八执行交接单：道途特例——血气道与魂道（T8.1 + T8.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §15.1-§15.2（血气与血道、气道聚量）、§15.3-§15.4（魂道收益收魂、魂魄数值五量与三操作）、§16.10 相关条款（兽化=非死亡特殊结局、主动二次确认）、§14.2（超载自伤的二次确认先例）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `a9e6384`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至七已合入。阶段七审查结论：**通过**（1 个 P3 层语义问题进任务 0）。全量 `-Suite all` 退出码 0、零失败（unit 1083/1082 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。行数门禁：`resolver.gd` 2452、`battle_resolver.gd` 1514。
- **可直接复用（薄委托，禁第二份实现）**：
  - `MaterialRules`（`divisible` 计量、`downscale_feed`、`named_diet_allowed`）；
  - `MarketRules`（低流动性/拒收口径——血气秘密交易门槛要与其对齐而非另写一套）；
  - `GuBalance` / `CultivatorRules`（数值唯一来源）；`FeedingRules.can_activate`（饥饿禁催动的先例——魂魄虚浮/失控的禁催动应同构）；
  - `GuInstance`（血气也是蛊材，走 `RunState.materials` 单一库存）。
- **现状摸底**：
  - `loot_tables.materials.beast_blood` 现为 `dao_tags: ["blood"]`、`diet_tags: ["meat","blood"]`、`divisible` 未声明——规格 §15.1 要求血气是**血+气双标签可分割蛊材**，T8.1 数据侧补 `"qi"` 标签与 `divisible: true`；
  - `resolver._use_material` 仍承载旧"血气 +2 气血"类语义（`loot_tables.materials.*.use`）——本批**接管语义到新模块，不动 resolver 行为**（切换挂 T9.2/T10.1）；
  - `RunState.cultivator` 现有遗留键 `soul: 1 / soul_max: 4 / soul_control_limit: 2`——这是**废止清单 T10.1 范围的旧魂魄模型**，T8.2 的新五量用**新键**，不读写旧键；`soul_capacity.gd` 已带 T10.1-③ 待删标记；
  - 战斗结算侧 `battle2/` 全模块可传 `state` 引用——血气产量与收魂入口挂战利品/结算命令面（T9.2），本批纯规则。
- **挂账延续**（写进完成报告即可）：`CultivatorRules.wisdom_bonus` 全目录口径；`GuInstance.uses_left`；`start_turn` ongoing `"id"` 约定；`RunState.materials` 小数计量裁定（T9.2 前）；核心确认门 `can_confirm` 的层语义（任务 0.1 裁定后此条关闭）。

---

## 任务 0：阶段七收尾补丁（1 个小提交，先于 T8.1）

### P0.1 核心确认门的层语义裁定（提交 A，必做，P3）

- **问题**：`CoreGuRules.can_confirm` 以 `current_node_layer >= 1` 作为"第一大层中段"的判定，并在注释里把 layer 0 解释为"第一大层的开场段"。但 `current_node_layer` 的编号语义尚无权威定义（`settle_layer` 目前只有测试调用，无生产方）——若层号是 0 起算（layer 0 = 第一层），则 `>= 1` 会把整个第一大层都关在门外，偏离规格 §1.1"**第一大层中段**起可确认"。
- **修法**：先裁定层号语义（0 起算 or 1 起算；以 `nodes.json` 的 `stage` 字段与 `RunState.stage` 的对应关系为准，写进代码注释与报告），然后让确认门真实对齐"第一大层中段"——建议层内进度判定（如已推进节点数 ≥ 该层中位，或复用 `settle_layer` 的大层进入事实 + 层内进度标记），不接受"整个第一层不可确认"的解释。同步修正测试与注释。
- 先红后绿：调整 `test_core_gu_confirm.gd` 的边界断言（第一层开场拒、中段放行、第二层起恒放行）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_core_gu_confirm.gd"` + `-Suite all`。

---

## T8.1 血气道与聚量（提交 B）

- **固定接口**：新增 `scripts/domain/blood_qi_rules.gd`（`class_name BloodQiRules`，纯静态、确定性）：
  1. **双标签单库存**（§15.1）：血气是 `dao_tags: ["blood","qi"]` 的可分割蛊材，血道与气道**争用同一份真实库存**（`RunState.materials` 单一来源）；`claim_inventory(state, material_id, amount, claiming_path)`——任一道扣取后另一道看到的余量即时一致（验收断言核心）。数据侧：`beast_blood` 补 `"qi"` 标签与 `divisible: true`（或新增一条高转血气样例），Schema 守卫双标签 + divisible 必须同时成立。
  2. **产量公式**（§15.1）：`blood_yield(target_health, target_rank, death_method, method_means, cat)`——目标血量、转数、死亡方式、采血手段决定产量与转数；基础搜刮保留，深度采血额外消耗时间/工具并产生 `blood_trail`（血腥踪迹，供 §16 世界一致性/遇袭判定消费）；紧迫场景"深度采血 vs 普通搜刮"二选一作为选项声明。
  3. **主动放血**（§15.1）：`self_bleed(state, target_rank, amount)`——玩家牺牲自身气血凝炼血气，**凝炼转数不高于自身转数**；自伤量与产量公式声明式输出；**预检含气血不足拒绝与预计死亡标记**（沿用 `battle2/body_rules.strike_preflight` 的 `lethal_confirm_required` 模式——不允许静默致死）。
  4. **旧语义接管声明**：血气类 `use_material` 的"+N 气血"语义由本模块的 `consume_blood_qi(state, ...)` 统一承载（纯函数版），resolver 旧行为不动（切换挂 T9.2/T10.1）；接管映射表写进报告。
  5. **血道交易门槛**（§15.1）：`trade_gate(material, channel)`——血道资源难公开交易：公开渠道拒收（衔接 `MarketRules` 拒收口径），秘密渠道需门槛（暗号/关系/代价），并输出势力后果声明（袭击/追踪/敌视倾向，供 §16 世界事件消费）。
  6. **气道聚量**（§15.2）：`accumulate_qi(inputs, effect_curve)`——投入越多效果越强，但**曲线/上限/最低单位必须由具体蛊效声明**（数据驱动，放蛊效字段或 effect 声明段）；**没有任何"气道材料自动换万能伤害"的路径**——无声明曲线时聚量函数拒绝。血气因双标签可进入气道消耗，与血道喂养/升炼/交易的机会成本真实成立（库存单源已保证）。
- **先红后绿**：新增 `tests/unit/test_blood_qi_path.gd`：
  1. **单源断言**（本批退出条件）：血道扣 X 后气道可见余量同步减 X，两道交替扣取总量守恒、永不相等背离；
  2. 产量公式逐数断言（表驱动，读 cat，改键随动）；深度采血代价与血腥踪迹输出；
  3. 放血：转数上限拒绝（高于自身转数）、气血不足拒绝、预计致死 `lethal_confirm_required` 标记；
  4. 聚量：有声明曲线按曲线结算、无声明拒绝、上限封顶、最低单位门槛；
  5. 公开渠道拒收血气、秘密渠道需门槛。
- **最小实现**：纯模块 + beast_blood 数据补全 + （可选）1 条高转血气样例；不切 resolver 行为。
- 验收：`tools/test.ps1 -Test "tests/unit/test_blood_qi_path.gd"` + `-Suite all`。
- 退出条件：**血气库存单源断言绿**；零随机（源码审计）；resolver 行数不增。

## T8.2 魂道与魂魄五量（提交 C）

- **固定接口**：新增 `scripts/domain/soul_rules.gd`（`class_name SoulRules`，纯静态、确定性）：
  1. **五量模型**（§15.4，`RunState.cultivator` **新键**，不碰遗留 `soul/soul_max/soul_control_limit`）：`soul_magnitude`（魂魄量级，连续人魂当量，浮点）、`soul_safe_capacity`（安全承载）、`soul_calm`（安分 0-100）、`soul_nature`（魂性，**同一时间只一种**——赋值即替换，Schema/校验拒绝混合）、`beast_nature`（兽性，独立积累项）。
  2. **三操作**：`strengthen_soul`（壮魂→量级↑）、`refine_soul`（炼魂→承载↑）、`calm_soul`（安魂→安分↑）；各操作的成本/效率由调用方声明传入（手段差异），模块只管规则与边界。
  3. **收魂手段门控**（§15.3，验收 #17）：`collect_soul(target, means)`——只有**有魂生灵**提供魂道收益（无魂目标零收益，输出 `yield: 0` + 原因）；**普通魂魄必须经声明手段（魂蛊/魂器/杀招/蛊阵）收取**，手段声明容量/效率/损耗；**无手段或手段容量满时魂魄不入库**——不是丢弃警告，是根本不产生库存；兽魂死亡掉落实体魂核（实体战利品，走四类战利品 `gu`/`material` 语义，衔接 LootRules）。
  4. **虚浮与膨胀**（§15.4）：允许主动把量级壮大到安全承载以上（`float_above_capacity` 标记）；**预计直接膨胀死亡必须二次确认**（复用 `lethal_confirm_required` 模式，死因 `soul_burst`）；虚浮状态输出（不稳定代价声明）。
  5. **安分与兽性**（§15.4）：安分不足的后果分层声明（情绪化→兽性显现→魂魄离体/失控）；狼魂蛊类"提高承载但积累狼性"是手段声明 + `beast_nature` 增量的组合；**兽念阈值提前展示**（输出当前阈值/风险等级/保留/利用/净化三选项的声明结构）；低度兽性的感知/追猎强化是**蛊效/手段声明**，不是全局被动。
  6. **兽化结局门**（§16.10）：`bestiality_endpoint_check(state)`——达到危险条件后输出"可触发兽化"标记；**兽化是非死亡特殊结局，必须玩家主动二次确认**，任何数值阈值都不得静默结束本局（断言：阈值达到时仅返回标记，不产生终态）。
- **先红后绿**：新增 `tests/unit/test_soul_rules.gd`——**挂接验收 #17**：无魂目标零收益；无收取手段的普通魂魄不入库；手段容量满拒绝且不丢失声明；五量字段齐备且与遗留 soul 键零耦合（改旧键不影响五量）；三操作边界；虚浮允许但致死需确认标记；安分/兽性分层；兽化仅标记不静默终局。
- **最小实现**：纯模块 + cultivator 新键默认值（`run_state.new_run` 补默认，不接任何行为）；`soul_capacity.gd` 不再改动（T10.1-③ 删）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_soul_rules.gd"` + `-Suite all`。
- 退出条件：#17 绿；虚浮致死与兽化结局均有二次确认路径断言；与旧 soul 键零耦合断言绿；resolver 行数不增。

---

## 全局纪律（每一批）

1. 每任务独立提交：`feat(spec-v4): T8.x ...` / `test(spec-v4): T8.x 先红测试`；补丁提交 `fix(spec-v4): P0.x ...`。
2. 先红后绿：红证据写进提交说明。
3. resolver 门禁：`resolver.gd` ≤ 2457（当前 2452）、`battle_resolver.gd` ≤ 1516（当前 1514）；T8.x 不触碰这两个文件。
4. 禁区目录只读；标识符 ASCII、玩家文案 UTF-8；调参进 balance.json 过 Schema（本批如需新键——如血气产量系数——逐键申报）。
5. **不可逆红线**：放血致死、魂魄膨胀致死、兽化结局全部二次确认标记先行；关键状态变化（采血、收魂、放血、壮魂/炼魂/安魂、兽性变化）的事件日志条目由返回值携带供 T9.2 命令面落账（§17.3 清单动作）。
6. 测试基线只增不回退；跨阶段缺陷记录报告，不夹带；EOF 换行有守卫兜底。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；层语义裁定结论（P0.1）；血气数据声明格式（双标签样例）；`use_material` 旧语义接管映射表；五量与遗留 soul 键的隔离说明；二次确认标记的三处落点（放血/膨胀/兽化）断言说明；`-Suite all` 最终数字；挂账项延续记录；未验证风险与遗留问题。
