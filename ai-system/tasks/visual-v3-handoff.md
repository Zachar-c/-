# Caveman Review Packet · v3 视觉取证送审（L2 交接）

> 交接对象：下一个接手的会话/Agent。本件只写事实、证据、风险、决定。
> 生成：2026-09-20　｜　写件：L2 Orchestrator（Codex）

## L0 审阅结论（2026-09-20）

- v3-F 已获 L0 采用：性质从“素材与假说”确定为“约束边界”，核心交付是 `HARD / SOFT / OPEN` 自由度矩阵。
- 下一阶段不再继续泛化 Lore 取证；进入《问真视觉定位决策稿 v1》阶段。
- 视觉定位候选由 L1 产出，L0 裁决；L2 不代选方向。
- 新请求已写入 `ai-system/RESEARCH-REQUEST-2026-09-20-visual-positioning.md`。
- 需要分开两类 HARD：世界规则约束不可改；组织制度等对象的**视觉表达**仍按 v3 的 `SOFT / OPEN` 处理。
- 追加 L1 产出、L0 批准件：`docs/superpowers/specs/2026-09-20-wenzhen-gu-dual-layer-visual-design.md`；当前版本为 v2.0，统一采用“本体层 + 高完成度主题皮肤”，取消 A/B/C 人格化生产档。
- L2 一审：HARD/SOFT 裁定可直接作为解释层使用；三项产品事项已由 v2.0 关闭，HARD 主题皮肤仍须保持幻想标识、来源识别和本体独立存在。
- L1 已裁定双层体系与 v3 的 HARD / SOFT 绑定边界：`docs/superpowers/specs/2026-09-20-wenzhen-gu-hard-soft-binding-decision.md`；三项产品取舍已由 L0 在 v2.0 中关闭。当前只进入视觉方向验证与单样本 POC 规划，不进入批量正式资产生产。
- 视觉任务模板已更新：`ai-system/visual-asset-task-packet-template.md`；任务级别区分 `Visual Proof of Concept / Production Asset`，资产类型使用 `Canonical Asset / Theme Skin Asset`，并强制包含 Prompt Draft、审查重点与 GPT Image 生成记录。
- L2 维护的提示词规范草稿：`docs/superpowers/specs/2026-09-20-wenzhen-visual-prompt-spec-v1.md`；L1 审查后才升级为正式规范。
- 前版逐只资产试点已作废：`ai-system/tasks/visual-v2-pilot-batch-plan.md`；月光蛊正式任务包同步标为 `VOID / DO NOT EXECUTE`。
- 当前执行件：`ai-system/tasks/visual-v2-quick-validation-plan.md`；拆为 A 轨结构验证与 B 轨视觉验证。
- L0 2026-09-20 二次校准：当前既不是资产生产阶段，也不是单纯工程复用阶段；目标是验证新视觉方向是否成立。
- L1 追加 `PASS WITH REQUIRED ADJUSTMENT`：视觉定位决策是当前唯一最高优先级；A 轨结构验证可以存在，但不得成为主线。
- 阶段优先级决策件：`docs/superpowers/specs/2026-09-20-wenzhen-visual-stage-priority-decision.md`。
- L1 视觉定位候选已产出：`docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-decision-v1.md`；L0 已批准推荐方向。
- L0 冻结件：`docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md`；视觉定位状态 `APPROVED / FROZEN`。
- L1 已产出《问真》视觉圣经 v1.0：`docs/superpowers/specs/2026-09-20-wenzhen-visual-bible-v1.md`；状态 `READY_FOR_L0_DECISION`。
- 当前下一步不是 POC，而是等待 L0 批准并冻结视觉圣经：三项决策见该件 `L0_DECISIONS`。
- 强制顺序：视觉定位冻结 → L0 批准视觉圣经 v1.0 → 月光蛊 POC → 结构适配。
- A 轨可用旧资产做结构占位，但旧素材不能证明新视觉；B 轨必须使用已冻结的新视觉定位，并通过 L1 Prompt 审查后用 GPT Image 做单样本 POC。
- 月光蛊任务已从 `Canonical Asset Production` 降级为 `Visual Proof of Concept`：`ai-system/tasks/visual-v2-01-moonlight-poc-task.md`；不批量扩展、不建资产库、不改 `game/`。

```text
TASK visual-v3-L1（L1 视觉语义与设计自由度取证 v3 · 送审）
PHASE V2 需求重构期 · 视觉线（采集 L3 → 归纳 L2 → 裁决 L1 → 批准 L0）
STATUS READY_FOR_REVIEW（等 L1 回执）
TYPE content（原著取证 + 汇总，零代码改动）
ASK ① 送审件是否就这样发 L1；② v3 产物是否随本批提交；③ Godot 在途的 SIDE-FIX 是否补提交（属 L0）

GOAL
跑完 L1 的 v3 任务书（A–G 七子专题），交一份 L1 能直接读、且每条结论都能追到原文行号的
《视觉设计自由度矩阵》取证件。**范围外**：不做画风结论、不选方向、不排优先级、不提具体方案。

DELTA
+ ai-system/tasks/visual-v3-L1-core.md        32,842 字符｜**送 L1 的唯一粘贴件**（已复制到剪贴板）
+ ai-system/tasks/visual-v3-L1.md            189,075 字符｜= core + 10 个子包全文，供追溯
+ ai-system/tasks/visual-v3-final.md         七节终稿（684 行），core 的「甲」部分
+ ai-system/tasks/visual-v3-final-part1.md / -part2.md   两个汇总半件（已被终稿吸收，留作过程件）
+ ai-system/tasks/visual-v3-schema.md        公共约定（含 §0.7/§0.8 两条由本批缺陷反推出来的约定）
+ 10 个子包 + 11 个任务包                      见 FILES
+ game/wenzhen-web-lab/docs/2026-09-20-deepening-experiment.md  网页端实验计划（§3.5 覆盖页待更正清单）
+ ai-system/tasks/web-lab-s1-multi-enemy-task.md、web-lab-s1b-continuation-task.md  网页端 S1 包与续做包
~ game/wenzhen-web-lab/tools/build_data.mjs + js/data.js        S1 已完成的部分（encounters 抽取 + 覆盖页更正）
~ ai-system/tasks/visual-v3-schema.md                           新增后再改（补两条约定）
= 未变但已验证：Godot 线零改动（scripts/ / scenes/ / data/ / world-model/ 全部只读）

STATE
- opencode + muse-spark-1.3-contributor-free  ->  BLOCKED（免费额度用尽；2026-09-20 03:38 起派发秒退）
- WorkBuddy 四候选（normal 链）               ->  BLOCKED（choose-worker-model.ps1 报全部 worker-body-not-ready）
- 本会话内的子代理（Agent 工具）             ->  VERIFIED（剩余 4 个子包由它跑完，L0 当次批准）
- lore/wiki 门禁脚本                          ->  VERIFIED（ALL CHECKS PASSED）

FILES
ai-system/tasks/visual-v3-final.md                七节终稿（送审核心）
ai-system/tasks/visual-v3-L1-core.md              交给 L1 的粘贴件（＝使用说明 + 终稿）
ai-system/tasks/visual-v3-L1.md                   全量证据件（＝core + 10 子包）
ai-system/tasks/visual-v3a1-gu-form.md            蛊本体形态 一至三转（22 条）
ai-system/tasks/visual-v3a2-gu-form.md            蛊本体形态 四至五转（22 条）
ai-system/tasks/visual-v3a3-immortal-gu-form.md   蛊本体形态 六至九转仙蛊（25 条）
ai-system/tasks/visual-v3b1-gu-identity-rule.md   蛊的规则身份：外形↔功能（32 条）
ai-system/tasks/visual-v3c1-refine-and-killer-moves.md  炼蛊 17 + 杀招 22
ai-system/tasks/visual-v3c2-array-and-gu-house.md  蛊阵 16 + 蛊屋 15
ai-system/tasks/visual-v3d-five-regions-org.md     五域组织制度（25 条，五域各 5）
ai-system/tasks/visual-v3e1-power-display.md       力量表现 一至七转（27 例）
ai-system/tasks/visual-v3e2-power-display-high.md  力量表现 八至九转（27 例）
ai-system/tasks/visual-v3g-character-looks.md      人物外形（32 人，五域各 ≥3）

TEST
引文机检（程序化，含全书行号定位）：10 个子包 + 终稿全部 **0 未命中**
  终稿 214/214｜A1 63｜A2 104｜A3 113｜B1 202｜C1 55｜C2 385｜D1 65｜E1 221｜E2 277｜G1 167
残留「无锚点」共 6 处，全部是自查表里的占位文字「原文未提供」（非引文），已逐条确认
禁词扫描：0（唯一命中是“本批不含画风结论”这句**声明本身**）
wiki 门禁：pwsh -NoProfile -File lore/wiki/tools/check.ps1  ->  ALL CHECKS PASSED（39/39 概念页）
网页端：node tools/build_data.mjs  ->  gu 10 | recipes 6 | killMoves 3 | enemies 6 | encounters 10
        （另报 1 条已知漂移：thunder_crown_wolf 的 counter_status="sparked" 无规则实现）
diff-check：PASS（Godot 线零改动；用户两个在途测试文件未碰）

WORKER
10 个子包：6 包由 opencode worker 完成 + 4 包由 L2 子代理完成（额度用尽后，L0 当次批准）
core patch: NO｜tests: YES（机检）｜protocol: YES｜Codex takeover: implementation（仅 C2 收尾）｜independent: YES

RISK
- **执行器单点**：opencode 免费额度用尽后无可用候选；剩余工作只能靠 L2 子代理，消耗本会话额度。new，不阻塞本次交付。
- **Godot 侧 SIDE-FIX 已实现、已评审、未提交**：scripts/domain/v1_battle_resolver.gd（+139 行，phases 运行时 +
  焚元结算）、battle_command_facade.gd、tests/unit/test_enemy_phases_runtime.gd 与 test_enemy_data_runtime_contract.gd（均新增）。
  这是仓库卫生问题，与视觉线无关；但它也是网页端覆盖页第二条过时声明的来源（已登记在实验文档 §3.5）。
- C2 由子代理执行时撞轮次上限，交付物含 102 处未清理项（自造标签/术语引用混进「」），已由 L2 收尾：
  内容一字未删，只降级为直引号。new，已闭合。
- `counter_status="sparked"`（雷冠头狼）仍无实现语义。pre-existing（v2 阶段就报过）。
UNPROVEN
- 终稿第 1 节规律 7（人物无统一制服）属「未见」型结论，分母只有 G1 单包 32 人 -> 只能读作「本批未见」。
- 规律二/三/四/五/六 判「本轮证据不足以判定」，需另开定向批次（见终稿第 2 节 2a）。

GIT
status: 61 项未提交（其中 v3/视觉/网页端 48 项，其余 13 项是会话开始前就存在的在途改动）
commit: NONE｜merge: NONE｜push: NO
**送审件本身也未提交**。

DECISION
D1 送审件就这样发 L1？        | recommend YES | core 一次可粘贴（约 2 万 token）；全量证据件另存备查，L1 需要时再给
D2 v3 产物随本批提交？        | recommend YES | 建议一次独立提交：10 子包 + 终稿 + 送审件 + schema + 任务包
D3 Godot SIDE-FIX 补提交？    | 需 L0 定     | 已评审通过却一直躺在工作区；补提交纯属仓库卫生，不属视觉线

NEXT
1. 用户把剪贴板里的 visual-v3-L1-core.md 发给 L1，取回裁决
2. 三件待 L0 拍板的事项未定前不启动 P0 实施：载体 / 视觉方向（本送审件是它的取证件）/ 收缩授权
3. 网页端 S1 续做包已写好（ai-system/tasks/web-lab-s1b-continuation-task.md）：等额度恢复或另定执行器
STOP

## 本会话自身事故留痕（给下一个接手的人）

1. **裸数字锚点会打断机械工具链**：E2 用了 `296770「…」`（行号在前、无括号）这种写法，
   我的降级脚本只认 `（12345）` / `L12345` / `12345行`，于是把 **64 条真引文误降级**为直引号。
   已按「该行确有此句」精确还原 64 条并复核。**教训**：schema 已写死锚点三种合法写法（§0.8），
   下一批派包时要把这句放在包内显著位置，而不是只放公共约定里。
2. **机器可读 ≠ 语义正确**：本批 10 个包的引文全部 0 未命中，但仍有 107 处「把非原文写进引号」——
   机器只报了 14 处真缺陷，另外 107 处是**逐条读内容**才发现的。下一批验收两类都要跑。
3. **子代理也会撞轮次上限**：C2 就是撞在"最后清理引文"这一步，交付物带着 102 处未清理项回来。
   派子代理做长任务时，要在包内写「先写完全文再统一清理」，并把清理与产文分成两次交付。

EVIDENCE
ai-system/tasks/visual-v3-final.md（七节终稿；含第 3 节《视觉设计自由度矩阵》）
ai-system/tasks/visual-v3-L1-core.md（送审件＝使用说明 + 终稿）
每个子包末尾的「L2 机检记录」（含该包修了几处、修了什么）
```

## Lore 追加

```text
FACT（本批产出的关键原著事实，均在终稿与子包里带行号）
- `门派` 593 行 / `宗门` 5 行 / `家族` 2185 行 -> 中洲有成文门派制（师徒取代血缘，L62304）；
  「原著没有门派制度」是**词选假象**（当时只数了「宗门」）。
- 「蛊屋与核心蛊共生死」原文**不存在**；「同存亡」只写在**阵灵**身上（L265524）。
- 人形拟人型在 69 只蛊的本体形态里为 **0**（v2 样本那例「书生蛊」是幻化后形态，非本体）。
ANALYSIS
- 自由度矩阵：282 条记录，HARD 96 / SOFT 117 / OPEN 69。
  HARD 集中在炼蛊与杀招（配方即身份，30/39）；OPEN 集中在五域组织（17/25）与蛊阵外形（12/31）
  -> 原著在制度与关系层写得具体，在外观层大量留白。
UNCHECKED
- 规律二/三/四/五/六 未获本轮证据覆盖（终稿第 2 节 2a 已逐条标注）。
- 矿物型无法可靠统计：69 只里仅 4 只给了材质字段。
- 蛊的「用时之形」与本体形常不一致，本批按字段分别记录，未做统一建模。
```
