# Handoff · Web parity slice 10 · 通用节点动作结算（险地 / 市集 / 野蛊）

```text
TASK web-parity-slice-10-node-actions
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 slice-09 的险地页泛化为通用节点动作页：固定图每层的非战斗槽位由「险地 3 模板」扩为合并池
（险地 3 + 市集 2 + 野蛊 1，共 6 个模板，仍由 seed 选定），节点动作卡来自 js/node_action_rules.js。
规则与文案逐条照搬 Godot（social_command_rules.gd:747-803 + action_preview_service.gd），
本片新增 work / harvest / buy_information / trade / leave，不新设计、不动数值。

DELTA
+ js/node_action_rules.js：标准动作纯规则（8 个动作的转移、元石/真元门禁、事实、Godot 原文文案与 remedy）；
  头部逐条标 Godot 文件与行号；导出 nodeTypes（三类节点）供 main / journey 单点引用。
+ tests/node_action_rules.test.mjs：15 条（转移 before/after 语义、两条门禁、两条成功扣减与事实、
  leave 事实、未知动作兜底、预览文案逐字、leave 补卡、结果文案、合并池放置确定性与固定 seed 钉值、
  三档难度的行/层主不变量、无模板回退、空 choices 模板不进池、数据契约）。
+ docs/2026-09-21-web-parity-slice-10-node-actions-handoff.md（本文件）。
+ docs/superpowers/specs/2026-09-21-wenzhen-web-node-actions-design.md（仓库根 docs/，不在 lab 目录里）。
- js/hazard_rules.js、tests/hazard_rules.test.mjs：改名后原文件已移出仓库，`HazardRules` / `hazard_rules`
  在 lab 内零残留（无别名、无双模块）。
~ js/run_flow.js：generateGraph 参数 hazardTemplates → nonCombatTemplates（+ nonCombatTypeLabels）；
  节点字段 hazardId → routeTemplateId + routeKind（type / tier 取模板 type）；无模板仍回退纯战斗图。
~ js/main.js：fresh 传合并池与类型中文名；chooseNode 对三类节点分流到 enterNodeAction；
  enterHazard / resolveHazard → enterNodeAction / resolveNodeAction（元石、真元、事实按结果回写；
  被拒只提示、不改状态、不开事件）；事件 targets 用 routeTemplateId。
~ js/journey.js：renderHazard → renderNodeActions（#panel-node-action）；currentNodePage / renderMap /
  mapNodeCard 对三类节点一视同仁；nodeTypeLabel 改取 DATA.nodeTypes（市集 / 野蛊 / 险地不再硬编码）；
  卡片按 Godot 口径带节点 summary（leave 卡用自己的固定 summary）。
~ index.html / css/lab.css：面板 id 与脚本名改 node-action *；样式 token、配色、字体不变，只改结构性类名。
~ tools/build_data.mjs：覆盖页把「非险地节点的路线选择结算」从 notCovered 移入 covered（写清新范围）；
  未覆盖新增 7 条（追击压力 / 升仙条件 / 体印 / 只记事实 / rest-class 门禁 / 其余节点类型 / knownFacts 只写不读）。
~ js/data.js：重新生成；仅 mechanisms 区变化（见 VERIFY 的逐字节证据）。

DECISIONS
- 槽位 seed 字符串沿用 slice-09 的 `L{s}D{d}.hazard.slot` / `L{s}D{d}.hazard.template` 不改名：这样每层非战斗槽位的
  落点与上一片逐格一致（seed 101 / normal 首层仍是 L1D0N2），本片唯一变化是模板池由 3 个险地扩为 6 个。
- leave 卡按 action_preview_service.gd:44-45 / :992-995 处理：choices 里的 leave 跳过、卡末总是补一张
  （标题「离开遭遇」、summary「主动结束当前遭遇，返回地图选择下一条路线。」、收益「结束当前遭遇。」）。
  险地不在 :44 的排除名单里，所以 Godot 也会给险地补 leave 卡——本片因此给险地页补了第 4 张卡（slice-09 未搬）。
- 只搬 8 个动作：work / harvest / buy_information / trade / cross / scout / withdraw / leave。
  其余动作一律不搬（追击、升仙、体印、纯事实组、refine/cultivate/rest、claim_recon/claim_token、
  settle_feeding/accept_debt），理由逐条登记在覆盖页 notCovered。
- 一个节点只解析一次：成功后进入统一整备，被拒只提示（对齐 Resolver._rejected）；不建模 Godot 社交节点的多次 choose_action。
- 数值全部取自 Godot：work 元石 +3、harvest 元石 +2、buy_information / trade 门禁元石 ≥ 2 且扣 2、
  cross 门禁真元 ≥ 1 且扣 1；before/after 语义照抄 _resource_transition:814-821（before = 改之前的值）。

VERIFY
data: node tools/build_data.mjs
      -> gu 77 | recipes 6 | killMoves 5 | enemies 14 | nodes 37 | route 12 | shopOffers 34
         数据/规则漂移（1）：thunder_crown_wolf 的 counter_status="sparked" 无规则实现（既有问题，未变）
      改动前后 data.js 逐字节证据：
        改前 sha256 06317b6d…（147054 字符 / 157272 字节）
        把 build_data 的 mechanisms 编辑临时回退后重跑 -> 仍得 06317b6d…（证明该哈希就是改前文件）
        改后 sha256 e72051b0…（149422 字符 / 160792 字节）
        prefix（`"mechanisms"` 之前）sha256 = 8f344e6f… 两次完全一致
        tail（mechanisms 对象之后）sha256 = 8de16e7a… 两次完全一致
        => 全部既有字段（gu/recipes/killMoves/enemies/nodes/route/shopOffers/flow/loot/...）逐字节不变，
           差异只在 mechanisms 区内。
tests: node --test tests/*.test.mjs -> tests 62 / pass 62 / fail 0（改前基线 55；新增文件单跑 15/15）
       逐文件：gu 14、loot 4、node_action 15、rules 2、run_flow 8、run_rules 14、shop 5（各自 fail 0）
syntax: 逐文件 node --check -> node_action_rules.js / run_flow.js / main.js / journey.js / build_data.mjs / data.js 全部 OK
        （未使用 `node --check a.js b.js` 组合写法——本仓 V1 记录在案的假绿陷阱）
integration（node 侧，真实 DATA 首局 seed 101 / normal）：
      ① 非战斗槽位 50 个 = 5 段 × 10 层，每层恰好 1 个；总节点 155（= 5×(10×3+1)）
         首层落点：L1D0N2 flooded_cave(hazard) / L1D3N0 village_short_work(market) / L1D7N1 blood_moss_grove(wild_gu)
      ② 合并池 size 6 = [hazard×3, wild_gu, market×2]；本局出现 hazard / market / wild_gu 三类
      ③ 市集节点 L1D3N0「市集 · 山村短工」choices ["work","trade","leave"]
         options@stones=0：work ok / trade blocked(insufficient_stone，文案「元石不足：需要 2 枚，还差 2 枚。」) / leave ok
         options@stones=2：三条全 ok
         险地节点 L1D0N2「险地 · 积水石窟」卡序 ["scout","cross","withdraw","leave"]（leave 为按 :44-45 补的卡）
      ④ work @stones=3  -> {"ok":true,"reason":"action_work_paid","stones":6,"stoneBefore":3,"stoneAfter":6,...}
         trade @stones=5 -> {"ok":true,"reason":"action_trade_service","stones":3,"stoneBefore":5,"stoneAfter":3,
                             "knownFacts":["bought_service"],"fact":"bought_service"}
         trade @stones=1 -> {"ok":false,"reason":"insufficient_stone","stones":1,"stoneBefore":1,"stoneAfter":1,
                             "knownFacts":["k"],"fact":""}（被拒且状态不变：元石与事实都没动）
diff-check: git diff --check -- game/wenzhen-web-lab -> 无输出，exit 0
browser（L2 实点，1440×900，`drive.mjs`，console 全程 0 error）：
  - 进市集节点「市集 · 山村短工」：页名 node-action / 面板 #panel-node-action；
    卡片 3 张 = 做工(可用) / 交易(元石 -2) / 离开遭遇(可用)
  - 元石置 0：交易按钮 disabled，blocked 文案逐字为「元石不足：需要 2 枚，还差 2 枚。」，
    remedy 三条齐全（可出售已炼化蛊虫。/ 可前往资源节点补足 2 枚元石。/ 也可选择不消耗元石的行动。）
  - 真点「做工」：元石 3→6（HUD 同步为 6）、页面转 prep、
    journal「市集 · 山村短工 · 做工 · 元石 +3」、event reason action_work_paid
  - 险地节点「险地 · 积水石窟」卡序 ["scout","cross","withdraw","leave"]；
    真点「穿越」：真元 20→19、转 prep、event action_cross_cost
  - 野蛊节点卡序 ["采集","交易","离开遭遇"]；真点「采集」：元石 3→5
  - 被拒路径：元石 0 时直接调 resolveNodeAction('trade') -> 元石仍 0、**页面不推进**、toast 显示门禁原文
  - 图类型分布（真实首局）：battle 79 / hazard 31 / market 12 / wild_gu 7 / elite 21 / boss 5；
    非战斗槽位合计 50 = 5 段 × 10 层；两次生成同一 seed 逐字节相同（确定性成立）
  - 对照：worker 自测报的分布是 hazard 30 / market 13 / 野蛊 7（总数同为 50）。
    差异来自其 harness 传入模板池的**顺序**不同（池序影响 seededIndex 选中项）；
    应用真实顺序（`DATA.nodes.filter` 的天然顺序）复算得 31/12/7，浏览器实测一致。

RISK
1. 合并池改变了「非战斗槽位里各类型的出现频率」（每层仍是 1 个非战斗槽位，但险地:市集:野蛊 ≈ 3:2:1），
   同层战斗/精英配比随之变化。这属于数值取舍，按 V3 留 L1 裁；本片未改槽位数、候选数、层数与难度曲线。
2. ~~险地页比 slice-09 多一张 leave 卡（Godot :44-45 口径）。若 L2 判定险地不应有 leave 卡，回退面是
   node_action_rules 的 options() 与一条测试，另需同步覆盖页措辞。~~
   **L2 已裁（2026-09-21）：保留。** 复核 `action_preview_service.gd:44-45` 的排除名单为
   `[caravan, refinement, cultivation, ledger, shop, event, rest]`，`hazard` 不在其中，Godot 对险地
   同样会补 leave 卡——多出来这一张是**对齐 Godot**，不是新行为。slice-09 当时少了一张，本片顺带补齐。
3. 元石结算与整备页共用同一池：买情报/交易会真实扣减 state.stones（Godot 口径），可能影响同局买货；
   Godot 的 remedy 三条只是提示文案，未做替代路径（不新增路径属本片边界）。
4. 模板 choices 的契约只在测试里钉住（6 个模板全部可解析）；若未来 nodes.json 给这三类节点加新 choice，
   契约测试会红——这是有意的。
5. 工作树含此前未提交改动（alchemy.js、视觉线、前几片 parity、两份既有 handoff），本轮未 commit / push。
6. 浏览器交互路径（进入市集 -> 做工/交易 -> 统一整备）未经真实点击，仅由规则测试与 node 侧集成覆盖。

NEXT
1. ~~L2 实点验收~~ 已执行，见上面 browser 段（全部通过）。
2. 若继续 parity：contact / caravan / event 等节点类型仍走「先取 Godot 实现与行号，再落地」的口径；
   rest-class 三选一门禁（rest_rules.gd:39/55/92/115）需要先确定 lab 的节点内多次行动模型才可搬。
3. knownFacts 只写不读已登记；若后续要让它参与判定，需先有产品/研究结论指定消费点。

L2 REVIEW（2026-09-21，PASS WITH FOLLOW-UP）
复核方式：不动 worker 的自述，自己重跑构建与测试、自己回 Godot 源码逐行核对引用、自己开无头浏览器实点。
三类断言分别验（代码改动 / 数字 / 根因归因），结论：三类全部成立，另有三处 L2 就地改动。

1. **L2 就地简化**：worker 为对齐我给的两个字面量加了一个 `panelIdFor` 特例映射。已改成把页名取为
   `node-action`，这样 `panel-${page}` 的既有约定直接成立，映射与那 4 行一并删除。
   （改动中我自己踩了一次坑：`sed` 把对象字面量的键写成 `node-action:` 造成语法错误，
   被逐文件 `node --check` 抓到后才修——这条正是 V1「判定要看真实输出」的用处。）
2. **归因已逐行回源核对**：`social_command_rules.gd` 的 747-803 / 814-821 / 823-831 / 881-887、
   `action_preview_service.gd` 的 44-45 / 992-995 / 1022-1035 / 1043-1044 / 1114-1115 / 1198-1208 / 1306-1309、
   `display_text.gd`（真实路径是 `scripts/presentation/`，不是 `scripts/domain/`）的
   226 / 230 / 232 / 238 / 241-243 / 459-460 / 503-505 —— **全部与所引内容一致**。
3. **本片自报数字有一处对不上（不影响产物）**：worker 报首局类型分布 hazard 30 / market 13 / 野蛊 7，
   实际为 31 / 12 / 7。总数与确定性都对，差异源于其 harness 传池顺序不同（池序影响 seededIndex）。
   已按真实顺序复算并在浏览器实测确认。**留痕原因：自述数字不可直接当证据。**
4. **残留保真差异（未改，登记）**：
   - 节点动作事件的目标写的是**模板 id**（`routeTemplateId`），Godot `choose_action` 事件写的是
     `state.current_node_id` 节点实例 id。slice-09 同口径，本片沿用；要改则两片一起改。
   - 事件只记 `after`，Godot `Resolver._event` 记 before + after（lab 无回放，与既有
     「完整事件日志与存档」未覆盖条目一致）。
   - `node.tier`（本片取模板 type）在 lab 里**没有任何读取点**——slice-09 起就是只写字段，
     与 `knownFacts` 同属「声明了没人读」一类，但影响面小，未动。
```
