# 页面和组件详情结构

## 当前页面入口

本轮玩家入口为 [lab.html](game/wenzhen-web-lab/lab.html)，操作说明见 [Web README](game/wenzhen-web-lab/README.md)：大厅 → 节点选择 → 战斗或其他节点 → 奖励与整备；存档与续玩由当前实现处理。

目录中还保留 `index.html` 与 `mvp.html`，不能仅按文件名把它们当作本轮玩家主入口。

游戏详细页面需求见 [页面清单与需求](game/docs/contracts/2026-09-02-page-inventory-requirements.md)；本轮 Web 范围见 [交付规格](docs/superpowers/specs/2026-09-22-lab-playable-game-design.md)。

## 详情文档记录方式

新增页面或组件详情时，在所属项目记录：用途、入口与退出路径、数据来源、用户操作、加载/空/错误/禁用状态、依赖、验收证据。

独立官网和组件展示站的路由及详情页尚未定义，本文件不代表它们已实现。
