# 并行批次协调（Narrative Compiler v0.1）

> 本文件是三条并行工作线的批次划分与工作树协作规则，由各线在自己批次完成时更新状态行。这是操作层文件，不是知识规范。
> 线名裁定（2026-09-25，L0）：A＝全书复杂规则精蒸馏；B＝全书粗蒸馏；C＝全书按剧情顺序精蒸馏。历史条目中 WTC 狼潮簇曾标"B 线"，按本裁定更正为 C 线；本文件旧版把粗蒸馏线标为"C"，更正为"B"。

## 会话交接

- [HANDOFF.md](HANDOFF.md)（2026-09-25，A 线）：新会话/任一线的接续入口——协议速记、三线车道速记、待办队列、已知坑、快速命令。

## 活跃线与簇车道（2026-09-25 起）

| 线 | 簇车道 | 页面范围 | 状态 |
|---|---|---|---|
| A（全书复杂规则精蒸馏） | 验证簇：QMS ✅ → FATE ✅ → XQ ✅（三类达标，v2.1 冻结转正）→ **规则精蒸馏路线五站全部完成：灾劫体系 ✅（TRIB-001…014）→ 道痕体系 ✅（DM-001…015）→ 炼蛊术语体系 ✅（REF-001…012，新术语平炼）→ 杀招-连招-并招体系 ✅（KM-001…012）→ 流派境界五级 ✅（PR-001…011，原 T1 延期项已恢复完成）→ 梦道机制 ✅（DRM-001…010）** | rules/ 目录五页互链成网 + cultivation-system、aptitude-and-aperture、primeval-essence、world-operating-system、soul-path 的深度规则表 | **五站 ✅ 全部提交** + 哲学思考页 ✅（themes/philosophy.md，四组命题轴；B 线主题补全候选与本页重合部分由 A 线承接）+ v2.2 条件③ check9 ✅（E-ID 段号自动校验进门禁，历史段号失配 50 处已修正）+ v2.2 条件② 口径调和 ✅（TRIB-002/014 与 PR-002/003 已调和，18 次判为原文笔误）+ v2.2 条件① 基准机制化 ✅（benchmark-pool 角色分离协议+轮换登记；RULES 七页 GEN-1 独立题集首测 24.5/50 FAIL，缺口清单 24 项登记、扩容批为下批候选）+ **RULES 扩容批 ✅（2026-09-25：GEN-1 缺口 24 项闭缺 + GEN-2 独立出题轮换复测 48.5/50 PASS，残余缺口 2 项当场补录；TRIB-015…021/DM-019…021/REF-023…024/KM-019…020/PR-012…016/VEN-016…020/DRM-011…016；详见 log.md 与 benchmark-rules.md GEN-2 节）** + **P1 月光切片批 ✅（2026-09-25，RUL PRIO P1）：IR v0.2 states 入 runtime（G1/G2 转正）、编译阻塞清偿（REF-013/017/022 段号修正 + 全库 5 位锚点补齐 + check9 非 6 位拦截）、rules_page 31→51、runtime 基准独立盲测 19/19、web canon 链 14/14；GATE ② 切片达成；详见 log.md 与 P1-IR 文档 §6** + **P2 Semantics Ready ✅（2026-09-25，game 侧批）：Game Semantics 层落点 game/world-model/semantics/（执行契约+README）；Q2 真源迁移落地（balance.effect_budget 30 值、build_data 纯映射+显式投影 PROJ-LAB-ROLE-CURVE-001、MVP 例外登记 PROJ-LAB-MVP-GU-EXCEPTION-001）、gu_rules 未知 verb fail-fast（No Silent Fallback 冻结不变量落地）；批B 五条全过（tests/semantics.test.mjs、check_projection 47/47、check_balance 49/49）；v1_battle 瘦身延后 Godot 迁移批（debt 登记）** + **P3 Conformance Ready ✅（2026-09-26，RUL Q4）：C1–C5 断言落 tests/conformance.test.mjs（C1 切片生成一致性+全量显式效果防替换、C2 效果 Golden Cases 含事务纪律与确定性、C3 投影全条目 parent/forbidWriteBack 校验、C4 Canon binding 在案+防静默兜底+未知 verb 复合内外抛错、C5 canon_driven_v1 provenance 分类与引用可解析）；月光三蛊 source_class=canon_driven_v1 + CAN/E:V 引用种子入 gu.json** + **P4 Game Generation Ready ✅（2026-09-26）：月光 Rank1 切片 GATE 六条件全 PASS（判定文档 docs/design/canon-runtime/2026-09-26-p4-moonlight-slice-gate.md）；换皮测试自动化 tests/skin-test.test.mjs 4/4（行为可辨识/标签无关结算/关系按 id 绑定/无占位）；Derived Content Ratio 基线登记；P5 批量扩展解锁**+ L0 指令承接：蛊虫总表三期精蒸馏（gu/roster-3.md，游戏映射 270 蛊转数层，分叉报告 19+33+5+18）+ game 桥接层 gu_lore.json；后续候选：尊者资格链核验（PR-011）、阵道外流派能力标尺、梦道机制；炼蛊—杀招高价值规则簇增量补全 ✅（2026-09-25 Source-first 深蒸馏：REF-013…022 / KM-013…018 / DM-016…018——残方论·失败归因·工艺路线·转数上限·固化谱系；REF/KM 聚焦十题小型回归 9/10、缺口当场回原文补录；详见 log.md） |
| B（全书粗蒸馏，本线） | ROSTER ✅ → GU-ROSTER ✅ → PATH-ROSTER ✅ → DOMAIN ✅ → ECON ✅ → ORG ✅ → THEME ✅ → GAP-SWEEP ✅ → ROSTER-2 ✅ → 地图/杀招/蛊虫二期/敌人（MAP/KM/GU2/ENEMY）✅ → **游戏数据两批 ✅（b4614cc 敌人模型 / a321260 蛊目录清洗）→ 交接完成，转按需维护** | 交接文档见 [HANDOFF-B.md](HANDOFF-B.md)（车道文件清单、验证基线、未决清单、下一步候选均在其中） | 十三簇全绿 + 游戏数据 2 批 + 维护批 ✅（2026-09-25：交接未决三项清偿——紫山真君双源裁定、百足家/黑家同一性裁定、G 笔记 312xxx 锚点抽验否证"系统性偏移"）+ 经济加锚批 ✅（同日：元石↔仙元石价值下限/仙元石天庭发行垄断/战时货币替代已核；灵缘斋古派身份四源已核；"僵盟拍卖大会"订正为北原大会僵盟事件——剧情页弧七表述待 C 线订正）；js/data.js 重生成与 bank-only 敌人接入等并行游戏批收口；粗粒度抽样核验、无 benchmark；rules/ 归 A 线不动 + 覆盖度回填批 ✅（2026-09-25：审计 100 题缺口组 1–3 全部回原文闭缺＋组 4 顺带 Q64/Q94，翻案 15 题为有据、Q37/Q49 转题面前提待核；涉及 roster/roster-3 备注/kill-move-roster/west-desert/east-sea/aptitude/primeval/economy/longevity-heaven/characters-roster/fang-yuan/spring-autumn-cicada，处置与自测登记 benchmark-100q.md 回填批）+ 系统补强批 ✅（2026-09-26：按 L0 指示按五热点系统补全——268 命名杀招全书扫描总览、约 80 座具名仙蛊屋总表、十尊本命蛊/成尊流派/护道人制度、影宗卧底结局与天庭/疯魔窟终局锚定、年蛊四膜黄杏炼蛊大会等量化规则；发现并登记原文 377902–392286 重复段、"疯魔窟属北原"归属订正；约 25 题成绩升级详见 log.md 与 benchmark-100q.md 系统补强批） |
| C（全书按剧情顺序精蒸馏） | 狼潮/兽潮簇（WTC，原误标 B 线）✅（benchmark-wtc 50/50）→ 弧三·南疆商队与商家城（CAR 簇）✅（benchmark-car 49.5/50，EVT-CAR-001…044）→ 弧四·仙鹤门方正线与三王福地（TKF 簇）✅（benchmark-tkf 50/50，EVT-TKF-001…032）→ 弧五·王庭之争（RTC 簇）✅（benchmark-rtc 48/50 复测达标，EVT-RTC-001…120）→ 弧六·真阳楼崩塌与仙僵升仙（ZYL 簇）✅（benchmark-zyl 48.5/50 首测达标，EVT-ZYL-001…060；true-yang-collapse.md 新建为弧六枢纽页，段三 116,326–135,000 行弧六主线全程核验）| 交接文档见 [HANDOFF-C.md](HANDOFF-C.md)（五簇快照、工作法、待核对清偿清单、下一轮入口）；页面资产 events/wolf-tide、south-caravan、three-kings-mountain、royal-court、true-yang-collapse + world/beast-tide、south-jiang 增补 + tools/benchmark-wtc/car/tkf/rtc/zyl | **五簇全绿（50/49.5/50/48/48.5）；剧情时间线推进至段四节 86《终于有了智道传承》（135,000 行，繁星洞天探底）**；下一轮自弧七·僵盟潜伏与梦境三层（段四 135,001 行起，笔记 D1 域）开新簇 |

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

## 阶段复盘

- [Narrative Compiler v0.1 阶段复盘](retrospective-v0.1.md)（2026-09-25，A 线召集）：三线产出盘点、五套基准成绩、方法论结论、事故教训与下阶段行动项。**B/C 线会合确认进行中；L0 已批准转正（2026-09-25），v2.2 迭代队列三项条件见 [schema-v2.1-l1-review.md](schema-v2.1-l1-review.md) 第 6 节。**

## 门禁与冻结

- Schema v2.1 **已转正为长期格式**（L0 批准 2026-09-25，评审见 [schema-v2.1-l1-review.md](schema-v2.1-l1-review.md)；冻结条款与 L1 评审通道维持），三线共用 `tools/check.ps1` 门禁；各簇各有 `tools/benchmark-*.md` 回归题集。
- 星宿仙尊/龙公页当前归 A 线 FATE 簇后续核验引用范围，B 线如需引用按现有页面链接，不迁移不改动。
