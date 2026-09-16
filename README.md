# 問眞

《蛊真人》同人单机卡牌肉鸽 **《問眞》**（前称《蛊路求生》/旧名 Nanjiang Smoke）——以《蛊真人》世界规则为素材的修行肉鸽原型项目。仓库不提供 `GDD.md`；当前最高设计宪章 = [蛊界世界模型纠偏设计](docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md)，既有机制规格在 Stage 0 通过前仅作为待审计实现材料。

当前版本：`0.9.0`（语义化版本 2.0 单源：`scripts/domain/game_version.gd`，大厅/设置屏统一读取）。

仓库同时保存两类内容：

- 原文语料与设定提炼物（`分支：六卷精编版/`）与游戏设计原始数据（`肉鸽设计-原始数据/`）。
- 《問眞》的设计、实施计划与 Godot 4.7.2 原型代码。

## 当前状态

- **玩法循环已通**：大厅 → 地图 → 节点 → 战斗 → 结算 → 轮回，存读档/流派选择/炼蛊/杀招/商店/事件/休息均已接线，主流程验证无阻塞。
- **视觉方向已定稿**：[问真视觉方向设计](docs/superpowers/specs/2026-09-04-wenzhen-visual-direction-design.md)（纸底网点、墨色、朱砂印章「問眞」）；[视觉最终验收报告](docs/superpowers/specs/2026-09-06-visual-final-acceptance-report.html)。
- **屏幕视觉硬流程**：1280×720 HTML 线框稿 → 逐屏审批 → tscn 实施 → 真窗渲染验收。已交付：大厅、地图、战斗、流派选择、设置、杀招、炼蛊、商店、结算、调试；全部按线框稿 1:1 对齐（线稿留证于 `docs/superpowers/specs/*.html`）。
- **双端可安装**：Windows 与 Android 安装包已导出并入库，见[下载安装包](#下载安装包)。

## 发布说明（v0.9.0）

- 应用图标与启动画面：问真风格（宣纸网点底 + 朱砂「问真」方印），程序化生成（`tools/gen_icons.py`），已接入 Windows/Android 双端。
- 版本正式化：语义化版本 `0.9.0`（去除 `+local` 构建标识），大厅/设置屏统一显示。
- 双端安装包重新导出并入库：Windows（PCK 内嵌、分卷 SHA256 校验）与 Android（`com.wenzhen.game`）。
- 内容规模：802 蛊、20 流派、386+ 合炼配方、37 地图节点、12 敌人、41 条音频。
- 说明：Android 当前使用 debug keystore 签名，可直接 `adb install` 试玩；应用商店上架需替换为正式 release keystore（见 `tools/sign_android.ps1` 注释）。

## 下载安装包

安装包随仓库存储于 `build/`（gitee 单文件上限 100 MB，Windows 包按二进制分卷为两个文件）。点击链接进入文件页后，点右上角「下载」按钮即可获取。

- **Windows**（约 150 MB，分卷 2 个文件，PCK 内嵌，双击即玩；1280×720 窗口）：
  - [gu-zhenren.exe.part1](https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat/blob/master/build/win/gu-zhenren.exe.part1)（~78 MB）
  - [gu-zhenren.exe.part2](https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat/blob/master/build/win/gu-zhenren.exe.part2)（~78 MB）
  - 两个分卷放同一目录后执行合并与校验：`powershell -ExecutionPolicy Bypass -File tools/join_installer.ps1`，得到 `build\win\gu-zhenren.exe`（SHA256 自动校验）。
- **Android**：[gu-zhenren-signed.apk](https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat/blob/master/build/android/gu-zhenren-signed.apk)（~77 MB，单文件，debug keystore 已签名，可 `adb install` 装机；包名 `com.wenzhen.game`；商店上架需换正式 keystore，见发布说明）

安装包均为 Release 构建，无调试面板（§16.22，F12 门禁经实测）。

## 从这里开始

- [项目决策浓缩对话](docs/项目决策浓缩对话.md)：快速了解已经确认的游戏方向与版本边界。
- [蛊界世界模型纠偏设计](docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md)：当前最高设计宪章；规定原著证据、Stage 0 硬 Gate 和改造边界。
- [机制先行锁死规格书](docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md)：既有机制基线——核心玩法循环/资源/流派/地图/战斗/交互/肉鸽规则；其中与世界模型冲突的部分须经 Stage 0 重新裁定。
- [问真视觉方向设计](docs/superpowers/specs/2026-09-04-wenzhen-visual-direction-design.md)：美术风格唯一来源（纸底网点/墨色/朱砂印章）。
- [南疆冒烟版设计](docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md)：旧基线，仅作参考。
- [协作约定](AGENTS.md)：人工与代理继续编辑本仓库时应遵循的规则。
- [文档体系标准与维护规范](docs/superpowers/specs/2026-08-28-doc-system-standard-design.md)：文档分层、命名、作品名口径、维护检查表。
- [模块清单](MODULE-INVENTORY.md)：核心模块与接口约定；[资产与来源](CREDITS.md)、[第三方许可](THIRD_PARTY_NOTICES.md)。

## 目录结构

| 目录 | 内容 |
| --- | --- |
| `assets/` | 美术资产（`wenzhen/` 问真风格：网点、立绘、图标、音乐/音效） |
| `scenes/` | 场景（`ui/screens/` 各屏幕 tscn，`ui/widgets/` 公共组件） |
| `scripts/` | 代码（`presentation/` 表现层、`domain/` 逻辑层、`core/` 基础设施） |
| `data/` | 数值配置（蛊/敌人/道具/事件 JSON/TSV） |
| `docs/` | 设计文档与线框稿留证（`superpowers/specs/`） |
| `tools/` | 开发工具（Godot 定位、测试、导出、校验脚本） |
| `tests/` | GUT 单元/集成测试 |
| `addons/` | 第三方 Godot 插件（GUT 等） |
| `分支：六卷精编版/`、`肉鸽设计-原始数据/` | 原文语料与设定提炼物 |

## 运行原型与开发

《問眞》是本地可复现的 Godot 卡牌肉鸽原型，单局目标 3--5 小时、200--300 有效节点（2026-08-25 裁定）。每次开局自动生成新种子，路线、掉落与事件随种子分化；种子 `101` 保留为固定演示/回归路线。没有网络或云端服务时，交涉仍使用本地模板继续。

- 目标引擎：Godot `4.7.2`。
- 启动：`powershell -ExecutionPolicy Bypass -File tools/play.ps1`。
- 单元测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`。
- 集成测试：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite integration`。
- 全量检查（测试、无窗口启动、空白错误）：`powershell -ExecutionPolicy Bypass -File tools/check.ps1`。

`tools/godot.ps1` 统一定位 Godot 控制台程序：优先使用环境变量 `GODOT_CONSOLE_PATH`，其次探测 `DevEnv\tools` 与 WinGet 的本机安装路径。`tools/play.ps1` 同样支持用 `GODOT_PATH` 覆盖图形版 Godot 路径。这样 CI、终端和手工验收共用同一入口，不依赖编辑器生成的脚本缓存。

可选云端对话适配器只读取环境变量 `NANJIANG_CLOUD_DIALOGUE_KEY`，不将密钥写入存档。当前适配器不配置网络传输时必定回退到 `data/dialogue_templates.json` 中的本地文本；读档复用已校验的对话回复，不重新请求云端。

首版玩家界面与离线对话均为中文，不提供语言切换；节点 ID、规则键、事件日志和存档字段仍保持 ASCII，以维持数据与存档的稳定性。窗口标题跟随项目名：开发/调试构建为「問眞 (DEBUG)」，Release 构建为「問眞」。

## 许可

《問眞》代码与设计文档以 **MIT** 许可发布（见根目录 `LICENSE`）。第三方
资源遵循各自许可证，署名与来源记录见 `CREDITS.md`；其中
game-icons.net 图标为 CC BY 3.0，要求游戏内署名（游戏内「关于」署名
界面按 W3b 工单落地中）。

《蛊真人》为原著作者及其版权方的作品：本项目是**同人原型**，不基于
原著商业授权，与原作无隶属关系；原著设定与名称的权利不因本仓库的
MIT 许可转移。

## 构建与导出

- 导出 Windows（需先在 Godot 编辑器安装 4.7.2 导出模板）：`powershell -ExecutionPolicy Bypass -File tools/export.ps1`，产物 `build/win/gu-zhenren.exe`（分卷入库，见[下载安装包](#下载安装包)）。
- 导出 Android：`powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Preset "Android"` 后执行 `powershell -ExecutionPolicy Bypass -File tools/sign_android.ps1`，产物 `build/android/gu-zhenren-signed.apk`（已签名）。
- 合并 Windows 分卷：`powershell -ExecutionPolicy Bypass -File tools/join_installer.ps1`（SHA256 校验）。

## 分支

| 分支 | 用途 |
| --- | --- |
| `master` | 唯一主线：语料、设计文档与《問眞》Godot 原型代码；新功能批直接落 master 并推 gitee。 |
| `ui-sts-redesign` | UI 重设计分支的历史名号，内容已全部合入 master（与 master 同点），主工作树检出中，仅为分支名遗留。 |

## 范围说明

当前可玩版本：南疆舞台、单机、固定身份开局、单局目标 3--5 小时（200--300 有效节点）的修行人生：从新开窍凡人开始，经资源、情报、人情、交易、战斗与机缘选择，冲击五转修为与结局（成功/险成/失败求生/蛊化坠落/真结局等，统一结算）。

它不是方源剧情复刻，也不以青茅山为唯一舞台。原著资料用于还原世界规则、物品关系与事件因果；剧情模式、其他地域、多身份、随机资质和蛊仙阶段玩法留待后续版本。
