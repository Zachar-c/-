# Wiki 治理登记（治质量 · 控规模 · 接生产）

> 2026-09-26 L0 三支柱指示的常驻登记。质量债台账、规模基线与预算、生产接口契约在此维护；每批次细目记 [log.md](log.md)。schema v2.1 冻结不变——本文件是运维登记，不新增数据字段、不改变页面结构规则。

## 一、治质量

口径基线：认知标记 `[叙事|对话|信念|传闻]×[已核|推断|未决|已修正]`；「资料整理」段属笔记层级、不得当作原著事实；**两说必须回原文裁定**，结果要么订正、要么落注「并存」并写明双方视角（AGENTS.md 既有规则的执行程序）。

### 质量债台账（2026-09-26 扫描基线，排除 log.md 历史记录）

| 标记 | 处数 | 说明 |
|---|---|---|
| 待核对 | 193 | 正文页遗留核验点，密度集中见下 |
| 笔记层级 | 48 | 「资料整理」段，须逐段回原文后升级为原著事实或删除 |
| 未核验 | 46 | 多为规则页：killer-moves 6、dream-path / path-realms / tribulation 各 4、refinement 3 |
| 不得当作原著 | 39 | 既有警示语，随笔记层级消化同步减少 |
| 尚未完成逐段原文核验 | 20 | 「资料整理」段头警示 |
| 两说 | 9 | 存量（HANDOFF-B 记 2 不计内容债）；新增两说即裁即清 |

### 密度 Top（按标记总数）
fang-yuan 13、qing-mao-mountain 10、feng-mo-ku 10、central-plain-refinement-conference 9、cultivation-system 8、zangmeng-ambush 8、three-kings-mountain 7、soul-path 7、dragon-duke 7。

### 首批已收口（2026-09-26）
六项移交裁定（CAR Q41 匪猴上肢原文两口径并存、ZYL Q15 借贷黎山 30/琅琊 15 题标订正、TKF Q2 考核年限闭合、YIT Q47 换魂前因三口径统一、元境毁弃两说裁定同事件双方视角、黑楼兰 ST-15 补 E:V5-216734 实锚）＋ DM-007 成功道痕「共六道/前六名各一道」回原文验证采认。细目见 log.md 治理批条目。

### 下一批队列
1. 密度 Top 五页的「资料整理」段回原文核验（双代理窗口制，升级或删除）；
2. 规则页未核验 21 处定点核验；
3. 余下两说逐一回原文。

## 二、控规模

### 基线（2026-09-26）
127 md / 1034 KB。events/ 354 KB、根 150 KB（log.md 114 KB 为单文件之最）、tools/ 138 KB、world/ 114 KB、source/ 95 KB、gu/ 60 KB、characters/ 58 KB、rules/ 39 KB、themes/ 22 KB。

### 预算
- 内容页 ≤40 KB；簇事件页例外上限 60 KB——超限触发三分流规则六回抽（状态→实体页状态时间线、机制→规则/世界页）。
- log.md ≥100 KB 触发轮换：历史整体切 `log-archive-2026H2.md`（搬移不改字、log.md 留轮换指针）；**现 114 KB，下批执行**。
- source/section-index.md 属 B 线按需维护索引，只增不扩写。
- tools/ 测试 scratch（`_*.md`、`_rows_*.txt`）不提交、用后即删（本批已清 9 件）。
- 重复文本区（377902–385324 ≡ 385490–392286）引用一律取 392482 起独有正文（既有登记重申）。

### 超限现况
feng-mo-ku.md 90 KB（唯一超限）——下批按三分流回抽；events/ 下一批整体体检（royal-court 38 KB 贴线）。

## 三、接生产

### 编译契约（compile_runtime.py，Owner＝canon-runtime 批次）
数据流：Wiki（Source of Truth）→ compile_runtime.py → lore/runtime/*.json（tracked 生成物，随 wiki 提交同步再生成）。
消费面：gu/roster-3 id 段、gu/* 实体页 ST-*→states[]、rules/refinement.md＋rules/killer-moves.md＋world/primeval-essence.md、RELATION_SOURCES 行锚（ST-SMALLLIGHT-03/04、ST-MOONLIGHT-06——措辞冻结，改动即编译报错，属设计）、source/section-index.md 段表、canon-index、原文 sha256（437060 行）。E-ID 段号校验与 check9 同款。

### 编辑纪律
1. 改实体/规则页后必须 `py -3 lore/wiki/tools/compile_runtime.py`，manifest 随 wiki 提交同步；
2. wiki 提交前门禁：check.ps1 全绿＋编译器零错误；
3. 「转数未核」段只有蛊名无 id，编译器跳过并登记 coverage——roster-3 蒸馏时优先补核转数。

### 缺口登记（移交 canon-runtime 批次，本车道不擅扩编译器）
characters/* 实体页 ST 时间线不在消费面内：fang-yuan ST-01…39、he-lou-lan ST-01…16、bai-ning-bing ST-01…12 等——runtime `entity_states` 现仅 28 条且全部来自 gu/ 页。角色状态线是多批基准盲测实测引用最密的数据集；扩展属 IR 设计决定（docs/design/canon-runtime/2026-09-25-p1-ir.md §6）。

## 批次记录

- 2026-09-26 首批：六项移交裁定收口、DM-007 采认、scratch 清理 9 件、规模/质量基线测量、编译验证与角色 ST 缺口登记。
