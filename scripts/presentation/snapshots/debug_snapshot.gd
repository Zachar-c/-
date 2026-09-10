class_name DebugSnapshot
extends RefCounted


# W12 split: the debug panel read-only snapshot (§16.22), moved verbatim from
# run_snapshot_builder.gd.


const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")


## T5-D 调试面板只读段（§16.22）：保底计数 / 池排除列表 / 当前种子 / 事件数 / DDA 分位。
## 数据形状对齐 DebugActions.query_loot_state 返回的 pity/excluded 结构。
## 仅由 debug_panel 渲染，绝不反向写入状态。
static func build(controller) -> Dictionary:
	var state = controller.state
	if state == null:
		return {}
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	return {
		"pity": {
			"loot_pity": int(state.loot_pity),
			"material_pity": int(state.material_pity),
			"synthesis_fail_streak": int(state.synthesis_fail_streak),
		},
		"excluded": [] as Array,
		"seed": int(state.seed),
		"event_count": state.event_log.size(),
		"dda_percentile": DdaResolverScript.score_label(state, catalog),
	}
