class_name V1BattleResolver
extends RefCounted

# V1 战斗引擎（蛊行动制，2026-08-30 用户裁定全量替换卡牌战斗）。
# 纯函数式：battle 是普通 Dictionary，每次动作 duplicate(true) 后写回。
# 规则来源：《蛊真人同人 Roguelike V1 战斗规则完整文档》定稿 +
# 2026-08-31 统一行动点裁定（念头/行动点/一心多用共用 ActionPoints 分档表）。
# 要点：无抽牌/牌库/弃牌堆；行动次数=魂魄底蕴分档，每次行动耗 1 念头；
# 真元（上限=境界基础×资质倍率 甲乙丙丁 4:3:2:1）；常驻蛊三模式；封印；
# 预制杀招（配方+化解标签，隐藏化解受击暴露）；肉体搏斗；全时死亡检测；
# 非战斗蛊自动过滤。

const ActionPointsScript = preload("res://scripts/domain/action_points.gd")
const SchoolRulesScript = preload("res://scripts/domain/school_rules.gd")
# T16 残锋降转（2026-09-15）：道痕余量/质变的唯一读写口（结算侧在门面）。
const SwordMarkRulesScript = preload("res://scripts/domain/sword_mark_rules.gd")
# Q8-IMPLEMENT Step 2（2026-09-12）：Effect Grammar V2 管线（FINAL §1）。
const GrammarPipeline = preload("res://scripts/domain/v1_grammar_pipeline.gd")

const DEFAULT_PHASE := "player_action"

# 蛊定义未声明 v1_effect 时的 role 兜底（W11 2026-09-09 迁 data/v1_battle.json
# default_effect_by_role，经 role_default_table 读取，见 load_config 同源）。
# 映射沿用旧栈 combat_effects 已有的设计意图（attack→strike /
# defense→guarded→shield / healing→heal / movement→retreat_preserved→shift /
# recon→revealed→标记 / logistics→delay_progress→束缚），基准值取同名手工蛊的
# v1_effect。数据里显式声明 v1_effect 的蛊一律优先，表只是补齐空效果蛊。
# 随转数线性成长的量纲；shift / status 是位置与层数，不随转数放大。
const RANK_SCALED_KINDS := ["strike", "shield", "heal"]


# ---------- 状态构建 ----------

static func load_config(catalog: Dictionary) -> Dictionary:
	return catalog.get("v1_battle", {})


## role 基础动作兜底表（data/v1_battle.json default_effect_by_role）。
## 缺键/形状退化一律回退空表——此时 default_v1_effect 全 miss 返回 {}，
## 与「无兜底」原语义一致；表形状由 ContentCatalog 校验钉住。
static func role_default_table(catalog: Dictionary) -> Dictionary:
	var battle: Variant = catalog.get("v1_battle", {})
	if not battle is Dictionary:
		return {}
	var table: Variant = (battle as Dictionary).get("default_effect_by_role", {})
	return table if table is Dictionary else {}


## 从 RunState 开局构建战斗（含资源初始化与玩家回合开始结算）。
static func start(run_state, catalog: Dictionary, enemy_entries: Array) -> Dictionary:
	var cfg: Dictionary = load_config(catalog)
	var player: Dictionary = run_state.cultivator if run_state.cultivator != null else {}
	var aptitude := str(player.get("aptitude", run_state.aptitude if run_state.aptitude != null else "bing"))
	var stage_tier := _stage_tier(run_state)
	var stage_base := int(cfg.get("stage_base", {}).get(stage_tier, 10))
	var mult := int(cfg.get("aptitude_mult", {}).get(aptitude, 2))
	var true_qi_max := stage_base * mult
	var soul := int(player.get("soul", 4))
	var battle := {
		"turn": 1,
		"phase": DEFAULT_PHASE,
		"cfg": cfg,
		"player": {
			# RunState.health 是本局气血唯一真值（resolver/shop/rest 全部写它；
			# cultivator.health 是镜像）。战斗 hp 取 RunState，结算后由
			# run_controller 同步写回，避免双源漂移。
			"hp": int(run_state.health),
			"max_hp": int(run_state.max_health),
			"life_time": int(player.get("lifespan", 60)),
			"soul": soul,
			"aptitude": aptitude,
			"cultivation": maxi(1, int(run_state.cultivation)),
			"stage": stage_tier,
			"stage_base": stage_base,
			"true_qi": true_qi_max,
			"true_qi_max": true_qi_max,
			"regen": _ceil_pct(true_qi_max, int(cfg.get("regen_pct", {}).get(aptitude, 25))),
			"thoughts": ActionPointsScript.per_turn(soul),
			"used_this_turn": 0,
			"shield": 0,
			"buffs": {"force": 0, "yi_zhang": 0},
		},
		"enemies": _build_enemies(enemy_entries),
		"gu_slots": _build_gu_slots(run_state, catalog),
		"active_permanents": [],
		# Q8 Step 5（FINAL §3/§8）：延迟效果表——battle 生命周期内登记与到期
		# 结算，战斗结束即销毁；随 battle Dictionary 整体序列化（只存 ID 与数值）。
		"delayed_effects": [],
		"kill_moves": _build_kill_moves(run_state, catalog),
		# T14：本场已泄密杀招被哪些敌人洞悉（用后追加，只增不减）。
		"revealed_to": [],
		"log": [],
		"flags": {},
		"result": null,
	}
	battle["phase"] = DEFAULT_PHASE
	return battle


static func _stage_tier(run_state) -> String:
	var cultivation := int(run_state.cultivation)
	var tiers := {"1": "one", "2": "two", "3": "three", "4": "four", "5": "five"}
	return str(tiers.get(str(cultivation), "one"))


static func _ceil_pct(value: int, pct: int) -> int:
	return ceili(float(value) * float(pct) / 100.0)


static func _build_enemies(enemy_entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in enemy_entries:
		var e: Dictionary = entry
		var intent: Dictionary = e.get("intent", {})
		var intent_kind := str(intent.get("kind", "attack"))
		result.append({
			"id": str(e.get("id", "enemy")),
			"label": str(e.get("label", str(e.get("id", "enemy")))),
			"hp": int(e.get("hp", 1)),
			"max_hp": int(e.get("hp", 1)),
			"alive": true,
			# SIDE-FIX（2026-09-19）：多阶段 AI。phases 随条目透传（facade 深拷贝），
			# phase_index = 上次结算所处阶段（-1 = 未计算），last_fired = 意图 id →
			# 上次发出回合。无 phases 的敌人走单意图 + 同一套冷却门禁。
			"phases": (e.get("phases", []) as Array).duplicate(true),
			"phase_index": -1,
			"last_fired": {},
			"intent": {
				"kind": intent_kind,
				# H3（Q8 Step 4）：意图带最小语义属性——这是不是一次伤害意图。
				# sealed 门禁与 weaken_intent 只作用于 damage intent；数据可显式
				# 声明覆盖，缺省按 kind 派生（attack=伤害意图）。
				"damage_intent": bool(intent.get("damage_intent", intent_kind == "attack")),
				"id": str(intent.get("id", "")),
				"damage": int(intent.get("damage", 0)),
				"label": str(intent.get("label", "蓄力")),
				"speed": int(intent.get("speed", 0)),
				"cooldown": maxi(0, int(intent.get("cooldown", 0))),
				"essence_burn": maxi(0, int(intent.get("essence_burn", 0))),
				"seal_turns": int(intent.get("seal_turns", 0)),
				"soul_drain": int(intent.get("soul_drain", 0)),
				"life_cost": int(intent.get("life_cost", 0)),
				"counter_tag": str(intent.get("counter_tag", "")),
			},
			"counter_revealed": [],
			"counter_hidden": [],
			"shield": 0,
			"statuses": {},
			# Q8 Step 4（FINAL §8）：下一次 damage intent 减免额（per-target，
			# weaken_intent 操作写入；消费或回合结束清零）。
			"intent_weaken": 0,
		})
		# SIDE-FIX：开局即落在当前血量比对应的阶段，避免首回合刷一条
		# 伪装的 phase_shift（满血即 phase 0，无切换可记）。
		var built: Dictionary = result[result.size() - 1]
		built["phase_index"] = active_phase_index(built)
		result[result.size() - 1] = built
	return result


## 非战斗蛊过滤：蛊定义缺少 combat 字段或 combat=="none" 视为非战斗蛊，
## 不进战斗面板。战斗蛊按 definition 构建槽位（含 V1 三模式与消耗字段）。
## 蛊定义未声明 v1_effect 时按 role 兜底（表=role_default_table(catalog)，
## data/v1_battle.json default_effect_by_role），避免空效果蛊占槽位、烧真元
## 却无事发生。显式声明的 v1_effect 永远优先。
## ponytail: 上限=~200 个 legacy 蛊效果朴素且无回合到期语义、但有执行 effect_reason/预览过滤双护栏；升级触发=某个蛊进 slice 或需要精确效果/到期时逐个迁显式 v1_effect。
static func default_v1_effect(definition: Dictionary, role_table: Dictionary) -> Dictionary:
	var role := str(definition.get("role", ""))
	var raw: Variant = role_table.get(role, {})
	if not raw is Dictionary:
		return {}
	var effect: Dictionary = (raw as Dictionary).duplicate(true)
	var kind := str(effect.get("kind", ""))
	if RANK_SCALED_KINDS.has(kind):
		effect["amount"] = int(effect.get("amount", 1)) + maxi(0, int(definition.get("rank", 1)) - 1)
	# Q7 阶段 B2（2026-09-12）：兜底表支援键——"self" 哨兵注入流派，bonus 随 rank 梯度。
	if str(effect.get("support_school", "")) == "self":
		effect["support_school"] = str(definition.get("school", ""))
	if effect.has("support_bonus"):
		effect["support_bonus"] = int(effect.get("support_bonus", 0)) + maxi(0, int(definition.get("rank", 1)) - 1)
	return effect


static func _build_gu_slots(run_state, catalog: Dictionary) -> Array[Dictionary]:
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var role_table: Dictionary = role_default_table(catalog)
	var result: Array[Dictionary] = []
	for instance in run_state.refined_instances():
		var definition: Dictionary = gu_by_id.get(str(instance.get("definition_id", "")), {})
		var combat := str(definition.get("combat", ""))
		if combat.is_empty() or combat == "none":
			continue
		# T16 残锋降转（2026-09-15）：持有转数取"同名升阶"口径，等效转数再减
		# 质变次数（下限 1 转）。未降转实例 effective == held ⇒ 行为保持。
		var held_rank := maxi(int(instance.get("rank", 1)), int(definition.get("rank", 1)))
		var downgrades := SwordMarkRulesScript.downgrades_of(instance)
		var effective_rank := SwordMarkRulesScript.effective_rank(held_rank, instance)
		var effect: Dictionary = definition.get("v1_effect", {})
		if effect.is_empty():
			effect = default_v1_effect(definition, role_table)
		else:
			effect = (effect as Dictionary).duplicate(true)
		# D16-4(b)：降转必须**真的变弱**——门禁转数下降只是"更易催动"，
		# 故 RANK_SCALED_KINDS 的显式 amount 同步按质变次数下调（下限 1）。
		if downgrades > 0 and RANK_SCALED_KINDS.has(str(effect.get("kind", ""))):
			effect["amount"] = maxi(1, int(effect.get("amount", 1)) - downgrades)
		result.append({
			"instance_id": str(instance.get("instance_id", "")),
			"definition_id": str(instance.get("definition_id", "")),
			# S4 元素协同：流派随槽位走，供支援加成匹配（本回合同流派 strike +N）。
			"school": str(definition.get("school", "")),
			# 同名升阶可让实例转数高于定义：门禁按两者较高者拦截。
			"rank": effective_rank,
			# T16 可见性：持有转数 / 道痕余量 / 距质变还差几次（UI 与快照只读）。
			"rank_held": held_rank,
			"sword_downgrades": downgrades,
			"dao_marks": SwordMarkRulesScript.remaining_marks(instance, catalog),
			"dao_marks_per_downgrade": SwordMarkRulesScript.downgrade_every(catalog),
			"sword_mark_cost": bool(definition.get("sword_mark_cost", false)),
			"low_rank_exception": bool(definition.get("low_rank_exception", false)),
			"is_sealed": false,
			"seal_turns": 0,
			"used_this_turn": false,
			"true_qi_cost": int(definition.get("true_qi_cost", int(definition.get("essence_cost", 1)))),
			"thought_cost": int(definition.get("thought_cost", 1)),
			"life_cost": int(definition.get("life_cost", 0)),
			"is_permanent": bool(definition.get("is_permanent", false)),
			"durability_mode": str(definition.get("durability_mode", "")),
			"trigger_qi_cost": int(definition.get("trigger_qi_cost", 0)),
			"trigger_block": int(definition.get("trigger_block", 0)),
			"maintain_qi_cost": int(definition.get("maintain_qi_cost", 0)),
			"duration_turns": int(definition.get("duration_turn", 0)),
			"effect": effect,
			"consumed": false,
		})
	return result


## L0 2026-09-22 battle2 归并：战斗伤害/效果/杀招/反击的唯一结算入口是本文件。
## battle2/turn_engine 只提供回合念头账本，不得并行结算战斗效果。
## 杀招效果 = recipe 组件 v1_effect 按顺序合成（见 play_kill_move）。
## data/v1_battle.json 或 gu 定义的 kill_moves（按 definition_id 组装）。
static func _build_kill_moves(run_state, catalog: Dictionary) -> Array[Dictionary]:
	var cfg: Dictionary = load_config(catalog)
	var raw: Array = cfg.get("kill_moves", [])
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var instance_by_def: Dictionary = {}
	for instance in run_state.refined_instances():
		var def_id := str(instance.get("definition_id", ""))
		if not instance_by_def.has(def_id):
			instance_by_def[def_id] = str(instance.get("instance_id", ""))
	var result: Array[Dictionary] = []
	for km_value in raw:
		var km: Dictionary = km_value
		var recipe: Array[String] = []
		var mark_recipe: Array[String] = []
		var recipe_ok := true
		for def_id_value in km.get("recipe", []):
			var def_id := str(def_id_value)
			if not instance_by_def.has(def_id):
				recipe_ok = false
				break
			var instance_id := str(instance_by_def[def_id])
			recipe.append(instance_id)
			# T16：配方里哪些蛊带残锋标记（`sword_mark_cost`）——逆炼只吃这些，
			# 出招前预检与持久化结算共用同一份名单，避免二次判定义。
			if bool((gu_by_id.get(def_id, {}) as Dictionary).get("sword_mark_cost", false)):
				mark_recipe.append(instance_id)
		if not recipe_ok:
			continue
		result.append({
			"id": str(km.get("id", "")),
			"label": str(km.get("label", str(km.get("id", "")))),
			"tag": str(km.get("tag", "")),
			"recipe": recipe,
			"sword_mark_recipe": mark_recipe,
			"true_qi_cost": int(km.get("true_qi_cost", 0)),
			"thought_cost": int(km.get("thought_cost", 1)),
			"life_cost": int(km.get("life_cost", 0)),
			# LEGACY 2026-09-22：预制 damage/effect 不再主结算；效果=recipe 组件 v1_effect 顺序合成。
			"damage": 0,
			"effect": {},
			"legacy_declared_damage": int(km.get("damage", 0)),
			"legacy_declared_effect": km.get("effect", {}),
			"reveals": false,
		})
		if recipe.size() != (km.get("recipe", []) as Array).size():
			# 配方部分缺失则整个杀招不成立（保持严格）。
			pass
	return result


# ---------- 可播放校验 ----------

static func can_play_gu(battle: Dictionary, slot_index: int) -> String:
	if slot_index < 0 or slot_index >= (battle["gu_slots"] as Array).size():
		return "unknown_gu"
	var slot: Dictionary = battle["gu_slots"][slot_index]
	if bool(slot.get("consumed", false)):
		return "gu_consumed"
	if bool(slot.get("is_sealed", false)):
		return "gu_sealed"
	if bool(slot.get("used_this_turn", false)):
		return "gu_used_this_turn"
	# spec §11.2（CultivatorRules.can_activate 单一实现）：普通低转蛊师不能
	# 催动高转蛊（真元质量不足）；珍稀蛊可声明 low_rank_exception 例外。
	# 拒绝零消耗，所以排在一切扣费之前。
	if not CultivatorRules.can_activate(int(battle["player"].get("cultivation", 1)), int(slot.get("rank", 1)), bool(slot.get("low_rank_exception", false))):
		return "insufficient_qi_quality"
	if _thoughts_used_up(battle):
		return "action_limit_reached"
	if int(battle["player"]["thoughts"]) < int(slot.get("thought_cost", 1)):
		return "insufficient_thought"
	if int(battle["player"]["true_qi"]) < int(slot.get("true_qi_cost", 0)):
		return "insufficient_true_qi"
	return ""


static func _thoughts_used_up(battle: Dictionary) -> bool:
	return int(battle["player"]["used_this_turn"]) >= ActionPointsScript.per_turn(int(battle["player"]["soul"]))


## 拳脚可释放校验（快照/预览与 basic_attack 同一套门禁）。
static func basic_attack_reason(battle: Dictionary) -> String:
	if _thoughts_used_up(battle):
		return "action_limit_reached"
	if int(battle["player"]["thoughts"]) < 1:
		return "insufficient_thought"
	return ""


# ---------- 玩家动作 ----------

## 统一入口：返回 {"battle": ..., "result": {"ok": bool, "reason": String, "changes": [...]}}
static func player_action(battle: Dictionary, action: Dictionary) -> Dictionary:
	if _is_over(battle):
		return _result(battle, false, "battle_over")
	match str(action.get("type", "")):
		"play_gu":
			return play_gu(battle, int(action.get("slot_index", -1)), str(action.get("target_id", "")))
		"basic_attack":
			return basic_attack(battle)
		"play_kill_move":
			return play_kill_move(battle, str(action.get("kill_move_id", "")),
					bool(action.get("confirmed", false)))
		"end_turn":
			return end_turn(battle)
		_:
			return _result(battle, false, "unknown_action")


## 释放蛊（瞬发/常驻通用入口，前置校验一致；效果按模式分派）。
## target_id 为空或无效时回退当前目标（首个存活敌人），保证向后兼容与确定性。
static func play_gu(battle: Dictionary, slot_index: int, target_id: String = "") -> Dictionary:
	var reason := can_play_gu(battle, slot_index)
	if not reason.is_empty():
		return _result(battle, false, reason)
	var slot: Dictionary = battle["gu_slots"][slot_index]
	# 2026-09-05 切片护栏：声明式 effect_reason 在扣费前拒绝未声明 / 非法 effect。
	var slot_effect_reason := effect_reason(slot.get("effect", {}))
	if not slot_effect_reason.is_empty():
		return _result(battle, false, slot_effect_reason)
	# Q8-IMPLEMENT Step 2（H1 硬约束）：trigger + condition 资格段必须在 cost commit
	# 之前——cost commit 是管线上第一笔不可逆变更，资格 miss 一分不扣。
	# miss 事件由本层落（pipeline 只判不写）；零消耗返回。
	var gate_reason: String = GrammarPipeline.gate_miss_reason(slot.get("effect", {}), battle)
	if not gate_reason.is_empty():
		var gatted := _dup(battle)
		_log(gatted, gate_reason, str(slot.get("definition_id", "")))
		return _result(gatted, false, gate_reason)
	var paid := _spend_costs(battle, slot, "gu:%s" % str(slot["instance_id"]))
	var life_cost := int(slot.get("life_cost", 0))
	if life_cost > 0 and int(paid["player"]["life_time"]) <= 0:
		# 释放耗寿元的蛊：扣减后寿元归零，则该次效果不执行，直接陨落。
		return _result(_mark_death(paid, "life_cost"), false, "life_cost_depleted")
	var is_permanent := bool(slot.get("is_permanent", false))
	if is_permanent:
		paid = _play_permanent(paid, slot_index, target_id)
	else:
		paid = _play_instant(paid, slot_index, target_id)
	return _result(paid, true, "")


## 2026-09-05 声明式 effect_reason：空 dict 仅允许 damage-only 杀招，gu slot
## 必须声明一种支持的 effect 类型。返回空字符串表示合法。
static func effect_reason(effect: Variant) -> String:
	if not (effect is Dictionary):
		return "unknown_effect"
	var data: Dictionary = effect
	if data.is_empty():
		return ""
	var kind := str(data.get("kind", ""))
	const SUPPORTED := ["strike", "shield", "buff", "heal", "heal_and_strike", "status", "shift", "sword_intent", "weaken_intent"]
	if not SUPPORTED.has(kind):
		return "unknown_effect"
	return ""


static func _spend_costs(battle: Dictionary, slot: Dictionary, target: String) -> Dictionary:
	var next := _dup(battle)
	var player: Dictionary = next["player"].duplicate(true)
	player["true_qi"] = int(player["true_qi"]) - int(slot.get("true_qi_cost", 0))
	player["thoughts"] = int(player["thoughts"]) - int(slot.get("thought_cost", 1))
	player["used_this_turn"] = int(player["used_this_turn"]) + 1
	var life_cost := int(slot.get("life_cost", 0))
	if life_cost > 0:
		player["life_time"] = maxi(0, int(player["life_time"]) - life_cost)
	next["player"] = player
	_log(next, "spent", target)
	return next


static func _play_instant(battle: Dictionary, slot_index: int, target_key: String = "") -> Dictionary:
	var next := _dup(battle)
	var slot: Dictionary = next["gu_slots"][slot_index].duplicate(true)
	slot["used_this_turn"] = true
	next["gu_slots"][slot_index] = slot
	return _apply_effect(next, slot, target_key)


static func _play_permanent(battle: Dictionary, slot_index: int, target_key: String = "") -> Dictionary:
	var next := _dup(battle)
	var slot: Dictionary = next["gu_slots"][slot_index].duplicate(true)
	slot["used_this_turn"] = true
	next["gu_slots"][slot_index] = slot
	var mode := str(slot.get("durability_mode", ""))
	if mode == "CONSUME_ON_USE":
		# 释放即销毁：本场战斗临时销毁，施加效果（buff 按 duration_turns 倒计时）。
		slot["consumed"] = true
		next["gu_slots"][slot_index] = slot
		return _apply_effect(next, slot, target_key)
	# TRIGGER_COST / PER_TURN_MAINTAIN：进入激活常驻列表。
	if not (next["active_permanents"] as Array).has(str(slot["instance_id"])):
		next["active_permanents"] = (next["active_permanents"] as Array).duplicate()
		(next["active_permanents"] as Array).append(str(slot["instance_id"]))
	return _apply_effect(next, slot, target_key)


static func _stack_buff(buffs: Dictionary, buff: Dictionary) -> Dictionary:
	var out := buffs.duplicate(true)
	var name := str(buff.get("name", "force"))
	var amount := int(buff.get("amount", 1))
	out[name] = int(out.get(name, 0)) + amount
	return out


## 对指定目标（target_key 为空/无效时回退首个存活敌人）应用蛊效果。
## effect 支持：
##   {"kind":"strike","amount":N} / {"kind":"shield","amount":N} /
##   {"kind":"buff","name":X,"amount":N} / {"kind":"heal","amount":N} /
##   {"kind":"heal_and_strike","heal":N,"amount":N} /
##   {"kind":"status","name":X,"amount":N} / {"kind":"shift","amount":N}
##
## Q8-IMPLEMENT Step 2：本函数是 Grammar 管线的结算段（cost commit 之后调用），
## 阶段标注（FINAL §1）：selector（下方 target_key 语义）-> modifier.prepare
## （Step 3 挂点：consume_status 定参位）-> operation（match kind）->
## modifier.commit（尾部 support 登记，登记型 modifier）。
## 行为零漂移：48 只显式蛊基线（test_q8_grammar_baseline.gd）逐只保持绿。
static func _apply_effect(battle: Dictionary, slot: Dictionary, target_key: String) -> Dictionary:
	var next := _dup(battle)
	var effect: Dictionary = slot.get("effect", {})
	var kind := str(effect.get("kind", ""))
	# ---- Step 5（FINAL §3 delay 形态锁定，先付费后延迟）：打出时 cost 已由
	# play_gu 提交（拖延不免费）；operation 不立即结算，改登记 delayed_effects，
	# 到期回合由 _fire_delayed_effects 结算（事件 delayed_scheduled / delayed_fired）。
	# 目标不在此刻锁定——到期重放走缺省解析（H4：队列第一个存活目标）。
	if effect.has("delay"):
		var due_turn := int(next.get("turn", 1)) + int((effect["delay"] as Dictionary).get("turns", 1))
		var scheduled := {
			"effect": (effect as Dictionary).duplicate(true),
			"school": str(slot.get("school", "")),
			"due_turn": due_turn,
			"source_id": str(slot.get("instance_id", "")),
		}
		next["delayed_effects"] = (next.get("delayed_effects", []) as Array).duplicate(true)
		(next["delayed_effects"] as Array).append(scheduled)
		_log(next, "delayed_scheduled", str(due_turn))
		return next
	# ---- selector（Step 2 现状回退语义）：target_key 空或无效时由
	# _enemy_index 回退首个存活敌（H4「enemy_first」的现状雏形）。
	# Step 3 换成冻结集合 self / enemy_first / enemy_all 的显式解析。
	# ---- modifier.prepare（Step 3 挂点）：consume_status 定参
	# final_amount = base + stacks * per_stack 在此处计算（H2 原子事务的算段）。
	# ---- operation：一效果恰好一个操作；遗留 4 kind（buff / heal_and_strike /
	# shift / sword_intent）原语义保留（FINAL §6），不新增数据。
	match kind:
		"strike":
			var amount := int(effect.get("amount", 0))
			# S4 元素协同：吃到本回合已登记的同流派支援（透明度：battle.turn_supports）。
			amount += int((next.get("turn_supports", {}) as Dictionary).get(str(slot.get("school", "")), 0))
			# Q7 阶段 A（2026-09-12）：剑意作用域硬边界——只加成剑道 strike，
			# 且只在此处计算后随 amount 进 _strike_enemy；杀招/刻痕划伤/拳脚/
			# heal_and_strike 直调或走别的通道，结构性吃不到（计划 §0-2）。
			if str(slot.get("school", "")) == "sword":
				amount += SchoolRulesScript.sword_intent(next)
			# modifier.prepare（H2 计算步，Step 3）：consume_status 定参——
			# final_amount = base + stacks * per_stack；gate 已保证 stacks >= 1
			# 且单目标（enemy_all / aoe 组合在 gate 拒绝），此处直接读首个存活敌。
			var consume: Dictionary = effect.get("consume_status", {}) if effect.has("consume_status") else {}
			if not consume.is_empty():
				var consume_index := GrammarPipeline.first_alive_index(next)
				if consume_index >= 0:
					var consume_statuses: Dictionary = (next["enemies"][consume_index] as Dictionary).get("statuses", {})
					amount = GrammarPipeline.consume_final_amount(
						amount,
						int(consume_statuses.get(str(consume.get("name", "marked")), 0)),
						int(consume.get("per_stack", 0))
					)
			# selector 解析（Step 3）：缺省回退 target_key/首个存活敌；
			# enemy_all 或遗留 aoe 键 = 全部存活敌（行为与 S2 aoe 现状一致）。
			var targets: Array = GrammarPipeline.resolve_targets(next, effect, target_key)
			for target_id_value in targets:
				next = _strike_enemy(next, amount, str(target_id_value))
			if targets.size() > 1:
				_log(next, "strike_aoe", str(amount))
			# modifier.commit（H2 清除步）：strike 提交完成后清除已消费状态——
			# 「消费状态 + 使用状态产生的效果」同一次确定性结算（同一 next 副本，
			# 纯函数天然原子）；禁止 clear-then-strike（先清再打）。
			if not consume.is_empty() and not targets.is_empty():
				next = _clear_enemy_status(next, str(consume.get("name", "marked")), str(targets[0]))
		"shield":
			next["player"]["shield"] = int(next["player"]["shield"]) + int(effect.get("amount", 0))
		"buff":
			next["player"]["buffs"] = _stack_buff(next["player"]["buffs"], effect)
		"heal":
			next = _heal_player(next, int(effect.get("amount", 0)))
		"heal_and_strike":
			next = _heal_player(next, int(effect.get("heal", 0)))
			next = _strike_enemy(next, int(effect.get("amount", 0)), target_key)
		"status":
			# Step 3：status 走 selector 解析（缺省/enemy_first 均单目标，矩阵冻结）。
			var status_targets: Array = GrammarPipeline.resolve_targets(next, effect, target_key)
			if status_targets.is_empty():
				return next
			next = _apply_enemy_status(next, effect, str(status_targets[0]))
		"weaken_intent":
			# Q8 Step 4（FINAL §2 第 5 操作）：per-target 降低目标**下一次**
			# damage intent 数值。写目标 intent_weaken（可叠加）；消费或回合
			# 结束清零；不做全局 debuff、不产生跨目标涟漪。
			var weaken_targets: Array = GrammarPipeline.resolve_targets(next, effect, target_key)
			if weaken_targets.is_empty():
				return next
			var weaken_index := _enemy_index(next, str(weaken_targets[0]))
			if weaken_index < 0:
				return next
			var weaken_enemy: Dictionary = (next["enemies"][weaken_index] as Dictionary).duplicate(true)
			weaken_enemy["intent_weaken"] = int(weaken_enemy.get("intent_weaken", 0)) + int(effect.get("amount", 0))
			next["enemies"][weaken_index] = weaken_enemy
			next["last_effect_target"] = str(weaken_enemy["id"])
			_log(next, "weaken_applied", str(weaken_enemy["id"]))
		"shift":
			# ⚠️ 2026-09-12 用户裁定（Q8）：位移同比转化为防御力——
			# 不实现闪避/位移/攻击距离，shift 一律转译为等量护盾。
			# 距离减伤/追击死路径已于 2026-09-12 清理批次删除。
			# 推翻：specs/2026-09-12-shift-distance-spec.md 的距离减伤模型。
			next["player"]["shield"] = int(next["player"].get("shield", 0)) + int(effect.get("amount", 1))
		"sword_intent":
			# Q7 阶段 A（2026-09-12）：剑意叠层（不消费，跨回合存续，回合末减半）。
			var intent_amount := int(effect.get("amount", 1))
			SchoolRulesScript.add_sword_intent(next, intent_amount)
			_log(next, "sword_intent", str(intent_amount))
	# ---- modifier.commit（登记型 modifier）：S4 元素协同支援类子键（随任意 kind
	# 叠加）——登记后本回合内该流派后续蛊伤害 +support_bonus；end_turn 统一清零，
	# 不跨回合。登记在 operation 之后：同蛊自己的 strike 读不到自己这发（基线实证）。
	var support_school := str(effect.get("support_school", ""))
	var support_bonus := int(effect.get("support_bonus", 0))
	if not support_school.is_empty() and support_bonus > 0:
		var supports: Dictionary = (next.get("turn_supports", {}) as Dictionary).duplicate(true)
		supports[support_school] = int(supports.get(support_school, 0)) + support_bonus
		next["turn_supports"] = supports
		_log(next, "support", support_school)
	return next


static func _heal_player(battle: Dictionary, amount: int) -> Dictionary:
	var next := _dup(battle)
	var player: Dictionary = next["player"]
	player["hp"] = mini(int(player["max_hp"]), int(player["hp"]) + maxi(0, amount))
	next["player"] = player
	return next


static func _apply_enemy_status(battle: Dictionary, effect: Dictionary, target_key: String = "") -> Dictionary:
	var next := _dup(battle)
	var target_index := _enemy_index(next, target_key)
	if target_index < 0:
		return next
	var enemy: Dictionary = next["enemies"][target_index].duplicate(true)
	var statuses: Dictionary = enemy.get("statuses", {}).duplicate(true)
	var name := str(effect.get("name", "marked"))
	statuses[name] = int(statuses.get(name, 0)) + int(effect.get("amount", 1))
	enemy["statuses"] = statuses
	next["enemies"][target_index] = enemy
	# Actual resolved target: survives empty/invalid fallback so the effect log
	# can record who really took the status.
	next["last_effect_target"] = str(enemy["id"])
	_log(next, "status", str(enemy["id"]))
	# Q8 Step 4：sealed 上身是关键状态变化，落专属事件（FINAL §8 允许面）。
	if name == "sealed":
		_log(next, "sealed_applied", str(enemy["id"]))
	return next


## H2 原子事务清除步：consume_status 结算提交后，清除目标身上该 status 的
## 全部层数（层数已全额计入 final_amount）。只清不补，不做部分保留。
static func _clear_enemy_status(battle: Dictionary, status_name: String, target_id: String) -> Dictionary:
	var next := _dup(battle)
	var target_index := _enemy_index(next, target_id)
	if target_index < 0:
		return next
	var enemy: Dictionary = (next["enemies"][target_index] as Dictionary).duplicate(true)
	var statuses: Dictionary = (enemy.get("statuses", {}) as Dictionary).duplicate(true)
	if not statuses.has(status_name):
		return next
	statuses.erase(status_name)
	enemy["statuses"] = statuses
	next["enemies"][target_index] = enemy
	return next


static func _strike_enemy(battle: Dictionary, amount: int, target_key: String = "") -> Dictionary:
	var next := _dup(battle)
	var target_index := _enemy_index(next, target_key)
	if target_index < 0:
		return next
	var enemy: Dictionary = next["enemies"][target_index].duplicate(true)
	var after_shield := maxi(0, int(enemy.get("shield", 0)) - amount)
	var leftover := maxi(0, amount - int(enemy.get("shield", 0)))
	enemy["shield"] = after_shield
	enemy["hp"] = maxi(0, int(enemy["hp"]) - leftover)
	if int(enemy["hp"]) <= 0:
		enemy["alive"] = false
	next["enemies"][target_index] = enemy
	# Actual resolved target: survives empty/invalid fallback so the effect log
	# can record who really took the strike.
	next["last_effect_target"] = str(enemy["id"])
	_log(next, "struck", str(enemy["id"]))
	_check_victory(next)
	return next


## Q8-POST（2026-09-12）：存活唯一事实来源 = `hp > 0`。
## 缺陷背景：本文件原以 `alive` 字段判存活，而 v1_grammar_pipeline / action_preview_service /
## battle_snapshot 三方均以 `hp > 0`（或 `alive && hp > 0`）判——同一概念两个来源。
## 一旦 hp 归零而 alive 未同步，selector 认为敌已死、行动队列认为敌还活着，
## 且 _check_victory 永远看不到全灭（结果不可预见）。
## 现统一口径：hp 归零即不可行动、不可选中、计入全灭。
## alive 字段保留（快照/表现层消费，写入口仍同步），但不再是权威判定。
static func _enemy_is_alive(enemy: Dictionary) -> bool:
	return int(enemy.get("hp", 0)) > 0


static func _current_enemy_index(battle: Dictionary) -> int:
	for i in (battle["enemies"] as Array).size():
		if _enemy_is_alive(battle["enemies"][i]):
			return i
	return -1


## 目标解析：target_key 指定且存活则命中该敌人；否则回退首个存活敌人。
static func _enemy_index(battle: Dictionary, target_key: String) -> int:
	if not target_key.is_empty():
		for i in (battle["enemies"] as Array).size():
			var enemy: Dictionary = battle["enemies"][i]
			if str(enemy.get("id", "")) == target_key and _enemy_is_alive(enemy):
				return i
	return _current_enemy_index(battle)


## 肉体搏斗：耗 1 念头、不耗真元、占用一次行动；伤害=基础+力道+仪仗。
static func basic_attack(battle: Dictionary) -> Dictionary:
	var reason := basic_attack_reason(battle)
	if not reason.is_empty():
		return _result(battle, false, reason)
	var cfg: Dictionary = battle.get("cfg", {})
	var base := int(cfg.get("fight_damage_base", 1))
	var force := int(battle["player"]["buffs"].get("force", 0))
	var yi_zhang := int(battle["player"]["buffs"].get("yi_zhang", 0))
	var next := _dup(battle)
	next["player"]["thoughts"] = int(next["player"]["thoughts"]) - 1
	next["player"]["used_this_turn"] = int(next["player"]["used_this_turn"]) + 1
	next = _strike_enemy(next, base + force + yi_zhang)
	_log(next, "fought", "")
	return _result(next, true, "")


## 预制杀招：配方蛊全部未封印、行动+念头+真元（+寿元）校验；化解判定；
## 配方蛊标记 used_this_turn；寿元消耗致死则效果不执行直接陨落。
static func play_kill_move(battle: Dictionary, kill_move_id: String, confirmed: bool = false) -> Dictionary:
	var index := -1
	for i in (battle["kill_moves"] as Array).size():
		if str(battle["kill_moves"][i]["id"]) == kill_move_id:
			index = i
			break
	if index < 0:
		return _result(battle, false, "unknown_kill_move")
	var km: Dictionary = battle["kill_moves"][index]
	# L0 2026-09-22：形状校验改为逐组件 v1_effect（合成结算）；预制 effect 仅 LEGACY 保留。
	var km_effect_reason := ""
	for instance_id in km["recipe"]:
		var check_slot := _find_slot(battle, str(instance_id))
		if check_slot.is_empty():
			continue
		km_effect_reason = effect_reason(check_slot.get("effect", {}))
		if not km_effect_reason.is_empty():
			return _result(battle, false, km_effect_reason)
	for instance_id in km["recipe"]:
		var slot := _find_slot(battle, str(instance_id))
		if slot.is_empty() or bool(slot.get("is_sealed", false)):
			return _result(battle, false, "kill_move_recipe_sealed")
	if _thoughts_used_up(battle):
		return _result(battle, false, "action_limit_reached")
	if int(battle["player"]["thoughts"]) < int(km.get("thought_cost", 1)):
		return _result(battle, false, "insufficient_thought")
	if int(battle["player"]["true_qi"]) < int(km.get("true_qi_cost", 0)):
		return _result(battle, false, "insufficient_true_qi")
	# T16 红线（AGENTS §核心业务红线）：残锋是**不可逆的永久削弱**，本次出招若会把
	# 任一配方剑蛊推过质变阈值，必须先经确认；未确认时不扣余量、不执行。
	if SwordMarkRulesScript.pending_downgrade(battle, kill_move_id) and not confirmed:
		return _result(battle, false, "sword_mark_confirm_required")
	var player: Dictionary = (battle["player"] as Dictionary).duplicate(true)
	player["true_qi"] = int(player["true_qi"]) - int(km.get("true_qi_cost", 0))
	player["thoughts"] = int(player["thoughts"]) - int(km.get("thought_cost", 1))
	player["used_this_turn"] = int(player["used_this_turn"]) + 1
	var life_cost := int(km.get("life_cost", 0))
	if life_cost > 0:
		player["life_time"] = int(player["life_time"]) - life_cost
		if int(player["life_time"]) <= 0:
			return _result(_mark_death(battle, "life_cost"), false, "life_cost_depleted")
	var next := _dup(battle)
	next["player"] = player
	for instance_id in km["recipe"]:
		var slot := _find_slot(next, str(instance_id))
		if not slot.is_empty():
			next["gu_slots"][_find_slot_index(next, str(instance_id))]["used_this_turn"] = true
	# T16：把本次逆炼的配方蛊名单交给门面——resolver 只持有 battle，
	# 写回 RunState.gu_instances 由 battle_command_facade 按 loot_resolver
	# 同款范式落地（跨战斗的永久消耗必须落在实例上）。
	next["sword_mark_spent"] = (km.get("sword_mark_recipe", []) as Array).duplicate()
	_log(next, "kill_move", kill_move_id)
	# 化解判定：命中已暴露或隐藏的同标签化解 → 效果无效（资源已扣）。
	var tag := str(km.get("tag", ""))
	var countered := false
	var target_index := _current_enemy_index(next)
	if target_index >= 0 and not tag.is_empty():
		var enemy: Dictionary = next["enemies"][target_index]
		if (enemy["counter_revealed"] as Array).has(tag) or (enemy["counter_hidden"] as Array).has(tag):
			countered = true
			# 隐藏化解受击后暴露。
			if (enemy["counter_hidden"] as Array).has(tag):
				next["enemies"][target_index]["counter_hidden"] = (enemy["counter_hidden"] as Array).duplicate()
				(next["enemies"][target_index]["counter_hidden"] as Array).erase(tag)
				next["enemies"][target_index]["counter_revealed"] = (enemy["counter_revealed"] as Array).duplicate()
				(next["enemies"][target_index]["counter_revealed"] as Array).append(tag)
	if not countered:
		# L0 2026-09-22：杀招效果必须由 recipe 组件按顺序合成；预制 effect/damage 不再主结算。
		for instance_id in km["recipe"]:
			var part_slot := _find_slot(next, str(instance_id))
			if part_slot.is_empty():
				continue
			var part_effect: Dictionary = (part_slot.get("effect", {}) as Dictionary).duplicate(true)
			if part_effect.is_empty():
				continue
			# T14：杀招吃本回合同流派支援——school 取组件自身流派，缺省回落 kill move tag。
			var part_school := str(part_slot.get("school", tag))
			if part_school.is_empty():
				part_school = tag
			next = _apply_effect(next, {
				"effect": part_effect,
				"school": part_school,
				"instance_id": str(instance_id),
			}, "kill_move")
	# T14：泄密——杀招用一次即入「被洞悉」态（原文「仙道杀招一旦被借用，当中的秘密
	# 就会被其他蛊仙洞悉」）。条目 `reveals` 置真，并把在场敌人记入 `battle.revealed_to`，
	# 供后续「被克制」判定消费（敌人生成侧接线属图谱 §4-D3，并入 P3）。
	var revealed_moves: Array = next["kill_moves"]
	var revealed_entry: Dictionary = (revealed_moves[index] as Dictionary).duplicate(true)
	revealed_entry["reveals"] = true
	revealed_moves[index] = revealed_entry
	var revealed_to: Array = (next.get("revealed_to", []) as Array).duplicate()
	for enemy_value in (next.get("enemies", []) as Array):
		var witnessed_id := str((enemy_value as Dictionary).get("id", ""))
		if not witnessed_id.is_empty() and not revealed_to.has(witnessed_id):
			revealed_to.append(witnessed_id)
	next["revealed_to"] = revealed_to
	_log(next, "kill_move_revealed", kill_move_id)
	return _result(next, true, "countered" if countered else "")


## 杀招可释放校验（快照/预览复用 play_kill_move 同一套门禁）。
static func kill_move_reason(battle: Dictionary, kill_move_id: String) -> String:
	var index := -1
	for i in (battle.get("kill_moves", []) as Array).size():
		if str(battle["kill_moves"][i]["id"]) == kill_move_id:
			index = i
			break
	if index < 0:
		return "unknown_kill_move"
	var km: Dictionary = battle["kill_moves"][index]
	# 2026-09-05 切片护栏：快照/预览必须和执行共用同一 effect_reason。
	var km_effect_reason := effect_reason(km.get("effect", {}))
	if not km_effect_reason.is_empty():
		return km_effect_reason
	for instance_id in km["recipe"]:
		var slot := _find_slot(battle, str(instance_id))
		if slot.is_empty() or bool(slot.get("is_sealed", false)):
			return "kill_move_recipe_sealed"
	if _thoughts_used_up(battle):
		return "action_limit_reached"
	if int(battle["player"]["thoughts"]) < int(km.get("thought_cost", 1)):
		return "insufficient_thought"
	if int(battle["player"]["true_qi"]) < int(km.get("true_qi_cost", 0)):
		return "insufficient_true_qi"
	return ""


## T16（2026-09-15）：本次释放该杀招是否会触发质变（等效转数 -1，不可逆）。
## 快照/UI 用它出招前给出确认提示；play_kill_move 用同一判据硬拦未确认的释放，
## 保证「禁止静默惩罚」——判据只有一处。
static func kill_move_downgrade_pending(battle: Dictionary, kill_move_id: String) -> bool:
	return SwordMarkRulesScript.pending_downgrade(battle, kill_move_id)


# ---------- 回合流转 ----------

## 结束玩家回合：念头清零、行动计数清零、敌人意图结算、TRIGGER_COST 受击
## 响应、隐藏化解不暴露（受击才暴露）、回合+1、开启新玩家回合。
static func end_turn(battle: Dictionary) -> Dictionary:
	if str(battle.get("phase", DEFAULT_PHASE)) == "victory" or str(battle.get("phase", DEFAULT_PHASE)) == "defeat":
		return _result(battle, false, "battle_over")
	var next := _dup(battle)
	next["player"]["thoughts"] = 0
	next["player"]["used_this_turn"] = 0
	# S4 元素协同：「本回合」语义在回合边界收口，支援不跨回合。
	next["turn_supports"] = {}
	for i in (next["gu_slots"] as Array).size():
		next["gu_slots"][i] = (next["gu_slots"][i] as Dictionary).duplicate(true)
		next["gu_slots"][i]["used_this_turn"] = false
	# 敌人回合（Q8-POST：存活判定统一为 hp > 0，见 _enemy_is_alive）
	for i in (next["enemies"] as Array).size():
		if not _enemy_is_alive(next["enemies"][i]):
			continue
		next = _resolve_enemy_intent(next, i)
		if _is_over(next):
			break
	if _is_over(next):
		return _result(next, true, "")
	# Q8 Step 4（FINAL §2）：intent_weaken「消费或回合结束」清零——未被消费的
	# 减免不跨回合（回合窗口语义，与 turn_supports 同构收口）。
	for i in (next["enemies"] as Array).size():
		var cleanup_enemy: Dictionary = (next["enemies"][i] as Dictionary).duplicate(true)
		if int(cleanup_enemy.get("intent_weaken", 0)) != 0:
			cleanup_enemy["intent_weaken"] = 0
			next["enemies"][i] = cleanup_enemy
	# Q8 死路径清理（2026-09-12）：_enemy_pursuit 已删——shift 转译护盾后无距离可追。
	# T15 刻痕通道（2026-09-12）：表面伤口会愈合，刻印下来的道痕不会消失——
	# 回合末按敌人身上 marked 层数结算一次**独立**伤害（见 _settle_marks）。
	next = _settle_marks(next)
	if _is_over(next):
		return _result(next, true, "")
	# Q7 阶段 A：剑意跨回合衰减（50% 向下取整，school_rules 落桩语义）。
	SchoolRulesScript.decay_sword_intent(next)
	next["turn"] = int(next["turn"]) + 1
	# Q8 Step 5：延迟效果到期结算（先于新玩家回合——埋下的蛊在下一回合开始时起效）。
	next = _fire_delayed_effects(next)
	if _is_over(next):
		return _result(next, true, "")
	next = _start_player_turn(next)
	return _result(next, true, "")


## T15 刻痕通道：回合末按敌人身上 `marked`（刻痕）层数结算伤害。
## 独立通道定位（重查报告 §2-M3，与 STS 中毒同构）：道痕**自寻弱点**——
##   - 不吃护盾（独立结算，不参与 shield 交换）；
##   - 不吃力量/虚弱等增益减益；
##   - 不衰减（原文「刻印不会消失」），层数由「每回合 2 念头」天然限流。
## 只伤敌，**无玩家致死路径**，故不需要死亡预检（任务书 T15 该句源自已被
## 重查推翻的「侵蚀自伤」，此处按重查口径更正）。
## 参数：cfg.mark_scratch_per_layer（每层伤害，默认 1）、cfg.mark_scratch_cap（层数上限，默认 10）。
static func _settle_marks(battle: Dictionary) -> Dictionary:
	var next := _dup(battle)
	var cfg: Dictionary = next.get("cfg", {})
	var per_layer := int(cfg.get("mark_scratch_per_layer", 1))
	var cap := int(cfg.get("mark_scratch_cap", 10))
	if per_layer <= 0:
		return next
	for i in (next["enemies"] as Array).size():
		var enemy: Dictionary = next["enemies"][i]
		if not _enemy_is_alive(enemy):
			continue
		var layers := int((enemy.get("statuses", {}) as Dictionary).get("marked", 0))
		if layers <= 0:
			continue
		var damage := mini(layers, maxi(0, cap)) * per_layer
		if damage <= 0:
			continue
		var updated: Dictionary = (next["enemies"][i] as Dictionary).duplicate(true)
		updated["hp"] = maxi(0, int(updated["hp"]) - damage)
		if int(updated["hp"]) <= 0:
			updated["alive"] = false
		next["enemies"][i] = updated
		next["last_effect_target"] = str(updated.get("id", ""))
		_log(next, "mark_scratch", str(updated.get("id", "")))
	_check_victory(next)
	return next


static func _fire_delayed_effects(battle: Dictionary) -> Dictionary:
	var next := _dup(battle)
	var pending: Array = (next.get("delayed_effects", []) as Array).duplicate(true)
	if pending.is_empty():
		return next
	var remaining: Array = []
	var current_turn := int(next.get("turn", 1))
	for entry_value in pending:
		var entry: Dictionary = entry_value
		if int(entry.get("due_turn", 0)) > current_turn:
			remaining.append(entry)
			continue
		# 到期重放：目标缺省解析（enemy_first 语义，H4——到期时队列第一个存活）。
		var replay_effect: Dictionary = (entry.get("effect", {}) as Dictionary).duplicate(true)
		replay_effect.erase("delay")
		next = _apply_effect(next, {"effect": replay_effect, "school": str(entry.get("school", ""))}, "")
		_log(next, "delayed_fired", str(entry.get("source_id", "")))
	_check_victory(next)
	next["delayed_effects"] = remaining
	return next


# ---------- 敌人多阶段 AI（SIDE-FIX 2026-09-19） ----------
# 语义来源：data/enemies.json → miasma_vein_lord._phases_note（唯一语义说明，
# 已与 game/wenzhen-web-lab/js/rules.js 的 activePhase/intentReady/selectIntent
# 逐条核对一致；Web 仅只读参照）。多意图优先级数据未写明 → 取数据顺序（原型口径）。

## 当前血量比（max_hp 缺失/归零时按满血计，避免除零）。
static func _hp_ratio(enemy: Dictionary) -> float:
	var max_hp := int(enemy.get("max_hp", 0))
	if max_hp <= 0:
		return 1.0
	return clampf(float(int(enemy.get("hp", 0))) / float(max_hp), 0.0, 1.0)


## 当前阶段下标 = 数据顺序中最后一个 until_hp_ratio >= 当前血量比的阶段。
## 无 phases 返回 -1（调用方走单意图路径）。
static func active_phase_index(enemy: Dictionary) -> int:
	var phases: Array = enemy.get("phases", [])
	if phases.is_empty():
		return -1
	var ratio := _hp_ratio(enemy)
	var index := 0
	for i in phases.size():
		if float((phases[i] as Dictionary).get("until_hp_ratio", 0.0)) >= ratio:
			index = i
	return index


## 意图是否已冷却完毕：第 T 回合发出后，最早 T+n+1 回合才能再选。
static func _intent_ready(last_fired: Dictionary, intent_id: String, cooldown: int, turn: int) -> bool:
	if not last_fired.has(intent_id):
		return true
	return turn >= int(last_fired[intent_id]) + maxi(0, cooldown) + 1


## 本回合意图：阶段内按数据顺序取第一条已冷却的；全部在冷却 → {}（cooldown_wait）。
static func select_enemy_intent(enemy: Dictionary, turn: int) -> Dictionary:
	var intents: Array = []
	var phases: Array = enemy.get("phases", [])
	if not phases.is_empty():
		var phase_index := active_phase_index(enemy)
		if phase_index >= 0:
			intents = (phases[phase_index] as Dictionary).get("intents", [])
	else:
		intents = [enemy.get("intent", {})]
	var last_fired: Dictionary = enemy.get("last_fired", {})
	for intent_value in intents:
		var candidate: Dictionary = intent_value
		var intent_id := str(candidate.get("id", ""))
		if _intent_ready(last_fired, intent_id, int(candidate.get("cooldown", 0)), turn):
			return candidate
	return {}


## 阶段意图 → 可结算意图（补全缺省键；无 kind 视为 attack；damage_intent 缺省按 kind 派生）。
static func _merge_phase_intent(candidate: Dictionary) -> Dictionary:
	var kind := str(candidate.get("kind", "attack"))
	return {
		"kind": kind,
		"damage_intent": bool(candidate.get("damage_intent", kind == "attack")),
		"id": str(candidate.get("id", "")),
		"damage": int(candidate.get("damage", 0)),
		"label": str(candidate.get("label", "蓄力")),
		"speed": int(candidate.get("speed", 0)),
		"cooldown": maxi(0, int(candidate.get("cooldown", 0))),
		"essence_burn": maxi(0, int(candidate.get("essence_burn", 0))),
		"seal_turns": int(candidate.get("seal_turns", 0)),
		"soul_drain": int(candidate.get("soul_drain", 0)),
		"life_cost": int(candidate.get("life_cost", 0)),
		"counter_tag": str(candidate.get("counter_tag", "")),
	}


static func _resolve_enemy_intent(battle: Dictionary, enemy_index: int) -> Dictionary:
	var next := _dup(battle)
	# 多阶段 / 冷却门禁：有 phases 按血量比选阶段 + 数据顺序选意图；单意图敌人
	# 同样过冷却门禁（cooldown 缺省 0 → 恒就绪，行为零漂移）。
	var phases: Array = (next["enemies"][enemy_index] as Dictionary).get("phases", [])
	if not phases.is_empty():
		var phase_enemy: Dictionary = next["enemies"][enemy_index]
		var phase_index := active_phase_index(phase_enemy)
		if phase_index != int(phase_enemy.get("phase_index", -1)):
			phase_enemy["phase_index"] = phase_index
			next["enemies"][enemy_index] = phase_enemy
			_log(next, "phase_shift", str(phase_enemy.get("id", "")))
		var selected := select_enemy_intent(next["enemies"][enemy_index], int(next.get("turn", 1)))
		if selected.is_empty():
			_log(next, "cooldown_wait", str((next["enemies"][enemy_index] as Dictionary).get("id", "")))
			return next
		var merged := _merge_phase_intent(selected)
		var fired: Dictionary = (next["enemies"][enemy_index] as Dictionary).duplicate(true)
		fired["intent"] = merged
		var last_fired: Dictionary = (fired.get("last_fired", {}) as Dictionary).duplicate(true)
		last_fired[str(merged["id"])] = int(next.get("turn", 1))
		fired["last_fired"] = last_fired
		next["enemies"][enemy_index] = fired
	else:
		var single: Dictionary = next["enemies"][enemy_index]
		var single_intent: Dictionary = single.get("intent", {})
		if not _intent_ready(single.get("last_fired", {}),
				str(single_intent.get("id", "")),
				int(single_intent.get("cooldown", 0)), int(next.get("turn", 1))):
			_log(next, "cooldown_wait", str(single.get("id", "")))
			return next
		var single_fired: Dictionary = (single as Dictionary).duplicate(true)
		var single_last: Dictionary = (single_fired.get("last_fired", {}) as Dictionary).duplicate(true)
		single_last[str(single_intent.get("id", ""))] = int(next.get("turn", 1))
		single_fired["last_fired"] = single_last
		next["enemies"][enemy_index] = single_fired
	var enemy: Dictionary = next["enemies"][enemy_index].duplicate(true)
	var intent: Dictionary = enemy["intent"]
	var kind := str(intent.get("kind", "attack"))
	match kind:
		"attack":
			# H3（Q8 Step 4）：门禁读意图自身的 damage_intent 属性裁决，**禁止**
			# 以 sealed 计数硬编码短路——非伤害意图不受 sealed 门禁、不消耗 sealed。
			var is_damage_intent := bool(intent.get("damage_intent", true))
			var enemy_statuses: Dictionary = (enemy.get("statuses", {}) as Dictionary)
			# sealed 最小纵切（FINAL §2）：下一次 damage intent 被门禁——意图不存在。
			# 消费即清；同在身的 weaken 未服务过，保留（不被本次门禁消耗）。
			if is_damage_intent and int(enemy_statuses.get("sealed", 0)) > 0:
				var sealed_enemy: Dictionary = enemy.duplicate(true)
				var sealed_statuses: Dictionary = (sealed_enemy.get("statuses", {}) as Dictionary).duplicate(true)
				sealed_statuses.erase("sealed")
				sealed_enemy["statuses"] = sealed_statuses
				next["enemies"][enemy_index] = sealed_enemy
				_log(next, "sealed_consumed", str(enemy["id"]))
				return next
			# weaken_intent（per-target，FINAL §2）：只降低本次 damage intent 数值，
			# 用后立即清零；减免不把意图变成非伤害意图，floor 0。
			var damage := int(intent.get("damage", 0))
			var weaken := int(enemy.get("intent_weaken", 0))
			if is_damage_intent and weaken > 0:
				damage = maxi(0, damage - weaken)
				var weakened_enemy: Dictionary = enemy.duplicate(true)
				weakened_enemy["intent_weaken"] = 0
				next["enemies"][enemy_index] = weakened_enemy
				_log(next, "weaken_consumed", str(enemy["id"]))
		# Q8 死路径清理（2026-09-12）：_distance_adjusted_damage 已删——
		# shift 转译护盾后 distance 恒 0，减伤入口不复存在。
		# 死亡归因（§17.3）：敌方攻击入战斗日志，DeathReport 由日志导出
			# 击杀意图（V1 无 final_blow 状态字段）。
			_log(next, "enemy_attack", str(intent.get("label", str(enemy["id"]))))
			next = _damage_player(next, damage)
		"seal":
			var turns := int(intent.get("seal_turns", 1))
			next = _seal_random_gu(next, turns)
		"soul_drain":
			next["player"]["soul"] = maxi(0, int(next["player"]["soul"]) - int(intent.get("soul_drain", 0)))
			_check_player_death(next)
		"life_cost":
			next["player"]["life_time"] = maxi(0, int(next["player"]["life_time"]) - int(intent.get("life_cost", 0)))
			_check_player_death(next)
		"counter":
			var tag := str(intent.get("counter_tag", ""))
			if not tag.is_empty() and not (enemy["counter_hidden"] as Array).has(tag):
				enemy["counter_hidden"] = (enemy["counter_hidden"] as Array).duplicate()
				enemy["counter_hidden"].append(tag)
				next["enemies"][enemy_index] = enemy
	# SIDE-FIX 收尾（2026-09-19）：焚元结算——意图实际发出即扣玩家真元，下限 0，
	# 对任何 kind 生效（attack/seal/soul_drain/… 一视同仁），独立于伤害
	# （格挡/减免不吞焚元）。能到这里说明意图确实发出：
	# cooldown_wait 未就绪已提前返回，sealed 门禁吞掉意图也在上面提前返回。
	# 只记账，不调数值（焚元被回复吃掉是已知平衡观察，不在本任务范围）。
	var burn := int(intent.get("essence_burn", 0))
	if burn > 0:
		next["player"]["true_qi"] = maxi(0, int(next["player"]["true_qi"]) - burn)
		_log(next, "essence_burn", str(enemy["id"]))
	return next


## 按「玩家与交战点的距离」削减敌人近身伤害（Q8 死路径，2026-09-12 已删除）：
## shift 一律转译为护盾，position 不再存在，距离减伤/追击无入口。


static func _damage_player(battle: Dictionary, amount: int) -> Dictionary:
	var next := _dup(battle)
	var after_shield := maxi(0, int(next["player"]["shield"]) - amount)
	var leftover := maxi(0, amount - int(next["player"]["shield"]))
	next["player"]["shield"] = after_shield
	next["player"]["hp"] = maxi(0, int(next["player"]["hp"]) - leftover)
	# TRIGGER_COST 受击触发：单次攻击事件最多触发 1 次；扣真元减伤。
	for instance_id in (next["active_permanents"] as Array).duplicate():
		var slot := _find_slot(next, str(instance_id))
		if slot.is_empty() or str(slot.get("durability_mode", "")) != "TRIGGER_COST":
			continue
		if int(next["player"]["true_qi"]) < int(slot.get("trigger_qi_cost", 0)):
			# 真元不足：蛊关闭移出激活列表。
			next["active_permanents"] = (next["active_permanents"] as Array).duplicate()
			(next["active_permanents"] as Array).erase(str(instance_id))
			continue
		next["player"]["true_qi"] = int(next["player"]["true_qi"]) - int(slot.get("trigger_qi_cost", 0))
		next["player"]["hp"] = maxi(0, int(next["player"]["hp"]) + int(slot.get("trigger_block", 0)))
		_log(next, "trigger_block", str(instance_id))
	_check_player_death(next)
	return next


static func _seal_random_gu(battle: Dictionary, turns: int) -> Dictionary:
	var next := _dup(battle)
	var candidates: Array[int] = []
	for i in (next["gu_slots"] as Array).size():
		var slot: Dictionary = next["gu_slots"][i]
		if not bool(slot.get("is_sealed", false)) and not bool(slot.get("consumed", false)):
			candidates.append(i)
	if candidates.is_empty():
		return next
	var seed_index := int(battle.get("turn", 1)) % candidates.size()
	var target := candidates[seed_index]
	next["gu_slots"][target] = (next["gu_slots"][target] as Dictionary).duplicate(true)
	next["gu_slots"][target]["is_sealed"] = true
	next["gu_slots"][target]["seal_turns"] = turns
	_log(next, "sealed", str(next["gu_slots"][target]["instance_id"]))
	return next


## 玩家回合开始（第 1 回合已在 start() 完成，此后每回合调用）：
## 1) 真元回复（上限×资质比例，向上取整）并钳制；2) 行动计数清零；
## 3) 念头=魂魄底蕴分档行动数；4) 全部蛊解除一次释放限制；5) 封印倒计时；
## 6) PER_TURN_MAINTAIN 总维持扣费（不足则全部关闭）。
static func _start_player_turn(battle: Dictionary) -> Dictionary:
	var next := _dup(battle)
	var player: Dictionary = next["player"].duplicate(true)
	player["true_qi"] = mini(int(player["true_qi_max"]), int(player["true_qi"]) + int(player["regen"]))
	player["used_this_turn"] = 0
	player["thoughts"] = ActionPointsScript.per_turn(int(player["soul"]))
	next["player"] = player
	for i in (next["gu_slots"] as Array).size():
		var slot: Dictionary = next["gu_slots"][i].duplicate(true)
		slot["used_this_turn"] = false
		if bool(slot.get("is_sealed", false)):
			slot["seal_turns"] = int(slot.get("seal_turns", 0)) - 1
			if int(slot.get("seal_turns", 0)) <= 0:
				slot["is_sealed"] = false
		next["gu_slots"][i] = slot
	# PER_TURN_MAINTAIN 维持结算
	var total := 0
	for instance_id in (next["active_permanents"] as Array).duplicate():
		var slot := _find_slot(next, str(instance_id))
		if slot.is_empty():
			(next["active_permanents"] as Array).erase(str(instance_id))
			continue
		if str(slot.get("durability_mode", "")) == "PER_TURN_MAINTAIN":
			total += int(slot.get("maintain_qi_cost", 0))
	if total > 0:
		if int(next["player"]["true_qi"]) >= total:
			next["player"]["true_qi"] = int(next["player"]["true_qi"]) - total
		else:
			next["active_permanents"] = []
	_log(next, "turn_start", str(next["turn"]))
	return next


# ---------- 死亡与胜负 ----------

static func _check_player_death(battle: Dictionary) -> void:
	var player: Dictionary = battle["player"]
	if int(player["hp"]) <= 0 or int(player["life_time"]) <= 0 or int(player["soul"]) <= 0:
		battle["phase"] = "defeat"
		battle["result"] = {"outcome": "death", "cause": _death_cause(player)}


static func _death_cause(player: Dictionary) -> String:
	if int(player["hp"]) <= 0:
		return "hp"
	if int(player["life_time"]) <= 0:
		return "life_cost"
	return "soul"


static func _mark_death(battle: Dictionary, cause: String) -> Dictionary:
	var next := _dup(battle)
	next["phase"] = "defeat"
	next["result"] = {"outcome": "death", "cause": cause}
	return next


static func _check_victory(battle: Dictionary) -> void:
	# Q8-POST：全灭判定同样以 hp > 0 为准——hp 归零的敌即使 alive 遗留 true
	# 也计入全灭，避免「打不死的敌人」。
	for enemy in battle["enemies"]:
		if _enemy_is_alive(enemy):
			return
	battle["phase"] = "victory"
	battle["result"] = {"outcome": "victory"}


static func _is_over(battle: Dictionary) -> bool:
	return str(battle.get("phase", "")) == "victory" or str(battle.get("phase", "")) == "defeat"


# ---------- 工具 ----------

static func _find_slot(battle: Dictionary, instance_id: String) -> Dictionary:
	for slot in battle["gu_slots"]:
		if str(slot.get("instance_id", "")) == instance_id:
			return slot
	return {}


static func _find_slot_index(battle: Dictionary, instance_id: String) -> int:
	for i in (battle["gu_slots"] as Array).size():
		if str(battle["gu_slots"][i]["instance_id"]) == instance_id:
			return i
	return -1


static func _dup(battle: Dictionary) -> Dictionary:
	return battle.duplicate(true)


static func _log(battle: Dictionary, reason: String, target: String) -> void:
	(battle["log"] as Array).append({
		"turn": int(battle["turn"]),
		"reason": reason,
		"target": target,
	})


static func _result(battle: Dictionary, ok: bool, reason: String) -> Dictionary:
	return {"battle": battle, "result": {"ok": ok, "reason": reason, "changes": []}}
