# 问真 Web 原型 · 通用节点动作设计（险地 / 市集 / 野蛊）

日期：2026-09-21

状态：本轮限定范围实现。规则、门禁与玩家可见文案全部照搬 Godot 现有实现
（`social_command_rules.gd` 的 standard actions + `action_preview_service.gd` 的预览卡），不新设计、不动数值。

## 范围

把 slice-09 的险地页泛化为**通用节点动作页**，并让固定节点图的非战斗槽位从「只有险地」扩为
「险地 + 市集 + 野蛊」的合并模板池：

```text
固定节点图某层（3 候选）
  -> 每层确定性换入 1 个非战斗节点（模板池 = 险地 3 + 市集 2 + 野蛊 1，共 6 个，按 seed 选）
  -> 选中后进入节点动作页：按模板 choices 出标准动作卡（另按 Godot 口径总补一张 leave 卡）
  -> 解析：元石 / 真元增减、事实记录、门禁拒绝
  -> 统一整备（沿用节点后统一整备）
  -> 选择下一个节点
```

本片接入的动作（8 个）：

| 动作 | 效果 | effect id | Godot 来源 |
| --- | --- | --- | --- |
| `work` | 元石 +3 | `action_work_paid` | `social_command_rules.gd:749-750` |
| `harvest` | 元石 +2 | `action_harvest_stone` | `:751-752` |
| `buy_information` | 门禁元石 ≥ 2；成功扣 2，记事实 `bought_information` | `action_bought_information` | `:764-765` + `:823-831` |
| `trade` | 门禁元石 ≥ 2；成功扣 2，记事实 `bought_service` | `action_trade_service` | `:766-767` + `:823-831` |
| `cross` | 门禁真元 ≥ 1；成功扣 1 | `action_cross_cost` | `:768-771` |
| `scout` | 只记事实 `route_scouted` | `action_scout_route` | `:801` |
| `withdraw` | 只记事实 `withdrawn_safely` | `action_withdraw_safely` | `:802` |
| `leave` | 只记事实 `route_left_behind` | `action_leave_route` | `:799`（转移）+ `:1198-1208`（卡片） |

未列出的 action id 一律拒绝 `unsupported_standard_action`（`:803` 兜底）。

不在本片范围（逐条登记在覆盖页 `notCovered`）：

- 效果落在 `pursuit`（追击压力）上的 `deceive` / `retreat`（`:774-777`）——lab 没有该状态槽。
- 效果落在 `ascension`（升仙五项）上的 `open` / `prepare` / `scheme`（`:778-783`）——lab 没有升仙窗口。
- 写入 `body_imprints` 的 `take_imprint`（`:784-794`）——lab 没有体印系统。
- 只记事实、lab 无消费点的 `accept` / `ally` / `claim` / `inspect` / `lure`（`:795-800`），
  以及 contact / caravan 的专属动作（`negotiate` / `deceive` / `retreat` / `fight` / `probe` / `buy` / `sell` / `exchange`）。
- `refine` / `cultivate`（→ `refine_command_rules.gd`）、`rest`（→ `rest_rules.gd`，含 rest-class 一次性门禁
  `rest_rules.gd:39/55/92/115` 与 `social_command_rules.gd:586-589` 的 `rest_choice_required`）、
  `claim_recon` / `claim_token`（→ `inheritance_claim_rules.gd`）、`settle_feeding` / `accept_debt`（总账）。
- 其余节点类型（contact / caravan / event / refinement / cultivation / ledger / inheritance / commission /
  pursuit / earth_vein / seclusion 等）的专属结算。

## Godot 语义来源（行号）

| 项 | 来源 | 内容 |
| --- | --- | --- |
| 动作全集 | `game/scripts/domain/social_command_rules.gd:512-517` | `STANDARD_ACTIONS` 23 个（本片只搬其中 8 个） |
| 转移总表 | 同文件 `:747-803` | `_standard_action_transition`；未列出 → `unsupported_standard_action`（`:803`） |
| 资源增减语义 | 同文件 `:814-821` | `_resource_transition`：`before` 记改之前的值、`after` 记改之后的值（不是 delta） |
| 元石购买门禁 | 同文件 `:823-831` | `_spend_stone_for_fact`：元石 < 2 直接拒绝 `insufficient_stone`，无 before/after |
| 事实转移 | 同文件 `:881-887` | `_fact_transition`：只写 `known_facts` |
| 事实去重 | `game/scripts/domain/resolver_helpers.gd:24-26` | `add_fact`：已存在则不重复追加 |
| 标准卡遍历 | `game/scripts/domain/action_preview_service.gd:992-995` | 遍历 `node.choices` 时跳过 `leave` |
| leave 卡补入条件 | 同文件 `:44-45` | 节点类型不在 `caravan/refinement/cultivation/ledger/shop/event/rest` 名单里时补一张（三类节点都在名单外） |
| 标准卡文案 | 同文件 `:998-1128` | `work` `:1114-1115`；`harvest` `:1043-1044`；`buy_information`/`trade` `:1029-1035`；`cross` `:1022-1028`；`scout` `:1076-1077`；`withdraw` `:1085-1087`；卡 `summary` 取节点 `summary` `:1119` |
| 元石 remedy | 同文件 `:1306-1309` | `_stone_remedies`：三条固定文案，`%d` = 2 − 当前元石 |
| leave 卡 | 同文件 `:1198-1208` | 标题「离开遭遇」、summary「主动结束当前遭遇，返回地图选择下一条路线。」、收益「结束当前遭遇。」 |
| 成本显示键 | `game/scripts/presentation/display_text.gd:455-462` | `stone` → 「元石 N」；`spirit` → 「真元 N」（领域键是 `essence`，lab 侧 `state.qi`） |
| 行动结果文案 | 同文件 `:223-244` | `:226` buy_information、`:230` harvest、`:232` leave、`:238` scout、`:241` trade、`:242` withdraw、`:243` work |
| 被拒兜底 | 同文件 `:503-505` | 「行动未能完成。」 |
| 模板与中文名 | `game/data/nodes.json` + `game/data/names.json` | `toxic_mountain_path` / `flooded_cave` / `black_mud_marsh`（险地）、`village_short_work` / `ridge_market`（市集）、`blood_moss_grove`（野蛊）；类型名与动作名取 `names.json` 的 `types` / `actions` 分区 |

## 图放置规则（零配比漂移）

保持既有不变量：每层 3 个候选、同层候选共用同一批后继、每段最后准备层汇入唯一层主、整局固定 5 段、
难度只改 `prepPerSegment`。本片**不改**槽位数、候选数与层数。

- 每层（segment, depth）确定性地把 3 个候选中的一个槽位换成非战斗节点：
  - 槽位：`RunRules.seededIndex(3, seed, 'L{segment}D{depth}.hazard.slot')`
  - 模板：`RunRules.seededIndex(pool.length, seed, 'L{segment}D{depth}.hazard.template')`
  - **槽位 seed 字符串沿用 slice-09 不改名**：每层非战斗槽位的落点与上一片逐格一致；
    本片唯一变化是模板池由 3 个险地扩为 6 个（险地 3 + 市集 2 + 野蛊 1）。
- 图节点 id 仍是 `L{segment}D{depth}N{slot}`；非战斗节点携带 `routeTemplateId`（模板 id）与
  `routeKind`（模板 type），`type` / `tier` 取模板 type，`enemyIds` 为空，`name` 为 `「类型名 · 模板名」`
  （类型名由调用方传入 `DATA.nodeTypes`，不在 `run_flow` 里硬编码）。
- 精英判定仍按原 `(depth + slot) % 4 === 3`；非战斗节点占了该槽时，该层少一个精英，不额外补位。
- 模板池为空时回退为纯战斗图（不抛错）；模板没有非空 `choices` 时不进池（节点动作页靠模板 `choices` 出按钮）。

## 结算与流程

- 进入非战斗节点（`hazard` / `market` / `wild_gu`）→ 节点动作页列出动作卡：
  - 按模板 `choices` 顺序出卡，跳过其中的 `leave`；末尾总是补一张 `leave` 卡（`:992-995` + `:44-45`）。
  - 每张卡带标题（`leave` 用固定标题「离开遭遇」，其余取 `names.json` 的 `actions`）、节点 `summary`
    （`leave` 用自己的固定 summary）、成本（元石 / 真元）、收益、风险、不可用原因与 remedy（元石不足三条）。
- 解析成功：按转移写回 `state.stones` / `state.qi` / `state.knownFacts`，记 `eventLog`（`choose_action`，
  reason = effect id，targets = `routeTemplateId`）、写 journal，然后进入统一整备。
- 解析被拒（元石 < 2 / 真元 < 1 / 未列出的动作）：只提示 Godot 文案，不改状态、不开事件（对齐 `Resolver._rejected`）。
- 每个节点只解析一次；之后该节点只剩统一整备，与战斗节点「一个节点一战」一致。
  Godot 社交节点理论上可多次 `choose_action`，本轮不建模。

## 验收

- `node tools/build_data.mjs` 成功，`nodes` 仍为 37；`js/data.js` 只有 `mechanisms` 区变化
  （prefix / tail 的 sha256 与改动前逐字节一致）。
- `node --test tests/*.test.mjs`：既有 55 条 + 新增 7 条，0 fail（新增文件单跑 15/15）。
- 规则测试覆盖：8 个动作的转移与 before/after 语义、两条门禁与「拒绝时状态不变」、两条成功扣减与事实、
  `leave` 事实、未知动作兜底、预览文案与 remedy 逐字、`leave` 补卡与 `choices` 去重、结果文案、
  合并池放置确定性（每层 1 个）与固定 seed 钉值、三档难度的行/层主不变量、无模板回退、
  空 `choices` 模板不进池、数据契约（6 个模板的每个 choice 都能解析）。
- 浏览器（由 L2 实点）：选中市集节点进入节点动作页 → 做工 / 交易 / 买情报 → 元石不足提示与 remedy →
  解析后进入统一整备 → 完成整备进入下一节点；控制台 0 error。

## 边界

- 仅修改 `game/wenzhen-web-lab/` 与本设计文档；不碰 Godot 线任何文件；不提交、不推送。
- 不引入 ES module、新依赖、Manager / EventBus / 状态管理、构建步骤；保持双击 `index.html` 即开。
- 数据只有一条来源 `tools/build_data.mjs`；不手改 `js/data.js`。
- 不新增 write-only 状态槽（不加 `pursuit` / `ascension` / `bodyImprints`）；既有 `knownFacts` 只写不读，
  已在覆盖页如实登记。
- 模板的 `stage` 字段仍不参与筛选（lab 段号与转数/阶段没有既有映射）；`on_skip` 仍不做（Godot 域层零实现）。
