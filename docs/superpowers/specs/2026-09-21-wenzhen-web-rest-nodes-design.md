# 问真 Web 原型 · 恢复类节点设计（休整 / 静修）

日期：2026-09-21

状态：本轮限定范围实现（parity 切片 11）。规则、门禁与玩家可见文案全部照搬 Godot 现有实现
（`rest_rules.gd` 的一次性收益门禁 + `action_preview_service.gd` 的休整卡集合 + `social_command_rules.gd`
的 `meditate`），不新设计、不动数值。

## 范围

把固定节点图的非战斗模板池由 6 个扩到 9 个，把「恢复气血与真元」的途径接回地图：

```text
固定节点图某层（3 候选）
  -> 每层确定性换入 1 个非战斗节点（模板池 = 险地 3 + 市集 2 + 野蛊 1 + 休整 2 + 静修 1，共 9 个，按 seed 选）
  -> 休整节点（type=rest）两步：先取「歇脚恢复」（一次性），「离开休整」才解禁 -> 统一整备
  -> 静修节点（type=seclusion）一步：任意标准动作（本片只搬「静修」）-> 统一整备
  -> 选择下一个节点
```

| 项 | 效果 | effect id | Godot 来源 |
| --- | --- | --- | --- |
| 休整「歇脚恢复」 | 气血 `min(上限, 当前 + max(1, floor(上限 × 0.30)))`、真元 `min(上限, 当前 + 2)`；消费本次探访 | `rest_recovered` | `rest_rules.gd:121-141` |
| 休整「离开休整」 | 探访未消费时拒绝 `rest_choice_required`；消费后放行（lab 沿用 leave 转移） | `action_leave_route` | `action_preview_service.gd:799-808`（卡）+ `social_command_rules.gd:586-589` / `encounter_session_resolver.gd:121-126`（门禁） |
| 静修「静修」 | 真元 +1（按真元上限截断） | `action_meditate_essence` | `social_command_rules.gd:772-773` |

## Godot 语义来源（行号）

| 项 | 来源 | 内容 |
| --- | --- | --- |
| 休整类型 | `game/scripts/domain/rest_rules.gd:22` | `REST_NODE_TYPE := "rest"` |
| 休息类名单 | 同文件 `:27` | `REST_CLASS_TYPES = ["rest", "refinement", "cultivation"]`；**`seclusion` 不在其中** |
| 恢复公式 | 同文件 `:121-141` | `_rest_heal`：探访已消费 → `rest_already_used`；成功写 `rest_recovered` 与 `<节点id>_used`（`:125,128`） |
| 消费探访 | 同文件 `:165-179` | `_consume_rest_visit`：写 `<节点id>_used="used"` 与 `<节点id>_mode="true"`，事件 `rest_visit_consumed`（本片未搬） |
| 跳过模式 | 同文件 `:89-103` | `_rest_skip`：只在领域层可达，Godot 的卡片集合没有入口（不搬） |
| 离开门禁 | `game/scripts/domain/social_command_rules.gd:586-589`、`encounter_session_resolver.gd:121-126` | 休息类节点探访未消费时离开被 `rest_choice_required` 拒绝 |
| 离开成功路径 | `encounter_session_resolver.gd:133-149` | `leave_node` → `complete_node(outcome="abandoned")`，reason `encounter_left` / `encounter_left_wounded`（lab 未搬该分支，见「偏差」） |
| 休整卡集合 | `game/scripts/domain/action_preview_service.gd:746-808` | `node.rest_heal`（`:750-758`）、`node.leave`（`:799-808`） |
| 收益卡门禁 | 同文件 `:811-831` | `executable = not used and available`；已消费 → `block_reason`「本次休整已处置完毕。」（`:822-823`） |
| 离开卡门禁 | 同文件 `:803-804` | `executable = used`；未消费 →「休整抉择未定：须先选择恢复、强化或移除其一，才能离开。」 |
| 文案漂移 | 同文件 `:756` vs `rest_rules.gd:129-131` | 卡片写死「恢复气血 2 点。/恢复真元 2 点。」，实际是 30% 上限（至少 1）与 +2 —— 已登记，lab 显示真实数值 |
| 静修动作 | `game/scripts/domain/social_command_rules.gd:772-773` | `meditate` → `_resource_transition(state, "essence", 1, "action_meditate_essence")`（`:814-821` 不截断上限） |
| 静修文案 | `game/scripts/presentation/display_text.gd:76,234`、`action_preview_service.gd:1068-1069` | 显示名「静修」、结果「你静修片刻，恢复了一点真元。」、收益「恢复 1 点真元。」 |
| 类型名缺口 | `game/data/names.json` → `types` vs `display_text.gd:54` | `types` 缺 `rest` 键；Godot `const TYPES` 里 `rest` =「休整」；lab 回退表取后者 |
| 模板与文案 | `game/data/nodes.json` | `rest_hollow`（山壁石穴）、`rest_shrine`（古祠残龛）、`body_imprint_ritual`（体印仪式） |

## 两步交互（本片唯一的模型改动）

只对 `type=rest` 生效；`seclusion` 与其余节点类型保持「一节点一动作」。

```text
进入休整节点（state.restUsed = false）
  ├─ 点「歇脚恢复」-> 结算 rest_recovered，restUsed = true，页面留在节点动作页（收益卡变禁用、离开卡变可用）
  ├─ 再点「歇脚恢复」-> 拒绝 rest_already_used，状态不变、页面不推进
  ├─ 未取收益点「离开休整」-> 拒绝 rest_choice_required，状态不变、页面不推进
  └─ 取过收益点「离开休整」-> 结束节点动作页，进入统一整备（沿用 lab 的 leave 口径）
```

被拒一律只提示不改状态（对齐 `Resolver._rejected`）。收益卡的 `available` 与离开卡的 `available`
都由「本次探访是否已消费」派生，因此不存在「可点但必然被拒」的按钮。

## 图放置规则（零配比漂移）

保持既有不变量：每层 3 个候选、同层候选共用同一批后继、每段最后准备层汇入唯一层主、整局固定 5 段、
难度只改 `prepPerSegment`。本片**不改**槽位数、候选数、层数与难度；`boss` 节点仍恰 5 个。

- 每层仍只换入 1 个非战斗节点，槽位与模板的 seed 字符串沿用 slice-09/10
  （`L{segment}D{depth}.hazard.slot` / `.hazard.template`），**槽位落点逐格不变**。
- 唯一变化：模板池由 6 个扩到 9 个（险地 3 + 市集 2 + 野蛊 1 + 休整 2 + 静修 1），
  因此各类型的出现频率被进一步稀释（本片首局 seed 101 / normal：险地 12 / 市集 11 / 野蛊 8 /
  休整 12 / 静修 7，slice-10 是险地 31 / 市集 12 / 野蛊 7）。这属于 slice-10 已登记、待 L1 裁的
  同一件事的延续，**不是本片新增裁决项**。
- 模板池为空时仍回退纯战斗图；模板 `choices` 为空时不进池（既有规则不变）。

## 结算与流程

- 休整节点不走 `choices` 出标准卡（Godot 侧本就是 `_append_rest_cards` 与 `_append_standard_cards`
  两条出牌函数）：卡片集合固定为「歇脚恢复 + 离开休整」两张。
- 标准节点继续按 `choices` 出卡，但**只对已搬动作出卡**：`body_imprint_ritual` 的 `take_imprint`
  未搬（写 `body_imprints`），不出禁用空按钮，按覆盖页登记不实现。
- 休整恢复的卡片收益显示按当前数值算出的真实恢复量（例：上限 24 点时「恢复气血 7 点。」），
  与 Godot 卡片写死的「2 点」不同——该不一致登记在覆盖页。
- 事件：休整取收益 reason `rest_recovered`；离开 reason `action_leave_route`；静修 reason
  `action_meditate_essence`；均落在 `choose_action` 事件上（targets = `routeTemplateId`），
  并在 `state.journal` 记一行。

## 偏差（登记，供 L2 裁决）

1. **离开成功路径**：Godot 的 `leave_node` 在领域侧走 `complete_node(abandoned)` 并记
   `encounter_left` / `encounter_left_wounded`（`encounter_session_resolver.gd:133-149`）。
   lab 为与其它节点类型的「离开」卡一致，沿用 `action_leave_route` + fact `route_left_behind`；
   门禁那一半（`rest_choice_required`）是照搬的。
2. **`meditate` 的上限截断**：Godot `_resource_transition:814-821` 不截断（`before + delta`），
   lab 按 L2 口径在真元上限（`state.qiMax`）处截断，避免出现超过上限的真元。
3. **探访标记的载体**：Godot 用按节点 id 作用域的 `<节点id>_used` 旗标；lab 复用既有
   `state.restUsed` 布尔并在进入节点时清零——lab 一次只处理一个节点，行为等价（该字段此前
   只写不读，本片起被真正消费）。
4. **文案选择**：`rest_choice_required` 的提示文本用卡片上的门禁原文（`:804`），不用
   `rejection_text.gd:101` 那条点名「调息/强化/移除/跳过」的版本——lab 的休整菜单没有强化/移除/跳过。

## 验收

- `node tools/build_data.mjs` 成功；既有字段计数不变（`gu 77 | recipes 6 | killMoves 5 | enemies 14 |
  nodes 37 | route 12 | shopOffers 34`）；`js/data.js` 只有 `mechanisms` 区变化（prefix / tail 逐字节一致）。
- `node --test tests/*.test.mjs`：69 条全绿（slice-10 基线 62）。
- 规则测试覆盖：`meditate` 真元 +1 与上限截断、休整恢复的三条边界（30% 向下取整 / 至少 1 / 上限截断）、
  休整卡的真实数值与两条门禁文案、重复取收益与未取收益离开的「拒绝且状态不变」、取过收益后离开、
  静修无休整门禁、`rest` 类型名回落、9 模板池的放置确定性与固定 seed 钉值、数据契约。
- 集成（node 侧真实 DATA + 真实模块，首局 seed 101 / normal）：模板池 9 与各类型计数、每层恰 1 个非战斗
  槽位、`boss` 恰 5 个、恢复数值 10/24 → 17、3/20 → 5、边界不越上限、三条门禁、静修真元 +1。
- 浏览器（由 L2 实点）：休整节点两步交互、静修节点一步、控制台 0 error。

## 边界

- 仅修改 `game/wenzhen-web-lab/` 与本设计文档；不碰 Godot 线任何文件；不提交、不推送。
- 不引入 ES module、新依赖、Manager / EventBus / 状态管理、构建步骤；保持双击 `index.html` 即开。
- 数据只有一条来源 `tools/build_data.mjs`；不手改 `js/data.js`。
- 不新增 write-only 状态槽（不加 `pursuit` / `ascension` / `bodyImprints` / `injury` / `relics` / `curses`）；
  `restUsed` 是本片唯一被新消费的状态，且既被写也被读。
- 不搬 `take_imprint`（写 `body_imprints`）与休整的另四种收益（强化蛊卡 / 移除蛊 / 抹除印记 / 拔除反噬）——
  lab 没有对应系统，搬进来就是空按钮，逐条登记在覆盖页。
