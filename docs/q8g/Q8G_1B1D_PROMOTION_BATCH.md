# Q8-G 1-B1-d：human / slave / soul / refine / sword 五派 promotion 收尾批（施工与验收记录）

> - **上游**：1-B1-c 关口 + 世界语义裁定（五派均 design_only 已验收；sword 已按方案 B 定稿 environment+gather）
> - **范围**：五派骨架链 5×4=20 条 promotion recipe + 配套品质带实例 15 个 + 测试；**收口后 19 派骨架全落（bone 单独补批）**
> - **状态**：✅ 施工完成，聚焦 10/10 + 全量 unit 1418/1418 + 交互闭环 17 屏全绿

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 新增 15 个品质带实例（5 派 × 档 2–4），材料 65 → **80** |
| `data/refinement_recipes.json` | 新增 20 条 `kind=promotion` 配方（总计 **76 条**） |
| `tests/unit/test_promotion_1b1d.gd` | 新增 10 条测试 |

## 2. 五派骨架链

| 派 | 链（rank 1→5） | 跨 role 步 | 主材品质阶梯（provisional） | 石耗 |
|---|---|---|---|---|
| human | 虚荣蛊 → 虚情假意蛊 → 悲伤蛊 → 情蛊 → 爱情蛊 | 无（全 atk 情感沉沦线） | 遗墨纸片 → 名家信札 → 宗师手札 → 圣贤遗篇 | 10/18/30/45 |
| slave | 驭犬蛊 → 鞭蛊 → 驭狼蛊 → 驭兽蛊 → 奴隶蛊 | 第1步 atk→mov（驯一犬者持鞭） | 兽革扣 → 厚兽革 → 兽王革 → 万兽纹革 | 10/18/30/45 |
| soul | 摄魂蛊 → 魂火蛊 → 魂雾蛊 → 魂冥蛊 → 英灵蛊 | 第1–3步 atk→def→heal→log（摄魂→养魂→入冥） | 魂絮 → 凝魂玉屑 → 魂将残晶 → 先贤英魂核 | 10/18/30/45 |
| refine | 熔蛊 → 合炼蛊 → 纯蛊 → 凝蛊 → 九转升炼蛊 | 全四步（atk→log→atk→def→log，工序即谱系） | 熔炉灰 → 地火熔渣 → 五金熔英 → 九转炉心 | 10/18/30/45 |
| sword | 鞘蛊 → 藏锋蛊 → 剑锋蛊 → 剑气蛊 → 飞剑蛊 | 第1–2步 def→atk→mov（鞘→藏锋→剑锋→剑气→飞剑） | 断刃屑 → 陨铁屑 → 寒铁屑 → 天外玄铁屑 | **6/8/12/18** |

- 🔴 **Economic Red Line 首次真实咬合**：sword 链终点 `sword_atk_5_02_gu`（飞剑蛊）存在商店 offer（直取 **70 石**），标准阶梯累计 125 石**违例**——按 provisional 纪律将 sword 石耗下调为 6/8/12/18（累计 **66 < 70** ✓），并写入 recipe `source` 存档。其余 19 个目标无 offer，维持 SKIP 台账。
- 新实例全部 `origin_status=design_extension`、`semantic_basis.type=design_only`（派级裁定已验收）+ 分层声明。

## 3. 验证记录

| Gate | 检查 | 结果 |
|---|---|---|
| Schema / M1 | 全量 validate 清洁；20 条换 definition、严格 +1、同流派、min_rank 阶梯；sword output 零撞 fixed | ✅ |
| 品质阶梯 | 每步消耗对应 `mat_<school>_<step>`，四带递进钉住 | ✅ |
| 执行 e2e | human 链 rank1→5 连炼（元石账本按 10/18/30/45 精确） | ✅ |
| 拒绝路径 | human 1→2 缺品质带材料必须拒绝 | ✅ |
| 红线 Gate | sword 第4步**实比通过**（66 < 70）；其余 19 目标 SKIP 台账（`skipped==19` 钉住） | ✅ |
| 聚焦测试 | `test_promotion_1b1d.gd` **10/10（225 asserts）** | ✅ |
| 全量 unit | **1418/1418** | ✅ |
| 交互闭环 | 17 屏全绿；`AUDIT[Refine]` 可点 455→**475**（+20 新卡接线） | ✅ |

## 4. 债务与遗留

| # | 项 | 归属 |
|---|---|---|
| 1 | 15 个品质变体 provisional 命名未做原文考据 | 可选：按 R14–R18 补 |
| 2 | bone 派世界模型论证 + promotion 配方 | 单独补批（暂缓维持） |
| 3 | 材料获取通道未落地（80 种材料中仅旧 7 种接池）| 1-C / 1-D |
| 4 | 品质带↔转数映射 | F8 / Batch 2 |

## 5. Batch 1 promotion 骨架状态

**19/20 派骨架落地**（a: force/gold/wisdom/heaven；b: fire/water/wind/wood/earth；c: blood/dream/luck/qi；d: human/slave/soul/refine/sword）——**bone 待世界模型论证后单独补批**。
按 Batch 1 路线，下一阶段为 **1-C（战斗产石 + 材料生产）**，随后 1-D（掉落分层清偿可达性债务）、Batch 1 总验收（Gate A/B/C）。
