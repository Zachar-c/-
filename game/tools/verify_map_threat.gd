extends SceneTree

# D7：精英节点显性化验证门（2026-09-16）。
# 用法：godot --headless --path . -s tools/verify_map_threat.gd
# 退出码：0 = 全部通过；1 = 任一门禁失败。
#
# 背景：地图屏的精英角标分支早就写了，但判据是 `node.enemy_kind.contains("elite")`，
# 而（a）地图快照从不写 `enemy_kind`、（b）12 个精英里只有 `ridge_elite_scout` 的 id
# 含 "elite"。本门禁证明修复后的投影是**数据驱动**的，且与旧子串判据的差距可量化。
#
# 门禁：
#   D0 反空转 canary —— catalog / route / 精英节点计数均非零
#   D1 逐点一致 —— 独立重算（直接读 enemy_roll + enemy_by_id）与 node_threat 完全一致
#                  （刻意不复用被测函数，避免同源空转）
#   D2 分层覆盖 —— L3..L5（精英在数据上可达的层）每层至少出现一次；
#                  L1/L2 恒为 0 的原因在输出里显式 NOTE（数据事实，非投影缺陷）
#   D3 零漏判 —— 凡遭遇含 tier=="elite" 的节点，必须全部被标记
#   D4 不误标 —— 被标记的节点必须 type=="combat" 且 revealed（迷雾纪律）
#   D5 判据对照 —— 旧子串判据 vs tier 判据的命中数并排打印（修复收益的证据）
#   D6 只读性 —— node_threat 不改写入参，且对同一入参可重复得同一结果

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

const SEEDS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
]


func _initialize() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	if enemy_by_id.is_empty():
		print("D7 FAIL: catalog canary empty (enemy_by_id=0)")
		quit(1)
		return

	var failures: Array[String] = []
	var elite_by_layer := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var total_nodes := 0
	var marked_nodes := 0
	var mismatched := 0
	var mislabelled := 0
	var legacy_substring_hits := 0
	var elite_enemies := _elite_enemy_ids(enemy_by_id)
	if elite_enemies.is_empty():
		failures.append("no tier==elite enemy in enemies.json (canary)")

	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false, catalog)
		if route.is_empty():
			failures.append("seed %d produced an empty route (canary)" % seed_value)
			continue
		for node_value in route:
			var node: Dictionary = node_value
			total_nodes += 1
			var expected := _expected_elite(node, enemy_by_id)
			var actual := MapGeneratorScript.node_threat(node, catalog)
			if expected != (actual == "elite"):
				mismatched += 1
				if mismatched <= 5:
					print("  MISMATCH seed=%d node=%s expected=%s actual=%s"
							% [seed_value, str(node.get("id", "")), str(expected), actual])
			if expected:
				marked_nodes += 1
				elite_by_layer[int(node.get("layer", 0))] = int(elite_by_layer.get(int(node.get("layer", 0)), 0)) + 1
			if actual == "elite":
				if str(node.get("type", "")) != "combat" or not bool(node.get("revealed", true)):
					mislabelled += 1
			# 旧判据（id 子串）在同一节点上的命中数——只作对照，不参与断言。
			if str(node.get("enemy_kind", "")).contains("elite"):
				legacy_substring_hits += 1

	print("===== D7 map threat projection over %d seeds =====" % SEEDS.size())
	print("nodes scanned: %d" % total_nodes)
	print("elite nodes by tier: %d" % marked_nodes)
	for layer in [1, 2, 3, 4, 5]:
		print("  layer %d: %d" % [layer, int(elite_by_layer.get(layer, 0))])
	print("legacy id-substring hits: %d" % legacy_substring_hits)
	print("mismatched=%d  mislabelled=%d" % [mismatched, mislabelled])
	# L1/L2 结构性为 0（不是本投影的缺陷，是数据/节奏事实）：
	#   本层精英可达的必要条件是「某主题在本层 enemy_rank 区间内有 tier==elite 成员」。
	#   L1 rank_max=1、L2 rank_max=2；除 faction 外所有主题的精英最低 rank 为 3
	#   （beast 3 / cultivator 3 / anomaly 3），故 L1/L2 只有 faction 主题能抽到精英
	#   （ridge_elite_scout / faction_guard / school_elder，rank 2）。
	#   而两个 faction 战斗模板被 stage 门禁挡住：scout_crossing_raid=stage three、
	#   faction_guard_checkpoint=stage four ⇒ L2 的战斗池只剩 beast 主题 ⇒ 精英恒为 0。
	#   ⇒ 前两大层没有任何精英威胁方差。修它要动 pacing（红线，待裁定），本轮只记录。
	print("NOTE layer 1/2 stay at 0: only faction templates can roll an elite that early,")
	print("     and both are stage-gated (three / four). See the D7 report for the pacing ask.")

	if total_nodes <= 0:
		failures.append("scanned zero nodes (canary)")
	# D0：投影必须是活数据——40 种子一个精英都没有就说明该键是死的。
	if marked_nodes <= 0:
		failures.append("no elite node found across %d seeds (canary)" % SEEDS.size())
	# D1
	if mismatched != 0:
		failures.append("%d node(s) where node_threat disagrees with an independent recount" % mismatched)
	# D2：精英必须在**数据可达**的层上真的出现（L3/L4/L5）。L1/L2 见上面的 NOTE。
	for layer in [3, 4, 5]:
		if int(elite_by_layer.get(layer, 0)) <= 0:
			failures.append("layer %d never rolls an elite fight" % layer)
	# D4
	if mislabelled != 0:
		failures.append("%d marked node(s) are not revealed combat nodes" % mislabelled)
	# D5：修复收益必须是正的——tier 判据至少不弱于子串判据，且应当更强。
	if marked_nodes < legacy_substring_hits:
		failures.append("tier-driven marking (%d) is weaker than the legacy substring (%d)"
				% [marked_nodes, legacy_substring_hits])

	# D6：只读性——同一入参两次调用结果相同，且入参未被改写。
	var probe: Dictionary = MapGeneratorScript.build(SEEDS[0], false, catalog)[0]
	var before := probe.duplicate(true)
	var first := MapGeneratorScript.node_threat(probe, catalog)
	var second := MapGeneratorScript.node_threat(probe, catalog)
	if first != second:
		failures.append("node_threat is not idempotent")
	if probe != before:
		failures.append("node_threat mutated its input node")

	if failures.is_empty():
		print("D7 PASS: threat is data-driven, layer-covering, fog-safe and read-only")
		quit(0)
	else:
		print("D7 FAIL: %d issue(s)" % failures.size())
		for line in failures:
			print("  - " + line)
		quit(1)


## 独立实现（不复用 MapGenerator.node_threat）：本节点是否含 tier==elite 的敌人。
static func _expected_elite(node: Dictionary, enemy_by_id: Dictionary) -> bool:
	if str(node.get("type", "")) != "combat":
		return false
	if not bool(node.get("revealed", true)):
		return false
	var kinds: Array = []
	if node.has("enemy_roll"):
		kinds = node.get("enemy_roll", [])
	elif node.has("enemy_kinds"):
		kinds = node.get("enemy_kinds", [])
	elif node.has("enemy_kind"):
		kinds = [node.get("enemy_kind", "")]
	for kind_value in kinds:
		if str((enemy_by_id.get(str(kind_value), {}) as Dictionary).get("tier", "")) == "elite":
			return true
	return false


static func _elite_enemy_ids(enemy_by_id: Dictionary) -> Dictionary:
	var ids := {}
	for enemy_id in enemy_by_id.keys():
		if str((enemy_by_id[enemy_id] as Dictionary).get("tier", "")) == "elite":
			ids[str(enemy_id)] = true
	return ids
