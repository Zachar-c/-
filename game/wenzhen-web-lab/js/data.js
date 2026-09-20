// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。
// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。
const DATA = {
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
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "ridge_elite_scout"
        ],
        "boss": [
          "crag_serpent_matriarch"
        ]
      },
      "2": {
        "battle": [
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "ridge_elite_scout",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "marrow_gu_adept"
        ]
      },
      "3": {
        "battle": [
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "ridge_elite_scout",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "thunder_crown_sovereign"
        ]
      },
      "4": {
        "battle": [
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "ridge_elite_scout",
          "demon_path_adept",
          "thunder_crown_wolf"
        ],
        "boss": [
          "blood_vein_bishop"
        ]
      },
      "5": {
        "battle": [
          "neutral_stone_wanderer",
          "ridge_hound",
          "iron_hide_boar"
        ],
        "elite": [
          "faction_guard",
          "ridge_elite_scout",
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
        "material_count": 1,
        "material_pool": [
          "beast_blood",
          "beast_bone",
          "moon_blue_petal",
          {
            "id": "mat_blood_1",
            "weight": 3
          },
          {
            "id": "mat_bone_1",
            "weight": 3
          },
          {
            "id": "mat_dream_1",
            "weight": 3
          },
          {
            "id": "mat_earth_1",
            "weight": 3
          },
          {
            "id": "mat_fire_1",
            "weight": 3
          },
          {
            "id": "mat_force_1",
            "weight": 3
          },
          {
            "id": "mat_gold_1",
            "weight": 3
          },
          {
            "id": "mat_heaven_1",
            "weight": 3
          },
          {
            "id": "mat_human_1",
            "weight": 3
          },
          {
            "id": "mat_luck_1",
            "weight": 3
          },
          {
            "id": "mat_qi_1",
            "weight": 3
          },
          {
            "id": "mat_refine_1",
            "weight": 3
          },
          {
            "id": "mat_slave_1",
            "weight": 3
          },
          {
            "id": "mat_soul_1",
            "weight": 3
          },
          {
            "id": "mat_sword_1",
            "weight": 3
          },
          {
            "id": "mat_water_1",
            "weight": 3
          },
          {
            "id": "mat_wind_1",
            "weight": 3
          },
          {
            "id": "mat_wisdom_1",
            "weight": 3
          },
          {
            "id": "mat_wood_1",
            "weight": 3
          }
        ],
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
        "material_count": 1,
        "material_pool": [
          "beast_blood",
          "beast_bone",
          "venom_sac",
          {
            "id": "mat_blood_2",
            "weight": 3
          },
          {
            "id": "mat_dream_2",
            "weight": 3
          },
          {
            "id": "mat_earth_2",
            "weight": 3
          },
          {
            "id": "mat_fire_2",
            "weight": 3
          },
          {
            "id": "mat_force_2",
            "weight": 3
          },
          {
            "id": "mat_gold_2",
            "weight": 3
          },
          {
            "id": "mat_heaven_2",
            "weight": 3
          },
          {
            "id": "mat_human_2",
            "weight": 3
          },
          {
            "id": "mat_luck_2",
            "weight": 3
          },
          {
            "id": "mat_qi_2",
            "weight": 3
          },
          {
            "id": "mat_refine_2",
            "weight": 3
          },
          {
            "id": "mat_slave_2",
            "weight": 3
          },
          {
            "id": "mat_soul_2",
            "weight": 3
          },
          {
            "id": "mat_sword_2",
            "weight": 3
          },
          {
            "id": "mat_water_2",
            "weight": 3
          },
          {
            "id": "mat_wind_2",
            "weight": 3
          },
          {
            "id": "mat_wisdom_2",
            "weight": 3
          },
          {
            "id": "mat_wood_2",
            "weight": 3
          },
          {
            "id": "mat_blood_3",
            "weight": 1
          },
          {
            "id": "mat_dream_3",
            "weight": 1
          },
          {
            "id": "mat_earth_3",
            "weight": 1
          },
          {
            "id": "mat_fire_3",
            "weight": 1
          },
          {
            "id": "mat_force_3",
            "weight": 1
          },
          {
            "id": "mat_gold_3",
            "weight": 1
          },
          {
            "id": "mat_heaven_3",
            "weight": 1
          },
          {
            "id": "mat_human_3",
            "weight": 1
          },
          {
            "id": "mat_luck_3",
            "weight": 1
          },
          {
            "id": "mat_qi_3",
            "weight": 1
          },
          {
            "id": "mat_refine_3",
            "weight": 1
          },
          {
            "id": "mat_slave_3",
            "weight": 1
          },
          {
            "id": "mat_soul_3",
            "weight": 1
          },
          {
            "id": "mat_sword_3",
            "weight": 1
          },
          {
            "id": "mat_water_3",
            "weight": 1
          },
          {
            "id": "mat_wind_3",
            "weight": 1
          },
          {
            "id": "mat_wisdom_3",
            "weight": 1
          },
          {
            "id": "mat_wood_3",
            "weight": 1
          }
        ],
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
        "material_count": 2,
        "material_pool": [
          "beast_blood",
          "beast_bone",
          "venom_sac",
          "moon_dew",
          {
            "id": "mat_blood_3",
            "weight": 2
          },
          {
            "id": "mat_dream_3",
            "weight": 2
          },
          {
            "id": "mat_earth_3",
            "weight": 2
          },
          {
            "id": "mat_fire_3",
            "weight": 2
          },
          {
            "id": "mat_force_3",
            "weight": 2
          },
          {
            "id": "mat_gold_3",
            "weight": 2
          },
          {
            "id": "mat_heaven_3",
            "weight": 2
          },
          {
            "id": "mat_human_3",
            "weight": 2
          },
          {
            "id": "mat_luck_3",
            "weight": 2
          },
          {
            "id": "mat_qi_3",
            "weight": 2
          },
          {
            "id": "mat_refine_3",
            "weight": 2
          },
          {
            "id": "mat_slave_3",
            "weight": 2
          },
          {
            "id": "mat_soul_3",
            "weight": 2
          },
          {
            "id": "mat_sword_3",
            "weight": 2
          },
          {
            "id": "mat_water_3",
            "weight": 2
          },
          {
            "id": "mat_wind_3",
            "weight": 2
          },
          {
            "id": "mat_wisdom_3",
            "weight": 2
          },
          {
            "id": "mat_wood_3",
            "weight": 2
          },
          {
            "id": "mat_blood_4",
            "weight": 3
          },
          {
            "id": "mat_dream_4",
            "weight": 3
          },
          {
            "id": "mat_earth_4",
            "weight": 3
          },
          {
            "id": "mat_fire_4",
            "weight": 3
          },
          {
            "id": "mat_force_4",
            "weight": 3
          },
          {
            "id": "mat_gold_4",
            "weight": 3
          },
          {
            "id": "mat_heaven_4",
            "weight": 3
          },
          {
            "id": "mat_human_4",
            "weight": 3
          },
          {
            "id": "mat_luck_4",
            "weight": 3
          },
          {
            "id": "mat_qi_4",
            "weight": 3
          },
          {
            "id": "mat_refine_4",
            "weight": 3
          },
          {
            "id": "mat_slave_4",
            "weight": 3
          },
          {
            "id": "mat_soul_4",
            "weight": 3
          },
          {
            "id": "mat_sword_4",
            "weight": 3
          },
          {
            "id": "mat_water_4",
            "weight": 3
          },
          {
            "id": "mat_wind_4",
            "weight": 3
          },
          {
            "id": "mat_wisdom_4",
            "weight": 3
          },
          {
            "id": "mat_wood_4",
            "weight": 3
          }
        ],
        "gu_chance_pct": 55,
        "gu_pool": {
          "weights": {},
          "by_rarity": {}
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
      ],
      "material_pity": {
        "threshold": 3,
        "target_bands_by_tier": {
          "common": [
            "crude"
          ],
          "elite": [
            "plain",
            "refined"
          ],
          "boss": [
            "prized"
          ]
        },
        "note": "P2-a（R-3 校准）：目标派系化——本派 promotion 链路材料中、该 tier 池声明且带段在允许集内的条目。硬限：只补池内已定义存在的目标带段，不跨 tier 拉取、不凭空生成。Reachability-3（2026-09-13 裁定）：保底计数按 tier 独立（state.material_pity_by_tier：common→f1、elite→f2/f3、boss→f4），其他带段掉落对计数零影响。带段→f 段映射 provisional（F8 校准）。"
      }
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
          "material_count": 2,
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
          "material_count": 2,
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
          "material_count": 3,
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
          "material_count": 3,
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
          "material_count": 4,
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
    "schoolMaterialResonance": 5,
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
    "materialPityTargetsByTier": {
      "common": [
        "beast_bone"
      ],
      "elite": [
        "venom_sac"
      ],
      "boss": []
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
      "school": "light",
      "value": 4,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 3
      },
      "icon": "gu_moon",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 3
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
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
      "icon": "gu_light",
      "combat": "reveal_hidden_bonus",
      "battleEffect": {
        "kind": "strike",
        "amount": 1,
        "support_school": "light",
        "support_bonus": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
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
      "labOnly": false
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
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_force",
      "combat": "white_boar_strength",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 1,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
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
      "labOnly": false
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
      "labOnly": false
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
        "kind": "shield",
        "amount": 4
      },
      "icon": "gu_water",
      "combat": "white_jade_form",
      "battleEffect": {
        "kind": "shield",
        "amount": 4
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
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
      "labOnly": false
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
      "labOnly": false
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
      "icon": "gu_qi",
      "combat": "vitality_grass_remedy",
      "battleEffect": {
        "kind": "heal",
        "amount": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
    },
    {
      "id": "sword_atk_1_06_gu",
      "name": "刃蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "sword_atk_1_05_gu",
      "name": "锋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "sword_rec_1_10_gu",
      "name": "青锋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "qi_atk_1_01_gu",
      "name": "硬气蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "school": "qi",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "qi_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
    },
    {
      "id": "qi_rec_2_14_gu",
      "name": "霭蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
      "school": "qi",
      "value": 5,
      "cost": 0,
      "effect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "qi",
        "support_bonus": 1
      },
      "icon": "gu_qi",
      "combat": "qi_recon_pattern",
      "battleEffect": {
        "kind": "status",
        "name": "marked",
        "amount": 1,
        "support_school": "qi",
        "support_bonus": 1
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
    },
    {
      "id": "wood_atk_1_05_gu",
      "name": "青藤蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "water_atk_1_08_gu",
      "name": "浪蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "moon_shadow_gu",
      "name": "月影蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "movement",
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
      "labOnly": false
    },
    {
      "id": "blood_heal_2_23_gu",
      "name": "血针蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_2_11_gu",
      "name": "赤铁舍利蛊",
      "rank": 2,
      "rarity": "common",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_2_12_gu",
      "name": "青铜舍利蛊",
      "rank": 2,
      "rarity": "common",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_3_13_gu",
      "name": "白银舍利蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_4_14_gu",
      "name": "黄金舍利蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_5_15_gu",
      "name": "紫晶舍利蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "gold_atk_2_16_gu",
      "name": "舍利蛊",
      "rank": 2,
      "rarity": "common",
      "role": "support",
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
      "labOnly": false
    },
    {
      "id": "bone_atk_1_08_gu",
      "name": "骨蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "human_atk_1_01_gu",
      "name": "自己蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
      "school": "human",
      "value": 3,
      "cost": 0,
      "effect": {
        "kind": "strike",
        "amount": 2
      },
      "icon": "gu_qi",
      "combat": "human_attack_pattern",
      "battleEffect": {
        "kind": "strike",
        "amount": 2
      },
      "trueQiCost": 0,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
    },
    {
      "id": "sword_atk_2_12_gu",
      "name": "古剑蛊",
      "rank": 2,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "sword_def_3_14_gu",
      "name": "软剑蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "defense",
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
      "labOnly": false
    },
    {
      "id": "sword_heal_4_16_gu",
      "name": "双剑蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "sword_atk_5_02_gu",
      "name": "飞剑蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "blood_atk_5_02_gu",
      "name": "血手印蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "fire_atk_2_01_gu",
      "name": "鬼火蛊",
      "rank": 2,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "water_atk_3_05_gu",
      "name": "雨蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "wisdom_rec_1_20_gu",
      "name": "灵感蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "wisdom_atk_3_13_gu",
      "name": "才华蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "wind_atk_1_02_gu",
      "name": "狂风蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "force_gu",
      "name": "力量蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "moon_ray_gu",
      "name": "月痕蛊",
      "rank": 2,
      "rarity": "rare",
      "role": "attack",
      "school": "light",
      "value": 10,
      "cost": 2,
      "effect": {
        "kind": "strike",
        "amount": 4
      },
      "icon": "gu_light",
      "combat": "moonlight_strike",
      "battleEffect": {
        "kind": "strike",
        "amount": 4
      },
      "trueQiCost": 2,
      "thoughtCost": 1,
      "lowRankException": false,
      "lifeCost": 0,
      "labOnly": false
    },
    {
      "id": "bear_strength_gu",
      "name": "熊力蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "blood_bat_gu",
      "name": "刀翅血蝠蛊",
      "rank": 1,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "force_atk_4_02_gu",
      "name": "苦力蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_1_01_gu",
      "name": "月旋蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_3_02_gu",
      "name": "邀月蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_5_03_gu",
      "name": "太光蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_1_04_gu",
      "name": "光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_3_05_gu",
      "name": "月蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_1_06_gu",
      "name": "星光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_rec_3_07_gu",
      "name": "星芽蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_rec_5_08_gu",
      "name": "星河蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_rec_3_09_gu",
      "name": "星萤蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_rec_1_10_gu",
      "name": "明星蛊",
      "rank": 1,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_rec_5_11_gu",
      "name": "星眸蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_rec_5_12_gu",
      "name": "星念蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_atk_1_13_gu",
      "name": "辉蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_1_14_gu",
      "name": "曜蛊",
      "rank": 1,
      "rarity": "common",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_def_1_15_gu",
      "name": "曦蛊",
      "rank": 1,
      "rarity": "common",
      "role": "defense",
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
      "labOnly": false
    },
    {
      "id": "light_mov_1_16_gu",
      "name": "旭蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
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
      "labOnly": false
    },
    {
      "id": "light_heal_2_17_gu",
      "name": "晨蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "light_rec_2_18_gu",
      "name": "晞蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_log_3_19_gu",
      "name": "晶蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
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
      "labOnly": false
    },
    {
      "id": "light_atk_3_20_gu",
      "name": "莹蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_4_21_gu",
      "name": "皎蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_def_5_22_gu",
      "name": "皓蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "defense",
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
      "labOnly": false
    },
    {
      "id": "light_mov_1_23_gu",
      "name": "朗蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
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
      "labOnly": false
    },
    {
      "id": "light_heal_2_24_gu",
      "name": "焕蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "light_rec_2_25_gu",
      "name": "熠蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_log_3_26_gu",
      "name": "熹蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
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
      "labOnly": false
    },
    {
      "id": "light_atk_3_27_gu",
      "name": "闪蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_atk_4_28_gu",
      "name": "耀蛊",
      "rank": 4,
      "rarity": "epic",
      "role": "attack",
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
      "labOnly": false
    },
    {
      "id": "light_def_5_29_gu",
      "name": "流光蛊",
      "rank": 5,
      "rarity": "epic",
      "role": "defense",
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
      "labOnly": false
    },
    {
      "id": "light_mov_1_30_gu",
      "name": "折光蛊",
      "rank": 1,
      "rarity": "common",
      "role": "movement",
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
      "labOnly": false
    },
    {
      "id": "light_heal_2_31_gu",
      "name": "烛光蛊",
      "rank": 2,
      "rarity": "common",
      "role": "healing",
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
      "labOnly": false
    },
    {
      "id": "light_rec_2_32_gu",
      "name": "萤光蛊",
      "rank": 2,
      "rarity": "common",
      "role": "recon",
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
      "labOnly": false
    },
    {
      "id": "light_log_3_33_gu",
      "name": "光辉蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "logistics",
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
      "labOnly": false
    },
    {
      "id": "light_atk_3_34_gu",
      "name": "光曜蛊",
      "rank": 3,
      "rarity": "rare",
      "role": "attack",
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
      "labOnly": false
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
      "source": "蛊真人-clean.txt 17024-17155：月芒蛊=月光蛊x1+小光蛊x2（合炼失败代价示例：小光蛊消亡）",
      "successRollMax": 100
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
      "source": "蛊真人-clean.txt 15860-15895：白玉蛊=白豕蛊+玉皮蛊，添头野猪王雪獠牙（后世改良，提高成功率）",
      "successRollMax": 100
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
      "source": "蛊真人-clean.txt 17140-17155：月光蛊晋升路线之一（月光蛊x1+小光蛊x1→月芒蛊）",
      "successRollMax": 100
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
      "source": "蛊真人-clean.txt 15860-15895：白玉蛊=白豕蛊+玉皮蛊",
      "successRollMax": 100
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
      "source": null,
      "successRollMax": 100
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
      "source": null,
      "successRollMax": 100
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
    },
    {
      "id": "km_sword_double_edge_1",
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
      "tier": "common",
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
      "tier": "common",
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
      "intent": {
        "id": "marrow_lance",
        "label": "蚀骨骨矛",
        "damage": 3,
        "speed": 2
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
      "intent": {
        "id": "swift_crossbow",
        "label": "弩箭上弦",
        "damage": 3,
        "speed": 3
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
      "id": "miasma_vein_lord",
      "name": "瘴脉蛊主",
      "rank": 3,
      "hp": 14,
      "theme": "anomaly",
      "tier": "boss",
      "intent": {
        "id": "miasma_burst",
        "label": "瘴气喷涌",
        "damage": 2,
        "speed": 1
      },
      "portrait": "enemy_toad",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "miasma_burst",
              "label": "瘴气喷涌",
              "damage": 2,
              "speed": 1,
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
        },
        {
          "until_hp_ratio": 0.5,
          "intents": [
            {
              "id": "miasma_burst",
              "label": "瘴气喷涌",
              "damage": 2,
              "speed": 1,
              "cooldown": 2
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
      "id": "clan_patriarch",
      "name": "族长",
      "rank": 5,
      "hp": 19,
      "theme": "faction",
      "tier": "boss",
      "intent": {
        "id": "clan_wrath",
        "label": "一族之威",
        "damage": 4,
        "speed": 2,
        "cooldown": 1
      },
      "portrait": "enemy_sanxiu",
      "phases": [
        {
          "until_hp_ratio": 1,
          "intents": [
            {
              "id": "clan_wrath",
              "label": "一族之威",
              "damage": 4,
              "speed": 2,
              "cooldown": 1
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
              "cooldown": 1
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
      "intent": {
        "id": "corpse_tide",
        "label": "尸潮掩杀",
        "damage": 4,
        "speed": 2,
        "cooldown": 1
      },
      "portrait": "enemy_centipede",
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
      "id": "demon_path_adept",
      "name": "魔道蛊师",
      "rank": 3,
      "hp": 7,
      "theme": "cultivator",
      "tier": "elite",
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
      "tier": "boss",
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
    },
    {
      "id": "faction_guard",
      "name": "势力守卫",
      "rank": 2,
      "hp": 6,
      "theme": "faction",
      "tier": "elite",
      "intent": {
        "id": "shield_bash",
        "label": "盾墙冲撞",
        "damage": 3,
        "speed": 3
      },
      "portrait": "enemy_sanxiu",
      "phases": null,
      "phasesNote": null,
      "clues": [
        "locked_shieldwall",
        "even_line"
      ],
      "reactions": []
    }
  ],
  "encounters": [
    {
      "id": "layer_boss_stand_1",
      "name": "崖蟒主母",
      "stage": "one",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "crag_serpent_matriarch",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 1,
      "layer": 1
    },
    {
      "id": "layer_boss_stand_2",
      "name": "蚀骨蛊师",
      "stage": "two",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "marrow_gu_adept",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 2,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_3",
      "name": "雷冠狼王",
      "stage": "three",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_sovereign",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "thunder_crown_sovereign",
        "clan_patriarch"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 3,
      "layer": 3
    },
    {
      "id": "layer_boss_stand_4",
      "name": "血络主教",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": 4,
      "layer": 4
    },
    {
      "id": "beast_swarm_pass",
      "name": "兽群隘口",
      "stage": "one",
      "type": "combat",
      "summary": "兽群堵住窄隘，击退它们可收取材料，撤退则必须改道。",
      "choices": [
        "fight",
        "retreat",
        "lure"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove"
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "final_boss_stand",
      "name": "瘴脉蛊主",
      "stage": "five",
      "type": "combat",
      "summary": "瘴脉尽头，蛊主把守升仙窗口。",
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
      "layerBoss": 5,
      "layer": 5
    },
    {
      "id": "iron_hide_ambush",
      "name": "铁皮山猪",
      "stage": "one",
      "type": "combat",
      "summary": "铁皮野猪拦在隘口，獠牙泛光，撞上来就是一道血口。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "scout_crossing_raid",
      "name": "山脊悍客",
      "stage": "three",
      "type": "combat",
      "summary": "斥候在岭脊设伏，弩机已上弦，先手藏在草丛里。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "wolf_pack_trail",
      "name": "雷冠头狼",
      "stage": "five",
      "type": "combat",
      "summary": "雷冠狼独踞道中，爪下电纹明灭，是兽群头狼。",
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
      "layerBoss": null,
      "layer": null
    }
  ],
  "nodes": [
    {
      "id": "neutral_wanderer",
      "name": "中立散修",
      "stage": "one",
      "type": "contact",
      "summary": "一名散修拦在岔路前，正试探你的虚实。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_caravan",
      "name": "山脊商队",
      "stage": "one",
      "type": "caravan",
      "summary": "山脊商队临时开市，可买卖或以蛊换蛊。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "refinement_hollow",
      "name": "炼蛊石穴",
      "stage": "one",
      "type": "refinement",
      "summary": "石穴余火未熄，可以冒险炼蛊。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "cultivation_spring",
      "name": "修行山泉",
      "stage": "one",
      "type": "cultivation",
      "summary": "山泉元气平稳，是冲击二转的短暂窗口。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "stage_one_ledger",
      "name": "第一阶段养蛊总账",
      "stage": "one",
      "type": "ledger",
      "summary": "第一阶段结束，所有已养蛊虫的养护开支需要一并结清。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "toxic_mountain_path",
      "name": "毒瘴山道",
      "stage": "one",
      "type": "hazard",
      "summary": "毒瘴沿山口沉降。谨慎侦察可避开消耗，强行穿越能节省时间。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "flooded_cave",
      "name": "积水石窟",
      "stage": "one",
      "type": "hazard",
      "summary": "暗河倒灌石洞，水声中有蛊虫振翅。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "black_mud_marsh",
      "name": "黑泥沼地",
      "stage": "three",
      "type": "hazard",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "moonlit_trail",
      "name": "月下小径",
      "stage": "one",
      "type": "inheritance",
      "summary": "月色下留有残缺传承痕迹，可能带来蛊方线索，也可能引来竞争者。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "blood_moss_grove",
      "name": "血苔林",
      "stage": "two",
      "type": "wild_gu",
      "summary": "血苔丛中藏着疗伤蛊与采集者，收益和伤势风险并存。",
      "choices": [
        "harvest",
        "trade",
        "leave"
      ],
      "nextIds": [
        "body_imprint_ritual"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "mist_shrine",
      "name": "雾隐祠",
      "stage": "four",
      "type": "inheritance",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "village_short_work",
      "name": "山村短工",
      "stage": "one",
      "type": "market",
      "summary": "山民寨子缺人守夜。短工给元石，交易则能换取情报。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_black_market",
      "name": "山脊黑市",
      "stage": "two",
      "type": "shop",
      "summary": "收摊前的黑市只认元石，摊主不问货物来历。",
      "choices": [],
      "nextIds": [
        "stage_one_ledger"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "ridge_extortionist",
      "eventId": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_1",
      "name": "崖蟒主母",
      "stage": "one",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "crag_serpent_matriarch",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 1,
      "layer": 1
    },
    {
      "id": "layer_boss_stand_2",
      "name": "蚀骨蛊师",
      "stage": "two",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "marrow_gu_adept",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 2,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_3",
      "name": "雷冠狼王",
      "stage": "three",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_sovereign",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "thunder_crown_sovereign",
        "clan_patriarch"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 3,
      "layer": 3
    },
    {
      "id": "layer_boss_stand_4",
      "name": "血络主教",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": 4,
      "layer": 4
    },
    {
      "id": "echo_cave",
      "name": "回声石洞",
      "stage": "two",
      "type": "event",
      "summary": "石壁上刻着旧痕，岩缝里的应答不知是谁留下的。",
      "choices": [],
      "nextIds": [
        "blood_moss_grove",
        "gu_rot_pact"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": null,
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "gu_rot_pact",
      "name": "异闻未死",
      "stage": "two",
      "type": "event",
      "summary": "异闻未死，风里带着一股说不清的代价味。",
      "choices": [],
      "nextIds": [],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": null,
      "eventId": "gu_rot_pact",
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "ridge_market",
      "name": "山脊市集",
      "stage": "one",
      "type": "market",
      "summary": "临时寨市接近收摊，能补资源，但会失去深入山路的时间。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "caravan_missing_goods",
      "name": "商队失货",
      "stage": "three",
      "type": "caravan",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "wandering_peddler",
      "name": "石甲散修",
      "stage": "one",
      "type": "contact",
      "summary": "一名货郎守着货担歇脚，担中蛊虫明码标价，也收以物易物。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "herbalist_commission",
      "name": "药师委托",
      "stage": "four",
      "type": "commission",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "beast_swarm_pass",
      "name": "兽群隘口",
      "stage": "one",
      "type": "combat",
      "summary": "兽群堵住窄隘，击退它们可收取材料，撤退则必须改道。",
      "choices": [
        "fight",
        "retreat",
        "lure"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove"
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
      "layerBoss": null,
      "layer": 1
    },
    {
      "id": "greedy_wanderer",
      "name": "贪客拦路",
      "stage": "one",
      "type": "pursuit",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": null,
      "layer": 4
    },
    {
      "id": "earth_vein_contest",
      "name": "地脉之争",
      "stage": "four",
      "type": "earth_vein",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "sealed_earth_vein",
      "name": "封存地脉",
      "stage": "four",
      "type": "earth_vein",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "poison_fog_vein",
      "name": "毒雾地脉",
      "stage": "five",
      "type": "earth_vein",
      "summary": "",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "final_boss_stand",
      "name": "瘴脉蛊主",
      "stage": "five",
      "type": "combat",
      "summary": "瘴脉尽头，蛊主把守升仙窗口。",
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
      "layerBoss": 5,
      "layer": 5
    },
    {
      "id": "rest_hollow",
      "name": "山壁石穴",
      "stage": "two",
      "type": "rest",
      "summary": "山壁石穴，落潮前的安静片刻，可稍作歇息恢复气血与真元。",
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
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "rest_shrine",
      "name": "古祠残龛",
      "stage": "two",
      "type": "rest",
      "summary": "古祠残龛，香火断绝后的清净角落，可稍作歇息恢复气血与真元。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "body_imprint_ritual",
      "name": "体印仪式",
      "stage": "one",
      "type": "seclusion",
      "summary": "石壁留有淬体仪式。可稳固根基，也可能留下难以察觉的代价。",
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
      "layerBoss": null,
      "layer": null
    },
    {
      "id": "iron_hide_ambush",
      "name": "铁皮山猪",
      "stage": "one",
      "type": "combat",
      "summary": "铁皮野猪拦在隘口，獠牙泛光，撞上来就是一道血口。",
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
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "scout_crossing_raid",
      "name": "山脊悍客",
      "stage": "three",
      "type": "combat",
      "summary": "斥候在岭脊设伏，弩机已上弦，先手藏在草丛里。",
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
      "layerBoss": null,
      "layer": 3
    },
    {
      "id": "wolf_pack_trail",
      "name": "雷冠头狼",
      "stage": "five",
      "type": "combat",
      "summary": "雷冠狼独踞道中，爪下电纹明灭，是兽群头狼。",
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
      "layerBoss": null,
      "layer": 5
    },
    {
      "id": "yizang_ridge",
      "name": "荒岭间一座前人遗葬",
      "stage": "one",
      "type": "inheritance",
      "summary": "荒岭间一座前人遗葬，草木倒伏成环。有传承者遗留的布置仍在运转。",
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
      "summary": "兽群堵住窄隘，击退它们可收取材料，撤退则必须改道。",
      "choices": [
        "fight",
        "retreat",
        "lure"
      ],
      "nextIds": [
        "toxic_mountain_path",
        "blood_moss_grove"
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
      "layerBoss": null,
      "layer": 1
    },
    {
      "id": "layer_boss_stand_1",
      "name": "崖蟒主母",
      "stage": "one",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "crag_serpent_matriarch",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "crag_serpent_matriarch",
        "marrow_gu_adept"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 1,
      "layer": 1
    },
    {
      "id": "rest_hollow",
      "name": "山壁石穴",
      "stage": "two",
      "type": "rest",
      "summary": "山壁石穴，落潮前的安静片刻，可稍作歇息恢复气血与真元。",
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
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "iron_hide_ambush",
      "name": "铁皮山猪",
      "stage": "one",
      "type": "combat",
      "summary": "铁皮野猪拦在隘口，獠牙泛光，撞上来就是一道血口。",
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
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "ridge_black_market",
      "name": "山脊黑市",
      "stage": "two",
      "type": "shop",
      "summary": "收摊前的黑市只认元石，摊主不问货物来历。",
      "choices": [],
      "nextIds": [
        "stage_one_ledger"
      ],
      "enemyKind": null,
      "enemyKinds": null,
      "enemyTheme": null,
      "bossPool": null,
      "npcId": "ridge_extortionist",
      "eventId": null,
      "layerBoss": null,
      "layer": 2
    },
    {
      "id": "layer_boss_stand_2",
      "name": "蚀骨蛊师",
      "stage": "two",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "marrow_gu_adept",
      "enemyKinds": null,
      "enemyTheme": "cultivator",
      "bossPool": [
        "marrow_gu_adept",
        "thunder_crown_sovereign"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 2,
      "layer": 2
    },
    {
      "id": "scout_crossing_raid",
      "name": "山脊悍客",
      "stage": "three",
      "type": "combat",
      "summary": "斥候在岭脊设伏，弩机已上弦，先手藏在草丛里。",
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
      "layerBoss": null,
      "layer": 3
    },
    {
      "id": "layer_boss_stand_3",
      "name": "雷冠狼王",
      "stage": "three",
      "type": "combat",
      "summary": "",
      "choices": [
        "fight"
      ],
      "nextIds": [],
      "enemyKind": "thunder_crown_sovereign",
      "enemyKinds": null,
      "enemyTheme": "beast",
      "bossPool": [
        "thunder_crown_sovereign",
        "clan_patriarch"
      ],
      "npcId": null,
      "eventId": null,
      "layerBoss": 3,
      "layer": 3
    },
    {
      "id": "faction_guard_checkpoint",
      "name": "势力关卡",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": null,
      "layer": 4
    },
    {
      "id": "layer_boss_stand_4",
      "name": "血络主教",
      "stage": "four",
      "type": "combat",
      "summary": "",
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
      "layerBoss": 4,
      "layer": 4
    },
    {
      "id": "wolf_pack_trail",
      "name": "雷冠头狼",
      "stage": "five",
      "type": "combat",
      "summary": "雷冠狼独踞道中，爪下电纹明灭，是兽群头狼。",
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
      "layerBoss": null,
      "layer": 5
    },
    {
      "id": "final_boss_stand",
      "name": "瘴脉蛊主",
      "stage": "five",
      "type": "combat",
      "summary": "瘴脉尽头，蛊主把守升仙窗口。",
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
      "id": "purchase_moon_blue_petal",
      "kind": "material_purchase",
      "card_key": "purchase.moon_blue_petal",
      "material_id": "moon_blue_petal",
      "stone_cost": 3,
      "tier": 1,
      "gu_name": ""
    },
    {
      "id": "purchase_boar_king_tusk",
      "kind": "material_purchase",
      "card_key": "purchase.boar_king_tusk",
      "material_id": "boar_king_tusk",
      "stone_cost": 10,
      "tier": 1,
      "gu_name": ""
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
      "id": "purchase_inheritance_token",
      "kind": "material_purchase",
      "card_key": "purchase.inheritance_token",
      "material_id": "inheritance_token",
      "stone_cost": 60,
      "tier": 2,
      "gu_name": ""
    },
    {
      "id": "gu_fang_moon_glow_gu",
      "kind": "gu_fang_unlock",
      "card_key": "gu_fang.moon_glow_gu",
      "gu_id": "moon_glow_gu",
      "stone_cost": 80,
      "tier": 2,
      "clue": "古方：持方即知产物，免未知损失。",
      "gu_name": "月芒蛊"
    },
    {
      "id": "gu_fang_white_jade_gu",
      "kind": "gu_fang_unlock",
      "card_key": "gu_fang.white_jade_gu",
      "gu_id": "white_jade_gu",
      "stone_cost": 80,
      "tier": 2,
      "clue": "古方：持方即知产物，免未知损失。",
      "gu_name": "白玉蛊"
    },
    {
      "id": "gu_fang_blood_heal_2_23_gu",
      "kind": "gu_fang_unlock",
      "card_key": "gu_fang.blood_heal_2_23_gu",
      "gu_id": "blood_heal_2_23_gu",
      "stone_cost": 80,
      "tier": 2,
      "clue": "古方：持方即知产物，免未知损失。",
      "gu_name": "血针蛊"
    },
    {
      "id": "gu_fang_blood_atk_3_03_gu",
      "kind": "gu_fang_unlock",
      "card_key": "gu_fang.blood_atk_3_03_gu",
      "gu_id": "blood_atk_3_03_gu",
      "stone_cost": 200,
      "tier": 3,
      "clue": "古方：持方即知产物，免未知损失。",
      "gu_name": "血气蛊"
    },
    {
      "id": "gu_fang_blood_atk_3_11_gu",
      "kind": "gu_fang_unlock",
      "card_key": "gu_fang.blood_atk_3_11_gu",
      "gu_id": "blood_atk_3_11_gu",
      "stone_cost": 200,
      "tier": 3,
      "clue": "古方：持方即知产物，免未知损失。",
      "gu_name": "血月蛊"
    },
    {
      "id": "purchase_sword_atk_1_06",
      "kind": "purchase",
      "card_key": "purchase.sword_atk_1_06",
      "gu_id": "sword_atk_1_06_gu",
      "stone_cost": 8,
      "tier": 1,
      "school": "sword",
      "gu_name": "刃蛊"
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
      "id": "lab_shop_gold_atk_2_11_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_2_11_gu",
      "tier": 2,
      "stone_cost": 10,
      "gu_name": "赤铁舍利蛊"
    },
    {
      "id": "lab_shop_gold_atk_2_12_gu",
      "kind": "purchase",
      "gu_id": "gold_atk_2_12_gu",
      "tier": 2,
      "stone_cost": 10,
      "gu_name": "青铜舍利蛊"
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
  "materials": [
    {
      "id": "beast_blood",
      "name": "兽血",
      "qualityBand": "plain",
      "daoTags": [
        "blood",
        "qi"
      ]
    },
    {
      "id": "beast_bone",
      "name": "兽骨",
      "qualityBand": "crude",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "venom_sac",
      "name": "毒囊",
      "qualityBand": "refined",
      "daoTags": [
        "poison"
      ]
    },
    {
      "id": "moon_dew",
      "name": "月华露",
      "qualityBand": "refined",
      "daoTags": [
        "moon"
      ]
    },
    {
      "id": "moon_blue_petal",
      "name": "月蓝花瓣",
      "qualityBand": "crude",
      "daoTags": [
        "moon"
      ]
    },
    {
      "id": "boar_king_tusk",
      "name": "野猪王牙",
      "qualityBand": "refined",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "inheritance_token",
      "name": "传承信物",
      "qualityBand": "prized",
      "daoTags": [
        "human"
      ]
    },
    {
      "id": "mat_blood_1",
      "name": "兽凝血膏",
      "qualityBand": "crude",
      "daoTags": [
        "blood"
      ]
    },
    {
      "id": "mat_qi_1",
      "name": "凝气露",
      "qualityBand": "crude",
      "daoTags": [
        "qi"
      ]
    },
    {
      "id": "mat_force_1",
      "name": "兽筋",
      "qualityBand": "crude",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "mat_soul_1",
      "name": "魂絮",
      "qualityBand": "crude",
      "daoTags": [
        "soul"
      ]
    },
    {
      "id": "mat_refine_1",
      "name": "熔炉灰",
      "qualityBand": "crude",
      "daoTags": [
        "refine"
      ]
    },
    {
      "id": "mat_wisdom_1",
      "name": "灵思墨",
      "qualityBand": "crude",
      "daoTags": [
        "wisdom"
      ]
    },
    {
      "id": "mat_dream_1",
      "name": "眠雾",
      "qualityBand": "crude",
      "daoTags": [
        "dream"
      ]
    },
    {
      "id": "mat_luck_1",
      "name": "福签",
      "qualityBand": "crude",
      "daoTags": [
        "luck"
      ]
    },
    {
      "id": "mat_sword_1",
      "name": "断刃屑",
      "qualityBand": "crude",
      "daoTags": [
        "sword"
      ]
    },
    {
      "id": "mat_wood_1",
      "name": "青树脂",
      "qualityBand": "crude",
      "daoTags": [
        "wood"
      ]
    },
    {
      "id": "mat_fire_1",
      "name": "地火膏",
      "qualityBand": "crude",
      "daoTags": [
        "fire"
      ]
    },
    {
      "id": "mat_water_1",
      "name": "潭心珠",
      "qualityBand": "crude",
      "daoTags": [
        "water"
      ]
    },
    {
      "id": "mat_wind_1",
      "name": "游风羽",
      "qualityBand": "crude",
      "daoTags": [
        "wind"
      ]
    },
    {
      "id": "mat_gold_1",
      "name": "砂金",
      "qualityBand": "crude",
      "daoTags": [
        "gold"
      ]
    },
    {
      "id": "mat_earth_1",
      "name": "壤髓泥",
      "qualityBand": "crude",
      "daoTags": [
        "earth"
      ]
    },
    {
      "id": "mat_slave_1",
      "name": "兽革扣",
      "qualityBand": "crude",
      "daoTags": [
        "slave"
      ]
    },
    {
      "id": "mat_heaven_1",
      "name": "天尘",
      "qualityBand": "crude",
      "daoTags": [
        "heaven"
      ]
    },
    {
      "id": "mat_human_1",
      "name": "遗墨纸片",
      "qualityBand": "crude",
      "daoTags": [
        "human"
      ]
    },
    {
      "id": "mat_bone_1",
      "name": "白骨粉",
      "qualityBand": "crude",
      "daoTags": [
        "bone"
      ]
    },
    {
      "id": "mat_force_2",
      "name": "荒兽筋",
      "qualityBand": "plain",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "mat_force_3",
      "name": "兽王筋",
      "qualityBand": "refined",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "mat_force_4",
      "name": "太古荒兽筋",
      "qualityBand": "prized",
      "daoTags": [
        "force"
      ]
    },
    {
      "id": "mat_gold_2",
      "name": "矿脉金砂",
      "qualityBand": "plain",
      "daoTags": [
        "gold"
      ]
    },
    {
      "id": "mat_gold_3",
      "name": "精金屑",
      "qualityBand": "refined",
      "daoTags": [
        "gold"
      ]
    },
    {
      "id": "mat_gold_4",
      "name": "藏山金精",
      "qualityBand": "prized",
      "daoTags": [
        "gold"
      ]
    },
    {
      "id": "mat_wisdom_2",
      "name": "谋算墨",
      "qualityBand": "plain",
      "daoTags": [
        "wisdom"
      ]
    },
    {
      "id": "mat_wisdom_3",
      "name": "传世墨锭",
      "qualityBand": "refined",
      "daoTags": [
        "wisdom"
      ]
    },
    {
      "id": "mat_wisdom_4",
      "name": "圣贤残墨",
      "qualityBand": "prized",
      "daoTags": [
        "wisdom"
      ]
    },
    {
      "id": "mat_heaven_2",
      "name": "雷涤尘",
      "qualityBand": "plain",
      "daoTags": [
        "heaven"
      ]
    },
    {
      "id": "mat_heaven_3",
      "name": "穹核尘",
      "qualityBand": "refined",
      "daoTags": [
        "heaven"
      ]
    },
    {
      "id": "mat_heaven_4",
      "name": "命数尘",
      "qualityBand": "prized",
      "daoTags": [
        "heaven"
      ]
    },
    {
      "id": "mat_fire_2",
      "name": "火岩髓",
      "qualityBand": "plain",
      "daoTags": [
        "fire"
      ]
    },
    {
      "id": "mat_fire_3",
      "name": "离火精",
      "qualityBand": "refined",
      "daoTags": [
        "fire"
      ]
    },
    {
      "id": "mat_fire_4",
      "name": "焚天髓",
      "qualityBand": "prized",
      "daoTags": [
        "fire"
      ]
    },
    {
      "id": "mat_water_2",
      "name": "寒潭髓",
      "qualityBand": "plain",
      "daoTags": [
        "water"
      ]
    },
    {
      "id": "mat_water_3",
      "name": "沧溟珠",
      "qualityBand": "refined",
      "daoTags": [
        "water"
      ]
    },
    {
      "id": "mat_water_4",
      "name": "弱水精",
      "qualityBand": "prized",
      "daoTags": [
        "water"
      ]
    },
    {
      "id": "mat_wind_2",
      "name": "罡风絮",
      "qualityBand": "plain",
      "daoTags": [
        "wind"
      ]
    },
    {
      "id": "mat_wind_3",
      "name": "天罡翎",
      "qualityBand": "refined",
      "daoTags": [
        "wind"
      ]
    },
    {
      "id": "mat_wind_4",
      "name": "太虚风息",
      "qualityBand": "prized",
      "daoTags": [
        "wind"
      ]
    },
    {
      "id": "mat_wood_2",
      "name": "百年松脂",
      "qualityBand": "plain",
      "daoTags": [
        "wood"
      ]
    },
    {
      "id": "mat_wood_3",
      "name": "木灵芯",
      "qualityBand": "refined",
      "daoTags": [
        "wood"
      ]
    },
    {
      "id": "mat_wood_4",
      "name": "建木青髓",
      "qualityBand": "prized",
      "daoTags": [
        "wood"
      ]
    },
    {
      "id": "mat_earth_2",
      "name": "黄泉壤",
      "qualityBand": "plain",
      "daoTags": [
        "earth"
      ]
    },
    {
      "id": "mat_earth_3",
      "name": "地心岩乳",
      "qualityBand": "refined",
      "daoTags": [
        "earth"
      ]
    },
    {
      "id": "mat_earth_4",
      "name": "息壤精",
      "qualityBand": "prized",
      "daoTags": [
        "earth"
      ]
    },
    {
      "id": "mat_blood_2",
      "name": "沁血髓",
      "qualityBand": "plain",
      "daoTags": [
        "blood"
      ]
    },
    {
      "id": "mat_blood_3",
      "name": "血菩提",
      "qualityBand": "refined",
      "daoTags": [
        "blood"
      ]
    },
    {
      "id": "mat_blood_4",
      "name": "万血精",
      "qualityBand": "prized",
      "daoTags": [
        "blood"
      ]
    },
    {
      "id": "mat_dream_2",
      "name": "酣梦丝",
      "qualityBand": "plain",
      "daoTags": [
        "dream"
      ]
    },
    {
      "id": "mat_dream_3",
      "name": "蝶梦纱",
      "qualityBand": "refined",
      "daoTags": [
        "dream"
      ]
    },
    {
      "id": "mat_dream_4",
      "name": "大梦真绫",
      "qualityBand": "prized",
      "daoTags": [
        "dream"
      ]
    },
    {
      "id": "mat_luck_2",
      "name": "吉运绦",
      "qualityBand": "plain",
      "daoTags": [
        "luck"
      ]
    },
    {
      "id": "mat_luck_3",
      "name": "鸿运绫",
      "qualityBand": "refined",
      "daoTags": [
        "luck"
      ]
    },
    {
      "id": "mat_luck_4",
      "name": "天运符",
      "qualityBand": "prized",
      "daoTags": [
        "luck"
      ]
    },
    {
      "id": "mat_qi_2",
      "name": "氤氲珠",
      "qualityBand": "plain",
      "daoTags": [
        "qi"
      ]
    },
    {
      "id": "mat_qi_3",
      "name": "纯阳息",
      "qualityBand": "refined",
      "daoTags": [
        "qi"
      ]
    },
    {
      "id": "mat_qi_4",
      "name": "龙涎气",
      "qualityBand": "prized",
      "daoTags": [
        "qi"
      ]
    },
    {
      "id": "mat_human_2",
      "name": "名家信札",
      "qualityBand": "plain",
      "daoTags": [
        "human"
      ]
    },
    {
      "id": "mat_human_3",
      "name": "宗师手札",
      "qualityBand": "refined",
      "daoTags": [
        "human"
      ]
    },
    {
      "id": "mat_human_4",
      "name": "圣贤遗篇",
      "qualityBand": "prized",
      "daoTags": [
        "human"
      ]
    },
    {
      "id": "mat_slave_2",
      "name": "厚兽革",
      "qualityBand": "plain",
      "daoTags": [
        "slave"
      ]
    },
    {
      "id": "mat_slave_3",
      "name": "兽王革",
      "qualityBand": "refined",
      "daoTags": [
        "slave"
      ]
    },
    {
      "id": "mat_slave_4",
      "name": "万兽纹革",
      "qualityBand": "prized",
      "daoTags": [
        "slave"
      ]
    },
    {
      "id": "mat_soul_2",
      "name": "凝魂玉屑",
      "qualityBand": "plain",
      "daoTags": [
        "soul"
      ]
    },
    {
      "id": "mat_soul_3",
      "name": "魂将残晶",
      "qualityBand": "refined",
      "daoTags": [
        "soul"
      ]
    },
    {
      "id": "mat_soul_4",
      "name": "先贤英魂核",
      "qualityBand": "prized",
      "daoTags": [
        "soul"
      ]
    },
    {
      "id": "mat_refine_2",
      "name": "地火熔渣",
      "qualityBand": "plain",
      "daoTags": [
        "refine"
      ]
    },
    {
      "id": "mat_refine_3",
      "name": "五金熔英",
      "qualityBand": "refined",
      "daoTags": [
        "refine"
      ]
    },
    {
      "id": "mat_refine_4",
      "name": "九转炉心",
      "qualityBand": "prized",
      "daoTags": [
        "refine"
      ]
    },
    {
      "id": "mat_sword_2",
      "name": "陨铁屑",
      "qualityBand": "plain",
      "daoTags": [
        "sword"
      ]
    },
    {
      "id": "mat_sword_3",
      "name": "寒铁屑",
      "qualityBand": "refined",
      "daoTags": [
        "sword"
      ]
    },
    {
      "id": "mat_sword_4",
      "name": "天外玄铁屑",
      "qualityBand": "prized",
      "daoTags": [
        "sword"
      ]
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
      "summary": "洞穴深处有回声应答，已知与未知的代价都刻在石壁上。",
      "flavor_gain": "取得回声允诺的机缘。",
      "unknown_note": "回声的后续代价结果未明，似有低语要在魂魄深处留下印记。",
      "health_cost": 1,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "gu_rot_pact",
      "kind": "curse_bargain",
      "title": "腐朽蛊契",
      "summary": "腐朽的蛊契在掌心发热，代价与收获都写在血色纹路里。",
      "flavor_gain": "借此蛊契牵动一线机缘。",
      "unknown_note": "蛊契烙入体内后，元石滞胀的苦果何时显现仍未明。",
      "health_cost": 1,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "curse_id": "essence_bloat"
    },
    {
      "id": "huajiu_cache",
      "title": "行者遗藏",
      "summary": "山腹深处藏着某位行者的遗藏，独吞者从无善终。",
      "flavor_gain": "取走遗藏中的元石。",
      "unknown_note": "遗藏深处是否另有埋伏，只有挖到尽头才知。",
      "health_cost": 2,
      "stone_gain": 5
    },
    {
      "id": "tithing_cache",
      "title": "献藏换赏",
      "summary": "遗藏见光便引来窥伺，不如报与山寨换一份赏钱。",
      "flavor_gain": "换一份稳妥的赏钱。",
      "unknown_note": "山寨给的赏钱是否足数，全看管事的心情。",
      "health_cost": 0,
      "stone_gain": 2
    },
    {
      "id": "small_beast_tide",
      "title": "小兽潮",
      "summary": "小型兽潮已经在山寨附近成形，蛊师是唯一能挡的墙。",
      "flavor_gain": "从兽尸与赏功中收得元石。",
      "unknown_note": "这股兽潮是否会滚成大型，眼下无人说得准。",
      "health_cost": 2,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "tide_aftermath",
      "title": "潮后拾骨",
      "summary": "兽潮退去，山道上留下成片尸骨与未干的血气。",
      "flavor_gain": "从尸骨间拾取遗留的元石。",
      "unknown_note": "尸骨之间还盘着什么活物，谁也说不上来。",
      "health_cost": 0,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 3
    },
    {
      "id": "duel_wager",
      "title": "赌斗押注",
      "summary": "有人当街设下赌斗，胜负各安天命，注头就摆在桌面上。",
      "flavor_gain": "赢下注头，把元石收入囊中。",
      "unknown_note": "对手的底细与后手一概不知，只看你敢不敢押。",
      "health_cost": 1,
      "stone_gain": 4
    },
    {
      "id": "duel_loss",
      "title": "斗蛊折戟",
      "summary": "斗蛊场上一场比试已经摆开，输家的代价写在契纸上。",
      "flavor_gain": "即便落败，也能从场中捡到零散的元石。",
      "unknown_note": "经脉封蛊何时松解，没有定数。",
      "health_cost": 2,
      "curse_id": "meridian_seal",
      "stone_gain": 1
    },
    {
      "id": "weird_trade",
      "title": "秘境换物",
      "summary": "秘境入口半开，守门者只要魂魄，不要元石。",
      "flavor_gain": "换回一份可用的元石。",
      "unknown_note": "换到手的东西能否合用，结果未明。",
      "health_cost": 0,
      "delayed_soul_cost": 1,
      "delayed_trigger": "next_travel",
      "stone_gain": 2
    },
    {
      "id": "contract_seal",
      "title": "毒誓之契",
      "summary": "要人用毒誓蛊立下不容反悔的契约，报酬先给。",
      "flavor_gain": "先收下契约的酬劳。",
      "unknown_note": "毒誓的制约何时收紧，只有违约那天才知道。",
      "health_cost": 1,
      "delayed_soul_cost": 2,
      "delayed_trigger": "next_travel",
      "stone_gain": 4
    },
    {
      "id": "recognition_toll",
      "title": "认主输诚",
      "summary": "有势力逼你认主输诚，输了名头，换一条活路。",
      "flavor_gain": "换得对方的赏赐。",
      "unknown_note": "蛊蚀何时发作，全看对方心意。",
      "health_cost": 0,
      "curse_id": "gu_erosion",
      "stone_gain": 3
    },
    {
      "id": "blood_vein_offering",
      "title": "血脉献祭",
      "summary": "血脉祭坛前有人收买精血，价钱开得很高。",
      "flavor_gain": "取走祭坛边堆积的元石。",
      "unknown_note": "元石滞胀的余患何时现形，无人敢断言。",
      "health_cost": 2,
      "curse_id": "essence_bloat",
      "stone_gain": 4
    }
  ],
  "actions": {
    "accept": "接取",
    "ally": "结盟",
    "attempt_ascension": "冲击升仙",
    "buy_information": "购买情报",
    "buy": "买蛊",
    "claim": "占取",
    "cross": "穿越",
    "deceive": "欺瞒",
    "fight": "交锋",
    "harvest": "采集",
    "inspect": "查验",
    "leave": "离开",
    "lure": "诱引",
    "meditate": "静修",
    "open": "开启",
    "prepare": "筹备",
    "pressure": "施压",
    "probe": "试探",
    "retreat": "撤离",
    "refine": "炼蛊",
    "cultivate": "冲击二转",
    "settle_feeding": "结清养护",
    "accept_debt": "欠下人情",
    "scout": "探查",
    "scheme": "设局",
    "take_imprint": "承受体印",
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
      "layer_step_pct": 20,
      "provisional_note": "Q8-G 1-C provisional：战斗产石 = base_by_tier[tier] + base*layer_step_pct*(layer-1)/100。Batch 0 §4 冻结口径：tier+layer 结构、数值 provisional、F8 校准；production 口径为净新增（卖材料不算）。"
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
        "name": "合炼与升炼配方",
        "detail": "6 条配方的材料、元石成本、原文出处行号；判定用 run seed 与事件序号，失败销毁全部投入",
        "source": "data/refinement_recipes.json（468 条）；refine_command_rules.gd::_refinement_roll/_apply_fixed_recipe"
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
        "name": "战利品池与保底",
        "detail": "按 tier+layer 读取材料数/权重、蛊概率/稀有度权重；common/elite/boss 材料保底与 common 蛊保底按事件序号推进",
        "source": "data/loot_tables.json；data/pacing.json；loot_resolver.gd::settle_victory"
      },
      {
        "name": "突破链",
        "detail": "每转四阶；小突破消耗元石或当前转数同阶舍利蛊，舍利不可越阶；巅峰冲下一转要求资质与元石同时达标",
        "source": "本轮 L0 裁决；大突破元石成本沿用 balance；essence_capacity.gd"
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
        "name": "坊市货架与蛊方服务",
        "detail": "按层显示 4–6 件蛊/材料；同店确定性洗牌、最高档保底、流派蛊保底；购买按层价加价；仅保留蛊方解锁服务",
        "source": "data/shops.json → purchase/material_purchase/gu_fang_unlock；data/pacing.json → layers；shop_command_rules.gd::shop_stock/shop_slot_count/shop_layer_price/_shop_gu_fang_unlock"
      }
    ],
    "notCovered": [
      {
        "name": "路线选择的领域结算",
        "why": "本原型只按节点类型分流，并在选择后推进路线；交涉、侦察、穿越等完整结算仍以 Godot 领域层为准"
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
        "name": "另 3 个带阶段数据的 Boss",
        "why": "blood_vein_bishop 之外的 clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，未纳入；其中 clan_patriarch 的「家族征召」是 damage 0 且无 essence_burn，语义未知"
      },
      {
        "name": "Boss 立绘",
        "why": "血络主教无专属立绘，借用同流派血道蝙蝠图（enemy_bat.png），仅影响观感"
      },
      {
        "name": "魂魄成长与失控",
        "why": "本页已接魂魄行动分档、抽魂与魂魄归零死亡；魂魄收集、成长、狂暴和失控仍未实现"
      },
      {
        "name": "完整事件日志与存档",
        "why": "已接最小 run event_log 并用于炼蛊与战利品 tick；完整领域事件形状、存档与回放尚未接入"
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
