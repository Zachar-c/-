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
