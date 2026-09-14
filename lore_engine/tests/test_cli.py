from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(ROOT)
    return subprocess.run(
        [sys.executable, "-m", "lore_engine.cli", *args],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


class CliTests(unittest.TestCase):
    def test_help_lists_v1_commands(self) -> None:
        result = run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        for command in ("ingest", "index", "run", "retry", "validate", "report"):
            self.assertIn(command, result.stdout)

    def test_unknown_command_is_configuration_error(self) -> None:
        result = run_cli("unknown")
        self.assertEqual(result.returncode, 2)

    def test_version_does_not_read_the_corpus(self) -> None:
        result = run_cli("--version")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "1.0.0")


if __name__ == "__main__":
    unittest.main()
