# 休眠文档资产索引（dormant-registry）

> 2026-09-25 冻结死档审计建立：全仓 45 份带「冻结 / 唯一依据 / 权威」标记且已死的文档中，26 份沉默死去（无任何废弃标记）。经 L0 确认这些文档的价值多数还在——死因是门禁未开、载体换血或批次阻塞，不是内容错误。
>
> **本文件是索引，不是权威**：登记可回收内容、换基前提与目标落点；不恢复任何旧文档的「唯一依据」地位。
> 使用纪律：设计类复用走取证 → 蒸馏 → L1 评审（根 `AGENTS.md` 设计顺序）；数值内容不得直接进 `game/data`；复用时引用原文并标注换基结果。

## A 档 · 内容仍是现行真值（4 份，2026-09-25 已落地）

| 路径 | 可回收内容 | 落地动作 |
|---|---|---|
| `game/wenzhen-web-lab/docs/2026-09-21-v4-calibration-handoff.md` | V4.1 冻结裁定与校准数值（至今是 lab 战斗核真值） | 事实索引已迁至 [`game/wenzhen-web-lab/docs/V4-CALIBRATION-STATE.md`](../game/wenzhen-web-lab/docs/V4-CALIBRATION-STATE.md)；原文件加归档头，降为历史记录 |
| `ai-system/tasks/p3b1-role-curves.md` | 六条 role 转数曲线任务底稿（权威链 RUL-008/011 + P2 预算未变） | 已挂回 Phase 8 批B：`TODO.md` NEXT 指向本包为批B 解锁底稿；包内 Godot=Canonical 前提加注换基（落点改 Web 侧 balance.js/balance.json） |
| `docs/art/decisions/2026-09-20-moonlight-visual-freeze.md` | 月光蛊视觉冻结方向（与 L0 09-24「美术可原创」一致） | 文件内登记为**美术线重启入口** |
| `docs/art/standards/2026-09-20-moonlight-visual-alignment-sheet.md` | 配套统一美术对齐单 | 随月光冻结件一并作为重启入口 |

## B 档 · 方法/模型可移植，须换基（11 份，待复用）

> 其中 Q1–Q4 数值/架构件的换基判断已上抛 L1：[`ai-system/RESEARCH-REQUEST-2026-09-25-dormant-asset-rebase.md`](../ai-system/RESEARCH-REQUEST-2026-09-25-dormant-asset-rebase.md)（PENDING_L1）；视觉类 6 件复用门禁在 L0，不在该评审件内。

| 路径 | 可回收内容 | 换基前提 | 目标落点 |
|---|---|---|---|
| `game/docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md` | 效果语义模型：六层执行管线、5 操作、3 修饰符、触发器、selector、最小引擎改动清单 | 缩放段按 RUL-2026-09-19-008（转数=能力层级轴，非万能倍率）与 011（sqrt 律）重写；采纳=行为变更，过 L1/L0 | lab 效果层 / 数据模型设计输入 |
| `game/docs/q8/Q8_12_GU_VERTICAL_SLICE.md` | 效果语法纵切蓝图 | 语法复活后按 Web 载体重排 | lab 垂直切片计划 |
| `ai-system/RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md` | 魂轴数值模型（368 行，自足件，原文逐条取证） | 该件已吸收 RUL-2026-09-19-004~007，且是 RUL-006 明文「后置给 L1 研究院」的委托受件——从未被回答；重派前先按 lab-run-v2 复核其 §4 `[游戏]` 事实（评审件 Q3） | 魂数值线启动时的设计底稿 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-bible-v1.md` | 686 行视觉规范本体：本体层/主题层、生命感/代价感规则、HARD/SOFT/OPEN 映射 | L0 批准或改版（差的只是一笔决议） | 美术线重启的方法层规范 |
| `ai-system/RESEARCH-REQUEST-2026-09-20-wenzhen-visual-bible-v1.md` | 视觉圣经方法论任务书 | 同上 | 同上 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-prompt-spec-v1.md` | Prompt 工程框架 | 重锚定现有五境 scene 素材 | 美术 Prompt 批次 |
| `ai-system/tasks/visual-v2-quick-validation-plan.md` | 「单样本 POC 先行、不批量生产」验证方法论 | A/B 轨语境重写 | 美术验证批 |
| `docs/superpowers/specs/2026-09-20-wenzhen-visual-stage-priority-decision.md` | 阶段顺序逻辑（定位→规范→POC→结构适配） | 状态表作废，顺序重审 | 美术线排期参考 |
| `game/world-model/rulings/RUL-2026-09-19-010.json`（机制遗产） | conformance cases 机制：防「双线手抄漂移」 | L0 重裁（其 Godot=Canonical 不变量已被 09-24 载体裁定实际反转） | lab ↔ game/data 一致性测试设计 |
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

- `game/world-model/rulings/RUL-2026-09-19-010.json`：修订或废止其「Godot=Canonical、Web=Disposable Prototype」不变量（与 `PROJECT_MAP.md` 09-24 载体裁定直接矛盾，rulings 内无修订记录）。
- `docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md`：APPROVED/FROZEN 但无取代件也无下游执行——撤销、消费或确认停摆，需 L0 一句话。
- 根目录孤儿《你是《问真》项目的最高级代码-产品审计员。.md》：零登记零引用，归档或删除。

## 死时有墓碑（19 份，仅备忘）

q8g 全组 6 份、`GU_EFFECT_GRAMMAR_V2.md`、`GU_EFFECT_GRAMMAR_V2_REVISED.md`、`2026-08-27-novel-to-game-phase-0-1`、`2026-09-16-world-model-correction-design`、`2026-09-20-visual-positioning-decision-v1`、`2026-09-22-lab-playable-game` 计划、`numeric-difficulty` RR、`visual-direction` RR、`moonlight-canonical-task`、`pilot-batch-plan`、`batch1-library`、`visual-v2a`、`ai-system/PRD.md`——均已有明文作废标记，不再逐份登记。
