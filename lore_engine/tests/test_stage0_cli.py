from __future__ import annotations

import copy
import io
import json
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from lore_engine import cli
from lore_engine.src.reports import build_world_baseline_report


ROOT = Path(__file__).resolve().parents[2]
GENERATED_AT = "2026-09-16T00:00:00Z"


class Stage0CliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.real_report = build_world_baseline_report(
            ROOT, generated_at_utc=GENERATED_AT
        )

    def _run(self, *args: str) -> tuple[int, str, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = cli.main(list(args))
        return code, stdout.getvalue(), stderr.getvalue()

    def _conditional_report(self) -> dict[str, object]:
        report = copy.deepcopy(self.real_report)
        for index, row in enumerate(report["claims"]):
            row["evidence"] = [
                {
                    "evidence_id": f"verified-{index:02d}",
                    "source_file_id": "gu_zhenren_main",
                    "source_ref": f"fixture:{index}",
                    "char_start": index,
                    "char_end": index + 1,
                    "authority": "primary_text",
                    "evidence_kind": "support",
                }
            ]
            row["effective_ruling"] = "retain"
            row["resolution_status"] = "not_required"
            row["unknowns"] = []
        report["claims"].append(
            {
                **copy.deepcopy(report["claims"][0]),
                "claim_id": "non_blocking_follow_up",
                "topic": "non_blocking_follow_up",
                "impact": "medium",
                "effective_ruling": "defer",
                "evidence": [],
                "source_fact": [],
                "unknowns": ["Deferred non-blocking review."],
            }
        )
        report["unresolved_high_impact"] = []
        return report

    def _init_git_repo(self, root: Path) -> str:
        subprocess.run(("git", "init", "-q"), cwd=root, check=True)
        subprocess.run(("git", "config", "user.name", "Stage0 Test"), cwd=root, check=True)
        subprocess.run(
            ("git", "config", "user.email", "stage0@example.invalid"),
            cwd=root,
            check=True,
        )
        (root / "README.md").write_text("baseline\n", encoding="utf-8")
        subprocess.run(("git", "add", "README.md"), cwd=root, check=True)
        subprocess.run(("git", "commit", "-q", "-m", "baseline"), cwd=root, check=True)
        return subprocess.run(
            ("git", "rev-parse", "HEAD"),
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

    def _commit_file(self, root: Path, relative: str, content: str) -> None:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        subprocess.run(("git", "add", relative), cwd=root, check=True)
        subprocess.run(("git", "commit", "-q", "-m", f"add {relative}"), cwd=root, check=True)

    def _real_commit_other_than_the_frozen_baseline(self) -> str:
        # The frozen constant is the boundary; any *other* real commit must be
        # rejected as the configured baseline, HEAD included. Walk back from HEAD
        # so the candidate differs even when HEAD happens to *be* the frozen
        # baseline - which is exactly the case while the pin points at the last
        # production commit and the Stage 0 work itself is not committed yet.
        for revision in ["HEAD"] + [f"HEAD~{step}" for step in range(1, 6)]:
            resolved = subprocess.run(
                ("git", "rev-parse", "--verify", revision),
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            if resolved.returncode != 0:
                break
            sha = resolved.stdout.strip()
            if sha != cli.PRE_STAGE0_BASELINE_COMMIT:
                return sha
        raise AssertionError("no real commit outside the frozen Stage 0 baseline")

    def test_world_model_0_returns_conditional_go_and_writes_only_output_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp) / "stage0"
            with (
                patch("lore_engine.cli.build_world_baseline_report", return_value=self._conditional_report()),
                patch("lore_engine.cli._git_changed_paths", return_value=()),
            ):
                code, stdout, stderr = self._run(
                    "world-model-0",
                    "--config",
                    "lore_engine/config/world-model-stage0.json",
                    "--out",
                    str(output_dir),
                    "--generated-at-utc",
                    GENERATED_AT,
                )

            self.assertEqual(code, 0, stderr)
            self.assertEqual(json.loads(stdout)["result"], "CONDITIONAL_GO")
            self.assertEqual(
                sorted(path.name for path in output_dir.iterdir()),
                [
                    "world-model-baseline-v1.json",
                    "world-model-baseline-v1.md",
                    "world-model-stage0-gate.md",
                ],
            )

    def test_world_model_0_returns_go_for_finalized_benchmark(self) -> None:
        # The benchmark ledger is finalized (all 24 high-impact claims carry a
        # final ruling backed by verified P0 citations), so the live gate must
        # report GO with a success exit code. A regression that reverts any
        # claim to a preliminary/needs_evidence state fails this guard.
        with tempfile.TemporaryDirectory() as tmp:
            with (
                patch("lore_engine.cli.build_world_baseline_report", return_value=copy.deepcopy(self.real_report)),
                patch("lore_engine.cli._git_changed_paths", return_value=()),
            ):
                code, stdout, stderr = self._run(
                    "world-model-0", "--out", tmp, "--generated-at-utc", GENERATED_AT
                )

        self.assertEqual(code, 0, stderr)
        self.assertEqual(json.loads(stdout)["result"], "GO")

    def test_world_model_0_missing_config_is_input_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, _stdout, stderr = self._run(
                "world-model-0",
                "--config",
                "lore_engine/config/does-not-exist.json",
                "--out",
                tmp,
            )

        self.assertEqual(code, 2)
        self.assertIn("does-not-exist.json", stderr)

    def test_world_model_0_missing_source_is_input_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch(
                "lore_engine.cli.build_world_baseline_report",
                side_effect=FileNotFoundError("missing-primary.txt"),
            ):
                code, _stdout, stderr = self._run("world-model-0", "--out", tmp)

        self.assertEqual(code, 2)
        self.assertIn("missing-primary.txt", stderr)

    def test_world_model_0_forbidden_production_diff_always_fails_gate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with (
                patch("lore_engine.cli.build_world_baseline_report", return_value=self._conditional_report()),
                patch("lore_engine.cli._git_changed_paths", return_value=("data/gu.json",)),
                patch("lore_engine.cli._production_diff_mentions_legacy", return_value=False),
            ):
                code, stdout, stderr = self._run(
                    "world-model-0", "--out", tmp, "--generated-at-utc", GENERATED_AT
                )

            gate = (Path(tmp) / "world-model-stage0-gate.md").read_text(encoding="utf-8")

        self.assertEqual(code, 3, stderr)
        self.assertEqual(json.loads(stdout)["result"], "NO_GO")
        self.assertIn("data/gu.json", gate)

    def test_git_baseline_detects_committed_forbidden_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = self._init_git_repo(root)
            self._commit_file(root, "scripts/domain/forbidden.gd", "extends RefCounted\n")

            changed = cli._git_changed_paths(root, baseline)

        self.assertIn("scripts/domain/forbidden.gd", changed)

    def test_weakened_config_denylist_cannot_allow_committed_production_change(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = self._init_git_repo(root)
            self._commit_file(root, "data/gu.json", "{}\n")
            changed = cli._git_changed_paths(root, baseline)

        config = json.loads(
            (ROOT / "lore_engine/config/world-model-stage0.json").read_text(encoding="utf-8")
        )
        config["production_write_denylist"] = []
        gate = cli._evaluate_stage0_gate(
            self._conditional_report(),
            config,
            changed,
            deterministic=True,
            q8g_f1_production_change=False,
        )

        self.assertEqual(gate["result"], "NO_GO")
        self.assertEqual(gate["production_paths_changed"], ["data/gu.json"])

    def test_duplicate_configured_topics_do_not_inflate_coverage(self) -> None:
        config = json.loads(
            (ROOT / "lore_engine/config/world-model-stage0.json").read_text(encoding="utf-8")
        )
        config["high_impact_claim_ids"][-1] = config["high_impact_claim_ids"][0]

        gate = cli._evaluate_stage0_gate(
            self._conditional_report(),
            config,
            (),
            deterministic=True,
            q8g_f1_production_change=False,
        )

        self.assertEqual(gate["result"], "NO_GO")
        self.assertEqual(gate["target_topic_count"], 23)
        self.assertEqual(gate["high_impact_covered"], 23)
        self.assertIn("configured unique target topic count 23 != 24", gate["blockers"])

    def test_invalid_configured_baseline_is_input_error(self) -> None:
        config = json.loads(
            (ROOT / "lore_engine/config/world-model-stage0.json").read_text(encoding="utf-8")
        )
        config["pre_stage0_baseline_commit"] = "f" * 40
        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "stage0.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            code, _stdout, stderr = self._run(
                "world-model-0",
                "--config",
                str(config_path),
                "--out",
                str(Path(tmp) / "out"),
            )

        self.assertEqual(code, 2)
        self.assertIn("pre-Stage-0 baseline", stderr)

    def test_configured_baseline_cannot_move_forward_to_head(self) -> None:
        config = json.loads(
            (ROOT / "lore_engine/config/world-model-stage0.json").read_text(encoding="utf-8")
        )
        config["pre_stage0_baseline_commit"] = self._real_commit_other_than_the_frozen_baseline()
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            config_path = Path(tmp) / "stage0.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            code, _stdout, stderr = self._run(
                "world-model-0",
                "--config",
                str(config_path),
                "--out",
                str(Path(tmp) / "out"),
            )

        self.assertEqual(code, 2)
        self.assertIn("fixed pre-Stage-0 baseline", stderr)

    def test_non_ancestor_baseline_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = self._init_git_repo(root)
            subprocess.run(("git", "checkout", "-q", "--orphan", "unrelated"), cwd=root, check=True)
            (root / "README.md").write_text("unrelated\n", encoding="utf-8")
            subprocess.run(("git", "add", "README.md"), cwd=root, check=True)
            subprocess.run(("git", "commit", "-q", "-m", "unrelated"), cwd=root, check=True)

            with self.assertRaisesRegex(ValueError, "not an ancestor of HEAD"):
                cli._git_changed_paths(root, baseline)


if __name__ == "__main__":
    unittest.main()
