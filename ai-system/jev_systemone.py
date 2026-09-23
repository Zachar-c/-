"""Jev System One adapter: task-tier proposal only (System One decision layer).

Scope is intentionally narrow. This module does not write code, pick game rules,
replace Codex/OpenCode, or own final authority. It returns a decision proposal
plus probability/confidence and always leaves a deterministic fallback path.

Transports:
  ollama (default, free local): POST http://127.0.0.1:11434/api/chat  model gemma2:2b
  openrouter: POST https://openrouter.ai/api/alpha/decisions  model typesafe/jev-1.13
  fixture: offline deterministic stand-in
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = REPO_ROOT / "ai-system" / "config" / "jev.json"

CHOICE_OPTIONS = (
    "cheap_worker",
    "standard_worker",
    "strong_worker",
    "gpt6_escalation",
)

DEFAULT_CRITERIA = {
    "cheap_worker": "Docs, census, typo, or marker-only edits. No logic change.",
    "standard_worker": (
        "Bounded code fix, focused regression test, or wiki distillation. "
        "Documented Worker class normal. No product or architecture decision."
    ),
    "strong_worker": (
        "Godot core lifecycle, multi-module architecture, save format, schema, "
        "or balance-formula change. Worker class hard."
    ),
    "gpt6_escalation": (
        "Product intent, major tradeoff, or multi-direction modeling that needs "
        "L1/L0 research before any worker task."
    ),
}


@dataclass
class DecisionRecord:
    decision_type: str
    selected_choice: str | None
    score: float | None
    probability: float | None
    confidence: float | None
    latency_ms: int
    input_token_estimate: int
    input_tokens_api: int | None
    output_tokens_api: int | None
    cost_usd: float | None
    fallback_used: bool
    final_action: str
    worker_class: str
    gate: str
    fallback_reason: str | None
    later_outcome: str | None
    state_hash: str
    mode: str
    transport: str
    model: str | None = None
    http_status: int | None = None
    error: str | None = None
    extras: dict[str, Any] = field(default_factory=dict)


def load_config(path: Path | None = None) -> dict[str, Any]:
    cfg_path = path or DEFAULT_CONFIG
    return json.loads(cfg_path.read_text(encoding="utf-8"))


def estimate_tokens(text: str) -> int:
    return max(1, len(text) // 4)


def hash_state(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def resolve_api_key(cfg: dict[str, Any]) -> str | None:
    names = [str(cfg.get("apiKeyEnv", "OPENROUTER_API_KEY"))]
    names.extend(str(x) for x in cfg.get("apiKeyEnvFallbacks") or [])
    names.extend(["OPENROUTER_API_KEY", "JEV_API_KEY", "TYPESAFE_API_KEY"])
    seen: set[str] = set()
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        val = os.environ.get(name)
        if val:
            return val
    return None


def baseline_task_tier(state: str) -> tuple[str, str]:
    """Deterministic stand-in for current Codex / static practice."""
    s = state.lower()
    for phrase in (
        "no architecture change",
        "no code architecture",
        "no architecture",
        "without architecture",
        "no logic change",
        "not architecture",
        "not a schema change",
        "no balance change",
        "no new numeric model",
    ):
        s = s.replace(phrase, " ")
    escalate_markers = (
        "research request",
        "research-request",
        "product direction",
        "产品意图",
        "重大取舍",
        "上抛",
        "cannot decide",
        "无法仅靠仓库事实",
        "多方向建模",
        "l1 must",
        "l1 research",
        "needs l1",
        "需要 l1",
        "l1 ruling",
        "to l1",
    )
    hard_markers = (
        "architecture",
        "架构",
        "core gameplay",
        "核心玩法",
        "godot core",
        "balance formula",
        "effect budget",
        "rank power budget",
        "multi-module",
        "save format",
        "schema change",
        "跨模块",
    )
    cheap_markers = (
        "docs only",
        "markdown only",
        "typo",
        "rename marker",
        "纯文档",
        "只读普查",
        "census only",
        "label update",
        "documentation edit",
        "docs-only",
    )
    if any(m in s for m in escalate_markers):
        return "gpt6_escalation", "baseline_escalate_markers"
    if any(m in s for m in hard_markers):
        return "strong_worker", "baseline_hard_markers"
    if any(m in s for m in cheap_markers):
        return "cheap_worker", "baseline_cheap_markers"
    return "standard_worker", "baseline_default"


def map_choice(choice: str, cfg: dict[str, Any]) -> tuple[str, str]:
    mapped_class = cfg.get("mapToWorkerClass", {}).get(choice, "normal")
    mapped_action = cfg.get("mapToFinalAction", {}).get(choice, "use_normal_chain")
    return str(mapped_class), str(mapped_action)


def _clamp01(value: Any) -> float | None:
    try:
        x = float(value)
    except (TypeError, ValueError):
        return None
    if x > 1.0 and x <= 100.0:
        x = x / 100.0
    if x < 0.0:
        return 0.0
    if x > 1.0:
        return 1.0
    return x


def build_choice_request(state: str, cfg: dict[str, Any]) -> dict[str, Any]:
    """OpenRouter Decisions / TypeSafe System One body: state + model + questions map."""
    criteria = cfg.get("criteria") or DEFAULT_CRITERIA
    question_id = str(cfg.get("questionId", "task_tier"))
    or_cfg = cfg.get("openrouter") or {}
    return {
        "model": or_cfg.get("model") or cfg.get("model", "typesafe/jev-1.13"),
        "state": state,
        "questions": {
            question_id: {
                "type": "choice",
                "instructions": cfg.get(
                    "instructions",
                    "Which execution tier should handle this task?",
                ),
                "criteria": {k: criteria.get(k) for k in CHOICE_OPTIONS},
            }
        },
    }


def parse_systemone_response(
    payload: dict[str, Any], question_id: str = "task_tier"
) -> tuple[str | None, float | None, float | None, dict[str, float] | None, int | None, int | None, float | None]:
    """Parse Choice answer under answers[question_id] plus usage."""
    answers = payload.get("answers")
    if not isinstance(answers, dict):
        return None, None, None, None, None, None, None
    data = answers.get(question_id)
    if not isinstance(data, dict):
        if len(answers) == 1:
            only = next(iter(answers.values()))
            data = only if isinstance(only, dict) else None
        if not isinstance(data, dict):
            return None, None, None, None, None, None, None

    choice = data.get("choice")
    if choice is not None:
        choice = str(choice)
        if choice not in CHOICE_OPTIONS:
            choice = None

    probs_raw = data.get("probabilities")
    probabilities: dict[str, float] | None = None
    top_prob: float | None = None
    if isinstance(probs_raw, dict):
        probabilities = {}
        for k, v in probs_raw.items():
            pv = _clamp01(v)
            if pv is not None:
                probabilities[str(k)] = pv
        if probabilities:
            top_prob = max(probabilities.values())

    confidence = _clamp01(data.get("confidence"))
    if confidence is None:
        confidence = top_prob

    usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
    try:
        input_tokens = int(usage.get("input_tokens")) if usage.get("input_tokens") is not None else None
    except (TypeError, ValueError):
        input_tokens = None
    try:
        output_tokens = int(usage.get("output_tokens")) if usage.get("output_tokens") is not None else None
    except (TypeError, ValueError):
        output_tokens = None
    try:
        cost = float(usage.get("cost")) if usage.get("cost") is not None else None
    except (TypeError, ValueError):
        cost = None

    return choice, top_prob, confidence, probabilities, input_tokens, output_tokens, cost


def scores_to_probabilities(scores: dict[str, float]) -> dict[str, float]:
    """Softmax over raw 0-100 scores so the distribution sums to 1."""
    vals = {k: max(0.0, float(v)) for k, v in scores.items() if k in CHOICE_OPTIONS}
    if not vals:
        return {}
    mx = max(vals.values())
    exps = {k: pow(2.718281828, (v - mx) / 25.0) for k, v in vals.items()}
    total = sum(exps.values()) or 1.0
    return {k: exps[k] / total for k in exps}


def choice_confidence(probabilities: dict[str, float]) -> float:
    """TypeSafe-style confidence: (n * peak - 1) / (n - 1), clamped to [0, 1]."""
    n = len(CHOICE_OPTIONS)
    if n <= 1:
        return 1.0
    peak = max((probabilities.get(k, 0.0) for k in CHOICE_OPTIONS), default=0.0)
    conf = (n * peak - 1.0) / (n - 1.0)
    return max(0.0, min(1.0, conf))


def request_url(cfg: dict[str, Any]) -> str:
    transport = str(cfg.get("transport", "laya"))
    if transport == "laya":
        return "laya://local"
    if transport == "ollama":
        oll = cfg.get("ollama") or {}
        base = str(oll.get("host") or cfg.get("baseUrl") or "http://127.0.0.1:11434").rstrip("/")
        path = str(cfg.get("path") or "/api/chat")
    else:
        or_cfg = cfg.get("openrouter") or {}
        base = str(or_cfg.get("baseUrl") or cfg.get("baseUrl") or "https://openrouter.ai").rstrip("/")
        path = str(or_cfg.get("path") or cfg.get("path") or "/api/alpha/decisions")
    if not path.startswith("/"):
        path = "/" + path
    return base + path


class LayaClient:
    """Local Laya System One client (open-source Jev alternative, Apache-2.0).

    Uses convaiinnovations/laya — non-autoregressive typed decisions with
    calibrated probabilities in one encoder pass.
    """

    _agent: Any = None

    def __init__(self, cfg: dict[str, Any], opener: Any | None = None) -> None:
        self.cfg = cfg
        self._urlopen = opener  # unused; kept for test symmetry
        self.timeout_s = max(0.2, float(cfg.get("timeoutMs", 2500)) / 1000.0)

    def available(self) -> bool:
        try:
            import laya  # noqa: F401

            return True
        except Exception:
            return False

    def _get_agent(self) -> Any:
        if LayaClient._agent is None:
            import os

            os.environ.setdefault("USE_TF", "0")
            import laya

            repo = str((self.cfg.get("laya") or {}).get("repo") or "convaiinnovations/laya")
            LayaClient._agent = laya.load(repo)
        return LayaClient._agent

    def build_questions(self) -> dict[str, Any]:
        criteria = self.cfg.get("criteria") or DEFAULT_CRITERIA
        question_id = str(self.cfg.get("questionId", "task_tier"))
        return {
            question_id: {
                "type": "choice",
                "instructions": self.cfg.get(
                    "instructions",
                    "Which execution tier should handle this task?",
                ),
                "criteria": {k: criteria.get(k) for k in CHOICE_OPTIONS},
            }
        }

    def systemone_choice(self, state: str) -> tuple[dict[str, Any] | None, int | None, str | None]:
        try:
            agent = self._get_agent()
            questions = self.build_questions()
            raw = agent.predict(state, questions)
        except Exception as exc:
            return None, None, f"laya:{type(exc).__name__}:{exc}"
        if not isinstance(raw, dict):
            return None, None, "laya:invalid_response"
        answers = raw.get("answers") if isinstance(raw.get("answers"), dict) else raw
        question_id = str(self.cfg.get("questionId", "task_tier"))
        data = (answers or {}).get(question_id) if isinstance(answers, dict) else None
        if not isinstance(data, dict) and isinstance(answers, dict) and len(answers) == 1:
            only = next(iter(answers.values()))
            data = only if isinstance(only, dict) else None
        if not isinstance(data, dict):
            return None, None, "laya:missing_answer"
        probs_raw = data.get("probabilities") or data.get("probs")
        probabilities = None
        if isinstance(probs_raw, dict):
            probabilities = {str(k): _clamp01(v) or 0.0 for k, v in probs_raw.items() if str(k) in CHOICE_OPTIONS}
        choice = data.get("choice") or data.get("label")
        if isinstance(choice, str) and choice not in CHOICE_OPTIONS:
            choice = None
        conf = _clamp01(data.get("confidence"))
        if conf is None and probabilities:
            conf = choice_confidence(probabilities)
        top = max(probabilities.values()) if probabilities else None
        model = raw.get("model") or raw.get("routing", {}).get("model") if isinstance(raw.get("routing"), dict) else raw.get("model")
        normalized = {
            "model": model if isinstance(model, str) else "convaiinnovations/laya",
            "answers": {
                question_id: {
                    "type": "choice",
                    "choice": choice,
                    "probabilities": probabilities or {},
                    "confidence": conf,
                }
            },
            "usage": {"input_tokens": estimate_tokens(state), "output_tokens": 0, "cost": 0.0},
        }
        return normalized, 200, None


class JevClient:
    """OpenRouter Decisions client (paid)."""

    def __init__(self, cfg: dict[str, Any], api_key: str | None = None, opener: Any | None = None) -> None:
        self.cfg = cfg
        or_cfg = cfg.get("openrouter") or {}
        self.api_key = api_key if api_key is not None else resolve_api_key({**cfg, "apiKeyEnv": or_cfg.get("apiKeyEnv", cfg.get("apiKeyEnv", "OPENROUTER_API_KEY"))})
        self.timeout_s = max(0.2, float(cfg.get("timeoutMs", 2500)) / 1000.0)
        self._urlopen = opener or urllib.request.urlopen

    def available(self) -> bool:
        return bool(self.api_key)

    def systemone_choice(self, state: str) -> tuple[dict[str, Any] | None, int | None, str | None]:
        if not self.api_key:
            return None, None, "missing_api_key"
        body = json.dumps(build_choice_request(state, self.cfg)).encode("utf-8")
        req = urllib.request.Request(
            request_url(self.cfg),
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with self._urlopen(req, timeout=self.timeout_s) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                status = int(getattr(resp, "status", 200) or 200)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:200]
            code = int(exc.code)
            if code in (402, 429, 502, 503, 524, 529):
                return None, code, f"http_{code}:transient:{detail}"
            return None, code, f"http_{code}:{detail}"
        except Exception as exc:
            return None, None, f"network:{type(exc).__name__}:{exc}"
        try:
            return json.loads(raw), status, None
        except json.JSONDecodeError as exc:
            return None, status, f"invalid_json:{exc}"


class OllamaClient:
    """Local Ollama chat client — free System One substitute via structured JSON."""

    def __init__(self, cfg: dict[str, Any], opener: Any | None = None) -> None:
        self.cfg = cfg
        self.timeout_s = max(0.2, float(cfg.get("timeoutMs", 2500)) / 1000.0)
        # Local generation can be slower than remote System One.
        self.timeout_s = max(self.timeout_s, 20.0)
        self._urlopen = opener or urllib.request.urlopen

    def available(self) -> bool:
        try:
            req = urllib.request.Request(request_url(self.cfg).rsplit("/", 1)[0] + "/api/tags", method="GET")
            with self._urlopen(req, timeout=1.0) as resp:
                return int(getattr(resp, "status", 200) or 200) == 200
        except Exception:
            return False

    def build_prompt(self, state: str) -> str:
        criteria = self.cfg.get("criteria") or DEFAULT_CRITERIA
        lines = [
            "You are a System One decision model. Choose exactly one execution tier.",
            "Return ONLY JSON: {\"choice\": \"<one option>\", \"scores\": {\"<option>\": 0-100, ...}}",
            "Options and criteria:",
        ]
        for opt in CHOICE_OPTIONS:
            lines.append(f"- {opt}: {criteria.get(opt, '')}")
        lines.append("Task brief:")
        lines.append(state)
        return "\n".join(lines)

    def systemone_choice(self, state: str) -> tuple[dict[str, Any] | None, int | None, str | None]:
        oll = self.cfg.get("ollama") or {}
        body = {
            "model": oll.get("model") or self.cfg.get("model") or "gemma2:2b",
            "stream": False,
            "format": oll.get("format", "json"),
            "options": {"temperature": float(oll.get("temperature", 0))},
            "messages": [{"role": "user", "content": self.build_prompt(state)}],
        }
        req = urllib.request.Request(
            request_url(self.cfg),
            data=json.dumps(body).encode("utf-8"),
            method="POST",
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        try:
            with self._urlopen(req, timeout=self.timeout_s) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                status = int(getattr(resp, "status", 200) or 200)
        except Exception as exc:
            return None, None, f"network:{type(exc).__name__}:{exc}"
        try:
            outer = json.loads(raw)
        except json.JSONDecodeError as exc:
            return None, status, f"invalid_json:{exc}"
        content = ""
        if isinstance(outer, dict):
            msg = outer.get("message") or {}
            if isinstance(msg, dict):
                content = str(msg.get("content") or "")
            if not content and isinstance(outer.get("response"), str):
                content = outer["response"]
        try:
            inner = json.loads(content) if content.strip().startswith("{") else {"choice": content.strip()}
        except json.JSONDecodeError:
            inner = {"choice": content.strip()[:64]}
        # Normalize to DecisionsResponse-like shape.
        scores = inner.get("scores") if isinstance(inner.get("scores"), dict) else {}
        probs = scores_to_probabilities(scores) if scores else None
        choice = inner.get("choice") or inner.get("selected") or (max(probs, key=probs.get) if probs else None)
        conf = _clamp01(inner.get("confidence"))
        if conf is None and probs:
            conf = choice_confidence(probs)
        usage = outer.get("prompt_eval_count") if isinstance(outer, dict) else None
        try:
            usage_i = int(usage) if usage is not None else None
        except (TypeError, ValueError):
            usage_i = None
        normalized = {
            "model": (outer or {}).get("model") if isinstance(outer, dict) else None,
            "answers": {
                str(self.cfg.get("questionId", "task_tier")): {
                    "type": "choice",
                    "choice": choice,
                    "probabilities": probs or {},
                    "confidence": conf,
                }
            },
            "usage": {"input_tokens": usage_i, "output_tokens": 0, "cost": 0.0},
        }
        return normalized, status, None


def _fixture_response(state: str, cfg: dict[str, Any]) -> dict[str, Any]:
    choice, _reason = baseline_task_tier(state)
    question_id = str(cfg.get("questionId", "task_tier"))
    probs = {opt: 0.0 for opt in CHOICE_OPTIONS}
    probs[choice] = 0.9
    for opt in CHOICE_OPTIONS:
        if opt != choice:
            probs[opt] = 0.1 / (len(CHOICE_OPTIONS) - 1)
    tokens = estimate_tokens(state)
    return {
        "model": "gemma2-fixture",
        "provider": "fixture",
        "answers": {
            question_id: {
                "type": "choice",
                "choice": choice,
                "probabilities": probs,
                "confidence": 0.88,
            }
        },
        "usage": {
            "input_tokens": tokens,
            "output_tokens": 8,
            "cost": round(tokens / 1_000_000 * 0.042, 8),
        },
    }


def propose_task_tier(
    state: str,
    cfg: dict[str, Any] | None = None,
    client: JevClient | None = None,
    mode_override: str | None = None,
) -> DecisionRecord:
    cfg = cfg or load_config()
    mode = mode_override or str(cfg.get("mode", "auto"))
    transport = str(cfg.get("transport", "laya"))
    thresholds = cfg.get("thresholds") or {}
    high = float(thresholds.get("highConfidence", 0.8))
    medium = float(thresholds.get("mediumConfidence", 0.55))
    decision_type = str(cfg.get("decisionType", "worker_task_tier"))
    question_id = str(cfg.get("questionId", "task_tier"))
    token_estimate = estimate_tokens(state)
    state_digest = hash_state(state)
    started = time.perf_counter()

    base_choice, _base_reason = baseline_task_tier(state)
    base_class, base_action = map_choice(base_choice, cfg)

    def _fallback(
        reason: str,
        *,
        choice: str | None = None,
        http_status: int | None = None,
        error: str | None = None,
        probability: float | None = None,
        confidence: float | None = None,
        input_tokens_api: int | None = None,
        output_tokens_api: int | None = None,
        cost_usd: float | None = None,
        gate: str = "FALLBACK",
        final_action: str | None = None,
        worker_class: str | None = None,
    ) -> DecisionRecord:
        elapsed = int((time.perf_counter() - started) * 1000)
        return DecisionRecord(
            decision_type=decision_type,
            selected_choice=choice if choice is not None else base_choice,
            score=None,
            probability=probability,
            confidence=confidence,
            latency_ms=elapsed,
            input_token_estimate=token_estimate,
            input_tokens_api=input_tokens_api,
            output_tokens_api=output_tokens_api,
            cost_usd=cost_usd,
            fallback_used=True,
            final_action=final_action or base_action,
            worker_class=worker_class or base_class,
            gate=gate,
            fallback_reason=reason,
            later_outcome=None,
            state_hash=state_digest,
            mode=mode,
            transport=transport,
            http_status=http_status,
            error=error,
        )

    if mode == "off" or not cfg.get("enabled", True):
        return _fallback("disabled_or_off", gate="OFF")

    payload: dict[str, Any] | None = None
    http_status: int | None = None
    error: str | None = None
    transport = str(cfg.get("transport", "laya"))

    if mode == "fixture":
        payload = _fixture_response(state, cfg)
    elif isinstance(client, LayaClient):
        payload, http_status, error = client.systemone_choice(state)
    elif isinstance(client, OllamaClient):
        payload, http_status, error = client.systemone_choice(state)
    elif isinstance(client, JevClient):
        if not client.available():
            error = "missing_api_key"
        else:
            payload, http_status, error = client.systemone_choice(state)
    elif transport == "laya":
        payload, http_status, error = LayaClient(cfg).systemone_choice(state)
    elif transport == "ollama":
        payload, http_status, error = OllamaClient(cfg).systemone_choice(state)
    else:
        jev = JevClient(cfg)
        if not jev.available():
            error = "missing_api_key"
        else:
            payload, http_status, error = jev.systemone_choice(state)

    if payload is None:
        return _fallback(error or "unavailable", http_status=http_status, error=error)

    (
        choice,
        probability,
        confidence,
        _probs,
        input_tokens_api,
        output_tokens_api,
        cost_usd,
    ) = parse_systemone_response(payload, question_id)
    model = payload.get("model") if isinstance(payload.get("model"), str) else None
    latency_ms = int((time.perf_counter() - started) * 1000)

    if choice is None or confidence is None:
        return _fallback(
            "invalid_response",
            choice=None,
            http_status=http_status,
            error="invalid_response",
            probability=probability,
            confidence=confidence,
            input_tokens_api=input_tokens_api,
            output_tokens_api=output_tokens_api,
            cost_usd=cost_usd,
        )

    if confidence >= high:
        worker_class, final_action = map_choice(choice, cfg)
        return DecisionRecord(
            decision_type=decision_type,
            selected_choice=choice,
            score=None,
            probability=probability,
            confidence=confidence,
            latency_ms=latency_ms,
            input_token_estimate=token_estimate,
            input_tokens_api=input_tokens_api,
            output_tokens_api=output_tokens_api,
            cost_usd=cost_usd,
            fallback_used=False,
            final_action=final_action,
            worker_class=worker_class,
            gate="HIGH",
            fallback_reason=None,
            later_outcome=None,
            state_hash=state_digest,
            mode=mode,
            transport=transport,
            model=model,
            http_status=http_status,
        )

    if confidence >= medium:
        return _fallback(
            "medium_confidence_use_existing_rules",
            choice=choice,
            http_status=http_status,
            probability=probability,
            confidence=confidence,
            input_tokens_api=input_tokens_api,
            output_tokens_api=output_tokens_api,
            cost_usd=cost_usd,
            gate="MEDIUM",
        )

    return _fallback(
        "low_confidence_escalate",
        choice=choice,
        http_status=http_status,
        probability=probability,
        confidence=confidence,
        input_tokens_api=input_tokens_api,
        output_tokens_api=output_tokens_api,
        cost_usd=cost_usd,
        gate="LOW",
        final_action="escalate_to_system2",
        worker_class="escalate",
    )


def append_observability(record: DecisionRecord, cfg: dict[str, Any], state: str) -> Path:
    obs = cfg.get("observability") or {}
    rel = obs.get("logPath", "ai-system/logs/jev-decisions.jsonl")
    log_path = (REPO_ROOT / rel).resolve()
    log_path.parent.mkdir(parents=True, exist_ok=True)
    row = asdict(record)
    row["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    if obs.get("logPromptBody"):
        row["state_preview"] = state[:200]
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    return log_path


def _read_state(args: argparse.Namespace) -> str:
    if args.state:
        return args.state
    if args.task_file:
        return Path(args.task_file).read_text(encoding="utf-8")
    import sys

    return sys.stdin.read()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Jev System One task-tier proposal")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG))
    parser.add_argument("--task-file")
    parser.add_argument("--state")
    parser.add_argument("--mode", choices=["auto", "live", "fixture", "off"], default=None)
    parser.add_argument("--log", action="store_true", help="Append decision row to observability JSONL")
    args = parser.parse_args(argv)

    cfg = load_config(Path(args.config))
    state = _read_state(args)
    record = propose_task_tier(state, cfg=cfg, mode_override=args.mode)
    if args.log:
        append_observability(record, cfg, state)
    print(json.dumps(asdict(record), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
