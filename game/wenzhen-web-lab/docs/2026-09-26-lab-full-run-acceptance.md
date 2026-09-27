# 浏览器整局验收记录 · 2026-09-26

```text
SCOPE: 仅 Web lab（game/wenzhen-web-lab/lab.html，contentVersion lab-run-v2）· Godot 不纳入本轮
STATUS: PASS（四项全过 · laya 辅助判定一致 · 残余风险=中低，广度未测）
```

## 0. 结论

| 验收项 | 结果 | 关键证据 |
| --- | --- | --- |
| 胜利路线 | **PASS** | seed 103 · normal：真实终局 `outcome=victory`「五段行程已走完」，55 节点走尽至 L5B |
| 重载续玩 | **PASS** | 地图页重载 state 深比较 **0 diff**；战斗中重载 battle 深比较 **0 diff** 且 boot 直接落战斗页续打 |
| 异闻代价 | **PASS** | 7 次 `accept_event` 结算，blood/stones 增减全部与展示代价精确一致 |
| 旧种子复走 | **PASS** | 终局→大厅 `archive-replay`：seed / 图根 / 初始可选节点 / 前 10 节点序列全部一致 |
| 控制台 | 干净 | 全程 0 exception / 0 console.error |

判定工具：`tools/acceptance_lab.mjs`（本批新增，复用 `tests/helpers/lab_browser.mjs`）——真实 DOM 可见按钮点击、不写 state、不调 act；判定读 `__labSnapshot()` 只读序列化（headless Edge + CDP）。

## 1. 胜利轨迹

seed 103 · difficulty normal · policy gu_first（蛊技优先）。

- 轨迹 55 节点：`L1D0N0 … L5D9N0 → L5B`；终局资源 blood 24/24、stones 3、lifeTime 60、soul 1/4。
- 终局由节点 `nextIds` 耗尽触发；`ending.outcome` 只能由真实终局转移写入（lab-runtime-contract §`ending`）。
- 证据：`acceptance-seed103-normal-gu_first.json`（全量 step ledger）、`ending-seed103.png`。

## 2. 重载续玩（同一局内两次）

| 时点 | 结果 |
| --- | --- |
| 地图页（completed=6） | restored=true · diffCount=0 · inProgress=true；续跑后仍达胜利 |
| 战斗中（turn=2，iron_hide_boar hp=3） | restored=true（battle 深比较 0 diff）· resumed=true · boot 按 `resumePage()` 直接落 battle 页（main.js:143-149），敌血前后一致 |

战斗中重载无需「继续」按钮是产品正确行为（存档带 battle 态时 resumePage 返回 battle），非缺陷。

## 3. 异闻代价结算（7 例，全部精确）

| eventId | 标题 | 展示代价 | 实际结算 | 断言 |
| --- | --- | --- | --- | --- |
| duel_wager | 赌斗押注 | 血-1 · 石+4 | 24→23 / 0→4 | ✓ |
| tithing_cache | 献藏换赏 | 石+2 | 0→2 | ✓ |
| unclaimed_waystone | 无主路钱 | 石+2 | 2→4 | ✓ |
| ropewalk_wager | 索桥赌注 | 血-1 · 石+4 | 23→22 / 0→4 | ✓ |
| sealed_silk_reliquary | 丝封遗匣 | 血-2 · 石+5 | 24→22 / 3→8 | ✓ |
| huajiu_cache | 行者遗藏 | 血-2 · 石+5 | 24→22 / 7→12 | ✓ |
| duel_wager（复现） | 赌斗押注 | 血-1 · 石+4 | 24→23 / 2→6 | ✓ |

事件页截图 `event-seed103-1..7.png`。

## 4. 旧种子复走

`seedOk / rootsOk / availableOk / prefixOk` 全 true；复走按同策略重走前 10 节点，序列与原局逐位一致（`L1D0N0, L1D1N2, L1D2N0, …`）。截图 `hall-archive-seed103.png`、`replay-prefix-seed103.png`。

## 5. laya 辅助判定（决策判断辅助，非权威）

- 模型与传输：`convaiinnovations/laya`（本地 System One，`ai-system/config/jev.json` `transport: "laya"`；pip 包 `laya`，`USE_TF=0`）。
- 输入：种子 103 验收 JSON 全量证据；问题集：四项 choice + overall + residual_risk score（脚本 `laya_judgment.py`，输出 `laya-judgment-seed103.json`）。
- 结果：**五个 choice 全部 top-1 = pass**；校准概率 pass 0.44–0.53（fail/inconclusive 保留可见概率质量）。
- `residual_risk` = 1.54 / 3，最高概率档「moderate：单一局/工具面覆盖不足」——与「胜利仅单种子」的广度缺口一致，判读与人工复核吻合。
- 地位：辅助判定；主证据是确定性断言 + 真实运行时（`docs/BALANCE_EVIDENCE_DISCIPLINE.md`）。

## 6. 数据点（决策器下限参照，非难度结论）

朴素 balanced 策略（拳脚优先）0/16（normal）与 0/16（easy），全败于气血/魂魄耗尽，最深 43 节点（batch-*.log，32 局，softlock=0，console error=0）。gu_first（蛊技优先）即达成 normal 胜利——策略质量对通过性影响显著；本数据不构成对人类难度的判断。

## 7. 残余与后续

- 胜利种子广度：当前 1 个胜利种子（103）；seed 109 同策略败局（36 节点，但其重载/异闻/复走证据同样全绿）。扩大种子面属后续批次。
- harness 偶发一次页面求值异常（与并行 pip 安装/多浏览器实例的资源竞争同现），单独重跑未复现；工具侧未复现即未修。
- `soul 1/4` 全程未动（种子化异闻只有气血/元石代价）——与魂轴现状（lab 内零增长路径）互相印证。

## 8. 产物清单

- `game/wenzhen-web-lab/tools/acceptance_lab.mjs`——整局验收驱动（四项一次会话覆盖）
- `screenshots/2026-09-26-lab-acceptance/`
  - `acceptance-seed103-normal-gu_first.json` / `acceptance-seed109-normal-gu_first.json`（全量证据）
  - `batch-normal-balanced-101-116.log` / `batch-easy-balanced-101-116.log`（32 局朴素策略参照）
  - `laya-judgment-seed103.json`（System One typed judgment + 校准概率）
  - `ending-*.png`、`event-*.png`、`reload-*.png`、`hall-archive-*.png`、`replay-prefix-*.png`
