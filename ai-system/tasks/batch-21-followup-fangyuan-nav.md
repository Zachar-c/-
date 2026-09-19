# Batch 21 Follow-up：清除方源导航行内锚点

## 目标

修复 Batch 21 独立复核发现的一个残留语义问题：方源关系网络“出身与早期舞台”中两行仍直接在导航行内写 notes 锚点。

## 允许修改的文件

仅允许修改：

- lore/wiki/characters/fang-yuan.md
- lore/wiki/log.md

禁止修改其他文件，禁止新增页面、来源、脚本或基础设施。

## 具体修改

只处理以下两行：

- 空窍与资质
- 真元

将它们从“导航名称 + notes 锚点”改成“纯导航 + 指向本页《资料整理》第三条”的形式，并明确本节不作事实断言。保留目标链接和原有概念入口，不新增事实，不改资料整理条目。

例如可以采用类似：

- 空窍与资质：开窍与资质相关导航入口（见本页《资料整理》第三条；本节不作事实断言）
- 真元：真元海规模相关导航入口（见本页《资料整理》第三条；本节不作事实断言）

不要改方源页其他行，不要改星宿页、龙公页。

在 lore/wiki/log.md 追加一条 Batch 21 follow-up 记录，说明这两处 notes 锚点已收敛为纯导航；不要改写历史记录。

## 验收

运行：

- pwsh -NoProfile -File lore/wiki/tools/check.ps1
- git diff --check
- git status --short -- lore/wiki

必须保持 check2 已知 18 条 WARN、0 FAIL。不要提交或推送。

## 交付

按 WORKER_HANDOFF_TEMPLATE 输出完整 Review Handoff，最终状态 READY_FOR_REVIEW 或 BLOCKED。

