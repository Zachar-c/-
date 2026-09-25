# lore/runtime — Canon Runtime Projection（生成物）

> **本目录全部为编译产物，不人工维护。** 修改请到源（lore/wiki 页面 / game/docs/lore/canon-index.md），然后重跑：
>
> ```powershell
> py -3 lore/wiki/tools/compile_runtime.py
> ```

层级定位（见 `docs/design/canon-runtime/2026-09-25-p1-ir.md`）：

```text
原著 Source → Evidence → Wiki（Source of Truth）
                          ↓ 编译边界（compile_runtime.py，唯一入口）
                      本目录 = Canon Runtime Projection（机器可查询，不产生新设定）
                          ↓ Game Adaptation（游戏数值/改编，见 game/data 与 ADP-* 登记）
                      《问真》Runtime
```

## 文件

| 文件 | 内容 |
|---|---|
| `manifest.json` | 编译元数据：原文 sha256/行数、编译范围、计数、coverage、content_version |
| `entities.json` | Entity[]：gu 实体（id 与 `game/data/gu.json` 同键空间），rank 取 roster-3「原文转」口径 + rank_status |
| `rules.json` | Rule[]：CAN-*（canon-index 全部）+ REF-*（炼蛊）+ KM-*（杀招）+ PE-*（真元，生成 ID） |
| `relations.json` | Relation[]：supports / refinement（合炼 n-ary） |
| `packs/*.json` | Context Pack：按场景选装的最小知识包（south_border_rank1_combat / rank1_refinement） |

## 硬边界

- 本层**不含任何游戏数值**（damage/cost/drop_rate 等被编译器禁入字段扫描拒绝）；游戏数值与改编属 Game Projection（`game/data/*` + ADP-*）。
- 所有事实可追溯：`evidence`（E-ID → 原文行号）、`provenance`（wiki 页 / ST 行 / CAN 条目）。
- 原文 `蛊真人-clean.txt` hash 变化或缺失时编译器拒绝输出，E-ID 不会静默指向新原文。
- `rank` 是 Canon 口径（原文转数）；游戏生效值（如 rank_cap 压缩到 5）是 Game Projection，对照 `rank_status` 理解分叉。
