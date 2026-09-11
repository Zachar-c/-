extends GutTest


# 剑道契约测试（T7，任务书 plans/2026-09-11-sword-school-landing-plan.md §4）。
#
# 5 条验收用例：
#   1. 40 只全部合法（显式 v1_effect、kind 白名单、status 白名单）
#   2. 转数单调（strike/shield/heal：amount(rank n+1) == amount(rank n) + 1，守住 F1 的坑）
#   3. 支援链生效（先出起势蛊再出主力蛊 → 主力 amount 增加，F4）
#   4. 出手顺序有含义（反序时主力吃不到加成）
#   5. 成本可预检（life_cost 蛊在寿元不足时被拒绝，失败原因可见，非静默致死）
#
# 数值口径：amount = 兜底 base + (rank - 1)（attack 2 / defense 3 / healing 2）；
# 行为保持红线：显式化前后伤害逐只相同（specs/2026-09-11-sword-gu-table.md）。
# 用例 5 用注入的演示剑蛊锁引擎预检路径（不扰动蛊池计数锁）；其余用真实目录。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const SchoolRulesScript = preload("res://scripts/domain/school_rules.gd")
const BattleSnapshotScript = preload("res://scripts/presentation/snapshots/battle_snapshot.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const SWORD_ROLE_BASE := {"attack": 2, "defense": 3, "healing": 2}
const SWORD_ROLE_KIND := {"attack": "strike", "defense": "shield", "healing": "heal"}

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _sword_defs() -> Array:
	var out: Array = []
	for id_value in catalog["gu_by_id"]:
		var def: Dictionary = catalog["gu_by_id"][id_value]
		if str(def.get("school", "")) == "sword":
			out.append(def)
	return out


func _enemy() -> Dictionary:
	return {
		"id": "sword_test_enemy", "label": "试招木人", "hp": 999,
		"intent": {"kind": "attack", "label": "测试意图", "damage": 0},
	}


func _run_with_sword(def_ids: Array) -> RunState:
	var run := RunState.new_run(20260911)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in def_ids.size():
		var instance_id := "sw_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(def_ids[index]),
			"state": "refined",
			"rank": 1,
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.cultivation = 3  # 抬到三转修为，绕开转数门禁（本套不测门禁，见 test_v1_battle_resolver）。
	run.sync_legacy_gu_projections()
	return run


func _battle_with_sword(def_ids: Array) -> Dictionary:
	return V1.start(_run_with_sword(def_ids), catalog, [_enemy()])


func _slot_index_by_def(battle: Dictionary, def_id: String) -> int:
	var index := 0
	for slot_value in battle["gu_slots"]:
		var slot: Dictionary = slot_value
		if str(slot.get("definition_id", "")) == def_id:
			return index
		index += 1
	return -1


# ── 用例 1：40 只全部合法 ─────────────────────────────────────────────

func test_sword_school_40_gu_all_have_valid_v1_effect() -> void:
	var defs := _sword_defs()
	assert_eq(defs.size(), 40, "剑道蛊恰 40 只（gu.json 锁定）")
	for def_value in defs:
		var def: Dictionary = def_value
		var gu_id := str(def.get("id", ""))
		var role := str(def.get("role", ""))
		var effect: Dictionary = def.get("v1_effect", {})
		# T2–T4 显式化范围 = attack/defense/healing/movement 30 只；
		# recon/logistics 10 只按 D3 裁定走兜底（显式为空是合法状态）。
		if role in ["attack", "defense", "healing", "movement"]:
			assert_false(effect.is_empty(), "%s 显式声明 v1_effect（显式化后不得回退兜底）" % gu_id)
		if effect.is_empty():
			continue
		var kind := str(effect.get("kind", ""))
		assert_true(ContentCatalog.V1_EFFECT_KIND_IDS.has(kind),
			"%s kind 在白名单内（实际=%s）" % [gu_id, kind])
		if kind == "status":
			assert_true(ContentCatalog.V1_STATUS_IDS.has(str(effect.get("name", ""))),
				"%s status 名在白名单内（实际=%s）" % [gu_id, str(effect.get("name", ""))])


# ── 用例 2：转数单调（F1 红线） ───────────────────────────────────────

func test_sword_rank_amounts_are_monotonic() -> void:
	for def_value in _sword_defs():
		var def: Dictionary = def_value
		var effect: Dictionary = def.get("v1_effect", {})
		if effect.is_empty():
			continue
		var role := str(def.get("role", ""))
		if not SWORD_ROLE_BASE.has(role):
			continue
		if str(effect.get("kind", "")) != str(SWORD_ROLE_KIND[role]):
			continue
		var rank := int(def.get("rank", 1))
		var expected := int(SWORD_ROLE_BASE[role]) + (rank - 1)
		assert_eq(int(effect.get("amount", 0)), expected,
			"%s amount 应为 base+%d（role=%s rank=%d，F1 转数单调）"
			% [str(def.get("id", "")), rank - 1, role, rank])


# ── 用例 3/4：支援链（F4 起势→出剑） ─────────────────────────────────

func test_sword_support_chain_boosts_follow_up_strike() -> void:
	# 1_05=起势（support_bonus 1），2_12=直刺（无支援字段）。
	var battle := _battle_with_sword(["sword_atk_1_05_gu", "sword_atk_2_12_gu"])
	var support_index := _slot_index_by_def(battle, "sword_atk_1_05_gu")
	var main_index := _slot_index_by_def(battle, "sword_atk_2_12_gu")
	assert_true(support_index >= 0, "起势蛊入槽")
	assert_true(main_index >= 0, "主力蛊入槽")
	var hp_before := int(battle["enemies"][0]["hp"])

	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": support_index})
	assert_true(out["result"]["ok"], "起势蛊可出：%s" % str(out["result"]))
	var mid: Dictionary = out["battle"]
	var out2 := V1.player_action(mid, {"type": "play_gu", "slot_index": main_index})
	assert_true(out2["result"]["ok"], "主力蛊可出：%s" % str(out2["result"]))
	# 起势 strike 2 + 登记支援 +1 → 直刺 rank2 实际打 3+1=4：总伤 6。
	assert_eq(int(out2["battle"]["enemies"][0]["hp"]), hp_before - 6,
		"支援链：后手主力吃到 +1（F4）")


func test_sword_strike_before_support_gets_no_bonus() -> void:
	var battle := _battle_with_sword(["sword_atk_1_05_gu", "sword_atk_2_12_gu"])
	var support_index := _slot_index_by_def(battle, "sword_atk_1_05_gu")
	var main_index := _slot_index_by_def(battle, "sword_atk_2_12_gu")
	var hp_before := int(battle["enemies"][0]["hp"])

	# 反序：直刺先出（无支援可吃，打基础 3），起势后出（支援无人消费，打 2）。
	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": main_index})
	assert_true(out["result"]["ok"])
	var mid: Dictionary = out["battle"]
	var out2 := V1.player_action(mid, {"type": "play_gu", "slot_index": support_index})
	assert_true(out2["result"]["ok"])
	assert_eq(int(out2["battle"]["enemies"][0]["hp"]), hp_before - 5,
		"反序无加成：3 + 2（F4 策略性：顺序有含义）")


func test_sword_support_resets_on_end_turn() -> void:
	var battle := _battle_with_sword(["sword_atk_1_05_gu", "sword_atk_1_06_gu"])
	var support_index := _slot_index_by_def(battle, "sword_atk_1_05_gu")
	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": support_index})
	assert_true(out["result"]["ok"])
	var mid: Dictionary = out["battle"]
	var end_out := V1.player_action(mid, {"type": "end_turn"})
	assert_true(end_out["result"]["ok"], "end_turn 成功：%s" % str(end_out["result"]))
	var next: Dictionary = end_out["battle"]
	assert_eq((next.get("turn_supports", {}) as Dictionary).size(), 0,
		"end_turn 后 turn_supports 清零（v1_battle_resolver.gd:603）")


# ── 用例 5：成本可预检（非静默致死红线） ─────────────────────────────

func test_sword_life_cost_gu_rejected_with_visible_reason() -> void:
	var cat := ContentCatalog.load_all()
	# 注入演示剑蛊：寿元代价 61 > 玩家寿元 60 → 施放必死，必须被拒绝且原因可见。
	# rank=1（一转可驱），确保拒绝发生在 life_cost 预检而非转数门禁。
	cat["gu_by_id"]["v1_sword_demo_life_gu"] = {
		"id": "v1_sword_demo_life_gu", "combat": "sword_attack_pattern", "school": "sword",
		"role": "attack", "rank": 1, "rarity": "common", "true_qi_cost": 1, "life_cost": 61,
		"v1_effect": {"kind": "strike", "amount": 2},
	}
	var battle := V1.start(_run_with_sword(["v1_sword_demo_life_gu"]), cat, [_enemy()])
	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(out["result"]["ok"], "寿元不足时 life_cost 蛊被拒绝（非静默致死）")
	assert_eq(str(out["result"]["reason"]), "life_cost_depleted",
		"失败原因可见：life_cost_depleted（实际=%s）" % str(out["result"]))
	# 引擎语义：代价真实结算——寿元扣到 0 并标记死亡，失败原因显式可见（红线 6）。
	assert_eq(int(out["battle"]["player"]["life_time"]), 0, "寿元代价真实结算（60-61→0）")


# ── T8：跨回合剑意（school_rules 契约，仿 blood_stacks 形状） ─────────

func test_sword_intent_stacks_cap_decay_and_isolation() -> void:
	var battle := {}
	assert_eq(SchoolRulesScript.sword_intent(battle), 0, "缺键回退 0")
	assert_eq(SchoolRulesScript.add_sword_intent(battle, 3), 3, "叠层")
	assert_eq(SchoolRulesScript.add_sword_intent(battle, 3), 5, "上限 5")
	assert_eq(SchoolRulesScript.add_sword_intent(battle, 1), 5, "超上限不溢出")
	assert_eq(SchoolRulesScript.add_sword_intent(battle, -2), 3, "可减")
	# 衰减：50% 向下取整（3→1）。
	assert_eq(SchoolRulesScript.decay_sword_intent(battle), 1, "衰减 50% 向下取整")
	assert_eq(SchoolRulesScript.decay_sword_intent(battle), 0, "1→0，不出现负数")
	# 与回合内 turn_supports 不串味：独立键，互不清除。
	battle = {"turn_supports": {"sword": 2}}
	SchoolRulesScript.add_sword_intent(battle, 2)
	assert_eq(int((battle["turn_supports"] as Dictionary).get("sword", 0)), 2,
		"加剑意不动 turn_supports")
	SchoolRulesScript.decay_sword_intent(battle)
	assert_eq(int((battle["turn_supports"] as Dictionary).get("sword", 0)), 2,
		"衰减不动 turn_supports（那是 resolver end_turn 的职责）")
	assert_eq(SchoolRulesScript.sword_intent(battle), 1, "剑意独立存续")


# ── T14：剑道杀招 6 线 × 转数矩阵（specs/2026-09-11-sword-kill-move-list.md v2）──
#
# 矩阵口径：总威力 = Σ 配方**攻击蛊**动效；转数门槛 = 配方蛊最高转数；配方全为剑道蛊。
# 期望值直接抄自 v2 矩阵的「威能」列（改数值必须同步改表，防漂移）。

const SWORD_KILL_MOVE_MATRIX := {
	"double_edge": {1: 4, 2: 6, 4: 8, 5: 12},
	"qi_surge": {1: 2, 2: 3, 4: 5, 5: 6},
	"myriad_shadows": {2: 9, 3: 9, 4: 11, 5: 18},
	"mark_seek": {1: 2, 2: 3, 4: 5, 5: 6},
	"five_fingers": {2: 15, 4: 17, 5: 24},
	"myriad_tribulation": {2: 9, 4: 11, 5: 18},
}


func _kill_move_config(km_id: String) -> Dictionary:
	var v1_battle: Dictionary = catalog.get("v1_battle", {})
	for km_value in v1_battle.get("kill_moves", []):
		var km: Dictionary = km_value
		if str(km.get("id", "")) == km_id:
			return km
	return {}


func _kill_move_entry(battle: Dictionary, km_id: String) -> Dictionary:
	for km_value in battle.get("kill_moves", []):
		var km: Dictionary = km_value
		if str(km.get("id", "")) == km_id:
			return km
	return {}


func test_sword_kill_move_matrix_is_complete_and_gated() -> void:
	for line_id in SWORD_KILL_MOVE_MATRIX:
		var variants: Dictionary = SWORD_KILL_MOVE_MATRIX[line_id]
		for turn_value in variants:
			var turn := int(turn_value)
			var km_id := "km_sword_%s_%d" % [line_id, turn]
			var km := _kill_move_config(km_id)
			assert_ne(km, Dictionary(), "%s 已落库（矩阵线 %s 第 %d 转）" % [km_id, line_id, turn])
			if km.is_empty():
				continue
			assert_eq(str(km.get("tag", "")), "sword", "%s 道归属为剑道" % km_id)
			var recipe: Array = km.get("recipe", [])
			assert_true(recipe.size() >= 2, "%s 配方非空（杀招 = 多蛊组合）" % km_id)
			assert_eq(recipe.size(), (recipe as Array).duplicate().size(), "%s 配方可枚举" % km_id)
			var sigma := 0
			var max_rank := 0
			for def_id_value in recipe:
				var def_id := str(def_id_value)
				var def: Dictionary = catalog["gu_by_id"].get(def_id, {})
				assert_false(def.is_empty(), "%s 配方引用真实蛊 %s" % [km_id, def_id])
				if def.is_empty():
					continue
				assert_eq(str(def.get("school", "")), "sword",
					"%s 配方蛊 %s 属剑道（吃同流派支援的前提）" % [km_id, def_id])
				if str(def.get("role", "")) == "attack":
					sigma += int((def.get("v1_effect", {}) as Dictionary).get("amount", 0))
				max_rank = maxi(max_rank, int(def.get("rank", 1)))
			assert_eq(int((km.get("effect", {}) as Dictionary).get("amount", 0)), sigma,
				"%s effect.amount = Σ 配方攻击蛊动效（%d）" % [km_id, sigma])
			assert_eq(sigma, int(variants[turn_value]),
				"%s 威能与 v2 矩阵一致（%d）" % [km_id, int(variants[turn_value])])
			assert_eq(max_rank, turn,
				"%s 转数门槛 = 配方最高转数（%d）" % [km_id, max_rank])
			assert_gt(int(km.get("thought_cost", 0)), 0, "%s 吃念头（大招约束）" % km_id)


func test_sword_kill_move_labels_follow_line_and_turn() -> void:
	var labels := {
		"km_sword_double_edge_1": "双锋引·一转",
		"km_sword_myriad_shadows_3": "剑影万千·三转",
		"km_sword_myriad_tribulation_5": "万剑劫·五转",
		"km_sword_five_fingers_5": "五指拳心剑·五转",
		"km_sword_mark_seek_4": "剑痕索命·四转",
		"km_sword_qi_surge_4": "剑气冲霄·四转",
	}
	for km_id in labels:
		var km := _kill_move_config(km_id)
		assert_eq(str(km.get("label", "")), str(labels[km_id]),
			"%s 玩家可见标签按「杀招线 · 转数」命名" % km_id)


func test_sword_kill_move_eats_same_school_support() -> void:
	# 起势蛊（1_05，support_bonus 1）先出 → 后手剑道杀招吃到 +1（F4 支援只惠及后续同流派）。
	# 杀招换用不含 1_05 的配方线，避免「配方蛊已出手」与支援语义混淆。
	var battle := _battle_with_sword([
		"sword_atk_1_05_gu", "sword_atk_2_12_gu", "sword_rec_1_10_gu",
	])
	var support_index := _slot_index_by_def(battle, "sword_atk_1_05_gu")
	var hp_before := int(battle["enemies"][0]["hp"])
	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": support_index})
	assert_true(out["result"]["ok"], "起势蛊可出：%s" % str(out["result"]))
	var mid: Dictionary = out["battle"]
	var out2 := V1.player_action(mid, {"type": "play_kill_move", "kill_move_id": "km_sword_mark_seek_2"})
	assert_true(out2["result"]["ok"], "杀招可放：%s" % str(out2["result"]))
	# 起势 strike 2 + 剑痕索命·二转 strike 3 + 支援 1 = 6。
	assert_eq(int(out2["battle"]["enemies"][0]["hp"]), hp_before - 6,
		"剑道杀招吃本回合同流派支援（+1）")


func test_sword_kill_move_records_reveal_after_use() -> void:
	var battle := _battle_with_sword(["sword_atk_1_05_gu", "sword_atk_1_06_gu"])
	assert_eq(bool(_kill_move_entry(battle, "km_sword_double_edge_1").get("reveals", true)), false,
		"使用前未泄密")
	assert_eq((battle.get("revealed_to", []) as Array).size(), 0, "使用前无洞悉记录")
	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_sword_double_edge_1"})
	assert_true(out["result"]["ok"], "释放成功：%s" % str(out["result"]))
	var next: Dictionary = out["battle"]
	assert_true(bool(_kill_move_entry(next, "km_sword_double_edge_1").get("reveals", false)),
		"使用后本条进入已泄密态（原文：用一次即被洞悉）")
	assert_true((next.get("revealed_to", []) as Array).has("sword_test_enemy"),
		"在场敌人被记入 revealed_to；实际=%s" % str(next.get("revealed_to", [])))


func test_sword_myriad_shadows_releases_for_sigma_damage() -> void:
	var run := _run_with_sword([
		"sword_atk_2_12_gu", "sword_atk_2_13_gu", "sword_atk_2_19_gu", "sword_mov_3_15_gu",
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	var ids := []
	for km_value in battle.get("kill_moves", []):
		ids.append(str((km_value as Dictionary).get("id", "")))
	assert_true(ids.has("km_sword_myriad_shadows_3"), "三转剑影可见；实际=%s" % str(ids))
	var hp_before := int(battle["enemies"][0]["hp"])
	var qi_before := int(battle["player"]["true_qi"])
	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_sword_myriad_shadows_3"})
	assert_true(out["result"]["ok"], "释放成功：%s" % str(out["result"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), hp_before - 9, "剑影万千结算 strike 9")
	assert_eq(int(out["battle"]["player"]["true_qi"]), qi_before - 5, "真元扣 5")


func test_sword_myriad_tribulation_releases_for_sigma_damage() -> void:
	var run := _run_with_sword([
		"sword_atk_5_02_gu", "sword_atk_5_03_gu", "sword_atk_5_04_gu", "sword_rec_5_17_gu",
	])
	run.cultivation = 5  # 五转修为可驱五转蛊。
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	var ids := []
	for km_value in battle.get("kill_moves", []):
		ids.append(str((km_value as Dictionary).get("id", "")))
	assert_true(ids.has("km_sword_myriad_tribulation_5"), "五转万剑劫可见；实际=%s" % str(ids))
	var hp_before := int(battle["enemies"][0]["hp"])
	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_sword_myriad_tribulation_5"})
	assert_true(out["result"]["ok"], "释放成功：%s" % str(out["result"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), hp_before - 18, "万剑劫结算 strike 18（3×6）")


# ── T15：刻痕通道（回合末按 marked 层数结算独立伤害） ─────────────────
#
# 规格：specs/2026-09-12-sword-p2-t15-t16-spec.md §1（D15-1 线性 / D15-2 不衰减 /
# D15-3 不吃护盾 / D15-5 参数落 v1_battle.json）。
# 原文依据：重查报告 §2-M3「刻印下来的剑道道痕……自寻目标的弱点，加以攻击」；
# 「表面伤口很快就自己愈合了，但刻印……不会消失」⇒ 不衰减。

func _battle_with_marks(layers: int, extra: Dictionary = {}) -> Dictionary:
	## _build_enemies 不接收 shield/statuses（引擎侧固定初值），故 start 后注入。
	var battle := V1.start(_run_with_sword(["sword_rec_1_10_gu"]), catalog, [_enemy()])
	var enemy: Dictionary = (battle["enemies"][0] as Dictionary).duplicate(true)
	enemy["statuses"] = {"marked": layers}
	for key in extra:
		enemy[key] = extra[key]
	battle["enemies"][0] = enemy
	return battle


func test_mark_scratch_damages_enemy_at_end_turn() -> void:
	# 端到端：出青锋蛊（recon → status marked 1 层）→ 回合末结算 1 点。
	var battle := V1.start(_run_with_sword(["sword_rec_1_10_gu"]), catalog, [_enemy()])
	var slot := _slot_index_by_def(battle, "sword_rec_1_10_gu")
	assert_true(slot >= 0, "侦察蛊入槽")
	var hp_before := int(battle["enemies"][0]["hp"])
	var played := V1.player_action(battle, {"type": "play_gu", "slot_index": slot})
	assert_true(played["result"]["ok"], "侦察蛊可出：%s" % str(played["result"]))
	var marked := int((played["battle"]["enemies"][0].get("statuses", {}) as Dictionary).get("marked", 0))
	assert_eq(marked, 1, "命中后登记 1 层刻痕")
	var ended := V1.player_action(played["battle"], {"type": "end_turn"})
	assert_true(ended["result"]["ok"], "end_turn 成功：%s" % str(ended["result"]))
	assert_eq(int(ended["battle"]["enemies"][0]["hp"]), hp_before - 1, "回合末刻痕结算 1 点")
	var reasons := []
	for entry_value in (ended["battle"].get("log", []) as Array):
		reasons.append(str((entry_value as Dictionary).get("reason", "")))
	assert_true(reasons.has("mark_scratch"), "刻痕结算写入战斗日志；实际=%s" % str(reasons))


func test_mark_scratch_is_an_independent_channel_ignoring_shield() -> void:
	# 独立通道：道痕自寻弱点 ⇒ 不吃护盾。3 层刻痕打 3 点，护盾分毫不动。
	var battle := _battle_with_marks(3, {"shield": 50})
	var hp_before := int(battle["enemies"][0]["hp"])
	var ended := V1.player_action(battle, {"type": "end_turn"})
	assert_true(ended["result"]["ok"], "end_turn 成功：%s" % str(ended["result"]))
	assert_eq(int(ended["battle"]["enemies"][0]["hp"]), hp_before - 3, "3 层刻痕 = 3 点伤害（线性）")
	assert_eq(int(ended["battle"]["enemies"][0]["shield"]), 50, "刻痕不吃护盾（独立通道）")


func test_mark_scratch_does_not_decay_and_can_finish_the_fight() -> void:
	# 不衰减（原文「刻印不会消失」）：后续回合仍按同层数结算。
	var first := V1.player_action(_battle_with_marks(2), {"type": "end_turn"})
	assert_eq(int(first["battle"]["enemies"][0]["hp"]), 997, "第一回合 -2（999→997）")
	assert_eq(int((first["battle"]["enemies"][0].get("statuses", {}) as Dictionary).get("marked", 0)), 2,
			"刻痕不衰减")
	var second := V1.player_action(first["battle"], {"type": "end_turn"})
	assert_eq(int(second["battle"]["enemies"][0]["hp"]), 995, "第二回合再 -2（跨回合持续追打）")
	# 层数上限：注入远超上限的层数时按 mark_scratch_cap 截断（默认 10）。
	var capped_end := V1.player_action(_battle_with_marks(999), {"type": "end_turn"})
	assert_eq(int(capped_end["battle"]["enemies"][0]["hp"]), 989, "层数上限 10 ⇒ 单次最多 10 伤害")
	# 刻痕可以收掉残敌（正常胜利判定）。
	var lethal_end := V1.player_action(_battle_with_marks(2, {"hp": 2}), {"type": "end_turn"})
	assert_eq(str(lethal_end["battle"]["phase"]), "victory", "刻痕击破敌人 → 战斗胜利")


# ── T10：剑道道痕登记（体印 → 知识图谱「身上道痕」转义） ──────────────
#
# 转义边界：`mark_<school>` 前缀的体印才是**道痕**（图谱 L2「身上道痕」节点，
# 属性 = 道归属 + 层数）；iron_bone / ice_skin / three_watch 是淬体类体印，
# 无道归属，不进图谱。依据 specs/2026-09-11-gu-knowledge-graph.md §1-L2 / §2。

func _run_with_marks(marks: Array) -> RunState:
	var run := RunState.new_run(20260912)
	for mark in marks:
		run.body_imprints.append(str(mark))
	return run


func test_sword_dao_mark_registers_through_the_body_imprint_ledger() -> void:
	var out := Resolver.apply(
		RunState.new_run(20260912),
		{"type": "take_body_imprint", "imprint_id": "mark_sword"},
		catalog)
	assert_true(out["result"]["ok"], "mark_sword 可取：%s" % str(out["result"]))
	var next: RunState = out["state"]
	assert_true(next.body_imprints.has("mark_sword"), "剑道道痕入账 body_imprints")
	assert_true(next.known_facts.has("sword_dao_mark"), "道痕事实入账")
	assert_true(next.known_facts.has("sword_dao_mark_erosion"), "侵蚀性事实入账（原文：剑道道痕似乎有侵蚀性）")
	assert_eq(str(next.event_log.back()["action"]), "take_body_imprint", "写入不可变事件日志")
	assert_eq(str(next.event_log.back()["reason"]), "body_imprint_sword_mark", "事件带理由")
	assert_eq(int(next.injury), 0, "获得瞬间不结算伤势（代价在排斥与残锋）")
	# 快照可读：结局账本从事件日志重建 body_imprints（既有消费方）。
	var rebuilt: Dictionary = JournalBuilder._log_snapshot(next.event_log)
	assert_true((rebuilt["body_imprints"] as Array).has("mark_sword"), "结局账本可重建该道痕")
	assert_true(RunState.STATE_FIELDS.has("body_imprints"), "随存档持久化（STATE_FIELDS 同源）")


func test_body_imprints_translate_to_school_marks_only_for_mark_prefix() -> void:
	var run := _run_with_marks(["iron_bone", "mark_sword"])
	assert_eq(SchoolRulesScript.school_marks(run), {"sword": 1},
		"只有 mark_<school> 转义为图谱节点；淬体体印不进图谱")
	assert_eq(SchoolRulesScript.mark_layers(run, "sword"), 1, "剑道道痕 1 层")
	assert_eq(SchoolRulesScript.mark_layers(run, "water"), 0, "未染水道 → 0 层")
	assert_eq(SchoolRulesScript.school_of_mark("mark_sword"), "sword", "id 前缀即道归属")
	assert_eq(SchoolRulesScript.school_of_mark("iron_bone"), "", "非道痕体印无道归属")
	assert_eq(SchoolRulesScript.school_marks(RunState.new_run(20260912)), {}, "无体印 → 空图谱")


# ── T11：兼修代价（cross_school_penalty） ─────────────────────────────

func test_cross_school_penalty_needs_two_marks_and_flags_sword_water_exclusion() -> void:
	var single := _run_with_marks(["mark_sword"])
	var no_penalty := SchoolRulesScript.cross_school_penalty(single, catalog)
	assert_eq(int(no_penalty["penalty"]), 0, "单道无罚")
	assert_eq(str(no_penalty["reason"]), "", "单道不产生排斥理由")
	assert_eq(no_penalty["excluded_pairs"], [], "单道无互斥对")

	var mixed := _run_with_marks(["mark_sword", "mark_water"])
	var excluded := SchoolRulesScript.cross_school_penalty(mixed, catalog)
	assert_eq(int(excluded["count"]), 2, "两道并存")
	assert_gt(int(excluded["penalty"]), 0, "混 2 道起罚")
	assert_eq(excluded["excluded_pairs"], [["sword", "water"]],
		"剑道与水道互斥（原文：残留的剑道道痕……隔绝了水道道痕）")
	assert_eq(str(excluded["reason"]), "cross_school_penalty", "理由可见")

	var three := _run_with_marks(["mark_sword", "mark_water", "mark_blood"])
	var more := SchoolRulesScript.cross_school_penalty(three, catalog)
	assert_gt(int(more["penalty"]), int(excluded["penalty"]), "道越多罚越重")
	assert_eq(more, SchoolRulesScript.cross_school_penalty(three, catalog),
		"确定性：同输入同输出")


# ── 真机验收：杀招的可达性 ────────────────────────────────────────────

func test_kill_screen_lists_buildable_moves_outside_battle() -> void:
	# 真机反馈「找不到构筑杀招的入口」：非战斗时杀招屏是三张「未研习」空卡。
	# V1 杀招没有研习步骤——持有配方蛊即自动成招，所以屏上必须给出可组清单
	# 与「还缺哪只」，否则玩家永远不知道杀招从哪来。
	var controller = RunControllerScript.new()
	controller.start_new_run(101, "sword", [], [])
	var snapshot: Dictionary = BattleSnapshotScript.build_kill(controller)
	var moves: Array = snapshot.get("kill_moves", [])
	assert_false(moves.is_empty(), "非战斗时须给出可组清单，不得是空态")
	var ids: Array = []
	for m in moves:
		ids.append(str((m as Dictionary).get("id", "")))
	assert_true(ids.has("km_sword_double_edge_1"),
			"开局一转剑蛊应能组出双锋引；实际=%s" % str(ids))
	var first: Dictionary = moves[0]
	assert_string_contains(str(first.get("intro", "")), "配方已齐",
			"已可组的杀招须明示；实际=%s" % str(first.get("intro", "")))
	assert_false(str(first.get("sequence_display", "")).is_empty(),
			"须显示配方构成")
