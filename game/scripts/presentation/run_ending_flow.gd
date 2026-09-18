extends RefCounted

## A7：结局 / 死亡结算与 run_end 落账外提。controller 保持同名一行包装。


const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")


static func run_end_outcome(outcome: String) -> String:
	match outcome:
		"success", "ascension_special", "ascension_high", "ascension_medium", "ascension_low":
			return "won"
		"risky_success": return "risky"
		"surrendered": return "abandoned"
	return "dead"


static func record_run_end(controller, outcome: String, ending_type := "") -> void:
	# 结局即此世终点（AGENTS）：结算时删除进行中 Run 存档，使大厅
	# 「续入此世」不再回到已结束的旧档；下一世从大厅进入时以全新
	# 随机种子开局。删除放在 meta 判空前，确保任何结局路径都清理。
	SaveRepositoryScript.delete_run_save()
	if controller.meta == null:
		return
	controller.meta = controller.meta.record_run_end(
			controller.state, outcome,
			controller.catalog if controller.catalog != null else {}, ending_type)
	SaveRepositoryScript.save_meta_file(controller.meta)


static func show_ending(controller, outcome: Dictionary) -> void:
	var otype := str(outcome.get("outcome", ""))
	record_run_end(controller, run_end_outcome(otype),
			RunSnapshotBuilderScript.ending_type_for(otype))
	controller._ending_state = RunSnapshotBuilderScript.ending(
			controller, outcome,
			JournalBuilder.build(controller.state, outcome),
			controller.state.to_save_data())
	controller._set_view("Ending")


static func show_death(controller, report: Dictionary) -> void:
	record_run_end(controller, "dead", "death")
	var cause: Dictionary = RunSnapshotBuilderScript.death_cause_fields(controller.state)
	var death_state := {
		"title": "身死道消",
		"ending_type": "death",
		"death_cause_id": str(cause["id"]),
		"death_cause": str(cause["text"]),
		"death_cause_short": str(cause["short"]),
		"key_decisions": ["最后一击：%s" % RunSnapshotBuilderScript.blow_text(str(report.get("final_blow", "")))],
		"gains_losses": "最后一击：%s（%d 点伤害）" % [
			RunSnapshotBuilderScript.blow_text(str(report.get("final_blow", ""))),
			int(report.get("damage", 0))],
		"resource_balance": {
			"yuanstone": int(controller.state.stone),
			"shouyuan": int(controller.state.cultivator.get("lifespan", 0)),
		},
		"unlocks": [],
		"aftermath": "残魂归于大地，修行札记已留存。",
	}
	death_state.merge(RunSnapshotBuilderScript.settlement_extras(controller))
	death_state["achievement"] = DisplayTextScript.ending_achievement("death")
	controller._ending_state = death_state
	controller._set_view("Ending")
