extends "res://addons/gut/test.gd"


# Exit flow (A6 settings -> quit): the command surface exposes quit, and the
# controller records the request. quit_game only touches SceneTree when a real
# runtime tree exists, so headless/GUT runs are never terminated.


const RunCommandBuilderScript := preload("res://scripts/presentation/run_command_builder.gd")
const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")


func test_title_command_surface_exposes_quit() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var commands := RunCommandBuilderScript.for_screen("Title", controller)
	assert_true(commands.has("quit"), "Title must expose a quit command")


func test_quit_command_requests_exit_without_killing_test_tree() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var commands := RunCommandBuilderScript.for_screen("Title", controller)
	commands["quit"].call()
	assert_true(controller.quit_requested, "quit command must flag the exit request")
	assert_false(controller.is_inside_tree(), "controller never attached in tests, tree untouched")


func test_request_quit_only_flags() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.request_quit()
	assert_true(controller.quit_requested)
	assert_false(controller.is_inside_tree(), "controller never attached in tests")