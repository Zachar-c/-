# 蛊库、蛊方与三构筑（世界内容底盘）v0.2

日期：2026-09-27。入口：[README](README.md)。状态：内容层首版，配套 [gu-library.json](gu-library.json)（version 0.2.0-draft）；未做独立 L1 审查，全部游戏映射为待实玩校准的设计值。与 [供应层](supply.json)、[完整模型](model.md)、[事实表](evidence.md) 并列，属同目录研究交付。

## 1. 定位与契约

`gu-library.json` 补齐 [模型](model.md) §12 登记的「命名原著蛊库」缺口：`gu`（蛊库）、`recipes`（蛊方与约束）、`builds`（burst/balanced/sustain 三套构筑）。机器事实底座为 [lore/runtime/entities.json](../../../lore/runtime/README.md)（生成物，本文引用一律锚到 wiki 源页）与 `lore/wiki/gu/` 三个 roster。

引擎契约要点（均已用 `model.mjs` 的 `auditBuilds`/`resolveStage`/`createSupply` 实测通过）：

- `builds` 以构筑 id 为键的对象（`{burst:{...},balanced:{...},sustain:{...}}`），与 `resolveStage` 的 `lib.builds[buildId]` 取法和 [验证器](validate.mjs) `Object.keys(lib.builds)` 一致；每个构筑对象仍带 `id` 字段。
- **主蛊动作映射取自 gu 条目本身**：`resolveStage` 主蛊分支读 `prim.poweredAction`，`slot.poweredAction` 只作用于 fallback（fallback 合并时 `fb.poweredAction` 优先）。因此每只可入槽的 gu 带 `poweredAction` 规范映射（非战斗蛊为 `null`），槽位映射与其保持一致；同一蛊在不同构筑中不重映射。这是对 schema 的最小必要扩展，字段名沿用 [参数表](parameters.json) `actions` 契约，非新造。
- fallbacks 顺序约定：具体替代蛊在前、`gu:null` 占位最后（占位分支会立即截断 fallback 循环）。
- 静态审计口径：槽位复杂度 L=n(n−1)/2 ≤ 心智容量 C=[4,5,6,7,8,12,16,20,24]（未声明 `attainment`，按基础容量保守口径）；每槽必须带 fallback；fallback 不得强于本体（动作伤害×转数基数）；越阶槽位、未知蛊、未知 fallback 一律登记。实测 0 条 issue。
- status 约定：gu 条目 `status`=身份与转数的可靠度；`effects[].status`=单条效果可靠度；slot `status`=「该蛊催动该占位动作」的可靠度（原著多只给能力方向，不给回合制动作，故不少映射为 assumption/inference）。

id 规则：`lore/runtime/entities.json` 有键的蛊，用其 snake_case id 的 kebab 对应（`moonlight_gu`→`moonlight-gu`，与 [供应层](supply.json) 同风格）；entities 无键的原著蛊新造 kebab id（对照表见 §6）。原著事实不取自 `game/data/`。

## 2. 原著蛊虫总表摘要

收录 69 条：lore/wiki 有单页的 13 蛊全收（月光、小光、月芒、月痕、熊力、骨蛊、青藤、硬气、自己、春秋蝉、宿命、智慧、坚持仙蛊；M0 六蛊边界页覆盖石皮/玉皮/白豕/刀翅血蝠身份）+ roster 系可定位转数与效果的代表性蛊。rank 取 canon 口径（roster-3「原文转」或 entities.json `rank`；rank_unstated 者给占位并标 assumption/inference）。`maxRank` 全部 `null`，九转白名单另行（REF-020：绝大多数仙蛊极限八转）。

| 转数 | 条数 | 代表（括号内为收录依据层级） |
|---|---:|---|
| 1 | 13 | 月光蛊（单页已核）、小光蛊（单页已核）、白豕蛊/玉皮蛊/石皮蛊（M0 已核）、青铜舍利蛊（经济已核）、酒虫（弧一时序+个案已核）、九叶生机草/熊力蛊/骨蛊/青藤蛊/硬气蛊/自己蛊（转数未检得、占位一转） |
| 2 | 5 | 月芒蛊（单页已核）、白玉蛊（合炼已核）、月痕蛊（效果已核/转数占位）、邀月蛊（rank 已核/效果未核）、赤铁舍利蛊（已核） |
| 3 | 13 | 血月蛊（已核）、冰肌蛊（已核）、玉骨蛊（已核）、石窍蛊（消耗蛊，已核）、木魅蛊、月蛊、自力更生蛊、铜皮蛊、白银舍利蛊、刀翅血蝠蛊（转数分叉登记）、黄金月/霜霖月/幻影月（秘方系资料整理） |
| 4 | 7 | 血颅蛊、火龙蛊、剑气蛊、全力以赴蛊（多时点 3→4）、古铜皮蛊（晋升链）、月影蛊（压制真元）、黄金舍利蛊（管禁） |
| 5 | 5 | 血手印蛊、血滴子（食精血/裂变，已核）、太光蛊（残蛊三次自毁，已核）、金甲蛊、紫晶舍利蛊（管禁+催化） |
| 6 | 7 | 血神子（血滴子晋升线，已核）、我力蛊、海誓蛊（仙蛊明文/转数并称口径）、挽澜仙蛊（六转口径，双实体疑）、狗屎运蛊（巨阳本命，已核）、定仙游蛊（秘方已核）、春秋蝉（单页已核） |
| 7 | 7 | 坚持仙蛊（单页已核）、智障仙蛊（障碍场已核）、飞剑蛊、龙息蛊、梦甲蛊、天机蛊（天道本质+损寿代价已核）、天妒仙蛊（天道不可催动，已核） |
| 8 | 5 | 雷电蛊（八转/九转双口径，见 §5）、慧剑蛊、悔蛊（镇压匿迹已核）、三气仙蛊（三气归来核心，已核）、鸿运齐天蛊（炼制失败例） |
| 9 | 7 | 宿命蛊（单页已核，双口径）、智慧蛊（单页已核）、命运蛊（316328 已核）、至尊仙胎蛊、九转光蛊、九转火蛊、力量蛊（九转传奇口径+游戏同名重用登记） |

条目 status 分布：fact 49、inference 14、assumption 6（assumption 全部是转数占位条目）。效果方向标注 70 条：attack 25、defense 15、special 17、support 8、recovery 5。仅见 roster 的名字（如爱别离、群力蛊、溪流蛊等 109 个转数未核名）不收；年蛊按年份阶梯转数（凡级至九转万年蛊仅理论）不设单一 rank，未入库。

## 3. 已知蛊方、材料与约束事实

recipes 15 条：实配方 11 + 约束条目 4（约束以 `outputGu:null` 登记，约束本身即配方系统的合法性边界）。绝大多数原著配方未公开，成分 unknown 处一律留空不造。

| id | 输出 | 转数 | 输入 | 状态 | 关键事实 |
|---|---|---:|---|---|---|
| recipe-moon-glow | 月芒蛊 | 2 | 月光蛊×1＋小光蛊×2 | fact | 方源首败、小光蛊消亡、三天后再成；攻=月光三倍 |
| recipe-white-jade | 白玉蛊 | 2 | 白豕蛊×1＋玉皮蛊×1 | fact | 主防；元石只够一次之用的原著供应压力 |
| recipe-moon-ray | 月痕蛊 | 2 | 月光蛊×1＋痕石蛊×1 | fact | 秘方在案；范围×2、攻击力不变；与月芒同底二选一 |
| recipe-immortal-roam | 定仙游蛊 | 6 | 仙风蛊×1＋明星蛊×7＋辅料 | fact | 唯一已核的成方仙蛊秘方（原文 56826） |
| recipe-human-beast-burial | 人兽葬生蛊（页未建） | 3 | 人×1＋兽×1＋杂材近十种 | inference | 主料资质/处理约束已核；产物转数取资料整理 |
| recipe-four-wine | 四味酒虫（页未建） | 2 | 酒虫×2＋四酒 | inference | 配比笔记层级；逆炼回酒虫已核（REF-029） |
| recipe-inverse-white-jade | 白豕蛊（+玉皮蛊，双输出记 note） | 1 | 白玉蛊×1＋幡然蛊×1 | fact | 逆炼定义条：高转分解回低转（E:V1-018464） |
| recipe-blood-god-child | 血神子 | 6 | 血滴子×1 | inference | 晋升关系已核；秘方残篇（B 85476） |
| recipe-blood-moon | 血月蛊 | 3 | （未公开） | inference | 秘方存在已核、成分 unknown |
| recipe-five-aperture-fire-tower | 五窍火塔蛊（页未建） | 5 | 四阶前序产物逐级 | fact | 蛊方=工艺路线：逐级递进、可改良跳步（REF-018） |
| recipe-nine-eye-wine | 九眼酒虫（页未建） | 4 占位 | 七香酒虫×2 | inference | 三天合炼、耗近二十万元石（REF-023 已核） |
| recipe-constraint-secret-required | — | — | — | fact | 合炼须秘方；有些蛊不能合炼（E:V1-015724） |
| recipe-constraint-failure-economics | — | — | — | fact | 五转成功率不足千分之一；春秋蝉合炼<1%；呕心婴泣十连败（REF-013/010/016） |
| recipe-constraint-immortal-unique | — | — | — | fact | 仙蛊极限八转为主、九转极少（REF-020）；同种仙蛊同世唯一 |
| recipe-constraint-material-path | — | — | — | fact | 流派一致才可互替；仙蛊食材替代上限 40%（REF-019） |

材料侧已核实例：月光蛊日耗月兰花瓣四片、一块元石十片且只存五天；酒虫青竹酒一坛两块元石撑四天；二转普通蛊日耗一至两块元石；蛊师通常养四五头同阶蛊（[养炼用](../../../lore/wiki/world/gu-care-and-refinement.md)）。经济侧：舍利蛊一至五转体系、黄金/紫晶受管禁（[经济总表](../../../lore/wiki/world/economy-roster.md)）。

## 4. 三套构筑逐转说明

槽位数（L 均 ≤ C[r]，审计实测通过）：burst 3/3/4/3/3/3/5/5/5；balanced 3/3/4/4/4/5/5/5/6；sustain 3/3/4/4/4/5/5/5/6。凡人段（1–5 转）核心链路全部落在已核事实；仙蛊段（6–9 转）核心多为唯一仙蛊、Wiki 无玩家可得证据者标 assumption/inference 并以近阶兜底——这是三套构筑的共同取舍：**当阶仙蛊按「世界唯一、可能被 NPC 持有」登记，实际可用性交给供应层判定，引擎靠 fallback 降到近阶凡蛊/仙蛊**（实测 seed=20260927 时血神子、九转核心等多处已按预期回落）。

### 4.1 burst 爆发构筑（月道）

- 一至三转走已核月光系晋升链：月光蛊（strike）＋小光蛊协同（已核翻倍）＋酒虫回填 → 二转月芒蛊（三倍攻）→ 三转血月蛊（射程十米、血流不止、食血好养）＋黄金月/幻影月秘方位。
- 四转起当阶攻击蛊效果多未核（血颅/火龙/血手印凭名占位，assumption）；五转太光蛊「荣耀之光可组合成攻击杀招」为已核（但残蛊月催三次自毁）。
- 六转核心取血神子——全表唯一有完整原著获取链的六转攻击仙蛊（养五转血滴子＋残篇秘方晋升）；七转起当阶仙蛊唯一且多半 NPC 持有，九转核心（九转光蛊/九转火蛊）为传奇/野生个案，实际输出常由 fallback（八转慧剑蛊/雷电蛊）承担。
- 同动作双槽（七转起 strike/burst 各两槽）是「主攻＋同域备胎」：引擎取转数最高者、两只均计供养，登记为已知冗余。

### 4.2 balanced 均衡构筑（月道，混修防御/恢复）

- 方源二转路线的构筑化：月芒主攻＋白玉主防＋九叶生机草治疗（「攻守兼备」「治疗有九叶生机草」均为已核引文，moon-glow 页）。
- 三转加入冰肌蛊（防御卓绝、练成后无须真元支持）与木魅蛊（元气补给）；四转月影蛊（压制真元）按 strike 占位。
- 六转起与 burst 同口径：血神子（burst）＋海誓蛊/金甲蛊系（guard，assumption）＋我力蛊（strike，assumption）；七转坚持仙蛊入列取「逆反八转攻势」防御核语义（笔记层级）；八转悔蛊（镇压/匿迹）＋智障仙蛊（已核障碍场）。
- **登记一个模型分歧**：原著方源二转同期至少携带四蛊（月芒/白玉/酒虫/九叶），L(4)=6 已超模型 C(2)=5——构筑按游戏容量裁为 3 槽。这是模型容量参数与原著事实的显式剪刀差，调整 C 前先承认它。

### 4.3 sustain 续航构筑（气道，混修水/骨/月）

- guard＋drain 主轴：玉皮/石皮蛊护防、硬气蛊（气道防御短板弥补，已核）、酒虫真元精炼、九叶生机草治疗、血滴子食精血、木魅蛊元气补给；攻击位从简（月痕蛊范围型、血月蛊低养护型）。
- 六转防御核挽澜仙蛊（逆流护身印双核之一，笔记层级）、七转坚持仙蛊＋智障仙蛊（障碍场，已核）；八转悔蛊为已核防御语义。
- 九转无已核当阶防御仙蛊：九转继续由八转核心承担（g≤r 近阶口径），雷电蛊（burst）留作应急爆发。缺口见 §5。

poweredAction 映射（规范层）：attack→strike；大范围/重击个案（火龙、太光、血神子、龙息、雷电、九转火）→burst；护防/障碍/骨骼/镇压→guard；真元精炼/治疗/食精血/元气补给→drain。`drain`（回收攻击）是设计模板，原著只有能力方向许可，没有逐项动作授权——接入实装时逐条过 [模型](model.md) §4.2 预算审核。

## 5. 边界与未决清单

原著事实（fact 49 条 + 实配方 10 条）之外的登记：

1. **7–9 转核心缺口**：当阶有名有页的宿命蛊（天道不可自主催动）、智慧蛊（灵感/推算、耗寿，非战斗）、命运蛊（未炼成的计划实体）、至尊仙胎蛊（效果未核）均不可作战斗核；可考的九转战斗核只有九转光蛊/九转火蛊两条资料整理级记载，全部标 assumption/inference。九转槽位实际强度主要来自八转 fallback，这是如实登记的缺口，不为好看而虚标。
2. **转数双口径**：雷电蛊——roster-3/entities.json 取九转（E:V6-376300），roster 弧十三补录记八转、由「大自然炼蛊」推向九转；本表取八转保守口径并登记分叉。宿命蛊——九转传说口径与正文六转口径双登记（roster-3），本表取九转。全力以赴蛊——三转初得、后升炼，取四转中段。天机蛊——七转、后期升炼九转（J2b 436442），取七转。
3. **双实体疑**：「挽澜蛊」（roster-3 转数未核名单记五转）与「挽澜仙蛊」（万我骨架、逆流护身印核心，六转口径）是否同一蛊未核；「力气蛊」凡蛊/六转仙蛊并存的先例（roster-3）提示按两个实体处理。力量蛊游戏 rank1 为同名重用异常（L0 裁定待改名），本表 canon 九转传奇口径与之互斥。
4. **path 归档**：69 条中 48 条 path=unknown——原著流派总表不按蛊记归属。已标者仅四类：天道（宿命/天妒/天机）、人道（坚持/自己/至尊仙胎）、气道（硬气/三气）、智道（智障）；「月道」「木道」为归档标签（流派总表无月道；木行≠木道裁定），只用于分组与供应匹配，不宣称原著流派。供应层 [supply.json](supply.json) 的木道/气道样例生产通道因此只有少量命中，其余蛊走引擎默认渠道（全可得、价格倍率 1），已按引擎注释口径核实。
5. **不可入槽约束**：天道蛊虫不可自主催动（宿命/天妒，path-roster 402750–402764）→ 永不入玩家槽位，供应 availability 0/极低；石窍蛊（用一次即消失＋终生无望三转）作剧情道具登记；春秋蝉/智慧蛊/定仙游蛊为轮回、推演、机动线组件，不映射战斗动作。
6. **poweredAction 与真元经济**：burst 25 真元/3 仙元当量等消耗是 [参数表](parameters.json) 动作契约，非原著每蛊耗量；月光蛊「每记一成真元」是唯一已核单蛊耗量（E05），用于校准 strike 基准而非逐蛊赋值。
7. 供应层场景 `key_gu_missing` 名单（月光/小光/月芒/白玉）与三构筑的 1–2 转核心重合，已实测 fallback 链（月光→青藤、白玉→玉皮、九叶→酒虫）可用。

## 6. 新造 id 对照表（entities.json 无键者）

| id | 原著名 | 依据页 |
|---|---|---|
| wine-insect-gu | 酒虫 | [roster](../../../lore/wiki/gu/roster.md)、[月光蛊](../../../lore/wiki/gu/moonlight-gu.md) |
| vitality-grass-gu | 九叶生机草 | [月芒蛊](../../../lore/wiki/gu/moon-glow-gu.md)（id 对应 game/data 键 vitality_grass_gu，仅取 id 不取数值） |
| golden-moon-gu / frost-rain-moon-gu / phantom-moon-gu | 黄金月／霜霖月／幻影月 | [roster](../../../lore/wiki/gu/roster.md) |
| immortal-roam-gu | 定仙游蛊 | [roster](../../../lore/wiki/gu/roster.md) |
| wanlan-immortal-gu | 挽澜仙蛊 | [坚持仙蛊](../../../lore/wiki/gu/persistence-gu.md) |
| zhizhang-immortal-gu | 智障仙蛊 | [roster](../../../lore/wiki/gu/roster.md)（拼音） |
| three-qi-immortal-gu | 三气仙蛊（三只一组） | [roster](../../../lore/wiki/gu/roster.md) |
| supreme-immortal-fetus-gu | 至尊仙胎蛊 | [roster](../../../lore/wiki/gu/roster.md) |
| nine-turn-light-gu / nine-turn-fire-gu | 九转光蛊／九转火蛊 | [roster](../../../lore/wiki/gu/roster.md) |

关联页面：[README](README.md)、[事实表](evidence.md)、[完整模型](model.md)、[参数](parameters.json)、[供应层](supply.json)、[验证器](validate.mjs)、[复核与限制](review.md)。
