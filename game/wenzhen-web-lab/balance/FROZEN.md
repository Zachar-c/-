# 禁止继续扩写（2026-09-21 Integration Pass）

本目录 `balance/` 为 **模型研究原型**，不是数值真源。

| 路径 | 身份 | 允许 |
| --- | --- | --- |
| `../js/balance.js` | Lab 校验器（应消费 `game/data/balance.json`） | 维护 |
| `../tools/check_balance.mjs` / `autoplay.mjs` | 验收 | 维护 |
| `../vertical/**` | Golden 校准集 + 已冻结 vbattle | 只读对照 |
| **本目录 canonical/models/projections/generated** | 实验 | **冻结**；不得成为第三套 Rank/定价/战斗 |

真源见 `../EXISTING_CAPABILITY_MAP.md`：

- Rank / HP / thought / essence → `game/data/balance.json` + `gu_balance.gd`
- 蛊 / 杀招 / 炼方 / 敌 / 店 / 掉落 → `game/data/*`
- 市价 → `market_rules.gd`

`index.html` 仅作地图/验收示意，不代表正式数值入口。
