"""Focused stdlib regression check for reviewed relation dependencies."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("compile_runtime", Path(__file__).with_name("compile_runtime.py"))
compiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compiler)


def must_fail(index):
    with contextlib.redirect_stderr(io.StringIO()):
        try:
            compiler.compile_relations({"小光蛊": "small_light_gu", "月光蛊": "moonlight_gu",
                                        "月芒蛊": "moon_glow_gu"}, index)
        except SystemExit as exc:
            assert exc.code == 1
            return
    raise AssertionError("changed relation dependency unexpectedly compiled")


states = compiler.index_state_rows()
baseline = compiler.compile_relations({"小光蛊": "small_light_gu", "月光蛊": "moonlight_gu",
                                       "月芒蛊": "moon_glow_gu"}, states)
runtime = json.loads((ROOT / "lore/runtime/relations.json").read_text(encoding="utf-8"))["relations"]
assert sorted(baseline, key=lambda row: row["id"]) == sorted(runtime, key=lambda row: row["id"])

for cfg in compiler.RELATION_SOURCES:
    st_id = cfg["st_id"]
    for field, value in (("statement", "mutated"), ("evidence", []),
                         ("canon_refs", ["CAN-CHANGED"]), ("page", "other.md")):
        changed = {key: dict(row) for key, row in states.items()}
        changed[st_id][field] = value
        must_fail(changed)
    missing = dict(states)
    del missing[st_id]
    must_fail(missing)
print("PASS baseline matches runtime; 12 field mutations and 3 missing ST rows rejected")
