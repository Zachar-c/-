"""Fallback and gate tests for the Jev System One task-tier adapter."""

from __future__ import annotations

import io
import json
import sys
import unittest
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ai-system"))

from jev_systemone import (  # noqa: E402
    JevClient,
    baseline_task_tier,
    build_choice_request,
    load_config,
    parse_systemone_response,
    propose_task_tier,
    request_url,
)


class FakeResponse:
    def __init__(self, body: bytes, status: int = 200) -> None:
        self._body = body
        self.status = status

    def read(self) -> bytes:
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class ScriptedOpener:
    def __init__(self, *, body: bytes | None = None, status: int = 200, exc: Exception | None = None) -> None:
        self.body = body
        self.status = status
        self.exc = exc
        self.calls = 0

    def __call__(self, req, timeout=None):
        self.calls += 1
        if self.exc is not None:
            raise self.exc
        return FakeResponse(self.body or b"{}", self.status)


def cfg_with(**over):
    cfg = load_config()
    cfg.update(over)
    return cfg


def official_choice_payload(choice: str, confidence: float, probs: dict[str, float] | None = None) -> dict:
    if probs is None:
        probs = {opt: 0.0 for opt in CHOICE_ALL}
        probs[choice] = 0.85
    return {
        "id": "gen-dec-test",
        "model": "typesafe/jev-1.13-20260917",
        "provider": "TypeSafe",
        "answers": {
            "task_tier": {
                "type": "choice",
                "choice": choice,
                "probabilities": probs,
                "confidence": confidence,
            }
        },
        "usage": {"input_tokens": 120, "output_tokens": 12, "cost": 0.00000504},
    }


CHOICE_ALL = ("cheap_worker", "standard_worker", "strong_worker", "gpt6_escalation")


class BaselineTests(unittest.TestCase):
    def test_escalate_markers(self):
        choice, _ = baseline_task_tier("RESEARCH REQUEST: multi-direction modeling; L1 must decide.")
        self.assertEqual(choice, "gpt6_escalation")

    def test_hard_markers(self):
        choice, _ = baseline_task_tier("Change architecture and save format across Godot core modules.")
        self.assertEqual(choice, "strong_worker")

    def test_negated_architecture_is_not_hard(self):
        choice, _ = baseline_task_tier(
            "Side-fix enemy runtime bug with focused unit tests. Normal worker execution, no architecture change."
        )
        self.assertEqual(choice, "standard_worker")

    def test_l1_already_decided_is_not_escalate(self):
        choice, _ = baseline_task_tier(
            "Wire runtime HP source to documented economy.json values already decided by L1. Mechanical code wiring plus tests."
        )
        self.assertEqual(choice, "standard_worker")

    def test_cheap_markers(self):
        choice, _ = baseline_task_tier("Docs only: rename marker in a decision register. No logic change.")
        self.assertEqual(choice, "cheap_worker")

    def test_default_standard(self):
        choice, _ = baseline_task_tier("Fix a focused runtime bug and add one regression test.")
        self.assertEqual(choice, "standard_worker")


class SchemaTests(unittest.TestCase):
    def test_request_url_is_local_laya_by_default(self):
        cfg = cfg_with()
        self.assertEqual(request_url(cfg), "laya://local")

    def test_scores_to_probabilities_and_confidence(self):
        from jev_systemone import choice_confidence, scores_to_probabilities

        probs = scores_to_probabilities({
            "cheap_worker": 10, "standard_worker": 80,
            "strong_worker": 20, "gpt6_escalation": 5,
        })
        self.assertAlmostEqual(sum(probs.values()), 1.0, places=5)
        self.assertGreater(probs["standard_worker"], 0.5)
        conf = choice_confidence(probs)
        self.assertGreaterEqual(conf, 0.0)
        self.assertLessEqual(conf, 1.0)

    def test_ollama_payload_normalized(self):
        from jev_systemone import OllamaClient

        def opener(req, timeout=None):
            body = json.dumps({
                "model": "gemma2:2b",
                "message": {"content": json.dumps({
                    "choice": "standard_worker",
                    "scores": {"cheap_worker": 5, "standard_worker": 90, "strong_worker": 10, "gpt6_escalation": 2},
                })},
                "prompt_eval_count": 120,
            }).encode()
            return FakeResponse(body)

        cfg = cfg_with(transport="ollama")
        client = OllamaClient(cfg, opener=opener)
        payload, status, err = client.systemone_choice("Fix a focused bug.")
        self.assertIsNone(err)
        ans = payload["answers"]["task_tier"]
        self.assertEqual(ans["choice"], "standard_worker")
        self.assertIsNotNone(ans["confidence"])
        self.assertEqual(payload["usage"]["input_tokens"], 120)

    def test_build_choice_request_matches_official(self):
        cfg = cfg_with(model="gemma2:2b", questionId="task_tier")
        body = build_choice_request("hello state", cfg)
        self.assertEqual(body["state"], "hello state")
        self.assertIn("model", body)
        q = body["questions"]["task_tier"]
        self.assertEqual(q["type"], "choice")
        self.assertIn("instructions", q)
        self.assertIn("criteria", q)
        self.assertEqual(set(q["criteria"]), set(CHOICE_ALL))

    def test_parse_official_choice_answer(self):
        payload = official_choice_payload("strong_worker", 0.81, {
            "cheap_worker": 0.0, "standard_worker": 0.15,
            "strong_worker": 0.85, "gpt6_escalation": 0.0,
        })
        choice, prob, conf, probs, tin, tout, cost = parse_systemone_response(payload, "task_tier")
        self.assertEqual(choice, "strong_worker")
        self.assertAlmostEqual(prob or 0, 0.85)
        self.assertAlmostEqual(conf or 0, 0.81)
        self.assertIsNotNone(probs)
        self.assertEqual(tin, 120)
        self.assertEqual(tout, 12)
        self.assertAlmostEqual(cost or 0, 0.00000504)

    def test_parse_rejects_unknown_choice(self):
        payload = official_choice_payload("not_an_option", 0.9)
        choice, _p, conf, _pr, _ti, _to, _c = parse_systemone_response(payload, "task_tier")
        self.assertIsNone(choice)
        self.assertAlmostEqual(conf or 0, 0.9)

    def test_parse_empty_answers(self):
        self.assertEqual(parse_systemone_response({"model": "typesafe/jev-1.13"}, "task_tier")[0], None)


class FallbackTests(unittest.TestCase):
    def test_missing_key_falls_back(self):
        cfg = cfg_with(mode="live")
        client = JevClient(cfg, api_key="")
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.gate, "FALLBACK")
        self.assertEqual(rec.final_action, "use_normal_chain")
        self.assertEqual(rec.worker_class, "normal")

    def test_timeout_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=TimeoutError("timed out"))
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertIn("network", rec.fallback_reason or "")

    def test_http_401_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=urllib.error.HTTPError(
            "https://x", 401, "unauthorized", {}, io.BytesIO(b'{"error":{"code":401}}')
        ))
        client = JevClient(cfg, api_key="bad", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.http_status, 401)

    def test_http_402_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=urllib.error.HTTPError(
            "https://x", 402, "Payment Required", {}, io.BytesIO(b"no credits")
        ))
        client = JevClient(cfg, api_key="k", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.http_status, 402)

    def test_http_429_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=urllib.error.HTTPError(
            "https://x", 429, "Too Many", {}, io.BytesIO(b"slow down")
        ))
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertIn("http_429", rec.fallback_reason or "")

    def test_http_529_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=urllib.error.HTTPError(
            "https://x", 529, "Overloaded", {}, io.BytesIO(b"busy")
        ))
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertIn("http_529", rec.fallback_reason or "")

    def test_http_500_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(exc=urllib.error.HTTPError(
            "https://x", 500, "boom", {}, io.BytesIO(b"err")
        ))
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.http_status, 500)

    def test_invalid_json_falls_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(body=b"not-json")
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertTrue((rec.fallback_reason or "").startswith("invalid_json:"))

    def test_invalid_response_fields_fall_back(self):
        cfg = cfg_with(mode="live")
        opener = ScriptedOpener(body=json.dumps({"model": "typesafe/jev-1.13", "answers": {}}).encode())
        client = JevClient(cfg, api_key="test-key", opener=opener)
        rec = propose_task_tier("Fix a focused bug.", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.fallback_reason, "invalid_response")

    def test_off_mode_uses_baseline(self):
        cfg = cfg_with(mode="off")
        rec = propose_task_tier("RESEARCH REQUEST to L1", cfg=cfg, mode_override="off")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.gate, "OFF")
        self.assertEqual(rec.worker_class, "escalate")


class GateTests(unittest.TestCase):
    def test_high_confidence_auto_applies(self):
        cfg = cfg_with(mode="live", thresholds={"highConfidence": 0.8, "mediumConfidence": 0.55})
        opener = ScriptedOpener(body=json.dumps(official_choice_payload("strong_worker", 0.9)).encode())
        client = JevClient(cfg, api_key="k", opener=opener)
        rec = propose_task_tier("ambiguous task", cfg=cfg, client=client, mode_override="live")
        self.assertFalse(rec.fallback_used)
        self.assertEqual(rec.gate, "HIGH")
        self.assertEqual(rec.worker_class, "hard")
        self.assertEqual(rec.final_action, "use_hard_chain")
        self.assertEqual(rec.input_tokens_api, 120)
        self.assertEqual(rec.model, "typesafe/jev-1.13-20260917")
        self.assertAlmostEqual(rec.cost_usd or 0, 0.00000504)

    def test_medium_confidence_uses_existing_rules(self):
        cfg = cfg_with(mode="live", thresholds={"highConfidence": 0.8, "mediumConfidence": 0.55})
        opener = ScriptedOpener(body=json.dumps(official_choice_payload("cheap_worker", 0.6)).encode())
        client = JevClient(cfg, api_key="k", opener=opener)
        rec = propose_task_tier(
            "architecture and save format change", cfg=cfg, client=client, mode_override="live"
        )
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.gate, "MEDIUM")
        self.assertEqual(rec.worker_class, "hard")
        self.assertEqual(rec.selected_choice, "cheap_worker")

    def test_low_confidence_escalates(self):
        cfg = cfg_with(mode="live", thresholds={"highConfidence": 0.8, "mediumConfidence": 0.55})
        opener = ScriptedOpener(body=json.dumps(official_choice_payload("standard_worker", 0.2)).encode())
        client = JevClient(cfg, api_key="k", opener=opener)
        rec = propose_task_tier("ambiguous task", cfg=cfg, client=client, mode_override="live")
        self.assertTrue(rec.fallback_used)
        self.assertEqual(rec.gate, "LOW")
        self.assertEqual(rec.final_action, "escalate_to_system2")

    def test_fixture_mode_end_to_end(self):
        cfg = cfg_with(mode="fixture")
        rec = propose_task_tier("RESEARCH REQUEST multi-direction modeling", cfg=cfg, mode_override="fixture")
        self.assertEqual(rec.mode, "fixture")
        self.assertEqual(rec.selected_choice, "gpt6_escalation")
        self.assertEqual(rec.worker_class, "escalate")

    def test_request_body_has_no_api_key_field(self):
        cfg = cfg_with(transport="openrouter")
        captured = {}

        def capture(req, timeout=None):
            auth = None
            if hasattr(req, "header_items"):
                headers = dict(req.header_items())
                auth = headers.get("Authorization") or headers.get("authorization")
            else:
                auth = req.headers.get("Authorization") or req.headers.get("authorization")
            captured["auth"] = auth
            captured["data"] = req.data.decode("utf-8")
            captured["url"] = req.full_url
            return FakeResponse(json.dumps(official_choice_payload("standard_worker", 0.9)).encode())

        client = JevClient(cfg, api_key="super-secret", opener=capture)
        client.systemone_choice("hello")
        self.assertIn("super-secret", captured["auth"] or "")
        self.assertEqual(captured["url"], "https://openrouter.ai/api/alpha/decisions")
        body = json.loads(captured["data"])
        self.assertEqual(body["model"], "typesafe/jev-1.13")
        self.assertIn("questions", body)
        self.assertNotIn("api_key", body)
        self.assertNotIn("super-secret", captured["data"])


if __name__ == "__main__":
    unittest.main()
