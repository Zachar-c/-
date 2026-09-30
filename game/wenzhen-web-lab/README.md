# 问真 · Web 游戏

浏览器 Web 版是《问真》当前完整长线游戏的产品载体，主入口为 `lab.html`。产品范围见 [唯一 PRD](../../docs/PRODUCT_REQUIREMENTS_v1.0.md)。Godot 工程保留成熟规则实现与共享数据；浏览器版按完整五层修行流程持续打磨，美术可另行原创设计。

主流程按五境使用 `../assets/wenzhen/web/scene-01.jpg` 至 `scene-05.jpg` 作为环境底图；进入战斗时切换到对应的 `scene-01-battle.jpg` 至 `scene-05-battle.jpg` 战场变体，并叠加同编号的透明 `*-battle-detail.png` 环境前景细节层。

## 实验页（已冻结）

`experiments/fast-loop.html` 是独立视觉/构筑实验（第三套战斗+炼蛊+商店+掉落+存档），**已冻结**：不接新功能、不进产品主链、不用作平衡结论。产品入口唯一为 `lab.html`。详见 `experiments/FROZEN.md`。

## 启动

直接双击打开 `lab.html`。无需 Node、Godot 或联网。

## 操作

- 大厅选择难度 →「开始新局」
- 五层种子化节点图选择路线 → 战斗 / 休整 / 市集 / 野蛊 / 险地 / 异闻
- 战斗：观察、拳脚、蛊虫、结束回合；注意意图与反击预警。杀招暂未开放
- 整备：坊市购蛊、蛊仓出售、炼化、蛊虫合炼、修为突破
- 自动保存；刷新后「继续当前局」
- 开新局会放弃当前局（有确认）
- 五段路线、逐层层主、路线种子和多难度图表均由现有流程生成；完整产品目标与时长见 [PRD](../../docs/PRODUCT_REQUIREMENTS_v1.0.md)

Web 游戏不设材料掉落、材料买卖或材料合成；战后成长来自元石与蛊虫选择，合炼只投入蛊虫与配方要求的元石。Godot 的材料规则和共享源数据保留，但不会投影到 Web 产品。

当前验收边界：最近一份整局报告记录于 2026-09-22，曾标注缺少获胜轨迹；之后的提交已继续扩展 Web 流程，但尚未据此更新整局验收状态。详见 [验收记录](docs/2026-09-22-playable-game-acceptance.md)。

## 存档

进行中存档与跨局旧录都写在浏览器 `localStorage`；换浏览器或清理浏览器数据不会迁移。存储失败会明确提示，不会假装已保存。`contentVersion` 标记完整生成数据快照；进行中存档以 `saveCompatibilityVersion` 校验。当前为 `lab-run-v3`；旧规则的进行中快照不兼容，页面会提示重新开局。最近 24 局会保存结局、种子、路线及局内摘要，可在大厅复走旧种子；旧录与进行中存档分开保存，坏旧录不会覆盖。

异闻路线只开放 Web 规则可完整结算的事件：即时气血代价、元石收益与离开；一局内会先轮完有效事件再重复。诅咒和延迟魂魄债事件仍未开放，避免遗漏战斗副作用。

## 开发

- 测试：`node --test tests/*.test.mjs`。其中浏览器集成用例需要本机安装 Edge 或 Chrome；纯规则与存档单测不需要浏览器。
- 走盘：`node tools/autoplay_lab.mjs --suite smoke --seed 101 --difficulty normal`
- 打包：`node tools/package_lab.mjs --out <新目录>`
- `?debug=1` 打开覆盖页与演武列表
- 动效：`js/motion.js`（GSAP 增强，纯表现层，不写 state）。GSAP 以本地 vendor 引入（`js/vendor/gsap.min.js`），保持 `file://` 离线可玩；GSAP 缺席或系统偏好"减弱动效"时自动静默回退 lab.css 原生 CSS 动画，玩法与走盘不受影响。

## 文档入口

- [EXISTING_CAPABILITY_MAP.md](EXISTING_CAPABILITY_MAP.md)：能力盘点与 Owner 边界
- [docs/lab-runtime-contract.md](docs/lab-runtime-contract.md)：运行时契约（act 写入口、存档、规则 Owner）
- [docs/lab-mechanics-three-questions.md](docs/lab-mechanics-three-questions.md)：机制三问
- [docs/2026-09-22-playable-game-current-state.md](docs/2026-09-22-playable-game-current-state.md)：可玩整局现状
- [docs/2026-09-20-deepening-experiment.md](docs/2026-09-20-deepening-experiment.md)：深化实验记录
- [../wenzhen-web/assets/gu/HIGH-FREQUENCY-CARDS-2026-09-26.md](../wenzhen-web/assets/gu/HIGH-FREQUENCY-CARDS-2026-09-26.md)：高频卡面素材说明
- [docs/MERGE-MVP-LAB.md](docs/MERGE-MVP-LAB.md)：MVP/Lab 合流记录
- [experiments/FROZEN.md](experiments/FROZEN.md)：冻结实验说明
- 历史交接与验收见 [docs/](docs/)（含 2026-09-22 起 playable-game、parity-slice 系列）
