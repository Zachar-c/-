extends GutTest


# Stage 1 纵向切片契约（specs/2026-09-16-stage1-gu-entity-vertical-slice-design.md）。
#
# 本切片不扩大目录，只证明 12 只名单在 catalog 侧已完备：
#   1. 每只均有显式 v1_effect（禁止静默 role 兜底）
#   2. 每只均有 feeding_need / feeding_cost
#   3. 新抬显式的 4 只效果可进战斗结算（与原兜底公式对齐）
#   4. 月光固定方 moon_glow_fixed 仍在、输入契约不变

const SLICE_GU := [
	"moonlight_gu",
	"small_light_gu",
	"moon_glow_gu",
	"moon_ray_gu",
	"moon_shadow_gu",
	"force_gu",
	"bear_strength_gu",
	"blood_droplet_gu",
	"blood_farewell_gu",
	"blood_def_1_21_gu",
	"blood_mov_1_22_gu",
	"sword_atk_1_05_gu",
]

# 原 role 兜底公式：attack 2 / defense 3 / healing 2 / movement shift 1；
# 月系 attack 在 rank2 为 4（moon_ray 与 moon_glow 同档）。
const EXPECTED_EFFECT := {
	"moonlight_gu": {"kind": "strike", "amount": 3},
	"small_light_gu": {"kind": "strike", "amount": 1},
	"moon_glow_gu": {"kind": "strike", "amount": 4},
	"moon_ray_gu": {"kind": "strike", "amount": 4},
	"moon_shadow_gu": null,  # 切片剧本可不出现；若填则必须是 shift
	"force_gu": {"kind": "strike", "amount": 2},
	"bear_strength_gu": {"kind": "heal", "amount": 2},
	"blood_droplet_gu": {"kind": "strike", "amount": 2},
	"blood_farewell_gu": {"kind": "strike", "amount": 4},
	"blood_def_1_21_gu": {"kind": "shield", "amount": 3},
	"blood_mov_1_22_gu": {"kind": "shift", "amount": 1},
	"sword_atk_1_05_gu": {"kind": "strike", "amount": 2},
}

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _def(gu_id: String) -> Dictionary:
	return (catalog["gu_by_id"] as Dictionary)[gu_id] as Dictionary


func test_slice_gu_all_present_in_catalog() -> void:
	for gu_id in SLICE_GU:
		assert_true((catalog["gu_by_id"] as Dictionary).has(gu_id), "切片蛊缺失: %s" % gu_id)


func test_slice_gu_have_explicit_v1_effects() -> void:
	for gu_id in SLICE_GU:
		var effect: Variant = _def(gu_id).get("v1_effect")
		if gu_id == "moon_shadow_gu":
			# 本切片剧本可不出现月影；若目录后续显式化，必须是 shift 而非兜底。
			if effect != null:
				assert_eq(str((effect as Dictionary).get("kind", "")), "shift",
					"moon_shadow 若显式化必须是 shift")
			continue
		assert_true(effect is Dictionary, "%s 缺显式 v1_effect（禁止 role 兜底）" % gu_id)
		var kind := str((effect as Dictionary).get("kind", ""))
		assert_true(kind in ["strike", "shield", "heal", "shift", "status", "weaken_intent"],
			"%s effect.kind 非法: %s" % [gu_id, kind])
		var expected: Variant = EXPECTED_EFFECT[gu_id]
		if expected != null:
			assert_eq(kind, str((expected as Dictionary).get("kind")), "%s kind 漂移" % gu_id)
			assert_eq(int((effect as Dictionary).get("amount", -1)),
				int((expected as Dictionary).get("amount")), "%s amount 漂移" % gu_id)


func test_slice_gu_have_feeding_fields() -> void:
	for gu_id in SLICE_GU:
		var def := _def(gu_id)
		assert_true(def.get("feeding_need") is Dictionary, "%s 缺 feeding_need" % gu_id)
		assert_true(int(def.get("feeding_cost", -1)) >= 1, "%s 缺 feeding_cost" % gu_id)


func test_newly_explicit_effects_reach_battle_slots() -> void:
	# 用 moon_ray / bear_strength / blood_def / blood_mov 进战斗槽，确认引擎读显式效果而非兜底。
	var run := RunState.new_run(20260916)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	var ids := ["moon_ray_gu", "bear_strength_gu", "blood_def_1_21_gu", "blood_mov_1_22_gu"]
	for index in ids.size():
		var instance_id := "s1_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": ids[index],
			"state": "refined",
			"rank": int(_def(ids[index]).get("rank", 1)),
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.cultivation = 3
	run.sync_legacy_gu_projections()
	var enemy := {
		"id": "slice_dummy", "label": "木桩", "hp": 99,
		"intent": {"kind": "attack", "label": "试", "damage": 0},
	}
	var battle := V1BattleResolver.start(run, catalog, [enemy])
	var by_def := {}
	for slot_value in battle["gu_slots"]:
		var slot: Dictionary = slot_value
		by_def[str(slot.get("definition_id", ""))] = slot
	for gu_id in ids:
		assert_true(by_def.has(gu_id), "战斗槽缺少 %s" % gu_id)
		var effect: Dictionary = by_def[gu_id].get("v1_effect", by_def[gu_id].get("effect", {}))
		assert_eq(str(effect.get("kind", "")), str(EXPECTED_EFFECT[gu_id]["kind"]),
			"%s 战斗槽 kind 须来自显式效果" % gu_id)
		assert_eq(int(effect.get("amount", -1)), int(EXPECTED_EFFECT[gu_id]["amount"]),
			"%s 战斗槽 amount 须来自显式效果" % gu_id)


func test_moon_glow_fixed_recipe_still_pinned() -> void:
	var recipe: Dictionary = (catalog["refinement_by_id"] as Dictionary)["moon_glow_fixed"]
	assert_eq(recipe.get("output_gu_id", ""), "moon_glow_gu")
	assert_eq(recipe.get("input_gu_ids", []),
		["moonlight_gu", "small_light_gu", "small_light_gu"])
	assert_true(bool(recipe.get("default_unlocked", false)), "月光固定方须默认可知")
