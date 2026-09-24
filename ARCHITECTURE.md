# 项目架构、目录与数据组织

本文件描述既有组织方式；完整来源与目录边界以 [PROJECT_MAP.md](PROJECT_MAP.md) 为准。

| 目录 | 职责 |
| --- | --- |
| `game/wenzhen-web-lab/` | 《问真》当前 Web 完整产品入口与玩家流程 |
| `game/` | 《问真》成熟 Godot 规则实现与共享数据来源；可为 Web 产品提供参考和生成数据 |
| `lore/wiki/` | 已蒸馏知识、分析及来源定位 |
| `lore/research/` | 研究资料与设计原始材料 |
| `editorial/` | 编辑部资料、精编流水线 |
| `fortune/app/`、`fortune/server/` | 独立应用及服务端 |
| `ai-system/` | Worker 执行约定与任务资料 |
| `docs/` | 产品权威、开发协议、规格、计划与债务 |
| `archive/` | 历史资料 |
| `source/` | 本地原始资料，不进入 Git |

游戏数据真源为 `game/data/`；`game/world-model/` 中保留的治理、裁定与报告不构成另一套运行时。各实现的数据加载与接口以所属项目契约为准，本次目录规范不调整数据 Owner。

新文档按职责进入对应目录，根入口链接到详细内容，避免复制成第二份权威。新增或移动来源时同时更新项目地图与 [债务清单](docs/debt.md)。
