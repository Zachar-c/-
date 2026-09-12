# Q8-G 1-B1 材料前置批：施工与验收记录

> - **上游**：`Q8G_1B0M_MATERIAL_MODEL_FREEZE_DRAFT.md`（✅ 冻结生效，D-B0-2M 收口）
> - **范围**：工作单 §4 工单第 1–5 项 —— schema 扩展、既有材料回填、19 派低档主材注册、校验同步、测试、债务账本
> - **不做**：promotion recipe 改写（1-B1-a~d 批）、掉落池变更（1-C/1-D）、定价（Batch 2）
> - **状态**：🟡 **工程施工 ✅ / 世界语义验收 🔴 / 不进入 1-B1-a**
>
> **审阅修订记录（2026-09-13，世界模型层审阅）**：
> 1. 🔴 **首版越权已纠正**：19 派材料曾把"主道痕 = 流派之道"从 M-11 的设计默认候选落成注册事实（`mat_bone_1 → bone` 直接触碰事实库 D3"骨≠骨道"）。裁定：**不删数据、不返工 schema**，全量降级为 `origin_status=design_candidate` + `semantic_basis.type=design_only`，在逐派世界语义验收前不得视为已证；
> 2. 新增 `origin_status`（original / design_extension / design_candidate）与 `semantic_basis`（{type, rationale}）两字段并纳入强校验——`moon_dew` / `venom_sac` 标记 `design_extension`（原文名 0 命中，E0），防止游戏扩展被误当世界模型批准的原生材料；
> 3. 测试拆为三 Gate：**Schema Gate / Data Integrity Gate / World Semantic Gate**——"schema 合法"不再等同"世界语义合法"。

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 7 种既有材料回填 `form` / `source_class` / `acquisition_mode` / `quality_band`；新增 19 种流派低档主材（`mat_<school>_1`），材料总数 7 → **26**；二轮审阅后全量补 `origin_status` + `semantic_basis` |
| `scripts/domain/content_catalog.gd` | 新增 `MATERIAL_SOURCE_CLASSES` / `MATERIAL_ACQUISITION_MODES` / `MATERIAL_QUALITY_BANDS` / `MATERIAL_ORIGIN_STATUS` / `MATERIAL_SEMANTIC_BASIS_TYPES` 五个枚举白名单；material 校验块追加强制校验（缺 form、枚举越界、缺 origin_status、semantic_basis 缺失/类型未知/rationale 为空即报错） |
| `tests/unit/test_material_model_fields.gd` | 新增 11 条测试，按三 Gate 分组（详见 §4） |

**schema 约定（冻结文档条文 9 的落地）**：

- `dao_tags[0]` = **主道痕**（约定，非新字段）；次道痕只降低适配强度，不做硬排他（M-10）。
- `source_class` ∈ `common_beast / fierce_beast / beast_king / gu_immortal / foreign_race / gu_master / environment / craft` —— **类型标签，无序**（M-4）。
- `acquisition_mode` = **玩家取得材料的方式** ∈ `hunt / gather / trade / husbandry / event / craft_byproduct / seize[设计] / inherit[设计]`（M-6）。
- `quality_band` ∈ `crude / plain / refined / prized`（provisional 四带；档位语义与 ↔ promotion rank 映射**未冻结**，M-8，交 1-B1/Batch 2）。

## 2. 既有 7 材料回填

| 材料 | form | source_class | acquisition_mode | quality_band | 备注 |
|---|---|---|---|---|---|
| beast_bone 兽骨 | bone | common_beast | hunt | crude | dao_tags `['force']` 不变 |
| beast_blood 兽血 | blood | common_beast | hunt | plain | `['blood','qi']` 双道痕保留，divisible 规则不受影响 |
| venom_sac 毒囊 | sac | common_beast | hunt | refined | |
| moon_dew 月华露 | dew | environment | hunt | refined | boss 池材料，主道痕 `moon` |
| moon_blue_petal 月蓝花瓣 | petal | environment | trade | crude | 原文实证：集市购买喂月光蛊（3834） |
| boar_king_tusk 野猪王牙 | tusk | **beast_king** | hunt | refined | 原文 E4：合练晋升之物（10974） |
| inheritance_token 传承信物 | token | gu_master | **inherit** | prized | 传承体系，不入 promotion（M-9 方向） |

## 3. 19 派低档主材注册（🟡 M-11 设计候选，未过 World Semantic Gate）

> 🔴 **状态声明（二轮审阅后）**：以下 19 条均为 **`origin_status=design_candidate` + `semantic_basis.type=design_only`** 的**设计候选**——
> "主道痕 = 流派之道"只是 M-11 的默认候选，**不构成世界语义已成立的注册事实**。
> 尤其 `mat_bone_1`（白骨粉 → bone）：事实库 D3 已证"骨≠骨道"（142182 象腿骨承载**力道**道痕），
> 本条 dao 归属属于待验证设计，裁定时须重点审。
> 进入 1-B1-a 前，须逐派回答"为什么这个材料在《問眞》的世界里能成为该流派 promotion 的主材"，
> 答案三选一并显式记录：原文事实 / D1-D3 推导 / 纯游戏设计。

| 流派 | 实例 id | name_zh | form | source_class | acquisition_mode | 语义关联依据 |
|---|---|---|---|---|---|---|
| blood | `mat_blood_1` | 兽凝血膏 | blood | common_beast | hunt | 血道"以血养蛊、精血饲蛊" |
| qi | `mat_qi_1` | 凝气露 | dew | environment | gather | 气道"掌气之有无形转化"，露为气凝之形 |
| force | `mat_force_1` | 兽筋 | sinew | common_beast | hunt | 力道"借荒兽之力入体"，筋腱为兽力载体 |
| soul | `mat_soul_1` | 魂絮 | wisp | environment | event | 魂道"掌魂魄之壮养收摄"，魂息残絮 |
| refine | `mat_refine_1` | 熔炉灰 | ash | craft | craft_byproduct | 炼道"以材换力"，炉灰为炼制副产 |
| wisdom | `mat_wisdom_1` | 灵思墨 | ink | gu_master | trade | 智道"念头为兵、算计无形"，墨载思算 |
| dream | `mat_dream_1` | 眠雾 | mist | environment | event | 梦道"掌梦境虚实"，眠者梦缘凝雾 |
| luck | `mat_luck_1` | 福签 | charm | environment | event | 运道"掌气运消长"，气运聚集处签枝 |
| sword | `mat_sword_1` | 断刃屑 | filing | gu_master | hunt | 剑道"掌剑意锋锐"，折剑碎屑承剑意 |
| wood | `mat_wood_1` | 青树脂 | resin | environment | gather | 木道"掌草木生发"，生发之脂 |
| fire | `mat_fire_1` | 地火膏 | grease | environment | gather | 火道焚灭之威，地脉火口膏脂 |
| water | `mat_water_1` | 潭心珠 | bead | environment | gather | 水道"上善若水"，深潭水眼凝珠 |
| wind | `mat_wind_1` | 游风羽 | feather | environment | gather | 风道"风行无形"，疾风卷落轻羽 |
| gold | `mat_gold_1` | 砂金 | grit | environment | gather | 金道"金铁之利"，河床淘金 |
| earth | `mat_earth_1` | 壤髓泥 | loam | environment | gather | 土道"厚土承载"，地脉滋养泥芯 |
| slave | `mat_slave_1` | 兽革扣 | leather | common_beast | hunt | 奴道"驭兽役傀"，驯兽革具原料 |
| heaven | `mat_heaven_1` | 天尘 | dust | environment | event | 天道"天纲天罚"，雷雨后异尘 |
| human | `mat_human_1` | 遗墨纸片 | paper | gu_master | trade | 人道"人情百态"，故人书信残页 |
| bone | `mat_bone_1` | 白骨粉 | bone_dust | common_beast | hunt | 骨道"白骨为兵"，研骨成粉 |

> **light 未注册**：按 D-B0-1 口径 (a)，light 谱系（§6.20 复核提案）尚未裁定；其材料随谱系裁定后在 promotion 批补注册。
> **命名声明**：19 个 name_zh 与 description 均为 `[设计]` provisional 文案，未做原文考据；其 `semantic_basis.type=design_only` 已如实标注，防止"命名关联"冒充"世界语义成立"。

## 4. 验证记录（三 Gate）

| Gate | 检查 | 结果 |
|---|---|---|
| **Schema Gate** | 五类属性齐全、四枚举合法、未知 source_class/quality_band 被拒、词表无 tier 化成员 | ✅ |
| **Data Integrity Gate** | 全量目录 validate 清洁、主道痕约定（beast_blood 首元素=blood + divisible 规则不受影响） | ✅ |
| **World Semantic Gate** | 全量 origin_status/semantic_basis 声明齐全且枚举合法；缺 semantic_basis 被拒；moon_dew/venom_sac 标 design_extension；19 候选保持 design_candidate + design_only（防静默升格）；mat_bone_1 rationale 含"骨≠骨道"警示 | ✅ |
| 聚焦测试 | `tools/test.ps1 -Test tests/unit/test_material_model_fields.gd` → **11/11（324 asserts）** | ✅ |
| 全量 unit | `tools/test.ps1 -Suite unit` → 全绿（退出时 RID/ObjectDB 泄漏为 AGENTS.md 已登记遗留） | ✅ |
| `content_catalog` 校验红线 | 六新字段纳入逐材料强制校验，词表为代码常量白名单 | ✅ |

## 5. 债务账本（可达性 Gate §5.2，滚动）

| # | 债务 | 状态 | 清偿归属 |
|---|---|---|---|
| 1 | 8 只非 starter 的 1→2 输入蛊（dream_atk_1_09 / earth_atk_1_05 / heaven_atk_1_12 / luck_atk_1_08 / refine_atk_1_10 / water_atk_1_12 / wind_atk_1_07 / wood_atk_1_11） | 未清偿 | 1-D 掉落 / 商店 offer |
| 2 | 19 种 `mat_*_1` 已注册但**无任何获取通道落地**（acquisition_mode 仅语义标注，未接入掉落池/商店） | 未清偿 | 1-C 材料生产 / 1-D 掉落分层 |
| 3 | `quality_band` 档位枚举 provisional（crude/plain/refined/prized），中高档实例未注册 | 未清偿 | 1-B1 promotion 批按需注册；定价 Batch 2 |
| 4 | `quality_band ↔ promotion rank` 映射未定（M-8 明确不冻结） | 未清偿 | 1-B1 promotion 批提出方案，F8 校准 |
| 5 | light 流派材料未注册（谱系待裁） | 未清偿 | D-B0-9（谱系批准）后补 |
| 6 | 🔴 ~~19 派主材的世界语义验收未完成~~ | **✅ 已清偿 18/19（2026-09-13 裁定，见 `Q8G_1B1_SEMANTIC_GATE_PROPOSALS.md` §4）**：blood D2 / force·gold·earth D1 / 其余纯设计，全部落 `design_extension`；bone 暂缓（design_candidate）**但不阻塞** |
| 7 | ~~19 派候选的 `source_class × acquisition_mode` 组合是候选生态设计~~ | **✅ sword 已清偿**（方案 B：environment+gather）；其余组合随各派 promotion 批验收时按 **World Semantic Gate 0（属性组合可解释性）** 复核 |

## 6. 下一批入口（已解锁）

世界语义裁定完成（18/19 通过，bone 暂缓不阻塞），**1-B1-a（force / gold / wisdom / heaven 四派 promotion 配方）开工条件成立**：
- 四派主材均已验收（force/gold=derived_D1，wisdom=design_only，heaven=design_only）；
- recipe 材料消耗按裁定后的 `semantic_basis` 选取，quality 档位按 provisional 品质带标注（M-8，映射曲线 F8 校准）；
- 骨道（bone）promotion 配方**排除在 1-B1-a~d 之外**，待其世界模型论证收口后单独补批。
