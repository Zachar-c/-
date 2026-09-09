extends GutTest


# P2a B: rest behavior is data-driven off nodes.json type=="rest" instead of
# hard-coded "rest_hollow" literals. Visit/mode flags are scoped per node id
# ("<id>_used"/"<id>_mode"). A second rest node (rest_shrine, stage two, kept
# out of the map generation pool) proves the chain generalizes. Legacy saves
# keyed the visit flag by the bare node id; loading migrates add-only because
# that bare key doubles as the visited marker for _complete_node and
# MapGenerator.reachable_nodes.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _run_at(node_id: String) -> RunState:
	var run := RunState.new_run(101)
	run.current_node_id = node_id
	return run


# ---- rest_shrine walks the full chain with scoped flags ----

func test_rest_shrine_heals_consumes_visit_and_gates_travel() -> void:
	var run := _run_at("rest_shrine")
	run.health = 3
	run.essence = 1

	var gate_shut := ResolverScript.apply(run, {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_false(gate_shut["result"]["ok"])
	assert_eq(str(gate_shut["result"]["reason"]), "rest_choice_required")

	var healed := ResolverScript.apply(gate_shut["state"], {"type": "rest"}, catalog)
	assert_true(healed["result"]["ok"])
	assert_eq(int(healed["state"].health), 27)
	assert_eq(int(healed["state"].essence), 3)
	assert_eq(str(healed["state"].node_flags.get("rest_shrine_used", "")), "used")

	var heal_again := ResolverScript.apply(healed["state"], {"type": "rest"}, catalog)
	assert_false(heal_again["result"]["ok"])
	assert_eq(str(heal_again["result"]["reason"]), "rest_already_used")

	var gate_open := ResolverScript.apply(healed["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_true(bool(gate_open["result"]["ok"]))


func test_rest_shrine_upgrade_and_removal_modes_write_scoped_flags() -> void:
	var upgraded := ResolverScript.apply(_run_at("rest_shrine"), {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)
	assert_true(bool(upgraded["result"]["ok"]))
	assert_eq(str(upgraded["state"].node_flags.get("rest_shrine_used", "")), "used")
	assert_eq(str(upgraded["state"].node_flags.get("rest_shrine_mode", "")), "true")
	assert_eq(int(upgraded["state"].gu_card_overrides.get("light_probe", {}).get("upgrade_level", 0)), 1)

	var removal := ResolverScript.apply(_run_at("rest_shrine"), {
		"type": "rest", "mode": "remove_card", "instance_id": "gu_001",
	}, catalog)
	assert_true(bool(removal["result"]["ok"]))
	assert_eq(str(removal["state"].gu_instances["gu_001"]["state"]), "dead")
	assert_eq(str(removal["state"].node_flags.get("rest_shrine_used", "")), "used")
	assert_eq(str(removal["state"].node_flags.get("rest_shrine_mode", "")), "true")

	var bad_target := ResolverScript.apply(_run_at("rest_shrine"), {
		"type": "rest", "mode": "remove_curse", "curse_id": "essence_bloat",
	}, catalog)
	assert_false(bool(bad_target["result"]["ok"]))
	assert_eq(str(bad_target["result"]["reason"]), "curse_not_present")
	assert_eq(str(bad_target["state"].node_flags.get("rest_shrine_used", "")), "")


func test_rest_hollow_chain_uses_scoped_keys_too() -> void:
	var healed := ResolverScript.apply(_run_at("rest_hollow"), {"type": "rest"}, catalog)
	assert_true(bool(healed["result"]["ok"]))
	assert_eq(str(healed["state"].node_flags.get("rest_hollow_used", "")), "used")
	var gate := ResolverScript.apply(healed["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_true(bool(gate["result"]["ok"]))

	var gated := ResolverScript.apply(_run_at("rest_hollow"), {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_false(bool(gated["result"]["ok"]))
	assert_eq(str(gated["result"]["reason"]), "rest_choice_required")


func test_rest_nodes_never_cross_pollinate_flags() -> void:
	var at_shrine := _run_at("rest_shrine")
	at_shrine.health = 2
	var shrine_rest: RunState = ResolverScript.apply(at_shrine, {"type": "rest"}, catalog)["state"]
	var travel := ResolverScript.apply(shrine_rest, {"type": "travel", "node_id": "rest_hollow"}, catalog)
	assert_true(bool(travel["result"]["ok"]))

	# The hollow's own visit is still unconsumed: its gate stays shut and its
	# choices stay open even though rest_shrine was already used this run.
	var hollow_gate := ResolverScript.apply(travel["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_false(bool(hollow_gate["result"]["ok"]))
	assert_eq(str(hollow_gate["result"]["reason"]), "rest_choice_required")
	var hollow_rest := ResolverScript.apply(travel["state"], {"type": "rest"}, catalog)
	assert_true(bool(hollow_rest["result"]["ok"]))
	assert_eq(str(hollow_rest["state"].node_flags.get("rest_shrine_used", "")), "used")
	assert_eq(str(hollow_rest["state"].node_flags.get("rest_hollow_used", "")), "used")


func test_instanced_rest_template_gates_travel_before_choice() -> void:
	var run := _run_at("L2R1N0")
	run.current_node_template_id = "rest_hollow"
	var gated := ResolverScript.apply(run, {"type": "travel", "node_id": "L2R2N0"}, catalog)
	var gated_result: Dictionary = gated.get("result", {})
	assert_false(bool(gated_result.get("ok", true)))
	assert_eq(str(gated_result.get("reason", "")), "rest_choice_required")


func test_rest_heal_recovers_thirty_percent_of_max_health() -> void:
	var run := _run_at("rest_shrine")
	run.health = 1
	run.max_health = 12
	var healed := ResolverScript.apply(run, {"type": "rest"}, catalog)
	assert_eq(int(healed["state"].health), mini(int(run.max_health), int(run.health) + int(floor(float(run.max_health) * 0.30))))


func test_rest_heal_never_drops_player_below_current_health() -> void:
	var run := _run_at("rest_shrine")
	run.health = 7
	run.max_health = 8
	var healed := ResolverScript.apply(run, {"type": "rest"}, catalog)
	assert_eq(int(healed["state"].health), 8)


func test_generated_layers_have_rest_node_every_stride_rows() -> void:
	for seed_value in [101, 4242, 91011]:
		var route: Array = MapGeneratorScript.build(seed_value, false, catalog)
		for layer in range(1, 6):
			var row_indices: Array = []
			for node in route:
				if int(node.get("layer", -1)) != layer:
					continue
				if str(node.get("template_id", "")) in ["rest_hollow", "rest_shrine"]:
					row_indices.append(int(node.get("row", -1)))
			row_indices.sort()
			var previous_row := -1
			for row in row_indices:
				if previous_row >= 0:
					# 间距以 MapGenerator.REST_ROW_STRIDE 为唯一事实来源（2026-09-08 由 3
					# 收紧到 2），别把数字写回测试。
					assert_eq(int(row) - previous_row, MapGeneratorScript.REST_ROW_STRIDE,
						"seed %d layer %d rest row %d must sit every %d rows"
						% [seed_value, layer, row, MapGeneratorScript.REST_ROW_STRIDE])
				previous_row = int(row)


func test_instanced_rest_template_session_leave_requires_choice() -> void:
	var run := _run_at("L2R1N0")
	run.current_node_template_id = "rest_hollow"
	var session := {"node_id": "L2R1N0", "completed": false}
	var left := preload("res://scripts/domain/encounter_session_resolver.gd").apply(
		run, session, {"type": "leave_node"}, catalog, {"id": "L2R1N0", "template_id": "rest_hollow", "type": "rest"})
	var left_result: Dictionary = left.get("result", {})
	assert_false(bool(left_result.get("ok", true)))
	assert_eq(str(left_result.get("reason", "")), "rest_choice_required")


# ---- bare completion marker: baseline event-stream parity ----

func _events_with_reason(state: RunState, reason: String) -> Array:
	var matches: Array = []
	for entry in state.event_log:
		if str(entry.get("reason", "")) == reason:
			matches.append(entry)
	return matches


func test_heal_leave_stream_stays_aligned_with_pre_scoped_baseline() -> void:
	# Pre-scoped baseline wrote the bare node id as the visited marker, so the
	# leave-time complete_node was a silent idempotent no-op: heal->leave
	# appended exactly one event and every later event kept its absolute tick
	# (seeded rolls derive from event_log.size()). Scoped keys must ride
	# alongside that marker or the whole random stream shifts.
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	run.health = 3
	run.essence = 1
	var base_size := run.event_log.size()

	var healed := ResolverScript.apply(run, {"type": "rest"}, catalog)
	assert_true(bool(healed["result"]["ok"]))
	assert_eq(str(healed["state"].node_flags.get("rest_shrine_used", "")), "used")
	assert_eq(str(healed["state"].node_flags.get("rest_shrine", "")), "used")

	var left := ResolverScript.apply(healed["state"], {
		"type": "complete_node", "node_id": "rest_shrine", "outcome": "abandoned",
	}, catalog)
	assert_true(bool(left["result"]["ok"]))
	# The parity lock itself: leave adds nothing beyond the heal entry.
	assert_eq(left["state"].event_log.size(), base_size + 1)
	assert_eq(_events_with_reason(left["state"], "node_completed").size(), 0)

	var appended_ids: Array = []
	for index in range(base_size, left["state"].event_log.size()):
		appended_ids.append(str(left["state"].event_log[index]["id"]))
	assert_eq(appended_ids, ["event_%04d" % base_size])

	# Repeated completion stays equally silent.
	var again := ResolverScript.apply(left["state"], {
		"type": "complete_node", "node_id": "rest_shrine", "outcome": "abandoned",
	}, catalog)
	assert_eq(again["state"].event_log.size(), base_size + 1)


func test_upgrade_and_removal_bare_markers_keep_mode_flags_isolated_across_nodes() -> void:
	# Review NOTE gap: upgrade/removal consume their visit through
	# _consume_rest_visit too, so the bare marker they now also write must not
	# turn one node's mode flag into another node's gate.
	var upgraded := ResolverScript.apply(_run_at("rest_shrine"), {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)
	assert_true(bool(upgraded["result"]["ok"]))
	assert_eq(str(upgraded["state"].node_flags.get("rest_shrine_mode", "")), "true")
	assert_eq(str(upgraded["state"].node_flags.get("rest_shrine", "")), "used")

	var travel := ResolverScript.apply(upgraded["state"], {"type": "travel", "node_id": "rest_hollow"}, catalog)
	assert_true(bool(travel["result"]["ok"]))

	var removed := ResolverScript.apply(travel["state"], {
		"type": "rest", "mode": "remove_card", "instance_id": "gu_001",
	}, catalog)
	assert_true(bool(removed["result"]["ok"]), str(removed["result"].get("reason", "")))
	assert_eq(str(removed["state"].gu_instances["gu_001"]["state"]), "dead")
	assert_eq(str(removed["state"].node_flags.get("rest_hollow_mode", "")), "true")
	assert_eq(str(removed["state"].node_flags.get("rest_hollow", "")), "used")
	# The shrine's scoped mode flag survives untouched by the hollow's removal.
	assert_eq(str(removed["state"].node_flags.get("rest_shrine_mode", "")), "true")
	assert_eq(_events_with_reason(removed["state"], "node_completed").size(), 0)


# ---- legacy save migration (add-only) ----

func _legacy_payload(flags: Dictionary) -> Dictionary:
	var run := RunState.new_run(31)
	run.current_node_id = "rest_hollow"
	run.node_flags = flags.duplicate(true)
	var data := {
		"version": SaveRepositoryScript.SAVE_VERSION,
		"state": run.to_save_data(),
		"route": [],
		"replies": [],
	}
	data["_checksum"] = SaveRepositoryScript._checksum_value(data["state"])
	return data


func test_legacy_visited_rest_save_migrates_additively() -> void:
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(
		_legacy_payload({"rest_hollow": "used", "rest_mode_used": "true"}))
	assert_false(loaded.is_empty())
	var flags: Dictionary = loaded["state"].node_flags

	# New per-node keys derived from the legacy literals.
	assert_eq(str(flags.get("rest_hollow_used", "")), "used")
	assert_eq(str(flags.get("rest_hollow_mode", "")), "true")
	# Add-only: the bare key stays because it doubles as the visited marker
	# (_complete_node idempotency + MapGenerator.reachable_nodes).
	assert_eq(str(flags.get("rest_hollow", "")), "used")
	assert_eq(str(flags.get("rest_mode_used", "")), "true")
	# And the migrated save may travel away from the consumed visit.
	var travel := ResolverScript.apply(
		loaded["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_true(bool(travel["result"]["ok"]))


func test_legacy_unvisited_rest_save_still_gates_travel() -> void:
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(_legacy_payload({}))
	assert_false(loaded.is_empty())
	var result := ResolverScript.apply(
		loaded["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_false(bool(result["result"]["ok"]))
	assert_eq(str(result["result"]["reason"]), "rest_choice_required")


# ---- data declaration & layer-two participation ----
# R-layering 2026-08-27: the five-layer ruling puts rest_shrine into the
# generation pool (layer two). The old "kept out of the generated map"
# contract is superseded; whether this specific node appears on a given
# seed is up to the picker, so only declaration + catalog validity are
# pinned here. Layer topology lives in test_five_layer_map_contract.gd.

func test_nodes_json_declares_second_rest_node_now_in_generation_pool() -> void:
	var nodes: Array = catalog["nodes"]
	assert_true(nodes.any(func(node: Dictionary) -> bool:
		return str(node.get("id", "")) == "rest_shrine" and str(node.get("type", "")) == "rest"))
	assert_eq(ContentCatalog.validate(catalog).size(), 0)


# ---- preview layer mirrors the generic rule ----

const SHRINE_NODE := {"id": "rest_shrine", "type": "rest", "choices": ["rest", "leave"]}


func test_preview_leave_lock_mirrors_domain_on_generic_rest_nodes() -> void:
	var run := _run_at("rest_shrine")
	var locked: Array = ActionPreviewServiceScript.preview_actions(run, SHRINE_NODE, catalog)
	assert_false(bool(_card(locked, "node.leave")["executable"]))

	var consumed: RunState = ResolverScript.apply(run, {"type": "rest"}, catalog)["state"]
	var open: Array = ActionPreviewServiceScript.preview_actions(consumed, SHRINE_NODE, catalog)
	assert_true(bool(_card(open, "node.leave")["executable"]))
	assert_false(bool(_card(open, "node.rest_heal")["executable"]))


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}
