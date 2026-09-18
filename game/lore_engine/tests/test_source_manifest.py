from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from lore_engine.src.source_manifest import (
    SourceFingerprintError,
    SourcePathError,
    SourceSpec,
    fingerprint_source,
    read_source,
)


class SourceManifestTests(unittest.TestCase):
    def test_reads_strict_utf8_and_reports_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "source.txt"
            payload = "第一行\r\n第二行"
            path.write_bytes(payload.encode("utf-8"))
            spec = SourceSpec(
                source_file_id="fixture",
                path="source.txt",
                encoding="utf-8",
                authority="primary_text",
                default_claim_type="CANON",
                expected_sha256=hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            )

            before = path.stat()
            self.assertEqual(read_source(root, spec), payload)
            fingerprint = fingerprint_source(root, spec)
            after = path.stat()

            self.assertEqual(fingerprint.bytes, len(path.read_bytes()))
            self.assertEqual(fingerprint.characters, len(payload))
            self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)

    def test_wrong_encoding_is_rejected_strictly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "gb.txt"
            path.write_bytes("人祖传".encode("gb18030"))
            spec = SourceSpec(
                source_file_id="fixture",
                path="gb.txt",
                encoding="utf-8",
                authority="in_world_text",
                default_claim_type="IN_WORLD_LORE",
                expected_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            )
            with self.assertRaises(UnicodeDecodeError):
                read_source(root, spec)

    def test_hash_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "source.txt").write_text("unchanged", encoding="utf-8")
            spec = SourceSpec(
                source_file_id="fixture",
                path="source.txt",
                encoding="utf-8",
                authority="primary_text",
                default_claim_type="CANON",
                expected_sha256="0" * 64,
            )
            with self.assertRaises(SourceFingerprintError):
                fingerprint_source(root, spec)

    def test_path_traversal_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            spec = SourceSpec(
                source_file_id="fixture",
                path="../outside.txt",
                encoding="utf-8",
                authority="primary_text",
                default_claim_type="CANON",
                expected_sha256="0" * 64,
            )
            with self.assertRaises(SourcePathError):
                fingerprint_source(root, spec)


if __name__ == "__main__":
    unittest.main()
