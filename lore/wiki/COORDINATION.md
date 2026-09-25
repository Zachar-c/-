# 并行批次协调（Narrative Compiler v0.1）

> 本文件是三条并行工作线的批次划分与工作树协作规则，由各线在自己批次完成时更新状态行。这是操作层文件，不是知识规范。
> 线名裁定（2026-09-25，L0）：A＝全书复杂规则精蒸馏；B＝全书粗蒸馏；C＝全书按剧情顺序精蒸馏。历史条目中 WTC 狼潮簇曾标"B 线"，按本裁定更正为 C 线；本文件旧版把粗蒸馏线标为"C"，更正为"B"。

## 活跃线与簇车道（2026-09-25 起）

| 线 | 簇车道 | 页面范围 | 状态 |
|---|---|---|---|
| A（全书复杂规则精蒸馏） | 验证簇：QMS ✅ → FATE ✅ → XQ ✅（三类达标，v2.1 冻结转正）→ **规则精蒸馏路线五站全部完成：灾劫体系 ✅（TRIB-001…014）→ 道痕体系 ✅（DM-001…015）→ 炼蛊术语体系 ✅（REF-001…012，新术语平炼）→ 杀招-连招-并招体系 ✅（KM-001…012）→ 流派境界五级 ✅（PR-001…011，原 T1 延期项已恢复完成）** | rules/ 目录五页互链成网 + cultivation-system、aptitude-and-aperture、primeval-essence、world-operating-system、soul-path 的深度规则表 | **五站 ✅ 全部提交** + 哲学思考页 ✅（themes/philosophy.md，四组命题轴；B 线主题补全候选与本页重合部分由 A 线承接）；后续候选：尊者资格链核验（PR-011）、阵道外流派能力标尺、梦道机制 |
| B（全书粗蒸馏，本线） | ROSTER ✅ → GU-ROSTER ✅ → PATH-ROSTER ✅ → 五域地域（DOMAIN）✅ → 经济与资源（ECON）✅ → 组织专页（ORG）✅ → 主题与《人祖传》补全（THEME）✅ → 世界观补漏复查（GAP-SWEEP）✅ → 后续候选：按需维护与B线页面跟进核验 | characters/roster.md、gu/roster.md、world/path-roster.md、world/ 四域页+economy-roster.md+四组织页、themes/immortality+power-and-interest+ren-zu-zhuan 补全、characters/index.md、gu/index.md、world/index.md、themes/index.md、index.md（Key Findings）、log.md | 八簇全绿（人物/蛊虫/流派/五域/经济/组织/主题/补漏）；粗粒度抽样核验、无 benchmark；rules/ 归 A 线不动 |
| C（全书按剧情顺序精蒸馏） | 狼潮/兽潮簇（WTC，原误标 B 线）✅ → **弧三·南疆商队与商家城（CAR 簇）进行中：标段一至标段三已提交（黄龙江逃生→白骨山→张家商队→商家内城演武扬名，EVT-CAR-001…037）；收束批＝节 124–134 离开商家城 + benchmark-car** | events/wolf-tide.md、events/south-caravan.md、world/beast-tide.md、world/south-jiang.md、events/story-arc-overview.md、qing-mao-mountain 的 WTC 投影行 | WTC ✅ 50/50（benchmark-wtc 首测满分）；CAR 标段一/二/三已提交，benchmark-car 随弧三打穿批落地 |

## 共享页分区块规则

- `events/qing-mao-mountain.md`：A 拥有 frontmatter/ID 层/QMS 投影行；B 拥有 WTC 投影行与狼潮相关叙述（按线名裁定，此 B 指现 C 线）。各自只追加自己的区块，不重排对方行。
- `world/path-roster.md`：B 线建（粗粒度归属表+阶梯实例）；A 线"流派境界五级"精蒸馏时以该页为底 refactor，已核实例锚点（图事成窗口、170734–170740）保留不重写。
- hub 索引页（`index.md`、`events/index.md`、`world/index.md`、`characters/index.md`、`gu/index.md`、`themes/index.md`）：双方只做"新增自己页面的一行登记"；改动前先 `git diff` 查对方未提交改动。
- `log.md`：append-only，双方各自追加自己的批次记录，不改写对方条目。

## 工作树协作规则（同一 checkout 并行）

1. 每批完成即提交，未完成的改动不过夜占用工作树。
2. 提交前 `git status --short -- lore/wiki` 区分自己与对方的改动，**只 add 自己车道内的文件**。
3. 改共享页前先 `git diff <该页>` 确认对方是否有未提交改动；有则等对方提交，或只追加不重叠区块。
4. 提交信息沿用 `docs(wiki): <簇名/批次名>`。
5. 新簇开工先在本文件登记车道；簇打穿后状态改 ✅ 并附 benchmark 得分。

## 门禁与冻结

- Schema v2.1 冻结（见 [AGENTS.md](AGENTS.md)），两线共用 `tools/check.ps1` 门禁；各簇各有 `tools/benchmark-*.md` 回归题集。
- 星宿仙尊/龙公页当前归 A 线 FATE 簇后续核验引用范围，B 线如需引用按现有页面链接，不迁移不改动。
