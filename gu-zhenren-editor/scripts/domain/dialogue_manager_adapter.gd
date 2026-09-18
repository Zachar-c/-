class_name DialogueManagerAdapter
extends DialogueGateway


const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const TemplateDialogueGatewayScript = preload("res://scripts/domain/template_dialogue_gateway.gd")
const EventFactoryScript = preload("res://scripts/domain/events.gd")
const EVENTS_DIALOGUE_PATH := "res://data/dialogues/events.dialogue"

var _fallback: DialogueGateway
var _selection_callback: Callable = Callable()


func _init(fallback: DialogueGateway = null) -> void:
	_fallback = fallback if fallback != null else TemplateDialogueGatewayScript.new()


## 运行时桥接入口（P1-B）：由 controller 在 begin() 后注入，把 Dialogue Manager
## 的 passed_title 信号（玩家点击 balloon 选项导致的 title 跳转）转成
## submit_dialogue_selection 的标题，从而走统一命令结算路径。
func set_branch_selection_callback(callback: Callable) -> void:
	_selection_callback = callback


## Narrative-only response boundary. Dialogue Manager is optional: this method
## always returns the validated offline response when the addon is unavailable.
func respond(context: Dictionary) -> Dictionary:
	# The addon exposes an asynchronous balloon API, so it cannot replace the
	# synchronous, replayable response contract. It is started explicitly by
	# begin() while this method remains deterministic for saves and tests.
	return _fallback.respond(context)


func plugin_available() -> bool:
	return _dialogue_manager() != null


## Start a Dialogue Manager balloon when the optional addon is installed. No
## RunState or command is passed to the addon; branch application stays below.
## Once the balloon runs, passed_title signals are forwarded to the injected
## selection callback (the controller's submit_dialogue_selection).
func begin(event_id: String, title: String = "start") -> Dictionary:
	var manager := _dialogue_manager()
	if manager == null:
		return {"ok": true, "source": "template", "event_id": event_id, "title": title}
	if not manager.has_method("show_dialogue_balloon"):
		return {"ok": true, "source": "template", "event_id": event_id, "title": title}
	var resource := load(EVENTS_DIALOGUE_PATH)
	if resource == null:
		return {"ok": true, "source": "template", "event_id": event_id, "title": title}
	if manager.has_signal("passed_title") and not manager.passed_title.is_connected(_on_passed_title):
		manager.passed_title.connect(_on_passed_title)
	manager.show_dialogue_balloon(resource, title)
	return {"ok": true, "source": "dialogue_manager", "event_id": event_id, "title": title}


## Dialogue Manager emits this when the balloon jumps to a title, i.e. the
## player picked one of the authored options. The title encodes the branch
## (event_id + branch), so it is handed straight to the domain command path.
func _on_passed_title(title: String) -> void:
	if _selection_callback.is_valid():
		_selection_callback.call(str(title))


## Convert authored branch IDs to existing domain commands. Context may carry
## an explicit branch_commands map for authored events without adding a new
## resolver or a second state owner.
##
## Two shapes are accepted:
##   - dot form (templates/tests): "event.echo_cave.accept" / "echo_cave.accept"
##   - underscore form (Dialogue Manager plugin title, which forbids "."):
##     "echo_cave_accept" / "gu_rot_pact_leave"
func command_for_branch(branch_id: String, context: Dictionary = {}) -> Dictionary:
	var normalized := branch_id.strip_edges().replace("/", ".")
	var declared: Variant = context.get("branch_commands", {})
	if declared is Dictionary and declared.has(normalized) and declared[normalized] is Dictionary:
		return (declared[normalized] as Dictionary).duplicate(true)

	var parts := normalized.split(".", false)
	if parts.size() > 1 and str(parts[0]) == "event":
		parts = parts.slice(1)
	if parts.size() >= 2:
		var action := str(parts[parts.size() - 1])
		var event_id := ".".join(parts.slice(0, parts.size() - 1))
		if not event_id.is_empty():
			var cmd := _match_branch(action, event_id)
			if not cmd.is_empty():
				return cmd
	var last_underscore := normalized.rfind("_")
	if last_underscore > 0 and last_underscore < normalized.length() - 1:
		var u_event := normalized.substr(0, last_underscore)
		var u_branch := normalized.substr(last_underscore + 1)
		if not u_event.is_empty():
			var cmd := _match_branch(u_branch, u_event)
			if not cmd.is_empty():
				return cmd
	return {}


static func _match_branch(action: String, event_id: String) -> Dictionary:
	match action:
		"accept", "accept_event", "take", "investigate":
			return {"type": "accept_event", "event_id": event_id}
		"leave", "decline", "reject":
			return {"type": "leave_node"}
	return {}


## Apply a branch through the existing encounter/resolver command paths. The
## adapter never edits state itself; rejected/unknown branches return the same
## state object and a visible Chinese message.
func apply_branch(
	state: RunState,
	session: Dictionary,
	branch_id: String,
	catalog: Dictionary,
	node: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if context.has("state_version") and int(context.get("state_version", -1)) != state.event_log.size():
		return _branch_rejected(state, session, "action_preview_stale", "局面已变化，请刷新当前事件后重试。")
	var command := command_for_branch(branch_id, context)
	if command.is_empty():
		return _branch_rejected(state, session, "unknown_dialogue_branch", "无法理解这段对话的选择，局面没有改变。")
	if str(command.get("type", "")) == "accept_event":
		var event_id := str(command.get("event_id", ""))
		var events_by_id: Dictionary = catalog.get("event_by_id", {})
		if not events_by_id.is_empty() and not events_by_id.has(event_id):
			return _branch_rejected(state, session, "unknown_dialogue_branch", "这段对话已经失去对应的事件，局面没有改变。")

	var resolved: Dictionary
	var session_for_apply := session.duplicate(true)
	var used: Array = session_for_apply.get("used_action_ids", [])
	if used.has(branch_id):
		return _branch_rejected(state, session, "dialogue_branch_used", "这项对话选择已经处理过了。")
	used.append(branch_id)
	session_for_apply["used_action_ids"] = used
	if not session.is_empty():
		resolved = EncounterSessionResolverScript.apply(state, session_for_apply, command, catalog, node)
		var nested: Dictionary = resolved.get("result", {})
		var ok := bool(nested.get("ok", false))
		var next_state: RunState = resolved.get("state", state)
		if ok:
			next_state = _append_branch_event(
				next_state, node, branch_id, str(command.get("event_id", "")), "accepted")
		return {
			"ok": ok,
			"reason": str(nested.get("reason", "")),
			"feedback": _feedback_for(ok, nested, resolved.get("feed", {})),
			"state": next_state,
			"session": resolved.get("session", session),
			"result": nested,
			"feed": resolved.get("feed", ResultFeedScript.entry("dialogue", "action_result", {}, [])),
			"command": command,
		}

	resolved = Resolver.apply(state, command, catalog)
	var result: Dictionary = resolved.get("result", {})
	var accepted := bool(result.get("ok", false))
	var next_state: RunState = resolved.get("state", state)
	if accepted:
		next_state = _append_branch_event(
			next_state, node, branch_id, str(command.get("event_id", "")), "accepted")
	return {
		"ok": accepted,
		"reason": str(result.get("reason", "")),
		"feedback": _feedback_for(accepted, result, {}),
		"state": next_state,
		"session": session.duplicate(true),
		"result": result,
		"feed": ResultFeedScript.entry("dialogue", "dialogue_branch", {}, []),
		"command": command,
	}


## 分支选择成功入不可变事件日志（P3-7）：EventFactory.dialogue_branch 产生
## 叙事元事件，供结局归因、回放与诊断；状态追加后返回新 RunState。
func _append_branch_event(state: RunState, node: Dictionary, branch_id: String, event_id: String, outcome: String) -> RunState:
	return state.append_event(EventFactoryScript.dialogue_branch(
		str(node.get("id", "")),
		branch_id,
		event_id,
		outcome
	))


func _branch_rejected(state: RunState, session: Dictionary, reason: String, feedback: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"feedback": feedback,
		"state": state,
		"session": session.duplicate(true),
		"result": {"ok": false, "reason": reason},
		"feed": ResultFeedScript.entry("dialogue", "dialogue_branch_rejected", {}, []),
	}


func _feedback_for(ok: bool, result: Dictionary, feed: Dictionary) -> String:
	if not ok:
		return "对话选择未能执行：%s。" % str(result.get("reason", "未知原因"))
	var changes: Variant = result.get("actual_changes", [])
	if changes is Array:
		var messages: Array[String] = []
		for change in changes:
			if change is Dictionary and not str(change.get("message", "")).is_empty():
				messages.append(str(change["message"]))
		if not messages.is_empty():
			return "、".join(messages)
	return "对话已回应，结果已记入行程。"


func _dialogue_manager() -> Object:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var node := (loop as SceneTree).root.get_node_or_null("DialogueManager")
		if node != null:
			return node
	return null
