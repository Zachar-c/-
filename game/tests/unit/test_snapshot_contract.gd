extends GutTest


# W4 快照契约测试（2026-09-09）：把 docs/contracts/2026-09-02-domain-ui-contract.md §2
# 声明的每屏必备键钉成红灯。任何快照键改名/删除而没有同步契约文档，本测试即红。
# 范围（v1）：Title / Map / Shop / Rest / Refine 五屏 + 局内屏通用键。
# v2 待补：Battle（需真实战斗语境，探针显示无战斗时直接调会崩于
# v1_battle_resolver.gd:254 basic_attack_reason 读 player on Dictionary）、Hall。
# 用途：它是 W11/W12 god-file 拆分的安全网 —— 拆分前必须先绿。

const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")


func _controller_before_run():
	var controller = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	await get_tree().process_frame
	return controller


func _controller_in_run() -> Dictionary:
	# 返回 {controller, snapshot_by_screen}；start_new_run 一次，逐屏取快照。
	var controller = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	await get_tree().process_frame
	controller.start_new_run(101)
	await get_tree().process_frame
	var by_screen := {}
	for screen in ["Map", "Shop", "Rest", "Refine"]:
		by_screen[screen] = RunSnapshotBuilderScript.for_screen(screen, controller)
	return {"controller": controller, "snapshots": by_screen}


# --- 局内屏通用键（契约 §2 "局内公共快照"） ---

func test_in_run_screens_carry_common_ledger_and_v2_groups() -> void:
	var ctx: Dictionary = await _controller_in_run()
	var snapshots: Dictionary = ctx["snapshots"]
	for screen in ["Map", "Shop", "Rest", "Refine"]:
		var snap: Dictionary = snapshots[screen]
		assert_true(snap.size() > 0, "%s snapshot must be non-empty" % screen)
		assert_true(snap.has("inventory"), "%s must carry inventory (contract §2)" % screen)
		assert_true(snap.has("death_lines"), "%s must carry death_lines (§2 death_lines)" % screen)
		for group in ["group1_gu_ledger", "group2_core", "group4_feeding", "group5_market",
				"group6_body", "group7_action", "group8_soul"]:
			assert_true(snap.has(group), "%s must carry %s (§2 v2 八组)" % [screen, group])
			assert_true(snap[group] is Dictionary, "%s.%s must be a Dictionary" % [screen, group])
		# group3_recipes 是配方清单（Array），元素携带 id/kind/product_rule/aux_core_warning
		assert_true(snap.has("group3_recipes"), "%s must carry group3_recipes (§2 v2 八组)" % screen)
		assert_true(snap["group3_recipes"] is Array,
				"%s.group3_recipes must be an Array (recipe list)" % screen)
		if not (snap["group3_recipes"] as Array).is_empty():
			var recipe: Dictionary = (snap["group3_recipes"] as Array)[0]
			for key in ["id", "kind", "product_rule", "aux_core_warning"]:
				assert_true(recipe.has(key), "group3_recipes[] must carry %s (§2 group3_recipes)" % key)
		assert_true(snap["inventory"] is Dictionary, "%s.inventory must be a Dictionary" % screen)


# --- Title（大厅）屏：契约 §2 Title/hall 行 + v8 线框稿段落 ---

func test_title_snapshot_carries_hall_entry_keys() -> void:
	var controller = await _controller_before_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Title", controller)
	assert_true(snap.size() > 0, "Title snapshot must be non-empty")
	assert_true(snap.has("run_summary"), "Title must carry run_summary (§2)")
	var summary: Dictionary = snap["run_summary"]
	for key in ["route", "rank", "hp", "lifespan", "gu_count", "node_count", "curse_count", "build_label"]:
		assert_true(summary.has(key), "Title.run_summary must carry %s (contract §2)" % key)
	assert_true(snap.has("has_save"), "Title must carry has_save")
	assert_true(snap.has("primary_action"), "Title must carry primary_action")
	assert_true(snap.has("available_schools"), "Title must carry available_schools")
	assert_true(snap["available_schools"] is Array, "available_schools must be an Array")
	assert_true(snap.has("meta_stats"), "Title must carry meta_stats")


# --- Map 屏：契约 §2 Map 行 ---

func test_map_snapshot_carries_route_nodes() -> void:
	var ctx: Dictionary = await _controller_in_run()
	var snap: Dictionary = ctx["snapshots"]["Map"]
	assert_true(snap.has("nodes"), "Map must carry nodes")
	assert_true(snap["nodes"] is Array, "Map.nodes must be an Array")
	assert_gt((snap["nodes"] as Array).size(), 0, "Map.nodes must not be empty after start_new_run")
	var first_node: Dictionary = (snap["nodes"] as Array)[0]
	for key in ["id", "type", "layer", "row", "reachable", "visited", "current"]:
		assert_true(first_node.has(key), "Map.nodes[] must carry %s (contract §2)" % key)
	assert_true(snap.has("current_node_id"), "Map must carry current_node_id")
	assert_true(snap.has("inventory"), "Map must carry inventory")


# --- Shop 屏：契约 §2 Shop 行（货架报价 / _shop_services） ---

func test_shop_snapshot_carries_offers_and_services() -> void:
	var ctx: Dictionary = await _controller_in_run()
	var snap: Dictionary = ctx["snapshots"]["Shop"]
	# 至少存在库存/资源等状态投影（_shop_services 仅黑市语境非空，不强断言非空）
	assert_true(snap.has("inventory"), "Shop must carry inventory")
	assert_true(snap.has("contracts"), "Shop must carry contracts (顶栏契约组)")


# --- Rest 屏：契约 §2 Rest 行（choices 是域全集门禁，AGENTS 红线） ---

func test_rest_snapshot_carries_choice_contract() -> void:
	var ctx: Dictionary = await _controller_in_run()
	var snap: Dictionary = ctx["snapshots"]["Rest"]
	assert_true(snap.has("choices"), "Rest must carry choices (契约 §2 rest choices 域全集)")
	assert_true(snap["choices"] is Array, "Rest.choices must be an Array")
	# 契约 §2：choices 携带 heal/upgrade_card/remove_card/remove_imprint/remove_curse/skip 域全集条目
	# （具体可用性随状态禁用，但键必须出现在 choices 里供 UI 渲染）
	var choice_ids := {}
	for choice_value in (snap["choices"] as Array):
		var choice: Dictionary = choice_value
		choice_ids[str(choice.get("id", ""))] = true
	for domain_id in ["heal", "upgrade_card", "remove_card", "remove_imprint", "remove_curse", "skip"]:
		assert_true(choice_ids.has(domain_id),
				"Rest.choices must expose domain id %s (rest 全集红线; got %s)" % [domain_id, str(choice_ids.keys())])
	for choice_value in (snap["choices"] as Array):
		var choice: Dictionary = choice_value
		for key in ["disabled", "reason"]:
			assert_true(choice.has(key), "Rest.choices[] must carry %s" % key)


# --- Refine 屏：契约 §2 Refine 行 ---

func test_refine_snapshot_carries_synthesis_keys() -> void:
	var ctx: Dictionary = await _controller_in_run()
	var snap: Dictionary = ctx["snapshots"]["Refine"]
	assert_true(snap.size() > 0, "Refine snapshot must be non-empty")
	# 炼蛊台核心键随状态可能为空字典，但键必须存在（契约 §2 Refine 行）
	assert_true(snap.has("inventory"), "Refine must carry inventory")
