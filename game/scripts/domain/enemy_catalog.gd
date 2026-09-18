class_name EnemyCatalog
extends RefCounted


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const SeededRngScript = preload("res://scripts/domain/rng.gd")


## 主题标签：敌人与点位用它组"同主题池"（E6 敌人按层随机的池来源）。
## 新增主题必须同时登记在这里，否则 enemy_catalog.validate 会报错。
const THEMES: Array[String] = ["beast", "faction", "cultivator", "neutral", "anomaly"]


# ---------------------------------------------------------------------------
# 战力阶梯（用户裁定 2026-09-10 + 原著 CAN-CULTIVATION-001 / CAN-BEAST-TIER-001）
# ---------------------------------------------------------------------------
#   凡人 < 普通野兽 < 一转蛊修 < 二转 < 三转 < 四转 < 五转
#
# `rank` 是**层位**：1..5 对应一至五转；0 是"未入转"档。
# **蛊修最低一转** —— 所以 grade=cultivator 的条目 rank 必须 >= 1；
# 反过来，rank 0 只可能是非蛊修（普通野兽 / 凡人 / 不入转的异变体，如白毛僵尸）。
# `grade` 是**阶梯类别**（身份），与 `theme`（阵营/态度）正交：
# 散修 theme=neutral 但 grade=cultivator；山间猎户 theme=neutral 但 grade=mortal。
const GRADES: Array[String] = ["mortal", "beast", "cultivator", "anomaly"]
const RANK_UNINITIATED := 0        # 未入转：其下依次为普通野兽与凡人
const RANK_MIN_CULTIVATOR := 1     # 蛊修最低一转


static func load_all() -> Dictionary:
	var entries := _load_entries()
	var indexed := {}
	var ids_by_theme := {}
	for theme in THEMES:
		ids_by_theme[theme] = []
	for entry in entries:
		var enemy_id := str(entry.get("id", ""))
		indexed[enemy_id] = entry.duplicate(true)
		var theme := str(entry.get("theme", ""))
		if ids_by_theme.has(theme):
			(ids_by_theme[theme] as Array).append(enemy_id)
	return {"enemies": entries, "enemy_by_id": indexed, "enemy_ids_by_theme": ids_by_theme}


## 按主题取敌人 id 池。
## 未知名主题 / 池为空时回退到 fallback_ids —— **池空绝不返回空**，
## 调用方因此不需要额外的兜底分支（参考 Slay-The-Robot 的 EventPoolData.fallback 约定）。
static func enemy_pool(catalog: Dictionary, theme: String, fallback_ids: Array = []) -> Array:
	var pools: Dictionary = catalog.get("enemy_ids_by_theme", {})
	var pool: Array = (pools.get(theme, []) as Array).duplicate()
	if pool.is_empty():
		return fallback_ids.duplicate()
	return pool


## E6 按层抽取：给一个战斗节点抽 `count` 个**普通遭遇**敌人（2026-09-10）。
##
## 候选池 = 主题池 ∩ `rank_min <= rank <= rank_max` ∩ `tier != boss`。
## **Boss 绝不参与随机**：大层关底台是刻意摆放的锚点，随机抽到 Boss 会让层节奏
## 与"Boss 是刻意安排"同时失效（校验侧 `pacing.enemy_weights.boss == 0` 与之呼应）。
##
## `rank_min` 是"按层品质"的下界，避免深层还抽到山猪这类未入转的杂鱼；
## 若该区间**没有候选**（该主题在这一档确实很薄），自动放宽到 `0..rank_max` 重试一次，
## 再不行才回退——**绝不因为下界把某个主题整层抽空**。
##
## 抽取按 `tier_weights` 加权、**同节点内不重复**——节点上出现两个同名敌人会被
## `content_catalog` 当错误拒绝，所以抽取必须自带去重。
##
## 池空时回退 `fallback_ids`（通常是节点模板自带的 `enemy_kind` / `enemy_kinds`），
## **绝不返回空数组**，调用方不需要额外的兜底分支。
##
## 确定性：种子流 = `mixed_seed(seed, "enemy_roll:<salt>", 0)`，候选池先 `sort()`
## 以与字典/数组顺序解耦。**这条流与地图生成的共享流相互独立**，所以引入本功能
## 不会改动既有地图布局与既有种子产出。
static func roll_enemy_ids(catalog: Dictionary, theme: String, rank_min: int, rank_max: int,
		tier_weights: Dictionary, count: int, seed_value: int, salt: String,
		fallback_ids: Array = []) -> Array:
	var candidates := _rollable_candidates(catalog, theme, rank_min, rank_max)
	if candidates.is_empty():
		candidates = _rollable_candidates(catalog, theme, 0, rank_max)
	if candidates.is_empty():
		return fallback_ids.duplicate()
	candidates.sort()
	var rng: Variant = SeededRngScript.new(SeededRollScript.mixed_seed(seed_value, "enemy_roll:%s" % salt, 0))
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	var remaining := candidates.duplicate()
	var picked: Array = []
	for _slot in range(maxi(0, count)):
		if remaining.is_empty():
			break
		var chosen := _weighted_pick(rng, remaining, enemy_by_id, tier_weights)
		picked.append(remaining[chosen])
		remaining.remove_at(chosen)
	return picked


## 该主题在 `[rank_min, rank_max]` 内可随机到的敌人（已排除 Boss）。
static func _rollable_candidates(catalog: Dictionary, theme: String, rank_min: int,
		rank_max: int) -> Array[String]:
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	var pools: Dictionary = catalog.get("enemy_ids_by_theme", {})
	var candidates: Array[String] = []
	for enemy_id_value in (pools.get(theme, []) as Array):
		var enemy_id := str(enemy_id_value)
		var definition: Dictionary = enemy_by_id.get(enemy_id, {})
		if str(definition.get("tier", "")) == "boss":
			continue
		var enemy_rank := int(definition.get("rank", 0))
		if enemy_rank < rank_min or enemy_rank > rank_max:
			continue
		candidates.append(enemy_id)
	return candidates


## 按 tier 权重从 `remaining` 里取一个下标。权重的 tier 取不到时按 1 计（退化为均匀），
## 权重合计为 0 时也退化为均匀——**不能因为权重表配错就抽不出敌人**。
static func _weighted_pick(rng: Variant, remaining: Array, enemy_by_id: Dictionary,
		tier_weights: Dictionary) -> int:
	var total := 0
	for enemy_id_value in remaining:
		total += _tier_weight(str(enemy_id_value), enemy_by_id, tier_weights)
	if total <= 0:
		return rng.next_index(remaining.size())
	var roll: int = rng.next_index(total)
	for index in range(remaining.size()):
		var weight := _tier_weight(str(remaining[index]), enemy_by_id, tier_weights)
		if roll < weight:
			return index
		roll -= weight
	return remaining.size() - 1


static func _tier_weight(enemy_id: String, enemy_by_id: Dictionary, tier_weights: Dictionary) -> int:
	var tier := str((enemy_by_id.get(enemy_id, {}) as Dictionary).get("tier", ""))
	return maxi(0, int(tier_weights.get(tier, 1)))


static func validate(entries: Array) -> Array[String]:
	var errors: Array[String] = []
	for entry in entries:
		var enemy_id := str(entry.get("id", "unknown"))
		var tier := str(entry.get("tier", "common"))
		if not tier in ["common", "elite", "boss"]:
			errors.append("enemy %s has invalid tier %s" % [enemy_id, tier])
		var theme := str(entry.get("theme", ""))
		if theme.is_empty():
			errors.append("enemy %s missing theme" % enemy_id)
		elif not THEMES.has(theme):
			errors.append("enemy %s has unknown theme %s" % [enemy_id, theme])
		# 阶梯：蛊修最低一转。见 GRADES / RANK_MIN_CULTIVATOR 的说明。
		var grade := str(entry.get("grade", ""))
		if grade.is_empty():
			errors.append("enemy %s missing grade" % enemy_id)
		elif not GRADES.has(grade):
			errors.append("enemy %s has unknown grade %s" % [enemy_id, grade])
		else:
			var rank_value: Variant = entry.get("rank", null)
			if _is_integral(rank_value):
				var enemy_rank := int(rank_value)
				if grade == "cultivator" and enemy_rank < RANK_MIN_CULTIVATOR:
					errors.append("enemy %s is a cultivator with rank %d; 蛊修最低一转（rank >= %d），rank %d 只可能是普通野兽或凡人"
							% [enemy_id, enemy_rank, RANK_MIN_CULTIVATOR, RANK_UNINITIATED])
				elif enemy_rank == RANK_UNINITIATED and grade == "cultivator":
					errors.append("enemy %s occupies the uninitiated rank 0 as a cultivator" % enemy_id)
		var reactions: Array = entry.get("reactions", [])
		for index in reactions.size():
			var reaction: Dictionary = reactions[index]
			for key in ["clue", "window", "trigger", "counter_status"]:
				if str(reaction.get(key, "")).is_empty():
					errors.append("enemy %s reaction %d missing %s" % [enemy_id, index, key])
		errors.append_array(_validate_phases(enemy_id, entry.get("phases", [])))
	return errors


# Phase tables (R5.7): until_hp_ratio values must stay inside (0, 1] and
# descend strictly in data order (later phases are reached at lower hp);
# every phase needs a non-empty intents array whose cooldown entries are
# non-negative integers.
static func _validate_phases(enemy_id: String, phases_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if phases_value == null:
		return errors
	if not phases_value is Array:
		errors.append("enemy %s phases must be an array" % enemy_id)
		return errors
	var phases: Array = phases_value
	var previous_ratio := INF
	for phase_index in phases.size():
		var phase: Dictionary = phases[phase_index]
		var ratio_value: Variant = phase.get("until_hp_ratio", null)
		if ratio_value is int or ratio_value is float:
			var ratio := float(ratio_value)
			if ratio <= 0.0 or ratio > 1.0:
				errors.append("enemy %s phase %d until_hp_ratio %s outside (0, 1]" % [enemy_id, phase_index, str(ratio_value)])
			elif ratio >= previous_ratio:
				errors.append("enemy %s phase %d until_hp_ratio must descend strictly (deeper phases unlock at lower hp)" % [enemy_id, phase_index])
			else:
				previous_ratio = ratio
		else:
			errors.append("enemy %s phase %d missing a numeric until_hp_ratio" % [enemy_id, phase_index])
		var intents: Array = phase.get("intents", [])
		if (intents as Array).is_empty():
			errors.append("enemy %s phase %d needs a non-empty intents array" % [enemy_id, phase_index])
		for intent_index in intents.size():
			var intent: Dictionary = intents[intent_index]
			var cooldown_value: Variant = intent.get("cooldown", 0)
			var integral := cooldown_value is int \
					or (cooldown_value is float and is_equal_approx(float(cooldown_value), floor(float(cooldown_value))))
			if not integral or int(cooldown_value) < 0:
				errors.append("enemy %s phase %d intent %d cooldown must be a non-negative integer" % [enemy_id, phase_index, intent_index])
	return errors


static func _load_entries() -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/enemies.json")) != OK:
		return []
	if json.data is Array:
		return json.data.duplicate(true)
	return []


static func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(float(value), floor(float(value)))
