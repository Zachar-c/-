#!/usr/bin/env python3
"""Verify the committed EPUB-derived text and build a conservative E-ID ledger.

This is a read-only verifier for source/Wiki inputs. It writes only the build
manifest and decision/coverage TSVs under lore/wiki/source/.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree as ET

try:
    import bs4
    from bs4 import BeautifulSoup
except ImportError as exc:  # pragma: no cover - environment diagnostic
    raise SystemExit("beautifulsoup4 is required to parse this EPUB's malformed XHTML") from exc

ROOT = Path(__file__).resolve().parents[3]
CANON = ROOT / "source" / "蛊真人-epub-canon.txt"
OLD = ROOT / "蛊真人-clean.txt"
MAP = ROOT / "lore/wiki/source/eid-migration-map-final.tsv"
SECTION_INDEX = ROOT / "lore/wiki/source/section-index.md"
OUT = ROOT / "lore/wiki/source"
RECENT_PAGES_COMMIT = "55032879754489fe5644830b5c37b28992d9e2f8"
EID_RE = re.compile(r"E:V[1-6]-(\d{6})$")
CHAPTER_RE = re.compile(r"chapter_(\d+)\.html$")
MARKER_RE = re.compile(r"^=== chapter_(\d{4})｜(.*) ===$")
EXPECTED_BS4 = "4.15.0"
EXPECTED_PYTHON = (3, 12)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_text(value: str) -> str:
    """Hash large Unicode artifacts without allocating a second full-size byte copy."""
    digest = hashlib.sha256()
    for offset in range(0, len(value), 65536):
        digest.update(value[offset:offset + 65536].encode("utf-8"))
    return digest.hexdigest()


def utf8_size(value: str) -> int:
    return sum(len(value[offset:offset + 65536].encode("utf-8"))
               for offset in range(0, len(value), 65536))


def canonicalize_paragraph(value: str) -> str:
    """Reproduce the committed extractor's output normalization."""
    value = value.replace("\u3000", " ")
    return re.sub(r" +", " ", value.strip())


def normalized_text(value: str) -> str:
    """Ignore whitespace differences when checking candidate identity."""
    return re.sub(r"\s+", " ", value.replace("\u3000", " ").strip())


def read_epub(epub: Path) -> tuple[list[tuple[int, str, list[str]]], dict]:
    if bs4.__version__ != EXPECTED_BS4 or sys.version_info[:2] != EXPECTED_PYTHON:
        raise ValueError(
            f"extractor runtime must be Python {EXPECTED_PYTHON[0]}.{EXPECTED_PYTHON[1]} + "
            f"beautifulsoup4 {EXPECTED_BS4}; found Python {sys.version_info.major}.{sys.version_info.minor} + bs4 {bs4.__version__}"
        )
    with zipfile.ZipFile(epub) as archive:
        container = ET.fromstring(archive.read("META-INF/container.xml"))
        cns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
        opf_path = container.find(".//c:rootfile", cns).attrib["full-path"]
        opf = ET.fromstring(archive.read(opf_path))
        ons = {"o": "http://www.idpf.org/2007/opf"}
        manifest = {
            item.attrib["id"]: item.attrib
            for item in opf.findall(".//o:manifest/o:item", ons)
        }
        spine = [item.attrib["idref"] for item in opf.findall(".//o:spine/o:itemref", ons)]
        chapters: list[tuple[int, str, list[str]]] = []
        seen: set[int] = set()
        normalized_paragraphs = fullwidth_space_paragraphs = repeated_space_paragraphs = 0
        for idref in spine:
            if idref not in manifest:
                raise ValueError(f"spine item absent from manifest: {idref}")
            href = manifest[idref]["href"]
            match = CHAPTER_RE.search(href)
            if not match:
                continue
            chapter_id = int(match.group(1))
            if chapter_id in seen:
                raise ValueError(f"duplicate chapter resource in spine: {chapter_id}")
            seen.add(chapter_id)
            member = str(PurePosixPath(opf_path).parent / href)
            soup = BeautifulSoup(archive.read(member), "html.parser")
            heading = soup.find(["h1", "h2", "h3"])
            if heading is None:
                raise ValueError(f"chapter has no h1/h2/h3 title: {member}")
            title = heading.get_text("", strip=True)
            raw_paragraphs = [p.get_text("", strip=True) for p in soup.find_all("p")]
            raw_paragraphs = [p for p in raw_paragraphs if p.strip()]
            paragraphs = []
            for raw in raw_paragraphs:
                clean = canonicalize_paragraph(raw)
                if clean != raw:
                    normalized_paragraphs += 1
                if "\u3000" in raw:
                    fullwidth_space_paragraphs += 1
                if re.search(r" {2,}", raw):
                    repeated_space_paragraphs += 1
                paragraphs.append(clean)
            chapters.append((chapter_id, title, paragraphs))
    expected = list(range(chapters[0][0], chapters[0][0] + len(chapters))) if chapters else []
    if [item[0] for item in chapters] != expected:
        raise ValueError("chapter_N resources have a gap or non-contiguous numbering")
    return chapters, {
        "spine_items": len(spine), "opf_path": opf_path,
        "normalized_paragraphs": normalized_paragraphs,
        "fullwidth_space_paragraphs": fullwidth_space_paragraphs,
        "repeated_ascii_space_paragraphs": repeated_space_paragraphs,
    }


def render(chapters: list[tuple[int, str, list[str]]]) -> str:
    lines: list[str] = []
    for index, (chapter_id, title, paragraphs) in enumerate(chapters):
        lines.append(f"=== chapter_{chapter_id:04d}｜{title} ===")
        lines.extend(paragraphs)
        if index != len(chapters) - 1:
            lines.append("")
    return "\n".join(lines) + "\n"


def parse_canon(text: str) -> tuple[dict[int, str], dict[tuple[int, int], str]]:
    titles: dict[int, str] = {}
    paragraphs: dict[tuple[int, int], str] = {}
    chapter: int | None = None
    para = 0
    for line in text.splitlines():
        marker = MARKER_RE.fullmatch(line)
        if marker:
            chapter = int(marker.group(1))
            titles[chapter] = marker.group(2)
            para = 0
        elif line and chapter is not None:
            para += 1
            paragraphs[(chapter, para)] = line
    return titles, paragraphs


def git_blob(path: Path) -> str | None:
    rel = path.relative_to(ROOT).as_posix()
    try:
        return subprocess.check_output(
            ["git", "rev-parse", f"HEAD:{rel}"], cwd=ROOT, text=True
        ).strip()
    except (subprocess.CalledProcessError, ValueError):
        return None


def load_segment_bounds() -> dict[int, tuple[int, int]]:
    names = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6}
    pattern = re.compile(r"^\|\s*([一二三四五六])\s*\|\s*([\d,]+)–([\d,]+)\s*\|")
    result = {}
    for line in SECTION_INDEX.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            result[names[match.group(1)]] = (
                int(match.group(2).replace(",", "")), int(match.group(3).replace(",", ""))
            )
    if len(result) != 6:
        raise ValueError(f"expected six E-ID segment bounds, found {len(result)}")
    return result


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epub", type=Path, required=True)
    parser.add_argument("--canonical", type=Path, default=CANON)
    parser.add_argument("--old-source", type=Path, default=OLD)
    parser.add_argument("--map", dest="mapping", type=Path, default=MAP)
    parser.add_argument("--out-dir", type=Path, default=OUT)
    parser.add_argument("--recent-pages-commit", default=RECENT_PAGES_COMMIT)
    args = parser.parse_args()
    for path in (args.epub, args.canonical, args.old_source, args.mapping):
        if not path.is_file():
            print(f"FAIL: missing input: {path}", file=sys.stderr)
            return 2

    chapters, epub_meta = read_epub(args.epub)
    rendered = render(chapters)
    rendered_hash = sha_text(rendered)
    canonical_bytes = args.canonical.read_bytes()
    canonical_text = canonical_bytes.decode("utf-8")
    # Git checkout may use CRLF; compare logical UTF-8/LF content, retain both hashes.
    logical_existing = canonical_text.replace("\r\n", "\n").replace("\r", "\n")
    if rendered != logical_existing:
        print("FAIL: EPUB reconstruction differs from committed canonical text", file=sys.stderr)
        return 1

    titles, paragraphs = parse_canon(rendered)
    old_source_bytes = args.old_source.read_bytes()
    old_source_sha = sha(old_source_bytes)
    old_lines = old_source_bytes.decode("utf-8").splitlines()
    segment_bounds = load_segment_bounds()
    paragraph_hashes = {key: sha(value.encode("utf-8")) for key, value in paragraphs.items()}
    text_addresses: dict[str, list[tuple[int, int]]] = collections.defaultdict(list)
    for address, value in paragraphs.items():
        text_addresses[normalized_text(value)].append(address)

    with args.mapping.open(encoding="utf-8-sig", newline="") as stream:
        map_rows = list(csv.DictReader(stream, delimiter="\t"))
    by_eid: dict[str, dict[str, str]] = {}
    for row in map_rows:
        if row["eid"] in by_eid:
            print(f"FAIL: duplicate E-ID in map: {row['eid']}", file=sys.stderr)
            return 1
        by_eid[row["eid"]] = row

    # Live scope: content Wiki pages, canon-index, compiled runtime, and Web source.
    content_dirs = ("characters", "events", "gu", "rules", "world", "themes")
    wiki_pages: dict[str, set[str]] = {}
    reference_files: dict[str, set[str]] = collections.defaultdict(set)
    live_ref_counts: collections.Counter = collections.Counter()
    live_re = re.compile(r"E:V[1-6]-\d{6}")
    for rel_dir in content_dirs:
        for path in (ROOT / "lore/wiki" / rel_dir).rglob("*.md"):
            rel = path.relative_to(ROOT).as_posix()
            text = path.read_text(encoding="utf-8")
            refs = live_re.findall(text)
            wiki_pages[rel] = set(refs)
            for eid in refs:
                live_ref_counts[eid] += 1
                reference_files[eid].add(rel)
    other_live_paths = [ROOT / "game/docs/lore/canon-index.md"]
    other_live_paths.extend((ROOT / "lore/runtime").rglob("*.json"))
    tracked_web = subprocess.check_output(
        ["git", "ls-files", "--", "game/wenzhen-web-lab"], cwd=ROOT, text=True
    ).splitlines()
    other_live_paths.extend(
        ROOT / rel for rel in tracked_web
        if Path(rel).suffix.lower() in (".js", ".json", ".html", ".md")
    )
    for test_root in (ROOT / "tests", ROOT / "game/tests", ROOT / "game/wenzhen-web-lab/tests"):
        if test_root.is_dir():
            for suffix in (".js", ".mjs", ".ts", ".json", ".md", ".html"):
                other_live_paths.extend(test_root.rglob(f"*{suffix}"))
    for path in other_live_paths:
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        refs = live_re.findall(path.read_text(encoding="utf-8", errors="replace"))
        for eid in refs:
            live_ref_counts[eid] += 1
            reference_files[eid].add(rel)
    live_eids = set(live_ref_counts)

    prior_approvals: dict[str, dict[str, str]] = {}
    decision_path = args.out_dir / "eid-migration-decisions.tsv"
    if decision_path.is_file():
        with decision_path.open(encoding="utf-8", newline="") as stream:
            for prior in csv.DictReader(stream, delimiter="\t"):
                if prior.get("decision") == "human_approved":
                    prior_approvals[prior["eid"]] = prior

    decisions: list[dict[str, object]] = []
    decision_counts: collections.Counter = collections.Counter()
    source_line_missing = legacy_address_mismatch = legacy_address_missing = 0
    decision_by_eid: dict[str, dict[str, object]] = {}
    all_eids = set(by_eid) | live_eids
    for eid in sorted(all_eids):
        row = by_eid.get(eid)
        match = EID_RE.fullmatch(eid)
        if not match:
            raise ValueError(f"malformed E-ID: {eid}")
        eid_vol, eid_line = int(eid.split(":V", 1)[1].split("-", 1)[0]), int(match.group(1))
        old_line = eid_line
        legacy_old_line = int(row["old_line"] or 0) if row else None
        old_vol = row["old_vol"] if row else str(eid_vol)
        start, end = segment_bounds[eid_vol]
        segment_ok = start <= old_line <= end
        old_text = old_lines[old_line - 1] if 1 <= old_line <= len(old_lines) else ""
        if not old_text:
            source_line_missing += 1
        candidate_addresses = text_addresses.get(normalized_text(old_text), []) if old_text.strip() else []
        candidate_count = len(candidate_addresses)
        line_is_heading = bool(re.match(r"^第[0-9一二三四五六七八九十百千万]+节[：:]", old_text.strip()))
        current_live = eid in live_eids
        selected_chapter, selected_para = candidate_addresses[0] if candidate_count == 1 else (None, None)
        target = paragraphs.get((selected_chapter, selected_para)) if selected_chapter is not None else None
        auto = current_live and segment_ok and old_text.strip() != "" and candidate_count == 1 and not line_is_heading
        decision = "auto_verified" if auto else "blocked"
        reviewer = reviewed_at = ""
        if auto:
            reason = "current old-source line uniquely equals a canonical paragraph under whitespace-only normalization"
        elif line_is_heading:
            reason = "old-source line is a chapter heading; paragraph locator is not defined for headings"
        elif not current_live:
            reason = "legacy map row is not referenced by current live Wiki/runtime/Web scope"
        elif not segment_ok:
            reason = "E-ID line falls outside the declared volume segment"
        elif not old_text:
            reason = "old-source E-ID line is empty or out of range"
        elif candidate_count == 0:
            reason = "old-source line has no exact full-paragraph match in canonical text"
        elif candidate_count != 1:
            reason = f"old-source line has {candidate_count} full-paragraph candidates"
        else:
            reason = "requires review"
        prior = prior_approvals.get(eid)
        prior_chapter = int(prior["selected_chapter_id"].removeprefix("chapter_")) if prior and prior.get("selected_chapter_id", "").startswith("chapter_") else None
        prior_para = int(prior["selected_paragraph_id"].removeprefix("para_")) if prior and prior.get("selected_paragraph_id", "").startswith("para_") else None
        prior_target = paragraphs.get((prior_chapter, prior_para)) if prior_chapter is not None and prior_para is not None else None
        prior_target_hash = paragraph_hashes.get((prior_chapter, prior_para), "") if prior_chapter is not None and prior_para is not None else ""
        if (prior and prior_target is not None and current_live and not auto
                and prior.get("old_source_sha256") == old_source_sha
                and prior.get("old_text_sha256") == (sha(old_text.encode("utf-8")) if old_text else "")
                and prior.get("new_source_sha256_lf") == rendered_hash
                and prior.get("paragraph_sha256") == prior_target_hash
                and prior.get("reviewer") and prior.get("reviewed_at") and prior.get("review_reason")):
            decision = "human_approved"
            selected_chapter, selected_para, target = prior_chapter, prior_para, prior_target
            reviewer = prior["reviewer"]
            reviewed_at = prior["reviewed_at"]
            reason = prior["review_reason"]
        target_hash = paragraph_hashes.get((selected_chapter, selected_para), "") if selected_chapter is not None and selected_para is not None and target is not None else ""
        decision_counts[decision] += 1
        mapped_chapter = int(row["chapter"]) if row and row["chapter"].isdigit() else None
        mapped_para = int(row["para"]) if row and row["para"].isdigit() else None
        mapped_target = paragraphs.get((mapped_chapter, mapped_para)) if mapped_chapter is not None and mapped_para is not None else None
        if row and (row["chapter"] or row["para"]) and mapped_target is None:
            legacy_address_missing += 1
        mapped_target_matches = bool(mapped_target is not None and normalized_text(old_text) == normalized_text(mapped_target))
        if row and row["class"] == "精确" and current_live and not mapped_target_matches:
            legacy_address_mismatch += 1
        item = {
            "eid": eid,
            "scope": "live" if current_live else "legacy_map_only",
            "live_ref_count": live_ref_counts[eid],
            "used_by_files_json": json.dumps(sorted(reference_files.get(eid, set())), ensure_ascii=False),
            "old_source_sha256": old_source_sha,
            "old_vol": old_vol,
            "old_line": old_line,
            "legacy_map_old_line": legacy_old_line if legacy_old_line is not None else "",
            "legacy_map_line_matches_eid": str(legacy_old_line in (None, old_line) and old_vol == str(eid_vol)).lower(),
            "segment_bounds_ok": str(segment_ok).lower(),
            "old_text_sha256": sha(old_text.encode("utf-8")) if old_text else "",
            "new_source_sha256_lf": rendered_hash,
            "extractor_version": f"bs4-{bs4.__version__}/html.parser-v1",
            "address_schema_version": "epub-chapter-para-v1",
            "legacy_match_class": row["class"] if row else "not_in_legacy_map",
            "legacy_mapped_chapter_id": f"chapter_{mapped_chapter:04d}" if mapped_chapter is not None and mapped_target else "",
            "legacy_mapped_paragraph_id": f"para_{mapped_para:03d}" if mapped_para is not None and mapped_target else "",
            "legacy_address_matches_text": str(mapped_target_matches).lower(),
            "selected_chapter_id": f"chapter_{selected_chapter:04d}" if selected_chapter is not None and target else "",
            "selected_paragraph_id": f"para_{selected_para:03d}" if selected_para is not None and target else "",
            "paragraph_sha256": target_hash,
            "match_class": "unique_exact_full_paragraph" if candidate_count == 1 else (
                "multiple_exact_full_paragraphs" if candidate_count > 1 else "no_exact_full_paragraph"
            ),
            "match_len": row["match_len"] if row else "",
            "candidate_count": candidate_count,
            "candidate_addresses_json": json.dumps(
                [f"chapter_{c:04d}:para_{p:03d}" for c, p in candidate_addresses], ensure_ascii=False
            ),
            "decision": decision,
            "reviewer": reviewer,
            "reviewed_at": reviewed_at,
            "review_reason": reason,
            "mapping_version": "1",
        }
        decisions.append(item)
        decision_by_eid[eid] = item

    args.out_dir.mkdir(parents=True, exist_ok=True)
    fields = list(decisions[0].keys()) if decisions else []
    write_tsv(args.out_dir / "eid-migration-decisions.tsv", fields, decisions)
    runtime_manifest = json.loads((ROOT / "lore/runtime/manifest.json").read_text(encoding="utf-8"))
    runtime_entities = json.loads((ROOT / "lore/runtime/entities.json").read_text(encoding="utf-8"))["entities"]
    runtime_ids = set(runtime_manifest["scope"]["entity_pages"])
    entity_pages: dict[str, str] = {}
    for entity in runtime_entities:
        if entity["id"] not in runtime_ids:
            continue
        gu_pages = [p for p in entity.get("provenance", {}).get("wiki_pages", [])
                    if p.startswith("lore/wiki/gu/") and p.endswith("-gu.md")]
        if len(gu_pages) == 1:
            entity_pages[gu_pages[0]] = entity["id"]
    if len(entity_pages) != 80:
        raise ValueError(f"runtime recovery-page inventory expected 80 pages, found {len(entity_pages)}")
    added_paths = subprocess.check_output(
        ["git", "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=A", "-r", args.recent_pages_commit],
        cwd=ROOT, text=True,
    ).splitlines()
    recent_pages = {p.replace("\\", "/") for p in added_paths
                    if p.startswith("lore/wiki/gu/") and p.endswith("-gu.md")}
    if len(recent_pages) != 40:
        raise ValueError(f"recent-pages commit expected 40 newly added entity pages, found {len(recent_pages)}")
    if not recent_pages.issubset(entity_pages):
        raise ValueError("some recent-40 pages are absent from the runtime 80-page inventory")
    coverage = []
    for page, page_eids in sorted(wiki_pages.items()):
        auto_count = sum(decision_by_eid[eid]["decision"] == "auto_verified" for eid in page_eids)
        human_count = sum(decision_by_eid[eid]["decision"] == "human_approved" for eid in page_eids)
        unmapped = sorted(
            eid for eid in page_eids
            if decision_by_eid[eid]["legacy_match_class"] == "not_in_legacy_map"
        )
        cohort_parts = []
        if page in entity_pages:
            cohort_parts.append("recovered_80")
        if page in recent_pages:
            cohort_parts.append("recent_40")
        coverage.append({
            "page": page,
            "entity_id": entity_pages.get(page, ""),
            "cohort": ";".join(cohort_parts) if cohort_parts else "other_live_wiki_page",
            "eid_total": len(page_eids),
            "auto_verified": auto_count,
            "human_approved": human_count,
            "blocked": len(page_eids) - auto_count - human_count,
            "unmapped_eids_json": json.dumps(unmapped, ensure_ascii=False),
            "coverage_scope": "unique E-IDs extracted from current active Wiki content",
        })
    write_tsv(args.out_dir / "migration-page-coverage.tsv", list(coverage[0].keys()) if coverage else [], coverage)

    index_digest = hashlib.sha256()
    index_path = args.out_dir / "chapter-paragraph-index.tsv"
    with index_path.open("w", encoding="utf-8", newline="\n") as index_stream:
        header = "chapter_id\tchapter_title\tparagraph_id\tparagraph_sha256\n"
        index_stream.write(header)
        index_digest.update(header.encode("utf-8"))
        for (chapter_id, para_id), paragraph_hash in sorted(paragraph_hashes.items()):
            line = (f"chapter_{chapter_id:04d}\t{titles[chapter_id]}\t"
                    f"para_{para_id:03d}\t{paragraph_hash}\n")
            index_stream.write(line)
            index_digest.update(line.encode("utf-8"))

    manifest = {
        "manifest_version": 1,
        "epub_sha256": sha(args.epub.read_bytes()),
        "canonical_logical_sha256_lf": rendered_hash,
        "canonical_worktree_sha256": sha(canonical_bytes),
        "canonical_git_blob": git_blob(args.canonical),
        "chapter_paragraph_index_sha256_lf": index_digest.hexdigest(),
        "old_source_sha256": old_source_sha,
        "extractor": f"beautifulsoup4 {bs4.__version__}, html.parser",
        "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "normalization": "p.get_text('', strip=True); U+3000 to ASCII space; collapse repeated ASCII spaces; paragraph bytes otherwise retained",
        "address_schema": "EPUB:chapter_N:para_M (paragraph IDs are per chapter, 1-based)",
        "line_ending_policy": "logical artifact is UTF-8 LF with terminal LF; worktree may be CRLF via Git autocrlf",
        "chapter_count": len(chapters),
        "chapter_min": min(titles) if titles else None,
        "chapter_max": max(titles) if titles else None,
        "paragraph_count": len(paragraphs),
        "paragraphs_with_whitespace_normalization": epub_meta["normalized_paragraphs"],
        "paragraphs_with_fullwidth_spaces": epub_meta["fullwidth_space_paragraphs"],
        "paragraphs_with_repeated_ascii_spaces": epub_meta["repeated_ascii_space_paragraphs"],
        "physical_line_count_lf": len(rendered.splitlines()),
        "byte_count_lf": utf8_size(rendered),
        "ends_with_newline": rendered.endswith("\n"),
        "spine_items": epub_meta["spine_items"],
        "legacy_map_eid_count": len(by_eid),
        "live_unique_eid_count": len(live_eids),
        "live_reference_count": sum(live_ref_counts.values()),
        "live_files_count": len({path for paths in reference_files.values() for path in paths}),
        "eids_auto_verified": sum(item["decision"] == "auto_verified" and item["scope"] == "live" for item in decisions),
        "eids_human_approved": sum(item["decision"] == "human_approved" and item["scope"] == "live" for item in decisions),
        "eids_blocked": sum(item["decision"] == "blocked" and item["scope"] == "live" for item in decisions),
            "legacy_only_eids": sum(item["scope"] == "legacy_map_only" for item in decisions),
        "live_eids_missing_from_legacy_map": sum(
            item["scope"] == "live" and item["legacy_match_class"] == "not_in_legacy_map"
            for item in decisions
        ),
        "legacy_exact_address_mismatches": legacy_address_mismatch,
        "runtime_recovered_entity_pages": len(entity_pages),
        "recent_entity_pages": len(recent_pages),
        "recent_pages_commit": args.recent_pages_commit,
        "legacy_mapped_address_missing": legacy_address_missing,
        "old_source_line_missing": source_line_missing,
        "decision_policy": "current live E-ID auto-verifies only when its segment/line is valid and the old-source line uniquely equals a full canonical paragraph under whitespace-only normalization",
    }
    (args.out_dir / "epub-canonical-build-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
