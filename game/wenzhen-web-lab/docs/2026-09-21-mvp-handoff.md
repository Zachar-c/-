# 2026-09-21 · 10 分钟 Web MVP

入口：`game/wenzhen-web-lab/mvp.html`

原 `index.html` 仍保留为上游 Web lab，不受本次 MVP 影响。直接双击 `mvp.html` 即可运行，不需要构建或本地服务。

## 本局范围

固定路线：

```text
山脊猎犬 -> 大巴扎 -> 铁皮山猪 -> 炼蛊台 -> 山脊悍客 -> 雷冠狼王 -> 结算
```

- 玩家 1 人，初始 5 只蛊。
- 4 场战斗、1 次三选一交易、1 次炼蛊或保炉、1 次 Boss 阶段战。
- 只从 `js/data.js` 读取蛊、敌人、气血、意图、反制与 Boss 阶段数据；MVP 自己只保存单局状态与流程。
- `mvp_content.js` 只定义本局内容选择和少量原型参数，不复制 Godot 数值表。

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
  "file:///C:/Users/Zachary/DevEnv/06_%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE/gu-zhenren/game/wenzhen-web-lab/mvp.html" `
  "wait:800,shot:C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren\output\playwright\mvp-check.png,log" `
  "1280,720"
```

本日实现后的手工走盘已完成：

- 猎犬反制先吞掉一次直接攻击，反制失效后可击杀。
- 大巴扎“稳购”实际支付 3 元石并增加 2 只小光蛊。
- 炼蛊把月光蛊与小光蛊消耗为月芒蛊。
- 月芒蛊可直接破掉下一只敌人的反制并压制其 1 回合。
- 雷冠狼王半血转入第 2 阶段，`麻痹长嗥` 实际焚元 2。
- 结算页记录战斗、交易、炼蛊、最终构筑与剩余资源，可重开。

## 已知边界

- 这是单局 MVP，不做存档、成就、难度、完整地图、完整商店或大规模蛊目录。
- 月芒蛊的“压制反制”是本 MVP 为验证合成改变规则而新增的 lab-only 行为；Godot 数据与原运行时未声明该规则。
- 现阶段平衡仍使用既有 Web lab 原型基线与真实敌人数据，不足以作为正式数值结论。
