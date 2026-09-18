extends GutTest


# Night batch N-candidate: NPC personal inventories. npc_trade reuses the shop
# handlers verbatim after NPC-scoped gates (stock containment + node presence),
# so prices/deck gates/seeded barter stay byte-identical with shop purchases.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state_at(node_id: String, seed_value: int = 101) -> RunState:
	var state := RunState.new_run(seed_value)
	state.current_node_id = node_id
	return state


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func test_real_catalog_validates_clean_and_nodes_declare_npc_owners() -> void:
	assert_true(ContentCatalogScript.validate(catalog).is_empty(),
			str(ContentCatalogScript.validate(catalog)))
	var found := {}
	for node in catalog["nodes"]:
		if str(node.get("npc_id", "")) != "":
			found[str(node["id"])] = str(node.get("npc_id", ""))
	assert_eq(found.get("ridge_caravan", ""), "caravan_steward")
	assert_eq(found.get("caravan_missing_goods", ""), "caravan_steward")
	assert_eq(found.get("village_short_work", ""), "wandering_healer")
	assert_eq(found.get("ridge_black_market", ""), "ridge_extortionist")


func test_validation_rejects_bad_npc_stock() -> void:
	var tuned := catalog.duplicate(true)
	tuned["npcs"] = catalog["npcs"].duplicate(true)
	var ghost: Dictionary = catalog["npcs"][0].duplicate(true)
	ghost["id"] = "stock_probe"
	ghost["stock"] = ["ghost_offer"]
	tuned["npcs"].append(ghost)
	var errors := ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "stock references unknown offer"))

	ghost["stock"] = ["soul_pill", "soul_pill"]
	tuned["npcs"] = catalog["npcs"].duplicate(true)
	tuned["npcs"].append(ghost)
	errors = ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "stock duplicates offer"))

	tuned["shop_offer_by_id"] = catalog["shop_offer_by_id"].duplicate(true)
	tuned["shop_offer_by_id"]["weird_offer"] = {"kind": "magic", "card_key": "x"}
	ghost["stock"] = ["weird_offer"]
	tuned["npcs"] = catalog["npcs"].duplicate(true)
	tuned["npcs"].append(ghost)
	errors = ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "unsupported kind"))


func test_npc_trade_happy_path_purchases_through_shop_semantics() -> void:
	var state := _state_at("ridge_caravan")
	var cost := ResolverScript.price_for(catalog, state, 6)
	var result := ResolverScript.apply(state, {
		"type": "npc_trade", "npc_id": "caravan_steward", "offer_id": "purchase_stone_shell",
	}, catalog)
	assert_true(bool(result["result"]["ok"]))
	assert_eq(int(result["state"].stone), 12 - cost)
	var granted := false
	for instance_value in result["state"].gu_instances.values():
		var instance: Dictionary = instance_value
		if str(instance.get("definition_id", "")) == "stone_shell_gu":
			granted = true
	assert_true(granted)
	var stored: Array = result["state"].cave_aperture["stored_gu_instance_ids"]
	var stored_count := 0
	for instance_id_value in stored:
		var instance: Dictionary = result["state"].gu_instances[str(instance_id_value)]
		if str(instance.get("definition_id", "")) == "stone_shell_gu":
			stored_count += 1
	assert_eq(stored_count, 1)
	var event: Dictionary = result["state"].event_log.back()
	assert_eq(str(event["action"]), "shop_purchase")
	assert_eq(str(event["reason"]), "shop_purchase_completed")
	assert_eq(event["targets"], ["stone_shell_gu"])


func test_npc_trade_rejections() -> void:
	var steward := {"type": "npc_trade", "npc_id": "caravan_steward", "offer_id": "purchase_stone_shell"}
	var ghost_npc := steward.duplicate()
	ghost_npc["npc_id"] = "ghost_npc"
	assert_eq(str(ResolverScript.apply(_state_at("ridge_caravan"), ghost_npc, catalog)["result"]["reason"]), "unknown_npc")
	var ghost_offer := steward.duplicate()
	ghost_offer["offer_id"] = "ghost_offer"
	assert_eq(str(ResolverScript.apply(_state_at("ridge_caravan"), ghost_offer, catalog)["result"]["reason"]), "unknown_shop_offer")
	var not_stocked := steward.duplicate()
	not_stocked["offer_id"] = "lifespan_pulse_drum"
	assert_eq(str(ResolverScript.apply(_state_at("ridge_caravan"), not_stocked, catalog)["result"]["reason"]), "npc_stock_missing")
	assert_eq(str(ResolverScript.apply(_state_at("ridge_black_market"), steward, catalog)["result"]["reason"]), "npc_not_present")
	var poor := _state_at("ridge_caravan")
	poor.stone = 3
	assert_eq(str(ResolverScript.apply(poor, steward, catalog)["result"]["reason"]), "insufficient_stone")


func test_npc_trade_barter_delegation_is_seeded() -> void:
	var tuned := catalog.duplicate(true)
	tuned["npcs"] = catalog["npcs"].duplicate(true)
	for npc_value in tuned["npcs"]:
		var npc: Dictionary = npc_value
		if str(npc.get("id", "")) == "earth_vein_scout":
			npc["stock"] = ["barter_unknown_gu"]
	tuned["nodes"] = catalog["nodes"].duplicate(true)
	tuned["nodes"].append({
		"id": "scout_den", "stage": "one", "type": "contact", "npc_id": "earth_vein_scout",
		"choices": ["negotiate", "leave"], "time_scale": "hours", "on_skip": "none", "next_ids": [],
	})
	var state := RunState.new_run(101)
	state.current_node_id = "scout_den"
	# barter_unknown_gu 的输入蛊随 802 重建从 trail_eye_gu 迁到 qi_rec_2_14_gu。
	state.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "qi_rec_2_14_gu", "state": "refined"},
	}
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_001"]
	state.refined_gu_ids = ["qi_rec_2_14_gu"]
	state.gu_ids = ["qi_rec_2_14_gu"]
	var result := ResolverScript.apply(state, {
		"type": "npc_trade", "npc_id": "earth_vein_scout", "offer_id": "barter_unknown_gu",
		"input_instance_ids": ["gu_001"],
	}, tuned)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	var event: Dictionary = result["state"].event_log.back()
	assert_eq(str(event["action"]), "shop_barter")
	assert_eq(str(event["reason"]), "shop_barter_resolved")
	var consumed: Dictionary = result["state"].gu_instances["gu_001"]
	assert_eq(str(consumed.get("state", "")), "dead")


func test_npc_trade_is_deterministic() -> void:
	var command := {
		"type": "npc_trade", "npc_id": "caravan_steward", "offer_id": "purchase_stone_shell",
	}
	var first_result: Dictionary = ResolverScript.apply(_state_at("ridge_caravan"), command, catalog)
	var second_result: Dictionary = ResolverScript.apply(_state_at("ridge_caravan"), command, catalog)
	var first: RunState = first_result["state"]
	var second: RunState = second_result["state"]
	assert_eq(first.event_log.size(), second.event_log.size())
	assert_eq(first.event_log.back(), second.event_log.back())


func test_snapshot_npc_offers_come_from_real_stock() -> void:
	var state := _state_at("ridge_caravan")
	var stub := {
		"current_node": {
			"id": "ridge_caravan", "type": "caravan", "npc_id": "caravan_steward",
			"choices": ["buy", "sell", "exchange", "leave"],
		},
		"state": state,
		"meta": null,
		"catalog": catalog,
	}
	var snaps: Dictionary = RunSnapshotBuilderScript.npc(stub)
	var offers: Array = snaps["offers"]
	assert_eq(offers.size(), 3)
	var ids: Array[String] = []
	for offer_value in offers:
		var offer: Dictionary = offer_value
		ids.append(str(offer["id"]))
		if str(offer["id"]) == "purchase_stone_shell":
			# 展示价必须等于实收价：purchase 与 _shop_purchase 同走 shop_layer_price。
			assert_eq(str(offer["price"]), "%d 元石" % ResolverScript.shop_layer_price(catalog, state, 6))
			assert_eq(str(offer["name"]), DisplayText.gu("stone_shell_gu"))
			assert_eq(str(offer["kind"]), "purchase")
			assert_eq(str(offer["quality"]), "稀有")
			assert_true(bool(offer["executable"]))
			assert_eq(str(offer["block_reason"]), "")
	assert_true(ids.has("purchase_stone_shell"))
	assert_true(ids.has("purchase_moonlight"))
	assert_true(ids.has("soul_pill"))
	assert_eq((snaps["barter"] as Array).size(), 0)

	var empty_stub := {
		"current_node": {"id": "stage_one_ledger", "type": "ledger", "choices": []},
		"state": state,
		"meta": null,
		"catalog": catalog,
	}
	var empty_catalog := catalog.duplicate(true)
	empty_catalog["npcs"] = []
	empty_stub["catalog"] = empty_catalog
	var empty_snaps: Dictionary = RunSnapshotBuilderScript.npc(empty_stub)
	assert_eq((empty_snaps["offers"] as Array).size(), 0)
	assert_eq((empty_snaps["barter"] as Array).size(), 0)


## §16.5 透明度：货阶超层的货保留展示但禁点并给原因；寿元交易带预检文案。
func test_snapshot_npc_offers_surface_tier_block_and_lifespan_precheck() -> void:
	var state := _state_at("ridge_caravan")
	var stub := {
		"current_node": {
			"id": "ridge_caravan", "type": "caravan", "npc_id": "caravan_steward",
			"choices": ["buy", "sell", "exchange", "leave"],
		},
		"state": state,
		"meta": null,
		"catalog": catalog,
	}
	var by_id := {}
	for offer_value in (RunSnapshotBuilderScript.npc(stub)["offers"] as Array):
		var offer: Dictionary = offer_value
		by_id[str(offer["id"])] = offer
	# Stage 1（2026-09-16）：货阶分层是「黑市上架」概念，只约束黑市节点。
	# NPC 个人货架（npc.stock）已由数据精确约束，不再套黑市分层 ——
	# 商队的 t3 月光蛊与 t2 魂魄丹在 L1 应当可点（与命令面 npc_trade 同口径）。
	assert_eq(str(by_id["purchase_moonlight"]["block_reason"]), "")
	assert_true(bool(by_id["purchase_moonlight"]["executable"]))
	assert_true(bool(by_id["soul_pill"]["executable"]))

	var extortionist_stub := {
		"current_node": {
			"id": "ridge_black_market", "type": "shop", "npc_id": "ridge_extortionist",
			"choices": [],
		},
		"state": state,
		"meta": null,
		"catalog": catalog,
	}
	var market_offers: Array = RunSnapshotBuilderScript.npc(extortionist_stub)["offers"]
	assert_eq(market_offers.size(), 1)
	var drum: Dictionary = market_offers[0]
	assert_true(bool(drum["curse_warning"]))
	# 黑市节点（type=shop）仍受货阶分层约束：L1 上限 1，t2 的寿元鼓禁点并给原因。
	assert_false(bool(drum["executable"]))
	assert_eq(str(drum["block_reason"]), "货阶超出当前大层")
	assert_true(str(drum["price"]).contains("寿元"))
	assert_true(str(drum["precheck"]).contains("当前寿元"), "lifespan deals must carry a precheck line")


## §16.5 后果预览：易物条目标注持有量；未持有可交付蛊时禁点并给原因。
func test_snapshot_npc_barter_owned_preview() -> void:
	var peddler_node := {
		"id": "wandering_peddler", "type": "contact", "npc_id": "wandering_peddler",
		"choices": ["negotiate", "deceive", "fight", "retreat"],
	}
	var empty_state := _state_at("wandering_peddler")
	var empty_snaps: Dictionary = RunSnapshotBuilderScript.npc({
		"current_node": peddler_node, "state": empty_state, "meta": null, "catalog": catalog,
	})
	var empty_barter: Array = empty_snaps["barter"]
	assert_eq(empty_barter.size(), 1)
	assert_eq(int(empty_barter[0]["owned"]), 0)
	assert_false(bool(empty_barter[0]["executable"]))
	assert_true(str(empty_barter[0]["block_reason"]).contains("未持有"))
	assert_true(str(empty_barter[0]["note"]).contains("消耗"))

	var holding := _state_at("wandering_peddler")
	holding.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "qi_rec_2_14_gu", "state": "refined"},
	}
	holding.cave_aperture["stored_gu_instance_ids"] = ["gu_001"]
	var holding_snaps: Dictionary = RunSnapshotBuilderScript.npc({
		"current_node": peddler_node, "state": holding, "meta": null, "catalog": catalog,
	})
	var holding_barter: Array = holding_snaps["barter"]
	assert_eq(int(holding_barter[0]["owned"]), 1)
	assert_true(bool(holding_barter[0]["executable"]))
	assert_eq(str(holding_barter[0]["block_reason"]), "")


## Shop 屏与 Npc 屏共用 NPC 名/立场推导：同一个 NPC 在两屏必须同名。
func test_shop_snapshot_shows_real_npc_identity() -> void:
	var state := _state_at("ridge_black_market")
	state.node_flags["reputation_hostile"] = "true"
	var market: Dictionary = RunSnapshotBuilderScript.shop({
		"current_node": {"id": "ridge_black_market", "type": "shop", "npc_id": "ridge_extortionist", "choices": []},
		"state": state, "meta": null, "catalog": catalog,
	})
	assert_eq(str(market["npc_name"]), "山岭索贿者")
	assert_eq(str(market["npc_stance"]), "敌视")

	var generic: Dictionary = RunSnapshotBuilderScript.shop({
		"current_node": {"id": "ridge_market", "type": "market", "choices": ["trade"]},
		"state": state, "meta": null, "catalog": catalog,
	})
	assert_eq(str(generic["npc_name"]), "地脉游商")
	assert_eq(str(generic["npc_stance"]), "中立")

	var peddler: Dictionary = RunSnapshotBuilderScript.npc({
		"current_node": {"id": "wandering_peddler", "type": "contact", "npc_id": "wandering_peddler", "choices": []},
		"state": state, "meta": null, "catalog": catalog,
	})
	assert_eq(str(peddler["npc_name"]), "散修货郎")


## 2026-08-28 验收批：黑市服务面板由领域真值导出——价格走 service_price_for
## （含次数递增），剩余走 service_limit - service_use_count，目标候选排除
## can_direct_drop=false 诅咒蛊与规则型印记；池屏蔽/净化躁动不再出现。
func test_shop_services_come_from_domain_truth() -> void:
	var state := _state_at("ridge_black_market")
	state.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "stone_shell_gu", "state": "refined"},
	}
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_001"]
	state.node_flags["svc_used_remove_card"] = "1"
	var snaps: Dictionary = RunSnapshotBuilderScript.shop({
		"current_node": {"id": "ridge_black_market", "type": "shop", "npc_id": "ridge_extortionist", "choices": []},
		"state": state, "meta": null, "catalog": catalog,
	})
	var by_id := {}
	for service_value in (snaps["services"] as Array):
		var service: Dictionary = service_value
		by_id[str(service["id"])] = service
	assert_false(by_id.has("pool_block"), "pool exclusion has no domain support and must not appear")
	assert_false(by_id.has("calm"), "restlessness service has no domain support and must not appear")

	var remove_card: Dictionary = by_id["remove_card"]
	# 已用 1 次 → 递增价：base 120 × price_for × (1 + 25%)
	var escalated := ResolverScript.service_price_for(catalog, state, "remove_card", int(catalog["balance"]["remove_card_cost"]))
	assert_eq(str(remove_card["price"]), "%d 元石" % escalated)
	assert_eq(int(remove_card["remaining"]), 1)
	assert_true(bool(remove_card["executable"]))
	assert_eq(((remove_card["candidates"] as Array)[0] as Dictionary)["id"], "gu_001")

	var wash: Dictionary = by_id["wash_notoriety"]
	assert_true(str(wash["price"]).contains("寿元"), "wash_notoriety is priced in lifespan per resolver")


## 散修货郎（2026-08-28 挂账落地）：contact 模板携带 npc_id 后，Npc 交易面板
## 的个人货架首次真实可达——resolve_contact 门禁放宽到 contact 模板全族。
func test_peddler_contact_node_carries_tradeable_stock() -> void:
	var peddler := {}
	for node_value in catalog["nodes"]:
		if str((node_value as Dictionary).get("id", "")) == "wandering_peddler":
			peddler = node_value
	assert_eq(str(peddler.get("type", "")), "contact")
	assert_eq(str(peddler.get("npc_id", "")), "wandering_peddler")

	var state := _state_at("wandering_peddler")
	var cost := ResolverScript.shop_layer_price(catalog, state, 6)
	var result := ResolverScript.apply(state, {
		"type": "npc_trade", "npc_id": "wandering_peddler", "offer_id": "purchase_stone_shell",
	}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_eq(int(result["state"].stone), 12 - cost)

	var barter_state := _state_at("wandering_peddler")
	barter_state.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "qi_rec_2_14_gu", "state": "refined"},
	}
	barter_state.cave_aperture["stored_gu_instance_ids"] = ["gu_001"]
	barter_state.refined_gu_ids = ["qi_rec_2_14_gu"]
	barter_state.gu_ids = ["qi_rec_2_14_gu"]
	var barter := ResolverScript.apply(barter_state, {
		"type": "npc_trade", "npc_id": "wandering_peddler", "offer_id": "barter_unknown_gu",
		"input_instance_ids": ["gu_001"],
	}, catalog)
	assert_true(bool(barter["result"]["ok"]), str(barter["result"]))
	assert_eq(str((barter["state"].gu_instances["gu_001"] as Dictionary).get("state", "")), "dead")


func test_peddler_contact_approaches_match_wanderer_contract() -> void:
	var fight_result: Dictionary = ResolverScript.apply(_state_at("wandering_peddler"), {
		"type": "resolve_contact", "node_id": "wandering_peddler", "approach": "fight",
	}, catalog)
	assert_true(bool(fight_result["result"]["ok"]))
	assert_true(bool(fight_result["result"].get("start_battle", false)))

	var deceive := _state_at("wandering_peddler")
	var deceive_result: Dictionary = ResolverScript.apply(deceive, {
		"type": "resolve_contact", "node_id": "wandering_peddler", "approach": "deceive",
	}, catalog)
	assert_true(bool(deceive_result["result"]["ok"]))
	assert_eq(int(deceive_result["state"].stone), 14)
	assert_eq(str(deceive_result["state"].event_log.back()["reason"]), "wandering_peddler_deceive")

	var retreat := _state_at("wandering_peddler")
	var retreat_result: Dictionary = ResolverScript.apply(retreat, {
		"type": "resolve_contact", "node_id": "wandering_peddler", "approach": "retreat",
	}, catalog)
	assert_true(bool(retreat_result["result"]["ok"]))
	assert_eq(int(retreat_result["state"].stone), 11)

	var negotiate_result: Dictionary = ResolverScript.apply(_state_at("wandering_peddler"), {
		"type": "resolve_contact", "node_id": "wandering_peddler", "approach": "negotiate",
	}, catalog)
	assert_true(bool(negotiate_result["result"]["ok"]))
	assert_eq(str(negotiate_result["result"].get("reward", "")), "caravan_discount")

	assert_eq(str(ResolverScript.apply(_state_at("refinement_hollow"), {
		"type": "resolve_contact", "node_id": "refinement_hollow", "approach": "negotiate",
	}, catalog)["result"]["reason"]), "unknown_contact")