extends GutTest


# Spec-v4 phase-2 (T7.2): core replacement tokens (§1.3). Guaranteed tokens on
# second/third-layer major nodes race the node's own strengthening; random
# encounters may come early but never bypass the per-run success hard cap; a
# replaced run swaps the guarantee for a peer reward. replace_core removes the
# old core's exclusive mods, keeps rank/identity, and hands the new core a
# fresh confirmation. Acceptance #2 wired.


const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state_with_two() -> RunState:
	var state: RunState = RunStateScript.new_run(23)
	state.current_node_layer = 2
	state.gu_instances["gu_001"] = GuInstanceScript.new_instance("moonlight_gu", "gu_001", catalog)
	state.gu_instances["gu_002"] = GuInstanceScript.new_instance("phantom_moon_gu", "gu_002", catalog)
	# Old core: confirmed facts + one core-exclusive modification.
	state.gu_instances["gu_001"]["core_state"] = {
		"confirmed_layer": 1, "depth": "common_core", "confirmed_at_event": "core_gu_001"}
	state.gu_instances["gu_001"]["modifications"] = [
		{"kind": "core_imprint", "source": "core_exclusive"},
		{"kind": "relic_boost", "source": "relic_hook"},
	]
	return state


func test_token_granted_on_second_third_layer_major_nodes() -> void:
	var state: RunState = RunStateScript.new_run(23)
	var node := {"id": "layer_boss_stand_2", "stage": "two",
			"core_replacement_token": {"claim_core_token": true}}
	var granted := CoreGuRulesScript.grant_replacement_token(state, node, null)
	assert_true(bool(granted["ok"]), str(granted))
	assert_eq(str(granted["token"]), "core_replacement_token")


func test_token_is_refused_after_a_successful_random_replacement() -> void:
	# §1.3: once a random encounter replaced the core, the guarantee node
	# hands out a peer reward instead of a useless token.
	var state: RunState = RunStateScript.new_run(23)
	state.node_flags["core_replace_count"] = 1
	var node := {"id": "caravan_missing_goods", "stage": "three",
			"core_replacement_token": {"claim_core_token": true}}
	var granted := CoreGuRulesScript.grant_replacement_token(state, node, null)
	assert_false(bool(granted["ok"]))
	assert_eq(str(granted["reason"]), "guarantee_replaced_with_peer_reward")


func test_replace_removes_core_mods_and_keeps_rank_and_identity() -> void:
	# Acceptance #2: the old gu keeps rank, state and definition/instance
	# identity; only core_state and its exclusive mods are removed.
	var state := _state_with_two()
	var replaced := CoreGuRulesScript.replace_core(
			state, "gu_001", "gu_002", {"certificate": 1, "stones": 0}, catalog)
	assert_true(bool(replaced["ok"]), str(replaced))
	var old: Dictionary = replaced["instances"]["gu_001"]
	assert_true((old["core_state"] as Dictionary).is_empty(),
			"the old core loses its core facts")
	var mods: Array = old["modifications"]
	assert_eq(mods.size(), 1, "the core-exclusive mod is removed, others stay")
	assert_eq(str(mods[0]["source"]), "relic_hook")
	assert_eq(str(old["state"]), "refined", "ordinary state survives")
	assert_eq(int(old["rank"]), int(state.gu_instances["gu_001"]["rank"]))
	assert_eq(str(old["instance_id"]), "gu_001")
	assert_eq(str(old["definition_id"]), "moonlight_gu")


func test_new_core_starts_fresh_without_inheritance() -> void:
	# Acceptance #2: the new core does not inherit route, mods or consumed
	# resources; its core_state is a fresh confirmation.
	var state := _state_with_two()
	var replaced := CoreGuRulesScript.replace_core(
			state, "gu_001", "gu_002", {"certificate": 1}, catalog)
	var new_core: Dictionary = replaced["instances"]["gu_002"]
	var core_state: Dictionary = new_core["core_state"]
	assert_true(bool(core_state.has("confirmed_layer")), str(core_state))
	assert_true((new_core["modifications"] as Array).is_empty(),
			"no inherited modifications")
	assert_eq(int(state.node_flags.get("core_replace_count", 0)) + 1,
			int(replaced["event"].get("replace_count", 0)))


func test_hard_cap_rejects_a_second_successful_replacement() -> void:
	# §1.3/§3: the per-run success cap (1) has a preflight rejection path.
	var state := _state_with_two()
	var first := CoreGuRulesScript.can_replace(state, "gu_001", "gu_002", {"certificate": 1}, catalog)
	assert_true(bool(first["ok"]), str(first))
	state.node_flags["core_replace_count"] = 1
	var second := CoreGuRulesScript.can_replace(state, "gu_001", "gu_002", {"certificate": 1}, catalog)
	assert_false(bool(second["ok"]))
	assert_eq(str(second["reason"]), "replace_limit_reached")


func test_cost_sources_are_visible_in_the_preflight() -> void:
	# §1.3: the cost's source (certificate / stones / lifespan / soul /
	# taboo) is structured and public before the trade.
	var state := _state_with_two()
	var pre := CoreGuRulesScript.can_replace(state, "gu_001", "gu_002",
			{"certificate": 1, "stones": 120, "lifespan": 5, "taboo": "unseal_blood_pact"}, catalog)
	assert_true(bool(pre["ok"]), str(pre))
	var sources: Array = pre["cost_sources"]
	assert_true(sources.has({"kind": "certificate", "amount": 1}))
	assert_true(sources.has({"kind": "stones", "amount": 120}))


func test_token_only_allowed_on_stage_two_three_nodes() -> void:
	# Schema guard: the token key shape and layer ownership are validated.
	var bad := catalog.duplicate(true)
	var nodes: Array = (catalog["nodes"] as Array).duplicate(true)
	nodes.append({"id": "early_token", "stage": "one", "core_replacement_token": {"x": true}})
	bad["nodes"] = nodes
	var errors := ContentCatalogScript.validate(bad)
	assert_true(errors.size() > 0, str(errors))