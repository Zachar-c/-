# 开发与发布流程

1. 阅读 [AGENTS.md](AGENTS.md) → [PROJECT_MAP.md](PROJECT_MAP.md) → 目标目录 README / AGENTS。
2. 核对已有改动、适用规格、允许写区与验收要求。Worker 执行遵循 [执行协议](ai-system/WORKER_PROTOCOL.md)。
3. 在所属目录修改；产品范围与技术路线变更遵循 [变更控制协议](docs/CHANGE_CONTROL_PROTOCOL_v1.0.md)。
4. 运行对应验收，保存真实输出；L2 独立复核改动、数字及根因。
5. 同步当前待办、变更记录和受影响的入口；提交、推送遵守根规则与现有阻塞项。

## 《问真》Web 完整产品

浏览器版本是当前产品载体，主入口为 [`lab.html`](game/wenzhen-web-lab/lab.html)；玩法目标与长线范围见 [唯一 PRD](docs/PRODUCT_REQUIREMENTS_v1.0.md)，启动和开发说明见 [Web README](game/wenzhen-web-lab/README.md)。

## Web 开发与验收

在 `game/wenzhen-web-lab/` 目录内使用 Node.js：

```powershell
node --test tests/*.test.mjs
node tools/autoplay_lab.mjs --suite smoke --seed 101 --difficulty normal
node tools/package_lab.mjs --out <全新输出目录>
```

命令来源：[Web README](game/wenzhen-web-lab/README.md)。打包拒绝覆盖已有目录；数据生成会更新 `contentVersion`，发布内容前须保证进行中的长局存档仍可继续。

## Godot 规则与数据来源

`game/` 保留成熟 Godot 4.7.2 规则实现。Web 消费共享数据时，通过 `game/wenzhen-web-lab/tools/build_data.mjs` 从 Godot 数据表生成 `js/data.js`，不要手改生成文件。

组件分发见 [REGISTRY.md](REGISTRY.md)，构建与部署状态见 [DEPLOYMENT.md](DEPLOYMENT.md)。
