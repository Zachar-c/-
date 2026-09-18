# 杀招（kill_moves）设计与落地计划

- 日期：2026-09-11
- 触发：剑道调研中发现 `kill_moves` 为空数组；进一步核查后发现**问题比"数据为空"更结构化**
- 依据：`AGENTS.md`（核心玩法支柱：玩家自由组装杀招 + 蛊虫海量合成）、
  `docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md` §4「自由组合与杀招」
- 本文所有「现状」条目均为实测（可指到文件与行）

---

## 0. 结论速览

1. **杀招不是"要从零建的系统"**：域结算（`play_kill_move`）、命令面（`battle_command_facade`）、
   释放门禁（`kill_move_reason`）、快照键（`kill_moves`）、战斗屏 UI（`KillRow` + "未研习"空位）、
   内容校验（`_validate_v1_kill_moves` + 切片闭包校验）**全部已存在且已接线**。
2. **真正缺的是三件事**：① `data/v1_battle.json.kill_moves` 是空数组（无内容）；
   ② **没有任何获取路径**（`kill_move` 字样只出现在 `v1_battle.json` 一处，
   传承/商店/遗藏数据里零命中）；③ **规格 §4.2 的"玩家可保存自由编排为杀招"完全没实现**。
3. **还有一处实现与规格相违背**：规格 §517 要求「杀招默认累加所有组成蛊的实际成本」，
   现实现却直接读杀招自己声明的 `true_qi_cost/thought_cost/life_cost`（可由数据写死）。
4. 因此本设计的重心**不是"造系统"，而是"补内容 + 接获取 + 让玩家的编排能固化"**，
   并且必须守住一条最容易被做错的语义：**保存的杀招不得退化成一个原子大招按钮**（规格 §4.2 明文）。

---

## 1. 现状基线（实测）

### 1.1 已通的部分

| 环节 | 实现 | 位置 |
|---|---|---|
| 战斗构建 | `_build_kill_moves(run_state, catalog)`：按 `recipe` 的 definition_id → 实例 id 映射；**配方缺一只即整个杀招不出现在列表**（严格） | `v1_battle_resolver.gd` |
| 杀招条目字段 | `{id, label, tag, recipe(instance ids), true_qi_cost, thought_cost, life_cost, damage, effect, reveals}` | 同上 |
| 释放门禁 | `kill_move_reason()`：未知 id / `effect_reason` 非法 / 配方蛊不在槽或 `is_sealed` → `kill_move_recipe_sealed` / 念头耗尽 → `action_limit_reached` | 同上 |
| 结算 | `play_kill_move()`：找到条目 → 校验 effect 形状（**空 effect 只允许 damage-only**）→ 结算 | 同上 |
| 命令面 | `play_kill_move` 已在白名单，映射 `{"type":"play_kill_move","kill_move_id":...}` | `battle_command_facade.gd:21,173` |
| 快照 | `battle_snapshot._v1_kill_moves()`，且拒绝原因有中文文案 | `battle_snapshot.gd:250,279` |
| UI | 战斗屏 `BattleInfo/KillRow` + `_refresh_kill_moves()`（空位显示"未研习"）；大厅 `kill_screen` 为杀招屏（文案「杀招在战斗中以念头施展」） | `battle_screen_view.gd:39,645` |
| 内容校验 | 形状校验 + 重复 id 检查 + 「带 `kill_move_id` 的配方」闭包校验（切片） | `content_catalog.gd:1062–1127` |
| 测试 | `test_v1_battle_resolver.gd` / `test_command_contract.gd` / `test_content_catalog.gd` 均含 kill_move 断言 | `tests/unit/` |

### 1.2 空的部分

| 缺口 | 实测 |
|---|---|
| 预制杀招内容 | `data/v1_battle.json.kill_moves = []` |
| 获取路径 | `kill_move` 只在 `v1_battle.json` 出现 1 次；`inheritances.json` / `shops.json` / `loot_tables.json` **零命中** |
| 合成杀招切片 | `refinement_recipes` 386 条中带 `kill_move_id` 的 = **0**（校验代码在，数据无） |
| 玩家自建杀招 | 无 `RunState` 字段、无域规则、无 UI、无存档 |
| 成本累加 | 走杀招自带 cost 字段，**不累加配方蛊成本**（违背规格 §517） |

### 1.3 规格对杀招的硬约束（§4.2 / §4.3 / §517）

1. 命名杀招靠**传承 / 购买 / 遗藏线索 / 推演 / 玩家验证**掌握。
2. **验证过的自由编排可以保存为杀招，之后一键提交**；
   **保存不把多只蛊变成一个不可打断的按钮**。
3. **默认累加组成蛊的真实真元、念头、蛊材和使用次数成本**；任何节省/增幅/额外代价必须来自**明确规则**。
4. 可跨回合维持编排；未完成步骤、主动维持、反应预留**照常占用念头**。
5. 失败传播：某步失败**不撤销**已完成或仍能独立完成的其他步骤；显式依赖失败步骤的后续动作**自动停止**；
   未执行动作不扣费，**已分配的念头本回合不返还**。

### 1.4 合规红线（会影响设计取舍）

- **蛊方图鉴是唯一允许的跨局内容解锁**（AGENTS）⇒ **玩家自建杀招不得跨局保存为战力**
  （可跨局留存的只能是"知识/配方记录"，不提供战力）。
- Run 内构筑在结局后清空。
- LLM 不参与杀招的数值/判定；数值全落 JSON 且过 Schema。
- 禁止"无来源"的协同倍率——杀招的增幅必须由 `rules` 显式声明。

---

## 2. 设计目标与核心玩法

### 2.1 目标

让 AGENTS 裁定的核心支柱「**玩家自由组装杀招**」从"有按钮没内容"变成**可玩闭环**：
玩家能把手上几只蛊编成一个序列 → 序列按规格逐步结算 → 验证有效后**固化成自己的杀招** → 之后一键提交（仍是逐步结算）。

### 2.2 核心玩法（三层，缺一不可）

| 层 | 内容 | 现状 |
|---|---|---|
| **L1 临场编排** | 逐个点蛊形成本回合的动作序列（含并行组）；每只蛊先按自身单一功能结算，后续蛊可读取已形成的状态/标记 | 部分：逐只催动已支持；**"序列/并行组"语义未显式建立** |
| **L2 保存为杀招** | 把验证过的编排固化为命名杀招，跨回合复用；**释放时仍逐步结算、可被打断** | ❌ 完全缺失（**本设计的主战场**） |
| **L3 获取命名杀招** | 设计者预制的、带协同倍率/替代步骤/特殊规则的杀招，经传承/购买/遗藏/推演获得 | ❌ 内容与渠道均空 |

### 2.3 体验目标（一句话）

> 玩家在战斗中试出一个巧妙的组合（"先破甲、再双剑齐出、最后引爆剑意"），把它存成「**双锋引**」，
> 之后每次遇到同类型敌人，一键就能把这三步按序提交——但**每一步仍可能被打断、被封印、被念头卡住**。

**反目标（明确不做）**：不做"攒满能量放大招"的原子按钮；不做无来源的协同倍率；
不让杀招绕过念头与真元预算。

---

## 3. 关键机制

### 机制 1 — 编排序列 steps（L1 的显式化）

- 杀招 = **有序步骤列表**：`steps: [ {gu: <definition_id>, target: "auto"|"enemy"|"self", group: <int>} ]`
- `group` 相同 = 并行组（规格 §4.1「串行顺序编排，也可以建立明确的并行组」）
- 步骤引用 **definition_id**（内容层），运行时映射到本局 **instance_id**（沿用现有 `_build_kill_moves` 的做法）

### 机制 2 — 成本累加与显式修正（修规格偏差，**优先级最高**）

```
实际成本 = Σ(step 引用蛊的 true_qi_cost / thought_cost / life_cost)
         + Σ(rules.modifiers 中显式声明的增减)
```

- `rules.modifiers` 是**白名单式**声明（如 `{"kind":"discount_thought","amount":1,"reason":"..."}`），
  没有声明就没有任何节省/增幅（规格 §517）
- 迁移：现有 km 的 `true_qi_cost/...` 字段保留为**兼容读取**，但数据为空 ⇒ 迁移成本≈0；
  新内容一律用累加模式，测试锁死"不得凭空节省"

### 机制 3 — 逐步结算 + 失败传播（L2 的正确性核心）

释放一个保存的杀招 = **依次执行每一步**（复用现有单蛊结算路径 `play_gu`），而不是新写一个批量结算：

| 情况 | 行为（规格 §4.3） |
|---|---|
| 某步因成本不足/条件不满足失败 | 不撤销已完成步骤；显式依赖该步的后续步骤**停止** |
| 配方中某只蛊被封印 | 释放前被 `kill_move_reason` 拦下（`kill_move_recipe_sealed`） |
| 念头耗尽 | 拦截 `action_limit_reached`；**已分配念头本回合不返还** |
| 未执行的动作 | 不扣真元/蛊材/使用次数 |

> **这条是"不做原子大招"的工程落地方式**：逐步结算天然满足"可打断"，
> 而把整段包成一个不可中断的原子操作才是违约。

### 机制 4 — 跨回合维持（P3 可选）

未完成的编排可跨回合保留其**未执行步骤**，并**照常占用念头**（规格 §4.2）。
实现上属"编排状态持久化"，与 L2 的保存机制共用数据结构。

### 机制 5 — 获取与掌握（L3）

| 渠道 | 落点 | 说明 |
|---|---|---|
| 传承 | `data/inheritances.json`（现有结构） | 遗葬点/传承节点给出杀招记录 |
| 购买 | `data/shops.json`（现有结构） | 黑市/市场售卖杀招记录 |
| 遗藏线索 | `data/nodes.json` 的 inheritance/event 模板 | 需先有事件节点（当前生成图不产事件节点，属后续） |
| 玩家验证 | L2 保存机制 | 自己试出来的即"已掌握" |

**掌握 = 解锁记录（知识），不是战力**：与蛊方图鉴同构，跨局只保存"知道有这招"，
不保存"这招可随时用"（符合"图鉴是唯一跨局解锁"的红线）。

---

## 4. 数据结构与模块划分

### 4.1 数据：预制杀招（`data/v1_battle.json.kill_moves`）

```json
{
  "id": "km_sword_double_edge",
  "label": "双锋引",
  "tag": "sword",
  "steps": [
    {"gu": "sword_atk_1_05_gu", "target": "enemy"},
    {"gu": "sword_atk_1_06_gu", "target": "enemy"},
    {"gu": "sword_def_1_07_gu", "target": "self"}
  ],
  "rules": {"modifiers": [], "keep_across_turns": false},
  "reveals": false,
  "source": "inheritance"
}
```

- **兼容**：`steps` 缺失时回落到旧的 `recipe`（definition_id 数组，全部 `target: "enemy"`）
- `tag` 与流派标签对齐（可用于"剑道杀招"的获取筛选）

### 4.2 数据：玩家自建杀招（RunState 内）

```
RunState.kill_moves: Array[Dictionary]   # 与预制同构，source = "player"
```
- 随存档序列化（`SAVE_VERSION` 提升；旧档缺键按空数组迁移）
- **结局清空**（属 Run 内构筑）

### 4.3 模块划分

| 层 | 模块 | 职责 | 状态 |
|---|---|---|---|
| 域规则 | `scripts/domain/kill_move_rules.gd`（新，无 `class_name`，`extends RefCounted`） | 成本累加、steps 形状校验、保存/删除、失败传播判定、跨回合维持 | 新增 |
| 域结算 | `scripts/domain/v1_battle_resolver.gd` | `play_kill_move` 改为**按 steps 逐步调用单蛊结算**；`kill_move_reason` 增加 steps 版本 | 改 |
| 数据 | `data/v1_battle.json`、`data/refinement_recipes.json`（`kill_move_id`） | 预制内容 + 合成杀招 | 填 |
| 校验 | `content_catalog._validate_v1_kill_moves` | 扩展校验 steps / rules 白名单 / 引用存在性 | 改 |
| 快照 | `presentation/snapshots/battle_snapshot.gd` | `kill_moves` 增加 `steps`/成本明细/可释放性 | 改 |
| UI | `battle_screen_view.gd`（KillRow 已有）+ 编排保存入口 | 展示 + 保存按钮 | 改 |
| 命令面 | `battle_command_facade.gd` | 新增 `save_kill_move` / `rename_kill_move` / `delete_kill_move` | 改 |
| 存档 | `RunState` + `save_repository` | 序列化新字段 + 版本迁移 | 改 |

> 依赖方向仍为 表现层 → 领域层 → 数据层；新域模块由 resolver 单向 preload，公开 API 保留一行转发。

---

## 5. 实现步骤与技术难点

### 5.1 步骤（建议按此顺序，每步独立可验收）

1. **S1 内容先行（零引擎改动）**：填 3–5 个预制杀招（damage-only 1 个 + `strike` 1 个 + 3 步序列 1 个），
   验证"初始 4 只 starter 就能释放其中一个"。
2. **S2 成本累加修正**：`_build_kill_moves` 改为累加式 + `rules.modifiers` 白名单；
   旧字段保留兼容读取。
3. **S3 steps 结算**：`play_kill_move` 改为逐步执行（复用 `play_gu` 路径），失败传播按 §4.3；
   门禁 `kill_move_reason` 同步支持 steps。
4. **S4 保存自由编排**：`kill_move_rules` + `RunState.kill_moves` + 命令面 + UI 保存按钮 + 存档版本迁移。
5. **S5 获取渠道**：传承（`inheritances.json`）与商店（`shops.json`）各接一个杀招记录。
6. **S6 合成杀招切片**：把 `refinement_recipes` 的 `kill_move_id` 用起来（校验已存在，只需数据）。

### 5.2 技术难点

| # | 难点 | 风险 | 应对 |
|---|---|---|---|
| 1 | **"保存 ≠ 原子大招"** | 最易做错：一键释放时若包成不可中断的原子操作，直接违约 | S3 用**逐步调用单蛊结算**实现；测试锁"中途某步失败后，已完成步骤的效果仍保留" |
| 2 | **成本累加改变强度基线** | 旧数据用固定 cost，改累加后杀招会显著变贵/变便宜 | 数据为空 ⇒ 迁移面为零；新内容按累加设计；测试锁"无 modifiers 时成本 = Σ 步骤成本" |
| 3 | **确定性** | 杀招释放必须可复现、进事件日志 | 复用现有 SeededRoll 与 `_log(next, ...)`；测试锁同种子同结果 |
| 4 | **存档兼容** | `RunState` 加字段会让旧档失效 | 提升 `SAVE_VERSION` + 缺键按空数组迁移；不兼容时按既有策略拒绝进行中 Run |
| 5 | **念头预算冲突** | 跨回合维持编排占念头，与"念头约束战斗操作"重叠 | 维持占用走同一 `thought_cost` 账本，不新开计数器 |
| 6 | **合规** | 玩家杀招跨局会变成"局外战力" | 跨局只存"已掌握记录"（图鉴同构），Run 内清空；写入契约文档 |
| 7 | **契约同步** | 新增命令与快照键必须回写 | S4 同步 `docs/contracts/2026-09-02-domain-ui-contract.md` + `module-interfaces/01-battle-settlement.md` |

---

## 6. 落地计划

| 阶段 | 内容 | 主要文件 | 验收 |
|---|---|---|---|
| **P1** | S1 预制杀招内容（3–5 条） | `data/v1_battle.json` | 新增单测：starter 局内 `battle.kill_moves` 非空、可被 `kill_move_reason` 放行；战斗屏"未研习"空位被填充 |
| **P2** | S2 成本累加 + modifiers 白名单 | `v1_battle_resolver.gd`、`content_catalog.gd` | 单测：无 modifiers 时 `cost == Σ steps`；非法 modifier 被校验拒绝 |
| **P3** | S3 steps 逐步结算 + 失败传播 | `v1_battle_resolver.gd` | 单测：三步杀招中途失败 → 已完成步骤效果保留、依赖步停止、未执行步不扣费 |
| **P4** | S4 玩家保存编排（域+命令+UI+存档） | `kill_move_rules.gd`(新)、`RunState`、`battle_command_facade.gd`、`battle_screen_view.gd`、`save_repository.gd`、契约文档 | 单测 + 集成：保存 → 下一回合可释放 → 存档往返 → 结局清空 |
| **P5** | S5 获取渠道（传承/商店） | `inheritances.json`、`shops.json` | 单测：获取后进入 `battle.kill_moves`；图鉴只记"已掌握"不含战力 |
| **P6** | S6 合成杀招切片 | `refinement_recipes.json` | 现有切片校验转绿：配方产出杀招可在战斗中使用 |

**每阶段的通用门禁**：`tools/test.ps1 -Suite unit` + `-Suite integration` 全绿；
涉及 UI 的（P1/P4）追加 `tools/verify_interaction_loop.gd` 三键全空。

**建议起手**：**P1 → P2**（零风险、立刻让支柱有内容），验证"杀招好玩"之后再投入 P3/P4 的引擎与存档改动。

---

## 7. 与剑道的关系

- 剑道调研中提出的 P2 项（临时剑/穿透/回合末侵蚀）**可以借杀招承载**：
  一个三步剑道杀招（破甲 → 双锋 → 引爆剑意）比新增引擎 effect 更省成本，且直接服务"自由组装"支柱。
- 因此**本设计应优先于剑道专属内容**：杀招是跨流派的公共基座，剑道只是它的第一个受益者。
