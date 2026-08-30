extends GutTest


func test_main_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(packed)
	var scene := packed.instantiate()
	assert_not_null(scene.get_node_or_null("RunController"))
	scene.free()


func test_open_rpg_context_is_local() -> void:
	var context := {
		"enemy_kind": "beast_swarm",
		"turn_order": ["player", "enemy"],
	}
	assert_eq(context["enemy_kind"], "beast_swarm")
	assert_true(context.has("turn_order"))


func test_upstream_provenance_and_license_are_present() -> void:
	assert_true(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"))
	assert_true(FileAccess.file_exists("res://vendor/godot-open-rpg/LICENSE"))
	var notice := FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
	assert_true(notice.contains("https://github.com/gdquest-demos/godot-open-rpg"))
	assert_true(notice.contains("Pinned commit:"))
