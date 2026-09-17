"""自动快照与回滚（约束 v2 / R4）：取代"禁止修改"，改为"改前快照 + 一条命令回滚"。

    python world-model/tools/snapshot.py take <label>   # 改动前拍一张
    python world-model/tools/snapshot.py list           # 列出快照
    python world-model/tools/snapshot.py restore <id> --yes
    python world-model/tools/snapshot.py diff <id>      # 与当前状态比对文件名集合

快照范围：world-model/ 下除 .snapshots/、saves/、runs/、reports/、__pycache__ 外的全部文件。
"""
from __future__ import annotations

import argparse
import datetime
import io
import shutil
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
WM_ROOT = Path(__file__).resolve().parents[1]
SNAP_DIR = WM_ROOT / ".snapshots"
EXCLUDE = {".snapshots", "saves", "runs", "reports", "__pycache__"}


def iter_files(root: Path):
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(root)
        if any(part in EXCLUDE for part in rel.parts):
            continue
        yield rel


def take(label: str) -> int:
    SNAP_DIR.mkdir(exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    dest = SNAP_DIR / f"{ts}-{label or 'snap'}"
    n = 0
    for rel in iter_files(WM_ROOT):
        target = dest / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(WM_ROOT / rel, target)
        n += 1
    (dest / "_MANIFEST.txt").write_text(
        f"label={label}\nfiles={n}\ntaken_at={ts}\n", encoding="utf-8")
    print(f"已快照 {n} 个文件 -> {dest}")
    return 0


def list_snaps() -> int:
    if not SNAP_DIR.exists():
        print("（无快照）")
        return 0
    for d in sorted(SNAP_DIR.iterdir(), reverse=True):
        if d.is_dir():
            m = d / "_MANIFEST.txt"
            print(f"  {d.name:<40} {m.read_text(encoding='utf-8').strip().replace(chr(10), ' | ') if m.exists() else ''}")
    return 0


def find_snap(sid: str) -> Path:
    cands = [d for d in SNAP_DIR.glob(f"*{sid}*") if d.is_dir()] if SNAP_DIR.exists() else []
    if not cands:
        raise SystemExit(f"找不到快照：{sid}")
    return sorted(cands)[-1]


def restore(sid: str, yes: bool) -> int:
    snap = find_snap(sid)
    files = [r for r in iter_files(snap) if str(r) != "_MANIFEST.txt"]
    print(f"将从 {snap.name} 恢复 {len(files)} 个文件到 world-model/")
    if not yes:
        print("（演练模式；加 --yes 真正执行。恢复前建议先 take 一张当前快照）")
        return 0
    for rel in files:
        target = WM_ROOT / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(snap / rel, target)
    print(f"已恢复 {len(files)} 个文件")
    return 0


def diff(sid: str) -> int:
    snap = find_snap(sid)
    old = {r for r in map(str, iter_files(snap)) if r != "_MANIFEST.txt"}
    new = set(map(str, iter_files(WM_ROOT)))
    changed = []
    for rel in sorted(old & new):
        if (snap / rel).read_bytes() != (WM_ROOT / rel).read_bytes():
            changed.append(rel)
    print(f"新增 {len(new - old)} | 删除 {len(old - new)} | 内容变化 {len(changed)}")
    for r in sorted(new - old)[:20]:
        print(f"  + {r}")
    for r in sorted(old - new)[:20]:
        print(f"  - {r}")
    for r in changed[:20]:
        print(f"  ~ {r}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="世界模型快照/回滚")
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("take"); t.add_argument("label", nargs="?", default="")
    sub.add_parser("list")
    r = sub.add_parser("restore"); r.add_argument("id"); r.add_argument("--yes", action="store_true")
    d = sub.add_parser("diff"); d.add_argument("id")
    a = ap.parse_args()
    if a.cmd == "take":
        return take(a.label)
    if a.cmd == "list":
        return list_snaps()
    if a.cmd == "restore":
        return restore(a.id, a.yes)
    return diff(a.id)


if __name__ == "__main__":
    raise SystemExit(main())
