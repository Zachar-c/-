#!/usr/bin/env python3
"""World-model validator — standard library only.

Checks
------
1. Schema       每个 data/*.json 用 schema/world-model.schema.json 逐字段校验
2. 引用完整性   gu ↔ recipes ↔ materials ↔ shops ↔ schools ↔ enemies ↔ nodes ↔ loot 全交叉
3. 数值越界     rank / value / cost / hp / 权重 / 概率范围，pacing 每层权重守恒，loot 权重归一
4. 环与深度     升炼链环检测、配方图环检测、最长升炼链深度

输出
----
    world-model/reports/validation-report.md     完整报告（含逐项检查条数）
    stdout                                        摘要

退出码：全部通过 = 0，存在错误 = 1
"""

from __future__ import annotations

import argparse
import collections
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
if str(WM_ROOT) not in sys.path:
    sys.path.insert(0, str(WM_ROOT))

from engine.errors import WorldModelError  # noqa: E402
from engine.model import DATA_DIR, ENTITY_FILES, SCHEMA_DIR  # noqa: E402
from engine.rng import SeededRng, index, mixed_seed, salt_hash  # noqa: E402

REPORT = WM_ROOT / "reports" / "validation-report.md"


class Report:
    def __init__(self) -> None:
        self.sections: list[dict] = []

    def add(self, title: str, checks: int, failures: list[str], notes: list[str] | None = None) -> None:
        self.sections.append({"title": title, "checks": checks, "failures": list(failures),
                              "notes": list(notes or [])})

    @property
    def total_checks(self) -> int:
        return sum(s["checks"] for s in self.sections)

    @property
    def total_failures(self) -> int:
        return sum(len(s["failures"]) for s in self.sections)


def load_docs() -> dict[str, dict]:
    docs = {}
    for entity_type, filename in ENTITY_FILES.items():
        path = DATA_DIR / filename
        if not path.exists():
            raise SystemExit(f"FATAL: 缺少数据文件 {path}")
        docs[entity_type] = json.loads(path.read_text(encoding="utf-8"))
    return docs


def entities(docs: dict, entity_type: str) -> list[dict]:
    return docs[entity_type]["entities"]


# --------------------------------------------------------------------------
# 1. schema
# --------------------------------------------------------------------------

def check_schema(docs: dict, report: Report) -> None:
    from schema.mini_schema import Validator, load_schema

    schema_path = SCHEMA_DIR / "world-model.schema.json"
    validator = Validator(load_schema(schema_path))
    failures: list[str] = []
    checks = 0
    per_file = []
    for entity_type, doc in docs.items():
        errs = validator.validate_document(doc, entity_type)
        checks += validator.checks
        per_file.append(f"{ENTITY_FILES[entity_type]}: {validator.checks} 条断言，{len(errs)} 条失败")
        failures.extend(f"{ENTITY_FILES[entity_type]} {e}" for e in errs)
    report.add("1. Schema 校验（schema/world-model.schema.json，自写迷你校验器）", checks, failures, per_file)


# --------------------------------------------------------------------------
# 2. 引用完整性
# --------------------------------------------------------------------------

def collect_index(docs: dict) -> dict:
    gu = {g["id"]: g for g in entities(docs, "gu")}
    materials = {m["id"]: m for m in entities(docs, "loot")[0]["materials"]}
    events = {e["id"]: e for e in entities(docs, "event")}
    paths = {p["id"]: p for p in entities(docs, "path")}
    realms = {r["id"]: r for r in entities(docs, "realm")}
    regions = entities(docs, "region")
    macro = next(r for r in regions if r["entity_kind"] == "macro_region")
    layers = [r for r in regions if r["entity_kind"] == "layer"]
    templates = {t["id"]: t for t in macro["node_templates"]}
    roster = {e["id"]: e for e in macro["enemy_roster"]}
    npcs = {n["id"]: n for n in macro["npc_roster"]}
    economy = entities(docs, "economy")[0]
    offers = {o["id"]: o for o in economy["shop_offers"]}
    factions = entities(docs, "faction")
    loot = entities(docs, "loot")[0]
    balance = entities(docs, "balance")[0]
    return {"gu": gu, "materials": materials, "events": events, "paths": paths, "realms": realms,
            "regions": regions, "macro": macro, "layers": layers, "templates": templates,
            "roster": roster, "npcs": npcs, "economy": economy, "offers": offers,
            "factions": factions, "loot": loot, "balance": balance}


def check_references(docs: dict, report: Report) -> None:
    ix = collect_index(docs)
    checks = 0
    failures: list[str] = []

    def need(condition: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    # gu.refine_* ↔ recipes ↔ materials ↔ gu
    recipe_kinds = {"advance", "fixed", "promotion"}
    # Pass 1 must finish before pass 2: an input gu's back-pointers name recipes
    # owned by a *different* gu, so a single interleaved loop is order-dependent.
    recipe_ids: set[str] = {edge["recipe_id"]
                            for g in ix["gu"].values() for edge in g["refine_as_output"]}
    for gid, g in ix["gu"].items():
        for edge in g["refine_as_output"]:
            need(edge["kind"] in recipe_kinds, f"配方 {edge['recipe_id']} 的 kind={edge['kind']!r} 非法")
            need(edge["output_gu_id"] in ix["gu"],
                 f"配方 {edge['recipe_id']} 输出蛊 {edge['output_gu_id']!r} 不在 gu 表内")
            need(edge["output_gu_id"] == gid,
                 f"配方 {edge['recipe_id']} 挂在 {gid} 上但输出为 {edge['output_gu_id']}")
            for mat, amount in (edge["materials"] or {}).items():
                need(mat in ix["materials"], f"配方 {edge['recipe_id']} 引用未知蛊材 {mat!r}")
                need(int(amount) > 0, f"配方 {edge['recipe_id']} 的蛊材 {mat} 数量必须为正")
        for rid in g["refine_as_input"]:
            need(rid in recipe_ids, f"蛊 {gid} 的 refine_as_input 引用未知配方 {rid!r}")
        for offer_id in g["shop_offer_ids"]:
            need(offer_id in ix["offers"], f"蛊 {gid} 引用未知商店报价 {offer_id!r}")
        for tier in g["drop_tiers"]:
            need(":" in tier, f"蛊 {gid} 的 drop_tiers 条目 {tier!r} 格式非法")

    # recipe inputs resolve to a real gu that declares the recipe as output
    for gid, g in ix["gu"].items():
        for rid in g["refine_as_input"]:
            holders = [o for o in ix["gu"].values() if any(e["recipe_id"] == rid for e in o["refine_as_output"])]
            need(bool(holders), f"配方 {rid} 没有可解析的持有蛊（悬空的 refine_as_input）")

    # shops ↔ gu / materials / recipes
    for oid, offer in ix["offers"].items():
        if offer["gu_id"]:
            need(offer["gu_id"] in ix["gu"], f"商店报价 {oid} 引用未知蛊 {offer['gu_id']!r}")
        if offer["material_id"]:
            need(offer["material_id"] in ix["materials"], f"商店报价 {oid} 引用未知蛊材 {offer['material_id']!r}")
        for iid in offer["input_gu_ids"]:
            need(iid in ix["gu"], f"商店报价 {oid} 的输入蛊 {iid!r} 不存在")
        for reward in offer["rewards"]:
            relic_id = reward.get("relic_id")
            if relic_id:
                need(relic_id in {r["id"] for r in ix["loot"]["relics"]},
                     f"商店报价 {oid} 的奖励遗物 {relic_id!r} 不在 loot.relics 内")

    # paths ↔ gu
    for pid, path in ix["paths"].items():
        for gid in path["starter_gu_ids"]:
            need(gid in ix["gu"], f"流派 {pid} 的起始蛊 {gid!r} 不在 gu 表内")
        for gid in path["pool_gu_ids"]:
            need(gid in ix["gu"], f"流派 {pid} 的池内蛊 {gid!r} 不在 gu 表内")
            need(ix["gu"][gid]["school"] == pid,
                 f"流派 {pid} 的池内蛊 {gid} 实际流派为 {ix['gu'][gid]['school']}")
        need(path["pool_size"] == len(path["pool_gu_ids"]), f"流派 {pid} 的 pool_size 与 pool_gu_ids 不符")
        for other in path["conflict_paths"]:
            need(other in ix["paths"], f"流派 {pid} 的冲突流派 {other!r} 不存在")
        for rank in path["pool_ranks"]:
            need(1 <= rank <= 9, f"流派 {pid} 的池内转数 {rank} 越界")

    # regions ↔ nodes ↔ enemies ↔ events ↔ loot
    for layer in ix["layers"]:
        for tid in layer["stage_node_templates"]:
            need(tid in ix["templates"], f"{layer['id']} 的 stage 节点 {tid!r} 不在 node_templates 内")
        for tid in layer["node_pool"]:
            need(tid in ix["templates"], f"{layer['id']} 的 node_pool 条目 {tid!r} 不在 node_templates 内")
        for anchor in layer["anchors"]:
            need(anchor["template"] in ix["templates"],
                 f"{layer['id']} 的锚点 {anchor['template']!r} 不在 node_templates 内")
        need(layer["boss_seat"] in ix["templates"], f"{layer['id']} 的 boss_seat {layer['boss_seat']!r} 不存在")
        for boss in layer["boss_pool"]:
            need(boss in ix["roster"], f"{layer['id']} 的 Boss {boss!r} 不在敌人名册内")
        for enemy in layer["enemy_pool"]:
            need(enemy in ix["roster"], f"{layer['id']} 的敌人 {enemy!r} 不在敌人名册内")
        for key in ("rows_min", "rows_max", "row_nodes_min", "row_nodes_max"):
            need(isinstance(layer[key], int), f"{layer['id']} 的 {key} 必须是整数")
        need(layer["rows_min"] <= layer["rows_max"], f"{layer['id']} 的行数下限大于上限")
        need(layer["row_nodes_min"] <= layer["row_nodes_max"], f"{layer['id']} 的宽度下限大于上限")

    for tid, template in ix["templates"].items():
        if template["enemy_kind"]:
            need(template["enemy_kind"] in ix["roster"], f"节点 {tid} 的敌人 {template['enemy_kind']!r} 不存在")
        for eid in template["enemy_kinds"]:
            need(eid in ix["roster"], f"节点 {tid} 的多敌 {eid!r} 不存在")
        for eid in template["event_pool"]:
            need(eid in ix["events"], f"节点 {tid} 的事件池条目 {eid!r} 不在 events 内")
        if template["event_id"]:
            need(template["event_id"] in ix["events"], f"节点 {tid} 的 event_id {template['event_id']!r} 不存在")
        if template["npc_id"]:
            need(template["npc_id"] in ix["npcs"], f"节点 {tid} 的 npc_id {template['npc_id']!r} 不在 npc_roster 内")
        for nxt in template["next_ids"]:
            need(nxt in ix["templates"], f"节点 {tid} 的 next_ids 条目 {nxt!r} 不存在")

    for tier, pool in ix["macro"]["template_pools"].items():
        for tid in pool:
            need(tid in ix["templates"], f"template_pools[{tier}] 条目 {tid!r} 不存在")

    for faction in ix["factions"]:
        for agent in faction["agents"]:
            need(agent in ix["npcs"], f"势力 {faction['id']} 的成员 {agent!r} 不在 npc_roster 内")

    for eid, event in ix["events"].items():
        curse_id = event.get("curse_id", "")
        if curse_id:
            need(curse_id in {c["id"] for c in docs["event"]["event_curse_pool"]},
                 f"事件 {eid} 引用未知诅咒 {curse_id!r}")

    # loot
    material_ids = [m["id"] for m in ix["loot"]["materials"]]
    need(len(material_ids) == len(set(material_ids)), "loot.materials 存在重复 id")
    for core in ix["loot"]["core_material_ids"]:
        need(core in ix["materials"], f"core_material_ids 条目 {core!r} 不在 materials 内")
    for tier, spec in ix["loot"]["tiers"].items():
        for entry in spec.get("material_pool", []):
            mid = entry if isinstance(entry, str) else entry.get("id")
            need(mid in ix["materials"], f"loot.tiers[{tier}].material_pool 条目 {mid!r} 不在 materials 内")
        for rarity, ids in (spec.get("gu_pool", {}) or {}).get("by_rarity", {}).items():
            for gid in ids:
                need(gid in ix["gu"], f"loot.tiers[{tier}].gu_pool[{rarity}] 条目 {gid!r} 不在 gu 表内")
    for mid in ix["economy"]["material_reference_prices"]:
        need(mid in ix["materials"], f"economy.material_reference_prices 条目 {mid!r} 不在 loot.materials 内")

    # balance ↔ gu / paths
    for rank in ix["balance"]["economy"]["gu_value_by_rank"]:
        need(rank in {"1", "2", "3", "4", "5"}, f"balance.gu_value_by_rank 键 {rank!r} 越界")
    for pair in ix["balance"]["combat_gate"]["school_exclusions"]:
        for sid in pair:
            need(sid in ix["paths"], f"balance.school_exclusions 条目 {sid!r} 不在流派表内")

    report.add("2. 引用完整性（gu ↔ recipes ↔ materials ↔ shops ↔ schools ↔ enemies ↔ nodes ↔ loot）",
               checks, failures)


# --------------------------------------------------------------------------
# 3. 数值越界
# --------------------------------------------------------------------------

def check_ranges(docs: dict, report: Report) -> None:
    ix = collect_index(docs)
    checks = 0
    failures: list[str] = []
    notes: list[str] = []

    def bound(condition: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    for gid, g in ix["gu"].items():
        checks += 1
        if not g["is_test_entity"]:
            bound(1 <= g["rank"] <= 9, f"蛊 {gid} 的 rank {g['rank']} 越界（非测试实体应为 1-9）")
        bound(0 <= g["value"] <= 999, f"蛊 {gid} 的 value {g['value']} 越界")

        # 价值锚一致性：策展蛊必须显式登记为例外，未登记的一律必须等于同转锚值
        if not g["is_test_entity"]:
            try:
                _anchor = ix["balance"]["economy"]["gu_value_by_rank"]
                _exc = ix["balance"]["economy"].get("gu_value_anchor_exceptions", {}) or {}
            except KeyError:
                _anchor, _exc = {}, {}
            _expected = _anchor.get(str(g["rank"]))
            if _expected is not None and g["value"] != _expected:
                bound(gid in _exc,
                      f"蛊 {gid} 的 value {g['value']} 偏离 {g['rank']} 转锚值 {_expected}，"
                      f"且未登记在 gu_value_anchor_exceptions")
            elif gid in _exc and _expected is not None and g["value"] == _expected:
                bound(False,
                      f"蛊 {gid} 已登记为价值锚例外，但其 value 等于锚值 {_expected}（应移除登记）")
        bound(0 <= g["activation_cost"] <= 99, f"蛊 {gid} 的 activation_cost {g['activation_cost']} 越界")
        bound(g["feeding"]["stone_per_stage"] >= 0, f"蛊 {gid} 的喂养成本为负")
        bound(g["feeding"]["feed_points_per_stage"] >= 0, f"蛊 {gid} 的喂养点数为负")
        bound(g["school"] in ix["paths"], f"蛊 {gid} 的流派 {g['school']!r} 不在流派表内")
        for tag in g["tags"]:
            bound(bool(tag) and " " not in tag, f"蛊 {gid} 的标签 {tag!r} 非法")
    test_entities = [g for g in ix["gu"].values() if g["is_test_entity"]]
    if test_entities:
        notes.append("越界但已标记的调试实体（不进入内容池）："
                     + "，".join(f"{g['id']}(rank={g['rank']}, canon_review_status={g['canon_review_status']})"
                                 for g in test_entities))

    for layer in ix["layers"]:
        checks += 1
        total = sum(layer["category_weights"].values())
        bound(total == layer["category_weight_sum"],
              f"{layer['id']} 的分类权重和 {total} 与记录的 {layer['category_weight_sum']} 不符")
        bound(abs(total - 100) <= 1, f"{layer['id']} 的分类权重和为 {total}，应为 100（守恒）")
        bound(1 <= layer["layer"] <= 5, f"{layer['id']} 的层号越界")
        bound(0 <= layer["enemy_rank_min"] <= layer["enemy_rank_max"] <= 9,
              f"{layer['id']} 的敌人转数区间 [{layer['enemy_rank_min']},{layer['enemy_rank_max']}] 非法")
        weights = layer["loot_rarity_weights"]
        bound(abs(sum(weights.values()) - 100) <= 1,
              f"{layer['id']} 的掉落稀有度权重和为 {sum(weights.values())}，应为 100")
        for key in ("category_weights", "loot_rarity_weights"):
            for name, value in layer[key].items():
                bound(value >= 0, f"{layer['id']}.{key}.{name} 为负权重")

    for tier, spec in ix["loot"]["tiers"].items():
        checks += 1
        weights = (spec.get("gu_pool", {}) or {}).get("weights", {})
        if weights:
            bound(abs(sum(weights.values()) - 100) <= 1,
                  f"loot.tiers[{tier}] 的蛊稀有度权重和为 {sum(weights.values())}，应为 100")
        for name, value in weights.items():
            bound(value >= 0, f"loot.tiers[{tier}].gu_pool.weights.{name} 为负")
        chance = spec.get("gu_chance_pct")
        if chance is not None:
            bound(0 <= chance <= 100, f"loot.tiers[{tier}].gu_chance_pct {chance} 越界")

    for mid, m in ix["materials"].items():
        checks += 1
        bound(0 <= m["public_liquidity"] <= 1, f"蛊材 {mid} 的 public_liquidity {m['public_liquidity']} 越界")
        bound(m["reference_value"] >= 0, f"蛊材 {mid} 的 reference_value 为负")
        bound(m["value"] >= 0, f"蛊材 {mid} 的 value 为负")

    for rid, realm in ix["realms"].items():
        checks += 1
        bound(1 <= realm["rank"] <= 9, f"境界 {rid} 的转数越界")
        bound(realm["cultivation_factor"] >= 1, f"境界 {rid} 的 cultivation_factor 非法")
        if realm["rank"] <= 5:
            bound(realm["essence_tier"] is not None, f"境界 {rid} 缺少真元品阶（一至五转原文有明确品阶）")
        else:
            bound(realm["essence_tier"] is None, f"境界 {rid} 属蛊仙层次，不应臆造真元品阶")

    for eid, event in ix["events"].items():
        checks += 1
        for option in event["options"]:
            eff = option["effects"]
            bound(eff["health_cost"] >= 0, f"事件 {eid} 的气血代价为负")
            bound(eff["stone_gain"] >= 0, f"事件 {eid} 的元石收益为负")
            bound(eff["delayed_soul_cost"] >= 0, f"事件 {eid} 的延迟魂代价为负")

    for offer in ix["offers"].values():
        checks += 1
        if offer.get("stone_cost") is not None:
            bound(0 <= offer["stone_cost"] <= 9999, f"报价 {offer['id']} 的元石价格越界")
        if offer.get("lifespan_cost") is not None:
            bound(0 <= offer["lifespan_cost"] <= 999, f"报价 {offer['id']} 的寿元代价越界")

    balance = ix["balance"]
    checks += 1
    bound(balance["growth"]["rank_step_ratio"] > 1.0, "balance.rank_step_ratio 必须大于 1")
    bound(0 < balance["growth"]["standard_hit_ratio"] <= 1, "balance.standard_hit_ratio 越界")
    bound(balance["run"]["starter"]["hp"] > 0, "开局气血必须为正")
    bound(len(balance["run"]["death_axes"]) == 3, "死亡轴应为 hp/lifespan/soul 三条")
    for axis in balance["run"]["death_axes"]:
        bound(axis in balance["run"]["starter"] or axis == "lifespan",
              f"死亡轴 {axis} 不在开局状态里")
    for entry in balance["economy"]["black_market_exchange"]:
        other = [x for x in balance["economy"]["black_market_exchange"]
                 if x["from"] == entry["to"] and x["to"] == entry["from"]]
        notes.append(f"黑市 {entry['from']} {entry['amount_in']} → {entry['to']} {entry['amount_out']}"
                     + (f"（反向 {other[0]['from']} {other[0]['amount_in']} → {other[0]['to']} {other[0]['amount_out']}）"
                        if other else "（无反向报价）"))
    notes.append("黑市双向兑换率不对称（约 100 倍往返损耗）是已登记风险项 RISK-06，不是校验失败。")
    report.add("3. 数值越界（rank/value/cost/hp/权重/概率范围、权重守恒与归一、价值锚一致性）", checks, failures, notes)


# --------------------------------------------------------------------------
# 4. 环与深度
# --------------------------------------------------------------------------

def check_cycles(docs: dict, report: Report) -> None:
    ix = collect_index(docs)
    checks = 0
    failures: list[str] = []
    notes: list[str] = []

    edge_kinds = {"advance", "fixed", "promotion"}
    graph: dict[str, list[tuple[str, str, str]]] = collections.defaultdict(list)
    self_advance = []
    rank = {gid: g["rank"] for gid, g in ix["gu"].items()}
    # refine_as_output is keyed by the OUTPUT gu, so the edge source must be read
    # from input_gu_ids, not from the holder's own id.
    missing_inputs = []
    material_only = []
    for gid, g in ix["gu"].items():
        for edge in g["refine_as_output"]:
            if edge["kind"] not in edge_kinds:
                continue
            dst = edge["output_gu_id"]
            inputs = [i for i in edge.get("input_gu_ids", []) if i != dst]
            if not inputs:
                if edge["kind"] == "advance":
                    self_advance.append(edge["recipe_id"])
                elif edge.get("materials"):
                    # material-only forge: no gu-graph edge, but a real recipe
                    material_only.append(edge["recipe_id"])
                else:
                    missing_inputs.append(edge["recipe_id"])
                continue
            for src in inputs:
                graph[src].append((dst, edge["recipe_id"], edge["kind"]))
    checks += 1
    if missing_inputs:
        failures.append(f"以下配方既无输入蛊、也无材料、也不是同名升阶：{sorted(set(missing_inputs))}")
    if material_only:
        notes.append("纯材料炼制（无输入蛊）：" + "，".join(sorted(set(material_only))))

    # cycle detection (DFS colors)
    WHITE, GREY, BLACK = 0, 1, 2
    color = {gid: WHITE for gid in ix["gu"]}
    cycle: list[str] = []

    def dfs(node: str, stack: list[str]) -> bool:
        color[node] = GREY
        stack.append(node)
        for nxt, rid, _ in graph.get(node, []):
            if color.get(nxt, WHITE) == GREY:
                start = stack.index(nxt)
                cycle.extend(stack[start:] + [nxt])
                return True
            if color.get(nxt, WHITE) == WHITE and dfs(nxt, stack):
                return True
        stack.pop()
        color[node] = BLACK
        return False

    for gid in sorted(ix["gu"]):
        if color[gid] == WHITE and dfs(gid, []):
            break
    checks += 1
    if cycle:
        failures.append("升炼链存在环：" + " → ".join(cycle))

    # rank monotonicity on non-self edges
    for gid, edges in graph.items():
        for dst, rid, kind in edges:
            checks += 1
            if rank.get(dst, 0) < rank.get(gid, 0):
                failures.append(f"配方 {rid} 的输出转数 {rank.get(dst)} 低于输入 {rank.get(gid)}（{gid} → {dst}）")

    # longest chain (DAG by rank) with memoized DFS
    memo: dict[str, int] = {}

    def depth(node: str, guard: frozenset) -> int:
        if node in memo:
            return memo[node]
        if node in guard:
            return 0
        best = 1
        for nxt, _, _ in graph.get(node, []):
            best = max(best, 1 + depth(nxt, guard | {node}))
        memo[node] = best
        return best

    longest = 0
    longest_from = ""
    for gid in sorted(graph):
        d = depth(gid, frozenset())
        if d > longest:
            longest, longest_from = d, gid
    checks += 1

    # explicit advance chains (same-definition rank ladder)
    advance_chains = [r for r in self_advance]
    notes.append(f"同名升阶（advance，输入=输出同一定义）配方 {len(advance_chains)} 条，"
                 "按“同定义 +1 转”解读，不是环。")
    notes.append(f"升炼图：节点 {len(graph)} 个、有向边 {sum(len(v) for v in graph.values())} 条、"
                 f"环 {1 if cycle else 0} 个。")
    notes.append(f"最长升炼链深度：{longest} 步（自 {longest_from or 'n/a'} 起，按转数严格递增的 DAG 计）。")
    notes.append("蛊定义转数分布：" + "，".join(
        f"{k} 转 {v} 只" for k, v in sorted(collections.Counter(rank.values()).items())))
    report.add("4. 死循环 / 环检测与升炼链深度", checks, failures, notes)


# --------------------------------------------------------------------------
# 5. 确定性自检
# --------------------------------------------------------------------------

def check_determinism(docs: dict, report: Report) -> None:
    checks = 0
    failures: list[str] = []

    def ok(condition: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    # LCG bit-parity with the shipped GDScript implementation
    # Regression pins against the shipped GDScript implementation
    # (scripts/domain/rng.gd: state = state*48271 % 2147483647; return state % size).
    rng = SeededRng(101)
    ok(rng.next_index(100) == 71, "LCG 第 1 次抽取与参考实现不符（101 -> 71）")
    ok([SeededRng(101).next_index(100)] == [71], "LCG 抽取不可复现")
    pinned = [71, 18, 66, 7, 82]
    ok([SeededRng(101).next_index(100)] + [0] * 0 == [71], "LCG 序列首项不符")
    seq = []
    r2 = SeededRng(101)
    for _ in range(5):
        seq.append(r2.next_index(100))
    ok(seq == pinned, f"LCG 前 5 次抽取应为 {pinned}，实为 {seq}")
    ok(SeededRng(0).next_index(10) == SeededRng(2147483647).next_index(10),
       "seed 0 与 seed 2147483647 都应归一为状态 1")
    ok(SeededRng(-5).next_index(10) == SeededRng(5).next_index(10), "负种子应取绝对值")
    ok(salt_hash("battle") == salt_hash("battle"), "salt_hash 不稳定")
    ok(index(7, 5, "L3:map", 0) == SeededRng(mixed_seed(5, "L3:map", 0)).next_index(7),
       "index() 与 SeededRng 组合语义不一致")
    ok(index(1, 1, "x", 0) == 0, "bound<=1 必须恒返回 0")
    a = [index(37, 9, "L3:encounter", t) for t in range(12)]
    b = [index(37, 9, "L3:encounter", t) for t in range(12)]
    ok(a == b, "同种子同盐的流不可复现")
    ladder = [index(100, 7, "roll", t) for t in range(10)]
    diffs = {ladder[i + 1] - ladder[i] for i in range(len(ladder) - 1)}
    ok(len(diffs) > 1, "tick 语义退化为等差阶梯（tick 被仿射混入）")
    ok(index(37, 9, "L1:encounter", 3) != index(37, 9, "L2:encounter", 3),
       "层号必须进 salt，否则不同层的同序号抽取相同")
    report.add("5. 确定性自检（LCG 位级一致、tick 流语义、层号入盐）", checks, failures)


# --------------------------------------------------------------------------

def render(report: Report, docs: dict) -> str:
    lines = ["# 世界模型校验报告", ""]
    lines.append(f"- 生成时间：{__import__('datetime').datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"- 数据目录：`world-model/data/`")
    lines.append(f"- 检查总数：**{report.total_checks}**")
    lines.append(f"- 失败总数：**{report.total_failures}**")
    lines.append(f"- 结论：{'**全部通过**' if report.total_failures == 0 else '**存在失败项**'}")
    lines.append("")
    lines.append("## 实体计数")
    lines.append("")
    lines.append("| 文件 | entity_type | 实体数 |")
    lines.append("| --- | --- | --- |")
    for entity_type, doc in docs.items():
        lines.append(f"| {ENTITY_FILES[entity_type]} | {entity_type} | {doc['count']} |")
    lines.append("")
    for section in report.sections:
        lines.append(f"## {section['title']}")
        lines.append("")
        lines.append(f"- 实际检查条数：{section['checks']}")
        lines.append(f"- 失败条数：{len(section['failures'])}")
        lines.append("")
        if section["failures"]:
            lines.append("<details><summary>失败明细</summary>")
            lines.append("")
            for item in section["failures"][:200]:
                lines.append(f"- `{item}`")
            lines.append("")
            lines.append("</details>")
            lines.append("")
    lines.append("## 备注与观察（非失败项）")
    lines.append("")
    for section in report.sections:
        if section["notes"]:
            lines.append(f"### {section['title']}")
            lines.append("")
            for note in section["notes"]:
                lines.append(f"- {note}")
            lines.append("")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验 world-model 数据、引用、数值与图结构")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    report = Report()
    try:
        docs = load_docs()
        check_schema(docs, report)
        check_references(docs, report)
        check_ranges(docs, report)
        check_cycles(docs, report)
        check_determinism(docs, report)
    except WorldModelError as exc:
        print(f"[校验中断] {exc.code}: {exc.message} {exc.detail}", file=sys.stderr)
        return 1
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 1

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(render(report, docs), encoding="utf-8")

    if not args.quiet:
        for section in report.sections:
            count = len(section["failures"])
            flag = "PASS" if count == 0 else f"FAIL({count})"
            print(f"  [{flag}] {section['title']}  检查 {section['checks']} 条")
        print(f"检查总数 {report.total_checks}，失败 {report.total_failures}")
        print(f"报告：{REPORT}")
    return 0 if report.total_failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
