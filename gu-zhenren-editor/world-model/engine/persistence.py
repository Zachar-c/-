"""Save files, run ledgers and hall (meta) progress.

Layout
------
world-model/saves/hall.json                大厅永久存档（图鉴/配方解锁，零数值成长）
world-model/saves/run.json                 进行中 Run 存档（原子写 + 版本 + 校验和）
world-model/runs/run-<seed>-<ts>.jsonl     每局台账（首行 header，其后每行一条不可变事件）

Determinism
-----------
The ledger **body** (every line after the header) is a pure function of the seed
and the world-model data digest. The header carries `content_sha256` of the body
plus wall-clock metadata; `--replay` compares `content_sha256`, so two runs of
the same seed are provably identical even though their file names differ.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
from pathlib import Path

from .errors import MetaProgressError, SaveCorruptError

WM_ROOT = Path(__file__).resolve().parents[1]
SAVE_DIR = WM_ROOT / "saves"
RUN_DIR = WM_ROOT / "runs"
HALL_FILE = SAVE_DIR / "hall.json"
RUN_SLOT = SAVE_DIR / "run.json"
SAVE_VERSION = "1.0.0"
LEDGER_VERSION = "1.0.0"


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def canonical(payload) -> str:
    return json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def checksum(payload) -> str:
    return hashlib.sha256(canonical(payload).encode("utf-8")).hexdigest()


def atomic_write(path: Path, text: str) -> Path:
    """tmp -> rename. A crash mid-write leaves the previous file intact."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    return path


# --------------------------------------------------------------------------
# envelope
# --------------------------------------------------------------------------

def build_envelope(kind: str, payload: dict) -> dict:
    return {
        "save_version": SAVE_VERSION,
        "world_model_version": payload.get("world_model_version", ""),
        "kind": kind,
        "saved_at": utc_now(),
        "checksum": checksum(payload),
        "payload": payload,
    }


def verify_envelope(doc: object, path: Path, expected_kind: str | None = None) -> dict:
    if not isinstance(doc, dict):
        raise SaveCorruptError(f"存档 {path.name} 不是对象", detail=repr(type(doc)))
    for key in ("save_version", "kind", "checksum", "payload"):
        if key not in doc:
            raise SaveCorruptError(f"存档 {path.name} 缺少字段 {key!r}")
    if doc["save_version"] != SAVE_VERSION:
        raise SaveCorruptError(
            f"存档 {path.name} 版本不兼容：{doc['save_version']} != {SAVE_VERSION}",
            detail="规则升级可拒绝不兼容的进行中 Run；请开新局。")
    if expected_kind and doc["kind"] != expected_kind:
        raise SaveCorruptError(f"存档 {path.name} 类型为 {doc['kind']!r}，期望 {expected_kind!r}")
    actual = checksum(doc["payload"])
    if actual != doc["checksum"]:
        raise SaveCorruptError(
            f"存档 {path.name} 校验和不符（内容可能已损坏）",
            detail=f"expected {doc['checksum'][:16]}… got {actual[:16]}…")
    return doc["payload"]


def write_save(path: Path, kind: str, payload: dict) -> Path:
    return atomic_write(path, json.dumps(build_envelope(kind, payload), ensure_ascii=False, indent=1) + "\n")


def read_save(path: Path, expected_kind: str | None = None) -> dict:
    if not path.exists():
        raise SaveCorruptError(f"存档不存在：{path.name}", detail=str(path))
    try:
        with path.open(encoding="utf-8") as fh:
            doc = json.load(fh)
    except json.JSONDecodeError as exc:
        raise SaveCorruptError(f"存档 {path.name} 不是合法 JSON", detail=str(exc)) from exc
    return verify_envelope(doc, path, expected_kind)


# --------------------------------------------------------------------------
# run save / recovery
# --------------------------------------------------------------------------

def save_run(state: dict, path: Path | None = None, ledger_path: str = "") -> Path:
    payload = {k: v for k, v in state.items() if k != "map"}
    payload["_map"] = state.get("map")
    payload["ledger_path"] = ledger_path
    return write_save(path or RUN_SLOT, "run", payload)


def load_run(path: Path | None = None) -> dict:
    return read_save(path or RUN_SLOT, "run")


def run_save_exists(path: Path | None = None) -> bool:
    return (path or RUN_SLOT).exists()


def delete_run(path: Path | None = None) -> None:
    target = path or RUN_SLOT
    if target.exists():
        target.unlink()


def recover_run() -> tuple[dict | None, str]:
    """Return (payload, note). Corrupted saves are reported, not fatal."""
    target = RUN_SLOT
    if not target.exists():
        return None, "没有进行中的 Run 存档。"
    try:
        return load_run(target), ""
    except SaveCorruptError as exc:
        quarantine = target.with_suffix(".corrupt.json")
        try:
            target.replace(quarantine)
            note = f"进行中的存档已损坏（{exc.message}），已隔离为 {quarantine.name}；可从大厅开新局。"
        except OSError:
            note = f"进行中的存档已损坏（{exc.message}），且无法隔离；可从大厅开新局。"
        return None, note


# --------------------------------------------------------------------------
# hall / meta
# --------------------------------------------------------------------------

EMPTY_META = {
    "meta_version": SAVE_VERSION,
    "codex_known_gu": [],
    "recipes_unlocked": [],
    "runs_played": 0,
    "endings": {},
    "numeric_growth": {},
    "world_model_version": "",
}


def load_meta(path: Path | None = None) -> dict:
    target = path or HALL_FILE
    if not target.exists():
        meta = dict(EMPTY_META)
        meta["codex_known_gu"] = []
        meta["recipes_unlocked"] = []
        meta["endings"] = {}
        meta["numeric_growth"] = {}
        return meta
    try:
        payload = read_save(target, "hall")
    except SaveCorruptError as exc:
        raise MetaProgressError(f"大厅存档不可用：{exc.message}", detail=exc.detail) from exc
    for key, default in EMPTY_META.items():
        payload.setdefault(key, json.loads(json.dumps(default)))
    return payload


def save_meta(meta: dict, path: Path | None = None) -> Path:
    return write_save(path or HALL_FILE, "hall", meta)


# --------------------------------------------------------------------------
# ledger
# --------------------------------------------------------------------------

def ledger_path_for(seed: int, timestamp: str | None = None, directory: Path | None = None) -> Path:
    """Unique path per call so two same-second runs do not overwrite each other
    (replay comparison needs both files to survive)."""
    directory = directory or RUN_DIR
    ts = (timestamp or utc_now()).replace(":", "").replace("-", "")
    base = directory / f"run-{int(seed)}-{ts}"
    candidate = base.with_suffix(".jsonl")
    index = 1
    while candidate.exists():
        candidate = base.with_name(f"{base.name}-{index}.jsonl")
        index += 1
    return candidate


def write_ledger(run, world_model_version: str, directory: Path | None = None,
                 timestamp: str | None = None) -> Path:
    body = run.ledger_body()
    content_sha256 = hashlib.sha256(body.encode("utf-8")).hexdigest()
    header = {
        "ledger_version": LEDGER_VERSION,
        "kind": "run_ledger",
        "seed": run.seed,
        "world_model_version": world_model_version,
        "data_digest": run.wm.data_digest,
        "created_at": timestamp or utc_now(),
        "entries": len(run.ledger),
        "content_sha256": content_sha256,
        "outcome": run.ending or run.state.get("status", ""),
        "state_digest": run.state_digest(),
    }
    # The body must be byte-identical to run.ledger_body(), otherwise the file's
    # own hash would not reproduce content_sha256.
    text = json.dumps(header, ensure_ascii=False, sort_keys=True) + "\n"
    text += body + "\n"
    path = ledger_path_for(run.seed, timestamp, directory)
    atomic_write(path, text)
    return path


def read_ledger(path: Path) -> dict:
    if not path.exists():
        raise SaveCorruptError(f"台账不存在：{path.name}", detail=str(path))
    header: dict | None = None
    body_lines: list[str] = []
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            if header is None:
                try:
                    header = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise SaveCorruptError(f"台账 {path.name} 头部不是合法 JSON", detail=str(exc)) from exc
            else:
                body_lines.append(line)
    if header is None:
        raise SaveCorruptError(f"台账 {path.name} 为空")
    body = "\n".join(body_lines)
    actual = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return {"header": header, "body_lines": body_lines, "body": body,
            "content_sha256": actual, "matches_header": actual == header.get("content_sha256")}


def find_ledgers(seed: int, directory: Path | None = None) -> list[Path]:
    directory = directory or RUN_DIR
    if not directory.exists():
        return []
    return sorted(directory.glob(f"run-{int(seed)}-*.jsonl"))


def compare_ledgers(a: Path, b: Path) -> dict:
    left, right = read_ledger(a), read_ledger(b)
    same_hash = left["content_sha256"] == right["content_sha256"]
    diff_index = None
    if not same_hash:
        for i, (x, y) in enumerate(zip(left["body_lines"], right["body_lines"])):
            if x != y:
                diff_index = i
                break
        if diff_index is None and len(left["body_lines"]) != len(right["body_lines"]):
            diff_index = min(len(left["body_lines"]), len(right["body_lines"]))
    return {
        "identical": same_hash,
        "left": a.name, "right": b.name,
        "left_sha256": left["content_sha256"], "right_sha256": right["content_sha256"],
        "left_entries": len(left["body_lines"]), "right_entries": len(right["body_lines"]),
        "first_diff_line": diff_index,
        "left_header_ok": left["matches_header"], "right_header_ok": right["matches_header"],
    }
