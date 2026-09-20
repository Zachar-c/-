# L2 → L1 Visual Task Packet · 月光蛊 Visual Proof of Concept

```yaml
TASK ID: V2-POC-01-MOONLIGHT
STATUS: DRAFT / BLOCKED_ON_L0_VISUAL_BIBLE_DECISION
TYPE: Visual Proof of Concept
LEVEL: 视觉方向验证
SUPERSEDES: ai-system/tasks/visual-v2-01-moonlight-canonical-task.md
PROVIDER: GPT Image only，且必须在 L1 Prompt 审查通过后启用
OUTPUT_MODE: 单样本；前一样本通过后才允许下一样本
ASSET_STATUS: NOT A PRODUCTION ASSET / NO ASSET LIBRARY ENTRY
EXECUTION_ORDER: 视觉定位决策与视觉规范冻结之后
```

> 本任务不是 Canonical Asset Production，不建立资产库，不修改 `game/`。
> 目的是用最少样本验证三件事：
>
> 1. 原著约束能否转化为视觉；
> 2. GPT Image 是否适合作为主要生产工具；
> 3. 本体层 / 主题层是否具有可区分的表达空间。

## 工作流位置

```text
WORKFLOW ROLE:
L2 → L1

UPSTREAM:
L0 视觉方向校准 + L1 视觉定位决策

DOWNSTREAM:
L1 Prompt 审查 → GPT Image 单样本生成 → L0 / L1 判定

CURRENT PHASE:
视觉方向验证
```

## 一、硬前置

执行前必须同时满足：

```text
1. L0《问真》视觉定位 v1.0 已冻结；
2. L0 已批准并冻结《问真》视觉圣经 v1.0；
3. 冻结后的视觉定位与视觉圣经已写入本任务输入；
4. L1 已审查并确认最终 Prompt；
5. 工具为 GPT Image；
6. 生图数量为 1；
7. 输出被标记为 POC，不进入正式资产池。
```

本任务不得先于视觉圣经批准执行。阶段优先级见：

```text
docs/superpowers/specs/2026-09-20-wenzhen-visual-stage-priority-decision.md
```

当前状态：

```text
新视觉定位输入：APPROVED / FROZEN
视觉圣经输入：L1 CANDIDATE / AWAITING L0
Prompt 最终审查：NOT STARTED
图像生成：HOLD
```

禁止用旧水墨 / 纸面 / 朱砂资产，或 `game/wenzhen-web/docs/2026-09-18-handoff.md`
中的 Web 实验方向，自动替代已冻结的 L0 视觉定位。

## 二、POC 门禁

### Gate 1 · 本体层单样本

只生成 1 张。

验证：

```text
1. 弯月、蓝水晶质感、小型生命体尺度是否被正确表达；
2. 催动月刃是否没有被误画成本体器官；
3. GPT Image 是否能稳定跟随 HARD / SOFT / OPEN 约束；
4. 新视觉定位是否能在本体层成立。
```

通过条件：

```text
本体识别成立
+ 原著身份未被替换
+ 新视觉定位可判断
+ Prompt 约束真实生效
```

### Gate 2 · 主题层单样本

只有 Gate 1 通过后才允许开启。

只生成 1 张。

验证：

```text
1. 主题层是否能形成角色级表达空间；
2. 角色化表达是否仍能追溯到月光蛊本体；
3. 主题层是否明确是幻想表现，而不是世界事实；
4. 是否避免退化为无对象来源的通用角色模板。
```

主题方向、角色化程度与具体视觉命题由 L1 基于已冻结的新视觉定位填写；L2 不预选。

## 三、对象事实

### 蛊名

```text
月光蛊
```

### 原著身份

```text
一转月道攻击型蛊虫，古月一族标志蛊虫。
催动后发出月刃攻击；可参与月芒蛊等合炼路线。
```

### 原著视觉证据

```text
L1826「月光蛊静静地躺在方源的掌心中，就好像一个弯弯的蓝色月亮」
L1836「月光蛊就像是一片弯弯的月牙」
L1844「蓝水晶一样的月光蛊表面」
L1494「只占据掌心一块，如寻常玉坠大小」
```

### CANON CONSTRAINT

```text
HARD:
弯月形态、蓝水晶质感、古月一族标志级身份。

SOFT:
内部晶体结构、表面纹理、边缘细节、灵气流动、微距质感与背景处理。

OPEN:
微观发光结构、少量月辉与悬浮粒子等原著未规定的细节。
```

## 四、固定边界

### 必须保留

```text
1. 弯月核心轮廓；
2. 蓝水晶 / 玉质类通透感；
3. 小型生命体尺度；
4. 一眼能识别为“活着的蛊”，不是武器或纯装饰；
5. 月刃属于催动表现，不属于本体器官。
```

### 禁止

```text
1. 不允许批量扩展；
2. 不允许建立资产库；
3. 不允许修改 game/ 下的脚本、场景、数据或资源；
4. 不允许把 POC 图登记为正式资产；
5. 不允许在首个样本未通过时继续生成第二个样本；
6. 不允许用旧视觉资产证明新视觉方向成立；
7. 不允许把主题层当作本体层替代。
```

## 五、Prompt Draft

以下只是待 L1 审查的骨架。
`[NEW VISUAL POSITIONING BLOCK]` 必须由已冻结的新视觉定位替换；
在替换前不得提交 GPT Image 生成。

```text
[NEW VISUAL POSITIONING BLOCK]

对象：月光蛊。
层级：本体层 Visual Proof of Concept，不是正式资产，不是主题层角色。

原著核心：
弯月形态，蓝水晶或玉质通透感，小型生命体，掌心或玉坠尺度。
月刃是催动表现，不是本体器官。

画面：
单个本体，主体居中，极简背景，清晰展示弯月轮廓、材质与生命感。
不得加入人物、角色服饰、武器化代替本体、满屏特效或文字。

输出目的：
验证原著约束能否转化为视觉，并验证 GPT Image 能否稳定跟随约束。
```

Gate 2 的主题层 Prompt 在 Gate 1 通过后另写，不得预生成。

## 六、L1 审查区域

```text
通过 / 修改 / 驳回

新视觉定位输入：

主要问题：

L1 修改建议：

最终 Prompt（Gate 1）：

是否允许进入 GPT Image 生成：
YES / NO
```

## 七、生成记录

```makefile
Provider: GPT Image
Gate: 1 / 2
样本数: 1

Prompt 版本:

结果:

本体识别:
新视觉定位成立:
GPT Image 约束跟随:
POC 通过:
YES / NO

不通过则停止，不生成下一样本。
```

## 八、返回格式

```text
STATUS:
CHANGED:
FOUND:
EVIDENCE:
TESTS:
RISKS:
QUESTIONS:
```

## 九、停止条件

```text
新视觉定位未冻结
L1 未审查 Prompt
Provider 不是 GPT Image
要求生成多于 1 张
要求进入资产库
要求修改游戏资源
要求扩展到其他蛊
```

出现任一条即停止并上报 L2。
