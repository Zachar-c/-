"""上游漂移检测（RISK-13）：world-model/data 是从上游 data/ 派生的快照，
上游被并行改动后两边会静默漂移。本脚本重新从上游读取关键事实并与 world-model 比对。

    python world-model/tools/check_upstream_drift.py

退出码：0 = 无漂移；1 = 检测到漂移（详情见 stdout）。
"""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
WM = Path(__file__).resolve().parents[1]
UP = WM.parent / "data"


def load(root: Path, name: str):
    p = root / f"{name}.json"
    return json.load(io.open(p, encoding="utf-8"))


def wm_entities(name: str):
    d = load(WM / "data", name)
    return {e["id"]: e for e in d.get("entities", [])}


drift: list[str] = []
checked = 0


def cmp(label: str, up, wm, key=None):
    global checked
    checked += 1
    a = key(up) if key else up
    b = key(wm) if key else wm
    if a != b:
        drift.append(f"{label}: 上游={a!r} 世界模型={b!r}")


# ---- gu ----
up_gu = load(UP, "gu")
up_names = load(UP, "gu_names")
wm_gu = wm_entities("gu")
up_ids = {g["id"] for g in up_gu}
wm_ids = set(wm_gu)
cmp("gu 数量", len(up_ids), len(wm_ids))
missing = sorted(up_ids - wm_ids)[:10]
extra = sorted(wm_ids - up_ids)[:10]
if missing or extra:
    drift.append(f"gu id 集合不一致：上游多 {missing}；世界模型多 {extra}")
for gid in sorted(up_ids & wm_ids):
    g, e = next(x for x in up_gu if x["id"] == gid), wm_gu[gid]
    for field, upf, wmf in (("rank", "rank", "rank"), ("value", "value", "value"),
                            ("school", "school", "school"), ("role", "role", "role"),
                            ("rarity", "rarity", "rarity")):
        cmp(f"gu[{gid}].{field}", g.get(upf), e.get(wmf))
    # effect_source 是世界模型的派生判定（上游给蛊补上显式 v1_effect 后，未重生成
    # 的 gu.json 会静默停留在 role_default）。只比这个枚举即可覆盖该类漏同步，
    # 不必在此复算 effect 本体（那会把生成器逻辑抄成第二份真相）。
    want_effect_source = ("explicit" if "v1_effect" in g
                          else "combat_effects" if "combat_effects" in g
                          else "role_default")
    cmp(f"gu[{gid}].effect_source", want_effect_source, e.get("effect_source"))
    if up_names.get(gid) and up_names[gid] != e.get("name_zh"):
        drift.append(f"gu[{gid}].name_zh: 上游名={up_names[gid]!r} 世界模型={e.get('name_zh')!r}")

# ---- enemies ----
up_en = load(UP, "enemies")
wm_en = wm_entities("regions")
wm_enemy = {}
for e in wm_en.values():
    for x in (e.get("enemy_roster") or []):
        wm_enemy[x["id"]] = x
up_en_ids = {e["id"] for e in up_en}
cmp("敌人数量", len(up_en_ids), len(wm_enemy))
if up_en_ids - set(wm_enemy):
    drift.append(f"敌人缺失：{sorted(up_en_ids - set(wm_enemy))[:10]}")
for e in up_en:
    w = wm_enemy.get(e["id"])
    if not w:
        continue
    for f in ("hp", "rank", "tier", "theme", "grade"):
        cmp(f"enemy[{e['id']}].{f}", e.get(f), w.get(f))

# ---- recipes / schools / shops / materials ----
cmp("配方数量（仅带产物边的）", len([r for r in load(UP, "refinement_recipes").get("recipes", []) if r.get("output_gu_id")]),
    sum(len(v.get("refine_as_output") or []) for v in wm_gu.values()))
def _count_entries(d):
    """上游表结构不统一：list 用长度；dict 若整体就是“id -> 定义”则用键数，
    否则取第一个 list 值（如 {"schools": [...]}）。"""
    if isinstance(d, list):
        return len(d)
    if isinstance(d, dict):
        if d and all(isinstance(v, (dict, list)) for v in d.values()) and not any(
                isinstance(v, list) for v in d.values()):
            return len(d)  # 本身就是 id -> 定义 的字典
        for v in d.values():
            if isinstance(v, list):
                return len(v)
        return len(d)
    return 0


cmp("流派数量", _count_entries(load(UP, "schools")), len(load(WM / "data", "paths").get("entities", [])))

# 商店报价：只比条数会漏掉"等量替换"（新增一条 + 删掉一条，总数不变），而 2026-09-16
# 新增的 purchase_blood_droplet 恰好是带 npc_only 标（货阶分层豁免）的规则输入，
# 漏同步会直接改变黑市/个人货架的档位判定，所以逐条比。
up_offers = {o["id"]: o for o in load(UP, "shops").get("offers", [])}
wm_offers = {o["id"]: o for e in wm_entities("economy").values() for o in (e.get("shop_offers") or [])}
cmp("商店报价数量", len(up_offers), len(wm_offers))
if set(up_offers) - set(wm_offers):
    drift.append(f"报价缺失：{sorted(set(up_offers) - set(wm_offers))[:10]}")
if set(wm_offers) - set(up_offers):
    drift.append(f"报价多余：{sorted(set(wm_offers) - set(up_offers))[:10]}")
for oid in sorted(set(up_offers) & set(wm_offers)):
    u, w = up_offers[oid], wm_offers[oid]
    for field, norm in (("kind", lambda v: v), ("tier", lambda v: int(v or 0)),
                        ("stone_cost", lambda v: v), ("npc_only", lambda v: bool(v))):
        cmp(f"报价[{oid}].{field}", norm(u.get(field)), norm(w.get(field)))

# 节点模板：同理，条数不变但某点的 stage 被改（如货郎 two→one）会让"该层可出哪些点"
# 静默失效——本层可出的点位判定直接决定地图生成，因此逐条比 stage/type。
up_nodes = {n["id"]: n for n in load(UP, "nodes").get("nodes", [])}
wm_nodes = {}
for e in wm_en.values():
    for t in (e.get("node_templates") or []):
        wm_nodes[t["id"]] = t
cmp("节点模板数量", len(up_nodes), len(wm_nodes))
if set(up_nodes) - set(wm_nodes):
    drift.append(f"节点缺失：{sorted(set(up_nodes) - set(wm_nodes))[:10]}")
if set(wm_nodes) - set(up_nodes):
    drift.append(f"节点多余：{sorted(set(wm_nodes) - set(up_nodes))[:10]}")
for nid in sorted(set(up_nodes) & set(wm_nodes)):
    for field in ("stage", "type"):
        cmp(f"节点[{nid}].{field}", up_nodes[nid].get(field), wm_nodes[nid].get(field))

print(f"检查项：{checked}｜漂移项：{len(drift)}")
if drift:
    print("\n漂移明细（前 25）：")
    for d in drift[:25]:
        print("  -", d)
    print("\n结论：检测到上游漂移，需重跑 build_world_model.py 或核对上游改动。")
    sys.exit(1)
print("\n结论：未检测到漂移。")
