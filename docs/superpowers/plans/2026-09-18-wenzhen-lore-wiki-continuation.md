# 问真 Wiki 解冻续作计划（Phase 4+）

**Goal:** 解冻 `lore/wiki/`，以 opencode 作为执行层，按"主题簇 / 叙事冲突 / 世界规则链"批次继续《蛊真人》蒸馏。

**Architecture:** `lore/wiki/` 是 Markdown-first 蒸馏层；`source/蛊真人-clean.txt` 与 `source/《人祖传》.txt`（本地忽略）是原文；`game/分支：六卷精编版/读书笔记/`、`.../记忆库/`、`game/docs/lore/canon-index.md` 是二级来源；`lore/research/` 是创作资料，不得当原著事实。不引入数据库、RAG、向量库、图谱或 Quartz。

## Global Constraints

- 不复制原文；引用用路径 + 区间/行号定位。
- 事实与解读分写：`原著明确内容` / `分析与解读` / `待核对`。
- 页面只用 `type`、`name`、`aliases`、`sources` 四个 frontmatter 字段；文件名用 ASCII slug。
- 来源命名空间固定为四类：`source:`（原文，指向本地 `source/`）、`notes:`（读书笔记）、`memory:`（记忆库）、`canon-index:`（`game/docs/lore/canon-index.md` 的 `CAN-*` 条目）。
- 一个批次 = 一个主题簇；批次内必须同时完成新增页、分类索引、反向链接、来源边界和验收，不留可在本批完成的"待建立"入口。
- 禁止改动 `game/` 下任何文件（迁移后游戏工程只读）；禁止把游戏数值、卡牌效果或《问真》改编写进原著事实区。

## Worker Contract（opencode 执行层）

- 调用形式：`opencode run "<任务>" -m opencode/muse-spark-1.3-contributor-free --auto -f <brief路径> --dir <仓库根>`
- worker 只执行简报：不推送、不切分支、不 `git add -A`、不 `reset --hard`、不 `git clean`、不删除磁盘文件。
- 每批一个提交，提交信息用 `docs(wiki): <批次名>`；协调方验收通过后才推送。
- 验收统一跑 `pwsh -NoProfile -File lore\wiki\tools\check.ps1`，并附 `git status --short --branch`。

## Task 1（Batch 0）：解冻与引用修正

- 修正 12 处迁移遗留的坏 `source:` 引用（`source:source/分支：六卷精编版/...` → `source:source/...`）。
- 统一 canon 命名空间为 `canon-index:`。
- 根 `AGENTS.md` 与 `PROJECT_MAP.md` 解除 wiki 冻结。
- 新增 `lore/wiki/tools/check.ps1` 验收脚本。

## Task 2（Batch 4）：天庭冲突簇

- 新增 3 个事件页：中洲炼蛊大会、石莲岛与红莲真传争夺、天庭入侵琅琊福地。
- 接通 `world/heavenly-court.md`、`characters/red-lotus.md`、`events/fate-war.md`、`characters/fang-yuan.md` 与 `events/index.md` 的反向链接，清掉 `heavenly-court.md` 里的 3 条"待建立"。

## Task 3（Batch 5）：坚持主题簇

- 新增人物页 `characters/yuan-lian-xian-zun.md` 与蛊虫页 `gu/persistence-gu.md`，接通 `themes/persistence.md`，清掉其中 2 条"待建立"。
- 注意：坚持仙蛊与"坚持"主题要区分开写，典故与人物关系必须有来源。

## Task 4：验收与记录

- 每批结束运行 `check.ps1`、`git diff --check`，把结果写入 `lore/wiki/log.md`。
- 批次完成即提交；不推送，等协调方验收。
