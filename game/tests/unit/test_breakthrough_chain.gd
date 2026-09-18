extends GutTest

## 一转一突破（2026-09-15 用户裁定：聚焦剑道、打造局内成长空间）。
##
## 为什么需要：`aptitude.json.cultivation_factor = {1:1, 2:3, 3:9, 4:27, 5:81}` 与
## `pacing.layers[N].enemy_rank_max = 1..5` **早已把 1→5 的成长曲线设计完**，
## 但领域只实现了硬编码的二转（且 `>= 2` 直接拒绝）⇒ 转数永久封顶 2 转。
## 门禁 `can_activate(cultivation >= gu_rank)` 于是让全库 52% 的蛊（rank ≥3）
## 永远无法催动——剑道 40 只蛊里 20 只是死内容。
##
## 本单钉住：逐档推进 / 不可跳档 / 不可越上限 / 元石门槛 / 真元上限按档 ×3 /
## 休整探访一次只取一份收益 / 剑道高转蛊随转数真正可用。

const RefineCommandRules := preload("res://scripts/domain/refine_command_rules.gd")
const CultivatorRules := preload("res://scripts/domain/cultivator_rules.gd")

const REST_NODE := "rest_shrine"


func _catalog() -> Dictionary:
	return ContentCatalog.load_all()


func _state_with(rank: int, stone: int, node_id: String = "L1R4N0") -> RunState:
	var state := RunState.new_run(20260915)
	# 实例 id 每档不同（模拟逐层的不同休整点），模板 id 指向休整模板以过类别门。
	state.current_node_id = node_id
	state.current_node_template_id = REST_NODE
	state.cultivation = rank
	state.stone = stone
	return state


func _walk_one_rank(state: RunState, catalog: Dictionary, layer: int) -> Dictionary:
	state.current_node_id = "L%dR4N0" % layer
	state.current_node_template_id = REST_NODE
	return _breakthrough(state, catalog)


func _breakthrough(state: RunState, catalog: Dictionary, target: int = 0) -> Dictionary:
	var command := {"type": "breakthrough"}
	if target > 0:
		command["target_rank"] = target
	return Resolver.apply(state, command, catalog)


# ---------- 成本表 ----------

func test_cost_table_is_data_driven_and_escalating() -> void:
	var catalog := _catalog()
	var costs: Array[int] = []
	for rank in range(2, RefineCommandRules.MAX_CULTIVATION + 1):
		costs.append(RefineCommandRules.cultivate_stone_cost(catalog, rank))
	assert_eq(costs, [5, 12, 20, 30] as Array[int],
			"四档成本必须全部来自 balance.json 且逐档递增；实际 %s" % str(costs))
	assert_eq(RefineCommandRules.cultivate_stone_cost(catalog, 1), 0, "一转不是突破目标")
	assert_eq(RefineCommandRules.cultivate_stone_cost(catalog, 6), 0, "越界档位无成本")


func test_cultivation_labels_cover_all_five_ranks() -> void:
	assert_eq(RefineCommandRules.cultivation_label(1), "一转")
	assert_eq(RefineCommandRules.cultivation_label(5), "五转")
	assert_eq(RefineCommandRules.cultivation_label(9), "9 转", "越界回退不得崩溃")


# ---------- 逐档推进 ----------

func test_breakthrough_walks_rank_one_to_five() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 100)
	var seen: Array[int] = []
	for expected in range(2, RefineCommandRules.MAX_CULTIVATION + 1):
		# 每次突破都在**不同的休整点**（模拟逐层推进），否则会被探访门拦下。
		var resolved := _walk_one_rank(state, catalog, expected)
		assert_true(bool(resolved["result"].get("ok", false)),
				"一转 → %d 转必须成立（%s）" % [expected, str(resolved["result"])])
		state = resolved["state"]
		seen.append(int(state.cultivation))
	assert_eq(seen, [2, 3, 4, 5] as Array[int], "必须逐档走到五转")


func test_default_target_is_current_plus_one() -> void:
	var catalog := _catalog()
	var state := _state_with(3, 100)
	var resolved := _breakthrough(state, catalog)
	assert_eq(int(resolved["state"].cultivation), 4, "缺省目标 = 当前 + 1（UI 不需知道档位公式）")


func test_skipping_a_rank_is_rejected() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 100)
	var resolved := _breakthrough(state, catalog, 3)
	assert_false(bool(resolved["result"].get("ok", false)), "不可越级突破")
	assert_eq(str(resolved["result"].get("reason", "")), "cultivation_step_too_far")
	assert_eq(int(resolved["state"].cultivation), 1, "被拒不得改变转数")


func test_cultivation_is_capped_at_five() -> void:
	var catalog := _catalog()
	var state := _state_with(5, 999)
	var resolved := _breakthrough(state, catalog)
	assert_false(bool(resolved["result"].get("ok", false)), "五转是境内上限")
	assert_eq(str(resolved["result"].get("reason", "")), "cultivation_already_max")


func test_stone_gate_matches_the_target_rank() -> void:
	var catalog := _catalog()
	# 三转成本 12：11 枚不足，12 枚刚好。
	var poor := _breakthrough(_state_with(2, 11), catalog)
	assert_false(bool(poor["result"].get("ok", false)), "元石不足须拒绝")
	assert_eq(str(poor["result"].get("reason", "")), "insufficient_stone")
	var exact := _breakthrough(_state_with(2, 12), catalog)
	assert_true(bool(exact["result"].get("ok", false)), "刚好够即成立")
	assert_eq(int(exact["state"].stone), 0, "成本必须真实结算，不得无来源补齐")
	assert_eq(int(exact["state"].cultivation), 3)


func test_breakthrough_requires_a_rest_class_node() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 100)
	state.current_node_id = "toxic_mountain_path"
	state.current_node_template_id = "toxic_mountain_path"
	var resolved := _breakthrough(state, catalog)
	assert_false(bool(resolved["result"].get("ok", false)), "非休息类节点不得突破")
	assert_eq(str(resolved["result"].get("reason", "")), "not_cultivation_window")


# ---------- 真元上限按档 ×3（aptitude.json 既有曲线） ----------

func test_essence_capacity_follows_the_three_fold_curve() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 9_999)
	var caps: Array[int] = []
	for layer in range(2, 6):
		state = _walk_one_rank(state, catalog, layer)["state"]
		caps.append(int(state.cave_aperture.get("essence_max", 0)))
	assert_eq(caps.size(), 4, "四档上限")
	# cultivation_factor 1/3/9/27/81 ⇒ 2 转起每档 ×3。
	assert_eq(caps[1], caps[0] * 3, "三转上限 = 二转 ×3")
	assert_eq(caps[2], caps[1] * 3, "四转上限 = 三转 ×3")
	assert_eq(caps[3], caps[2] * 3, "五转上限 = 四转 ×3")


func test_essence_capacity_never_shrinks() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 9_999)
	state.current_node_id = REST_NODE
	state.cave_aperture["essence_max"] = 999_999
	var resolved := _breakthrough(state, catalog)
	assert_true(bool(resolved["result"].get("ok", false)))
	assert_eq(int(resolved["state"].cave_aperture.get("essence_max", 0)), 999_999,
			"已有更高上限不得被突破拉低（maxi 语义）")


# ---------- 每次突破消费一次休整探访 ----------

func test_breakthrough_consumes_the_rest_visit() -> void:
	var catalog := _catalog()
	var state := _state_with(1, 100)
	var first := _breakthrough(state, catalog)
	assert_true(bool(first["result"].get("ok", false)))
	var second := _breakthrough(first["state"], catalog)
	assert_false(bool(second["result"].get("ok", false)),
			"一次探访只取一份收益：连续突破必须被休整门拦下")


# ---------- 剑道：转数成长让高转蛊真正可用 ----------

func test_sword_high_rank_gu_becomes_activatable_with_cultivation() -> void:
	var catalog := _catalog()
	# 剑道 5 转蛊（真实数据）：二转时门禁拒，五转时放行。
	var sword_id := "sword_atk_5_02_gu"
	assert_true((catalog.get("gu_by_id", {}) as Dictionary).has(sword_id),
			"剑道五转蛊必须存在于 data/gu.json")
	var rank := int((catalog["gu_by_id"][sword_id] as Dictionary).get("rank", 1))
	assert_eq(rank, 5, "该蛊定义转数应为 5")
	assert_false(CultivatorRules.can_activate(2, rank), "二转蛊师不得催动五转蛊")
	assert_true(CultivatorRules.can_activate(5, rank), "五转蛊师可催动五转蛊")


func test_legacy_rank_two_command_still_works() -> void:
	# 旧命令名保留（旧存档 / 既有领域命令面）：等价于目标二转。
	var catalog := _catalog()
	var state := _state_with(1, 100)
	var resolved := Resolver.apply(state, {"type": "cultivate_rank_two"}, catalog)
	assert_true(bool(resolved["result"].get("ok", false)), "cultivate_rank_two 必须继续可用")
	assert_eq(int(resolved["state"].cultivation), 2)
