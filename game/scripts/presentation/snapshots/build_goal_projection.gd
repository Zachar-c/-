class_name BuildGoalProjection
extends RefCounted


## Playable Core Loop（2026-09-15）：把「当前构筑目标」做成**纯函数只读投影**。
##
## 目的：让玩家在地图上回答「我当前想做什么 / 还缺什么 / 去哪里能推进」。
##
## 硬性约束（任务书 Phase 1）：
##   - 只投影现有 recipe / inventory / gu_instances / stone，不新增成长线；
##   - 不读、不显示任何内部保底计数（loot_pity / material_pity_by_tier）；
##   - 不写 RunState；
##   - 不复制领域判断：可执行性统一经 refine_command_rules 的同源门禁
##     （recipe_unlocked），缺料/缺石只做只读比较。
##
## 目标选择规则（确定性、可测试；优先级固定）：
##   1. 本流派 promotion 链中「第一条尚未完成」的配方（按 input_min_rank 升序、id 升序）；
##   2. 若链已走完，回退到「已解锁且可执行的关键炼蛊配方」（fixed / advance）；
##   3. 若都没有，返回 available=false（文案「暂无可执行构筑目标」）。

const RefineRulesScript = preload("res://scripts/domain/refine_command_rules.gd")

const RANK_LABELS: Array[String] = ["一转", "二转", "三转", "四转", "五转"]

## 节点类型 → 推进能力分组。只声明「可能推进」的能力，不承诺具体掉落。
const COMBAT_TYPES: Array[String] = ["combat", "pursuit"]
const TRADE_TYPES: Array[String] = ["caravan", "market", "shop"]
const EXECUTE_TYPES: Array[String] = ["refinement"]


## 选定当前构筑目标。返回 {"kind","recipe","chain_index","chain_length"}；
## 无目标返回 {}。纯函数。
static func select_goal(state, catalog: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var school := str(state.get("school"))
	if school.is_empty():
		return {}
	var promotion := _first_unfinished_promotion(state, catalog, school)
	if not promotion.is_empty():
		return promotion
	var fallback := _key_refine_recipe(state, catalog)
	if not fallback.is_empty():
		return fallback
	return {}


## 任务书规定的 build_goal 块。无目标时仍返回同构字典（available=false），
## 让消费侧不必分支判空。
static func build_goal(state, catalog: Dictionary) -> Dictionary:
	var catalog_safe: Dictionary = catalog if catalog != null else {}
	var school := str(state.get("school")) if state != null else ""
	var goal := select_goal(state, catalog_safe)
	if goal.is_empty():
		return {
			"available": false,
			"school": school,
			"title": "暂无可执行构筑目标",
			"recipe_id": "",
			"recipe_kind": "",
			"recipe_name": "",
			"input_gu_id": "",
			"input_gu_name": "",
			"input_instance_id": "",
			"input_gu_ready": false,
			"output_gu_id": "",
			"output_name": "",
			"materials": [],
			"stone_owned": int(state.get("stone")) if state != null else 0,
			"stone_required": 0,
			"missing_materials": [],
			"missing_stone": 0,
			"ready": false,
			"missing_summary": "本流派暂无可推进的配方。",
			"recommended_node_types": [],
			"progress_text": "暂无可执行构筑目标。",
			"chain_index": 0,
			"chain_length": 0,
		}
	var recipe: Dictionary = goal["recipe"]
	var input_gu_ids: Array = recipe.get("input_gu_ids", [])
	var input_gu_id := str(input_gu_ids[0]) if input_gu_ids.size() == 1 else ""
	var output_gu_id := str(recipe.get("output_gu_id", ""))
	var input_instance_id := _refined_instance_for(state, input_gu_id)
	var input_gu_ready := not input_instance_id.is_empty()
	var owned_materials: Dictionary = state.get("materials") if state != null else {}
	var stone_owned := int(state.get("stone")) if state != null else 0
	var evaluated := evaluate_requirements(recipe, owned_materials, stone_owned, input_gu_ready, catalog_safe)
	var output_name := DisplayText.gu(output_gu_id)
	var input_name := DisplayText.gu(input_gu_id)
	var out_rank := int(recipe.get("output_rank", 0))
	if out_rank <= 0:
		var output_def: Dictionary = catalog_safe.get("gu_by_id", {}).get(output_gu_id, {})
		out_rank = int(output_def.get("rank", 0))
	var rank_suffix := _rank_label(out_rank)
	var title := output_name if rank_suffix.is_empty() else "%s（%s）" % [output_name, rank_suffix]
	var chain_index := int(goal.get("chain_index", 0))
	var chain_length := int(goal.get("chain_length", 0))
	return {
		"available": true,
		"school": school,
		"title": title,
		"recipe_id": str(recipe.get("id", "")),
		"recipe_kind": str(recipe.get("kind", "")),
		"recipe_name": "%s → %s" % [input_name, output_name],
		"input_gu_id": input_gu_id,
		"input_gu_name": input_name,
		"input_instance_id": input_instance_id,
		"input_gu_ready": input_gu_ready,
		"output_gu_id": output_gu_id,
		"output_name": output_name,
		"materials": evaluated["materials"],
		"stone_owned": stone_owned,
		"stone_required": int(recipe.get("stone_cost", 0)),
		"missing_materials": evaluated["missing_materials"],
		"missing_stone": evaluated["missing_stone"],
		"ready": evaluated["ready"],
		"missing_summary": evaluated["missing_summary"],
		"recommended_node_types": _recommended_types(evaluated["missing_materials"],
				evaluated["missing_stone"], input_gu_ready),
		"progress_text": evaluated["progress_text"],
		"chain_index": chain_index,
		"chain_length": chain_length,
	}


## 单条配方的「需求视图」：给炼蛊台逐条展示成本与缺失项（Phase 4）。
## `executable` = 领域门禁会放行的条件（元石 / 材料 / 输入蛊），不含成功率的随机部分。
static func requirement_view(recipe: Dictionary, state, catalog: Dictionary) -> Dictionary:
	var catalog_safe: Dictionary = catalog if catalog != null else {}
	var inputs: Array = recipe.get("input_gu_ids", [])
	var input_gu_id := str(inputs[0]) if inputs.size() == 1 else ""
	var input_instance := _refined_instance_for(state, input_gu_id)
	var owned_materials: Dictionary = state.get("materials") if state != null else {}
	var stone := int(state.get("stone")) if state != null else 0
	var evaluated := evaluate_requirements(recipe, owned_materials, stone,
			not input_instance.is_empty(), catalog_safe)
	var missing: Array[String] = []
	if not input_gu_id.is_empty() and input_instance.is_empty():
		missing.append("输入蛊 %s" % DisplayText.gu(input_gu_id))
	for material_name in evaluated["missing_materials"]:
		missing.append("材料 %s" % str(material_name))
	var missing_stone := int(evaluated["missing_stone"])
	if missing_stone > 0:
		missing.append("元石 ×%d" % missing_stone)
	return {
		"executable": bool(evaluated["ready"]),
		"materials": evaluated["materials"],
		"missing": missing,
		"missing_summary": "、".join(missing),
		"stone_owned": stone,
		"stone_required": int(recipe.get("stone_cost", 0)),
		"input_gu_id": input_gu_id,
		"input_gu_name": DisplayText.gu(input_gu_id) if not input_gu_id.is_empty() else "",
		"input_instance_id": input_instance,
		"input_owned": not input_instance.is_empty(),
		"output_gu_id": str(recipe.get("output_gu_id", "")),
		"output_name": DisplayText.gu(str(recipe.get("output_gu_id", ""))),
	}


## 按**显式给定的库存**评估一条配方的需求（纯函数）。
##
## 与 build_goal 共用同一套规则，供 Reward 屏用「战利品入账前」的库存重算
## before/after —— 避免第二处复制「什么算就绪」的判断。
## `owned_materials` 形如 {material_id: count}；`stone` 为元石数；`input_ready` 为输入蛊是否在手。
static func evaluate_requirements(recipe: Dictionary, owned_materials: Dictionary, stone: int,
		input_ready: bool, catalog: Dictionary) -> Dictionary:
	var catalog_safe: Dictionary = catalog if catalog != null else {}
	var material_cost: Dictionary = recipe.get("materials", {})
	var stone_required := int(recipe.get("stone_cost", 0))
	var rows := _material_rows(owned_materials, material_cost, catalog_safe)
	var missing_materials: Array[String] = []
	for row in rows:
		if not bool(row["complete"]):
			missing_materials.append(str(row["name"]))
	var missing_stone := maxi(0, stone_required - stone)
	var ready := missing_materials.is_empty() and missing_stone == 0 and input_ready
	return {
		"materials": rows,
		"missing_materials": missing_materials,
		"missing_stone": missing_stone,
		"ready": ready,
		"missing_summary": _missing_summary(missing_materials, missing_stone, input_ready),
		"progress_text": _progress_text(rows, stone, stone_required, input_ready, ready),
	}


## 节点「与当前目标的关系」。只表达「可能推进 / 可执行 / 无直接关系」，
## 不承诺掉落、不反推未揭示节点的内容。
## `precomputed_goal` 允许调用方复用同一份 build_goal（地图逐节点调用时避免 O(nodes×recipes) 重算）。
## 返回 {"code": "advance"|"execute"|"trade"|"none"|"unknown", "text": String}。
static func node_relevance(node: Dictionary, state, catalog: Dictionary,
		precomputed_goal: Dictionary = {}) -> Dictionary:
	if node.is_empty():
		return {"code": "none", "text": "与当前目标无直接关系"}
	if not bool(node.get("revealed", true)):
		# 未揭示节点：不给任何可反推内容的提示。
		return {"code": "unknown", "text": "未知 · 进入后揭示"}
	var goal: Dictionary = precomputed_goal
	if goal.is_empty():
		goal = build_goal(state, catalog)
	if not bool(goal.get("available", false)):
		return {"code": "none", "text": "与当前目标无直接关系"}
	var node_type := str(node.get("type", ""))
	var missing_materials: Array = goal.get("missing_materials", [])
	var missing_stone := int(goal.get("missing_stone", 0))
	var input_ready := bool(goal.get("input_gu_ready", false))
	if COMBAT_TYPES.has(node_type):
		if not missing_materials.is_empty():
			return {"code": "advance", "text": "可能获得缺少的材料（不保证掉落）"}
		if missing_stone > 0:
			return {"code": "advance", "text": "可能获得元石（不保证掉落）"}
		return {"code": "none", "text": "与当前目标无直接关系"}
	if EXECUTE_TYPES.has(node_type):
		if bool(goal.get("ready", false)):
			return {"code": "execute", "text": "可执行当前构筑目标：%s" % str(goal.get("title", ""))}
		return {"code": "execute", "text": "炼蛊台：当前目标尚未就绪，可查看成本明细"}
	if TRADE_TYPES.has(node_type):
		if not input_ready:
			return {"code": "trade", "text": "可购买或交换推进目标所需的蛊虫与材料"}
		if not missing_materials.is_empty():
			return {"code": "trade", "text": "可购买或交换缺少的材料"}
		return {"code": "none", "text": "与当前目标无直接关系"}
	return {"code": "none", "text": "与当前目标无直接关系"}


# ---------------------------------------------------------------- 目标选择

## 本流派 promotion 链中第一条「尚未完成」的配方。
## 「完成」= 已持有该配方的产出蛊定义（任意实例状态）。
static func _first_unfinished_promotion(state, catalog: Dictionary, school: String) -> Dictionary:
	var prefix := "promote_%s_" % school
	var recipes: Array[Dictionary] = []
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "promotion":
			continue
		if not str(recipe.get("id", "")).begins_with(prefix):
			continue
		if not RefineRulesScript.recipe_unlocked(state, recipe):
			continue
		recipes.append(recipe)
	if recipes.is_empty():
		return {}
	recipes.sort_custom(_recipe_order)
	var owned := _owned_definition_ids(state)
	for index in recipes.size():
		var recipe: Dictionary = recipes[index]
		if not owned.has(str(recipe.get("output_gu_id", ""))):
			return {
				"kind": "promotion",
				"recipe": recipe,
				"chain_index": index + 1,
				"chain_length": recipes.size(),
			}
	return {}


## 回退：已解锁、输入蛊在手、且当前可执行的关键炼蛊配方（fixed / advance）。
static func _key_refine_recipe(state, catalog: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		var kind := str(recipe.get("kind", ""))
		if kind != "fixed" and kind != "advance":
			continue
		if not RefineRulesScript.recipe_unlocked(state, recipe):
			continue
		var inputs: Array = recipe.get("input_gu_ids", [])
		if inputs.size() != 1:
			continue
		if _refined_instance_for(state, str(inputs[0])).is_empty():
			continue
		candidates.append(recipe)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(_recipe_order)
	var recipe_pick: Dictionary = candidates[0]
	return {"kind": "refine", "recipe": recipe_pick, "chain_index": 0, "chain_length": 0}


static func _recipe_order(a: Dictionary, b: Dictionary) -> bool:
	var ra := int(a.get("input_min_rank", 1))
	var rb := int(b.get("input_min_rank", 1))
	if ra != rb:
		return ra < rb
	return str(a.get("id", "")) < str(b.get("id", ""))


# ---------------------------------------------------------------- 只读派生

static func _owned_definition_ids(state) -> Dictionary:
	var owned := {}
	if state == null:
		return owned
	for instance_value in state.get("gu_instances").values():
		var instance: Dictionary = instance_value
		if str(instance.get("state", "")) == "dead":
			continue
		owned[str(instance.get("definition_id", ""))] = true
	return owned


## 蛊仓（cave_aperture）中第一个匹配定义且已炼成的实例 ID；无则空串。
static func _refined_instance_for(state, definition_id: String) -> String:
	if state == null or definition_id.is_empty():
		return ""
	for stored_value in state.get("cave_aperture").get("stored_gu_instance_ids", []):
		var instance_id := str(stored_value)
		var instance: Dictionary = state.get("gu_instances").get(instance_id, {})
		if str(instance.get("definition_id", "")) != definition_id:
			continue
		if str(instance.get("state", "")) != "refined":
			continue
		return instance_id
	return ""


static func _material_rows(owned_materials: Dictionary, material_cost: Dictionary,
		catalog: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var material_defs: Dictionary = catalog.get("material_by_id", {})
	var owned_map: Dictionary = owned_materials if owned_materials != null else {}
	var ids: Array[String] = []
	for material_id_value in material_cost:
		ids.append(str(material_id_value))
	ids.sort()
	for material_id in ids:
		var required := int(material_cost[material_id])
		var owned := int(owned_map.get(material_id, 0))
		var definition: Dictionary = material_defs.get(material_id, {})
		var display := str(definition.get("name_zh", ""))
		if display.is_empty():
			display = str(definition.get("name", ""))
		if display.is_empty():
			display = DisplayText.material(material_id)
		rows.append({
			"id": material_id,
			"name": display,
			"owned": owned,
			"required": required,
			"complete": owned >= required,
		})
	return rows


static func _missing_summary(missing_materials: Array[String], missing_stone: int,
		input_gu_ready: bool) -> String:
	var parts: Array[String] = []
	if not input_gu_ready:
		parts.append("缺少输入蛊")
	for name in missing_materials:
		parts.append("缺 %s" % name)
	if missing_stone > 0:
		parts.append("缺元石 ×%d" % missing_stone)
	if parts.is_empty():
		return "条件已满足，可前往炼蛊台执行。"
	return " · ".join(parts)


static func _recommended_types(missing_materials: Array[String], missing_stone: int,
		input_gu_ready: bool) -> Array[String]:
	var types: Array[String] = []
	if not input_gu_ready:
		for trade_type in TRADE_TYPES:
			types.append(trade_type)
	if not missing_materials.is_empty() or missing_stone > 0:
		for combat_type in COMBAT_TYPES:
			types.append(combat_type)
	for execute_type in EXECUTE_TYPES:
		types.append(execute_type)
	return types


static func _progress_text(rows: Array[Dictionary], stone_owned: int,
		stone_required: int, input_gu_ready: bool, ready: bool) -> String:
	if ready:
		return "材料与元石已就绪，输入蛊在手 —— 前往炼蛊台执行。"
	var segments: Array[String] = []
	for row in rows:
		segments.append("%s %d/%d" % [str(row["name"]), int(row["owned"]), int(row["required"])])
	segments.append("元石 %d/%d" % [stone_owned, stone_required])
	segments.append("输入蛊%s" % ("已拥有" if input_gu_ready else "缺失"))
	return " · ".join(segments)


static func _rank_label(rank: int) -> String:
	if rank < 1 or rank > RANK_LABELS.size():
		return ""
	return RANK_LABELS[rank - 1]
