# Q8-G 1-B1-b：fire / water / wind / wood / earth 五派 promotion 批（施工与验收记录）

> - **上游**：1-B1-a 关口（CLOSED）+ 世界语义裁定（五派均 design_only 已验收）
> - **范围**：五派骨架链 5×4=20 条 promotion recipe + 配套品质带实例 15 个 + 测试
> - **状态**：✅ 施工完成，聚焦 10/10 + 全量 unit 1398/1398 + 交互闭环 17 屏全绿

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 新增 15 个品质带实例（5 派 × 档 2–4），材料 38 → **53** |
| `data/refinement_recipes.json` | 新增 20 条 `kind=promotion` 配方（总计 40 条） |
| `tests/unit/test_promotion_1b1b.gd` | 新增 10 条测试 |

## 2. 五派骨架链（单处跨 role，语义已在谱系表解释并随 recipe source 存档）

| 派 | 链（rank 1→5） | 跨 role 步 | 主材品质阶梯（provisional） |
|---|---|---|---|
| fire | 火鸦蛊 → 火炎蛊 → 炎心蛊 → 火龙蛊 → 火焚蛊 | 第4步 atk→heal（焚灭归烬、烬土养人） | 地火膏 → 火岩髓 → 离火精 → 焚天髓 |
| water | 泉蛊 → 涟蛊 → 潮蛊 → 水瀑蛊 → 河蛊 | 第1步 atk→rec（水纹侦察） | 潭心珠 → 寒潭髓 → 沧溟珠 → 弱水精 |
| wind | 风刃蛊 → 啸蛊 → 狂蛊 → 风气蛊 → 风虎云龙蛊 | 第2步 atk→mov（风道擅移形，后三步全 mov） | 游风羽 → 罡风絮 → 天罡翎 → 太虚风息 |
| wood | 木蛊 → 参天蛊 → 木树蛊 → 木藤蛊 → 森林蛊 | 第1步 atk→log、第3步 atk→def | 青树脂 → 百年松脂 → 木灵芯 → 建木青髓 |
| earth | 泥沼蛊 → 脉蛊 → 垒蛊 → 磐蛊 → 地藏花蛊 | 第1步 atk→rec、第3步 atk→def | 壤髓泥 → 黄泉壤 → 地心岩乳 → 息壤精 |

- 石耗 10/18/30/45；材料每步对应品质带实例 ×2；跨 role 依据已写入每条 recipe 的 `source` 字段。
- 新实例全部 `origin_status=design_extension`、`semantic_basis.type=design_only`（派级裁定已验收）、source_class=environment / gather（Gate 0 组合与档 1 一致）。

## 3. 验证记录

| Gate | 检查 | 结果 |
|---|---|---|
| Schema / M1 | 全量 validate 清洁；20 条换 definition、严格 +1、同流派、min_rank 阶梯 | ✅ |
| 结构 | 五链连通、与既有 fixed 输出零重叠、跨 role 步与谱系表一致 | ✅ |
| 品质阶梯 | 每步消耗对应 `mat_<school>_<step>`，四带递进钉住 | ✅ |
| 执行 e2e | fire 链 rank1→5 连炼（含跨 role 步）：definition 每步更换、元石账本 500−103=397 | ✅ |
| 拒绝路径 | earth 1→2 缺品质带材料必须拒绝 | ✅ |
| 红线 Gate | 20 目标全部无商店 offer → SKIP 台账（`skipped==20` 钉住）；offer 出现即自动激活比较；机制非空断言保持 | ✅ |
| 聚焦测试 | `test_promotion_1b1b.gd` **10/10（276 asserts）** | ✅ |
| 全量 unit | **1398/1398** | ✅ |
| 交互闭环 | 17 屏全绿；`AUDIT[Refine]` 可点 419→**439**（+20 新卡接线） | ✅ |

## 4. 债务与遗留

| # | 项 | 归属 |
|---|---|---|
| 1 | 15 个品质变体 provisional 命名未做原文考据 | 可选：按 R14–R18 补 |
| 2 | 9 派 promotion 未铺：blood / qi / force✓… 剩 **human / slave / soul / refine / sword**（1-B1-d）与 luck？——实际剩余：human / slave / soul / refine / sword（1-B1-d 前置需要其派级裁定均已验收 ✅）| 1-B1-d |
| 3 | 材料获取通道仍未落地 | 1-C / 1-D |

> 注：1-B1-c 批（blood / bone / dream / luck / qi）中 blood / dream / luck / qi 已验收，**bone 仍暂缓**——c 批届时为 4 派（blood / dream / luck / qi），bone 单独补批。

## 5. 下一批入口

1-B1-c（blood / dream / luck / qi 四派，bone 除外）：叙事链跨 role 模式，四派主材均已验收（blood=derived_D2、其余 design_only）。
