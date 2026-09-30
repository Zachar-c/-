# Wiki 既有正文归并与纠偏

TASK wiki-existing-content-refactor-01
PHASE 青茅山相关既有页，第一批
STATUS READY_FOR_WORKER（手动转交；未启动执行器）
TYPE content
ASK 完成下述四页正文整理后返回实际差异，不请求逐页确认。

## GOAL

修复已有知识的组织和可信度，不重新蒸馏小说。先读根导航、Wiki编辑约定和相关分类索引。保护工作区已有改动；不得恢复[已撤回任务](2026-09-30-wiki-narrative-layer.md)。

允许修改：

- `lore/wiki/characters/fang-yuan.md`
- `lore/wiki/world/gu-care-and-refinement.md`
- `lore/wiki/world/cultivation-system.md`
- `lore/wiki/world/aptitude-and-aperture.md`
- `lore/wiki/log.md`（一条结果记录）

只读参照：已纠偏的 `lore/wiki/events/qing-mao-mountain.md`。不得改目录、schema、游戏或新增平行摘要。

## DELTA

先处理四页中“本批窗口新增／核验／首轮”的追加段落：按现有主题归并进正文，重叠事实保留完整版本及全部证据；人物当时的判断、限制条件和时序不得压没。生产过程移出事实正文，来源范围和“个案不得泛化”等认识边界必须保留。

已知纠偏：炼化月光蛊夺头名依靠春秋蝉气息（EPUB `chapter_0020` `para_019`–`para_026`），不能套用酒虫精炼真元解释；赤练在 `chapter_0021` `para_058` 作出帮助承诺，不直接等于已实施。检查四页有无同类错误，有则就地修正。

默认只读既有Wiki；只对冲突或待修事实回查 `source/蛊真人-epub-canon.txt` 的相关章节段落。不得输入全文、按章节重新抽取、出题答题或仅换标题。旧E-ID保留；迁移映射不自动证明事实相同。无法确定的事实标为待核对，不补造结论。

## TEST

- `pwsh -NoProfile -File lore/wiki/tools/check.ps1`
- `node tools/docs-lint.mjs`
- `git diff --check`
- `py -3 lore/wiki/web/build_app.py`
- `node lore/wiki/web/app/check-app.mjs`

返回四页的实际归并位置、已修事实及出处、保留的条件、删除的重复、真实测试输出。按[结果包](../WORKER_HANDOFF_TEMPLATE.md)区分 FACT / ANALYSIS / UNCHECKED；不能用补录条数或门禁通过证明内容完整。

## GIT / STOP

不commit、merge、push。普通编辑问题持续处理到四页收口；涉及源冲突的条目降级并报告，不牵连其余可确定的整理。权限、覆盖用户改动或范围变更才暂停该批。
