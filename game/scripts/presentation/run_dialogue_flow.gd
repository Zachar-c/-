extends RefCounted

## A7：对话分支结算外提。controller 保持同名一行包装。


const DialogueGatewayScript = preload("res://scripts/domain/dialogue_gateway.gd")
const DialogueManagerAdapterScript = preload("res://scripts/domain/dialogue_manager_adapter.gd")
const RejectionTextScript = preload("res://scripts/presentation/rejection_text.gd")


static func submit_branch(controller, command: Dictionary) -> Dictionary:
	if controller._dialogue_gateway == null:
		controller._dialogue_gateway = DialogueManagerAdapterScript.new()
	var branch_id := str(command.get("branch_id", ""))
	var branch_context: Dictionary = command.get("context", {}) if command.get("context", {}) is Dictionary else {}
	if command.has("state_version"):
		branch_context["state_version"] = command.get("state_version")
	var branch_result: Dictionary = {}
	if controller._dialogue_gateway.has_method("apply_branch"):
		branch_result = controller._dialogue_gateway.apply_branch(
			controller.state,
			controller.state.encounter_session,
			branch_id,
			controller.catalog,
			controller.current_node,
			branch_context
		)
	else:
		branch_result = {
			"ok": false,
			"reason": "dialogue_adapter_unavailable",
			"feedback": "对话暂时无法回应，局面没有改变。",
			"state": controller.state,
			"session": controller.state.encounter_session.duplicate(true),
			"result": {"ok": false, "reason": "dialogue_adapter_unavailable"},
		}
	controller.state = branch_result.get("state", controller.state)
	controller.last_result = branch_result.get("result", {})
	controller.last_feedback = str(branch_result.get("feedback", ""))
	if controller.last_feedback.is_empty() and not bool(branch_result.get("ok", false)):
		controller.last_feedback = RejectionTextScript.text(
			str(branch_result.get("reason", "unknown_dialogue_branch")))
	if bool(controller.state.encounter_session.get("completed", false)):
		controller._return_to_map()
	else:
		controller._re_show_current_screen()
	return branch_result


static func record_dialogue_reply(controller, result: Dictionary) -> void:
	var reply: Variant = result.get("dialogue", {})
	if not reply is Dictionary or reply.is_empty():
		return
	var payload: Dictionary = reply.duplicate(true)
	payload.erase("source")
	if DialogueGatewayScript.is_valid_response(payload):
		controller.dialogue_replies.append(payload)


static func attach_social_dialogue(controller, result: Dictionary) -> void:
	var action_id := str(result.get("action_id", ""))
	if action_id not in ["probe", "trade"] or controller._dialogue_gateway == null:
		return
	var social: Dictionary = controller.state.relations.get("caravan_steward", {})
	result["dialogue"] = controller._dialogue_gateway.respond({
		"intent": action_id,
		"disposition": str(social.get("npc_disposition", "neutral")),
	})
