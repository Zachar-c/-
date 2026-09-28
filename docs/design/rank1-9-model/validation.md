# 一至九转模型：可复算验证报告

日期：2026-09-27。由 [validate.mjs](validate.mjs) 生成；主说明见 [README](README.md)。仅验证此模型，不代表玩家体验或既有游戏验收。burst/balanced/sustain 是数值测试配置，不是已完成的流派蛊虫构筑；现有 69 蛊的构筑证据盘点见[库存关系](inventory-combinations.md)。

参数 SHA-256：`6df2f5776040f30ad788a210ea8fa367fa11f4350c72611db38ddf630ed45e57`。

## 规则与边界

- 通过：酒虫仅作一转真元品质提纯，不映射战斗回复
- 通过：九转与各阶仙元名称
- 通过：七到八转基准差距大于六到七，不制造晋阶道痕
- 通过：一至三转真元10倍不等于伤害10倍
- 通过：下位蛊不继承宿主的转数输出
- 通过：禁常规越阶催动，凡仙资源池分离
- 通过：道痕增幅与异道冲突边界
- 通过：六七八转灾劫次数和道痕守恒
- 通过：灾劫各级内部增长且不越级
- 通过：内外时间同向增加生产与灾劫；超过300年仍计时
- 通过：死窍不自产不招灾，九转周期不伪造已知
- 通过：仙蛊唯一和炼制概率上限
- 通过：升仙均衡成功、贪吸失败、失败不可逆、非法输入拒绝
- 通过：成尊多条件，不靠道痕或三次万劫自动晋升
- 通过：轮回保留知识，不保留属性；已知配方不稀释未知发现
- 通过：战斗确定性与资源边界
- 通过：买卖和失败残值无直接套利
- 通过：杀招心智容量和控制递减
- 通过：炼蛊交易原子性、投入消耗、本命蛊失败保留
- 通过：随机种子相邻不会集中在极窄区间
- 通过：基准筹备路线可以实际走通一至九转
- 通过：炼蛊Monte Carlo均值接近理论期望，95%分位检验尾概率
- 通过：载体战斗按种子确定，且与常规模板结果有差异
- 通过：soulBody 对常规动作减伤可观测，爆发类全额承伤
- 通过：guHouse 高耐受低输出，beastPack 群体衰减与范围收益
- 通过：灾劫实战口径与聚合代理返回同形，账本接口一致
- 通过：构筑审计：未知蛊、越阶、缺fallback、超心智容量、fallback强于本体全部登记
- 通过：供应解析：gu精确匹配优先于泛匹配，同级行内 first-match-wins，key_gu_missing 强制整局不可得
- 通过：availability 有界且不可刷：场景乘数截断到[0,1]，同一供应实例内同蛊判定恒定
- 通过：supply.json 数据边界：availability∈[0,1]，渠道与场景键合法

## 九转标尺

所有生命/伤害/概率都是游戏设计值。生命是战斗耐受，不是原著肉身实测。

|转数|仙元/真元|初始耐受|标准攻击|道痕起点→终点|准备后炼制率|完整周期灾劫事件|
|---|---|---:|---:|---|---:|---:|
|1|青铜真元|100|24|0→0|98.0%|0|
|2|赤铁真元|200|48|0→0|98.0%|0|
|3|白银真元|400|96|0→0|95.0%|0|
|4|黄金真元|800|192|0→0|90.0%|0|
|5|紫晶真元|1,600|384|0→0|85.0%|0|
|6|青提仙元|12,000|2,880|1000→10000|75.0%|33|
|7|红枣仙元|132,000|31,680|10000→49000|65.0%|39|
|8|白荔仙元|1,800,000|432,000|49000→316000|55.0%|39|
|9|黄杏仙元|45,648,000|10,955,520|316000→1000000|45.0%|0|

六至八转的事件为完整账本，重合时间同时记入；九转的 0 表示未编造周期，不表示无灾劫。

## 战斗矩阵

每行100个种子；同转初始道痕、满状态；策略为固定脚本，无配方抽取、玩家学习或实战操作。

|转|敌人|构筑|胜率|平均回合|剩余耐受|
|---|---|---|---:|---:|---:|
|1|skirmisher|burst|100.0%|1.83|89.3%|
|1|skirmisher|balanced|100.0%|4.3|96.2%|
|1|skirmisher|sustain|100.0%|5.44|100.0%|
|1|brute|burst|100.0%|3.73|72.5%|
|1|brute|balanced|100.0%|5.08|72.3%|
|1|brute|sustain|100.0%|5.07|88.7%|
|1|pressure|burst|100.0%|2.29|71.9%|
|1|pressure|balanced|100.0%|5.33|64.3%|
|1|pressure|sustain|100.0%|6.43|79.7%|
|1|armored|burst|96.0%|5.46|24.3%|
|1|armored|balanced|95.0%|8.56|21.8%|
|1|armored|sustain|100.0%|9.39|42.4%|
|1|disruptor|burst|100.0%|2.11|82.4%|
|1|disruptor|balanced|100.0%|4.59|74.5%|
|1|disruptor|sustain|100.0%|5.21|80.8%|
|1|soulBody|burst|100.0%|1.82|80.6%|
|1|soulBody|balanced|0.0%|7.25|0.0%|
|1|soulBody|sustain|3.0%|8.89|0.3%|
|1|guHouse|burst|100.0%|14|48.3%|
|1|guHouse|balanced|100.0%|17.12|47.7%|
|1|guHouse|sustain|100.0%|17.91|59.1%|
|1|beastPack|burst|49.0%|8.96|5.4%|
|1|beastPack|balanced|7.0%|10.62|0.4%|
|1|beastPack|sustain|45.0%|14.23|5.3%|
|2|skirmisher|burst|100.0%|1.83|89.3%|
|2|skirmisher|balanced|100.0%|4.3|96.2%|
|2|skirmisher|sustain|100.0%|5.44|100.0%|
|2|brute|burst|100.0%|3.73|72.5%|
|2|brute|balanced|100.0%|5.08|72.3%|
|2|brute|sustain|100.0%|5.07|88.7%|
|2|pressure|burst|100.0%|2.29|71.9%|
|2|pressure|balanced|100.0%|5.33|64.3%|
|2|pressure|sustain|100.0%|6.43|79.7%|
|2|armored|burst|96.0%|5.46|24.3%|
|2|armored|balanced|95.0%|8.56|21.8%|
|2|armored|sustain|100.0%|9.39|42.4%|
|2|disruptor|burst|100.0%|2.11|82.4%|
|2|disruptor|balanced|100.0%|4.59|74.5%|
|2|disruptor|sustain|100.0%|5.21|80.8%|
|2|soulBody|burst|100.0%|1.82|80.6%|
|2|soulBody|balanced|0.0%|7.25|0.0%|
|2|soulBody|sustain|3.0%|8.89|0.3%|
|2|guHouse|burst|100.0%|14|48.3%|
|2|guHouse|balanced|100.0%|17.12|47.7%|
|2|guHouse|sustain|100.0%|17.91|59.1%|
|2|beastPack|burst|49.0%|8.96|5.4%|
|2|beastPack|balanced|7.0%|10.62|0.4%|
|2|beastPack|sustain|45.0%|14.23|5.3%|
|3|skirmisher|burst|100.0%|1.83|89.3%|
|3|skirmisher|balanced|100.0%|4.3|96.2%|
|3|skirmisher|sustain|100.0%|5.44|100.0%|
|3|brute|burst|100.0%|3.73|72.5%|
|3|brute|balanced|100.0%|5.08|72.3%|
|3|brute|sustain|100.0%|5.07|88.7%|
|3|pressure|burst|100.0%|2.29|71.9%|
|3|pressure|balanced|100.0%|5.33|64.3%|
|3|pressure|sustain|100.0%|6.43|79.7%|
|3|armored|burst|96.0%|5.46|24.3%|
|3|armored|balanced|95.0%|8.56|21.8%|
|3|armored|sustain|100.0%|9.39|42.4%|
|3|disruptor|burst|100.0%|2.11|82.4%|
|3|disruptor|balanced|100.0%|4.59|74.5%|
|3|disruptor|sustain|100.0%|5.21|80.8%|
|3|soulBody|burst|100.0%|1.82|80.6%|
|3|soulBody|balanced|0.0%|7.25|0.0%|
|3|soulBody|sustain|3.0%|8.89|0.3%|
|3|guHouse|burst|100.0%|14|48.3%|
|3|guHouse|balanced|100.0%|17.12|47.7%|
|3|guHouse|sustain|100.0%|17.91|59.1%|
|3|beastPack|burst|49.0%|8.96|5.4%|
|3|beastPack|balanced|7.0%|10.62|0.4%|
|3|beastPack|sustain|45.0%|14.23|5.3%|
|4|skirmisher|burst|100.0%|1.83|89.3%|
|4|skirmisher|balanced|100.0%|4.3|96.2%|
|4|skirmisher|sustain|100.0%|5.44|100.0%|
|4|brute|burst|100.0%|3.73|72.5%|
|4|brute|balanced|100.0%|5.08|72.3%|
|4|brute|sustain|100.0%|5.07|88.7%|
|4|pressure|burst|100.0%|2.29|71.9%|
|4|pressure|balanced|100.0%|5.33|64.3%|
|4|pressure|sustain|100.0%|6.43|79.7%|
|4|armored|burst|96.0%|5.46|24.3%|
|4|armored|balanced|95.0%|8.56|21.8%|
|4|armored|sustain|100.0%|9.39|42.4%|
|4|disruptor|burst|100.0%|2.11|82.4%|
|4|disruptor|balanced|100.0%|4.59|74.5%|
|4|disruptor|sustain|100.0%|5.21|80.8%|
|4|soulBody|burst|100.0%|1.82|80.6%|
|4|soulBody|balanced|0.0%|7.25|0.0%|
|4|soulBody|sustain|3.0%|8.89|0.3%|
|4|guHouse|burst|100.0%|14|48.3%|
|4|guHouse|balanced|100.0%|17.12|47.7%|
|4|guHouse|sustain|100.0%|17.91|59.1%|
|4|beastPack|burst|49.0%|8.96|5.4%|
|4|beastPack|balanced|7.0%|10.62|0.4%|
|4|beastPack|sustain|45.0%|14.23|5.3%|
|5|skirmisher|burst|100.0%|1.83|89.3%|
|5|skirmisher|balanced|100.0%|4.3|96.2%|
|5|skirmisher|sustain|100.0%|5.44|100.0%|
|5|brute|burst|100.0%|3.73|72.5%|
|5|brute|balanced|100.0%|5.08|72.3%|
|5|brute|sustain|100.0%|5.07|88.7%|
|5|pressure|burst|100.0%|2.29|71.9%|
|5|pressure|balanced|100.0%|5.33|64.3%|
|5|pressure|sustain|100.0%|6.43|79.7%|
|5|armored|burst|96.0%|5.46|24.3%|
|5|armored|balanced|95.0%|8.56|21.8%|
|5|armored|sustain|100.0%|9.39|42.4%|
|5|disruptor|burst|100.0%|2.11|82.4%|
|5|disruptor|balanced|100.0%|4.59|74.5%|
|5|disruptor|sustain|100.0%|5.21|80.8%|
|5|soulBody|burst|100.0%|1.82|80.6%|
|5|soulBody|balanced|0.0%|7.25|0.0%|
|5|soulBody|sustain|3.0%|8.89|0.3%|
|5|guHouse|burst|100.0%|14|48.3%|
|5|guHouse|balanced|100.0%|17.12|47.7%|
|5|guHouse|sustain|100.0%|17.91|59.1%|
|5|beastPack|burst|49.0%|8.96|5.4%|
|5|beastPack|balanced|7.0%|10.62|0.4%|
|5|beastPack|sustain|45.0%|14.23|5.3%|
|6|skirmisher|burst|100.0%|1.83|89.3%|
|6|skirmisher|balanced|100.0%|3.67|100.0%|
|6|skirmisher|sustain|100.0%|4.48|100.0%|
|6|brute|burst|100.0%|2.79|79.7%|
|6|brute|balanced|100.0%|3.65|93.8%|
|6|brute|sustain|100.0%|4.56|90.8%|
|6|pressure|burst|100.0%|2|78.1%|
|6|pressure|balanced|100.0%|4.47|92.3%|
|6|pressure|sustain|100.0%|5.67|89.8%|
|6|armored|burst|100.0%|3.48|58.2%|
|6|armored|balanced|100.0%|7.3|99.8%|
|6|armored|sustain|100.0%|9.08|99.8%|
|6|disruptor|burst|100.0%|2|84.1%|
|6|disruptor|balanced|100.0%|4.23|100.0%|
|6|disruptor|sustain|100.0%|5.49|100.0%|
|6|soulBody|burst|100.0%|1.71|83.2%|
|6|soulBody|balanced|98.0%|9.45|53.7%|
|6|soulBody|sustain|98.0%|11.1|58.3%|
|6|guHouse|burst|100.0%|6.82|76.9%|
|6|guHouse|balanced|100.0%|16.12|71.8%|
|6|guHouse|sustain|100.0%|17.79|80.9%|
|6|beastPack|burst|100.0%|4.29|46.8%|
|6|beastPack|balanced|100.0%|12.83|69.3%|
|6|beastPack|sustain|100.0%|14.9|75.6%|
|7|skirmisher|burst|100.0%|1.83|89.3%|
|7|skirmisher|balanced|100.0%|3.67|100.0%|
|7|skirmisher|sustain|100.0%|4.48|100.0%|
|7|brute|burst|100.0%|2.79|79.7%|
|7|brute|balanced|100.0%|3.65|93.8%|
|7|brute|sustain|100.0%|4.56|90.8%|
|7|pressure|burst|100.0%|2|78.1%|
|7|pressure|balanced|100.0%|4.47|92.3%|
|7|pressure|sustain|100.0%|5.67|89.8%|
|7|armored|burst|100.0%|3.48|58.2%|
|7|armored|balanced|100.0%|7.3|99.8%|
|7|armored|sustain|100.0%|9.08|99.8%|
|7|disruptor|burst|100.0%|2|84.1%|
|7|disruptor|balanced|100.0%|4.23|100.0%|
|7|disruptor|sustain|100.0%|5.49|100.0%|
|7|soulBody|burst|100.0%|1.71|83.2%|
|7|soulBody|balanced|98.0%|9.45|53.7%|
|7|soulBody|sustain|98.0%|11.1|58.3%|
|7|guHouse|burst|100.0%|6.82|76.9%|
|7|guHouse|balanced|100.0%|16.12|71.8%|
|7|guHouse|sustain|100.0%|17.79|80.9%|
|7|beastPack|burst|100.0%|4.29|46.8%|
|7|beastPack|balanced|100.0%|12.83|69.3%|
|7|beastPack|sustain|100.0%|14.9|75.6%|
|8|skirmisher|burst|100.0%|1.83|89.3%|
|8|skirmisher|balanced|100.0%|3.67|100.0%|
|8|skirmisher|sustain|100.0%|4.48|100.0%|
|8|brute|burst|100.0%|2.79|79.7%|
|8|brute|balanced|100.0%|3.65|93.8%|
|8|brute|sustain|100.0%|4.56|90.8%|
|8|pressure|burst|100.0%|2|78.1%|
|8|pressure|balanced|100.0%|4.47|92.3%|
|8|pressure|sustain|100.0%|5.67|89.8%|
|8|armored|burst|100.0%|3.48|58.2%|
|8|armored|balanced|100.0%|7.3|99.8%|
|8|armored|sustain|100.0%|9.08|99.8%|
|8|disruptor|burst|100.0%|2|84.1%|
|8|disruptor|balanced|100.0%|4.23|100.0%|
|8|disruptor|sustain|100.0%|5.49|100.0%|
|8|soulBody|burst|100.0%|1.71|83.2%|
|8|soulBody|balanced|98.0%|9.45|53.7%|
|8|soulBody|sustain|98.0%|11.1|58.3%|
|8|guHouse|burst|100.0%|6.82|76.9%|
|8|guHouse|balanced|100.0%|16.12|71.8%|
|8|guHouse|sustain|100.0%|17.79|80.9%|
|8|beastPack|burst|100.0%|4.29|46.8%|
|8|beastPack|balanced|100.0%|12.83|69.3%|
|8|beastPack|sustain|100.0%|14.9|75.6%|
|9|skirmisher|burst|100.0%|1.83|89.3%|
|9|skirmisher|balanced|100.0%|3.67|100.0%|
|9|skirmisher|sustain|100.0%|4.48|100.0%|
|9|brute|burst|100.0%|2.79|79.7%|
|9|brute|balanced|100.0%|3.65|93.8%|
|9|brute|sustain|100.0%|4.56|90.8%|
|9|pressure|burst|100.0%|2|78.1%|
|9|pressure|balanced|100.0%|4.47|92.3%|
|9|pressure|sustain|100.0%|5.67|89.8%|
|9|armored|burst|100.0%|3.48|58.2%|
|9|armored|balanced|100.0%|7.3|99.8%|
|9|armored|sustain|100.0%|9.08|99.8%|
|9|disruptor|burst|100.0%|2|84.1%|
|9|disruptor|balanced|100.0%|4.23|100.0%|
|9|disruptor|sustain|100.0%|5.49|100.0%|
|9|soulBody|burst|100.0%|1.71|83.2%|
|9|soulBody|balanced|98.0%|9.45|53.7%|
|9|soulBody|sustain|98.0%|11.1|58.3%|
|9|guHouse|burst|100.0%|6.82|76.9%|
|9|guHouse|balanced|100.0%|16.12|71.8%|
|9|guHouse|sustain|100.0%|17.79|80.9%|
|9|beastPack|burst|100.0%|4.29|46.8%|
|9|beastPack|balanced|100.0%|12.83|69.3%|
|9|beastPack|sustain|100.0%|14.9|75.6%|

## 越转基准（低转爆发，对高一转持续压力）

|转数|胜率|平均回合|
|---|---:|---:|
|1→2|0.0%|2.85|
|2→3|0.0%|2.85|
|3→4|0.0%|2.85|
|4→5|0.0%|2.85|
|5→6|0.0%|1|
|6→7|0.0%|1|
|7→8|0.0%|1|
|8→9|0.0%|1|

## 敏感性

每行1350次战斗，包含九转、五类敌人、30个种子。

|扰动对象|倍率|构筑|胜率|剩余耐受|
|---|---:|---|---:|---:|
|enemyMultiplier|0.8|burst|98.4%|71.4%|
|enemyMultiplier|0.8|balanced|90.7%|70.8%|
|enemyMultiplier|0.8|sustain|96.1%|78.4%|
|actionMultiplier|0.8|burst|87.3%|49.0%|
|actionMultiplier|0.8|balanced|77.7%|49.5%|
|actionMultiplier|0.8|sustain|82.7%|57.8%|
|enemyMultiplier|1|burst|95.4%|64.9%|
|enemyMultiplier|1|balanced|85.1%|62.9%|
|enemyMultiplier|1|sustain|90.1%|69.3%|
|actionMultiplier|1|burst|95.4%|64.9%|
|actionMultiplier|1|balanced|85.1%|62.9%|
|actionMultiplier|1|sustain|90.1%|69.3%|
|enemyMultiplier|1.2|burst|91.7%|59.2%|
|enemyMultiplier|1.2|balanced|80.5%|54.2%|
|enemyMultiplier|1.2|sustain|82.3%|58.7%|
|actionMultiplier|1.2|burst|99.5%|75.4%|
|actionMultiplier|1.2|balanced|91.0%|72.3%|
|actionMultiplier|1.2|sustain|94.2%|76.7%|

## 低转末期对高一转初期

与初入转数对比不同，此表保留前一转积累；没有自动越阶禁伤。

|转数|胜率|平均回合|
|---|---:|---:|
|1→2|21.0%|3.49|
|2→3|21.0%|3.49|
|3→4|21.0%|3.49|
|4→5|21.0%|3.49|
|5→6|0.0%|1|
|6→7|2.0%|2.85|
|7→8|0.0%|2|
|8→9|0.0%|1.86|

## 炼蛊尾部预算

每转10000个随机样本；单位为该转货币。投入蛊重置成本另计，不包含在费用列。经验分位受有限样本影响，正式预算使用理论分位；例如九转五次失败尾概率5.0328%，须准备六次才达到理论95%覆盖。

|转|准备后概率|平均尝试次数|样本95%次数|样本95%费用|理论95%次数|
|---|---:|---:|---:|---:|---:|
|1|98.0%|1.02|1|12|1|
|2|98.0%|1.02|1|24|1|
|3|95.0%|1.05|1|48|1|
|4|90.0%|1.11|2|192|2|
|5|85.0%|1.17|2|384|2|
|6|75.0%|1.33|3|36|3|
|7|65.0%|1.53|3|108|3|
|8|55.0%|1.81|4|432|4|
|9|45.0%|2.21|5|1,620|6|

## 126场完整账本压力测试

一至五转每转4期、六至八转每转6期、九转4期；每期3场。炼蛊按期望费用计账，晋阶/境界/知识资格由测试情景提供，因此不是完整游戏通关率。灾劫用聚合结算代理，不是逐场战斗。

|构筑|筹备|收入倍率|完成率|失败位置与原因|
|---|---:|---:|---:|---|
|burst|0|0.8|0.0%|{"4转:长期筹备破产":25,"5转:长期筹备破产":5}|
|burst|0|1|0.0%|{"5转:升仙失败":30}|
|burst|0|1.2|0.0%|{"5转:升仙失败":30}|
|burst|0.5|0.8|0.0%|{"4转:长期筹备破产":25,"5转:长期筹备破产":5}|
|burst|0.5|1|0.0%|{"8转:灾劫准备不足":30}|
|burst|0.5|1.2|0.0%|{"8转:灾劫准备不足":30}|
|burst|1|0.8|0.0%|{"4转:长期筹备破产":25,"5转:长期筹备破产":5}|
|burst|1|1|100.0%|{}|
|burst|1|1.2|100.0%|{}|
|balanced|0|0.8|0.0%|{"3转:长期筹备破产":29,"4转:长期筹备破产":1}|
|balanced|0|1|0.0%|{"5转:升仙失败":30}|
|balanced|0|1.2|0.0%|{"5转:升仙失败":30}|
|balanced|0.5|0.8|0.0%|{"3转:长期筹备破产":29,"4转:长期筹备破产":1}|
|balanced|0.5|1|0.0%|{"8转:灾劫准备不足":24,"8转:长期筹备破产":6}|
|balanced|0.5|1.2|0.0%|{"8转:灾劫准备不足":30}|
|balanced|1|0.8|0.0%|{"3转:长期筹备破产":29,"4转:长期筹备破产":1}|
|balanced|1|1|36.7%|{"9转:长期筹备破产":19}|
|balanced|1|1.2|100.0%|{}|
|sustain|0|0.8|0.0%|{"4转:长期筹备破产":18,"5转:长期筹备破产":12}|
|sustain|0|1|0.0%|{"5转:升仙失败":30}|
|sustain|0|1.2|0.0%|{"5转:升仙失败":30}|
|sustain|0.5|0.8|0.0%|{"4转:长期筹备破产":18,"5转:长期筹备破产":12}|
|sustain|0.5|1|0.0%|{"8转:灾劫准备不足":30}|
|sustain|0.5|1.2|0.0%|{"8转:灾劫准备不足":30}|
|sustain|1|0.8|0.0%|{"4转:长期筹备破产":18,"5转:长期筹备破产":12}|
|sustain|1|1|100.0%|{}|
|sustain|1|1.2|100.0%|{}|

基准路线：126场、160次修炼行动、终局1000000道痕、余1,159.97仙元石、封存1,443.86元石（不兑换）。这条可行路线只证明模型无必然资源死锁。

## 载体战斗矩阵（v0.2）

soulBody/guHouse/beastPack 为特殊防御载体模板，数值全部是纯游戏设计假设，概念锚点只取自 lore/wiki（魂道：常规手段难伤；KM-006：蛊屋高耐受低机动；兽潮：多单位聚合逐波衰减），不声称原著数值。每行 100 个种子，与上方战斗矩阵同种子（fixedSeed=20260927）。胜率差 = 载体胜率 − 同转同构筑 pressure 模板胜率；机制断言（魂体减伤、蛊屋低攻、兽群衰减与范围收益）见「规则与边界」。

|转|载体|构筑|胜率|平均回合|剩余耐受|对pressure胜率差|
|---|---|---|---:|---:|---:|---:|
|1|soulBody|burst|100.0%|1.82|80.6%|+0.0pp|
|1|soulBody|balanced|0.0%|7.25|0.0%|-100.0pp|
|1|soulBody|sustain|3.0%|8.89|0.3%|-97.0pp|
|1|guHouse|burst|100.0%|14|48.3%|+0.0pp|
|1|guHouse|balanced|100.0%|17.12|47.7%|+0.0pp|
|1|guHouse|sustain|100.0%|17.91|59.1%|+0.0pp|
|1|beastPack|burst|49.0%|8.96|5.4%|-51.0pp|
|1|beastPack|balanced|7.0%|10.62|0.4%|-93.0pp|
|1|beastPack|sustain|45.0%|14.23|5.3%|-55.0pp|
|2|soulBody|burst|100.0%|1.82|80.6%|+0.0pp|
|2|soulBody|balanced|0.0%|7.25|0.0%|-100.0pp|
|2|soulBody|sustain|3.0%|8.89|0.3%|-97.0pp|
|2|guHouse|burst|100.0%|14|48.3%|+0.0pp|
|2|guHouse|balanced|100.0%|17.12|47.7%|+0.0pp|
|2|guHouse|sustain|100.0%|17.91|59.1%|+0.0pp|
|2|beastPack|burst|49.0%|8.96|5.4%|-51.0pp|
|2|beastPack|balanced|7.0%|10.62|0.4%|-93.0pp|
|2|beastPack|sustain|45.0%|14.23|5.3%|-55.0pp|
|3|soulBody|burst|100.0%|1.82|80.6%|+0.0pp|
|3|soulBody|balanced|0.0%|7.25|0.0%|-100.0pp|
|3|soulBody|sustain|3.0%|8.89|0.3%|-97.0pp|
|3|guHouse|burst|100.0%|14|48.3%|+0.0pp|
|3|guHouse|balanced|100.0%|17.12|47.7%|+0.0pp|
|3|guHouse|sustain|100.0%|17.91|59.1%|+0.0pp|
|3|beastPack|burst|49.0%|8.96|5.4%|-51.0pp|
|3|beastPack|balanced|7.0%|10.62|0.4%|-93.0pp|
|3|beastPack|sustain|45.0%|14.23|5.3%|-55.0pp|
|4|soulBody|burst|100.0%|1.82|80.6%|+0.0pp|
|4|soulBody|balanced|0.0%|7.25|0.0%|-100.0pp|
|4|soulBody|sustain|3.0%|8.89|0.3%|-97.0pp|
|4|guHouse|burst|100.0%|14|48.3%|+0.0pp|
|4|guHouse|balanced|100.0%|17.12|47.7%|+0.0pp|
|4|guHouse|sustain|100.0%|17.91|59.1%|+0.0pp|
|4|beastPack|burst|49.0%|8.96|5.4%|-51.0pp|
|4|beastPack|balanced|7.0%|10.62|0.4%|-93.0pp|
|4|beastPack|sustain|45.0%|14.23|5.3%|-55.0pp|
|5|soulBody|burst|100.0%|1.82|80.6%|+0.0pp|
|5|soulBody|balanced|0.0%|7.25|0.0%|-100.0pp|
|5|soulBody|sustain|3.0%|8.89|0.3%|-97.0pp|
|5|guHouse|burst|100.0%|14|48.3%|+0.0pp|
|5|guHouse|balanced|100.0%|17.12|47.7%|+0.0pp|
|5|guHouse|sustain|100.0%|17.91|59.1%|+0.0pp|
|5|beastPack|burst|49.0%|8.96|5.4%|-51.0pp|
|5|beastPack|balanced|7.0%|10.62|0.4%|-93.0pp|
|5|beastPack|sustain|45.0%|14.23|5.3%|-55.0pp|
|6|soulBody|burst|100.0%|1.71|83.2%|+0.0pp|
|6|soulBody|balanced|98.0%|9.45|53.7%|-2.0pp|
|6|soulBody|sustain|98.0%|11.1|58.3%|-2.0pp|
|6|guHouse|burst|100.0%|6.82|76.9%|+0.0pp|
|6|guHouse|balanced|100.0%|16.12|71.8%|+0.0pp|
|6|guHouse|sustain|100.0%|17.79|80.9%|+0.0pp|
|6|beastPack|burst|100.0%|4.29|46.8%|+0.0pp|
|6|beastPack|balanced|100.0%|12.83|69.3%|+0.0pp|
|6|beastPack|sustain|100.0%|14.9|75.6%|+0.0pp|
|7|soulBody|burst|100.0%|1.71|83.2%|+0.0pp|
|7|soulBody|balanced|98.0%|9.45|53.7%|-2.0pp|
|7|soulBody|sustain|98.0%|11.1|58.3%|-2.0pp|
|7|guHouse|burst|100.0%|6.82|76.9%|+0.0pp|
|7|guHouse|balanced|100.0%|16.12|71.8%|+0.0pp|
|7|guHouse|sustain|100.0%|17.79|80.9%|+0.0pp|
|7|beastPack|burst|100.0%|4.29|46.8%|+0.0pp|
|7|beastPack|balanced|100.0%|12.83|69.3%|+0.0pp|
|7|beastPack|sustain|100.0%|14.9|75.6%|+0.0pp|
|8|soulBody|burst|100.0%|1.71|83.2%|+0.0pp|
|8|soulBody|balanced|98.0%|9.45|53.7%|-2.0pp|
|8|soulBody|sustain|98.0%|11.1|58.3%|-2.0pp|
|8|guHouse|burst|100.0%|6.82|76.9%|+0.0pp|
|8|guHouse|balanced|100.0%|16.12|71.8%|+0.0pp|
|8|guHouse|sustain|100.0%|17.79|80.9%|+0.0pp|
|8|beastPack|burst|100.0%|4.29|46.8%|+0.0pp|
|8|beastPack|balanced|100.0%|12.83|69.3%|+0.0pp|
|8|beastPack|sustain|100.0%|14.9|75.6%|+0.0pp|
|9|soulBody|burst|100.0%|1.71|83.2%|+0.0pp|
|9|soulBody|balanced|98.0%|9.45|53.7%|-2.0pp|
|9|soulBody|sustain|98.0%|11.1|58.3%|-2.0pp|
|9|guHouse|burst|100.0%|6.82|76.9%|+0.0pp|
|9|guHouse|balanced|100.0%|16.12|71.8%|+0.0pp|
|9|guHouse|sustain|100.0%|17.79|80.9%|+0.0pp|
|9|beastPack|burst|100.0%|4.29|46.8%|+0.0pp|
|9|beastPack|balanced|100.0%|12.83|69.3%|+0.0pp|
|9|beastPack|sustain|100.0%|14.9|75.6%|+0.0pp|

## 灾劫两口径对照（v0.2）

同一账本接口（alive/injury/ecology/marks/power/margin）下的两种结算：聚合代理（resolveTribulation，v0.1 口径）与实战口径（tribulationFight：敌人=载体模板×tribulationPower 威能倍率）。实战口径 margin=剩余耐受/0.75 仅用于与代理口径同轴对比，不再作为生死门槛；存活后道痕记法与生态修复费公式与代理口径完全相同。preparation=1、rewardMultiplier=1、每行 30 个种子；实战口径未接蛊库（§4.1 占位动作口径），升仙与成尊仍是聚合代理。

|构筑|口径|完成率|平均场次|失败位置与原因|
|---|---|---:|---:|---|
|burst|聚合代理|100.0%|126|{}|
|burst|实战载体|63.3%|111.4|{"8转:长期筹备破产":2,"7转:长期筹备破产":5,"6转:长期筹备破产":3,"8转:灾劫战斗失败":1}|
|balanced|聚合代理|36.7%|122.2|{"9转:长期筹备破产":19}|
|balanced|实战载体|0.0%|70.4|{"6转:长期筹备破产":15,"6转:灾劫战斗失败":14,"7转:长期筹备破产":1}|
|sustain|聚合代理|100.0%|126|{}|
|sustain|实战载体|0.0%|75|{"6转:灾劫战斗失败":30}|

## 数值测试配置×供应（v0.2，--builds）

测试配置库：`C:\Users\90877\work_space\gu-zhenren\docs\design\rank1-9-model\gu-library.json`（SHA-256 `f6eef60ce7843ee79aad864d1548c3a989b870e7c5e74883be9dbb151df777bc`）；供应：`C:\Users\90877\work_space\gu-zhenren\docs\design\rank1-9-model\supply.json`（SHA-256 `ecacfb89df60dfb805978e8b7e756b7806a8d4e7bb5c2ed55a3214685e69ccf4`）。场景臂：supply_limited、key_gu_missing、refine_tail；每行 30 个种子；preparation=1、rewardMultiplier=1；灾劫用聚合代理口径。槽位静态审计问题 0 条（防套利口径全部通过）。供养合计与炼制费为全程账本累计（一至五转元石、六至九转仙元石混计，仅作同表量级对照，不跨币相加解读）；complete 与失败分布见下表，缺失转数指该配置未声明槽位的阶段（引擎退回基础动作、供养按 0 计）。

|测试配置|场景|样本|完成率|平均场次|供养合计均值|炼制费合计均值|缺档转数|失败位置与原因|
|---|---|---:|---:|---:|---:|---:|---|---|
|burst|baseline|30|26.7%|85.5|1,210.18|697.49|—|{"6转:长期筹备破产":7,"6转:战败":9,"8转:战败":6}|
|burst|supply_limited|30|23.3%|79.7|1,070.77|657.42|—|{"6转:战败":13,"6转:长期筹备破产":7,"8转:战败":3}|
|burst|key_gu_missing|30|26.7%|85.5|1,178.18|697.49|—|{"6转:长期筹备破产":7,"6转:战败":9,"8转:战败":6}|
|burst|refine_tail|30|10.0%|84.3|1,156.18|1,296|—|{"6转:长期筹备破产":7,"6转:战败":9,"8转:战败":6,"9转:长期筹备破产":4,"8转:长期筹备破产":1}|
|balanced|baseline|30|0.0%|60|1,138.23|354.25|—|{"6转:长期筹备破产":5,"2转:战败":8,"6转:战败":6,"7转:战败":6,"8转:长期筹备破产":3,"9转:战败":1,"8转:战败":1}|
|balanced|supply_limited|30|0.0%|58.5|1,187.7|365.32|—|{"6转:长期筹备破产":8,"2转:战败":5,"6转:战败":11,"7转:战败":5,"9转:战败":1}|
|balanced|key_gu_missing|30|0.0%|72.7|1,479.17|462.94|—|{"6转:长期筹备破产":9,"6转:战败":10,"7转:战败":6,"8转:长期筹备破产":3,"9转:战败":1,"8转:战败":1}|
|balanced|refine_tail|30|0.0%|50.4|1,030.53|500.4|—|{"6转:长期筹备破产":16,"2转:战败":8,"6转:战败":6}|
|sustain|baseline|30|0.0%|60.4|1,318.6|419.81|—|{"6转:战败":18,"6转:长期筹备破产":4,"6转:补给破产":8}|
|sustain|supply_limited|30|0.0%|60.2|1,314.47|419.81|—|{"6转:战败":25,"6转:补给破产":3,"6转:长期筹备破产":2}|
|sustain|key_gu_missing|30|0.0%|60.4|1,318.6|419.81|—|{"6转:战败":18,"6转:长期筹备破产":4,"6转:补给破产":8}|
|sustain|refine_tail|30|0.0%|60.4|1,318.6|660|—|{"6转:战败":18,"6转:长期筹备破产":4,"6转:补给破产":8}|

## 已知验证限制

- 高阶同转战斗沿用相同战术模板；相同胜率是尺度归一化的结果，不是九个阶段内容都已平衡。
- 所有脚本都可购买完全恢复，尚未测试稀缺商店、随机掉落、关键蛊缺失、社会风险及玩家决策。
- 炼蛊使用几何分布期望费用，不把均值冒充尾部风险；尾部预算见模型正文。
- 升仙气量、人气折算与成尊研究门槛属设计假设。独立 L1 审查和实玩尚未完成。
- 原文未确证或本 Wiki 未收录的九转周期及成尊第四条件保持未知。

完整矩阵、账本、来源哈希见 [results.json](results.json)。

### v0.2 追加限制

- 载体模板（soulBody/guHouse/beastPack）与灾劫实战化数值全部是纯游戏设计假设；概念锚点只取自 lore/wiki，不声称原著数值（登记见 [engine-v02](engine-v02.md)）。
- 升仙、八转后研究与成尊条件仍是聚合代理；实战口径只替换六至八转灾劫结算，替换后完成率显著下降是如实记录的漂移，不为变绿调参。
- 高阶同转沿用同一战术模板，载体矩阵跨转的相似结果是尺度归一化的产物，不是独立的高阶内容证据。
- 场景 priceMultiplier（如 supply_limited 的 market ×1.4 稀缺溢价）未进入引擎记账：v0.2 引擎无购置扣费，供养按行内价格倍率计；渠道稀缺表现为当期不可得→构筑 fallback/占位，未实现「等待期数」报告。
- 「数值测试配置×供应」节来自命令行指定的蛊库，检验旧动作槽与供应回落；不构成完整流派蛊虫构筑或玩家体验的证据。
- 供应数据取自 C:\Users\90877\work_space\gu-zhenren\docs\design\rank1-9-model\supply.json；未命中任何 supply 行的蛊落到 market 默认（可得、价格倍率 1）。
- model.mjs 存在四处登记在案的修复级改动（供应乘数形态、通配匹配、审计覆盖、兽群系数键域，见 [engine-v02](engine-v02.md) §4）；模型哈希因此与 v0.1 报告不同，beastPack 相关行数字随之漂移。
