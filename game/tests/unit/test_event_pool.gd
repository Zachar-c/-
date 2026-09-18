extends GutTest

# D4 事件池（2026-09-16）：宿主事件选取 + 真实收益结算 + 预检/结算同源。
#
# 覆盖三件事：
#   1. `accept_event` 的 `stone_gain` 必须在**同一条**不可变事件日志里落账；
#   2. 事件卡片只渲染本点位宿主的那一条（扩容到 12 条后不能铺满屏）；
#   3. 卡片上的代价/收益文案与真实结算**同源**（数值全部由杠杆派生，禁止各写一份）。

const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_accept_event_settles_stone_gain_in_the_same_logged_event() -> void:
	var run := RunState.new_run(101)
	var stone_before := run.stone
	var accepted := Resolver.apply(run, {"type": "accept_event", "event_id": "echo_cave"}, catalog)

	assert_true(bool(accepted["result"]["ok"]))
	assert_eq(int(accepted["state"].stone), stone_before + 2, "stone_gain must be settled")
	var logged: Dictionary = accepted["state"].event_log[accepted["state"].event_log.size() - 1]
	assert_eq(str(logged["action"]), "accept_event")
	assert_eq(int(logged["before"]["stone"]), stone_before)
	assert_eq(int(logged["after"]["stone"]), stone_before + 2)


func test_accept_event_rejects_when_health_cannot_cover_the_cost() -> void:
	var run := RunState.new_run(101)
	run.health = 2
	var stone_before := run.stone
	# huajiu_cache 代价 2 气血：health <= cost 必须被拒（不允许静默致死）。
	var rejected := Resolver.apply(run, {"type": "accept_event", "event_id": "huajiu_cache"}, catalog)

	assert_false(bool(rejected["result"]["ok"]))
	assert_eq(str(rejected["result"]["reason"]), "insufficient_health")
	assert_eq(int(rejected["state"].stone), stone_before, "rejected event must not pay out")


func test_accept_event_grants_stone_and_curse_together() -> void:
	var run := RunState.new_run(101)
	var stone_before := run.stone
	var accepted := Resolver.apply(
			run, {"type": "accept_event", "event_id": "blood_vein_offering"}, catalog)

	assert_true(bool(accepted["result"]["ok"]))
	assert_eq(int(accepted["state"].health), 78)
	assert_eq(int(accepted["state"].stone), stone_before + 4)
	assert_gt(CurseRegistry.layers_of(accepted["state"], "essence_bloat"), 0,
			"curse_bargain must land with the payout")


func test_preview_renders_only_the_host_event() -> void:
	var run := RunState.new_run(101)
	# echo_cave 节点未声明 event_id ⇒ 回退到 node.id（与 run_travel_flow 同源）。
	var cards := ActionPreviewServiceScript.preview_actions(
			run, {"id": "echo_cave", "type": "event"}, catalog)

	var accept_ids: Array[String] = []
	for card in cards:
		if str(card.get("id", "")).begins_with("event."):
			accept_ids.append(str(card["id"]))
	assert_eq(accept_ids, ["event.echo_cave.accept"],
			"an event node must render exactly its own host event")


func test_preview_follows_node_event_id_over_node_id() -> void:
	var run := RunState.new_run(101)
	var node := {"id": "L2R3N1", "type": "event", "event_id": "duel_wager"}
	var card := _card(ActionPreviewServiceScript.preview_actions(run, node, catalog),
			"event.duel_wager.accept")

	assert_eq(str(card["command"]["event_id"]), "duel_wager")
	assert_eq(str(card["title"]), "赌斗押注")
	assert_false(card["expected_gain"].is_empty())


func test_preview_keeps_leave_card_when_no_host_event_matches() -> void:
	var run := RunState.new_run(101)
	# toxic_mountain_path 是 hazard 点位 id，不是事件 id：不得渲染任何应答卡，
	# 但必须留离场卡，否则玩家会被软锁在节点里。
	var cards := ActionPreviewServiceScript.preview_actions(
			run, {"id": "toxic_mountain_path", "type": "event"}, catalog)

	var has_accept := false
	var has_leave := false
	for card in cards:
		if str(card.get("id", "")).begins_with("event."):
			has_accept = true
		if str(card.get("command", {}).get("type", "")) == "leave_node":
			has_leave = true
	assert_false(has_accept, "no host event -> no accept card")
	assert_true(has_leave, "leave must stay available (no soft-lock)")


## 反漂移守卫：卡片上每一条代价/收益都必须由事件的数值杠杆派生。
## 一旦有人只改 JSON 不改正则、或只改文案不改结算，这条会当场炸。
func test_preview_cost_and_gain_lines_are_derived_from_the_actual_levers() -> void:
	var run := RunState.new_run(101)
	var events: Array = catalog.get("events", [])
	assert_gt(events.size(), 0, "catalog canary: no events at all")

	for event_value in events:
		var event: Dictionary = event_value
		var event_id := str(event["id"])
		var node := {"id": "synth_%s" % event_id, "type": "event", "event_id": event_id}
		var card := _card(ActionPreviewServiceScript.preview_actions(run, node, catalog),
				"event.%s.accept" % event_id)
		assert_false(card.is_empty(), "missing accept card for %s" % event_id)

		var risks := " ".join(card["known_risk"])
		var gains := " ".join(card["expected_gain"])
		var health_cost := int(event.get("health_cost", 0))
		var delayed_soul := int(event.get("delayed_soul_cost", 0))
		var stone_gain := int(event.get("stone_gain", 0))
		var curse_id := str(event.get("curse_id", ""))

		assert_eq(bool(card["executable"]), run.health > health_cost,
				"%s executable must follow the same precheck as the resolver" % event_id)
		if health_cost > 0:
			assert_string_contains(risks, "%d 点气血" % health_cost, event_id)
		if delayed_soul > 0:
			assert_string_contains(risks, "%d 点魂魄" % delayed_soul, event_id)
		if not curse_id.is_empty():
			assert_string_contains(risks, str(catalog["curse_by_id"][curse_id]["name_zh"]), event_id)
		if stone_gain > 0:
			assert_string_contains(gains, "%d 枚元石" % stone_gain, event_id)
		else:
			assert_false(gains.contains("枚元石"), "%s must not promise stone it never pays" % event_id)


func test_catalog_validation_accepts_the_shipped_event_pool() -> void:
	var loaded := ContentCatalog.load_and_validate_all()
	assert_eq(loaded["errors"], [], "shipped catalog must validate cleanly")


func test_catalog_validation_rejects_an_unknown_event_pool_member() -> void:
	var broken := catalog.duplicate(true)
	var node: Dictionary = (broken["nodes"][0] as Dictionary)
	node["type"] = "event"
	node["event_pool"] = ["echo_cave", "no_such_event"]

	var errors: Array = ContentCatalog.validate(broken)
	var found := false
	for line in errors:
		if str(line).contains("event_pool references unknown event"):
			found = true
	assert_true(found, "validator must reject unknown event_pool members: %s" % str(errors))


func test_every_event_declares_a_title_and_at_least_one_lever() -> void:
	for event_value in catalog.get("events", []):
		var event: Dictionary = event_value
		var event_id := str(event["id"])
		assert_false(str(event.get("title", "")).is_empty(), "%s needs a title" % event_id)
		var levers := int(event.get("health_cost", 0)) + int(event.get("delayed_soul_cost", 0)) \
				+ int(event.get("stone_gain", 0)) + (1 if event.has("curse_id") else 0)
		assert_gt(levers, 0, "%s is dead content: no cost, no gain, no curse" % event_id)


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	return {}
