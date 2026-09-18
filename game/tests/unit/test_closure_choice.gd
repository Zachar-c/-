extends GutTest

## 收官抉择（2026-09-15 用户裁定）：`pacing.ending_after_stage` 从
## 「打掉该层关底即强制收官」改为「自该层起，收官成为**玩家可选**」。
##
## 本单钉住领域契约（判据单一事实来源 = `SocialCommandRules.closure_available`，
## 快照按钮与命令校验共用），不测 UI 外观。

const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const SocialCommandRules = preload("res://scripts/domain/social_command_rules.gd")


func _controller() -> RunController:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260915, "light", [], [])
	return controller


func _defeat_layer(controller, layer: int) -> void:
	controller.state = Resolver.apply(controller.state,
			{"type": "record_layer_boss_defeated", "layer": layer}, controller.catalog)["state"]


func test_closure_locked_before_any_layer_boss() -> void:
	var controller := _controller()
	assert_false(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"未打任何关底前不得收官")
	var resolved := Resolver.apply(controller.state, {"type": "close_run"}, controller.catalog)
	assert_false(bool(resolved["result"]["ok"]), "领域必须拒绝未解锁的收官")
	assert_eq(str(resolved["result"].get("reason", "")), "closure_not_available")
	assert_eq(str(resolved["state"].terminal_state), "active", "被拒的收官不得改变终局态")
	assert_eq(resolved["state"].event_log.size(), controller.state.event_log.size(),
			"被拒的收官不得落事件")


func test_closure_unlocks_after_configured_threshold_layer() -> void:
	var controller := _controller()
	assert_eq(str(controller.catalog.get("pacing", {}).get("ending_after_stage", "")), "one",
			"生产阈值层 = one")
	_defeat_layer(controller, 1)
	assert_true(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"打掉 L1 关底后收官开放")


func test_close_run_ends_the_run_and_logs_immutable_event() -> void:
	var controller := _controller()
	_defeat_layer(controller, 1)
	var resolved := Resolver.apply(controller.state, {"type": "close_run"}, controller.catalog)
	assert_true(bool(resolved["result"]["ok"]), "解锁后收官成立")
	assert_eq(str(resolved["result"].get("route", "")), "player_closure")
	assert_eq(str(resolved["result"].get("outcome", "")), "success")
	assert_eq(str(resolved["state"].terminal_state), "success", "收官即终局")
	var last: Dictionary = resolved["state"].event_log[-1]
	assert_eq(str(last.get("action", "")), "close_run", "收官必须落不可变事件")
	assert_eq(str(last.get("reason", "")), "player_closure_layer_1")


func test_terminal_run_cannot_close_twice() -> void:
	var controller := _controller()
	_defeat_layer(controller, 1)
	controller.state = Resolver.apply(controller.state, {"type": "close_run"}, controller.catalog)["state"]
	var again := Resolver.apply(controller.state, {"type": "close_run"}, controller.catalog)
	assert_false(bool(again["result"]["ok"]), "已终局的 Run 不得二次收官")
	assert_eq(str(again["result"].get("reason", "")), "terminal_run")


## 「继续深入」保留：更深的阈值层仍然拦得住早收官（配置能力未被削弱）。
func test_deeper_threshold_still_blocks_early_closure() -> void:
	var controller := _controller()
	controller.catalog["pacing"]["ending_after_stage"] = "three"
	_defeat_layer(controller, 1)
	assert_false(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"L1 不足以解锁 L3 收官")
	_defeat_layer(controller, 3)
	assert_true(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"打掉 L3 关底后开放收官")


## 空阈值（深层机制测试用的"不强制收官"态）＝ 打完任意关底即可主动收官。
func test_empty_threshold_allows_closure_after_first_boss() -> void:
	var controller := _controller()
	controller.catalog["pacing"]["ending_after_stage"] = ""
	assert_false(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"未打关底前仍不可收官")
	_defeat_layer(controller, 1)
	assert_true(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"空阈值下打完关底即可主动收官")
