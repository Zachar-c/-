// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。
// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。
const DATA = {
  "gu": [
    {
      "id": "moonlight_gu",
      "name": "月光蛊",
      "rank": 1,
      "rarity": "epic",
      "role": "attack",
      "school": "light",
      "value": 4,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 3
      },
      "icon": "gu_moon"
    },
    {
      "id": "small_light_gu",
      "name": "小光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "school": "light",
      "value": 3,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 2
      },
      "icon": "gu_light"
    },
    {
      "id": "moon_glow_gu",
      "name": "月芒蛊",
      "rank": 2,
      "rarity": "rare",
      "role": "attack",
      "school": "light",
      "value": 9,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_moon"
    },
    {
      "id": "white_boar_strength_gu",
      "name": "白豕蛊",
      "rank": 1,
      "rarity": "epic",
      "role": "attack",
      "school": "force",
      "value": 10,
      "cost": 1,
      "effect": {
        "kind": "composite",
        "parts": [
          {
            "kind": "add_temp_stat",
            "stat": "force_power",
            "amount": 3,
            "duration_turns": 1
          }
        ]
      },
      "icon": "gu_force"
    },
    {
      "id": "jade_skin_gu",
      "name": "玉皮蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "defense",
      "school": "earth",
      "value": 8,
      "cost": 1,
      "effect": {
        "kind": "composite",
        "parts": [
          {
            "kind": "grant_block",
            "amount": 3,
            "duration_turns": 1
          }
        ]
      },
      "icon": "gu_water"
    },
    {
      "id": "stone_shell_gu",
      "name": "石皮蛊",
      "rank": 1,
      "rarity": "common",
      "role": "defense",
      "school": "earth",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "shield",
        "amount": 3
      },
      "icon": "gu_earth"
    },
    {
      "id": "white_jade_gu",
      "name": "白玉蛊",
      "rank": 2,
      "rarity": "epic",
      "role": "defense",
      "school": "earth",
      "value": 30,
      "cost": 2,
      "effect": {
        "kind": "composite",
        "parts": [
          {
            "kind": "grant_block",
            "amount": 5,
            "duration_turns": 1
          }
        ]
      },
      "icon": "gu_water"
    },
    {
      "id": "blood_farewell_gu",
      "name": "爱别离蛊",
      "rank": 1,
      "rarity": "epic",
      "role": "attack",
      "school": "blood",
      "value": 6,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 4,
        "condition": {
          "type": "self_hp_below",
          "threshold": 0.5
        }
      },
      "icon": "gu_blood"
    },
    {
      "id": "blood_droplet_gu",
      "name": "血滴子",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "school": "blood",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_blood"
    },
    {
      "id": "vitality_grass_gu",
      "name": "生机草蛊",
      "rank": 1,
      "rarity": "common",
      "role": "logistics",
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 1
      },
      "icon": "gu_qi"
    }
  ],
  "recipes": [
    {
      "id": "moon_glow_fixed",
      "kind": "fixed",
      "inputs": [
        "moonlight_gu",
        "small_light_gu",
        "small_light_gu"
      ],
      "output": "moon_glow_gu",
      "stoneCost": 0,
      "materials": null,
      "source": "蛊真人-clean.txt 17024-17155：月芒蛊=月光蛊x1+小光蛊x2（合炼失败代价示例：小光蛊消亡）"
    },
    {
      "id": "white_jade_advance",
      "kind": "fixed",
      "inputs": [
        "jade_skin_gu",
        "white_boar_strength_gu"
      ],
      "output": "white_jade_gu",
      "stoneCost": 50,
      "materials": {
        "boar_king_tusk": 1
      },
      "source": "蛊真人-clean.txt 15860-15895：白玉蛊=白豕蛊+玉皮蛊，添头野猪王雪獠牙（后世改良，提高成功率）"
    },
    {
      "id": "moonlight_glow",
      "kind": "fixed",
      "inputs": [
        "moonlight_gu",
        "small_light_gu"
      ],
      "output": "moon_glow_gu",
      "stoneCost": 0,
      "materials": null,
      "source": "蛊真人-clean.txt 17140-17155：月光蛊晋升路线之一（月光蛊x1+小光蛊x1→月芒蛊）"
    },
    {
      "id": "white_jade_basic",
      "kind": "fixed",
      "inputs": [
        "jade_skin_gu",
        "white_boar_strength_gu"
      ],
      "output": "white_jade_gu",
      "stoneCost": 50,
      "materials": null,
      "source": "蛊真人-clean.txt 15860-15895：白玉蛊=白豕蛊+玉皮蛊"
    },
    {
      "id": "advance_small_light_gu",
      "kind": "advance",
      "inputs": [
        "small_light_gu"
      ],
      "output": "small_light_gu",
      "stoneCost": 6,
      "materials": {
        "beast_blood": 1
      },
      "source": null
    },
    {
      "id": "advance_stone_shell_gu",
      "kind": "advance",
      "inputs": [
        "stone_shell_gu"
      ],
      "output": "stone_shell_gu",
      "stoneCost": 6,
      "materials": {
        "beast_bone": 2
      },
      "source": null
    }
  ],
  "killMoves": [
    {
      "id": "km_light_converge",
      "label": "凝光",
      "tag": "light",
      "recipe": [
        "moonlight_gu",
        "small_light_gu"
      ],
      "true_qi_cost": 3,
      "thought_cost": 1,
      "life_cost": 0,
      "damage": 0,
      "effect": {
        "kind": "strike",
        "amount": 5
      }
    },
    {
      "id": "km_light_bulwark",
      "label": "明光壁",
      "tag": "light",
      "recipe": [
        "stone_shell_gu",
        "vitality_grass_gu"
      ],
      "true_qi_cost": 2,
      "thought_cost": 1,
      "life_cost": 0,
      "damage": 0,
      "effect": {
        "kind": "shield",
        "amount": 6
      }
    },
    {
      "id": "km_blood_ember",
      "label": "血昙",
      "tag": "blood",
      "recipe": [
        "blood_farewell_gu",
        "blood_droplet_gu"
      ],
      "true_qi_cost": 3,
      "thought_cost": 2,
      "life_cost": 0,
      "damage": 0,
      "effect": {
        "kind": "heal_and_strike",
        "heal": 2,
        "amount": 3
      }
    }
  ],
  "enemies": [
    {
      "id": "neutral_stone_wanderer",
      "name": "石甲散修",
      "rank": 1,
      "hp": 4,
      "theme": "neutral",
      "intent": {
        "id": "stone_palm",
        "label": "掌势蓄而未发",
        "damage": 2,
        "speed": 1
      },
      "portrait": "enemy_stone_wanderer",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "stone_dust",
        "steady_stance"
      ],
      "reactions": [
        {
          "id": "stone_shell",
          "clue": "stone_dust",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "石甲护身"
        }
      ]
    },
    {
      "id": "ridge_hound",
      "name": "山脊猎犬",
      "rank": 1,
      "hp": 3,
      "theme": "beast",
      "intent": {
        "id": "pounce",
        "label": "伏肩扑咬",
        "damage": 2,
        "speed": 0
      },
      "portrait": "enemy_ridge_hound",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "lowered_shoulders",
        "wet_fang"
      ],
      "reactions": [
        {
          "id": "counter_bite",
          "clue": "lowered_shoulders",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "反口撕咬"
        }
      ]
    },
    {
      "id": "iron_hide_boar",
      "name": "铁皮山猪",
      "rank": 2,
      "hp": 5,
      "theme": "beast",
      "intent": {
        "id": "tusk_drive",
        "label": "獠牙冲撞",
        "damage": 2,
        "speed": 1
      },
      "portrait": "enemy_iron_hide_boar",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "mud_caked",
        "worn_tusks"
      ],
      "reactions": [
        {
          "id": "bristle_turn",
          "clue": "mud_caked",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "厚皮硬受"
        }
      ]
    },
    {
      "id": "thunder_crown_wolf",
      "name": "雷冠头狼",
      "rank": 3,
      "hp": 7,
      "theme": "beast",
      "intent": {
        "id": "thunder_bite",
        "label": "雷冠撕咬",
        "damage": 3,
        "speed": 3
      },
      "portrait": "enemy_thunder_crown_wolf",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "crackling_fur",
        "hunched_gait"
      ],
      "reactions": []
    },
    {
      "id": "thunder_crown_sovereign",
      "name": "雷冠狼王",
      "rank": 5,
      "hp": 18,
      "theme": "beast",
      "intent": {
        "id": "crown_bolt",
        "label": "雷冠贯落",
        "damage": 4,
        "speed": 2,
        "cooldown": 1
      },
      "portrait": "enemy_thunder_crown_sovereign",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "crown_bolt",
              "label": "雷冠贯落",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            }
          ],
          "reactions": []
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "crown_bolt",
              "label": "雷冠贯落",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            },
            {
              "id": "paralyzing_howl",
              "label": "麻痹长嗥",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": []
        }
      ],
      "phasesNote": null,
      "clues": [
        "charged_fur",
        "crackling_air"
      ],
      "reactions": []
    },
    {
      "id": "blood_vein_bishop",
      "name": "血络主教",
      "rank": 5,
      "hp": 20,
      "theme": "cultivator",
      "intent": {
        "id": "vein_whip",
        "label": "血络鞭挞",
        "damage": 4,
        "speed": 3,
        "cooldown": 1
      },
      "portrait": "enemy_bat",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "vein_whip",
              "label": "血络鞭挞",
              "damage": 4,
              "speed": 3,
              "cooldown": 1
            }
          ],
          "reactions": [
            {
              "id": "blood_siphon",
              "clue": "swollen_veins",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "血络回吸"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "vein_whip",
              "label": "血络鞭挞",
              "damage": 4,
              "speed": 3,
              "cooldown": 1
            },
            {
              "id": "crimson_feast",
              "label": "猩红盛餐",
              "damage": 5,
              "speed": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "blood_siphon",
              "clue": "swollen_veins",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "血络回吸"
            }
          ]
        }
      ],
      "phasesNote": null,
      "clues": [
        "swollen_veins",
        "beating_drum"
      ],
      "reactions": [
        {
          "id": "blood_siphon",
          "clue": "swollen_veins",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "血络回吸"
        }
      ]
    }
  ],
  "encounters": [
    {
      "id": "layer_boss_stand_1",
      "name": "layer_boss_stand_1",
      "type": "combat",
      "enemy_kind": "crag_serpent_matriarch",
      "enemy_kinds": null,
      "enemy_theme": "beast",
      "boss_pool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept"
      ],
      "summary": ""
    },
    {
      "id": "layer_boss_stand_2",
      "name": "layer_boss_stand_2",
      "type": "combat",
      "enemy_kind": "marrow_gu_adept",
      "enemy_kinds": null,
      "enemy_theme": "cultivator",
      "boss_pool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign"
      ],
      "summary": ""
    },
    {
      "id": "layer_boss_stand_3",
      "name": "layer_boss_stand_3",
      "type": "combat",
      "enemy_kind": "thunder_crown_sovereign",
      "enemy_kinds": null,
      "enemy_theme": "beast",
      "boss_pool": [
        "thunder_crown_sovereign",
        "clan_patriarch"
      ],
      "summary": ""
    },
    {
      "id": "layer_boss_stand_4",
      "name": "layer_boss_stand_4",
      "type": "combat",
      "enemy_kind": "blood_vein_bishop",
      "enemy_kinds": null,
      "enemy_theme": "cultivator",
      "boss_pool": [
        "clan_patriarch",
        "blood_vein_bishop",
        "blue_fur_jiangshi"
      ],
      "summary": ""
    },
    {
      "id": "beast_swarm_pass",
      "name": "兽群隘口",
      "type": "combat",
      "enemy_kind": "ridge_hound",
      "enemy_kinds": [
        "ridge_hound",
        "neutral_stone_wanderer"
      ],
      "enemy_theme": "beast",
      "boss_pool": null,
      "summary": "兽群堵住窄隘，击退它们可收取材料，撤退则必须改道。"
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "type": "combat",
      "enemy_kind": "faction_guard",
      "enemy_kinds": null,
      "enemy_theme": "faction",
      "boss_pool": null,
      "summary": ""
    },
    {
      "id": "final_boss_stand",
      "name": "final_boss_stand",
      "type": "combat",
      "enemy_kind": "miasma_vein_lord",
      "enemy_kinds": null,
      "enemy_theme": "anomaly",
      "boss_pool": null,
      "summary": "瘴脉尽头，蛊主把守升仙窗口。"
    },
    {
      "id": "iron_hide_ambush",
      "name": "iron_hide_ambush",
      "type": "combat",
      "enemy_kind": "iron_hide_boar",
      "enemy_kinds": null,
      "enemy_theme": "beast",
      "boss_pool": null,
      "summary": "铁皮野猪拦在隘口，獠牙泛光，撞上来就是一道血口。"
    },
    {
      "id": "scout_crossing_raid",
      "name": "scout_crossing_raid",
      "type": "combat",
      "enemy_kind": "ridge_elite_scout",
      "enemy_kinds": null,
      "enemy_theme": "faction",
      "boss_pool": null,
      "summary": "斥候在岭脊设伏，弩机已上弦，先手藏在草丛里。"
    },
    {
      "id": "wolf_pack_trail",
      "name": "wolf_pack_trail",
      "type": "combat",
      "enemy_kind": "thunder_crown_wolf",
      "enemy_kinds": null,
      "enemy_theme": "beast",
      "boss_pool": null,
      "summary": "雷冠狼独踞道中，爪下电纹明灭，是兽群头狼。"
    }
  ],
  "battle": {
    "aptitudeMult": {
      "jia": 4,
      "yi": 3,
      "bing": 2,
      "ding": 1
    },
    "regenPct": {
      "jia": 35,
      "yi": 30,
      "bing": 25,
      "ding": 18
    },
    "stageBase": {
      "one": 10,
      "two": 30,
      "three": 60,
      "four": 100,
      "five": 150
    },
    "thoughtCostDefault": 1,
    "trueQiCostDefault": 1,
    "fightDamageBase": 1
  },
  "mechanisms": {
    "covered": [
      {
        "name": "真实蛊实体",
        "detail": "10 只蛊的名称/转数/稀有度/流派/价值/效果",
        "source": "world-model/data/gu.json（802 实体）"
      },
      {
        "name": "合炼与升炼配方",
        "detail": "6 条配方的材料、元石成本、原文出处行号；失败代价按原文个案（小光蛊消亡）",
        "source": "data/refinement_recipes.json（468 条）"
      },
      {
        "name": "杀招组装与消耗",
        "detail": "3 个杀招的配方、真元/念头消耗、效果",
        "source": "data/v1_battle.json → kill_moves（26 条）"
      },
      {
        "name": "真元上限与回复",
        "detail": "真元上限 = stage_base × aptitude_mult；每回合按 regen_pct 回复（丙等 25%）",
        "source": "data/v1_battle.json → stage_base / aptitude_mult / regen_pct"
      },
      {
        "name": "敌人意图",
        "detail": "意图标签与伤害，每回合公开",
        "source": "data/enemies.json → intent"
      },
      {
        "name": "线索与反击（隐藏→揭示）",
        "detail": "敌人自带 clues 与 reactions；揭示前不预警，揭示后可预警",
        "source": "v1_battle_resolver.gd:136,724-731（counter_revealed）"
      },
      {
        "name": "直接攻击被反击吞掉",
        "detail": "触发条件 trigger=direct_strike / window=before_damage；吞掉后敌方进入 bound/guarded，该反击随即不再预警",
        "source": "action_preview_service.gd:325-347（_live_counter_labels）"
      },
      {
        "name": "多阶段 AI（阶段 + 冷却门禁）",
        "detail": "按 until_hp_ratio 切阶段；每阶段可有多条意图，第 T 回合发出后 T+cooldown+1 起才可再选；当前阶段所有意图都在冷却时显示 cooldown_wait、该回合不攻击",
        "source": "data/enemies.json 的 phases 与自带 _phases_note；enemy_catalog.gd:174-208 只做 schema 校验，运行时未实现——本页是首个实现"
      },
      {
        "name": "焚元意图",
        "detail": "意图带 essence_burn 时烧掉玩家真元（蚀脉扰元 / 麻痹长嗥）",
        "source": "data/enemies.json phases[].intents[].essence_burn（按字段名直译，Godot 运行时不读该字段）"
      },
      {
        "name": "多敌遭遇",
        "detail": "10 个 type=combat 模板中唯一多敌 beast_swarm_pass（enemy_kinds 2 只）；规模 = enemy_kinds 长度；玩家点选目标、未选回退第一个存活；敌方按数组序逐个结算、每次立即判胜负；全灭才胜利；反击/阶段/冷却每敌一份；护体是池语义",
        "source": "data/nodes.json → beast_swarm_pass；battle_command_facade.gd:58-68,152-160（_v1_enemies）；v1_grammar_pipeline.gd:103-124（resolve_targets）、132-137（alive_count）；v1_battle_resolver.gd:110-135（_build_enemies）、644（_enemy_is_alive）、820-826（end_turn）、1063-1072（焚元）、1083-1088（护体池）"
      }
    ],
    "notCovered": [
      {
        "name": "marked 刻痕",
        "why": "v1_battle.json 的 kill_moves 里没有任何带 marked 的招，来源在剑道刻痕通道，本批无数据支撑，不臆造"
      },
      {
        "name": "sealed 封印",
        "why": "同上，26 个 kill_moves 无 sealed 效果"
      },
      {
        "name": "support_bonus 辅助加成",
        "why": "只在 content_catalog.gd 里做 schema 校验，未找到结算应用点，故不实现"
      },
      {
        "name": "意图选取顺序",
        "why": "数据未写明多意图之间的优先级（_phases_note 只定义了冷却门禁）。本页取\"数据顺序中第一条可用的\"，属原型设定，Godot 无实现可对照"
      },
      {
        "name": "另 3 个带阶段数据的 Boss",
        "why": "blood_vein_bishop 之外的 clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，未纳入；其中 clan_patriarch 的「家族征召」是 damage 0 且无 essence_burn，语义未知"
      },
      {
        "name": "Boss 立绘",
        "why": "血络主教无专属立绘，借用同流派血道蝙蝠图（enemy_bat.png），仅影响观感"
      },
      {
        "name": "念头/魂魄完整系统",
        "why": "本页只用了念头作为行动成本，魂魄与失控未实现"
      },
      {
        "name": "确定性、存档、事件日志",
        "why": "本原型完全没有：随机、不落盘、不改写状态机，仅供视觉确认"
      },
      {
        "name": "counter_status=\"sparked\"（雷冠头狼）",
        "why": "数据漂移：data/enemies.json 声明了该反击状态，但 scripts/ 与 docs/ 里零命中，规则层无实现语义。本页不臆造，已从反击列表剔除"
      },
      {
        "name": "线索的中文名",
        "why": "数据缺口：data/names.json 没有 clues 分区，敌人线索只有 id（stone_dust、steady_stance 等）；本页照原样显示 id，不自行译名"
      }
    ]
  }
};
