# 《蛊真人》可追溯视觉知识库 V1

这是给 Codex / AI 生图 / 游戏美术资产使用的结构化知识库。它不是“总结文档”，而是**保留细节的可追溯知识树**。

## 核心 Doctrine

**大道具象，人行其间。**

《蛊真人》的艺术不是让图像象征一个道理，而是让道理成为现实：抽象规则可以被炼成蛊、身体、建筑、地貌和运行机制；人的选择在真实限制与代价中获得重量。

## 使用顺序

1. 先读 `doctrine.md`：了解跨对象原则。
2. 通过 `INDEX.md` 找对象 dossier。
3. 生成图片时读取该 dossier 的 `Visual Thesis`、`Canon Appearance`、`Asset Roles`、`Must Keep`、`Avoid`。
4. `Evidence` 决定某条信息是否能当硬约束。
5. 批量任务直接读取 `machine/dossiers.json` 与 `machine/tokens.json`。

## 不允许的压缩

- 不得只保留一句“东方暗黑仙侠”。
- 不得只保留颜色/材质/光效。
- 不得删除对象级反差、状态、尺度、资产角色、网络漂移和证据状态。
- 不得把社区高频形象自动升级为原著 Canon。
- 不得为了补齐 schema 而捏造原著未明确的形态。

## 文件结构

```text
reverend_insanity_visual_kb_v1/
├─ README.md
├─ doctrine.md
├─ INDEX.md
├─ STATUS.md
├─ schema.yaml
├─ sources.json
├─ dossiers/
│  ├─ gu/
│  ├─ characters/
│  ├─ houses/
│  └─ scenes/
└─ machine/
   ├─ dossiers.json
   ├─ tokens.json
   ├─ doctrine.json
   └─ rejected_conventions.json
```

## 当前规模

- 44 个对象级 dossier
- 42 条来源记录
- 10 个跨对象视觉 Token

## 数据哲学

**总结只做索引，不删除细节。**

如果一个条目只有前序调查结论、尚未在本轮补到来源，它会被保留，但明确标记 `prior_research_needs_source_refresh` / `pending_primary_source`。这比删除有价值的研究、或把未核信息冒充 Canon 都更安全。


## 第二轮 Canon Hardening 01

第二轮没有扩张对象数量，而是把 V1 全部薄弱条目补上文本证据，并新增 `reference_art.md` / `machine/reference_art.json`。

新增原则：**Canon 可以规定“不要锁死形态”**。当原文只支持行为、尺度、场域或观察者关系时，后续生成系统不得为了产图方便伪造固定外形。

Codex 正式阶段建议读取顺序：`doctrine.md` → 单对象 dossier → `reference_art.md` → `machine/dossiers.json`/`tokens.json`，并把 `avoid` 与 `community_drift` 作为负面约束。
