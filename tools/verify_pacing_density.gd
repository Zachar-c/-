extends SceneTree

# 一次性体检：统计各层节点构成，验证「商店/炼蛊/战斗多样性」是否真的落到了生成图上。
# 用法：godot --headless --path . -s tools/verify_pacing_density.gd


func _initialize() -> void:
	var MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
	for seed_value in [101, 4242, 777]:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		print("===== seed %d =====" % seed_value)
		for layer_key in ["1", "2", "3", "4", "5"]:
			var counts: Dictionary = {}
			var combat_templates: Array = []
			for node_value in route:
				var node: Dictionary = node_value
				if str(node.get("layer", "")) != layer_key:
					continue
				var template_id := str(node.get("template_id", ""))
				counts[template_id] = int(counts.get(template_id, 0)) + 1
				if (not combat_templates.has(template_id) and not _is_special(template_id)
						and not template_id.is_empty()):
					combat_templates.append(template_id)
			var total := 0
			for key in counts.keys():
				total += int(counts[key])
			var shop := int(counts.get("ridge_black_market", 0))
			var refine := int(counts.get("refinement_hollow", 0))
			var rest := int(counts.get("rest_hollow", 0)) + int(counts.get("rest_shrine", 0))
			var boss := 0
			for key in counts.keys():
				if str(key).begins_with("layer_boss_stand_") or str(key) == "final_boss_stand":
					boss += int(counts[key])
			var inherit := int(counts.get("yizang_ridge", 0))
			var unknown := int(counts.get("", 0))
			var combat := total - shop - refine - rest - boss - inherit - unknown
			print("  L%s total=%d | combat=%d shop=%d rest=%d refine=%d inherit=%d boss=%d unknown=%d | 战斗模板=%d 种 %s"
					% [layer_key, total, combat, shop, rest, refine, inherit, boss, unknown,
					combat_templates.size(), str(combat_templates)])
	quit(0)


func _is_special(template_id: String) -> bool:
	return (template_id == "ridge_black_market" or template_id == "refinement_hollow"
			or template_id == "rest_hollow" or template_id == "rest_shrine"
			or template_id == "yizang_ridge"	# 遗葬：L1 anchor 保底投放，非战斗
			or template_id == "final_boss_stand" or template_id.begins_with("layer_boss_stand_"))
