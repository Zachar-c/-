# MVP × Lab 合并约定

```text
原则：一个规则核 · 两层皮可退役
壳  = lab.css / lab.html / journey
核  = MvpLogic（CombatCore）+ balance.js + gu/shop/run_flow
场景 = mvp_content（剧本夹具，不是第二引擎）
```

## MVP 已吸收进 Lab（不是挂脚本）

| MVP 价值 | Lab 落点 |
| --- | --- |
| 迎击/铁皮吞伤、压制 | `applyEffectPlan` → `CombatCore.resolveDirectStrike` |
| 读对+做对减伤、逐光 +3 | `enemyTurn` → `previewEnemyDamage` + `draw_light` |
| 情报已知/未察 | `battle.js` `intelBlock`（`MVP_CONTENT.intel`） |
| 意图伤预估（含反制） | `intelBlock` / `previewEnemyDamage` |
| 逆息保险丝 | `act.exhaust()` + `data-exhaust` 按钮 |
| 越阶门禁 | `useGu` + `lowRankException` |
| 反制徽章 | `counterBadge` |

## 归属

| 层 | 内容 |
| --- | --- |
| Lab 样式 | `css/lab.css`、HUD、地图/整备/大厅 |
| MVP 逻辑 | Counter/意图/逆息/越阶（`mvp_logic` = `CombatCore`） |
| 共享 | `gu_rules` `shop_rules` `run_flow` `run_rules` `balance.js` |
| 夹具 | `mvp_content.js` |

**禁止**第二套结算。入口：`lab.html`。
