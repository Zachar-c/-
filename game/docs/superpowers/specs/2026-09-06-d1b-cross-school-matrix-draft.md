# D1b 跨流派合炼矩阵 · 首批方向策展稿（2026-09-06）

> 状态：首批 rank3 层已落表（178 方，`tools/generate_cross_school_matrix.py`）；方向矩阵待用户复核——改配对只需改 `SCHOOL_PARTNER` 重跑生成器，分钟级重落。
> 原则（用户裁定 2026-09-06）：3转 = 2转+2转 跨流派；4转 = 3+3；5转 = 4+4。合炼语义按「流派 + 转阶」表达，不按职介。

## 1. 首批方向矩阵（20 道）

| 道 | 伴道 | 锚点 / 推导 |
|----|------|-------------|
| light 光 | qi 气 | R4 月影蛊 光×气 原文锚 clean 17152-17155 |
| blood 血 | light 光 | R5 血月蛊 光×血 同构（读书笔记 A2b 蛊虫盘） |
| qi 气 | light 光 | R4 镜像：气承光耀 |
| water 水 | fire 火 | 水火既济；鬼火蛊水火炼法 clean 150990-151208 |
| fire 火 | water 水 | 水火既济镜像 |
| wood 木 | earth 土 | 木植于土 |
| earth 土 | wood 木 | 土养草木 |
| gold 金 | sword 剑 | 锐金成剑 |
| sword 剑 | gold 金 | 剑承金气 |
| force 力 | bone 骨 | 力发筋骨 |
| bone 骨 | force 力 | 骨承其力 |
| soul 魂 | dream 梦 | 魂梦交感 |
| dream 梦 | soul 魂 | 梦载魂影 |
| wind 风 | qi 气 | 风行气随 |
| refine 炼 | fire 火 | 炉火炼材 |
| heaven 天 | luck 运 | 天命气运 |
| luck 运 | heaven 天 | 运承天时 |
| human 人 | wisdom 智 | 人心生智 |
| wisdom 智 | human 人 | 智出人心 |
| slave 奴 | human 人 | 奴道驭人 |

## 2. 生成规则（确定性）

- 目标：每个无配方产出的 rank3 蛊生成 1 条 fixed 方（本轮 178 条，id 前缀 `mx_`）。
- 主蛊 = 输出同道的 2 转蛊（校内轮转均摊）；伴蛊 = 伴道 2 转蛊（伴道池轮转均摊）。
- 字段：`input_gu_ids`（v1 具体蛊 id，执行必需——fixed 按 definition_id 消耗）+ `input_min_rank: 2` + `output_rank: 3` + v2 `inputs` 镜像（school/rank/count）+ `derived:` source 锚。
- 幂等：重跑替换全部 `mx_` 方；策展配方（`moon_glow_fixed` 等）不动。
- 职介语义（atk 配 atk）仅 39/180 可满足，按「流派+转阶」裁定不作为约束；职介加权（合成亲和）归杀招/synergy 线，不在本矩阵。

## 3. 覆盖率进度（tools/verify_recipe_coverage.py）

| 层 | 基线 | 首批后 | 目标 |
|----|------|--------|------|
| rank3 | 2/180 | **180/180** ✅ | 180 |
| rank4 | 0/97 | 0/97 | 97（次批：3转+3转） |
| rank5 | 0/147 | 0/147 | 147（三批：4转+4转） |
| 合计缺口 | 422 | **244** | 0 |

## 4. 待复核与次批预告

- 方向矩阵 20 行如需改配（如 gold→force 而非 sword、slave→refine），改表重跑即可。
- 次批（rank4，97 方）：主蛊 = 同道 3 转蛊（首批产物，链式可达已打通），伴道方向沿矩阵。
- 三批（rank5，147 方）：主蛊 = 同道 4 转，同理。三批完成后 `verify_recipe_coverage.py` 零缺口 = D1b 验收达成。
