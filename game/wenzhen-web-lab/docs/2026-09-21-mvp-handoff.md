# 2026-09-21 · 10 分钟 Web MVP

入口：`game/wenzhen-web-lab/index.html`

原实验台已原样保留为 `game/wenzhen-web-lab/lab.html`。直接双击 `index.html` 即可运行，不需要构建或本地服务；若浏览器限制本地资源，可从 `game/` 根目录启动静态服务。

> **后续状态看哪里**：本文件是 MVP 完成时的记录。此后落地的 V4 数值校准、
> `autoplay` 验收门与两个待裁决阻塞，全部记在
> [`2026-09-21-v4-calibration-handoff.md`](2026-09-21-v4-calibration-handoff.md)，
> 本文件不再同步那部分（避免同一状态在两个文件里各自演化）。

## 本局范围

固定路线：

```text
山脊猎犬 -> 大巴扎 -> 铁皮山猪 -> 炼蛊台 -> 山脊悍客 -> 雷冠狼王 -> 结算
```

- 玩家 1 人，初始 5 只蛊。
- 4 场战斗、1 次三选一交易、1 次炼蛊或保炉、1 次 Boss 阶段战。
- `js/data.js` 提供蛊名、图标、敌人名、肖像和战斗奖励；`mvp_content.js` 只定义本局原型场景的持久资源、敌人意图和反制规则。
- 真元不按回合自动恢复；**普通战胜利恢复 2 点气血 + 2 点真元**（V4 唯一的生存校准阀门，不做节点/UI/选择），元石可在非战斗阶段以 1→2 碎石还元。
- 每回合 2 念头；反制**同一类型在本场被观察过一次后永久识别**，不再每回合重新隐藏。
- **正确处理当前反制 → 本次敌方伤害 -3 并取消该意图附带的特殊效果**（下限 0）；未识破则不给减伤（读对 + 做对才给）。

## 验证

Node 22 下 `node --test <目录>` 会报 `MODULE_NOT_FOUND`，**必须显式列出 8 个测试文件**：

```powershell
cd game/wenzhen-web-lab
node --test tests/rules.test.mjs tests/gu_rules.test.mjs tests/run_rules.test.mjs `
  tests/loot_rules.test.mjs tests/shop_rules.test.mjs tests/node_action_rules.test.mjs `
  tests/run_flow.test.mjs tests/mvp_logic.test.mjs
node --check js/mvp_content.js
node --check js/mvp_logic.js
node --check js/mvp.js
node --check tools/autoplay.mjs
```

当前基线：**98/98 通过**。

## 产品验收门（V4 起的第一道门）

88/88 只能证明「按钮能按、状态能变」，证明不了「这个游戏数学上还能不能玩」。
所以从 V4 起，真实 DOM 自动走盘是**必过的产品验收门**：

```powershell
cd game/wenzhen-web-lab
node tools/autoplay.mjs --route all --seed 101        # 三条交易分支 + L1 验收区间判定
node tools/autoplay.mjs --route sacrifice --trace     # 逐回合决策与逐场指标
```

它按 `2026-09-21 L1 冻结规则 V4` 的区间逐项判定（猎犬后 HP≥18 / 山猪后 HP≥12 /
悍客后 HP≥8 / Boss 开战不满血满真元 / 三条路线轨迹不同 / 全部通关 / 各场回合数），
并逐场记录 `HP / Qi / Stone / turnCount / observeCount / damageTaken / guUsage`。
判定不通过时退出码为 3。

浏览器走盘：

```powershell
cd game/wenzhen-web
node tools/drive.mjs `
  "file:///C:/Users/Zachary/DevEnv/06_%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE/gu-zhenren/game/wenzhen-web-lab/index.html" `
  "wait:800,shot:C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren\output\playwright\mvp-check.png,log" `
  "1280,720"
```

本日实现后的手工走盘已完成：

- 猎犬的隐藏反制会持续到敌方行动结束；观察揭示后可选择攻击、收势或保存资源。
- 大巴扎三项分别改变元石/真元储备、护体蛊构筑或真元上限；选择后不可反悔。
- 炼蛊把月光蛊与小光蛊消耗为月芒蛊，并支付 2 真元；月芒命中已洞悉目标时压制反制与特殊效果。
- 雷冠狼王在 14 气血进入第 2 阶段，二阶段含 3 真元的焚元意图。
- 结算页记录战斗、交易、炼蛊、最终构筑与剩余资源，可重开。

## 已知边界

- 这是单局 MVP，不做存档、成就、难度、完整地图、完整商店或大规模蛊目录。
- 月芒蛊的“压制反制”是本 MVP 为验证合成改变规则而新增的 lab-only 行为；Godot 数据与原运行时未声明该规则。
- 敌人意图/反制是本局验证用场景配置，不应回写为正式 Godot 数值结论；当前仍需 L1/L0 试玩后再校准平衡。
- **V4 起的数值校准与验收门状态不在本文件维护**，见
  [`2026-09-21-v4-calibration-handoff.md`](2026-09-21-v4-calibration-handoff.md)。
  一句话摘要：验收门 **19/34**，两个结构性阻塞已上抛 L1、lab 内未自行改数 ——
  ① 炼蛊台消耗月光蛊+小光蛊后真元归零会进入「打不死也死不了」的僵局（soft-lock）；
  ② 反制序列使「不能出手」的回合占比过高，各场回合数约为目标值的 2 倍。
  另有一处反制缺口：悍客 `crossbow_shot` 与狼王二阶段 `thunder_pounce_2` 无 counterPool，天生不可减免。
