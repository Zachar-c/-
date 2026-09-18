#!/usr/bin/env python3
"""World-model balance simulator — standard library only.

用 `--auto` 决策器批量跑局，统计胜率、局时长、构筑分布、卡点与异常终止，并给
「明显失衡项」下结论或标为「待确认项」。

    python world-model/tools/simulate_balance.py --runs 200
    python world-model/tools/simulate_balance.py --runs 60 --hp-mult 2.0   # 灵敏度扫描

输出：world-model/reports/balance-simulation.md
"""

from __future__ import annotations

import argparse
import collections
import datetime
import json
import statistics
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
if str(WM_ROOT) not in sys.path:
    sys.path.insert(0, str(WM_ROOT))

from engine import persistence as ps  # noqa: E402
from engine.errors import WorldModelError  # noqa: E402
from engine.model import WorldModel  # noqa: E402
from engine.run import Run  # noqa: E402

REPORT = WM_ROOT / "reports" / "balance-simulation.md"
BASE_SEED = 900000


def empty_meta() -> dict:
    return {"meta_version": ps.SAVE_VERSION, "codex_known_gu": [], "recipes_unlocked": [],
            "runs_played": 0, "endings": {}, "numeric_growth": {}, "world_model_version": ""}


def simulate(wm: WorldModel, runs: int, base_seed: int, progress=None) -> dict:
    meta = empty_meta()
    records: list[dict] = []
    aborted: list[dict] = []
    for i in range(runs):
        seed = base_seed + i
        run = Run(wm, seed, meta=meta)
        try:
            run.start()
            summary = run.run_to_end()
        except WorldModelError as exc:
            aborted.append({"seed": seed, "error": exc.code, "message": exc.message})
            continue
        except Exception as exc:  # noqa: BLE001 - the report must record, not hide, engine faults
            aborted.append({"seed": seed, "error": type(exc).__name__, "message": str(exc)})
            continue
        records.append(summary)
        if progress and (i + 1) % max(1, runs // 10) == 0:
            progress(f"  ... {i + 1}/{runs}")
    return {"records": records, "aborted": aborted, "meta": meta}


def analyse(result: dict, label: str) -> dict:
    records = result["records"]
    aborted = result["aborted"]
    n = len(records)
    if n == 0:
        return {"label": label, "runs": 0, "aborted": aborted}
    outcomes = collections.Counter(r["outcome"] for r in records)
    wins = outcomes.get("ascended", 0)
    deaths = outcomes.get("death", 0)
    other = n - wins - deaths

    layer_of_death = collections.Counter(r["layer_reached"] for r in records if r["outcome"] == "death")
    node_of_death = collections.Counter(r["last_node_type"] for r in records if r["outcome"] == "death")
    node_of_end = collections.Counter(r["last_node_type"] for r in records if r["outcome"] == "ascended")
    cause_of_death = collections.Counter(r["death_cause"] for r in records if r["outcome"] == "death")
    paths = collections.Counter(r["path"] for r in records)
    mains = collections.Counter(r["main_gu"] for r in records)
    ranks = collections.Counter(r["rank"] for r in records)
    gu_counts = [r["gu_count"] for r in records]
    stone_end = [r["stone"] for r in records]
    hp_end = [r["hp"] for r in records]

    return {
        "label": label,
        "runs": n,
        "aborted": aborted,
        "outcomes": dict(outcomes),
        "win_rate": wins / n,
        "death_rate": deaths / n,
        "other_terminations": other,
        "nodes": {"mean": statistics.fmean(r["nodes_visited"] for r in records),
                  "min": min(r["nodes_visited"] for r in records),
                  "max": max(r["nodes_visited"] for r in records)},
        "battles": {"mean": statistics.fmean(r["battles"] for r in records),
                    "min": min(r["battles"] for r in records),
                    "max": max(r["battles"] for r in records)},
        "battle_rounds": {"mean": statistics.fmean(r["battle_rounds"] for r in records),
                          "min": min(r["battle_rounds"] for r in records),
                          "max": max(r["battle_rounds"] for r in records)},
        "enemy_turns": {"mean": statistics.fmean(r["enemy_turns"] for r in records)},
        "layer_reached": dict(collections.Counter(r["layer_reached"] for r in records)),
        "death_layer": dict(layer_of_death),
        "death_node_type": dict(node_of_death),
        "end_node_type": dict(node_of_end),
        "death_cause": dict(cause_of_death),
        "paths": dict(paths),
        "main_gu_top": mains.most_common(10),
        "main_gu_distinct": len(mains),
        "final_rank": dict(ranks),
        "gu_count": {"mean": statistics.fmean(gu_counts), "min": min(gu_counts), "max": max(gu_counts)},
        "stone_end": {"mean": statistics.fmean(stone_end), "min": min(stone_end), "max": max(stone_end)},
        "hp_end": {"mean": statistics.fmean(hp_end), "min": min(hp_end), "max": max(hp_end)},
    }


def section(lines: list[str], title: str, rows: list[tuple[str, str]]) -> None:
    lines.append(f"### {title}")
    lines.append("")
    lines.append("| 指标 | 数值 |")
    lines.append("| --- | --- |")
    for key, value in rows:
        lines.append(f"| {key} | {value} |")
    lines.append("")


def conclude(base: dict, sensitivity: list[dict], wm: WorldModel) -> list[tuple[str, str, str]]:
    """Return (结论 / 等级 / 依据) rows."""
    out: list[tuple[str, str, str]] = []
    win = base["win_rate"]
    if win >= 0.75:
        out.append(("**明显失衡：通关率过高**（%.1f%%）" % (win * 100), "待用户确认",
                    "自动决策器在默认参数下几乎总能通关；根因是行动经济（每回合 2 念头 × 2 伤害）"
                    "远快于敌人血量（杂兵 3-5 / 层主 22-30），且 5 层共 +100 寿元使寿元轴永不告急。"
                    "调参入口：`balance.json` → `run.action_points_by_soul`、`run.difficulty.enemy_hp_mult`。"))
    elif win <= 0.15:
        out.append(("**明显失衡：通关率过低**（%.1f%%）" % (win * 100), "待用户确认",
                    "自动决策器过于保守或敌人强度偏高；调参入口 `run.difficulty.enemy_hp_mult`。"))
    else:
        out.append(("通关率处于可接受区间（%.1f%%）" % (win * 100), "已缓解",
                    "40%–75% 区间的自动决策通关率对应合理的肉鸽难度带。"))
    if base["death_rate"] and base["death_cause"]:
        top_cause, top_count = max(base["death_cause"].items(), key=lambda kv: kv[1])
        total = sum(base["death_cause"].values())
        share = top_count / total
        if share >= 0.8:
            top_node = max(base["death_node_type"].items(), key=lambda kv: kv[1]) if base["death_node_type"] else ("?", 0)
            out.append((f"**死亡轴单一化**：{share * 100:.0f}% 的死亡来自「{top_cause}」，"
                        f"且集中在 `{top_node[0]}` 节点（{top_node[1]}/{total}）", "待用户确认",
                        "三轴中只有一条真正会在实战中归零，另外两条（气血/寿元）几乎不构成压力。"
                        "调参入口：`events.json` 的 `delayed_soul_cost`、`run.lifespan_milestones`"
                        "（5 层共 +100 寿元 vs 起点 60）。"))
    if base["death_layer"] and len(base["death_layer"]) >= 4:
        counts = list(base["death_layer"].values())
        if max(counts) - min(counts) <= max(1, sum(counts) * 0.08):
            out.append(("**卡点均匀分布**：死亡在第 1–5 层几乎等量出现", "待用户确认",
                        "说明难度曲线是平的：没有「越往后越危险」的递增压力，"
                        "层间唯一变化是敌人血量/伤害与商店加价。"
                        "调参入口：`regions.json` 各层的 `enemy_rank_min/max`、`turn_scaling`、`difficulty`。"))
    if base["final_rank"].get(1, 0) > base["runs"] * 0.2:
        out.append(("**成长不足**：%.1f%% 的通关局停留在 1 转"
                    % (100 * base["final_rank"].get(1, 0) / base["runs"]), "待用户确认",
                    "`balance.run.cultivate_stone_cost`（2 转 5 石）与元石收入相比过低或过高，"
                    "导致转数推进在多数局里不发生。"))
    if base["gu_count"]["mean"] > 12:
        out.append(("**持有蛊虫数量偏高**（均值 %.1f 只）" % base["gu_count"]["mean"], "待用户确认",
                    "原著口径为「一般蛊师通常养四五只同转蛊」（CAN-GU-CARE-001）；"
                    "自动决策器不主动精简构筑，且 `wild_gu`/商店节点无获取上限。"
                    "收紧入口：`loot.tiers[*].gu_chance_pct`、`balance.run.feed_tier`。"))
    if base["stone_end"]["mean"] < 3:
        out.append(("**元石长期见底**（终点均值 %.1f 石）" % base["stone_end"]["mean"], "已缓解",
                    "层预算与掉落产石之间基本平衡，元石是可感的稀缺资源。"))
    if sensitivity:
        best = max(sensitivity, key=lambda r: r["win_rate"])
        worst = min(sensitivity, key=lambda r: r["win_rate"])
        if worst["win_rate"] < base["win_rate"] - 0.1:
            out.append(("**难度旋钮有效**：`enemy_hp_mult` 从 1.0 提到 %s 可把通关率从 %.1f%% 压到 %.1f%%"
                        % ("/".join(str(s["hp_mult"]) for s in sensitivity), base["win_rate"] * 100,
                           worst["win_rate"] * 100), "已缓解",
                        "证明 `balance.json` 是单点可调参数（验收 A5），无需改任何引擎代码。"))
        else:
            out.append(("**难度旋钮灵敏度不足**（最高通关率 %.1f%%）" % (best["win_rate"] * 100), "待用户确认",
                        "单纯提高敌人血量无法改变通关率——说明瓶颈不在 HP，而在行动经济与寿元净正收益。"))
    return out


def render(base: dict, sensitivity: list[dict], wm: WorldModel, runs_requested: int,
           seeds: tuple[int, int]) -> str:
    lines: list[str] = ["# 世界模型平衡模拟报告", ""]
    lines.append(f"- 生成时间：{datetime.datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"- 世界模型版本：{wm.version}｜数据指纹：`{wm.data_digest[:24]}…`")
    lines.append(f"- 请求局数：{runs_requested}｜种子区间：{seeds[0]} … {seeds[1]}")
    lines.append(f"- 决策器：`runner` 的脚本化 `--auto` 启发式（不是人工最优解，也不是随机乱按）")
    lines.append("")

    lines.append("## 一、基线（`balance.json` 默认参数）")
    lines.append("")
    lines.append(f"- 实际完成局数：**{base['runs']}**｜异常终止：**{len(base['aborted'])}**")
    lines.append(f"- 通关率：**{base['win_rate'] * 100:.1f}%**｜死亡：{base['death_rate'] * 100:.1f}%"
                 f"｜其他终止：{base['other_terminations']}")
    lines.append("")
    section(lines, "局时长", [
        ("平均访问节点数", f"{base['nodes']['mean']:.1f}（{base['nodes']['min']}–{base['nodes']['max']}）"),
        ("平均战斗场次", f"{base['battles']['mean']:.1f}（{base['battles']['min']}–{base['battles']['max']}）"),
        ("平均玩家行动回合", f"{base['battle_rounds']['mean']:.1f}（{base['battle_rounds']['min']}–{base['battle_rounds']['max']}）"),
        ("平均敌方回合", f"{base['enemy_turns']['mean']:.1f}"),
        ("终局气血均值", f"{base['hp_end']['mean']:.1f}"),
        ("终局元石均值", f"{base['stone_end']['mean']:.1f}（{base['stone_end']['min']}–{base['stone_end']['max']}）"),
        ("终局蛊虫数均值", f"{base['gu_count']['mean']:.1f}（{base['gu_count']['min']}–{base['gu_count']['max']}）"),
    ])
    section(lines, "结局与终止", [("结局分布", json.dumps(base["outcomes"], ensure_ascii=False)),
                              ("到达层分布", json.dumps(base["layer_reached"], ensure_ascii=False)),
                              ("死亡层分布", json.dumps(base["death_layer"], ensure_ascii=False)),
                              ("死亡节点类型", json.dumps(base["death_node_type"], ensure_ascii=False)),
                              ("死亡原因", json.dumps(base["death_cause"], ensure_ascii=False)),
                              ("通过时的末节点类型", json.dumps(base["end_node_type"], ensure_ascii=False))])
    section(lines, "构筑分布", [("流派分布", json.dumps(base["paths"], ensure_ascii=False)),
                            ("主要蛊 Top 10", "，".join(f"`{g}`×{c}" for g, c in base["main_gu_top"])),
                            ("出现过的不同主蛊数", str(base["main_gu_distinct"])),
                            ("终局转数分布", json.dumps(base["final_rank"], ensure_ascii=False))])

    if sensitivity:
        lines.append("## 二、灵敏度扫描（临时覆盖 `run.difficulty.enemy_hp_mult`）")
        lines.append("")
        lines.append("| enemy_hp_mult | 局数 | 通关率 | 死亡 | 平均行动回合 | 平均终局气血 |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for row in sensitivity:
            lines.append(f"| {row['hp_mult']} | {row['runs']} | {row['win_rate'] * 100:.1f}% | "
                         f"{row['death_rate'] * 100:.1f}% | {row['battle_rounds']['mean']:.1f} | "
                         f"{row['hp_end']['mean']:.1f} |")
        lines.append("")
        lines.append("> 覆盖只存在于内存（`WorldModel.set_override`），不写回任何文件。")
        lines.append("")

    lines.append("## 三、结论与待确认项")
    lines.append("")
    lines.append("| 结论 | 等级 | 依据与调参入口 |")
    lines.append("| --- | --- | --- |")
    for text, level, evidence in conclude(base, sensitivity, wm):
        lines.append(f"| {text} | {level} | {evidence} |")
    lines.append("")

    lines.append("## 四、卡点位置（死亡集中处）")
    lines.append("")
    if base["death_layer"]:
        lines.append("| 层 | 死亡数 | 占死亡比例 |")
        lines.append("| --- | --- | --- |")
        total_deaths = sum(base["death_layer"].values())
        for layer, count in sorted(base["death_layer"].items()):
            lines.append(f"| 第 {layer} 层 | {count} | {count / total_deaths * 100:.0f}% |")
    else:
        lines.append("本批次没有发生死亡，因此没有可统计的卡点层。")
    lines.append("")

    lines.append("## 五、异常终止")
    lines.append("")
    if base["aborted"]:
        lines.append("| 种子 | 错误码 | 说明 |")
        lines.append("| --- | --- | --- |")
        for row in base["aborted"][:50]:
            lines.append(f"| {row['seed']} | `{row['error']}` | {row['message'][:120]} |")
    else:
        lines.append("无异常终止（0 例未捕获异常 / 引擎错误）。")
    lines.append("")

    lines.append("## 六、复现方式")
    lines.append("")
    lines.append("```bash")
    lines.append(f"python world-model/tools/simulate_balance.py --runs {runs_requested}")
    lines.append("```")
    lines.append("")
    lines.append("同一种子区间与同一份 `world-model/data/` 必然产出同一份统计"
                 "（模拟器使用与运行器相同的确定性流）。")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="批量模拟并输出平衡报告")
    parser.add_argument("--runs", type=int, default=200, help="基线局数（默认 200）")
    parser.add_argument("--seed", type=int, default=BASE_SEED, help="起始种子")
    parser.add_argument("--hp-mult", type=float, nargs="*", default=None,
                        help="额外做灵敏度扫描的敌人血量倍率（如 --hp-mult 1.5 2.0）")
    parser.add_argument("--sensitivity-runs", type=int, default=None, help="每个扫描点的局数（默认 --runs 的 1/4）")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    try:
        wm = WorldModel()
    except WorldModelError as exc:
        print(f"[启动失败] {exc.code}: {exc.message} {exc.detail}", file=sys.stderr)
        return 2

    say = (lambda *_a: None) if args.quiet else print
    say(f"世界模型 v{wm.version}（数据指纹 {wm.data_digest[:16]}…）")
    say(f"基线：{args.runs} 局，种子 {args.seed}…")
    base_raw = simulate(wm, args.runs, args.seed, progress=say)
    base = analyse(base_raw, "baseline")
    if base["runs"] == 0 and base_raw["aborted"]:
        sample = base_raw["aborted"][0]
        print(f"[全部异常终止] {sample['error']}: {sample['message']}", file=sys.stderr)
        return 1
    say(f"  通关率 {base['win_rate'] * 100:.1f}%｜死亡 {base['death_rate'] * 100:.1f}%"
        f"｜异常 {len(base['aborted'])}｜平均节点 {base['nodes']['mean']:.1f}")

    sensitivity: list[dict] = []
    if args.hp_mult:
        runs = args.sensitivity_runs or max(20, args.runs // 4)
        for mult in args.hp_mult:
            wm.set_override(("run", "difficulty"), {"enemy_hp_mult": float(mult),
                                                    "enemy_damage_mult": 1.0, "note_zh": "sensitivity sweep"})
            say(f"灵敏度：enemy_hp_mult={mult}，{runs} 局…")
            raw = simulate(wm, runs, args.seed + 500000, progress=None)
            row = analyse(raw, f"hp_mult={mult}")
            row["hp_mult"] = mult
            sensitivity.append(row)
            say(f"  通关率 {row['win_rate'] * 100:.1f}%｜平均行动回合 {row['battle_rounds']['mean']:.1f}")
        wm.clear_overrides()

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(render(base, sensitivity, wm, args.runs,
                             (args.seed, args.seed + args.runs - 1)), encoding="utf-8")
    say(f"报告：{REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
