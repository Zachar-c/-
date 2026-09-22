# Web 主链集成验收记录 · 2026-09-21

```text
SCOPE: 仅 Web · Godot 不纳入本轮
STATUS: ACCEPTED_WITH_GAPS
```

## 1. 复验（修复探针重放）

| 门 | 结果 |
| --- | --- |
| Projection（含突变 value=999） | **34/34** · 突变 *detected* |
| P2–P5 阶段门（未知组件/非法 role/damage=99999 突变） | **fail=0** · 3 探针均检出 |
| Counter 边界测试 | **9/9** |
| C3 `forge.kind=experimental_scenario_recipe` | 通过（真实 `MVP_CONTENT.forge`） |

命令：

```powershell
cd game/wenzhen-web-lab
node tools/check_projection.mjs
node tools/check_l1_phases.mjs
node --test tests/l1_boundaries.test.mjs
```

## 2. autoplay 回归

| 集 | 结果 |
| --- | --- |
| seed 101 三路线 | 30/41 · sacrifice cleared · secure/debt lost at Boss · stalemate 0 · console error 0 |
| seeds 101–105 | 138/191 · 通关 5/15（仅 sacrifice 5/5）· **逐场与 101 完全一致** |

定位（**不调数值**）：

- 失败项为 L1 V4 窗口（总回合/battle_2·elite·boss 窗）与通关率；与本批门禁改动无关（修复前后同像）。
- **GAP-SEED**：lab 对 `?seed=N` 无方差（V4.1 反制确定性序列后已知）。多种子集等于复制局，不能当蒙特卡洛。
- secure/debt 死 Boss = 构筑差（白豕持续输出 vs 保炉/借月），非实现 bug。

## 3. R1→R5 主链闭环（不用 vertical）

探针 `tools/check_progression_loop.mjs` 只组装现有纯模块：

`mvp_logic` → 战斗 · `battle_stone_rewards` → 资源 · `ShopRules.stock/layerPrice` → 购买 ·
`GuRules.killMoveRecipeInstances` → 杀招组件 · `applyForge` → 炼蛊 · `RunFlow.nextBreakthrough` → 4 次大阶至五转 · `RunRules.restHeal`

**结果 10/10 PASS**：

```
战斗 createRun → 元石入账 → 商店 stock n=4 → 杀招实例
→ 炼出 moon_glow → 突破 1→2→3→4→5（stage 至巅峰）
```

证明：战斗→资源→购买/炼蛊→杀招→突破在 **Web 主链可串**。  
不表示正式单局必须完成五转（C6 仍 UNRESOLVED）。

## 4. Capability gaps（下一轮依据，本轮不扩内容）

| ID | 缺口 | 影响 |
| --- | --- | --- |
| **GAP-SEED** | autoplay seed 无方差 | 多种子/蒙特卡洛/掉率验证不可用 |
| **GAP-SHOP-BUY** | `stock` 有，缺「扣款买入口袋」一体化断言 | 购买步仅生成货架 |
| **GAP-LOOT-PIPE** | 探针未接 `loot_rules` 实掉 | 掉落→入袋未进闭环 |
| **GAP-INCOME-R2R5** | IncomeCurve 为 provisional 显式表 | 购买力 11 ALARM |
| **GAP-MVP-RANK** | `autoplay.mjs` 只驱动 10 分钟剧本，不跨转 | 需要 journey 长跑驱动器（非新战斗引擎） |
| **GAP-KM-COMP** | 杀招仍 declared damage（方案 B） | 组件推导迁移待 L0 |

## 5. 完成标准对照

| 标准 | 状态 |
| --- | --- |
| 真实消费者接线可证 | ✅ Projection 读 `balance.js` 实值 + 突变检出 |
| 错误数据能被门禁拦住 | ✅ 未知组件 / 非法 role / 99999 / 突变 999 |
| 闭环有可复现记录 | ✅ `check_progression_loop.mjs` 10/10 |
