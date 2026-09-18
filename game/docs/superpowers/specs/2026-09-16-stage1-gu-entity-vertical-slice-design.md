# Stage 1 纵向切片设计：蛊虫实体与构筑（2026-09-16）

> **权威依据**：`docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md` §7 阶段 1。
> **前置**：Stage 0 Gate = **GO**（`docs/lore/generated/world-model-stage0-gate.md`，24/24 完整 P0 引用）。
> **本文件性质**：设计稿 + 切片边界。
> **实施状态（2026-09-16 晚）**：**数据完备化 + 场景探针已落地**——5 只补显式 effect/feeding
> （`tests/unit/test_stage1_gu_entity_slice.gd`）+ `tools/verify_stage1_slice.gd`（Gate A–F，165 项 PASS，
> 固定 seed=101）+ `tests/unit/test_stage1_slice_scene_gates.gd`（5/5）。
> 身份夹具落在**探针级**（未接生产开局），**生产零 diff**；暴露 5 条缺口待裁定
> （详见 `docs/superpowers/reports/2026-09-16-stage1-slice-probe.md` §3）：
> ① L1 不出货郎节点 ② 无「未炼化 → 已炼化」命令 ③ 盲炼失败无世界内原因文案
> ④ 货郎货架不含血滴蛊 ⑤ 货郎 `purchase_moonlight` 为 tier 3（L1 被 `shop_tier_locked` 拒）。
> **出口**：切片剧本探针通过前，禁止扩大生产蛊目录、流派数或敌人池。

---

## 0. 一句话

用 **12 只已入目录的蛊 + 1 个身份背景 + 1 条短路线 + 3 个敌人 + 1 个炼蛊场景 + 1 个 NPC**，
把「蛊是独立生命实体」从裁定表落到可玩、可测、可验收的最小竖条；证明清理 `role` 兜底后游戏仍能开局、战斗、炼蛊、走到节点终局。

---

## 1. 切片边界

### 1.1 In scope

| 维度 | 本切片 |
|---|---|
| 蛊 | **12 只**，全部已有 id（不新造蛊）；每只补全「显式效果 / 食性 / 来源 / 运作 / 处置」 |
| 身份 | **1 个**：南疆边地散修（非 20 流派职业包） |
| 地图 | **1 条**短路线：L1 内 8–12 节点量级的验收剧本（可用现有 generator 种子钉死） |
| 敌人 | **3 个**：`ridge_hound` / `mountain_boar` / `straw_puppet`（皆 rank ≤1，已入池） |
| 炼蛊 | **1 个场景**：月光 → 月芒/月辉 固定方 + 一次盲炼失败样例 |
| NPC | **1 个**：山脚货郎（交易 + 一句人情，不接全势力系统） |
| 契约 | 领域-UI 新键若产生，必须回写契约；本切片尽量 **零新命令面** |

### 1.2 Out of scope（明确不做）

- 扩大 `gu.json` 总量、20 流派选择语义重做、D5 杀招自由组装
- 元海/真元双轨合并（阶段 2）
- 战斗距离/速度/准备窗口（阶段 3）
- promotion/material 体系存废（阶段 4）
- 势力追杀链、地图「地理化」（阶段 5）
- 图鉴/轮回边界重做（阶段 6）
- 任何「看起来像原著」但 **无 Stage 0 证据 ID** 的新规则

### 1.3 Non-regression 硬门

- 切片外 802 蛊目录 **不得删减**；只允许对 **切片内 12 只** 提升数据完备度，以及对 **生产禁用路径** 做「未切片蛊不进本验收剧本」的约束。
- 旧 Run 存档：本切片 **不迁移**；若实例字段语义变更，读档缺键走默认，禁止静默改写旧档语义。
- 全量 unit / integration / 交互门保持绿；新增切片场景探针必须可 headless 复现。

---

## 2. 身份背景（非职业流派）

| 项 | 设计 |
|---|---|
| 名称 | **南疆边地散修**（内部 id 建议 `background_nanjiang_wanderer`） |
| 世界句 | 你不是「选了血道/力道」，而是：猎户之子，幼时误吞/偶得 **月光蛊** 认主，从此靠山货、人情和一两条野路子蛊活命。 |
| 开局持有 | `moonlight_gu`（本命候选，已炼化）+ `small_light_gu` ×2（未炼化，可喂可炼可丢） |
| 不给 | 任意流派 starter 四件套、核心蛊槽、跨局战力 |
| 道标签 | 开放集；本剧本实际接触 `light` / `force` / `blood`，**不注册新 school 枚举** |
| 与现有 UI | 择道屏本切片剧本 **跳过或只读展示倾向**；命令面仍走现有 `select_school` 兼容（若必须开局），但语义文案改为「出身倾向」——实现批次再定，本稿不锁死 |

**依据（Baseline）**：`gu_is_life` retain · `gu_is_independent_entity` retain · `natal_gu` **remove**（禁止任意后置核心槽）· 宪章 §5.3/§5.4。

---

## 3. 蛊池（12 只，全部现有 id）

完备度定义（切片内每只必须同时满足）：

1. **显式 `v1_effect`**（禁止静默走 `default_effect_by_role`）
2. **`feeding_need` / `feeding_cost`** 非空（世界内食性，不是统一 feed_points 口号——字段可沿用，但须有食性文案/来源）
3. **来源**：开局认主 / 路线拾取 / 炼成 / 货郎 —— 四者之一，写入切片剧本
4. **运作**：战斗内如何被催动（成本、条件、支援）
5. **处置**：可丢弃 / 可炼入 / 死亡后果；禁止「无来源永久能力」

### 3.1 名单

| id | 转 | 道 | 角色 | 本切片角色 | 数据缺口（相对完备度） |
|---|---|---|---|---|---|
| `moonlight_gu` | 1 | light | attack | **本命候选**，开局已炼化 | 已有 strike3 + 食性；补「来源/本命叙事」与死亡预检文案 |
| `small_light_gu` | 1 | light | attack | 开局未炼化×2；炼成原料 | 已有 strike1+support；补未炼化态展示 |
| `moon_glow_gu` | 2 | light | attack | 固定方产物 | 已有 strike4；配方 `moon_glow_fixed` |
| `moon_ray_gu` | 2 | light | attack | 固定方产物 | **缺显式 effect** → 补 strike（拟 amount 3–4，见 §3.2） |
| `moon_shadow_gu` | 3 | light | movement | 后期可选，本剧本可不出 | **缺显式 effect**；若进剧本须补 shift |
| `force_gu` | 1 | force | attack | 拾取/货郎 | 已有 strike2+食性 |
| `bear_strength_gu` | 1 | force | healing | 拾取 | **缺显式 effect** → 补 heal |
| `blood_droplet_gu` | 1 | blood | attack | 敌人掉落样例 | 已有 strike2+食性 |
| `blood_farewell_gu` | 1 | blood | attack | 高风险高回报样例 | 已有条件 strike；**执行前预检**已有红线要求 |
| `blood_def_1_21_gu` | 1 | blood | defense | 防御样例 | **缺显式 effect** → 补 shield |
| `blood_mov_1_22_gu` | 1 | blood | movement | 位移样例 | **缺显式 effect** → 补 shift |
| `sword_atk_1_05_gu` | 1 | sword | attack | 证明「剑道蛊可被散修偶然获得」 | 已有显式；**食性缺失** → 补 feeding |

> 选择原则：优先 **已有显式效果或配方链已通** 的蛊，把「补洞」控制在 5–6 只，而不是重写 802。

### 3.2 拟补显式效果（数据，待批准后改 `data/gu.json`）

| id | 拟 `v1_effect` | 理由 |
|---|---|---|
| `moon_ray_gu` | `{kind:"strike", amount:4}` | 与 moon_glow 同档；月系远程 |
| `bear_strength_gu` | `{kind:"heal", amount:2}` | 与 healing role 兜底一致，抬成显式 |
| `blood_def_1_21_gu` | `{kind:"shield", amount:3}` | 与 defense 兜底一致 |
| `blood_mov_1_22_gu` | `{kind:"shift", amount:1}` | 与 movement 兜底一致 |

**禁止**：用兜底「碰巧等于」冒充已完备；切片验收脚本必须断言这 12 只 **均有** `v1_effect`。

### 3.3 食性叙事（不改结算公式，补世界语义）

- 光系：月露/夜气（低频、便宜）
- 力系：兽肉/山果
- 血系：精血（与 `life_cost` / 气血预检同源叙事，**不在本切片加新扣血通道**）
- 剑系：剑油/磨石或「以战养锋」——仅文案与 feeding 字段，不接 T16 之外新残锋

字段可继续用现有 `feeding_need.feed_points` / `feeding_cost`，切片只保证 **非空 + 可展示**；统一食性模型归阶段 4。

---

## 4. 一条路线剧本（验收用，非新地图系统）

用现有 `MapGenerator` + **固定 seed** 钉出一条可复现短路径；脚本断言拓扑与节点类型，不手搓第二套地图。

| 步 | 节点 | 本切片要证明的事 |
|---|---|---|
| 1 | 开局/休整 | 身份句 + 月光蛊已炼化 + 两只小光蛊未炼化可见 |
| 2 | 战斗 `ridge_hound` | 显式效果结算；未炼化蛊不能当已炼化催动 |
| 3 | 探索/拾取 | 获得 `force_gu`（来源事件日志） |
| 4 | 战斗 `mountain_boar` | 喂养压力首次可见（食性/喂养点） |
| 5 | 炼蛊场景 | `moonlight + small_light×2 → moon_glow` 固定方；失败路径一次（输入消亡有日志） |
| 6 | 货郎 NPC | 元石买 `blood_droplet_gu` 或卖山货；**价格与可负担性预览**（已有 refine/shop 成本红线） |
| 7 | 战斗 `straw_puppet` | 防御/位移蛊显式效果 |
| 8 | 节点终局/离开 | 事件日志可归因；无软锁；无隐藏成本 |

敌人只用 §1.1 三只；**不抽 E6 全池**。

---

## 5. 炼蛊场景

| 项 | 内容 |
|---|---|
| 知识 | 固定方 `moon_glow_fixed`：`moonlight_gu + small_light_gu + small_light_gu → moon_glow_gu`（`default_unlocked`） |
| 盲炼样例 | 一次自由混合：输入真实、结果失败或低价值产物；**失败必须有世界内原因文案**（「火候/相性/心神」） |
| 预览 | 卡片必须显示输入、成功率/固定、元石与材料、失败是否毁输入（已有 `_append_recipe_card` 红线） |
| 禁止 | 本切片不改 468 配方全局成功率，不引入 promotion |

---

## 6. NPC：山脚货郎

| 项 | 内容 |
|---|---|
| 立场 | 中立小贩，非势力代表 |
| 交互 | 买 `blood_droplet_gu`（元石）、卖山货（材料）、一句「下次带蛇胆给你让价」——**人情只记事件日志，不建关系账系统** |
| 禁止 | 单次成功/失败不假装有长期追杀；长期后果归阶段 5 |

---

## 7. Baseline claim → 切片动作映射

| Claim | 裁定 | 本切片动作 |
|---|---|---|
| `gu_is_life` | retain | 月光蛊本命叙事；死亡/丢弃有后果预检 |
| `gu_is_independent_entity` | retain | 实例级炼化/喂养/持有；禁止「目录条目=玩家能力」 |
| `gu_feeding` | revise | 12 只食性字段非空 + 展示；不扩统一 feed 模型 |
| `gu_recipe` | retain | 固定方知识默认解锁可见；来源可追溯 |
| `gu_refinement` | revise | 固定方 vs 盲炼分流；失败有原因 |
| `gu_activation` | retain | 显式 effect + 真元/念头成本；role 兜底不进切片验收 |
| `primeval_essence` | revise | **只审计不合并**；切片仍用现役 essence/true_qi |
| `rank_and_subrank` | retain | 1–3 转门禁与 amount 不新造倍率 |
| `dao_marks` | **remove** | 凡人通用道痕进度条 **不进本切片**；剑道 T16 残锋保持现状、不扩 |
| `natal_gu` | **remove** | 无任意核心蛊槽；月光是「已发生炼化」不是「玩家点选天赋位」 |
| `lifespan` | revise | 血 farewell 类若触寿元必须预检（现红线） |
| `world_scope_and_compression` | retain | 剧本不宣称五层=真实地理 |

---

## 8. 验收标准

### 8.1 功能

1. 固定 seed 剧本 headless 跑通：开局 → 3 战 → 炼蛊 → 货郎 → 离开/终局。
2. 12 只切片蛊在 catalog 校验与切片探针中均有 `v1_effect`；无一只依赖 role 兜底。
3. 未炼化 `small_light_gu` 不能被当作已炼化催动（或现有规则下行为有明确测试）。
4. 月光固定方成功路径 + 一次失败路径均有不可变事件日志。
5. 货郎交易预览成本与结算一致（无隐藏元石）。
6. 新开一局仍可走 **全量 802 目录** 的既有模式；切片剧本只是验收夹具，不是删目录。

### 8.2 Non-regression

- `tools/test.ps1 -Suite unit` / integration 全绿  
- 剑道 T15/T16、残锋确认、D1/D4/D7 门禁不回退  
- 契约：若新增快照键 → 回写 `docs/contracts/2026-09-02-domain-ui-contract.md`  
- 交互门：无新死按钮/遮挡  

### 8.3 代表性场景探针（建议实现物）

- `tools/verify_stage1_slice.gd` 或 `tests/integration/test_stage1_gu_entity_slice.gd`  
- 断言：剧本拓扑、12 蛊完备度、炼成日志、交易成本、终局可达  

---

## 9. 批准后实施顺序（另开 implementation plan）

1. 冻结本切片名单与 seed（数据 PR 只动切片 12 只字段）  
2. 补 `v1_effect` / feeding / 显示文案（DisplayText）  
3. 身份背景与开局注入（最小：剧本夹具；完整择道改造可后置）  
4. 切片探针 + 契约回写  
5. Non-regression 全绿后 **再** 讨论是否扩大  

---

## 10. 风险

| 风险 | 应对 |
|---|---|
| 身份与现有 `select_school` 冲突 | 切片先用夹具注入，不拆 20 流派命令面 |
| 补 effect 改变既有平衡 | 只改「原先走兜底」的 4–5 只，amount 对齐兜底公式 |
| 被误读成「可以扩目录」 | 文首出口条款 + AGENTS 同步：切片通过前不扩池 |
| Stage 0 裁定 confidence=unknown | 本切片动作全部落在「审计后允许的最小完备化」，不发明新世界规则 |

---

## 11. 请求裁定

请用户批准或改写：

1. **切片名单**是否就用上表 12 只（可增删，建议 ≤16）  
2. **身份**是否采用「南疆边地散修 + 月光本命候选」  
3. **实施批次**是否同意「先夹具剧本、后拆流派择道」  
4. 批准前 **零生产 diff**；批准后另开 implementation plan 并走 Shared 五步（若碰契约）  
