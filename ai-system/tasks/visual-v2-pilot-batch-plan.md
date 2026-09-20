# 《问真》蛊虫视觉 v2.0 · 首批验证批次计划

```yaml
STATUS: VOID / SUPERSEDED
SUPERSEDED_BY:
  - ai-system/tasks/visual-v2-quick-validation-plan.md
  - ai-system/tasks/visual-v2-01-moonlight-poc-task.md
UPSTREAM: L0《蛊虫双层表现体系 v2.0》
AUTHORITY: L2 任务规划；不改变产品优先级
PURPOSE: 验证 Canonical Asset → Theme Skin Asset 全链路
EXECUTION: 不执行
```

> 作废原因（L0 2026-09-20 更正）：当前阶段是原则验证，不应批量生产逐只蛊虫美术资产。
> 本计划保留为历史记录。后续先走现有资产、开源资源、复用组件和单屏快速视觉迭代。

## 一、批次目的

首批不验证“哪只蛊最值得商业化”，而是验证生产与验收链是否能同时处理：

- 明确本体；
- 生命型表达；
- 本体留白；
- HARD 识别；
- SOFT / OPEN 创造；
- 本体与主题皮肤分离。

完成首批后，L2 才能据此生成稳定的 Worker Task Packet，并判断筛选类别是否需要调整。

## 二、试点选择

### 试点 1：月光蛊

覆盖：

- A 类核心代表蛊；
- 已有稳定本体描写；
- 身份识别强；
- 同时有原著喂养、战斗、合炼关系。

验证重点：

- Canonical Asset 是否保持弯月、玉质/晶体、蓝光等身份特征；
- Theme Skin Asset 是否在角色化后仍能识别为月光蛊；
- 主题皮肤是否与本体独立存在。

原著证据入口：

- L1826：「就好像一个弯弯的蓝色月亮，小巧玲珑，晶莹剔透」
- L1494：「只占据掌心一块，如寻常玉坠大小」

### 试点 2：酒虫

覆盖：

- A 类核心代表蛊；
- 生命型；
- 早期高认知；
- 外形与能力关系明显，但不是复杂器物结构。

验证重点：

- 是否保留蚕形、珍珠白光和生命感；
- 是否避免把所有生命型主题都套成同一角色模板；
- 主题皮肤是否仍能解释其与酒、真元提纯和意志的关系。

原著证据入口：

- L2400：「酒虫体型如蚕宝宝，通体散发着珍珠一样的白光，有点胖胖的，外形很可爱」

### 试点 3：智慧蛊

覆盖：

- A 类核心代表蛊；
- 九转概念型；
- 本体外形未直接描写；
- 主要存在光效、状态与功能表现。

验证重点：

- 在 OPEN 区创造本体时，是否从功能、流派、能力逻辑、世界生态出发；
- 是否把智慧光晕误当成本体本身；
- 主题皮肤是否允许抽象人格化，同时不把角色误认为世界事实；
- 是否能明确区分本体层、表现层与主题层。

原著证据入口：

- L118878：「它能散发出智慧之光」
- L121500：「智慧蛊上闪烁了一下五彩的华光」

## 三、每只蛊的任务顺序

每只蛊按以下顺序执行，不并行跳过：

```text
1. L2 生成 Canonical Asset Task Packet + Prompt Draft
2. Worker（如需要）补齐原著证据
3. L1 审查 Prompt 并用 GPT Image 生成 Canonical Asset
4. L2 按 HARD/SOFT 判定表和系列一致性审阅
5. L2 生成 Theme Skin Asset Task Packet + Prompt Draft
6. L1 审查 Prompt 并用 GPT Image 生成 Theme Skin Asset
7. L2 按双层体系验收
```

原因：

主题皮肤必须引用已经通过审阅的本体，不能让主题层反过来定义本体。

每个任务包必须附：

- `Prompt Draft`；
- L1 审查重点；
- 系列风格挂钩；
- 明确的 `Canonical Asset / Theme Skin Asset` 类型。

Prompt 规范见 `docs/superpowers/specs/2026-09-20-wenzhen-visual-prompt-spec-v1.md`；
任务包模板见 `ai-system/visual-asset-task-packet-template.md`。

## 四、首批验收覆盖

| 验收项 | 月光蛊 | 酒虫 | 智慧蛊 |
| --- | --- | --- | --- |
| Canonical Asset | 必做 | 必做 | 必做 |
| Theme Skin Asset | 必做 | 必做 | 必做 |
| 身份识别 | HARD | 稳定本体 | OPEN 创造 |
| 能力语义 | 强 | 强 | 强 |
| 表现层分离 | 月刃表现 | 真元提纯表现 | 智慧光效 / 推算 |
| 主题人格化 | 允许 | 允许 | 允许 |
| 是否可直接替代本体 | 否 | 否 | 否 |

## 五、Worker 任务边界

- 每个 Task Packet 只包含一个蛊、一个资产类型。
- 不在同一任务中同时制作本体与主题皮肤。
- 不引入未经批准的风格、配色或跨蛊统一模板。
- 不修改游戏数值、能力、流派、配方和世界关系。
- 主题皮肤必须明确标记为幻想表现。
- 正式候选图只允许使用 GPT Image；其他工具只能用于参考、对比和非正式研究。

## 六、首批产物

1. 三份 Canonical Asset；
2. 三份对应 Theme Skin Asset；
3. 每份资产的证据、层归属、HARD/SOFT/OPEN 判定和验收记录；
4. 一份首批生产链复盘，只回答流程是否可行，不决定下一批商业优先级。

## 七、当前入口（历史）

本计划不得作为当前入口。

月光蛊的历史正式任务已作废：

- `ai-system/tasks/visual-v2-01-moonlight-canonical-task.md`

当前降级后的单样本 POC：

- `ai-system/tasks/visual-v2-01-moonlight-poc-task.md`
- 状态：`DRAFT / BLOCKED_ON_NEW_VISUAL_POSITIONING`
- 下一步：先冻结新视觉定位，再由 L1 审查 Prompt。

## 八、停止条件

出现以下任一情况时停止并上报：

- 本体证据与现有游戏数据冲突；
- HARD/SOFT 判定无法落入现有裁定表；
- 主题皮肤必须改变能力、流派或世界事实才能成立；
- 现有资产管线无法区分本体与主题；
- 试点要求扩容到其它蛊或整个游戏。

## 九、L0 保留事项

本批次只用于验证体系，不代表正式商业排序。

后续仍由 L0 决定：

- 首批正式主题蛊的最终名单；
- 主题层的解锁方式；
- 收藏展示与长期运营顺序；
- 是否按本批次结果扩大或收缩范围。
