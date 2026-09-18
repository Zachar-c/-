#!/usr/bin/env python3
"""World-model test suite — assert-style, standard library only.

    python world-model/tests/run_tests.py            # 全部用例
    python world-model/tests/run_tests.py rng persistence   # 只跑名称匹配的用例

退出码：全部通过 = 0，存在失败 = 1
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import traceback
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
if str(WM_ROOT) not in sys.path:
    sys.path.insert(0, str(WM_ROOT))

from engine import persistence as ps  # noqa: E402
from engine import rules  # noqa: E402
from engine.errors import (DataFormatError, DataMissingError, GuBacklash, NumericOverflow,  # noqa: E402
                           ResourceExhausted, SaveCorruptError, WorldModelError)
from engine.model import WorldModel  # noqa: E402
from engine.rng import SeededRng, Stream, index, mixed_seed, salt_hash, wrap64  # noqa: E402
from engine.run import Run  # noqa: E402
from schema.mini_schema import Validator, load_schema  # noqa: E402

TESTS: list[tuple[str, callable]] = []


def test(fn):
    TESTS.append((fn.__name__, fn))
    return fn


class Ctx:
    """Per-test scratch space under a temporary directory."""

    def __init__(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="wm-test-"))

    def path(self, name: str) -> Path:
        return self.tmp / name

    def cleanup(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)


def approx(a: float, b: float, tol: float = 1e-9) -> bool:
    return abs(a - b) <= tol


# ==========================================================================
# 1. schema / 加载
# ==========================================================================

@test
def schema_files_present(ctx: Ctx) -> None:
    from engine.model import ENTITY_FILES
    for entity_type, filename in ENTITY_FILES.items():
        assert (WM_ROOT / "data" / filename).exists(), f"缺少数据文件 {filename}（{entity_type}）"
    assert (WM_ROOT / "schema" / "world-model.schema.json").exists()


@test
def schema_documents_all_pass(ctx: Ctx) -> None:
    schema = load_schema(WM_ROOT / "schema" / "world-model.schema.json")
    validator = Validator(schema)
    checks = 0
    for path in sorted((WM_ROOT / "data").glob("*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        errors = validator.validate_document(doc, doc["entity_type"])
        checks += validator.checks
        assert not errors, f"{path.name} 未通过 schema：{errors[:3]}"
    assert checks > 20000, f"schema 断言太少（{checks}），校验器可能没真正工作"


@test
def world_model_loads_and_exposes_accessors(ctx: Ctx) -> None:
    wm = WorldModel()
    assert len(wm.gu) == 802, f"应载入 802 只蛊，实际 {len(wm.gu)}"
    assert len(wm.realms) == 36
    assert len(wm.paths) == 20
    assert len(wm.layers()) == 5
    assert wm.gu_def("small_light_gu")["name_zh"] == "小光蛊"
    assert wm.b("growth", "essence_base") == 10
    assert wm.data_digest and len(wm.data_digest) == 64


@test
def schema_field_tables_documented(ctx: Ctx) -> None:
    """验收 A1：字段说明表必须真实存在且覆盖全部实体。"""
    readme = (WM_ROOT / "schema" / "README.md").read_text(encoding="utf-8")
    schema = json.loads((WM_ROOT / "schema" / "world-model.schema.json").read_text(encoding="utf-8"))
    for entity_type in schema["$defs"]["entity_type"]["enum"]:
        assert f"## " in readme
        assert entity_type in readme, f"schema/README.md 未说明实体 {entity_type}"
    assert "source_class" in readme and "tunable" in readme


# ==========================================================================
# 2. 种子可复现性
# ==========================================================================

@test
def lcg_matches_reference_implementation(ctx: Ctx) -> None:
    assert SeededRng(101).next_index(100) == 71
    rng = SeededRng(101)
    assert [rng.next_index(100) for _ in range(5)] == [71, 18, 66, 7, 82]
    assert SeededRng(0).next_index(10) == SeededRng(2147483647).next_index(10)
    assert SeededRng(-5).next_index(10) == SeededRng(5).next_index(10)
    assert index(1, 1, "x", 5) == 0
    assert salt_hash("") == 0
    assert wrap64(1 << 63) == -(1 << 63)
    assert mixed_seed(1, "", 0) == 1000003


@test
def tick_is_stream_position_not_affine_mix(ctx: Ctx) -> None:
    """若把 tick 直接仿射混入种子再走一步，相邻抽取会退化成等差阶梯。"""
    ladder = [index(100, 7, "roll", t) for t in range(12)]
    diffs = {ladder[i + 1] - ladder[i] for i in range(len(ladder) - 1)}
    assert len(diffs) > 1, f"出现等差阶梯（diffs={diffs}），tick 语义错误"
    stream = Stream(7, "roll")
    assert [stream.draw(100) for _ in range(12)] == ladder, "Stream.draw 与 index() 语义不一致"


@test
def layer_goes_into_salt(ctx: Ctx) -> None:
    a = Stream(11, "encounter", layer=1)
    b = Stream(11, "encounter", layer=2)
    assert a.salt != b.salt
    assert [a.draw(50) for _ in range(6)] != [b.draw(50) for _ in range(6)]


@test
def same_seed_produces_identical_ledger(ctx: Ctx) -> None:
    wm = WorldModel()
    run_a = Run(wm, 4242)
    run_a.start()
    run_a.run_to_end()
    run_b = Run(wm, 4242)
    run_b.start()
    run_b.run_to_end()
    assert run_a.ledger_body() == run_b.ledger_body(), "同种子两次运行的台账不一致"
    assert run_a.content_sha256() == run_b.content_sha256()
    assert run_a.state_digest() == run_b.state_digest()
    assert run_a.summary()["outcome"] == run_b.summary()["outcome"]


@test
def ledger_is_independent_of_hall_progress(ctx: Ctx) -> None:
    """同种子台账不得依赖大厅进度，否则重放比对会因累计图鉴而失败。"""
    wm = WorldModel()
    empty = {"meta_version": ps.SAVE_VERSION, "codex_known_gu": [], "recipes_unlocked": [],
             "runs_played": 0, "endings": {}, "numeric_growth": {}, "world_model_version": ""}
    warmed = {"meta_version": ps.SAVE_VERSION, "codex_known_gu": ["moonlight_gu", "stone_shell_gu"],
              "recipes_unlocked": ["moonlight_glow"], "runs_played": 7, "endings": {"ascended": 7},
              "numeric_growth": {}, "world_model_version": ""}
    a = Run(wm, 808, meta=dict(empty))
    a.start()
    a.run_to_end()
    b = Run(wm, 808, meta=dict(warmed))
    b.start()
    b.run_to_end()
    assert a.ledger_body() == b.ledger_body(), "同种子台账随大厅进度变化（台账漏进了全局状态）"
    assert a.content_sha256() == b.content_sha256()


@test
def different_seeds_diverge(ctx: Ctx) -> None:
    wm = WorldModel()
    digests = set()
    for seed in (1, 2, 3, 4, 5):
        run = Run(wm, seed)
        run.start()
        run.run_to_end()
        digests.add(run.content_sha256())
    assert len(digests) >= 4, f"不同种子产生了过于相似的台账（{len(digests)} 种）"


@test
def ledger_file_roundtrips_and_replays(ctx: Ctx) -> None:
    wm = WorldModel()
    run = Run(wm, 555)
    run.start()
    run.run_to_end()
    directory = ctx.path("runs")
    directory.mkdir()
    p1 = ps.write_ledger(run, wm.version, directory=directory, timestamp="2026-01-01T00:00:00Z")
    p2 = ps.write_ledger(run, wm.version, directory=directory, timestamp="2026-01-01T00:00:00Z")
    assert p1 != p2, "同秒两次写台账必须产生两个文件，否则重放无法比对"
    loaded = ps.read_ledger(p1)
    assert loaded["matches_header"], "台账正文哈希与 header.content_sha256 不符"
    assert loaded["content_sha256"] == run.content_sha256()
    comparison = ps.compare_ledgers(p1, p2)
    assert comparison["identical"], comparison


# ==========================================================================
# 3. 完整一局
# ==========================================================================

@test
def full_run_reaches_settlement(ctx: Ctx) -> None:
    wm = WorldModel()
    run = Run(wm, 101)
    run.start()
    assert run.state["status"] == "active"
    assert run.state["rank"] == 1 and run.state["aptitude"] == "bing"
    assert run.state["hp"] == 80 and run.state["lifespan"] == 60 and run.state["soul"] == 1
    summary = run.run_to_end()
    assert summary["outcome"] in ("ascended", "death"), summary["outcome"]
    assert summary["layer_reached"] == 5, f"应走到第 5 层，实际 {summary['layer_reached']}"
    assert summary["nodes_visited"] >= 10
    assert summary["ledger_entries"] > 10
    assert any(e["type"] == "run_end" for e in run.ledger), "缺少结算事件"
    assert run.state["status"] == summary["outcome"]


@test
def layer_traversal_visits_one_node_per_row(ctx: Ctx) -> None:
    wm = WorldModel()
    run = Run(wm, 202)
    run.start()
    seen_rows = []
    guard = 0
    while run.state["status"] == "active" and guard < 5000:
        if run.state["node_taken"] is None:
            seen_rows.append((run.state["layer"], run.state["row"]))
        run.auto_step()
        guard += 1
    assert guard < 5000, "运行器没有收敛（可能存在僵局）"
    assert len(seen_rows) == len(set(seen_rows)), "同一行被重复选择"
    map_layers = run.state["map"]["layers"]
    assert len(map_layers) == 5
    for layer in map_layers:
        rows = layer["rows"]
        assert len(rows) >= 2
        assert rows[-1]["kind"] == "boss", "每层最后一行必须是 Boss 席"
        assert len(rows[-1]["nodes"]) == 1


@test
def boss_row_uses_layer_boss_pool(ctx: Ctx) -> None:
    wm = WorldModel()
    for seed in (11, 22, 33, 44):
        run = Run(wm, seed)
        run.start()
        run.run_to_end()
        boss_starts = [e for e in run.ledger if e["type"] == "battle_start" and e["tier"] == "boss"]
        pools = {layer["layer"]: set(layer["boss_pool"]) for layer in run.state["map"]["layers"]}
        for entry in boss_starts:
            assert entry["enemy_id"] in pools[entry["layer"]], \
                f"第 {entry['layer']} 层的 Boss {entry['enemy_id']} 不在该层 Boss 池内"


@test
def battle_bounds_and_no_stalemate_in_the_wild(ctx: Ctx) -> None:
    wm = WorldModel()
    limit = int(wm.b("run", "max_battle_rounds"))
    for seed in range(700, 712):
        run = Run(wm, seed)
        run.start()
        run.run_to_end()
        for entry in run.ledger:
            if entry["type"] == "battle_stalemate":
                assert entry["rounds"] <= limit
                assert entry["rule"] == wm.b("run", "stalemate_rule")
        assert run.state["status"] != "active", f"种子 {seed} 未收束"


@test
def three_death_axes_are_wired(ctx: Ctx) -> None:
    wm = WorldModel()
    assert set(wm.b("run", "death_axes")) == {"hp", "lifespan", "soul"}
    state = {"hp": 0, "lifespan": 60, "soul": 1}
    events = rules.check_death(wm, state)
    assert events and events[0]["cause_zh"] == "气血耗尽而亡"
    state = {"hp": 10, "lifespan": 0, "soul": 1}
    assert rules.check_death(wm, state)[0]["cause_zh"] == "寿元枯竭而亡"
    state = {"hp": 10, "lifespan": 10, "soul": 0}
    assert rules.check_death(wm, state)[0]["cause_zh"] == "魂魄崩散而亡"


@test
def cultivation_hard_gate_blocks_bing_rank_three(ctx: Ctx) -> None:
    wm = WorldModel()
    ok, reason = rules.can_cultivate_to(wm, 1, 2, "bing")
    assert ok, reason
    ok, reason = rules.can_cultivate_to(wm, 2, 3, "bing")
    assert not ok and "资质" in reason, "丙等必须被三转硬门槛拦住"
    ok, _ = rules.can_cultivate_to(wm, 2, 3, "yi")
    assert ok, "乙等应可冲三转"
    ok, reason = rules.can_cultivate_to(wm, 1, 3, "jia")
    assert not ok and "逐转" in reason, "不允许跳转"


@test
def essence_formulas_match_the_locked_spec(ctx: Ctx) -> None:
    wm = WorldModel()
    # rank 0 走 floor：与 1 转同读 cultivation_factor["1"]
    assert rules.essence_max(wm, 0, "bing") == 20
    assert rules.essence_max(wm, 1, "bing") == 20
    assert rules.essence_max(wm, 2, "bing") == 60
    assert rules.essence_max(wm, 3, "jia") == 360
    assert rules.essence_max(wm, 5, "jia") == 3240
    assert rules.essence_max_battle(wm, 1, "bing") == 20
    assert rules.essence_max_battle(wm, 5, "jia") == 600
    assert rules.essence_regen_per_turn(wm, 20, "bing") == 5
    # down-rank discount: 2^(gu_rank - cultivator_rank)
    assert approx(rules.actual_activation_cost(wm, 8, 1, 3), 2.0), rules.actual_activation_cost(wm, 8, 1, 3)
    assert approx(rules.actual_activation_cost(wm, 8, 3, 3), 8.0)


# ==========================================================================
# 4. 异常路径
# ==========================================================================

@test
def exception_resource_exhausted_fires(ctx: Ctx) -> None:
    wm = WorldModel()
    state = {"stone": 1, "aptitude": "bing", "essence": 0, "essence_max": 20}
    try:
        rules.stone_to_essence(wm, 10, state)
    except ResourceExhausted as exc:
        assert exc.code == "resource_exhausted"
        assert "元石不足" in exc.message
    else:
        raise AssertionError("元石不足未抛 ResourceExhausted")
    state = {"stone": 100, "aptitude": "bing", "essence": 20, "essence_max": 20}
    try:
        rules.stone_to_essence(wm, 5, state)
    except ResourceExhausted as exc:
        assert "真元已满" in exc.message
    else:
        raise AssertionError("真元已满未抛 ResourceExhausted")
    # empty gu list feeding bill is free and silent
    assert rules.feeding_bill(wm, []) == 0


@test
def exception_gu_backlash_fires(ctx: Ctx) -> None:
    wm = WorldModel()
    run = Run(wm, 9)
    run.start()
    over = next((g for g in wm.gu.values()
                 if g["rank"] == 5 and not g["is_test_entity"]), None)
    assert over is not None
    run.state["gu_instances"].append(rules.gu_instance(wm, over["id"], "over"))
    hp_before = run.state["hp"]
    try:
        rules.activate_gu(wm, run.state, "over", in_battle=False, strict=True)
    except GuBacklash as exc:
        assert exc.code == "gu_backlash"
        assert "反噬" in exc.message
    else:
        raise AssertionError("越级催蛊未抛 GuBacklash")
    assert run.state["hp"] == hp_before, "strict 模式必须零副作用（预检语义）"

    forced = rules.gu_instance(wm, over["id"], "over2")
    run.state["gu_instances"].append(forced)
    run.state["essence"] = run.state["essence_max"]
    result = rules.activate_gu(wm, run.state, "over2", in_battle=False, strict=False)
    assert result["forced"] and result["backlash_damage"] >= 1
    assert run.state["hp"] == hp_before - result["backlash_damage"]

    run.state["gu_instances"].append(rules.gu_instance(wm, "small_light_gu", "sealed"))
    run.state["gu_instances"][-1]["sealed_turns"] = 2
    try:
        rules.activate_gu(wm, run.state, "sealed", in_battle=False)
    except ResourceExhausted as exc:
        assert "禁锢" in exc.message
    else:
        raise AssertionError("被禁锢的蛊仍可催动")


@test
def exception_numeric_overflow_fires(ctx: Ctx) -> None:
    wm = WorldModel()
    # 局外真元上限：cultivation_factor 只覆盖 1-5 转，越界必须报错而不是静默退回 1 转
    for rank in (6, 9):
        try:
            rules.essence_max(wm, rank, "jia")
        except NumericOverflow as exc:
            assert exc.code == "numeric_overflow"
            assert str(rank) in exc.message, f"报错信息须带上越界转数：{exc.message}"
        else:
            raise AssertionError(f"{rank} 转的局外真元上限未被 NumericOverflow 拦住")
    try:
        rules.essence_max_battle(wm, 9, "bing")
    except NumericOverflow as exc:
        assert exc.code == "numeric_overflow"
    else:
        raise AssertionError("蛊仙阶段战斗真元未被 NumericOverflow 拦住")
    try:
        rules.cultivation_cost(wm, 9)
    except NumericOverflow:
        pass
    else:
        raise AssertionError("未定义转数的突破成本应抛 NumericOverflow")

    meta = {"codex_known_gu": [], "recipes_unlocked": [], "numeric_growth": {"attack": 1}}
    run = Run(wm, 3)
    run.start()
    try:
        rules.apply_ending(wm, run.state, "death", meta)
    except NumericOverflow as exc:
        assert "永久数值成长" in exc.message
    else:
        raise AssertionError("Meta 数值成长必须被拒绝")

    state = {"hp": 10, "lifespan": 10, "soul": 1, "gu_instances": [], "materials": {}, "stone": 0,
             "rank": 1, "pursuit_stage": 0}
    try:
        rules.gu_instance(wm, "definitely_not_a_gu", "x")
    except DataMissingError:
        pass
    else:
        raise AssertionError("未知蛊 id 应抛 DataMissingError")


@test
def exception_data_missing_fires(ctx: Ctx) -> None:
    broken = ctx.path("data_missing")
    broken.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        if path.name != "realms.json":
            shutil.copy(path, broken / path.name)
    try:
        WorldModel(data_dir=broken, validate=False)
    except DataMissingError as exc:
        assert exc.code == "data_missing" and "realms.json" in exc.message
    else:
        raise AssertionError("缺少数据文件未抛 DataMissingError")
    wm = WorldModel()
    try:
        wm.gu_def("no_such_gu")
    except DataMissingError as exc:
        assert "no_such_gu" in exc.message
    else:
        raise AssertionError("未知实体未抛 DataMissingError")
    try:
        wm.b("growth", "no_such_param")
    except DataMissingError:
        pass
    else:
        raise AssertionError("未知 balance 参数未抛 DataMissingError")


@test
def exception_data_format_fires(ctx: Ctx) -> None:
    broken = ctx.path("data_bad_json")
    broken.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        shutil.copy(path, broken / path.name)
    (broken / "balance.json").write_text("{ this is not json", encoding="utf-8")
    try:
        WorldModel(data_dir=broken, validate=False)
    except DataFormatError as exc:
        assert exc.code == "data_format"
    else:
        raise AssertionError("坏 JSON 未抛 DataFormatError")

    wrong = ctx.path("data_wrong_type")
    wrong.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        shutil.copy(path, wrong / path.name)
    doc = json.loads((wrong / "gu.json").read_text(encoding="utf-8"))
    doc["entity_type"] = "realm"
    (wrong / "gu.json").write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        WorldModel(data_dir=wrong, validate=False)
    except DataFormatError as exc:
        assert "entity_type" in exc.message
    else:
        raise AssertionError("entity_type 不符未抛 DataFormatError")

    incomplete = ctx.path("data_count")
    incomplete.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        shutil.copy(path, incomplete / path.name)
    doc = json.loads((incomplete / "gu.json").read_text(encoding="utf-8"))
    doc["count"] = doc["count"] + 1
    (incomplete / "gu.json").write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        WorldModel(data_dir=incomplete, validate=False)
    except DataFormatError as exc:
        assert "count" in exc.message
    else:
        raise AssertionError("count 不符未抛 DataFormatError")

    # schema-level violation is caught by the validating loader
    hack = ctx.path("data_schema")
    hack.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        shutil.copy(path, hack / path.name)
    doc = json.loads((hack / "realms.json").read_text(encoding="utf-8"))
    doc["entities"][0]["rank"] = 99
    (hack / "realms.json").write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        WorldModel(data_dir=hack, validate=True)
    except DataFormatError as exc:
        assert exc.code == "data_format"
    else:
        raise AssertionError("schema 违规未抛 DataFormatError")

    dupes = ctx.path("data_dupes")
    dupes.mkdir()
    for path in (WM_ROOT / "data").glob("*.json"):
        shutil.copy(path, dupes / path.name)
    doc = json.loads((dupes / "events.json").read_text(encoding="utf-8"))
    doc["entities"].append(json.loads(json.dumps(doc["entities"][0])))
    doc["count"] = len(doc["entities"])
    (dupes / "events.json").write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        WorldModel(data_dir=dupes, validate=False)
    except DataFormatError as exc:
        assert "重复实体" in exc.message
    else:
        raise AssertionError("重复实体 id 未抛 DataFormatError")


@test
def exception_save_corrupt_fires(ctx: Ctx) -> None:
    run = Run(WorldModel(), 77)
    run.start()
    path = ctx.path("run.json")
    ps.save_run(run.state, path=path)
    assert ps.read_save(path, "run")["seed"] == 77

    doc = json.loads(path.read_text(encoding="utf-8"))
    doc["payload"]["stone"] = doc["payload"]["stone"] + 999
    path.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        ps.read_save(path, "run")
    except SaveCorruptError as exc:
        assert exc.code == "save_corrupt" and "校验和" in exc.message
    else:
        raise AssertionError("被篡改的存档未抛 SaveCorruptError")

    path.write_text("{not json", encoding="utf-8")
    try:
        ps.read_save(path, "run")
    except SaveCorruptError as exc:
        assert "JSON" in exc.message
    else:
        raise AssertionError("坏 JSON 存档未抛 SaveCorruptError")

    ps.save_run(run.state, path=path)
    doc = json.loads(path.read_text(encoding="utf-8"))
    doc["save_version"] = "0.0.1"
    path.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    try:
        ps.read_save(path, "run")
    except SaveCorruptError as exc:
        assert "版本" in exc.message
    else:
        raise AssertionError("版本不兼容未抛 SaveCorruptError")

    ps.save_run(run.state, path=path)
    try:
        ps.read_save(path, "hall")
    except SaveCorruptError as exc:
        assert "类型" in exc.message
    else:
        raise AssertionError("存档类型不符未抛 SaveCorruptError")


@test
def save_recovery_quarantines_corrupt_file(ctx: Ctx) -> None:
    original_slot = ps.RUN_SLOT
    try:
        ps.RUN_SLOT = ctx.path("run.json")
        payload, note = ps.recover_run()
        assert payload is None and "没有进行中" in note, note
        run = Run(WorldModel(), 88)
        run.start()
        ps.save_run(run.state)
        ps.RUN_SLOT.write_text("{broken", encoding="utf-8")
        payload, note = ps.recover_run()
        assert payload is None, "损坏存档不应被当作可用存档返回"
        assert "损坏" in note and "隔离" in note, note
        assert ctx.path("run.corrupt.json").exists(), "损坏存档应被隔离保留"
    finally:
        ps.RUN_SLOT = original_slot


@test
def invalid_input_does_not_crash(ctx: Ctx) -> None:
    run = Run(WorldModel(), 12)
    run.start()
    for bad in ("no_such_action", "", "gu:nope", "gu_force:nope"):
        try:
            run.apply_action(bad)
        except WorldModelError as exc:
            assert isinstance(exc.message, str) and exc.message
        except Exception as exc:  # noqa: BLE001
            raise AssertionError(f"非法输入 {bad!r} 抛出了非 WorldModelError：{type(exc).__name__}: {exc}")
    try:
        run.choose_node(999)
    except WorldModelError as exc:
        assert "越界" in exc.message
    else:
        raise AssertionError("越界节点序号未报错")


# ==========================================================================
# 5. Meta 继承
# ==========================================================================

@test
def meta_inheritance_keeps_knowledge_only(ctx: Ctx) -> None:
    wm = WorldModel()
    meta = ps.EMPTY_META.copy()
    meta = {"meta_version": ps.SAVE_VERSION, "codex_known_gu": [], "recipes_unlocked": [],
            "runs_played": 0, "endings": {}, "numeric_growth": {}, "world_model_version": ""}
    first = Run(wm, 31, meta=meta)
    first.start()
    first.run_to_end()
    codex_after_first = len(meta["codex_known_gu"])
    assert codex_after_first >= 1, "第一局结束后图鉴应有内容"
    assert meta["runs_played"] == 1
    assert meta["numeric_growth"] == {}, "Meta 不允许任何永久数值成长"
    assert all(k not in meta for k in ("hp", "attack", "essence_max", "stone")), \
        "Meta 存档不得包含局内数值字段"

    second = Run(wm, 32, meta=meta)
    second.start()
    assert second.state["hp"] == wm.b("run", "starter")["hp"], "新局气血不得被 Meta 影响"
    assert second.state["stone"] == wm.b("run", "starter")["stone"], "新局元石不得被 Meta 影响"
    assert second.state["rank"] == 1, "新局转数不得被 Meta 影响"
    second.run_to_end()
    assert meta["runs_played"] == 2
    assert len(meta["codex_known_gu"]) >= codex_after_first, "图鉴只能增长"

    hall = ctx.path("hall.json")
    ps.save_meta(meta, path=hall)
    loaded = ps.load_meta(path=hall)
    assert loaded["codex_known_gu"] == meta["codex_known_gu"]
    assert loaded["numeric_growth"] == {}


@test
def missing_hall_file_yields_empty_meta(ctx: Ctx) -> None:
    meta = ps.load_meta(path=ctx.path("no_such_hall.json"))
    assert meta["runs_played"] == 0
    assert meta["codex_known_gu"] == []
    assert meta["numeric_growth"] == {}


# ==========================================================================
# 6. 规则与经济细节
# ==========================================================================

@test
def feeding_ledger_pays_then_backlashes(ctx: Ctx) -> None:
    wm = WorldModel()
    run = Run(wm, 606)
    run.start()
    run.state["stone"] = 0
    run.state["gu_instances"].append(rules.gu_instance(wm, "moonlight_gu", "g99"))
    bill = rules.feeding_bill(wm, run.state["gu_instances"])
    assert bill > 0
    result = rules.settle_feeding(wm, run.state)
    assert result["shortfall"] > 0, "付不起时不允许静默补齐"
    assert result["paid"] == 0
    assert result["backlash"], "欠账必须产生反噬或降阶记录"


@test
def loot_weights_are_normalised_and_pity_fires(ctx: Ctx) -> None:
    wm = WorldModel()
    for tier, spec in wm.loot["tiers"].items():
        weights = (spec.get("gu_pool", {}) or {}).get("weights", {})
        if weights:
            assert abs(sum(weights.values()) - 100) <= 1, f"{tier} 的稀有度权重和为 {sum(weights.values())}"
    for layer in wm.layers():
        assert abs(sum(layer["loot_rarity_weights"].values()) - 100) <= 1
        assert abs(sum(layer["category_weights"].values()) - 100) <= 1
    state = {"pity_by_tier": {}}
    threshold = int(wm.b("loot", "pity_threshold"))
    got = None
    for tick in range(threshold + 2):
        stream = Stream(1, f"loot-probe-{tick}")
        drop = rules.roll_loot(wm, stream, 1, "common", state)
        if drop["gu"]:
            got = drop["gu"]
            break
    assert got is not None, f"保底 {threshold} 次内没有掉出蛊虫"
    assert state["pity_by_tier"]["common"] == 0, "出蛊后保底计数必须清零"


@test
def refinement_graph_is_acyclic_and_lifts_rank(ctx: Ctx) -> None:
    wm = WorldModel()
    rank = {gid: g["rank"] for gid, g in wm.gu.items()}
    edges = []
    for gid, g in wm.gu.items():
        for edge in g["refine_as_output"]:
            if edge["kind"] == "free_mix":
                continue
            dst = edge["output_gu_id"]
            inputs = [i for i in edge["input_gu_ids"] if i != dst]
            if not inputs:
                if edge["kind"] == "advance":
                    continue  # same definition, rank +1 in place
                assert edge["materials"], f"{edge['recipe_id']} 既无输入蛊也无材料"
                continue  # material-only forge: no gu-graph edge
            for src in inputs:
                edges.append((src, dst))
                assert rank[dst] > rank[src], \
                    f"配方 {edge['recipe_id']} 的输出转数 {rank[dst]} 未高于输入 {src}（{rank[src]}）"
    adjacency: dict[str, list[str]] = {}
    for src, dst in edges:
        adjacency.setdefault(src, []).append(dst)

    visiting: set[str] = set()
    done: set[str] = set()

    def visit(node: str, path: list[str]) -> None:
        assert node not in visiting, f"升炼图存在环：{' → '.join(path + [node])}"
        if node in done:
            return
        visiting.add(node)
        for nxt in adjacency.get(node, []):
            visit(nxt, path + [node])
        visiting.discard(node)
        done.add(node)

    for node in list(adjacency):
        visit(node, [])
    assert edges, "升炼图不应为空"


@test
def action_points_follow_soul_ladder(ctx: Ctx) -> None:
    wm = WorldModel()
    assert rules.action_points(wm, 1) == 2
    assert rules.action_points(wm, 10) == 3
    assert rules.action_points(wm, 100) == 4
    assert rules.action_points(wm, 1000) == 5
    assert rules.action_points(wm, 10000) == 6
    assert rules.action_points(wm, 999999) == 6


@test
def enemy_profiles_scale_by_layer(ctx: Ctx) -> None:
    wm = WorldModel()
    l1 = rules.enemy_profile(wm, "clan_patriarch", 1, turn=1)
    l5 = rules.enemy_profile(wm, "clan_patriarch", 5, turn=5)
    assert l5["hp_max"] > l1["hp_max"], "Boss 血量应随层提高"
    assert l5["intent"]["damage"] >= l1["intent"]["damage"], "Boss 意图伤害应随层提高"
    plain = rules.enemy_profile(wm, "ridge_hound", 1, turn=1)
    assert plain["hp_max"] == 3
    assert plain["phases"], "所有敌人都应有至少一个相位"


@test
def realm_table_matches_canon_essence_grades(ctx: Ctx) -> None:
    wm = WorldModel()
    expected = {1: "bronze", 2: "iron", 3: "silver", 4: "gold", 5: "amethyst"}
    for rank, tier in expected.items():
        assert wm.realm(rank)["essence_tier"] == tier, f"{rank} 转真元品阶应为 {tier}"
    for rank in range(6, 10):
        realm = wm.realm(rank)
        assert realm["essence_tier"] is None, "六转以上原著未明确品阶，不得臆造"
        assert realm["cultivator_class"] == "gu_immortal"
        assert realm["is_immortal_tier"] is True
    assert wm.realm(9)["honorific"] == "venerable"


@test
def gu_table_faithfully_flags_role_defaults(ctx: Ctx) -> None:
    wm = WorldModel()
    sources = {}
    for g in wm.gu.values():
        sources[g["effect_source"]] = sources.get(g["effect_source"], 0) + 1
    assert sources.get("role_default", 0) > 700, \
        "只有 role 兜底的蛊必须如实标注 effect_source=role_default，不许假装有独立效果"
    assert sources.get("explicit", 0) > 0
    total = sum(sources.values())
    assert total == 802
    for g in wm.gu.values():
        if g["effect_source"] == "role_default":
            assert g["effect"]["kind"] in ("strike", "shield", "heal", "shift", "status"), g["id"]


@test
def traceability_fields_are_wellformed(ctx: Ctx) -> None:
    wm = WorldModel()
    pattern_ok = ("CAN-", "ADP-", "GAME-")
    for entity_type in ("realm", "path", "gu", "economy", "faction", "region", "event", "loot", "balance", "manifest"):
        for entity in wm.all(entity_type):
            assert entity["source_class"] in ("canon", "adaptation", "original_game_content"), entity["id"]
            assert entity["canon_review_status"] in ("draft", "needs_source", "approved", "rejected"), entity["id"]
            assert isinstance(entity["tunable"], bool)
            assert isinstance(entity["adaptation_note"], str)
            for sid in entity["source_ids"]:
                assert sid.startswith(pattern_ok), f"{entity['id']} 的来源编号 {sid!r} 不是 CAN-/ADP-/GAME-"
            if entity_type == "manifest":
                # 数据清单是构建产物，不对应原著设定，豁免内容溯源要求
                continue
            if entity["source_class"] == "canon":
                assert entity["source_ids"], (
                    f"{entity['id']} 标为 canon 却没有 source_ids —— 必须补 CAN 编号，"
                    f"或改判为 adaptation/original_game_content")
            if entity["canon_review_status"] == "approved":
                assert entity["source_ids"], f"{entity['id']} 已是 approved 状态却无来源编号"
    canon_gu = [g for g in wm.gu.values() if g["source_class"] == "canon"]
    assert len(canon_gu) > 200, "原著蛊虫数量偏少"


@test
def manifest_hashes_match_files(ctx: Ctx) -> None:
    import hashlib
    wm = WorldModel()
    manifest = wm.manifest
    assert manifest["third_party_dependencies"] == []
    assert manifest["file_count"] == len(manifest["files"])
    for entry in manifest["files"]:
        path = WM_ROOT.parent / entry["path"]
        assert path.exists(), f"清单条目 {entry['path']} 不存在"
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == entry["sha256"], f"{entry['path']} 的 sha256 与清单不符"
        assert entry["bytes"] == path.stat().st_size


@test
def cli_auto_run_writes_ledger_and_save(ctx: Ctx) -> None:
    import subprocess
    cli = WM_ROOT / "runner" / "cli.py"
    result = subprocess.run(
        [sys.executable, str(cli), "--seed", "31337", "--auto", "--quiet"],
        capture_output=True, text=True, encoding="utf-8", timeout=300, cwd=str(WM_ROOT))
    assert result.returncode == 0, f"CLI 退出码 {result.returncode}\n{result.stdout}\n{result.stderr}"
    assert "content_sha256" in result.stdout, result.stdout[-500:]
    assert list(ps.RUN_DIR.glob("run-31337-*.jsonl")), "CLI 未写出台账"

    replay = subprocess.run(
        [sys.executable, str(cli), "--seed", "31337", "--auto", "--replay", "--quiet"],
        capture_output=True, text=True, encoding="utf-8", timeout=300, cwd=str(WM_ROOT))
    assert replay.returncode == 0, f"重放退出码 {replay.returncode}\n{replay.stdout}\n{replay.stderr}"
    assert "一致" in replay.stdout and "不一致" not in replay.stdout, replay.stdout[-500:]

    status = subprocess.run(
        [sys.executable, str(cli), "--status"],
        capture_output=True, text=True, encoding="utf-8", timeout=120, cwd=str(WM_ROOT))
    assert status.returncode == 0, status.stderr
    assert "世界模型" in status.stdout and "实体计数" in status.stdout

    bad = subprocess.run(
        [sys.executable, str(cli), "--replay"],
        capture_output=True, text=True, encoding="utf-8", timeout=120, cwd=str(WM_ROOT))
    assert bad.returncode == 2, "--replay 缺少 --seed 应返回 2"
    assert "需要 --seed" in bad.stderr


# ==========================================================================

def main(argv: list[str]) -> int:
    filters = argv[1:]
    selected = [(name, fn) for name, fn in TESTS
                if not filters or any(f in name for f in filters)]
    if not selected:
        print(f"没有匹配的用例（过滤器：{filters}）")
        return 1
    passed, failed = 0, []
    for name, fn in selected:
        ctx = Ctx()
        try:
            fn(ctx)
        except Exception as exc:  # noqa: BLE001 - the harness must report every failure
            failed.append((name, exc, traceback.format_exc()))
            print(f"  FAIL  {name}: {type(exc).__name__}: {exc}")
        else:
            passed += 1
            print(f"  PASS  {name}")
        finally:
            ctx.cleanup()
    print("")
    print(f"用例：{len(selected)}｜通过：{passed}｜失败：{len(failed)}")
    for name, exc, tb in failed:
        print("")
        print(f"--- {name} ---")
        print(tb.strip())
    return 0 if not failed else 1


@test
def attune_gu_mirrors_godot_lifecycle(ctx: Ctx) -> None:
    from engine import rules as R

    wm = WorldModel()
    inst = R.gu_instance(wm, "small_light_gu", "i1")
    inst["state"] = "wild"
    state = {"gu_instances": [inst], "essence": 100}
    out = R.attune_gu(wm, state, "i1")
    assert inst["state"] == "refined", "炼化后应转为 refined"
    assert out["cost"] == 4 and state["essence"] == 96, f"1 转成本应为 4，实际 {out}"

    # 非 wild 拒绝
    rejected = False
    try:
        R.attune_gu(wm, state, "i1")
    except Exception:
        rejected = True
    assert rejected, "已炼化的蛊再次炼化应被拒绝"

    # 真元不足：拒绝且不扣费、状态不变
    inst2 = R.gu_instance(wm, "small_light_gu", "i2")
    inst2["state"] = "wild"
    st2 = {"gu_instances": [inst2], "essence": 0}
    rejected2 = False
    try:
        R.attune_gu(wm, st2, "i2")
    except Exception:
        rejected2 = True
    assert rejected2 and inst2["state"] == "wild" and st2["essence"] == 0, "真元不足时应零副作用拒绝"

    # 高转成本随转数递增，且与 Godot 公式一致
    hi = R.gu_instance(wm, "small_light_gu", "i3")
    hi["instance_rank"] = 5
    hi["state"] = "wild"
    st3 = {"gu_instances": [hi], "essence": 100}
    assert R.attune_gu(wm, st3, "i3")["cost"] == 4 + 2 * (5 - 1) == 12

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))


