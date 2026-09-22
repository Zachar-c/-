# Golden Dataset / Calibration Set

`../vertical/data/` 中的 30 蛊 / 24 杀招 / 50 敌人 / 商店 / 掉落
**身份 = 校准集**，不是真源。

用途：

1. 验证 `balance/projections/` 能否从 Canonical + Rulings + Models 重推出同构结果；
2. 看序关系（月光 < 月芒 < 黄金月）、交叉（垃圾三转 vs 极品二转）、价值向量形状；
3. 改上游 Fact/Ruling/Model 后，对比校准集看世界如何整体移动。

**禁止**：把 golden 数字拷回 `canonical/` 或手改 `generated/`。

对齐命令：

```powershell
cd game/wenzhen-web-lab/balance
node projections/generate.mjs
node simulation/compare_golden.mjs
```
