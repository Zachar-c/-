# V4 / V4.1 数值校准 · 现行状态索引

> 2026-09-25 休眠资产收口建立（见 [docs/dormant-registry.md](../../../docs/dormant-registry.md)）。
> 本文件是 V4/V4.1 校准事实的现行索引；**代码为真源**，本文件只登记 L1 冻结裁定与代码锚点。
> 取代 [`2026-09-21-v4-calibration-handoff.md`](2026-09-21-v4-calibration-handoff.md) 的「唯一出处」地位（该文件归档为历史记录）。

## 上游权威

- V4.1 结构裁决（逆息 / 反制确定性 / 回合窗口）：`ai-system/RESEARCH-REQUEST-2026-09-21-v4-structural-blockers.md`（ANSWERED）。
- Lab 平衡框架裁决（`LAB_BUDGET_PROJECTION` / `LAB_PRICING_V1` / `THREAT_V1`）：`ai-system/RESEARCH-REQUEST-2026-09-21-balance-compat-audit.md`（ANSWERED）。
- 预算曲线真源：`game/data/balance.json` rank_power_budget（RUL-2026-09-19-008；40/80/160/320/640）。

## 现行冻结锚点（战斗核 = `lab.html` 加载的 `mvp_logic.js` / `mvp_content.js`，见 `lab.html:90-91`）

| 事实 | 锚点 |
| --- | --- |
| 玩家基线 HP 24 | `js/mvp_content.js:25` |
| `victoryRecovery {hp:2, qi:2}`（MVP 战斗核战后回复） | `js/mvp_content.js:354`、`js/mvp_logic.js:316` |
| V4.1-Q1 逆息（主刀回气，1 念头 / 气血 -2 / 真元 +3，CD 2） | `js/mvp_logic.js:470` 起 |
| 反制「读对 + 做对」减伤 `counterHandled` | `js/mvp_logic.js:301` |
| V4 敌方 HP 快照（猎犬 10 / 山猪 15 / 悍客 18 / 狼王 28） | `js/mvp_content.js:263` |
| `LAB_BUDGET_PROJECTION = 20` | `js/balance.js:49` |
| `LAB_PRICING_V1` / `THREAT_V1` 相对尺 | `js/balance.js:35`、`js/balance.js:126` |

## 变更纪律

- 上表冻结值属 L1/L0 边界：调整走 [`BALANCE_EVIDENCE_DISCIPLINE.md`](BALANCE_EVIDENCE_DISCIPLINE.md) 与根 `AGENTS.md` 数值边界。
- HOLD-1（主运行层战后真元完全回满）NOT APPROVED，未批准前不得顺手改（`docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md:110`）。
- 修改本文件时须重新核验锚点行号仍指向同一事实；行号漂移先修锚点再改字。

## 历史结论（不再现行，留在旧 handoff）

V4 门 30/41、seed 101 逐场指标、0/3 clear 与「冻结伤害表 × 回合窗口算术冲突」等验收结论见 [`2026-09-21-v4-calibration-handoff.md`](2026-09-21-v4-calibration-handoff.md)；其 `tools/autoplay.mjs` 验收门与 `mvp.html` 入口已按 2026-09-25 L0 收敛批删除，文中相关门禁条目仅作历史。
