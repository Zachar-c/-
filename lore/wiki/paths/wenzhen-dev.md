# 做《问真》

> 给开发：拿规则/数值边界与游戏数据分界，避免把改编当原著、把原著直接当数值。

## 给谁

做《问真》剧情、系统、美术、关卡的开发者——需要知道「哪些是原著事实、哪些是游戏裁定、改哪里要先问谁」。

## 你会得到什么

- 规则与数值的边界入口（能改什么、不能改什么）
- 原著层与游戏层的分界地图
- 数据/契约的落点与回查路径

读完后你知道一条需求该查哪张表、写回哪一层，以及什么情况必须上抛而不是自行决定。

## 怎么用本页

先读 **分层边界**，再按你要做的模块走对应清单。本 Wiki（`lore/wiki/`）是 L0–L5 原著知识层；**L6 改编与数值裁定不进本目录**，见 [Wiki 编辑约定](../AGENTS.md) 分层模型。

## 逐步阅读清单

### 一、分层边界（先读）

1. [Wiki 编辑约定](../AGENTS.md) —— L0–L5 / L6 分离规则；这条是所有开发动作的前置约束。
2. [原始资料入口](../source/README.md) 来源优先级节 —— 原著事实从哪来、改编不得伪装成原著。

### 二、规则/数值边界

3. [规则页索引](../rules/index.md) —— 成文规则簇（灾劫、道痕、炼蛊、杀招、境界、尊者、梦道）；实现机制前先对 claim 与禁止误读。
4. [修炼体系](../world/cultivation-system.md) + [空窍与资质](../world/aptitude-and-aperture.md) + [元海与真元](../world/primeval-essence.md) —— 成长曲线的原著边界；数值建模的事实底座。
5. [蛊虫、蛊方、炼蛊与杀招](../world/gu-refine-killer-chain.md) + [养蛊、用蛊与炼蛊](../world/gu-care-and-refinement.md) —— 蛊/炼/杀招关系链；战斗与合成系统的原著约束。
6. [经济与资源总表](../world/economy-roster.md) —— 货币层级与资源品类；经济系统不要越过原著层级拍脑袋。
7. [canon-index](../../../game/docs/lore/canon-index.md) —— CAN-* 命题登记表；与规则页互相链接，实现前逐条核对。

### 三、游戏数据分界

8. [game-rule-register](../../../game/docs/lore/game-rule-register.md) —— 游戏规则登记；查「这条是不是游戏裁定」。
9. [adaptation-register](../../../game/docs/lore/adaptation-register.md) —— 改编登记；原著→游戏的妥协与决定留痕处。
10. [蛊虫总表三期·游戏映射蛊精蒸馏](../gu/roster-3.md) —— gu.json 原著来源蛊的转数层核验与分叉报告；接 gu 数据先看这里。
11. [content-source-schema](../../../game/docs/lore/content-source-schema.md) —— 内容来源 schema；数据落库格式与来源标注。

### 四、验收与上抛

12. [文档治理](../../../docs/DOCUMENTATION_GOVERNANCE.md) —— 入库清单与门禁；改文档/导航后必跑。
13. `game/tools/check.ps1` + `lore/wiki/tools/check.ps1` —— 游戏与 Wiki 两侧门禁；Wiki 绿 ≠ 实现正确。

## 常见坑

- **把 L6 数值写进 Wiki**：本目录不放《问真》数值与改编裁定；写错层会污染原著事实。
- **把游戏效果写进原著事实区**：实体页「原著明确内容」只收逐段核验的事实；游戏效果在游戏侧登记。
- **自行决定产品/数值**：核心体验、阶段范围、数值与架构判定按变更协议上抛 L0/L1，不自行拍板。
- **Wiki 门禁绿当成实现正确**：内容门禁只管知识层；Runtime/Conformance 门禁另跑。
- **「待核对」当已解决**：缺口与冲突已登记在 `docs/debt.md` 与各页「待核对」；实现前先看是否被标 blocked/待裁定。

## 相关阅读路径

- [五分钟看懂世界](five-minute-world.md) —— 世界骨架不够。
- [跟上方源一生](follow-fang-yuan.md) —— 剧情节点与事件链。
- [同人写作](fanfic-writer.md) —— 人物动机/关系/限制视角。
- [查设定/证据](lore-researcher.md) —— 要精确原文锚点与争议裁决。
