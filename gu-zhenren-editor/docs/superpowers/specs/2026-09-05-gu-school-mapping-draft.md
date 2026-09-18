# 214 蛊 → 道痕流派全量映射（C2 阶段一产出）

> 状态：**C2 产出 · 待门 U2 审订**。审订锁定前不落任何数据表（`gu.json`/`schools.json` v2 均未改动）。
> 工单：`docs/superpowers/plans/2026-09-05-architecture-refactor-master-plan.md` C2（存量 214 蛊流派映射）。
> 词汇表版本：U1 已认可清单 26 道痕 = `docs/superpowers/specs/2026-09-05-dao-mark-school-list-draft.md` §1；本文拟定 school id 全部落在该 26 集合内（程序校验通过），未发明清单外 id。
> 输入（全部只读）：`data/gu.json`（工作树当前版本，214 条，**现 `school` 字段 214 条齐备但系旧前缀生成器时代的批量占位/错位**）；`data/schools.json`（旧六校）；蛊名解析 `names.json → gu_names.json → display_text.gd`；语料定点核验 = `分支：六卷精编版/读书笔记` + `蛊真人-clean.txt`。
> 方法：蛊名语义/原著语料定位 > v1_effect/role/slot_role/tags > 现 school 归属；对约 80 个存疑蛊名做了语料定点检索（词条命中即引出处）。
> 禁改遵守：语料目录、`data/*`、代码均未触碰；本工单产出物仅此一个 markdown。

## 0. 头部统计

- **映射行数：214 / 214（全覆盖）**；其中『直接建议』134 条，『待 U2 复核』（依据列以 ☆ 标出）80 条。待复核中多数为**占位/残句名蛊维持原校**（规则性处置，风险低），真正需要 U2 强裁的 5 条见 §2.4 主冲突表。
- **拟定流派分布**：`blood` 血道 × 23；`qi` 气道 × 22；`force` 力道 × 51；`soul` 魂道 × 16；`refine` 炼道 × 27；`light` 光道 × 8；`change` 变化道 × 0；`wisdom` 智道 × 2；`star` 星道 × 0；`dream` 梦道 × 4；`zhou` 宙道 × 0；`luck` 运道 × 1；`sword` 剑道 × 2；`wood` 木道 × 5；`fire` 火道 × 3；`water` 水道 × 1；`thunder` 雷道 × 0；`ice` 冰道 × 0；`wind` 风道 × 6；`gold` 金道 × 13；`earth` 土道 × 10；`slave` 奴道 × 1；`formation` 阵道 × 0；`heaven` 天道 × 4；`human` 人道 × 6；`bone` 骨道 × 9。
- **零覆盖流派**：`change`/`star`/`zhou`/`thunder`/`ice`/`formation`（变化道、星道、宙道、雷道、冰道、阵道）。说明：214 蛊为既有游戏蛊库而非按 26 道痕配平；C1 清单中雷/冰/星/宙/变化/阵道代表蛊（雷电蛊/冰锥/星辉假眼/回溯蛊/变形仙蛊/阵心蛊等）均不在现库，需 D 阶段配方/策展扩充。
- **同名/疑似重复蛊**：`月芒蛊`（moon_glow_gu 与 moon_ray_gu）、`力量蛊`（force_gu 与 gen_qi_healing_054）见 §3.4；残句前缀同名族（但/不到/拿到/得到/撤销/几位/炼制…）见 §2.3 与 §3 R3。
- **旧 school 现状**（U2 审订时全量重写）：`qi`=46，`force`=44，`blood`=43，`soul`=40，`refine`=40，`moonlight`=1。旧 `moonlight` 学校仅 1 蛊（vitality_grass_gu），建议并入 `light`。
- **首发光道 4 初始蛊（S1）落地情况**：月光蛊 moonlight_gu、小光蛊 small_light_gu、生机草蛊 vitality_grass_gu 均拟 `light`；石皮蛊（现条目 gen_soul_attack_120_gu）为**三向错配**，主冲突 #1，见表内行与 §2.4。

## 1. 全量映射表（214 行）

> 约定：现 school = JSON 现字段；拟定 school = 本表建议（**加粗**）；依据列以 ☆ 开头为『待 U2 复核』。

| gu_id | 中文名 | 现 school | 拟定 school | 一句依据 |
|---|---|---|---|---|
| `bear_strength_gu` | 熊力蛊 | force | **force** | 熊力蛊：C1 force 例（熊家寨兽力），现 force 正确 |
| `blood_bat_gu` | 幽血蝙蝠蛊 | blood | **blood** | 幽血蝙蝠蛊=吸血蝠类，drain；blood 正确 |
| `blood_droplet_gu` | 血滴子蛊 | blood | **blood** | 血滴子蛊：C1 blood 例（需精血喂养）；现 blood 正确 |
| `blood_farewell_gu` | 爱别离蛊 | blood | **blood** | ☆待U2·爱别离蛊：王大杀妻夺心悲剧，血道语境流传；候选 human（情/心之名） |
| `blood_moss_gu` | 血苔蛊 | blood | **blood** | ☆待U2·血苔蛊：血苔林产物（血养苔藓，吸血植物），血道 heal；tags 含 wood |
| `blood_wing_gu` | 血翼蛊 | blood | **blood** | 血翼蛊=血道飞行（血翼魔教系），blood 正确 |
| `bone_knit_gu` | 续骨蛊 | blood | **bone** | 续骨蛊=接骨疗伤（heal vitality）；骨道 heal 语义，现 blood 旧映射 |
| `force_gu` | 力量蛊 | force | **force** | ☆待U2·力量蛊=力道本体；现 force 正确；与 gen_qi_healing_054(力量蛊) 同名冲突 |
| `heaven_dew_gu` | 天露蛊 | qi | **water** | ☆待U2·天露蛊=九天露水 heal，水道（露为水属）；现 qi 旧映射 |
| `jade_marrow_gu` | 玉髓蛊 | qi | **earth** | ☆待U2·玉髓蛊=玉石精髓 heal；玉系归土石，候选 gold，现 qi 旧映射 |
| `jade_skin_gu` | 玉皮蛊 | force | **earth** | ☆待U2·玉皮蛊：玉石皮甲（族长赠方正；月霓裳=月光蛊+玉皮蛊 配方伴侣）；玉系归土石，候选 gold |
| `life_root_gu` | 生根蛊 | qi | **wood** | 生根蛊=草木生根 heal（生命根系），木道；现 qi 旧映射 |
| `mending_grass_gu` | 回春草蛊 | qi | **wood** | 回春草蛊=草木治疗（vitality heal）；C1 medical 线索指治疗多由木草承担，现 qi 旧映射 |
| `mist_step_gu` | 雾步蛊 | force | **qi** | ☆待U2·雾步蛊=雾气位移，雾属气态无形；现 force 为旧 starter 池归属 |
| `moon_glow_gu` | 月芒蛊 | blood | **light** | ☆待U2·月芒蛊（语料合炼月芒蛊），C1 light 例；现 blood 系旧前缀错配；与 moon_ray_gu 同名冲突 |
| `moon_ray_gu` | 月芒蛊 | force | **light** | ☆待U2·月芒蛊（gu_names 命名）；与 moon_glow_gu 疑重复条目（同 r2 月华攻蛊，v1_effect 空），建议合并 |
| `moon_shadow_gu` | 月影蛊 | force | **light** | 月影蛊（语料四转月影蛊=月系），light tag+synergy light_combo；现 force 旧映射 |
| `moonlight_gu` | 月光蛊 | force | **light** | 月光蛊：C1 light 首例（镇族蛊/月华），现 force 系旧映射中间态，须改 light |
| `phantom_moon_gu` | 幻月蛊 | qi | **light** | 幻月蛊=月华幻影（light tag）；现 qi 旧映射；候选 change |
| `phoenix_drop_gu` | 凤髓滴蛊 | blood | **fire** | ☆待U2·凤髓滴蛊=凤髓精华 heal；凤凰=火/涅槃系（低置信），候选原 blood |
| `pulse_drum_gu` | 脉冲鼓蛊 | qi | **qi** | ☆待U2·脉冲鼓蛊=音波震慑（sound/bound），无道痕语义锚点，维持现 qi |
| `qi_wall_gu` | 气墙蛊 | qi | **qi** | 气墙蛊=气之壁障，气道本体；现 qi 正确 |
| `shadow_veil_gu` | 影幕蛊 | qi | **qi** | ☆待U2·影幕蛊=影幕伪装；影道未入正表、魂道偏诡，维持现 qi |
| `small_light_gu` | 小光蛊 | qi | **light** | C1 修正项/工单背景：小光蛊为光道辅助蛊（S1 光道初始），现 qi 系旧映射中间态 |
| `spring_heart_gu` | 春心蛊 | qi | **human** | ☆待U2·春心蛊=萌动之心 heal（心/情之名近人道情感），候选 qi/wood |
| `stone_shell_gu` | 石甲蛊 | force | **earth** | 石甲蛊=石质皮甲防御（tags 已含 earth）；现 force 为旧 starter 池归属 |
| `test_slay_gu` | 十转杀蛊 | qi | **qi** | ☆待U2·十转杀蛊=S2 开局 Buff 机制蛊（群体 999），非流派实体；维持现 qi，随 Buff 定义单独对待 |
| `thorn_whip_gu` | 棘鞭蛊 | force | **wood** | ☆待U2·棘鞭蛊=藤木荆棘鞭，bound 束缚=木道缠绕语义；现 force 为旧 starter 池归属 |
| `trail_eye_gu` | 寻迹眼蛊 | qi | **qi** | ☆待U2·寻迹眼蛊=自制侦察蛊，无道痕语义锚点，维持现 qi |
| `undying_vine_gu` | 不死藤蛊 | blood | **wood** | 不死藤蛊=不灭藤蔓 heal，木道；现 blood 旧映射 |
| `venom_thread_gu` | 毒丝蛊 | qi | **qi** | ☆待U2·毒丝蛊=毒线控场，毒系无正表流派，维持现 qi（耗材制敌接近气道工具化） |
| `vitality_grass_gu` | 生机草蛊 | moonlight | **light** | ☆待U2·生机草蛊=S1 光道初始 4 蛊之一（工单背景：须 light）；现 moonlight 学校并入 light；候选 wood（九叶生机草=木道 C1） |
| `white_boar_strength_gu` | 白猪力蛊 | force | **force** | 白猪力蛊=白猪兽力（temporary power），force 正确 |
| `white_jade_gu` | 白玉蛊 | force | **earth** | ☆待U2·白玉蛊：玉质防御（石林猎杀玉眼石猴验防）；玉系归土石，候选 gold |
| `gen_blood_attack_001_gu` | 血颅蛊 | blood | **blood** | 血颅蛊=血海九道真传之一（血颅/血手印/血气/血汗/经血/血影/血战/血神子） |
| `gen_blood_attack_002_gu` | 血月蛊 | blood | **blood** | ☆待U2·血月蛊=血+光跨界成品（C1 blood 例；Master 配方 3 转血月蛊=2血+2光）；月字含光道成分，主血 |
| `gen_blood_attack_008_gu` | 血手印蛊 | blood | **blood** | 血手印蛊=血海九真传（商燕飞五转） |
| `gen_blood_attack_009_gu` | 血气蛊 | blood | **blood** | 血气蛊=血海九真传 |
| `gen_blood_attack_015_gu` | 血绳蛊 | blood | **blood** | 血绳蛊=宗祠血绳（牵扯血道） |
| `gen_blood_attack_016_gu` | 血道侦察蛊 | blood | **blood** | 名称『血道侦察蛊』直陈血道；blood |
| `gen_blood_attack_022_gu` | 勇气蛊 | blood | **human** | 勇气蛊=C1 human 例（人祖传勇气蛊/冰魄借勇）；现 blood 错位 |
| `gen_blood_attack_023_gu` | 气囊蛊 | blood | **qi** | 气囊蛊=C1 qi 例（三转存储蛊，献气囊蛊之法） |
| `gen_blood_attack_029_gu` | 追风蛊 | blood | **wind** | 追风蛊=追风速度（四转移动蛊），风道；现 blood 错位 |
| `gen_blood_attack_030_gu` | 金风送爽蛊 | blood | **gold** | ☆待U2·金风送爽蛊=铁慕白金道蛊组（金龙/金缕衣/金霞并列），金道治疗；候选 wind |
| `gen_blood_defense_003_gu` | 血幕天华蛊 | blood | **blood** | 血幕天华=血道防御（章名/杀招级） |
| `gen_blood_defense_010_gu` | 血狂蛊 | blood | **blood** | 血狂蛊=一团血气四转（血滴子合炼秘方组） |
| `gen_blood_defense_017_gu` | 血道凡蛊 | blood | **blood** | 名称『血道凡蛊』直陈血道；blood |
| `gen_blood_defense_024_gu` | 风气蛊 | blood | **qi** | ☆待U2·风气蛊=C1 qi 代表例（上古气道一系，五十万拍卖）；候选 wind |
| `gen_blood_defense_031_gu` | 风力蛊 | blood | **force** | ☆待U2·风力蛊=『X力蛊』借自然之力体系（地火水风天力并列），力道；候选 wind |
| `gen_blood_healing_005_gu` | 血汗蛊 | blood | **blood** | 血汗蛊=血海九真传 |
| `gen_blood_healing_012_gu` | 但血颅蛊 | blood | **blood** | 但血颅蛊=『但』残句前缀+血颅蛊（血海九真传） |
| `gen_blood_healing_019_gu` | 力气蛊 | blood | **force** | 力气蛊=力道四件套之一（全力以赴+苦力+自力更生+力气；C1 force 例）；现 blood 系前缀错位 |
| `gen_blood_healing_026_gu` | 火焰披风蛊 | blood | **fire** | 火焰披风蛊=火焰护体，火道；现 blood 错位 |
| `gen_blood_healing_033_gu` | 风虎云龙蛊 | blood | **wind** | 风虎云龙蛊=风系大蛊（飞熊身上，与星河蛊并列），风道；现 blood 错位 |
| `gen_blood_logistics_007_gu` | 血战蛊 | blood | **blood** | 血战蛊=血海九真传 |
| `gen_blood_logistics_014_gu` | 血神子蛊 | blood | **blood** | 血神子蛊=血海九真传（六转仙蛊；C1 blood 例） |
| `gen_blood_logistics_021_gu` | 炼制气囊蛊 | blood | **qi** | 炼制气囊蛊=『炼制』残句+气囊蛊（C1 qi 例：三转存储蛊） |
| `gen_blood_logistics_028_gu` | 硬气蛊 | blood | **force** | ☆待U2·硬气蛊=巨开碑（力道流）硬气防御，力道系（候选 qi）；现 blood 错位 |
| `gen_blood_movement_004_gu` | 败血妖花蛊 | blood | **blood** | ☆待U2·败血妖花蛊=败血妖花（鹤风扬线失控害方正），血道妖花；候选 wood |
| `gen_blood_movement_011_gu` | 血鬼尸蛊 | blood | **blood** | 血鬼尸蛊=血道飞僵（古月一代成飞僵） |
| `gen_blood_movement_018_gu` | 血道炼蛊 | blood | **blood** | 名称『血道炼蛊』直陈血道（血道之炼法，非炼道）；blood |
| `gen_blood_movement_025_gu` | 扬眉吐气蛊 | blood | **qi** | 扬眉吐气蛊=吐气/真元对耗，气道；现 blood 错位 |
| `gen_blood_movement_032_gu` | 风花蛊 | blood | **wind** | 风花蛊=风系移蛊（与烁蝺/鹰扬同用），风道；现 blood 错位 |
| `gen_blood_recon_006_gu` | 经血蛊 | blood | **blood** | 经血蛊=血海九真传（能让人放血） |
| `gen_blood_recon_013_gu` | 血影蛊 | blood | **blood** | 血影蛊=血海九真传 |
| `gen_blood_recon_020_gu` | 小家子气蛊 | blood | **wisdom** | 小家子气蛊=推算算计（C1 wisdom 例；毛民拆古蛊方练习）；现 blood 错位 |
| `gen_blood_recon_027_gu` | 八面威风蛊 | blood | **qi** | ☆待U2·八面威风蛊=威风/乾清一气关联，气道名（候选 wind）；现 blood 错位 |
| `gen_blood_recon_034_gu` | 人气蛊 | blood | **qi** | 人气蛊=C1 qi 代表例（人气仙蛊@C/I2b）；现 blood 错位 |
| `gen_force_attack_071_gu` | 骨枪蛊 | force | **bone** | 骨枪蛊=C1 bone 例（白骨传承一转骨枪，饿死大半） |
| `gen_force_attack_072_gu` | 人力胜天蛊 | force | **force** | 人力胜天蛊=人力开窍（商燕飞换购），力道 |
| `gen_force_attack_078_gu` | 费力蛊 | force | **force** | 费力蛊=力之名，力道 |
| `gen_force_attack_079_gu` | 铁柜蛊 | force | **gold** | 铁柜蛊=铁质柜形防御/保命（铁若男被铁柜蛊保命），金道 |
| `gen_force_attack_085_gu` | 十斤之力蛊 | force | **force** | 十斤之力蛊=增长十斤力气（人力钧力流），力道 |
| `gen_force_attack_086_gu` | 水力蛊 | force | **force** | ☆待U2·水力蛊=借水流之力（力蛊清单），力道（候选 water） |
| `gen_force_attack_092_gu` | 铁甲大蛊 | force | **gold** | 铁甲大蛊=人祖传铁甲大（拦人祖），铁甲=金道 |
| `gen_force_attack_093_gu` | 隐石蛊 | force | **earth** | 隐石蛊=石系隐匿（袭杀猴王后得），土道 |
| `gen_force_attack_099_gu` | 炼制奋力蛊 | force | **force** | 炼制奋力蛊=『炼制』残句+奋力蛊（琅琊交易/上古力），力道 |
| `gen_force_attack_100_gu` | 炼制群力蛊 | force | **force** | 炼制群力蛊=『炼制』残句+群力蛊（黑楼兰渡劫备战），力道 |
| `gen_force_defense_073_gu` | 借力蛊 | force | **force** | 借力蛊=借力（力蛊清单），力道 |
| `gen_force_defense_080_gu` | 火力蛊 | force | **force** | ☆待U2·火力蛊=借火焰之力（力蛊清单），力道（候选 fire） |
| `gen_force_defense_087_gu` | 熊家蛊 | force | **force** | ☆待U2·熊家蛊=『熊家』家族名+蛊 残片，无锚点，维持现 force |
| `gen_force_defense_094_gu` | 青牛劳力蛊 | force | **force** | 青牛劳力蛊=牛类兽力（合炼损失组），力道 |
| `gen_force_healing_068_gu` | 石窍蛊 | force | **earth** | 石窍蛊=C1 earth 例（强取石窍蛊）；现 force 错位 |
| `gen_force_healing_075_gu` | 惯力蛊 | force | **force** | 惯力蛊=C1 force 例（力道流巅峰战 vs 全力以赴蛊） |
| `gen_force_healing_082_gu` | 石龟负力蛊 | force | **force** | 石龟负力蛊=龟类兽力（合炼损失组），力道 |
| `gen_force_healing_089_gu` | 生铁蛊 | force | **gold** | 生铁蛊=修复锯齿金蜈的铁材（金属），金道 |
| `gen_force_healing_096_gu` | 五转群力蛊 | force | **force** | 五转群力蛊=群力五转，力道 |
| `gen_force_logistics_070_gu` | 飞熊之力蛊 | force | **force** | 飞熊之力蛊=飞熊兽力，力道 |
| `gen_force_logistics_077_gu` | 群力蛊 | force | **force** | 群力蛊=合力（古代蛊方），力道 |
| `gen_force_logistics_084_gu` | 骨翼蛊 | force | **bone** | 骨翼蛊=骨翼飞行（臂骨翼/肋骨盾/飞骨盾骨系），骨道 |
| `gen_force_logistics_091_gu` | 铁壁蛊 | force | **gold** | 铁壁蛊=铁壁防御，金道 |
| `gen_force_logistics_098_gu` | 努力蛊 | force | **force** | 努力蛊=力之名（残句倾向），力道 |
| `gen_force_movement_074_gu` | 地力蛊 | force | **force** | 地力蛊=借大地之力（力蛊清单），力道 |
| `gen_force_movement_081_gu` | 玉骨蛊 | force | **bone** | 玉骨蛊=C1 bone 例（强骨，配冰肌成冰肌玉骨） |
| `gen_force_movement_088_gu` | 熔岩炸裂蛊 | force | **fire** | ☆待U2·熔岩炸裂蛊=熔岩爆炸（熔岩鳄王三蛊：炸裂/炎胄/积灰），火道（候选 earth） |
| `gen_force_movement_095_gu` | 五行熊皮蛊 | force | **force** | 五行熊皮蛊=五转熊类兽力皮甲（飞熊身上），力道 |
| `gen_force_recon_069_gu` | 钧力蛊 | force | **force** | 钧力蛊=人力钧力流，力道 |
| `gen_force_recon_076_gu` | 战骨车轮蛊 | force | **bone** | 战骨车轮蛊=C1 bone 例（白骨战车部件） |
| `gen_force_recon_083_gu` | 铁手擒拿蛊 | force | **gold** | 铁手擒拿蛊=五转铁质擒拿，金道 |
| `gen_force_recon_090_gu` | 钢筋蛊 | force | **gold** | 钢筋蛊=铁骨钢筋铜皮三防（速成修行），金道 |
| `gen_force_recon_097_gu` | 几位石人蛊 | force | **earth** | 几位石人蛊=『几位』残句+石人蛊，土道 |
| `gen_qi_attack_036_gu` | 七面威风蛊 | qi | **qi** | ☆待U2·七面威风蛊=威风系气道（可升八面威风蛊）；候选 wind |
| `gen_qi_attack_037_gu` | 六转力气蛊 | qi | **force** | 六转力气蛊=『六转』残句+力气蛊（力道四件套） |
| `gen_qi_attack_043_gu` | 水风电力蛊 | qi | **qi** | ☆待U2·水风电力蛊=元素复合命名蛊，无明确锚点，维持现 qi；候选 force(X力蛊)/thunder |
| `gen_qi_attack_044_gu` | 狂风蛊 | qi | **wind** | 狂风蛊=风攻（+旋踵蛊+冰刃蛊攻防一体），风道；现 qi 前缀 |
| `gen_qi_attack_050_gu` | 赤铁舍利蛊 | qi | **gold** | 赤铁舍利蛊=赤铁矿物舍利（与金罡蛊/白银舍利蛊同期拍卖），金道 |
| `gen_qi_attack_051_gu` | 飞熊虚像蛊 | qi | **force** | 飞熊虚像蛊=兽力虚影（飞熊虚像），力道 |
| `gen_qi_attack_057_gu` | 螺旋骨枪蛊 | qi | **bone** | 螺旋骨枪蛊=骨枪二转（白骨传承），骨道 |
| `gen_qi_attack_058_gu` | 铁冠鹰力蛊 | qi | **force** | 铁冠鹰力蛊=铁冠鹰之兽力（+三百斤太泽土售卖），力道 |
| `gen_qi_attack_064_gu` | 定力蛊 | qi | **force** | ☆待U2·定力蛊=力之名，力道（候选 qi/refine 心定之力） |
| `gen_qi_attack_065_gu` | 解石蛊 | qi | **qi** | ☆待U2·解石蛊=『解石蛊师』职业名抽取残片，无语义锚点，维持现 qi |
| `gen_qi_defense_038_gu` | 刀气蛊 | qi | **gold** | ☆待U2·刀气蛊=刀兵锋锐之气，金道（候选 sword）；现 qi 前缀 |
| `gen_qi_defense_045_gu` | 量春风蛊 | qi | **wind** | ☆待U2·量春风蛊=『少量春风蛊』抽取残名（真身春风蛊），春风属风道；候选 qi |
| `gen_qi_defense_052_gu` | 兽力胎盘蛊 | qi | **force** | 兽力胎盘蛊=兽力集人窍，力道 |
| `gen_qi_defense_059_gu` | 蛮力天牛蛊 | qi | **force** | 蛮力天牛蛊=暴涨一牛之力，力道 |
| `gen_qi_defense_066_gu` | 铁家蛊 | qi | **qi** | ☆待U2·铁家蛊=『铁家』家族名+蛊 残片，无语义锚点，维持现 qi |
| `gen_qi_healing_040_gu` | 化气蛊 | qi | **qi** | 化气蛊=C1 qi 例（气道代表蛊） |
| `gen_qi_healing_047_gu` | 全力以赴蛊 | qi | **force** | 全力以赴蛊=C1 force 例（上古力道绝迹蛊，四件套核心） |
| `gen_qi_healing_054_gu` | 力量蛊 | qi | **force** | ☆待U2·力量蛊=力道本体（与 force_gu 同名冲突）；现 qi 错位 |
| `gen_qi_healing_061_gu` | 棕熊本力蛊 | qi | **force** | 棕熊本力蛊=熊类兽力（四次合炼失败的兽力蛊组），力道 |
| `gen_qi_logistics_035_gu` | 四转风气蛊 | qi | **qi** | 四转风气蛊=『四转』残句+风气蛊（气道） |
| `gen_qi_logistics_042_gu` | 朝气蛊 | qi | **qi** | 朝气蛊=气之名（朝气），气道；现 qi 一致 |
| `gen_qi_logistics_049_gu` | 自力更生蛊 | qi | **force** | 自力更生蛊=C1 force 例（力道四件套支点） |
| `gen_qi_logistics_056_gu` | 石人蛊 | qi | **earth** | 石人蛊=石傀儡/石系造物（clean 石人蛊仙），土道 |
| `gen_qi_logistics_063_gu` | 鳄力蛊 | qi | **force** | 鳄力蛊=C1 force 例（鳄力兽力入体，须玉骨蛊强骨） |
| `gen_qi_movement_039_gu` | 剑气蛊 | qi | **sword** | 剑气蛊=剑气纵横，剑道；现 qi 前缀 |
| `gen_qi_movement_046_gu` | 餐风蛊 | qi | **wind** | ☆待U2·餐风蛊=风蛊套组拍卖（风气蛊之后即餐风蛊），风道；现 qi 前缀 |
| `gen_qi_movement_053_gu` | 苦力蛊 | qi | **force** | 苦力蛊=C1 force 例（力道四件套） |
| `gen_qi_movement_060_gu` | 镇魔铁索蛊 | qi | **gold** | ☆待U2·镇魔铁索蛊=铁索镇压之器，金道（候选 force） |
| `gen_qi_movement_067_gu` | 能力蛊 | qi | **qi** | ☆待U2·能力蛊=无锚点命名，维持现 qi；候选 force/human |
| `gen_qi_recon_041_gu` | 四转剑气蛊 | qi | **sword** | 四转剑气蛊=剑气系，剑道；现 qi 前缀 |
| `gen_qi_recon_048_gu` | 骨肉团圆蛊 | qi | **bone** | 骨肉团圆蛊=灰骨才子骨道传承蛊（血亲合炼转化真元），骨道 |
| `gen_qi_recon_055_gu` | 十钧之力蛊 | qi | **force** | 十钧之力蛊=人力钧力流（斤/十斤/一钧/十钧/百钧），力道 |
| `gen_qi_recon_062_gu` | 大力屙屎蛊 | qi | **force** | ☆待U2·大力屙屎蛊=大力蛊+屙屎蛊合炼（力量语义），力道（低置信） |
| `gen_refine_attack_141_gu` | 炼蛊 | refine | **refine** | 『炼蛊』=炼蛊行为词作名，炼道占位（C1 注凡蛊代表暂缺、gen_refine 待校验），维持 refine |
| `gen_refine_attack_142_gu` | 此蛊 | refine | **refine** | ☆待U2·『此蛊』=指示代词占位名，维持 refine |
| `gen_refine_attack_148_gu` | 八转蛊 | refine | **refine** | ☆待U2·『八转蛊』=品阶词占位名，维持 refine |
| `gen_refine_attack_149_gu` | 宿命蛊 | refine | **heaven** | 宿命蛊=C1 heaven 例（宿命仙蛊=天道碎片） |
| `gen_refine_attack_155_gu` | 毛民蛊 | refine | **refine** | ☆待U2·『毛民蛊』=毛民（炼道主族/长毛老祖等三老）族名作蛊名，炼道关联，维持 refine |
| `gen_refine_attack_156_gu` | 推杯换盏蛊 | refine | **qi** | ☆待U2·推杯换盏蛊=空穴传输/挪移蛊（运蛊、北原版）；语义属宇道(space 未入 U1 清单)，暂拟 qi，建议 U2 扩清后改归 space |
| `gen_refine_attack_162_gu` | 青年蛊 | refine | **refine** | ☆待U2·『青年蛊』=占位名（人祖传『青年』语境非蛊），维持 refine |
| `gen_refine_attack_163_gu` | 东海蛊 | refine | **refine** | ☆待U2·『东海蛊』=地域词占位名，维持 refine |
| `gen_refine_attack_169_gu` | 异人蛊 | refine | **refine** | ☆待U2·『异人蛊』=族名占位名，维持 refine |
| `gen_refine_attack_170_gu` | 五转蛊 | refine | **refine** | ☆待U2·『五转蛊』=品阶词占位名，维持 refine |
| `gen_refine_attack_176_gu` | 黑家蛊 | refine | **refine** | ☆待U2·『黑家蛊』=家族名占位残片，维持 refine |
| `gen_refine_attack_177_gu` | 寿蛊 | refine | **heaven** | 寿蛊=C1 heaven 例（寿元即天道道痕；八十年寿蛊） |
| `gen_refine_defense_143_gu` | 天庭蛊 | refine | **refine** | ☆待U2·『天庭蛊』=势力词占位名（天庭非道痕），维持 refine |
| `gen_refine_defense_150_gu` | 南疆蛊 | refine | **refine** | ☆待U2·『南疆蛊』=地域词占位名，维持 refine |
| `gen_refine_defense_157_gu` | 胆识蛊 | refine | **soul** | 胆识蛊=C1 soul 例（荡魂山壮魂/胆识蛊） |
| `gen_refine_defense_164_gu` | 修复宿命蛊 | refine | **heaven** | 修复宿命蛊=宿命系（修复宿命蛊），天道 |
| `gen_refine_defense_171_gu` | 思想蛊 | refine | **human** | ☆待U2·思想蛊=人祖传思想蛊（指点创新；思想的自由），人道（候选 wisdom） |
| `gen_refine_defense_178_gu` | 戚家蛊 | refine | **refine** | ☆待U2·『戚家蛊』=家族名占位残片，维持 refine |
| `gen_refine_healing_145_gu` | 至尊仙胎蛊 | refine | **human** | 至尊仙胎蛊=C1 human 例（道痕不互斥之九转根基） |
| `gen_refine_healing_152_gu` | 北原蛊 | refine | **refine** | ☆待U2·『北原蛊』=地域词占位名，维持 refine |
| `gen_refine_healing_159_gu` | 七转蛊 | refine | **refine** | ☆待U2·『七转蛊』=品阶词占位名，维持 refine |
| `gen_refine_healing_166_gu` | 但蛊 | refine | **refine** | ☆待U2·『但蛊』=残句占位名，维持 refine |
| `gen_refine_healing_173_gu` | 摧毁宿命蛊 | refine | **heaven** | 摧毁宿命蛊=宿命系，天道 |
| `gen_refine_healing_180_gu` | 对于蛊 | refine | **refine** | ☆待U2·『对于蛊』=介词占位名，维持 refine |
| `gen_refine_logistics_147_gu` | 洲蛊 | refine | **refine** | ☆待U2·『洲蛊』=占位名，维持 refine |
| `gen_refine_logistics_154_gu` | 凡蛊 | refine | **refine** | ☆待U2·『凡蛊』=泛称占位名，维持 refine |
| `gen_refine_logistics_161_gu` | 鸿运齐天蛊 | refine | **luck** | 鸿运齐天蛊=C1 luck 例（鸿运齐天仙蛊/巨阳仙尊） |
| `gen_refine_logistics_168_gu` | 自己蛊 | refine | **human** | ☆待U2·自己蛊=人祖传自己蛊（自己蛊咬力量蛊；C1 H1 人祖传诸蛊皆人道），人道 |
| `gen_refine_logistics_175_gu` | 其他蛊 | refine | **refine** | ☆待U2·『其他蛊』=占位名，维持 refine |
| `gen_refine_movement_144_gu` | 第二空窍蛊 | refine | **refine** | ☆待U2·第二空窍蛊=第二空窍（额外窍穴）改造蛊，炼道关联（候选 space/qi） |
| `gen_refine_movement_151_gu` | 女蛊 | refine | **refine** | ☆待U2·『女蛊』=占位名，维持 refine |
| `gen_refine_movement_158_gu` | 许多蛊 | refine | **refine** | ☆待U2·『许多蛊』=量词占位名，维持 refine |
| `gen_refine_movement_165_gu` | 其余蛊 | refine | **refine** | ☆待U2·『其余蛊』=占位名，维持 refine |
| `gen_refine_movement_172_gu` | 白莲巨蚕蛊 | refine | **soul** | ☆待U2·白莲巨蚕蛊=幽魂魔尊所创（净魂仙蛊以白莲巨蚕血肉豢养），魂道；候选 refine |
| `gen_refine_movement_179_gu` | 房家蛊 | refine | **refine** | ☆待U2·『房家蛊』=家族名占位残片，维持 refine |
| `gen_refine_recon_146_gu` | 智慧蛊 | refine | **wisdom** | 智慧蛊=C1 wisdom 首例（九转概念仙蛊） |
| `gen_refine_recon_153_gu` | 很多蛊 | refine | **refine** | ☆待U2·『很多蛊』=量词占位名，维持 refine |
| `gen_refine_recon_160_gu` | 强蛊 | refine | **refine** | ☆待U2·『强蛊』=占位名，维持 refine |
| `gen_refine_recon_167_gu` | 六转蛊 | refine | **refine** | ☆待U2·『六转蛊』=品阶词占位名，维持 refine |
| `gen_refine_recon_174_gu` | 态度蛊 | refine | **human** | ☆待U2·态度蛊=人祖传态度蛊（态度是心的面具）；C1 refine 行曾引 F2b『琅琊炼道仙蛊』为证——语义为人道寓言蛊，拟 human 候选 refine，需 U2 裁 |
| `gen_soul_attack_106_gu` | 幽影随行蛊 | soul | **soul** | ☆待U2·幽影随行蛊=潜行追踪蛊（王大），幽影系魂域，soul（候选 shadow/qi） |
| `gen_soul_attack_107_gu` | 魂山胆识蛊 | soul | **soul** | 魂山胆识蛊=『魂山』+胆识蛊（荡魂山壮魂），魂道 |
| `gen_soul_attack_113_gu` | 月魂蛊 | soul | **soul** | 月魂蛊=魂道蛊原列（凝练魂魄用，非光道！多义词），魂道 |
| `gen_soul_attack_114_gu` | 梦魂蛊 | soul | **soul** | 梦魂蛊=魂道蛊原列（虽带梦字，仍属凝魂蛊），魂道 |
| `gen_soul_attack_120_gu` | 石皮蛊 | soul | **light** | ☆待U2·石皮蛊名占位蛊=S1 首发光道 4 初始蛊之『石皮蛊』（工单背景：须 light）；U1 附录语料指皮甲系疑土石(earth)——三向错配待 U2 同步定校（改派此 id 或新建 stone_skin_gu） |
| `gen_soul_attack_121_gu` | 臂骨翼蛊 | soul | **bone** | 臂骨翼蛊=骨系蛊选（肋骨盾/飞骨盾/臂骨翼），骨道 |
| `gen_soul_attack_127_gu` | 龙象巨力蛊 | soul | **force** | 龙象巨力蛊=四转兽力（龙象），力道 |
| `gen_soul_attack_128_gu` | 不到苦力蛊 | soul | **force** | 不到苦力蛊=『不到』残句+苦力蛊（力道四件套） |
| `gen_soul_attack_134_gu` | 战力媲美蛊 | soul | **soul** | ☆待U2·战力媲美蛊=『战力媲美XX蛊』描述句残片，无锚点，维持现 soul |
| `gen_soul_attack_135_gu` | 拳石蛊 | soul | **earth** | 拳石蛊=凝石成拳（与风刃/水龙/金锥并列），土道 |
| `gen_soul_defense_101_gu` | 魂灯蛊 | soul | **soul** | 魂灯蛊=魂灯（武庸魂灯灭/命牌碎），魂道 |
| `gen_soul_defense_108_gu` | 五转狼魂蛊 | soul | **soul** | 五转狼魂蛊=狼魂五转，魂道 |
| `gen_soul_defense_115_gu` | 炼梦道凡蛊 | soul | **dream** | 炼梦道凡蛊=梦道凡蛊系（『炼』残句前缀），梦道 |
| `gen_soul_defense_122_gu` | 铁刺荆棘蛊 | soul | **wood** | ☆待U2·铁刺荆棘蛊=荆棘衣衫攻防一体（白凝冰本命），木道藤棘；候选 force/gold |
| `gen_soul_defense_129_gu` | 但钧力蛊 | soul | **force** | 但钧力蛊=『但』残句+钧力蛊（人力钧力流） |
| `gen_soul_defense_136_gu` | 拿到苦力蛊 | soul | **force** | 拿到苦力蛊=『拿到』残句+苦力蛊，力道 |
| `gen_soul_healing_103_gu` | 潜魂兽衣蛊 | soul | **soul** | 潜魂兽衣蛊=魂衣蛊方（魂道），soul |
| `gen_soul_healing_110_gu` | 四转狼魂蛊 | soul | **soul** | 四转狼魂蛊=狼魂四转，魂道 |
| `gen_soul_healing_117_gu` | 龙魂蛊 | soul | **soul** | 龙魂蛊=魂道蛊原列（龙魂），魂道 |
| `gen_soul_healing_124_gu` | 铁骨蛊 | soul | **gold** | 铁骨蛊=锻骨炼铁（铁骨+钢筋+铜皮三防），金道 |
| `gen_soul_healing_131_gu` | 全力操纵蛊 | soul | **force** | ☆待U2·全力操纵蛊=全力（力之语义）操纵，力道（低置信） |
| `gen_soul_healing_138_gu` | 斤力蛊 | soul | **force** | 斤力蛊=人力钧力流（斤力），力道 |
| `gen_soul_logistics_105_gu` | 梦道凡蛊 | soul | **dream** | 梦道凡蛊=梦道凡蛊（解梦杀招耗材，方源炼制），梦道 |
| `gen_soul_logistics_112_gu` | 怨魂蛊 | soul | **soul** | 怨魂蛊=魂道蛊原列，魂道 |
| `gen_soul_logistics_119_gu` | 电力蛊 | soul | **force** | ☆待U2·电力蛊=『X力蛊』借电之力（力蛊清单：借力/地水风电力蛊并列），力道（候选 thunder） |
| `gen_soul_logistics_126_gu` | 驭熊蛊 | soul | **slave** | 驭熊蛊=驭熊兽役（方源敲走熊骄嫚驭熊蛊），奴道 |
| `gen_soul_logistics_133_gu` | 情同骨肉蛊 | soul | **bone** | 情同骨肉蛊=骨肉团圆蛊五品质之一（血亲合炼），骨道 |
| `gen_soul_logistics_140_gu` | 暴力蛊 | soul | **force** | 暴力蛊=身躯膨胀力量暴涨（暴力蛊），力道 |
| `gen_soul_movement_102_gu` | 制梦道凡蛊 | soul | **dream** | 制梦道凡蛊=梦道凡蛊系（『制』残句前缀），梦道 |
| `gen_soul_movement_109_gu` | 多梦道凡蛊 | soul | **dream** | 多梦道凡蛊=梦道凡蛊系（『多』残句前缀），梦道 |
| `gen_soul_movement_116_gu` | 诗魂蛊 | soul | **soul** | 诗魂蛊=魂道蛊原列，魂道 |
| `gen_soul_movement_123_gu` | 铁皮蛊 | soul | **earth** | ☆待U2·铁皮蛊=青茅山皮甲系凡蛊（石皮/铜皮/铁皮同族，C1 附录疑土石），土道（候选 gold） |
| `gen_soul_movement_130_gu` | 入力胜夭蛊 | soul | **force** | 入力胜夭蛊=『人力胜天』错字版，力道 |
| `gen_soul_movement_137_gu` | 撤销铁柜蛊 | soul | **gold** | 撤销铁柜蛊=『撤销』残句+铁柜蛊，金道 |
| `gen_soul_recon_104_gu` | 狼魂蛊 | soul | **soul** | 狼魂蛊=兽魂（三转狼魂蛊，方源购八只），魂道 |
| `gen_soul_recon_111_gu` | 冰魂蛊 | soul | **soul** | 冰魂蛊=魂道蛊原列（clean 凝魂蛊单：龙魂/冰魂/梦魂/月魂…），魂道 |
| `gen_soul_recon_118_gu` | 熊豪蛊 | soul | **force** | 熊豪蛊=三熊之力兽力（汤雄战），力道 |
| `gen_soul_recon_125_gu` | 霸力蛊 | soul | **force** | 霸力蛊=四转上古力道（铁霸修霸王之力），力道 |
| `gen_soul_recon_132_gu` | 得到铁骨蛊 | soul | **gold** | 得到铁骨蛊=『得到』残句+铁骨蛊（三防），金道 |
| `gen_soul_recon_139_gu` | 昆仑牛力蛊 | soul | **force** | 昆仑牛力蛊=牛类兽力（昆仑牛），力道 |

## 2. 修正与冲突清单

### 2.1 C1 已知修正项承接（已在本表落实）

1. **小光蛊 → light**：`small_light_gu` 现 qi → 拟 light（C1 修正项 + S1 光道初始）。
2. **`moonlight` 学校并入 light**：现 moonlight 学校仅 `vitality_grass_gu`（生机草蛊），拟 light；`moonlight_gu`（月光蛊）现错挂 force，同拟 light。旧 `schools.json` 的 `moonlight` 条目建议作为 `light` 历史别名处置，不再保留独立学校 id。
3. **现月光系旧映射中间态清理**：moon_glow_gu(blood)、moon_ray_gu(force)、moon_shadow_gu(force)、phantom_moon_gu(qi)、vitality_grass_gu(moonlight) 均拟 light；`gen_soul_attack_120_gu`（石皮蛊名）见主冲突 #1。

### 2.2 C1 附录存疑项处置建议

1. **石皮蛊归属（U1 附录 `stone`）**→ 见 §2.4 主冲突 #1。
2. **血月蛊（附录 `bloodmoon`）**：拟 `blood`（C1 blood 行代表例；Master 配方『2 转血道蛊+2 转光道蛊 → 3 转血月蛊』语义自洽——成品主血、原料含光），月字成分仅供配方引用。候选 light 已否决（成品血属性）。
3. **玉皮/白玉/玉髓（附录 `jade`）**：拟统一归 `earth`（玉石=土石），候选 `gold`；若 U2 改判 gold，请三蛊（jade_skin_gu/white_jade_gu/jade_marrow_gu）一并改，保持玉系一致。月霓裳/天蓬的合炼伴侣语义属配方（D 阶段），不改变玉蛊流派。
4. **铁皮蛊与石皮/铜皮蛊同族（附录 `stone` 引语料）**：`gen_soul_movement_123_gu`（铁皮蛊）拟 `earth`（青茅山皮甲系），候选 gold——与石皮蛊处置须配套（见 #1）。
5. **痕石蛊/成功道痕/年兽等附录条目**：214 库中无对应条目，不涉及本表。

### 2.3 新发现冲突（本阶段新增）

1. **蛊名中文重名 ×2 组**：`月芒蛊`（moon_glow_gu r2/v9 vs moon_ray_gu r2/v10，同月华攻击蛊；moon_glow_gu 有 v1_effect+card、moon_ray_gu 的 v1_effect 为空且无 card_blueprint_ids，疑重复落库，且后者将通不过 B2 后『v1_effect 完备』目录校验）；`力量蛊`（force_gu 现 force vs gen_qi_healing_054 现 qi）。建议 U2：月芒蛊以 moon_glow_gu 为正身、moon_ray_gu 删除或更名（旧配方文本曾出现『月辉蛊』可作更名候选）；力量蛊以 force_gu 为正身，gen_qi_healing_054 更名。
2. **石皮蛊三向错配**（蛊名语料身份 / 占位条目身份 / S1 初始蛊身份）：见 §2.4 #1。
3. **旧前缀 school 全面失真**：gen_blood/gen_qi/gen_force/gen_soul/gen_refine 各 34/33/33/40/40 蛊系生成器按旧六校批量落桶后、中文名由语料回填，前缀与蛊名语义**大面积错位**（血段混入力道四件套、气段混入骨/力、魂段混入梦道/力/骨/石、炼段混入天道/人道/智道等）。本表已按蛊名语义重归类；规则见 §3。
4. **品阶/量词/家族占位名蛊**：gen_refine 段约 27 只、其他段零星（铁家/熊家/解石/能力/战力媲美等）为语料抽取残片（如『但血颅蛊』=『但』+血颅蛊；『量春风蛊』=『少量春风蛊』）。本表按『核心词归位或继承原校』处理并标 ☆，**建议 U2 授权批量改名/替换在 D/S 阶段随策展执行**，不在 C2 落库时展开。
5. **test_slay_gu（十转杀蛊）**：S2 Buff 机制蛊，rank=10 超出 C3 的 1–5 转语义；建议随 Buff 定义单独登记，school 维持 qi 占位即可（本表已拟 qi）。

### 2.4 待 U2 强裁主冲突（5 条）

| # | 蛊 | 冲突 | 方案 A（本表倾向） | 方案 B | 影响面 |
|---|---|---|---|---|---|
| 1 | 石皮蛊（gen_soul_attack_120_gu） | 语料=青茅山皮甲凡蛊（土石系）；现条目=soul 段攻击占位蛊；S1 要求=光道初始 4 蛊之一 | 改派此 id 为光道初始，school=light（须补 v1_effect/card 重做为防御向光道蛊） | 新建策展条目 stone_skin_gu(light)，本 id 更名回 soul 占位（school=soul 或 earth） | S1 初始蛊名单 + moon 系 starter + 铁皮蛊(earth)同族一致性 |
| 2 | 血月蛊（gen_blood_attack_002_gu） | 血 vs 光跨界 | 定 blood（成品主血） | 定 light（月华主名） | C1 blood 代表例引用；Master 3 转配方目标学校 |
| 3 | X力蛊族（火力/水力/风力/电力/地力蛊） | clean 语料将天/地/火/水/风/电力蛊列同谱『借自然之力』 | 全部归 force（力道·借自然力），候选 fire/water/wind/thunder/earth 留配方引用 | 各自归元素道（fire/water/wind/thunder/earth） | 五只蛊 + 力道总量 |
| 4 | 月芒蛊双 id（moon_glow/moon_ray） | 同语料蛊疑似重复落库 | moon_glow_gu 为正身（light）；moon_ray_gu 删除/更名 | 保留双 id（一为月芒一为月辉），school 均 light | B2 目录校验（v1_effect 完备） |
| 5 | 态度蛊（gen_refine_recon_174_gu） | C1 refine 行曾引『琅琊炼道仙蛊炼化』为证 vs 人祖传语义（态度=心的面具，人道寓言） | 拟 human（人道寓言蛊本体），refine 仅为其在琅琊被炼化的语境 | 维持 refine（尊重 C1 代表蛊例） | C1 refine 代表蛊例引用 |

## 3. 批量蛊归类规则建议（供 C2 落库程序化执行）

> 目标：把 §1 表中『☆ 待复核』的规则性项收敛为可编程规则，U2 一次授权后由落库脚本执行；强裁 5 条仍逐条定案。规则按优先级匹配，命中即止。

| 优先级 | 规则 | 归 school | 适用蛊（代表） | 例外/说明 |
|---|---|---|---|---|
| R1 | 蛊名在 U1 清单 §1 代表蛊例 / 本文语料核验表中已定位（依据列非 ☆ 或标注出处） | 按表 | 见 §1 表 | 最高优先，U2 改判才覆盖 |
| R2a | 名字含『血/经血/败血/血幕/血手印/血影/血绳/血神子/血颅/血鬼尸/血狂/血战/血汗』等血系字根 | blood | gen_blood_001~018 等 | 血月蛊/败血妖花蛊按 R1 个案 |
| R2b | 名字含『魂』或属 clean 凝魂蛊清单（狼魂/怨魂/龙魂/诗魂/月魂/冰魂/梦魂/将魂…）；或含『胆识』；魂灯/魂山 | soul | 狼魂×3、怨魂、龙魂、诗魂、月魂、冰魂、梦魂、胆识蛊、魂山胆识蛊、魂灯蛊、潜魂兽衣蛊 | 梦魂/月魂/冰魂**不按字面**入梦/冰/月道（语料确证为魂道凝魂蛊） |
| R2c | 名字含『力/钧/斤』，或为兽力系（熊/牛/鹰/天牛/鳄/龟/龙象/飞熊/棕熊/青牛/昆仑牛/白猪/豪猪） | force | 力道四件套、人力钧力流（斤力/十斤/十钧/钧力）、熊豪/驭熊除外 | 驭熊蛊含『熊』但属驭兽→slave（R1 个案）；X力蛊族见 R2d |
| R2d | 名形如『X 力蛊』，X∈{火,水,风,电,地,天} | force（候选对应元素道） | 火力蛊、水力蛊、风力蛊、电力蛊、地力蛊 | clean 同谱语料；候选 fire/water/wind/thunder/earth 供配方 |
| R2e | 名字含『骨』（骨枪/螺旋骨枪/玉骨/骨翼/臂骨翼/战骨车轮/续骨/骨肉团圆/情同骨肉） | bone | 骨枪蛊、玉骨蛊、战骨车轮蛊、骨翼蛊、续骨蛊、骨肉团圆蛊、情同骨肉蛊、臂骨翼蛊 | 骨肉团圆/情同骨肉含『肉』仍属骨道（灰骨才子） |
| R2f | 名字含『石/山/窍/拳石/隐石/石人』；皮甲系（石皮/铜皮/铁皮） | earth | 石窍蛊、石人蛊、拳石蛊、隐石蛊、石甲蛊、铁皮蛊、（方案 A 下石皮蛊除外） | 熔岩炸裂蛊=岩浆→fire（个案） |
| R2g | 名字含『铁/钢/金/铜/赤铁/铁索/铁柜/铁壁/铁甲/铁手/铁骨/钢筋/生铁』（器物/防护金属） | gold | 铁骨蛊、钢筋蛊、生铁蛊、铁壁蛊、铁柜蛊、铁甲大蛊、铁手擒拿蛊、镇魔铁索蛊、赤铁舍利蛊、金风送爽蛊 | 铁皮蛊(皮甲系)走 R2f；铁冠鹰力蛊=鹰力→force |
| R2h | 名字含『剑/剑气』 | sword | 剑气蛊、四转剑气蛊 | 刀气蛊拟 gold（候选 sword，刀≠剑） |
| R2i | 名字含『气/吐气/风气/化气/气囊/人气/朝气/威风』 | qi | 化气蛊、气囊蛊、人气蛊、风气蛊、朝气蛊、扬眉吐气蛊、八面/七面威风蛊 | 硬气蛊拟 force（候选 qi）；风气蛊候选 wind |
| R2j | 名字含『风』（追风/狂风/餐风/风花/风虎云龙/春风） | wind | 追风蛊、狂风蛊、餐风蛊、风花蛊、风虎云龙蛊、量春风蛊(春风) | 风力蛊→R2d；风气蛊→qi |
| R2k | 名字含『月/光/幻月』（月光/月芒/月影/幻月/小光） | light | 月光蛊、小光蛊、月芒蛊×2、月影蛊、幻月蛊、生机草蛊(S1) | 月魂蛊/月霓裳系不适用（月魂=soul）；石皮蛊=S1 个案 |
| R2l | 名含『梦道凡蛊』（梦道/制梦/多梦/炼梦前缀） | dream | 梦道凡蛊、制梦道凡蛊、多梦道凡蛊、炼梦道凡蛊 | 梦魂蛊=soul（凝魂蛊） |
| R2m | 藤/草/根/棘/荆棘（草木） | wood | 棘鞭蛊、铁刺荆棘蛊、回春草蛊、生根蛊、不死藤蛊 | 生机草蛊→light(S1)、血苔蛊→blood |
| R2n | 玉系（玉皮/白玉/玉髓） | earth（候选 gold） | jade_skin_gu、white_jade_gu、jade_marrow_gu | 需与 U2 对玉系裁决一致 |
| R2o | 族/族名或种族词作蛊名（毛民/天庭/南疆/北原/东海/洲/异人/黑家/戚家/房家/铁家/熊家） | 继承原前缀学校 | 集中于 gen_refine 段 | 占位名（R3 同源） |
| R3 | 占位/残句名蛊（判定：无语料蛊名对应，名含『但/不到/拿到/得到/撤销/几位/炼制/此/强/凡/对于/其余/其他/很多/许多/女/青年/八转/七转/六转/五转/品阶词』等 + 蛊）：核心词有实义则按核心词归位（但血颅→blood、拿到苦力→force、得到铁骨→gold、几位石人→earth、撤销铁柜→gold），无实义则继承原前缀学校 | 核心词对应道痕 / 原前缀 | 见 §1 表 ☆ 行 | 批量标记『流派占位·待策展替换』，供 D/S 阶段策展 |
| R4 | role/effect 兜底：仅当名字完全无信息且非 R3 时 | 维持现 school | — | 本批实际全部落入 R1–R3，R4 未触发 |

> 执行顺序建议：落库脚本先跑 R1 特判表（§1 直接建议行与强裁定案），再跑 R2 字根表，最后 R3 占位归位；输出与 §1 表逐行 diff 校验后方可写 `gu.json`。

## 4. 审订遗留风险

1. **旧 starter_gu_ids 失真**：`schools.json` v1 各校 starter 大量引用将被改派的蛊（qi/force/soul/refine 段），U2 落库时需一并重排 starter（每校 4 只 1 转初始蛊由 S1 起逐校铺开）。
2. **红线六校保有量核查**：blood 23 / qi 22 / force 51 / soul 16 / refine 27 / light 8。light 偏薄但 S1 只要求 4 初始蛊；soul 建议后续策展补强（若 U2 认为 16 不足）。
3. **换名/改名不属本工单**：残句蛊更名、moon_ray_gu 合并等仅提出建议，实际改名留待对应策展工单。
4. **语料核验边界**：本表依据『蛊名+语料定点检索』，对 ~80 词做过命中核验；未对全部 214 蛊穷举原文语境，占位名蛊（§3 R3）的『原语义』可能随后续精读修正。