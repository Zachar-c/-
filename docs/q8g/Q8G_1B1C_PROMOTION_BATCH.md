# Q8-G 1-B1-c：blood / dream / luck / qi 四派 promotion 批（施工与验收记录）

> - **上游**：1-B1-b 关口（CLOSED）+ 世界语义裁定（blood=derived_D2，dream/luck/qi=design_only，均已验收）
> - **范围**：四派骨架链 4×4=16 条 promotion recipe + 配套品质带实例 12 个 + 测试；**bone 按裁定暂缓，不在本批**
> - **状态**：✅ 施工完成，聚焦 10/10 + 全量 unit 1408/1408 + 交互闭环 17 屏全绿

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 新增 12 个品质带实例（4 派 × 档 2–4），材料 53 → **65** |
| `data/refinement_recipes.json` | 新增 16 条 `kind=promotion` 配方（总计 56 条） |
| `tests/unit/test_promotion_1b1c.gd` | 新增 10 条测试 |

## 2. 四派骨架链（叙事链跨 role，依据随 recipe source 存档）

| 派 | 链（rank 1→5） | 跨 role 步 | 主材品质阶梯（provisional） | 语义依据 |
|---|---|---|---|---|
| blood | 血滴子 → 血线蛊 → 血气蛊 → 血狂蛊 → 血手印蛊 | 第1步 atk→rec（血道先寻猎再杀） | 兽凝血膏 → 沁血髓 → 血菩提 → 万血精 | **derived_D2** |
| dream | 梦魇蛊 → 梦黄粱蛊 → 黄粱蛊 → 南柯蛊 → 梦蝶仙蛊 | 全四步（atk→rec→atk→def→atk，典故链） | 眠雾 → 酣梦丝 → 蝶梦纱 → 大梦真绫 | design_only |
| luck | 转运蛊 → 聚蛊 → 运泰蛊 → 运昌蛊 → 鸿运齐天蛊 | 第1步 atk→rec（先聚敛气运） | 福签 → 吉运绦 → 鸿运绫 → 天运符 | design_only |
| qi | 吐气蛊 → 纳蛊 → 气云蛊 → 气虹蛊 → 龙息蛊 | 第1步 atk→heal（一吐一纳为吐纳之道） | 凝气露 → 氤氲珠 → 纯阳息 → 龙涎气 | design_only |

- 石耗 10/18/30/45；材料每步对应品质带实例 ×2；新实例 `origin_status=design_extension` + 分层声明（派级依据 / 实例扩展两层不互读）。
- dream 为典故链（一枕黄粱 → 南柯 → 庄周梦蝶），四步全跨 role、每步有典——跨 role 护栏（1-B1-b 收口新增）已确认：跨 role 是具体谱系设计，不构成流派全局规则。

## 3. 验证记录

| Gate | 检查 | 结果 |
|---|---|---|
| Schema / M1 | 全量 validate 清洁；16 条换 definition、严格 +1、同流派、min_rank 阶梯 | ✅ |
| 结构 | 四链连通、与既有 fixed 输出零重叠（血月蛊已避开）、跨 role 步与谱系表一致 | ✅ |
| 品质阶梯 | 每步消耗对应 `mat_<school>_<step>`，四带递进钉住 | ✅ |
| 执行 e2e | blood 链 rank1→5 连炼（元石账本 500−103=397） | ✅ |
| 拒绝路径 | blood 1→2 缺品质带材料必须拒绝 | ✅ |
| 红线 Gate | 16 目标全部无商店 offer → SKIP 台账（`skipped==16` 钉住）；机制非空断言保持 | ✅ |
| 聚焦测试 | `test_promotion_1b1c.gd` **10/10（225 asserts）** | ✅ |
| 全量 unit | **1408/1408** | ✅ |
| 交互闭环 | 17 屏全绿；`AUDIT[Refine]` 可点 439→**455**（+16 新卡接线） | ✅ |

## 4. 债务与遗留

| # | 项 | 归属 |
|---|---|---|
| 1 | 12 个品质变体 provisional 命名未做原文考据 | 可选：按 R14–R18 补 |
| 2 | bone 派世界模型论证 + promotion 配方 | 单独补批（暂缓维持） |
| 3 | 材料获取通道未落地 | 1-C / 1-D |

## 5. 下一批入口

**1-B1-d（收尾批）**：human / slave / soul / refine / sword 五派（派级裁定均已验收；sword 已按方案 B 改 environment+gather）。收口后 19 派骨架全落（bone 单独补批），Batch 1 转入 1-C（战斗产石）。
