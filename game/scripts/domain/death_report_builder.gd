class_name DeathReportBuilder
extends RefCounted


const STONE_EXHAUSTED_TAUNT := "见光便扑？这点真元，也敢替我试蛊。下辈子先照照脚下的石粉。"


static func build(battle: Dictionary, state: RunState) -> Dictionary:
	var final_blow: Dictionary = battle.get("final_blow", {})
	# V1 契约无 final_blow 状态字段（禁止字段清单）；击杀意图从战斗日志的
	# enemy_attack 条目导出（enemy attack 入日志见 v1_battle_resolver）。
	if final_blow.is_empty() and not (battle.get("log", []) as Array).is_empty():
		for index in range((battle.get("log", []) as Array).size() - 1, -1, -1):
			var entry: Dictionary = (battle["log"] as Array)[index]
			if str(entry.get("reason", "")) == "enemy_attack":
				final_blow = {"id": str(entry.get("target", "")), "damage": 0}
				break
	var facts: Array[String] = []
	for clue in battle.get("clues", []):
		facts.append(str(clue))
	for reaction in battle.get("revealed_reactions", []):
		facts.append(str(reaction))
	return {
		"final_blow": str(final_blow.get("id", "unknown")),
		"damage": int(final_blow.get("damage", 0)),
		"known_facts": facts,
		"taunt": _taunt_for(battle, state, final_blow),
	}


static func _taunt_for(battle: Dictionary, state: RunState, final_blow: Dictionary) -> String:
	if str(battle.get("enemy_kind", "")) == "neutral_stone_wanderer" and str(final_blow.get("id", "")) == "stone_palm":
		if state.essence <= 0 and battle.get("clues", []).has("stone_dust"):
			return STONE_EXHAUSTED_TAUNT
		return "看见石粉还敢硬扑？这点力道，正好替我试试掌上石甲。"
	if str(battle.get("enemy_kind", "")) == "ridge_hound" and str(final_blow.get("id", "")) == "pounce":
		return "肩一沉你还不退，山路上的肉，从来不等第二口。"
	return "修行路窄，脚下的每一步都得先看清。"
