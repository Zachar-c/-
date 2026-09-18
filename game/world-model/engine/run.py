"""Roguelike run structure: opening build, layer traversal, encounter mix,
boss/stage nodes, death or clear settlement, and codex-only meta inheritance.

Determinism contract
--------------------
A run's entire ledger is a pure function of (seed, world-model data digest).
No wall-clock time, no python `random`, no dict-iteration order dependence.
The ledger body is hashed into `content_sha256`; re-running the same seed must
reproduce that hash exactly.
"""

from __future__ import annotations

import hashlib
import json

from . import rules
from .errors import GuBacklash, InputError, NumericOverflow, ResourceExhausted
from .rng import Stream

LAYER_COUNT = 5
ROW_ANCHOR_KEYS = ("quarter", "mid", "pre_boss")


def _canon(payload) -> str:
    return json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


class Run:
    """One roguelike run. All state lives in `self.state` (pure data)."""

    def __init__(self, wm, seed: int, meta: dict | None = None, verbose: bool = False):
        self.wm = wm
        self.seed = int(seed)
        self.meta = meta if meta is not None else {}
        self.verbose = verbose
        self.ledger: list[dict] = []
        self.state: dict = {}
        self._seq = 0
        self.ending: str | None = None

    # ------------------------------------------------------------------ log
    def log(self, event_type: str, **payload) -> dict:
        self._seq += 1
        entry = {"seq": self._seq, "type": event_type}
        entry.update(payload)
        self.ledger.append(entry)
        return entry

    def ledger_body(self) -> str:
        return "\n".join(_canon(e) for e in self.ledger)

    def content_sha256(self) -> str:
        return hashlib.sha256(self.ledger_body().encode("utf-8")).hexdigest()

    def state_digest(self) -> str:
        return hashlib.sha256(_canon({k: v for k, v in self.state.items() if k != "map"}).encode("utf-8")).hexdigest()

    # ---------------------------------------------------------------- start
    def start(self) -> None:
        starter = self.wm.b("run", "starter")
        self.state = {
            "seed": self.seed,
            "world_model_version": self.wm.version,
            "data_digest": self.wm.data_digest,
            "status": "active",
            "aptitude": starter["aptitude"],
            "aptitude_capacity_ratio": self.wm.b("growth", "aptitude_capacity_ratio")[starter["aptitude"]],
            "rank": int(starter["rank"]),
            "stage": starter["stage"],
            "hp": int(starter["hp"]), "hp_max": int(starter["hp_max"]),
            "lifespan": int(starter["lifespan"]), "lifespan_max": int(starter["lifespan_max"]),
            "soul": int(starter["soul"]), "soul_max": int(starter["soul_max"]),
            "stone": int(starter["stone"]),
            "materials": {},
            "relics": [],
            "curses": [],
            "notoriety": 0,
            "path": starter["path"],
            "gu_instances": [],
            "recipes_used": [],
            "codex_seen": [],
            "pity_by_tier": {},
            "layer": 1,
            "row": 0,
            "node_taken": None,
            "last_node": "",
            "last_node_type": "",
            "battle": None,
            "pending_delayed": [],
            "nodes_visited": 0,
            "battles": 0,
            "turns_total": 0,
            "battle_rounds": 0,
        }
        for gu_id in starter["gu"]:
            self.state["gu_instances"].append(rules.gu_instance(self.wm, gu_id, f"g{len(self.state['gu_instances']) + 1}"))
            self.state["codex_seen"].append(gu_id)
        self.state["thought_max"] = int(starter["thought_max"])
        self._recompute(starter=True)
        self._streams = {}
        self.state["map"] = self._generate_map()
        self.log("run_start", seed=self.seed, aptitude=self.state["aptitude"], rank=self.state["rank"],
                 path=self.state["path"], starter_gu=starter["gu"], hp=self.state["hp"],
                 lifespan=self.state["lifespan"], soul=self.state["soul"], stone=self.state["stone"])

    # ------------------------------------------------------------ rng plumbing
    def stream(self, salt: str, layer: int | None = None) -> Stream:
        """One Stream per (salt, layer); the position is tracked per-stream so
        draw order inside a node/battle is independent of anything else."""
        key = (salt, layer)
        if key not in self._streams:
            self._streams[key] = Stream(self.seed, salt, layer)
        return self._streams[key]

    # ------------------------------------------------------------------ map
    def _generate_map(self) -> dict:
        macro = self.wm.regions["south_jiang"]
        templates = {t["id"]: t for t in macro["node_templates"]}
        pools = macro["template_pools"]
        layers = []
        for layer in range(1, LAYER_COUNT + 1):
            region = self.wm.region(layer)
            stream = self.stream("map", layer)
            rows_min, rows_max = region["rows_min"], region["rows_max"]
            row_count = rows_min + stream.draw(rows_max - rows_min + 1)
            width_min, width_max = region["row_nodes_min"], region["row_nodes_max"]
            anchors_by_row: dict[int, list[str]] = {}
            for anchor in region["anchors"]:
                row_key = anchor.get("row", "")
                if row_key == "quarter":
                    target = max(1, row_count // 4)
                elif row_key == "mid":
                    target = row_count // 2
                elif row_key == "pre_boss":
                    target = row_count - 2
                else:
                    continue
                if 0 <= target < row_count - 1:
                    anchors_by_row.setdefault(target, []).append(anchor["template"])
            rows = []
            for i in range(row_count):
                is_boss_row = i == row_count - 1
                if is_boss_row:
                    rows.append({"index": i, "kind": "boss", "nodes": [region["boss_seat"]]})
                    continue
                width = width_min + stream.draw(width_max - width_min + 1)
                pinned = list(anchors_by_row.get(i, []))
                if i > 0 and i % int(self.wm.b("run", "rows_between_forced_rest")) == 0:
                    rest_template = stream.pick(pools["rest"])
                    if rest_template not in pinned:
                        pinned.append(rest_template)
                width = max(width, len(pinned) + 1)
                nodes = list(pinned)
                categories = list(region["category_weights"].keys())
                weights = [(c, region["category_weights"][c]) for c in categories]
                while len(nodes) < width:
                    category = stream.weighted_pick(weights)
                    candidate = stream.pick(pools.get(category, pools["unknown"]))
                    if templates[candidate]["type"] == "shop" and "shop" in pinned:
                        candidate = "ridge_market"
                    nodes.append(candidate)
                nodes = nodes[:width]
                kind = "normal"
                if i % int(self.wm.b("run", "rows_between_forced_rest")) == 0 and i > 0:
                    kind = "rest-row"
                rows.append({"index": i, "kind": kind, "nodes": nodes})
            layers.append({"layer": layer, "name_zh": region["name_zh"], "rows": rows,
                           "boss_seat": region["boss_seat"], "boss_pool": region["boss_pool"]})
        return {"layers": layers}

    # ------------------------------------------------------------ settlement
    def _recompute(self, starter: bool = False) -> None:
        st = self.state
        st["essence_max"] = rules.essence_max(self.wm, st["rank"], st["aptitude"])
        st["essence_max_battle"] = rules.essence_max_battle(self.wm, st["rank"], st["aptitude"])
        if "essence" not in st:
            st["essence"] = st["essence_max"]
        st["essence"] = max(0, min(int(st["essence"]), st["essence_max"]))
        st["thought_max"] = int(self.wm.b("growth", "thought_base_capacity"))
        st["thoughts"] = (rules.action_points(self.wm, st["soul"]) if st.get("battle") else st["thought_max"])

    def heal(self, amount: int) -> int:
        healed = max(0, min(int(amount), self.state["hp_max"] - self.state["hp"]))
        self.state["hp"] += healed
        return healed

    def clamp(self) -> None:
        st = self.state
        for key in ("hp", "lifespan", "soul"):
            st[key] = max(0, int(st[key]))
        st["soul"] = min(st["soul"], st["soul_max"])
        st["hp"] = min(st["hp"], st["hp_max"])
        st["lifespan"] = min(st["lifespan"], st["lifespan_max"])
        st["stone"] = max(0, int(st["stone"]))
        st["essence"] = max(0, min(int(st["essence"]), st["essence_max"]))

    def check_death(self) -> bool:
        events = rules.check_death(self.wm, self.state)
        for e in events:
            if e["kind"] == "death":
                self.log("death", axis=e["axis"], cause_zh=e["cause_zh"], values=e["values"])
                self._finish("death")
                return True
        return False

    def _finish(self, outcome: str) -> None:
        self.state["status"] = outcome
        result = rules.apply_ending(self.wm, self.state, outcome, self.meta)
        self.ending = outcome
        self.log("run_end", outcome=outcome, layer=self.state["layer"], row=self.state["row"],
                 nodes_visited=self.state["nodes_visited"], battles=self.state["battles"],
                 battle_rounds=self.state["battle_rounds"], enemy_turns=self.state["turns_total"],
                 meta=result)

    # =====================================================================
    # Map traversal
    # =====================================================================
    def current_row(self) -> dict | None:
        if self.state["status"] != "active":
            return None
        layer = self.state["map"]["layers"][self.state["layer"] - 1]
        rows = layer["rows"]
        if self.state["row"] >= len(rows):
            return None
        return rows[self.state["row"]]

    def row_options(self) -> list[dict]:
        row = self.current_row()
        if row is None:
            return []
        macro = self.wm.regions["south_jiang"]
        templates = {t["id"]: t for t in macro["node_templates"]}
        out = []
        for i, tid in enumerate(row["nodes"]):
            t = templates[tid]
            out.append({
                "index": i,
                "template": tid,
                "type": t["type"],
                "summary_zh": t["summary_zh"] or t["type"],
                "is_boss": bool(t.get("layer_boss")),
                "enemy_kind": t.get("enemy_kind", ""),
                "visible": t["visible"],
            })
        return out

    def choose_node(self, index: int) -> None:
        row = self.current_row()
        if row is None:
            raise InputError("当前没有可选节点")
        if not 0 <= int(index) < len(row["nodes"]):
            raise InputError(f"节点序号 {index} 越界（本行共 {len(row['nodes'])} 个可选节点）")
        tid = row["nodes"][int(index)]
        self.state["node_taken"] = tid
        self.state["nodes_visited"] += 1
        template = self._template(tid)
        self.log("node_enter", layer=self.state["layer"], row=self.state["row"], template=tid,
                 node_type=template["type"], hp=self.state["hp"], stone=self.state["stone"])
        self._resolve_delayed()
        if template["type"] in ("combat", "pursuit"):
            self._start_battle(template)
        elif template["type"] == "earth_vein":
            self._start_battle(template)
        elif template["type"] == "event":
            pass  # event node is resolved by node_actions()
        else:
            pass

    def advance_row(self) -> None:
        """Finish the current node and move to the next row (one node per row)."""
        if self.state["node_taken"]:
            self.state["last_node"] = self.state["node_taken"]
            self.state["last_node_type"] = self._template(self.state["node_taken"])["type"]
        self.state["node_taken"] = None
        self.state["battle"] = None
        self.state["row"] += 1
        layer = self.state["map"]["layers"][self.state["layer"] - 1]
        if self.state["row"] >= len(layer["rows"]):
            self._end_layer()

    def _end_layer(self) -> None:
        layer = self.state["layer"]
        milestone = self.wm.b("run", "lifespan_milestones")
        if layer >= 1:
            self.state["lifespan"] = min(self.state["lifespan_max"],
                                         self.state["lifespan"] + int(milestone["stage_one_ledger"]))
            self.log("lifespan_milestone", reason="stage_ledger", gained=int(milestone["stage_one_ledger"]),
                     lifespan=self.state["lifespan"])
        bill = rules.settle_feeding(self.wm, self.state)
        self.log("feeding_ledger", layer=layer, bill=bill["bill"], paid=bill["paid"],
                 shortfall=bill["shortfall"], backlash=bill["backlash"])
        self.clamp()
        if self.check_death():
            return
        if layer >= LAYER_COUNT:
            self._finish("ascended")
            return
        self.state["layer"] = layer + 1
        self.state["row"] = 0
        self.log("layer_enter", layer=self.state["layer"],
                 name_zh=self.wm.region(self.state["layer"])["name_zh"],
                 stone_budget=self.wm.region(self.state["layer"])["stone_budget"])

    def _template(self, tid: str) -> dict:
        for t in self.wm.regions["south_jiang"]["node_templates"]:
            if t["id"] == tid:
                return t
        raise InputError(f"未知节点模板 {tid!r}")

    def _resolve_delayed(self) -> None:
        pending = self.state["pending_delayed"]
        if not pending:
            return
        self.state["pending_delayed"] = []
        for item in pending:
            if item.get("soul"):
                self.state["soul"] = max(0, self.state["soul"] - int(item["soul"]))
                self.log("delayed_cost_paid", curse_id=item.get("curse_id", ""), soul_cost=int(item["soul"]),
                         soul=self.state["soul"])
        self.clamp()
        self.check_death()

    # =====================================================================
    # Node actions
    # =====================================================================
    def node_actions(self) -> list[dict]:
        if self.state["status"] != "active":
            return []
        if self.state.get("battle") and self.state["battle"]["active"]:
            return self._battle_actions()
        template = self._template(self.state["node_taken"]) if self.state["node_taken"] else None
        if template is None:
            return [{"id": "next", "label_zh": "选择下一个节点"}]
        actions = []
        ttype = template["type"]
        if ttype == "rest":
            cost = self.wm.b("run", "rest_heal_pct")
            actions.append({"id": "rest_heal", "label_zh": f"静养（恢复 {cost}% 气血）",
                            "effects": {"hp_pct": cost}})
            actions.append({"id": "rest_cultivate", "label_zh": "就地突破（若条件满足）"})
            actions.append({"id": "skip", "label_zh": "跳过"})
        elif ttype in ("shop", "market", "caravan"):
            actions.append({"id": "trade_buy", "label_zh": "查看货架并购买"})
            actions.append({"id": "trade_sell", "label_zh": "出售蛊材"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "refinement":
            actions.append({"id": "refine", "label_zh": "炼蛊（选一条可用配方）"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "cultivation":
            actions.append({"id": "cultivate", "label_zh": "冲击下一转"})
            actions.append({"id": "rest_heal", "label_zh": "静坐调息"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "event":
            pool = template.get("event_pool") or [self.wm.all("event")[0]["id"]]
            actions.append({"id": "event_resolve", "label_zh": "面对事件"})
            actions.append({"id": "skip", "label_zh": "绕开"})
        elif ttype in ("inheritance", "seclusion"):
            actions.append({"id": "claim_inheritance", "label_zh": "查探并取走遗藏"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "wild_gu":
            actions.append({"id": "harvest_gu", "label_zh": "采集野生蛊虫"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "hazard":
            actions.append({"id": "hazard_scout", "label_zh": "谨慎侦察（消耗元石）"})
            actions.append({"id": "hazard_cross", "label_zh": "强行穿越（消耗气血）"})
            actions.append({"id": "skip", "label_zh": "绕行"})
        elif ttype == "ledger":
            actions.append({"id": "settle", "label_zh": "结清养护总账"})
            actions.append({"id": "skip", "label_zh": "拖着（接受欠账）"})
        elif ttype == "commission":
            actions.append({"id": "commission_accept", "label_zh": "接下委托"})
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "contact":
            actions.append({"id": "contact_negotiate", "label_zh": "交涉"})
            actions.append({"id": "contact_deceive", "label_zh": "欺瞒"})
            actions.append({"id": "contact_fight", "label_zh": "动手"})
            actions.append({"id": "contact_retreat", "label_zh": "退走"})
        elif ttype == "earth_vein":
            actions.append({"id": "skip", "label_zh": "离开"})
        elif ttype == "ascension":
            actions.append({"id": "skip", "label_zh": "暂缓"})
        else:
            actions.append({"id": "skip", "label_zh": "离开"})
        if self.state.get("battle") and not self.state["battle"]["active"]:
            actions.insert(0, {"id": "next", "label_zh": "继续前进"})
        return actions

    def apply_action(self, action_id: str) -> list[str]:
        """Dispatch one non-battle node action. Returns human-readable lines."""
        st = self.state
        if st["status"] != "active":
            return ["本局已结束。"]
        if st.get("battle") and st["battle"]["active"]:
            return self.apply_battle_action(action_id)
        template = self._template(st["node_taken"]) if st["node_taken"] else None
        lines: list[str] = []
        advance = True

        if action_id in ("next", "skip"):
            self.advance_row()
            return ["（继续前进）"]

        if action_id == "rest_heal":
            healed = self.heal(int(st["hp_max"] * self.wm.b("run", "rest_heal_pct") / 100))
            self.log("rest_heal", healed=healed, hp=st["hp"])
            lines.append(f"调息完毕，气血 +{healed}（当前 {st['hp']}/{st['hp_max']}）。")
        elif action_id == "rest_cultivate" or action_id == "cultivate":
            lines.extend(self._do_cultivate())
        elif action_id == "trade_buy":
            lines.extend(self._do_buy())
        elif action_id == "trade_sell":
            lines.extend(self._do_sell())
        elif action_id == "refine":
            lines.extend(self._do_refine())
        elif action_id == "event_resolve":
            lines.extend(self._do_event(template))
        elif action_id == "claim_inheritance":
            lines.extend(self._do_inheritance())
        elif action_id == "harvest_gu":
            lines.extend(self._do_harvest())
        elif action_id == "hazard_scout":
            st["stone"] = max(0, st["stone"] - int(self.wm.b("run", "retreat_stone_cost")))
            self.log("hazard_scout", stone_cost=int(self.wm.b("run", "retreat_stone_cost")), stone=st["stone"])
            lines.append("谨慎侦察花去少量元石，安全通过。")
        elif action_id == "hazard_cross":
            loss = max(1, st["hp_max"] // 10)
            st["hp"] -= loss
            self.log("hazard_cross", hp_loss=loss, hp=st["hp"])
            lines.append(f"强行穿越：气血 -{loss}。")
            self.clamp()
            if self.check_death():
                return lines
        elif action_id == "settle":
            bill = rules.settle_feeding(self.wm, st)
            self.log("feeding_settled", **bill)
            lines.append(f"养护总账 {bill['bill']} 元石，付清 {bill['paid']}，欠 {bill['shortfall']}。")
            self.clamp()
            if self.check_death():
                return lines
        elif action_id == "commission_accept":
            reward = 3 + int(st["layer"])
            st["stone"] += reward
            self.log("commission_done", reward=reward, stone=st["stone"])
            lines.append(f"委托完成，得元石 {reward}。")
        elif action_id == "contact_negotiate":
            lines.extend(self._do_contact("negotiate"))
        elif action_id == "contact_deceive":
            lines.extend(self._do_contact("deceive"))
        elif action_id == "contact_fight":
            self._start_battle(template)
            lines.append("你抢先动手！")
            advance = False
        elif action_id == "contact_retreat":
            cost = int(self.wm.b("run", "retreat_stone_cost"))
            if st["stone"] >= cost:
                st["stone"] -= cost
                self.log("retreat", stone_cost=cost, stone=st["stone"])
                lines.append(f"退走，花去元石 {cost}。")
            else:
                lines.append("元石不足，退不走，只能硬着头皮留下。")
        else:
            raise InputError(f"未知操作 {action_id!r}")

        self.clamp()
        if advance and st["status"] == "active" and not (st.get("battle") and st["battle"]["active"]):
            self.advance_row()
        return lines

    # ------------------------------------------------------------ sub-actions
    def _do_cultivate(self) -> list[str]:
        st = self.state
        target = st["rank"] + 1
        ok, reason = rules.can_cultivate_to(self.wm, st["rank"], target, st["aptitude"])
        if not ok:
            self.log("cultivate_blocked", target=target, reason=reason, aptitude=st["aptitude"])
            return [f"无法突破：{reason}"]
        cost = rules.cultivation_cost(self.wm, target)
        if st["stone"] < cost:
            raise ResourceExhausted(f"元石不足：突破 {target} 转需要 {cost}，现有 {st['stone']}")
        st["stone"] -= cost
        st["rank"] = target
        st["stage"] = "initial"
        self._recompute()
        self.log("rank_up", rank=target, stone_cost=cost, essence_max=st["essence_max"],
                 essence_max_battle=st["essence_max_battle"])
        return [f"突破成功：你已是一转之上一名 {target} 转蛊师（真元上限 {st['essence_max']}）。"]

    def _do_buy(self) -> list[str]:
        st = self.state
        region = self.wm.region(st["layer"])
        price_pct = int(region["shop_price_pct"]) + int(st["notoriety"]) * int(
            self.wm.b("faction", "reputation_effects")["price_pct_per_point"])
        price_pct = min(price_pct, int(self.wm.b("faction", "reputation_effects")["price_cap_pct"])) \
            if st["notoriety"] > 0 else price_pct
        candidates = [g for g in self.wm.gu.values()
                      if g["shop_offer_ids"] and not g["is_test_entity"]
                      and int(g["rank"]) <= int(region["shop_max_tier"])]
        if not candidates:
            return ["此地无货可供。"]
        stream = self.stream(f"shop_buy:{st['layer']}:{st['nodes_visited']}", st["layer"])
        pick = stream.pick(sorted(candidates, key=lambda g: g["id"]))
        base = rules.gu_value(self.wm, pick["id"])
        cost = int(round(base * (1 + price_pct / 100.0)))
        if st["stone"] < cost:
            return [f"看中 {pick['name_zh']}（{cost} 元石）但元石不足。"]
        st["stone"] -= cost
        st["gu_instances"].append(rules.gu_instance(self.wm, pick["id"], f"g{len(st['gu_instances']) + 1}"))
        st["codex_seen"].append(pick["id"])
        self.log("gu_purchased", gu_id=pick["id"], stone_cost=cost, price_pct=price_pct, stone=st["stone"])
        return [f"买下 {pick['name_zh']}（{cost} 元石，含 {price_pct}% 加价）。"]

    def _do_sell(self) -> list[str]:
        st = self.state
        if not st["materials"]:
            return ["没有可卖的蛊材。"]
        ratio = self.wm.b("economy", "public_buyback_ratio")
        total = 0
        for mid, count in list(st["materials"].items()):
            mat = self.wm.material(mid)
            total += int(round(mat["value"] * ratio * count))
        st["stone"] += total
        st["materials"] = {}
        self.log("materials_sold", stone_gain=total, stone=st["stone"])
        return [f"卖出全部蛊材，得元石 {total}。"]

    def _do_refine(self) -> list[str]:
        st = self.state
        held = {i["gu_id"] for i in st["gu_instances"] if i.get("alive", True)}
        options = []
        for gid in sorted(held):
            for edge in self.wm.gu_def(gid)["refine_as_output"]:
                if edge["kind"] == "free_mix":
                    continue
                need_ok = all(st["materials"].get(m, 0) >= n for m, n in (edge["materials"] or {}).items())
                if need_ok and edge["stone_cost"] <= st["stone"]:
                    options.append((gid, edge))
        if not options:
            return ["没有可用配方（材料或元石不足）。"]
        gid, edge = sorted(options, key=lambda pair: (pair[1]["stone_cost"], pair[1]["recipe_id"]))[0]
        result = rules.refine_gu(self.wm, st, gid, edge)
        st["recipes_used"].append(result["recipe_id"])
        st["codex_seen"].append(result["output"])
        self.log("refine_success", **result, stone=st["stone"])
        return [f"炼蛊成功：{result['recipe_id']} → {self.wm.gu_def(result['output'])['name_zh']}"
                f"（{result['instance_rank']} 转）。"]

    def _do_event(self, template: dict) -> list[str]:
        st = self.state
        pool = template.get("event_pool") or [e["id"] for e in self.wm.all("event")]
        stream = self.stream(f"event:{template['id']}", st["layer"])
        event_id = stream.pick(sorted(pool))
        event = self.wm.by_id("event", event_id)
        accept = stream.chance(70)
        option = next(o for o in event["options"] if o["id"] == ("accept" if accept else "decline"))
        eff = option["effects"]
        applied = []
        if eff["stone_gain"]:
            st["stone"] += int(eff["stone_gain"])
            applied.append(f"元石 +{eff['stone_gain']}")
        if eff["health_cost"]:
            st["hp"] -= int(eff["health_cost"])
            applied.append(f"气血 -{eff['health_cost']}")
        if eff["delayed_soul_cost"]:
            st["pending_delayed"].append({"soul": int(eff["delayed_soul_cost"]),
                                          "curse_id": eff.get("curse_id", ""),
                                          "trigger": eff.get("delayed_trigger", "")})
            applied.append(f"延迟代价：魂 -{eff['delayed_soul_cost']}")
        if eff.get("curse_id"):
            st["curses"].append({"id": eff["curse_id"], "stages": 1})
            applied.append(f"染上诅咒「{eff.get('curse_name_zh') or eff['curse_id']}」")
        self.log("event_resolved", event_id=event_id, option=option["id"], applied=applied,
                 hp=st["hp"], stone=st["stone"], soul=st["soul"])
        self.clamp()
        if self.check_death():
            return [f"事件「{event['name_zh']}」夺走了你的性命。"]
        return [f"事件「{event['name_zh']}」：{option['label_zh']}。" + ("；".join(applied) if applied else "（无变化）")]

    def _do_inheritance(self) -> list[str]:
        st = self.state
        stream = self.stream(f"inheritance:{st['layer']}:{st['nodes_visited']}", st["layer"])
        relics = self.wm.loot["relics"]
        if relics and stream.chance(60):
            relic = stream.pick(sorted(relics, key=lambda r: r["id"]))
            if relic["id"] not in [r["id"] for r in st["relics"]]:
                st["relics"].append({"id": relic["id"]})
                self.log("relic_gained", relic_id=relic["id"])
                return [f"你从遗藏中取出遗物「{relic['id']}」。（{self.wm.loot['id']}）"]
        stone = 4 + int(st["layer"])
        st["stone"] += stone
        self.log("inheritance_stone", stone_gain=stone, stone=st["stone"])
        return [f"遗藏里只剩零散家当，得元石 {stone}。"]

    def _do_harvest(self) -> list[str]:
        st = self.state
        stream = self.stream("harvest", st["layer"])
        candidates = [g for g in self.wm.gu.values()
                      if not g["is_test_entity"] and int(g["rank"]) <= min(int(st["rank"]) + 1,
                                                                          int(self.wm.region(st["layer"])["enemy_rank_max"]))]
        pick = stream.pick(sorted(candidates, key=lambda g: g["id"]))
        st["gu_instances"].append(rules.gu_instance(self.wm, pick["id"], f"g{len(st['gu_instances']) + 1}"))
        st["codex_seen"].append(pick["id"])
        self.log("wild_gu_harvested", gu_id=pick["id"], rank=pick["rank"])
        return [f"采得野生 {pick['name_zh']}（{pick['rank']} 转）。"]

    def _do_contact(self, mode: str) -> list[str]:
        st = self.state
        stream = self.stream(f"contact:{mode}", st["layer"])
        if mode == "negotiate":
            if stream.chance(60):
                info_gain = 2
                st["stone"] += info_gain
                self.log("contact_negotiated", success=True, stone_gain=info_gain)
                return [f"对方透露了山道行情，折成元石 {info_gain}。"]
            st["notoriety"] += 1
            self.log("contact_negotiated", success=False, notoriety=st["notoriety"])
            return ["交涉破裂，你的名头受了损（恶名 +1）。"]
        if mode == "deceive":
            if stream.chance(50):
                st["stone"] += 3
                self.log("contact_deceived", success=True, stone_gain=3)
                return ["你骗过了对方，顺手拿走 3 元石。"]
            st["notoriety"] += int(self.wm.b("faction", "reputation_gains")["broken_trust"])
            self.log("contact_deceived", success=False, notoriety=st["notoriety"])
            return ["欺瞒被识破，恶名 +1。"]
        raise InputError(f"未知交涉方式 {mode!r}")

    # =====================================================================
    # Battle
    # =====================================================================
    def _start_battle(self, template: dict, enemy_id: str | None = None) -> None:
        st = self.state
        region = self.wm.region(st["layer"])
        enemy_id = enemy_id or template.get("enemy_kind")
        if not enemy_id:
            pool = region["enemy_pool"] or [e["id"] for e in self.wm.regions["south_jiang"]["enemy_roster"]]
            enemy_id = pool[0]
        roster = {e["id"]: e for e in self.wm.regions["south_jiang"]["enemy_roster"]}
        tier = roster[enemy_id]["tier"]
        if template.get("layer_boss") and region["boss_pool"]:
            stream = self.stream("boss_pick", st["layer"])
            enemy_id = stream.pick(sorted(region["boss_pool"]))
            tier = roster[enemy_id]["tier"]
        enemy = rules.enemy_profile(self.wm, enemy_id, st["layer"], turn=int(region["enemy_turn"]))
        st["battle"] = {
            "active": True, "enemy": enemy, "turn": 1, "shield": 0, "phase_index": 0,
            "cooldown_until": {}, "tier": tier, "template": template["id"],
        }
        st["essence"] = st["essence_max_battle"]
        st["thoughts"] = rules.action_points(self.wm, st["soul"])
        st["battles"] += 1
        self.log("battle_start", enemy_id=enemy_id, tier=tier, layer=st["layer"], hp=enemy["hp_max"],
                 intent=enemy["intent"].get("id", ""), intent_damage=enemy["intent"].get("damage", 0))

    def _battle_actions(self) -> list[dict]:
        st = self.state
        battle = st["battle"]
        actions = [{"id": "basic_attack", "label_zh": "基础攻击（1 念头，0 真元）",
                    "damage": int(self.wm.b("run", "fight_damage_base"))}]
        for inst in st["gu_instances"]:
            if not inst.get("alive", True):
                continue
            definition = self.wm.gu_def(inst["gu_id"])
            exception = bool(definition.get("low_rank_exception"))
            eligible = rules.can_activate(self.wm, st["rank"], inst["instance_rank"], exception)
            cost = int(round(rules.actual_activation_cost(
                self.wm, int(definition["activation_cost"]), inst["instance_rank"], st["rank"])))
            entry = {
                "id": f"gu:{inst['iid']}", "label_zh": f"催蛊 {inst['name_zh']}",
                "gu_id": inst["gu_id"], "essence_cost": cost, "eligible": eligible,
                "sealed": int(inst.get("sealed_turns", 0)) > 0,
            }
            if not eligible:
                entry["label_zh"] = f"催蛊 {inst['name_zh']}（越级，需强催）"
                entry["backlash_preview"] = rules.backlash_preview(self.wm, st, inst)
                entry["force_id"] = f"gu_force:{inst['iid']}"
            actions.append(entry)
        actions.append({"id": "end_turn", "label_zh": "结束回合"})
        return actions

    def apply_battle_action(self, action_id: str) -> list[str]:
        st = self.state
        battle = st["battle"]
        if not battle or not battle["active"]:
            raise InputError("当前不在战斗中")
        if st["thoughts"] <= 0 and action_id != "end_turn":
            raise ResourceExhausted("本回合念头已用尽，请结束回合")
        lines: list[str] = []
        if action_id != "end_turn":
            st["battle_rounds"] += 1

        if action_id == "end_turn":
            lines.append("你收势退步。")
            return self._enemy_turn(lines, battle)

        if action_id == "basic_attack":
            damage = int(self.wm.b("run", "fight_damage_base"))
            st["thoughts"] -= 1
            battle["enemy"]["hp"] -= damage
            self.log("battle_basic_attack", damage=damage, enemy_hp=max(0, battle["enemy"]["hp"]),
                     thoughts=st["thoughts"])
            lines.append(f"基础攻击命中，造成 {damage} 点伤害。")
        elif action_id.startswith("gu:") or action_id.startswith("gu_force:"):
            forced = action_id.startswith("gu_force:")
            iid = action_id.split(":", 1)[1]
            result = rules.activate_gu(self.wm, st, iid, in_battle=True, strict=not forced)
            if result.get("backlash_damage"):
                lines.append(f"强催反噬：气血 -{result['backlash_damage']}。")
                self.log("gu_backlash", iid=iid, gu_id=result["gu_id"],
                         damage=result["backlash_damage"], hp=st["hp"])
                if rules.check_death(self.wm, st):
                    self.log("death", axis="hp", cause_zh="强催越级蛊虫，反噬致死",
                             values={k: st[k] for k in self.wm.b("run", "death_axes")})
                    self._finish("death")
                    return lines
            effect = result["effect"]
            damage = int(effect.get("damage", 0))
            definition = self.wm.gu_def(result["gu_id"])
            support = definition["effect"].get("support_school")
            if support and damage > 0:
                allies = sum(1 for i in st["gu_instances"]
                             if i.get("alive", True) and i["gu_id"] != result["gu_id"]
                             and self.wm.gu_def(i["gu_id"])["school"] == support)
                if allies > 0:
                    damage += int(definition["effect"].get("support_bonus", 0))
            if damage:
                battle["enemy"]["hp"] -= damage
            if effect.get("heal"):
                healed = self.heal(int(effect["heal"]))
                lines.append(f"回复气血 {healed}。")
            if effect.get("shield"):
                battle["shield"] += int(effect["shield"])
                lines.append(f"获得护盾 {effect['shield']}（共 {battle['shield']}）。")
            self.log("battle_gu_activated", iid=iid, gu_id=result["gu_id"],
                     essence_cost=result["essence_cost"], thought_cost=result["thought_cost"],
                     damage=damage, enemy_hp=max(0, battle["enemy"]["hp"]), essence=st["essence"])
            lines.append(f"催动 {result['name_zh']}：真元 -{result['essence_cost']}"
                         + (f"，造成 {damage} 点伤害" if damage else ""))
        else:
            raise InputError(f"战斗中不支持的操作 {action_id!r}")

        if battle["enemy"]["hp"] <= 0:
            return self._win_battle(lines)
        if st["thoughts"] <= 0:
            lines.append("念头用尽，回合自动结束。")
            return self._enemy_turn(lines, battle)
        return lines

    def _enemy_turn(self, lines: list[str], battle: dict) -> list[str]:
        st = self.state
        events = rules.enemy_turn(self.wm, st, battle)
        for e in events:
            self.log("battle_enemy:" + e["kind"], **{k: v for k, v in e.items() if k != "kind"})
        for e in events:
            if e["kind"] == "enemy_attack":
                lines.append(f"敌方行动：造成 {e['damage']} 点伤害（护盾吸收 {e['absorbed']}）。")
            elif e["kind"] == "gu_sealed":
                lines.append(f"你的 {e['gu_id']} 被禁锢 {e['turns']} 回合。")
            elif e["kind"] == "soul_drained":
                lines.append(f"魂魄被摄去 {e['amount']} 点。")
            elif e["kind"] == "lifespan_burned":
                lines.append("寿元被烧去一截。")
            elif e["kind"] == "boss_phase_shift":
                lines.append("敌方进入下一相位，意图组合变化！")
            elif e["kind"] == "cooldown_wait":
                lines.append("敌方在调息，本回合未出手。")
            elif e["kind"] == "death":
                lines.append(f"你死了：{e['cause_zh']}。")
        for e in events:
            if e["kind"] == "death":
                self.log("death", axis=e["axis"], cause_zh=e["cause_zh"], values=e["values"],
                         context="battle", enemy_id=battle["enemy"]["id"])
                self._finish("death")
                return lines
        battle["turn"] += 1
        st["turns_total"] += 1
        st["essence"] = min(st["essence_max_battle"],
                            st["essence"] + rules.essence_regen_per_turn(self.wm, st["essence_max_battle"], st["aptitude"]))
        st["thoughts"] = rules.action_points(self.wm, st["soul"])
        self.clamp()
        self.log("battle_turn_start", turn=battle["turn"], essence=st["essence"], thoughts=st["thoughts"],
                 hp=st["hp"], enemy_hp=max(0, battle["enemy"]["hp"]))
        limit = int(self.wm.b("run", "max_battle_rounds"))
        if battle["turn"] > limit:
            return self._stalemate(lines, battle, limit)
        return lines

    def _stalemate(self, lines: list[str], battle: dict, limit: int) -> list[str]:
        """敌方意图全部处于 cooldown 时双方都可能无法终结战斗；超过回合上限即撤退。"""
        st = self.state
        cost = int(self.wm.b("run", "retreat_stone_cost"))
        paid = "stone"
        if st["stone"] >= cost:
            st["stone"] -= cost
        else:
            paid = "hp"
            st["hp"] -= max(1, st["hp_max"] // 10)
        self.log("battle_stalemate", enemy_id=battle["enemy"]["id"], rounds=battle["turn"] - 1,
                 limit=limit, rule=self.wm.b("run", "stalemate_rule"), paid=paid, cost=cost)
        battle["active"] = False
        lines.append(f"久攻不下（{battle['turn'] - 1} 回合），你按 {self.wm.b('run', 'stalemate_rule')} 抽身退走："
                     + (f"元石 -{cost}。" if paid == "stone" else "气血受损。"))
        self.clamp()
        if self.check_death():
            return lines
        self.advance_row()
        return lines

    def _win_battle(self, lines: list[str]) -> list[str]:
        st = self.state
        battle = st["battle"]
        enemy = battle["enemy"]
        lines.append(f"{enemy.get('name_zh', enemy['id'])}（{enemy['id']}）被击倒。")
        self.log("battle_win", enemy_id=enemy["id"], tier=battle["tier"], turns=battle["turn"] - 1)
        stream = self.stream(f"loot:{battle['tier']}", st["layer"])
        drop = rules.roll_loot(self.wm, stream, st["layer"], battle["tier"], st)
        for mid, count in drop["materials"].items():
            st["materials"][mid] = st["materials"].get(mid, 0) + int(count)
        st["stone"] += drop["stone"]
        if drop["gu"]:
            st["gu_instances"].append(rules.gu_instance(self.wm, drop["gu"], f"g{len(st['gu_instances']) + 1}"))
            st["codex_seen"].append(drop["gu"])
        self.log("battle_loot", tier=drop["tier"], materials=drop["materials"], gu=drop["gu"],
                 stone=drop["stone"], pity=drop["pity"])
        st["pity_by_tier"] = drop["pity"]
        if battle["enemy"]["tier"] == "boss":
            gained = int(self.wm.b("run", "lifespan_milestones")["boss_defeated"])
            st["lifespan"] = min(st["lifespan_max"], st["lifespan"] + gained)
            self.log("lifespan_milestone", reason="boss_defeated", gained=gained, lifespan=st["lifespan"])
        battle["active"] = False
        st["essence"] = st["essence_max"]
        st["thoughts"] = st["thought_max"]
        self.clamp()
        return lines

    # =====================================================================
    # Auto-decider (headless / simulator)
    # =====================================================================
    def auto_step(self) -> str | None:
        """Apply one autonomous decision. Returns the action id applied, or None
        when the run has ended."""
        st = self.state
        if st["status"] != "active":
            return None
        if st.get("battle") and st["battle"]["active"]:
            return self._auto_battle()
        template = self._template(st["node_taken"]) if st["node_taken"] else None
        if template is None:
            return self._auto_pick_node()
        actions = {a["id"]: a for a in self.node_actions()}
        choice = self._auto_node_choice(template, actions)
        try:
            self.apply_action(choice)
        except (ResourceExhausted, GuBacklash, NumericOverflow) as exc:
            self.log("auto_action_failed", action=choice, error=exc.code, message=exc.message)
            self.apply_action("skip")
        return choice

    def _auto_pick_node(self) -> str:
        options = self.row_options()
        if not options:
            # map exhausted without a boss row (should not happen): finish safely
            self._end_layer()
            return "layer_end"
        st = self.state
        hp_ratio = st["hp"] / max(1, st["hp_max"])
        priority = {"rest": 0, "shop": 1, "market": 2, "caravan": 2, "refinement": 3,
                    "cultivation": 4, "inheritance": 5, "wild_gu": 6, "commission": 7,
                    "contact": 8, "event": 9, "hazard": 10, "combat": 11, "pursuit": 11,
                    "earth_vein": 12, "ledger": 13, "seclusion": 6, "ascension": 14}
        def key(node):
            base = priority.get(node["type"], 20)
            if node["is_boss"]:
                base = 0 if hp_ratio > 0.6 else 30
            if node["type"] == "rest" and hp_ratio > 0.85:
                base = 30
            if node["type"] in ("combat", "pursuit", "earth_vein") and hp_ratio < 0.35:
                base += 40
            return (base, node["index"])
        chosen = sorted(options, key=key)[0]
        self.choose_node(chosen["index"])
        return f"node:{chosen['template']}"

    def _auto_node_choice(self, template: dict, actions: dict) -> str:
        st = self.state
        ttype = template["type"]
        hp_ratio = st["hp"] / max(1, st["hp_max"])
        if ttype == "rest":
            if hp_ratio < 0.95:
                return "rest_heal"
            target = st["rank"] + 1
            ok, _ = rules.can_cultivate_to(self.wm, st["rank"], target, st["aptitude"])
            if ok and st["stone"] >= rules.cultivation_cost(self.wm, target):
                return "rest_cultivate"
            return "skip"
        if ttype == "cultivation":
            target = st["rank"] + 1
            ok, _ = rules.can_cultivate_to(self.wm, st["rank"], target, st["aptitude"])
            if ok and st["stone"] >= rules.cultivation_cost(self.wm, target):
                return "cultivate"
            return "rest_heal" if hp_ratio < 0.9 else "skip"
        if ttype in ("shop", "market", "caravan"):
            if st["stone"] >= 8:
                return "trade_buy"
            if st["materials"]:
                return "trade_sell"
            return "skip"
        if ttype == "refinement":
            return "refine"
        if ttype == "hazard":
            if st["stone"] >= int(self.wm.b("run", "retreat_stone_cost")):
                return "hazard_scout"
            return "skip"
        if ttype == "event":
            return "event_resolve" if hp_ratio > 0.4 else "skip"
        if ttype in ("inheritance", "seclusion"):
            return "claim_inheritance"
        if ttype == "wild_gu":
            return "harvest_gu"
        if ttype == "commission":
            return "commission_accept"
        if ttype == "contact":
            return "contact_negotiate" if hp_ratio > 0.5 else "contact_retreat"
        if ttype == "ledger":
            return "settle"
        return "skip"

    def _auto_battle(self) -> str:
        st = self.state
        battle = st["battle"]
        hp_ratio = st["hp"] / max(1, st["hp_max"])
        # heal first when hurt and a healing gu is available
        if hp_ratio < 0.5:
            for action in self._battle_actions():
                if action["id"].startswith("gu:") and action.get("eligible") and not action.get("sealed"):
                    inst = next(i for i in st["gu_instances"] if i["iid"] == action["id"][3:])
                    effect = self.wm.gu_def(inst["gu_id"])["effect"]
                    if effect.get("kind") in ("heal", "heal_and_strike") and action["essence_cost"] <= st["essence"]:
                        self.apply_battle_action(action["id"])
                        return action["id"]
        # otherwise the most damaging affordable, eligible gu
        best, best_damage = None, 0
        for action in self._battle_actions():
            if not action["id"].startswith("gu:") or not action.get("eligible") or action.get("sealed"):
                continue
            inst = next(i for i in st["gu_instances"] if i["iid"] == action["id"][3:])
            definition = self.wm.gu_def(inst["gu_id"])
            effect = definition["effect"]
            damage = 0
            if effect.get("kind") in ("strike",):
                damage = int(effect.get("amount", 0))
            elif effect.get("kind") == "heal_and_strike":
                damage = int(effect.get("amount", 0))
            if damage > best_damage and action["essence_cost"] <= st["essence"] and not action["sealed"]:
                best, best_damage = action["id"], damage
        if best:
            try:
                self.apply_battle_action(best)
            except (ResourceExhausted, GuBacklash, NumericOverflow) as exc:
                self.log("auto_battle_action_failed", action=best, error=exc.code, message=exc.message)
                self.apply_battle_action("end_turn")
            return best
        if st["thoughts"] > 0:
            self.apply_battle_action("basic_attack")
            return "basic_attack"
        self.apply_battle_action("end_turn")
        return "end_turn"

    # =====================================================================
    def run_to_end(self, max_steps: int = 20000) -> dict:
        """Drive the run autonomously until it ends. Returns a summary."""
        steps = 0
        while self.state["status"] == "active" and steps < max_steps:
            action = self.auto_step()
            steps += 1
            if action is None:
                break
        if self.state["status"] == "active":
            self.log("run_aborted", reason="step_budget_exhausted", steps=steps)
            self._finish("aborted")
        return self.summary(steps)

    def summary(self, steps: int | None = None) -> dict:
        st = self.state
        return {
            "seed": self.seed,
            "outcome": self.ending or st["status"],
            "layer_reached": st["layer"],
            "row_in_layer": st["row"],
            "nodes_visited": st["nodes_visited"],
            "battles": st["battles"],
            "battle_rounds": st["battle_rounds"],
            "enemy_turns": st["turns_total"],
            "steps": steps,
            "hp": st["hp"], "lifespan": st["lifespan"], "soul": st["soul"], "stone": st["stone"],
            "rank": st["rank"], "aptitude": st["aptitude"], "path": st["path"],
            "gu_count": len([i for i in st["gu_instances"] if i.get("alive", True)]),
            "main_gu": _main_gu(st),
            "materials": st["materials"],
            "relics": [r["id"] for r in st["relics"]],
            "curses": [c["id"] for c in st["curses"]],
            "run_codex_count": len(set(self.state.get("codex_seen", []))),
            "run_recipe_count": len(set(self.state.get("recipes_used", []))),
            "ledger_entries": len(self.ledger),
            "content_sha256": self.content_sha256(),
            "state_digest": self.state_digest(),
            "death_cause": next((e.get("cause_zh", "")
                                 for e in reversed(self.ledger)
                                 if e["type"] == "death" or e["type"].endswith(":death")), ""),
            "last_node": st.get("last_node", st["node_taken"] or ""),
            "last_node_type": st.get("last_node_type", ""),
        }


def _main_gu(state: dict) -> str:
    alive = [i for i in state["gu_instances"] if i.get("alive", True)]
    if not alive:
        return ""
    counts: dict[str, int] = {}
    for inst in alive:
        counts[inst["gu_id"]] = counts.get(inst["gu_id"], 0) + 1
    return max(sorted(counts), key=lambda gid: (counts[gid], -len(gid)))
