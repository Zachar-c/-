# 约束体系 v2 —— 取代此前全部约束

> **层级（2026-09-20 补）**：本文件属**第 3 层「阶段契约」**，低于第 1 层 PRD 与第 2 层 AI 开发协议。
> 权威链以根 `AGENTS.md`「文档权威链」一节为准。**本文件不得推翻 PRD 或协议**，冲突时以上位为准。
> 下方原表述「凡与本文件冲突的旧文档一律以本文件为准」，效力**仅及第 3 层及以下的旧文档**，
> 不得解释为凌驾 `docs/PRODUCT_REQUIREMENTS_v1.0.md` 与 `docs/CHANGE_CONTROL_PROTOCOL_v1.0.md`。
>
> **生效依据**：制作人裁定 2026-09-17「把目前所有的约束都无效，探索新的高效可行办法，不要被旧有的屎山束缚了手脚」。
> **效力**：本文件取代下列全部既往约束。凡与本文件冲突的旧文档，一律以本文件为准，旧文档降级为历史档案。

---

## 1. 作废清单（既往约束，全部失效）

| 组 | 作废内容 | 原位置 |
| --- | --- | --- |
| A 设计宪章 | 全部此前被当作"最高层级"的设计文档与宪章 | `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md`、`2026-08-25-mechanics-first-lockdown-design.md`、`2026-09-04-wenzhen-visual-direction-design.md`、`2026-08-28-doc-system-standard-design.md`、`docs/项目决策浓缩对话.md` |
| B 内容登记册 | 对每一条内容强制 `source_class` / `source_ids` / `canon_review_status` / `adaptation_note` 的审查制度 | `docs/lore/canon-index.md`、`adaptation-register.md`、`game-rule-register.md`、`content-source-schema.md` |
| C 批次裁定 | 全部批次裁定、工单、可达性轨道 | `docs/q8*`（RULING / WORKSHEET / BATCH / REACHABILITY）、`2026-08-25-rulings-batch-implementation-spec.md` |
| D 冻结与门禁 | Stage 0 硬 Gate、「通过前不得改生产 `scripts/` `data/` `scenes/`」的冻结令 | 同上 A 组文件 §0.1 / §7 |
| E 执行纪律 | 「Agent 无选职权」「不得自行决定数值」「语义冻结≠数值冻结」 | `docs/q8g/Q8G_BATCH0_RULING.md` |
| F 协作流程 | 四角色写区、Shared 单写者区、5 步协议、git 禁令、17 审计标签、约 30 个逐特性 verify 脚本、worktree 验收 | `docs/contracts/2026-09-12-agent-ownership-contract.md`、`AGENTS.md` 相关段落 |
| G 我自己的派单纪律 | 「三域裁定必须走 3-agent 流水线」「裁定必写裁定书」等自我加码 | 本会话派单 |

**作废不是删除**：上述文件仍在原位，只是不再有约束力。需要时可作历史参考。

## 2. 三条不随本次裁定作废的事项

这三条**不是流程规矩**，放弃它们等于直接破坏你要的功能或造成不可逆损失。我不擅自放弃，但也不拦你——你说放弃，我就照办。

| # | 事项 | 为什么不是"规矩" |
| --- | --- | --- |
| 1 | **可复现**（种子确定性） | 这是「同一种子跑出同一局」这个功能本身。作废它 = 你此前要求的复现验收作废，且全部平衡结论不可复算。 |
| 2 | **改前可回滚** | 仓库 `.git` 已损坏过 5 次（现存 `.git.broken-20260916` 为证）。这不是纪律，是防止不可逆损失。 |
| 3 | **不复制原著正文** | 法律边界，不是项目规矩。 |

## 3. 新约束体系（6 条，全部可执行、可自动验证）

| # | 规则 | 落地方式（可执行） |
| --- | --- | --- |
| **R1** | **数据即规范**：结构约束由 schema + 校验器强制，不靠文档说服人 | `tools/validate_world_model.py` |
| **R2** | **一条命令验收**：校验 + 测试 + 冒烟跑局。~~退出码即结论~~ → **退出码仅对 Python 工具链成立；Godot/GUT 链路看文本，见下方更正** | `tools/accept.py` |
| **R3** | **单一裁定入口**：一条裁定一个文件，替代批次文档堆 | `rulings/*.json`（见 §4） |
| **R4** | **默认放行 + 自动快照**：任何文件都可改；改前自动快照，改后自动校验；不再有"禁止修改" | `tools/snapshot.py` |
| **R5** | **约束必须可执行**：任何新规则必须写成脚本里的断言；写不进脚本的规则不许存在 | 评审口径 |
| **R6** | **验收不靠人勾选**：结论由脚本输出，不靠人读文档打勾 | `tools/accept.py` |

> **R2 判据更正（2026-09-20，实测）**：原表述「退出码即结论」**对本仓库的 Godot 链路不成立**。
> 实测：非 console 版 Godot 二进制在 `--headless` 下**零 stdout 且退出码 0**；
> `game/tools/test.ps1` 因取不到文本而**恒返回 1**。两种表现都与真实结果无关，本会话曾据此误判。
> **正确口径**：Python 侧（`accept.py` / `validate_world_model.py` / `check_upstream_drift.py`）看退出码；
> **Godot/GUT 侧只看 GUT 文本**（`Passing` / `Failing` / `Asserts` 三项数字），不看退出码。
> 该更正同时登记为根 `AGENTS.md` 的 V1 条。

## 4. 裁定文件格式（R3）

```json
{
  "ruling_id": "RUL-2026-09-17-003",
  "date": "2026-09-17",
  "by": "producer",
  "scope": ["gu", "enemy", "economy"],
  "statement": "裁定原文（逐字）",
  "voids": ["旧条目 id 或文档路径"],
  "effects": [
    { "target": "world-model/data/balance.json#/entities/0/run/starter", "action": "replace", "to": "…" }
  ],
  "status": "RULED"
}
```

## 5. 旧 vs 新（成本对照）

| 目的 | 旧做法 | 新做法 | 成本 |
| --- | --- | --- | --- |
| 改一个数值 | 5 步协议 + 3 登记册 + Gate | 直接改 + 跑 `accept.py` | 分钟级 → 秒级 |
| 加一个实体 | 写 spec + 登记 source_ids + 审查 | 加数据 + schema 校验通过 | 天级 → 分钟级 |
| 判断能否提交 | 17 审计标签 + 约 30 个 verify 脚本 | `accept.py` 退出码（Godot/GUT 链路须读文本，见 §3 更正） | 小时级 → 秒级 |
| 回滚 | 手动 + git 纪律 | 快照目录 + 一条命令 | 分钟级 → 秒级 |

## 6. 本文件不做什么

- 不删除任何旧文件（只解除约束力）。
- 不主张作者身份或版权。
- 不代替你对玩法做决定：数值与玩法仍由你拍板，我只负责让改动**快、可验证、可回滚**。
