# 并行批次协调（Narrative Compiler v0.1）

> 本文件是两条并行工作线的批次划分与工作树协作规则，由各线在自己批次完成时更新状态行。这是操作层文件，不是知识规范。

## 活跃线与簇车道（2026-09-25 起）

| 线 | 簇车道 | 页面范围 | 状态 |
|---|---|---|---|
| A（Narrative Compiler 主线） | 剧情簇 QMS → 叙事簇 FATE → 规则簇 XQ（仙窍—仙元—灾劫—道痕） | gu/、characters/、events/ 的 ID 化；world-operating-system、cultivation-system、aptitude-and-aperture、soul-path、primeval-essence | QMS ✅ 49.5/50 · FATE ✅ 50/50 · XQ ✅ 50/50（**三簇三类全部达标，v2.1 具备转正条件**） |
| B（兽潮线） | 狼潮/兽潮簇（WTC） | events/wolf-tide.md、world/beast-tide.md、world/south-jiang.md、events/story-arc-overview.md、qing-mao-mountain 的 WTC 投影行 | 第一标段已提交（小兽潮→爆发日序幕，EVT-WTC-001…007）；覆灭段核验 + benchmark-wtc 待收尾批 |
| C（粗蒸馏线） | ROSTER ✅ → GU-ROSTER ✅ → 流派总表（PATH-ROSTER）→ 后续候选：五域地域与组织 | characters/roster.md、gu/roster.md、world/path-roster.md、characters/index.md、gu/index.md、world/index.md、index.md（Key Findings）、log.md | ROSTER ✅ · GU-ROSTER ✅ · PATH-ROSTER ✅（图事成流派源流整段已核 + 境界阶梯实例；粗粒度无 benchmark） |

## 共享页分区块规则

- `events/qing-mao-mountain.md`：A 拥有 frontmatter/ID 层/QMS 投影行；B 拥有 WTC 投影行与狼潮相关叙述。各自只追加自己的区块，不重排对方行。
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
