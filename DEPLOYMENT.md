# 构建与 Cloudflare 部署

## 已有本地发行方式

Web 可玩版使用 [package_lab.mjs](game/wenzhen-web-lab/tools/package_lab.mjs) 生成离线发行目录，命令见 [开发流程](DEVELOPMENT.md)。该脚本保留页面与资源的相对目录，并生成入口说明及文件哈希清单。

发行验收要求见 [W7 交付计划](docs/superpowers/plans/2026-09-22-lab-playable-game.md)。打包成功本身不能代替离线游玩、续玩和结局验证。

## Cloudflare 状态

本次未发现已登记的 Cloudflare / Wrangler 部署配置，未执行线上部署。

实际部署前需确定 Cloudflare 项目、发布目录、页面入口及域名，并核实所用服务的配置方法；部署配置就绪后在此记录构建命令、发布命令、环境变量名称、验收和回滚方式。凭据不得写入文档或 Git。

本文件不将仓库根目录指定为发布目录；本地原文、研究资料、测试及其他子项目不应随游戏发行包发布。
