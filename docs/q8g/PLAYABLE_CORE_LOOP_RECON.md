# Playable Core Loop Vertical Slice — Phase 0 侦察记录

> 任务：`Q8-Playable-Core-Loop-Vertical-Slice`
> 时间：2026-09-15；基线 HEAD `7e6ac907`
> 性质：本文件只记录侦察事实与最小改动范围，不含实现。

---

## 1. 当前已有字段（快照层）

### Map（`map_snapshot.gd`）

```text
nodes[]: {id, type, label, layer, row, next_ids, reachable, visited, current, visibility, revealed}
current_node_id, reachable_ids[]
gu_satchel[]: {id, name}
inventory: {materials[{id,name,quantity}], gu_instances[{id,definition_id,name,state,...}]}
zone_title, depth_label, realm_label, toast
resources, contracts[], anomalies[], death_lines, leave_confirm
```

### Reward（`reward_snapshot.gd`）

```text
title, rewards[]: {name, kind, quality, effect, cost, curse_warning?}
full_satchel, pity_note, pool_fallback_note
（+ RunSnapshotBuilder._gui_state 的通用块）
```

### Refine（`refine_snapshot.gd`）

```text
title, channels[4]（fixed/combine/free_pair/blind）
recipes[]: {id, channel, name, output, rank_note, quality, fail_chance, backlash, curse, unlocked}
pair_candidates / pair_main / pair_partner / pair_preview
slot_ok, blind_note, dismantle_slots[], streak_note
from_rest, initial_channel
```

## 2. 当前缺失字段

```text
Map     缺「当前构筑目标」块（build_goal）；节点检视只有 type/label/描述，缺「与目标关系」
Reward  缺「本场推进了什么」；缺 promotion 可执行性变化；缺「下一步去哪」
Refine  缺每配方 owned/required 材料、元石 owned/required、输入蛊是否持有、缺失项明细
        （玩家点击后才第一次看到成本——Phase 4 明确禁止）
        配方无排序（按 refinement_by_id 字典序），build_goal 对应配方不置顶
        promotion 未与 combine/advance 区分（kind=="promotion" 落进 channel="fixed"）
```

## 3. 当前已有命令（闭环所需命令**全部已存在**）

```text
travel{node_id}                     地图选路
（战斗）submit_command → BattleCommandFacade.apply_turn
refine_gu{recipe_id, input_instance_ids?}   炼蛊/合成/promotion 统一入口
rest{mode,...}                      休整
```

`refine_gu` 已完整支持 `kind == "promotion"`（`refine_command_rules.gd:262 _apply_promotion_recipe`）：

```text
门禁顺序：配方存在 → recipe_unlocked → 元石 → 输入实例定位 → 容量 → 缺料
        → 输入 rank >= input_min_rank → 输入 rank < 5
扣费：_spend_materials 扣材料；_add_gu_transaction 扣元石 + 消费输入实例 + 产出 output_gu_id
事件：promotion_succeeded（带 recipe:<id> 标签）
拒绝码：unknown_refinement_recipe / refinement_recipe_locked / insufficient_stone /
        missing_refinement_input / refinement_capacity_exceeded /
        missing_refinement_material / refinement_input_rank_insufficient / promotion_capped
输入选择：ShopRules.selected_input_instance_ids(state, command, inputs)
        —— command 可带 input_instance_ids[]；缺省取第一个匹配 definition 的 refined 实例
```

## 4. 当前缺失路由

```text
无缺失路由。
闭环所需的地图选路、战斗、战利品确认、炼蛊执行全部已有命令与屏面。
本任务的缺口是「信息投影」而非「命令面」——玩家看不懂产出与目标的关系。
```

## 5. 关键可达性事实（决定切片能否在 20–40 分钟内闭合）

### 5.1 promotion 链已就绪且成本很低

```text
refinement_recipes.json：468 条 = advance 377 / promotion 76 / fixed 14 / free_mix 1
promotion 76 条全部 default_unlocked = true

force 链（4 步）：
  promote_force_atk_1_05_to_force_atk_2_06   in=force_atk_1_05_gu  rank=1  mats={mat_force_1:1}  stone=10
  promote_force_atk_2_06_to_force_atk_3_07   in=force_atk_2_06_gu  rank=2  mats={mat_force_2:1}  stone=18
  promote_force_atk_3_07_to_force_atk_4_08   in=force_atk_3_07_gu  rank=3  mats={mat_force_3:1}  stone=30
  promote_force_atk_4_08_to_force_atk_5_23   in=force_atk_4_08_gu  rank=4  mats={mat_force_4:1}  stone=45

sword 链（4 步）：
  promote_sword_def_1_07_to_sword_atk_2_20   in=sword_def_1_07_gu  rank=1  mats={mat_sword_1:1} stone=6
  promote_sword_atk_2_20_to_sword_mov_3_22   in=sword_atk_2_20_gu  rank=2  mats={mat_sword_2:1} stone=8
  promote_sword_mov_3_22_to_sword_atk_4_01   in=sword_mov_3_22_gu  rank=3  mats={mat_sword_3:1} stone=12
  promote_sword_atk_4_01_to_sword_atk_5_02   in=sword_atk_4_01_gu  rank=4  mats={mat_sword_4:1} stone=18
```

### 5.2 开局**已持有** rank-1 promotion 的输入蛊

```text
data/schools.json
  force.starter_gu_ids = [force_gu, bear_strength_gu, white_boar_strength_gu, force_atk_1_05_gu]
  sword.starter_gu_ids = [sword_atk_1_05_gu, sword_heal_1_09_gu, sword_def_1_07_gu, sword_mov_1_08_gu]
```

⇒ 切片缺的只有 **1 份 crude 材料 + 6~10 元石**，不需要任何跨系统改造。

### 5.3 材料与元石的可达性（引用 Agent-1 POST 基线）

```text
每场 Common 胜利落 2–4 件材料，其中本流派 crude（f1）每抽命中率 19.0%
每场 Common 胜利至少掉 1 件 f1 的概率 ≈ 40.6%（实测 63/155）
战斗产石：loot.stone_reward（balance.battle_stone_rewards，按 tier+layer）
```

⇒ 数场战斗即可凑齐「1 份 crude + 6~10 元石」，20–40 分钟切片成立。

## 6. 预计最小改动范围

| # | 文件 | 改动 | 类型 |
|---|---|---|---|
| 1 | `scripts/presentation/snapshots/build_goal_projection.gd` | **新增**：build_goal 纯函数投影 + 节点相关性派生 | 新增（非 Shared） |
| 2 | `scripts/presentation/snapshots/map_snapshot.gd` | +`build_goal`、每节点 +`build_relevance` | **Shared** |
| 3 | `scripts/presentation/snapshots/reward_snapshot.gd` | +`build_progress` | **Shared** |
| 4 | `scripts/presentation/snapshots/refine_snapshot.gd` | 每配方 +成本/缺失/可执行 + 按目标排序 +`build_goal` | **Shared** |
| 5 | `scripts/presentation/screens/map_screen_view.gd` + `scenes/ui/screens/map_screen.tscn` | 渲染构筑目标区 + 检视器相关性 | Presentation |
| 6 | `scripts/presentation/screens/reward_screen_view.gd` + tscn | 渲染构筑进度块 | Presentation |
| 7 | `scripts/presentation/screens/refine_screen_view.gd` + tscn | 渲染成本/缺失 + 目标置顶 | Presentation |
| 8 | `docs/contracts/2026-09-02-domain-ui-contract.md` | 新增键登记 | **Shared 契约** |
| 9 | `docs/contracts/2026-09-02-page-inventory-requirements.md` | 逐屏需求更新 | **Shared 契约** |
| 10 | `tests/unit/test_build_goal_projection.gd`（新） | 纯函数目标选择 + 投影契约 | 测试 |
| 11 | `tests/unit/test_core_loop_snapshots.gd`（新） | 三屏新键契约 + 与库存一致 | 测试 |
| 12 | `tools/verify_core_loop.gd`（新） | 真实两轮闭环 driver（Gate A–F） | 验收 |

**不触碰**：`scripts/domain/**`、`data/**`、`RunState`、`save_repository.gd`、`resolver.gd`、
`loot_resolver.gd`、promotion 成本、battle 数值、E6、pacing、敌人 tier、正式 pity、
M/G/T 经济规则、`project.godot`。

## 7. 设计约束确认

```text
build_goal 是「构筑目标」，不是 raw pity counter —— 不显示任何保底计数
不新增第二条成长线（目标只投影现有 promotion / 炼蛊配方）
不在 UI 内复制领域判断（可执行性统一来自 refine_command_rules 的同源门禁）
不伪造掉落（节点相关性只说「可能推进 / 可执行 / 无直接关系」）
不泄露隐藏信息（未知节点仍按 revealed 遮蔽，相关性文案不得反推节点内容）
```

## 8. 已知既有观察（不在本任务范围，仅登记）

```text
reward_snapshot.pity_note 当前直接展示 loot_pity / material_pity_by_tier 内部计数。
任务书只要求 build_goal 不显示保底计数，未要求移除既有 pity_note。
本任务不修改它；若要改，属独立裁定。
```

---

## 9. Shared 文件 Ownership 5 步声明（`2026-09-12-agent-ownership-contract.md` §3）

任务书已预先授权下列 Shared 文件（= §4「Astra 升级触发」由任务书本身满足），
现按 §3 补齐 5 步声明。**声明落档后开始施工。**

### 步骤 1：声明文件（完整路径）

```text
scripts/presentation/snapshots/map_snapshot.gd
scripts/presentation/snapshots/reward_snapshot.gd
scripts/presentation/snapshots/refine_snapshot.gd
docs/contracts/2026-09-02-domain-ui-contract.md
docs/contracts/2026-09-02-page-inventory-requirements.md
```

新增（非 Shared，但归快照区）：`scripts/presentation/snapshots/build_goal_projection.gd`

### 步骤 2：原因（对应已批准任务）

```text
Q8-Playable-Core-Loop-Vertical-Slice（用户 2026-09-15 任务书）。
Phase 1–4 明确要求在三屏新增「构筑目标 / 进度 / 成本」只读投影，
并同步回写两份契约文档。
```

### 步骤 3：预期影响面

```text
受影响屏：Map / Reward / Refine（仅新增只读键，不删改既有键）
受影响命令：无（命令面零变更；refine_gu 等既有命令原样复用）
受影响快照消费者：map_screen_view.gd / reward_screen_view.gd / refine_screen_view.gd
受影响测试：tests/unit/test_snapshot_contract.gd（键白名单可能需登记新键）、
            tests/unit/test_snapshot_transparency_v2.gd、新增两个单测
受影响验收：tools/verify_interaction_loop.gd（三屏交互门）、tools/verify_map_v1_render.gd、
            tools/verify_reward_v1_render.gd、tools/verify_refine_v1_render.gd
向后兼容：新键为「新增」而非「替换」，旧存档与既有测试不应因缺键而崩；
          消费侧一律用 get() 兜底空值。
```

### 步骤 4：提交前指定测试

```text
聚焦：node tools/q8g_agent1_post_fix_baseline.mjs（无关，仅基线核对）
      新增 tests/unit/test_build_goal_projection.gd
      新增 tests/unit/test_core_loop_snapshots.gd
      既有 tests/unit/test_snapshot_contract.gd
全量：godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2
      godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2
交互门：godot --headless --path . -s tools/verify_interaction_loop.gd
闭环：godot --headless --path . -s tools/verify_core_loop.gd
```

### 步骤 5：单独 commit

```text
Commit A：快照/契约/测试（本任务 Shared 批次，单独提交）
Commit B：Map/Reward/Refine presentation（屏面 + tscn）
Commit C：playthrough driver + 报告
（沿用任务书建议的三段拆分；不与其他任务混提）
```
