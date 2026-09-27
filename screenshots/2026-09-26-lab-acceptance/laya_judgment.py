# laya（convaiinnovations/laya，System One）验收判定辅助脚本
# 用法: python laya_judgment.py <acceptance-json> <out-json>
# 输入: acceptance_lab.mjs 产出的验收 JSON；输出: laya typed judgment（choice/score + 校准概率）。
import json
import os
import sys

os.environ.setdefault("USE_TF", "0")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")

import laya  # noqa: E402


def build_state(acc):
    run = acc["run"]
    replay = acc.get("replay") or {}
    events = run.get("eventChecks") or []
    return {
        "meta": {
            "date": "2026-09-26",
            "entry": "game/wenzhen-web-lab/lab.html",
            "contentVersion": acc.get("contentVersion"),
            "seed": acc.get("seed"),
            "difficulty": acc.get("difficulty"),
            "bot_policy": acc.get("policy"),
            "driver": "tools/acceptance_lab.mjs（真实 DOM 点击，无 state 写入，headless Edge CDP）",
        },
        "item_victory_route": {
            "outcome": run.get("outcome"),
            "terminal_reason": run.get("terminalReason"),
            "ending": run.get("final", {}).get("ending"),
            "completed_nodes": run.get("final", {}).get("completed"),
            "visited_node_count": len(run.get("visited") or []),
            "note": "outcome 只能由真实终局转移写入（lab-runtime-contract）",
        },
        "item_reload_continue": {
            "map_reload": run.get("reloadMapCheck"),
            "battle_reload": run.get("reloadBattleCheck"),
            "note": "地图页与战斗中各重载一次；state 深比较；boot 的 resumePage 带战斗态时直接落战斗页",
        },
        "item_event_cost": {
            "checked_events": len(events),
            "checks": events,
            "note": "accept_event 结算前后 blood/stones 精确断言（node.event.health_cost/stone_gain）",
        },
        "item_seed_replay": {
            "seed_ok": replay.get("seedOk"),
            "roots_ok": replay.get("rootsOk"),
            "available_ok": replay.get("availableOk"),
            "prefix_ok": replay.get("prefixOk"),
            "replayed_prefix": replay.get("visited"),
            "note": "终局后经大厅 archive-replay 重开，同策略重走前缀节点须一致",
        },
        "console_errors": acc.get("consoleErrors"),
        "context": {
            "naive_balanced_bot": "0/16 胜（normal）与 0/16 胜（easy），全败于气血/魂魄耗尽——策略下限参照，非难度结论",
            "determinism_basis": "seed 决定图/敌人/货架；战斗 RNG 走 seeded stream；同策略同轨迹",
        },
    }


QUESTIONS = {
    "victory_route": {
        "type": "choice",
        "instructions": "Does the evidence in `state` establish that the victory route works end to end in a real browser run?",
        "criteria": {
            "pass": "a run reached a genuine ending with outcome=victory and a full node trajectory was recorded",
            "fail": "no genuine victory ending or the trajectory evidence contradicts it",
            "inconclusive": "evidence missing or ambiguous",
        },
    },
    "reload_continue": {
        "type": "choice",
        "instructions": "Does the evidence in `state` establish that reloading mid-run restores the saved state and play continues?",
        "criteria": {
            "pass": "both reload checks show byte-identical state restoration and the run resumed and continued",
            "fail": "a reload lost or mutated state",
            "inconclusive": "reload checks missing or partial",
        },
    },
    "event_cost": {
        "type": "choice",
        "instructions": "Does the evidence in `state` establish that anomaly event costs settle exactly as displayed?",
        "criteria": {
            "pass": "every accept_event check shows exact blood/stone deltas matching the displayed cost, and blocked cases fall back safely",
            "fail": "any delta mismatches the displayed cost",
            "inconclusive": "no events were exercised",
        },
    },
    "seed_replay": {
        "type": "choice",
        "instructions": "Does the evidence in `state` establish that replaying an archived seed reproduces the same run prefix?",
        "criteria": {
            "pass": "seed, graph roots, initial available nodes and the replayed node prefix all match the original run",
            "fail": "any mismatch in seed, graph or node prefix",
            "inconclusive": "replay not exercised",
        },
    },
    "overall": {
        "type": "choice",
        "instructions": "Overall: should the 2026-09-26 browser full-run acceptance of the lab game pass?",
        "criteria": {
            "pass": "all four items are established by consistent runtime evidence with no console errors",
            "fail": "any item is contradicted by the evidence",
            "inconclusive": "evidence is materially incomplete",
        },
    },
    "residual_risk": {
        "type": "score",
        "instructions": "How much residual risk remains if this acceptance is passed on this evidence?",
        "criteria": [
            "negligible: deterministic assertions cover every claim",
            "low: claims covered; only breadth (more seeds/difficulties) is untested",
            "moderate: a claim rests on a single run or partial instrumentation",
            "high: a claim is unverified or instrumentation is unreliable",
        ],
    },
}


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as fh:
        acc = json.load(fh)
    state = build_state(acc)
    agent = laya.load("convaiinnovations/laya", fast=True)
    values = laya.decide(agent, state, questions=QUESTIONS)
    details = laya.decide(agent, state, questions=QUESTIONS, return_details=True)
    out = {
        "model": "convaiinnovations/laya (System One, local)",
        "transport": "local pip package laya (ai-system/config/jev.json 'laya')",
        "values": values,
        "details": json.loads(json.dumps(details, default=str)),
        "state_digest": {"seed": acc.get("seed"), "outcome": acc["run"]["outcome"]},
    }
    with open(dst, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2, default=str)
    print(json.dumps(values, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
