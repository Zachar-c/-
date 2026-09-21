# Handoff · Web parity slice 11 · 恢复类节点（休整 / 静修）

```text
TASK web-parity-slice-11-rest-nodes
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 Godot 的恢复类节点接回固定图：模板池由 6 个扩到 9 个（险地 3 + 市集 2 + 野蛊 1 + 休整 2 + 静修 1），
休整节点（type=rest）实现「一次收益门禁」的两步交互（先取「歇脚恢复」，「离开休整」才解禁），
静修节点（type=seclusion）接入「静修」（真元 +1，真元上限截断）。规则、门禁与文案逐条照搬
rest_rules.gd:121-141 / action_preview_service.gd:746-808,811-831 / social_command_rules.gd:772-773
与 :586-589，不新设计、不动数值（恢复比例、开局气血、成本一律未动）。

DELTA
+ game/wenzhen-web-lab/js/node_action_rules.js
  ~ NODE_TYPES 扩为 5 类（hazard/market/wild_gu/rest/seclusion）；新增 restNodeType 与
    REST_HEAL_ID='node.rest_heal' / REST_LEAVE_ID='node.leave' 及两张卡的文案常量；
  + meditate 动作（TRANSITIONS：essence delta +1、reason action_meditate_essence；卡 gain 与结果文案照抄）；
  + resolve() 支持 delta 型 essence 转移，并接收 essenceMax（meditate 的上限截断）；
  + typeLabel / typeLabels（names.json 的 types 优先，缺 rest 时回退 display_text.gd:54 的「休整」）；
  + restRecovery / restCards / resolveRest / restReasonLabel（休整两步交互与门禁）。
  ~ options() 只对已搬动作出卡（choices 里未搬的 take_imprint 不再渲染禁用空按钮）；
    单个 option() 仍保留 Godot 兜底卡（既有契约测试用）。
  ~ 头部注释按既有风格逐条标 Godot 文件与行号（含「不搬」清单与漂移登记）。
+ game/wenzhen-web-lab/tests/node_action_rules.test.mjs：15 → 21 条（新增 meditate 数值与上限、
  休整卡真实数值与两条门禁文案、恢复公式三条边界、重复取收益/未取收益离开的「拒绝且状态不变」、
  取过收益后离开、静修无门禁、rest 类型名回落；夹具池 6 → 9 并按 DATA.nodes 顺序重排；固定 seed 钉值重算）。
+ game/wenzhen-web-lab/tests/run_flow.test.mjs：模板池断言 6 → 9；新增「休整/静修节点的数值语义」
  一条（真实 DATA + 真实模块，休整 10/24 → 17、3/20 → 5、边界、三条门禁、静修真元 +1）。
+ game/wenzhen-web-lab/docs/2026-09-21-web-parity-slice-11-rest-nodes-handoff.md（本文件）。
+ docs/superpowers/specs/2026-09-21-wenzhen-web-rest-nodes-design.md（仓库根 docs/，不在 lab 目录里）。
~ game/wenzhen-web-lab/js/main.js
  ~ fresh()：nonCombatTypeLabels 改用 NodeActionRules.typeLabels(DATA.nodeTypes)（rest 回退名单点）；
  ~ chooseNode()：进入节点时清零 state.restUsed（「本次探访是否已消费」按节点重置）；
  ~ resolveNodeAction()：休整类型分流到新的 resolveRestAction()；标准动作传入 essenceMax；
    journal 的「真元」增量改为双向显示（meditate 是 +1，此前只显示扣减）；
  + resolveRestAction()：休整两步交互（取收益留在本页、离开才进统一整备、被拒只提示不改状态）；
  - restHeal() 死桩（「休整节点已移除」）删除——本片起休整节点已存在，留着就是假状态。
~ game/wenzhen-web-lab/js/journey.js
  ~ nodeTypeLabel()：改走 NodeActionRules.typeLabel（DATA 优先 + rest 回退「休整」）；
  ~ renderNodeActions()：休整节点出 restCards()（含 used/气血/真元/上限），其余出 options()；
    底注文案按类型分流；mapNodeCard 的动作摘要改走 nodeActionMenuLabels()（休整列两张卡的标题，
    标准节点只列真的会出卡的动作）；hall 文案补「休整 / 静修」。
~ game/wenzhen-web-lab/tools/build_data.mjs：覆盖页 covered +1（恢复类节点），notCovered +5 新条目
  （休整另四种收益 / rest skip 模式 / 文案与实现漂移：「恢复 2 点」/ 数据缺口：names.json 缺 rest /
  非战斗槽位类型分布进一步稀释），改 4 条（体印卡不出卡、rest-class 门禁拆分为 refinement+cultivation、
  其余节点类型不再列 seclusion、险地 on_skip 补休整/静修模板）。
~ game/wenzhen-web-lab/js/data.js：重新生成；仅 mechanisms 区变化（见 VERIFY 的逐字节证据）。
- game/wenzhen-web-lab/js/run_flow.js / js/index.html / js/css：本片无需改动（池过滤走
  NodeActionRules.nodeTypes，页面结构与样式沿用现有 token）。

DECISIONS
- 休整节点不走 options()：Godot 侧本就是两条出牌函数（_append_rest_cards:746-808 vs
  _append_standard_cards:992-1128），所以休整的入口是并列的 restCards()，不塞进标准动作表。
- 探访已消费标记复用既有的 state.restUsed（不是新增槽）：该字段原本只写不读，本片起同时被
  journey（禁用离开卡）与 main（拒绝重复取收益）读取；语义是「本次进入的节点」，在 chooseNode 清零。
  Godot 是按节点 id 作用域的 <节点id>_used（rest_rules.gd:125,167）；lab 一次只处理一个节点，行为等价。
- 休整的「离开休整」在成功路径上沿用 lab 既有 leave 转移（action_leave_route + route_left_behind），
  与其它节点类型的「离开」卡口径一致；门禁（rest_choice_required）照搬。Godot 的 leave_node 实际走
  complete_node(abandoned) 记 encounter_left(_wounded)（encounter_session_resolver.gd:133-149），
  lab 未搬该分支——登记为偏差，供 L2 裁决。
- meditate 在真元上限处截断（L2 指定口径）。Godot 的 _resource_transition:814-821 不截断，
  lab 调用点一律传 state.qiMax——登记为偏差。
- 休整卡显示按当前数值算出的真实恢复量（例：上限 24 点时「恢复气血 7 点。」），不照抄 Godot 卡片
  写死的「恢复 2 点」；该漂移登记在覆盖页 notCovered。
- choices 里未搬的动作（take_imprint）不出卡：搬进来只会是禁用空按钮，按覆盖页登记不实现。
  这是 options() 唯一的 slice-10 行为变化（既有 8 个动作的模板 choices 全部是已搬动作，无可见影响）。
- rest_choice_required 的提示文本用卡片门禁原文（action_preview_service.gd:804），不用
  rejection_text.gd:101 那条点名「调息/强化/移除/跳过」的版本（lab 菜单没有强化/移除/跳过）。

VERIFY
data: node tools/build_data.mjs
      -> gu 77 | recipes 6 | killMoves 5 | enemies 14 | nodes 37 | route 12 | shopOffers 34
         数据/规则漂移（1）：thunder_crown_wolf 的 counter_status="sparked" 无规则实现（既有问题，未变）
      改动前后 data.js 逐字节证据（与 HEAD 的 committed 版本对比）：
        改前 sha256 e72051b0130a2a65…（149422 字符）
        改后 sha256 339abd8388cf0a06…（151957 字符）
        prefix（`"mechanisms"` 之前）逐字节相同：true
        tail（mechanisms 对象之后）逐字节相同：true
        结构化：两边 DATA 去掉 mechanisms 后 JSON.stringify 完全相同：true
        => 全部既有字段（gu/recipes/killMoves/enemies/nodes/route/shopOffers/flow/loot/...）逐字节不变，
           差异只在 mechanisms 区内（covered 26→27，notCovered 17→22）。
tests: node --test tests/*.test.mjs -> tests 69 / pass 69 / fail 0（改前基线 62）
       逐文件：gu 14、loot 4、node_action 21、rules 2、run_flow 9、run_rules 14、shop 5（各自 fail 0）
syntax: 逐文件 node --check -> js/node_action_rules.js / js/run_flow.js / js/main.js / js/journey.js /
       js/data.js / tools/build_data.mjs 全部 OK
       （未使用 `node --check a.js b.js` 组合写法——本仓 V1 记录在案的假绿陷阱）
diff-check: git diff --check -- game/wenzhen-web-lab -> 无输出
integration（node 侧，真实 DATA + NodeActionRules + RunFlow，首局 seed 101 / normal）：
      ① pool 9 {"hazard":3,"wild_gu":1,"market":2,"rest":2,"seclusion":1}
         order toxic_mountain_path,flooded_cave,black_mud_marsh,blood_moss_grove,village_short_work,
               ridge_market,rest_hollow,rest_shrine,body_imprint_ritual
      ② slots 50（5×10，每层恰 1 个）bad layers 0 | boss 5
         kinds {"market":11,"rest":12,"wild_gu":8,"hazard":12,"seclusion":7}
         首层落点 L1D0N2 = 市集·山村短工（槽位与 slice-10 逐格一致）；首个休整节点 L1D1N2
         「休整 · 山壁石穴」choices ["rest","leave"]；首个静修节点 L2D0N1「静修 · 体印仪式」
         choices ["meditate","take_imprint","leave"]
      ③ heal 10->17 3->5 rest_recovered（30% 向下取整 = 7，至少 1）
      ④ 气血 24/24 -> 24；真元 20/20 -> 20；meditate 19->20、20->20（不越上限）
      ⑤ leave-unused rest_choice_required（状态不变：气血/真元/used 都不动）
         | heal true（used false->true）| heal-again rest_already_used（状态不变）
         | leave-used action_leave_route + fact route_left_behind
      ⑥ meditate 3->4（action_meditate_essence）| 静修 leave ok、无休整门禁
         | 静修卡片 meditate,leave（take_imprint 不出卡）
app-drive（补充证据：用 stub DOM 在 vm 里按 index.html 顺序载入全部 15 个脚本，真跑 main.js 的 act 流程；
      不是浏览器，浏览器实点由 L2 做）：
      起始 seed 101 / normal（DATA.runSeed=101），nodes=155
      - 市集 L1D0N2：page=node-action -> 做工 -> page=prep、元石 3->6、journal「市集 · 山村短工 · 做工 · 元石 +3」
      - 休整 L1D1N2：「休整 · 山壁石穴」，page=node-action；未取收益点离开 -> 拒绝、page 仍 node-action、
        restUsed=false、prepFor=null；置气血 10 / 真元 3 后取「歇脚恢复」-> 气血 17、真元 5、restUsed=true、
        page 仍 node-action、journal「休整 · 山壁石穴 · 歇脚恢复 · 气血 +7 · 真元 +2」、event rest_recovered；
        再点一次 -> 拒绝、气血/真元/restUsed 不变；点「离开休整」-> page=prep、prepFor=L1D1N2、
        journal「… · 离开休整」、event action_leave_route、fact route_left_behind
      - 静修 L2D0N1（直接切节点页，不模拟战斗）：「静修 · 体印仪式」->「静修」-> page=prep、真元 5->6、
        event action_meditate_essence
      - 地图卡摘要：rest ->「歇脚恢复 · 离开休整」；seclusion ->「静修 · 离开」；类型名 休整/静修/战斗

RISK
1. 类型分布继续稀释（本片首局 hazard 12 / market 11 / wild_gu 8 / rest 12 / seclusion 7，slice-10 是
   hazard 31 / market 12 / wild_gu 7）：属 slice-10 已登记、待 L1 裁的同一件事的延续，本片未改
   槽位数/候选数/层数/难度。
2. 休整「离开」的事件 reason 沿用 action_leave_route（Godot 的 leave_node 路径记 encounter_left）——
   lab 内一致性优先，属偏差；若 L2 要求严格 parity，回退面是 resolveRest 的一条分支 + 两条测试。
3. meditate 上限截断是 L2 口径（Godot 不截断，可超上限）。若要求严格 parity，回退面是 resolve() 的
   essenceCap 与其 3 条测试断言。
4. state.restUsed 复用既有字段而非按节点 id 记旗标；lab 一次只处理一个节点、进入即清零，行为等价，
   但若未来 lab 支持节点内多次往返/回访，需要改成按节点作用域。
5. options() 现在会过滤未搬动作（take_imprint 不再出现禁用卡）——本片唯一改变 slice-10 行为的地方，
   已登记；若 L2 认为应保留「声明了就有卡」的兜底，回退面是 options() 的 filter 与 2 条断言。
6. 休整节点在气血与真元都满时仍可点「歇脚恢复」并消耗探访（Godot 的 available 恒为 true，属既有语义）；
   lab 保留该行为，可能被玩家当作陷阱——未改，登记备查。
7. 浏览器交互路径（休整两步、静修一步）未经真实点击，仅由规则测试 + node 侧集成 + stub DOM 驱动覆盖。
8. 工作树含本片 7 个文件改动（run_flow.js 无需改动）；本轮未 commit / push。

NEXT
1. ~~L2 实点浏览器~~（已完成，见下 L2 REVIEW 的 browser 证据）。
2. 若继续 parity：contact / caravan / event 等节点类型仍走「先取 Godot 实现与行号，再落地」的口径。
3. L2 任务书给的行号与实际文件有 ±2~+8 偏移（实测：`_append_rest_cards` 实为 746-808 而非 746-812；
   收益卡 expected_gain 实为 :756 而非 :758；离开卡实为 :799-808 而非 :800-811；另四种收益实为
   759-768/769-778/779-788/789-798 而非 766-773/774-782/783-792/793-801；display_text.gd 的 const TYPES
   实为 39-58 而非 38-57）。本片注释与覆盖页一律用实测行号。
4. 偏差 2/3/5 与 RISK 2/4 需要 L2 裁决是否回退到严格 Godot 口径。
```

---

## L2 REVIEW（2026-09-21，PASS WITH FOLLOW-UP）

独立复核口径：不采信结果包自述，build / tests / syntax / diff-check / node 侧集成全部自己重跑一遍；
浏览器验证由 L2 自己做（本片任务书 §NEXT 1 明确不由 Worker 做）。

### 自己重跑到的数字

```text
build : gu 77 | recipes 6 | killMoves 5 | enemies 14 | nodes 37 | route 12 | shopOffers 34（未变）
tests : node --test tests/*.test.mjs -> tests 69 / pass 69 / fail 0（基线 62）
syntax: 逐文件 node --check 8 个改动文件全部 OK
diff  : git diff --check -- game/wenzhen-web-lab -> 无输出
```
结果包自述的 4 类数字（池 9、槽 50、kinds 合计 50、heal 10→17 / 3→5）全部复算一致；
自述的「险地 12 / 市集 11 / 野蛊 8 / 休整 12 / 静修 7」一致（合计 50）。

### 实点浏览器证据（drive.mjs + 无头 Edge，1280×720）

路径走的是**零战斗**的那条：`L1D0N2 市集 → L1D1N2 休整`（起点三根里 L1D0N2 就是市集，
所以休整节点不用打任何一场战斗就能到）。

```text
① 进休整前（休整节点面板，真实坐标点击进入）
   page=panel-node-action
   node.rest_heal  可用  「歇脚恢复 · 恢复气血 0 点。恢复真元 0 点。」
   node.leave      禁用  block_reason「休整抉择未定：须先选择恢复、强化或移除其一，才能离开。」  ← 与 Godot 门禁原文一致
   截图 rest-before.png
② 真实点击「歇脚恢复」（坐标 270,357）
   page 仍为 panel-node-action（停在节点页，没有跳走）
   node.rest_heal  转禁用  「本次休整已处置完毕。」
   node.leave      转可用
   截图 rest-after-heal.png
   注：此节点上气血 24/24、真元 20/20 都是满的，所以真实增益 0——这正好把 RISK 6
   （满状态仍可点、仍消耗探访）在浏览器里复现了；「有涨幅」的那条见 ③。
③ 静修 L2D0N1（打完 L1B 崖蟒主母后）：page=panel-node-action，两张卡
   meditate 可用「恢复 1 点真元。」 / leave 可用——**没有休整门禁**（seclusion 不在 rest-class 名单）
   点静修 -> 直接 page=panel-prep，无中间门禁
   截图 seclusion-before.png / seclusion-after.png
④ 全程 console 无输出、无页面错误；中途过 L1D8N1 险地的 cross（真元 -1）与 L1B 首领战（胜，元石 3→18）均正常
```

休整、静修两条路径都用真实鼠标坐标点击；纯机械穿行的中间节点（市集/野蛊/险地的 leave、
整备页 continue）用 `element.click()` 派发真事件，不影响被验对象的真伪。

### 对 Worker 四个待裁问题的裁决

1. **休整「离开」的事件 reason**：**保留 lab 口径**（`action_leave_route` + fact `route_left_behind`），不改成
   Godot 的 `encounter_left(_wounded)`。理由：lab 每种节点类型的「离开」只有一套语义，改成 Godot 口径就会
   出现「同一张离开卡、两种 reason」，而 Godot 那条分支挂在 `complete_node(abandoned)` 上，lab 整条都没有建模。
   **这是有意偏差**，已登记在 RISK 2；若将来 lab 要搬 `abandoned` 分支，再一起改。
2. **`state.restUsed` 复用与否**：**接受复用**。它原本是「只写不读」的死槽，本片起有 `journey`（禁用离开卡）与
   `main`（拒绝重复取收益）两个真读者——这正好修掉了本项目那一类签名缺陷，方向是对的。按节点 id 建旗标表
   在当前 lab 里没有消费者（一次只处理一个节点、不能回访），属预抽象。
   **约束**：lab 一旦支持节点内往返或回访，必须改成按节点 id 作用域（Godot 是 `<节点id>_used`）。
3. **meditate 是否按真元上限截断**：**保留截断**。lab 的顶栏直接读 `state.qi`，不截断就会出现「真元 21/20」
   这类自相矛盾的可见状态；lab 内真元上限处处生效（战斗回复、休整回复都截断），不截断才是特例。
   Godot 不截断是因为它的消费点在别处再夹一次。**属有意偏差**，已登记在 RISK 3。
4. **`options()` 过滤未搬动作（`take_imprint` 不出卡）**：**接受为本片起的约定**。未搬的动作没有结算器，
   出禁用卡就是假的可供性；这与「只搬有消费点的东西」是同一条门槛。RISK 5 的回退面保留，但默认不回退。

### 本片留下的两件待办（不阻塞提交）

1. **L1 待裁（不由 L2 决）**：非战斗槽位类型分布被进一步稀释——险地每局出现次数 50（更早）→ 31（slice-10）
   → 12（本片）。槽位数、层数、候选数、难度一个字没动，纯是模板池 6→9 的算术后果。**我没有替 L1 挑权重**，
   按 V3 上抛。
2. **浏览器未覆盖到的一条**：本片路线上的休整节点恰好气血真元双满，所以「真实恢复涨幅」只在模块与 node 侧
   集成里验到（10/24 → 17、3/20 → 5），浏览器里看到的是 0 增益。要补的话，跑完一场战斗后再进 L2D2N2
   （气血会低于上限）即可看到非零涨幅——留作下次复核用，不影响本片结论。

