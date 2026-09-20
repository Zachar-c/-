# RESEARCH REQUEST ·《问真》视觉圣经 v1.0

> 日期：2026-09-20
> 发起：L2 Orchestrator（Codex）
> 上游输入：L0 已冻结《问真》视觉定位 v1.0
> 送审：L1（ChatGPT）
> 后续裁决：L0
> 当前阶段：视觉方向已冻结，进入视觉规范建立
> 资产生产：HOLD
>
> **STATUS: ANSWERED / AWAITING_L0_DECISION**
> L1 输出见 `docs/superpowers/specs/2026-09-20-wenzhen-visual-bible-v1.md`。
> 该件仍为候选，L0 三项决策关闭前不启动月光蛊 POC。

## CURRENT PHASE

L0 已批准：

```text
世界定位：
规则生命收藏世界

本体层：
规则炼成世界

主题层：
超凡收藏世界

文明模拟：
未来扩展，不是当前视觉母方向
```

当前不生成图片，不准备逐只蛊资产。

本件的唯一目标，是请求 L1 产出能够约束后续所有视觉任务的《问真》视觉圣经 v1.0。

## QUESTION

在已冻结的视觉定位下，如何建立一套统一、可审查、可执行的视觉规范，使后续本体层、主题层、UI、场景和 Prompt 任务不会重新发散？

需要回答的不是“最终画风”，而是：

```text
哪些视觉规律必须跨资产稳定？
哪些视觉元素属于本体身份？
哪些属于主题表达？
哪些属于材质、光影、构图的方法层？
如何验收“符合问真”而不是“看起来像普通仙侠”？
```

## WHY CODEX CANNOT DECIDE

- 视觉母方向已由 L0 冻结，但方法层的统一仍需 L1 建立。
- 若 L2 自行编写材质、光影、构图规则，会把实现细节提升为产品事实。
- 若 Worker 自行填写 Prompt 规则，会出现一只蛊一个视觉世界观。
- 本件会影响后续本体层、主题层、UI 和场景的统一性，属于高阶视觉建模，不由 L2 代决。

## KNOWN FACTS

### 已生效上游

- `docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md`
- `docs/superpowers/specs/2026-09-20-wenzhen-gu-dual-layer-visual-design.md`
- `docs/superpowers/specs/2026-09-20-wenzhen-gu-hard-soft-binding-decision.md`
- `docs/superpowers/specs/2026-09-20-wenzhen-visual-stage-priority-decision.md`

### 已冻结边界

- 本体层是世界真实性层，主题层是玩家表达层。
- 主题皮肤不得替代本体身份。
- HARD 改动会改变对象身份。
- SOFT 可以重演，OPEN 可以原创，但都必须维持能力、流派和世界逻辑。
- 正式资产不得批量生产。
- 所有 AI 生图必须经过 L1 Prompt 审查，并使用 GPT Image。
- P0 只验证月光蛊：本体是否成立，主题是否成立。

## CONSTRAINTS

- 不输出最终画风名称；
- 不推荐配色方案；
- 不推荐 UI 方案；
- 不推荐具体角色造型；
- 不输出正式资产清单；
- 不重新讨论 v3 已确认的 HARD / SOFT / OPEN 事实；
- 不把文明模拟层提升为当前视觉母方向；
- 不修改游戏数值、规则、架构或 `game/` 资源。

## DELIVERABLE

请 L1 产出：

```text
《问真》视觉圣经 v1.0
```

至少包含以下八节：

1. 世界视觉核心原则；
2. 本体层规范；
3. 主题层规范；
4. 材质语言；
5. 光影语言；
6. 构图规则；
7. Prompt 规范；
8. 资产验收标准。

每节必须说明：

- 它约束的是什么；
- 它不约束什么；
- 如何映射到 `HARD / SOFT / OPEN`；
- 如何区分本体层与主题层；
- 如何避免普通仙侠模板、无来源角色化和旧水墨方案回潮。

## EXPECTED OUTPUT FORMAT

```text
STATUS:
READY_FOR_L0_DECISION

VISUAL_BIBLE:
1. 世界视觉核心原则
   - 必须稳定：
   - 允许变化：
   - 禁止回潮：
   - HARD / SOFT / OPEN 映射：

2. 本体层规范
   - 识别规则：
   - 材质与结构规则：
   - 生命感规则：
   - 代价感规则：

3. 主题层规范
   - 人格化边界：
   - 来源识别规则：
   - 幻想表现标识：
   - 禁止事项：

4. 材质语言
5. 光影语言
6. 构图规则
7. Prompt 规范
8. 资产验收标准

L0_DECISIONS:
<需要用户批准或修改的最少问题>

DO_NOT_ASSUME:
<哪些内容仍不能进入生产>
```

## NEXT GATE

视觉圣经通过 L0 后，才允许：

```text
L2 准备月光蛊 Prompt Task Packet
→ L1 审查 Prompt
→ GPT Image 单样本 POC
→ 单样本通过后才允许下一步
```
