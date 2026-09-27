# 休眠文档资产索引（dormant-registry）

> 2026-09-25 冻结死档审计建立：全仓 45 份带「冻结 / 唯一依据 / 权威」标记且已死的文档中，26 份沉默死去（无任何废弃标记）。经 L0 确认这些文档的价值多数还在——死因是门禁未开、载体换血或批次阻塞，不是内容错误。
>
> **本文件是索引，不是权威**：登记可回收内容、换基前提与目标落点；不恢复任何旧文档的「唯一依据」地位。
> 使用纪律：设计类复用走取证 → 蒸馏 → L1 评审（根 `AGENTS.md` 设计顺序）；数值内容不得直接进 `game/data`；复用时引用原文并标注换基结果。

## A 档 · 内容仍是现行真值（4 份，2026-09-25 已落地）

| 路径 | 可回收内容 | 落地动作 |
|---|---|---|
| `game/wenzhen-web-lab/docs/2026-09-21-v4-calibration-handoff.md` | V4.1 冻结裁定与校准数值（至今是 lab 战斗核真值） | 事实索引已迁至 [`game/wenzhen-web-lab/docs/V4-CALIBRATION-STATE.md`](../game/wenzhen-web-lab/docs/V4-CALIBRATION-STATE.md)；原文件加归档头，降为历史记录 |
| `ai-system/tasks/p3b1-role-curves.md` | 六条 role 转数曲线任务底稿（权威链 RUL-008/011 + P2 预算未变） | 已挂回批B（role curves 批；与 Phase 8 批B「×3 真元曲线」是两个批，后者 PENDING_L1）：`TODO.md` NEXT 指向本包为批B 解锁底稿；包内 Godot=Canonical 前提加注换基；2026-09-25 L0 Q2 裁定：真源落 `game/data/balance.json` `effect_budget.default_amount_by_role`、`v1_battle.json` 只存 role→kind（包内注记已同步）。**2026-09-26 收敛改写**：数据面（①–④）已随 P2 批落地，包体改写为批B 剩余面——换基激活 + Enemy HP envelope 重推导 + ⑤ encounter 窗口验收；前置已满足：lab 公式投影 policy 由 L1 裁定（[RUL-2026-09-26-001](../game/world-model/rulings/RUL-2026-09-26-001.json) RULED，policy=`sqrt_budget_scalar_projection_v1`）；**同日已执行完毕**（换基+敌方压缩表重基+MVP 五字段重基+envelope 重推导，check_projection 60/60、check_balance 49/49、测试 263/264、真实整局 victory；结果包 [p3b1-role-curves-result.md](../ai-system/tasks/p3b1-role-curves-result.md)）；旧 §A–§D 见 git 历史 |
| `docs/art/decisions/2026-09-20-moonlight-visual-freeze.md` | 月光蛊视觉冻结方向（与 L0 09-24「美术可原创」一致） | 文件内登记为**美术线重启入口** |
| `docs/art/standards/2026-09-20-moonlight-visual-alignment-sheet.md` | 配套统一美术对齐单 | 随月光冻结件一并作为重启入口 |

## B 档 · 方法/模型可移植，须换基（11 份，待复用）

> 其中 Q1–Q4 数值/架构件的换基判断已于 2026-09-25 由 L0 直接裁定（[`game/world-model/rulings/RUL-2026-09-25-001.json`](../game/world-model/rulings/RUL-2026-09-25-001.json)；裁定全文见[评审件 ANSWER 节](../ai-system/RESEARCH-REQUEST-2026-09-25-dormant-asset-rebase.md)）：Q1-A' 效果语法按节采纳并撤销 FINAL、Q2 曲线真源入 balance.json、Q3 魂模型先刷新再重派、Q4 conformance 恢复并反转基准。视觉类 6 件复用门禁仍在 L0。

| 路径 | 可回收内容 | 换基前提 | 目标落点 |
|---|---|---|---|
| `game/docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md` | 效果语义模型：六层执行管线、5 操作、3 修饰符、触发器、selector、最小引擎改动清单 | **已裁决（Q1-A'）**：执行语义与事务纪律升级为 Effect Execution Contract；5 操作降为 V1 最小 verb 集，新增 verb 走 Canon→Semantics→verb；Executor 禁隐藏 Rank 倍率（文件 FINAL 地位已撤销注记） | lab 效果层 / 数据模型设计输入 |
| `game/docs/q8/Q8_12_GU_VERTICAL_SLICE.md` | 效果语法纵切蓝图 | **已裁决（Q1-A'）**：执行语义已采纳，切片蓝图随 Effect Execution Contract 复用 | lab 垂直切片计划 |
| `ai-system/RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md` | 魂轴数值模型（368 行，自足件，原文逐条取证） | **已裁决（Q3）**：先按 lab-run-v2 事实刷新（soul 字段/上限、AP 实读、增长/死亡入口、存档/战斗/魂道蛊入口、旧 A/B 两套残留）再重派；RUL-004~007 设计原则有效；旧矛盾仍在时按 S1–S5（foundation/integrity 分离先行）。**事实刷新已落盘（2026-09-26）**：[RESEARCH-REQUEST-2026-09-26-soul-axis-fact-refresh.md](../ai-system/RESEARCH-REQUEST-2026-09-26-soul-axis-fact-refresh.md)，READY_FOR_L1_REDISPATCH（旧件 §4/§4.7 已标注为旧载体历史数据，不得作重派输入） | 魂数值线启动时的设计底稿；重派包裹=刷新件+旧件 §3/§6/§7/§8 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-bible-v1.md` | 686 行视觉规范本体：本体层/主题层、生命感/代价感规则、HARD/SOFT/OPEN 映射 | L0 批准或改版（差的只是一笔决议） | 美术线重启的方法层规范 |
| `ai-system/RESEARCH-REQUEST-2026-09-20-wenzhen-visual-bible-v1.md` | 视觉圣经方法论任务书 | 同上 | 同上 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-prompt-spec-v1.md` | Prompt 工程框架 | 重锚定现有五境 scene 素材 | 美术 Prompt 批次 |
| `ai-system/tasks/visual-v2-quick-validation-plan.md` | 「单样本 POC 先行、不批量生产」验证方法论 | A/B 轨语境重写 | 美术验证批 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-stage-priority-decision.md` | 阶段顺序逻辑（定位→规范→POC→结构适配） | 状态表作废，顺序重审 | 美术线排期参考 |
| `game/world-model/rulings/RUL-2026-09-19-010.json`（机制遗产） | conformance cases 机制：防「双线手抄漂移」 | **已裁决（Q4）**：conformance 立即恢复，基准反转为 game/data / Game Semantics → generated Web data → Web Runtime；落盘 `RUL-2026-09-25-001`（supersedes 其不变量）；第一批 C1–C5 已定 | lab ↔ game/data 一致性测试设计 |
| `game/docs/superpowers/specs/2026-09-16-rogue-layer-temperament-spec.md` | 肉鸽层性向设计 | pacing 红线裁定 + Web 版是否立项肉鸽层，两个裁定先补 | 肉鸽层 backlog |
| `game/docs/superpowers/plans/2026-09-20-wenzhen-v2-requirements-restructure.md` | 需求重构思路 | 剥离已被 09-24 裁定回答的「载体之问」 | 需求整理参考 |

## C 档 · 已被现实超越（11 份，存档不复活）

| 路径 | 不复用原因 |
|---|---|
| `ai-system/reviews/phase2-worker-001.md` | 补丁已被 main 重新实现（commit `0278f6a6`） |
| `ai-system/reviews/phase2-worker-002.md` | 同上（分支 `ee19c0ee` 历史收编） |
| `ai-system/REVIEW-SUBMISSION.md` | 结构批评已被后续审计（v4-structural-blockers、code-drift）覆盖 |
| `game/MODULE-INVENTORY.md` | 09-05 事实基线过期；接口权威已是 `game/docs/contracts/module-interfaces/` |
| `game/docs/superpowers/plans/2026-09-05-architecture-refactor-master-plan.md` | 自身已取消 A2-A5，派发链被 09-06/09-09/09-17 系列接管 |
| `game/docs/superpowers/reports/2026-09-16-roguelike-audit-and-directions.md` | D1/D4/D7 已落 Godot；剩余方向菜单当 backlog 索引引用，不复活 |
| `game/docs/superpowers/reports/2026-09-16-roguelike-handover.md` | 交接语境死，仅记录价值 |
| `game/docs/superpowers/reports/2026-09-16-open-items-and-decisions.md` | 待办已被 `game/AGENTS.md` 当前待办节接手 |
| `game/docs/q8/Q8_GRAMMAR_DECISION_LOG.md` | R1→R2 决策史，存档价值 |
| `ai-system/tasks/visual-v3-handoff.md` | 一次性封装，内容已被定位冻结件与取证件吸收 |
| `ai-system/tasks/visual-direction-handoff-L1.md` | 被 `visual-report-v1-L1.md` 接替 |

## 待 L0 裁定（不计档）

- ~~`game/world-model/rulings/RUL-2026-09-19-010.json` 修订~~ **已裁定（2026-09-25）**：`RUL-2026-09-25-001` 反转基准关系（game/data / Game Semantics → generated Web data → Web Runtime）并 supersedes 其不变量；RUL-010 文件本体不改，作历史记录保留。
- `docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md`：APPROVED/FROZEN 但无取代件也无下游执行——撤销、消费或确认停摆，需 L0 一句话。
- 根目录孤儿《你是《问真》项目的最高级代码-产品审计员。.md》：零登记零引用，归档或删除。

## 死时有墓碑（19 份，仅备忘）

q8g 全组 6 份、`GU_EFFECT_GRAMMAR_V2.md`、`GU_EFFECT_GRAMMAR_V2_REVISED.md`、`2026-08-27-novel-to-game-phase-0-1`、`2026-09-16-world-model-correction-design`、`2026-09-20-visual-positioning-decision-v1`、`2026-09-22-lab-playable-game` 计划、`numeric-difficulty` RR、`visual-direction` RR、`moonlight-canonical-task`、`pilot-batch-plan`、`batch1-library`、`visual-v2a`、`ai-system/PRD.md`——均已有明文作废标记，不再逐份登记。
