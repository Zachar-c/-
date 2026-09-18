class_name RecipeRules
extends RefCounted


# Spec-v4 phase-2 (T5.2): unified recipe rules - deterministic success
# (§5.3), deterministic candidate selection (§5.2) and identity-bound
# substitution (§5.4). Zero dice: a known recipe never rolls and never eats
# inputs; tag recipes pick from the hand-authored pool in declaration order;
# identity binds by name - equivalent materials and yuanstone never
# substitute unless allow_substitute declares the relation, and the swap
# travels with its declared cost/condition/product changes.


# §5.3: a known ordinary recipe succeeds deterministically whenever the
# conditions are complete, safe and uninterrupted - no roll, no swallowed
# inputs. Failure comes only from declared conditions.
static func known_fixed_success(recipe: Dictionary, inputs_ready: bool, unlocked: bool, interrupted: bool) -> Dictionary:
	if not unlocked:
		return {"ok": false, "reason": "recipe_locked"}
	if not inputs_ready:
		return {"ok": false, "reason": "inputs_incomplete"}
	if interrupted:
		return {"ok": false, "reason": "interrupted"}
	return {"ok": true, "reason": "", "success": true, "swallowed_inputs": false}


# §5.2: a tag recipe resolves its candidates deterministically from the
# hand-authored pool, in declaration order - never shuffled, never generated.
# Candidate ids missing from gu.json are schema-rejected at load; this pass
# filters defensively anyway.
static func resolve_candidates(recipe: Dictionary, catalog: Dictionary) -> Array:
	var out: Array = []
	for gu_id_value in recipe.get("candidate_pool", []):
		var gu_id := str(gu_id_value)
		if catalog.get("gu_by_id", {}).has(gu_id):
			out.append(gu_id)
	return out


# §5.4 identity gate. offered_definitions: the provided gu definition ids;
# offered_ranks: definition id -> rank; offered_materials: material id ->
# count. Named requirements must be met exactly; an undeclared swap is a
# rejection; a declared allow_substitute swap passes and reports both the
# substitution record and the recipe's cost_change.
static func check_identity(recipe: Dictionary, offered_definitions: Array, offered_materials: Dictionary, offered_ranks: Dictionary, catalog: Dictionary, offered_media: Array = []) -> Dictionary:
	var identity: Dictionary = recipe.get("identity_requirements", {})
	var substitutions: Array = []
	for required_value in identity.get("named_gu_ids", []):
		if not offered_definitions.has(str(required_value)):
			return {"ok": false, "reason": "named_gu_not_offered", "detail": str(required_value)}
	for required_value in identity.get("dao_tags", []):
		var matched := false
		for definition_id in offered_definitions:
			var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
			if (definition.get("tags", []) as Array).has(str(required_value)):
				matched = true
				break
		if not matched:
			return {"ok": false, "reason": "dao_tag_not_offered", "detail": str(required_value)}
	var declared: Dictionary = recipe.get("allow_substitute", {}).get("materials", {})
	for required_value in identity.get("named_materials", []):
		var required := str(required_value)
		if int(offered_materials.get(required, 0)) >= 1:
			continue
		var alternatives: Array = declared.get(required, [])
		var found := ""
		for alternative_value in alternatives:
			if int(offered_materials.get(str(alternative_value), 0)) >= 1:
				found = str(alternative_value)
				break
		if found.is_empty():
			return {"ok": false, "reason": "named_material_missing", "detail": required}
		substitutions.append({"from": required, "to": found})
	var declared_media: Dictionary = recipe.get("allow_substitute", {}).get("media", {})
	for required_value in identity.get("named_media", []):
		var required := str(required_value)
		if offered_media.has(required):
			continue
		var media_alternatives: Array = declared_media.get(required, [])
		var found_media := ""
		for alternative_value in media_alternatives:
			if offered_media.has(str(alternative_value)):
				found_media = str(alternative_value)
				break
		if found_media.is_empty():
			return {"ok": false, "reason": "named_media_missing", "detail": required}
		substitutions.append({"from": required, "to": found_media})
	var min_rank := int(identity.get("min_rank", 0))
	if min_rank > 0:
		var highest := 0
		for definition_id in offered_definitions:
			highest = maxi(highest, int(offered_ranks.get(str(definition_id), 1)))
		if highest < min_rank:
			return {"ok": false, "reason": "min_rank_not_met", "detail": str(min_rank)}
	return {
		"ok": true,
		"reason": "",
		"substitutions": substitutions,
		"cost_change": (recipe.get("allow_substitute", {}) as Dictionary).get("cost_change", {}),
	}
