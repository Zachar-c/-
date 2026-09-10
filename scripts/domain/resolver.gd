class_name Resolver
extends RefCounted

# ponytail: W11 m3（A1--A5，2026-09-10）命令族拆分已落地——rest/shop/refine/
# social 四模块承载具体 handler，resolver 261 行纯路由核心（apply/_handler_for/
# 薄转发/跨族桥接 + 共享 helper）。行数门限 1200 保留为任何 domain 单文件护栏；
# 升级触发=任一 domain 文件撞门限时继续按命令族抽模块。


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const InheritanceClaimRulesScript = preload("res://scripts/domain/inheritance_claim_rules.gd")
const SynthesisRulesScript = preload("res://scripts/domain/synthesis_rules.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_rules.gd")
const ResolverHelpersScript = preload("res://scripts/domain/resolver_helpers.gd")
const RestRulesScript = preload("res://scripts/domain/rest_rules.gd")
const ShopCommandRulesScript = preload("res://scripts/domain/shop_command_rules.gd")
const RefineCommandRulesScript = preload("res://scripts/domain/refine_command_rules.gd")
const SocialCommandRulesScript = preload("res://scripts/domain/social_command_rules.gd")
const RunCommandsScript = preload("res://scripts/domain/run_command_rules.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
# GuBalance 为 class_name 静态公式模块，直接按全局类名调用。


# R4.8: meta-rule grade imprints are rule changers; cap per run lives in deck.json.
# Removal service base prices (Task 5, R6.8) live in deck.json.

# Forced drop of a can_direct_drop=false gu attaches this configured curse.
const FORCED_DROP_CURSE_ID := "gu_erosion"


## 公开价格 API 转发（W11 A3）：实现迁至 shop_command_rules.gd。
## 外部调用点（snapshot_builder/acceptance_driver/测试）经 ResolverScript 引用，
## 签名不变，仅加一行转发。
static func shop_layer_price(catalog: Dictionary, state: RunState, base: int) -> int:
	return ShopCommandRulesScript.shop_layer_price(catalog, state, base)


static func shop_max_tier(state: RunState, catalog: Dictionary) -> int:
	return ShopCommandRulesScript.shop_max_tier(state, catalog)


## 公开 API 转发（W11 A4）：实现迁至 refine_command_rules.gd。
## 外部调用点（action_preview_service / snapshot_builder / 测试）经
## ResolverScript 引用，签名不变，仅加一行转发。
static func recipe_unlocked(state: RunState, recipe: Dictionary) -> bool:
	return RefineCommandRulesScript.recipe_unlocked(state, recipe)


static func scavenge_pending_recipes(state: RunState, catalog: Dictionary) -> Array[String]:
	return RefineCommandRulesScript.scavenge_pending_recipes(state, catalog)


static func service_use_count(state: RunState, service_id: String) -> int:
	return RefineCommandRulesScript.service_use_count(state, service_id)


static func service_limit(catalog: Dictionary, service_id: String) -> int:
	return RefineCommandRulesScript.service_limit(catalog, service_id)


static func service_price_for(catalog: Dictionary, state: RunState, service_id: String, base: int) -> int:
	return RefineCommandRulesScript.service_price_for(catalog, state, service_id, base)


## 跨族桥接（W11 A3/A4）：rest_rules ↔ refine_command_rules 互不 preload
## （避免循环），均经 Resolver 转发。rest 依赖的 refine 移除链与 refine
## 依赖的 rest 类门禁在此薄转发。
static func _upgrade_card(state: RunState, command: Dictionary) -> Dictionary:
	return RefineCommandRulesScript._upgrade_card(state, command)


static func _cursed_drop_block(state: RunState, catalog: Dictionary, definition_id: String) -> Dictionary:
	return RefineCommandRulesScript._cursed_drop_block(state, catalog, definition_id)


static func _destroyed_gu_payload(state: RunState, instance_id: String, extracted: Dictionary = {}) -> Dictionary:
	return RefineCommandRulesScript._destroyed_gu_payload(state, instance_id, extracted)


static func _is_rest_class_node(catalog: Dictionary, node_id: String) -> bool:
	return RestRulesScript._is_rest_class_node(catalog, node_id)


## 公开 API 转发（W11 A5）：实现迁至 social_command_rules.gd。
## 外部调用点（tests / refine_command_rules / shop_command_rules）经
## ResolverScript 引用，签名不变，仅加一行转发。
static func apply_social_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	return SocialCommandRulesScript.apply_social_action(state, command, catalog)


static func _can_gain_relic(state: RunState, catalog: Dictionary, relic_id: String) -> String:
	return SocialCommandRulesScript._can_gain_relic(state, catalog, relic_id)


static func _grant_lifespan_milestone(state: RunState, catalog: Dictionary, milestone_id: String) -> RunState:
	return SocialCommandRulesScript._grant_lifespan_milestone(state, catalog, milestone_id)


static func apply(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, "terminal_run")
	var handler: Variant = _handler_for(str(command.get("type", "")))
	if handler == null:
		return _rejected(state, "unsupported_command")
	return handler.call(state, command, catalog)


static var _dispatch: Dictionary = {}


static func _handler_for(command_type: String) -> Variant:
	if _dispatch.is_empty():
		_dispatch = {
			"travel": func(state, command, catalog): return SocialCommandRulesScript._travel(state, command, catalog),
			"resolve_contact": func(state, command, catalog): return SocialCommandRulesScript._resolve_contact(state, command, catalog),
			"complete_node": func(state, command, _catalog): return SocialCommandRulesScript._complete_node(state, command),
			"buy_gu": func(state, command, catalog): return RefineCommandRulesScript._buy_gu(state, command, catalog),
			"sell_gu": func(state, command, catalog): return RefineCommandRulesScript._sell_gu(state, command, catalog),
			"exchange_gu": func(state, command, catalog): return RefineCommandRulesScript._exchange_gu(state, command, catalog),
			"refine_gu": func(state, command, catalog):
				var refined := RefineCommandRulesScript._refine_gu(state, command, catalog)
				if bool(refined["result"].get("ok", false)):
					refined["state"] = RestRulesScript._consume_rest_visit_if_rest_class(refined["state"], catalog)
				return refined,
			"refine_free_pair": func(state, command, catalog):
				var paired := SynthesisRulesScript.execute(state, catalog, str(command.get("main_instance_id", "")), str(command.get("partner_instance_id", "")))
				if bool(paired["result"].get("ok", false)):
					paired["state"] = RestRulesScript._consume_rest_visit_if_rest_class(paired["state"], catalog)
				return paired,
			"cultivate_rank_two": func(state, _command, catalog):
				var cultivated := RefineCommandRulesScript._cultivate_rank_two(state, catalog)
				if bool(cultivated["result"].get("ok", false)):
					cultivated["state"] = RestRulesScript._consume_rest_visit_if_rest_class(cultivated["state"], catalog)
				return cultivated,
			"settle_feeding": func(state, _command, catalog): return RefineCommandRulesScript._settle_feeding(state, catalog),
			"settle_node_feeding": func(state, _command, catalog): return RefineCommandRulesScript._settle_node_feeding(state, catalog),
			"disable_card": func(state, command, _catalog): return RefineCommandRulesScript._disable_card(state, command),
			"upgrade_card": func(state, command, _catalog): return RefineCommandRulesScript._upgrade_card(state, command),
			"copy_card": func(state, command, _catalog): return RefineCommandRulesScript._copy_card(state, command),
			"destroy_gu": func(state, command, catalog): return RefineCommandRulesScript._destroy_gu(state, command, catalog),
			"remove_card": func(state, command, catalog): return RefineCommandRulesScript._remove_card_command(state, command, catalog),
			"remove_imprint": func(state, command, catalog): return RefineCommandRulesScript._remove_imprint_command(state, command, catalog),
			"spend_lifespan": func(state, command, _catalog): return SocialCommandRulesScript._spend_lifespan(state, command),
			"accept_debt": func(state, _command, catalog): return SocialCommandRulesScript._accept_debt(state, catalog),
			"use_gu": func(state, command, catalog): return SocialCommandRulesScript._use_gu(state, command, catalog),
			"buy_opportunity": func(state, command, _catalog): return SocialCommandRulesScript._buy_opportunity(state, command),
			"take_body_imprint": func(state, command, _catalog): return SocialCommandRulesScript._take_body_imprint(state, command),
			"choose_action": func(state, command, catalog): return SocialCommandRulesScript._choose_action(state, command, catalog),
			"retreat": func(state, _command, _catalog): return SocialCommandRulesScript._retreat(state),
			"attempt_ascension": func(state, command, _catalog): return SocialCommandRulesScript._attempt_ascension(state, command),
			"gain_relic": func(state, command, catalog): return SocialCommandRulesScript._gain_relic(state, command, catalog),
			"shop_purchase": func(state, command, catalog): return ShopCommandRulesScript._shop_purchase(state, command, catalog),
			"shop_lifespan_deal": func(state, command, catalog): return ShopCommandRulesScript._shop_lifespan_deal(state, command, catalog),
			"shop_barter": func(state, command, catalog): return ShopCommandRulesScript._shop_barter(state, command, catalog),
			"npc_trade": func(state, command, catalog): return SocialCommandRulesScript._npc_trade(state, command, catalog),
			"scavenge": func(state, command, catalog): return RefineCommandRulesScript._scavenge(state, command, catalog),
			"sell_material": func(state, command, catalog): return RefineCommandRulesScript._sell_material(state, command, catalog),
			"use_material": func(state, command, catalog): return RefineCommandRulesScript._use_material(state, command, catalog),
			"raise_aptitude": func(state, command, catalog): return ShopCommandRulesScript._raise_aptitude(state, command, catalog),
			"record_neutral_npc_kill": func(state, _command, catalog): return SocialCommandRulesScript._record_neutral_npc_kill(state, catalog),
			"wash_notoriety": func(state, _command, catalog): return SocialCommandRulesScript._wash_notoriety(state, catalog),
			"record_boss_defeated": func(state, _command, catalog): return SocialCommandRulesScript._record_boss_defeated(state, catalog),
			"record_layer_boss_defeated": func(state, command, catalog): return SocialCommandRulesScript._record_layer_boss_defeated(state, command, catalog),
			"rest": func(state, command, catalog): return RestRulesScript._rest(state, command, catalog),
			"gain_force_power": func(state, command, catalog): return SocialCommandRulesScript._gain_force_power(state, command, catalog),
			"accept_event": func(state, command, catalog): return SocialCommandRulesScript._accept_event(state, command, catalog),
			"gain_curse": func(state, command, catalog): return SocialCommandRulesScript._gain_curse_command(state, command, catalog),
			"remove_curse": func(state, command, catalog): return SocialCommandRulesScript._remove_curse_command(state, command, catalog),
			"swear_contracts": func(state, command, catalog): return SocialCommandRulesScript._swear_contracts(state, command, catalog),
			# T9.2 v2 command family - thin dispatch to RunCommands (rules live
			# in the phase 1-8 modules; V1 battle path untouched, switch at T10.1-6).
			"confirm_core": func(state, command, catalog): return RunCommandsScript.confirm_core(state, command, catalog),
			"replace_core": func(state, command, catalog): return RunCommandsScript.replace_core(state, command, catalog),
			"feed_instance": func(state, command, catalog): return RunCommandsScript.feed_instance(state, command, catalog),
			"settle_layer": func(state, command, catalog): return RunCommandsScript.settle_layer(state, command, catalog),
			"collect_surviving": func(state, command, catalog): return RunCommandsScript.collect_surviving(state, command, catalog),
			"release_gu": func(state, command, catalog): return RunCommandsScript.release_gu(state, command, catalog),
			"sell_info": func(state, command, catalog): return RunCommandsScript.sell_info(state, command, catalog),
			"enact": func(state, command, catalog): return RunCommandsScript.enact(state, command, catalog),
			"dodge": func(state, command, catalog): return RunCommandsScript.dodge(state, command, catalog),
			"grapple": func(state, command, catalog): return RunCommandsScript.grapple(state, command, catalog),
			"respond": func(state, command, catalog): return RunCommandsScript.respond(state, command, catalog),
			"refine_up_material": func(state, command, catalog): return RunCommandsScript.refine_up_material(state, command, catalog),
			"bloodlet": func(state, command, catalog): return RunCommandsScript.bloodlet(state, command, catalog),
			"absorb_soul": func(state, command, catalog): return RunCommandsScript.absorb_soul(state, command, catalog),
		}
	return _dispatch.get(command_type, null)


static func _finalize_if_dead(state: RunState) -> Dictionary:
	if state.health > 0 and int(state.cultivator.get("lifespan", 0)) > 0 and int(state.cultivator.get("soul", 0)) > 0:
		return _accepted(state)
	return _accepted(state.finalize_death())


static func _event(
	state: RunState,
	action: String,
	before: Dictionary,
	after: Dictionary,
	reason: String,
	node_id: String,
	targets: Array = []
) -> Dictionary:
	return {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": action,
		"before": before,
		"after": after,
		"reason": reason,
		"source": "resolver",
		"targets": targets,
	}


static func notoriety(state: RunState) -> int:
	return EconomyRulesScript.notoriety(state)


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	return EconomyRulesScript.roll_chance(state, pct, salt)


static func price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.price_for(catalog, state, base)


static func sell_price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.sell_price_for(catalog, state, base)


## 搜刮候选蛊方（预览与执行共用的唯一配方选择函数，2026-09-01）：
## scavenge_recipe 兼容单串与数组；过滤出「存在且尚未持有」的配方。
## 持有判定与图鉴门禁同源：global_codex_ids 命中 recipe id 或产出蛊 id。

static func gain_notoriety(state: RunState, amount: int, reason_key: String) -> RunState:
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["notorious"] = int(cultivator.get("notorious", 0)) + amount
	return state.append_event(_event(
		state,
		"gain_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_gained",
		state.current_node_id,
		[reason_key]
	))


static func _accepted(next: RunState) -> Dictionary:
	return {"state": next, "result": {"ok": true}}


static func _rejected(state: RunState, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}
