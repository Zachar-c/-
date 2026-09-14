# Q8-G Reachability-8 / G1 K=2 Implementation Preflight（实现前预审）

> **批次**：`Reachability-8 / G1 K=2 Implementation Preflight`（§25 批准）
> **性质**：**仅准备**。**未施工**。本次**未修改任何生产代码/数据**。
> **禁止区（未触碰）**：`data/**`、`scripts/domain/**`、`RunState`、正式 pity / E6 / pacing / battle 规则。
> **未运行**：`M+G`、`M+T`、`M+G+T`、`A5 combined`。
> **本文件不构成施工许可**；施工前必须重做产品裁定 + Shared ownership 声明 + 受影响测试计划 + 独立验证 + 单独 commit。

---

## 0. 🔴 结论先行：存在两个必须先解决的阻塞项

§25 要求的 7 项交付物**已全部给出**，但在准备过程中发现**两个阻塞项**，
它们决定 G1 K=2 的语义**能否按测量口径实现**。**建议在解决它们之前不要进入施工。**

| 编号 | 阻塞项 | 性质 |
|---|---|---|
| **B1** | **「短局」population 的有效性未证实** —— 语料中的短局**全部自 L3/L4 起手**，且 13/14 含撤退 | 语料/测量有效性 |
| **B2** | **tier 的决策点（地图生成）拿不到「本局是否短」** —— 测量口径用了**事后**才知的最终战斗数 | 实现可行性 |

**B2 是纯技术阻塞**（决定了语义能否落地）；**B1 是证据阻塞**（决定了 §25 里的验收数值是否可信）。

---

## 1. 🔴 B2（技术阻塞）：tier 在地图生成时固定，而「短局」要到运行结束才知道

### 1.1 事实链（已读代码确认）

```text
① tier 来源 = 敌人定义，不是掉落决策
   LootResolver._enemy_tier(enemy_kind, catalog)
     → for enemy in catalog.enemies: return enemy.get("tier", "common")     [loot_resolver.gd:206-211]

② 敌人在「地图生成」时抽取（不是进入节点时）
   map_generator.gd:105  →  _roll_enemy_for(...)                            [map_generator.gd:299-320]

③ 抽取是纯函数，输入里没有任何运行进度
   EnemyCatalog.roll_enemy_ids(catalog, theme, rank_min, rank_max,
                               tier_weights, count, seed_value, salt, fallback_ids)
   → SeededRng(mixed_seed(seed_value, "enemy_roll:<node_id>", 0))          [enemy_catalog.gd:74-91]
```

⇒ **每个战斗节点的 tier 在「地图生成」时就已确定**，且抽取函数**只依赖 (seed, node_id)**，
**不接收 RunState、不知道已打了几场、也不知道这局会不会短**。

### 1.2 由此产生的矛盾

| 测量口径（R5–R7E） | 生产现实 |
|---|---|
| 「若**该局最终**战斗数 < 15，则保证 ≥2 个 Common」 | tier 在生成时定死，**最终战斗数此时未知** |
| 施加点是「该局」这一整体 | 施加点必须是**单个节点生成时** |

⇒ **测量口径的 guard 无法按字面实现。** 必须先选定一个**生成期可观测的替代量**（surrogate）。

### 1.3 候选替代量（**需产品/技术裁定，本预审不预设**）

| 方案 | 「短」的定义 | 生成期可知 | 风险 |
|---|---|---|---|
| **S1 路线战斗节点数** | 生成出的路线里 combat 节点数 < N | ✅ 是 | **不保证等价**于「实际战斗数 <15」（见 B1：实测短局由起手层与撤退共同决定） |
| **S2 已打过场次** | 进入该节点时已结算战斗数 < N | ✅ 是（若调用方传入） | tier 已在生成时定死，无法回改 ⇒ 需要**在生成阶段就注入进度**或**改为结算期重抽** |
| **S3 层 + 场次复合** | 如「L4 起手且场次 < N」 | ✅ 是 | 直接编码了 B1 的可疑特征，**不建议**在 B1 未澄清前采用 |
| **S4 结算期改判 tier** | 结算时按进度覆盖 loot tier | ✅ 是 | 会让「精英敌人掉落 common 表」，**语义割裂**，且违反 §25「必须是当前合法 Common 候选」的精神 |

**可行路径初判**：**S1 或 S2/S3 变体**，但**每一个都必须重新测量**（B1 未澄清前，
R7E 的 `9/32 局`、`−0.38 elite/局`、§25 的 `单局最多 2 场` **均不可直接沿用**）。

### 1.4 与 §25 验收边界的关系

§25 写下 `单局 Elite 最大损失不得超过 2 场` —— 该数值**直接来自 R7E 的测量**。
若替代量 S1 使受影响集合变化，**这条边界必须重新标定**。

---

## 2. 🔴 B1（证据阻塞）：「短局」population 不是随机样本

### 2.1 事实一：短局全部自 L3/L4 起手

扫描全部 32 局的**首个访问节点**与战斗数：

```text
run                first=       battles
force_606          L4R2N3            3
sword_606          L4R2N3            7
force_33           L4R3N1            8
sword_33           L4R3N1            8
sword_909          L4R2N2            8
force_1212         L3R3N1            9
force_909          L4R2N2            9
sword_11           L4R3N1            9
sword_1212         L3R3N1            9
------------------------------------------------  短局全部 ≤ L4 起手
force_11           L4R3N1           12
force_808          L4R4N0           12
sword_202          L1R0N0           12   ← 例外（长层起手但短）
sword_808          L4R4N0           12
sword_20260927     L1R3N3           13
------------------------------------------------
force_404          L2R3N3           15
force_303          L1R2N4           16
...
force_505          L1R0N0           19
...
sword_101          L1R0N0           24
```

**14 个短局中 12 个首个节点在 L3/L4**（例外仅 2 个：`sword_202` = L1R0N0 / 12 场，
`sword_20260927` = L1R3N3 / 13 场）；而 18 个长局绝大多数自 **L1R0N0** 起手。

⇒ **起手层与战斗数强相关**：L4 起手 → 3–12 场；L1R0 起手 → 19–24 场。
⇒ **「短局」集合主要由「从哪一层开始」决定，不是一次随机抽样。**

### 2.2 事实二：13/14 短局含撤退，撤退来自测试驱动策略

```text
驱动撤退条件（acceptance_driver.gd:3069,3073,3077）：
  hp <= 1  或  intent_damage >= hp  或  intent_damage*2 >= hp  或  stuck >= 6   → 撤退
  hp * 10 < max_hp * 6   （= 气血 < 60%）                                    → 撤退
注释原文：「仅测量口径」「驱动器不许替游戏"送死"污染生存数据」
```

- `retreat` 本身是**正式游戏命令**（`battle_command_facade.gd:24`，结局类型亦含 `retreat`）。
- 但**触发阈值是驱动策略**（`止损撤离` 仅出现在 `scripts/acceptance_driver.gd`，`scripts/domain/` 无）。
- 短局的撤退计数：`force_909`=6、`sword_202`=6、`sword_909`=4、其余多为 3。

### 2.3 尚未澄清的一点（**必须澄清，本预审无法定论**）

`force_606` 的日志显示**开局即 `起点=trailhead`，但第一个访问节点是 `L4R2N3`**，且**全程无 `行至被拒`**：

```text
[play] 开局 seed=606 | 起点=trailhead | 元石=12 | 气血=80/80 | 魂魄=1 | 契约=[]
[play] 行至 L4R2N3 (contact)：元石=12 气血=80
[play] 行至 L4R3N3 (combat)：元石=12 气血=80
...   （全程只有 L4R2..L4R7 六个节点，无 L1–L3 活动）
```

代码里 `reachable_nodes()` 在 `origin_id == "trailhead"` 时只返回 `start == true` 的节点，
而 `start` 只在 `_route_from_ids()` 中赋给 **route 的第 0 个元素**；同时 `node["layer"]` 来自节点的 `stage` 字段。

⇒ **未能解答**：这些 seed 的「route 首节点落在 L4」是**该 seed 的合法地图产出**，
还是**地图生成/驱动路径的退化或缺陷**？
（要定论需读地图产物或加埋点重跑，二者均超出 §25 允许范围。）

### 2.4 对结论的影响（诚实声明）

| 若 B1 的答案是… | 则… |
|---|---|
| **合法地图产出**（真有 L4 起手路线） | 语料可继续使用；但仍需回答 B2 的替代量问题 |
| **退化/缺陷** | **R7B–R7E 的全部数值需要在新语料上重测**；§25 的 `9/32`、`单局最多 2 场` 等验收线**作废重定** |

**在 B1 澄清前，本预审不背书任何「短局」数值作为生产验收线。**

---

## 3. 【§25-1】G1 K=2 正式语义草案（**条件稿**）

> **前置条件**：B1 + B2 解决后方可定稿。以下为**候选语义**，供讨论。

### 3.1 目标（§25 已裁定，直接采用）

```text
提高短局的 F1 opportunity 与 promotion 转化机会；
不承诺所有 Run 都完成 F1；
不承诺 Batch 1 Final Gate B/C 通过；
长局失败另由 M 轴单独处理。
```

### 3.2 语义候选（三选一，**待定**）

**候选 A —— 生成期路线级（推荐优先评估）**
```text
在地图生成时，若该局「路线内 combat 类节点总数」< T，则：
  对路线内的非锚点 combat 节点，保证至少 K 个节点的抽取结果 tier == "common"。
不变量：锚点/Boss 免抽（沿用现状）；抽取仍是 (seed, node_id) 的纯函数（可复现）；
        被提升的节点必须使用**当前合法的 common 候选**（同一 theme/rank 池内的 common-tagged 敌人）。
```
- 优点：**生成期完全可知**，无 RunState 依赖，确定性天然保持。
- 缺点：`T` 与实测 `<15 战斗` **不等价**，必须重测。

**候选 B —— 结算期进度级**
```text
进入战斗节点时，若「已结算战斗数」< T 且本局尚未触发过 K 次该补偿，
  则把本节点的 loot tier 由 elite 覆盖为 common。
```
- 优点：贴近实测口径（按已发生场次）。
- 缺点：**tier 已在生成时定死**，需要引入「结算期 tier 覆盖」新语义（敌人 tier 与 loot tier 解耦），
  与 `LootResolver._enemy_tier` 的现有单一来源冲突。

**候选 C —— 混合（暂不建议）**
在候选 A 之上叠加候选 B。**属于组合改动，须单独裁定**（§25 禁止未经批准的复合方案）。

### 3.3 无论选哪个，以下不变量必须成立

```text
① 锚点节点与 Boss 台不受影响（沿用 anchor 免抽现状）；
② 抽取仍是纯函数 ⇒ 同 seed / school / route 结果一致（确定性）；
③ 被提升的节点必须落在**已存在的**合法 candidate 内（不新增敌人定义、不改 enemies.json 的 tier）；
④ 不新增 pity 语义、不改 material_pity_by_tier；
⑤ 不引入 Soul / 商店 / 地图拓扑 / 第二成长线（§25 硬边界）。
```

---

## 4. 【§25-2】受影响文件清单（**只读勘察结果，未修改**）

| 文件 | 现状职责 | 若采用候选 A 需改动 | 若采用候选 B 需改动 |
|---|---|---|---|
| `scripts/domain/map_generator.gd` | `:105` 调 `_roll_enemy_for`；`:299-320` 组装 roll 入参 | ✅ **主改动点**（需知道路线 combat 节点总数 ⇒ 需两遍或先算后抽） | ⚠️ 抽取入参需带进度 |
| `scripts/domain/enemy_catalog.gd` | `:74-91` `roll_enemy_ids` 纯函数 | ⚠️ 可能需新增「保证 K 个 common」的后处理 | ⚠️ 同上 |
| `scripts/domain/loot_resolver.gd` | `:206-211` `_enemy_tier` 单一来源 | ❌ 不动 | ✅ **主改动点**（tier 覆盖） |
| `data/enemies.json` | 敌人 `tier` 字段 | ❌ **不动**（§25 明令） | ❌ 不动 |
| `data/pacing.json` | `enemy_weights` / 层 rank 区间 | ❌ **不动**（§25 明令） | ❌ 不动 |
| `scripts/domain/run_state.gd` | `RunState` | ❌ **大概率不动**（候选 A 无需新状态） | ⚠️ 可能需「本局补偿计数」字段 |
| `scripts/domain/content_catalog.gd` | 白名单校验 | ⚠️ 仅当新增数据键时（候选 A/B 均**不新增键** ⇒ 不动） | 同左 |

**结论**：**候选 A 的改动面最小**（集中 1–2 个文件，且不动 `RunState` / 存档 / 数据）。

---

## 5. 【§25-3】RunState / event / save 是否需要变化

### 5.1 候选 A（生成期路线级）

| 关注点 | 判断 | 理由 |
|---|---|---|
| `RunState` | **不需要** | 补偿在生成期一次性决定，无跨节点记忆 |
| 事件日志 | **不需要**（建议仅在开启审计开关时落只读观测） | 生成期不产生玩家可见状态变化 |
| 存档 | **不需要** | 敌人 `enemy_roll` 已随地图序列化；补偿结果自然随地图持久化 |
| `SAVE_VERSION` | **不抬** | 无新键、无格式变化 |
| 确定性 | **保持** | 仍是 `(seed, node_id)` 派生流；补偿判据是路线级纯函数 |

### 5.2 候选 B（结算期进度级）

| 关注点 | 判断 |
|---|---|
| `RunState` | **需要**（本局补偿计数，否则无法限制「最多 K 次」） |
| 事件日志 | **需要**（tier 被覆盖是状态变化，须落账） |
| 存档 | **需要**（计数须持久化） |
| `SAVE_VERSION` | **需评估是否抬**（新增键 ⇒ 按项目惯例走迁移判断） |

⇒ **候选 A 在「不动 RunState / 事件 / 存档」这一点上明显占优**，与 §25
「事件、存档、pity、RunState：若不改变则明确保持不变」的偏好一致。

---

## 6. 【§25-4】测试矩阵（草案）

| # | 层 | 用例 | 断言 |
|---|---|---|---|
| T1 | 单元 | `EnemyCatalog.roll_enemy_ids` 在同一 `(seed, node_id)` 下重复调用 | 结果**逐字节一致**（确定性） |
| T2 | 单元 | 候选 A 补偿后，被提升节点 | `tier == "common"` 且**属于该 theme/rank 池的既有 candidate** |
| T3 | 单元 | 锚点 / Boss 节点 | **永不参与补偿**（`anchor` 免抽不变） |
| T4 | 单元 | 路线 combat 节点数 ≥ T 的局 | **补偿不触发**（长局零影响） |
| T5 | 单元 | 补偿次数与目标 K | 恰好保证 ≥K 个 common（不超发） |
| T6 | 契约 | 地图产物 | 不新增数据键；`content_catalog.validate` 全绿 |
| T7 | 集成 | 32 局回归（或更大样本） | `f1zero` 修复以 **pooled+shrink 区间**报告；`shortZero` 相对基线显著下降 |
| T8 | 集成 | 长局子集 | **Elite / Gu / 材料件数不下降**（§25 硬边界） |
| T9 | 集成 | 全局 | **材料件数恒等守恒**（elite↔common 互换不改件数） |
| T10 | 集成 | 全局 | 单局 Elite 最大损失 ≤ **2 场**（**B1 澄清后需重新标定**） |
| T11 | 交互门 | `verify_interaction_loop.gd` | `dead=[] no_ui_click=[] occluded=[]` |
| T12 | 存档 | 存读往返 | 补偿结果随地图一致保留；`SAVE_VERSION` 行为符合第 5 节判断 |

---

## 7. 【§25-5】回归命令

```bash
# ① 全量单测（约 2 分钟，必须后台）
tools/test.ps1 -Suite unit
# ② 集成
tools/test.ps1 -Suite integration
# ③ 契约/静态检查
tools/check.ps1
# ④ 交互门
tools/godot.ps1 --headless --path . -s tools/verify_interaction_loop.gd

# ⑤ 32 局语料回归（重建语料；单局约 8.5 秒 ⇒ 全量约 4.5 分钟）
GODOT="<godot console exe>"
for school in force sword; do for seed in 20260927 11 33 55 101 202 303 404 \
        505 606 707 808 909 1111 1212 1313; do
  PLAYTHROUGH_FULL=1 PLAYTHROUGH_COMBAT_FIRST=1 PLAYTHROUGH_SCHOOL=$school \
  PLAYTHROUGH_SEED=$seed PLAYTHROUGH_F1_OPPORTUNITY_PITY= PLAYTHROUGH_E6_TIER_AUDIT=1 \
  "$GODOT" --headless --path . -s scripts/acceptance_driver.gd -- --mode=play
done; done

# ⑥ 报告层区间化复核（自动适配语料规模）
node tools/q8g_reachability7e_boundary_spec.mjs
```

> ⚠️ **已知工具缺陷**：`q8g_reachability5_tier_audit.ps1` 经 `godot.ps1 -Console` 时 `$LASTEXITCODE` 为空 ⇒ 误报失败。
> **必须用上面的「直调 Godot 二进制」写法**（已验证）。
> 语料默认落 `<TEMP>/gu-zhenrens-r5-logs/`（**会被系统清理**）；耐久副本
> `C:/Users/90877/gu-zhenrens-r5-logs-archive/`，工具支持 `Q8G_R5_LOG_DIR` 覆盖。

---

## 8. 【§25-6】回滚条件

| 触发 | 动作 |
|---|---|
| 确定性测试 T1 失败（同 seed 结果漂移） | **立即回滚**该改动；这是纯函数被污染 |
| 长局 Elite / Gu / 材料件数出现任何下降（T8） | **立即回滚**；违反 §25 硬边界 |
| 材料件数非恒等（T9） | **立即回滚** |
| 锚点 / Boss 被补偿（T3） | **立即回滚** |
| 单局 Elite 损失 > 2 场（T10） | 停止并回到裁定（**B1 澄清后重新标定**） |
| `tools/check.ps1` 或契约校验失败（T6） | **立即回滚** |
| 存档往返不一致（T12） | 回滚；若已抬 `SAVE_VERSION` 则同时回滚版本号 |

**回滚纪律（沿用仓库既有约束）**：
```text
禁 git reset --hard / git checkout -- . / 递归删除
改动必须**单独 commit** ⇒ 回滚 = revert 该 commit（不触碰其它工作）
改本地分支指针只用 git update-ref refs/heads/<b> <new> <old>（CAS）
```

---

## 9. 【§25-7】Shared Ownership 声明草案

> 依 `docs/contracts/2026-09-12-agent-ownership-contract.md` 的 5 步协议。
> **本预审仅申报，不执行。**

```text
声明文件（候选 A）：
  scripts/domain/map_generator.gd      ← Shared 单写者区
  （可能）scripts/domain/enemy_catalog.gd

变更原因：
  为短局保证至少 K 个 combat 节点的敌人为 common tier，
  以提高短局 F1 opportunity 与 promotion 转化机会（§25 裁定二）。

影响面：
  地图生成期的敌人抽取结果；
  不涉及 RunState / 存档 / 事件 / UI 契约 / 数据文件。
  长局、锚点、Boss 不受影响。

指定测试：
  T1–T6（单元/契约）+ T7–T10（集成）+ T11（交互门）+ T12（存档）

提交：
  **单独 commit**，与 Reachability 工具/文档分离。
  提交信息须含：批次名、§25 裁定引用、受影响文件、验证命令与结果。

验证要求：
  施工前必须重做产品裁定 + 独立验证（§25 明文）。
  **B1 澄清前不得进入施工。**
```

**未在本次申报**：`data/**`、`RunState`、pity / E6 / pacing / battle 规则（§25 明令不得修改）。

---

## 10. 建议的下一步（按优先级）

1. **澄清 B1**：这些 seed 的「路线首节点落在 L3/L4」是合法地图产出还是退化？
   —— 需要读地图产物或加只读埋点重跑（**均需你批准，因为超出 §25 的 7 项允许范围**）。
2. **裁定 B2 的替代量**：S1（路线战斗节点数）/ S2（已打过场次）/ S3（复合）三选一。
3. **在解决 1+2 后用新语料重测**，重新标定 §25 的 `9/32`、`单局最多 2 场` 等验收线。
4. 上述完成后，再定稿第 3 节的语义并进入正式施工流程。

---

## 11. 交付物与冻结状态

| 文件 | 性质 |
|---|---|
| `docs/q8g/Q8G_REACHABILITY8_IMPL_PREFLIGHT.md` | 本文件 |

**本次未新增工具、未修改任何生产代码/数据。**
冻结区在工作树中**存在既有未提交改动**（ZCode 的 R5/R6 审计仪器），**非本次产物，亦未被本次触碰**。

---

**记录时间**：2026-09-13
**裁定状态**：**G1 K=2 条件接受（§25）；A 仍 CONDITIONAL；B/C/D 不批准；生产规则冻结；A5 未批准**
**施工状态**：**未批准施工。B1 + B2 为施工前置。**
