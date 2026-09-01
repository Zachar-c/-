extends GutTest


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")

const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"

var _rui_roots: Array = []
var _rui_hosts: Array = []


func after_each() -> void:
	for r in _rui_roots:
		if r != null and r.has_method("unmount"):
			r.unmount()
	_rui_roots.clear()
	for host in _rui_hosts:
		if host != null and is_instance_valid(host):
			host.queue_free()
	_rui_hosts.clear()


func test_hall_uses_wenzhen_brand_and_one_primary_action() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	var snapshot := controller._snapshot_for("Title")
	assert_eq(snapshot["brand_title"], "問眞")
	assert_eq(snapshot["primary_action"], "continue_run" if snapshot["has_save"] else "open_schools")

	# .tscn 迁移后：主按钮唯一性直接挂新屏断言（role 语义由 MasterTheme.apply_button 赋）。
	var host := _mount_hall(Vector2i(1920, 1080), snapshot)
	await get_tree().process_frame
	assert_eq(_primary_button_count(host), 1)


func test_hall_projects_current_run_summary_without_ui_recomputation() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var run: RunState = RunStateScript.new_run(101)
	run.current_node_id = "rest_hollow"
	run.cultivation = 3
	run.health = 27
	controller.state = run
	add_child(controller)

	var summary: Dictionary = controller._snapshot_for("Title")["run_summary"]
	assert_eq(summary, {"route": "休整", "rank": "3 转", "hp": "27"})


func test_hall_matches_approved_horizontal_composition() -> void:
	var host := _mount_hall(Vector2i(1920, 1080), _running_snapshot())
	await get_tree().process_frame
	await get_tree().process_frame
	var sheet := _named(host, "HallSheet")
	var identity := _named(host, "HallIdentity")
	var rule := _named(host, "HallPrimaryRule")
	var primary := _named(host, "HallPrimary")
	var archive_rule := _named(host, "HallArchiveRule")
	var archive := _named(host, "HallArchive")
	var folio := _named(host, "HallFolio")
	var seal := _named(host, "HallSeal")
	var title := _named(host, "HallTitle")
	var action := _named(host, "HallPrimaryAction")
	assert_not_null(sheet, "hall HTML uses a full-page sheet layer")
	assert_not_null(identity, "hall must expose its identity region")
	assert_not_null(rule, "hall HTML puts a hairline before the central chapter")
	assert_not_null(primary, "hall must expose its primary decision region")
	assert_not_null(archive_rule, "hall HTML puts a hairline before the archive")
	assert_not_null(archive, "hall must expose its quiet archive navigation")
	assert_not_null(folio, "hall HTML keeps the folio in the upper left margin")
	assert_not_null(seal, "hall HTML keeps the cinnabar seal in the upper right margin")
	assert_not_null(title, "hall HTML makes the horizontal title its largest element")
	assert_not_null(action, "hall HTML has one selected chapter action")
	assert_null(_named(host, "HallArt"), "approved hall master has no standalone image column")
	if sheet == null or identity == null or rule == null or primary == null or archive_rule == null or archive == null or folio == null or seal == null or title == null or action == null:
		return
	assert_gte(host.get_global_rect().size.x, 1888.0)
	assert_almost_eq(sheet.get_global_rect().position.y, 72.0, 3.0, "sheet starts at the HTML top padding")
	assert_almost_eq(sheet.get_global_rect().end.y, host.get_global_rect().end.y - 48.0, 3.0, "sheet keeps the HTML bottom padding")
	assert_almost_eq(sheet.get_global_rect().position.x, host.get_global_rect().size.x * 0.07, 4.0, "sheet keeps the HTML horizontal page margin")
	assert_lt(identity.get_global_rect().get_center().x, primary.get_global_rect().get_center().x)
	assert_lt(primary.get_global_rect().get_center().x, archive.get_global_rect().get_center().x)
	assert_gte(identity.get_global_rect().size.x, 330.0)
	assert_gte(primary.get_global_rect().size.x, 350.0)
	assert_almost_eq(rule.get_global_rect().position.x, primary.get_global_rect().position.x - 50.0, 3.0, "central rule and 50px inset mechanically follow the HTML")
	assert_almost_eq(archive_rule.get_global_rect().position.x, archive.get_global_rect().position.x - 26.0, 3.0, "archive rule and 26px inset mechanically follow the HTML")
	assert_gte(title.get_global_rect().size.y, 88.0, "title retains HTML-scale calligraphic hierarchy")
	assert_gte(action.get_global_rect().size.y, 52.0)
	assert_lte(archive.get_global_rect().end.y, sheet.get_global_rect().end.y + 1.0)
	assert_gte(archive.get_global_rect().position.y, sheet.get_global_rect().get_center().y, "archive actions stay quiet and bottom-aligned")
	assert_almost_eq(folio.get_global_rect().position, Vector2(29, 25), Vector2(3, 3))
	assert_almost_eq(seal.get_global_rect().position, Vector2(host.size.x - 75, 27), Vector2(3, 3))
	assert_eq(_primary_button_count(host), 1)
	assert_eq(_visible_text_count(host, "問眞"), 1)


func test_hall_uses_the_approved_paper_and_semantic_colors() -> void:
	var host := _mount_hall(Vector2i(1920, 1080), _running_snapshot())
	await get_tree().process_frame
	var paper := _named(host, "HallPaper") as ColorRect
	var rule := _named(host, "HallPrimaryRule") as ColorRect
	assert_not_null(paper, "hall must own the HTML paper color instead of inheriting the global token")
	assert_not_null(rule, "hall must retain its HTML hairline rule")
	if paper == null or rule == null:
		return
	assert_true(paper.color.is_equal_approx(Color("e5e2d7")), "hall paper must be the HTML PAPER_HALL")
	assert_true(rule.color.is_equal_approx(Color("b8b6aa")), "hall rule must be the HTML RULE_HALL")


func test_hall_running_summary_uses_the_master_ink_color() -> void:
	var host := _mount_hall(Vector2i(1920, 1080), _running_snapshot())
	await get_tree().process_frame
	for label_name in ["hall_summary_route", "hall_summary_rank", "hall_summary_hp"]:
		var summary_label := _named(host, label_name) as Label
		assert_not_null(summary_label, "hall running summary needs a named master-visible label: %s" % label_name)
		if summary_label != null:
			assert_true(summary_label.get_theme_color("font_color").is_equal_approx(Color("171817")), "%s must use the hall HTML ink" % label_name)


func _mount_hall(viewport_size: Vector2i, state: Dictionary) -> Control:
	# 2026-09-01 .tscn 迁移后：大厅主屏 = scenes/ui/screens/hall_screen.tscn
	# （旧 hall_view.gd/RUI 路由已退役）。挂载走 TscnMountHelper，快照直入。
	var host := Control.new()
	host.size = Vector2(viewport_size)
	host.custom_minimum_size = Vector2(viewport_size)
	add_child(host)
	_rui_hosts.append(host)
	var hall = TscnMountHelper.instantiate(HALL_SCREEN_TSCN, state, {})
	if hall != null:
		host.add_child(hall)
	return host


func _running_snapshot() -> Dictionary:
	return {
		"has_save": true,
		"brand_title": "問眞",
		"primary_action": "continue_run",
		"run_summary": {"route": "黑市交易后", "rank": "4 转", "hp": "27"},
		"meta_stats": {"runs": 3, "endings": 1},
	}


func _named(node: Node, wanted: String) -> Control:
	if node is Control and node.name == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _primary_button_count(node: Node) -> int:
	var count := 1 if node is Button and node.name == "HallPrimaryAction" else 0
	for child in node.get_children():
		count += _primary_button_count(child)
	return count


func _visible_text_count(node: Node, wanted: String) -> int:
	var count := 0
	if node is Label and node.visible and node.text == wanted:
		count += 1
	for child in node.get_children():
		count += _visible_text_count(child, wanted)
	return count


func _buttons_with_role(vnode: Variant, role: String) -> Array:
	var out: Array = []
	if vnode == null:
		return out
	if vnode is RefCounted or vnode is Dictionary:
		var props: Variant = vnode.props if vnode is RefCounted else vnode.get("props", {})
		if props is Dictionary and str(props.get("role", "")) == role:
			out.append(vnode)
		var children: Variant = vnode.children if vnode is RefCounted else vnode.get("children", [])
		if children is Array:
			for child in children:
				out.append_array(_buttons_with_role(child, role))
	return out
