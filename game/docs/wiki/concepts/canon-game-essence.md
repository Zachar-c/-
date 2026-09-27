---
title: Canon→Game Production View
description: 生产视图：当前游戏真正依赖的 Canon 规则/实体/关系及其 Gameplay 含义与实现状态；非第三真源
date: 2026-09-26
tags: [production-view, canon, semantics, l6]
---

# Canon→Game Production View

**定位（L1 裁决 B1'）**：本页是 **Canon→Game Production View**，不是知识层、不是第三真源。

| Owner | 职责 |
|---|---|
| `lore/wiki` | **FACT OWNER**——机制、事件、人物、世界观全文 |
| 本页 | **PRODUCTION VIEW**——只引用、选择、组织、声明游戏意义 |

本页只能回答：**当前游戏生产真正依赖哪些 Canon Rules / Entities / Relations？**

**禁止**在此重写：蛊虫完整机制、原著事件、人物事实、炼蛊规则全文、世界观结论。

## 条目格式

```text
Canon Ref → Relevant Rule / Entity → Gameplay implication → Game Semantic / Ruling → Implementation status
```

## 失效规则

上游出现 `[已修正]`、CAN 状态变更、Rule 被推翻、Evidence 降级时，对应条目必须标 **STALE**，禁止静默沿用旧结论。

## 知识生产等级

```text
CANON_VERIFIED → KNOWLEDGE_READY → RUNTIME_READY → SEMANTICS_READY → GAME_GENERATION_READY
```

---

## P0 链 · 杀招 ↔ 蛊 ↔ 炼蛊

> 统一规则链（L1）：`Gu → components → Killer Move Runtime Structure`；`Gu/Materials → Refinement Process → new stable Gu structure`。

### 样本：月光 / 小光 / 月芒体系（验证链）

| Canon Ref | Rule / Entity | Gameplay implication | Semantic / Ruling | Status |
|---|---|---|---|---|
| `CAN-SMALL-LIGHT-001`；`E:V1-009704` 等 | 小光辅助月光，月刃体积/攻击扩大（lore [small-light-gu](../../../../lore/wiki/gu/small-light-gu.md)、[moonlight-gu](../../../../lore/wiki/gu/moonlight-gu.md)） | 双蛊连携不是装饰标签；辅助蛊须真实改变主蛊输出 | 待绑定：增幅维度与叠加规则 | **CANON_VERIFIED** · Semantic **OPEN** |
| `CAN-SMALL-LIGHT-002`；`E:V1-015708` | 小光可合炼；月光+双小光→月芒（lore [moon-glow-gu](../../../../lore/wiki/gu/moon-glow-gu.md)） | recipe 不能只当技能解锁钥匙；须承载组件结构 | REL-REFINE-MOONGLOW（runtime 已有） | **RUNTIME_READY**（Pack 样本） |
| ST-MOONGLOW-02…04 | 首炼失败；三倍攻击；一只增幅一倍、两只不叠加 | 合成失败/叠加上限须可结算，不可文案化 | Pack-Only 已盲测 3/3 | **SEMANTICS_READY**（月光切片） |
| KM 体系：杀招=多蛊组合（`CAN-GU-CARE` 邻域；[killer-moves](../../../../lore/wiki/rules/killer-moves.md) KM-*） | 配方蛊是运行结构组件 | 杀招=组件合成，非独立技能表 | RUL-2026-09-21-010 等（挂起项另列） | **KNOWLEDGE_READY** → Semantic **PARTIAL** |
| REF-*：炼化意志/合炼秘方/推演（[refinement](../../../../lore/wiki/rules/refinement.md)） | 炼化=抹意志；合炼须秘方 | 炼蛊是过程不是购买 | 09-01 spec 已有部分绑定 | **KNOWLEDGE_READY** |

### P0 知识债清偿（2026-09-26 首批）

| 项 | 结果 |
|---|---|
| KM 命名规则 | **已核** KM-021（自命名/改名，无登记明文） |
| KM 凡/仙分界 + 技巧族谱 | **已核** KM-022/023（连招变招附招拆招；组件层级分界） |
| KM 连招定义/大宗师门槛 | **已在** KM-010（E:V4-171842/171860、E:V5-332208 复核） |
| REF 平炼 | **已核** REF-028（罕见、年蛊谱系、升炼难度数十至百倍） |
| REF 逆炼定义 | **已核** REF-029（高转→低转；合炼/逆炼二分） |
| REF 修复维度 | **已核** REF-030（非炼法维度，禁发明四维） |
| 残留 | 道痕残留时长量化；并招独立境界；距离限制；魂修赋能体系化；仙蛊屋升级；roster-3 转数未核；杀招 amount 纪律（工程债） |

---

## P1 链 · 力量承载（排队）

真元 / 资质 / 转数 / 念头 / 魂魄 → 「蛊师能力承载模型」。

| Canon Ref | Rule / Entity | Gameplay implication | Semantic / Ruling | Status |
|---|---|---|---|---|
| `CAN-CULTIVATION-001…003`；`CAN-APTITUDE-001…003` | 九转四小境；真元五档；资质丁丙乙甲 | 转数=层级轴非万能倍率 | RUL-2026-09-19-008/009 | **CANON_VERIFIED** · 部分 Semantic |
| primeval-essence / soul-path 规则表 | 双轨真元、魂魄代价 | 节点预算=游戏压缩（须三件套） | 已标 L6 裁定 | **PARTIAL** |

## P2 链 · 经济世界（排队）

经济 / 蛊材 / 养蛊 / 掉落 / 敌人库存 / 交易 → 「打谁、养什么、炼什么、买什么」同一世界经济。

| Canon Ref | Rule / Entity | Gameplay implication | Semantic / Ruling | Status |
|---|---|---|---|---|
| `CAN-ECONOMY-001`；economy-roster 货币双层 | 元石/仙元石；养蛊软上限 | 成本形成软上限，无硬蛊槽 | AGENTS 红线 | **CANON_VERIFIED** · 实现 **存疑** |
| `CAN-BEAST-TIER-*`；enemy-roster | 兽王分级、威胁结构 | 敌人 rank 须可消费世界规则 | canon-index 敌人节 | **KNOWLEDGE_READY** |

---

## Implementation status 图例

| 含义 |
|---|
| **CANON_VERIFIED** | 原著已核（E-ID 可回放） |
| **KNOWLEDGE_READY** | 本问题所需规则已够答 + 基准通过 |
| **RUNTIME_READY** | 已入 Canon Runtime（实体/规则/关系完整） |
| **SEMANTICS_READY** | Canon→Game binding 明确 |
| **GAME_GENERATION_READY** | Conformance 通过，不依赖 Legacy fallback |
| **STALE** | 上游变更未跟——禁止继续当有效结论 |
| **OPEN / PARTIAL / 存疑** | 未绑定 / 部分 / 实现仅作差距对照 |

---

## VOID · 802 蛊目录（L0 2026-09-26）

| 项 | 状态 |
|---|---|
| `game/data/gu.json` 802 生成条目 | **VOID / 已删除 / 不予参考** |
| 原因 | 高度重复、无创意；742/802 role 兜底同质，撑不起牌组构筑 |
| 新血规则 | 仅从 **wiki Canon + 玩法支柱** 重设计；分层 Canon 核 / Derived / Creative；禁止批量同质生成 |
| 本页旧条目 | 凡引用 802 目录规模/映射者一律 **STALE**，只保留 Canon Ref 链 |

## 关联

- 方向与裁决：`lore/wiki/l1-extraction-direction-2026-09-26.md`
- 事实真源：`lore/wiki/`（FACT OWNER）
- 游戏裁定与工程：本目录 concepts / entities
- 失效门禁：随上游 `[已修正]`/CAN/RULE 变更打 STALE（L1 D-B 长期成本入 D-E）
