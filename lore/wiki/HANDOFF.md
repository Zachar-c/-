# HANDOFF——Narrative Compiler 会话交接（2026-09-25）

> 本文件是 A 线会话交接文档：任何新会话读完本文件即可无状态接续。状态快照与三线车道见 [COORDINATION.md](COORDINATION.md)；批次史见 [log.md](log.md)；本文件只保留接续所需的最小协议与待办。

## 1. 一句话状态

《蛊真人》知识库（lore/wiki，Narrative Compiler v0.1）已完成：Schema v2.1 **转正**（L0 批准）、三验证簇 + 规则精蒸馏七页 + 哲学轴五批 + v2.2 条件③ check9（A 线）、B 线粗蒸馏八簇（+游戏数据 2 批，已交接）、C 线三弧收口（基准 50/50·49.5·50 在案，截止卷二终）；**64 笔提交未推送**；门禁 check1–9 全绿。

## 2. 必读文件（按序）

1. [AGENTS.md](AGENTS.md)——编辑约定与 **Schema v2.1 转正声明**（冻结条款、v2.2 迭代队列）
2. [COORDINATION.md](COORDINATION.md)——三线车道、共享页分区块规则、工作树协作五条
3. [retrospective-v0.1.md](retrospective-v0.1.md)——v0.1 阶段复盘（结论/教训/债务）
4. [schema-v2.1-l1-review.md](schema-v2.1-l1-review.md)——转正依据与 v2.2 队列（三项条件）
5. 本簇基准文件 `tools/benchmark-*.md` 与 [distillation-metrics.md](tools/distillation-metrics.md)

## 3. 协议速记（违反即返工）

- **来源纪律**：事实必须带 E-ID/行号锚点；笔记层级条目只进《资料整理》；某人认为 X ≠ 世界规则 X（认知标记 `[叙事|对话|信念|传闻]` × `[已核|推断|未决|已修正]`）。
- **断点纪律**：只引用 ≤437,061 行文本；断点后不补写。
- **L6 边界**：游戏数值/《问真》改编不入 lore/wiki。
- **原文边界**：不复制大段原文；`蛊真人-clean.txt`（UTF-8，437,060 行）与《人祖传》.txt 均为本地 gitignored。
- **提交**：`docs(wiki): <簇名>`；只 add 自己车道文件；pre-commit 需 fetch GitHub——网络被拦时先 `py -3 editorial/scripts/check_remote_base.py --NoFetch` 离线证明再 `--no-verify`（本会话已多次使用，均先证明）。
- **共享文件**：log.md / COORDINATION.md / 各 index 用 shell 原子追加或改前必 `git diff`；rules/index.md 归 A 线（曾被并行管线两次清空）。
- **推送**：全部未推送，推送 `github/master` 需 L0 发话（网络不稳时同样有既定通道）。

## 4. 三线车道（速记，权威版见 COORDINATION）

- **A（本会话）**：规则精蒸馏。已完成：灾劫 TRIB / 道痕 DM / 炼蛊术语 REF / 杀招 KM / 流派境界 PR / 尊者 VEN / 梦道 DRM 七页 + soul-path 深度表 + 哲学轴五批（philosophy.md）+ v2.2 条件③ check9（E-ID 段号自动校验，历史失配 50 处已修正）+ v2.2 条件② 口径调和（TRIB-002/014、PR-002/003）+ v2.2 条件① 基准机制化（benchmark-pool；RULES 独立题集首测 24.5/50）+ L0 指令批：蛊虫总表三期精蒸馏（roster-3，270 蛊转数层）+ 游戏桥接层 gu_lore.json。候选：蛊虫扩容批（117 未核转数+18 碰撞+19 分叉 game 侧裁定）、规则七页扩容批（按 benchmark-rules.md 缺口清单 24 项闭缺）、成尊四条件集齐（菇人乐土弧逐段，取证地图在 venerables.md 待核对）、人心/棋盘轴续挖、尊者页 benchmark。阵道外流派能力标尺、成尊四条件集齐（菇人乐土弧逐段）、人心/棋盘轴续挖、尊者页 benchmark。
- **B（粗蒸馏）**：十三簇全绿 + 游戏数据两批（敌人模型 b4614cc、蛊目录清洗 a321260）；已交接 [HANDOFF-B.md](HANDOFF-B.md)，转按需维护；rules/ 归 A 不动。
- **C（剧情顺序）**：本轮已收口于卷二终——WTC ✅ 50/50 → CAR ✅ 49.5/50 → TKF ✅ 50/50（三簇全绿）；接续入口见 [HANDOFF-C.md](HANDOFF-C.md)。

## 5. 待办与队列

- **v2.2 迭代队列（转正条件）**：①基准题目池轮换与独立出题机制化 ✅（2026-09-25 落地：benchmark-pool.md 角色分离协议+轮换登记表；RULES 七页 GEN-1 独立题集首测 24.5/50 FAIL——同源高分膨胀被证实，缺口清单 24 项见 benchmark-rules.md） ②规则口径调和专项 ✅（2026-09-25：TRIB-002/014 与 PR-002/003 已调和，18 次判为原文笔误、30=名义口径、四五十=统计均值）③check9 E-ID 段号自动校验 ✅（2026-09-25 落地：全库审计 794 个 E-ID，历史段号失配 50 处同步修正）。
- **A 线候选**：见第 4 节；另有人祖传寓言全篇逐段核验、400k+ 棋盘隐喻后文。
- **C 线**：本轮已收口（WTC/CAR/TKF 三簇全绿，截止卷二终）；下一轮弧五·王庭之争，接续见 [HANDOFF-C.md](HANDOFF-C.md)。
- **跨线**：推送 64 笔（L0 发话）；`measure_distillation.py` 随窗口扩张重跑（C 线 WTC/CAR/TKF 三簇待纳入）；canon-index 并档受 `game/` 冻结（L0 裁量）。

## 6. 已知坑（新会话必读）

1. `蛊真人-clean.txt` 编码 UTF-8；`蛊真人.txt` 为 UTF-16 无换行——一律用 clean 版。
2. 节号按卷重置、非全局唯一——引用一律以**行号**为主锚点，节#N（见 source/section-index.md）仅作人文定位。
3. 原文行号与读书笔记行号是两套体系，笔记锚点（如"G 的 312128"）**不可直接当小说行号用**（已发生一例失配）。
4. check.ps1 的 check6 会拦未登记索引的新页——新页必须同批登记分类 index。
5. E-ID 段号（V1–V6）按六段表（source/section-index.md）校正，跨段引用易错——check9 已进门禁自动校验（段 N 行域=[本段首节起始行，下一段首节起始行-1]，段六延伸至原文末行）。
6. 三线共用同一 checkout——开工先 `git status --short -- lore/wiki` 分辨他人改动，只 add 自己文件。

## 7. 快速命令

```
pwsh -NoProfile -File lore/wiki/tools/check.ps1     # 门禁（check1–9）
py -3 lore/wiki/tools/build_section_index.py         # 重建卷节索引（原文变更后必跑）
py -3 lore/wiki/tools/measure_distillation.py        # 蒸馏率指标（tokenizer: tiktoken cl100k）
py -3 editorial/scripts/check_remote_base.py --NoFetch  # 离线门禁证明（网络被拦时先跑）
```
