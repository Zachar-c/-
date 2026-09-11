# 剑道流派完整度审计与收口（2026-09-12）

> **任务**：把剑道完善到可正常使用的完整状态，逐一核对该流派关联的全部任务单，
> 说明完成情况与仍需跟进的问题。
> **审计依据**：落地任务书 `plans/2026-09-11-sword-school-landing-plan.md`、
> 设计 `specs/2026-09-11-sword-school-design.md`、数值表 `specs/2026-09-11-sword-gu-table.md`、
> 杀招矩阵 `specs/2026-09-11-sword-kill-move-list.md`、整合框架 `specs/2026-09-11-sword-cosmology-integration.md`、
> 重查报告 `reports/2026-09-11-sword-recheck.md`。
> **代码基线**：`b5d1857`（剑道批次 1/2/2b 重建提交）。

---

## 0. 结论速览

| 维度 | 状态 |
|---|---|
| **可正常使用** | ✅ **是**。剑道已跑通完整流程至结局（`ascension_window`，2/3 seed 到达；见 §6） |
| 任务单完成度 | 落地任务书 T1–T14 ✅（T12 已裁定删除）；T15/T16 属批次 3，任务书明定「不实施，需单独规格」 |
| 设计文档 P0/P1 | P0-1…P0-4 ✅、P1-1…P1-3 ✅ |
| 设计文档 P2 | P2-1…P2-3 ⬜ 未实施（任务书明定 P2 需试玩验证后另开规格） |
| 数据完备 | 40 只蛊（与其余 19 流派等量）、4 starter、`school_pools` 全 40、杀招 22 条、advance 升阶链覆盖剑道蛊 |
| 本次新增 | 端到端覆盖扩到剑道（此前 6 流派里没有剑道）+ 修掉驱动把休整节点误判为软锁的缺陷 |
| 仍需跟进 | 见 §7（P2 三项、剑意未接线、`bound` 死数据、`sword_mark_cost` 占位、传承 P5、refine 卡成本隐藏） |

---

## 1. 落地任务书 T1–T16 逐项核对

| # | 任务 | 完成判定 | 状态 | 证据 |
|---|---|---|---|---|
| **T1** | 剑道「式」数值表（40 只） | 表内 40 行齐全，`amount = base + rank - 1` | ✅ | `specs/2026-09-11-sword-gu-table.md`（40 行 + 3 决策点裁定） |
| **T2** | attack 15 只显式 `v1_effect` | 15 只含显式效果，`support_bonus` 按式分档 | ✅ | `data/gu.json`：strike 15（4 只带 `support_bonus:1`） |
| **T3** | defense 5 + healing 5 显式化 | 10 只合法、行为保持 | ✅ | `data/gu.json`：shield 5 / heal 5 |
| **T4** | movement 5 显式化 | `shift` 不随转数放大 | ✅ | `data/gu.json`：shift 5，全部 `amount:1` |
| **T5** | recon 5 + logistics 5 定位裁定 | 三选一并记录理由 | ✅ | 裁定 D3：recon 保留 `marked`（情报语义）、logistics 暂不动标 P2；批次 1 零改动。⚠️ 遗留见 §7-③ |
| **T6** | 侵蚀代价（按 D1-A 改写） | 成本可见、无静默致死 | ✅ | `thought_cost:2` 于藏锋蛊/剑匕蛊；**未用 `life_cost`**（残锋≠自伤，遵守横幅裁定） |
| **T7** | 剑道契约测试 | 用例全绿 | ✅ | `tests/unit/test_sword_school_gu.gd` **16/16 绿（465 断言）** |
| **T8** | `school_rules` 跨回合剑意 | 单测：叠层/上限 5/衰减取整/不串味 | ✅ | `school_rules.gd:24-43`（`sword_intent`/`add_sword_intent`/`decay_sword_intent`）。⚠️ 契约桩未接线，见 §7-② |
| **T9** | 剑道杀招 +2 条 | 配方可达、过校验 | ✅ | 已被 v2 矩阵取代并扩充为 22 条（T14） |
| **T10** | 剑道道痕登记（体印→图谱转义） | 复用容器、事件日志、`mark_layers` 可读 | ✅ | `social_command_rules.gd`（`mark_sword`）、`school_rules.gd:46-83`、`display_text.gd` |
| **T11** | 兼修代价 `cross_school_penalty` | 单道无罚/混 2 道起罚/剑水互斥 | ✅ | `school_rules.gd:85-117`、`data/balance.json`（`school_exclusions` 等 3 键 + 形状守卫） |
| ~~T12~~ | ~~剑意与道痕分层~~ | — | ❌ 已删 | 重查报告：建立在无原文依据的「剑意核心」上 |
| **T13** | 元石→真元 | 不超 `essence_max`、元石不为负 | ✅ | `essence_capacity.gd`（`stone_to_essence`）、`balance.json`（`stone_to_essence_per_stone`） |
| **T14** | 剑道杀招 6 线×转数矩阵 + `reveals` | 矩阵完整 + Σ 规则 + 转数门禁 + 吃支援 + 泄密记录 | ✅ | `data/v1_battle.json` **22 条** `km_sword_<line>_<n>`；`v1_battle_resolver.gd`（tag 作流派吃 `turn_supports`；用后 `reveals=true` + `battle.revealed_to`） |
| **T15** | 刻痕通道（回合末结算 + 死亡预检） | — | ⬜ **P2 未实施** | 任务书 §1 批次 3 明定「本任务书不实施，需单独规格」 |
| **T16** | 残锋降转（蛊实例道痕余量） | — | ⬜ **P2 未实施** | 同上 |

**批次结论**：批次 1（T1–T7）✅、批次 2（T8/T9）✅、批次 2b（T10/T11/T13/T14）✅、批次 3（T15/T16）按任务书**冻结**。

---

## 2. 设计文档 P0/P1/P2 清单核对

| # | 动作 | 验收 | 状态 | 证据 |
|---|---|---|---|---|
| P0-1 | attack 蛊补显式 `v1_effect` | 契约测试 | ✅ | `test_sword_school_gu.gd` 用例 1/2 |
| P0-2 | starter 4 只差异化 | 新局 starter 行为可区分 | ✅ | `schools.json` starter 不变；`gu.json` 起势 4 只带 `support_bonus` |
| P0-3 | 侵蚀用现成字段（抬 `thought_cost`） | 价格可见 | ✅ | 2 只高阶起势 `thought_cost:2`（按 D1-A 不用 `life_cost`） |
| P0-4 | 回合内剑意上限与 `end_turn` 清零 | 引擎测试绿 | ✅ | 用例 3/4（支援链 + 反序无加成 + `end_turn` 清零） |
| P1-1 | `sword_intent` 跨回合层数 | 单测：叠层/上限/衰减 | ✅ | 同 T8 |
| P1-2 | `kill_moves` 填充剑道配方 | 战斗内可用、配方可校验 | ✅ | 22 条（远超「至少 3 个」） |
| P1-3 | 剑道蛊「式」化：**40 只至少 6 种可区分行为** | 40 只 ≥ 6 种行为 | ✅ | 实测 **7 种**：`strike`／`strike+support_bonus`／`shield`／`heal`／`shift`／`status:marked`／`status:bound`（后两者来自 `default_effect_by_role` 兜底） |
| P2-1 | 剑气：生成临时剑蛊 | — | ⬜ 未实施（需新 effect kind + 快照键） |
| P2-2 | 破锋 `pierce` | — | ⬜ 未实施 |
| P2-3 | 侵蚀回合末结算 | — | ⬜ 未实施（= T15） |

---

## 3. 机制 A–D 状态（含重查后的重定义）

| 机制 | 设计原意 | 重查后 | 现状 |
|---|---|---|---|
| **A 剑意 Intent** | 剑道核心乘数 | ❌ **降级**：「剑意」原文仅 4 次且无层数规则；剑道优势是**用法** | `sword_intent` 保留为契约桩（T8 判定达标），**未接线**（§7-②） |
| **B 剑气 Blade Qi** | 多段 | ✅ 多段改用杀招 `steps`（P3）承载，不新增 effect | 本批以 Σ 聚合落库（22 条）；`steps` 逐步结算归 P3 |
| **C 侵蚀 Erosion** | 施术者自伤代价 | ❌ **方向纠正**：侵蚀是**对目标及其蛊虫**的持续破坏；剑道代价是**残锋** | 代价侧由 `thought_cost` 承担（P0-3）；残锋 = T16（P2） |
| **D 破锋 Pierce** | 对防御的破局 | 维持 | ⬜ P2-2 未实施 |

---

## 4. 数据完备性核对

| 项 | 结果 |
|---|---|
| 剑道蛊总数 | **40**（与其余 19 流派等量；human 42） |
| role 分布 | attack 15 / defense 5 / healing 5 / movement 5 / recon 5 / logistics 5 |
| rank 分布 | 1 转 11 / 2 转 9 / 3 转 8 / 4 转 5 / 5 转 7 |
| 稀有度分层 | r1–r2 `common`（20）／r3 `rare`（8）／r4–r5 `epic`（12）——与掉落分层吻合 |
| 显式 `v1_effect` | 30 只（attack/defense/healing/movement）；recon/logistics 10 只走兜底（合法，D3 裁定） |
| starter | 4 只（攻/防/疗/移，均 1 转）——`schools.json` 已登记 |
| `school_pools["sword"]` | **全 40 只**；`loot_resolver._pick_from_bucket` 优先取本流派蛊 ⇒ 剑道蛊在剑道局**可稳定获取** |
| 杀招 | **22 条 / 6 条线**（双锋引、剑气冲霄、剑影万千、剑痕索命、五指拳心剑、万剑劫）；id 方案 `km_sword_<line>_<n>` |
| 杀招配方约束 | 全部为剑道蛊；转数门槛 = 配方最高转数（脚本自检 + 契约测试钉死） |
| 炼蛊升阶链 | `refinement_recipes` 含剑道蛊 advance 配方（如 `advance_sword_atk_1_05_gu`）⇒ 同名升阶成长路径存在 |
| 装备/遗物/契约 | 遗物、契约、传承为**全流派通用**（无 `school` 字段），剑道无需专属条目；「装备」= 蛊装配（`equipped_gu_ids`），通用 |

---

## 5. 本次补齐

1. **端到端覆盖扩到剑道**（此前 6 个流派里没有剑道——剑道从未跑过完整流程）：
   - `tests/integration/test_five_schools_smoke.gd`：`SCHOOLS` 加入 `sword`（starter 注入 / 战斗 / 掉落 / 死亡终结 / 新局重注入 + 专属池唯一性）。**2/2 绿**。
   - `scripts/acceptance_driver.gd`：`PLAYTHROUGH_SCHOOL` 不再白名单 5 个流派，改为**凡 `schools.json` 登记的流派都可驱动**。
2. **修掉驱动把休整节点误判为软锁**（`_step_via_cards`）：
   - 旧行为：第一张卡被拒即 `break` → 落到 `leave_node` → 被 `rest_choice_required` 拦 → 打印「软锁」并终止冒烟。`refinement`/`cultivation` 节点在元石不足时**必现**。
   - 新行为：被拒继续试下一张；全部失败时按领域全集兜底提交 `{"type":"rest","mode":"skip"}`（与 `rest_snapshot` 的「放弃收益并离开」等价，落 `rest_skipped`）。
   - 说明：**游戏侧 skip 通路本来就是完整的**（`rest_rules._rest_skip` + `rest_snapshot` 的 skip 卡），这是**驱动缺陷**，不是软锁。

---

## 6. 端到端验收证据（剑道）

### 6.1 全流程回归门（GUT，`tests/integration/test_drive_to_ending.gd::test_sword_school_drives_to_ending_or_terminal`）

**3/3 通过**，且三个 seed 全部打满 5 层、5 个 Boss 并进入结局：

| seed | 结果 | 层 | 进入结局 | 战斗数 | Boss 数 |
|---|---|---|---|---|---|
| 20260927 | `ending` | 5 | ✅ | 30 | 5 |
| 101 | `ending` | 5 | ✅ | 23 | 5 |
| 777 | `ending` | 5 | ✅ | 25 | 5 |

断言覆盖：不得 `no_route` / `leave_blocked` / `steps_cap`，且必须抵达 Ending 或确定性终局。

### 6.2 无头驱动实测（`PLAYTHROUGH_SCHOOL=sword`，真实开局路径）

| seed | 结局 | 步数 | 终局 | 事件数 |
|---|---|---|---|---|
| 20260927 | `ending` | 339 | `ascension_window` | 609 |
| 101 | `ending` | 99 | `ascension_window` | 168 |
| 777 | terminal | 41 | L1R10N0（战死） | 89 |

### 6.3 覆盖边界（诚实说明）

上述驱动/回归门证明**剑道局能开局、能推进、能打 Boss、能结算结局**，并覆盖 starter 注入、
掉落、死亡终结、新局重注入；但驱动的战斗策略以基础攻击为主，**不证明剑道蛊与杀招在实战中被使用**。
后者的覆盖来自 `test_sword_school_gu.gd`（支援链、反序、成本预检、22 条杀招的 Σ/门禁/泄密）
与 `test_kill_move_content.gd`（杀招可见性与释放结算）。

---

## 7. 仍需跟进的问题

| # | 问题 | 性质 | 建议 |
|---|---|---|---|
| ① | **T15 刻痕通道 / T16 残锋** 未实施 | 任务书**明定冻结**（P2，需单独规格；且要求先试玩验证 P0/P1） | 需用户裁定解禁；T15 必带死亡预检 |
| ② | **`sword_intent`（T8）未接线**：全仓无调用点，局内「势」不存在 | 契约桩（T8 自身判定已达标）；且重查已把「剑意」从核心降级 | 若要接线，需先论证「势」是否值得做（重查报告要求「另行论证」） |
| ③ | **logistics 5 只 `status:"bound"` 无读取点**（5/40 = 12.5% 效果为死数据） | T5 裁定 D3「暂不动，标 P2」；整合框架新依据倾向「做成结构差异」 | 与 T15/T16 一并设计（需引擎侧读取点） |
| ④ | **`sword_mark_cost` 预留标记 4 只未被读取** | D1-A 有意预留，结算归 T16 | 随 T16 落地 |
| ⑤ | **剑道传承（薄青一脉）未立项** | 整合框架 §5 建议挂人物级传承（P5），任务书未列 | 若要「获取路径完整」，可另立 P5 任务 |
| ⑥ | **refine 卡隐藏关键成本**（通用缺陷，非剑道专属）：`advance` 配方卡 `cost` 不含 `stone_cost`、`executable` 不看元石/材料是否够 → 玩家看到「可执行」的卡，点了才被告知「元石不足/缺材料」 | 违反红线「禁止隐藏关键成本」；`action_preview_service._append_recipe_card` | 按 AGENTS「不擅自修无关既有问题」**仅登记**。修法：`cost` 带上 `stone`+`materials`，`executable` 并入可负担性判定与 `block_reason` |
| ⑦ | ~~缺专用「剑道 → 结局」回归测试~~ **本轮已补**：`test_drive_to_ending.gd::test_sword_school_drives_to_ending_or_terminal`（3 seed，3/3 绿） | 已关闭 | — |
| ⑧ | **`.git` 被外部进程删除**（`refs/remotes/origin/` 在 fetch 后消失；原始事故同源） | 环境层风险 | 未修；**不排查则仓库随时可能再丢一次** |

---

## 8. 平衡小结

- **规模**：剑道 40 只蛊，与其余 19 流派等量（human 42）——无规模失衡。
- **数值**：attack `amount = 2 + (rank-1)`、defense `3 + (rank-1)`、healing `2 + (rank-1)`、movement 固定 1——与兜底公式逐只一致（T2–T4 是**行为保持**改动，红线 11）。
- **剑道独占增益**：仅 ①起势 4 只 `support_bonus:1`（本回合后续同流派 +1）②高阶起势 `thought_cost:2`（代价侧）③`sword_mark_cost` 占位（未生效）。
- **天然限流**：念头每回合上限 2（魂魄底蕴 1 档）⇒ 一回合至多 2 个动作，支援叠层无法无限堆；`end_turn` 清零 `turn_supports` ⇒ 支援不跨回合。
- **杀招成本**：2 蛊 → 真 3/念 1；3 蛊 → 真 4–5/念 2；5 蛊（五指拳心剑）→ 真 7/念 2。五转杀招真元 5–7，三转战斗真元上限 120（60×2），**不构成资源墙**。
- **杀招条数**：sword 22 / light 2 / blood 1 / force 1 —— 剑道作为**试点流派**刻意领先（任务书 §2「剑道是试点，跑通后再复用同一套流程」），非失衡。
- **无跨流派克制倍率**（规格 §2.3）：剑道差异化全部落在己方资源循环与结算方式上 ✅。
