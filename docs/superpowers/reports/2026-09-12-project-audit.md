# 项目全面审计报告（2026-09-12）

> **性质**：只读审计，未改动任何代码。范围=肉鸽主旨符合度（玩法循环/随机性/成长曲线）+ 工程结构/质量/技术债。
> **证据**：仓库实测（scripts 127 文件 31,777 行；tests/unit 185 文件；data 30 JSON；tools 110 脚本）+ 跨会话记忆。
> **结论先行**：**工程纪律是本项目最强资产**（确定性 RNG、不可变状态、契约测试、集中校验）；
> **最大短板在内容侧的肉鸽结构性要素**——节点多样性、遗物系统、跨局目标感，三者空瘪使"每局都差不多"。

---

## 一、核心玩法循环（评级：骨架完整，血肉不足）

**现状**：一局 = 5 大层（`map_generator.LAYER_ORDER` one→five），末层收敛 `final_boss_stand`，
中途 `ascension_window` 唯一节点；死亡走单一终结转换（`finalize_death`）；存档 SAVE_VERSION 4 + checksum。

| 环节 | 现状 | 评估 |
|---|---|---|
| 节点节奏 | pacing 权重：battle **74–82%** / rest 恒 5 / trade 4–8 / unknown 9–13 | ⚠️ 战斗占比过高且 rest 恒定——层间节奏无变化 |
| 节点模板 | nodes.json 有 **17 类 37 模板**（market/hazard/inheritance/wild_gu/commission/earth_vein…） | ⚠️ pacing 池只产 4 类 ⇒ **约 2/3 模板闲置**（E5/E6/E7 未落） |
| 战斗 | V1 蛊行动制 + 杀招 + 刻痕（T15）+ 支援链；steps 逐步结算未落（P3） | ✅ 深度足够；⚠️ 大招不可打断 |
| 经济 | 元石=货币+真元电池语义已考据；balance.json 48 键集中 | ✅ 地基好；⚠️"元石补真元"职能未实现（T13 缺口） |
| 失败/重来 | 死亡→统计+图鉴保留（首次获取永久） | ✅ 单局闭环成立 |

**判定**：循环"能转"但**结构性趋同**——每局的差异主要来自洗牌与 seed，而非节点/事件的结构性分岔。

## 二、随机性与可重玩性（评级：中）

- ✅ **确定性基础扎实**：SeededRNG 贯穿 map_generator(9 处)/enemy_catalog/loot/dda/economy/refine；
  种子可复现（`SeededRoll.mixed_seed(seed, node_id, 0)`），这对调试与公平性是正确设计。
- ⚠️ **方差来源偏窄**：20 流派选择 + 洗牌 + 掉落是主要随机面；事件/奇遇/岔路结构性随机缺失（同上）。
- ⚠️ **跨局驱动单一**：MetaProgress 只有图鉴解锁（gu/recipe/relic/inheritance）+ 契约/日志解锁 + 统计——
  **无解锁驱动的开局变体、无挑战模式、无周目/进阶结构**（ascension_window 是局内节点非 meta 进阶）。
- ❌ **遗物系统空瘪**：`relics.json` 仅 **2 条**——肉鸽 build 多样性的标配支柱形同虚设
  （relic_codex 容器已建，内容没跟上）。
- ⚠️ **无固定 seed 扫描工具**：`reached_l5/entered_ending` 的 25-seed 扫描是 ad hoc（提交信息可见），
  未沉淀为 tools 常备脚本——平衡回归缺护栏。

## 三、角色成长与难度曲线（评级：中）

- ✅ 成长链完整：转数 1–5（rank_step_ratio）+ 资质公式（essence_max=base×aptitude×cultivation）+
  同名升阶 + 晋升配方（`a7c8ae0`）+ 修为门禁（低转不可驱高转）——**"战力=转数×蛊(质×量)"忠实落地**。
- ✅ DDA 自适应难度存在（`dda_resolver`，MetaProgress 有开关）。
- ⚠️ **曲线手段单一**：敌人数值=中央 `beast_scale(rank)` 投影 + boss_layer_mult；层间主要靠 rank 门禁抬升；
  rest 权重恒 5 ⇒ **恢复节奏不随层数调整**，难度是"阶梯"而非"曲线"。
- ⚠️ **流派间成长差异未表达**：原文"流派不同维度不同"（奴道看兽群规模）——现网各流派成长手感趋同
  （同一套 role×rank 模板），剑道的"起势→出剑"是唯一结构性差异点（试点正确，但只此一家）。

## 四、结构与代码质量（评级：良）

- ✅ **架构纪律强**：resolver.gd 已拆至 205 行路由核；命令族模块单向 preload；快照 13 模块；
  RunState 不可变 + 命令分发表；`MASTER_SCENE_PATHS` 唯一路由。
- ✅ **测试文化罕见地好**：185 个 unit 文件 / 1239 测试，契约测试先行（TDD 红→绿）是常态；
  integration 32 项；渲染级验证（force_draw/唯一色数）工具链齐。
- ✅ **校验集中**：`content_catalog.validate` 一入口（rank/value/school/effect 形状/杀招引用）+ 红线写进代码注释。
- ⚠️ **god-file 风险转移而非消除**：`content_catalog.gd` 1540 行（目录加载+校验+白名单三职责合一）；
  `acceptance_driver.gd` 2850 行（工具侧，随屏数增长会失控）；`action_preview_service.gd` 1182 行。
- ✅ TODO/FIXME/HACK 计数 = 0；run_controller 已拆至 903 行（<900 债务基本清偿）。

## 五、技术债清单（按风险排序）

| # | 债 | 位置 | 风险 |
|---|---|---|---|
| 1 | **content_catalog 三职责合一**（load/validate/白名单） | `content_catalog.gd` 1540 行 | 改校验即碰全库；后续补流派（每流派 6 处改动）会持续加压 |
| 2 | **Q8 死路径**：距离减伤/敌人追击代码保留但恒 no-op（distance≡0） | `v1_battle_resolver._distance_adjusted_damage/_enemy_pursuit` + cfg 3 键 | 死代码+注释误导（spec 已加推翻横幅）；需清理批次 |
| 3 | **status=bound 全仓无读取点**（logistics 兜底死数据）；buff 只喂 basic_attack 语义弱 | `v1_effect` 体系 | Q7 辅助蛊实义化的直接动机 |
| 4 | **regen_pct 同名双源**（aptitude.json 40/30/20/10 vs v1_battle.json 35/30/25/18） | 两 JSON | 已知勿误改，但迟早该改名消歧 |
| 5 | **acceptance_driver 2850 行** | tools | 工具不挡生产，但每扩屏都要改它，维护成本线性涨 |
| 6 | **杀招 steps 未落（P3）**：大招原子结算，与"逐步可打断"语义缺口 | kill move 结算 | 玩法债非代码债 |
| 7 | **流程债：并行会话物理删除事故 ×4** | 协作流程 | 非代码，但恢复成本高（checkout-index 手工流程） |

## 六、与肉鸽主旨不符或缺失的要素（核心发现）

1. **结构性随机缺失**（最高优先）：事件/奇遇/岔路节点全部退役出 pacing 池——每局地图只剩"战斗走廊"。
   37 个模板是现成资产，接回 pacing（E5–E7）是**性价比最高的可重玩性投资**。
2. **遗物/圣物层空瘪**（2 条）：肉鸽 build 多样性缺支柱。原文可支撑的方向：蛊方图谱解锁、仙蛊残片、
   福地遗藏（inheritance 骨架已有）。
3. **跨局目标感弱**：图鉴之外无"下一局想试什么"的钩子（无开局变体/挑战/解锁build）。
4. **难度曲线无"选择"**：缺风险-回报节点（如 hazard 类高危高赏）——模板有、池里没有。
5. **流派手感同质**：20 流派共用 role 模板，差异化只有数值（剑道试点除外）。
6. **元石第二职能缺失**（T13）："用元石补充真元"是经济-战斗的资源转换闭环，缺它经济层偏扁平。

## 七、改进建议（按投入产出排序）

| 优先 | 建议 | 依据 |
|---|---|---|
| P0 | **接回事件/岔路节点到 pacing 池**（E5–E7），先 3–4 类低耦合模板（market/hazard/wild_gu） | 模板现成；直接解决"每局趋同" |
| P0 | **遗物系统补内容**至 10–15 条（走 inheritance/relic_codex 现成容器），每条一个 build 钩子 | 肉鸽标配；容器已建 |
| P1 | **沉淀 seed 扫描工具** `tools/seed_sweep.gd`（N seed × reached_l5/entered_ending/均层/均元石），进 check.ps1 | 平衡回归护栏；cc614b4 已手工做过 |
| P1 | **Q7 辅助蛊实义化**（规格已落位 plans/2026-09-12-shop-recipe-support-landing.md） | 同时消解债 #3 |
| P1 | **rest 权重随层浮动** + hazard 高危高赏节点 | 曲线"曲线化" |
| P2 | content_catalog 拆校验子系统（validate→catalog_validators/） | 债 #1 |
| P2 | Q13 元石补真元 + Q4 商店分栏/卖出（规格已落位） | 经济闭环 + 商店体验 |
| P2 | 清理 Q8 死路径 + regen_pct 消歧 | 债 #2/#4 |
| P3 | 杀招 steps 逐步结算 | 玩法深度 |

## 八、风险与结论

- **最大的项目风险不是技术，是"内容方差"**：架构能扛 20 流派×40 蛊的扩展（校验+测试兜住），
  但如果玩家第三局就见过所有节点类型，留存会先于技术债爆发。
- **第二风险是流程性**：并行会话曾 4 次物理删除文件；任何多会话施工前应先约定"单写者"边界。
- **总评**：这是一个**工程素养高于内容丰度**的肉鸽项目——继续按"先骨架后血肉"的路线走是正确的，
  当前进度正处于"该往池子里放内容"的转折点（节点/遗物/流派差异化三件事）。
