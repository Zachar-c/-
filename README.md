# 蛊祖

《蛊真人》原文资料整理与单机肉鸽游戏原型项目。

仓库同时保存两类内容：

- 原文精编、记忆库与游戏设计原始数据。
- 南疆凡人修行肉鸽的设计、实施计划与后续 Godot 原型代码。

## 从这里开始

- [项目决策浓缩对话](docs/项目决策浓缩对话.md)：快速了解已经确认的游戏方向与版本边界。
- [南疆冒烟版设计](docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md)：玩法、数据和 LLM 边界的完整规格。
- [南疆冒烟版实施计划](docs/superpowers/plans/2026-08-21-nanjiang-roguelite-smoke-implementation.md)：分任务实现顺序与验收标准。
- [协作约定](AGENTS.md)：人工与代理继续编辑本仓库时应遵循的规则。

## 分支

| 分支 | 用途 |
| --- | --- |
| `master` | 原始资料、设计文档和项目入口。 |
| `codex/nanjiang-smoke-prototype` | 南疆冒烟版的游戏原型工作分支。 |

## 运行原型

南疆冒烟版是一个本地可复现的 Godot 原型。固定种子 `101` 会生成包含商队纠纷、地脉争夺和升仙窗口的验证路线；没有网络或云端服务时，交涉仍使用本地模板继续。

- 目标引擎：Godot `4.6.2`。
- 测试框架：仓库已包含 GUT `9.x` 于 `addons/gut/`。
- 启动：`powershell -ExecutionPolicy Bypass -File tools/play.ps1`。
- 单元测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`。
- 集成测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite integration`。
- 蛊卡纵向切片验收（迷雾路线、原子提交、死亡重开）：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_v3_roguelike_vertical_slice.gd`。
- 全量检查（测试、无窗口启动、空白错误）：`powershell -ExecutionPolicy Bypass -File tools/check.ps1`。

`tools/godot.ps1` 统一定位 Godot 控制台程序：优先使用环境变量 `GODOT_CONSOLE_PATH`，其次使用 WinGet 的本机安装路径。`tools/play.ps1` 同样支持用 `GODOT_PATH` 覆盖图形版 Godot 路径。这样 CI、终端和手工验收共用同一入口，不依赖编辑器生成的脚本缓存。

可选云端对话适配器只读取环境变量 `NANJIANG_CLOUD_DIALOGUE_KEY`，不将密钥写入存档。当前适配器不配置网络传输时必定回退到 `data/dialogue_templates.json` 中的本地文本；读档复用已校验的对话回复，不重新请求云端。

首版玩家界面与离线对话均为中文，不提供语言切换；节点 ID、规则键、事件日志和存档字段仍保持 ASCII，以维持数据与存档的稳定性。调试窗口标题 `Nanjiang Smoke (DEBUG)` 保持不变。

## 范围说明

首个可玩版本是南疆、单机、固定身份开局、45--90 分钟的一局修行人生：从新开窍凡人开始，经过资源、情报、人情、战斗与机缘选择，最终冲击蛊仙并进入成功、险成或失败求生三种结局。

它不是方源剧情复刻，也不以青茅山为唯一舞台。原著资料用于还原世界规则、物品关系与事件因果；剧情模式、其他地域、多身份、随机资质和蛊仙阶段玩法留待后续版本。
