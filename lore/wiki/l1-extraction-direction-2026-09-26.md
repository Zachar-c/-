---
title: 原著扣取全量清单与 L1 方向判决书
description: 从《蛊真人》扣进 lore/wiki 的知识资产事无巨细盘点；L1 定后续方向；L0 意见=愿意支付代价
date: 2026-09-26
tags: [l1, extraction, inventory, direction, canon]
---

# 原著扣取全量清单 · L1 方向判决书

| 项 | 内容 |
|---|---|
| 对象 | `lore/wiki/` 全库——从《蛊真人》原文扣取并编译的全部知识资产 |
| 发起 | L0：「把 wiki 从蛊真人上扣下来的东西事无巨细的按原则上述 L1，让 L1 把握方向」 |
| **L0 意见** | **愿意支付代价**（质量债清偿、再核验、生产转换、持续维护的全部成本） |
| 判决人 | L1（知识架构与研究方向） |
| 性质 | **方向判决**，不改产品数值、不改游戏契约；定「这批资产接下来怎么用、先还什么债、往哪打」 |

## 0. 原则（所依）

1. **原书事实=正典**；从 wiki 取已核验事实再优先化；**现实现全部存疑**，核查从 Wiki 出发。
2. L0–L5 与 L6 严格分离；游戏数值不进 lore。
3. 证据缺口显式降级；笔记层级不得当原著事实；某人认为 X ≠ 世界规则 X。
4. 门禁本地可复跑；Wiki 内容质量与 Canon→Game 实现门禁分立。
5. L1 管高不确定性的架构、优先级与多模型择一；普通工程直接闭环。

---

## 1. 资产总览（事无巨细）

### 1.1 规模

| 量 | 值 |
|---|---|
| Markdown | **122 页**（概念页 82；另 tools/ 20、source/ 3、根治理 11） |
| 体积 | ~1034 KB（events 354 / 根 150 / tools 138 / world 114 / source 95 / gu 60 / characters 58 / rules 39 / themes 22） |
| 原文覆盖 | 《蛊真人》净本 **437,060 行**（六段：V1–V6），断点后不写 |
| 门禁 | `check.ps1` **ALL PASS**（check1–9）；E-ID **4950/4950** 段号一致；链接 1513/1513；canon-index 31/31 |

### 1.2 一等公民 ID 层（扣取骨架）

| ID 族 | 量级 | 含义 |
|---|---|---|
| `E:V{段}-{6位行号}` | **4950**（引用约 4983） | 原文证据锚点，可回放 |
| `EVT-{簇}-{序}` | 引用 **2647** | 事件（L2）；十三弧+余波域全覆盖 |
| `ST-{实体}-{序}` | 引用 **289** | 实体状态时间线（L3） |
| `CAN-*` | 登记 **31+**（引用 114） | L4 命题（`game/docs/lore/canon-index.md`） |
| 规则簇 ID | **~190** | TRIB 27 · DM 29 · REF 33 · KM 31 · PR 18 · VEN 23 · DRM 21 |

### 1.3 按层盘点（L0–L5 扣取物）

#### L1 证据层（锚点与来源）

- 全库主张带 E-ID / 行号；`source/section-index.md` 六段表；`source/chapter-index.md` 节序。
- 来源四类：`source:`（原文）· `notes:`（读书笔记）· `memory:`（记忆库）· `canon-index:`（CAN-*）。
- 已知边界：`source/蛊真人-clean.txt` 等原文 **local-only 不进 Git**（82 条 check2 WARN，设计使然）。

#### L2 事件层（十三弧 + 余波域，全书 100% 行域）

| 弧 | 行域（约） | 承载页 | EVT 域 | 基准 |
|---|---|---|---|---|
| 一 重生青茅 | 426–15,500 | qing-mao-mountain | QMS-001…114 | 49.5/50 |
| 二 狼潮覆灭 | 15,501–45,000 | wolf-tide | WTC-001…026 | 50/50 |
| 三 商队商家城 | 45,001–75,383 前 | south-caravan | CAR-001…044 | 49/50 |
| 四 三王福地 | 45,001–75,383 后 | three-kings-mountain | TKF-001…032 | 48.5/50 |
| 五 王庭之争 | 75,384–116,326 | royal-court | RTC-001…120 | 47–48/50 |
| 六 真阳楼崩塌 | 116,326–135,000 | true-yang-collapse | ZYL-001…060 | 47.5–48.5/50 |
| 七 僵盟潜伏 | 135,001–172,000 | zangmeng-ambush | ZGM-001…107 | 47.5/50 |
| 八 炼蛊大会 | ~150,642–156,775 | central-plain-refinement-conference | CPR-001…038 | 48.5/50 |
| 九 义天山 | 172,000–200,000 | yitian-mountain | YIT-001…112 | 49.5/50 |
| 十 逆流河琅琊 | 200,001–270,000 | reverse-flow-river | RFR-001…122+补录 | 49/50 |
| 十一 宿命 Run1 | 270,001–323,421 | fate-war | FATE-001…066 | 50/50 |
| 十二 Run2 宿命毁灭 | 323,422–360,000 | fate-war | FATE-067…158 | 50/50 |
| 十三 三尊博弈断点 | 360,001–437,061 | feng-mo-ku | FMK-001…170 | 48–50/50 |
| 余波域 | 200,001–225,037 | 折入 YIT/RFR | 补录行表 | 已读闭合 |

- 导航中枢：`events/story-arc-overview.md`（覆盖看板+主链+十三弧分节）。
- 方法：逐窗精读 → 事件单点定义 → 三分流（L2 留簇页 / 实体 ST / 机制入规则世界页）→ 基准盲测 ≥45/50。

#### L3 实体层（人物 / 蛊 / 地理 / 势力）

**人物（characters/ 11 页）**

| 资产 | 内容 |
|---|---|
| roster.md | 约 45 主要人物·势力分组 + **方源马甲归一表**（11+ 马甲） |
| roster-2.md | 约 50 复现配角八组 |
| enemy-roster.md | 五层威胁结构 + 弧线敌人速查 |
| 专页 | fang-yuan（ST-01…61）、he-lou-lan、bai-ning-bing、red-lotus、star-constellation、dragon-duke、yuan-lian-xian-zun |

**蛊（gu/ 18 页）**

| 资产 | 内容 |
|---|---|
| roster.md | 约 60+ 蛊品阶谱系 + 方源蛊链时序 + 人道蛊族 + **仙蛊屋总表 ~80 座** |
| roster-2.md | 约 24 基础设施型蛊 |
| roster-3.md | **270 蛊转数层逐蛊核验**（游戏映射源；含「转数未核」段） |
| 专页 | 春秋蝉 / 宿命 / 智慧 / 坚持 / 月光系（月光·月芒·月痕·小光）/ 熊力 / 骨 / 青藤 / 硬气 / 自己 / M0 六蛊边界 |

**世界（world/ 27 页）**

| 资产 | 内容 |
|---|---|
| 五域 | north-plain / central-plain / east-sea / west-desert / south-jiang |
| 体系 | cultivation-system / aptitude-and-aperture / primeval-essence / soul-path / world-operating-system / gu-care-and-refinement |
| 总表 | path-roster（流派源流+33 归属+境界阶梯）/ economy-roster / map-roster（~40 地点）/ kill-move-roster（**268 命名杀招扫描**+实例） |
| 势力 | heavenly-court / longevity-heaven / shadow-sect / zangmeng / ten-ancient-sects / beast-tide |
| 视觉 | visual-qing-mao / frontier / central-plain / late-era / nanjiang-shangjia |

#### L4 规则命题层（rules/ 7 页 + canon-index）

| 页 | ID 域 | 扣取内容 |
|---|---|---|
| tribulation | TRIB-001…025+ | 灾劫周期、天意边界、口径调和（30/18/四五十） |
| dao-marks | DM-001…026+ | 道痕吸收/残留/天道道痕、成功道痕「共六道」 |
| refinement | REF-001…027+ | 炼化/合炼/推演/自然炼蛊/仙材分级 |
| killer-moves | KM-001…020+ | 杀招组合/连招并招/代价/泄密/化解 |
| path-realms | PR-001…016+ | 流派境界阶梯、大师宗师特征、成尊必要非充分 |
| venerables | VEN-001…020+ | 十尊/成尊四条件（拼装+未决）/万劫道痕 |
| dream-path | DRM-001…018+ | 梦境炼蛊/解梦/现世仙蛊/三尊说 |
| canon-index | CAN-* | 游戏侧 L4 登记表（南疆/经济/蛊养/资质/升仙/兽王阶梯等 31+） |

#### L5 综合层（主题 / 哲学 / 人祖传）

- themes/ 8 页：immortality · power-and-interest · fate · freedom · persistence · philosophy（四组命题轴）· ren-zu-zhuan（寓言-剧情互文 12 锚）· index
- 认知标记两维全库执行：`[叙事|对话|信念|传闻]` × `[已核|推断|未决|已修正]`

---

## 2. 质量与债（扣取的诚实边界）

| 债 | 量 | 性质 |
|---|---|---|
| 待核对 | **193** | 正文遗留核验点（密度 Top：fang-yuan 13、qing-mao 10、feng-mo-ku 10…） |
| 笔记层级（资料整理） | **48** | 未升原著事实，不得当规则 |
| 未核验 | **46** | 多在规则页（KM/DRM/PR/TRIB/REF） |
| 两说 | **9** | 已裁 6+，余须回原文 |
| 蒸馏缺口 | 100 题审计后已清 | 复测触达 77→95；余 5 为原文无/题面前提 |
| 规模超限 | feng-mo-ku 等 | 三分流预算制；log.md 114KB 待轮换 |
| 方法论残留 | 出题同源、题目轮换 | v2.2 条件①已机制化，待长期执行 |

**置信分层（下游必读）**：已核（E-ID 回读）＞ 未决/推断 ＞ 资料整理（笔记）＞ 两说并存。roster 类=导航定位，**规则源走 rules/ 与 world/ 体系页**。

---

## 3. 与《问真》接口现状（对照，非依据）

| 接口 | 状态 |
|---|---|
| canon-index 31+ | 已映射南疆/经济/蛊养/资质/升仙/敌人阶梯 |
| compile_runtime / lore/runtime | 实体 160+ / 规则 95+ / 月光切片 Pack 已通 |
| Game Semantics / Conformance | P2–P4 门禁在案 |
| game/data + 现网实现 | **全部存疑**（L0 原则）——只作对照缺口，不反向定真 |

---

## 4. L1 方向判决项（请择定）

### D-A · 资产用途主线（多模型择一）

| 选项 | 内容 | 代价（L0 已同意支付） |
|---|---|---|
| **A1 生产优先** | 先做「游戏向精华」：13 主题簇+规则页 → P0 杀招/合成 → P1 系统 → L6 转译 | 中：精华层新建；与簇页漂移风险须投影纪律 |
| **A2 质量优先** | 先清债：193 待核对+48 笔记+46 未核验+两说 → 全库升「已核」 | 高：回原文窗口制，周期长 |
| **A3 混合（建议）** | **P0 路径上的债先清**（杀招/炼蛊/蛊实体/经济锚点）再出精华；非 P0 债排期 | 中高：可交付与质量并行 |

### D-B · 精华落点

| 选项 | 落点 | 说明 |
|---|---|---|
| **B1** | `game/docs/wiki/concepts/canon-game-essence.md` | L6 侧；不镜像 lore（D5） |
| B2 | `lore/wiki/` 内「生产导出」子目录 | 仍在真源库，易混 L5/L6 |
| **建议 B1** | | |

### D-C · 优先级轴

| 选项 | 轴 |
|---|---|
| **C1 核心支柱** | 杀招组装 + 蛊合成配方 → 经济/敌/流派/资质真元 → 风味 |
| C2 叙事弧序 | 按弧一→十三 |
| C3 实现缺口 | 现网缺什么补什么（**违 L0「实现存疑」**，不建议） |
| **建议 C1** | |

### D-D · 组织债

- 三线（A/B/C）车道已废；`COORDINATION.md`/`HANDOFF*` 改为「历史交接、资产按需维护」。
- 是否同批执行：**是 / 否**。

### D-E · 持续代价范围（L0 已声明愿付，请圈定）

1. 质量债清偿（窗口制回原文）
2. 精华层维护（防漂移、随 lore 修订同步 L6）
3. Canon→Game 对照与实现纠偏（现实现存疑）
4. 基准/门禁长期运行（check + benchmark 轮换）
5. 规模治理（log 轮换、簇页预算、三分流回抽）

---

## 5. L1 裁决（2026-09-26 已签）

| 项 | 裁决 |
|---|---|
| **D-A** | **A3 混合**：P0 游戏核心支柱知识债优先清偿 + 建 Canon→Game Production View；非生产链债排队，不做无差别清零 |
| **D-B** | **B1'**：`game/docs/wiki/concepts/canon-game-essence.md` = **Canon→Game Production View**（非第三真源）；只回答「生产依赖哪些 Canon」；禁止重写世界观/机制全文 |
| **D-C** | **C1** 核心支柱轴：杀招↔蛊↔炼蛊 → 真元/念头/转数/资质 → 经济/材料/养蛊 → 敌/掉落/交互 → 流派 → 叙事风味；**禁 C3 实现反推** |
| **D-D** | **同批清理**：COORDINATION/HANDOFF/三线说明降级为历史生产记录 |
| **D-E** | **1–5 全包，持续预算制**（清债只清阻塞 Knowledge Ready 的） |

**P0 优先清偿顺序**：①杀招 ②炼蛊 ③蛊虫实体及关系 ④真元/资质/转数 ⑤经济与资源 ⑥敌人可消费世界规则。

**Production View 条目格式**：
`Canon Ref → Relevant Rule/Entity → Gameplay implication → Game Semantic/Ruling → Implementation status`
上游 `[已修正]`/CAN 变更/Rule 推翻/证据降级 → 条目标 **STALE**。

**知识生产等级**（取代单一「已核」）：
`CANON_VERIFIED → KNOWLEDGE_READY → RUNTIME_READY → SEMANTICS_READY → GAME_GENERATION_READY`

**阶段转换**：Extraction → **Compilation**。主指标改为 Rule Coverage / Relation Density / Knowledge Ready clusters / Canon Runtime coverage / Semantic bindings / Game Generation Ready slices。

**第一生产主线**：杀招+炼蛊+蛊虫完整知识链；验证样本=月光/小光/月芒体系。成功标准=Wiki 事实稳定决定游戏里的蛊、杀招、炼蛊与敌人行为。第二=真元/资质/转数/念头/魂魄；第三=经济/蛊材/养蛊/掉落/交易。十三弧仅作检索与 Context Pack 来源，按需 JIT deepening。

---

## 6. 签署

| 角色 | 状态 |
|---|---|
| 资产盘点 | 本文件 §1–2，2026-09-26 |
| **L0 意见** | **愿意支付代价**（D-E 1–5 全包，持续预算制） |
| **L1 方向判决** | **已签，2026-09-26**：A3 · B1' · C1 · D-D 同批清理 · D-E 全包 |

生效：按本裁决开工。

---

## 7. L0 追加决断（2026-09-26）· 802 蛊作废

| 项 | 内容 |
|---|---|
| 决断 | **生成器产出的 802 蛊质量过低（高度重复、无创意），不能支撑玩法创意与牌组构建；全部删除、不予参考** |
| 依据 | 审计早载：742/802 role 兜底、同 role 战斗等价、目录多样性未兑换成玩法多样性（`game/PROJECT_WORLD_MODEL_AUDIT.md`、`game/world-model/RISK_REGISTER.md`） |
| 效力 | `gu.json` 802 体系 **VOID**：不作新设计参考、不作 Canon 证据、不进 Production View 正面清单；历史快照仅存 git/归档 |
| 新血 | 新蛊池必须从 **wiki Canon + 玩法支柱** 重新设计（分层：Canon 核 / Derived / Creative），禁止再走「批量生成同质条目」 |
| L0 意见 | 愿付重建代价；宁要少而有创意的蛊，不要 802 同质壳 |

与 D-A…E 并行有效；Production View 中涉及 802 目录的行一律标 **STALE/VOID**。
