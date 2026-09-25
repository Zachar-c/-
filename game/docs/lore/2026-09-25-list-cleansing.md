# 四清单原文核验与清洗台账（2026-09-25）

> 任务：根据原著《蛊真人》（
>
> `蛊真人-clean.txt`
>
> ，行号 L 即原文锚点，项目约定同 
>
> `lore/wiki/gu/roster.md`
>
> ）核验并清洗四份游戏数据清单：蛊虫（
>
> `game/data/gu.json`
>
> ，802 只）、杀招（
>
> `game/data/v1_battle.json`
>
> ，26 条）、地图节点（
>
> `game/data/nodes.json`
>
> ，37 个）、敌人（
>
> `game/data/enemies.json`
>
> ，32 个）。
> 核验方式：对原文全文逐词检索，命中行号记入 
>
> `origin_ref`
>
> 。
>
> `origin`
>
>  三值口径对齐 
>
> `docs/lore/content-source-schema.md`
>
>  的 
>
> `source_class`
>
> ：
> `canon`
>
> ：原著直接对应的实体 / 命名（附首次行号）；
> `adaptation`
>
> ：有原著概念或词源基础，具体形态为游戏化组合；
> `original_game_content`
>
> ：原著无对应，游戏原创命名。
> 本次改动仅增加元数据字段（
>
> `source`
>
>  / 
>
> `origin`
>
>  / 
>
> `origin_ref`
>
> ），不触碰任何数值与玩法。
>
> `ContentCatalog.validate`
>
>  改动前后均 
>
> `VALIDATE_ERRORS=0`
>
> 。

## 一、蛊虫 gu.json（802）

**source 现状**：786 条已有 `source`，仅两类分类标签、无行号锚 ——`novel` 261 + `school_derived` 525；16 条缺失。

**novel 261 只全量核验：中文名全部命中原文（261/261）**，`novel` 分类可信（如血颅蛊、血月蛊 L26850、骨枪蛊、梦蝶仙蛊、火龙蛊、拔山蛊等）。原字段只标 "原著有据" 分类、无具体锚点，属记录粒度不足而非错误。

**school\_derived 525 只**：流派体系批量衍生命名（抽查 25 只如 "剑利剑蛊 / 骨骨环蛊 / 梦沉梦蛊" 多为自动拼接造名）。个别名字与原文蛊名重合属正常现象（原文蛊名亦被流派借用）。口径：`school_derived` = 体系衍生，不代表原著存在。

**16 只无 source 已补**（全部为流派基石蛊 + 1 只测试蛊）：



| id                        | 中文名   | 补 source | 原文锚点                                                 |
| ------------------------- | ----- | -------- | ---------------------------------------------------- |
| small\_light\_gu          | 小光蛊   | novel    | L9704                                                |
| moonlight\_gu             | 月光蛊   | novel    | L1430                                                |
| moon\_glow\_gu            | 月芒蛊   | novel    | L15710                                               |
| moon\_ray\_gu             | 月痕蛊   | novel    | L17156                                               |
| moon\_shadow\_gu          | 月影蛊   | novel    | L2648                                                |
| vitality\_grass\_gu       | 生机草蛊  | novel    | L16490（九叶生机草，二转治疗蛊）                                  |
| force\_gu                 | 力量蛊   | novel    | L1110（《人祖传》）                                         |
| bear\_strength\_gu        | 熊力蛊   | novel    | L3602（熊家标志蛊）                                         |
| white\_boar\_strength\_gu | 白豕蛊   | novel    | L9670                                                |
| jade\_skin\_gu            | 玉皮蛊   | novel    | L9612                                                |
| white\_jade\_gu           | 白玉蛊   | novel    | L9986（白豕蛊 + 玉皮蛊合炼）                                   |
| stone\_shell\_gu          | 石皮蛊   | novel    | L9600（**注意：id 是 stone\_shell，中文名正确为 "石皮蛊"，无 "石壳蛊"**） |
| blood\_farewell\_gu       | 爱别离蛊  | novel    | L11784                                               |
| blood\_droplet\_gu        | 血滴子   | novel    | L28418（第一百六十五节章名）                                    |
| blood\_bat\_gu            | 刀翅血蝠蛊 | novel    | L31864                                               |
| test\_slay\_gu            | 十转杀蛊  | test     | 测试蛊，非原著                                              |

## 二、杀招 v1\_battle.json（26）



| origin                  | 条数 | 明细                                                                                                                                         |
| ----------------------- | -- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| canon                   | 10 | 五指拳心剑・二 / 四 / 五转（L160024/L160166 剑道仙级杀招，秦百胜杀手锏 L168076）；剑痕索命・一 / 二 / 四 / 五转（L194470 剑道杀招，仙级）；万剑劫・二 / 四 / 五转（L192506 薄青所创仙道杀招，以飞剑仙蛊为核心以一化万） |
| adaptation              | 1  | 明光壁（原文 "光壁"L130776 蛊仙光壁，全名为游戏组合）                                                                                                           |
| original\_game\_content | 15 | 凝光（原文仅 "虎目凝光" 成语语境 L259148）、血昙（0 命中）、崩山（仅 "遇山崩山" 成语 L68440，非杀招名）、双锋引 ×4、剑气冲霄 ×4、剑影万千 ×4（均 0 命中）                                            |

**注意**：三组 canon 杀招原著均为**仙级 / 仙道杀招**（六转起），游戏做成凡级一至五转，转数化属游戏裁定（与 content-source-schema 的杀招记录语义一致，本次未改数值，仅登记命名出处）。

## 三、敌人 enemies.json（32）



| origin                  | 条数 | 明细                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------- | -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| canon                   | 13 | beast\_swarm 兽潮 L4708・mountain\_boar 山猪 L664・fat\_sand\_scorpion 肥肉沙蝎 L124846・straw\_puppet 草人傀儡 L3634・white/black/blue\_fur\_jiangshi 白毛 / 黑毛 / 蓝毛僵 L45600・venom\_whisker\_wolf\_king 毒须狼王 L78814・thunder\_crown\_wolf 雷冠头狼 L4908・iron\_crown\_eagle 铁冠鹰 L127802・dragon\_eagle 龙鹰 L127802・blood\_forest\_wolf 血森狼 L90496・sand\_lurker\_spider 潜沙蛛 L152032                                                                                                                                                                                                                                                                                                 |
| adaptation              | 17 | 散修系（neutral\_stone\_wanderer/rogue\_cultivator L51260）・ridge\_hound 山脊猎犬（三犬一獒 L29094）・miasma\_vein\_lord 瘴脉蛊主（瘴气 L192232）・iron\_hide\_boar 黑皮野猪（L2070；原 "铁皮山猪" 已改）・crag\_serpent\_matriarch 崖蟒主母（巨蟒 L2504）・clan\_warden/faction\_guard（山寨 L322）・school\_elder/clan\_elder（长老 L1012）・clan\_patriarch（族长 L326）・demon\_path\_adept（魔道蛊师 L11580）・slave\_path\_adept（奴道蛊师 L64294）・roaming\_jiangshi 游僵（僵尸 L20746）・mountain\_hunter（山民 / 猎人 L10074）・marrow\_gu\_adept 蚀骨蛊师（骨肉团圆蛊 L37456）・thunder\_crown\_sovereign 雷冠狼王（雷冠头狼 L4908 + 狼王 L15292 组合，游戏升级命名） |
| original\_game\_content | 2  | ridge\_elite\_scout 精英哨探（探子 / 哨探原文无）・blood\_vein\_bishop 血络主教（"血络" 原文 0 命中）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

## 四、地图节点 nodes.json（37）



| origin                  | 条数 | 明细                                                                                                                                                                                      |
| ----------------------- | -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| canon                   | 4  | cultivation\_spring 灵泉 L926・ridge\_black\_market 黑市 L95680・beast\_swarm\_pass 兽潮 L4708・**yizang\_ridge 遗藏岭 L1334**（"遗藏"138 命中，"义葬" 为误读，原文无此词）                                           |
| adaptation              | 27 | 商队 L2014・山寨 / 寨 L322・散修 L51260・狼群 L4908・地脉 L214986・炼道 L64574・传承之地 L39168・溶洞 L922・沼泽 + 黑泥 L51142・血藤 L150596・祠堂 L336・祭坛 L76348・尸蛊 L21360・石屋 / 石窟 L36762・瘴气 L192232・黑皮野猪 L2070 等场景概念       |
| original\_game\_content | 6  | stage\_one\_ledger 账簿（游戏机制位）・echo\_cave 回音洞（"回音" 仅山谷回音语境 L31550，事件为游戏设计）・herbalist\_commission 草药师委托・final\_boss\_stand 终局 Boss 位・body\_imprint\_ritual 刻印仪式・scout\_crossing\_raid 哨探突袭 |

## 五、命名修订执行记录（2026-09-25）

以下修订已按原文执行到 `game/data/names.json` 与 wiki 页；`enemies.json` 的 `origin` 已同步。

1. **iron_hide_boar：`铁皮山猪` → `黑皮野猪`**（原文 L2070；"铁皮山猪/铁皮野猪/铁背猪"均无原文）——已改 `names.json`，并同步节点名 `iron_hide_ambush`（铁皮野猪伏击 → 黑皮野猪伏击）。
2. **blood_forest_wolf：维持 `血森狼`，origin 升 `canon`**——原文 `蛊真人-clean.txt` L90496 详写"血森狼"（皮毛血红、背生白色骨树成"血森"，23 处命中），是原著狼种；本台账初判"游戏原创/改血狼"系漏查，已修正（曾误改"血狼"，已回退）。`enemies.json` origin 由 adaptation L87694 升级为 canon L90496。
3. **thunder_crown_sovereign：维持 `雷冠狼王`，标注升级命名**——原文"雷冠头狼"（L4908 狼群首领，94 命中）与"狼王"（L15292，724 命中）均有据；组合名"雷冠狼王"为游戏升级命名，保留并标注。`map-generator.md` 已同步。
4. **data-tables.md L17：`石壳蛊 6` → `石皮蛊 6`**（原文与 `gu_names.json` 均为"石皮蛊"L9600）——已改；同步修正 `map-generator.md`"遗葬"→"遗藏"与 `names.json`"荒岭遗葬"→"荒岭遗藏"（yizang = 遗藏，L1334）。
5. **血络主教 / 瘴脉蛊主 / 山脊悍客：游戏原创标注已就位**——`enemies.json` origin 均已标 `original_game_content`；`map-generator.md` 层主位注释已注明游戏命名与台账对照。
6. **crag_serpent_matriarch：维持 `崖蟒主母`，标注蟒系词源**——原文无"蟒母/蛇母"，有"巨蟒"（L2504）与"血蟒蛊"（L33390）；"崖蟒主母"含蟒系词源，保留并标注。`map-generator.md` 已同步。
7. **追加修正：sand_lurker_spider 升 `canon`**——原文"潜沙蛛"L152032（15 处命中，西漠萧家战潜沙蛛群），初判"游戏原创"系漏查；`enemies.json` origin 由 adaptation L6080 升级为 canon L152032。

执行验证：`names.json` / `enemies.json` JSON 解析通过；`ContentCatalog.validate` 复跑 `VALIDATE_ERRORS=0`。

## 六、数据文件改动与验证



| 文件                         | 改动                                | 验证                                            |
| -------------------------- | --------------------------------- | --------------------------------------------- |
| `game/data/gu.json`        | 16 条补 `source`（15 novel + 1 test） | JSON 可解析；`ContentCatalog.validate` = 0 errors |
| `game/data/v1_battle.json` | 26 条补 `origin` / `origin_ref`     | 同上                                            |
| `game/data/enemies.json`   | 32 条补 `origin` / `origin_ref`；blood\_forest\_wolf / sand\_lurker\_spider 升 canon（血森狼 L90496 / 潜沙蛛 L152032） | 同上                                            |
| `game/data/nodes.json`     | 37 条补 `origin` / `origin_ref`     | 同上                                            |
| `game/data/names.json`      | 敌人/节点中文名修订 4 处（铁皮山猪→黑皮野猪、铁皮野猪伏击→黑皮野猪伏击、荒岭遗葬→荒岭遗藏；血森狼维持原名） | JSON 可解析 |

验证命令：`godot --headless --path . -s tools/_clean_validate_probe.gd`（临时探针，已删）；改动前基线 `VALIDATE_ERRORS=0`，改动后仍 `VALIDATE_ERRORS=0`。

工作树改动未提交（项目惯例：仅用户要求时提交）。字段口径说明：`origin_ref` 中 `L` 指 `蛊真人-clean.txt` 行号；`origin` 与 `content-source-schema.md` 的 `source_class` 三值对齐，可作为后续 `source_class` 迁移的输入。