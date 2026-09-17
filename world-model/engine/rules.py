"""Pure rule functions for the world model.

Every numeric constant is read from the centralized `balance.json` entity
(`WorldModel.b(...)`) — nothing in this module hardcodes a tuning value
(acceptance A5). Functions are pure where possible; the few that mutate take an
explicit state dict and return a structured event so `run.py` can append it to
the immutable run log.
"""

from __future__ import annotations

import math

from .errors import DataMissingError, GuBacklash, NumericOverflow, ResourceExhausted

APTITUDE_ORDER = ["ding", "bing", "yi", "jia", "ten_extreme"]

# The prototype's stage keys are ordinal words, not numbers (data/v1_battle.json,
# data/pacing.json). This is the single translation point.
STAGE_WORDS = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


def stage_word(rank: int) -> str:
    index = int(rank) - 1
    if not 0 <= index < len(STAGE_WORDS):
        raise NumericOverflow(f"转数 {rank} 超出世界模型覆盖范围（1-9）")
    return STAGE_WORDS[index]


# --------------------------------------------------------------------------
# 修炼晋升
# --------------------------------------------------------------------------

def aptitude_rank(aptitude: str) -> int:
    return APTITUDE_ORDER.index(aptitude) if aptitude in APTITUDE_ORDER else 0


def essence_max(wm, rank: int, aptitude: str) -> int:
    """局外真元上限：essence_base * aptitude_factor * cultivation_factor."""
    base = wm.b("growth", "essence_base")
    apt = wm.b("growth", "aptitude_factor").get(aptitude, 1)
    cult = wm.b("growth", "cultivation_factor").get(str(max(1, int(rank))), 1)
    return int(base * apt * cult)


def essence_max_battle(wm, rank: int, aptitude: str) -> int:
    """战斗真元上限：stage_base[rank] * aptitude_factor."""
    base = wm.b("growth", "stage_base_battle").get(stage_word(rank))
    if base is None:
        raise NumericOverflow(f"balance 的 stage_base_battle 未覆盖 {rank} 转")
    return int(base * wm.b("growth", "aptitude_factor").get(aptitude, 1))


def essence_regen_per_turn(wm, max_essence: int, aptitude: str) -> int:
    pct = wm.b("growth", "regen_pct_battle").get(aptitude, 0)
    return int(math.ceil(max_essence * pct / 100.0))


def natural_recovery_rate(wm, aptitude: str) -> float:
    pct = wm.b("growth", "regen_pct_out_of_run").get(aptitude, 0)
    return wm.b("growth", "aptitude_recovery_multiplier") + pct / 100.0


def stone_to_essence(wm, stones: int, state: dict) -> dict:
    """元石换真元：每石 floor(stone_to_essence_per_stone * 自然恢复率)，不超上限、不浪费。"""
    if stones <= 0:
        raise ResourceExhausted("换取的元石数量必须为正")
    if stones > state["stone"]:
        raise ResourceExhausted(f"元石不足：需要 {stones}，现有 {state['stone']}")
    per_stone = max(1, int(math.floor(wm.b("growth", "stone_to_essence_per_stone")
                                       * natural_recovery_rate(wm, state["aptitude"]))))
    capacity = max(0, state["essence_max"] - state["essence"])
    usable = capacity // per_stone
    if usable <= 0:
        raise ResourceExhausted("真元已满，无需以元石补充")
    spent = min(int(stones), usable)
    return {"stones_spent": spent, "essence_gain": spent * per_stone, "per_stone": per_stone}


def can_cultivate_to(wm, current_rank: int, target_rank: int, aptitude: str) -> tuple[bool, str]:
    """丙等硬门槛：未在本局提升资质前不得冲三转（ADP-CULTIVATION-001）。"""
    if target_rank != current_rank + 1:
        return False, f"只能逐转突破：当前 {current_rank} 转，不能直接跳到 {target_rank} 转"
    gate = wm.b("growth", "aptitude_hard_gate")
    if target_rank >= int(gate["target_rank"]) and aptitude_rank(aptitude) < aptitude_rank(gate["min_aptitude"]):
        return False, f"{target_rank} 转需要 {gate['min_aptitude']} 等以上资质：必须先洗髓换骨提升资质"
    cost = wm.b("growth", "cultivate_stone_cost").get(str(target_rank))
    if cost is None:
        return False, f"balance 未定义 {target_rank} 转的突破成本"
    return True, ""


def cultivation_cost(wm, target_rank: int) -> int:
    cost = wm.b("growth", "cultivate_stone_cost").get(str(target_rank))
    if cost is None:
        raise NumericOverflow(f"balance 未定义 {target_rank} 转的突破成本")
    return int(cost)


def can_activate(wm, cultivator_rank: int, gu_rank: int, low_rank_exception: bool = False) -> bool:
    """真元质量门禁：低转蛊师不能催动高阶普通蛊，除非该蛊自带 low_rank_exception。"""
    return bool(low_rank_exception) or int(cultivator_rank) >= int(gu_rank)


def actual_activation_cost(wm, native_cost: int, gu_rank: int, cultivator_rank: int) -> float:
    """高阶蛊师驱动低阶蛊的折价：native * r^(gu_rank-1) / r^(cultivator_rank-1)，
    等价于 2^(gu_rank - cultivator_rank) 折价。"""
    ratio = float(wm.b("growth", "rank_step_ratio"))
    return float(native_cost) * (ratio ** (int(gu_rank) - 1)) / (ratio ** (int(cultivator_rank) - 1))


def action_points(wm, soul: int) -> int:
    for step in wm.b("run", "action_points_by_soul"):
        if int(soul) >= int(step["min_soul"]):
            return int(step["ap"])
    return 1


def standard_gu_power(wm, rank: int) -> float:
    return (wm.b("growth", "human_base_health") * wm.b("growth", "standard_hit_ratio")
            * (wm.b("growth", "rank_step_ratio") ** max(0, int(rank))))


def fixed_defense(wm, rank: int) -> float:
    return standard_gu_power(wm, rank) * wm.b("growth", "fixed_defense_ratio")


def beast_scale(wm, rank: int) -> float:
    return wm.b("growth", "human_base_health") * (wm.b("growth", "rank_step_ratio") ** max(0, int(rank)))


# --------------------------------------------------------------------------
# 蛊虫 获取 / 炼化 / 喂养 / 晋升 / 反噬
# --------------------------------------------------------------------------

def gu_instance(wm, gu_id: str, iid: str) -> dict:
    definition = wm.gu_def(gu_id)
    return {
        "iid": iid,
        "gu_id": gu_id,
        "name_zh": definition["name_zh"],
        "instance_rank": int(definition["rank"]),
        "definition_rank": int(definition["rank"]),
        "feed_debt": 0,
        "starved_stages": 0,
        "sealed_turns": 0,
        "alive": True,
        # wild=野生未炼化；refined=已炼化认主（与 Godot refine_command_rules 同语义）
        "state": "refined",
    }


def gu_value(wm, gu_id: str, instance_rank: int | None = None) -> int:
    """卖出/回购基准：max(定义字面价值, gu_value_by_rank[实例转数])。"""
    definition = wm.gu_def(gu_id)
    literal = int(definition["value"])
    rank = int(instance_rank if instance_rank is not None else definition["rank"])
    table = wm.b("economy", "gu_value_by_rank")
    tiered = int(table.get(str(max(1, rank)), literal))
    return max(literal, tiered)


def feeding_bill(wm, instances: list[dict]) -> int:
    """阶段末喂养总账：每只蛊 stone_per_stage，欠账按 stage 计息。"""
    total = 0
    for inst in instances:
        if not inst.get("alive", True):
            continue
        definition = wm.gu_def(inst["gu_id"])
        total += int(definition["feeding"]["stone_per_stage"]) * (1 + int(inst.get("starved_stages", 0)))
    return total


def settle_feeding(wm, state: dict) -> dict:
    """结清喂养总账。付不起就走欠账与反噬路径，不允许静默补齐。"""
    bill = feeding_bill(wm, state["gu_instances"])
    paid = min(bill, int(state["stone"]))
    state["stone"] -= paid
    shortfall = bill - paid
    if shortfall <= 0:
        for inst in state["gu_instances"]:
            inst["feed_debt"] = 0
        return {"bill": bill, "paid": paid, "shortfall": 0, "backlash": []}

    backlash = []
    unpaid = [i for i in state["gu_instances"] if i.get("alive", True)]
    for inst in unpaid:
        inst["feed_debt"] += shortfall
        inst["starved_stages"] = int(inst.get("starved_stages", 0)) + 1
        definition = wm.gu_def(inst["gu_id"])
        if inst["feed_debt"] >= int(definition["feeding"]["feed_points_per_stage"]) * 2:
            inst["instance_rank"] = max(1, int(inst["instance_rank"]) - 1)
            inst["feed_debt"] = 0
            backlash.append({"kind": "rank_decay", "iid": inst["iid"], "gu_id": inst["gu_id"],
                             "to_rank": inst["instance_rank"]})
    if shortfall > 0:
        hp_loss = min(state["hp"] - 1, shortfall)
        if hp_loss > 0:
            state["hp"] -= hp_loss
            backlash.append({"kind": "hp_loss", "amount": hp_loss})
    return {"bill": bill, "paid": paid, "shortfall": shortfall, "backlash": backlash}


def backlash_preview(wm, state: dict, inst: dict) -> int:
    """越级催蛊的自伤预检读数（执行前必须展示）。"""
    over = max(0, int(inst["instance_rank"]) - int(state["rank"]))
    return max(1, over * 2)


def activate_gu(wm, state: dict, iid: str, *, in_battle: bool = True, strict: bool = True) -> dict:
    """催蛊。

    strict=True（默认）：不合规就抛 GuBacklash，**执行前不产生任何状态变更**，
    便于 UI 预检与自动决策直接跳过。
    strict=False：「强催」路径——先扣下反噬自伤，再按正常流程结算。
    """
    inst = next((i for i in state["gu_instances"] if i["iid"] == iid and i.get("alive", True)), None)
    if inst is None:
        raise ResourceExhausted(f"没有存活的可催蛊虫实例 {iid!r}")
    if int(inst.get("sealed_turns", 0)) > 0:
        raise ResourceExhausted(f"{inst['name_zh']} 正被禁锢，剩余 {inst['sealed_turns']} 回合")
    definition = wm.gu_def(inst["gu_id"])
    exception = bool(definition.get("low_rank_exception"))
    backlash = 0
    if not can_activate(wm, state["rank"], inst["instance_rank"], exception):
        backlash = backlash_preview(wm, state, inst)
        message = (f"{inst['name_zh']} 超出你的转数"
                   f"（{inst['instance_rank']} 转 > {state['rank']} 转），真元反噬：气血 -{backlash}")
        if strict:
            raise GuBacklash(message, detail=f"over_rank={int(inst['instance_rank']) - int(state['rank'])}")
        state["hp"] = int(state["hp"]) - backlash
    cost = actual_activation_cost(wm, int(definition["activation_cost"]), inst["instance_rank"], state["rank"])
    need = max(0, int(math.ceil(cost)))
    if need > state["essence"]:
        raise ResourceExhausted(
            f"真元不足：催动 {inst['name_zh']} 需要 {need} 点，当前 {state['essence']} 点")
    state["essence"] -= need
    thoughts = int(definition.get("thought_cost", wm.b("run", "thought_cost_per_action")))
    if in_battle and thoughts > state.get("thoughts", 0):
        raise ResourceExhausted(f"念头不足：催动 {inst['name_zh']} 需要 {thoughts} 念头")
    if in_battle:
        state["thoughts"] = state.get("thoughts", 0) - thoughts
    effect = resolve_effect(wm, definition["effect"], inst["instance_rank"], state)
    return {"iid": iid, "gu_id": inst["gu_id"], "name_zh": inst["name_zh"],
            "essence_cost": need, "thought_cost": thoughts if in_battle else 0,
            "native_cost": int(definition["activation_cost"]), "effect": effect,
            "backlash_damage": backlash, "forced": backlash > 0}


def resolve_effect(wm, effect: dict, gu_rank: int, state: dict) -> dict:
    """把蛊虫 effect 投影成可结算读数。kind 未知时按 role_default 兜底，不静默归零。"""
    kind = effect.get("kind", "none")
    if kind == "composite":
        parts = effect.get("parts", [])
        return {"kind": "composite", "parts": [resolve_effect(wm, p, gu_rank, state) for p in parts],
                "damage": sum(int(p.get("amount", 0)) for p in parts if p.get("kind") == "strike")}
    if kind == "strike":
        amount = int(effect.get("amount", 0))
        condition = effect.get("condition")
        if condition and condition.get("type") == "self_hp_below":
            ratio = state["hp"] / max(1, state["hp_max"])
            if ratio >= float(condition.get("threshold", 1.0)):
                amount = max(1, amount // 2)
        return {"kind": "strike", "damage": amount}
    if kind == "heal":
        return {"kind": "heal", "heal": int(effect.get("amount", 0))}
    if kind == "shield":
        return {"kind": "shield", "shield": int(effect.get("amount", 0))}
    if kind == "shift":
        return {"kind": "shift", "speed": int(effect.get("amount", 0))}
    if kind == "status":
        return {"kind": "status", "name": effect.get("name", "marked"), "amount": int(effect.get("amount", 0))}
    if kind == "heal_and_strike":
        return {"kind": "heal_and_strike", "heal": int(effect.get("heal", 0)), "damage": int(effect.get("amount", 0))}
    if kind == "weaken_intent":
        return {"kind": "weaken_intent", "amount": int(effect.get("amount", 1))}
    if kind == "add_temp_stat":
        return {"kind": "add_temp_stat", "stat": effect.get("stat", ""), "amount": int(effect.get("amount", 0))}
    if kind == "grant_block":
        return {"kind": "shield", "shield": int(effect.get("amount", 0))}
    if kind == "aoe_strike":
        return {"kind": "strike", "damage": int(effect.get("amount", 0)), "aoe": True}
    if kind == "sword_intent":
        return {"kind": "strike", "damage": int(effect.get("amount", 0)), "sword_mark": True}
    return {"kind": "none", "damage": 0}



def attune_gu(wm, state: dict, iid: str) -> dict:
    """炼化/认主：把野生蛊转为已炼化。

    与 Godot `scripts/domain/refine_command_rules.gd:268 _attune_gu` 同语义：
    仅 wild 可炼化；消耗 4 + 2*(转-1) 真元；先判门槛后扣费（不足时一只真元都不扣、状态不变）。
    """
    inst = next((i for i in state.get("gu_instances", []) if i.get("iid") == iid), None)
    if inst is None:
        raise ResourceExhausted(f"没有这只蛊实例：{iid}")
    if inst.get("state", "refined") != "wild":
        raise ResourceExhausted(f"该蛊并非野生状态，无需炼化：{iid}")
    rank = max(1, int(inst.get("instance_rank", 1)))
    cost = 4 + 2 * (rank - 1)
    if "essence" in state and int(state["essence"]) < cost:
        raise ResourceExhausted(f"真元不足：炼化需要 {cost}，现有 {state['essence']}")
    if "essence" in state:
        state["essence"] = int(state["essence"]) - cost
    inst["state"] = "refined"
    return {"iid": iid, "cost": cost, "rank": rank}

def refine_gu(wm, state: dict, gu_id: str, recipe: dict, *, roll: float = None) -> dict:
    """炼蛊/升炼。recipe 来自 gu.json 的 refine_as_output 边。"""
    if recipe["kind"] == "free_mix":
        raise ResourceExhausted("自由混合配方需要 min_inputs，请使用 free_mix 专用路径")
    for input_id in recipe.get("input_gu_ids", []):
        if not any(i["gu_id"] == input_id and i.get("alive", True) for i in state["gu_instances"]):
            raise ResourceExhausted(f"手中没有配方所需的输入蛊 {input_id}")
    stone = int(recipe.get("stone_cost", 0))
    if stone > state["stone"]:
        raise ResourceExhausted(f"元石不足：炼蛊需要 {stone}，现有 {state['stone']}")
    for mat_id, need in (recipe.get("materials") or {}).items():
        have = state["materials"].get(mat_id, 0)
        if have < int(need):
            raise ResourceExhausted(f"蛊材不足：{mat_id} 需要 {need}，现有 {have}")
    state["stone"] -= stone
    for mat_id, need in (recipe.get("materials") or {}).items():
        state["materials"][mat_id] = state["materials"].get(mat_id, 0) - int(need)
        if state["materials"][mat_id] <= 0:
            state["materials"].pop(mat_id, None)
    # 消耗输入蛊
    for input_id in recipe.get("input_gu_ids", []):
        for inst in state["gu_instances"]:
            if inst["gu_id"] == input_id and inst.get("alive", True) and int(inst["instance_rank"]) == int(
                    wm.gu_def(input_id)["rank"]):
                inst["alive"] = False
                break
    output_id = recipe.get("output_gu_id", gu_id)
    new_inst = gu_instance(wm, output_id, f"g{len(state['gu_instances']) + 1}")
    if recipe.get("output_rank"):
        new_inst["instance_rank"] = int(recipe["output_rank"])
    state["gu_instances"].append(new_inst)
    return {"recipe_id": recipe["recipe_id"], "kind": recipe["kind"], "output": output_id,
            "stone_cost": stone, "instance_rank": new_inst["instance_rank"]}


def free_mix(wm, state: dict, gu_ids: list[str], roll: float) -> dict:
    """自由混合：按 outcomes 权重结算。roll ∈ [0,1)。"""
    if len(gu_ids) < 2:
        raise ResourceExhausted("自由混合至少需要两只蛊")
    for gid in gu_ids:
        if not any(i["gu_id"] == gid and i.get("alive", True) for i in state["gu_instances"]):
            raise ResourceExhausted(f"手中没有 {gid}")
    recipe = wm.b("economy", "free_mix_recipe")
    outcomes = recipe.get("outcomes") or []
    if not outcomes:
        raise ResourceExhausted("世界模型未提供自由混合结果表（balance.economy.free_mix_recipe.outcomes）")
    total = sum(float(o["weight"]) for o in outcomes)
    acc, chosen = 0.0, outcomes[-1]
    for o in outcomes:
        acc += float(o["weight"]) / total
        if roll < acc:
            chosen = o
            break
    for gid in gu_ids:
        for inst in state["gu_instances"]:
            if inst["gu_id"] == gid and inst.get("alive", True):
                inst["alive"] = False
                break
    result = {"outcome": chosen["id"], "effect": chosen["effect"], "rolled": roll}
    if chosen["effect"] == "mutate_to":
        state["gu_instances"].append(gu_instance(wm, chosen["target_gu_id"], f"g{len(state['gu_instances']) + 1}"))
        result["target_gu_id"] = chosen["target_gu_id"]
    if chosen["effect"] == "explosion":
        state["hp"] -= int(chosen.get("health_cost", 0))
        state["soul"] -= int(chosen.get("soul_cost", 0))
        state["lifespan"] -= int(chosen.get("lifespan_cost", 0))
        result.update({"health_cost": chosen.get("health_cost", 0), "soul_cost": chosen.get("soul_cost", 0),
                       "lifespan_cost": chosen.get("lifespan_cost", 0)})
    if chosen.get("fail_curse_id"):
        state["curses"].append({"id": chosen["fail_curse_id"], "stages": 1})
        result["curse_id"] = chosen["fail_curse_id"]
    return result


# --------------------------------------------------------------------------
# 战斗结算
# --------------------------------------------------------------------------

def enemy_profile(wm, enemy_id: str, layer: int, turn: int = 1) -> dict:
    """敌人投影。

    `turn` 用的是该层的 enemy_turn 档位（pacing.layers[L].enemy_turn），
    按 turn_scaling 逐档叠加 HP/伤害并受 cap 限制；Boss 再乘 boss_layer_mult。
    """
    enemies = {e["id"]: e for e in _enemies(wm)}
    if enemy_id not in enemies:
        raise ResourceExhausted(f"未知敌人：{enemy_id}")
    e = enemies[enemy_id]
    scaling = wm.b("run", "turn_scaling")
    steps = max(0, int(turn) - 1)
    hp = float(e["hp"])
    boss_mult = wm.b("run", "boss_layer_mult").get(stage_word(layer), {"hp": 1.0, "damage": 1.0})
    if e["tier"] == "boss":
        hp *= float(boss_mult["hp"])
    hp += min(scaling["hp_add_per_turn"] * steps, scaling["hp_cap_bonus"])
    difficulty = wm.b("run", "difficulty")
    hp *= float(difficulty["enemy_hp_mult"])
    phases = _normalize_phases(e)
    intents = phases[0]["intents"] if phases else [dict(e.get("intent", {"damage": 0}))]
    for intent in intents:
        bonus = min(scaling["damage_add_per_turn"] * steps, scaling["damage_cap_bonus"])
        damage = int(round((int(intent.get("damage", 0)) + bonus) * float(difficulty["enemy_damage_mult"])))
        if e["tier"] == "boss":
            damage = int(round(damage * float(boss_mult["damage"])))
        intent["damage"] = damage
    return {
        "id": e["id"],
        "name_zh": e.get("name_zh", e["id"]),
        "theme": e["theme"], "grade": e["grade"], "tier": e["tier"], "rank": int(e["rank"]),
        "hp_max": int(round(hp)), "hp": int(round(hp)),
        "intent": dict(intents[0]),
        "phases": phases,
        "reactions": list(e.get("reactions", [])),
        "clues": list(e.get("clues", [])),
    }


def _normalize_phases(enemy: dict) -> list[dict]:
    """enemies.json 的 phases 是 [{until_hp_ratio, intents, reactions}, ...]，
    阈值按数据顺序严格递减；没有 phases 的敌人只有单相。"""
    raw = enemy.get("phases")
    if not raw:
        intent = dict(enemy.get("intent", {}))
        intent.setdefault("damage", 0)
        return [{"until_hp_ratio": 1.0, "intents": [intent],
                 "reactions": list(enemy.get("reactions", []))}]
    if isinstance(raw, dict):
        raw = [raw]
    phases = []
    for ph in raw:
        intents = [dict(i) for i in (ph.get("intents") or [])]
        if not intents:
            intents = [dict(enemy.get("intent", {"damage": 0}))]
        for i in intents:
            i.setdefault("damage", 0)
        phases.append({"until_hp_ratio": float(ph.get("until_hp_ratio", 1.0)), "intents": intents,
                       "reactions": list(ph.get("reactions", []))})
    return phases


def _enemies(wm) -> list[dict]:
    """敌人名册内嵌在 regions.json 的 macro_region 实体（南疆）上：他们就是这些
    地域的居民，因此不需要第 11 个实体文件。"""
    roster = wm.regions["south_jiang"].get("enemy_roster")
    if not roster:
        raise DataMissingError("regions.json 的 south_jiang 缺少 enemy_roster")
    return roster


def resolve_player_action(wm, state: dict, battle: dict, action: dict) -> list[dict]:
    """结算玩家的一次行动，返回事件列表。会校验三轴死亡。"""
    events = []
    enemy = battle["enemy"]
    damage = int(action.get("damage", 0))
    if action.get("kind") == "basic_attack":
        damage = int(wm.b("run", "fight_damage_base"))
        events.append({"kind": "basic_attack", "damage": damage})
    if damage > 0:
        enemy["hp"] -= damage
        events.append({"kind": "damage_dealt", "damage": damage, "enemy_hp": enemy["hp"]})
    if action.get("heal"):
        healed = min(int(action["heal"]), state["hp_max"] - state["hp"])
        state["hp"] += healed
        events.append({"kind": "heal", "amount": healed})
    if action.get("shield"):
        battle["shield"] = battle.get("shield", 0) + int(action["shield"])
        events.append({"kind": "shield_gain", "shield": int(action["shield"]), "total": battle["shield"]})
    if action.get("weaken_intent"):
        enemy["intent_damage"] = max(0, int(enemy["intent_damage"]) - int(action["weaken_intent"]))
        events.append({"kind": "intent_weakened", "amount": int(action["weaken_intent"])})
    events.extend(check_death(wm, state, enemy))
    return events


def enemy_turn(wm, state: dict, battle: dict) -> list[dict]:
    """敌方回合：按当前相位的意图轮转结算（含 cooldown 与相位切换）。"""
    events: list[dict] = []
    enemy = battle["enemy"]
    phases = enemy.get("phases") or []
    ratio = enemy["hp"] / max(1, enemy["hp_max"])
    index = 0
    if phases:
        for i, ph in enumerate(phases):
            if ratio <= float(ph["until_hp_ratio"]):
                index = i
        if index != int(battle.get("phase_index", 0)):
            battle["phase_index"] = index
            events.append({"kind": "boss_phase_shift", "phase_index": index, "hp_ratio": round(ratio, 3)})
    else:
        battle["phase_index"] = 0
    active = phases[index] if phases else {"intents": [enemy.get("intent", {"damage": 0})]}
    intents = active.get("intents") or []
    cooldown_until = battle.setdefault("cooldown_until", {})
    current_turn = int(battle.get("turn", 1))
    chosen = None
    for intent in intents:
        if int(cooldown_until.get(str(intent.get("id", "")), 0)) <= current_turn:
            chosen = intent
            break
    if chosen is None:
        events.append({"kind": "cooldown_wait", "intents": [i.get("id") for i in intents]})
    else:
        cooldown = int(chosen.get("cooldown", 0))
        if cooldown > 0:
            cooldown_until[str(chosen.get("id", ""))] = current_turn + cooldown + 1
        enemy["intent"] = dict(chosen)
        kind = chosen.get("kind", "attack")
        if kind == "seal":
            alive = [i for i in state["gu_instances"] if i.get("alive", True)]
            turns = min(int(chosen.get("seal_turns", 1)), int(wm.b("run", "max_seal_turns")))
            if alive:
                target = alive[current_turn % len(alive)]
                target["sealed_turns"] = turns
                events.append({"kind": "gu_sealed", "iid": target["iid"], "gu_id": target["gu_id"],
                               "turns": turns})
        elif kind == "soul_drain":
            drain = int(chosen.get("soul_drain", 1))
            state["soul"] = max(0, int(state["soul"]) - drain)
            events.append({"kind": "soul_drained", "amount": drain, "soul": state["soul"]})
        elif kind == "life_cost":
            burn = int(chosen.get("life_cost", 1))
            state["lifespan"] = max(0, int(state["lifespan"]) - burn)
            events.append({"kind": "lifespan_burned", "amount": burn, "lifespan": state["lifespan"]})
        elif kind == "essence_burn":
            burn = int(chosen.get("essence_burn", 1))
            state["essence"] = max(0, int(state["essence"]) - burn)
            events.append({"kind": "essence_burned", "amount": burn, "essence": state["essence"]})
        incoming = int(chosen.get("damage", 0))
        if incoming > 0:
            absorbed = min(int(battle.get("shield", 0)), incoming)
            battle["shield"] = int(battle.get("shield", 0)) - absorbed
            raw = incoming - absorbed
            state["hp"] = int(state["hp"]) - raw
            events.append({"kind": "enemy_attack", "intent": chosen.get("id", ""), "damage": raw,
                           "absorbed": absorbed, "hp": state["hp"]})

    for inst in state["gu_instances"]:
        if int(inst.get("sealed_turns", 0)) > 0:
            inst["sealed_turns"] = int(inst["sealed_turns"]) - 1
    events.extend(check_death(wm, state, enemy))
    return events


def check_death(wm, state: dict, enemy: dict | None = None) -> list[dict]:
    """三轴死亡判定：气血 / 寿元 / 魂。必须给出精准死因，不允许静默致死。"""
    events = []
    if enemy is not None and enemy.get("hp", 1) <= 0:
        events.append({"kind": "enemy_defeated", "enemy_id": enemy["id"]})
        return events
    axes = wm.b("run", "death_axes")
    thresholds = {
        "hp": wm.b("run", "stats_hp_death_threshold"),
        "lifespan": wm.b("run", "stats_lifespan_death_threshold"),
        "soul": wm.b("run", "stats_soul_death_threshold"),
    }
    labels = {"hp": "气血耗尽而亡", "lifespan": "寿元枯竭而亡", "soul": "魂魄崩散而亡"}
    for axis in axes:
        if state.get(axis, 1) <= thresholds[axis]:
            state["hp"] = max(0, state["hp"]) if axis == "hp" else state["hp"]
            events.append({"kind": "death", "axis": axis, "cause_zh": labels[axis],
                           "values": {a: state.get(a) for a in axes}})
            break
    return events


# --------------------------------------------------------------------------
# 掉落与权重
# --------------------------------------------------------------------------

def loot_weights(wm, layer: int, tier: str) -> dict:
    """层权重与掉落档权重合并：层权重是 tier→rarity 分布，掉落表提供池与数量。"""
    layer_data = wm.region(layer)
    tier_data = wm.loot["tiers"][tier]
    return {
        "material_count": int(layer_data.get("loot_material_count", tier_data.get("material_count", 1))),
        "material_pool": tier_data.get("material_pool", []),
        "gu_chance_pct": float(tier_data.get("gu_chance_pct", 0)),
        "gu_pool": tier_data.get("gu_pool", {}),
        "rarity_weights": layer_data.get("loot_rarity_weights", {}),
        "forced_rarity": tier_data.get("forced_rarity"),
    }


def normalize_material_pool(pool: list) -> list[tuple[str, float]]:
    out: list[tuple[str, float]] = []
    for entry in pool:
        if isinstance(entry, str):
            out.append((entry, 1.0))
        elif isinstance(entry, dict) and "id" in entry:
            out.append((entry["id"], float(entry.get("weight", 1))))
    return out


def battle_stone_reward(wm, tier: str, layer: int) -> int:
    table = wm.b("economy", "battle_stone_rewards")
    base = int(table["base_by_tier"].get(tier, 0))
    return int(base + base * table["layer_step_pct"] * (int(layer) - 1) / 100)


def roll_loot(wm, stream, layer: int, tier: str, state: dict) -> dict:
    """掉落结算：蛊材 + 蛊虫 + 元石。保底计数按档位独立（pity_by_tier）。"""
    spec = loot_weights(wm, layer, tier)
    got_materials: dict[str, int] = {}
    pool = normalize_material_pool(spec["material_pool"])
    for _ in range(max(0, int(spec["material_count"]))):
        mat = stream.weighted_pick(pool)
        got_materials[mat] = got_materials.get(mat, 0) + 1

    got_gu = None
    pity = state.setdefault("pity_by_tier", {})
    pity[tier] = int(pity.get(tier, 0)) + 1
    threshold = int(wm.b("loot", "pity_threshold"))
    forced = spec.get("forced_rarity")
    if forced or stream.chance(spec["gu_chance_pct"]) or pity[tier] >= threshold:
        rarity_weights = spec["gu_pool"].get("weights", {})
        by_rarity = spec["gu_pool"].get("by_rarity", {})
        rarity = forced or stream.weighted_pick(list(rarity_weights.items())) if rarity_weights else None
        candidates = by_rarity.get(rarity, []) if rarity else []
        if candidates:
            got_gu = stream.pick(candidates)
            pity[tier] = 0
    stones = battle_stone_reward(wm, tier, layer)
    return {"tier": tier, "layer": layer, "materials": got_materials, "gu": got_gu,
            "stone": stones, "pity": dict(pity)}


# --------------------------------------------------------------------------
# 失败与继承
# --------------------------------------------------------------------------

def apply_ending(wm, state: dict, outcome: str, meta: dict) -> dict:
    """结局结算 + Meta 继承。

    只允许图鉴型跨局继承：知识/配方解锁；零永久数值成长。
    Run 内资源与构筑一律清空。
    """
    # IMPORTANT: the returned record is RUN-LOCAL only. Hall (meta) totals must not
    # leak into the run ledger, otherwise the ledger would depend on how many runs
    # the player already played and same-seed replay could not reproduce it.
    run_codex = sorted({inst["gu_id"] for inst in state["gu_instances"]}
                       | set(state.get("codex_seen", [])))
    run_recipes = sorted(set(state.get("recipes_used", [])))
    codex = set(meta.setdefault("codex_known_gu", []))
    recipes = set(meta.setdefault("recipes_unlocked", []))
    codex.update(run_codex)
    recipes.update(run_recipes)
    meta["codex_known_gu"] = sorted(codex)
    meta["recipes_unlocked"] = sorted(recipes)
    meta.setdefault("runs_played", 0)
    meta["runs_played"] += 1
    meta.setdefault("endings", {})
    meta["endings"][outcome] = meta["endings"].get(outcome, 0) + 1
    meta.setdefault("numeric_growth", {})
    if meta["numeric_growth"]:
        raise NumericOverflow("Meta 继承不允许任何永久数值成长（numeric_growth 必须为空）")
    return {"outcome": outcome,
            "run_codex_gu": run_codex,
            "run_codex_count": len(run_codex),
            "run_recipes": run_recipes,
            "run_recipe_count": len(run_recipes),
            "numeric_growth": {},
            "meta_numeric_growth": dict(meta.get("numeric_growth", {})),
            "cleared": True}
