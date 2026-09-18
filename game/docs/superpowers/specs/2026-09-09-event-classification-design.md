# 事件分类与路线生成设计（2026-09-09）

> 用户裁定（2026-09-09）：**先对事件分类；节点模板在分类内按当前层难度与概率伪随机**。
> 暂定 4 类：战斗 / 休息 / 未知 / 交易；覆盖不全再补充。
> 休息类合并原修炼、休息、炼蛊节点，玩家**仅有一次选择机会**。
> 本规格替代 `docs/superpowers/plans/2026-09-09-route-content-diversity-plan.md` 的 R1 工单方案
> （R2-R4 回归工具与测试沿用）。实现前先读本文件与
> `docs/contracts/2026-09-02-domain-ui-contract.md`、`docs/contracts/2026-09-02-page-inventory-requirements.md`。

## 1. 目标

- 修复路线断层：现 `pacing.json` 每层 pool 仅 3 个战斗模板，73% 节点为战斗，
  21 个非战斗模板 / 12 类型整局不可达（contact/event/market/caravan/commission/wild_gu/
  hazard/earth_vein/seclusion/cultivation/ledger/pursuit）。
- 节点生成改为：**层概率 → 分类 → 层难度过滤 → 权重伪随机**（种子化，PoolManager）。
- 地图对「未知」类节点以迷雾呈现，进入后揭示（杀戮尖塔「?」节点语义）。

## 2. 事件分类映射（37 模板 → 4 分类 + 特殊）

| 分类 | 节点类型 | 模板数 | 模板 id | 现路由 |
|---|---|---|---|---|
| **战斗** | combat | 10 | beast_swarm_pass / iron_hide_ambush / scout_crossing_raid / wolf_pack_trail / faction_guard_checkpoint / layer_boss_stand_1..4 / final_boss_stand | Battle |
| **战斗** | pursuit | 1 | greedy_wanderer | Battle |
| **休息** | rest | 2 | rest_hollow / rest_shrine | Rest |
| **休息** | refinement | 1 | refinement_hollow | Refine |
| **休息** | cultivation | 1 | cultivation_spring | Rest（并入三选一） |
| **未知** | hazard | 3 | toxic_mountain_path / flooded_cave / black_mud_marsh | Encounter |
| **未知** | event | 2 | echo_cave / gu_rot_pact | Dialogue/Encounter |
| **未知** | inheritance | 3 | moonlit_trail / yizang_ridge / mist_shrine | Encounter |
| **未知** | earth_vein | 3 | earth_vein_contest / sealed_earth_vein / poison_fog_vein | Encounter |
| **未知** | wild_gu | 1 | blood_moss_grove | Encounter |
| **未知** | seclusion | 1 | body_imprint_ritual | Encounter |
| **交易** | contact | 2 | neutral_wanderer / wandering_peddler | Npc |
| **交易** | caravan | 2 | ridge_caravan / caravan_missing_goods | Shop |
| **交易** | market | 2 | village_short_work / ridge_market | Shop |
| **交易** | shop | 1 | ridge_black_market | Shop |
| **交易** | commission | 1 | herbalist_commission | Encounter |
| **特殊（固定位）** | ledger | 1 | stage_one_ledger | Encounter（阶段结算锚点） |
| **特殊（固定位）** | ascension | 1 | ascension_window | Encounter（终局锚点） |

统计：战斗 11 / 休息 4 / 未知 13 / 交易 8 = **36 模板进随机池**；特殊 2 模板走锚点固定位。
4 分类完全覆盖 17 种类型，无需第 5 类。

## 3. 层生成算法（替代 pacing.pool 直选）

```
对每个非锚点节点槽：
1. 按本层分类概率表抽一个分类（种子化权重）
2. 分类内取 stage <= 当前层 的模板（层难度过滤）
3. 池内去重（used_in_row）后按模板权重伪随机（PoolManager 过滤/权重/保底）
锚点槽：保持现状（boss / ledger / ascension / yizang_ridge / refinement_hollow /
        ridge_black_market 等固定位，不属于随机池）
```

### 3.1 层分类概率表（2026-09-09 E2a 实测校准 v3，随机槽权重）

> **口径注**：此表是**随机槽分类权重**（进入分类池的模板抽取概率）。整局实际占比受两类
> 固定位稀释：① `REST_ROW_STRIDE=2` 强制休息行（2026-09-08 用户裁定续航节奏，每层 ~4 个）；
> ② 锚点（黑市 3 / 遗葬 1 / 修炼 1，每层 ~5 个）+ 行尾 Boss 1。100 种子整局实测
> **战斗 53.7% / 休息 21.2% / 未知 9.2% / 交易 15.9%**；20 种子聚合 59.4% 落入目标区间。
> 若需整局战斗更贴近 60%，须牺牲 unknown/trade 存在感或放宽休息节奏（二者均经用户裁定，
> 未获新指令前不再上调 battle 权重）。

| 层 | 战斗 | 休息 | 未知 | 交易 | 说明 |
|---|---|---|---|---|---|
| L1 | 82% | 5% | 9% | 4% | 新手层，战斗主导 |
| L2 | 80% | 5% | 10% | 5% | 未知渐增 |
| L3 | 78% | 5% | 11% | 6% | 车队/追猎进入池 |
| L4 | 76% | 5% | 12% | 7% | 灵脉/险地 |
| L5 | 74% | 5% | 13% | 8% | 终盘，战斗占比保底 |

目标：整局战斗占比 73% → **55–60%**（整局口径，含固定位；实测聚合 59.4%，见 §6）。

## 4. 休息类三选一机制（修炼 / 休整 / 炼蛊）

- 定义：**type ∈ {rest, refinement, cultivation} 的节点统一归入休息类**，
  进入后玩家从三个动作族中选择**一次**，执行后离开（沿用 `rest_choice_required`
  硬选择门禁，leave 仅在任一动作合法或 skip 确认后放行——契约 §P6 不变）。
- 三个动作族：
  - **休整**：现有 `rest` 命令全集（heal / upgrade_card / remove_card / remove_imprint / remove_curse / skip）
  - **修炼**：`meditate`（调息）/ `cultivate`（冲阶）——领域命令已存在（resolver 已注册 meditate；cultivate 经 action_card）
  - **炼蛊**：`refine`（炼蛊 / 合炼）——领域命令已存在（refinement 会话）
- 快照结构（contract 待回写）：`rest` 快照新增 `mode_groups` 键——
  `{ "休整": [...], "修炼": [...], "炼蛊": [...] }`，每组沿用现有 card 结构；
  未开放的动作族给 `disabled + reason`（如无蛊可炼 / 无蛊可强化）。
- 模板归属：`rest_hollow/rest_shrine` 主推「休整」（修炼/炼蛊可开放但空置禁用）；
  `refinement_hollow` 主推「炼蛊」；`cultivation_spring` 主推「修炼」。
  三组 UI 始终展示，禁用的原因直白（不藏）。
- 路由：三个模板统一 `_show_rest()`；`refinement` 不再单独走 Refine 屏（炼蛊在休息屏内执行）。

## 5. 地图显示

- 未知类节点（hazard/event/inheritance/earth_vein/wild_gu/seclusion）在地图上显示为
  「未知 · ?」迷雾节点，点击后进入时揭示模板 id 与标题。
- 战斗/休息/交易节点按现有规则显示类型图标（或模板图标）。
- 地图屏节点图标映射表见 §2「现路由」列（type → 图标）。

## 5.5 战斗敌人按层伪随机（用户裁定 2026-09-09 追加）

现状：敌人写在节点模板 `enemy_kind`/`enemy_kinds`（硬编码单一绑定）；
`data/enemies.json` 已有 `tier(common/elite/boss)` + `rank(0-5)` + `hp/turn`，
但随机选敌从未使用（12 敌人，数值已按层缩放 turn_scaling 存在）。

- 数据：`enemies.json` 每敌人补 `weight`（默认 10，越高越常出）。
- 生成：战斗节点实例化时（map_generator，种子化 SeededRoll）：
  1. 模板保留 `enemy_kind`/`enemy_kinds` 为**锚定池**（boss 位、兽群主题位直用）；
  2. 普通战斗模板可加 `enemy_roll: {min_rank, max_rank, count}`——按当前层
     rank 范围过滤敌人池 → **品质权重**（pacing 每层 `enemy_weights`：
     L1 80/20/0 → L5 40/60/0，common/elite/boss；boss 只 boss 位）伪随机抽 count 个；
  3. 无 `enemy_roll` 的模板回落现有 enemy_kind 直用（兼容，schema 校验保留）。
- 品质随层：elite 概率逐层升（L1 20% → L5 60%），common 反向；boss 仅
  layer_boss_stand/final_boss_stand 固定，不入随机池。
- 确定性：同种子同敌人组合；`battle.enemies` 快照与战斗实例一致。

## 5.6 商店物品按层伪随机（用户裁定 2026-09-09 追加）

现状：`run_snapshot_builder.shop()` 遍历全部 `shops.json` offers 仅按
`tier > max_tier` 过滤——**无随机、无权重**，同层每次商店货架相同。

- 数据：`shops.json` offers 补 `weight`（默认 10）。
- 生成：进入商店节点时（travel 会话，种子化）在 state 记 `shop_roll`
  （本店 offer id 列表 + 保底标记），快照与购买命令均读同一 `shop_roll`：
  1. 按当前层 `max_tier`（pacing `shop_max_tier`）过滤货池；
  2. 按 tier 权重伪随机抽 N 个（N = 4 + layer/2，约 4-6；高 tier 货 weight 低=稀有）；
  3. **保底**：至少 1 件当前层最高可上架 tier 的"品质货"（soul_boost/barter 优先）。
- 购买：`_shop_purchase` 校验 offer id ∈ 本店 `shop_roll`（不在货架= `unknown_shop_offer`
  拒绝，现有文案复用）；`shop_tier_locked` 门禁保留。
- 快照：`shop.offers` = 本店实际上架（含现有 price/quality/curse_warning 字段），
  契约回写说明随机化（同层不同店货架不同）。

## 6. 校准与验收

- `tools/verify_pacing_density.gd` 扩展：按 4 分类统计全路线节点分布
  （当前只按 6 类计数），断言每层 4 分类均 > 0 且战斗占比落在目标区间。
- 新增 `route_diversity` 校验：全 36 随机模板在 5 层长线种子族中**至少可达**
  （travel → leave 冒烟，含特殊锚点）。
- 单元测试：分类概率抽样确定性（同种子同结果）、层难度过滤（stage > 层不选）、
  三选一命令面（rest 节点 mode_groups 三族齐全、执行一族后 leave 放行）。
- 冒烟：`verify_master_flow.gd` 全类型 travel 覆盖（contact→Npc、event→对话、
  market→Shop、refinement→Rest、hazard/event→Encounter）。

## 7. 实施工单（分批，每批独立可验证）

| 工单 | 内容 | 验证 |
|---|---|---|
| **E1 数据层** | `pacing.json` 改为层分类概率表（§3.1）；`nodes.json` 增补
  stage 归属修正（如有 stage 空缺模板调整）；删除 pool 直选数组 | 解析 + schema 校验 |
| **E2 生成器** | `map_generator.gd`：分类抽取 → 层过滤 → 权重伪随机；
  保留锚点逻辑；未知类节点标记 `revealed=false` | 确定性单测（种子族分布） |
| **E3 领域三选一** | rest 快照 `mode_groups`；refinement/cultivation 并入 rest 会话；
  contract 回写（§P6 + 快照键） | rest 单测 + contract 校验 |
| **E4 表现层** | 休息屏三选一 UI（三组卡片区，一组高亮可执行）；
  地图屏未知类「?」迷雾渲染；travel 分发 refinement→Rest | 交互审计（无死按钮）+ 截图 |
| **E5 回归** | `verify_pacing_density` 扩展 + `route_diversity` + 全量测试 | unit + integration 全绿 |
| **E6 敌人伪随机** | `enemies.json` 补 weight；`map_generator.gd` 战斗节点
  `enemy_roll` 抽取（层 rank 过滤 + 品质权重 + 种子化）；pacing 每层
  `enemy_weights`；battle 快照一致 | 确定性单测（同种子同敌）+ 层门禁 |
| **E7 商店伪随机** | `shops.json` offers 补 weight；travel→shop 时生成
  `shop_roll`（按层 tier 权重抽 N + 保底 1 品质货）；快照与购买读同一
  `shop_roll`；契约回写 | 确定性单测 + 保底断言 + 购买越权拒绝 |

风险表：休息屏三选一若领域命令（cultivate 冲阶）语义与现状冲突 → 先只接
meditate/refine/rest 三族，cultivate 保留 action_card 通道；未知类节点揭示后
若有屏内缺内容（Npc 无商人数据等）→ 按 D3 决策「先可达、内容后补」，列入待办。

## 8. 待用户拍板

- D-A：战斗占比目标 55–60% 是否接受（现 73%）。
- D-B：休息类三选一是否覆盖所有 type ∈ {rest, refinement, cultivation} 节点
  （含锚点 refinement_hollow）。
- D-C：未知类「?」迷雾是否连已知模板也隐藏（现 yizang_ridge 等 visible=true 锚点是否保留可见）。
- D-D：聚焦提交（E1-E5 分批提交）还是单批聚合提交。
- D-E：敌人随机粒度——「节点主题锚定池 + 层品质随机」是否接受（兽群位固定兽群、
  其余按 rank/品质抽），还是完全脱离模板全局抽。
- D-F：商店每次上架数 N=4+layer/2 与保底规则是否接受；同层多次进店是否允许
  货架刷新（现方案：每店生成一次 shop_roll，固定到离开）。
