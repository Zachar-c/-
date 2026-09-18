extends SceneTree

# Q8-F / F8：标准 Run 经济模拟（**只读，不改任何生产数值 / 不写存档**）
#
# 用法：godot --headless --path . -s tools/q8f_f8_simulate.gd
#
# 方法：用真实领域代码（MapGenerator / LootResolver / MarketRules /
# GuBalance / ShopRules）在固定种子下推演五种 Run 原型：
#   A 新手 Run   B 正常 Run   C 富裕 Run   D 贫困 Run   E 高层 Run
# 每种原型跑固定种子集合，记录：初始财富 / 收入 / 支出 / 终局财富 /
# 核心材料 / 核心蛊 / 真元 / 寿元 / 魂。
#
# 本脚本不进入 RunCommand 命令面（只读 catalog + 纯函数），
# 因此不会污染状态、不会落事件日志、不需要存档校验。

const SEEDS: Array[int] = [1, 7, 13, 29, 42, 77, 101]
const LAYERS: Array[int] = [1, 2, 3, 4, 5]


func _initialize() -> void:
	var MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
	var LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
	var MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
	var GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
	var RunStateScript = preload("res://scripts/domain/run_state.gd")

	var catalog := _load_catalog()
	if catalog.is_empty():
		print("FATAL: catalog empty")
		quit(1)
		return

	print("######################################################################")
	print("# Q8-F F8 — STANDARD RUN ECONOMY SIMULATION (read-only)")
	print("######################################################################")
	print("seeds=%s layers=%s" % [str(SEEDS), str(LAYERS)])
	print("")

	# --- 原型定义 -----------------------------------------------------------
	# 每种原型 = 一组外生参数（不是改数值，而是描述"这类玩家怎么玩"）
	var archetypes := [
		{"id": "A_novice", "label": "新手", "combats_per_layer": 3,
			"elite_ratio": 0.1, "shop_visits_per_layer": 1, "spend_profile": "cheap"},
		{"id": "B_normal", "label": "正常", "combats_per_layer": 6,
			"elite_ratio": 0.25, "shop_visits_per_layer": 2, "spend_profile": "mixed"},
		{"id": "C_rich", "label": "富裕", "combats_per_layer": 9,
			"elite_ratio": 0.4, "shop_visits_per_layer": 3, "spend_profile": "aggressive"},
		{"id": "D_poor", "label": "贫困", "combats_per_layer": 2,
			"elite_ratio": 0.0, "shop_visits_per_layer": 0, "spend_profile": "none"},
		{"id": "E_late", "label": "高层", "combats_per_layer": 6,
			"elite_ratio": 0.35, "shop_visits_per_layer": 2, "spend_profile": "mixed",
			"start_layer": 4},
	]

	var agg := {}
	for arche in archetypes:
		agg[arche["id"]] = _empty_agg(arche)

	for arche in archetypes:
		print("======================================================================")
		print("ARCHETYPE %s (%s)" % [arche["id"], arche["label"]])
		print("======================================================================")
		for seed_value in SEEDS:
			_run_one(seed_value, arche, catalog, MapGeneratorScript, LootResolverScript,
					MarketRulesScript, GuBalanceScript, RunStateScript, agg[arche["id"]])
		_print_archetype(arche, agg[arche["id"]])

	print("")
	print("######################################################################")
	print("# SUMMARY TABLE")
	print("######################################################################")
	_print_summary(archetypes, agg)
	quit(0)


func _empty_agg(arche: Dictionary) -> Dictionary:
	return {
		"arche": arche,
		"runs": 0,
		"start_stone": 0,
		"earned": 0,
		"spent": 0,
		"end_stone": 0,
		"end_lifespan": 0,
		"end_soul": 0,
		"end_essence": 0,
		"materials": {},
		"gu_gained": 0,
		"combat_count": 0,
		"stone_samples": [],
	}


func _run_one(seed_value: int, arche: Dictionary, catalog: Dictionary,
		MapGeneratorScript, LootResolverScript, MarketRulesScript, GuBalanceScript,
		RunStateScript, agg: Dictionary) -> void:
	var state = RunStateScript.new_run(seed_value)
	var start_stone := int(state.stone)
	var earned := 0
	var spent := 0
	var combats := 0
	var gu_gained := 0

	var start_layer := int(arche.get("start_layer", 1))
	var combats_per_layer := int(arche["combats_per_layer"])
	var elite_ratio := float(arche["elite_ratio"])

	# 逐大层推进：战斗 → 掉落 → 里程碑 → 商店
	for layer in LAYERS:
		if layer < start_layer:
			# 未探索的层：只模拟"路过"（不产生收益），但保留初始资金
			continue
		state.current_node_layer = layer

		# --- 战斗掉落 --------------------------------------------------------
		var elite_count := int(round(float(combats_per_layer) * elite_ratio))
		for i in range(combats_per_layer):
			var is_elite := i < elite_count
			var tier := "elite" if is_elite else "common"
			var battle := {"enemy_kind": _enemy_for_tier(tier, catalog), "layer": layer}
			var result: Dictionary = LootResolverScript.settle_victory(battle, state, catalog)
			state = result["state"]
			var loot: Dictionary = result.get("loot", {})
			for material_value in loot.get("material_ids", []):
				var mid := str(material_value)
				state.materials[mid] = int(state.materials.get(mid, 0)) + 1
				agg["materials"][mid] = int(agg["materials"].get(mid, 0)) + 1
			if not str(loot.get("gu_id", "")).is_empty():
				gu_gained += 1
			combats += 1

		# --- 层里程碑（与真实路径一致：stage_one_ledger / boss_defeated） ----
		if layer == 1:
			state.cultivator["lifespan"] = int(state.cultivator.get("lifespan", 60)) + 10
			earned += 10  # 里程碑按寿元计，非元石；这里只统计寿元收入
		# Boss 战：boss 节点在 pre_boss 行，掉落 + 里程碑
		var boss_battle := {"enemy_kind": _enemy_for_tier("boss", catalog), "layer": layer}
		var boss_result: Dictionary = LootResolverScript.settle_victory(boss_battle, state, catalog)
		state = boss_result["state"]
		var boss_loot: Dictionary = boss_result.get("loot", {})
		for material_value in boss_loot.get("material_ids", []):
			var mid2 := str(material_value)
			state.materials[mid2] = int(state.materials.get(mid2, 0)) + 1
			agg["materials"][mid2] = int(agg["materials"].get(mid2, 0)) + 1
		state.cultivator["lifespan"] = int(state.cultivator.get("lifespan", 60)) + 10
		combats += 1

		# --- 硬编码小收入（work / harvest / deceive，每次遭遇一次） ----------
		var encounter_income := 3  # work
		if layer % 2 == 0:
			encounter_income += 2  # harvest
		earned += encounter_income
		state.stone = int(state.stone) + encounter_income

		# --- 变卖战利品（F1 §1：唯一实质购买力来源） ------------------------
		# 按 F2 判定：纯商品材料立即卖；生产资料（兽骨）保留
		for material_id in ["moon_blue_petal", "inheritance_token", "venom_sac"]:
			var held := int(state.materials.get(material_id, 0))
			if held <= 0:
				continue
			var unit := _material_value(catalog, material_id)
			var liquidity := _material_liquidity(catalog, material_id)
			var ratio: float = MarketRulesScript.low_liquidity_resale(1.0, catalog) if liquidity < 0.5 \
					else MarketRulesScript.public_resale(1.0, catalog)
			var gain := int(round(float(unit) * ratio)) * held
			if gain > 0:
				earned += gain
				state.stone = int(state.stone) + gain
				state.materials[material_id] = 0

		# --- 商店支出（按 spend_profile） ------------------------------------
		var visits := int(arche["shop_visits_per_layer"])
		if visits > 0:
			for v in range(visits):
				var sp := _try_purchase(state, catalog, MarketRulesScript, GuBalanceScript,
						str(arche["spend_profile"]), layer)
				spent += sp["spent"]
				if sp["bought_gu"]:
					gu_gained += 1

		agg["stone_samples"].append(int(state.stone))

	agg["runs"] += 1
	agg["start_stone"] += start_stone
	agg["earned"] += earned
	agg["spent"] += spent
	agg["end_stone"] += int(state.stone)
	agg["end_lifespan"] += int(state.cultivator.get("lifespan", 0))
	agg["end_soul"] += int(state.cultivator.get("soul", 0))
	agg["end_essence"] += int(state.essence)
	agg["gu_gained"] += gu_gained
	agg["combat_count"] += combats

	print("  seed=%-4d layer_start=%d start=%3d earned=%4d spent=%4d end=%4d life=%3d soul=%d mat=%s"
			% [seed_value, start_layer, start_stone, earned, spent, int(state.stone),
				int(state.cultivator.get("lifespan", 0)), int(state.cultivator.get("soul", 0)),
				_fmt_materials(state.materials)])


# 商店购买决策：按 spend_profile 决定"买什么价位的货"
func _try_purchase(state, catalog: Dictionary, MarketRulesScript, GuBalanceScript,
		profile: String, layer: int) -> Dictionary:
	var offers: Array = catalog.get("shop_offers", [])
	if offers.is_empty():
		return {"spent": 0, "bought_gu": false}
	var budget_mult := 0.0
	match profile:
		"none": return {"spent": 0, "bought_gu": false}
		"cheap": budget_mult = 0.5
		"mixed": budget_mult = 1.0
		"aggressive": budget_mult = 2.0
		_: return {"spent": 0, "bought_gu": false}
	var affordable := int(float(state.stone) * budget_mult)
	var best := {}
	var best_value := 0
	for offer_value in offers:
		var offer: Dictionary = offer_value
		if str(offer.get("kind", "")) != "purchase":
			continue
		var price := int(offer.get("stone_cost", 0))
		var layer_pct := _layer_price_pct(catalog, layer)
		price = price + int(price * layer_pct / 100.0)
		if price <= 0 or price > affordable:
			continue
		var gu_def: Dictionary = catalog.get("gu_by_id", {}).get(offer.get("gu_id", ""), {})
		var value: int = GuBalanceScript.gu_value(gu_def, int(gu_def.get("rank", 1)), catalog)
		# 效用代理：value/price 比（越高越值得买）
		var utility := float(value) / float(maxi(1, price))
		if utility > best_value:
			best_value = utility
			best = {"offer": offer, "price": price}
	if best.is_empty():
		return {"spent": 0, "bought_gu": false}
	state.stone = int(state.stone) - int(best["price"])
	return {"spent": int(best["price"]), "bought_gu": true}


func _layer_price_pct(catalog: Dictionary, layer: int) -> int:
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(layer), {})
	return int(layer_cfg.get("shop_price_pct", 0))


func _enemy_for_tier(tier: String, catalog: Dictionary) -> String:
	for enemy_value in catalog.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("tier", "")) == tier:
			return str(enemy.get("id", ""))
	return ""


func _material_value(catalog: Dictionary, material_id: String) -> int:
	var defs: Dictionary = catalog.get("materials_by_id", {})
	return int(defs.get(material_id, {}).get("value", 1))


func _material_liquidity(catalog: Dictionary, material_id: String) -> float:
	var defs: Dictionary = catalog.get("materials_by_id", {})
	return float(defs.get(material_id, {}).get("public_liquidity", 0.5))


func _fmt_materials(materials: Dictionary) -> String:
	var parts: Array[String] = []
	var keys: Array = materials.keys()
	keys.sort()
	for key in keys:
		var amount := int(materials[key])
		if amount > 0:
			parts.append("%s=%d" % [str(key), amount])
	if parts.is_empty():
		return "{}"
	return "{" + ", ".join(parts) + "}"


func _print_archetype(arche: Dictionary, a: Dictionary) -> void:
	var runs := maxi(1, int(a["runs"]))
	print("----------------------------------------------------------------------")
	print("  %s (%s)  runs=%d" % [arche["id"], arche["label"], a["runs"]])
	print("    start_stone avg = %.1f" % (float(a["start_stone"]) / float(runs)))
	print("    earned      avg = %.1f" % (float(a["earned"]) / float(runs)))
	print("    spent       avg = %.1f" % (float(a["spent"]) / float(runs)))
	print("    end_stone   avg = %.1f" % (float(a["end_stone"]) / float(runs)))
	print("    net (end-start) avg = %.1f" % (
			float(int(a["end_stone"]) - int(a["start_stone"])) / float(runs)))
	print("    end_lifespan avg = %.1f" % (float(a["end_lifespan"]) / float(runs)))
	print("    end_soul    avg = %.1f" % (float(a["end_soul"]) / float(runs)))
	print("    end_essence avg = %.1f" % (float(a["end_essence"]) / float(runs)))
	print("    gu_gained   avg = %.1f" % (float(a["gu_gained"]) / float(runs)))
	print("    combats     avg = %.1f" % (float(a["combat_count"]) / float(runs)))
	print("    materials total = %s" % str(a["materials"]))
	print("")


func _print_summary(archetypes: Array, agg: Dictionary) -> void:
	print("%-12s %8s %8s %8s %8s %10s %10s %8s" % [
		"archetype", "start", "earned", "spent", "end", "net", "lifespan", "gu"])
	for arche in archetypes:
		var a: Dictionary = agg[arche["id"]]
		var runs := maxi(1, int(a["runs"]))
		var net := float(int(a["end_stone"]) - int(a["start_stone"])) / float(runs)
		print("%-12s %8.1f %8.1f %8.1f %8.1f %10.1f %10.1f %8.1f" % [
			str(arche["id"]),
			float(a["start_stone"]) / float(runs),
			float(a["earned"]) / float(runs),
			float(a["spent"]) / float(runs),
			float(a["end_stone"]) / float(runs),
			net,
			float(a["end_lifespan"]) / float(runs),
			float(a["gu_gained"]) / float(runs),
		])


func _load_catalog() -> Dictionary:
	var ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
	var result: Dictionary = ContentCatalogScript.load_all()
	if result.has("catalog"):
		return result["catalog"]
	return result
