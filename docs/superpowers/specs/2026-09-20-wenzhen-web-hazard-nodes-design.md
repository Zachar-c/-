# 问真 Web 原型 · 险地节点设计（hazard / 探查 · 穿越 · 退回）

日期：2026-09-20

状态：本轮限定范围实现。规则全部照搬 Godot 现有实现（social_command_rules 的 standard actions + action_preview_service 的预览门禁与文案），不新设计。

## 范围

把 Godot 的 `hazard`（险地）节点类型的三条 standard action 接进 Web lab 的固定节点图：

```text
固定节点图某层
  -> 选中险地节点
  -> 险地页：探查 / 穿越 / 退回（按 Godot 预览判定可用性）
  -> 解析：真元扣减 / 事实记录 / 拒绝
  -> 统一整备（沿用节点后统一整备）
  -> 选择下一个节点
```

不在本轮范围：

- `nodes.json` 里险地模板的 `on_skip` 字段（`lose_route` / `lose_clue` / `gain_pursuit`）在 `game/scripts/` 里零命中，Godot 域层没有实现，lab 不臆造跳过后果。
- 预览里额外的 `leave` 卡、以及 cross 被拒时指向「静修路线」的 remedy 文案。
- 其他节点类型（接触、商队、事件、休整等）的选择结算。

## Godot 语义来源

| 项 | 来源 | 内容 |
| --- | --- | --- |
| `scout` 转移 | `game/scripts/domain/social_command_rules.gd:801` | 只记事实 `route_scouted`，effect id `action_scout_route` |
| `cross` 转移 | `game/scripts/domain/social_command_rules.gd:768-771` | 真元 < 1 拒绝（`insufficient_essence`）；否则真元 −1，effect id `action_cross_cost` |
| `withdraw` 转移 | `game/scripts/domain/social_command_rules.gd:802` | 只记事实 `withdrawn_safely`，effect id `action_withdraw_safely` |
| 未知选择 | `game/scripts/domain/social_command_rules.gd:803` | 拒绝，理由 `unsupported_standard_action` |
| 事实去重 | `game/scripts/domain/resolver_helpers.gd:24-26` | `add_fact`：已存在则不重复追加 |
| `cross` 预览门禁 | `game/scripts/domain/action_preview_service.gd:1022-1028` | 成本 `spirit: 1`（显示键）；拒绝文案「真元不足：需要 1 点。」 |
| `scout` 预览文案 | `game/scripts/domain/action_preview_service.gd:1076-1077` | 收益「查明前路的已知征兆。」 |
| `withdraw` 预览文案 | `game/scripts/domain/action_preview_service.gd:1085-1087` | 收益「安全收手，保留当前资源与情报。」；风险「放弃此处机缘，之后无法再从当前路线取得。」 |
| 行动结果文案 | `game/scripts/presentation/display_text.gd:228,238,242` | 「你耗去真元，穿过了眼前险处。」「你探明前路，留下了可靠的路径情报。」「你及时收手，暂时全身而退。」 |
| 被拒兜底文案 | `game/scripts/presentation/display_text.gd:505` | 「行动未能完成。」 |
| 显示名 | `game/scripts/presentation/display_text.gd:69,86,90` | `cross` 穿越 / `scout` 探查 / `withdraw` 退回 |
| 节点类型名 | `game/scripts/presentation/display_text.gd:44` | `hazard` = 险地 |
| 模板与中文名 | `game/data/nodes.json` + `game/data/names.json` | `toxic_mountain_path` 毒瘴山道 / `flooded_cave` 积水石窟 / `black_mud_marsh` 黑泥沼地；`choices` 均为 `["scout","cross","withdraw"]` |

预览成本键是 `spirit`（`display_text.gd:459-460` 显示为「真元」），领域键是 `essence`；lab 侧对应 `state.qi`。

## 图放置规则（本轮唯一的设计决定）

保持既有不变量：每层 3 个候选、同层候选共用同一批后继、每段最后准备层汇入唯一层主、整局固定 5 段、难度只改 `prepPerSegment`。

- 每层（segment, depth）确定性地把 3 个候选中的一个槽位换成险地节点：
  - 槽位：`RunRules.seededIndex(3, seed, 'L{segment}D{depth}.hazard.slot')`
  - 模板：`RunRules.seededIndex(pool.length, seed, 'L{segment}D{depth}.hazard.template')`
  - 同一 `seed` + `difficulty` 产出完全相同的图；换 seed 才换槽位与模板。
- 图节点 id 仍是 `L{segment}D{depth}N{slot}`，不新增 id 空间；hazard 节点携带 `hazardId`、模板 `name`（显示为「险地 · …」）、`summary`、`choices`，`enemyIds` 为空。
- 精英判定仍按原 `(depth + slot) % 4 === 3`；险地占了该槽时，该层少一个精英，不额外补位。
- 险地模板池为空时回退为纯战斗图（不抛错），保证 `run_flow.js` 可独立使用；模板没有非空 `choices` 时不进池（险地页靠模板 `choices` 出按钮，空列表会卡死节点）。

## 结算与流程

- 进入险地节点 → 险地页列出 `choices` 三条，各自带可用性与不可用原因（`insufficient_essence` 时禁用）。
- 解析成功：真元扣减（`cross`）、事实写入 `state.knownFacts`（`scout` / `withdraw`）、记 `eventLog`（`choose_action`，reason = effect id）、写 journal，然后进入统一整备。
- 解析被拒（`cross` 真元 < 1）：只提示 Godot 预览文案，不改状态、不开事件（对齐 `Resolver._rejected`）。
- 每个险地节点只解析一次；之后该节点只剩统一整备，与战斗节点「一个节点一战」一致。Godot 社交节点理论上可多次 `choose_action`、并另挂 `leave` 卡，本轮不建模。

## 验收

- `node tools/build_data.mjs` 成功，`nodes` 仍为 37（覆盖页新增险地条目与 `on_skip` 未覆盖条目）。
- `node --test tests/*.test.mjs`：既有 45 条 + 新增 9 条，0 fail。
- 规则测试覆盖：三条转移、事实去重、`cross` 真元不足被拒、未知选择兜底、选项可用性与文案、同种子放置确定性与图不变量、无模板回退、无 `choices` 模板不进池、数据契约。
- 浏览器（由 L0/L2 实点）：选中险地节点进入险地页 → 三条选择 → 真元不足时禁用与提示 → 解析后进入统一整备 → 完成整备进入下一节点；控制台 0 error。

## 边界

- 仅修改 `game/wenzhen-web-lab/` 与本设计文档；不碰 Godot 线任何文件；不提交、不推送。
- 不引入 ES module、新依赖、Manager / EventBus / 状态管理、构建步骤；保持双击即开。
- 数据只有一条来源 `tools/build_data.mjs`；不手改 `js/data.js`。
- 险地模板的 `stage` 字段（`one` / `three`）本轮不参与筛选：lab 的段号与转数/阶段没有既有映射，加筛选属新设计。
- `on_skip` 登记为「数据有字段、Godot 无实现、本轮不做」（覆盖页未覆盖清单 + 交接文档）。
