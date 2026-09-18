extends GutTest

const RuiRoot = preload(
	"res://addons/reactive_ui_toolkit/core/reactive_root.gd"
)
const VLib = preload(
	"res://addons/reactive_ui_toolkit/core/v.gd"
)


func test_unmount_is_idempotent_and_set_root_is_safe_afterwards() -> void:
	var host := Control.new()
	add_child(host)
	var root = RuiRoot.create(
		host,
		VLib.Label({"text": "first"})
	)
	assert_eq(host.get_child_count(), 1)

	root.unmount()
	root.unmount()
	root.set_root(VLib.Label({"text": "ignored"}))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		host.get_child_count(),
		0,
		"unmounted roots must not render again"
	)
	host.free()
