# P4 判定：月光 Rank1 切片 GAME_GENERATION_READY

> 日期：2026-09-26。依据：RUL-2026-09-25-001 GATE（六条件）+ L1 计划 §17-20。
> 切片范围：月光蛊 / 小光蛊 / 月芒蛊 / 杀招 km_light_converge / 炼蛊链（月光+双小光→月芒）/ MVP 一转战斗循环（lab.html）。
> 本判定按六条件逐项给证据；每条注明局限。换皮测试已自动化（tests/skin-test.test.mjs）。

## GATE 六条件逐项

| # | 条件 | 判定 | 证据 |
|---|---|---|---|
| ① | 独立 Wiki-only benchmark ≥45/50 | **PASS** | RULES 簇 GEN-2 独立出题复测 **48.5/50**（lore/wiki/tools/benchmark-rules.md，覆盖切片全部规则域：炼蛊/杀招/道痕/灾劫）；runtime 基准一阶 **19/19 独立 Pack-Only 盲测**（benchmark-runtime-stage1.md，覆盖切片编译知识可行动性）。局限：切片实体页（moonlight-gu/small-light-gu）未单跑独立 Wiki-Only 基准，由 runtime 盲测间接覆盖——列入 GEN 轮换队列 |
| ② | 关键 Canon Rule/Entity/Relation 已编译进 Canon Runtime | **PASS** | `lore/runtime/`：entities 156（含三蛊）+ entity_states 11（月刃消耗/印记等）、rules 94（REF-001..024/KM-001..020/PE/CAN-43）、relations 2（supports + refinement，全部属于本切片）、packs 2；独立盲测 19/19（P1 批，commit ddf2c6be） |
| ③ | 切片关键字段无 UNKNOWN/裸名占位 | **PASS** | tests/skin-test.test.mjs「GATE-③」：三蛊 rank/role/school/v1_effect 全实、无 UNKNOWN/TODO/占位标记；三蛊 source 字段 `source: novel` + `source_class: canon_driven_v1`。注记：moon_glow_gu 无独立实体页，其 canon 身份由 roster-3 rank + refinement relation 承载（实体页归 P5 扩容） |
| ④ | Canon→Game Semantics binding 明确 | **PASS** | Game Semantics 层落点 `game/world-model/semantics/`（执行契约 V1 + 真源映射表）；切片三蛊 `source_class: canon_driven_v1` + `canon_refs`（CAN-SMALL-LIGHT-001/002，可在 lore/runtime/rules.json 解析）+ `canon_anchors`（E:V 锚点）——C5 断言强制；role 曲线绑定 balance.effect_budget → PROJ-LAB-ROLE-CURVE-001 显式投影 |
| ⑤ | Runtime conformance 全通过 | **PASS** | tests/conformance.test.mjs C1–C5 **15/15**（生成一致性/效果 Golden Cases/投影/防静默兜底/provenance）；canon_runtime + canon_pack **14/14**；全量 257 测试 256 过（唯一失败为 B 线在途 data.js 节点标签项，scope 外） |
| ⑥ | 切片核心玩法不依赖 legacy_role_fallback | **PASS** | 玩家可玩组合=MVP 覆写（PROJ-LAB-MVP-GU-EXCEPTION-001 显式例外，7 只含裁定四蛊）；杀招结算=组件合成（换皮-2：伤害 3+1=4，预制 effect 不驱动）；敌 HP=kit 吞吐推导（check_balance 49/49，目标回合区间维持）。legacy 兜底曲线仍服务广度内容（shop 池等非核心路径），其收敛计 P5 |

## 换皮测试（Mechanic Distinctness，已自动化）

`tests/skin-test.test.mjs` 4/4：

1. **行为可辨识**：三蛊 effect 签名（kind/amount/ignoreEvasion/suppress/inspect/support）两两互异——隐藏名称后不是「strike 3 → strike 4」式同质换皮。
2. **标签无关结算**：全部改名后杀招组件合成逐字节一致；伤害=组件合成 3+1=4，预制 effect(5) 不驱动（L0 2026-09-22 裁定的执行证据）。
3. **Canon 关系按 id 绑定**：supports（小光→月光）与 refinement（月光+双小光→月芒，output_rank 2）换皮后仍成立。
4. **无占位**：GATE-③ 断言常驻。

## Derived Content Ratio（L1 计划 §19 指标，基线登记）

- **切片内**：核心玩法（MVP 组合+杀招+敌 HP 包络）100% 走显式投影/组件合成/吞吐推导；三蛊效果为手填 `v1_effect`（带 canon 引用，canon_driven_v1 分类）。
- **全库**：手填显式效果 62/802 + MVP 覆写 7；fallback 曲线经编译投影服务 ~740 只广度蛊；kill moves 组件合成运行时派生。派生比例随 P5 批量迁移上升——本指标只登记基线，不作门禁。

## 判定

**月光 Rank1 切片 = GAME_GENERATION_READY（六条件全 PASS）。**

解锁与后续：

- P5 批量扩展解锁（长尾蛊/敌人持蛊化/配方/杀招/Context Packs 的 breadth-first 迁移，按 C1–C5 门禁逐批走）。
- 显式非目标（后续切片增量，不阻塞本判定）：敌人持蛊化（enemies.json 仍 hp/intent 型，R0 换皮风险 #2）、世界实体派生掉落、节点世界事件生成、moon_glow 实体页、Godot legacy 曲线收敛（debt 登记）。
- 维持条件：切片相关 Wiki/数据/语义层任何变更须重跑 C1–C5 + skin-test + 对应基准；GATE 状态随回归失效。
