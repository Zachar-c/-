extends GutTest


## W11 迁移前置（2026-09-09）：蛊 role 基础动作兜底表数值契约与
## default_v1_effect 逻辑。六档 role 兜底（蛊定义未声明 v1_effect 时）：
## attack=strike 2 / defense=shield 3 / healing=heal 2 / movement=shift 1 /
## recon=status marked 1 / logistics=status bound 1；
## strike/shield/heal 随转数线性成长，shift/status 是位置与层数不成长。
## 表存 data/v1_battle.json 的 default_effect_by_role（原内嵌常量
## DEFAULT_EFFECT_BY_ROLE 迁移），数值契约由 shipped 断言钉死。


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


const ROLE_TABLE := {
	"attack": {"kind": "strike", "amount": 2},
	"defense": {"kind": "shield", "amount": 3},
	"healing": {"kind": "heal", "amount": 2},
	"movement": {"kind": "shift", "amount": 1},
	# Q7 B2（2026-09-12）：recon=刻痕+同流派支援（self 哨兵运行时注入流派）；
	# logistics 由死状态 bound 改为 heal（bound 全仓无消费者）。
	"recon": {"kind": "status", "name": "marked", "amount": 1, "support_school": "self", "support_bonus": 1},
	"logistics": {"kind": "heal", "amount": 1},
}


func test_shipped_role_table_in_v1_battle_json_matches_contract() -> void:
	var catalog := ContentCatalog.load_all()
	var table_value: Variant = (catalog.get("v1_battle", {}) as Dictionary).get("default_effect_by_role", {})
	assert_true(table_value is Dictionary, "v1_battle.json must ship default_effect_by_role")
	if not table_value is Dictionary:
		return
	# JSON 数值经 Godot 解析为 float（项目惯例：消费端 int()），此处逐项归一比较。
	var table := table_value as Dictionary
	assert_eq(table.size(), ROLE_TABLE.size())
	for role in ROLE_TABLE:
		assert_true(table.has(role), "role %s missing" % role)
		if not table.has(role):
			continue
		var effect: Variant = table[role]
		assert_true(effect is Dictionary, "role %s must be an effect object" % role)
		if not effect is Dictionary:
			continue
		var expected: Dictionary = ROLE_TABLE[role]
		assert_eq(str((effect as Dictionary).get("kind", "")), str(expected.get("kind", "")),
				"role %s kind" % role)
		assert_eq(int((effect as Dictionary).get("amount", 0)), int(expected.get("amount", 0)),
				"role %s amount" % role)
		assert_eq(str((effect as Dictionary).get("name", "")), str(expected.get("name", "")),
				"role %s name" % role)


func test_role_fallbacks_resolve_to_expected_effects() -> void:
	assert_eq(V1.default_v1_effect({"role": "attack", "rank": 1}, ROLE_TABLE),
			{"kind": "strike", "amount": 2})
	assert_eq(V1.default_v1_effect({"role": "defense", "rank": 1}, ROLE_TABLE),
			{"kind": "shield", "amount": 3})
	assert_eq(V1.default_v1_effect({"role": "healing", "rank": 1}, ROLE_TABLE),
			{"kind": "heal", "amount": 2})
	assert_eq(V1.default_v1_effect({"role": "movement", "rank": 1}, ROLE_TABLE),
			{"kind": "shift", "amount": 1})
	# Q7 B2：recon 刻痕+同流派支援（self 注入）；logistics 由死 bound 改 heal。
	assert_eq(V1.default_v1_effect({"role": "recon", "rank": 1, "school": "fire"}, ROLE_TABLE),
			{"kind": "status", "name": "marked", "amount": 1, "support_school": "fire", "support_bonus": 1})
	assert_eq(V1.default_v1_effect({"role": "logistics", "rank": 1}, ROLE_TABLE),
			{"kind": "heal", "amount": 1})


func test_strike_shield_heal_scale_with_rank() -> void:
	assert_eq(V1.default_v1_effect({"role": "attack", "rank": 3}, ROLE_TABLE),
			{"kind": "strike", "amount": 4})
	assert_eq(V1.default_v1_effect({"role": "defense", "rank": 5}, ROLE_TABLE),
			{"kind": "shield", "amount": 7})
	assert_eq(V1.default_v1_effect({"role": "healing", "rank": 2}, ROLE_TABLE),
			{"kind": "heal", "amount": 3})


func test_shift_and_status_do_not_scale_with_rank() -> void:
	assert_eq(V1.default_v1_effect({"role": "movement", "rank": 5}, ROLE_TABLE),
			{"kind": "shift", "amount": 1})
	# Q7 B2：marked 层数不随 rank 缩放（T15 限流）；梯度走 support_bonus。
	var recon5 := V1.default_v1_effect({"role": "recon", "rank": 5, "school": "wind"}, ROLE_TABLE)
	assert_eq(int(recon5.get("amount", 0)), 1, "marked 恒 1")
	assert_eq(int(recon5.get("support_bonus", 0)), 5, "support_bonus 随 rank")
	# logistics 走 heal（RANK_SCALED_KINDS），梯度免费。
	assert_eq(V1.default_v1_effect({"role": "logistics", "rank": 3}, ROLE_TABLE),
			{"kind": "heal", "amount": 3})


func test_unknown_or_empty_role_yields_no_fallback() -> void:
	assert_eq(V1.default_v1_effect({"role": "trade", "rank": 1}, ROLE_TABLE), {})
	assert_eq(V1.default_v1_effect({"role": "", "rank": 1}, ROLE_TABLE), {})
	assert_eq(V1.default_v1_effect({}, ROLE_TABLE), {})


func test_fallback_duplicates_table_so_caller_cannot_mutate_source() -> void:
	var out: Dictionary = V1.default_v1_effect({"role": "attack", "rank": 1}, ROLE_TABLE)
	out["amount"] = 99
	assert_eq(int(ROLE_TABLE["attack"]["amount"]), 2, "source table must stay untouched")
