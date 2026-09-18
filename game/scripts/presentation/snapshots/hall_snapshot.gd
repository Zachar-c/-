class_name HallSnapshot
extends RefCounted


# W12 split: the Title/Hall screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; shared text helpers live in
# SnapshotTextUtil.


const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")
const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")


static func build(controller) -> Dictionary:
	var state = controller.get("state")
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var meta = controller.meta
	var schools: Dictionary = catalog.get("schools", {})
	var school_list: Array[Dictionary] = []
	for school_id in schools:
		var sdata: Dictionary = schools[school_id]
		var starters: Array = sdata.get("starter_gu_ids", [])
		var starter_names: Array[String] = []
		for sid in starters:
			starter_names.append(DisplayText.gu(str(sid)))
		school_list.append({
			"id": str(school_id),
			"name": str(sdata.get("name", str(school_id))),
			"summary": str(sdata.get("summary", "")),
			"starter_gu_ids": starters,
			"starter_gu_names": starter_names,
		})
	# S2 开局 Buff：目录 buffs 投影为大厅多选列表（只读，toggle 走命令面）。
	var buff_list: Array[Dictionary] = []
	for buff_id in catalog.get("buffs", {}):
		var bdata: Dictionary = catalog["buffs"][buff_id]
		buff_list.append({
			"id": str(buff_id),
			"name": str(bdata.get("name", str(buff_id))),
			"summary": str(bdata.get("summary", "")),
		})
	var runs := 0
	var endings := 0
	var won := 0
	var deaths := 0
	if meta != null:
		runs = int(meta.statistics.get("runs_started", 0))
		endings = meta.gu_codex_ids.size() + meta.recipe_codex_ids.size() + meta.inheritance_codex_ids.size()
		won = int(meta.statistics.get("runs_won", 0))
		deaths = int(meta.statistics.get("deaths", 0))
	var out := {
		"has_save": FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
		"hall_subview": str(controller._hall_subview),
		"selected_school": str(controller._selected_school),
		"available_schools": school_list,
		"available_buffs": buff_list,
		"selected_buffs": Array(controller._selected_buffs),
		"contracts": _available_contracts(meta, catalog, _contract_selection_state(controller)),
		"selected_school_name": SnapshotTextUtil._school_display_name(catalog, str(controller._selected_school)),
		"meta_stats": {"runs": runs, "endings": endings, "won": won, "deaths": deaths},
		# D4 预留（§16.22）：SaveRepository.load_meta_file 在版本不符时返回 null，与无档/损坏
		# 不可区分；待领域侧暴露版本冲突标记后在此注入提示文案，hall_view 已预留 warn Toast 槽位。
		"hall_version_warning": "",
		"codex": _codex(catalog, meta),
		"journal": _journal(meta, catalog),
		"dda_state_adaptive_enabled": bool(meta.dda_state_adaptive_enabled) if meta != null else true,
		# A6 设置接线：客户端偏好只投影数值与选项标签，绝不写回（只读快照）。
		"master_volume": AppSettingsScript.clamp_volume(int(controller.app_settings.master_volume)) if controller.get("app_settings") != null else 100,
		"resolution_index": int(controller.app_settings.resolution_index) if controller.get("app_settings") != null else 0,
		"resolution_options": AppSettingsScript.resolution_labels(),
	}
	out["brand_title"] = "問眞"
	out["primary_action"] = "continue_run" if out["has_save"] else "open_schools"
	var run_route := _run_route_label(controller)
	out["run_summary"] = {
		"route": run_route,
		"rank": _rank_cn(int(state.cultivation)) if state != null else "0转",
		"hp": "%d" % int(state.health) if state != null else "0",
		# v8 线框稿还原（2026-09-07）：寿元 = cultivator.lifespan - lifespan_debt；
		# 蛊囊只显示持有数，不伪造分母（项目红线：持有数量无通用硬上限）。
		"lifespan": "%d年" % _lifespan_remaining(state) if state != null else "0年",
		"gu_count": state.gu_ids.size() if state != null else 0,
		"node_count": state.route_progress.size() if state != null else 0,
		"curse_count": _curse_count(state) if state != null else 0,
		"build_label": "BUILD 0.9.0 · LOCAL",
	}
	out["hall_epoch"] = "今世·第%s劫" % _cn_number(
			int(state.route_progress.size()) + 1) if state != null else "今世·第一劫"
	out["prev_life"] = ("上一世止于：%s" % run_route) if out["has_save"] else "上一世止于：—"
	out["prev_note"] = "札记新得：%s" % _latest_journal_title(meta, catalog)


	return out


static func _run_route_label(controller) -> String:
	var state = controller.state
	if state == null:
		return "未载入"
	var node_id := str(state.current_node_id)
	if node_id.is_empty():
		return "流派选择"
	var node: Dictionary = controller._node_by_id(node_id) if controller.has_method("_node_by_id") else {}
	var template_id := str(state.current_node_template_id)
	if template_id.is_empty() and not node.is_empty():
		template_id = str(node.get("template_id", ""))
	if template_id.is_empty():
		template_id = node_id
	var catalog_node: Dictionary = controller.catalog.get("node_by_id", {}).get(template_id, {}) if controller.catalog != null else {}
	if not catalog_node.is_empty():
		var display_name := DisplayText.node(template_id)
		if display_name == "未知地点":
			display_name = DisplayText.type(str(catalog_node.get("type", "")))
		return display_name
	if not node.is_empty():
		return str(node.get("label", DisplayText.node(template_id)))
	return DisplayText.node(template_id)


## v8 线框稿（2026-09-07）：大厅数值区辅助函数。
static func _rank_cn(n: int) -> String:
	const CN_RANK := ["一", "二", "三", "四", "五"]
	if n <= 0:
		return "0转"
	return CN_RANK[clampi(n - 1, 0, CN_RANK.size() - 1)] + "转"


static func _lifespan_remaining(state) -> int:
	return int(state.cultivator.get("lifespan", 0)) - int(state.lifespan_debt)


## 诅咒状态数：cultivator.statuses 中 layers>0 的条目数（参考图「N只诅咒蛊」近似口径）。
static func _curse_count(state) -> int:
	var statuses: Dictionary = state.cultivator.get("statuses", {})
	var n := 0
	for curse_id in statuses:
		var entry: Variant = statuses[curse_id]
		if entry is Dictionary and int(entry.get("layers", 0)) > 0:
			n += 1
	return n


## 100 以内中文数字（「今世·第六十三劫」等）。
static func _cn_number(n: int) -> String:
	const UNITS := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n <= 0:
		return "零"
	if n < 10:
		return UNITS[n]
	if n < 20:
		return "十" + UNITS[n % 10]
	if n < 100:
		return UNITS[n / 10] + "十" + UNITS[n % 10]
	return str(n)


## 最新一条已解锁手记标题（无则「—」）。
static func _latest_journal_title(meta, catalog: Dictionary) -> String:
	if meta == null:
		return "—"
	var by_id: Dictionary = catalog.get("journal_entry_by_id", {})
	var last_id := ""
	for jid in meta.journal_unlocked:
		last_id = str(jid)
	if last_id.is_empty():
		return "—"
	var entry: Dictionary = by_id.get(last_id, {})
	return str(entry.get("title", "—"))


## 勾选草稿 ∪ 已立誓（去重）：契约 selected 态的单一真值来源。
## StubController（测试）可能缺字段，逐项防御读取；注意 RunState 覆写了 get()，
## 不能对 state 调 .get("contracts")，须直接属性访问。
static func _contract_selection_state(controller) -> Array:
	var merged: Array = []
	var draft: Variant = controller.get("_selected_contracts")
	if draft != null:
		for v in draft:
			if not merged.has(str(v)):
				merged.append(str(v))
	var run_state: Variant = controller.get("state")
	if run_state != null and "contracts" in run_state:
		for v in run_state.contracts:
			if not merged.has(str(v)):
				merged.append(str(v))
	return merged


# C1-min §16.13: the hall lists every contract with its exact numbers;
# ending-locked entries are marked so the UI can gate its checkboxes.
# Structured rows (id/name/desc/locked/selected) drive hall_view checkboxes;
# `selected` mirrors the controller's pre-run checkbox state.
static func _available_contracts(meta, catalog: Dictionary, selected: Array = []) -> Array:
	## selected 语义 = 大厅勾选草稿 ∪ 本局已立誓（state.contracts），由调用方合并传入；
	## Run 结束后草稿清空，仅剩已立誓 id 供结算/复盘对照。
	var unlocked: Array[String] = []
	if meta != null and meta.has_method("unlocked_contracts"):
		unlocked = meta.unlocked_contracts(catalog)
	var by_id: Dictionary = catalog.get("contract_entry_by_id", {})
	var out: Array = []
	for entry_id in by_id:
		var entry: Dictionary = by_id[entry_id]
		out.append({
			"id": str(entry_id),
			"name": str(entry.get("label", str(entry_id))),
			"desc": str(entry.get("desc", "")),
			"locked": not unlocked.has(str(entry_id)),
			"selected": selected.has(str(entry_id)),
		})
	return out


## A5 图鉴数据（只读）：蛊 / 敌人 / 配方 / 传承 / 遗物 五类，每类带 unlocked 标记。
## 遭遇即解锁（meta.codex ids）；未解锁只显剪影（§16.20）。
static func _codex(catalog: Dictionary, meta) -> Dictionary:
	var unlocked_gu: Array = meta.gu_codex_ids if meta != null else []
	var unlocked_recipes: Array = meta.recipe_codex_ids if meta != null else []
	var unlocked_relics: Array = meta.relic_codex_ids if meta != null else []
	var unlocked_inheritance: Array = meta.inheritance_codex_ids if meta != null else []

	var gu_entries: Array[Dictionary] = []
	for g in catalog.get("gu", []):
		var gid := str(g.get("id", ""))
		# 2026-09-04：图鉴透出转数与效果文本（未声明 v1_effect 时走
		# V1 role 兜底，与战斗口径一致），不再只给流派/品阶剪影。
		var codex_effect: Dictionary = g.get("v1_effect", {})
		if codex_effect.is_empty():
			codex_effect = V1BattleResolverScript.default_v1_effect(g,
					V1BattleResolverScript.role_default_table(catalog))
		gu_entries.append({
			"id": gid,
			"name": DisplayText.gu(gid),
			"rank": int(g.get("rank", 1)),
			"effect": SnapshotTextUtil._v1_effect_text({"effect": codex_effect}),
			"school": str(g.get("school", "")),
			# C2 2026-09-05：图鉴透出中文流派名（schools.json v2），UI 不再裸显英文 id。
			"school_name": SnapshotTextUtil._school_display_name(catalog, str(g.get("school", ""))),
			"rarity": str(g.get("rarity", "common")),
			"unlocked": unlocked_gu.has(gid),
		})

	var enemy_entries: Array[Dictionary] = []
	for e in catalog.get("enemies", []):
		var eid := str(e.get("id", ""))
		enemy_entries.append({
			"id": eid,
			"name": eid,
			"tier": str(e.get("tier", "")),
			"unlocked": unlocked_gu.has(eid),
		})

	var recipe_entries: Array[Dictionary] = []
	var recipe_rows: Array = catalog.get("refinement_recipes", [])
	if recipe_rows.is_empty():
		recipe_rows = catalog.get("refinement", {}).get("recipes", [])
	for r_value in recipe_rows:
		var r: Dictionary = r_value
		var rid := str(r.get("id", ""))
		recipe_entries.append({
			"id": rid,
			"kind": str(r.get("kind", "")),
			"output_gu": DisplayText.gu(str(r.get("output_gu_id", ""))),
			# 默认配方（default_unlocked）初始即持有，随 Hall 首屏可见。
			"unlocked": unlocked_recipes.has(rid) or bool(r.get("default_unlocked", false)),
		})

	var relic_entries: Array[Dictionary] = []
	for r in catalog.get("relics", []):
		var rid := str(r.get("id", ""))
		relic_entries.append({"id": rid, "name": rid, "unlocked": unlocked_relics.has(rid)})

	var inheritance_entries: Array[Dictionary] = []
	for ih in catalog.get("inheritances", []):
		var iid := str(ih.get("id", ""))
		inheritance_entries.append({"id": iid, "name": iid, "unlocked": unlocked_inheritance.has(iid)})

	return {
		"gu": gu_entries,
		"enemies": enemy_entries,
		"recipes": recipe_entries,
		"relics": relic_entries,
		"inheritances": inheritance_entries,
	}


## A7 手记库（§16.9 叙事沉淀）：只渲染已解锁条目；ending 页结局短句优先取
## journal.json ending_texts（缺 key 回退硬编码）；解锁判定在 MetaProgress。
## 外层 dict 兼容新旧两代消费端：entries 内每条同时携带新端键
## id/title/text 与旧端键 title/body（body 为 text 的同值别名）。
static func _journal(meta, catalog: Dictionary) -> Dictionary:
	var by_id: Dictionary = catalog.get("journal_entry_by_id", {})
	var entries: Array[Dictionary] = []
	if meta != null:
		for jid in meta.journal_unlocked:
			var entry: Dictionary = by_id.get(str(jid), {})
			if not entry.is_empty():
				var text := str(entry.get("text", ""))
				entries.append({
					"id": str(jid),
					"title": str(entry.get("title", "")),
					"text": text,
					"body": text,
				})
	var total := (catalog.get("journal", {}).get("entries", []) as Array).size()
	return {
		"entries": entries,
		"count": entries.size(),
		"journal_locked_count": maxi(0, total - entries.size()),
	}
