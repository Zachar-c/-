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
	_collect_art(view, art_nodes, bodies)
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
		assert_ne((b as Button).text, "", "info band text non-empty")


func _collect_art(node: Node, arts: Array[Node], bodies: Array[Node]) -> void:
	for child in node.get_children():
		if child is TextureRect and str(child.name).begins_with("card_art_"):
			arts.append(child)
		if child is Button and str(child.name).begins_with("card_body_"):
			bodies.append(child)
		_collect_art(child, arts, bodies)


func test_face_text_compacts_to_info_band_lines() -> void:
	var view: Control = autofree(FanScript.new())
	var text: String = view._face_text(_card("blood"))
	var lines := text.split("\n")
	assert_lte(lines.size(), 3, "info band allows at most 3 compact lines")
	assert_string_contains(text, "念头 1")
