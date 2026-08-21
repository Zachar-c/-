extends GutTest


func test_saved_reply_is_replayed_without_gateway_call() -> void:
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	var replies := [{
		"intent": "trade",
		"confidence": 0.9,
		"conditions": ["ledger_evidence"],
		"text": "管事收下账册证据，为你打开一条有人照看的路。",
		"needs_clarification": false,
	}]
	var saved := SaveRepository.serialize_run(state, route, replies)
	var gateway := CountingGateway.new()
	var loaded := SaveRepository.load_run_from_data(saved)
	assert_eq(loaded["replies"][0]["text"], "管事收下账册证据，为你打开一条有人照看的路。")
	assert_eq(gateway.calls, 0)


class CountingGateway extends DialogueGateway:
	var calls := 0

	func respond(_context: Dictionary) -> Dictionary:
		calls += 1
		return {}
