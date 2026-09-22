# 力量体系偏移审计 · KEEP / DEMOTE / CONFLICT / MISSING

> 依据：L0 2026-09-21 纠偏令 + `ORIGINAL_POWER_SYSTEM_AXIOMS.md`
> 范围：balance.js · priceGu · Effect Budget · PP · kitDpr · 当前 MVP 蛊定义 · 杀招相关 · 修为相关
> **本轮只识别问题。禁止因 MISSING 开发完整系统。**

| 资产 | 判定 | 处置 |
| --- | --- | --- |
| `js/balance.js` 整体身份 | **DEMOTE** | 降为**数值工程校验工具**。不再是「P3 Effect 定价参考实现」。文件头已改。 |
| `LAB_BUDGET_PROJECTION = 20` | **KEEP** | 仅作 WORLD→LAB 投影备忘；不是 Effect→amount 最终换算。 |
| `PP` 权重（1 / 1.2 / 1.5 / …） | **DEMOTE** | `LAB_PRICING_V1` 检测用相对尺；**不是**「1 suppress 客观 = 2.5 伤」。禁止升格全仓。 |
| `costTax` | **DEMOTE** | 同上，报警用；与 `light_cost_ratio` 职责分离。 |
| `priceGu()` | **DEMOTE** | **禁止**回答「这只蛊值多少 / 是否该选 / 是否公平」。只允许：基础效果量级是否异常。 |
| `guBudget()` | **DEMOTE** | 异常扫描尺；不给出品质结论。 |
| `kitDpr` / `expectedDamagePerUse` | **KEEP** | 静态遭遇估算器；实战以 autoplay 为准。 |
| `deriveEnemyHp` / `deriveEnemyDamagePerTurn` | **KEEP** | 给遭遇预算基线；手写须 `checkEncounter` + >20% 写 `override_reason`（H1）。 |
| `checkEncounter` / `check_balance.mjs` | **KEEP** | 数学门禁（HP/回合/威胁/投影）。不判「好不好玩、强不强、该不该削弱」。 |
| `counterZeroRate` | **KEEP** | **仅 lab 遭遇估算**；非通用战斗规则（迎击≠整回合无效）。 |
| `rankMultiplier` | **KEEP** | 术语对齐；仍表示层级步进，**不是**万能伤害倍率。 |
| V4.1 逆息 / 胜利回复 +2 / 炼耗月光+小光 | **DEMOTE** | LAB pacing valve / anti-softlock / MVP recipe rule。未经 L0 长期体验不得进 world。 |
| `mvp_content.js` 月光/小光/月芒/白豕 | **DEMOTE** | **10 分钟切片实验组合**，禁止反推「所有一转 ≈ 2 PP」定价模板。 |
| MVP 意图伤害 4/5/6、敌 HP 8/9/14/15 | **KEEP** | 场景校准值；H1 门 + autoplay 验收。非全仓敌人表。 |
| 杀招：配方组装 / 化解 / 泄密 / 残锋 / 跨转数 | **KEEP** | 已符合公理 4（元件 + 运行结构 + 风险 + 知识资产）。勿用「杀招 Lv+30%」覆盖。 |
| 项目决策「自由搭配 + 少量传承杀招范例」 | **KEEP** | 与公理 4/6 一致。 |
| 转数质量门禁（低转催不动高转蛊） | **KEEP** | 公理 1 的正确实现（门槛 ≠ 品质）。 |
| `standard_gu_power` / Rank Power Budget 40…640 | **KEEP** | 层级效果预算轴（RUL-008）；**禁止**再当「所有伤害 ×N」。 |
| fallback `default_effect_by_role` +1/转 | **DEMOTE** | L1：legacy compatibility fallback；非目标曲线。暂不批量重标 741。 |
| 「同转综合价值 ±10%」类平衡 | **CONFLICT** | 直接 REJECT（公理 7 / L0 反例）。 |
| `priceGu` = 终局价值 / 是否淘汰 | **CONFLICT** | 与公理 2 冲突。已 DEMOTE。 |
| 道 = 伤害颜色 / 元素染色 | **CONFLICT** | 与公理 3 冲突。现有 lab 未做多道，**不得**按染色扩。 |
| 蛊 = 技能卡、杀招 = 大技能 | **CONFLICT** | 与公理 4 冲突。Godot 杀招侧已偏正确；Web lab 目前把蛊当动作，属切片简化。 |
| 高转自动替换低转（装备等级） | **CONFLICT** | 与公理 1/2 冲突。 |
| 同转品质分档（垃圾→极品）显式模型 | **MISSING** | 完整系统要补；**本轮不实现**。 |
| 各道独立资源/状态/风险循环 | **MISSING** | 血/智/魂/力仅在公理层定义；引擎未齐。 |
| 杀招作为可重构结构（换核/调序/改触发） | **MISSING** | Godot 有配方与 steps；「自由重构生命周期」未齐。 |
| 修为 = 承载能力扩容（非倍率） | **MISSING** | 仅有转数门禁与 stage_base；完整承载模型未齐。 |
| 路线级平衡（成型构筑对位） | **MISSING** | 当前只有 lab 三条交易路径；非完整路线平衡。 |
| 升仙总检验链（碎窍/三气/渡劫） | **MISSING** | 长期骨架；**禁止本轮开发**。 |
| 公理三问（SOURCE/COMPRESSION/RISK）写入 Worker 协议 | **MISSING** | 后续补进 `ai-system/WORKER_PROTOCOL.md`（本轮不扩协议正文，仅在公理附录冻结）。 |

---

## 汇总

| 判定 | 数量 | 一句话 |
| --- | ---: | --- |
| KEEP | 12 | 校验器、数学门禁、杀招语义、转数门禁 |
| DEMOTE | 9 | 全部定价/价值/实验规则，降为报警器与切片 |
| CONFLICT | 5 | 已识别越权逻辑，禁止回潮 |
| MISSING | 7 | 只登记，不开发 |

**纠偏原则**：原作规律决定游戏是什么；数值模型只检查它有没有坏。
