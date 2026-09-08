extends SceneTree
func _initialize() -> void:
	var battle: Control = (load("res://scenes/ui/screens/battle_screen.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	var hand = battle.get_node("Root/HandStage/HandMargin/battle_hand/HandArea/CenterWrap/Hand")
	print("hand size=", hand.size, " min=", hand.get_combined_minimum_size())
	var cardrow = hand.get_node("CardRow")
	var cancelrow = hand.get_node("CancelRow")
	print("cardrow size=", cardrow.size, " min=", cardrow.get_combined_minimum_size())
	print("cancelrow size=", cancelrow.size, " min=", cancelrow.get_combined_minimum_size(), " children=", cancelrow.get_child_count())
	if cancelrow.get_child_count() > 0:
		var btn = cancelrow.get_child(0)
		print("cancel btn size=", btn.size, " min=", btn.get_combined_minimum_size(), " font=", btn.get_theme_font_size("font_size"))
	battle.queue_free()
	quit()
