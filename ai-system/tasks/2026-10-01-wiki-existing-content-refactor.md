# Wiki 既有正文归并与纠偏

TASK wiki-existing-content-refactor-01
PHASE 青茅山相关既有页，第一批
STATUS COMPLETE（bbc622e8 第一批已交付；2026-10-01 事实边界续批完成）
TYPE content
ASK 完成下述四页正文整理后返回实际差异，不请求逐页确认。

## 当前续批

用户在 2026-10-01 要求持续交付。第一批已由 `bbc622e8` 完成，不再次执行旧追加段整理；续批在上述四页基础上，拆清方源长段与导航、修复提纯和晋升混写、核对升炼证据、分开生死仙窍的记载与人物预期。为避免跨页口径漂移，同步修正 `lore/wiki/rules/tribulation.md` 的 TRIB-017；保留旧知识 ID，不改目录、schema 或游戏。

同步本任务状态、交接与 Wiki 日志，重建受版本控制的网站快照。最终网页验收发现导读无标题锚点，已在现有 `lore/wiki/web/build_app.py` 和 `web/app/app.js` 中修复，并扩展现有 `check-app.mjs` 检查导读目标、前端保留 ID 及 TRIB-017 四列表格边界。仍不恢复连续章节生产，也不恢复外部执行器；验证结果写入本任务与 Wiki 日志。

续批实际结果见 [Wiki 更新日志](../../lore/wiki/log.md)。入口说明与编辑约定一并对齐用户全书知识层目标；正文五页旧知识 ID 集合保留，拆分长段无文字与证据丢失，新增原文定位已定向核对。Wiki 内容门禁和 G0 通过，网站重建并同步本地数据；远程事项因 GitHub CLI 未登录而未核对，未提交推送或关闭持续事项。

2026-10-01 用户验收：关键事实重新回查原文，通过；发现页内点击覆盖文章路由的问题并在原点击委托中返修，增补中文锚点跳转后仍保留文章路由的检查。网站验证使用生成 HTML 与实际函数的模拟 DOM；未进行真实浏览器视觉验收。详细结果见 Wiki 日志的“续批验收与页内导航返修”。

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
