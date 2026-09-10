class_name RefineSnapshot
extends RefCounted


# W12 split: the Refine (synthesis) screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; multi-screen shared helpers
# stay on RunSnapshotBuilder and are called via the global class name.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const SynthesisRulesScript = preload("res://scripts/domain/synthesis_rules.gd")


## C6 炼蛊 / 合成屏快照（refinement_by_id 真实配方 + 盲盒）。
## 2026-08-28 验收批：配方行带 channel 标签供屏内过滤（通道切换是展示层状态，
## 不再发幽灵命令 refine_channel）；slot_ok 用 DeckCapacity 真实空位校验
## （旧值恒 false，确认按钮永久禁用）；拆解槽列真实蛊囊（destroy_gu）；
## 盲盒通道即 free_mix 真实配方（空选择时领域自动投入全部已炼成蛊）。
static func build(controller) -> Dictionary:
	var out := RunSnapshotBuilder._gui_state(controller)
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var recipe_by_id: Dictionary = catalog.get("refinement_by_id", {})
	var rec_rows: Array[Dictionary] = []
	for recipe_key in recipe_by_id:
		var r: Dictionary = recipe_by_id[recipe_key]
		var kind := str(r.get("kind", "combine"))
		var inputs: Array = r.get("input_gu_ids", [])
		var in_names: Array[String] = []
		for iid in inputs:
			in_names.append(DisplayText.gu(str(iid)))
		var output := DisplayText.gu(str(r.get("output_gu_id", "")))
		var fail := "成功配方"
		if r.has("success_roll_max"):
			fail = "失败率 %d%%" % (100 - int(r.get("success_roll_max", 100)))
		# 产出转数标注：advance 跟输入蛊走（+1 封顶五转），其余优先配方
		# output_rank，缺省回退产出蛊本体定义。
		var rank_note := ""
		if kind == "advance":
			rank_note = "产出转数 = 输入转数 + 1（封顶五转）"
		else:
			var output_gu: Dictionary = catalog.get("gu_by_id", {}).get(str(r.get("output_gu_id", "")), {})
			var out_rank := int(r.get("output_rank", int(output_gu.get("rank", 1))))
			rank_note = "产出 %s" % RunSnapshotBuilder._rank_label(clampi(out_rank, 1, 5))
		# 解锁旗标与执行/预览共用 Resolver.recipe_unlocked：fixed/combine 须持有
		# 蛊方（default_unlocked 豁免，advance/free_mix 不设门禁）。
		var recipe_unlocked: bool = state != null \
				and ResolverScript.recipe_unlocked(state, r)
		if state == null:
			recipe_unlocked = str(r.get("kind", "combine")) == "advance" \
					or bool(r.get("default_unlocked", false))
		rec_rows.append({
			"id": str(recipe_key),
			"channel": "combine" if kind == "combine" else "fixed",
			"name": " + ".join(in_names) + " → " + output,
			"output": output,
			"rank_note": rank_note,
			"quality": "稀有",
			"fail_chance": fail,
			"backlash": "失败毁材 · 躁动 +1" if kind == "combine" else "无躁动",
			"curse": "",
			"unlocked": recipe_unlocked,
		})
	var free_mix: Dictionary = recipe_by_id.get("free_mix", {})
	if not free_mix.is_empty():
		var blind_fail := "成功配方"
		if free_mix.has("success_roll_max"):
			blind_fail = "失败率 %d%%" % (100 - int(free_mix.get("success_roll_max", 100)))
		rec_rows.append({
			"id": "free_mix",
			"channel": "blind",
			"name": "盲盒 · 自由组合（随机产物）",
			"output": "未知蛊",
			"quality": "随机",
			"fail_chance": blind_fail,
			"backlash": "炸炉按结果表结算（气血/魂魄/寿元）",
			"curse": "诅咒继承⚠",
			"unlocked": true,
		})
	out["title"] = "炼蛊台"
	out["channels"] = [
		{"id": "fixed", "label": "定向配方"},
		{"id": "combine", "label": "组合标签"},
		{"id": "free_pair", "label": "自由配对"},
		{"id": "blind", "label": "盲盒随机"},
	]
	# E4a 炼蛊子屏语境：从休息屏「炼蛊」卡进入时，「离开」退回休息屏而非
	# 结束探访；initial_channel 用于预选自由配对等通道（用户手动切 Tab 后失效）。
	# 用 get() 兜底：测试侧的 Dictionary stub（非 RunController 实例）没有这两个
	# 属性；缺键返回 null，不能直接 bool()/str() 收敛（null 会报 Nonexistent
	# constructor），改用 == 比较与显式空串回退。
	var subview_flag = controller.get("_refine_from_rest")
	out["from_rest"] = subview_flag == true
	var subview_channel = controller.get("_refine_initial_channel")
	out["initial_channel"] = "" if subview_channel == null else str(subview_channel)
	# 古方知识模型：自由配对（主+辅，同转）——零门槛试炼，产物按知识状态揭示。
	var pair_candidates: Array[Dictionary] = []
	if state != null:
		for pair_instance_key in state.cave_aperture.get("stored_gu_instance_ids", []):
			var pair_inst: Dictionary = state.gu_instances.get(str(pair_instance_key), {})
			var pair_def: Dictionary = catalog.get("gu_by_id", {}).get(str(pair_inst.get("definition_id", "")), {})
			if pair_def.is_empty() or str(pair_inst.get("state", "")) == "dead":
				continue
			pair_candidates.append({
				"id": str(pair_instance_key),
				"name": DisplayText.gu(str(pair_inst.get("definition_id", ""))),
				"rank": int(pair_def.get("rank", 0)),
				"school": str(pair_def.get("school", "")),
			})
	out["pair_candidates"] = pair_candidates
	out["pair_main"] = str(controller._selected_pair_main)
	out["pair_partner"] = str(controller._selected_pair_partner)
	var pair_preview: Dictionary = {}
	if state != null:
		pair_preview = SynthesisRulesScript.pair_preview(state, catalog, str(controller._selected_pair_main), str(controller._selected_pair_partner))
	out["pair_preview"] = pair_preview
	out["slot_ok"] = true
	out["blind_note"] = "盲盒自动投入全部已炼成蛊虫（至少 %d 只），产物与炸炉代价按种子结算。" % int(free_mix.get("min_inputs", 2))
	out["recipes"] = rec_rows
	var dismantle_slots: Array[Dictionary] = []
	if state != null:
		for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if instance.is_empty() or str(instance.get("state", "")) == "dead":
				continue
			var dismantle_gu: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			if not bool(dismantle_gu.get("can_direct_drop", true)):
				continue
			dismantle_slots.append({"id": str(instance_id_value), "name": DisplayText.gu(str(instance.get("definition_id", "")))})
	out["dismantle_slots"] = dismantle_slots
	out["streak_note"] = "连续失败计数 Run 内清零，成功率加成永不到 100%"
	return out
