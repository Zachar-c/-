extends RefCounted

# W11 measure 3, atomic A2 (2026-09-10): the rest command family moved out
# of resolver.gd. Extracted verbatim - behavior unchanged.
#
# Dependency direction note: this module calls back into Resolver's shared
# low-level helpers (_accepted/_rejected/_event) and cross-family helpers
# (_cursed_drop_block/_destroyed_gu_payload/_upgrade_card, which live in
# resolver.gd until the A4 refine extraction) via the global class name.
# resolver.gd preloads this script (one-way), so there is no preload cycle.
# Once A4/A5 land, those helpers should graduate to ResolverHelpers and this
# file's Resolver.* call sites can switch over.

const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")


const REST_REMOVAL_MODES := ["remove_card", "remove_imprint", "remove_curse"]
# P2a B: rest visit/mode flags are scoped per node id ("<id>_used"/"<id>_mode")
# so nodes.json may declare more than one rest node. Every consumed visit also
# refreshes the bare "<id>" visited marker (_complete_node idempotency +
# MapGenerator.reachable_nodes, matching every other completed node).
const REST_NODE_TYPE := "rest"
## E3a（2026-09-09 规格事件分类 §4）：休息类三选一——rest/refinement/cultivation
## 统一归入休息类。修炼（meditate / cultivate_rank_two）与炼蛊（refine_gu /
## refine_free_pair）在休息类节点成功执行即消费本次探访（等同 rest 消耗，
## leave 门禁放行）；硬选择门禁仍只锁 type=="rest" 节点（E4c 路由统一时再扩展）。
const REST_CLASS_TYPES := ["rest", "refinement", "cultivation"]


static func _is_rest_node(catalog: Dictionary, node_id: String) -> bool:
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id and str(node.get("type", "")) == REST_NODE_TYPE:
			return true
	return false


## E3a：休息类节点判定（rest/refinement/cultivation；实例 id 或模板 id 皆可命中）。
static func _is_rest_class_node(catalog: Dictionary, node_id: String) -> bool:
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id and REST_CLASS_TYPES.has(str(node.get("type", ""))):
			return true
	return false


static func _rest_visit_key(node_id: String) -> String:
	return "%s_used" % node_id


static func _rest_mode_key(node_id: String) -> String:
	return "%s_mode" % node_id


static func _rest_visit_consumed(state: RunState) -> bool:
	return str(state.node_flags.get(_rest_visit_key(state.current_node_id), "")) == "used"


static func _rest(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# 地图实例 id（L1R1N0）与目录模板 id 不同——休整门禁必须双查：
	# 实例 id 直命中，或实例的 template_id 指向休整模板。
	# E3a 三选一（规格 §4）：休整族命令在休息类（rest/refinement/cultivation）
	# 节点均开放，否则 refinement/cultivation 无法 skip 会与硬门禁互相卡死。
	if not _is_rest_class_node(catalog, state.current_node_id) \
			and not _is_rest_class_node(catalog, str(state.current_node_template_id)):
		return Resolver._rejected(state, "not_rest_node")
	var mode := str(command.get("mode", "heal"))
	if mode == "heal":
		return _rest_heal(state)
	if mode == "upgrade_card":
		return _rest_upgrade(state, command)
	if mode == "skip":
		return _rest_skip(state)
	return _rest_removal(state, command, catalog, mode)


# BUG-001: a player who cannot or will not take any rest benefit still has to
# leave the node. _rest_skip consumes the visit (so the leave gate unblocks)
# and writes a rest_skipped event so the audit log and ending attribution stay
# intact. Pre-check is identical to every other rest mode: same scoped flag.
static func _rest_skip(state: RunState) -> Dictionary:
	if str(state.node_flags.get(_rest_mode_key(state.current_node_id), "")) == "true":
		return Resolver._rejected(state, "rest_mode_already_used")
	if _rest_visit_consumed(state):
		return Resolver._rejected(state, "rest_already_used")
	var consumed := _consume_rest_visit(state)
	return Resolver._accepted(consumed.append_event(Resolver._event(
		consumed,
		"rest",
		{"node_flags": state.node_flags},
		{"node_flags": consumed.node_flags},
		"rest_skipped",
		state.current_node_id,
		[]
	)))


# R8.1 hard choice adds the upgrade option to the rest menu: it reuses the
# standalone upgrade accounting (which is free) and pays with the visit
# instead. Target validation happens before the visit is consumed.
static func _rest_upgrade(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return Resolver._rejected(state, "missing_card_key")
	if str(state.node_flags.get(_rest_mode_key(state.current_node_id), "")) == "true":
		return Resolver._rejected(state, "rest_mode_already_used")
	if _rest_visit_consumed(state):
		return Resolver._rejected(state, "rest_already_used")
	var consumed := _consume_rest_visit(state)
	return Resolver._upgrade_card(consumed, {"card_key": card_key})


static func _rest_heal(state: RunState) -> Dictionary:
	if _rest_visit_consumed(state):
		return Resolver._rejected(state, "rest_already_used")
	var flags := state.node_flags.duplicate(true)
	flags[_rest_visit_key(state.current_node_id)] = "used"
	# Bare-id marker rides along so _complete_node stays an idempotent no-op
	# when leaving (keeps the seeded event stream aligned with the baseline).
	flags[state.current_node_id] = "used"
	var next_health := mini(state.max_health, state.health + maxi(1, int(floor(float(state.max_health) * 0.30))))
	var essence_max := int(state.cave_aperture.get("essence_max", 4))
	var next_essence := mini(essence_max, state.essence + 2)
	var next := state.append_event(Resolver._event(
		state,
		"rest",
		{"health": state.health, "essence": state.essence, "node_flags": state.node_flags},
		{"health": next_health, "essence": next_essence, "node_flags": flags},
		"rest_recovered",
		state.current_node_id,
		[]
	))
	return Resolver._accepted(next)


# R8.1 rest removal is free but consumes the visit (opportunity cost instead
# of money). It never touches the black-market service counters and allows a
# single removal mode per node.
static func _rest_removal(state: RunState, command: Dictionary, catalog: Dictionary, mode: String) -> Dictionary:
	if not REST_REMOVAL_MODES.has(mode):
		return Resolver._rejected(state, "unsupported_rest_mode")
	if str(state.node_flags.get(_rest_mode_key(state.current_node_id), "")) == "true":
		return Resolver._rejected(state, "rest_mode_already_used")
	if _rest_visit_consumed(state):
		return Resolver._rejected(state, "rest_already_used")
	var consumed := _consume_rest_visit(state)
	match mode:
		"remove_card":
			return _rest_remove_card(state, command, catalog, consumed)
		"remove_imprint":
			return _rest_remove_imprint(state, command, catalog, consumed)
		"remove_curse":
			return _rest_remove_curse(state, command, catalog, consumed)
	return Resolver._rejected(state, "unsupported_rest_mode")


static func _consume_rest_visit(state: RunState) -> RunState:
	var flags := state.node_flags.duplicate(true)
	flags[_rest_visit_key(state.current_node_id)] = "used"
	flags[_rest_mode_key(state.current_node_id)] = "true"
	# Same bare-id marker contract as _rest_heal (see comment there).
	flags[state.current_node_id] = "used"
	return state.append_event(Resolver._event(
		state,
		"rest",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"rest_visit_consumed",
		state.current_node_id,
		[]
	))


## E3a：休息类节点上修炼/炼蛊族动作成功执行后消费本次探访（幂等：已消费或
## 非休息类节点原样返回）。这是三选一「执行一次后 leave 放行」的领域支点。
static func _consume_rest_visit_if_rest_class(state: RunState, catalog: Dictionary) -> RunState:
	if _rest_visit_consumed(state):
		return state
	if not _is_rest_class_node(catalog, state.current_node_id) \
			and not _is_rest_class_node(catalog, str(state.current_node_template_id)):
		return state
	return _consume_rest_visit(state)


static func _rest_remove_card(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return Resolver._rejected(state, "gu_instance_unavailable")
	var blocked := Resolver._cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	var payload := Resolver._destroyed_gu_payload(state, instance_id)
	var next := consumed.append_event(Resolver._event(
		consumed,
		"rest",
		{},
		{"gu_instances": payload["instances"], "cave_aperture": payload["aperture"]},
		"rest_removed_gu",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


static func _rest_remove_imprint(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	if not catalog.get("relic_by_id", {}).has(relic_id):
		return Resolver._rejected(state, "unknown_relic")
	if not state.relic_ids.has(relic_id):
		return Resolver._rejected(state, "relic_not_owned")
	if str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule":
		return Resolver._rejected(state, "meta_rule_not_removable")
	var relics := state.relic_ids.duplicate()
	relics.erase(relic_id)
	var meta_rules := state.meta_rules.duplicate(true)
	meta_rules.erase(relic_id)
	var next := consumed.append_event(Resolver._event(
		consumed,
		"rest",
		{"relic_ids": state.relic_ids, "meta_rules": state.meta_rules},
		{"relic_ids": relics, "meta_rules": meta_rules},
		"rest_removed_imprint",
		state.current_node_id,
		[relic_id]
	))
	return Resolver._accepted(next)


static func _rest_remove_curse(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return Resolver._rejected(state, "unknown_curse")
	if CurseRegistryScript.layers_of(state, curse_id) <= 0:
		return Resolver._rejected(state, "curse_not_present")
	return Resolver._accepted(CurseRegistryScript.remove_curse(consumed, curse_id))
