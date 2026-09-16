# 待办 / 待裁定清单（2026-09-16 全量待办清扫后）

> 接替 `2026-09-10-open-items-and-decisions.md`（已标历史）。
> 口径：只列**当前仍需动作**的事项。已闭环的不占行。
> 优先级：**P0** 阻断玩法或用错会伤人 · **P1** 需裁定/需人工 · **P2** 队列 · **P3** 债务。
> 本轮清扫性质：**文档同步 + 登记关闭**，零生产规则变更（Stage 0 冻结令）。

---

## 0. 速览

| 类别 | 数量 | 含义 |
|---|---|---|
| **A. 等人工/裁定** | 4 | Stage 1 切片批准、pacing 解冻、L5 平衡、多敌 loot 口径 |
| **B. 纵向切片后才排** | 3 | 剑道 P2-1/P2-2、剑意论证、（若裁定需要）bound 重引入 |
| **C. 可并行内容/资产** | 2 | 美术批次 2 生图、印章裁切 |
| **D. 长期残留** | 1 | GUT ObjectDB 泄漏（已大幅下降） |

---

## A. 等人工 / 裁定

| # | 事项 | 状态 | 优先级 | 卡在哪 | 你只需给 |
|---|---|---|---|---|---|
| ~~**A1**~~ | ~~World Model Stage 0 证据债~~ | **✅ Gate GO（2026-09-16 重跑）**：24/24 完整 P0 引用；manifest 指纹已按只读原文校正 | — | 已解锁 | 进入 Stage 1 |
| **A1b** | **Stage 1 纵向切片** | 设计已出；**数据完备化已落地**（5 蛊 effect/feeding + 切片单测 5/5）；身份夹具/路线探针未做 | P1 | 身份与择道改造 | 是否拆流派择道 |
| **A2** | **`pacing.json` 是否解冻** | 同时卡 D2 层性向 / D4 事件频率 / D7 L1–L2 零精英 | P1 | Reachability「不改 pacing」红线 + 作废 f1 语料 | 一句：解冻 / 不解冻 |
| **A3** | **L5 终局随机化** | `miasma_vein_lord` 强度倒挂（有效 HP 21 < L4 27） | P2 | 需平衡裁定或另立终局候选 | 抬数值 / 换终局叙事 |
| **A4** | **多敌遭遇 loot tier 错位** | `LootResolver` 只读 `battle.enemy_kind`；多敌模板不写该键 ⇒ 精英按 common 结算 | P2 | 动 `LootResolver` 红线 | 修 / 不修 |

## B. 纵向切片批准后才排（当前仍不直接改生产规则）

| # | 事项 | 备注 |
|---|---|---|
| B1 | 剑道 **P2-1 剑气临时蛊** / **P2-2 pierce** | T15/T16 已落地；需新 effect/结算分支前再写规格 |
| B2 | `sword_intent` 是否接线 | 重查已把「剑意」从核心降级；需另行论证是否值得做 |
| B3 | 重新引入 combat `status:bound`（若 Stage 0 裁定需要） | 现役 logistics 默认已改 `heal:1`，无死数据 |

## C. 可并行（内容 / 资产，不碰规则）

| # | 事项 | 入口 |
|---|---|---|
| C1 | AI 美术批次 2（29 条提示词） | `docs/art/BATCH-2-PROMPTS.md` → 生成后 `tools/import.ps1` |
| C2 | 印章网格裁切 15 枚 + 道徽入框（可选） | `seal_missing_grid.png` |

## D. 长期残留（不阻断）

| # | 事项 | 现状 |
|---|---|---|
| D1 | GUT 语境 ObjectDB/RID 泄漏 | 已从历史 2 万级降到退出期十余实例；属 GUT 既有遗留 |

---

## 本轮清扫关闭的登记项（对照）

| 原登记 | 关闭证据 |
|---|---|
| T16 残锋「第一阻塞」 | 代码+契约+12 单测已落地（2026-09-15）；AGENTS/审计已改口 |
| logistics `bound` 死数据 | `v1_battle.json` logistics → `heal:1`；`gu.json` 无显式 bound |
| refine 卡隐藏 `stone_cost`/材料 | `_append_recipe_card` 已摊开并写 `executable`；`test_action_preview_service.gd` |
| module-01 缺 T16 键/API | `gu_slots` 残锋键、`settle_sword_marks`、`play_kill_move.confirmed` 已回写 |
| module-08 缺 `confirmed` | 已补一句命令面约定 |
| 剑道/肉鸽审计「T16 未完工」 | 已加状态同步横幅（正文保留为历史快照） |
| 双编号「两个 2.」与已闭环流水账 | AGENTS 待办整节重写 |

## 建议的下一批

1. **Stage 0 证据人工确认**（唯一 P0）——不完成则整条世界模型线停着。
2. 同步等你裁定 A2 pacing；其余（美术 C 线）可与 Stage 0 并行。
3. 解冻后再开剑道 P2 规格，不扩包。
