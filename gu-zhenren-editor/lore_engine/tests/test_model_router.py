from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from lore_engine.src.contracts import ChunkRecord
from lore_engine.src.model_router import DisabledBackend, FixtureBackend, ModelRouter, build_model_task


class ModelRouterTests(unittest.TestCase):
    def test_fixture_is_cached_and_disabled_isolated(self) -> None:
        chunk = ChunkRecord("V01-C001-S01", "V01-C001", "fixture", 1, 1, "测试", 1, 1, 0, 4, 0, 12, "月光蛊证据", "hash")
        task = build_model_task(chunk, {})
        with tempfile.TemporaryDirectory() as tmp:
            router = ModelRouter(FixtureBackend(), cache_dir=Path(tmp))
            first = router.run(task)
            second = router.run(task)
            self.assertEqual(first.status, "SUCCESS")
            self.assertEqual(second.status, "SUCCESS")
            self.assertEqual(second.elapsed_ms, 0)
            self.assertEqual(first.output, second.output)
        disabled = ModelRouter(DisabledBackend()).run(task)
        self.assertEqual(disabled.status, "ISOLATED")
        self.assertEqual(disabled.error_code, "backend_disabled")

    def test_fixture_output_contains_current_chunk_evidence(self) -> None:
        chunk = ChunkRecord("V01-C001-S01", "V01-C001", "fixture", 1, 1, "测试", 1, 1, 0, 4, 0, 12, "月光蛊证据", "hash")
        result = ModelRouter(FixtureBackend()).run(build_model_task(chunk, {}))
        self.assertEqual(result.output["facts"][0]["source_quote"], "月光蛊证据")
        self.assertEqual(result.output["facts"][0]["chunk_id"], chunk.chunk_id)


if __name__ == "__main__":
    unittest.main()
