# RESEARCH REQUEST · 魂道数值模型重派（lab-run-v2 事实刷新件）

> 提交人：L2 Orchestrator
> 上抛对象：**L1（研究院）**
> 日期：2026-09-26
> 裁定依据：`game/world-model/rulings/RUL-2026-09-25-001.json` **Q3**——「先按 lab-run-v2 做魂轴事实刷新……再重派 L1 数值模型；RUL-004~007 设计裁决继续有效；矛盾仍在时按 S1–S5 顺序」
> 配套底稿：[RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md](RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md)（下称「旧件」）
> STATUS：**READY_FOR_L1_REDISPATCH**

---

## 0. 本件怎么用

本件是旧件 **§4（游戏现状）的换载体刷新**，按 Q3 列举的八项逐一取证。旧件 §3 的原著取证
（魂魄底蕴量级、百人魂生死极限、壮炼安三要素、凝魂名录、狼魂蛊经济锚点等）是原著事实，
**不随载体变化，全部沿用**；旧件 §6 的 Q1–Q9 问题清单不变。

**重派包裹 = 本件 + 旧件 §3/§6/§7/§8**。旧件 §4 与 §4.7 的实测数据基于当时的旧实现
（尚有魂丹与黑市路径），在当前产品载体上已不成立，只作历史参照，**不得作为重派输入**。

取证纪律：标注 `[事实]` 的每条附 `文件:行号`，来自对当前工作树的只读审计；
`[分析]` 是 L2 的解读，L1 可推翻。本件不重跑 200 局模拟（Q3 明令不得先用旧模拟调难度）。

## 0.1 载体口径（先读）

- 产品载体 = 浏览器 Web 版《问真》，主入口 `game/wenzhen-web-lab/lab.html`（L0 2026-09-24）。
- 进行中存档兼容版本 = **lab-run-v2**（`game/wenzhen-web-lab/js/data.js:4` `saveCompatibilityVersion`）。
- Godot 自 `RUL-2026-09-25-001` 起降为**成熟参考实现与规则资产来源**，不再是产品运行载体。
  本件凡标 `[Godot]` 的事实属参考侧，产品不消费。

---

## 1. soul 字段与上限

- `[事实]` 运行状态初始值：`soul: 1, soulMax: 4`（`game/wenzhen-web-lab/js/main.js:10`，`READY` 常量）。
- `[事实]` `soulMax` 在整个 `wenzhen-web-lab/js/` 内**零写入路径**（全库检索唯一命中即定义行）——
  硬顶，与旧件 §4.1 A 套结论一致。
- `[事实]` `state.soul` 的全部写入只有两处：敌方抽魂结算 `main.js:675`
  （`RunRules.drainSoul`，只减不增）与死亡清零 `main.js:707`。
- `[事实]` `[Godot]` 参考侧同构：`soul:1 / soul_max:4`（`game/scripts/domain/run_state.gd:115-116`；
  专项盘点 `game/world-model/reports/soul-system-audit.md` Q1 节）。

## 2. AP（念头）是否实读 soul——**是，且只作用于战斗内行动上限**

- `[事实]` 档位表仍按原文百/千/万人魂落点：`run_rules.js:7-13`
  （`actionPointsPerTurn`：≥10000→6、≥1000→5、≥100→4、≥10→3、否则 2；注释标明镜像
  `action_points.gd::per_turn`）。
- `[事实]` 真实战斗**每回合**重算：战斗启动 `main.js:1325-1326`、每回合重置
  `main.js:745-750`（`state.thoughtMax = actionPointsPerTurn(state.soul)`，
  `b.actionLimit = state.thoughtMax`）；新局初始化 `main.js:211`（`fresh()`）。
- `[事实]` soul 恒在 1–4 → 玩家**永远停留在 2 点档**，3/4/5/6 档不可达——旧件 §4.2 的
  「最大结构断裂」在 lab 上原样延续。
- `[事实]` `balance.js:106` 的 `thoughtsPerTurn: 2` 常量**只**被静态预算估算器 kitDpr 消费
  （`balance.js:197`），真实战斗不读它；全仓真值 `thought_base_capacity=3`
  （`game/data/balance.json`）。
- `[事实]` 结构变化（相对旧件 §4.2 的语境）：lab 中 soul→AP **只影响战斗内每回合行动上限**；
  run 层（地图/节点动作）没有行动点经济。旧件所写「行动点、多线作战上限」两消费者，lab 只落地前者。
- `[事实]` `[Godot]` 参考侧另有 lab 未投影的两个消费者：`SoulCapacity.battle_ops_cap`（= soul 值本身）
  与 `craft_cap_for_soul`（5/3 两档），见 `soul-system-audit.md` Q1 节。

## 3. 增长入口——**lab 内为零**（与旧件最大的差异）

- `[事实]` 魂丹数据仍存在但**不进货**：`game/data/shops.json` 含
  `{"id":"soul_pill","kind":"soul_boost","stone_cost":6,"soul_gain":1,"tier":2}`；
  lab 货架过滤 `GOODS_KINDS = ['purchase']`（`shop_rules.js:3`，过滤点 `:49`），
  `soul_boost` 类别被整体排除。
- `[事实]` L0 裁定注记随数据投影留痕（`data.js:8824`）：「除蛊方服务外，资源交换、寿元交易、
  以物易物、洗恶名、**补魂丹**、配方解锁与动态难度均不作为本原型目标」。
- `[事实]` 黑市兑换（寿元/气血 ↔ 魂）在 lab 不存在；事件零加魂（`data.js` 全文无 `soul_gain`）。
- `[事实]` 综上：lab 的 soul 是**纯递减量**——开局 1、无任何 +1 路径、上限恒 4。
  旧件 §4.3 的两条增长路径（魂丹 6 石、黑市 20 寿/血）在当前产品中均已不可达。
- `[分析]` 这使 soul 当前形态 = 「恒 2 档的战斗行动上限常量 + 第三条死亡条」，
  与 L0 四重身份（生存值/资源/攻防基础/成长轴）的落差**大于** 2026-09-19 审计时点
  （当时至少还有两条 +1 路径）。Q1（换算骨架）的紧迫性相应上升。

## 4. 死亡入口

- `[事实]` 三轴死亡（气血/寿元/魂，阈值 0）保留：战斗中即时检查 `main.js:687-689`；
  结算分支 `main.js:691-713`（`deathCause: 'life_cost' | 'soul'`，气血默认）；
  判定函数 `run_rules.js:30-37`（`soulDefeated` / `lifeDefeated`）；
  死亡报告三因呈现 `main.js:783-789`（「魂魄耗尽」）。

## 5. 存档字段

- `[事实]` 存档为**整包 state 序列化**：`lab_save.js:54-60`（`encode(state, contentVersion)`），
  存储 key `wenzhen.lab.run.v1`、`schemaVersion: 1`（`lab_save.js:5,9`）、
  `contentVersion = 'lab-run-v2'`（`data.js:4`）→ `soul/soulMax/thought/thoughtMax` 随包入档。
- `[事实]` 关键字段校验清单**不含 soul**（`lab_save.js:27-52` `missingCriticalState`）：
  缺 soul 的损坏档不会被判 `missing_state`。
- `[分析]` 该坏档回退行为：`actionPointsPerTurn(undefined||0)=2` 档、HUD 显示 `undefined/4`；
  低危鲁棒性缺口，随魂轴重做一并收口即可，不构成本次阻塞。
- `[事实]` 迁移逻辑仅处理材料字段移除（`lab_save.js:15-25`）；soul 字段形状自 v1 起未变，无迁移历史。
- `[事实]` 旧录归档上限 24 条（`lab_save.js:8`）。

## 6. 战斗入口

- `[事实]` 敌→玩家：45 只敌人中**唯一** soul 类意图 = `demon_path_adept`「噬魂魔功」
  （`data.js:4120-4123`：`kind: "soul_drain", soul_drain: 1, damage: 0, speed: 2`）；
  结算点 `main.js:674-676`。玩家无任何反制通道——旧结论保持。
- `[事实]` `soul_path_reaper`「魂道摄魂人」（rank5 / boss / anomaly）意图 `soul_bell`
  是**普通伤害 4**（guRef = `blood_atk_5_02_gu` 血道蛊）——魂道皮、血道骨，无魂池交互。
- `[事实]` 玩家→敌方魂伤害通道**不存在**：敌人无魂池字段；`v1_battle.json` 效果 kind 全集 =
  `strike / shield / heal / heal_and_strike / shift / status`，无任何 soul 类 verb。

## 7. 魂道蛊入口

- `[事实]` `game/data/gu.json`：soul 流派 **40 只**（rank 分布 1–5 转 = 11/10/9/4/6；
  role 分布 attack17 / defense5 / movement5 / healing5 / recon4 / logistics4）——
  与旧件 §4.4 审计**逐项一致**，未增未改。
- `[事实]` 带 `v1_effect` 的仍只有 **1 只**：`soul_def_2_10_gu`（kind=status）；
  其余 39 只走 role 兜底曲线。
- `[事实]` 炼蛊/掉落/商店路径零触及 soul 资源（`alchemy.js` / `loot_rules.js` 全文无 soul 引用）。
- `[事实]` 旧件 §4.4 的原文比对结论（4 只有据 / 31 零命中 / 5 词切误会 / 胆识蛊挂人道）
  本刷新未重做，沿用旧件（原著事实不随载体变化）。

## 8. 旧 A/B 两套残留——「互不相通」跨载体延续

- `[事实]` **lab（产品载体）内 B 套零残留**：`soul_magnitude / soul_safe_capacity / soul_calm /
  soul_nature / beast_nature / soul_control_limit / absorb_soul` 在 `wenzhen-web-lab/js/` 全部零命中。
- `[事实]` **B 套完整存活于 Godot 参考侧**：
  引擎 `game/scripts/domain/soul_rules.gd`（五量、strengthen/refine/calm 三操作、
  `collect_soul` 受门限收取、`soul_burst` 爆魂与 bestiality 兽化端点，调参全读 balance.json；
  头注明确「五量用新键，不碰 legacy soul / soul_max / soul_control_limit（T10.1 退役范围）」）；
  命令面 `run_command_rules.gd:320`（`absorb_soul`）；快照 `run_snapshot_builder.gd`；
  测试 `test_soul_rules.gd` / `test_snapshot_transparency_v2.gd` / `test_spec_v4_acceptance.gd`。
- `[事实]` `game/data/balance.json` 仍带 B 套调参 6 键：`soul_burst_capacity_ratio=2`（致死线=2 倍容量）、
  `soul_calm_emotional_below=40`、`soul_calm_beast_below=25`、`soul_calm_departure_below=10`、
  `beast_nature_emerging_above=0.5`、`beast_nature_threshold=1`；world-model 生成基线亦含 B 套字段。
- `[事实]` 既有只读专项盘点可直接引用：`game/world-model/reports/soul-system-audit.md`（FACT+行号）。
- `[分析]` 旧件 §4.1「两套互不相通、代码内注释声明永不互通」的现状，从**同库两套**
  演化为**两库各一套**：A 套（标量 soul/soulMax + AP 档位）在 Web 产品载体；
  B 套（五量三操作）在 Godot 参考实现。若 L1 骨架采纳 B 套语义，落地路径是
  「Godot 参照 → 按投影纪律进 lab」，而非移植代码。

---

## 9. 对旧件 Q1–Q9 的影响一览

| 问题 | 输入变化 |
|---|---|
| Q1 换算骨架 | **加剧**：增长路径归零（§3），soul 在产品中已是「2 档常量+死亡条」，跨百人魂档位的诉求更无从落地 |
| Q2 百人魂生死极限 | 参照物升级：Godot B 套已有 `soul_burst` 端点实现可作参照（§8）；lab 侧为全新实现 |
| Q3 三要素落系统 | 无变化（原著与旧件分析沿用）；落点载体改为 lab |
| Q4 凝魂名录定位 | 无变化 |
| Q5 兽魂改造定位 | 无变化 |
| Q6 机会成本建模 | **收紧**：元石→魂的直接兑换（魂丹）已被 L0 明令退出原型（data.js:8824），Q6 的竞争层设计需在「无直接兑换」前提下重来 |
| Q7 魂道蛊重做方向 | 数据面与旧审计逐项一致（§7）；L0 已另裁定内容批走 Canon→Semantics→verb（RUL-001） |
| Q8 难度分档挂轴 | 旧 §4.7 的 200 局实测基于旧载体（有增长路径），**不可复用**；如需实测须在 lab 重跑（Q3：不得先用旧模拟调难度） |
| Q9 决策顺序 | 维持，且 Q3 裁定已给兜底顺序 S1–S5 |

## 10. 重派上下文（L1 必读的裁定增量）

1. 载体与基准已反转：`RUL-2026-09-25-001`——产品载体 lab.html；基准关系
   game/data / Game Semantics → generated Web data → Web Runtime；Godot = 参考实现。
2. 设计裁决延续：RUL-004~007（魂道设计原则）继续有效。
3. 矛盾现状：A 套（标量）与 B 套（五量三操作）分居两载体（§8）——按 Q3，矛盾仍在，
   L1 回答时按 **S1 soul_foundation / soul_integrity 分离先行 → S2 AP 派生 → S3 魂道蛊与魂攻击入轴
   → S4 修魂资源竞争 → S5 敌人与整局平衡** 给出骨架，不得用旧 200 局数据调难度。
4. 效果层纪律：新增魂类 effect verb 必须走 Wiki/Canon rule → Game Semantic binding → Effect verb，
   禁止 resolver 散落特判（RUL-001 frozen invariants）。
5. 旧件 §7 约束（L0 四禁止、个人项目产能序、三轴死亡/行动点经济已落地）继续适用，
   其中「行动点经济」在 lab 的现形见本件 §2。

## 11. 本件未覆盖 / 未验证（透明清单）

- 未重跑任何局内模拟（含旧 200 局的 lab 复刻）——属重派后的验证批。
- 未重做原著文学取证——旧件 §3 沿用；若 L1 需要凝魂名录之外的补充取证，另派一轮。
- `soul_def_2_10_gu` 的 status 具体状态语义（是否仍为「封印」）只确认了 kind，未逐字核对状态表。
- `missingCriticalState` 缺 soul 的实际运行表现（§5 分析项）未做浏览器实测。
