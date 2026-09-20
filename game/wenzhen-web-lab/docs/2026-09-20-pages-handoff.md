# 页面扩展交接（2026-09-20）

> 定位：`wenzhen-web-lab` 的页面验收扩展记录。产品权威仍以仓库高层文档为准，
> 本文件只记录这次原型做到了什么、哪些仍是占位、如何复跑验证。

## 本轮完成

在原「炼蛊 / 杀招 / 战斗 / 覆盖」单页基础上，补齐：

- 大厅：本局进度、资源、记录。
- 地图：从 `data/first_run.json` 读取 12 个当前可解析的首局路线节点。
- 遭遇：节点摘要、真实 `choices`、后继节点；NPC 与事件有数据时展示。
- 人物：读取 `data/npcs.json` 的目标、底线、已知事实、撤退条件与个人货架。
- 坊市：从 `data/shops.json` 读取 8 条可展示报价；其中蛊、材料、补魂丹可真实扣元石购入。
- 休整：调息（回满气血/真元）与离开；其余领域全集选项保持可见但明确禁用。
- 收获：战后路线战果确认页；当前只入账原型元石 +2。
- 终局：路线走完或气血耗尽时展示归因页。

战斗页同时从单敌扩到多敌：可切换目标，逐敌保留意图、阶段、冷却、线索、反击与状态。

## 真实数据边界

- 节点、路线、商店报价、蛊、敌人、事件、NPC、材质名均从 Godot 侧 JSON 生成。
- `tools/build_data.mjs` 仍是 `js/data.js` 的唯一入口。
- 炼蛊与杀招仍只使用既有白名单；坊市新增蛊只进入持有与展示，不扩展杀招白名单。
- 不要把这轮页面状态当成领域层实现：路线选择、掉落池、保底、魂魄完整系统与寿元交易尚未接入。

## 复跑

```powershell
cd game/wenzhen-web-lab
node tools/build_data.mjs
node --check js/data.js
node --check js/main.js
node --check js/journey.js
node --check js/battle.js
```

浏览器验收：

```powershell
node ../wenzhen-web/tools/drive.mjs `
  "file:///C:/Users/Zachary/DevEnv/06_%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE/gu-zhenren/game/wenzhen-web-lab/index.html?silent=1" `
  "wait:800,eval:document.querySelector('[data-tab=map]').click(),shot:.preview/pages-map.png,log" `
  "1280,720"
```

截图落在 `game/wenzhen-web-lab/.preview/`，该目录由 `game/.gitignore` 的 `*.png` 规则排除。
