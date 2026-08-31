extends GutTest


# 行动点（念头）+ 真元回复台账（2026-08-31）：
# - 每回合结束 action_energy 重置为 first_turn_energy 上限。
# - 真元按资质等级 aptitude_pct 回复：floor(essence_capacity * aptitude_pct / 100)。
# - 回复后 essence 不得超过 essence_capacity。


const BattleScript = preload("res://scripts/domain/battle_resolver.gd")


func _make_battle(aptitude: String, cultivation: int = 1) -> Dictionary:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(7)
	state.aptitude = aptitude
	state.cultivation = cultivation
	var max := int(catalog["aptitude"]["stage_essence_base"][catalog["aptitude"]["rank_tier"][str(cultivation)]])
	state.essence_capacity = max
	state.essence = 0
	state.cave_aperture["essence_max"] = max
	state.cave_aperture["essence_regen_per_turn"] = 0
	state.cave_aperture["essence"] = max
	# 防 end_turn 时被敌方一击致死：拉高气血上限到可承受两次 ridge_hound pounce(2)
	state.health = 100
	state.max_health = 100
	var battle := BattleScript.start({"enemy_kind": "ridge_hound", "first_mover": "player"}, state, catalog)
	return {"catalog": catalog, "state": state, "battle": battle}


func _end_turn(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	# take_turn 把 _expected_state_version 比作 state.event_log.size()。
	return BattleScript.take_turn(battle.duplicate(true), {"type": "end_turn"}, state, catalog, int(state.event_log.size()), "player")


func test_action_energy_resets_to_cap_on_end_turn() -> void:
	var ctx := _make_battle("bing")
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	# 模拟耗光行动点：直接清零
	battle["action_energy"] = 0
	var res := _end_turn(battle, state, catalog)
	assert_true(bool(res.get("accepted", false)), "end_turn OK")
	assert_eq(int(res["battle"].get("action_energy", -1)), 4, "行动点回复到上限 4")


func test_essence_regen_uses_aptitude_pct_for_bing() -> void:
	# bing(100) capacity=4 → 回复 4
	var ctx := _make_battle("bing")
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.essence = 0
	var res := _end_turn(battle, state, catalog)
	assert_eq(int(res["state"].essence), 4, "bing 100% 回 4")


func test_essence_regen_uses_aptitude_pct_for_wu_low_tier() -> void:
	# wu(60) cultivation=1 → tier=low → base=4 → 回复 floor(4*0.6)=2
	var ctx := _make_battle("wu", 1)
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.essence = 0
	var res := _end_turn(battle, state, catalog)
	assert_eq(int(res["state"].essence), 2, "wu 60% 回 2")


func test_essence_regen_uses_aptitude_pct_for_jia_high_tier() -> void:
	# jia(140) cultivation=5 → tier=nirvana → base=24 → 回复 floor(24*1.4)=33
	var ctx := _make_battle("jia", 5)
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.essence = 0
	state.essence_capacity = int(catalog["aptitude"]["stage_essence_base"]["nirvana"])  # 24
	var res := _end_turn(battle, state, catalog)
	# 上限 clamp = essence_capacity = 24
	assert_eq(int(res["state"].essence), 24, "jia 140% nirvana 回满 24")


func test_essence_never_exceeds_capacity_after_multi_turns() -> void:
	var ctx := _make_battle("ding", 2)  # 80%, mid, base=6 → 4
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.essence = 0
	state.essence_capacity = 6
	var cur_battle := battle
	var cur_state := state
	for turn in 5:
		var res := _end_turn(cur_battle, cur_state, catalog)
		cur_state = res["state"]
		cur_battle = res["battle"]
		assert_true(int(cur_state.essence) <= int(cur_state.essence_capacity), "T%d essence 上限 clamp" % turn)
	assert_eq(int(cur_state.essence), 6, "5 回合后回满至 6")