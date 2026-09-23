# 问真 · Web 可玩版

## 启动

直接双击打开 `lab.html`。无需 Node、Godot 或联网。

## 操作

- 大厅选择难度 →「开始新局」
- 节点图选择后继 → 战斗 / 休整 / 市集 / 野蛊 / 险地
- 战斗：观察、拳脚、蛊虫、杀招、结束回合；注意意图与反击预警
- 整备：坊市买卖、炼化、开炉、杀招组装、修为突破
- 自动保存；刷新后「继续当前局」
- 开新局会放弃当前局（有确认）

## 存档

写在浏览器 `localStorage`。换浏览器或移动目录不会迁移。存储失败会明确提示，不会假装已保存。

## 开发

- 测试：`node --test tests/*.test.mjs`
- 走盘：`node tools/autoplay_lab.mjs --suite smoke --seed 101 --difficulty normal`
- 打包：`node tools/package_lab.mjs --out <新目录>`
- `?debug=1` 打开覆盖页与演武列表
