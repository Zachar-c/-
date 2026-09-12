# Q8-G 1-B1-a：force / gold / wisdom / heaven 四派 promotion 批（施工与验收记录）

> - **上游**：材料前置批收口（`Q8G_1B1_MATERIAL_FRONT_BATCH.md`）+ 世界语义裁定（`Q8G_1B1_SEMANTIC_GATE_PROPOSALS.md` §4，18/19 通过）
> - **范围**：四派骨架链 4×4=16 条 promotion recipe + 配套品质带实例 12 个 + 测试
> - **状态**：✅ **CLOSED（2026-09-13 二次审阅正式关闭）**——Economic Red Line Gate 通过（口径复用 1-A：累计成本=石+材料 value，baseline=商店最低直取价；机制非空断言 + 16 目标 SKIP 台账 + offer 出现自动激活比较）；语义分层闭环（派级依据 / 实例扩展两层不互读）；provisional 品质映射边界保持。剩余均为计划内工作：bone 论证（暂缓）· 获取通道（1-C/1-D）· 品质映射（F8/Batch 2）· 1-B1-b（fire/water/wind/wood/earth）

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 新增 12 个品质带实例（4 派 × 档 2–4），材料 26 → **38** |
| `data/refinement_recipes.json` | 新增 16 条 `kind=promotion` 配方（20 条总计） |
| `tests/unit/test_promotion_1b1a.gd` | 新增 7 条测试（结构 / M1 / 品质阶梯 / e2e / 拒绝路径） |

## 2. 四派骨架链（全部 atk 线、零跨 role，世界语义已验收）

| 派 | 链（rank 1→5） | 主材品质阶梯（provisional） | 语义依据 |
|---|---|---|---|
| force | 斤力蛊 → 十斤之力 → 一钧之力 → 十钧之力 → 挽澜蛊 | 兽筋 → 荒兽筋 → 兽王筋 → 太古荒兽筋 | derived_D1 |
| gold | 铜蛊 → 青铜舍利 → 白银舍利 → 黄金舍利 → 紫晶舍利 | 砂金 → 矿脉金砂 → 精金屑 → 藏山金精 | derived_D1 |
| wisdom | 思想蛊 → 学习蛊 → 才华蛊 → 推演蛊 → 慧剑蛊 | 灵思墨 → 谋算墨 → 传世墨锭 → 圣贤残墨 | design_only |
| heaven | 灾蛊 → 乾蛊 → 雷蛊 → 雷盾蛊 → 宿命蛊 | 天尘 → 雷涤尘 → 穹核尘 → 命数尘 | design_only |

- 石耗沿用 1-A provisional 阶梯：**10 / 18 / 30 / 45**（每步）。
- 材料：每步消耗对应品质带实例 ×2（`mat_<school>_<step>`）。
- ⚠️ **品质带 ↔ 转数映射为设计提案**（crude/plain/refined/prized ↔ 1→2/2→3/3→4/4→5）：M-8 明确不冻结，本批落地的是"设计提案 + 测试钉住防漂移"，最终由 F8 校准。
- 语义继承分层（2026-09-13 审阅明确）：**派级 semantic_basis = derived_D1 / design_only**（证明该形态/来源路线与流派的关联合理性）；**具体品质材料实例 = design_extension**（纯设计命名，原文未证明荒兽筋/兽王筋等存在或必然同道痕）。两层不得互读。
- source_class 阶梯按类型标签设计：force 走 common_beast→fierce_beast→beast_king；gold/earth 类走 environment；wisdom 走 gu_master+trade；heaven 走 environment+event——组合均可解释（Gate 0）。

## 3. 验证记录

| Gate | 检查 | 结果 |
|---|---|---|
| Schema / M1 | 全量 validate 清洁；16 条全部换 definition、严格 +1、同流派、input_min_rank 阶梯 | ✅ |
| 结构 | 四链步间连通（step n 输出 = step n+1 输入）、与既有 fixed 输出零重叠 | ✅ |
| 品质阶梯 | 每步消耗 `mat_<school>_<step>`，品质带 crude→plain→refined→prized 递进 | ✅ |
| 执行 e2e | force 链 rank1→5 四步连炼：definition 每步更换、rank 递进、洞天单实例、元石账本 500-103=397 | ✅ |
| 拒绝路径 | 缺品质带材料拒绝（gold 1→2 持兽骨 9 必须失败） | ✅ |
| 聚焦测试 | `test_promotion_1b1a.gd` **9/9（193 asserts）**（含 Economic Red Line Gate 两条） | ✅ |
| 全量 unit | **1386/1386** | ✅ |
| 交互闭环 | 17 屏 `dead=[] no_ui_click=[] occluded=[]`；`AUDIT[Refine]` 可点 403→**419**（+16 新卡全部接线） | ✅ |

## 4. 债务与遗留

| # | 项 | 归属 |
|---|---|---|
| 1 | 品质带↔转数映射（本批提案 crude/plain/refined/prized 四带）| F8 模拟 + Batch 2 校准 |
| 1b | ~~Economic Red Line Gate 缺失~~ | ✅ 已补：`test_economic_red_line_holds_...`（机制非空断言防真空通过）+ `..._records_targets_without_a_baseline`（16 目标 SKIP 台账，offer 出现即自动比较） |
| 2 | 12 个品质变体的 provisional 命名未做原文考据（description 已标注）| 可选：后续按 R14–R18 补 |
| 3 | 15 派 promotion 配方未铺（1-B1-b/c/d）| 下一批：fire/water/wind/wood/earth |
| 4 | bone 派：世界模型论证未收口，其 promotion 配方**排除在 1-B1-b~d 之外** | 单独补批 |
| 5 | 材料获取通道仍未落地（38 种中仅 7 种旧材料接入掉落池）| 1-C/1-D |

## 5. 下一批入口

1-B1-b（fire / water / wind / wood / earth）：单处跨 role 模式统一；五派主材均已验收（纯设计），可直接按本批模式铺 recipe + 品质变体。
