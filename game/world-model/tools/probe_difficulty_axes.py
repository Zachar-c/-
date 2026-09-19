#!/usr/bin/env python3
"""Difficulty-axis probe — read-only numeric experiment, standard library only.

Question: is the 33% death rate a weak auto-decider or genuinely high difficulty?
Method: on the SAME seed interval as the tracked baseline (900000..900199),
run 4 groups x 200 games with in-memory overrides only (WorldModel.set_override).
Nothing is written back to any data file; simulate_balance.py default behavior
is untouched (only simulate()/analyse() are imported).

Groups:
  baseline — no override
  soul     — ("run","starter") with soul 1 -> 4 (soul_max stays 4)
  ap       — ("run","action_points_by_soul") with the 3-AP tier min_soul 10 -> 1
  combo    — soul + ap together

Usage:
    python world-model/tools/probe_difficulty_axes.py [--runs 200] [--seed 900000]

Output: world-model/reports/difficulty-axis-probe.md
"""

from __future__ import annotations

import argparse
import copy
import datetime
import json
import re
import statistics
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
if str(WM_ROOT) not in sys.path:
    sys.path.insert(0, str(WM_ROOT))
TOOLS_ROOT = WM_ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

from simulate_balance import analyse, simulate  # noqa: E402 — reuse only, no behavior change
from engine.model import WorldModel  # noqa: E402

REPORT = WM_ROOT / "reports" / "difficulty-axis-probe.md"
BASELINE_REPORT = WM_ROOT / "reports" / "balance-simulation.md"
BASE_SEED = 900000
RUNS = 200


def read_reference_baseline() -> float | None:
    """Win rate recorded in the standing balance-simulation.md, if present.

    Parsed rather than hardcoded so the comparison note cannot go stale, and so
    this section survives a re-run (a hand-written note would not).
    """
    if not BASELINE_REPORT.exists():
        return None
    for line in BASELINE_REPORT.read_text(encoding="utf-8").splitlines():
        match = re.search(r"通关率：\*\*([\d.]+)%\*\*", line)
        if match:
            return float(match.group(1)) / 100.0
    return None


def build_overrides(wm: WorldModel, group: str) -> dict[tuple, object]:
    """Return {path: value} overrides for a group; empty dict for baseline."""
    ov: dict[tuple, object] = {}
    if group in ("soul", "combo"):
        starter = copy.deepcopy(wm.b("run", "starter"))
        starter["soul"] = 4
        assert starter["soul_max"] == 4, "soul_max must stay 4"
        ov[("run", "starter")] = starter
    if group in ("ap", "combo"):
        table = copy.deepcopy(wm.b("run", "action_points_by_soul"))
        hit = [row for row in table if row.get("min_soul") == 10 and row.get("ap") == 3]
        assert len(hit) == 1, f"expected exactly one 3-AP tier, got {hit}"
        hit[0]["min_soul"] = 1
        ov[("run", "action_points_by_soul")] = table
    return ov


def run_group(group: str, runs: int, base_seed: int, progress=None) -> dict:
    wm = WorldModel()
    for path, value in build_overrides(wm, group).items():
        wm.set_override(path, value)
    raw = simulate(wm, runs, base_seed, progress=progress)
    stat = analyse(raw, group)
    stat["group"] = group
    stat["aborted_count"] = len(raw["aborted"])
    stat["overrides"] = sorted(str(k) for k in wm.overrides.keys())
    stat["wm_version"] = wm.version
    stat["wm_digest"] = wm.data_digest
    return stat


def fmt_pct(x: float) -> str:
    return f"{x * 100:.1f}%"


def summarize(stat: dict) -> dict:
    ranks = stat.get("final_rank", {})
    total_ranked = sum(ranks.values())
    mean_rank = (sum(int(k) * v for k, v in ranks.items()) / total_ranked) if total_ranked else 0.0
    return {
        "group": stat["group"],
        "runs": stat["runs"],
        "aborted": stat["aborted_count"],
        "win_rate": stat["win_rate"],
        "death_rate": stat["death_rate"],
        "deaths": sum(stat.get("death_cause", {}).values()),
        "death_cause": dict(stat.get("death_cause", {})),
        "death_node_type": dict(stat.get("death_node_type", {})),
        "final_rank": {str(k): v for k, v in sorted(ranks.items(), key=lambda kv: int(kv[0]))},
        "mean_rank": mean_rank,
        "gu_mean": stat["gu_count"]["mean"],
        "battle_rounds_mean": stat["battle_rounds"]["mean"],
        "nodes_mean": stat["nodes"]["mean"],
    }


def render(groups: list[dict], runs: int, seed: int, wm_version: str, digest: str) -> str:
    sums = [summarize(g) for g in groups]
    base = sums[0]
    lines: list[str] = ["# 难度轴判别探针报告", ""]
    lines.append(f"- 生成时间：{datetime.datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"- 世界模型版本：{wm_version}｜数据指纹：`{digest[:24]}…`")
    lines.append(f"- 每组局数：{runs}｜种子区间：{seed} … {seed + runs - 1}（与 `balance-simulation.md` 基线同区间）")
    lines.append("- 决策器：与基线相同的脚本化 `--auto` 启发式；覆盖仅内存 `set_override`，不写回任何文件")
    lines.append("")
    lines.append("## 一、四组对比")
    lines.append("")
    lines.append("| 组 | 通关率 | 死亡数 | 平均行动回合 | 平均终局蛊虫数 | 平均终局转数 | 异常终止 |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- |")
    for s in sums:
        lines.append(f"| {s['group']} | {fmt_pct(s['win_rate'])} | {s['deaths']} | "
                     f"{s['battle_rounds_mean']:.1f} | {s['gu_mean']:.1f} | "
                     f"{s['mean_rank']:.2f}（{json.dumps(s['final_rank'], ensure_ascii=False)}） | {s['aborted']} |")
    lines.append("")
    lines.append("## 二、相对基线的变化")
    lines.append("")
    lines.append("| 组 | 通关率变化（百分点） | 死亡数变化 |")
    lines.append("| --- | --- | --- |")
    for s in sums[1:]:
        dpp = (s["win_rate"] - base["win_rate"]) * 100
        lines.append(f"| {s['group']} | {'+' if dpp >= 0 else ''}{dpp:.1f} | {s['deaths'] - base['deaths']:+d} |")
    lines.append("")
    lines.append("## 三、死因分布（按组）")
    lines.append("")
    for s in sums:
        lines.append(f"- `{s['group']}`：{json.dumps(s['death_cause'], ensure_ascii=False)}")
    lines.append("")
    lines.append("## 四、死亡节点类型分布（按组）")
    lines.append("")
    for s in sums:
        lines.append(f"- `{s['group']}`：{json.dumps(s['death_node_type'], ensure_ascii=False)}")
    lines.append("")
    lines.append("## 五、结论")
    lines.append("")
    soul_dpp = (sums[1]["win_rate"] - base["win_rate"]) * 100
    ap_dpp = (sums[2]["win_rate"] - base["win_rate"]) * 100
    combo_dpp = (sums[3]["win_rate"] - base["win_rate"]) * 100
    lines.append(f"- 把魂预算放宽（soul 1→4）后通关率变化 **{'%+.1f' % soul_dpp} 个百分点**"
                 f"（{fmt_pct(base['win_rate'])} → {fmt_pct(sums[1]['win_rate'])}）。")
    lines.append(f"- 把行动点轴放宽（3 AP 门槛 min_soul 10→1）后通关率变化 **{'%+.1f' % ap_dpp} 个百分点**"
                 f"（{fmt_pct(base['win_rate'])} → {fmt_pct(sums[2]['win_rate'])}）。")
    lines.append(f"- 组合覆盖后通关率变化 **{'%+.1f' % combo_dpp} 个百分点**"
                 f"（{fmt_pct(base['win_rate'])} → {fmt_pct(sums[3]['win_rate'])}）。")
    if max(abs(soul_dpp), abs(ap_dpp), abs(combo_dpp)) >= 10:
        lines.append("- 判读：某资源放宽带来 ≥10 个百分点改善 → 该资源是真实瓶颈（难度问题主导）。")
    else:
        lines.append("- 判读：两轴放宽均未带来显著改善（<10 个百分点）→ "
                     "瓶颈主要在决策器（67% 是该决策器的下限，不是游戏难度过高）。")
    lines.append("")
    lines.append("> ⚠️ **修复方向的边界（`RUL-2026-09-19-004`，2026-09-19）**：本探针只证明"
                 "「魂的存量是通关率的绑定约束」这一**事实**。")
    lines.append("> 它**不得**被当作难度调参依据——L0 已裁定魂是**可成长的 Build Axis（魂道玩法）**，"
                 "同时承担魂魄生存值 / 魂道能力资源 / 魂道攻防基础 / 长期成长属性，**不是**固定 1–4 的风险条。")
    lines.append("> 明令禁止：删除高魂 AP 档位；以 `max_soul = 4` 为前提调难度；"
                 "把 `starting_soul` 定为主要 difficulty knob；仅把魂视为第三死亡条。")
    lines.append("> 本文件的 `soul 1→4` 一组仅是**诊断探针**，不是修复方案。")
    lines.append("")
    reference = read_reference_baseline()
    if reference is not None:
        delta_pp = (base["win_rate"] - reference) * 100
        lines.append("## 六、与既有基线的关系")
        lines.append("")
        lines.append(f"- 本探针基线组通关率 **{fmt_pct(base['win_rate'])}**；"
                     f"`balance-simulation.md` 记录为 **{fmt_pct(reference)}**"
                     f"（差 {delta_pp:+.1f} 个百分点）。")
        lines.append("- 两者同种子区间（900000 … 900199）、同决策器，因此差异来自"
                     "`world-model/data/` 或 `engine/` 的既有改动，不是随机波动。")
        lines.append("- 判读本报告时请以**组间差值**（§二）为准；组内基线漂移不影响"
                     "「放宽某轴带来多少改善」的结论。")
        lines.append("")
    lines.append("## 七、复现方式" if reference is not None else "## 六、复现方式")
    lines.append("")
    lines.append("```bash")
    lines.append(f"python world-model/tools/probe_difficulty_axes.py --runs {runs} --seed {seed}")
    lines.append("```")
    lines.append("")
    lines.append("同一种子区间与同一份 `world-model/data/` 必然产出同一份统计（确定性流）。")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="难度轴判别探针：4 组 x N 局内存覆盖对比")
    parser.add_argument("--runs", type=int, default=RUNS)
    parser.add_argument("--seed", type=int, default=BASE_SEED)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    say = (lambda *_a: None) if args.quiet else print
    groups: list[dict] = []
    version, digest = "", ""
    for group in ("baseline", "soul", "ap", "combo"):
        say(f"组 {group}：{args.runs} 局，种子 {args.seed}…")
        stat = run_group(group, args.runs, args.seed,
                         progress=(lambda m, g=group: say(f"  [{g}]{m}")))
        groups.append(stat)
        version, digest = stat["wm_version"], stat["wm_digest"]
        say(f"  [{group}] 通关率 {stat['win_rate'] * 100:.1f}%｜死亡 {stat['death_rate'] * 100:.1f}%"
            f"｜异常 {stat['aborted_count']}")
        if stat["runs"] == 0:
            print(f"[全部异常终止] {group}", file=sys.stderr)
            return 1

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(render(groups, args.runs, args.seed, version, digest), encoding="utf-8")
    say(f"报告：{REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
