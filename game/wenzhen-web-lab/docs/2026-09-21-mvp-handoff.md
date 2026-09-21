# 2026-09-21 · 10 分钟 Web MVP

入口：`game/wenzhen-web-lab/index.html`

原实验台已原样保留为 `game/wenzhen-web-lab/lab.html`。直接双击 `index.html` 即可运行，不需要构建或本地服务；若浏览器限制本地资源，可从 `game/` 根目录启动静态服务。

## 本局范围

固定路线：

```text
山脊猎犬 -> 大巴扎 -> 铁皮山猪 -> 炼蛊台 -> 山脊悍客 -> 雷冠狼王 -> 结算
```

- 玩家 1 人，初始 5 只蛊。
- 4 场战斗、1 次三选一交易、1 次炼蛊或保炉、1 次 Boss 阶段战。
- `js/data.js` 提供蛊名、图标、敌人名、肖像和战斗奖励；`mvp_content.js` 只定义本局原型场景的持久资源、敌人意图和反制规则。
- 真元不按回合自动恢复；战斗胜利恢复 2 点真元且不回血，元石可在非战斗阶段以 1→2 碎石还元。
- 每回合 2 念头；观察消耗 1 念头并揭示当前反制，反制持续到敌方行动结束或被正确解法压制。

## 验证

```powershell
cd game/wenzhen-web-lab
node --test tests/mvp_logic.test.mjs
node --check js/mvp_content.js
node --check js/mvp_logic.js
node --check js/mvp.js
```

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
