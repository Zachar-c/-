extends GutTest

## C3：竖长卡留白排版 —— 按道映射插画 + 占位 + 信息带文案。

const FanScript = preload("res://scripts/presentation/widgets/gu_tall_fan_hand_view.gd")


func _card(school_id: String) -> Dictionary:
	return {
		"id": "gu.test_" + school_id,
		"name": "试验蛊",
		"quality": "普通",
		"school_label": "血道",
		"school_id": school_id,
		"effect": "造成 2 点伤害",
		"cost": "念头 1",
		"cost_ex": "",
		"executable": true,
	}


func test_dao_texture_map_covers_existing_pngs() -> void:
	var missing: Array[String] = []
	for school_id in FanScript.DAO_TEXTURE:
		var path: String = str(FanScript.DAO_TEXTURE[school_id])
		if not FileAccess.file_exists(path):
			missing.append("%s -> %s" % [school_id, path])
	assert_eq(missing, [] as Array[String], str(missing))


func test_card_builds_art_texture_rect_and_info_button() -> void:
	var view: Control = FanScript.new()
	# 先入树再 setup，保证 _ready/_ensure_scaffold 已执行（与生产 mount 顺序一致）。
	add_child_autofree(view)
	view.setup([_card("blood"), _card("wisdom")], func(_id, _t): pass)
	await get_tree().process_frame
	# 构建卡体（勿依赖 _cards_host 节点名：可能尚未挂到 scene tree 可见路径）。
	var art_nodes: Array[Node] = []
	var bodies: Array[Node] = []
	_collect_face(view, art_nodes, bodies)
	assert_true(art_nodes.size() >= 2, "expected >=2 art TextureRects, got %d" % art_nodes.size())
	var blood_tex_ok := false
	var unknown_placeholder_ok := false
	for art in art_nodes:
		var tr := art as TextureRect
		if tr == null:
			continue
		if tr.texture != null:
			blood_tex_ok = true
		else:
			unknown_placeholder_ok = true
	assert_true(blood_tex_ok, "at least one school with png should load texture")
	assert_true(unknown_placeholder_ok, "unknown school keeps null placeholder")
	assert_true(bodies.size() >= 2, "expected card body buttons")
	for b in bodies:
		# 2026-09-11 卡面层级重构：卡名在 `card_name` meta（不在 Button.text）。
		assert_ne(str((b as Button).get_meta("card_name", "")), "", "card name meta non-empty")
	# 标题 Label（毛笔字槽）每张卡一个，卡名与 meta 一致。
	for title in _collect_named(view, "card_title_"):
		assert_string_contains(str((title as Label).text), "试验蛊")


func test_face_slots_exist_and_desc_truncates() -> void:
	var view: Control = FanScript.new()
	add_child_autofree(view)
	var long_card := _card("blood")
	long_card["effect"] = "消耗2真元对单体造成 6 点伤害并附加流血（详情归共享 tooltip）"
	view.setup([long_card], func(_id, _t): pass)
	await get_tree().process_frame
	assert_not_null(_find_named(view, "card_tag_"), "quality tag row on face")
	assert_not_null(_find_named(view, "card_frame_"), "framed art slot on face")
	assert_not_null(_find_named(view, "card_desc_"), "desc slot on face")
	var desc := _find_named(view, "card_desc_") as RichTextLabel
	assert_not_null(desc)
	if desc != null:
		assert_false(str(desc.text).contains("（"), "parenthetical note belongs to shared tooltip")
		assert_true(str(desc.text).ends_with("…"), "long effect is truncated with ellipsis")
		assert_true(str(desc.text).contains("[color=#"), "desc keywords are bbcode highlighted")


func test_split_cost_routes_zhenyuan_to_badge_and_rest_to_tag() -> void:
	var parts: Dictionary = FanScript._split_cost("真元 2 · 念头 1")
	assert_eq(str(parts["badge"]), "2", "zhenyuan number becomes the badge")
	assert_eq(str(parts["rest"]), "念头 1", "thought cost stays visible on the tag row")
	var plain: Dictionary = FanScript._split_cost("3")
	assert_eq(str(plain["badge"]), "3", "plain numeric cost becomes the badge")
	assert_eq(str(plain["rest"]), "", "no leftover for plain numeric cost")
	var thought_only: Dictionary = FanScript._split_cost("念头 1")
	assert_eq(str(thought_only["badge"]), "", "thought-only cost has no zhenyuan badge")
	assert_eq(str(thought_only["rest"]), "念头 1", "thought-only cost stays on the tag row")


func _collect_face(node: Node, arts: Array[Node], bodies: Array[Node]) -> void:
	for child in node.get_children():
		if child is TextureRect and str(child.name).begins_with("card_art_"):
			arts.append(child)
		if child is Button and str(child.name).begins_with("card_body_"):
			bodies.append(child)
		_collect_face(child, arts, bodies)


func _collect_named(node: Node, prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		if str(child.name).begins_with(prefix):
			out.append(child)
		out.append_array(_collect_named(child, prefix))
	return out


func _find_named(node: Node, prefix: String) -> Node:
	for child in node.get_children():
		if str(child.name).begins_with(prefix):
			return child
		var found := _find_named(child, prefix)
		if found != null:
			return found
	return null
