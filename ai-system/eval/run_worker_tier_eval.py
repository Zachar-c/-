"""Minimal eval: baseline static rules vs Jev System One on worker_task_tier cases."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ai-system"))

from jev_systemone import (  # noqa: E402
    DecisionRecord,
    baseline_task_tier,
    load_config,
    propose_task_tier,
)

CASES_PATH = Path(__file__).resolve().parent / "worker_tier_cases.json"

WORKER_LABELS = {"cheap_worker", "standard_worker", "strong_worker"}

# Collapsed to the existing choose-worker-model surface: normal | hard | escalate.
COLLAPSE = {
    "cheap_worker": "normal",
    "standard_worker": "normal",
    "strong_worker": "hard",
    "gpt6_escalation": "escalate",
}


def collapse(label: str) -> str:
    return COLLAPSE.get(label, "escalate")


def load_cases() -> list[dict]:
    return json.loads(CASES_PATH.read_text(encoding="utf-8"))["cases"]


def predict_baseline(state: str, cfg: dict) -> str:
    choice, _ = baseline_task_tier(state)
    return choice


def predict_jev(state: str, cfg: dict, mode: str) -> DecisionRecord:
    return propose_task_tier(state, cfg=cfg, mode_override=mode)


def metrics(preds: list[str], golds: list[str]) -> dict:
    n = len(golds)
    correct = sum(p == g for p, g in zip(preds, golds))
    # false escalation: predicted escalate when gold is a worker tier
    false_esc = sum(p == "gpt6_escalation" and g in WORKER_LABELS for p, g in zip(preds, golds))
    # false cheap: predicted cheap/standard when gold is strong or escalate
    false_cheap = sum(
        p in {"cheap_worker", "standard_worker"} and g in {"strong_worker", "gpt6_escalation"}
        for p, g in zip(preds, golds)
    )
    collapsed_preds = [collapse(p) for p in preds]
    collapsed_golds = [collapse(g) for g in golds]
    collapsed_correct = sum(p == g for p, g in zip(collapsed_preds, collapsed_golds))
    collapsed_false_esc = sum(p == "escalate" and g == "normal" for p, g in zip(collapsed_preds, collapsed_golds))
    collapsed_false_cheap = sum(p == "normal" and g in {"hard", "escalate"} for p, g in zip(collapsed_preds, collapsed_golds))
    return {
        "n": n,
        "accuracy": round(correct / n, 4) if n else 0.0,
        "false_escalation": false_esc,
        "false_cheap_routing": false_cheap,
        "correct": correct,
        "collapsed_to_worker_class": {
            "accuracy": round(collapsed_correct / n, 4) if n else 0.0,
            "false_escalation": collapsed_false_esc,
            "false_cheap_routing": collapsed_false_cheap,
            "correct": collapsed_correct,
        },
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["auto", "live", "fixture", "off"], default="auto")
    parser.add_argument("--config", default=None)
    args = parser.parse_args(argv)

    cfg = load_config(Path(args.config)) if args.config else load_config()
    cases = load_cases()
    golds = [c["gold"] for c in cases]
    states = [c["state"] for c in cases]

    base_preds = [predict_baseline(s, cfg) for s in states]
    base_metrics = metrics(base_preds, golds)

    latencies: list[int] = []
    jev_preds: list[str] = []
    fallbacks = 0
    cost_units = 0
    api_tokens = 0
    for s in states:
        rec = predict_jev(s, cfg, args.mode)
        latencies.append(rec.latency_ms)
        fallbacks += int(rec.fallback_used)
        cost_units += rec.input_token_estimate
        if rec.input_tokens_api:
            api_tokens += rec.input_tokens_api
        jev_preds.append(rec.selected_choice or "gpt6_escalation")

    jev_metrics = metrics(jev_preds, golds)
    avg_latency = int(sum(latencies) / len(latencies)) if latencies else 0

    report = {
        "decision_type": cfg.get("decisionType", "worker_task_tier"),
        "mode": args.mode,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "cases": len(cases),
        "baseline_existing_routing": base_metrics,
        "jev_routing": jev_metrics,
        "latency_ms_avg": avg_latency,
        "fallback_used_count": fallbacks,
        "input_token_estimate_total": cost_units,
        "input_tokens_api_total": api_tokens,
        "estimated_cost_usd_at_list_price": round(api_tokens / 1_000_000 * 0.042, 8) if api_tokens else None,
        "estimated_cost_note": "List price $0.042/MTok input (OpenRouter typesafe/jev-1.13); output free. Prefer usage.cost from API when live.",
        "api_verification": cfg.get("apiVerification", {}).get("status"),
        "mismatch_ids": [
            {"id": c["id"], "gold": g, "baseline": b, "jev": j}
            for c, g, b, j in zip(cases, golds, base_preds, jev_preds)
            if b != g or j != g
        ],
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
