# Wiki 交接 · 2026-10-01

工作区：`C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren`，分支 `master`。本交接前最新远程提交 `ed521050`。先读根 `PROJECT_MAP.md`、`lore/wiki/README.md`、`lore/wiki/AGENTS.md`；涉及Worker再读本目录协议。

## 本地续批交付（2026-10-01）

当前工作区为 `/home/usrs/dev/codex-test`；本文件开头的 Windows 路径与远程提交为前次交接快照。`bbc622e8` 已完成第一批，本轮续批见[任务状态](tasks/2026-10-01-wiki-existing-content-refactor.md)与[Wiki 日志](../lore/wiki/log.md)：方源长段分节、真元提纯与晋升区分、升炼证据归并、生死仙窍预期与规则页同步，以及入口目标纠偏已完成。本地网站快照随正文重建；本轮尚未提交或推送，GitHub CLI 未登录，远程事项未核对。后续从现有差异与尚存缺口继续，不按旧 READY 状态重做第一批。

## 用户目标与执行边界

Wiki应减少AI处理约700万字原文的需要，支持高质量同人创作；网站是用户查看产物和其他人访问的窗口。优先解决正文质量与混乱结构，不能用目录漂亮、门禁通过或补录数量代替知识质量。

用户额度紧张，优先免费Worker，必要复核用Luna。不要重复出题、答题、评分、逐孔补洞；不要恢复全库重蒸馏。已授权工作连续完成，不能每一步停下来等用户追问。用户已要求停止外部执行器重试，由用户手动转交任务包；本交接不授权自动恢复这些尝试。

## 已交付与真实状态

- `16efd898`：kind导航、网站修复与历史产物快照；原逐章叙事任务已撤回。
- `4a9d7e46`：前40章产物纠偏与下一批任务包。第1–20章12条，第21–40章59条已写入；不代表章节完整覆盖。修正炼化头名原因（春秋蝉气息，而非酒虫精炼真元）、承诺与实作、预测时序、角色信念与错指条目；归并11条重复事实、缩短9处过长引文，旧E-ID／EVT引用保留。
- `735b36eb`：远程合入QMS跨页引用修复，已整合。
- `ed521050`：本地网站静态快照纳入Git，含210页数据、142张优化图片。`lore/wiki/web/app/dist/`现在受版本控制，正文变化后须重建并提交快照。
- Wiki正文真源仍为 `source/蛊真人-epub-canon.txt`。旧TXT行号、重复区、脱敏描述仅作历史回查，不代表EPUB状态；映射不自动证明事实相同。

## 续接状态（2026-10-01）

使用[既有正文归并与纠偏任务包](tasks/2026-10-01-wiki-existing-content-refactor.md)，第一批已由 `bbc622e8` 完成，不能按旧 READY 状态重跑；持续交付续批状态以任务包“当前续批”和 Wiki 日志为准。原四页范围：

- `lore/wiki/characters/fang-yuan.md`
- `lore/wiki/world/gu-care-and-refinement.md`
- `lore/wiki/world/cultivation-system.md`
- `lore/wiki/world/aptitude-and-aperture.md`

按现有主题替换、归并正文，清理生产记录，保留完整证据、局部条件、时序与角色认知；仅在事实冲突时回查相关原文。不要只换标题，也不要追加第二套章节摘要。青茅山页是只读参照，范围与验收以任务包为准。前任扫描发现103页含批次类措辞，这是候选筛选结果，含正常叙事用语，不能当作103页均有缺陷或直接批量删除的依据。

[原连续蒸馏任务](tasks/2026-09-30-wiki-narrative-layer.md)保持WITHDRAWN，其中从第21章续接至第200章的旧指令仅为历史。不得从第41章继续生产。

## 网站与验证

入口：<http://127.0.0.1:8877/#/events/qing-mao-mountain>。启动：`python -m http.server 8877 --bind 127.0.0.1 --directory lore/wiki/web/app/dist`。重建：`py -3 lore/wiki/web/build_app.py`。本地纳入Git不等于发布ChatGPT Site，远程站点未在本轮同步。

最近实际输出：Wiki九项检查通过（194概念页、3946链接、21126个E-ID）；前20章51个引文片段、第21–40章182个引文片段匹配所引章节，后者单条引文不超过60字。这是引文检查，不是全部段落语义或知识覆盖验收。网站检查10类列表、旧URL、缺图回退、世界旧类型和搜索通过；docs-lint FAIL 0，其他孤儿8页为既有游戏临时文档。

必要验证：`pwsh -NoProfile -File lore/wiki/tools/check.ps1`、`node tools/docs-lint.mjs`、`git diff --check`；正文变更后重建网站并运行 `node lore/wiki/web/app/check-app.mjs`。

## Git与未完成事项

交接开始时受版本控制文件干净；本地有无关游戏图片导入文件及美术目录未跟踪，不纳入Wiki提交。Worker默认不提交或推送，用户授权后由L2验收提交。远程可能并行更新，推送被拒应先检查新增提交再安全整合，不强推；若更新Wiki正文，整合后重建站点快照。

持续事项：[Wiki质量 #6](https://github.com/Zachar-c/-/issues/6)、[EPUB切源 #13](https://github.com/Zachar-c/-/issues/13)、[Runtime债务 #7](https://github.com/Zachar-c/-/issues/7)仍OPEN。本次不能据门禁通过关闭这些事项。
