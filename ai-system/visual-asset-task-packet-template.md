# L2 → L1 Visual Task Packet Template

> **STATUS: TEMPLATE ONLY / NO ACTIVE TASKS**
>
> 当前阶段先做视觉方向验证，不批量生成正式资产。本模板只用于单个 POC 或单个正式任务。

> 用于所有正式蛊虫视觉任务。每个任务只包含一个对象、一个资产类型。
> 旧术语“C 档”统一写作 `Theme Skin Asset`，不恢复 A/B/C 生产档。

```text
TASK ID:

对象:

任务级别:
Visual Proof of Concept | Production Asset

资产类型:
Canonical Asset | Theme Skin Asset

新视觉定位输入:
<已冻结的 L1 / L0 视觉定位件；POC 必填>

视觉圣经输入:
<已批准的《问真》视觉圣经版本；生成前必填>

用途:
概念验证 | 角色立绘 | 收藏皮肤 | 宣传图 | 卡面

优先级:
```

POC 硬限制：

```text
1. 一次只生成一个样本；
2. L1 必须先审查 Prompt；
3. Provider 只允许 GPT Image；
4. 单样本通过后才能扩展；
5. 不进入资产库；
6. 不修改 game/ 资源或代码。
```

## 一、对象信息

### 蛊名称

```text
<蛊名称>
```

### 原著身份

```text
它是什么？
它解决什么问题？
它代表什么力量？
```

## 二、本体约束

### 必须保留

```text
1.
2.
3.
```

### HARD

```text
不可改变：
```

### SOFT

```text
可重新表达：
```

### OPEN

```text
原著没有限定、允许自由发挥：
```

## 三、主题层目标

> `Canonical Asset` 填写 `不适用`。

### 希望玩家感受到

```text
圣洁 / 危险 / 孤独 / 高贵 / 疯狂 / 诱惑 / 灵性 / 压迫 / 寄生感
```

### 人格化方向

不是：

```text
普通角色
```

而是：

```text
为什么这只蛊会成为这样的生命形态？
```

## 四、视觉要求

### 身体设计

```text
保留哪些蛊元素：
新增哪些人格元素：
```

### 材质

```text
玉 / 虫甲 / 晶体 / 血 / 骨 / 灵光 / 特殊组织
```

### 光影

```text
冷月 / 血色 / 幽光 / 神圣 / 压迫
```

### 构图

```text
全身 / 半身 / 立绘 / 卡面

主体位置：

展示重点：

背景复杂度：

视角：

输出比例：
```

## 五、本次视觉目标

### 要强调什么

```text
圣洁 / 危险 / 妖异 / 饥饿 / 高贵 / 压迫 / 灵性 / 诱惑 / 疯狂 / 寄生感
```

### 不要什么

```text
普通仙侠感
普通角色收集模板
失去原蛊识别度
无身份依据的材质与饰品
低级擦边
```

## 六、系列风格挂钩

```text
所属系列:
问真本体层 / 问真高完成度主题皮肤

必须统一的元素:
材质逻辑
饰品逻辑
光感逻辑
肌理精度
角色完成度
东方幻想基底
高级感 / 收藏感 / 可商业化

本次允许变化的点:
个体主题色
个体危险感
个体象征元素
```

参考规范：

```text
docs/superpowers/specs/2026-09-20-wenzhen-visual-prompt-spec-v1.md
docs/superpowers/specs/2026-09-20-wenzhen-gu-dual-layer-visual-design.md
docs/superpowers/specs/2026-09-20-wenzhen-gu-hard-soft-binding-decision.md
```

## 七、Prompt Draft

由 L2 填写，必须是完整 Prompt，不是关键词堆砌。

```text
[项目定位]

[对象]

[原蛊核心]

[人格化方向]

[角色设计]

[材质]

[光影]

[构图]

[质量要求]

[负面约束]
```

## 八、审查重点

L2 必须写明本次希望 L1 重点审查什么：

```text
1.
2.
3.
```

## 九、L2 提交前自检

```text
□ 能看出是哪只蛊
□ 没有脱离原著核心
□ 不是普通仙侠
□ 不是普通角色收集换脸
□ 有收藏价值
□ 符合问真统一风格
□ 已声明资产类型
□ 已写 Prompt Draft
□ 已写审查重点
```

## 十、L1 审查区域

```text
通过 / 修改 / 驳回

主要问题：

L1 修改建议：

最终 Prompt：
```

## 十一、生成记录

```makefile
Provider: GPT Image

版本:

样本数: 1

结果评价:

是否进入候选资产: YES / NO
是否需要下一样本: YES / NO

可固化规范:

仅本次个案:
```

## 十二、返回格式

```text
STATUS:
CHANGED:
FOUND:
EVIDENCE:
TESTS:
RISKS:
QUESTIONS:
```
