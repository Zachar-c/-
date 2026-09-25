// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。
// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。
const DATA = {
  "saveCompatibilityVersion": "lab-run-v2",
  "compatibleContentVersions": [
    "lab-run-v1",
    "907a8d845d0680bba5ff4ee636e21aaf78c498c6de5ef93fa2f820f7252364e6",
    "061e49e1986a381495a2155aecf82b1e8e449a06a02d448c24150f21c4cd6c1a",
    "1c47e693695324b76dda72cce2457d09aefb757c405cef23bad01debfe0ac7f2"
  ],
  "runSeed": 101,
  "aptitude": {
    "essence_base": 10,
    "aptitude_factor": {
      "jia": 4,
      "yi": 3,
      "bing": 2,
      "ding": 1
    },
    "cultivation_factor": {
      "1": 1,
      "2": 3,
      "3": 9,
      "4": 27,
      "5": 81
    },
    "regen_pct": {
      "jia": 40,
      "yi": 30,
      "bing": 20,
      "ding": 10
    },
    "paths": [
      {
        "id": "essence_refinement",
        "name_zh": "洗髓换骨",
        "desc": "以十年寿元为引，重塑根骨，资质提升一档。",
        "cost_lifespan": 10,
        "cost_stone": 8,
        "limit_per_run": 1,
        "node_kinds": [
          "seclusion",
          "inheritance"
        ]
      }
    ]
  },
  "cultivationCosts": {
    "2": 5,
    "3": 12,
    "4": 20,
    "5": 30
  },
  "flow": {
    "difficulties": {
      "easy": {
        "label": "简单",
        "prepPerSegment": 15
      },
      "normal": {
        "label": "普通",
        "prepPerSegment": 10
      },
      "hard": {
        "label": "困难",
        "prepPerSegment": 5
      }
    },
    "stageLabels": [
      "初阶",
      "中阶",
      "高阶",
      "巅峰"
    ],
    "segmentTitles": {
      "1": "青茅山外围",
      "2": "落瘴岭",
      "3": "血蟒涧",
      "4": "万蛊窟",
      "5": "瘴脉深处"
    },
    "poolsBySegment": {
      "1": {
        "battle": [
          "beast_swarm",
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "mo_family_huntsman",
          "ridge_elite_scout"
        ],
        "boss": [
          "crag_serpent_matriarch"
        ]
      },
      "2": {
        "battle": [
          "beast_swarm",
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "mo_family_huntsman",
          "ridge_elite_scout",
          "bone_gun_marauder",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "marrow_gu_adept"
        ]
      },
      "3": {
        "battle": [
          "beast_swarm",
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "mo_family_huntsman",
          "ridge_elite_scout",
          "bone_gun_marauder",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "thunder_crown_sovereign"
        ]
      },
      "4": {
        "battle": [
          "beast_swarm",
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "mo_family_huntsman",
          "ridge_elite_scout",
          "bone_gun_marauder",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "blood_vein_bishop"
        ]
      },
      "5": {
        "battle": [
          "beast_swarm",
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "mo_family_huntsman",
          "ridge_elite_scout",
          "bone_gun_marauder",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "miasma_vein_lord"
        ]
      }
    },
    "supportGuBySegment": {
      "1": [
        "gold_atk_2_11_gu",
        "gold_atk_2_12_gu",
        "gold_atk_2_16_gu"
      ],
      "2": [
        "gold_atk_2_11_gu",
        "gold_atk_2_12_gu",
        "gold_atk_3_13_gu",
        "gold_atk_2_16_gu",
        "aptitude_gu"
      ],
      "3": [
        "gold_atk_2_11_gu",
        "gold_atk_2_12_gu",
        "gold_atk_3_13_gu",
        "gold_atk_4_14_gu",
        "gold_atk_2_16_gu",
        "aptitude_gu"
      ],
      "4": [
        "gold_atk_2_11_gu",
        "gold_atk_2_12_gu",
        "gold_atk_3_13_gu",
        "gold_atk_4_14_gu",
        "gold_atk_5_15_gu",
        "gold_atk_2_16_gu",
        "aptitude_gu"
      ],
      "5": [
        "gold_atk_2_11_gu",
        "gold_atk_2_12_gu",
        "gold_atk_3_13_gu",
        "gold_atk_4_14_gu",
        "gold_atk_5_15_gu",
        "gold_atk_2_16_gu",
        "aptitude_gu"
      ]
    },
    "supportGuIds": [
      "aptitude_gu",
      "gold_atk_2_11_gu",
      "gold_atk_2_12_gu",
      "gold_atk_3_13_gu",
      "gold_atk_4_14_gu",
      "gold_atk_5_15_gu",
      "gold_atk_2_16_gu"
    ],
    "aptitudeGuId": "aptitude_gu",
    "smallBreakthroughCosts": {
      "1": [
        2,
        3,
        4
      ],
      "2": [
        4,
        6,
        8
      ],
      "3": [
        8,
        12,
        16
      ],
      "4": [
        12,
        18,
        24
      ],
      "5": [
        20,
        30,
        40
      ]
    },
    "bigStoneCosts": {
      "2": 5,
      "3": 12,
      "4": 20,
      "5": 30
    },
    "aptitudeOrder": [
      "ding",
      "bing",
      "yi",
      "jia"
    ],
    "aptitudeGateByTargetRank": {
      "2": "bing",
      "3": "yi",
      "4": "yi",
      "5": "jia"
    },
    "sariByRank": {
      "1": "gold_atk_2_12_gu",
      "2": "gold_atk_2_11_gu",
      "3": "gold_atk_3_13_gu",
      "4": "gold_atk_4_14_gu",
      "5": "gold_atk_5_15_gu"
    },
    "rewardGuChoiceCount": 3,
    "postBattleHealPct": 30
  },
  "loot": {
    "tables": {
      "common": {
        "gu_chance_pct": 6,
        "gu_pool": {
          "weights": {
            "common": 80,
            "rare": 18,
            "epic": 2
          },
          "by_rarity": {
            "common": [
              "small_light_gu",
              "qi_atk_1_01_gu",
              "stone_shell_gu",
              "wind_atk_1_02_gu",
              "force_gu",
              "blood_droplet_gu"
            ],
            "rare": [
              "moon_glow_gu",
              "moon_ray_gu",
              "jade_skin_gu",
              "bear_strength_gu",
              "blood_bat_gu"
            ],
            "epic": [
              "moonlight_gu",
              "white_jade_gu",
              "white_boar_strength_gu"
            ]
          }
        }
      },
      "elite": {
        "gu_chance_pct": 35,
        "forced_rarity": "epic",
        "gu_pool": {
          "weights": {
            "common": 60,
            "rare": 35,
            "epic": 5
          },
          "by_rarity": {
            "common": [
              "stone_shell_gu",
              "qi_atk_1_01_gu"
            ],
            "rare": [
              "moon_ray_gu",
              "blood_bat_gu",
              "jade_skin_gu"
            ],
            "epic": [
              "moonlight_gu",
              "white_jade_gu",
              "force_atk_4_02_gu"
            ]
          }
        }
      },
      "boss": {
        "gu_chance_pct": 55,
        "gu_pool": {
          "weights": {
            "rare": 40,
            "epic": 60
          },
          "by_rarity": {
            "rare": [
              "moon_glow_gu",
              "moon_ray_gu",
              "jade_skin_gu",
              "blood_bat_gu",
              "bear_strength_gu"
            ],
            "epic": [
              "moonlight_gu",
              "white_jade_gu",
              "white_boar_strength_gu",
              "blood_farewell_gu",
              "force_atk_4_02_gu"
            ]
          },
          "note": "L0 2026-09-25 Phase 0/D3：补真实池，兑现层主给新构筑未来；禁止空池假 55%。"
        },
        "scavenge_recipe": [
          "moon_shadow_locked",
          "blood_moon_forged"
        ]
      }
    },
    "pity": {
      "threshold": 3,
      "clearing_rarities": [
        "rare",
        "epic",
        "legendary"
      ]
    },
    "pacingLayers": {
      "1": {
        "rows": [
          8,
          11
        ],
        "row_nodes": [
          2,
          6
        ],
        "entry_nodes": [
          1,
          2
        ],
        "stone_budget": 12,
        "enemy_turn": 1,
        "enemy_rank_min": 0,
        "enemy_rank_max": 1,
        "loot": {
          "weights": {
            "common": 90,
            "rare": 10,
            "epic": 0
          }
        },
        "shop_price_pct": 0,
        "shop_max_tier": 1,
        "anchors": [
          {
            "template": "yizang_ridge",
            "row": "pre_boss"
          },
          {
            "template": "refinement_hollow",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "pre_boss"
          },
          {
            "template": "ridge_black_market",
            "row": "quarter"
          }
        ],
        "pool": [
          "beast_swarm_pass",
          "iron_hide_ambush",
          "scout_crossing_raid"
        ],
        "title": "青茅山外圍",
        "category_weights": {
          "battle": 82,
          "rest": 6,
          "unknown": 9,
          "trade": 4
        }
      },
      "2": {
        "rows": [
          8,
          11
        ],
        "row_nodes": [
          2,
          6
        ],
        "entry_nodes": [
          1,
          2
        ],
        "stone_budget": 16,
        "enemy_turn": 2,
        "enemy_rank_min": 0,
        "enemy_rank_max": 2,
        "loot": {
          "weights": {
            "common": 80,
            "rare": 18,
            "epic": 2
          }
        },
        "shop_price_pct": 10,
        "shop_max_tier": 2,
        "anchors": [
          {
            "template": "ridge_black_market",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "pre_boss"
          },
          {
            "template": "refinement_hollow",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "quarter"
          }
        ],
        "pool": [
          "iron_hide_ambush",
          "scout_crossing_raid",
          "beast_swarm_pass"
        ],
        "title": "落瘴岭",
        "category_weights": {
          "battle": 80,
          "rest": 6,
          "unknown": 10,
          "trade": 5
        }
      },
      "3": {
        "rows": [
          8,
          11
        ],
        "row_nodes": [
          2,
          6
        ],
        "entry_nodes": [
          1,
          2
        ],
        "stone_budget": 22,
        "enemy_turn": 3,
        "enemy_rank_min": 1,
        "enemy_rank_max": 3,
        "loot": {
          "weights": {
            "common": 70,
            "rare": 24,
            "epic": 6
          }
        },
        "shop_price_pct": 20,
        "shop_max_tier": 3,
        "anchors": [
          {
            "template": "ridge_black_market",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "pre_boss"
          },
          {
            "template": "refinement_hollow",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "quarter"
          }
        ],
        "pool": [
          "scout_crossing_raid",
          "faction_guard_checkpoint",
          "wolf_pack_trail"
        ],
        "title": "血蟒涧",
        "category_weights": {
          "battle": 78,
          "rest": 6,
          "unknown": 11,
          "trade": 6
        }
      },
      "4": {
        "rows": [
          8,
          11
        ],
        "row_nodes": [
          2,
          6
        ],
        "entry_nodes": [
          1,
          2
        ],
        "stone_budget": 28,
        "enemy_turn": 4,
        "enemy_rank_min": 2,
        "enemy_rank_max": 4,
        "loot": {
          "weights": {
            "common": 60,
            "rare": 28,
            "epic": 12
          }
        },
        "shop_price_pct": 35,
        "shop_max_tier": 4,
        "anchors": [
          {
            "template": "ridge_black_market",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "pre_boss"
          },
          {
            "template": "refinement_hollow",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "quarter"
          }
        ],
        "pool": [
          "faction_guard_checkpoint",
          "wolf_pack_trail",
          "scout_crossing_raid"
        ],
        "title": "万蛊窟",
        "category_weights": {
          "battle": 76,
          "rest": 6,
          "unknown": 12,
          "trade": 7
        }
      },
      "5": {
        "rows": [
          8,
          11
        ],
        "row_nodes": [
          2,
          6
        ],
        "entry_nodes": [
          1,
          2
        ],
        "stone_budget": 35,
        "enemy_turn": 5,
        "enemy_rank_min": 3,
        "enemy_rank_max": 5,
        "loot": {
          "weights": {
            "common": 50,
            "rare": 30,
            "epic": 20
          }
        },
        "shop_price_pct": 50,
        "shop_max_tier": 5,
        "anchors": [
          {
            "template": "ridge_black_market",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "pre_boss"
          },
          {
            "template": "refinement_hollow",
            "row": "mid"
          },
          {
            "template": "ridge_black_market",
            "row": "quarter"
          }
        ],
        "pool": [
          "wolf_pack_trail",
          "faction_guard_checkpoint",
          "iron_hide_ambush"
        ],
        "title": "瘴脉深處",
        "category_weights": {
          "battle": 74,
          "rest": 6,
          "unknown": 13,
          "trade": 8
        }
      }
    },
    "schoolPools": {
      "light": [
        "small_light_gu",
        "moonlight_gu",
        "moon_glow_gu",
        "moon_ray_gu",
        "moon_shadow_gu",
        "vitality_grass_gu",
        "light_atk_1_01_gu",
        "light_atk_3_02_gu",
        "light_atk_5_03_gu",
        "light_atk_1_04_gu",
        "light_atk_3_05_gu",
        "light_atk_1_06_gu",
        "light_rec_3_07_gu",
        "light_rec_5_08_gu",
        "light_rec_3_09_gu",
        "light_rec_1_10_gu",
        "light_rec_5_11_gu",
        "light_rec_5_12_gu",
        "light_atk_1_13_gu",
        "light_atk_1_14_gu",
        "light_def_1_15_gu",
        "light_mov_1_16_gu",
        "light_heal_2_17_gu",
        "light_rec_2_18_gu",
        "light_log_3_19_gu",
        "light_atk_3_20_gu",
        "light_atk_4_21_gu",
        "light_def_5_22_gu",
        "light_mov_1_23_gu",
        "light_heal_2_24_gu",
        "light_rec_2_25_gu",
        "light_log_3_26_gu",
        "light_atk_3_27_gu",
        "light_atk_4_28_gu",
        "light_def_5_29_gu",
        "light_mov_1_30_gu",
        "light_heal_2_31_gu",
        "light_rec_2_32_gu",
        "light_log_3_33_gu",
        "light_atk_3_34_gu"
      ]
    },
    "school": "light"
  },
  "gu": [
    {
      "id": "moonlight_gu",
      "name": "月光蛊",
      "rank": 1,
      "rarity": "epic",
      "role": "attack",
      "buildRole": "Core",
      "buildTags": [
        "stable_hit",
        "ignoreEvasion",
        "sustain_core"
      ],
      "school": "light",
      "value": 4,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 3,
        "ignoreEvasion": true
      },
      "icon": "gu_moon",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 3,
        "ignoreEvasion": true
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-001472"
      ]
    },
    {
      "id": "small_light_gu",
      "name": "小光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": "Information",
      "buildTags": [
        "inspect",
        "support",
        "info_answer"
      ],
      "school": "light",
      "value": 3,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 2,
        "inspect": true
      },
      "icon": "gu_light",
      "combat": "reveal_hidden_bonus",
      "battleEffect": {
        "kind": "strike",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 2,
        "inspect": true
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-009708",
        "E:V1-015710"
      ]
    },
    {
      "id": "moon_glow_gu",
      "name": "月芒蛊",
      "rank": 2,
      "rarity": "rare",
      "role": "attack",
      "buildRole": "Support",
      "buildTags": [
        "suppress",
        "info_answer"
      ],
      "school": "light",
      "value": 9,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 4,
        "suppressWhenRevealed": true,
        "suppress": true
      },
      "icon": "gu_moon",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 4,
        "suppressWhenRevealed": true,
        "suppress": true
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-015710"
      ]
    },
    {
      "id": "moon_ray_gu",
      "name": "月痕蛊",
      "rank": 2,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 10,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_moon",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "bear_strength_gu",
      "name": "熊力蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "force",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "heal",
        "amount": 2
      },
      "icon": "gu_force",
      "combat": "heal_and_bleed",
      "battleEffect": {
        "kind": "heal",
        "amount": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "white_boar_strength_gu",
      "name": "白豕蛊",
      "rank": 1,
      "rarity": "epic",
      "role": "attack",
      "buildRole": "Transform",
      "buildTags": [
        "armorBreak",
        "pierce",
        "burst_setup"
      ],
      "school": "force",
      "value": 10,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 2,
        "armorBreak": 2,
        "pierce": 2
      },
      "icon": "gu_force",
      "combat": "white_boar_strength",
      "battleEffect": {
        "kind": "strike",
        "amount": 2,
        "armorBreak": 2,
        "pierce": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "jade_skin_gu",
      "name": "玉皮蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "earth",
      "value": 8,
      "cost": 1,
      "effect": {
        "kind": "shield",
        "amount": 3
      },
      "icon": "gu_water",
      "combat": "jade_skin_guard",
      "battleEffect": {
        "kind": "shield",
        "amount": 3
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-009654"
      ]
    },
    {
      "id": "stone_shell_gu",
      "name": "石皮蛊",
      "rank": 1,
      "rarity": "common",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "earth",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "shield",
        "amount": 3
      },
      "icon": "gu_earth",
      "combat": "guard_against_hit",
      "battleEffect": {
        "kind": "shield",
        "amount": 3
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "white_jade_gu",
      "name": "白玉蛊",
      "rank": 2,
      "rarity": "epic",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "earth",
      "value": 30,
      "cost": 2,
      "effect": {
        "kind": "shield",
        "amount": 5
      },
      "icon": "gu_water",
      "combat": "white_jade_form",
      "battleEffect": {
        "kind": "shield",
        "amount": 5
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-009986"
      ]
    },
    {
      "id": "blood_farewell_gu",
      "name": "爱别离",
      "rank": 2,
      "rarity": "epic",
      "role": "attack",
      "buildRole": "Finisher",
      "buildTags": [
        "burst",
        "condition",
        "pierce_follow"
      ],
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
      "icon": "gu_blood",
      "combat": "poison_and_slow",
      "battleEffect": {
        "kind": "strike",
        "amount": 4,
        "condition": {
          "type": "self_hp_below",
          "threshold": 0.5
        }
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "blood_droplet_gu",
      "name": "血滴子",
      "rank": 5,
      "rarity": "common",
      "role": "attack",
      "buildRole": "Core",
      "buildTags": [
        "stable_hit",
        "chip",
        "sustain_core"
      ],
      "school": "blood",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_blood",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "vitality_grass_gu",
      "name": "生机草蛊",
      "rank": 1,
      "rarity": "common",
      "role": "logistics",
      "buildRole": "Resource",
      "buildTags": [
        "sustain",
        "heal"
      ],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "vitality_grass_remedy",
      "battleEffect": {
        "kind": "heal",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-017128"
      ]
    },
    {
      "id": "sword_atk_1_06_gu",
      "name": "剑纹刃蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2,
        "support_school": "sword",
        "support_bonus": 1
      },
      "icon": "gu_sword",
      "combat": "sword_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2,
        "support_school": "sword",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "sword_atk_1_05_gu",
      "name": "剑纹锋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2,
        "support_school": "sword",
        "support_bonus": 1
      },
      "icon": "gu_sword",
      "combat": "sword_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2,
        "support_school": "sword",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "sword_rec_1_10_gu",
      "name": "青锋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "sword_intent",
        "amount": 1
      },
      "icon": "gu_sword",
      "combat": "sword_recon_pattern",
      "battleEffect": {
        "kind": "sword_intent",
        "amount": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "qi_atk_1_01_gu",
      "name": "硬气蛊",
      "rank": 1,
      "rarity": "common",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "qi",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "shield",
        "amount": 3
      },
      "icon": "gu_qi",
      "combat": "qi_guard_pattern",
      "battleEffect": {
        "kind": "shield",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V2-058640"
      ]
    },
    {
      "id": "qi_rec_2_14_gu",
      "name": "气纹霭蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "qi",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "inspect"
      },
      "icon": "gu_qi",
      "combat": "qi_recon_pattern",
      "battleEffect": {
        "kind": "inspect"
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "school_derived",
      "canonAnchors": []
    },
    {
      "id": "wood_atk_1_05_gu",
      "name": "青藤蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "wood",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "wood_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-016788"
      ]
    },
    {
      "id": "water_atk_1_08_gu",
      "name": "浪蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "water",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_water",
      "combat": "water_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "school_derived",
      "canonAnchors": []
    },
    {
      "id": "moon_shadow_gu",
      "name": "月影蛊",
      "rank": 4,
      "rarity": "rare",
      "role": "movement",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 16,
      "cost": 3,
      "effect": {
        "kind": "shift",
        "amount": 1
      },
      "icon": "gu_moon",
      "combat": "shift_position",
      "battleEffect": {
        "kind": "shift",
        "amount": 1
      },
      "trueQiCost": 3,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V1-002648",
        "E:V1-026794"
      ]
    },
    {
      "id": "blood_heal_2_23_gu",
      "name": "血针蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "blood",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_blood",
      "combat": "blood_healing_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "school_derived",
      "canonAnchors": []
    },
    {
      "id": "gold_atk_2_11_gu",
      "name": "赤铁舍利蛊",
      "rank": 2,
      "rarity": "common",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "gold_atk_2_12_gu",
      "name": "青铜舍利蛊",
      "rank": 1,
      "rarity": "common",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "gold_atk_3_13_gu",
      "name": "白银舍利蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "gold_atk_4_14_gu",
      "name": "黄金舍利蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 12,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "gold_atk_5_15_gu",
      "name": "紫晶舍利蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "gold_atk_2_16_gu",
      "name": "舍利蛊",
      "rank": 2,
      "rarity": "common",
      "role": "support",
      "buildRole": null,
      "buildTags": [],
      "school": "gold",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "breakthrough_material"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "bone_atk_1_08_gu",
      "name": "骨蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "bone",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "bone_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "school_derived",
      "canonAnchors": []
    },
    {
      "id": "human_atk_1_01_gu",
      "name": "自己蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "human",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "inspect"
      },
      "icon": "gu_qi",
      "combat": "human_insight_pattern",
      "battleEffect": {
        "kind": "inspect"
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": "canon_driven_v1",
      "canonAnchors": [
        "E:V3-120396",
        "E:V3-120404"
      ]
    },
    {
      "id": "sword_atk_2_12_gu",
      "name": "古剑蛊",
      "rank": 2,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 3
      },
      "icon": "gu_sword",
      "combat": "sword_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "sword_def_3_14_gu",
      "name": "软剑蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "shield",
        "amount": 5
      },
      "icon": "gu_sword",
      "combat": "sword_defense_pattern",
      "battleEffect": {
        "kind": "shield",
        "amount": 5
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "sword_heal_4_16_gu",
      "name": "双剑蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 12,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 5
      },
      "icon": "gu_sword",
      "combat": "sword_healing_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 5
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "sword_atk_5_02_gu",
      "name": "飞剑蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "sword",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 6
      },
      "icon": "gu_sword",
      "combat": "sword_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 6
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "blood_atk_5_02_gu",
      "name": "血手印蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "blood",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 8
      },
      "icon": "gu_blood",
      "combat": "blood_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 8
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 2,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "fire_atk_2_01_gu",
      "name": "鬼火蛊",
      "rank": 2,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "fire",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 3,
        "delay": {
          "turns": 1
        }
      },
      "icon": "gu_fire",
      "combat": "fire_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 3,
        "delay": {
          "turns": 1
        }
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "water_atk_3_05_gu",
      "name": "雨蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "water",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2,
        "consume_status": {
          "name": "marked",
          "per_stack": 1
        }
      },
      "icon": "gu_water",
      "combat": "water_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2,
        "consume_status": {
          "name": "marked",
          "per_stack": 1
        }
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "wisdom_rec_1_20_gu",
      "name": "灵感蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "wisdom",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "wisdom",
        "support_bonus": 1
      },
      "icon": "gu_qi",
      "combat": "wisdom_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "wisdom",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "wisdom_atk_3_13_gu",
      "name": "智才华蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "wisdom",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "weaken_intent",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "wisdom_attack_pattern",
      "battleEffect": {
        "kind": "weaken_intent",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "wind_atk_1_02_gu",
      "name": "狂风蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "wind",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_wind",
      "combat": "wind_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "force_gu",
      "name": "力量蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "force",
      "value": 5,
      "cost": 1,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_force",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "blood_bat_gu",
      "name": "刀翅血蝠蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "blood",
      "value": 6,
      "cost": 1,
      "effect": {
        "kind": "heal_and_strike",
        "heal": 1,
        "amount": 1
      },
      "icon": "gu_blood",
      "combat": "drain_strike",
      "battleEffect": {
        "kind": "heal_and_strike",
        "heal": 1,
        "amount": 1
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "force_atk_4_02_gu",
      "name": "苦力蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "force",
      "value": 12,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 5
      },
      "icon": "gu_force",
      "combat": "force_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 5
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_1_01_gu",
      "name": "月旋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_3_02_gu",
      "name": "邀月蛊",
      "rank": 2,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_5_03_gu",
      "name": "太光蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 6
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 6
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_1_04_gu",
      "name": "光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_3_05_gu",
      "name": "月蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_1_06_gu",
      "name": "星光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_3_07_gu",
      "name": "星芽蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_5_08_gu",
      "name": "星河蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_3_09_gu",
      "name": "星萤蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_1_10_gu",
      "name": "明星蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_5_11_gu",
      "name": "星眸蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_5_12_gu",
      "name": "星念蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_1_13_gu",
      "name": "辉蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_1_14_gu",
      "name": "曜蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_def_1_15_gu",
      "name": "曦蛊",
      "rank": 1,
      "rarity": "common",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "shield",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_defense_pattern",
      "battleEffect": {
        "kind": "shield",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_mov_1_16_gu",
      "name": "旭蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "shift",
        "amount": 1
      },
      "icon": "gu_light",
      "combat": "light_movement_pattern",
      "battleEffect": {
        "kind": "shift",
        "amount": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_heal_2_17_gu",
      "name": "晨蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_healing_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_2_18_gu",
      "name": "晞蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_log_3_19_gu",
      "name": "晶蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_logistics_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_3_20_gu",
      "name": "莹蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_4_21_gu",
      "name": "皎蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 12,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 5
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 5
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_def_5_22_gu",
      "name": "皓蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "shield",
        "amount": 7
      },
      "icon": "gu_light",
      "combat": "light_defense_pattern",
      "battleEffect": {
        "kind": "shield",
        "amount": 7
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_mov_1_23_gu",
      "name": "朗蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "shift",
        "amount": 1
      },
      "icon": "gu_light",
      "combat": "light_movement_pattern",
      "battleEffect": {
        "kind": "shift",
        "amount": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_heal_2_24_gu",
      "name": "焕蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_healing_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_2_25_gu",
      "name": "熠蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_log_3_26_gu",
      "name": "熹蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_logistics_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_3_27_gu",
      "name": "闪蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_4_28_gu",
      "name": "耀蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 12,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 5
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 5
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_def_5_29_gu",
      "name": "流光蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "defense",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "shield",
        "amount": 7
      },
      "icon": "gu_light",
      "combat": "light_defense_pattern",
      "battleEffect": {
        "kind": "shield",
        "amount": 7
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_mov_1_30_gu",
      "name": "折光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "shift",
        "amount": 1
      },
      "icon": "gu_light",
      "combat": "light_movement_pattern",
      "battleEffect": {
        "kind": "shift",
        "amount": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_heal_2_31_gu",
      "name": "烛光蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_healing_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_rec_2_32_gu",
      "name": "萤光蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "icon": "gu_light",
      "combat": "light_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_log_3_33_gu",
      "name": "光辉蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "heal",
        "amount": 3
      },
      "icon": "gu_light",
      "combat": "light_logistics_pattern",
      "battleEffect": {
        "kind": "heal",
        "amount": 3
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "light_atk_3_34_gu",
      "name": "光曜蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
      "buildRole": null,
      "buildTags": [],
      "school": "light",
      "value": 8,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_light",
      "combat": "light_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false,
      "sourceClass": null,
      "canonAnchors": []
    },
    {
      "id": "aptitude_gu",
      "name": "资质蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "support",
      "school": "human",
      "value": 20,
      "cost": 0,
      "effect": {
        "kind": "aptitude_up"
      },
      "icon": "gu_qi",
      "combat": "",
      "battleEffect": null,
      "trueQiCost": 0,
      "thoughtCost": 0,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": true
    }
  ],
  "recipes": [
    {
      "id": "moon_ray_forged",
      "kind": "fixed",
      "inputs": [
        "moonlight_gu",
        "small_light_gu"
      ],
      "output": "moon_ray_gu",
      "stoneCost": 0,
      "source": "蛊真人-clean.txt 17140-17155：月光蛊多晋升路线之一（月光蛊+小光蛊；输出月痕蛊，语料名缺，策展补名）；L0 Phase 5 兽骨=爆发支配方钥匙",
      "successRollMax": 100,
      "forkId": "fork_moonlight_small",
      "branchLabel": "炼向月痕·爆发",
      "branchAxis": "burst",
      "closes": [
        "kit_info_suppress",
        "moon_glow_gu"
      ],
      "delays": [
        "kit_info_suppress"
      ]
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
      "source": "蛊真人-clean.txt 17140-17155：月光蛊晋升路线之一（月光蛊x1+小光蛊x1→月芒蛊）；L0 Phase 5 月露=信息支配方钥匙",
      "successRollMax": 100,
      "forkId": "fork_moonlight_small",
      "branchLabel": "炼向月芒·信息压制",
      "branchAxis": "info",
      "closes": [
        "moon_ray_gu",
        "kit_pierce_burst"
      ],
      "delays": [
        "kit_pierce_burst"
      ]
    },
    {
      "id": "white_jade_basic",
      "kind": "fixed",
      "inputs": [
        "jade_skin_gu",
        "white_boar_strength_gu"
      ],
      "output": "white_jade_gu",
      "stoneCost": 15,
      "source": "蛊真人-clean.txt 15860-15895：白玉蛊=白豕蛊+玉皮蛊；L0 Phase 5 兽血=防御支配方钥匙",
      "successRollMax": 100,
      "forkId": "fork_jade_boar",
      "branchLabel": "炼向白玉·防御",
      "branchAxis": "armor",
      "closes": [
        "bear_strength_gu",
        "kit_stable_sustain"
      ],
      "delays": [
        "kit_pierce_burst"
      ]
    },
    {
      "id": "bear_split",
      "kind": "fixed",
      "inputs": [
        "jade_skin_gu",
        "white_boar_strength_gu"
      ],
      "output": "bear_strength_gu",
      "stoneCost": 8,
      "source": "L0 Phase 4/5 分支：玉皮+白豕另一去向；毒囊=持续支配方钥匙",
      "successRollMax": 100,
      "forkId": "fork_jade_boar",
      "branchLabel": "炼向熊力·持续",
      "branchAxis": "sustain",
      "closes": [
        "white_jade_gu"
      ],
      "delays": [
        "kit_pierce_burst"
      ]
    }
  ],
  "killMoves": [
    {
      "id": "km_light_converge",
      "origin": "original_game_content",
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
      "origin": "adaptation",
      "origin_ref": "L130776",
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
      "origin": "original_game_content",
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
    },
    {
      "id": "km_sword_double_edge_1",
      "origin": "original_game_content",
      "label": "双锋引·一转",
      "tag": "sword",
      "recipe": [
        "sword_atk_1_05_gu",
        "sword_atk_1_06_gu"
      ],
      "true_qi_cost": 3,
      "thought_cost": 1,
      "life_cost": 0,
      "damage": 0,
      "effect": {
        "kind": "strike",
        "amount": 4
      }
    },
    {
      "id": "km_sword_mark_seek_1",
      "origin": "canon",
      "origin_ref": "L194470",
      "label": "剑痕索命·一转",
      "tag": "sword",
      "recipe": [
        "sword_atk_1_05_gu",
        "sword_rec_1_10_gu"
      ],
      "true_qi_cost": 3,
      "thought_cost": 1,
      "life_cost": 0,
      "damage": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
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
      "tier": "common",
      "problemAxis": "info",
      "problemLabel": "信息/反制",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "bone_atk_1_08_gu",
        "stone_shell_gu"
      ],
      "intent": {
        "id": "stone_palm",
        "label": "掌势蓄而未发",
        "damage": 2,
        "speed": 1,
        "guRefs": [
          "bone_atk_1_08_gu"
        ]
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
      "tier": "common",
      "problemAxis": "evasion",
      "problemLabel": "高速/闪避",
      "armorValue": null,
      "evasionBreakpoint": 2,
      "attackSource": "innate",
      "guRefs": [],
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
      "name": "黑皮野猪",
      "rank": 2,
      "hp": 5,
      "theme": "beast",
      "tier": "common",
      "problemAxis": "armor",
      "problemLabel": "重甲/防御",
      "armorValue": 2,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
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
      "tier": "elite",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
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
      "id": "crag_serpent_matriarch",
      "name": "崖蟒主母",
      "rank": 4,
      "hp": 15,
      "theme": "beast",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "crush_coil",
        "label": "绞缠碾压",
        "damage": 3,
        "speed": 1
      },
      "portrait": "enemy_crag_serpent_matriarch",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "coiled_shadows",
        "scraped_scale"
      ],
      "reactions": []
    },
    {
      "id": "marrow_gu_adept",
      "name": "蚀骨蛊师",
      "rank": 4,
      "hp": 16,
      "theme": "cultivator",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "water_atk_3_05_gu",
        "bone_atk_1_08_gu"
      ],
      "intent": {
        "id": "marrow_lance",
        "label": "蚀骨骨矛",
        "damage": 3,
        "speed": 2,
        "guRefs": [
          "water_atk_3_05_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "bone_charms",
        "burnt_incense"
      ],
      "reactions": [
        {
          "id": "bone_thorn_shield",
          "clue": "bone_charms",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "骨棘反甲"
        }
      ]
    },
    {
      "id": "ridge_elite_scout",
      "name": "山脊悍客",
      "rank": 2,
      "hp": 6,
      "theme": "faction",
      "tier": "elite",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "fire_atk_2_01_gu",
        "qi_rec_2_14_gu"
      ],
      "intent": {
        "id": "swift_crossbow",
        "label": "弩箭上弦",
        "damage": 3,
        "speed": 3,
        "guRefs": [
          "fire_atk_2_01_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "high_ground",
        "steady_breath"
      ],
      "reactions": [
        {
          "id": "elusive_step",
          "clue": "high_ground",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "高处闪避"
        }
      ]
    },
    {
      "id": "demon_path_adept",
      "name": "魔道蛊师",
      "rank": 3,
      "hp": 7,
      "theme": "cultivator",
      "tier": "elite",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "blood_heal_2_23_gu"
      ],
      "intent": {
        "id": "soul_gnaw",
        "label": "噬魂魔功",
        "kind": "soul_drain",
        "soul_drain": 1,
        "damage": 0,
        "speed": 2
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "bloody_miasma",
        "green_pupils"
      ],
      "reactions": [
        {
          "id": "blood_shroud",
          "clue": "bloody_miasma",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "血气护体"
        }
      ]
    },
    {
      "id": "thunder_crown_sovereign",
      "name": "雷冠狼王",
      "rank": 5,
      "hp": 18,
      "theme": "beast",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
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
      "id": "miasma_vein_lord",
      "name": "瘴脉蛊主",
      "rank": 3,
      "hp": 14,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "water_atk_1_08_gu",
        "wood_atk_1_05_gu"
      ],
      "intent": {
        "id": "miasma_burst",
        "label": "瘴气喷涌",
        "damage": 2,
        "speed": 1,
        "guRefs": [
          "water_atk_1_08_gu"
        ]
      },
      "portrait": "web_boss_miasma_vein_lord",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "miasma_burst",
              "label": "瘴气喷涌",
              "damage": 2,
              "speed": 1,
              "cooldown": 2,
              "guRefs": [
                "water_atk_1_08_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "corrosive_mist",
              "clue": "wilting_aura",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "蚀气反激"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "miasma_burst",
              "label": "瘴气喷涌",
              "damage": 2,
              "speed": 1,
              "cooldown": 2,
              "guRefs": [
                "water_atk_1_08_gu"
              ]
            },
            {
              "id": "essence_scorch",
              "label": "蚀脉扰元",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "corrosive_mist",
              "clue": "wilting_aura",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "蚀气反激"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "wilting_aura",
        "slow_gaits"
      ],
      "reactions": [
        {
          "id": "corrosive_mist",
          "clue": "wilting_aura",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "蚀气反激"
        }
      ]
    },
    {
      "id": "blood_vein_bishop",
      "name": "血络主教",
      "rank": 5,
      "hp": 20,
      "theme": "cultivator",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "blood_droplet_gu",
        "blood_heal_2_23_gu"
      ],
      "intent": {
        "id": "vein_whip",
        "label": "血络鞭挞",
        "damage": 4,
        "speed": 3,
        "cooldown": 1,
        "guRefs": [
          "blood_droplet_gu"
        ]
      },
      "portrait": "web_boss_blood_vein_bishop",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "vein_whip",
              "label": "血络鞭挞",
              "damage": 4,
              "speed": 3,
              "cooldown": 1,
              "guRefs": [
                "blood_droplet_gu"
              ]
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
              "cooldown": 1,
              "guRefs": [
                "blood_droplet_gu"
              ]
            },
            {
              "id": "crimson_feast",
              "label": "猩红盛餐",
              "damage": 5,
              "speed": 2,
              "cooldown": 2,
              "attackSource": "innate"
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
    },
    {
      "id": "clan_patriarch",
      "name": "族长",
      "rank": 5,
      "hp": 19,
      "theme": "faction",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "moonlight_gu",
        "sword_atk_1_06_gu",
        "white_jade_gu",
        "stone_shell_gu"
      ],
      "intent": {
        "id": "clan_wrath",
        "label": "一族之威",
        "damage": 4,
        "speed": 2,
        "cooldown": 1,
        "guRefs": [
          "moonlight_gu",
          "sword_atk_1_06_gu"
        ]
      },
      "portrait": "web_boss_clan_patriarch",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "clan_wrath",
              "label": "一族之威",
              "damage": 4,
              "speed": 2,
              "cooldown": 1,
              "guRefs": [
                "moonlight_gu",
                "sword_atk_1_06_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "ancestral_tablet",
              "clue": "solemn_robe",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "祖宗牌位"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "clan_wrath",
              "label": "一族之威",
              "damage": 4,
              "speed": 2,
              "cooldown": 1,
              "guRefs": [
                "moonlight_gu",
                "sword_atk_1_06_gu"
              ]
            },
            {
              "id": "clan_muster",
              "label": "家族征召",
              "kind": "seal",
              "seal_turns": 2,
              "damage": 0,
              "speed": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "ancestral_tablet",
              "clue": "solemn_robe",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "祖宗牌位"
            }
          ]
        }
      ],
      "phasesNote": null,
      "clues": [
        "frosted_temples",
        "solemn_robe"
      ],
      "reactions": [
        {
          "id": "ancestral_tablet",
          "clue": "solemn_robe",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "祖宗牌位"
        }
      ]
    },
    {
      "id": "blue_fur_jiangshi",
      "name": "蓝毛僵尸",
      "rank": 5,
      "hp": 20,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "corpse_tide",
        "label": "尸潮掩杀",
        "damage": 4,
        "speed": 2,
        "cooldown": 1
      },
      "portrait": "web_boss_blue_fur_jiangshi",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "corpse_tide",
              "label": "尸潮掩杀",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            }
          ],
          "reactions": [
            {
              "id": "corpse_barrier",
              "clue": "corpse_army",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "尸群为障"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "corpse_tide",
              "label": "尸潮掩杀",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            },
            {
              "id": "raise_corpse",
              "label": "起尸困敌",
              "kind": "seal",
              "seal_turns": 2,
              "damage": 0,
              "speed": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "corpse_barrier",
              "clue": "corpse_army",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "尸群为障"
            }
          ]
        }
      ],
      "phasesNote": null,
      "clues": [
        "blue_fur",
        "corpse_army"
      ],
      "reactions": [
        {
          "id": "corpse_barrier",
          "clue": "corpse_army",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "尸群为障"
        }
      ]
    },
    {
      "id": "faction_guard",
      "name": "势力守卫",
      "rank": 2,
      "hp": 6,
      "theme": "faction",
      "tier": "elite",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "sword_atk_2_12_gu",
        "jade_skin_gu"
      ],
      "intent": {
        "id": "shield_bash",
        "label": "盾墙冲撞",
        "damage": 3,
        "speed": 3,
        "guRefs": [
          "sword_atk_2_12_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "locked_shieldwall",
        "even_line"
      ],
      "reactions": []
    },
    {
      "id": "beast_swarm",
      "name": "兽群",
      "rank": 1,
      "hp": 4,
      "theme": "beast",
      "tier": "common",
      "problemAxis": null,
      "problemLabel": null,
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "swarm_bite",
        "label": "蜂群撕缠",
        "damage": 2,
        "speed": 1
      },
      "portrait": "enemy_beast_swarm",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "droning_wings",
        "swarming_shadows"
      ],
      "reactions": []
    },
    {
      "id": "mo_family_huntsman",
      "name": "漠家猎手",
      "rank": 2,
      "hp": 5,
      "theme": "faction",
      "tier": "elite",
      "problemAxis": "info",
      "problemLabel": "情报/先手",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "bone_atk_1_08_gu"
      ],
      "intent": {
        "id": "mo_hunt_fork",
        "label": "漠家猎叉",
        "damage": 2,
        "speed": 1,
        "guRefs": [
          "bone_atk_1_08_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "hound_whistle",
        "crossbow_glint"
      ],
      "reactions": [
        {
          "id": "mo_crossguard",
          "clue": "crossbow_glint",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "弩盾斜架"
        }
      ]
    },
    {
      "id": "jiangshi_handler_boss",
      "name": "僵王传人",
      "rank": 3,
      "hp": 14,
      "theme": "faction",
      "tier": "boss",
      "problemAxis": "info",
      "problemLabel": "破绽/读招",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "bone_atk_1_08_gu"
      ],
      "intent": {
        "id": "corpse_command",
        "label": "驱僵号令",
        "damage": 2,
        "speed": 1,
        "guRefs": [
          "bone_atk_1_08_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "corpse_command",
              "label": "驱僵号令",
              "damage": 2,
              "speed": 1,
              "cooldown": 2,
              "guRefs": [
                "bone_atk_1_08_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "talisman_guard",
              "clue": "paper_talismans",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "黄符护身"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "corpse_command",
              "label": "驱僵号令",
              "damage": 2,
              "speed": 1,
              "cooldown": 2,
              "guRefs": [
                "bone_atk_1_08_gu"
              ]
            },
            {
              "id": "talisman_ignite",
              "label": "掷符引火",
              "damage": 3,
              "speed": 2,
              "cooldown": 2,
              "attackSource": "innate"
            }
          ],
          "reactions": [
            {
              "id": "talisman_guard",
              "clue": "paper_talismans",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "黄符护身"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "corpse_bells",
        "paper_talismans"
      ],
      "reactions": [
        {
          "id": "talisman_guard",
          "clue": "paper_talismans",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "黄符护身"
        }
      ]
    },
    {
      "id": "blood_grave_thrall",
      "name": "血湖血傀",
      "rank": 3,
      "hp": 8,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": "info",
      "problemLabel": "破绽/读招",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "blood_claw",
        "label": "血爪撕扯",
        "damage": 2,
        "speed": 1
      },
      "portrait": "enemy_toad",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "blood_claw",
              "label": "血爪撕扯",
              "damage": 2,
              "speed": 1,
              "cooldown": 1
            }
          ],
          "reactions": [
            {
              "id": "blood_tendril_bind",
              "clue": "crimson_veins",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "血丝缠缚"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "blood_claw",
              "label": "血爪撕扯",
              "damage": 2,
              "speed": 1,
              "cooldown": 1
            },
            {
              "id": "blood_seethe",
              "label": "血沸蚀元",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "blood_tendril_bind",
              "clue": "crimson_veins",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "血丝缠缚"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "crimson_veins",
        "grave_fog"
      ],
      "reactions": [
        {
          "id": "blood_tendril_bind",
          "clue": "crimson_veins",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "血丝缠缚"
        }
      ]
    },
    {
      "id": "bone_gun_marauder",
      "name": "骨枪马贼",
      "rank": 3,
      "hp": 7,
      "theme": "cultivator",
      "tier": "elite",
      "problemAxis": "evasion",
      "problemLabel": "机动/命中",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "water_atk_3_05_gu"
      ],
      "intent": {
        "id": "bone_spear_barrage",
        "label": "骨枪连掷",
        "damage": 3,
        "speed": 2,
        "guRefs": [
          "water_atk_3_05_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "bone_powder_trail",
        "throwing_arc"
      ],
      "reactions": [
        {
          "id": "bone_tether",
          "clue": "throwing_arc",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "缠骨锁足"
        }
      ]
    },
    {
      "id": "slave_path_overseer",
      "name": "奴道监工",
      "rank": 4,
      "hp": 12,
      "theme": "faction",
      "tier": "boss",
      "problemAxis": "info",
      "problemLabel": "破绽/读招",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "moon_ray_gu"
      ],
      "intent": {
        "id": "overseer_whip",
        "label": "鞭笞驱兽",
        "damage": 3,
        "speed": 1,
        "guRefs": [
          "moon_ray_gu"
        ]
      },
      "portrait": "enemy_sanxiu",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "overseer_whip",
              "label": "鞭笞驱兽",
              "damage": 3,
              "speed": 1,
              "cooldown": 1,
              "guRefs": [
                "moon_ray_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "iron_barricade",
              "clue": "chained_beasts",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "铁栏横挡"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "overseer_whip",
              "label": "鞭笞驱兽",
              "damage": 3,
              "speed": 1,
              "cooldown": 1,
              "guRefs": [
                "moon_ray_gu"
              ]
            },
            {
              "id": "slave_seal_burn",
              "label": "奴印蚀元",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "iron_barricade",
              "clue": "chained_beasts",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "铁栏横挡"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "whip_crack",
        "chained_beasts"
      ],
      "reactions": [
        {
          "id": "iron_barricade",
          "clue": "chained_beasts",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "铁栏横挡"
        }
      ]
    },
    {
      "id": "soul_path_reaper",
      "name": "魂道摄魂人",
      "rank": 5,
      "hp": 16,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": "info",
      "problemLabel": "破绽/读招",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "gu",
      "guRefs": [
        "blood_atk_5_02_gu"
      ],
      "intent": {
        "id": "soul_bell",
        "label": "摄魂铃荡",
        "damage": 4,
        "speed": 2,
        "guRefs": [
          "blood_atk_5_02_gu"
        ]
      },
      "portrait": "enemy_toad",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "soul_bell",
              "label": "摄魂铃荡",
              "damage": 4,
              "speed": 2,
              "cooldown": 2,
              "guRefs": [
                "blood_atk_5_02_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "soul_chain",
              "clue": "soul_lantern_flicker",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "锁魂索"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "soul_bell",
              "label": "摄魂铃荡",
              "damage": 4,
              "speed": 2,
              "cooldown": 2,
              "guRefs": [
                "blood_atk_5_02_gu"
              ]
            },
            {
              "id": "soul_burst",
              "label": "魂爆灭识",
              "damage": 4,
              "speed": 1,
              "essence_burn": 2,
              "cooldown": 2,
              "guRefs": [
                "blood_atk_5_02_gu"
              ]
            }
          ],
          "reactions": [
            {
              "id": "soul_chain",
              "clue": "soul_lantern_flicker",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "锁魂索"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "soul_lantern_flicker",
        "whisper_wind"
      ],
      "reactions": [
        {
          "id": "soul_chain",
          "clue": "soul_lantern_flicker",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "锁魂索"
        }
      ]
    },
    {
      "id": "blood_god_larva",
      "name": "血神子",
      "rank": 5,
      "hp": 18,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": "armor",
      "problemLabel": "护体/磨血",
      "armorValue": 1,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "blood_rain",
        "label": "血雨漫天",
        "damage": 4,
        "speed": 1
      },
      "portrait": "enemy_toad",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "blood_rain",
              "label": "血雨漫天",
              "damage": 4,
              "speed": 1,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "blood_film",
              "clue": "blood_moon_trace",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "血膜凝甲"
            },
            {
              "id": "blood_tendon_bind",
              "clue": "splitting_swarm",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "血丝缚肢"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "blood_rain",
              "label": "血雨漫天",
              "damage": 4,
              "speed": 1,
              "cooldown": 2
            },
            {
              "id": "split_devour",
              "label": "裂体分噬",
              "damage": 4,
              "speed": 1,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "blood_film",
              "clue": "blood_moon_trace",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "血膜凝甲"
            },
            {
              "id": "blood_tendon_bind",
              "clue": "splitting_swarm",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "血丝缚肢"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "blood_moon_trace",
        "splitting_swarm"
      ],
      "reactions": [
        {
          "id": "blood_film",
          "clue": "blood_moon_trace",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "血膜凝甲"
        },
        {
          "id": "blood_tendon_bind",
          "clue": "splitting_swarm",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "血丝缚肢"
        }
      ]
    },
    {
      "id": "dream_wraith_echo",
      "name": "梦境残念",
      "rank": 5,
      "hp": 15,
      "theme": "anomaly",
      "tier": "boss",
      "problemAxis": "info",
      "problemLabel": "情报/先手",
      "armorValue": null,
      "evasionBreakpoint": null,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "nightmare_whisper",
        "label": "梦魇低语",
        "damage": 0,
        "speed": 2,
        "essence_burn": 2
      },
      "portrait": "enemy_toad",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "nightmare_whisper",
              "label": "梦魇低语",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "mirror_flower",
              "clue": "mirage_step",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "镜花障"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "nightmare_whisper",
              "label": "梦魇低语",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            },
            {
              "id": "phantom_pain",
              "label": "幻痛反噬",
              "damage": 4,
              "speed": 1,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "mirror_flower",
              "clue": "mirage_step",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "镜花障"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "mirage_step",
        "echoed_voice"
      ],
      "reactions": [
        {
          "id": "mirror_flower",
          "clue": "mirage_step",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "镜花障"
        }
      ]
    },
    {
      "id": "thousand_li_earth_tarantula",
      "name": "千里地狼蛛",
      "rank": 5,
      "hp": 20,
      "theme": "beast",
      "tier": "boss",
      "problemAxis": "evasion",
      "problemLabel": "机动/命中",
      "armorValue": null,
      "evasionBreakpoint": 2,
      "attackSource": "innate",
      "guRefs": [],
      "intent": {
        "id": "burrow_ambush",
        "label": "地遁突袭",
        "damage": 4,
        "speed": 2
      },
      "portrait": "enemy_beast_swarm",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "burrow_ambush",
              "label": "地遁突袭",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            }
          ],
          "reactions": [
            {
              "id": "spider_carapace",
              "clue": "sand_breath",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "蛛甲横障"
            },
            {
              "id": "web_binding",
              "clue": "tremor_lines",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "蛛网黏缚"
            }
          ]
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "burrow_ambush",
              "label": "地遁突袭",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
            },
            {
              "id": "web_seal",
              "label": "蛛网封穴",
              "damage": 0,
              "speed": 2,
              "essence_burn": 2,
              "cooldown": 2
            }
          ],
          "reactions": [
            {
              "id": "spider_carapace",
              "clue": "sand_breath",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "guarded",
              "label": "蛛甲横障"
            },
            {
              "id": "web_binding",
              "clue": "tremor_lines",
              "window": "before_damage",
              "trigger": "direct_strike",
              "counter_status": "bound",
              "label": "蛛网黏缚"
            }
          ]
        }
      ],
      "phasesNote": "cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.",
      "clues": [
        "tremor_lines",
        "sand_breath"
      ],
      "reactions": [
        {
          "id": "spider_carapace",
          "clue": "sand_breath",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "guarded",
          "label": "蛛甲横障"
        },
        {
          "id": "web_binding",
          "clue": "tremor_lines",
          "window": "before_damage",
          "trigger": "direct_strike",
          "counter_status": "bound",
          "label": "蛛网黏缚"
        }
      ]
    }
  ],
  "nodes": [
    {
      "id": "neutral_wanderer",
      "name": "中立散修",
      "stage": "one",
      "type": "contact",
      "summary": "散修拦在岔路前，袖口沾着新土；他先打量你的蛊囊，再问你要走哪条道。",
      "choices": [
        "negotiate",
        "deceive",
        "fight",
        "retreat"
      ],
      "nextIds": [
        "beast_swarm_pass",
        "moonlit_trail"
      ],
      "enemyKind": "neutral_stone_wanderer",
      "enemyKinds": null,
      "enemyTheme": "neutral",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_caravan",
      "name": "山脊商队",
      "stage": "one",
      "type": "caravan",
      "summary": "商队在山脊支起临时货棚。管事认得附近的路，也记得每一笔人情。",
      "choices": [
        "buy",
        "sell",
        "exchange",
        "leave"
      ],
      "nextIds": [
        "refinement_hollow",
        "cultivation_spring",
        "village_short_work"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "caravan_steward",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "refinement_hollow",
      "name": "炼蛊石穴",
      "stage": "one",
      "type": "refinement",
      "summary": "石穴里的炉火还温着。风从裂缝灌入，炉口却留着一批未收的蛊材。",
      "choices": [
        "refine",
        "leave"
      ],
      "nextIds": [
        "toxic_mountain_path"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "cultivation_spring",
      "name": "修行山泉",
      "stage": "one",
      "type": "cultivation",
      "summary": "山泉灵气平稳，正好静修或冲击二转；泉眼旁的脚印还没被水冲散。",
      "choices": [
        "cultivate",
        "meditate",
        "leave"
      ],
      "nextIds": [
        "flooded_cave"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "stage_one_ledger",
      "name": "第一阶段养蛊总账",
      "stage": "one",
      "type": "ledger",
      "summary": "这一层的养蛊账目已到期。结清、卖蛊或欠债都能过关，账却不会自己消失。",
      "choices": [
        "settle_feeding",
        "sell",
        "exchange",
        "refine",
        "accept_debt"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "toxic_mountain_path",
      "name": "毒瘴山道",
      "stage": "one",
      "type": "hazard",
      "summary": "毒瘴沿坡压下，林间几道脚印在雾中断开。先探路稳妥，硬闯省事，也会留下破绽。",
      "choices": [
        "scout",
        "cross",
        "withdraw"
      ],
      "nextIds": [
        "ridge_market"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "flooded_cave",
      "name": "积水石窟",
      "stage": "one",
      "type": "hazard",
      "summary": "暗河倒灌进石窟，水面漂着几片新折的月蓝花瓣；洞顶深处传来蛊翅声。",
      "choices": [
        "scout",
        "cross",
        "withdraw"
      ],
      "nextIds": [
        "echo_cave"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "black_mud_marsh",
      "name": "黑泥沼地",
      "stage": "three",
      "type": "hazard",
      "summary": "黑泥漫过旧木栈道，踏错一步便会困在淤地；远处几根立桩仍指着干路。",
      "choices": [
        "scout",
        "cross",
        "withdraw"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "moonlit_trail",
      "name": "月下小径",
      "stage": "one",
      "type": "inheritance",
      "summary": "月下石阶只剩半截，沿途手记彼此矛盾。蛊方线索在前，后来者也在前。",
      "choices": [
        "inspect",
        "claim",
        "leave"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "blood_moss_grove",
      "name": "血苔林",
      "stage": "two",
      "type": "wild_gu",
      "summary": "血苔在湿石上泛红，采药人留下的布条还挂在枝间；林里既有药材，也有兽迹。",
      "choices": [
        "harvest",
        "trade",
        "leave"
      ],
      "nextIds": [
        "body_imprint_ritual",
        "jiangshi_bell_road"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "mist_shrine",
      "name": "雾隐祠",
      "stage": "four",
      "type": "inheritance",
      "summary": "山雾封住残祠，门槛上的封痕已被人动过。查验、备好退路，或趁封痕未破时离开。",
      "choices": [
        "inspect",
        "claim",
        "prepare",
        "leave"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "village_short_work",
      "name": "山村短工",
      "stage": "one",
      "type": "market",
      "summary": "寨中缺人守夜，村民肯拿元石换一晚值守；药师也愿用消息回报旧人情。",
      "choices": [
        "work",
        "trade",
        "leave"
      ],
      "nextIds": [
        "ridge_black_market",
        "body_imprint_ritual"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "wandering_healer",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_black_market",
      "name": "山脊黑市",
      "stage": "two",
      "type": "shop",
      "summary": "黑市藏在两道山梁之间，货物没有来路，摊主也不问。看中的东西，得拿元石换。",
      "choices": [],
      "nextIds": [
        "stage_one_ledger",
        "bone_gun_ambush"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "ridge_extortionist",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_1",
      "name": "青茅外隘·关底",
      "stage": "one",
      "type": "combat",
      "summary": "青茅外隘的最后一关被强敌把守，岩壁上的爪痕与蛊痕交叠。想进下一层，先摸清守关者的路数。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "crag_serpent_matriarch",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept",
        "slave_path_overseer"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 1,
      "layer": 1
    },
    {
      "id": "layer_boss_stand_2",
      "name": "落瘴岭·关底",
      "stage": "two",
      "type": "combat",
      "summary": "落瘴岭的出口藏在狭窄洞道后，守关者已占住最窄处。这里没有宽阔场地，出手前要看清局势。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "marrow_gu_adept",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign",
        "soul_path_reaper",
        "blood_god_larva",
        "dream_wraith_echo"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 2,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_3",
      "name": "血蟒涧·关底",
      "stage": "three",
      "type": "combat",
      "summary": "血蟒涧深处的断桥被层主占据，桥下兽痕与刀痕叠成一片。要穿过山涧，得先逼出它的破绽。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_sovereign",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "thunder_crown_sovereign",
        "clan_patriarch",
        "thousand_li_earth_tarantula"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 3,
      "layer": 3
    },
    {
      "id": "layer_boss_stand_4",
      "name": "万蛊窟·关底",
      "stage": "four",
      "type": "combat",
      "summary": "万蛊窟尽头的石门前，守关者已经等候多时。沿途痕迹都指向门后，却没人留下答案。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "blood_vein_bishop",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "clan_patriarch",
        "blood_vein_bishop",
        "blue_fur_jiangshi"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 4,
      "layer": 4
    },
    {
      "id": "echo_cave",
      "name": "回声石洞",
      "stage": "two",
      "type": "event",
      "summary": "石壁刻痕层层叠叠，岩缝里的应答却总慢半拍。你听见的不止自己的回声。",
      "choices": [],
      "nextIds": [
        "blood_moss_grove",
        "gu_rot_pact",
        "blood_grave_stir"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": [
        "echo_cave",
        "gu_rot_pact",
        "huajiu_cache",
        "tithing_cache",
        "small_beast_tide",
        "tide_aftermath",
        "duel_wager",
        "duel_loss",
        "weird_trade",
        "contract_seal",
        "recognition_toll",
        "blood_vein_offering",
        "broken_bridge_vow",
        "cold_ash_pile",
        "sealed_silk_reliquary",
        "unclaimed_waystone",
        "cliffside_beast_bounty",
        "gravewatch_bones",
        "ropewalk_wager",
        "marrow_lock_duel",
        "unlit_soul_lantern",
        "inked_promise",
        "red_seal_submission",
        "bloodstone_cistern"
      ],
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "gu_rot_pact",
      "name": "腐朽蛊契",
      "stage": "two",
      "type": "event",
      "summary": "腐蛊外壳早已碎裂，契文却仍能回应。触碰它或可换来机缘，也会留下代价。",
      "choices": [],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": "gu_rot_pact",
      "eventPool": [
        "echo_cave",
        "gu_rot_pact",
        "huajiu_cache",
        "tithing_cache",
        "small_beast_tide",
        "tide_aftermath",
        "duel_wager",
        "duel_loss",
        "weird_trade",
        "contract_seal",
        "recognition_toll",
        "blood_vein_offering",
        "broken_bridge_vow",
        "cold_ash_pile",
        "sealed_silk_reliquary",
        "unclaimed_waystone",
        "cliffside_beast_bounty",
        "gravewatch_bones",
        "ropewalk_wager",
        "marrow_lock_duel",
        "unlit_soul_lantern",
        "inked_promise",
        "red_seal_submission",
        "bloodstone_cistern"
      ],
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_market",
      "name": "山脊市集",
      "stage": "one",
      "type": "market",
      "summary": "临时寨市正在收摊，摊主肯卖一条确切消息；多停一刻，就少一刻赶路。",
      "choices": [
        "trade",
        "buy_information",
        "leave"
      ],
      "nextIds": [
        "stage_one_ledger"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "caravan_missing_goods",
      "name": "商队失货",
      "stage": "three",
      "type": "caravan",
      "summary": "失货的箱车堵住谷口，账册与搬运痕迹互相对不上。管事不肯丢下伤员，却不能再等。",
      "choices": [
        "probe",
        "trade",
        "leave",
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "faction_guard",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": "caravan_steward",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "wandering_peddler",
      "name": "行脚货郎",
      "stage": "one",
      "type": "contact",
      "summary": "货郎把蛊笼摆在两匹瘦马之间，货价写得清楚，来路却一个字也不肯提。",
      "choices": [
        "negotiate",
        "deceive",
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "neutral_stone_wanderer",
      "enemyKinds": null,
      "enemyTheme": "neutral",
      "bossPool": null,
      "npcId": "wandering_peddler",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "herbalist_commission",
      "name": "药师委托",
      "stage": "four",
      "type": "commission",
      "summary": "药师留下的委托单只写了目标，没写路上的代价。接下委托、付费换取服务，或趁早抽身，由你定。",
      "choices": [
        "accept",
        "trade",
        "leave"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "beast_swarm_pass",
      "name": "兽群隘口",
      "stage": "one",
      "type": "combat",
      "summary": "兽群挤满山隘，身后还有头兽不断催逼；诱引可把威胁提到眼前，硬打则可夺取战后赏赐。",
      "choices": [
        "fight",
        "retreat",
        "lure"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove",
        "mo_line_pursuit"
      ],
      "enemyKind": "ridge_hound",
      "enemyKinds": [
        "ridge_hound",
        "neutral_stone_wanderer"
      ],
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 1
    },
    {
      "id": "greedy_wanderer",
      "name": "贪客拦路",
      "stage": "one",
      "type": "pursuit",
      "summary": "有人撬开兽巢夺走蛊材，却把山兽引上归路。空行囊散在两侧，兽吼已逼近。",
      "choices": [
        "fight",
        "trade",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_wolf",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "stage": "four",
      "type": "combat",
      "summary": "势力守卫封住山口，腰牌与弩机都已备好。说明来路、硬闯或退避，各有后果。",
      "choices": [
        "fight",
        "deceive",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "faction_guard",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 4
    },
    {
      "id": "earth_vein_contest",
      "name": "地脉之争",
      "stage": "four",
      "type": "earth_vein",
      "summary": "两路人马同时摸到地脉入口，附近兽群闻着气息聚拢。站队、设局或退走，都还来得及。",
      "choices": [
        "ally",
        "scheme",
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "beast_swarm",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "sealed_earth_vein",
      "name": "封存地脉",
      "stage": "four",
      "type": "earth_vein",
      "summary": "门壁上的封痕还很新，地脉气息却从缝隙外泄。先查封印，再决定是否打开，退路仍在。",
      "choices": [
        "scout",
        "open",
        "withdraw"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "poison_fog_vein",
      "name": "毒雾地脉",
      "stage": "five",
      "type": "earth_vein",
      "summary": "瘴气在地脉裂口间吞吐，近处石苔已褪色。先辨气流再占取；贸然深入，肉身会先受其害。",
      "choices": [
        "scout",
        "claim",
        "withdraw"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "final_boss_stand",
      "name": "瘴脉尽头",
      "stage": "five",
      "type": "combat",
      "summary": "瘴脉尽头的蛊主挡在升仙窗口前。雾从它脚下向四面回卷，进退都要由你亲自判断。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "miasma_vein_lord",
      "enemyKinds": null,
      "enemyTheme": "anomaly",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 5,
      "layer": 5
    },
    {
      "id": "rest_hollow",
      "name": "山壁石穴",
      "stage": "two",
      "type": "rest",
      "summary": "山壁石穴里只余风声，蛊虫也能暂歇片刻。休整可恢复气血与真元，也可尽早动身。",
      "choices": [
        "rest",
        "leave"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "rest_shrine",
      "name": "古祠残龛",
      "stage": "two",
      "type": "rest",
      "summary": "古祠香火早已断绝，却还有一角未被潮气侵蚀。你可在此歇息，也可不惊动尘埃继续赶路。",
      "choices": [
        "rest",
        "leave"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "body_imprint_ritual",
      "name": "体印仪式",
      "stage": "one",
      "type": "seclusion",
      "summary": "石壁刻着一套淬体法门，笔画间故意留了缺口。承受体印可强健肉身，却也会留下副作用。",
      "choices": [
        "meditate",
        "take_imprint",
        "leave"
      ],
      "nextIds": [
        "stage_one_ledger"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "iron_hide_ambush",
      "name": "黑皮野猪伏击",
      "stage": "one",
      "type": "combat",
      "summary": "铁皮野猪从岩后顶出，鬃毛间结着硬壳；隘路窄得避不开，先手比蛊力更要紧。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "iron_hide_boar",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "scout_crossing_raid",
      "name": "岭脊斥候伏击",
      "stage": "three",
      "type": "combat",
      "summary": "脊线上箭簇一闪，伏兵借风声遮住脚步。若惊动整队，前路很快会多出追兵。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "ridge_elite_scout",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 3
    },
    {
      "id": "wolf_pack_trail",
      "name": "兽群山径",
      "stage": "five",
      "type": "combat",
      "summary": "兽群沿山脊压境，爪印与撕咬痕密密叠在一起。拦路的只是先锋，身后还有整群兽物。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_wolf",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 5
    },
    {
      "id": "yizang_ridge",
      "name": "荒岭遗藏",
      "stage": "one",
      "type": "inheritance",
      "summary": "荒岭上草木环伏，墓中机关仍有余力。信物与路线图分在两处，贪多未必能全取。",
      "choices": [
        "claim_recon",
        "claim_token",
        "leave"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "mo_line_pursuit",
      "name": "漠家猎手",
      "stage": "one",
      "type": "combat",
      "summary": "漠家猎手缀在坡道背风处，犬哨一声，弩光先于人影出现。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "mo_family_huntsman",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "jiangshi_bell_road",
      "name": "僵王传人",
      "stage": "two",
      "type": "combat",
      "summary": "尸铃摇响，黄符贴地成阵——僵王传人立在道中央，身后青毛僵缓缓抬手。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "jiangshi_handler_boss",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "blood_grave_stir",
      "name": "血湖血傀",
      "stage": "two",
      "type": "combat",
      "summary": "坟雾里赤筋蠕动——血湖旧物循着尸铃醒来，挡在商队的退路上。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "blood_grave_thrall",
      "enemyKinds": null,
      "enemyTheme": "anomaly",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "bone_gun_ambush",
      "name": "骨枪马贼",
      "stage": "two",
      "type": "combat",
      "summary": "骨粉撒径，掷枪弧光自林隙掠出——马贼的骨枪比人先到。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "bone_gun_marauder",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": null
    }
  ],
  "route": [
    {
      "id": "beast_swarm_pass",
      "name": "兽群隘口",
      "stage": "one",
      "type": "combat",
      "summary": "兽群挤满山隘，身后还有头兽不断催逼；诱引可把威胁提到眼前，硬打则可夺取战后赏赐。",
      "choices": [
        "fight",
        "retreat",
        "lure"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove",
        "mo_line_pursuit"
      ],
      "enemyKind": "ridge_hound",
      "enemyKinds": [
        "ridge_hound",
        "neutral_stone_wanderer"
      ],
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 1
    },
    {
      "id": "layer_boss_stand_1",
      "name": "青茅外隘·关底",
      "stage": "one",
      "type": "combat",
      "summary": "青茅外隘的最后一关被强敌把守，岩壁上的爪痕与蛊痕交叠。想进下一层，先摸清守关者的路数。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "crag_serpent_matriarch",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept",
        "slave_path_overseer"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 1,
      "layer": 1
    },
    {
      "id": "rest_hollow",
      "name": "山壁石穴",
      "stage": "two",
      "type": "rest",
      "summary": "山壁石穴里只余风声，蛊虫也能暂歇片刻。休整可恢复气血与真元，也可尽早动身。",
      "choices": [
        "rest",
        "leave"
      ],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "iron_hide_ambush",
      "name": "黑皮野猪伏击",
      "stage": "one",
      "type": "combat",
      "summary": "铁皮野猪从岩后顶出，鬃毛间结着硬壳；隘路窄得避不开，先手比蛊力更要紧。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "iron_hide_boar",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "ridge_black_market",
      "name": "山脊黑市",
      "stage": "two",
      "type": "shop",
      "summary": "黑市藏在两道山梁之间，货物没有来路，摊主也不问。看中的东西，得拿元石换。",
      "choices": [],
      "nextIds": [
        "stage_one_ledger",
        "bone_gun_ambush"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "ridge_extortionist",
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_2",
      "name": "落瘴岭·关底",
      "stage": "two",
      "type": "combat",
      "summary": "落瘴岭的出口藏在狭窄洞道后，守关者已占住最窄处。这里没有宽阔场地，出手前要看清局势。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "marrow_gu_adept",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign",
        "soul_path_reaper",
        "blood_god_larva",
        "dream_wraith_echo"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 2,
      "layer": 2
    },
    {
      "id": "scout_crossing_raid",
      "name": "岭脊斥候伏击",
      "stage": "three",
      "type": "combat",
      "summary": "脊线上箭簇一闪，伏兵借风声遮住脚步。若惊动整队，前路很快会多出追兵。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "ridge_elite_scout",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 3
    },
    {
      "id": "layer_boss_stand_3",
      "name": "血蟒涧·关底",
      "stage": "three",
      "type": "combat",
      "summary": "血蟒涧深处的断桥被层主占据，桥下兽痕与刀痕叠成一片。要穿过山涧，得先逼出它的破绽。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_sovereign",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "thunder_crown_sovereign",
        "clan_patriarch",
        "thousand_li_earth_tarantula"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 3,
      "layer": 3
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "stage": "four",
      "type": "combat",
      "summary": "势力守卫封住山口，腰牌与弩机都已备好。说明来路、硬闯或退避，各有后果。",
      "choices": [
        "fight",
        "deceive",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "faction_guard",
      "enemyKinds": null,
      "enemyTheme": "faction",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 4
    },
    {
      "id": "layer_boss_stand_4",
      "name": "万蛊窟·关底",
      "stage": "four",
      "type": "combat",
      "summary": "万蛊窟尽头的石门前，守关者已经等候多时。沿途痕迹都指向门后，却没人留下答案。",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "blood_vein_bishop",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "clan_patriarch",
        "blood_vein_bishop",
        "blue_fur_jiangshi"
      ],
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 4,
      "layer": 4
    },
    {
      "id": "wolf_pack_trail",
      "name": "兽群山径",
      "stage": "five",
      "type": "combat",
      "summary": "兽群沿山脊压境，爪印与撕咬痕密密叠在一起。拦路的只是先锋，身后还有整群兽物。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_wolf",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": null,
      "layer": 5
    },
    {
      "id": "final_boss_stand",
      "name": "瘴脉尽头",
      "stage": "five",
      "type": "combat",
      "summary": "瘴脉尽头的蛊主挡在升仙窗口前。雾从它脚下向四面回卷，进退都要由你亲自判断。",
      "choices": [
        "fight",
        "retreat"
      ],
      "nextIds": [],
      "enemyKind": "miasma_vein_lord",
      "enemyKinds": null,
      "enemyTheme": "anomaly",
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "eventPool": null,
      "layerBoss": 5,
      "layer": 5
    }
  ],
  "shopOffers": [
    {
      "id": "purchase_stone_shell",
      "kind": "purchase",
      "card_key": "purchase.stone_shell",
      "gu_id": "stone_shell_gu",
      "stone_cost": 6,
      "tier": 1,
      "gu_name": "石皮蛊"
    },
    {
      "id": "purchase_moonlight",
      "kind": "purchase",
      "card_key": "purchase.moonlight",
      "gu_id": "moonlight_gu",
      "stone_cost": 6,
      "tier": 3,
      "gu_name": "月光蛊"
    },
    {
      "id": "purchase_blood_droplet",
      "kind": "purchase",
      "card_key": "purchase.blood_droplet",
      "gu_id": "blood_droplet_gu",
      "stone_cost": 6,
      "tier": 1,
      "npc_only": true,
      "gu_name": "血滴子"
    },
    {
      "id": "purchase_thunder_ward",
      "kind": "purchase",
      "card_key": "purchase.thunder_ward",
      "gu_id": "qi_atk_1_01_gu",
      "stone_cost": 9,
      "tier": 4,
      "gu_name": "硬气蛊"
    },
    {
      "id": "purchase_moon_glow",
      "kind": "purchase",
      "card_key": "purchase.moon_glow",
      "gu_id": "moon_glow_gu",
      "stone_cost": 12,
      "tier": 5,
      "gu_name": "月芒蛊"
    },
    {
      "id": "purchase_small_light_gu",
      "kind": "purchase",
      "card_key": "purchase.small_light",
      "gu_id": "small_light_gu",
      "stone_cost": 12,
      "tier": 1,
      "gu_name": "小光蛊"
    },
    {
      "id": "purchase_jade_skin_gu",
      "kind": "purchase",
      "card_key": "purchase.jade_skin",
      "gu_id": "jade_skin_gu",
      "stone_cost": 30,
      "tier": 1,
      "gu_name": "玉皮蛊"
    },
    {
      "id": "purchase_white_boar_strength_gu",
      "kind": "purchase",
      "card_key": "purchase.white_boar",
      "gu_id": "white_boar_strength_gu",
      "stone_cost": 35,
      "tier": 1,
      "gu_name": "白豕蛊"
    },
    {
      "id": "purchase_mending_grass",
      "kind": "purchase",
      "card_key": "purchase.mending_grass",
      "gu_id": "wood_atk_1_05_gu",
      "stone_cost": 8,
      "tier": 1,
      "gu_name": "青藤蛊"
    },
    {
      "id": "purchase_bone_knit",
      "kind": "purchase",
      "card_key": "purchase.bone_knit",
      "gu_id": "bone_atk_1_08_gu",
      "stone_cost": 14,
      "tier": 2,
      "gu_name": "骨蛊"
    },
    {
      "id": "purchase_spring_heart",
      "kind": "purchase",
      "card_key": "purchase.spring_heart",
      "gu_id": "human_atk_1_01_gu",
      "stone_cost": 18,
      "tier": 3,
      "gu_name": "自己蛊"
    },
    {
      "id": "purchase_moon_shadow_300",
      "kind": "purchase",
      "card_key": "purchase.moon_shadow_300",
      "gu_id": "moon_shadow_gu",
      "stone_cost": 40,
      "tier": 3,
      "gu_name": "月影蛊"
    },
    {
      "id": "purchase_life_root",
      "kind": "purchase",
      "card_key": "purchase.life_root",
      "gu_id": "wood_atk_1_05_gu",
      "stone_cost": 20,
      "tier": 4,
      "gu_name": "青藤蛊"
    },
    {
      "id": "purchase_undying_vine",
      "kind": "purchase",
      "card_key": "purchase.undying_vine",
      "gu_id": "wood_atk_1_05_gu",
      "stone_cost": 20,
      "tier": 4,
      "gu_name": "青藤蛊"
    },
    {
      "id": "purchase_heaven_dew",
      "kind": "purchase",
      "card_key": "purchase.heaven_dew",
      "gu_id": "water_atk_1_08_gu",
      "stone_cost": 80,
      "tier": 5,
      "gu_name": "浪蛊"
    },
    {
      "id": "purchase_sword_atk_1_06",
      "kind": "purchase",
      "card_key": "purchase.sword_atk_1_06",
      "gu_id": "sword_atk_1_06_gu",
      "stone_cost": 8,
      "tier": 1,
      "school": "sword",
      "gu_name": "剑纹刃蛊"
    },
    {
      "id": "purchase_sword_atk_2_12",
      "kind": "purchase",
      "card_key": "purchase.sword_atk_2_12",
      "gu_id": "sword_atk_2_12_gu",
      "stone_cost": 18,
      "tier": 2,
      "school": "sword",
      "gu_name": "古剑蛊"
    },
    {
      "id": "purchase_sword_def_3_14",
      "kind": "purchase",
      "card_key": "purchase.sword_def_3_14",
      "gu_id": "sword_def_3_14_gu",
      "stone_cost": 30,
      "tier": 3,
      "school": "sword",
      "gu_name": "软剑蛊"
    },
    {
      "id": "purchase_sword_heal_4_16",
      "kind": "purchase",
      "card_key": "purchase.sword_heal_4_16",
      "gu_id": "sword_heal_4_16_gu",
      "stone_cost": 45,
      "tier": 4,
      "school": "sword",
      "gu_name": "双剑蛊"
    },
    {
      "id": "purchase_sword_atk_5_02",
      "kind": "purchase",
      "card_key": "purchase.sword_atk_5_02",
      "gu_id": "sword_atk_5_02_gu",
      "stone_cost": 70,
      "tier": 5,
      "school": "sword",
      "gu_name": "飞剑蛊"
    },
    {
      "id": "lab_shop_aptitude_gu",
      "kind": "purchase",
      "gu_id": "aptitude_gu",
      "tier": 1,
      "stone_cost": 20,
      "gu_name": ""
    },
    {
      "id": "lab_shop_gold_atk_2_12_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_2_12_gu",
      "tier": 1,
      "stone_cost": 10,
      "gu_name": "青铜舍利蛊"
    },
    {
      "id": "lab_shop_gold_atk_2_11_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_2_11_gu",
      "tier": 2,
      "stone_cost": 10,
      "gu_name": "赤铁舍利蛊"
    },
    {
      "id": "lab_shop_gold_atk_3_13_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_3_13_gu",
      "tier": 3,
      "stone_cost": 16,
      "gu_name": "白银舍利蛊"
    },
    {
      "id": "lab_shop_gold_atk_4_14_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_4_14_gu",
      "tier": 4,
      "stone_cost": 24,
      "gu_name": "黄金舍利蛊"
    },
    {
      "id": "lab_shop_gold_atk_5_15_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_5_15_gu",
      "tier": 5,
      "stone_cost": 40,
      "gu_name": "紫晶舍利蛊"
    }
  ],
  "npcs": [
    {
      "id": "caravan_steward",
      "goals": [
        "recover_goods",
        "protect_caravan_reputation"
      ],
      "bottom_line": "will_not_abandon_injured_guard",
      "will": 3,
      "known_facts": [
        "missing_goods",
        "injured_guard"
      ],
      "retreat": "trade_safe_passage",
      "reinforcements": "three_day_patrol",
      "injury_reaction": "exploit",
      "stock": [
        "purchase_stone_shell",
        "purchase_moonlight"
      ]
    },
    {
      "id": "earth_vein_scout",
      "goals": [
        "claim_earth_vein_entry",
        "avoid_open_conflict"
      ],
      "bottom_line": "will_not_share_map_without_value",
      "will": 4,
      "known_facts": [
        "toxic_fog",
        "sealed_entry"
      ],
      "retreat": "leave_with_map_copy",
      "reinforcements": "faction_guard_pair",
      "injury_reaction": "caution",
      "stock": []
    },
    {
      "id": "wandering_healer",
      "goals": [
        "repay_old_favor",
        "preserve_herbs"
      ],
      "bottom_line": "will_not_treat_known_betrayer",
      "will": 2,
      "known_facts": [
        "blood_moss_growth"
      ],
      "retreat": "offer_safe_treatment",
      "reinforcements": "none",
      "injury_reaction": "sympathy",
      "stock": []
    },
    {
      "id": "ridge_extortionist",
      "goals": [
        "collect_stone",
        "keep_route_control"
      ],
      "bottom_line": "will_not_face_guarded_passage_alone",
      "will": 2,
      "known_facts": [
        "alternate_ridge_path"
      ],
      "retreat": "accept_stone_and_withdraw",
      "reinforcements": "beast_swarm_lure",
      "injury_reaction": "contempt",
      "stock": []
    },
    {
      "id": "wandering_peddler",
      "goals": [
        "move_goods_safely",
        "profit_from_barter"
      ],
      "bottom_line": "will_not_trade_under_threat",
      "will": 2,
      "known_facts": [
        "ridge_market_prices"
      ],
      "retreat": "pack_up_and_leave",
      "reinforcements": "none",
      "injury_reaction": "caution",
      "stock": [
        "purchase_stone_shell",
        "purchase_moonlight",
        "purchase_blood_droplet"
      ]
    }
  ],
  "events": [
    {
      "id": "echo_cave",
      "kind": "delayed_cost",
      "title": "残响叩穴",
      "summary": "洞穴里有人敲出三短一长。墙上旧字已被磨平，只剩一行新刻：听见的人算一个。",
      "flavor_gain": "收下回声允诺的机缘。",
      "unknown_note": "应声后，一缕回音会留在魂魄里；下一段路未必安静。",
      "health_cost": 1,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "gu_rot_pact",
      "kind": "curse_bargain",
      "title": "腐朽蛊契",
      "summary": "残契压在一枚虫蜕下，触碰时虫蜕先碎，朱痕却自己爬上掌心。",
      "flavor_gain": "借腐蛊契文换得一线机缘。",
      "unknown_note": "契文未写还期，元石滞胀的苦果可能稍后才显。",
      "health_cost": 1,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "curse_id": "essence_bloat"
    },
    {
      "id": "huajiu_cache",
      "title": "行者遗藏",
      "summary": "旧酒葫芦卡在岩缝，晃动时传出石子声。葫口下压着一张空白遗言。",
      "flavor_gain": "取走遗藏中保存完好的元石。",
      "unknown_note": "葫芦底部还压着一层封口，挖到尽头才知里面是否另有东西。",
      "health_cost": 2,
      "stone_gain": 5
    },
    {
      "id": "tithing_cache",
      "title": "献藏换赏",
      "summary": "遗藏刚见光，山寨巡哨已摸到附近。报出位置只换一份现成赏钱，不必守到天黑。",
      "flavor_gain": "领下山寨给出的赏钱。",
      "unknown_note": "遗藏报上去后会落到谁手里，管事没有写进账册。",
      "health_cost": 0,
      "stone_gain": 2
    },
    {
      "id": "small_beast_tide",
      "title": "小兽潮",
      "summary": "小兽潮压向寨墙，守夜人敲响木梆。你出手后能按约领赏，却还得接着赶路。",
      "flavor_gain": "从兽尸与赏功中收下应得的元石。",
      "unknown_note": "兽潮散去后，山道上的追随者会不会也散去，眼下无人说得准。",
      "health_cost": 2,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "tide_aftermath",
      "title": "潮后拾骨",
      "summary": "兽潮退去，尸骨嵌在泥里；石缝间散着未被啃碎的元石，兽尸已开始发热。",
      "flavor_gain": "从尸骨与泥缝中拾回元石。",
      "unknown_note": "低头拾取时，骨堆深处的动静始终没有停。",
      "health_cost": 0,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "duel_wager",
      "title": "赌斗押注",
      "summary": "赌斗台只摆着一张契纸和一枚筹码；对手不露面，围观者却都已押好。",
      "flavor_gain": "拿走赌斗台上的注头。",
      "unknown_note": "对手的底细与后手一概不知，台下的人也没有替你作证的意思。",
      "health_cost": 1,
      "stone_gain": 4
    },
    {
      "id": "duel_loss",
      "title": "斗蛊折戟",
      "summary": "胜负已分，台上只剩碎蛊与几枚元石。输家仍跪着，掌纹里的封印尚未散去。",
      "flavor_gain": "从散落的注头里捡回少许元石。",
      "unknown_note": "封蛊何时松解没有定数，场边也没人肯替你担保。",
      "health_cost": 2,
      "curse_id": "meridian_seal",
      "stone_gain": 1
    },
    {
      "id": "weird_trade",
      "title": "秘境换物",
      "summary": "秘境只开一线，守门者不收元石，只把一盏暗灯推到你面前。",
      "flavor_gain": "换回一份能继续上路的元石。",
      "unknown_note": "灯里封着什么，守门者不答；你只觉魂魄像被轻轻拨了一下。",
      "health_cost": 0,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "contract_seal",
      "title": "毒誓之契",
      "summary": "契纸没有署名，酬劳却已摆上桌。墨里混着誓蛊的血，见证人不许追问条款。",
      "flavor_gain": "先收下契约列明的酬劳。",
      "unknown_note": "誓约会在何时收紧，只有走到那一天才知道。",
      "health_cost": 1,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 4
    },
    {
      "id": "recognition_toll",
      "title": "认主输诚",
      "summary": "关卡前的印台只缺一个掌印。守关者把赏赐推近，另一只手始终按着封蛊。",
      "flavor_gain": "收下对方许诺的赏赐。",
      "unknown_note": "掌印留下的蛊蚀何时发作，仍由对方拿捏。",
      "health_cost": 0,
      "curse_id": "gu_erosion",
      "stone_gain": 3
    },
    {
      "id": "blood_vein_offering",
      "title": "血脉献祭",
      "summary": "地脉裂口边有人收买精血，祭坛旁的元石堆得很高，石面都染成暗红。",
      "flavor_gain": "取走祭坛边堆积的元石。",
      "unknown_note": "血祭留下的滞胀余患何时显形，无人敢断言。",
      "health_cost": 2,
      "curse_id": "essence_bloat",
      "stone_gain": 4
    },
    {
      "id": "broken_bridge_vow",
      "title": "断桥余誓",
      "summary": "断桥下挂着一只铜铃，铃舌系着未拆的契纸。桥另一头有人留下元石，却没有脚印。",
      "flavor_gain": "收下铜铃旁留下的元石。",
      "unknown_note": "应声后，一缕回音会留在魂魄里；下一段路未必安静。",
      "kind": "delayed_cost",
      "health_cost": 1,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "cold_ash_pile",
      "title": "冷灰拾遗",
      "summary": "营火只剩冷灰，灰下压着整齐摆开的兽骨。最后一名拾荒者说，骨堆里有人数数。",
      "flavor_gain": "从冷灰与兽骨间拾回元石。",
      "unknown_note": "俯身拾取时，骨堆里的声音像隔着魂魄数你的脚步。",
      "health_cost": 0,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "sealed_silk_reliquary",
      "title": "丝封遗匣",
      "summary": "丝囊封死在岩壁上，拆取时细丝割开掌心。里面的元石没有受潮，囊口却缝了三层。",
      "flavor_gain": "取下丝囊中保存的元石。",
      "unknown_note": "囊底还有一圈未拆的旧线，拉开后会放出什么仍未可知。",
      "health_cost": 2,
      "stone_gain": 5
    },
    {
      "id": "unclaimed_waystone",
      "title": "无主路钱",
      "summary": "石堆夹着一小袋无人认领的元石，袋口沾着新泥。附近的脚印到此为止，又从另一侧折回。",
      "flavor_gain": "拿走石堆里留下的元石。",
      "unknown_note": "这笔路钱为何无人取走，留下脚印的人没有解释。",
      "health_cost": 0,
      "stone_gain": 2
    },
    {
      "id": "cliffside_beast_bounty",
      "title": "崖边悬赏",
      "summary": "受伤的兽物把巡山人逼退到崖沿，赏格还贴在树上。血迹一路向上，没有往回走。",
      "flavor_gain": "从兽尸与悬赏中收下元石。",
      "unknown_note": "血腥味会留在身上，下一段路上是否还有追兵未可知。",
      "health_cost": 2,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "gravewatch_bones",
      "title": "守骨人不眠",
      "summary": "兽潮后的骨堆被人垒成一圈，圈心埋着元石。守骨人已经不在，地上却多了一双新脚印。",
      "flavor_gain": "从骨圈中取回元石。",
      "unknown_note": "拨开骨头后，那双脚印仍在你身后多出一步。",
      "health_cost": 0,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "ropewalk_wager",
      "title": "索桥赌注",
      "summary": "索桥两端各压着一份赌注，桥中央却只剩半张契纸。山风一过，桥板便互相撞响。",
      "flavor_gain": "取走桥头留下的赌注。",
      "unknown_note": "契纸缺掉的那一半记着谁先走上桥，无从查证。",
      "health_cost": 1,
      "stone_gain": 4
    },
    {
      "id": "marrow_lock_duel",
      "title": "封脉残局",
      "summary": "斗蛊场已散，只留下一把断刃和一枚孤零零的元石。台下有人劝你别碰那张封脉符。",
      "flavor_gain": "捡起残局里尚未被取走的元石。",
      "unknown_note": "符印落在经脉上后何时松解，没人能替你定。",
      "health_cost": 2,
      "curse_id": "meridian_seal",
      "stone_gain": 1
    },
    {
      "id": "unlit_soul_lantern",
      "title": "无火魂灯",
      "summary": "一盏魂灯放在秘境门外，灯油早已干涸，灯芯却还留着温度。守门者让你自取灯旁的元石。",
      "flavor_gain": "取走灯旁无人看守的元石。",
      "unknown_note": "灯火未燃，魂魄却像被它认了出来。",
      "health_cost": 0,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "inked_promise",
      "title": "墨债先偿",
      "summary": "借贷的元石先摆到面前，契纸却要你以血印押下姓名。放贷人不问何时还，只问你敢不敢走远。",
      "flavor_gain": "先收下契纸列出的酬劳。",
      "unknown_note": "上路后，契文会从魂魄里取走利钱。",
      "health_cost": 1,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 4
    },
    {
      "id": "red_seal_submission",
      "title": "朱印换路",
      "summary": "关卡的朱印台旁堆着赏钱，守门人要的不是姓名，只要你按下掌印。",
      "flavor_gain": "收下朱印台旁的赏钱。",
      "unknown_note": "掌印化成蛊蚀后会如何发作，仍由掌印的势力拿捏。",
      "health_cost": 0,
      "curse_id": "gu_erosion",
      "stone_gain": 3
    },
    {
      "id": "bloodstone_cistern",
      "title": "血池高价",
      "summary": "地脉裂隙旁的石池收买精血，价钱高得反常。池沿刻满名字，最近一个还没有干。",
      "flavor_gain": "取走石池边摆放的元石。",
      "unknown_note": "精血换来的元石可能在体内滞胀，余患何时显现无人能断。",
      "health_cost": 2,
      "curse_id": "essence_bloat",
      "stone_gain": 4
    }
  ],
  "canon": {
    "contentVersion": "a3333e6df461d1981cf1bcd996881a4fe24dae75091e341ef2a756c1891129e8",
    "sourceSha256": "bf78d41427e28bb8b64f1ad6d93b971d1a77458abf273e554aabe7f27a155d34",
    "entities": {
      "bear_strength_gu": {
        "name": "熊力蛊",
        "rank": null,
        "rankStatus": "rank_unstated"
      },
      "blood_atk_1_18_gu": {
        "name": "鳄力蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "blood_atk_3_03_gu": {
        "name": "血气蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "blood_atk_3_11_gu": {
        "name": "血月蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "blood_atk_3_15_gu": {
        "name": "血蝠蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "blood_atk_4_01_gu": {
        "name": "血颅蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "blood_atk_5_02_gu": {
        "name": "血手印蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "blood_atk_5_09_gu": {
        "name": "血神子",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "blood_atk_5_12_gu": {
        "name": "血本仙蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "blood_atk_5_13_gu": {
        "name": "血本蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "blood_atk_5_14_gu": {
        "name": "血缘仙蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "blood_bat_gu": {
        "name": "刀翅血蝠蛊",
        "rank": 3,
        "rankStatus": "divergence"
      },
      "blood_droplet_gu": {
        "name": "血滴子",
        "rank": 5,
        "rankStatus": "verified"
      },
      "blood_farewell_gu": {
        "name": "爱别离",
        "rank": 2,
        "rankStatus": "verified"
      },
      "bone_atk_1_08_gu": {
        "name": "骨蛊",
        "rank": null,
        "rankStatus": "rank_unstated"
      },
      "bone_atk_3_03_gu": {
        "name": "骨刺蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "bone_def_3_01_gu": {
        "name": "骨枪蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "bone_def_3_05_gu": {
        "name": "玉骨蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "bone_mov_4_04_gu": {
        "name": "骨翼蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "dream_atk_5_02_gu": {
        "name": "梦蝶仙蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "dream_atk_5_06_gu": {
        "name": "解谜蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "dream_def_5_01_gu": {
        "name": "梦甲蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "earth_atk_5_02_gu": {
        "name": "洞地蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "earth_atk_5_03_gu": {
        "name": "地藏花蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "earth_def_3_01_gu": {
        "name": "石窍蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "fire_atk_2_01_gu": {
        "name": "鬼火蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "fire_atk_4_02_gu": {
        "name": "丹火蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "fire_atk_4_05_gu": {
        "name": "火龙蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "fire_atk_4_06_gu": {
        "name": "火蛇蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "fire_atk_4_07_gu": {
        "name": "炎蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "fire_mov_4_39_gu": {
        "name": "火炭蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "force_atk_1_05_gu": {
        "name": "斤力蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "force_atk_2_06_gu": {
        "name": "十斤之力蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "force_atk_3_01_gu": {
        "name": "力气蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "force_atk_3_07_gu": {
        "name": "一钧之力蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "force_atk_3_29_gu": {
        "name": "天蓬蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "force_atk_4_02_gu": {
        "name": "苦力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_04_gu": {
        "name": "全力以赴蛊",
        "rank": 3,
        "rankStatus": "timepoint"
      },
      "force_atk_4_08_gu": {
        "name": "十钧之力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_11_gu": {
        "name": "兽力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_17_gu": {
        "name": "借力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_18_gu": {
        "name": "费力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_25_gu": {
        "name": "巨力蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_4_26_gu": {
        "name": "直撞蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "force_atk_4_27_gu": {
        "name": "横冲蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "force_atk_4_28_gu": {
        "name": "横冲直撞蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "force_atk_5_10_gu": {
        "name": "钧力蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "force_atk_5_16_gu": {
        "name": "群力蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "force_atk_5_19_gu": {
        "name": "我力蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "force_atk_5_20_gu": {
        "name": "我力仙蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "force_gu": {
        "name": "力量蛊",
        "rank": 9,
        "rankStatus": "name_reuse"
      },
      "force_heal_3_03_gu": {
        "name": "自力更生蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "force_mov_5_21_gu": {
        "name": "飞熊之力蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "gold_atk_2_11_gu": {
        "name": "赤铁舍利蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "gold_atk_2_12_gu": {
        "name": "青铜舍利蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "gold_atk_2_16_gu": {
        "name": "舍利蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "gold_atk_2_19_gu": {
        "name": "铁蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "gold_atk_3_06_gu": {
        "name": "金罡蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "gold_atk_3_13_gu": {
        "name": "白银舍利蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "gold_atk_4_02_gu": {
        "name": "金龙蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_atk_4_04_gu": {
        "name": "金缕衣蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_atk_4_14_gu": {
        "name": "黄金舍利蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_atk_5_01_gu": {
        "name": "点金蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "gold_atk_5_03_gu": {
        "name": "金风送爽蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_atk_5_05_gu": {
        "name": "金霞蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_atk_5_15_gu": {
        "name": "紫晶舍利蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "gold_atk_5_17_gu": {
        "name": "金甲蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "gold_atk_5_18_gu": {
        "name": "剑蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "gold_atk_5_20_gu": {
        "name": "金蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "gold_def_3_08_gu": {
        "name": "铜皮蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "gold_def_3_09_gu": {
        "name": "古铜皮蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "gold_def_3_10_gu": {
        "name": "铁柜蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "heaven_atk_1_11_gu": {
        "name": "命蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "heaven_atk_1_12_gu": {
        "name": "灾蛊",
        "rank": 7,
        "rankStatus": "name_reuse"
      },
      "heaven_atk_3_10_gu": {
        "name": "雷翼蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "heaven_atk_3_13_gu": {
        "name": "雷蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "heaven_atk_3_14_gu": {
        "name": "电蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "heaven_atk_4_09_gu": {
        "name": "雷盾蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "heaven_atk_5_01_gu": {
        "name": "宿命蛊",
        "rank": 9,
        "rankStatus": "rank_cap"
      },
      "heaven_atk_5_02_gu": {
        "name": "命运蛊",
        "rank": 9,
        "rankStatus": "rank_cap"
      },
      "heaven_atk_5_03_gu": {
        "name": "天妒仙蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "heaven_atk_5_06_gu": {
        "name": "天机蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "heaven_atk_5_07_gu": {
        "name": "寿蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "heaven_atk_5_08_gu": {
        "name": "雷电蛊",
        "rank": 9,
        "rankStatus": "rank_cap"
      },
      "human_atk_1_38_gu": {
        "name": "人如故仙蛊",
        "rank": 6,
        "rankStatus": "name_reuse"
      },
      "human_atk_3_19_gu": {
        "name": "刃蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "human_atk_3_33_gu": {
        "name": "毒誓蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "human_atk_4_40_gu": {
        "name": "情蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "human_atk_5_02_gu": {
        "name": "爱情蛊",
        "rank": 9,
        "rankStatus": "rank_cap"
      },
      "human_atk_5_10_gu": {
        "name": "能力蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "human_atk_5_21_gu": {
        "name": "大侠蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "human_atk_5_31_gu": {
        "name": "海誓蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "human_atk_5_34_gu": {
        "name": "悔蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "human_atk_5_37_gu": {
        "name": "人如故蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "human_atk_5_41_gu": {
        "name": "恨蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "human_def_1_32_gu": {
        "name": "山盟蛊",
        "rank": null,
        "rankStatus": "name_reuse"
      },
      "human_heal_5_42_gu": {
        "name": "团圆蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "jade_skin_gu": {
        "name": "玉皮蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "light_atk_1_04_gu": {
        "name": "光蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "light_atk_3_02_gu": {
        "name": "邀月蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "light_atk_3_05_gu": {
        "name": "月蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "light_atk_5_03_gu": {
        "name": "太光蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "light_rec_3_07_gu": {
        "name": "星芽蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "light_rec_3_09_gu": {
        "name": "星萤蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "light_rec_5_08_gu": {
        "name": "星河蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "light_rec_5_12_gu": {
        "name": "星念蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "luck_atk_1_03_gu": {
        "name": "招灾蛊",
        "rank": 7,
        "rankStatus": "name_reuse"
      },
      "luck_atk_5_01_gu": {
        "name": "鸿运齐天蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "luck_atk_5_04_gu": {
        "name": "狗屎运蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "luck_atk_5_05_gu": {
        "name": "排难蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "luck_rec_5_02_gu": {
        "name": "察运蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "moon_glow_gu": {
        "name": "月芒蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "moon_ray_gu": {
        "name": "月痕蛊",
        "rank": null,
        "rankStatus": "rank_unstated"
      },
      "moon_shadow_gu": {
        "name": "月影蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "moonlight_gu": {
        "name": "月光蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "qi_atk_5_05_gu": {
        "name": "龙息蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "qi_atk_5_08_gu": {
        "name": "霞蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "qi_mov_4_03_gu": {
        "name": "风气蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "qi_mov_4_06_gu": {
        "name": "云蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "refine_atk_1_04_gu": {
        "name": "化蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "refine_log_2_03_gu": {
        "name": "合炼蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "refine_log_5_01_gu": {
        "name": "升炼蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "refine_log_5_02_gu": {
        "name": "九转升炼蛊",
        "rank": 9,
        "rankStatus": "rank_cap"
      },
      "refine_log_5_05_gu": {
        "name": "炼炉蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "refine_log_5_07_gu": {
        "name": "量蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "slave_atk_1_03_gu": {
        "name": "驭犬蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "slave_atk_3_04_gu": {
        "name": "驭狼蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "slave_atk_3_05_gu": {
        "name": "驭熊蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "slave_atk_4_02_gu": {
        "name": "驭兽蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "slave_atk_5_01_gu": {
        "name": "奴隶蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "small_light_gu": {
        "name": "小光蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "soul_atk_1_02_gu": {
        "name": "净魂仙蛊",
        "rank": 7,
        "rankStatus": "name_reuse"
      },
      "soul_atk_5_01_gu": {
        "name": "魂灯蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "stone_shell_gu": {
        "name": "石皮蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "sword_atk_4_01_gu": {
        "name": "剑气蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "sword_atk_5_02_gu": {
        "name": "飞剑蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "sword_atk_5_03_gu": {
        "name": "剑鞘蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "water_atk_3_06_gu": {
        "name": "冰肌蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "water_atk_3_07_gu": {
        "name": "蓝鸟冰棺蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "water_atk_4_02_gu": {
        "name": "水瀑蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "water_atk_4_09_gu": {
        "name": "海蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "water_atk_5_10_gu": {
        "name": "河蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "water_atk_5_11_gu": {
        "name": "湖蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "water_rec_5_04_gu": {
        "name": "浪迹天涯仙蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "white_boar_strength_gu": {
        "name": "白豕蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "white_jade_gu": {
        "name": "白玉蛊",
        "rank": 2,
        "rankStatus": "verified"
      },
      "wind_mov_4_04_gu": {
        "name": "龙行虎步蛊",
        "rank": 4,
        "rankStatus": "verified"
      },
      "wind_mov_5_06_gu": {
        "name": "风虎云龙蛊",
        "rank": 5,
        "rankStatus": "verified"
      },
      "wisdom_atk_1_01_gu": {
        "name": "智慧蛊",
        "rank": 9,
        "rankStatus": "name_reuse"
      },
      "wisdom_atk_3_21_gu": {
        "name": "心蛊",
        "rank": null,
        "rankStatus": "collision"
      },
      "wisdom_atk_5_03_gu": {
        "name": "态度蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "wisdom_atk_5_04_gu": {
        "name": "定力蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "wisdom_atk_5_05_gu": {
        "name": "慧剑蛊",
        "rank": 8,
        "rankStatus": "rank_cap"
      },
      "wisdom_atk_5_15_gu": {
        "name": "妇人心蛊",
        "rank": 6,
        "rankStatus": "rank_cap"
      },
      "wood_atk_1_05_gu": {
        "name": "青藤蛊",
        "rank": null,
        "rankStatus": "rank_unstated"
      },
      "wood_atk_3_01_gu": {
        "name": "木魅蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "wood_atk_3_09_gu": {
        "name": "花蛊",
        "rank": 3,
        "rankStatus": "verified"
      },
      "wood_atk_5_08_gu": {
        "name": "森林蛊",
        "rank": 7,
        "rankStatus": "rank_cap"
      },
      "wood_heal_3_03_gu": {
        "name": "草傀蛊",
        "rank": 1,
        "rankStatus": "verified"
      },
      "wood_heal_3_10_gu": {
        "name": "草蛊",
        "rank": null,
        "rankStatus": "collision"
      }
    },
    "relations": [
      {
        "id": "REL-REFINE-MOONGLOW",
        "relation": "refinement",
        "statement": "月光蛊加两只小光蛊，可合炼成二转月芒蛊",
        "inputs": [
          "moonlight_gu",
          "small_light_gu",
          "small_light_gu"
        ],
        "output": "moon_glow_gu",
        "output_rank": 2
      },
      {
        "id": "REL-SMALLLIGHT-MOONLIGHT-SUPPORT",
        "relation": "supports",
        "statement": "双蛊同催：月刃体积与攻击力各扩大一倍；一只即翻倍、两只不叠加",
        "from": "small_light_gu",
        "to": "moonlight_gu"
      }
    ]
  },
  "worldBalance": {
    "rank_step_ratio": 2,
    "standard_hit_ratio": 0.2,
    "human_base_health": 100,
    "standard_human_hp": 100,
    "player_start_hp": 100,
    "thought_base_capacity": 3,
    "stone_to_essence_per_stone": 5,
    "rank_power_budget": {
      "formula": "rank1_budget * rank_step_ratio^(rank-1)",
      "rank1_formula": "human_base_health * standard_hit_ratio * rank_step_ratio",
      "rank1_budget": 40,
      "budget_by_rank": {
        "1": 40,
        "2": 80,
        "3": 160,
        "4": 320,
        "5": 640
      },
      "axis": "rank_power_budget",
      "axis_note_zh": "RUL-2026-09-19-008 D2/D12：全仓唯一能力预算真源。每转约 x2、1->5 约 x16，作用于效果预算（Effect Budget），不直接乘所有伤害。rank_step_ratio 升格为本曲线的步进比；standard_gu_power 指定为本曲线的唯一真源（值不变，零数值漂移）。"
    },
    "effect_budget": {
      "source_ruling": "RUL-2026-09-25-001 Q2",
      "axis_note_zh": "role 曲线唯一真源（WORLD 量纲，裁定直给 30 值，无公式）。amount 是该 role 在该转的能力预算表达，不是通用倍率；Executor 内禁止隐藏 rank 缩放。Web 消费须经显式投影（wenzhen-web-lab/data/projections.json PROJ-LAB-ROLE-CURVE-001）；Godot 参考实现暂读 v1_battle.json legacy 值，迁移批后归一。",
      "default_amount_by_role": {
        "attack": [
          4,
          6,
          8,
          11,
          16
        ],
        "defense": [
          4,
          6,
          8,
          11,
          16
        ],
        "healing": [
          3,
          4,
          6,
          8,
          12
        ],
        "logistics": [
          2,
          3,
          4,
          6,
          8
        ],
        "movement": [
          1,
          1,
          2,
          2,
          3
        ],
        "recon": [
          1,
          1,
          1,
          1,
          1
        ]
      }
    }
  },
  "projections": {
    "role_curve_lab": {
      "attack": [
        2,
        3,
        4,
        5,
        6
      ],
      "defense": [
        3,
        4,
        5,
        6,
        7
      ],
      "healing": [
        2,
        3,
        4,
        5,
        6
      ],
      "logistics": [
        1,
        2,
        3,
        4,
        5
      ],
      "movement": [
        1,
        1,
        1,
        1,
        1
      ],
      "recon": [
        1,
        1,
        1,
        1,
        1
      ]
    },
    "enemy_attack_amount_by_gu_rank": {
      "1": 2,
      "2": 3,
      "3": 3,
      "4": 4,
      "5": 4
    }
  },
  "actions": {
    "accept": "接取",
    "ally": "结盟",
    "attempt_ascension": "冲击升仙",
    "buy_information": "购买情报",
    "buy": "买蛊",
    "claim": "占取",
    "exchange": "换物",
    "cross": "穿越",
    "deceive": "欺瞒",
    "fight": "交锋",
    "harvest": "采集",
    "inspect": "查验",
    "leave": "离开",
    "lure": "诱引",
    "meditate": "静修",
    "negotiate": "交涉",
    "open": "开启",
    "prepare": "筹备",
    "pressure": "施压",
    "probe": "试探",
    "retreat": "撤离",
    "rest": "歇息",
    "refine": "炼蛊",
    "cultivate": "冲击二转",
    "settle_feeding": "结清养护",
    "accept_debt": "欠下人情",
    "scout": "探查",
    "scheme": "设局",
    "take_imprint": "承受体印",
    "sell": "售物",
    "trade": "交易",
    "withdraw": "退回",
    "work": "做工"
  },
  "nodeTypes": {
    "contact": "接触",
    "refinement": "炼蛊",
    "cultivation": "修行",
    "ledger": "总账",
    "hazard": "险地",
    "inheritance": "传承",
    "wild_gu": "野蛊",
    "market": "市集",
    "caravan": "商队",
    "commission": "委托",
    "combat": "交锋",
    "pursuit": "追击",
    "earth_vein": "地脉",
    "seclusion": "静修",
    "shop": "黑市",
    "event": "异象",
    "ascension": "升仙"
  },
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
    "fightDamageBase": 1,
    "stoneRewards": {
      "base_by_tier": {
        "common": 3,
        "elite": 8,
        "boss": 15
      },
      "layer_step_pct": 20
    },
    "markScratchPerLayer": 1,
    "markScratchCap": 10
  },
  "mechanisms": {
    "covered": [
      {
        "name": "真实蛊实体",
        "detail": "77 只可在当前原型出现的蛊定义（基础白名单 + 战利品池 + V1 特殊效果样本 + 舍利/资质蛊）；舍利与资质蛊不进入战斗列表",
        "source": "data/gu.json（802 实体）+ 本轮 L0 要求的 lab-only 资质蛊"
      },
      {
        "name": "固定节点图与统一整备",
        "detail": "开局按难度生成固定五段分支图；每段准备深度为简单 15 / 普通 10 / 困难 5，只展示当前可走的 2–3 个后继；每场战斗胜利后进入同一整备页",
        "source": "本轮设计：docs/superpowers/specs/2026-09-20-wenzhen-web-run-flow-convergence-design.md"
      },
      {
        "name": "异闻节点与即时抉择",
        "detail": "每层非战斗模板池含 2 个异闻模板；seed 决定遇见的事件。只开放 6 条能由 Web 完整结算的事件，并按确定性牌序轮完后再重复；卡片展示气血代价/元石所得，可承受时收下、否则离开；同 seed 同难度仍生成相同节点图",
        "source": "data/nodes.json → echo_cave / gu_rot_pact；data/events.json → huajiu_cache / tithing_cache / duel_wager / sealed_silk_reliquary / unclaimed_waystone / ropewalk_wager；social_command_rules.gd 事件接受结算"
      },
      {
        "name": "跨局旧录与种子复走",
        "detail": "大厅单独保存最近 24 局结局、路线、摘要与种子；按原难度与种子开新局，同一内容版本下会生成相同地图。旧录与进行中存档分开；不还原当局结束前角色状态",
        "source": "js/lab_save.js → ARCHIVE_KEY / appendArchive；js/main.js → archiveRun / startRun(seedOverride)；js/journey.js → archiveRunCard"
      },
      {
        "name": "合炼与升炼配方",
        "detail": "Web 开放配方只投入蛊虫与配方标注的元石；判定用 run seed 与事件序号，失败销毁全部蛊虫投入",
        "source": "data/refinement_recipes.json（468 条，Web 只投影蛊虫/元石成本）；refine_command_rules.gd::_refinement_roll/_apply_fixed_recipe"
      },
      {
        "name": "蛊虫行动",
        "detail": "所有已炼化战斗蛊直接进入战斗可用列表，无固定槽位上限；每回合念头/行动数按魂魄分档，转数质量门禁、真元/念头成本、条件门禁、每回合一次限制与同流派支援按 Godot 解析器执行",
        "source": "data/gu.json → combat/true_qi_cost/thought_cost/v1_effect；action_points.gd::per_turn；cultivator_rules.gd::can_activate；v1_battle_resolver.gd::can_play_gu/play_gu；v1_grammar_pipeline.gd::gate_miss_reason"
      },
      {
        "name": "寿元、延迟、状态消费与意图弱化",
        "detail": "gu life_cost 在支付后结算，归零立即败北且本次效果不执行；delay 先付费后登记，到期回合重放；consume_status 要求至少一层并在命中后全额清除；weaken_intent 只降低目标下一次伤害意图并在消费或回合末归零",
        "source": "data/gu.json → life_cost/v1_effect.delay/v1_effect.consume_status/kind=weaken_intent；v1_battle_resolver.gd::_spend_costs/_apply_effect/_fire_delayed_effects/_resolve_enemy_intent/end_turn；v1_grammar_pipeline.gd::gate_miss_reason"
      },
      {
        "name": "野生蛊炼化",
        "detail": "开局带 2 只野生小光蛊；野生蛊不可催动；炼化按 rank 支付 4+2×(rank-1) 真元，成功后转为已炼化实例并可出战",
        "source": "run_opening_flow.gd::_inject_wild_starters；refine_command_rules.gd::_attune_gu；refine_snapshot.gd::attune_candidates"
      },
      {
        "name": "杀招组装与消耗",
        "detail": "5 个杀招的配方、真元/念头消耗、效果",
        "source": "data/v1_battle.json → kill_moves（26 条）"
      },
      {
        "name": "杀招配方与支援",
        "detail": "配方蛊封印门禁、配方实例本回合锁定，杀招效果吃同流派支援与剑意；额外 damage 独立结算",
        "source": "v1_battle_resolver.gd::play_kill_move/_apply_effect"
      },
      {
        "name": "真元上限与回复",
        "detail": "真元上限 = essence_base × aptitude_factor × cultivation_factor；战斗每回合按 v1 regen_pct 向上取整回复（丙等 25%）",
        "source": "data/aptitude.json；v1_battle_resolver.gd::_ceil_pct"
      },
      {
        "name": "战后恢复",
        "detail": "战斗胜利后真元回满，气血恢复最大气血的 30%；不设休整节点或调息按钮",
        "source": "本轮 L0 裁决"
      },
      {
        "name": "战后蛊虫与元石奖励",
        "detail": "按 tier+layer 读取蛊概率/稀有度权重及元石收益；常见蛊保底按事件序号推进",
        "source": "data/loot_tables.json；data/pacing.json；loot_resolver.gd::settle_victory"
      },
      {
        "name": "突破链",
        "detail": "每转四阶；小突破消耗元石或当前转数同阶舍利蛊，舍利不可越阶；巅峰冲下一转要求资质与元石同时达标。舍利系列按原著定位建转数：一转青铜 / 二转赤铁 / 三转白银 / 四转黄金 / 五转紫晶",
        "source": "本轮 L0 裁决；舍利转数依据 `蛊真人-clean.txt:86506`「从一转到五转，分别有青铜、赤铁、白银、黄金、紫晶舍利蛊」（另见 `:18066` `:18068`）；大突破元石成本沿用 balance；essence_capacity.gd"
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
        "name": "刻痕回合末结算",
        "detail": "敌方行动后，按存活敌人身上的 marked 层数结算独立伤害；不吃护盾、不衰减，层数按 mark_scratch_cap 截断",
        "source": "data/v1_battle.json mark_scratch_per_layer/mark_scratch_cap；v1_battle_resolver.gd::_settle_marks"
      },
      {
        "name": "剑意加成与衰减",
        "detail": "剑意上限 5，只加成剑道 strike，不吃自己的出招；回合末按 50% 向下取整衰减并跨回合保留",
        "source": "school_rules.gd::add_sword_intent/decay_sword_intent；v1_battle_resolver.gd::_apply_effect/end_turn"
      },
      {
        "name": "基础搏斗",
        "detail": "拳脚消耗 1 念头和 1 次行动，不耗真元；伤害 = fight_damage_base + force + yi_zhang",
        "source": "v1_battle_resolver.gd::basic_attack"
      },
      {
        "name": "敌方封印意图",
        "detail": "seal 意图按 turn % 候选蛊数量确定目标，封印状态按回合倒计时解除",
        "source": "data/enemies.json seal_turns；v1_battle_resolver.gd::_seal_random_gu/_start_player_turn"
      },
      {
        "name": "抽魂意图",
        "detail": "soul_drain 扣除玩家魂魄；魂魄归零立即败北，翌回合念头上限按剩余魂魄重新分档",
        "source": "v1_battle_resolver.gd::_resolve_enemy_intent/_check_player_death；action_points.gd::per_turn"
      },
      {
        "name": "多阶段 AI（阶段 + 冷却门禁）",
        "detail": "按 until_hp_ratio 切阶段；每阶段可有多条意图，第 T 回合发出后 T+cooldown+1 起才可再选；当前阶段所有意图都在冷却时显示 cooldown_wait、该回合不攻击",
        "source": "data/enemies.json 的 phases 与自带 _phases_note；本页按该语义独立实现检索台"
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
      },
      {
        "name": "坊市蛊虫货架",
        "detail": "按层显示 4–6 只蛊；同店确定性洗牌、最高档保底、流派蛊保底；购买按层价加价",
        "source": "data/shops.json → purchase；data/pacing.json → layers；shop_command_rules.gd::shop_stock/shop_slot_count/shop_layer_price"
      },
      {
        "name": "险地节点（探查 / 穿越 / 退回）",
        "detail": "固定图每层 3 个候选中确定性地换入 1 个险地节点（毒瘴山道 / 积水石窟 / 黑泥沼地；槽位与模板都由 seed 决定，同 seed 同难度同图）；探查与退回只记事实（route_scouted / withdrawn_safely），穿越消耗 1 点真元、真元不足则拒绝且不结算；解析后回统一整备，不做 on_skip 后果",
        "source": "data/nodes.json → toxic_mountain_path / flooded_cave / black_mud_marsh（choices 均为 scout/cross/withdraw）；social_command_rules.gd:768-771,801-803（标准行动转移）；action_preview_service.gd:1022-1028,1076-1077,1085-1087（预览门禁与文案）；display_text.gd:69,86,90（显示名）、228,238,242（行动结果文案）"
      },
      {
        "name": "非战斗节点的标准动作结算（险地 / 市集 / 野蛊）",
        "detail": "固定图每层 3 个候选中确定性地换入 1 个非战斗节点，模板池 = 险地 3 + 市集 2 + 野蛊 1 + 休整 2 + 静修 1 + 异闻 2 共 11 个模板（槽位与模板都由 seed 决定，同 seed 同难度同图）；节点动作页按模板 choices 出标准动作卡（choices 里未搬的动作不出卡），并按 Godot 口径总是补一张 leave 卡（离开遭遇）。已接入：work（元石 +3）/ harvest（元石 +2）/ buy_information 与 trade（门禁元石 ≥ 2，不足则拒绝且不结算；成功扣 2 并记事实 bought_information / bought_service）/ leave（记 route_left_behind）/ scout / cross（门禁真元 ≥ 1，成功扣 1）/ withdraw；静修的 meditate 见下条。被拒不结算，解析后进入统一整备",
        "source": "data/nodes.json → village_short_work / ridge_market / blood_moss_grove / rest_hollow / rest_shrine / body_imprint_ritual 与三个险地模板；social_command_rules.gd:747-803（转移；_resource_transition:814-821 的 before/after 语义、_spend_stone_for_fact:823-831、_fact_transition:881-887）；action_preview_service.gd:44-45,992-995,1022-1035,1043-1044,1114-1115,1119,1198-1208,1306-1309（卡片、门禁、文案与 remedy）；display_text.gd:226,230,232,238,241-243（行动结果）、503-505（被拒兜底）；data/names.json → types / actions 分区（节点与动作中文名）"
      },
      {
        "name": "恢复类节点（休整 / 静修）",
        "detail": "非战斗模板池加入休整（山壁石穴 / 古祠残龛）与静修（体印仪式）后，地图上第一次出现恢复气血与真元的途径。休整节点（type=rest）是一次收益门禁、两步交互：先取「歇脚恢复」（气血恢复 max(1, floor(上限×0.30))、真元 +2，均按各自上限截断；卡片显示按当前数值算出的真实恢复量），「离开休整」卡此时才解禁——未取收益时该卡禁用并显示门禁原文「休整抉择未定：须先选择恢复、强化或移除其一，才能离开。」；探访已消费后收益卡禁用（「本次休整已处置完毕。」），重复取收益被拒（rest_already_used）且状态不变，未取收益就想离开被拒（rest_choice_required）且状态不变。静修节点（type=seclusion）走标准动作：「静修」真元 +1（按真元上限截断），离开没有休整门禁（seclusion 不在 rest-class 名单内）",
        "source": "data/nodes.json → rest_hollow / rest_shrine / body_imprint_ritual；rest_rules.gd:22（REST_NODE_TYPE）、:27（REST_CLASS_TYPES，seclusion 不在其中）、:121-141（_rest_heal：气血/真元公式与 rest_recovered、<节点id>_used 标记）、:165-179（_consume_rest_visit 的旗标语义，本片未搬）；social_command_rules.gd:586-589 与 encounter_session_resolver.gd:121-126（未消费不许离开 → rest_choice_required）；action_preview_service.gd:746-808（node.rest_heal / node.leave 两张卡与文案）、:811-831（已消费卡禁用的 block_reason）；social_command_rules.gd:772-773（meditate 真元 +1）与 display_text.gd:76,234（静修显示名与结果文案）"
      }
    ],
    "notCovered": [
      {
        "name": "追击压力类动作（deceive / retreat）",
        "why": "效果落在 state.pursuit（social_command_rules.gd:774-777）；本原型没有追击压力槽，搬进来就是「声明了但没人读」的字段，按登记不实现"
      },
      {
        "name": "升仙条件类动作（open / prepare / scheme）",
        "why": "效果落在 state.ascension 的升仙五项（social_command_rules.gd:778-783）；本原型没有升仙窗口与终局资格判定，登记不实现"
      },
      {
        "name": "体印动作（take_imprint）",
        "why": "效果写入 body_imprints（social_command_rules.gd:784-794 的铁骨体印）；本原型没有体印系统，登记不实现。静修节点（体印仪式）的 choices 里有这条，但节点动作页不出这张卡——搬进来只会是禁用空按钮"
      },
      {
        "name": "只有单张蛊卡的强化、免费移除、印记与反噬（休整节点的另四种收益）",
        "why": "休整节点在 Godot 还有强化一张蛊卡（action_preview_service.gd:759-768）、移除一只蛊（:769-778）、抹除一枚印记（:779-788）、拔除一层反噬（:789-798）四个选项；本原型没有蛊卡强化、没有免费移除（蛊仓只有卖蛊返 50%）、没有印记/遗物、没有诅咒系统，搬进来就是空按钮，按登记不实现"
      },
      {
        "name": "休整跳过模式（rest mode=skip）",
        "why": "rest_rules.gd:89-103 的 _rest_skip 只在领域层可达（消费探访并落 rest_skipped），Godot 侧的休整卡集合（action_preview_service.gd:746-808）没有它的入口，故本片不搬；休整节点因此必须至少取一次收益才能离开"
      },
      {
        "name": "文案与实现漂移：休整收益卡的「恢复 2 点」",
        "why": "数据/表现漂移（登记，不修 Godot）：action_preview_service.gd:756 的 node.rest_heal 卡写死 expected_gain「恢复气血 2 点。/恢复真元 2 点。」，而 rest_rules.gd:129-131 的实际效果是「气血 +max(1, floor(上限×0.30))、真元 +2」。本页按真实数值显示（例：上限 24 点时恢复 7 点）"
      },
      {
        "name": "数据缺口：data/names.json → types 缺 rest 键",
        "why": "data/names.json 的 types 分区有 seclusion（静修）但没有 rest，而 Godot 侧的 scripts/presentation/display_text.gd:54 的 const TYPES 里 rest 是「休整」。本页类型名取 DATA.nodeTypes 优先、缺失时回退「休整」（来源 display_text.gd:54），回退表在 js/node_action_rules.js"
      },
      {
        "name": "只记事实、无消费点的动作（accept / ally / claim / inspect / lure 与 contact / caravan 专属动作）",
        "why": "这些动作只写 known_facts（social_command_rules.gd:795-800），而本原型对已知事实没有任何分支消费（见下面 knownFacts 一条）；contact 的 negotiate/deceive/retreat/fight 与 caravan 的 probe/buy/sell/exchange 还各自需要专属结算模块，一并登记不实现"
      },
      {
        "name": "炼蛊 / 修行节点的休息类门禁（rest-class 剩余部分）",
        "why": "rest_rules.gd:27 的 REST_CLASS_TYPES = [rest, refinement, cultivation]：rest 的那一份门禁已在本片搬入（见 covered 的恢复类节点），refinement / cultivation 两类节点本原型仍未接入（连节点带动作），其一次性门禁与 refine / cultivate 专属动作一并不搬"
      },
      {
        "name": "诅咒与延迟魂魄债异闻",
        "why": "异闻投影只开放即时气血代价与元石收益均能完整结算的 6 条事件；带 curse_id 或 delayed_soul_cost 的事件会进入 Web 事件池过滤。Web 尚无诅咒战斗效果和延迟魂债结算，暂不呈现这些选择"
      },
      {
        "name": "其余节点类型的专属结算",
        "why": "contact / caravan / refinement / cultivation / ledger / inheritance / commission / pursuit / earth_vein 等类型各有专属选项与命令面（商队、炼蛊、修行、总账、遗葬传承等）；Web 固定图当前采用战斗与六类非战斗模板（险地 / 市集 / 野蛊 / 休整 / 静修 / 异闻），其余类型未接入"
      },
      {
        "name": "非战斗槽位的类型分布与重复率",
        "why": "非战斗槽位每层仍为 1 个，11 个模板由 seed 确定性选择；各模板等权，异闻模板内部再选有效事件。路线重复率和事件出现频率尚未做长局实测，后续根据完整跑局证据调整内容密度"
      },
      {
        "name": "knownFacts 只写不读",
        "why": "本片与 slice-09 引入的 state.knownFacts 至今只被写入（scout / withdraw / leave / buy_information / trade），没有任何分支消费它；读取点只有 node_action_rules 的透传与 main.js 的事件日志。照实登记：这是「声明了但没人读」的状态槽，不要以为它已经在驱动玩法"
      },
      {
        "name": "精英代价绑定",
        "why": "elite 战利品表声明 backlash/notoriety cost_pool；本原型不继承恶名系统，也不伪造精英代价结算"
      },
      {
        "name": "Godot 服务型系统与动态难度",
        "why": "L0 裁决：除蛊方服务外，资源交换、寿元交易、以物易物、洗恶名、补魂丹、配方解锁与动态难度均不作为本原型目标；相关 Godot 实现仅保留为历史参照"
      },
      {
        "name": "意图选取顺序",
        "why": "数据未写明多意图之间的优先级（_phases_note 只定义了冷却门禁）。本页取\"数据顺序中第一条可用的\"，属原型设定，Godot 无实现可对照"
      },
      {
        "name": "族长阶段意图「家族征召」",
        "why": "数据条目为 damage 0 且无 essence_burn，Godot 行为语义未明确；沿用数据但不臆造额外效果，需补充规则来源后再扩展"
      },
      {
        "name": "魂魄成长与失控",
        "why": "本页已接魂魄行动分档、抽魂与魂魄归零死亡；魂魄收集、成长、狂暴和失控仍未实现"
      },
      {
        "name": "完整领域事件账本与角色状态回放",
        "why": "Web 具备进行中存档和跨局种子旧录；尚未实现 Godot 完整领域事件形状、结束前角色状态快照及精确局面回放"
      },
      {
        "name": "counter_status=\"sparked\"（雷冠头狼）",
        "why": "数据漂移：data/enemies.json 声明了该反击状态，但 scripts/ 与 docs/ 里零命中，规则层无实现语义。本页不臆造，已从反击列表剔除"
      },
      {
        "name": "险地节点的 on_skip",
        "why": "数据漂移：data/nodes.json 的险地模板声明了 on_skip（lose_route / lose_clue / gain_pursuit），但 scripts/ 里零命中，Godot 域层没有实现该字段。本页不臆造跳过后果，险地只结算 choices 里的三条 standard action。休整/静修模板也带 on_skip（rest 为 none；体印仪式为 lose_foundation），本页同样不结算——休整节点没有跳过入口（见上一条），静修节点也没有"
      },
      {
        "name": "线索的中文名",
        "why": "数据缺口：data/names.json 没有 clues 分区，敌人线索只有 id（stone_dust、steady_stance 等）；本页照原样显示 id，不自行译名"
      }
    ]
  },
  "contentVersion": "cf32f8085e5051fe702dfa9fbc4ab2377eaa2145c9b0589cea07387756629fb3"
};
