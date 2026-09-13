# Installed Agent Skills

ZCode 在 `<project>/.agents/skills/<name>/SKILL.md` 自动发现这些技能。

## 仓库原生技能（本项目的 gu / 问真领域技能，随仓库提交）

| 技能 | 用途 |
|---|---|
| `gu-data-content` | 修改 `data/*.json` 内容（蛊/敌人/池/配方/商店/NPC/事件等），保住目录引用与种子化推进 |
| `gu-domain-change` | 修改 `scripts/domain/` 领域规则（战斗/地图/经济/持久化/结局），保持确定性状态转换 |
| `gu-godot-delivery` | 跨切面 Godot 交付（运行时设置、领域/表现边界、release/debug 分离、端到端验证） |
| `gu-ui-flow-verify` | `ui/`、`scenes/`、`scripts/presentation/` 表现层流程改动与信息透明度校验 |
| `wenzhen-visual-style` | 问真 UI 美术风格唯一权威规范（基线图 `assets/base_ref.png` 随技能自带） |

> 2026-09-13 自 `scripts/core/.agents/skills/` 迁入：技能发现只扫描"当前目录向上到仓库根"，不向下进入子目录，原位置不可被发现；且技能正文引用的 `AGENTS.md`、`scripts/domain/` 均为仓库根相对路径，迁到根目录后路径语义才正确。
> 同日修正过时陈述：UI 工作流由 `.guitkx`/RUI 更新为 `scenes/ui/**/*.tscn` 现状；权威规格改为按主题二分（蛊/经济/战斗/合成以 2026-09-01 规格为准）；移除不存在的 `data/cards.json` 锚点；capture 输出路径更正为 `scripts/core/.superpowers/ui_captures/wenzhen/`（按需生成）；UI 改动补齐 domain-ui 契约回写要求。

## 第三方技能

## 行为协议类（工作流框架）

| 技能 | 用途 | 来源 | 许可证 |
|---|---|---|---|
| `test-driven-development` | 实现任何功能/修复前先写失败测试 | [obra/superpowers](https://github.com/obra/superpowers) @ `b36e082`（skills/test-driven-development） | MIT |
| `systematic-debugging` | 遇到 bug/测试失败时先定位根因再修复 | [obra/superpowers](https://github.com/obra/superpowers) @ `b36e082`（skills/systematic-debugging） | MIT |
| `verification-before-completion` | 声称完成前必须先跑验证命令并确认输出 | [obra/superpowers](https://github.com/obra/superpowers) @ `b36e082`（skills/verification-before-completion） | MIT |

安装时剔除了 systematic-debugging 的 CREATION-LOG.md 与 test-pressure-*.md（技能自检文档，运行时不需要）。

## 领域知识类（Godot / GDScript 参考）

| 技能 | 用途 | 来源 | 许可证 |
|---|---|---|---|
| `godot-gdscript-mastery` | GDScript API 雷区与模式（静态类型、signal 架构、@onready 生命周期等） | [thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills) @ `4c4d0ff`（skills/godot-gdscript-mastery） | LGPL-3.0 |
| `godot-resource-data-patterns` | 数据驱动设计模式（Resource 数据库、序列化、类型化集合），契合本仓库 JSON 数据表架构 | [thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills) @ `4c4d0ff`（skills/godot-resource-data-patterns） | LGPL-3.0 |

注意：`godot-testing-patterns` 同样来自 gd-agentic-skills 但**有意未装**——它面向 GdUnit4，而本项目测试栈固定为 GUT（`tools/test.ps1`），保留会引入冲突指导。`fernforestgames/agent-skill-godot` 也未装——依赖两个 MCP 服务器。

## 与仓库约定的优先级

这些技能提供通用工作流与 Godot 模式参考；本仓库 `AGENTS.md` 与 `docs/contracts/module-interfaces/` 是权威，冲突时以仓库约定优先（例如技能中的 Resource/`.tres` 示例需映射为本仓库的 JSON 数据表 + `content_catalog` 加载模式；技能中的 GdUnit4 示例不适用）。
