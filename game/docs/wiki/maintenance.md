---
title: 知识库维护机制
description: 本 wiki 的更新流程、lint 卫生清单与例行维护提示词（LLM Wiki 方法论）
date: 2026-09-12
tags: [maintenance, workflow, lint, routine]
---

本知识库采用 LLM Wiki（github.com/lucasastorian/llmwiki）的方法论：源文档是唯一事实层（只读），`docs/wiki/` 是综合编译层，文件系统是真相、页面间引用构成知识图谱[^1]。

## 分层架构

| 层 | 路径 | 权限 |
|---|---|---|
| 原始源 | docs/superpowers/{specs,plans}/、docs/contracts/、AGENTS.md、根级报告 | 只读，不修改 |
| 编译层 | docs/wiki/（overview + concepts/ + entities/ + timeline + plan） | Agent 撰写维护 |
| 引擎 | 人或 Agent 阅读时即时综合 | — |

## 新文档接入流程

1. 新规格/计划/报告落入源层后，判断它影响的 wiki 页面（用 [overview.md](overview.md) 导航表定位）。
2. 按影响面更新：写新概念页（concepts/）、新实体页（entities/），或并入既有页面——**一个源通常触及 5-15 个页面是正常的**。
3. 更新受影响页面后，回查引用它的页面（反向链接），保持一致。
4. 更新 [overview.md](overview.md) 的 Key Findings 与导航（仅当范围/结论/结构变化时）。
5. 在 [plan.md](plan.md) 登记动作（What/Why 缩进注记）。

## Lint 卫生清单（每次维护后自查）

- [ ] 每页 frontmatter 四字段齐全：title / description（具体单句）/ date（YYYY-MM-DD）/ tags（≥2）
- [ ] 每个事实主张有脚注引用，引用用完整源文件路径，指向真实存在的文件
- [ ] 无悬空 wiki 链接（页面间相对路径可解析）
- [ ] 无孤儿页（每个页面至少被一个页面链接）
- [ ] date 在实质性修订时更新；编辑时保留既有 frontmatter 字段
- [ ] 表格用于结构化对比；流程关系用 mermaid（节点标签含括号须加引号）
- [ ] 区分 [FACT]/[DESIGN]/[INFERRED]：推断不得写成事实
- [ ] 豁免：`references/` 下的规范提取副本按原文保留（内含示例路径如 diagram.svg），不参与链接 lint

## 例行维护提示词（可按需调度）

> 读 docs/wiki/maintenance.md 与 docs/wiki/plan.md。找出上次运行以来新增或变更的源文档（git log --diff-filter=A/M -- docs/ AGENTS.md 报告）；对每个源：读它，更新 wiki——必要时写新页、把新材料并入既有页、修正所有受影响的交叉引用与脚注引用；跑 lint 清单自查；在 plan.md 登记 What/Why。

## 规范来源

规范提取自 llmwiki 仓库的 mcp/tools/guide.py（Apache 2.0）：页面结构（overview hub / concepts / entities / comparisons / timeline / plan）、frontmatter 必填、每页至少一个可视化、脚注引用回源、交叉引用与引用图、lint 维护工作流、nightly routine 自维护模式[^1]。

[^1]: references/llmwiki-guide-extract.md（规范提取副本，源仓库 lucasastorian/llmwiki，Apache 2.0）
