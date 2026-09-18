#!/usr/bin/env python3
"""《蛊真人》肉鸽世界模型 · 可玩命令行运行器

零第三方依赖、纯离线、不依赖 Godot。

用法
----
    python world-model/runner/cli.py --seed 101            # 交互式打一局（stdin 逐行命令）
    python world-model/runner/cli.py --seed 101 --auto     # 无人值守自动打一局并落盘
    python world-model/runner/cli.py --seed 101 --auto --replay   # 重放并比对台账
    python world-model/runner/cli.py --status              # 打印当前存档摘要
    python world-model/runner/cli.py                        # 大厅（可新开一局 / 继承图鉴继续）

交互命令（任意位置可用）
    help / ?            帮助
    status              当前状态
    map                 本层地图
    save                立即存档
    1..9                选择列表中对应序号
    next / n            继续前进
    skip                跳过当前节点
    quit / q            保存并退出到大厅
"""

from __future__ import annotations

import argparse
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

HELP = """命令：
  help / ?            显示本帮助
  status              打印当前状态
  map                 打印本层地图
  save                立即存档
  <数字>              选择列表中该序号
  act <id>            直接执行某个操作 id（如 act basic_attack）
  next / n            继续前进（结束当前节点）
  skip                跳过当前节点
  quit / q            保存并退回大厅
"""


class Cli:
    def __init__(self, wm: WorldModel, seed: int, auto: bool = False, quiet: bool = False):
        self.wm = wm
        self.seed = int(seed)
        self.auto = auto
        self.quiet = quiet
        self.meta = ps.load_meta()
        self.run: Run | None = None
        self.ledger_path: Path | None = None

    # ------------------------------------------------------------------ io
    def say(self, text: str = "") -> None:
        if not self.quiet:
            print(text)

    # --------------------------------------------------------------- status
    def status_lines(self) -> list[str]:
        if self.run is None:
            return ["尚未开局。"]
        st = self.run.state
        lines = [
            f"种子 {self.seed}｜{st['status']}｜第 {st['layer']} 层 第 {st['row'] + 1} 行"
            f"｜已访 {st['nodes_visited']} 节点｜战斗 {st['battles']} 场 / {st['battle_rounds']} 回合",
            f"气血 {st['hp']}/{st['hp_max']}｜寿元 {st['lifespan']}/{st['lifespan_max']}"
            f"｜魂 {st['soul']}/{st['soul_max']}｜真元 {st['essence']}/{st['essence_max']}"
            f"｜元石 {st['stone']}｜恶名 {st['notoriety']}",
            f"{st['rank']} 转 {st['stage']}（{st['aptitude']} 等）｜{self.wm.paths[st['path']]['name_zh']}"
            f"｜在世蛊虫 {len([i for i in st['gu_instances'] if i.get('alive', True)])} 只",
        ]
        return lines

    def print_status(self) -> None:
        for line in self.status_lines():
            self.say(line)

    def print_map(self) -> None:
        if self.run is None:
            return
        layer = self.run.state["map"]["layers"][self.run.state["layer"] - 1]
        self.say(f"—— 第 {layer['layer']} 层 {layer['name_zh']} ——")
        for row in layer["rows"]:
            mark = "→" if row["index"] == self.run.state["row"] else " "
            self.say(f" {mark} 行 {row['index'] + 1:>2}: " + " ".join(row["nodes"]))

    # ---------------------------------------------------------------- lobby
    def lobby(self) -> int:
        if ps.run_save_exists():
            try:
                payload = ps.load_run()
                self.say(f"检测到进行中的存档：{payload.get('status')}，"
                         f"第 {payload.get('layer')} 层（种子 {payload.get('seed')}）。")
                self.say("开新局会放弃这份存档（本局资源与构筑清零，只保留图鉴）。")
                if not self._confirm("放弃并进行新局？"):
                    return self.resume()
            except WorldModelError as exc:
                self.say(f"存档读取失败：{exc.message}")
        return self.start_new_run()

    def _confirm(self, question: str) -> bool:
        if self.auto:
            return True
        try:
            answer = input(f"{question} [y/N] ").strip().lower()
        except EOFError:
            return False
        return answer in ("y", "yes", "是", "1")

    def start_new_run(self) -> int:
        self.run = Run(self.wm, self.seed, meta=self.meta)
        self.run.start()
        self.say(f"开局：丙等一转散修（固定身份），携小光蛊一只。种子 {self.seed}。")
        self.say(f"世界模型 v{self.wm.version}｜数据指纹 {self.wm.data_digest[:16]}…")
        return self.play()

    def resume(self) -> int:
        payload = ps.load_run()
        self.run = Run(self.wm, int(payload["seed"]), meta=self.meta)
        self.run.seed = int(payload["seed"])
        self.run.state = {k: v for k, v in payload.items() if k != "_map"}
        self.run.state["map"] = payload.get("_map", {})
        self.run._streams = {}
        self.ledger_path = Path(payload["ledger_path"]) if payload.get("ledger_path") else None
        self.say(f"已恢复种子 {payload['seed']} 的第 {payload['layer']} 层进度。")
        return self.play()

    # ----------------------------------------------------------------- play
    def play(self) -> int:
        assert self.run is not None
        while self.run.state["status"] == "active":
            if self.auto:
                action = self.run.auto_step()
                if action is None:
                    break
                continue
            if not self.prompt():
                break
        return self.finish()

    def prompt(self) -> bool:
        """One interactive step. Returns False to leave the loop."""
        run = self.run
        assert run is not None
        in_battle = bool(run.state.get("battle") and run.state["battle"]["active"])
        picking_node = (not in_battle) and run.state["node_taken"] is None
        if in_battle:
            self._render_battle()
            options = [{**a, "label": a["label_zh"]} for a in run.node_actions()]
        elif picking_node:
            self._render_node()
            options = [{**o, "label": f"{o['template']}（{'Boss' if o['is_boss'] else o['type']}）"
                                     f"{o['summary_zh']}"}
                       for o in run.row_options()]
        else:
            self._render_node()
            options = [{**a, "label": a["label_zh"]} for a in run.node_actions()]
        for i, opt in enumerate(options, 1):
            self.say(f"  [{i}] {opt['label']}")
        try:
            raw = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            self.say("（输入结束，保存并退出）")
            return False
        return self.dispatch(raw, options, picking_node)

    def dispatch(self, raw: str, options: list[dict], picking_node: bool = False) -> bool:
        run = self.run
        assert run is not None
        if not raw:
            return True
        lowered = raw.lower()
        if lowered in ("quit", "q", "exit"):
            self.say("保存并退回大厅。")
            return False
        if lowered in ("help", "?", "h"):
            self.say(HELP)
            return True
        if lowered == "status":
            self.print_status()
            return True
        if lowered == "map":
            self.print_map()
            return True
        if lowered == "save":
            self.save()
            return True
        if lowered in ("next", "n"):
            self._apply("next")
            return True
        action_id = None
        if raw.isdigit():
            index = int(raw)
            if not 1 <= index <= len(options):
                self.say(f"序号超出范围：本处共 {len(options)} 个选项。")
                return True
            node_options = run.row_options()
            if picking_node and node_options:
                run.choose_node(index - 1)
                self.say(f"→ 进入节点 {node_options[index - 1]['template']}"
                         f"（{node_options[index - 1]['type']}）")
                return True
            action_id = options[index - 1]["id"]
        elif lowered.startswith("act "):
            action_id = raw[4:].strip()
        elif lowered.startswith("gu:"):
            action_id = raw
        elif lowered.startswith("gu_force:"):
            action_id = raw
        else:
            # allow short ids and the `gu_force` alias to fall through to the option list
            for opt in options:
                if opt.get("id") == raw or opt.get("force_id") == raw:
                    action_id = opt.get("id")
                    break
        if action_id is None:
            if picking_node:
                self.say("请输入节点序号（或 help 查看命令）。")
            else:
                self.say(f"无法识别的命令 {raw!r}（可用：help / status / map / save / 数字 / next / skip / quit）。")
            return True
        self._apply(action_id)
        return True

    def _apply(self, action_id: str) -> None:
        run = self.run
        assert run is not None
        try:
            for line in run.apply_action(action_id):
                self.say("  " + line)
        except WorldModelError as exc:
            self.say(f"  [无法执行] {exc.message}")
        except ValueError as exc:
            self.say(f"  [无法执行] {exc}")

    def _render_node(self) -> None:
        run = self.run
        assert run is not None
        if run.state["node_taken"] is None:
            row = run.current_row()
            if row is None:
                self.say("（本层已走完）")
                return
            self.say(f"\n=== 第 {run.state['layer']} 层 · 第 {run.state['row'] + 1} 行"
                     f"（{len(row['nodes'])} 个去处）===")
        else:
            template = run._template(run.state["node_taken"])
            self.say(f"\n=== 节点 {template['id']}（{template.get('type_zh', template['type'])}）===")
        self.print_status()

    def _render_battle(self) -> None:
        run = self.run
        assert run is not None
        battle = run.state["battle"]
        enemy = battle["enemy"]
        intent = enemy["intent"]
        self.say(f"\n=== 交锋：{enemy['name_zh']}（{enemy['tier']}，{enemy['rank']} 转）===")
        self.say(f"  敌方气血 {max(0, enemy['hp'])}/{enemy['hp_max']}｜意图「{intent.get('label', '')}」"
                 f"伤害 {intent.get('damage', 0)}｜护盾 {battle.get('shield', 0)}")
        self.say(f"  我方 气血 {run.state['hp']}/{run.state['hp_max']}｜真元 {run.state['essence']}"
                 f"｜念头 {run.state['thoughts']}")

    # --------------------------------------------------------------- finish
    def save(self) -> None:
        if self.run is None:
            return
        self.ledger_path = ps.write_ledger(self.run, self.wm.version)
        ps.save_run(self.run.state, ledger_path=str(self.ledger_path))
        if self.run.state["status"] != "active":
            ps.save_meta(self.meta)
            ps.delete_run()
        if not self.quiet:
            self.say(f"已存档（台账 {self.ledger_path.name}）。")

    def finish(self) -> int:
        run = self.run
        assert run is not None
        if run.state["status"] == "active":
            self.save()
            return 0
        summary = run.summary()
        self.ledger_path = ps.write_ledger(run, self.wm.version)
        ps.save_meta(self.meta)
        ps.delete_run()
        self.say("\n================ 结算 ================")
        outcome_zh = {"death": "身死道消", "ascended": "通关（登临蛊仙之窗）", "aborted": "运行中止"}.get(
            summary["outcome"], summary["outcome"])
        self.say(f"结局：{outcome_zh}"
                 + (f"（{summary['death_cause']}）" if summary["death_cause"] else ""))
        self.say(f"到达：第 {summary['layer_reached']} 层 第 {summary['row_in_layer'] + 1} 行")
        self.say(f"节点 {summary['nodes_visited']} 个｜战斗 {summary['battles']} 场"
                 f"／{summary['battle_rounds']} 回合｜最后节点 {summary['last_node']}（{summary['last_node_type']}）")
        self.say(f"终局：{summary['rank']} 转 {summary['aptitude']} 等｜蛊虫 {summary['gu_count']} 只"
                 f"｜气血 {summary['hp']}｜寿元 {summary['lifespan']}｜魂 {summary['soul']}｜元石 {summary['stone']}")
        self.say(f"台账：{self.ledger_path}")
        self.say(f"台账内容哈希 content_sha256 = {summary['content_sha256']}")
        # hall totals are printed, never written into the run ledger
        self.say(f"本局新增图鉴 {summary.get('run_codex_count', '?')} 只蛊 / 配方 {summary.get('run_recipe_count', '?')} 条")
        self.say(f"大厅累计 {len(self.meta['codex_known_gu'])} 只蛊 / 配方 {len(self.meta['recipes_unlocked'])} 条"
                 f"（跨局只保留知识，零永久数值成长）")
        return 0


# ==========================================================================
# replay
# ==========================================================================

def replay(seed: int, quiet: bool = False) -> int:
    wm = WorldModel()
    existing = ps.find_ledgers(seed)
    previous = ps.read_ledger(existing[-1]) if existing else None
    run = Run(wm, seed, meta={"codex_known_gu": [], "recipes_unlocked": [], "runs_played": 0,
                              "endings": {}, "numeric_growth": {}})
    run.start()
    run.run_to_end()
    content_sha256 = run.content_sha256()
    if not quiet:
        print(f"重放种子 {seed}：content_sha256 = {content_sha256}")
    if previous is None:
        path = ps.write_ledger(run, wm.version)
        if not quiet:
            print(f"没有历史台账可比对；已写出 {path.name}")
        return 0
    identical = previous["content_sha256"] == content_sha256
    if not quiet:
        print(f"历史台账 {existing[-1].name}：content_sha256 = {previous['content_sha256']}")
    # The verdict is always printed: it is the whole point of --replay.
    if identical:
        print(f"比对结果：一致（同种子逐字节可复现）｜content_sha256 = {content_sha256}")
    else:
        print(f"比对结果：不一致 —— 存在非确定性！prev={previous['content_sha256']} new={content_sha256}")
        for i, (a, b) in enumerate(zip(previous["body_lines"], run.ledger_body().splitlines())):
            if a != b:
                print(f"  首个不同行 #{i}:")
                print(f"    prev: {a[:200]}")
                print(f"    new : {b[:200]}")
                break
        print(f"  行数 prev={len(previous['body_lines'])} new={len(run.ledger_body().splitlines())}")
    path = ps.write_ledger(run, wm.version)
    if not quiet:
        print(f"本次台账：{path}")
    return 0 if identical else 1


def status() -> int:
    print(f"世界模型：{WM_ROOT}")
    try:
        wm = WorldModel()
    except WorldModelError as exc:
        print(f"[世界模型不可用] {exc.message} {exc.detail}")
        return 1
    summary = wm.summary()
    print(f"版本 {summary['version']}｜数据指纹 {summary['data_digest'][:24]}…｜schema 检查 {summary['schema_checks']} 条")
    print("实体计数：" + "，".join(f"{k}={v}" for k, v in summary["counts"].items()))
    print("蛊虫效果来源：" + "，".join(f"{k}={v}" for k, v in summary["gu_effect_sources"].items()))
    print("——")
    payload, note = ps.recover_run()
    if note:
        print(note)
    if payload:
        print(f"进行中存档：种子 {payload['seed']}｜{payload['status']}｜第 {payload['layer']} 层"
              f"｜已访 {payload['nodes_visited']} 节点｜战斗 {payload['battles']} 场")
        print(f"  气血 {payload['hp']}/{payload['hp_max']}｜寿元 {payload['lifespan']}"
              f"｜魂 {payload['soul']}｜元石 {payload['stone']}｜{payload['rank']} 转")
        print(f"  台账：{payload.get('ledger_path', '')}")
    try:
        meta = ps.load_meta()
    except WorldModelError as exc:
        print(f"[大厅存档不可用] {exc.message}")
        return 1
    print(f"大厅：累计 {meta['runs_played']} 局｜图鉴 {len(meta['codex_known_gu'])} 只蛊"
          f"｜已解锁配方 {len(meta['recipes_unlocked'])} 条｜结局分布 {meta['endings']}")
    ledgers = sorted(ps.RUN_DIR.glob("run-*.jsonl")) if ps.RUN_DIR.exists() else []
    print(f"台账文件：{len(ledgers)} 个（{ps.RUN_DIR}）")
    return 0


# ==========================================================================
# main
# ==========================================================================

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="《蛊真人》肉鸽世界模型命令行运行器")
    parser.add_argument("--seed", type=int, default=None, help="本局种子")
    parser.add_argument("--auto", action="store_true", help="无人值守自动打完整局")
    parser.add_argument("--replay", action="store_true", help="按种子重放并与历史台账比对")
    parser.add_argument("--status", action="store_true", help="打印存档与大厅摘要后退出")
    parser.add_argument("--seed-count", type=int, default=1, help="连打多少局（不同派生种子）")
    parser.add_argument("--quiet", action="store_true", help="静默模式（只输出结算）")
    args = parser.parse_args(argv)

    try:
        if args.status:
            return status()
        if args.replay:
            if args.seed is None:
                print("--replay 需要 --seed", file=sys.stderr)
                return 2
            return replay(args.seed, quiet=args.quiet)
        wm = WorldModel()
    except WorldModelError as exc:
        print(f"[启动失败] {exc.code}: {exc.message} {exc.detail}", file=sys.stderr)
        return 2

    if args.seed is None:
        cli = Cli(wm, 0, auto=False)
        return cli.lobby()

    code = 0
    for offset in range(max(1, args.seed_count)):
        seed = int(args.seed) + offset
        cli = Cli(wm, seed, auto=args.auto, quiet=args.quiet and args.seed_count > 1)
        cli.meta = ps.load_meta()
        code = cli.start_new_run() if args.auto or args.seed_count == 1 else cli.start_new_run()
        cli.say("")
    return code


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\n已中断。")
        raise SystemExit(130)
