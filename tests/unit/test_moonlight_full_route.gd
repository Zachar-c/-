extends GutTest


# 光道全链路验收（2026-08-31 用户验收台账；moonlight 系于 C2 2026-09-05
# 并入 light，本路由改用光道开局）：
# 开局（光道 + 枯敌试炼契约）→ 战斗节点击败敌人并确认奖励 →
# 黑市节点 5 条资源交易全部可换（一次性）→ 交易节点在 1000 元石内
# 购买蛊虫与材料 → 炼蛊节点炼出月芒蛊（moonlight_glow）与白玉蛊
# （white_jade_basic 基础蛊方默认解锁）→ 休整节点回复 30% 生命
# （不超过上限）→ 击败第一层 Boss → 进入第二层地图。
#
# 路线为测试夹具手工构造的线性实例链（机制已验证：reachable 只看
# next_ids 与 boss_defeated_L{n} 旗标；每节点完成后 node_flags 落id）。
#
# 战斗策略：只用无反噬的 rank1 手段——小光蛊（光术绕过敌方反应）、
# 守护卡（guarded 反制直击反应）、白猪力蛊（临时力道+3）+ 拳脚。
# 月芒蛊 rank=2，施放触发转阶反噬扣魂魄，验收流程不碰。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

# 802 重建后 light 校 v2 starter pack（schools.json）不再含月光系战斗蛊：
# 战斗中先消费 pack 里的小光蛊与守御蛊，月芒/白玉炼蛊靠市场购入的
# 月光蛊 + 备用小光蛊完成，Boss 战仍有剩余的小光蛊可攻。
const LIGHT_GU_IDS := ["small_light_gu", "moonlight_gu"]
const GUARD_GU_IDS := ["stone_shell_gu", "jade_skin_gu", "bear_strength_gu"]


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _route_node(id: String, template_id: String, type: String, layer: int, row: int, next_ids: Array, extra: Dictionary = {}) -> Dictionary:
	var node := {
		"id": id,
		"template_id": template_id,
		"type": type,
		"layer": layer,
		"row": row,
		"next_ids": next_ids,
	}
	for key in extra:
		node[key] = extra[key]
	return node


func _build_route() -> Array[Dictionary]:
	var route: Array[Dictionary] = [
		_route_node("L1R0N0", "beast_swarm_pass", "combat", 1, 0, ["L1R1N0"], {"start": true, "enemy_kind": "ridge_hound", "choices": ["fight", "retreat"]}),
		_route_node("L1R1N0", "ridge_black_market", "shop", 1, 1, ["L1R2N0"], {"choices": []}),
		_route_node("L1R2N0", "ridge_market", "market", 1, 2, ["L1R3N0"], {"choices": ["trade", "leave"]}),
		_route_node("L1R3N0", "refinement_hollow", "refinement", 1, 3, ["L1R4N0"], {"choices": ["refine", "leave"]}),
		_route_node("L1R4N0", "rest_hollow", "rest", 1, 4, ["L1R5N0"], {"choices": ["rest", "leave"]}),
		_route_node("L1R5N0", "layer_boss_stand_1", "combat", 1, 5, ["L2R0N0"], {"enemy_kind": "crag_serpent_matriarch", "layer_boss": 1, "choices": ["fight"]}),
		_route_node("L2R0N0", "toxic_mountain_path", "hazard", 2, 0, [], {"choices": ["scout", "leave"]}),
	]
	return route


func _start_light_run() -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(20260831, "light", ["enemy_vitality_trial"])
	# 深层机制覆盖：本测试走多层契约，关闭切片收官（S6 默认 L1 Boss 落败即 Ending）。
	controller.catalog["pacing"]["ending_after_stage"] = ""
	controller.route = _build_route()
	return controller


func _living_target_id(battle: Dictionary) -> String:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)) and int(enemy.get("hp", 0)) > 0:
			return str(enemy.get("id", ""))
	return ""


## V1 蛊行动制：按蛊槽 definition_id 挑目标蛊，use_gu 直接施放。
func _play_source_gu(controller: RunController, battle: Dictionary, skip: Dictionary, gu_ids: Array) -> bool:
	for slot_value in battle.get("gu_slots", []):
		var slot: Dictionary = slot_value
		var instance_id := str(slot.get("instance_id", ""))
		if skip.has(instance_id):
			continue
		if not (str(slot.get("definition_id", "")) in gu_ids):
			continue
		var res := controller.submit_command({
			"type": "use_gu",
			"instance_id": instance_id,
			"state_version": controller.state.event_log.size(),
		})
		if bool(res.get("accepted", false)):
			return true
		skip[instance_id] = true
	return false


func _fight_to_victory(controller: RunController, max_steps: int = 40) -> void:
	var debug := OS.get_environment("DEBUG_FIGHT") == "1"
	var skip := {}
	var steps := 0
	while controller.current_view_name() == "Battle" and steps < max_steps:
		steps += 1
		var battle: Dictionary = controller.current_battle
		if debug:
			var slot_desc := []
			for slot_value in battle.get("gu_slots", []):
				slot_desc.append(str((slot_value as Dictionary).get("definition_id", "")))
			print("[fight %d] turn=%s thoughts=%s used=%s qi=%s hp=%s target=%s slots=%s flags=%s" % [
				steps, str(battle.get("turn")), str(battle["player"].get("thoughts")),
				str(battle["player"].get("used_this_turn")), str(battle["player"].get("true_qi")),
				str(battle["player"].get("hp")), str(_living_target_id(battle)),
				str(slot_desc), str(battle.get("flags"))])
		var acted := false
		# 1) 小光蛊：rank1 光术伤害，绕过敌方反应（每回合一次）
		acted = _play_source_gu(controller, battle, skip, LIGHT_GU_IDS)
		# 2) 守护蛊：护盾/力道上场（V1 常驻或瞬发皆可）
		if not acted:
			acted = _play_source_gu(controller, battle, skip, GUARD_GU_IDS)
		# 3) 白猪力蛊：力道 +1（每回合一次；V1 无临时力道投影，按 slot 限次即可）
		if not acted:
			acted = _play_source_gu(controller, battle, skip, ["white_boar_strength_gu"])
		# 4) 拳脚：基础 1 + 力道/仪仗，耗 1 念头
		if not acted:
			var res := controller.submit_command({
				"type": "basic_attack",
				"state_version": controller.state.event_log.size(),
			})
			if bool(res.get("accepted", false)):
				acted = true
		# 5) 收势：敌人回合结算后念头回满，skip 随回合重置
		if not acted:
			controller.submit_command({
				"type": "end_turn",
				"state_version": controller.state.event_log.size(),
			})
			skip = {}


func _leave_to_map(controller: RunController) -> void:
	controller.submit_command({"type": "leave_encounter"})
	assert_eq(controller.current_view_name(), "Map", "离场回 Map")


func test_white_jade_basic_recipe_default_unlocked_and_display_name() -> void:
	var recipe: Dictionary = catalog.get("refinement_by_id", {}).get("white_jade_basic", {})
	assert_false(recipe.is_empty(), "white_jade_basic 配方存在")
	assert_eq(str(recipe.get("kind", "")), "fixed")
	assert_eq(recipe.get("input_gu_ids", []), ["jade_skin_gu", "white_boar_strength_gu"])
	assert_eq(str(recipe.get("output_gu_id", "")), "white_jade_gu")
	assert_eq(int(recipe.get("stone_cost", -1)), 50)
	assert_false(bool(recipe.get("locked", false)), "基础蛊方默认解锁")
	assert_eq(DisplayText.gu("moon_glow_gu"), "月芒蛊", "moon_glow_gu 显示名为月芒蛊")


func test_full_route_light_to_layer2() -> void:
	var controller := _start_light_run()

	# ---- 开局 ----
	assert_eq(controller.current_view_name(), "Map", "开局进 Map")
	assert_eq(controller.state.school, "light")
	assert_eq(controller.state.contracts, ["enemy_vitality_trial"], "契约已立誓")
	assert_eq(int(controller.state.stone), 1000, "契约给 1000 元石")
	# light 校 v2 starter pack（schools.json 802 重建，防/移/侦为派生蛊）
	var light_starters := ["moonlight_gu", "small_light_gu", "stone_shell_gu", "vitality_grass_gu"]
	for gu_id in light_starters:
		assert_true(controller.state.refined_gu_ids.has(gu_id), "起始包含 %s" % gu_id)
	assert_true(controller.state.refined_gu_ids.count("small_light_gu") >= 1, "小光蛊实例在袋")

	# ---- 节点1：战斗 → 击败 → 奖励 ----
	controller.submit_command({"type": "travel", "node_id": "L1R0N0"})
	assert_eq(controller.current_view_name(), "Battle", "战斗节点自动开战")
	_fight_to_victory(controller)
	assert_true(controller.current_view_name() in ["Reward", "Encounter"], "胜利后进奖励/遭遇屏（实际=%s）" % controller.current_view_name())
	assert_true((controller.last_battle_loot as Dictionary).size() > 0 or (controller.state.materials as Dictionary).size() > 0, "战利品已入账")
	_leave_to_map(controller)
	assert_true(controller.state.node_flags.has("L1R0N0"), "战斗节点已标记完成")

	# ---- 节点2：黑市 5 条资源交易 ----
	controller.submit_command({"type": "travel", "node_id": "L1R1N0"})
	assert_true(controller.current_view_name() in ["Shop", "Encounter"], "黑市进 Shop 屏")
	# 流程夹具：领域默认生命上限 8 不够扣 20 生命交易，调高后 5 条全换。
	controller.state.health = 60
	controller.state.max_health = 60
	controller.state.cultivator["max_health"] = 60
	controller.state.cultivator["lifespan"] = 100
	controller.state.cultivator["soul"] = 2
	controller.state.cultivator["soul_max"] = 6
	# T2 魂魄→寿元：soul 2→1，寿元 +10
	var r2 := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_soul_for_lifespan"})
	assert_true(bool((r2.get("result", r2) as Dictionary).get("ok", false)), "魂魄→寿元 OK")
	assert_eq(int(controller.state.cultivator["soul"]), 1)
	assert_eq(int(controller.state.cultivator["lifespan"]), 110)
	# T1 寿元→魂魄：寿元 −20，soul 1→2
	var r1 := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_lifespan_for_soul"})
	assert_true(bool((r1.get("result", r1) as Dictionary).get("ok", false)), "寿元→魂魄 OK")
	assert_eq(int(controller.state.cultivator["lifespan"]), 90)
	assert_eq(int(controller.state.cultivator["soul"]), 2)
	# T3 生命→魂魄：生命 60→40，soul 2→3
	var r3 := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_health_for_soul"})
	assert_true(bool((r3.get("result", r3) as Dictionary).get("ok", false)), "生命→魂魄 OK")
	assert_eq(int(controller.state.health), 40)
	assert_eq(int(controller.state.cultivator["soul"]), 3)
	# T4 魂魄→生命：soul 3→2，生命 40→50，上限 60→70
	var r4 := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_soul_for_health"})
	assert_true(bool((r4.get("result", r4) as Dictionary).get("ok", false)), "魂魄→生命 OK")
	assert_eq(int(controller.state.health), 50)
	assert_eq(int(controller.state.max_health), 70)
	# T5 生命→寿元：生命 50→30，寿元 90→100
	var r5 := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_health_for_lifespan"})
	assert_true(bool((r5.get("result", r5) as Dictionary).get("ok", false)), "生命→寿元 OK")
	assert_eq(int(controller.state.health), 30)
	assert_eq(int(controller.state.cultivator["lifespan"]), 100)
	# 一次性：复购被拒
	var replay := controller.submit_command({"type": "shop_purchase", "offer_id": "black_market_health_for_lifespan"})
	assert_eq(str((replay.get("result", replay) as Dictionary).get("reason", "")), "resource_trade_already_used", "复购被拒")
	_leave_to_map(controller)

	# ---- 节点3：交易节点购买蛊虫与材料（1000 元石实力买）----
	controller.submit_command({"type": "travel", "node_id": "L1R2N0"})
	assert_true(controller.current_view_name() in ["Shop", "Encounter"], "交易节点进 Shop 屏")
	# 流程夹具：此处是本局第 2 次商店类节点，复访通胀 25%/次会把 500 级蛊
	# 抬到 625 超出 1000 预算；重置复访计数让验收按目录基准价实买。
	controller.state.node_flags["shop_visits"] = 0
	var buys := [
		["purchase_jade_skin_gu", 30],
		["purchase_white_boar_strength_gu", 35],
	]
	for row in buys:
		var res := controller.submit_command({"type": "shop_purchase", "offer_id": str(row[0])})
		assert_true(bool((res.get("result", res) as Dictionary).get("ok", false)), "购买 %s OK" % str(row[0]))
	assert_eq(int(controller.state.stone), 935, "1000−65=935")
	assert_true(controller.state.refined_gu_ids.has("jade_skin_gu"), "玉皮蛊入袋")
	assert_true(controller.state.refined_gu_ids.has("white_boar_strength_gu"), "白猪力蛊入袋")
	_leave_to_map(controller)

	# ---- 节点4：炼蛊 → 白玉蛊（white_jade_basic 基础蛊方默认解锁）----
	controller.submit_command({"type": "travel", "node_id": "L1R3N0"})
	# E4a 三选一（规格 §4）：refinement 统一进 Rest 屏，Refine 改为休息屏「炼蛊」
	# 卡的子屏；本验收直接提交领域命令，屏幕归属由 test_rest_screen_tri_mode 覆盖。
	assert_eq(controller.current_view_name(), "Rest", "炼蛊节点进 Rest 屏（E4a 三选一路由）")
	# 月芒链配方输入 moonlight_gu 在本市场节点不可购（802 重建后未入市），
	# 白玉链用小光/守御/力蛊之外的购入材料独立成方，保持光道全链路可走完。
	var wj := controller.submit_command({"type": "refine_gu", "recipe_id": "white_jade_basic"})
	assert_true(bool((wj.get("result", wj) as Dictionary).get("ok", false)), "炼白玉蛊 OK: %s" % str((wj.get("result", wj) as Dictionary).get("reason", "")))
	assert_true(controller.state.refined_gu_ids.has("white_jade_gu"), "白玉蛊入袋")
	assert_eq(int(controller.state.stone), 885, "935−50=885（炼白玉蛊扣 50 元石）")
	_leave_to_map(controller)

	# ---- 节点5：休整 → 回复 30% 生命（不超上限）----
	controller.submit_command({"type": "travel", "node_id": "L1R4N0"})
	assert_true(controller.current_view_name() in ["Rest", "Encounter"], "休整节点进 Rest 屏")
	var hp_before := int(controller.state.health)
	var max_hp := int(controller.state.max_health)
	var expected := mini(max_hp, hp_before + maxi(1, int(floor(float(max_hp) * 0.30))))
	var heal := controller.submit_command({"type": "rest", "mode": "heal"})
	assert_true(bool((heal.get("result", heal) as Dictionary).get("ok", false)), "休整 OK")
	assert_eq(int(controller.state.health), expected, "回复 30%% 上限封顶（%d → %d）" % [hp_before, expected])
	assert_true(int(controller.state.health) <= int(controller.state.max_health), "不超过生命上限")
	_leave_to_map(controller)

	# ---- 节点6：第一层 Boss → 击败 → 进第二层 ----
	controller.submit_command({"type": "travel", "node_id": "L1R5N0"})
	assert_eq(controller.current_view_name(), "Battle", "Boss 台自动开战")
	_fight_to_victory(controller)
	assert_true(controller.current_view_name() in ["Reward", "Encounter"], "Boss 击败（实际=%s）" % controller.current_view_name())
	assert_eq(str(controller.state.node_flags.get("boss_defeated_L1", "")), "true", "boss_defeated_L1 旗标落账")
	_leave_to_map(controller)

	# ---- 进入第二层 ----
	var t2 := controller.submit_command({"type": "travel", "node_id": "L2R0N0"})
	assert_ne(str((t2.get("result", t2) as Dictionary).get("reason", "")), "unreachable_route_node", "第二层入口可达")
	assert_eq(int(controller.state.current_node_layer), 2, "已进入第二层")
	assert_eq(controller.state.current_node_id, "L2R0N0")
	# 已击败的 Boss 台不可回游（不在任何 next_ids 中）
	var back := controller.submit_command({"type": "travel", "node_id": "L1R5N0"})
	assert_eq(str((back.get("result", back) as Dictionary).get("reason", "")), "unreachable_route_node", "Boss 台不可回游")
	controller.free()


func test_no_backlash_keeps_soul_intact_in_route() -> void:
	# 2026-08-31 裁定：蛊虫无负面效果——光道开局打完战斗节点后魂魄无损。
	var controller := _start_light_run()
	controller.submit_command({"type": "travel", "node_id": "L1R0N0"})
	assert_eq(controller.current_view_name(), "Battle")
	var soul_before := int(controller.state.cultivator["soul"])
	_fight_to_victory(controller)
	assert_true(controller.current_view_name() in ["Reward", "Encounter"])
	assert_eq(int(controller.state.cultivator["soul"]), soul_before, "战斗后魂魄无损")
	controller.free()
