"""Derive the machine-readable world model under world-model/data/ from the
read-only Godot prototype tables under data/.

STRICTLY READ-ONLY on the parent repository: this script never writes outside
world-model/. It reads ../../data/*.json and emits world-model's own, uniform,
ASCII-keyed entity format.

Usage:
    python world-model/tools/build_world_model.py [--generated-at ISO8601]
"""

from __future__ import annotations

import argparse
import collections
import datetime as _dt
import hashlib
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = WM_ROOT.parent
DATA_DIR = REPO_ROOT / "data"
OUT_DIR = WM_ROOT / "data"

WORLD_MODEL_VERSION = (WM_ROOT / "VERSION").read_text(encoding="utf-8").strip() if (WM_ROOT / "VERSION").exists() else "1.0.0"
SCHEMA_VERSION = "1.0.0"

# Canon identifiers resolved from docs/lore/canon-index.md and docs/lore/adaptation-register.md.
CAN_NANJIANG = ["CAN-NANJIANG-001", "CAN-NANJIANG-002", "CAN-NANJIANG-003", "CAN-NANJIANG-004"]
CAN_CULTIVATION = ["CAN-CULTIVATION-001", "CAN-CULTIVATION-002", "CAN-CULTIVATION-003"]
CAN_APTITUDE = ["CAN-APTITUDE-001", "CAN-APTITUDE-002", "CAN-APTITUDE-003"]
CAN_ASCENSION = ["CAN-ASCENSION-001", "CAN-ASCENSION-002"]
CAN_ECONOMY = ["CAN-ECONOMY-001"]
CAN_GU_CARE = ["CAN-GU-CARE-001"]
CAN_GU_SYNERGY = ["CAN-GU-SYNERGY-001", "CAN-GU-SYNERGY-002"]
CAN_SMALL_LIGHT = ["CAN-SMALL-LIGHT-001", "CAN-SMALL-LIGHT-002"]
CAN_BEAST_TIER = ["CAN-BEAST-TIER-001", "CAN-BEAST-TIER-002", "CAN-BEAST-TIER-003"]
CAN_BEAST_BASELINE = ["CAN-BEAST-BASELINE-001", "CAN-MORTAL-001"]
CAN_RANK_LADDER = ["CAN-RANK-LADDER-001"]
CAN_FACTION = ["CAN-FACTION-001", "CAN-FACTION-002", "CAN-FACTION-003"]
CAN_CULTIVATOR = ["CAN-CULTIVATOR-001", "CAN-CULTIVATOR-002"]
CAN_BEAST_TIDE = ["CAN-BEAST-TIDE-001", "CAN-BEAST-TIDE-002", "CAN-BEAST-SWARM-001"]
CAN_IMMORTAL_BOUNDARY = ["CAN-IMMORTAL-BOUNDARY-001"]

ADP_RUN = ["ADP-RUN-001"]
ADP_LOADOUT = ["ADP-GU-LOADOUT-001"]
ADP_SYNERGY = ["ADP-GU-SYNERGY-001"]
ADP_SMALL_LIGHT = ["ADP-SMALL-LIGHT-001"]
ADP_FACTION = ["ADP-FACTION-001"]
ADP_ASCENSION = ["ADP-ASCENSION-001"]
ADP_COMBAT = ["ADP-COMBAT-001"]
ADP_CULTIVATION = ["ADP-CULTIVATION-001"]

GAME_RULES = [
    "GAME-CULTIVATOR-001", "GAME-CULTIVATOR-002", "GAME-CULTIVATOR-003", "GAME-CULTIVATOR-004",
    "GAME-PLAYER-001", "GAME-GU-LOADOUT-001", "GAME-GU-COMBAT-001", "GAME-GU-FEEDING-001",
    "GAME-GU-REFINEMENT-001", "GAME-GU-REFINEMENT-004",
]

CANON, ADAPT, ORIGINAL = "canon", "adaptation", "original_game_content"

_READ_CACHE: dict[str, object] = {}


def load(table: str):
    if table not in _READ_CACHE:
        path = DATA_DIR / f"{table}.json"
        if not path.exists():
            raise SystemExit(f"FATAL: read-only source table missing: {path}")
        with path.open(encoding="utf-8") as fh:
            _READ_CACHE[table] = json.load(fh)
    return _READ_CACHE[table]


def trace(source_class: str, source_ids: list[str], note: str, status: str = "draft", tunable: bool = False) -> dict:
    return {
        "source_class": source_class,
        "source_ids": list(source_ids),
        "canon_review_status": status,
        "adaptation_note": note,
        "tunable": tunable,
    }


def envelope(entity_type: str, entities: list, source_refs: list[str], generated_at: str, extra: dict | None = None) -> dict:
    doc = {
        "world_model_version": WORLD_MODEL_VERSION,
        "schema_id": "gu-zhenren/world-model",
        "schema_version": SCHEMA_VERSION,
        "entity_type": entity_type,
        "generated_at": generated_at,
        "generator": "world-model/tools/build_world_model.py",
        "source_refs": sorted(set(source_refs)),
        "count": len(entities),
        "entities": entities,
    }
    if extra:
        doc.update(extra)
    return doc


def write(doc: dict, name: str) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / name
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1, sort_keys=False)
        fh.write("\n")


# --------------------------------------------------------------------------
# realms.json
# --------------------------------------------------------------------------

STAGES = ["initial", "middle", "upper", "peak"]
STAGE_ZH = {"initial": "初阶", "middle": "中阶", "upper": "高阶", "peak": "巅峰"}
CN_NUM = {1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九"}
# CAN-CULTIVATION-002 covers ranks 1-5 only. Ranks 6-9 are immortal-tier and
# their essence-grade wording is NOT stated in the indexed canon, so the field
# is left null rather than invented.
ESSENCE_TIER_BY_RANK = {1: "bronze", 2: "iron", 3: "silver", 4: "gold", 5: "amethyst"}
ESSENCE_TIER_ZH = {1: "青铜", 2: "赤铁", 3: "白银", 4: "黄金", 5: "紫晶"}
# cultivation_factor 1:3:9:27:81 is the shipped prototype ladder (data/aptitude.json).
# Ranks 6-9 continue the same geometric ladder as an explicit game extension.
CULTIVATION_FACTOR = {1: 1, 2: 3, 3: 9, 4: 27, 5: 81, 6: 243, 7: 729, 8: 2187, 9: 6561}
STAGE_BASE_BATTLE = {1: 10, 2: 30, 3: 60, 4: 100, 5: 150}


def build_realms(generated_at: str) -> dict:
    v1 = load("v1_battle")
    aptitude = load("aptitude")
    balance = load("balance")
    cultivate_word = {2: "two", 3: "three", 4: "four", 5: "five"}
    _CULTIVATE_WORD = {r: balance.get(f"cultivate_rank_{w}_stone_cost") for r, w in cultivate_word.items()}
    entities = []
    for rank in range(1, 10):
        immortal = rank >= 6
        tier = ESSENCE_TIER_BY_RANK.get(rank)
        for stage in STAGES:
            rid = f"r{rank}_{stage}"
            in_launch = rank <= 5
            note = (
                "一至九转与四小境界来自原著；真元品阶一至五转来自原著（五转用「紫晶」）。"
                if not immortal else
                "六至九转属蛊仙层次，规则边界见 CAN-IMMORTAL-BOUNDARY-001；首发不将蛊仙阶段做成可玩内容，"
                "本表仅记录世界观层级。六转以上真元品阶原著未明确，故 essence_tier 留空。"
            )
            entities.append({
                "id": rid,
                "name_zh": f"{CN_NUM[rank]}转{STAGE_ZH[stage]}",
                "rank": rank,
                "stage": stage,
                "cultivator_class": "gu_immortal" if immortal else "gu_master",
                "honorific": "venerable" if rank == 9 else "",
                "energy_type": "immortal_essence" if immortal else "primeval_essence",
                "essence_tier": tier,
                "essence_tier_zh": ESSENCE_TIER_ZH.get(rank),
                "essence_tier_note": (
                    "" if tier else "原著未明确六至九转真元品阶用词；蛊仙阶段核心资源为仙元，见 economy.json 的仙元石条目。"
                ),
                "cultivation_factor": CULTIVATION_FACTOR[rank],
                "essence_max_formula": "essence_base * aptitude_factor * cultivation_factor",
                "essence_max_battle_base": STAGE_BASE_BATTLE.get(rank),
                "load_capacity": balance["human_base_body_capacity"],
                "thought_capacity_base": balance["thought_base_capacity"],
                "body_anchor": {
                    "health": balance["human_base_health"],
                    "strength": balance["human_base_strength"],
                    "body_capacity": balance["human_base_body_capacity"],
                },
                "advance_to_next_rank": None if rank == 9 else {
                    "target_rank": rank + 1,
                    "cultivate_stone_cost": _CULTIVATE_WORD.get(rank + 1),
                    "aptitude_gate": "yi" if rank + 1 >= 3 else "any",
                    "note": "丙等必须先在本局把资质提升到乙等，才可尝试三转。" if rank + 1 == 3 else "",
                },
                "in_launch_scope": in_launch,
                "is_immortal_tier": immortal,
                **trace(
                    CANON if not immortal else CANON,
                    CAN_CULTIVATION + CAN_APTITUDE + (CAN_IMMORTAL_BOUNDARY if immortal else []),
                    note,
                    "approved" if in_launch else "draft",
                    tunable=True,
                ),
            })
    # repair cultivate_stone_cost keys (kept explicit so the ladder is readable)
    costs = {2: balance.get("cultivate_rank_two_stone_cost"), 3: balance.get("cultivate_rank_three_stone_cost"),
             4: balance.get("cultivate_rank_four_stone_cost"), 5: balance.get("cultivate_rank_five_stone_cost")}
    for e in entities:
        a = e["advance_to_next_rank"]
        if a:
            a["cultivate_stone_cost"] = costs.get(e["rank"] + 1)
    return envelope("realm", entities, ["data/aptitude.json", "data/balance.json", "data/v1_battle.json"], generated_at)


# --------------------------------------------------------------------------
# paths.json
# --------------------------------------------------------------------------

def build_paths(generated_at: str) -> dict:
    schools = load("schools")
    pools = load("school_pools")
    balance = load("balance")
    gu = {g["id"]: g for g in load("gu")}
    loot = load("loot_tables")
    exclusions = balance.get("school_exclusions", [])
    entities = []
    for sid, meta in schools.items():
        raw_pool = pools.get(sid, [])
        pool = [g for g in raw_pool if g in gu and not (g.startswith("test_") or gu[g]["rank"] > 9)]
        ranks = sorted({gu[g]["rank"] for g in pool})
        tags = sorted({t for g in meta.get("starter_gu_ids", []) if g in gu for t in gu[g].get("tags", [])})
        conflicts = sorted({other for pair in exclusions if sid in pair for other in pair if other != sid})
        entities.append({
            "id": sid,
            "name_zh": meta["name"],
            "summary_zh": meta["summary"],
            "dao_tags": tags,
            "starter_gu_ids": list(meta.get("starter_gu_ids", [])),
            "pool_gu_ids": list(pool),
            "pool_size": len(pool),
            "pool_excluded_debug_entities": sorted(set(raw_pool) - set(pool)),
            "pool_ranks": ranks,
            "conflict_paths": conflicts,
            "cross_school_penalty_per_extra": balance["cross_school_penalty_per_extra"],
            "cross_school_exclusion_penalty": balance["cross_school_exclusion_penalty"],
            "material_resonance": loot.get("school_material_resonance", 0),
            "is_open_set": True,
            **trace(
                ADAPT, ADP_SYNERGY + CAN_GU_SYNERGY + CAN_SMALL_LIGHT,
                "流派名称与描述取自原著道途（血/气/力/魂/炼/光/智/梦/运/剑/木/火/水/风/金/土/奴/天/人/骨）；"
                "道标签为开放集合，权重、兼修罚值与流派互斥为游戏规则（GAME 条目），不是原著规则。",
                "approved", tunable=True,
            ),
        })
    return envelope("path", entities,
                    ["data/schools.json", "data/school_pools.json", "data/balance.json", "data/gu.json", "data/loot_tables.json"],
                    generated_at,
                    extra={"open_dao_tag_policy": "道标签是开放集合；本表所列 20 条道途是首批重点，不是封闭枚举。"})


# --------------------------------------------------------------------------
# gu.json
# --------------------------------------------------------------------------

# Hand-authored prototype gu carry no `source` field in data/gu.json. Per
# docs/lore/content-source-schema.md these must be traced, and the register
# notes several are still unregistered -> canon_review_status "needs_source".
CURATED_GU: dict[str, tuple[list[str], str, str]] = {
    "small_light_gu": (CAN_SMALL_LIGHT, "approved", "原著小光蛊：可辅助月光蛊、可参与合炼；信息/照明/伪装为扩展效果。"),
    "moonlight_gu": (CAN_SMALL_LIGHT, "approved", "原著月光蛊：与小光蛊并用时月刃体积与攻击力扩大。"),
    "moon_glow_gu": (CAN_SMALL_LIGHT, "needs_source", "月芒蛊＝月光蛊×1＋小光蛊×2，出处见 refinement_recipes 的 moon_glow_fixed 条目。"),
    "moon_ray_gu": (CAN_SMALL_LIGHT, "needs_source", "月痕蛊：月光蛊多晋升路线之一，输出名由策展补名。"),
    "moon_shadow_gu": (CAN_SMALL_LIGHT, "needs_source", "月影蛊＝月芒蛊＋雾步蛊（光×气跨流派）。"),
}
CURATED_GU_DEFAULT = ([], "needs_source", "原著语料可定位，但尚未在 docs/lore/canon-index.md 登记 CAN 条目。")


def build_gu(generated_at: str) -> dict:
    gu_list = load("gu")
    names = load("gu_names")
    v1 = load("v1_battle")
    role_default = v1["default_effect_by_role"]
    recipes = load("refinement_recipes")["recipes"]
    shops = load("shops")["offers"]
    loot_tiers = load("loot_tables")["loot"]
    node_list = load("nodes")["nodes"]

    by_output: dict[str, list] = collections.defaultdict(list)
    by_input: dict[str, list] = collections.defaultdict(list)
    for r in recipes:
        if r.get("output_gu_id"):
            by_output[r["output_gu_id"]].append(r)
        for gid in r.get("input_gu_ids", []) or []:
            by_input[gid].append(r)
    shop_by_gu: dict[str, list] = collections.defaultdict(list)
    for o in shops:
        if o.get("gu_id"):
            shop_by_gu[o["gu_id"]].append(o["id"])
        for gid in o.get("input_gu_ids", []) or []:
            shop_by_gu[gid].append(o["id"])
    drop_by_gu: dict[str, list] = collections.defaultdict(list)
    for tier, t in loot_tiers.items():
        for rarity, ids in (t.get("gu_pool", {}) or {}).get("by_rarity", {}).items():
            for gid in ids:
                drop_by_gu[gid].append(f"{tier}:{rarity}")
    node_by_gu: dict[str, list] = collections.defaultdict(list)
    for n in node_list:
        if n.get("enemy_kind"):
            node_by_gu[n["enemy_kind"]].append(n["id"])

    def recipe_view(r: dict) -> dict:
        return {"recipe_id": r["id"], "kind": r["kind"],
                "input_gu_ids": list(r.get("input_gu_ids", [])),
                "materials": r.get("materials", {}), "stone_cost": r.get("stone_cost", 0),
                "output_gu_id": r.get("output_gu_id", ""), "output_rank": r.get("output_rank"),
                "default_unlocked": bool(r.get("default_unlocked", False))}

    entities = []
    for g in gu_list:
        gid = g["id"]
        if "v1_effect" in g:
            effect, effect_source = dict(g["v1_effect"]), "explicit"
        elif "combat_effects" in g:
            effect, effect_source = {"kind": "composite", "parts": list(g["combat_effects"])}, "combat_effects"
        else:
            effect = dict(role_default.get(g["role"], {"kind": "none"}))
            effect_source = "role_default"
        if "true_qi_cost" in g:
            cost, cost_source = int(g["true_qi_cost"]), "true_qi_cost"
        elif "essence_cost" in g:
            cost, cost_source = int(g["essence_cost"]), "essence_cost"
        else:
            cost, cost_source = 1, "default"
        is_test = gid.startswith("test_") or int(g["rank"]) > 9
        if is_test:
            src_class, src_ids, review, note = ORIGINAL, GAME_RULES[:1], "needs_source", "调试/越界实体（rank>9），不进入正式内容池；仅用于端到端流程验证。"
        elif g.get("source") == "novel":
            src_class, src_ids, review = CANON, CAN_CULTIVATION + CAN_GU_CARE + CAN_SMALL_LIGHT, "draft"
            note = "原著蛊虫：取自原文语料，CAN 条目尚未逐条登记，故为 draft 状态。"
        elif g.get("source") == "school_derived":
            src_class, src_ids, review = ORIGINAL, GAME_RULES[:4], "draft"
            note = "批量派生蛊：由流派×角色×转数机械生成，其伤害数值与标签联动为游戏规则，不代表原著中同名或同类蛊虫的既定能力。"
        else:
            src_ids, review, note = CURATED_GU_DEFAULT
            src_class = CANON
            if gid in CURATED_GU:
                src_ids, review, note = CURATED_GU[gid]
        entities.append({
            "id": gid,
            "name_zh": names.get(gid, gid),
            "rank": int(g["rank"]),
            "rarity": g["rarity"],
            "school": g["school"],
            "role": g["role"],
            "value": int(g["value"]),
            "tags": list(g.get("tags", [])),
            "activation_cost": cost,
            "activation_cost_source": cost_source,
            "feeding": {
                "stone_per_stage": int(g.get("feeding_cost", 1)),
                "feed_points_per_stage": int(g.get("feeding_need", {}).get("feed_points", int(g.get("feeding_cost", 1)))),
            },
            "effect": effect,
            "effect_source": effect_source,
            "combat_key": g.get("combat", ""),
            "low_rank_exception": bool(g.get("low_rank_exception", False)),
            "sword_mark_cost": bool(g.get("sword_mark_cost", False)),
            "life_cost": int(g.get("life_cost", 0)),
            "is_test_entity": is_test,
            "in_launch_scope": 1 <= int(g["rank"]) <= 3 and not is_test,
            "prototype_source": g.get("source", ""),
            "refine_as_output": [recipe_view(r) for r in by_output.get(gid, [])],
            "refine_as_input": sorted({r["id"] for r in by_input.get(gid, [])}),
            "shop_offer_ids": sorted(set(shop_by_gu.get(gid, []))),
            "drop_tiers": sorted(set(drop_by_gu.get(gid, []))),
            **trace(src_class, src_ids, note, review, tunable=True),
        })
    stats = {
        "total": len(entities),
        "by_effect_source": dict(collections.Counter(e["effect_source"] for e in entities)),
        "by_role": dict(collections.Counter(e["role"] for e in entities)),
        "by_rarity": dict(collections.Counter(e["rarity"] for e in entities)),
        "by_rank": {str(k): v for k, v in sorted(collections.Counter(e["rank"] for e in entities).items())},
        "by_school": dict(collections.Counter(e["school"] for e in entities)),
        "by_source_class": dict(collections.Counter(e["source_class"] for e in entities)),
        "test_entities": [e["id"] for e in entities if e["is_test_entity"]],
        "gu_with_refine_output": sum(1 for e in entities if e["refine_as_output"]),
        "gu_with_refine_input": sum(1 for e in entities if e["refine_as_input"]),
        "gu_in_shop": sum(1 for e in entities if e["shop_offer_ids"]),
        "gu_in_drop_tables": sum(1 for e in entities if e["drop_tiers"]),
    }
    return envelope("gu", entities, ["data/gu.json", "data/gu_names.json", "data/v1_battle.json", "data/balance.json",
                                     "data/refinement_recipes.json", "data/shops.json", "data/loot_tables.json"],
                    generated_at, extra={"gu_stats": stats})


# --------------------------------------------------------------------------
# economy.json
# --------------------------------------------------------------------------

def build_economy(generated_at: str) -> dict:
    balance = load("balance")
    loot = load("loot_tables")
    pacing = load("pacing")
    shops = load("shops")["offers"]
    reputation = load("reputation")
    mats = loot["materials"]
    layer_budget = {str(k): {"stone_budget": v["stone_budget"], "shop_price_pct": v["shop_price_pct"],
                             "shop_max_tier": v["shop_max_tier"]} for k, v in pacing["layers"].items()}
    resource = lambda **kw: kw
    entities = [{
        "id": "south_jiang_mortal_economy",
        "name_zh": "南疆凡人经济（元石本位）",
        "scope": "mortal_run",
        "resources": [
            {"id": "primeval_stone", "name_zh": "元石", "unit": "块", "start_value": 12, "hard_cap": None,
             "channels_in": ["battle_reward", "event_stone_gain", "node_reward", "sell_material", "sell_gu", "commission"],
             "channels_out": ["gu_purchase", "material_purchase", "refine_cost", "cultivate_cost", "feed_cost",
                              "remove_card", "remove_imprint", "remove_curse", "retreat", "stone_to_essence"],
             "tunable": True},
            {"id": "gu_material", "name_zh": "蛊材", "unit": "份", "start_value": 0, "hard_cap": None,
             "channels_in": ["battle_loot", "event_gain", "harvest", "shop_purchase"],
             "channels_out": ["refine_input", "feeding_input", "sell", "self_use"], "tunable": True},
            {"id": "lifespan", "name_zh": "寿元", "unit": "年", "start_value": 60, "hard_cap": None,
             "channels_in": ["lifespan_milestone_stage_ledger", "lifespan_milestone_boss_defeated", "black_market_exchange"],
             "channels_out": ["aptitude_reroll", "black_market_exchange", "wash_notoriety", "event_cost", "curse_recovery"],
             "tunable": True},
            {"id": "soul", "name_zh": "魂", "unit": "点", "start_value": 1, "hard_cap": 4,
             "channels_in": ["soul_pill", "black_market_exchange", "soul_gain_event"],
             "channels_out": ["soul_burst", "delayed_event_cost", "curse_cost"], "tunable": True},
            {"id": "primeval_essence", "name_zh": "真元", "unit": "点", "start_value": None,
             "hard_cap": "10 * aptitude_factor * cultivation_factor",
             "channels_in": ["turn_regen", "stone_to_essence", "material_use"],
             "channels_out": ["gu_activation", "kill_move"], "tunable": True},
            {"id": "health", "name_zh": "气血", "unit": "点", "start_value": 80, "hard_cap": 80,
             "channels_in": ["rest_heal", "healing_gu", "material_use"],
             "channels_out": ["enemy_damage", "hazard_cost", "event_cost", "backlash", "overload"], "tunable": True},
            {"id": "thought", "name_zh": "念头", "unit": "点", "start_value": 3, "hard_cap": 3,
             "channels_in": ["turn_refresh"], "channels_out": ["gu_activation", "basic_attack", "kill_move"], "tunable": True},
            {"id": "immortal_stone", "name_zh": "仙元石", "unit": "块", "start_value": 0, "hard_cap": None,
             "channels_in": ["heaven_court_monopoly"], "channels_out": ["immortal_tier_only"],
             "in_launch_scope": False, "tunable": False},
        ],
        "price_anchors": {
            "gu_value_by_rank": balance["gu_value_by_rank"],
            "public_buyback_ratio": balance["public_buyback_ratio"],
            "low_liquidity_ratio": balance["low_liquidity_ratio"],
            "demand_price_tiers": balance["demand_price_tiers"],
            "remove_card_cost": balance["remove_card_cost"],
            "remove_imprint_cost": balance["remove_imprint_cost"],
            "imprint_capacity": balance["imprint_capacity"],
            "free_pair_success_pct": balance["free_pair"]["success_pct"],
            "free_pair_stone_cost": balance["free_pair"]["stone_cost"],
            "material_refine_efficiency": balance["material_refine_efficiency"],
            "stone_per_t1_material": balance["stone_per_t1_material"],
            "stone_to_essence_per_stone": balance["stone_to_essence_per_stone"],
            "retreat_stone_cost": balance["retreat_stone_cost"],
            "base_speed": balance["base_speed"], "speed_min": balance["speed_min"], "speed_max": balance["speed_max"],
            "gu_estimate_ratio": balance["gu_estimate_ratio"],
            "reference_price_note": "每条蛊材的 reference_value 是黑市/需求价基准；public_liquidity 决定公开市场可兑现比例。",
        },
        "battle_stone_rewards": balance["battle_stone_rewards"],
        "layer_budget": layer_budget,
        "inflation": {
            "shop_price_pct_by_layer": [pacing["layers"][k]["shop_price_pct"] for k in sorted(pacing["layers"], key=int)],
            "revisit_price_pct_per_visit": reputation["effects"]["revisit_price_pct_per_visit"],
            "revisit_price_cap_pct": reputation["effects"]["revisit_price_cap_pct"],
            "service_use_price_pct_per_use": reputation["effects"]["service_use_price_pct_per_use"],
            "service_use_price_cap_pct": reputation["effects"]["service_use_price_cap_pct"],
            "layer_stone_step_pct": balance["battle_stone_rewards"]["layer_step_pct"],
        },
        "black_market_exchange": [
            {"from": "lifespan", "amount_in": 20, "to": "soul", "amount_out": 1},
            {"from": "soul", "amount_in": 1, "to": "lifespan", "amount_out": 10},
            {"from": "health", "amount_in": 20, "to": "soul", "amount_out": 1},
            {"from": "soul", "amount_in": 1, "to": "health", "amount_out": 10},
            {"from": "health", "amount_in": 20, "to": "lifespan", "amount_out": 10},
        ],
        "black_market_asymmetry_note": "同一对资源双向兑换率不对称（如 寿20→魂1 与 魂1→寿10，隐含约 100 倍往返损耗），属已登记风险项。",
        "shop_offer_histogram": dict(collections.Counter(o["kind"] for o in shops)),
        "shop_offers": [{
            "id": o["id"], "kind": o["kind"], "tier": int(o.get("tier", 0)),
            "gu_id": o.get("gu_id", ""), "material_id": o.get("material_id", ""),
            "stone_cost": o.get("stone_cost"), "lifespan_cost": o.get("lifespan_cost"),
            "soul_gain": o.get("soul_gain"),
            "cost_kind": o.get("cost_kind", ""), "cost_amount": o.get("cost_amount"),
            "gain_kind": o.get("gain_kind", ""), "gain_amount": o.get("gain_amount"),
            "input_gu_ids": o.get("input_gu_ids", []), "rewards": o.get("rewards", []),
            "recipe_id": o.get("recipe_id", ""), "school": o.get("school", ""),
            "card_key": o.get("card_key", ""),
            **trace(ADAPT, CAN_ECONOMY + CAN_NANJIANG,
                    "元石本位、议价与商队临时开市是原著事实；每条报价的档位与价格数值为游戏规则（附录 B 口径）。",
                    "approved", tunable=True),
        } for o in shops],
        "material_reference_prices": {k: {"name_zh": v.get("name_zh", k), "value": v.get("value"), "reference_value": v.get("reference_value"),
                                          "public_liquidity": v.get("public_liquidity")} for k, v in mats.items()},
        "dragon_fish_replacement": balance["dragon_fish_replacement"],
        **trace(ADAPT, CAN_ECONOMY + CAN_GU_CARE + CAN_NANJIANG,
                "元石本位、元石兼作修行/战斗/炼蛊消耗品是原著事实；层预算、通胀乘数、黑市兑换率与回购比例为游戏规则。"
                "仙元石仅登记为蛊仙阶段资源，首发不参与凡人跑局（CAN-IMMORTAL-BOUNDARY-001）。",
                "approved", tunable=True),
    }]
    return envelope("economy", entities, ["data/balance.json", "data/loot_tables.json", "data/pacing.json",
                                          "data/shops.json", "data/reputation.json"], generated_at)


# --------------------------------------------------------------------------
# factions.json
# --------------------------------------------------------------------------

def build_factions(generated_at: str) -> dict:
    reputation = load("reputation")
    npcs = load("npcs")
    balance = load("balance")
    fx = reputation["effects"]
    rel_levels = [
        {"id": "hostile", "label_zh": "敌对", "min_points": -99, "max_points": -2,
         "price_pct": fx["price_cap_pct"], "hostile_chance_pct": fx["hostile_chance_pct_per_point"] * 2,
         "first_move_chance_pct": fx["first_move_chance_pct_per_point"] * 2},
        {"id": "cold", "label_zh": "冷淡", "min_points": -1, "max_points": -1,
         "price_pct": fx["price_pct_per_point"], "hostile_chance_pct": fx["hostile_chance_pct_per_point"],
         "first_move_chance_pct": fx["first_move_chance_pct_per_point"]},
        {"id": "neutral", "label_zh": "中立", "min_points": 0, "max_points": 0,
         "price_pct": 0, "hostile_chance_pct": 0, "first_move_chance_pct": 0},
        {"id": "warm", "label_zh": "友善", "min_points": 1, "max_points": 2,
         "price_pct": -fx["price_pct_per_point"], "hostile_chance_pct": 0, "first_move_chance_pct": 0},
        {"id": "honored", "label_zh": "尊崇", "min_points": 3, "max_points": 99,
         "price_pct": -fx["price_pct_per_point"] * 2, "hostile_chance_pct": 0, "first_move_chance_pct": 0},
    ]
    npc_ids = {n["id"] for n in npcs}
    base_route = {"price_pct": 0, "hostile_chance_pct": 0, "first_move_chance_pct": 0, "extra_encounter_weight": 0, "retreat_allowed": True, "pursuit_allowed": False}
    entities = []

    def faction(fid, name, summary, agents, route, src_class, src_ids, note, status="draft"):
        entities.append({
            "id": fid, "name_zh": name, "summary_zh": summary, "entity_kind": "faction",
            "agents": [a for a in agents if a in npc_ids] or agents,
            "relation_levels": rel_levels,
            "route_effects": {**base_route, **route},
            "trade_effects": {"shop_price_pct": route.get("price_pct", 0),
                              "buyback_ratio": balance["public_buyback_ratio"]},
            "pursuit_effects": {"pursuit_allowed": route.get("pursuit_allowed", False),
                                "pursuit_pressure_pct": route.get("pursuit_pressure_pct", 0)},
            **trace(src_class, src_ids, note, status, tunable=True),
        })

    faction("qingmao_clan", "青茅山寨", "青茅山三家山寨之一的秩序方：守备、征丁、赏功与家族权柄。",
            ["clan_warden", "school_elder", "clan_elder", "clan_patriarch", "caravan_steward"],
            {"price_pct": -10, "hostile_chance_pct": 0, "retreat_allowed": True, "pursuit_allowed": True, "pursuit_pressure_pct": 15},
            ADAPT, CAN_FACTION + CAN_BEAST_TIDE + ADP_FACTION,
            "山寨聚居、家老/族长权柄、战斗蛊师为护卫、兽潮时分摊防线均为原著事实；"
            "「青茅山寨」这一具体势力名与关系阈值、赏功数值为游戏原创（ADP-FACTION-001 的首发四势力之一）。")
    faction("scarlet_caravan", "丹霞商队", "跨山险行商的车队：临时开市、以蛊换蛊、情报买卖与护送委托。",
            ["caravan_steward", "wandering_peddler"],
            {"price_pct": 0, "hostile_chance_pct": 5, "retreat_allowed": True},
            ADAPT, CAN_NANJIANG + ADP_FACTION,
            "商队越山运输、驻扎成市、与山寨互赖为原著事实；商队名号、报价倍率与换物规则为游戏原创。")
    faction("ridge_scavengers", "拾骨帮", "山道上的体制外散修与拾荒者：劫掠、赌斗、以命换石。",
            ["ridge_extortionist", "wandering_peddler"],
            {"price_pct": 10, "hostile_chance_pct": 25, "first_move_chance_pct": 20,
             "extra_encounter_weight": 10, "pursuit_allowed": True, "pursuit_pressure_pct": 25},
            ORIGINAL, CAN_CULTIVATOR + ADP_FACTION,
            "「体制外者机缘巧合成为魔道蛊师」是原著事实；本势力名称、成员与劫掠机制为游戏原创。")
    faction("miasma_cult", "瘴蛊教", "盘踞瘴脉的魔道教团：以蛊蚀与毒誓契约换取短期力量。",
            ["wandering_healer", "earth_vein_scout"],
            {"price_pct": 20, "hostile_chance_pct": 30, "first_move_chance_pct": 15,
             "extra_encounter_weight": 15, "retreat_allowed": False, "pursuit_allowed": True, "pursuit_pressure_pct": 35},
            ORIGINAL, CAN_CULTIVATOR + ADP_FACTION,
            "魔道作为修行路径是原著事实；本教团名称、诅咒契约与敌意机制为游戏原创。")
    faction("beast_tide", "兽潮", "周期性天灾：兽群成潮冲击山寨，蛊师是唯一能挡的墙。",
            [],
            {"price_pct": 0, "hostile_chance_pct": 100, "first_move_chance_pct": 50,
             "extra_encounter_weight": 25, "retreat_allowed": False, "pursuit_allowed": True, "pursuit_pressure_pct": 40},
            CANON, ["CAN-BEAST-TIDE-001", "CAN-BEAST-TIDE-002", "CAN-BEAST-SWARM-001"],
            "兽潮作为周期性天灾、狼潮三年一次、雷冠头狼是狼群首领均为原著事实；本条目不是可谈判势力，"
            "而是地图压力源，登记在此以便统一关系/路线影响面。", status="approved")
    entities.append({
        "id": "notoriety_axis", "name_zh": "恶名轴（全局）", "entity_kind": "global_axis",
        "summary_zh": "杀死中立者与背信会累积恶名；恶名提高全场价格与敌方敌意，洗白需以寿元为代价。",
        "agents": [], "relation_levels": rel_levels,
        "route_effects": base_route,
        "trade_effects": {"shop_price_pct": 0, "buyback_ratio": balance["public_buyback_ratio"]},
        "pursuit_effects": {"pursuit_allowed": True, "pursuit_pressure_pct": 0},
        "notoriety": {"gains": reputation["gains"], "effects": reputation["effects"]},
        **trace(ADAPT, ADP_FACTION + CAN_CULTIVATOR,
                "恶名惩罚价格与敌意为游戏规则；洗白消耗寿元为不可逆代价，执行前必须预检并明确提示。",
                "approved", tunable=True),
    })
    return envelope("faction", entities, ["data/reputation.json", "data/npcs.json", "data/balance.json"], generated_at,
                    extra={"relation_model": {"axis_range": [-3, 3], "levels": [l["id"] for l in rel_levels],
                                              "simultaneous_active_factions": [2, 3],
                                              "note": "每局激活 2–3 个势力（ADP-FACTION-001）；玩家不能让所有势力永久满意。"}})


# --------------------------------------------------------------------------
# regions.json
# --------------------------------------------------------------------------

def build_regions(generated_at: str) -> dict:
    pacing = load("pacing")
    nodes = load("nodes")
    enemy_list = load("enemies")
    enemies = {e["id"]: e for e in enemy_list}
    node_list = nodes["nodes"]
    display = load("names")
    by_id = {n["id"]: n for n in node_list}
    entities = [{
        "id": "south_jiang", "name_zh": "南疆", "entity_kind": "macro_region", "layer": None,
        "summary_zh": "广阔而险恶的山域，人族以山寨聚居，商队跨山险运货；低转蛊师通常没有独自远游的资格。",
        "map_structure": {"layers": 5, "first_run_node_budget": 13,
                          "node_budget_per_run": [40, 55], "row_rest_every": 2},
        "routes": ["mountain_pass", "beast_trail", "black_market", "earth_vein", "mist_shrine"],
        "template_pools": pacing["category_pools"],
        "npc_roster": [{
            "id": n["id"], "goals": n.get("goals", []), "bottom_line": n.get("bottom_line", ""),
            "will": int(n.get("will", 0)), "known_facts": n.get("known_facts", []),
            "retreat": n.get("retreat", ""), "reinforcements": n.get("reinforcements", ""),
            "injury_reaction": n.get("injury_reaction", ""), "stock": n.get("stock", []),
            **trace(ADAPT, CAN_NANJIANG + ADP_FACTION,
                    "NPC 的动机、底线与受伤反应是游戏设计；商队、地脉与山寨的利害结构取自原著。",
                    "approved", tunable=True),
        } for n in load("npcs")],
        "display_names": {"types": display.get("types", {}), "actions": display.get("actions", {}),
                          "outcomes": display.get("outcomes", {})},
        "node_templates": [{
            "id": n["id"], "name_zh": display.get("nodes", {}).get(n["id"], n["id"]),
            "type": n["type"], "type_zh": display.get("types", {}).get(n["type"], n["type"]),
            "stage": n["stage"], "visible": bool(n["visible"]),
            "summary_zh": n.get("summary", ""), "choices": n["choices"], "time_scale": n["time_scale"],
            "on_skip": n["on_skip"], "next_ids": n.get("next_ids", []),
            "enemy_kind": n.get("enemy_kind", ""), "enemy_theme": n.get("enemy_theme", ""),
            "enemy_kinds": n.get("enemy_kinds", []), "npc_id": n.get("npc_id", ""),
            "layer_boss": n.get("layer_boss"), "boss_pool": n.get("boss_pool", []),
            "event_pool": n.get("event_pool", []), "event_id": n.get("event_id", ""),
            "ascension_grants": n.get("ascension_grants", []),
            **trace(CANON if n["id"] in ("neutral_wanderer", "ridge_caravan", "stage_one_ledger",
                                         "moonlit_trail", "yizang_ridge", "ridge_black_market",
                                         "toxic_mountain_path", "flooded_cave", "body_imprint_ritual")
                    else ADAPT,
                    CAN_NANJIANG + CAN_GU_CARE,
                    "节点类型（战斗/休整/交易/炼蛊/传承/险地/地脉/遗藏）取自原著场景；"
                    "每个模板的选项集、时间尺度与跳过后果为游戏规则。",
                    "approved", tunable=True),
        } for n in node_list],
        "enemy_roster": [{
            "id": e["id"], "name_zh": display.get("enemies", {}).get(e["id"], e["id"]),
            "theme": e["theme"], "theme_zh": display.get("themes", {}).get(e["theme"], e["theme"]),
            "grade": e["grade"], "tier": e["tier"], "tier_zh": {"common": "杂兵", "elite": "精英", "boss": "层主"}.get(e["tier"], e["tier"]),
            "rank": int(e["rank"]), "hp": int(e["hp"]),
            "intent": e["intent"], "reactions": e.get("reactions", []),
            "clues": e.get("clues", []), "phases": e.get("phases"),
            "boss_layer": next((n.get("layer_boss") for n in nodes["nodes"] if n.get("layer_boss") and e["id"] in (n.get("boss_pool") or [n.get("enemy_kind")])), None),
            "is_final_boss": e["id"] == nodes["nodes"][[n["id"] for n in nodes["nodes"]].index("final_boss_stand")].get("enemy_kind"),
            **trace(CANON, CAN_RANK_LADDER + CAN_BEAST_TIER + CAN_BEAST_TIDE,
                    "战力阶梯（凡人 < 普通野兽 < 一转 < … < 五转）与兽王百/千/万分级的判定依据为原著事实；"
                    "每只敌人的 HP、意图伤害与反制数值为游戏规则，并按层下压，不代表原著战力。",
                    "approved", tunable=True if e["tier"] != "boss" else False),
        } for e in enemy_list],
        "travel_gate": {"min_rank_for_free_travel": 3,
                        "note": "三转才具备远游能力（CAN-NANJIANG-002）；低转必须经由护送、伪装或撤离路径。"},
        **trace(CANON, CAN_NANJIANG + CAN_BEAST_TIDE,
                "南疆地理、山寨聚居、商队互赖、低转远游限制、兽潮天灾均为原著事实；"
                "5 层路线图与节点数是游戏化抽象（ADP-RUN-001）。", "approved", tunable=True),
    }]
    for lk in sorted(pacing["layers"], key=int):
        L = pacing["layers"][lk]
        layer = int(lk)
        stage_word = ["one", "two", "three", "four", "five"][layer - 1]
        stage_nodes = [n["id"] for n in node_list if n["stage"] == stage_word]
        boss_seat = next((n["id"] for n in node_list if n.get("layer_boss") == layer), None)
        boss_pool = by_id[boss_seat].get("boss_pool") or ([by_id[boss_seat]["enemy_kind"]] if boss_seat and by_id[boss_seat].get("enemy_kind") else [])
        boss = boss_pool[0] if boss_seat and len(boss_pool) == 1 else None
        entities.append({
            "id": f"layer_{layer}",
            "name_zh": L["title"],
            "entity_kind": "layer",
            "layer": layer,
            "stage": stage_word,
            "summary_zh": f"第 {layer} 层。{L['title']}，本层真元/元石预算 {L['stone_budget']}，商店加价 {L['shop_price_pct']}%。",
            "rows_min": L["rows"][0], "rows_max": L["rows"][1],
            "row_nodes_min": L["row_nodes"][0], "row_nodes_max": L["row_nodes"][1],
            "entry_nodes_min": L["entry_nodes"][0], "entry_nodes_max": L["entry_nodes"][1],
            "category_weights": L["category_weights"],
            "category_weight_sum": sum(L["category_weights"].values()),
            "anchors": L["anchors"],
            "node_pool": L["pool"],
            "stage_node_templates": stage_nodes,
            "boss_seat": boss_seat,
            "boss_pool": boss_pool,
            "final_boss": boss,
            "boss_pool_is_fixed": bool(boss_seat and not by_id[boss_seat].get("boss_pool")),
            "enemy_rank_min": L["enemy_rank_min"],
            "enemy_rank_max": L["enemy_rank_max"],
            "enemy_turn": L["enemy_turn"],
            "loot_material_count": L["loot"]["material_count"],
            "loot_rarity_weights": L["loot"]["weights"],
            "shop_price_pct": L["shop_price_pct"],
            "shop_max_tier": L["shop_max_tier"],
            "stone_budget": L["stone_budget"],
            "enemy_pool": sorted([e["id"] for e in enemies.values()
                                  if e["tier"] != "boss" and L["enemy_rank_min"] <= e["rank"] <= L["enemy_rank_max"]]),
            **trace(CANON if layer == 1 else ADAPT,
                    CAN_NANJIANG + CAN_BEAST_TIDE,
                    "层名与「青茅山外围」取自原著地理线索；每层行数、宽度、分类权重、锚点、Boss 席位与预算为游戏规则。"
                    "Boss 池按有效强度（hp × 层倍率）滑动窗口选取，相邻层不重复。",
                    "approved", tunable=True),
        })
    entities.append({
        "id": "ascension_window", "name_zh": "升仙之窗", "entity_kind": "special_stage", "layer": 5,
        "summary_zh": "夺取固定遗藏并撤离后出现的终局窗口：以本局构筑、伤势、资源、情报与势力关系映射为升仙抉择。",
        "node_id": nodes["ascension_node"]["id"],
        "choices": nodes["ascension_node"]["choices"],
        "on_skip": nodes["ascension_node"]["on_skip"],
        "visible": nodes["ascension_node"]["visible"],
        **trace(ADAPT, CAN_ASCENSION + ADP_ASCENSION,
                "碎窍纳气、天地人三气、失败不可逆为原著事实；界面、阈值、成功率与结局文本为游戏规则。"
                "首发不把蛊仙阶段做成可继续游玩的正式内容。", "approved", tunable=True),
    })
    return envelope("region", entities, ["data/pacing.json", "data/nodes.json", "data/enemies.json",
                                          "data/names.json", "data/npcs.json"],
                    generated_at)


# --------------------------------------------------------------------------
# events.json
# --------------------------------------------------------------------------

def build_events(generated_at: str) -> dict:
    ev = load("events")["events"]
    curses = {c["id"]: c for c in load("curse")}
    entities = []
    for e in ev:
        eid = e["id"]
        effects_accept = {
            "stone_gain": int(e.get("stone_gain", 0)),
            "health_cost": int(e.get("health_cost", 0)),
            "delayed_soul_cost": int(e.get("delayed_soul_cost", 0)),
            "delayed_trigger": e.get("delayed_trigger", ""),
            "curse_id": e.get("curse_id", ""),
            "curse_name_zh": curses.get(e.get("curse_id", ""), {}).get("name_zh", ""),
        }
        entities.append({
            "id": eid,
            "name_zh": e.get("title", eid),
            "kind": e.get("kind", "cache"),
            "summary_zh": e.get("summary", ""),
            "trigger": {"node_type": "event", "pool_owner": "event_node", "selection": "seeded_pick_from_node_event_pool"},
            "options": [
                {"id": "accept", "label_zh": "接受", "effects": effects_accept,
                 "precheck_required": bool(effects_accept["health_cost"] or effects_accept["delayed_soul_cost"] or effects_accept["curse_id"]),
                 "precheck_text_zh": "接受后将立刻扣除气血并背负延迟代价，蛊虫可能反噬；不可撤销。"},
                {"id": "decline", "label_zh": "离开", "precheck_required": False, "precheck_text_zh": "",
                 "effects": {"stone_gain": 0, "health_cost": 0, "delayed_soul_cost": 0,
                             "delayed_trigger": "", "curse_id": "", "curse_name_zh": ""}},
            ],
            "gain_text_zh": e.get("flavor_gain", ""),
            "unknown_note_zh": e.get("unknown_note", ""),
            "delayed_cost": {"soul": int(e.get("delayed_soul_cost", 0)), "trigger": e.get("delayed_trigger", "")},
            "health_cost": int(e.get("health_cost", 0)),
            "stone_gain": int(e.get("stone_gain", 0)),
            "curse_id": e.get("curse_id", ""),
            **trace(ORIGINAL, GAME_RULES[:2] + CAN_BEAST_TIDE,
                    "事件母题（遗藏/兽潮/赌斗/斗蛊/秘境/血脉/元石/本命蛊）取自原著高频场景；"
                    "具体事件文案、数值与诅咒绑定为游戏原创内容，不是原著情节。",
                    "draft", tunable=True),
        })
    return envelope("event", entities, ["data/events.json", "data/curse.json"], generated_at,
                    extra={"event_curse_pool": [{"id": c["id"], "name_zh": c["name_zh"], "effect": c["effect"],
                                                 "base_intensity": c["base_intensity"],
                                                 "escalation_per_stage": c["escalation_per_stage"],
                                                 "removal_base_cost": c["removal_base_cost"]} for c in curses.values()]})


# --------------------------------------------------------------------------
# loot.json
# --------------------------------------------------------------------------

CORE_MATERIALS = ["beast_blood", "beast_bone", "venom_sac", "moon_dew", "moon_blue_petal",
                  "boar_king_tusk", "inheritance_token"]


def build_loot(generated_at: str) -> dict:
    lt = load("loot_tables")
    relics = load("relics")
    balance = load("balance")
    materials = []
    for mid, m in lt["materials"].items():
        materials.append({
            "id": mid,
            "name_zh": m.get("name_zh", mid),
            "value": m.get("value"),
            "value_tier": m.get("value_tier"),
            "rank": m.get("rank"),
            "dao_tags": m.get("dao_tags", []),
            "diet_tags": m.get("diet_tags", []),
            "form": m.get("form", ""),
            "quality_band": m.get("quality_band", ""),
            "is_common": bool(m.get("is_common", False)),
            "is_exclusive": bool(m.get("is_exclusive", False)),
            "divisible": bool(m.get("divisible", False)),
            "public_liquidity": m.get("public_liquidity"),
            "reference_value": m.get("reference_value"),
            "acquisition_mode": m.get("acquisition_mode", ""),
            "origin_status": m.get("origin_status", ""),
            "use": m.get("use", {}),
            "is_core_material": mid in CORE_MATERIALS,
            **trace(CANON if m.get("origin_status") == "original" else ORIGINAL,
                    CAN_GU_CARE + CAN_ECONOMY,
                    (m.get("semantic_basis", {}) or {}).get("rationale", "游戏扩展材料。"),
                    "draft", tunable=True),
        })
    relic_entities = []
    for r in relics:
        relic_entities.append({
            "id": r["id"], "name_zh": r["id"], "grade": r.get("grade", ""), "rarity": r.get("rarity", ""),
            "hooks": r.get("hooks", []),
            **trace(ORIGINAL, GAME_RULES[:3], "遗物钩子为游戏原创机制，不是原著道具。", "draft", tunable=True),
        })
    entities = [{
        "id": "south_jiang_loot",
        "name_zh": "南疆掉落与遗物",
        "core_material_ids": CORE_MATERIALS,
        "materials": materials,
        "relics": relic_entities,
        "tiers": lt["loot"],
        "pity": lt["pity"],
        "rarity_weights": {k: v.get("gu_pool", {}).get("weights", {}) for k, v in lt["loot"].items()},
        "school_material_resonance": lt.get("school_material_resonance"),
        "school_material_resonance_note": lt.get("school_material_resonance_note", ""),
        "gu_drop_chance_pct": {k: v.get("gu_chance_pct") for k, v in lt["loot"].items()},
        "sell_prices": {"public_buyback_ratio": balance["public_buyback_ratio"],
                        "low_liquidity_ratio": balance["low_liquidity_ratio"]},
        **trace(ADAPT, CAN_GU_CARE + CAN_ECONOMY + CAN_BEAST_TIER,
                "掉落按敌人档位（common/elite/boss）分层是游戏规则；保底计数按档位独立，只补池内已定义存在的目标带段，"
                "不跨档拉取、不凭空生成。", "approved", tunable=True),
    }]
    return envelope("loot", entities, ["data/loot_tables.json", "data/relics.json", "data/balance.json"], generated_at)


# --------------------------------------------------------------------------
# balance.json  (single point of tuning)
# --------------------------------------------------------------------------

def build_balance(generated_at: str) -> dict:
    b = load("balance")
    v1 = load("v1_battle")
    pacing = load("pacing")
    aptitude = load("aptitude")
    reputation = load("reputation")
    synthesis = load("synthesis")
    contracts = load("contracts")
    entity = {
        "id": "world_balance",
        "name_zh": "世界模型集中参数表",
        "note_zh": "所有引擎逻辑必须从本表读参数，不得硬编码数值；改这里即可整体调参（验收 A5）。",
        "growth": {
            "essence_base": aptitude["essence_base"],
            "aptitude_factor": aptitude["aptitude_factor"],
            "aptitude_capacity_ratio": {"ding": 0.23, "bing": 0.44, "yi": 0.67, "jia": 0.89, "ten_extreme": 1.0},
            "cultivation_factor": aptitude["cultivation_factor"],
            "regen_pct_out_of_run": aptitude["regen_pct"],
            "regen_pct_battle": v1["regen_pct"],
            "stage_base_battle": v1["stage_base"],
            "aptitude_recovery_multiplier": b["aptitude_recovery_multiplier"],
            "stone_to_essence_per_stone": b["stone_to_essence_per_stone"],
            "rank_step_ratio": b["rank_step_ratio"],
            "standard_hit_ratio": b["standard_hit_ratio"],
            "standard_activation_cost": b["standard_activation_cost"],
            "human_base_health": b["human_base_health"],
            "human_base_strength": b["human_base_strength"],
            "human_base_body_capacity": b["human_base_body_capacity"],
            "thought_base_capacity": b["thought_base_capacity"],
            "unarmed_damage_ratio": b["unarmed_damage_ratio"],
            "fixed_defense_ratio": b["fixed_defense_ratio"],
            "aptitude_reroll": aptitude["paths"][0],
            "cultivate_stone_cost": {"2": b["cultivate_rank_two_stone_cost"], "3": b["cultivate_rank_three_stone_cost"],
                                     "4": b["cultivate_rank_four_stone_cost"], "5": b["cultivate_rank_five_stone_cost"]},
            "aptitude_hard_gate": {"target_rank": 3, "min_aptitude": "yi",
                                   "note": "丙等必须先在本局提升资质，才可尝试三转（ADP-CULTIVATION-001）。"},
        },
        "run": {
            "starter": {"aptitude": "bing", "rank": 1, "stage": "initial", "hp": 80, "hp_max": 80,
                        "lifespan": 60, "lifespan_max": 60, "soul": 1, "soul_max": 4, "stone": 12,
                        "gu": ["small_light_gu"], "path": "light", "thought_max": b["thought_base_capacity"]},
            "action_points_by_soul": [{"min_soul": 10000, "ap": 6}, {"min_soul": 1000, "ap": 5},
                                      {"min_soul": 100, "ap": 4}, {"min_soul": 10, "ap": 3}, {"min_soul": 0, "ap": 2}],
            "thought_cost_per_action": v1["thought_cost_default"],
            "fight_damage_base": v1["fight_damage_base"],
            "layer_count": len(pacing["layers"]),
            "first_run_node_budget": 13,
            "rest_heal_pct": 30,
            "rest_heal_flat": 0,
            "rows_between_forced_rest": 2,
            "lifespan_milestones": pacing["lifespan_milestones"],
            "advance_bonus_by_rank": pacing["advance_bonus_by_rank"],
            "ending_after_stage": pacing["ending_after_stage"],
            "enemy_tier_weights": pacing["enemy_weights"],
            "turn_scaling": pacing["turn_scaling"],
            "boss_layer_mult": v1["boss_layer_mult"],
            "max_seal_turns": v1["max_seal_turns"],
            "mark_scratch_per_layer": v1["mark_scratch_per_layer"],
            "mark_scratch_cap": v1["mark_scratch_cap"],
            "sword_dao_marks_init": v1["sword_dao_marks_init"],
            "sword_downgrade_every": v1["sword_downgrade_every"],
            "retreat_stone_cost": b["retreat_stone_cost"],
            "feed_tier": b["feed_tier"],
            "max_battle_rounds": 40,
            "stalemate_rule": "retreat_with_cost",
            "stalemate_note_zh": "敌方意图全部处于 cooldown 时原型口径为「调息不出手」；"
                                 "若双方都无法终结战斗，回合数超过 max_battle_rounds 即按撤退结算"
                                 "（付 retreat_stone_cost，不足则改付气血），避免不可终结的僵局。",
            "difficulty": {
                "enemy_hp_mult": 1.0,
                "enemy_damage_mult": 1.0,
                "note_zh": "默认 1.0 = 原型口径，不改变任何既有语义。这是唯一的整体难度旋钮："
                           "tools/simulate_balance.py --hp-mult 会临时覆盖它做灵敏度扫描，不会写回文件。",
            },
            "stats_hp_death_threshold": 0,
            "stats_lifespan_death_threshold": 0,
            "stats_soul_death_threshold": 0,
            "death_axes": ["hp", "lifespan", "soul"],
        },
        "economy": {
            "gu_value_by_rank": b["gu_value_by_rank"],
            "public_buyback_ratio": b["public_buyback_ratio"],
            "low_liquidity_ratio": b["low_liquidity_ratio"],
            "demand_price_tiers": b["demand_price_tiers"],
            "material_refine_efficiency": b["material_refine_efficiency"],
            "stone_per_t1_material": b["stone_per_t1_material"],
            "remove_card_cost": b["remove_card_cost"],
            "remove_imprint_cost": b["remove_imprint_cost"],
            "imprint_capacity": b["imprint_capacity"],
            "meta_rule_cap": b["meta_rule_cap"],
            "battle_stone_rewards": b["battle_stone_rewards"],
            "layer_stone_budget": {k: pacing["layers"][k]["stone_budget"] for k in sorted(pacing["layers"], key=int)},
            "layer_shop_price_pct": {k: pacing["layers"][k]["shop_price_pct"] for k in sorted(pacing["layers"], key=int)},
            "black_market_exchange": [
                {"from": "lifespan", "amount_in": 20, "to": "soul", "amount_out": 1},
                {"from": "soul", "amount_in": 1, "to": "lifespan", "amount_out": 10},
                {"from": "health", "amount_in": 20, "to": "soul", "amount_out": 1},
                {"from": "soul", "amount_in": 1, "to": "health", "amount_out": 10},
                {"from": "health", "amount_in": 20, "to": "lifespan", "amount_out": 10},
            ],
            "quick_substitute_cap": b["quick_substitute_cap"],
            "blood_yield_ratio": b["blood_yield_ratio"],
            "deep_blood_multiplier": b["deep_blood_multiplier"],
            "deep_blood_trail": b["deep_blood_trail"],
            "deep_blood_time_cost": b["deep_blood_time_cost"],
            "gu_estimate_ratio": b["gu_estimate_ratio"],
            "free_pair": b["free_pair"],
            "soul_burst_capacity_ratio": b["soul_burst_capacity_ratio"],
            "soul_calm_emotional_below": b["soul_calm_emotional_below"],
            "soul_calm_beast_below": b["soul_calm_beast_below"],
            "soul_calm_departure_below": b["soul_calm_departure_below"],
            "beast_nature_emerging_above": b["beast_nature_emerging_above"],
            "beast_nature_threshold": b["beast_nature_threshold"],
            "dragon_fish_replacement": b["dragon_fish_replacement"],
            "synthesis": synthesis,
            "contracts": contracts,
            "free_mix_recipe": next((r for r in load("refinement_recipes")["recipes"] if r["kind"] == "free_mix"), {}),
        },
        "loot": {
            "pity_threshold": load("loot_tables")["pity"]["threshold"],
            "clearing_rarities": load("loot_tables")["pity"]["clearing_rarities"],
            "material_pity": load("loot_tables")["pity"]["material_pity"],
            "gu_chance_pct_by_tier": {k: v.get("gu_chance_pct") for k, v in load("loot_tables")["loot"].items()},
            "material_count_by_tier": {k: v.get("material_count") for k, v in load("loot_tables")["loot"].items()},
            "rarity_weights_by_layer": {k: pacing["layers"][k]["loot"]["weights"] for k in sorted(pacing["layers"], key=int)},
            "school_material_resonance": load("loot_tables").get("school_material_resonance"),
        },
        "faction": {"reputation_gains": reputation["gains"], "reputation_effects": reputation["effects"]},
        "combat_gate": {
            "down_rank_cost_formula": "native_cost * rank_step_ratio^(gu_rank-1) / rank_step_ratio^(cultivator_rank-1)",
            "down_rank_cost_note": "等价于 2^(gu_rank - cultivator_rank) 折价；低转蛊师不能催动高阶普通蛊。",
            "low_rank_exception_field": "gu.low_rank_exception",
            "reaction_multiplier": b["reaction_multiplier"],
            "light_cost_ratio": b["light_cost_ratio"],
            "heavy_cost_ratio": b["heavy_cost_ratio"],
            "natural_recovery_cost_ratio": b["natural_recovery_cost_ratio"],
            "cross_school_penalty_per_extra": b["cross_school_penalty_per_extra"],
            "cross_school_exclusion_penalty": b["cross_school_exclusion_penalty"],
            "school_exclusions": b["school_exclusions"],
        },
        **trace(ADAPT, GAME_RULES + ADP_COMBAT + ADP_CULTIVATION,
                "本表把所有可调数值集中到单点（验收 A5）：成长曲线、强度上限、掉落权重、经济通胀参数都在这里。"
                "表中数值多为 provisional（Q8-G 1-C 与 F8 校准前），改动前必须重跑 tools/simulate_balance.py。",
                "draft", tunable=True),
    }
    # ship-time formula annotations for auditability
    entity["formulas"] = {
        "essence_max_out_of_run": "essence_base * aptitude_factor * cultivation_factor",
        "essence_max_battle": "stage_base_battle[rank] * aptitude_factor",
        "essence_regen_per_turn": "ceil(essence_max * regen_pct_battle[aptitude] / 100)",
        "standard_gu_power": "human_base_health * standard_hit_ratio * rank_step_ratio^rank",
        "fixed_defense": "standard_gu_power(rank) * fixed_defense_ratio",
        "actual_activation_cost_pct": "native * rank_step_ratio^(gu_rank-1) / rank_step_ratio^(cultivator_rank-1)",
        "beast_scale": "human_base_health * rank_step_ratio^rank",
        "battle_stone": "base_by_tier[tier] + base_by_tier[tier] * layer_step_pct * (layer-1) / 100",
        "action_points": "action_points_by_soul 中满足 min_soul 的最高档",
    }
    return envelope("balance", [entity], ["data/balance.json", "data/v1_battle.json", "data/pacing.json",
                                          "data/aptitude.json", "data/reputation.json", "data/loot_tables.json",
                                          "data/synthesis.json", "data/contracts.json"], generated_at)


# --------------------------------------------------------------------------
# manifest.json
# --------------------------------------------------------------------------

SINGULAR = {"realms": "realm", "paths": "path", "gu": "gu", "economy": "economy", "factions": "faction",
            "regions": "region", "events": "event", "loot": "loot", "balance": "balance", "manifest": "manifest"}


def build_manifest(generated_at: str, files: list[tuple[str, int]]) -> dict:
    entries = []
    for name, count in files:
        path = OUT_DIR / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        entries.append({"path": f"world-model/data/{name}", "entity_type": SINGULAR[name[:-5]], "count": count,
                        "bytes": path.stat().st_size, "sha256": digest})
    entity = {
        "id": "world_model_manifest",
        "name_zh": "世界模型数据清单",
        "version": WORLD_MODEL_VERSION,
        "schema_version": SCHEMA_VERSION,
        "schema_id": "gu-zhenren/world-model",
        "generated_at": generated_at,
        "generator": "world-model/tools/build_world_model.py",
        "python_requires": ">=3.9 (standard library only)",
        "third_party_dependencies": [],
        "files": entries,
        "file_count": len(entries),
        "total_bytes": sum(e["bytes"] for e in entries),
        "read_only_upstream": ["data/gu.json", "data/gu_names.json", "data/enemies.json", "data/nodes.json",
                               "data/pacing.json", "data/loot_tables.json", "data/refinement_recipes.json",
                               "data/schools.json", "data/school_pools.json", "data/shops.json", "data/balance.json",
                               "data/aptitude.json", "data/v1_battle.json", "data/events.json", "data/relics.json",
                               "data/contracts.json", "data/curse.json", "data/npcs.json", "data/reputation.json",
                               "data/synthesis.json"],
        "upstream_write_policy": "read_only",
        **trace(ADAPT, [], "清单本身为构建产物；sha256 用于检测数据漂移。", "approved", tunable=False),
    }
    return envelope("manifest", [entity], [], generated_at, extra={"version_source": "world-model/VERSION"})


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--generated-at", default=None)
    args = ap.parse_args()
    generated_at = args.generated_at or _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    produced: list[tuple[str, int]] = []

    def emit(doc: dict, name: str):
        write(doc, name)
        produced.append((name, doc.get("count", len(doc.get("entities", [])))))
        print(f"  wrote {name:<16} entities={doc.get('count')}")

    print(f"world-model build  version={WORLD_MODEL_VERSION}  generated_at={generated_at}")
    emit(build_realms(generated_at), "realms.json")
    emit(build_paths(generated_at), "paths.json")
    emit(build_gu(generated_at), "gu.json")
    emit(build_economy(generated_at), "economy.json")
    emit(build_factions(generated_at), "factions.json")
    emit(build_regions(generated_at), "regions.json")
    emit(build_events(generated_at), "events.json")
    emit(build_loot(generated_at), "loot.json")
    emit(build_balance(generated_at), "balance.json")
    emit(build_manifest(generated_at, produced), "manifest.json")
    print(f"  done: {len(produced)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
