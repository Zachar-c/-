from __future__ import annotations

import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from lore_engine.src.contracts import ImplementationFinding
from lore_engine.src.implementation_audit import (
    UnsafeAuditPathError,
    audit_current_implementation,
)


FIXTURE_ROOT = Path(__file__).parent / "fixtures" / "world_model" / "game_snapshot"
EXPECTED_FIXTURE_FINDING_COUNT = 37


def resolve_json_pointer(payload: object, pointer: str) -> object:
    if pointer == "":
        return payload
    if not pointer.startswith("/"):
        raise ValueError("JSON Pointer must start with a slash")
    current = payload
    for encoded in pointer[1:].split("/"):
        if re.search(r"~(?![01])", encoded):
            raise ValueError(f"invalid JSON Pointer escape: {encoded}")
        segment = encoded.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            current = current[int(segment)]
        elif isinstance(current, dict):
            current = current[segment]
        else:
            raise ValueError(f"cannot descend through {type(current).__name__}")
    return current


class ImplementationAuditTests(unittest.TestCase):
    def test_fixture_scan_is_deterministic_sorted_and_has_stable_locators(self) -> None:
        first = audit_current_implementation(FIXTURE_ROOT)
        second = audit_current_implementation(FIXTURE_ROOT)

        self.assertEqual(first, second)
        self.assertEqual(len(first), EXPECTED_FIXTURE_FINDING_COUNT)
        self.assertTrue(all(isinstance(item, ImplementationFinding) for item in first))
        self.assertEqual(
            first,
            sorted(first, key=lambda item: (item.claim_id, item.path, item.locator, item.finding_id)),
        )
        by_surface = {item.observed.split("]", 1)[0][1:]: item for item in first}
        self.assertEqual(by_surface["explicit_gu_effect"].locator, "/0/v1_effect")
        self.assertEqual(by_surface["role_fallback_candidate"].locator, "/1/role")
        self.assertEqual(by_surface["school_starter_pool"].locator, "/light~0~1path/starter_gu_ids")
        self.assertEqual(by_surface["immutable_event_log"].locator, "line:7")
        self.assertEqual(by_surface["legacy_q8g_reference"].locator, "line:3")
        self.assertEqual(by_surface["explicit_gu_effect"].finding_id, "implementation-1da12cbc9eab3b54")

    def test_fixture_covers_every_named_audit_surface_without_world_rulings(self) -> None:
        findings = audit_current_implementation(FIXTURE_ROOT)
        surfaces = {item.observed.split("]", 1)[0][1:] for item in findings}

        self.assertTrue(
            {
                "role_fallback_definition", "role_fallback_candidate", "school_starter_pool",
                "school_class_semantics",
                "generic_rank_multiplier", "rank_field", "essence_field", "dual_resource_cost",
                "aptitude_field", "lifespan_field", "soul_field", "dao_field",
                "explicit_gu_effect", "recipe_definition", "refinement_path", "feeding_path",
                "transaction_path", "combat_hook", "npc_hook", "map_hook", "meta_hook",
                "immutable_event_log", "legacy_q8g_reference", "legacy_f1_reference",
                "promotion_reference", "material_reference",
            }.issubset(surfaces)
        )
        self.assertEqual({item.behavior_status for item in findings}, {"unknown"})
        self.assertEqual({item.migration_action for item in findings}, {"defer"})

    def test_school_class_like_assignments_are_reported_individually(self) -> None:
        findings = audit_current_implementation(FIXTURE_ROOT)
        class_findings = [item for item in findings if item.observed.startswith("[school_class_semantics]")]

        self.assertEqual(
            {item.locator for item in class_findings},
            {
                "/light~0~1path/archetype",
                "/light~0~1path/class",
                "/light~0~1path/role",
                "/light~0~1path/specialization",
            },
        )
        self.assertEqual({item.behavior_status for item in class_findings}, {"unknown"})
        self.assertEqual({item.migration_action for item in class_findings}, {"defer"})

    def test_every_json_locator_is_an_rfc6901_pointer_to_fixture_data(self) -> None:
        findings = audit_current_implementation(FIXTURE_ROOT)
        payloads = {
            relative.as_posix(): json.loads((FIXTURE_ROOT / relative).read_text(encoding="utf-8"))
            for relative in (
                Path("data/gu.json"),
                Path("data/schools.json"),
                Path("data/balance.json"),
                Path("data/recipes.json"),
            )
        }

        for finding in (item for item in findings if item.source_layer == "data"):
            with self.subTest(path=finding.path, locator=finding.locator):
                try:
                    resolve_json_pointer(payloads[finding.path], finding.locator)
                except (KeyError, IndexError, TypeError, ValueError) as exc:
                    self.fail(f"invalid JSON Pointer {finding.path}#{finding.locator}: {exc}")

    def test_generated_lore_outputs_do_not_feed_back_into_register_scan(self) -> None:
        findings = audit_current_implementation(FIXTURE_ROOT)

        self.assertFalse(any(item.path.startswith("docs/lore/generated/") for item in findings))

    def test_scan_opens_only_repository_paths_for_reading_and_never_mutates_fixture(self) -> None:
        before = {path.relative_to(FIXTURE_ROOT): path.read_bytes() for path in FIXTURE_ROOT.rglob("*") if path.is_file()}
        opened: list[tuple[Path, str]] = []
        original_open = Path.open

        def guarded_open(path: Path, mode: str = "r", *args: object, **kwargs: object):
            resolved = path.resolve()
            self.assertTrue(resolved.is_relative_to(FIXTURE_ROOT.resolve()))
            self.assertEqual(mode, "r")
            opened.append((resolved, mode))
            return original_open(path, mode, *args, **kwargs)

        with patch.object(Path, "open", guarded_open):
            audit_current_implementation(FIXTURE_ROOT)

        after = {path.relative_to(FIXTURE_ROOT): path.read_bytes() for path in FIXTURE_ROOT.rglob("*") if path.is_file()}
        self.assertTrue(opened)
        self.assertEqual(before, after)

    def test_rejects_an_enumerated_file_outside_repository_before_opening_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            outside = Path(directory) / "outside.gd"
            outside.write_text("default_v1_effect", encoding="utf-8")
            with patch("lore_engine.src.implementation_audit._iter_approved_files", return_value=(outside,)):
                with patch.object(Path, "open", side_effect=AssertionError("unsafe path was opened")):
                    with self.assertRaises(UnsafeAuditPathError):
                        audit_current_implementation(FIXTURE_ROOT)


if __name__ == "__main__":
    unittest.main()
