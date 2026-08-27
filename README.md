# 蛊祖

《蛊真人》同人单机卡牌肉鸽《蛊路求生》——以《蛊真人》世界规则为素材的修行肉鸽原型项目。

仓库同时保存两类内容：

- 原文语料与设定提炼物（`分支：六卷精编版/`）与游戏设计原始数据（`肉鸽设计-原始数据/`）。
- 《蛊路求生》的设计、实施计划与 Godot 4.7.2 原型代码。

## 从这里开始

- [项目决策浓缩对话](docs/项目决策浓缩对话.md)：快速了解已经确认的游戏方向与版本边界。
- [机制先行锁死规格书](docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md)：**权威基线**——核心玩法循环/资源/流派/地图/战斗/交互/肉鸽规则。
- [南疆冒烟版设计](docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md)：旧基线，仅作参考。
- [协作约定](AGENTS.md)：人工与代理继续编辑本仓库时应遵循的规则。

## 分支

| 分支 | 用途 |
| --- | --- |
| `master` | 唯一主线：语料、设计文档与《蛊路求生》Godot 原型代码；新功能批直接落 master 并推 gitee。 |
| `ui-sts-redesign` | UI 重设计分支的历史名号，内容已全部合入 master（与 master 同点），主工作树检出中，仅为分支名遗留。 |

## 运行原型

《蛊路求生》是本地可复现的 Godot 卡牌肉鸽原型，单局目标 3--5 小时、200--300 有效节点（2026-08-25 裁定）。每次开局自动生成新种子，路线、掉落与事件随种子分化；种子 `101` 保留为固定演示/回归路线。没有网络或云端服务时，交涉仍使用本地模板继续。

- 目标引擎：Godot `4.7.2`。
- 测试框架：仓库已包含 GUT `9.6.1` 于 `addons/gut/`。
- 启动：`powershell -ExecutionPolicy Bypass -File tools/play.ps1`。
- 单元测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`。
- 集成测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite integration`。
- 全量检查（测试、无窗口启动、空白错误）：`powershell -ExecutionPolicy Bypass -File tools/check.ps1`。
- 导出 Windows 包（需先在 Godot 编辑器安装 4.7.2 导出模板）：`powershell -ExecutionPolicy Bypass -File tools/export.ps1`，产物 `build/win/gu-zhenren.exe`（不入库）。Release 包无调试面板（§16.22，F12 门禁经实测）；调试用 `--export-debug` 产物或直接 `tools/play.ps1`。

`tools/godot.ps1` 统一定位 Godot 控制台程序：优先使用环境变量 `GODOT_CONSOLE_PATH`，其次探测 `DevEnv\tools` 与 WinGet 的本机安装路径。`tools/play.ps1` 同样支持用 `GODOT_PATH` 覆盖图形版 Godot 路径。这样 CI、终端和手工验收共用同一入口，不依赖编辑器生成的脚本缓存。

可选云端对话适配器只读取环境变量 `NANJIANG_CLOUD_DIALOGUE_KEY`，不将密钥写入存档。当前适配器不配置网络传输时必定回退到 `data/dialogue_templates.json` 中的本地文本；读档复用已校验的对话回复，不重新请求云端。

首版玩家界面与离线对话均为中文，不提供语言切换；节点 ID、规则键、事件日志和存档字段仍保持 ASCII，以维持数据与存档的稳定性。窗口标题跟随项目名：开发/调试构建为「蛊真人 (DEBUG)」，Release 构建为「蛊真人」。

## 范围说明

当前可玩版本：南疆舞台、单机、固定身份开局、单局目标 3--5 小时（200--300 有效节点）的修行人生：从新开窍凡人开始，经资源、情报、人情、交易、战斗与机缘选择，冲击五转修为与结局（成功/险成/失败求生/蛊化坠落/真结局等，统一结算）。核心循环（大厅→地图→节点→战斗→结算→轮回）已通，进入待发布流程。

它不是方源剧情复刻，也不以青茅山为唯一舞台。原著资料用于还原世界规则、物品关系与事件因果；剧情模式、其他地域、多身份、随机资质和蛊仙阶段玩法留待后续版本。
