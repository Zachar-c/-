# 层性向（layer temperament）设计预审 —— 层节点构成按种子抖动

> 状态：**设计预审，不构成施工许可**。本轮不修改任何 `data/` 与 `scripts/` 生产文件。
> 日期：2026-09-16 · 议题来源：用户「强化本游戏的肉鸽元素」→ 选定「层节点构成抖动」。
> 作者：Agent（预审）· 待产品裁定后进入施工。

---

## 0. 一句话

让每一局的「战斗密度」不再是一个常数：开局按种子抽一个**全局地脉倾向**（run temper），
再为每层叠加一个**层微扰**（layer temper），二者以零和方式在 battle 与 unknown/trade 之间转移权重。
聚合期望基本不动，但**整局战斗占比的标准差从 0.032 提升到 ≥0.050**，「凶险局 / 富饶局」才真实存在。

---

## 1. 现状基线（实测，非推断）

数据源：`tools/verify_pacing_density.gd`（E5a 门禁）在 **40 个种子**上的原始输出，
留档 `tools/_baseline_e5a_40seeds.txt`；解析产物 `tools/_measure_out.md`
（`tools/measure_category_variance.py`，已在基线上正确报 **M2 FAIL**，非空转）。
复现命令见 §7.4。

### 1.1 每层随机槽 battle 占比

| 层 | 均值 | 标准差 σ | 最小 | 最大 | 极差 |
|---|---|---|---|---|---|
| L1 | 0.571 | 0.074 | 0.438 | 0.732 | 0.294 |
| L2 | 0.594 | 0.059 | 0.483 | 0.733 | 0.251 |
| L3 | 0.576 | 0.076 | 0.429 | 0.725 | 0.296 |
| L4 | 0.558 | 0.071 | 0.360 | 0.700 | 0.340 |
| L5 | 0.553 | 0.078 | 0.357 | 0.689 | 0.332 |
| **合并** | **0.570** | **0.073** | — | — | 0.376 |

### 1.2 整局 battle 占比（这才是玩家的体感口径）

- n=40，均值 **0.577**，σ **0.032**，范围 0.512–0.658，极差 0.146
- 单局越界（出 [0.50,0.60]）的种子：**8 / 40**
- E5a 聚合判定：`AGG battle_share=0.578 [ok]`，退出码 0

### 1.3 三个诊断结论

**(a) 层内有方差，整局没有。** 单层 σ≈0.073，整局 σ 只有 0.032 —— 5 层独立抽样把方差平均掉了
（≈σ/√5）。这正是「每局都差不多」的数学根源。
⇒ **推论：只做「每层独立抖动」无效**，它同样会被 √5 平均掉。抖动必须带 **run 级相关分量**，
让五层同向偏移，才能传导到整局体感。这是本设计的核心决策。

**(b) 当前均值贴着门禁上界。** 聚合 0.577，离上界 0.60 只有 0.023，离下界 0.50 有 0.077。
这是一个**既存的脆弱点**：任何增加方差的改动都会先撞上界。
⇒ 本设计顺带把聚合均值**重定位到带心 ≈0.55**，换取双向抖动空间（见 §3.4 期望配平）。

**(c) rest 权重是个假旋钮。** `category_weights.rest` 恒为 6，但实测 rest 密度主要由
`MapGenerator.REST_ROW_STRIDE = 2` 的结构性锚点决定（`_anchor_rows` 每两行强制插入
`rest_hollow`/`rest_shrine`，且这些锚点**不经过** category_weights）。
⇒ **rest 不参与抖动**：它基数太小（6），任何显著抖动都会撞地板并被钳制，只会制造噪声。

---

## 2. 设计

### 2.1 数据 schema（`data/pacing.json`，顶层新增）

```json
"category_weight_jitter": {
  "enabled": true,
  "battle_delta_min": -12,
  "battle_delta_max": 4,
  "donor_categories": ["unknown", "trade"],
  "donor_floors": { "unknown": 6, "trade": 2 }
}
```

- 缺省 / `enabled: false` / 两档 delta 全 0 ⇒ **行为与今天逐位一致**（兼容回退）。
- `content_catalog` 需新增校验：两档为整数且 `min <= max`；`donor_categories` 非空且不含
  `battle`；`donor_floors` 覆盖每个 donor 且 > 0。

### 2.2 零和转移规则（每层调用一次）

设本层基础权重 `w_battle / w_unknown / w_trade`（rest 不参与，保持原值），总和 `S`：

1. 抽 `delta = run_delta + layer_delta`，其中
   - `run_delta` ~ U[min, max]，**全局同一局只抽一次**（五层共用）
   - `layer_delta` ~ U[min, max] **的缩幅版本**（建议 `layer_jitter_ratio = 0.5`），每层独立
2. `battle' = w_battle + delta`
3. donor 按各自基础权重**比例**吸收 `−delta`：`w_i' = w_i − delta * (w_i / W_donor)`，`W_donor = Σ w_i`
4. 钳制：`w_i' = max(w_i', floor_i)`；钳制产生的残差 `residual` 从 `battle'` 扣回，
   **保证 `S` 守恒** —— 这样 `_pick_category_template` 里的 `total` 稳定，抖动幅度可预测
5. `rest' = w_rest`（不动）

> 为什么「比例吸收」而不是「均分」：donor 里 unknown(9) 与 trade(4) 基数差 2 倍以上，
> 均分会先把 trade 打穿到地板。比例吸收让两者同比例缩放，钳制触发率最低。

### 2.3 抽取必须用**独立派生流**（硬约束）

沿用 E6 的既有先例（`map_generator.gd:100-107` 注释：加入该功能不改变既有种子产出）：

```gdscript
SeededRng.new(SeededRollScript.mixed_seed(seed_value, "run_temper", 0))
SeededRng.new(SeededRollScript.mixed_seed(seed_value, "layer_temper_L%d" % layer_number, 0))
```

⚠️ **禁止把 `layer_number` 放进 `tick` 参数**。`seeded_roll.gd:43-45` 明确记录：
`mixed_seed(seed, salt, tick)` 的 tick 是**仿射**混入（相邻 tick 的中间状态恒差常数
`97 * 48271 mod M`），连续 tick 的抽取会退化。层号必须进 **salt**，tick 恒为 0
（与 `_node_rng` 现有写法一致）。

因为不消耗 `_generate_instance_route` 的共享 `rng`，且 `_pick_category_template` 每次
仍只调用一次 `rng.next_index(total)`（调用次数与权重取值无关），所以：

> **主 rng 流的消耗序列完全不变** ⇒ 行数、每行节点数、入口数、锚点行位、行进边、
> 关底 Boss —— **逐位不变**。变化的只有「非锚点随机槽填了哪个模板」。
> （total 变了 ⇒ 槽内容会变；这是本改动唯一的有意影响面。）

### 2.4 不破坏 `_pick_category_template` 的签名（硬约束）

`tests/unit/test_category_route.gd:63` **直接静态调用**：

```gdscript
MapGenerator._pick_category_template(rng, pacing["layers"]["1"], pools, node_by_id, 1, [], [], used)
```

该函数**没有 seed 参数**。因此：

- ❌ 禁止让 `_pick_category_template` 自己去算抖动（会编译失败）
- ✅ 由 `_generate_instance_route` 在 layer 循环内预先算好抖动后的权重，
  合成 `eff_cfg = cfg.duplicate(true); eff_cfg["category_weights"] = <jittered>`，
  再把 `eff_cfg` 传给 `_pick_category_template`

该单测传入的是原始 `pacing["layers"]["1"]`（无 jitter 键 → 走原路径），
**行为与签名均不变**。

### 2.5 可观测出口（新增纯函数，不影响现有路径）

```gdscript
static func layer_category_weights(seed_value: int, layer_number: int,
        pacing: Dictionary = {}) -> Dictionary
```

返回抖动后的四分类权重。用途：验证工具断言、后续地图屏展示「本层地脉」。
本轮**不接 UI**。

---

## 3. 参数校准（施工时用测量搜索，不手工拍）

### 3.1 搜索目标（同时满足）

| # | 指标 | 门槛 |
|---|---|---|
| M1 | 40 种子聚合整局 battle share | ∈ [0.54, 0.58]（带心，双向留白） |
| M2 | 40 种子整局 battle share **σ** | ≥ 0.050（基线 0.032） |
| M3 | 每层四分类齐全 | 10 种子 × 5 层全过 |
| M4 | 31 个池模板覆盖 | seed 1..10 全覆盖 |
| M5 | 拓扑冻结 | 与基线快照逐位相等 |

### 3.2 搜索方法

在 `(battle_delta_min, battle_delta_max)` 上做网格搜索（步长 2，范围 [−20, +8]）。

⚠️ **必须用「与参数无关的稳定均匀数」**（seed 1..40 固定集），
**不要把种子本身混进搜索目标** —— 否则指标随参数非单调，配对对比失效
（Reachability 轨道 R7 教训，见 `.workbuddy/memory/MEMORY.md` §五）。

### 3.3 期望配平（M1 的关键）

`delta` 取 U[min,max] 对称区间时 E[δ] = (min+max)/2。
§1.3(b) 要求均值从 0.577 下移到 ≈0.55，故取 **非对称区间**（如 [−12, +4]，E[δ]=−4）。
配平后若 M1 不过，**优先调区间端点，不要调 floors**。

### 3.4 预估（待实测确认，禁止当结论用）

- run 级 σ_δ ≈ (max−min)/√12 ≈ 4.6（区间宽 16）→ 整局 share σ 增量 ≈ 0.046
- 叠加基线 0.032 ⇒ 合成 σ ≈ √(0.032² + 0.046²) ≈ **0.056**
- 层微扰（ratio 0.5）贡献 ≈ 0.023/√5 ≈ 0.010 ⇒ 总 σ ≈ **0.057**

---

## 4. 红线冲突（**需产品显式裁定覆盖**）

| 冲突项 | 出处 | 说明 |
|---|---|---|
| **「不改 pacing」** | Reachability 轨道红线（`.workbuddy/memory/MEMORY.md` §五） | 本改动直接写 `data/pacing.json`。该红线的立意是「不污染 f1 可达性语料的 population」，而本改动**恰恰会改变每局战斗节点数分布**。 |
| **f1 语料 population 失效** | 同上 | 改动后，既有 32 局语料与 R7B–R7E 全部效应量结论**再次作废**。 |

**请求裁定**：确认「强化肉鸽」优先级高于「保持 f1 语料 population 稳定」，
并批准在改动落地后**重建语料再评估**（不复用旧语料做任何对比）。

**不冲突的确认项**：本改动**不触碰** enemies tier、地图拓扑/连边/锚点、正式 pity、
战斗元石、Elite cost、promotion、E6/E7 —— 保持 Reachability 其余红线。

---

## 5. Shared ownership 声明（按 `docs/contracts/2026-09-12-agent-ownership-contract.md` 5 步协议）

**1) 声明文件**

| 文件 | 是否 Shared 单写者区 | 改动性质 |
|---|---|---|
| `data/pacing.json` | 否（data 层） | 顶层新增 `category_weight_jitter` |
| `scripts/domain/map_generator.gd` | 否 | 新增 2 个静态函数 + layer 循环内 3 行注入 |
| `scripts/domain/content_catalog.gd` | 否（但为全局校验器，爆炸半径大） | 新增 jitter 段校验 |
| `docs/contracts/2026-09-02-domain-ui-contract.md` | **是（Shared）** | 仅当 UI 暴露层性向时才动；**本轮不动** |

**2) 原因**：`category_weights` 每层写死，五层独立抽样导致整局方差被 √5 平均掉（§1.3a），
每局体感同质；这是「肉鸽感」最主要的量化缺口。

**3) 影响面**：所有 `MapGenerator.build` 的非锚点随机槽内容。
拓扑/连边/锚点/Boss 逐位不变（§2.3）。

**4) 指定测试**：见 §6。

**5) Commit**：单独一个 commit，标题 `feat(map): per-run layer temperament for category weights`，
**不与剑道 T16、美术素材等其它在途改动混合**。

### 5.1 正向证据：进行中存档不受影响

`save_repository.gd:68` 把 **整张 `route` 序列化进存档**（`"route": route.duplicate(true)`），
读档时直接反序列化，不重新生成。
⇒ **改动不会让老存档的地图错位**。这是本设计最大的一块兼容性风险，已排除。
（对照：`run_state.gd` 只存 `route_progress`，不存 route。）

---

## 6. 受影响测试清单

`MapGenerator.build` 的调用方共 10 个测试文件：
`test_category_route` · `test_map_generator` · `test_map_catalog_config` ·
`test_map_anchor_guards` · `test_map_network` · `test_runtime_seed_policy` ·
`test_save_import_export` · `test_save_repository` · `test_t5d_debug_panel` · `test_v3_ui_sync`

### 6.1 已逐条判定（直接契约）

| 测试 | 判定 | 依据 |
|---|---|---|
| `test_category_pick_weights_match` | **不受影响** | 直传原始 `pacing["layers"]["1"]`，签名与行为均不变（§2.4） |
| `test_combat_share_within_50_60_percent` | **需实测** | seed 1..20 聚合，σ_agg ≈ 0.057/√20 ≈ 0.013；均值须落在带心 |
| `test_every_layer_has_all_four_categories` | **需实测** | 依赖 `slots_so_far >= 5` 保底；donor floor > 0 保证强制补类可触发 |
| `test_category_pool_templates_are_reachable_some_seed` | **需实测** | donor 权重被压低时，冷门模板（如 `herbalist_commission`）可能掉出 seed 1..10 |
| `test_same_seed_same_category_route` | 不受影响 | 派生流为纯函数 |

### 6.2 施工前必做基线

其余 9 个文件**未逐条精读**。施工前必须在 worktree 上跑一次
`tools/test.ps1 -Suite unit` 取全绿基线，改动后**逐项 diff 失败清单**，
区分「存量失败 vs 新增失败」（`.workbuddy/memory/MEMORY.md` §三）。

⚠️ 判据不要只看 GUT 汇总行 —— `.gutconfig.json` 把 engine 类错误排除在 Failing 之外，
必须同时看 `SCRIPT ERROR` 计数 / `Orphans` / 退出期 ObjectDB 泄漏
（`.workbuddy/memory/MEMORY.md` §二）。

---

## 7. 独立验证方案

### 7.1 施工前：冻结拓扑基线

新增 `tools/verify_map_topology_frozen.gd`：对 seed 1..40 导出
`(node_id, layer, row, template_id 的 anchor/start 位, next_ids)` 到 JSON。
**在改动前的 HEAD 上先跑一次**，产物作为 `docs/` 证据文件留档。

### 7.2 施工后：三重比对

1. **拓扑冻结**：重跑 7.1，与基线 JSON 逐字节比对 ⇒ 断言 M5（证明主 rng 流未被消耗）
2. **方差提升**：`tools/verify_pacing_density.gd` → `tools/measure_category_variance.py`
   解析 ⇒ 断言 M1 / M2
3. **门禁**：`tools/verify_pacing_density.gd`（E5a，rc=0）+
   `tools/verify_route_diversity.gd`（E5b，rc=0）

### 7.3 反空转 canary（**强制**）

参照 `.workbuddy/memory/MEMORY.md` §二⑦的教训（`agent3_pck_audit.gd` 曾恒报 PASS
却只扫了 34 字节）：

- 7.1 的导出**必须断言 `node_count > 0` 且覆盖 40 个 seed**，否则 FAIL
- 反向对照：把 `battle_delta_min/max` 临时设成 `0/0`，M2（σ ≥ 0.050）**必须 FAIL**；
  恢复后必须 PASS。两个方向都验过才算工具可信。

### 7.4 复现命令

```powershell
$g = "C:\Users\90877\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
cd C:\Users\90877\work_space\gu-zhenrens-pigeon-meat
& $g --headless --path . --import          # 必做：导入缓存陈旧会导致编译期失败
& $g --headless --path . -s tools/verify_pacing_density.gd
& $g --headless --path . -s tools/verify_route_diversity.gd
```

⚠️ `tools/*.ps1` 在本 agent 沙箱不可用（子进程 stdout 不转发），
**必须直连 Godot 二进制**，不要用 `tools/test.ps1` 判成败。

---

## 8. 风险与回滚

| 风险 | 等级 | 处置 |
|---|---|---|
| 聚合 share 出带（撞 0.60 上界） | 中 | 网格搜索端点；已通过「重定位到 0.55」预留双向空间 |
| 冷门模板掉出 seed 1..10 | 中 | 抬 donor floor；必要时把个别模板加入层 `pool` 直选 |
| donor 钳制吃掉抖动幅度，M2 不达 | 中 | 降 `battle_delta` 绝对值；或让 `rest` 也按比例参与 donor（需重估 §1.3c） |
| 与剑道 T16 / 在途改动冲突 | 中 | 独立 worktree + 单独 commit |
| f1 语料作废 | **高（已裁定则接受）** | 见 §4；改动后重建语料 |

**回滚**：删除 `pacing.json` 顶层 `category_weight_jitter` 即回到今日行为
（`enabled` 缺省路径已按「逐位一致」设计）。单点开关，无需回滚代码。

---

## 附录 A：肉鸽元素诊断快照（2026-09-16 只读体检）

| 项 | 实测 | 判读 |
|---|---|---|
| 节点模板 | 37（combat 10 / hazard 3 / inheritance 3 / earth_vein 3 / 其余 18 类） | 够用 |
| 敌人 | 32（common 13 / elite 12 / boss 7） | 够用 |
| 合成配方 | 468 | 构筑空间充足 |
| **events.json** | **2 条** | **严重不足** |
| **关底 Boss** | 5 席硬编码，7 个 boss 中 `clan_patriarch`、`blue_fur_jiangshi` **从未上场** | **零随机** |
| category_weights | 每层写死（battle 74→82，rest 恒 6） | 本议题 |
| 层数量 / 行结构 | 恒 5 层，行 8–11 × 宽 2–6 | 有随机，保持 |
| 每局真随机项 | 行数 / 行宽 / 连边 / 分类抽取 / E6 敌人 / E7 商店库存 | 已有基础 |

**每局恒定项**：层数量、category_weights、anchors 模板与行位、rest 模板交替顺序、
关底 Boss 身份、石预算、loot 权重、shop_price_pct。

---

## 9. 本轮未做（后续候选）

- **UI 暴露**：地图屏显示本层地脉倾向（「瘴气郁结 · 凶」/「山货丰饶」）——
  抖动若不可见，感知增益打折。需改 `docs/contracts/2026-09-02-domain-ui-contract.md`（Shared）。
- **Boss 随机化**：7 个 boss 有 2 个从未上场（`clan_patriarch`、`blue_fur_jiangshi`），
  5 个关底台 `enemy_kind` 硬编码且 `instance_anchor` 为真会跳过 E6 ⇒ 每局 Boss 完全相同。
  感知最强、独立性强，建议作为下一个改动。
- **事件池扩容**：`data/events.json` 仅 2 条。
- **层异变词缀**：需领域层新增 modifier 通路，工程量最大。
