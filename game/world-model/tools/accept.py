"""一键验收（约束 v2 / R2、R6）：校验 + 测试 + 冒烟跑局，退出码即结论。

    python world-model/tools/accept.py           # 默认冒烟 10 局
    python world-model/tools/accept.py --smoke 30

退出码：0 = 全绿；1 = 有失败项。
"""
from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
PY = sys.executable


def run(label: str, argv: list[str]) -> tuple[bool, str, float]:
    t0 = time.time()
    proc = subprocess.run(argv, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(WM_ROOT))
    dt = time.time() - t0
    out = (proc.stdout or "") + (proc.stderr or "")
    tail = [ln for ln in out.splitlines() if ln.strip()][-1:] or [""]
    return proc.returncode == 0, tail[0].strip(), dt


def smoke(runs: int) -> tuple[bool, str, float]:
    t0 = time.time()
    sys.path.insert(0, str(WM_ROOT))
    from engine import persistence as ps
    from engine.model import WorldModel
    from engine.run import Run

    wm = WorldModel()
    meta = {"meta_version": ps.SAVE_VERSION, "codex_known_gu": [], "recipes_unlocked": [],
            "runs_played": 0, "endings": {}, "numeric_growth": {}, "world_model_version": ""}
    ok = aborted = 0
    for i in range(runs):
        r = Run(wm, 880000 + i, meta=meta)
        try:
            r.start()
            s = r.run_to_end()
            ok += 1 if s.get("outcome") in ("death", "ascended") else 0
        except Exception:  # noqa: BLE001
            aborted += 1
    dt = time.time() - t0
    passed = ok == runs and aborted == 0
    return passed, f"{ok}/{runs} 局走到结算，异常终止 {aborted}", dt


def main() -> int:
    ap = argparse.ArgumentParser(description="世界模型一键验收")
    ap.add_argument("--smoke", type=int, default=10, help="冒烟跑局数（默认 10）")
    args = ap.parse_args()

    checks = [
        ("1 数据校验（schema/引用/数值/环）", lambda: run("validate", [PY, str(WM_ROOT / "tools" / "validate_world_model.py")])),
        ("2 测试套件（断言式，全量）", lambda: run("tests", [PY, str(WM_ROOT / "tests" / "run_tests.py")])),
        (f"3 冒烟跑局（{args.smoke} 局）", lambda: smoke(args.smoke)),
    ]

    print("=" * 66)
    print("世界模型一键验收 —— 约束体系 v2（R2 / R6）")
    print("=" * 66)
    all_ok = True
    for label, fn in checks:
        ok, detail, dt = fn()
        all_ok &= ok
        print(f"  [{'PASS' if ok else 'FAIL'}] {label:<34} {dt:5.1f}s  {detail}")
    print("-" * 66)
    print(f"结论：{'全绿，可提交' if all_ok else '有失败项，不可提交'}（退出码 {0 if all_ok else 1}）")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
