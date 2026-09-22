window.SPINE = {
  "generated_at": "2026-09-22T06:30:56.157Z",
  "acceptance": [
    {
      "name": "1 RankProfile → R2 蛊重生成",
      "pass": true,
      "detail": "changed=7/7 leakR1R3=0"
    },
    {
      "name": "2 MoonDaoProfile → 月系价值向量重生成",
      "pass": true,
      "detail": "changed=24/24"
    },
    {
      "name": "3 small_light scarcity → 炼制期望成本传染",
      "pass": true,
      "detail": "small 136→217, moonglow expected 636→855"
    },
    {
      "name": "4 月芒 override → 杀招投影变化",
      "pass": true,
      "detail": "moonglow_break dmg 18→6"
    },
    {
      "name": "5 EnemyArchetype.armored → 五实例同步变化",
      "pass": true,
      "detail": "28,50,80,124,184"
    }
  ],
  "sample": {
    "gu": [
      {
        "id": "moonlight_gu",
        "name": "月光蛊",
        "rank": 1,
        "dao": [
          "moon",
          "light"
        ],
        "archetype": [
          "direct_projectile"
        ],
        "quality": "normal",
        "origin": "canonical",
        "sources": [
          "FACT-MOONLIGHT-001",
          "FACT-MOONLIGHT-002",
          "FACT-MOONLIGHT-003"
        ],
        "unique_rules": {},
        "traits": {
          "range_bias": "medium",
          "qi_efficiency": "normal"
        },
        "combat": {
          "damage": 4,
          "block": 0,
          "qi": 9,
          "thought": 1,
          "cd": 0,
          "dims": {
            "power": 1,
            "range": 0.8,
            "accuracy": 1,
            "penetration": 0,
            "targets": 1
          },
          "archetype": "direct_projectile",
          "qualityClass": "normal"
        },
        "value_vector": {
          "combat_direct": 0.9,
          "defense": 0.11,
          "control": 0.33,
          "information": 0.39,
          "mobility": 0.24,
          "resource": 0.27,
          "refinement": 0.3,
          "killer_move": 1.09,
          "economy": 0.27
        },
        "intrinsic_value": 3.52,
        "economy": {
          "marketPrice": 79,
          "npcBuyPrice": 43,
          "blackMarketPrice": 103
        },
        "refinement_edges": [
          "moon_glow_gu",
          "moon_mark_gu",
          "moon_spin_gu",
          "moon_rainbow_gu"
        ],
        "deps": {
          "rank_profile": "rank_profiles_v1",
          "quality_profile": "quality_profiles_v1/normal",
          "effect_archetype": "direct_projectile",
          "dao_profile": "moon",
          "economy_tier": "1",
          "facts": [
            "FACT-MOONLIGHT-001",
            "FACT-MOONLIGHT-002",
            "FACT-MOONLIGHT-003"
          ],
          "rulings": []
        }
      },
      {
        "id": "small_light_gu",
        "name": "小光蛊",
        "rank": 1,
        "dao": [
          "light"
        ],
        "archetype": [
          "support_amp"
        ],
        "quality": "normal",
        "origin": "canonical",
        "sources": [
          "FACT-SMALLLIGHT-001"
        ],
        "unique_rules": {},
        "traits": {
          "refinement_hunger": "high",
          "qi_efficiency": "high"
        },
        "combat": {
          "damage": 0,
          "block": 0,
          "qi": 8,
          "thought": 1,
          "cd": 0,
          "dims": {},
          "archetype": "support_amp",
          "qualityClass": "normal"
        },
        "value_vector": {
          "combat_direct": 0.08,
          "defense": 0.06,
          "control": 0.15,
          "information": 0.42,
          "mobility": 0.12,
          "resource": 0.8,
          "refinement": 2.08,
          "killer_move": 1.32,
          "economy": 0.3
        },
        "intrinsic_value": 4.85,
        "economy": {
          "marketPrice": 136,
          "npcBuyPrice": 75,
          "blackMarketPrice": 177
        },
        "refinement_edges": [
          "moon_glow_gu",
          "condense_light_gu",
          "moon_draw_gu"
        ],
        "deps": {
          "rank_profile": "rank_profiles_v1",
          "quality_profile": "quality_profiles_v1/normal",
          "effect_archetype": "support_amp",
          "dao_profile": "light",
          "economy_tier": "1",
          "facts": [
            "FACT-SMALLLIGHT-001"
          ],
          "rulings": []
        }
      },
      {
        "id": "moon_watch_gu",
        "name": "照月蛊",
        "rank": 1,
        "dao": [
          "moon"
        ],
        "archetype": [
          "inspect"
        ],
        "quality": "good",
        "origin": "adaptation",
        "sources": [
          "FACT-MOONWATCH-ADAPT-001"
        ],
        "unique_rules": {
          "if_already_revealed_moon_vuln": true
        },
        "traits": {
          "range_bias": "wide",
          "longevity": true
        },
        "combat": {
          "damage": 0,
          "block": 0,
          "qi": 10,
          "thought": 1,
          "cd": 0,
          "dims": {
            "range": 1.5,
            "accuracy": 1
          },
          "archetype": "inspect",
          "qualityClass": "good"
        },
        "value_vector": {
          "combat_direct": 0.19,
          "defense": 0.13,
          "control": 0.41,
          "information": 3.17,
          "mobility": 0.3,
          "resource": 0.34,
          "refinement": 0.38,
          "killer_move": 0.61,
          "economy": 0.34
        },
        "intrinsic_value": 4.94,
        "economy": {
          "marketPrice": 107,
          "npcBuyPrice": 59,
          "blackMarketPrice": 139
        },
        "refinement_edges": [
          "moon_veil_gu",
          "condense_light_gu"
        ],
        "deps": {
          "rank_profile": "rank_profiles_v1",
          "quality_profile": "quality_profiles_v1/good",
          "effect_archetype": "inspect",
          "dao_profile": "moon",
          "economy_tier": "1",
          "facts": [
            "FACT-MOONWATCH-ADAPT-001"
          ],
          "rulings": []
        }
      },
      {
        "id": "moon_glow_gu",
        "name": "月芒蛊",
        "rank": 2,
        "dao": [
          "moon",
          "light"
        ],
        "archetype": [
          "burst_projectile"
        ],
        "quality": "excellent",
        "origin": "canonical",
        "sources": [
          "FACT-MOONGLOW-001",
          "FACT-MOONGLOW-003",
          "FACT-MOONGLOW-004"
        ],
        "unique_rules": {
          "suppress_if_revealed": true
        },
        "traits": {
          "range_bias": "medium",
          "refinement_hunger": "high"
        },
        "combat": {
          "damage": 16,
          "block": 0,
          "qi": 12,
          "thought": 1,
          "cd": 1,
          "dims": {
            "power": 1.55,
            "range": 0.8,
            "accuracy": 1,
            "penetration": 0.2,
            "targets": 1
          },
          "archetype": "burst_projectile",
          "qualityClass": "excellent"
        },
        "value_vector": {
          "combat_direct": 4.1,
          "defense": 0.16,
          "control": 0.5,
          "information": 0.59,
          "mobility": 0.36,
          "resource": 0.41,
          "refinement": 0.72,
          "killer_move": 2,
          "economy": 0.41
        },
        "intrinsic_value": 8.64,
        "economy": {
          "marketPrice": 426,
          "npcBuyPrice": 234,
          "blackMarketPrice": 554
        },
        "refinement_edges": [
          "golden_moon_gu",
          "frost_moon_gu",
          "phantom_moon_gu",
          "blood_moon_gu"
        ],
        "deps": {
          "rank_profile": "rank_profiles_v1",
          "quality_profile": "quality_profiles_v1/excellent",
          "effect_archetype": "burst_projectile",
          "dao_profile": "moon",
          "economy_tier": "2",
          "facts": [
            "FACT-MOONGLOW-001",
            "FACT-MOONGLOW-003",
            "FACT-MOONGLOW-004"
          ],
          "rulings": []
        }
      },
      {
        "id": "moon_mark_gu",
        "name": "月痕蛊",
        "rank": 2,
        "dao": [
          "moon"
        ],
        "archetype": [
          "ranged_snipe"
        ],
        "quality": "good",
        "origin": "canonical",
        "sources": [
          "FACT-MOONTRACE-001",
          "FACT-MOONTRACE-002"
        ],
        "unique_rules": {},
        "traits": {
          "range_bias": "long"
        },
        "combat": {
          "damage": 5,
          "block": 0,
          "qi": 14,
          "thought": 1,
          "cd": 0,
          "dims": {
            "power": 0.65,
            "range": 1.8,
            "accuracy": 1,
            "penetration": 0.35,
            "targets": 1
          },
          "archetype": "ranged_snipe",
          "qualityClass": "good"
        },
        "value_vector": {
          "combat_direct": 0.88,
          "defense": 0.13,
          "control": 0.55,
          "information": 0.49,
          "mobility": 0.3,
          "resource": 0.34,
          "refinement": 0.38,
          "killer_move": 1.1,
          "economy": 0.34
        },
        "intrinsic_value": 4.06,
        "economy": {
          "marketPrice": 178,
          "npcBuyPrice": 98,
          "blackMarketPrice": 231
        },
        "refinement_edges": [],
        "deps": {
          "rank_profile": "rank_profiles_v1",
          "quality_profile": "quality_profiles_v1/good",
          "effect_archetype": "ranged_snipe",
          "dao_profile": "moon",
          "economy_tier": "2",
          "facts": [
            "FACT-MOONTRACE-001",
            "FACT-MOONTRACE-002"
          ],
          "rulings": []
        }
      }
    ],
    "edges": [
      {
        "id": "R01",
        "from": [
          "moonlight_gu",
          "small_light_gu",
          "small_light_gu"
        ],
        "to": "moon_glow_gu",
        "success": 0.74,
        "onceCost": 471,
        "expectedCost": 636,
        "marketPrice": 426
      },
      {
        "id": "R02",
        "from": [
          "moonlight_gu",
          "stone_mark_gu"
        ],
        "to": "moon_mark_gu",
        "success": 0.74,
        "onceCost": 277,
        "expectedCost": 374,
        "marketPrice": 178
      },
      {
        "id": "R03",
        "from": [
          "moonlight_gu",
          "whirlwind_gu"
        ],
        "to": "moon_spin_gu",
        "success": 0.74,
        "onceCost": 277,
        "expectedCost": 374,
        "marketPrice": 156
      },
      {
        "id": "R04",
        "from": [
          "moonlight_gu",
          "jade_skin_gu"
        ],
        "to": "moon_rainbow_gu",
        "success": 0.74,
        "onceCost": 225,
        "expectedCost": 304,
        "marketPrice": 168
      },
      {
        "id": "R05",
        "from": [
          "moon_glow_gu"
        ],
        "to": "golden_moon_gu",
        "success": 0.6,
        "onceCost": 466,
        "expectedCost": 777,
        "marketPrice": 2461
      },
      {
        "id": "R06",
        "from": [
          "moon_glow_gu"
        ],
        "to": "frost_moon_gu",
        "success": 0.6,
        "onceCost": 466,
        "expectedCost": 777,
        "marketPrice": 1346
      }
    ],
    "killerMoves": [
      {
        "id": "curved_moon_chase",
        "name": "弧月追影",
        "rank": 1,
        "components": {
          "core": [
            "moonlight_gu"
          ],
          "transforms": [
            "whirlwind_gu"
          ]
        },
        "execution": {
          "sequence": [
            "trajectory_transform",
            "projectile_attack"
          ]
        },
        "emergent_rules": [
          "ignore_linear_obstacle",
          "evade_counter_reduction"
        ],
        "projected": {
          "damage": 5,
          "block": 0,
          "qi": 16,
          "thought": 2,
          "slots": 1.5
        },
        "primitives": [
          "Damage"
        ],
        "deps": {
          "skeleton": "curved_moon_chase",
          "core": [
            "moonlight_gu"
          ],
          "transforms": [
            "whirlwind_gu"
          ],
          "coordination": 1.15
        }
      },
      {
        "id": "double_moon_blades",
        "name": "双月连刃",
        "rank": 1,
        "components": {
          "core": [
            "moonlight_gu"
          ],
          "transforms": [
            "small_light_gu"
          ]
        },
        "execution": {
          "sequence": [
            "amp",
            "projectile",
            "projectile"
          ]
        },
        "emergent_rules": [
          "second_hit_bonus_if_revealed"
        ],
        "projected": {
          "damage": 5,
          "block": 0,
          "qi": 16,
          "thought": 2,
          "slots": 1.5
        },
        "primitives": [
          "Damage"
        ],
        "deps": {
          "skeleton": "double_moon_blades",
          "core": [
            "moonlight_gu"
          ],
          "transforms": [
            "small_light_gu"
          ],
          "coordination": 1.15
        }
      },
      {
        "id": "moon_mark_raid",
        "name": "月痕远袭",
        "rank": 1,
        "components": {
          "core": [
            "moonlight_gu",
            "stone_mark_gu"
          ],
          "transforms": []
        },
        "execution": {
          "sequence": [
            "extend_range",
            "piercing_shot"
          ]
        },
        "emergent_rules": [
          "blocks_melee_counter_if_fared"
        ],
        "projected": {
          "damage": 5,
          "block": 0,
          "qi": 17,
          "thought": 2,
          "slots": 2
        },
        "primitives": [
          "Damage"
        ],
        "deps": {
          "skeleton": "moon_mark_raid",
          "core": [
            "moonlight_gu",
            "stone_mark_gu"
          ],
          "transforms": [],
          "coordination": 1.15
        }
      },
      {
        "id": "jade_moon_guard",
        "name": "玉月护身",
        "rank": 1,
        "components": {
          "core": [
            "moonlight_gu",
            "jade_skin_gu"
          ],
          "transforms": []
        },
        "execution": {
          "sequence": [
            "shield",
            "optional_follow_moon"
          ]
        },
        "emergent_rules": [
          "shield_unbroken_next_moon_plus"
        ],
        "projected": {
          "damage": 5,
          "block": 7,
          "qi": 17,
          "thought": 2,
          "slots": 2
        },
        "primitives": [
          "Shield",
          "Damage"
        ],
        "deps": {
          "skeleton": "jade_moon_guard",
          "core": [
            "moonlight_gu",
            "jade_skin_gu"
          ],
          "transforms": [],
          "coordination": 1.15
        }
      }
    ],
    "enemies": [
      {
        "id": "hunter_r2",
        "archetype": "hunter",
        "family": "山脊猎犬系",
        "name": "山脊猎犬系·R2",
        "rank": 2,
        "hp": 21,
        "defense": 1,
        "speed": 2,
        "damage": 7,
        "mechanisms": [
          "wounded_pounce_bonus"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "beast": 1.8,
            "moon": 0.6
          }
        },
        "tests": "基础攻防与节奏",
        "deps": {
          "enemy_archetype": "hunter",
          "rank_profile": "2",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "armored_r1",
        "archetype": "armored",
        "family": "铁皮山猪系",
        "name": "铁皮山猪系·R1",
        "rank": 1,
        "hp": 18,
        "defense": 0,
        "speed": 1,
        "damage": 3,
        "mechanisms": [
          "temporary_shield"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "armor": 1.8,
            "gold": 1.2
          }
        },
        "tests": "穿透、控制、持续输出",
        "deps": {
          "enemy_archetype": "armored",
          "rank_profile": "1",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "armored_r2",
        "archetype": "armored",
        "family": "铁皮山猪系",
        "name": "铁皮山猪系·R2",
        "rank": 2,
        "hp": 31,
        "defense": 2,
        "speed": 1,
        "damage": 5,
        "mechanisms": [
          "shield_break_window"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "armor": 1.8,
            "gold": 1.2
          }
        },
        "tests": "穿透、控制、持续输出",
        "deps": {
          "enemy_archetype": "armored",
          "rank_profile": "2",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "armored_r3",
        "archetype": "armored",
        "family": "铁皮山猪系",
        "name": "铁皮山猪系·R3",
        "rank": 3,
        "hp": 50,
        "defense": 3,
        "speed": 1,
        "damage": 9,
        "mechanisms": [
          "flat_reduction"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "armor": 1.8,
            "gold": 1.2
          }
        },
        "tests": "穿透、控制、持续输出",
        "deps": {
          "enemy_archetype": "armored",
          "rank_profile": "3",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "armored_r4",
        "archetype": "armored",
        "family": "铁皮山猪系",
        "name": "铁皮山猪系·R4",
        "rank": 4,
        "hp": 78,
        "defense": 5,
        "speed": 1,
        "damage": 13,
        "mechanisms": [
          "control_immunity_while_armored"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "armor": 1.8,
            "gold": 1.2
          }
        },
        "tests": "穿透、控制、持续输出",
        "deps": {
          "enemy_archetype": "armored",
          "rank_profile": "4",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "armored_r5",
        "archetype": "armored",
        "family": "铁皮山猪系",
        "name": "铁皮山猪系·R5",
        "rank": 5,
        "hp": 115,
        "defense": 6,
        "speed": 1,
        "damage": 19,
        "mechanisms": [
          "vulnerability_after_break"
        ],
        "isBoss": false,
        "ecology": {
          "type": "beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "armor": 1.8,
            "gold": 1.2
          }
        },
        "tests": "穿透、控制、持续输出",
        "deps": {
          "enemy_archetype": "armored",
          "rank_profile": "5",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "swift_r2",
        "archetype": "swift",
        "family": "影兔/风鼬系",
        "name": "影兔/风鼬系·R2",
        "rank": 2,
        "hp": 18,
        "defense": 1,
        "speed": 3,
        "damage": 7,
        "mechanisms": [
          "evasion_on_lock"
        ],
        "isBoss": false,
        "ecology": {
          "type": "moon_beast",
          "wealth_class": "wild_beast",
          "material_bias": {
            "wind": 1.5,
            "moon": 1.2
          }
        },
        "tests": "命中、预判、范围",
        "deps": {
          "enemy_archetype": "swift",
          "rank_profile": "2",
          "quality_band": "normal"
        },
        "origin": "derived"
      },
      {
        "id": "swarm_r2",
        "archetype": "swarm",
        "family": "蛊虫群",
        "name": "蛊虫群·R2",
        "rank": 2,
        "hp": 23,
        "defense": 1,
        "speed": 2,
        "damage": 5,
        "mechanisms": [
          "poison_if_many_alive"
        ],
        "isBoss": false,
        "ecology": {
          "type": "swarm",
          "wealth_class": "wild_beast",
          "material_bias": {
            "bug": 1.6
          }
        },
        "tests": "多目标、范围能力",
        "deps": {
          "enemy_archetype": "swarm",
          "rank_profile": "2",
          "quality_band": "normal"
        },
        "origin": "derived"
      }
    ],
    "impact": {
      "gu": [
        "small_light_gu",
        "moon_glow_gu"
      ],
      "killer_moves": [
        "double_moon_blades",
        "moonglow_break",
        "variant_moon_glow_from_moonlight"
      ],
      "refine_edges": [
        "R01"
      ],
      "shops": [
        "tiers touching",
        "small_light_gu",
        "moon_glow_gu"
      ],
      "drops": [],
      "enemies": [],
      "notes": [
        "small_light_gu 价格/供应变化",
        "炼制期望成本 → 成品市价 → 路线成型速度"
      ]
    }
  },
  "layers": {
    "canonical": [
      "facts/moon_facts.json",
      "gu/moon_gu_identity.json",
      "dao/dao_profiles.json"
    ],
    "rulings": [
      "moon_rulings.json"
    ],
    "models": [
      "rank_profiles",
      "quality_profiles",
      "effect_archetypes",
      "enemy_archetypes",
      "economy",
      "refinement",
      "killer_moves",
      "combat/primitives"
    ],
    "projections": [
      "index.js",
      "killer_moves.js",
      "impact.js"
    ],
    "generated": [
      "gu_stats.json",
      "enemy_stats.json",
      "refine_projection.json"
    ],
    "golden": [
      "vertical/data/* 校准集"
    ]
  }
};
