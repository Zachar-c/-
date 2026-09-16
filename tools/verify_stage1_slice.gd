extends SceneTree

## Stage 1 纵向切片验收探针（2026-09-16）。
##
## 规格：docs/superpowers/specs/2026-09-16-stage1-gu-entity-vertical-slice-design.md
## 目的：把「蛊是独立生命实体」从 Stage 0 裁定落到可复现的验收条：
##   Gate A 目录完备度（12 只切片蛊）
##   Gate B 固定 seed 路线拓扑
##   Gate C 身份夹具 + 未炼化门禁
##   Gate D 炼成场景（月光固定方 + 一次盲炼失败）
##   Gate E 货郎场景（报价 / 结算 / 门禁）
##   Gate F 确定性（同 seed 复跑同结果）
##
## 纪律：
##   - 判定全部走**真实领域规则**（Resolver.apply / V1BattleResolver / MapGenerator），
##     不伪造状态、不重抽随机、不绕过门禁；
##   - 只有「开局身份」这一项在现役领域里没有对应命令，因此用**夹具注入**，
##     且注入同样写不可变事件日志（reason = stage1_background_injected）；
##   - 断言基于真实事件日志与真实库存变化。
##
## 用法：godot --headless --path . -s tools/verify_stage1_slice.gd
##       STAGE1_SEED=<int> 覆盖固定 seed（默认取预登记列表内第一个满足 L1 含炼蛊台的 seed）

const SLICE_GU: Array[String] = [
	"moonlight_gu",
	"small_light_gu",
	"moon_glow_gu",
	"moon_ray_gu",
	"moon_shadow_gu",
	"force_gu",
	"bear_strength_gu",
	"blood_droplet_gu",
	"blood_farewell_gu",
	"blood_def_1_21_gu",
	"blood_mov_1_22_gu",
	"sword_atk_1_05_gu",
]

const SLICE_ENEMIES: Array[String] = ["ridge_hound", "mountain_boar", "straw_puppet"]

const MOON_FIXED_RECIPE := "moon_glow_fixed"
const FREE_MIX_RECIPE := "free_mix"
const MOONLIGHT_GU := "moonlight_gu"
const SMALL_LIGHT_GU := "small_light_gu"
const MOON_GLOW_GU := "moon_glow_gu"
const PEDDLER_NODE_ID := "wandering_peddler"
const PEDDLER_NPC_ID := "wandering_peddler"
## 货郎货架上 tier 1（L1 可买）的那一档；purchase_moonlight 是 tier 3，见 Gate E 的 GAP。
const PEDDLER_OFFER_ID := "purchase_stone_shell"
## 设计 §6 的「元石买血滴蛊」在现役数据里挂在商队报价，不在货郎货架。
const CARAVAN_DROPLET_OFFER := "buy_droplet"
const BLOOD_DROPLET_GU := "blood_droplet_gu"
const BACKGROUND_ID := "background_nanjiang_wanderer"

## 夹具专用「未炼化」状态字。现役领域的实例状态词表只有
## refined / contracted / weakened（RunState.refined_instances），
## **没有**「未炼化」态 —— 这本身是切片要暴露的缺口（见 Gate C 的 GAP 输出）。
const UNREFINED_STATE := "unrefined"

## 预登记 seed 列表（不是事后挑选）：从表头开始取第一个「L1 含炼蛊台 **且** 含货郎节点」的 seed
## （剧本第 5/6 步都在 L1 内）；无同时命中者退化为只要求炼蛊台，货郎缺口由 Gate B 报出。
const SEED_CANDIDATES: Array[int] = [101, 202, 303, 404, 505, 606, 707, 808, 909, 1111,
		1212, 1313, 1414, 1515, 1616, 1717, 1818, 1919, 2020, 2121]

var _catalog: Dictionary = {}
var _failed := 0
var _checks := 0
var _gaps: Array[String] = []
var _seed_used := 0


func _initialize() -> void:
	print("===== Stage 1 纵向切片验收（蛊虫实体） =====")
	var loaded: Dictionary = ContentCatalog.load_and_validate_all()
	_catalog = loaded.get("catalog", {})
	var errors: Array = loaded.get("errors", [])
	_gate_a(errors)
	_seed_used = _pick_seed()
	if _seed_used == 0:
		print("RESULT: FAIL（预登记 seed 列表内无一局的 L1 含炼蛊台）")
		quit(1)
		return
	print("固定 seed = %d" % _seed_used)
	var signature_1 := _gate_b(_seed_used) + _gate_c(_seed_used) + _gate_d(_seed_used) + _gate_e(_seed_used)
	await _gate_c_run(_seed_used)
	var signature_2 := _gate_b(_seed_used) + _gate_c(_seed_used) + _gate_d(_seed_used) + _gate_e(_seed_used)
	_gate_f(signature_1, signature_2)
	print("")
	print("===== summary =====")
	print("checks=%d failed=%d gaps=%d" % [_checks, _failed, _gaps.size()])
	if not _gaps.is_empty():
		print("---- 已知缺口（不阻断，需裁定后才修） ----")
		for line in _gaps:
			print("  [GAP] %s" % line)
	if _failed > 0:
		print("RESULT: FAIL")
		quit(1)
		return
	print("RESULT: PASS")
	quit(0)


# ---------------------------------------------------------------- Gate A

func _gate_a(errors: Array) -> void:
	print("")
	print("----- Gate A：切片目录完备度（12 只） -----")
	_check("catalog 全量校验无错误", errors.is_empty(), str(errors.size()) + " 条")
	for line in errors:
		print("      %s" % str(line))
	var gu_by_id: Dictionary = _catalog.get("gu_by_id", {})
	for gu_id in SLICE_GU:
		var definition: Dictionary = gu_by_id.get(gu_id, {})
		_check("切片蛊在目录中：%s" % gu_id, not definition.is_empty(), "")
		if definition.is_empty():
			continue
		if gu_id == "moon_shadow_gu":
			# 本切片剧本可不出现月影；若已显式化则必须是 shift。
			var shadow: Variant = definition.get("v1_effect")
			if shadow != null:
				_check("moon_shadow_gu 若显式化必须是 shift",
						str((shadow as Dictionary).get("kind", "")) == "shift", str(shadow))
			continue
		var effect: Variant = definition.get("v1_effect")
		_check("%s 有显式 v1_effect（禁止 role 兜底）" % gu_id, effect is Dictionary, str(effect))
		_check("%s 有 feeding_need" % gu_id, definition.get("feeding_need") is Dictionary, "")
		_check("%s 有 feeding_cost" % gu_id, int(definition.get("feeding_cost", -1)) >= 1,
				str(definition.get("feeding_cost", "")))
	var recipe: Dictionary = _catalog.get("refinement_by_id", {}).get(MOON_FIXED_RECIPE, {})
	_check("月光固定方仍在：%s" % MOON_FIXED_RECIPE, not recipe.is_empty(), str(recipe.get("output_gu_id", "")))
	_check("月光固定方默认可知", bool(recipe.get("default_unlocked", false)), "")
	var expected_inputs: Array[String] = ["moonlight_gu", "small_light_gu", "small_light_gu"]
	var actual_inputs: Array[String] = []
	for input_value in recipe.get("input_gu_ids", []):
		actual_inputs.append(str(input_value))
	_check("月光固定方输入契约不变", actual_inputs == expected_inputs, str(actual_inputs))


# ---------------------------------------------------------------- Gate B

## 从预登记列表里挑第一个「L1 内存在炼蛊台（refinement）」的 seed。
func _pick_seed() -> int:
	var override := OS.get_environment("STAGE1_SEED")
	if not override.is_empty():
		return int(override)
	for candidate in SEED_CANDIDATES:
		var route: Array = MapGenerator.build(candidate, false, _catalog)
		if _count_type(route, 1, "refinement") > 0 and _l1_has_peddler(route):
			return candidate
	for fallback in SEED_CANDIDATES:
		var route2: Array = MapGenerator.build(fallback, false, _catalog)
		if _count_type(route2, 1, "refinement") > 0:
			return fallback
	return 0


## L1 内是否存在货郎节点（剧本第 6 步：元石买血滴蛊 / 卖山货）。
func _l1_has_peddler(route: Array) -> bool:
	for node_value in route:
		var node: Dictionary = node_value
		if _coords(str(node.get("id", ""))).x != 1:
			continue
		if str(node.get("npc_id", "")) == PEDDLER_NPC_ID:
			return true
	return false


func _gate_b(seed_value: int) -> String:
	print("")
	print("----- Gate B：固定 seed 路线拓扑（seed=%d） -----" % seed_value)
	var route: Array = MapGenerator.build(seed_value, false, _catalog)
	_check("路线非空", route.size() > 0, "%d 个节点" % route.size())

	# 按层分组 + 行数。
	var rows_by_layer: Dictionary = {}
	var starts: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		var coords := _coords(str(node.get("id", "")))
		if coords.x <= 0:
			continue  # ascension_window 等无坐标节点
		var layer_key := str(coords.x)
		if not rows_by_layer.has(layer_key):
			rows_by_layer[layer_key] = {}
		(rows_by_layer[layer_key] as Dictionary)[str(coords.y)] = \
				int((rows_by_layer[layer_key] as Dictionary).get(str(coords.y), 0)) + 1
		if bool(node.get("start", false)):
			starts.append(str(node.get("id", "")))
	# 起点数由 pacing.entry_nodes（1..2）决定，不是恒为 1；双入口是合法拓扑。
	_check("起点数在 1..2 之间（pacing entry_nodes）", starts.size() >= 1 and starts.size() <= 2, str(starts))
	_check("五大层齐全", rows_by_layer.size() == 5, "%d 层" % rows_by_layer.size())

	var shape_parts: Array[String] = []
	for layer_number in range(1, 6):
		var rows: Dictionary = rows_by_layer.get(str(layer_number), {})
		var row_count := rows.size()
		shape_parts.append("L%d:%d行" % [layer_number, row_count])
		_check("L%d 行数在 8–11 之间" % layer_number, row_count >= 8 and row_count <= 11, "%d 行" % row_count)
		var last_row: int = rows.get(str(row_count - 1), 0)
		_check("L%d 末行单节点（关底台）" % layer_number, last_row == 1, "%d 个" % last_row)
	print("  层形状：%s" % ", ".join(shape_parts))

	# 连边：无后向边 + 非首行每节点 ≥1 入边。
	var by_id: Dictionary = {}
	for node_value in route:
		var node: Dictionary = node_value
		by_id[str(node.get("id", ""))] = node
	var in_degree: Dictionary = {}
	var backward: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		var source := _coords(str(node.get("id", "")))
		if source.x <= 0:
			continue
		for next_value in node.get("next_ids", []):
			var next_id := str(next_value)
			in_degree[next_id] = int(in_degree.get(next_id, 0)) + 1
			var target := _coords(next_id)
			if target.x <= 0:
				continue
			if target.x < source.x or (target.x == source.x and target.y <= source.y):
				backward.append("%s->%s" % [str(node.get("id", "")), next_id])
	_check("无后向边（DAG，不可回溯）", backward.is_empty(), str(backward))
	var orphans: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		var coords := _coords(str(node.get("id", "")))
		if coords.x <= 0 or coords.y == 0:
			continue
		if int(in_degree.get(str(node.get("id", "")), 0)) < 1:
			orphans.append(str(node.get("id", "")))
	_check("非首行每节点 ≥1 入边（无孤岛）", orphans.is_empty(), str(orphans))

	# L1 剧本可达性：从起点走到 L1 关底台需要几步（只在本层内走，不跨层）。
	var longest := _longest_path(route, by_id, starts[0] if not starts.is_empty() else "", 1)
	_check("L1 从起点到关底的步数在 7–10 之间", longest >= 7 and longest <= 10, "%d 步" % longest)
	print("  L1 剧本长度：起点 → 关底 %d 步" % longest)

	# 切片剧本第 5 步（炼蛊台）必须在 L1 可达。
	var refine_count := _count_type(route, 1, "refinement")
	_check("L1 存在炼蛊台节点（剧本第 5 步可达）", refine_count > 0, "%d 个" % refine_count)
	var contact_count := _count_type(route, 1, "contact")
	var peddler_in_l1 := false
	for node_value in route:
		var node: Dictionary = node_value
		if _coords(str(node.get("id", ""))).x != 1:
			continue
		if str(node.get("npc_id", "")) == PEDDLER_NPC_ID:
			peddler_in_l1 = true
			break
	print("  L1 节点类型：%s" % _type_histogram(route, 1))
	print("  L1 含货郎节点：%s（contact 节点 %d 个）" % [str(peddler_in_l1), contact_count])
	if not peddler_in_l1:
		_gap("L1 未出现 %s 节点（剧本第 6 步）；Gate E 用节点模板 id 直接钉场景" % PEDDLER_NODE_ID)

	# 切片敌人是否出现在 L1 的战斗抽取里。
	var rolled: Dictionary = {}
	for node_value in route:
		var node: Dictionary = node_value
		if _coords(str(node.get("id", ""))).x != 1:
			continue
		for enemy_value in node.get("enemy_roll", []):
			rolled[str(enemy_value)] = int(rolled.get(str(enemy_value), 0)) + 1
	var present: Array[String] = []
	for enemy_id in SLICE_ENEMIES:
		if rolled.has(enemy_id):
			present.append("%s×%d" % [enemy_id, int(rolled[enemy_id])])
	print("  L1 抽取到的切片敌人：%s" % (", ".join(present) if not present.is_empty() else "(无)"))
	if present.is_empty():
		_gap("L1 的 enemy_roll 未抽到切片三敌（%s）；战斗断言改用目录定义直接装配" % ", ".join(SLICE_ENEMIES))

	return "B|%d|%d|%s" % [route.size(), longest, _type_histogram(route, 1)]


# ---------------------------------------------------------------- Gate C

func _gate_c(seed_value: int) -> String:
	print("")
	print("----- Gate C：身份夹具（南疆边地散修）+ 未炼化门禁 -----")
	var state := _build_background(seed_value, false)
	var stored: Array = state.cave_aperture.get("stored_gu_instance_ids", [])
	_check("开局持有 3 只蛊（月光 + 小光×2）", stored.size() == 3, "%d 只" % stored.size())

	var moon_ids: Array[String] = []
	var small_ids: Array[String] = []
	for instance_id_value in stored:
		var instance_id := str(instance_id_value)
		var instance: Dictionary = state.gu_instances.get(instance_id, {})
		match str(instance.get("definition_id", "")):
			MOONLIGHT_GU:
				moon_ids.append(instance_id)
			SMALL_LIGHT_GU:
				small_ids.append(instance_id)
	_check("本命月光蛊已炼化（1 只）", moon_ids.size() == 1, str(moon_ids))
	_check("小光蛊 ×2 未炼化", small_ids.size() == 2, str(small_ids))
	for instance_id in moon_ids:
		_check("月光实例状态为 refined",
				str(state.gu_instances.get(instance_id, {}).get("state", "")) == "refined", instance_id)
	for instance_id in small_ids:
		_check("小光实例状态为未炼化（%s）" % UNREFINED_STATE,
				str(state.gu_instances.get(instance_id, {}).get("state", "")) == UNREFINED_STATE, instance_id)
	_check("注入写进了不可变事件日志", _has_event(state, "stage1_background_injected"),
			"%d 条事件" % state.event_log.size())
	_check("旧开局流派四件套已被夹具替换（不给流派 starter）",
			not _owns_definition(state, "force_gu") and not _owns_definition(state, "blood_droplet_gu"),
			str(state.refined_gu_ids))

	# 未炼化蛊不得被当作已炼化催动：战斗槽只收 refined_instances()。
	var battle: Dictionary = V1BattleResolver.start(state, _catalog, [_enemy_payload("ridge_hound")])
	var slot_ids: Array[String] = []
	for slot_value in battle.get("gu_slots", []):
		slot_ids.append(str((slot_value as Dictionary).get("instance_id", "")))
	_check("月光蛊进战斗槽（已炼化可催动）", slot_ids.has(moon_ids[0]) if moon_ids.size() == 1 else false,
			str(slot_ids))
	var leaked: Array[String] = []
	for instance_id in small_ids:
		if slot_ids.has(instance_id):
			leaked.append(instance_id)
	_check("未炼化小光蛊不进战斗槽（不能被催动）", leaked.is_empty(), str(leaked))

	if not _has_unrefined_transition():
		_gap("现役领域没有「未炼化 → 已炼化」的炼化命令；剧本第 5 步（未炼化小光作原料）在现役规则下不可执行，夹具用已炼化实例代跑")
	return "C|%d|%s|%s" % [stored.size(), str(slot_ids), str(leaked)]


## 真实开局通路（证明清理 role 兜底后游戏仍能开局）：走 controller 的
## start_new_run —— 这是 UI 的唯一入口，不是领域夹具。
func _gate_c_run(seed_value: int) -> void:
	print("")
	print("----- Gate C-0：真实开局（controller） -----")
	var controller = await _new_controller()
	controller.start_new_run(seed_value, "force")
	await process_frame
	_check("真实开局进入 Map 屏", controller.current_view_name() == "Map", controller.current_view_name())
	var content_errors: Array = controller.get("_content_errors")
	_check("真实开局无内容校验错误", content_errors.is_empty(), str(content_errors.size()) + " 条")
	_check("真实开局持有蛊实例", (controller.state.gu_instances as Dictionary).size() > 0,
			"%d 只" % (controller.state.gu_instances as Dictionary).size())
	controller.free()


## 现役命令面里是否存在「炼化未炼化蛊」的入口。
## 判定口径：resolver 的命令表里没有 refine/炼化类动词（只有 refine_gu 合炼、
## feed_instance 喂养、release_gu 放生），故此处恒为 false —— 缺口留档用。
func _has_unrefined_transition() -> bool:
	var command_types: Array[String] = ["tame_gu", "refine_unrefined", "bind_gu", "claim_gu"]
	for command_type in command_types:
		if Resolver._handler_for(command_type) != null:
			return true
	return false


# ---------------------------------------------------------------- Gate D

func _gate_d(seed_value: int) -> String:
	print("")
	print("----- Gate D：炼成场景（月光固定方 + 一次盲炼失败） -----")
	# D0：容量门禁先自证（魂魄 1 ⇒ craft_cap=2 < 3 只输入）。
	var capped := _build_background(seed_value, true, 1)
	var capped_result: Dictionary = Resolver.apply(capped, {
		"type": "refine_gu",
		"recipe_id": MOON_FIXED_RECIPE,
	}, _catalog)
	_check("魂魄 1 时三蛊合炼被拒（refinement_capacity_exceeded）",
			str(capped_result.get("result", {}).get("reason", "")) == "refinement_capacity_exceeded",
			str(capped_result.get("result", {}).get("reason", "")))
	_check("被拒时不烧输入（3 只仍在蛊仓）",
			(capped_result.get("state", capped).cave_aperture.get("stored_gu_instance_ids", []) as Array).size() == 3, "")

	# D1：夹具补到魂魄 3（craft_cap=3）后走成功路径。
	var state := _build_background(seed_value, true, 3)
	var input_ids: Array[String] = []
	for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
		input_ids.append(str(instance_id_value))
	_check("炼蛊台夹具：3 只输入均已炼化", input_ids.size() == 3, "%d 只" % input_ids.size())
	var before_events := state.event_log.size()

	# --- 成功路径：月光固定方 ---
	var result: Dictionary = Resolver.apply(state, {
		"type": "refine_gu",
		"recipe_id": MOON_FIXED_RECIPE,
	}, _catalog)
	_check("月光固定方命令被领域接受", bool(result.get("result", {}).get("ok", false)),
			str(result.get("result", {}).get("reason", "")))
	if not bool(result.get("result", {}).get("ok", false)):
		return "D|rejected"
	state = result.get("state", state)
	var consumed_ok := true
	for instance_id in input_ids:
		var instance: Dictionary = state.gu_instances.get(instance_id, {})
		var is_consumed := str(instance.get("state", "")) == "consumed"
		var removed := not (state.cave_aperture.get("stored_gu_instance_ids", []) as Array).has(instance_id)
		if not (is_consumed and removed):
			consumed_ok = false
	_check("3 只输入蛊被真实消耗（state=consumed 且移出蛊仓）", consumed_ok, str(input_ids))
	_check("产出月芒蛊进入蛊仓（已炼化）", _owns_definition(state, MOON_GLOW_GU), MOON_GLOW_GU)
	_check("炼成写入事件日志（refinement_succeeded）", _has_event(state, "refinement_succeeded"),
			"%d → %d 条" % [before_events, state.event_log.size()])
	var recipe_tagged := false
	for event_value in state.event_log:
		var event: Dictionary = event_value
		if str(event.get("reason", "")) != "refinement_succeeded":
			continue
		if (event.get("targets", []) as Array).has("recipe:%s" % MOON_FIXED_RECIPE):
			recipe_tagged = true
	_check("事件 target 标注配方来源（可归因）", recipe_tagged, "recipe:%s" % MOON_FIXED_RECIPE)

	# --- 失败路径：盲炼（自由混合）---
	var blind := _build_pair(seed_value, "force_gu", "blood_droplet_gu")
	var pair_ids: Array[String] = []
	for instance_id_value in blind.cave_aperture.get("stored_gu_instance_ids", []):
		pair_ids.append(str(instance_id_value))
	var blind_events := blind.event_log.size()
	var blind_result: Dictionary = Resolver.apply(blind, {
		"type": "refine_gu",
		"recipe_id": FREE_MIX_RECIPE,
		"input_instance_ids": pair_ids,
	}, _catalog)
	_check("盲炼命令被领域接受", bool(blind_result.get("result", {}).get("ok", false)),
			str(blind_result.get("result", {}).get("reason", "")))
	if bool(blind_result.get("result", {}).get("ok", false)):
		blind = blind_result.get("state", blind)
	var reasons: Array[String] = []
	for event_value in blind.event_log.slice(blind_events):
		reasons.append(str((event_value as Dictionary).get("reason", "")))
	var known_reason := false
	for reason in reasons:
		if reason in ["free_mix_destroyed", "free_mix_mutation", "free_mix_explosion"]:
			known_reason = true
	_check("盲炼结果有明确事件归因（free_mix_*）", known_reason, str(reasons))
	var survivors: Array[String] = []
	var stored_after: Array = blind.cave_aperture.get("stored_gu_instance_ids", [])
	for instance_id in pair_ids:
		if (stored_after as Array).has(instance_id):
			var instance: Dictionary = blind.gu_instances.get(instance_id, {})
			if str(instance.get("state", "")) in ["refined", "contracted", "weakened"]:
				survivors.append(instance_id)
	print("  盲炼事件：%s；存活输入：%s；本局是否终局：%s"
			% [str(reasons), str(survivors), str(blind.is_terminal())])
	if survivors.is_empty():
		print("  盲炼代价已落地：输入蛊消亡（世界内代价真实结算）")
	# 世界内失败原因文案（设计 §5 要求「火候/相性/心神」）。
	if not _has_failure_copy():
		_gap("盲炼失败无世界内原因文案：事件 reason（free_mix_destroyed / mutation / explosion）在 DisplayText 无映射，UI 只能显示原始 code")
	return "D|%s|%s|%s" % [str(reasons), str(survivors), str(recipe_tagged)]


## 盲炼失败是否有面向玩家的原因文案：DisplayText 无 reason → 文本映射，
## 表现层也没有 free_mix 的文案入口（grep 证据：scripts/presentation 无 free_mix 引用）。
func _has_failure_copy() -> bool:
	var script := load("res://scripts/presentation/display_text.gd")
	if script == null:
		return false
	return script.has_method("refine_failure_text")


# ---------------------------------------------------------------- Gate E

func _gate_e(seed_value: int) -> String:
	print("")
	print("----- Gate E：货郎场景（报价 / 结算 / 门禁） -----")
	var npc: Dictionary = {}
	for npc_value in _catalog.get("npcs", []):
		if str((npc_value as Dictionary).get("id", "")) == PEDDLER_NPC_ID:
			npc = npc_value as Dictionary
			break
	_check("货郎 NPC 在目录中", not npc.is_empty(), PEDDLER_NPC_ID)
	var offer: Dictionary = _catalog.get("shop_offer_by_id", {}).get(PEDDLER_OFFER_ID, {})
	_check("报价在目录中：%s" % PEDDLER_OFFER_ID, not offer.is_empty(), str(offer.get("gu_id", "")))
	_check("货郎货架含该报价", (npc.get("stock", []) as Array).has(PEDDLER_OFFER_ID), str(npc.get("stock", [])))
	# 分层上架观察：货郎的 purchase_moonlight 是 tier 3，而切片剧本只在 L1。
	# npc_trade 复用 _shop_purchase，因此**也会被黑市分层门禁拦住**
	# （shop_command_rules 只把「货架」判定豁免给了 npc_trade，tier 门禁没有）。
	# 缺口 4（2026-09-16 已修）：货郎货架新增 purchase_blood_droplet（npc_only，
	# 不进黑市货池，避免洗牌结果整体漂移）。判定改为「货架上存在产出血滴蛊的报价」。
	var droplet_on_peddler := _stock_has_gu(npc, BLOOD_DROPLET_GU)
	if not droplet_on_peddler and not (npc.get("stock", []) as Array).has(CARAVAN_DROPLET_OFFER):
		_gap("货郎货架不含血滴蛊；设计 §6「货郎买 %s」在现役数据里挂在商队报价 %s（已用商队通路验证）"
				% [BLOOD_DROPLET_GU, CARAVAN_DROPLET_OFFER])
	# 缺口 5（2026-09-16 已修）：货阶分层只约束黑市节点（type=shop），NPC 个人
	# 货架已由 npc.stock 精确约束。这里改为正向断言：L1 走 npc_trade 能买到 tier 3 的月光蛊。
	var moonlight_offer: Dictionary = _catalog.get("shop_offer_by_id", {}).get("purchase_moonlight", {})
	var moon_state := _peddler_state(seed_value, 30)
	var moon_result: Dictionary = Resolver.apply(moon_state, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": "purchase_moonlight",
	}, _catalog)
	_check("L1 内货郎个人货架不受黑市货阶门禁限制（tier %d 可买）" % int(moonlight_offer.get("tier", 1)),
			bool(moon_result.get("result", {}).get("ok", false)),
			str(moon_result.get("result", {}).get("reason", "")))
	var node_declares_npc := false
	for node_value in _catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == PEDDLER_NODE_ID:
			node_declares_npc = str(node.get("npc_id", "")) == PEDDLER_NPC_ID
			break
	_check("节点模板声明了该 NPC（%s）" % PEDDLER_NODE_ID, node_declares_npc, "")

	# --- 正向：报价 → 结算（取货郎货架上 tier 1 的货，L1 可买）---
	var bought_gu_id := str(offer.get("gu_id", ""))
	var state := _peddler_state(seed_value, 30)
	var price := Resolver.shop_layer_price(_catalog, state, int(offer.get("stone_cost", 0)))
	print("  报价 %s：标价 %d，分层计价后 %d 元石（产出 %s）"
			% [PEDDLER_OFFER_ID, int(offer.get("stone_cost", 0)), price, DisplayText.gu(bought_gu_id)])
	var before_stone := int(state.stone)
	var result: Dictionary = Resolver.apply(state, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": PEDDLER_OFFER_ID,
	}, _catalog)
	_check("货郎交易被领域接受", bool(result.get("result", {}).get("ok", false)),
			str(result.get("result", {}).get("reason", "")))
	state = result.get("state", state)
	_check("元石扣减与计价一致（预览 = 结算，无隐藏元石）",
			before_stone - int(state.stone) == price, "扣 %d / 计价 %d" % [before_stone - int(state.stone), price])
	_check("买到 %s（已炼化实例入库）" % DisplayText.gu(bought_gu_id),
			_owns_definition(state, bought_gu_id), bought_gu_id)
	_check("交易写入事件日志", state.event_log.size() > 1, "%d 条" % state.event_log.size())

	# --- 负向门禁 ---
	var poor := _peddler_state(seed_value, 0)
	var poor_result: Dictionary = Resolver.apply(poor, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": PEDDLER_OFFER_ID,
	}, _catalog)
	_check("元石不足时被拒（insufficient_stone）",
			str(poor_result.get("result", {}).get("reason", "")) == "insufficient_stone",
			str(poor_result.get("result", {}).get("reason", "")))
	_check("被拒时不产出蛊（无白拿）", not _owns_definition(poor_result.get("state", poor), bought_gu_id), "")

	var off_stock := _peddler_state(seed_value, 99)
	var off_result: Dictionary = Resolver.apply(off_stock, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": "purchase_moon_glow",  # 不在货郎 stock 里
	}, _catalog)
	_check("非货郎货架的报价被拒（npc_stock_missing）",
			str(off_result.get("result", {}).get("reason", "")) == "npc_stock_missing",
			str(off_result.get("result", {}).get("reason", "")))

	var elsewhere := _peddler_state(seed_value, 99)
	elsewhere.current_node_id = "trailhead"
	var elsewhere_result: Dictionary = Resolver.apply(elsewhere, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": PEDDLER_OFFER_ID,
	}, _catalog)
	_check("不在货郎节点时被拒（npc_not_present）",
			str(elsewhere_result.get("result", {}).get("reason", "")) == "npc_not_present",
			str(elsewhere_result.get("result", {}).get("reason", "")))

	# --- 商队通路：设计 §6 的「元石买血滴蛊」在现役数据里挂在商队报价 buy_droplet ---
	var caravan := _peddler_state(seed_value, 30)
	var droplet_offer: Dictionary = _catalog.get("caravan_offer_by_id", {}).get(CARAVAN_DROPLET_OFFER, {})
	_check("商队报价在目录中：%s" % CARAVAN_DROPLET_OFFER, not droplet_offer.is_empty(),
			str(droplet_offer.get("output_gu_id", "")))
	var droplet_price := Resolver.price_for(_catalog, caravan, int(droplet_offer.get("stone_cost", 0)))
	var stone_before_buy := int(caravan.stone)
	var buy_result: Dictionary = Resolver.apply(caravan, {
		"type": "buy_gu",
		"offer_id": CARAVAN_DROPLET_OFFER,
	}, _catalog)
	_check("商队买血滴蛊被领域接受", bool(buy_result.get("result", {}).get("ok", false)),
			str(buy_result.get("result", {}).get("reason", "")))
	var bought_state = buy_result.get("state", caravan)
	_check("商队买蛊扣费与报价一致",
			stone_before_buy - int(bought_state.stone) == droplet_price,
			"扣 %d / 报价 %d" % [stone_before_buy - int(bought_state.stone), droplet_price])
	_check("血滴蛊入库（已炼化）", _owns_definition(bought_state, BLOOD_DROPLET_GU), BLOOD_DROPLET_GU)

	# --- 卖山货（材料）：报价与结算一致 ---
	var material_id := _first_material_id()
	if material_id.is_empty():
		_gap("loot_tables.materials 为空，无法验证「卖山货」通路")
		return "E|nomaterial"
	var seller := RunState.new_run(seed_value)
	seller.current_node_id = PEDDLER_NODE_ID
	seller.materials[material_id] = 2
	var base_value := int(_catalog.get("loot_tables", {}).get("materials", {}).get(material_id, {}).get("value", 1))
	var unit_price := Resolver.sell_price_for(_catalog, seller, base_value)
	var stone_before_sell := int(seller.stone)
	var sell_result: Dictionary = Resolver.apply(seller, {
		"type": "sell_material",
		"material_id": material_id,
	}, _catalog)
	_check("卖山货被领域接受", bool(sell_result.get("result", {}).get("ok", false)),
			str(sell_result.get("result", {}).get("reason", "")))
	var sold_state = sell_result.get("state", seller)
	_check("卖山货所得 = 单价 × 数量（无隐藏差价）",
			int(sold_state.stone) - stone_before_sell == unit_price * 2,
			"得 %d / 预期 %d" % [int(sold_state.stone) - stone_before_sell, unit_price * 2])
	_check("卖出的材料清零", int((sold_state.materials as Dictionary).get(material_id, -1)) == 0,
			str((sold_state.materials as Dictionary).get(material_id, "")))
	return "E|%d|%d|%d" % [price, before_stone - int(state.stone), unit_price]


# ---------------------------------------------------------------- Gate F

func _gate_f(first: String, second: String) -> void:
	print("")
	print("----- Gate F：确定性（同 seed 复跑） -----")
	_check("同 seed 两次跑判定序列一致", first == second,
			"%d / %d 字符" % [first.length(), second.length()])
	if first != second:
		print("    首轮：%s" % first)
		print("    复跑：%s" % second)


# ---------------------------------------------------------------- 夹具

## 南疆边地散修开局夹具。
## `refine_small_light=true` 时把两只小光蛊也置为已炼化 —— 现役领域没有
## 「未炼化 → 已炼化」的炼化命令（Gate C 会把它记为缺口），故炼蛊台场景
## 只能用已炼化实例代跑。
## `soul` 是三蛊合炼的既有容量前提（SoulCapacity.craft_cap：魂魄 1–2 ⇒ 上限 2，
## ≥3 ⇒ 上限 3）；夹具把它写进事件的 after，代价/权限变更同样留痕。
func _build_background(seed_value: int, refine_small_light: bool, soul: int = 1) -> RunState:
	var state := RunState.new_run(seed_value)
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	cultivator["soul"] = soul
	var instances: Dictionary = {}
	var stored: Array[String] = []
	var index := 0
	var plan: Array[String] = [MOONLIGHT_GU, SMALL_LIGHT_GU, SMALL_LIGHT_GU]
	for definition_id in plan:
		index += 1
		var instance_id := "s1_%03d" % index
		var instance: Dictionary = GuInstance.new_instance(definition_id, instance_id, _catalog)
		if definition_id == SMALL_LIGHT_GU and not refine_small_light:
			instance["state"] = UNREFINED_STATE
		instances[instance_id] = instance
		stored.append(instance_id)
	var aperture: Dictionary = state.cave_aperture.duplicate(true)
	aperture["stored_gu_instance_ids"] = stored
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "stage1_background",
		"before": {
			"gu_instances": state.gu_instances,
			"cave_aperture": state.cave_aperture,
			"cultivator": state.cultivator,
		},
		"after": {
			"gu_instances": instances,
			"cave_aperture": aperture,
			"cultivator": cultivator,
		},
		"reason": "stage1_background_injected",
		"source": "verify_stage1_slice",
		"targets": [BACKGROUND_ID, MOONLIGHT_GU, SMALL_LIGHT_GU],
	})
	state.cultivation = 1
	state.sync_legacy_gu_projections()
	return state


## 货郎场景夹具：把玩家放到货郎节点上（L1），并给定元石。
func _peddler_state(seed_value: int, stone: int) -> RunState:
	var state := RunState.new_run(seed_value)
	state.current_node_id = PEDDLER_NODE_ID
	state.current_node_layer = 1
	state.stone = stone
	return state


## 两只指定的蛊（已炼化），用于盲炼场景。
## 魂魄默认给 2：盲炼的 explosion 分支会扣 1 点魂魄，而 new_run 只给 1 点，
## 否则「一次爆炉」会直接把本局判死（那是真实后果，但会让失败路径的
## 其余断言无从观察）。这里只是让夹具站在「局中」而不是「开局一秒」。
func _build_pair(seed_value: int, main_gu_id: String, partner_gu_id: String, soul: int = 2) -> RunState:
	var state := RunState.new_run(seed_value)
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	cultivator["soul"] = soul
	var instances: Dictionary = {}
	var stored: Array[String] = []
	var index := 0
	for definition_id in [main_gu_id, partner_gu_id]:
		index += 1
		var instance_id := "s1p_%03d" % index
		instances[instance_id] = GuInstance.new_instance(definition_id, instance_id, _catalog)
		stored.append(instance_id)
	var aperture: Dictionary = state.cave_aperture.duplicate(true)
	aperture["stored_gu_instance_ids"] = stored
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "stage1_pair",
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture,
				"cultivator": state.cultivator},
		"after": {"gu_instances": instances, "cave_aperture": aperture, "cultivator": cultivator},
		"reason": "stage1_pair_injected",
		"source": "verify_stage1_slice",
		"targets": [main_gu_id, partner_gu_id],
	})
	state.cultivation = 1
	state.sync_legacy_gu_projections()
	return state


func _enemy_payload(enemy_id: String) -> Dictionary:
	var enemy: Dictionary = _catalog.get("enemy_by_id", {}).get(enemy_id, {})
	if enemy.is_empty():
		return {"id": enemy_id, "label": enemy_id, "hp": 20,
				"intent": {"kind": "attack", "label": "扑咬", "damage": 1}}
	var payload: Dictionary = enemy.duplicate(true)
	payload["hp"] = int(enemy.get("hp", 20))
	var intent: Variant = payload.get("intent")
	if not (intent is Dictionary) or (intent as Dictionary).is_empty():
		payload["intent"] = {"kind": "attack", "label": "扑咬", "damage": 1}
	return payload


func _new_controller() -> Node:
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	root.add_child(controller)
	await process_frame
	return controller


# ---------------------------------------------------------------- 工具

func _coords(node_id: String) -> Vector2i:
	if not node_id.begins_with("L"):
		return Vector2i(-1, -1)
	var rest := node_id.substr(1)
	var head := rest.split("R", true, 1)
	if head.size() != 2:
		return Vector2i(-1, -1)
	var tail := str(head[1]).split("N", true, 1)
	if tail.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(str(head[0])), int(str(tail[0])))


func _count_type(route: Array, layer_number: int, type_id: String) -> int:
	var count := 0
	for node_value in route:
		var node: Dictionary = node_value
		if _coords(str(node.get("id", ""))).x != layer_number:
			continue
		if str(node.get("type", "")) == type_id:
			count += 1
	return count


func _type_histogram(route: Array, layer_number: int) -> String:
	var counts: Dictionary = {}
	for node_value in route:
		var node: Dictionary = node_value
		if _coords(str(node.get("id", ""))).x != layer_number:
			continue
		var type_id := str(node.get("type", ""))
		counts[type_id] = int(counts.get(type_id, 0)) + 1
	var parts: Array[String] = []
	for type_id in counts:
		parts.append("%s×%d" % [type_id, int(counts[type_id])])
	parts.sort()
	return ", ".join(parts)


## 从 start 出发能走的最长边数（DAG，只沿 next_ids）。
## `layer_limit` 限制只在本大层内走 —— 否则关底台的 next_ids 会接下一大层入口，
## 步数会变成全图长度而不是「本层剧本长度」。
func _longest_path(route: Array, by_id: Dictionary, start_id: String, layer_limit: int) -> int:
	if start_id.is_empty() or not by_id.has(start_id):
		return 0
	var best_by_id: Dictionary = {}
	var order: Array[String] = [start_id]
	var index := 0
	while index < order.size():
		var node_id: String = order[index]
		index += 1
		for next_value in (by_id[node_id] as Dictionary).get("next_ids", []):
			var next_id := str(next_value)
			if not by_id.has(next_id):
				continue
			if layer_limit > 0 and _coords(next_id).x != layer_limit:
				continue
			var candidate := int(best_by_id.get(node_id, 0)) + 1
			if candidate > int(best_by_id.get(next_id, -1)):
				best_by_id[next_id] = candidate
			if not order.has(next_id):
				order.append(next_id)
	var best := 0
	for value in best_by_id.values():
		best = maxi(best, int(value))
	return best


func _owns_definition(state, definition_id: String) -> bool:
	for instance_value in state.gu_instances.values():
		var instance: Dictionary = instance_value
		if str(instance.get("definition_id", "")) != definition_id:
			continue
		if str(instance.get("state", "")) in ["refined", "contracted", "weakened"]:
			return true
	return false


## NPC 货架上是否存在「产出该蛊」的报价（按 gu_id 判，不依赖报价 id 命名）。
func _stock_has_gu(npc: Dictionary, gu_id: String) -> bool:
	var offer_by_id: Dictionary = _catalog.get("shop_offer_by_id", {})
	for offer_id_value in npc.get("stock", []):
		var offer: Dictionary = offer_by_id.get(str(offer_id_value), {})
		if str(offer.get("gu_id", "")) == gu_id:
			return true
	return false


func _has_event(state, reason_id: String) -> bool:
	for event_value in state.event_log:
		if str((event_value as Dictionary).get("reason", "")) == reason_id:
			return true
	return false


func _first_material_id() -> String:
	var materials: Dictionary = _catalog.get("loot_tables", {}).get("materials", {})
	for material_id_value in materials:
		return str(material_id_value)
	return ""


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s%s" % [label, "" if detail.is_empty() else "  (%s)" % detail])
		return
	_failed += 1
	print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  (%s)" % detail])


func _gap(label: String) -> void:
	if _gaps.has(label):
		return
	_gaps.append(label)
