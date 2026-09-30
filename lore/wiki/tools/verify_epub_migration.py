#!/usr/bin/env python3
"""Verify the committed EPUB-derived text and build a conservative E-ID ledger.

This is a read-only verifier for source/Wiki inputs. It writes only the build
manifest and decision/coverage TSVs under lore/wiki/source/.
"""
from __future__ import annotations

import argparse
import bisect
import collections
import csv
import difflib
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

# —— Classification v3 (C2 消歧, 2026-09-29) ——
# The EPUB is the text truth; the old TXT is only a legacy evidence-recovery
# source. An E-ID therefore auto-verifies when its locator is *uniquely
# determined and order-consistent* — NOT when the two texts happen to be
# byte-identical. Prose whose wording differs is recorded in legacy_variance and
# may still auto-verify; only an unresolvable or positionally ambiguous E-ID is
# withheld for human review.
DECISION_AUTO = "auto_verified"
DECISION_HUMAN = "human_approved"
DECISION_BLOCKED = "blocked"
DECISION_OUT_OF_SCOPE = "out_of_scope"

# Mutually exclusive blocker taxonomy. Assigned in this priority order to the
# baseline live blockers, so the partition is strict and sums to 801.
BLOCKER_CLASS_ORDER = (
    "heading_anchor",               # the E-ID line is a 第N节 chapter heading
    "segment_label_out_of_range",   # E-ID line falls outside its declared volume segment
    "legacy_blank_or_out_of_range",  # the legacy line is empty or past end of file
    "multiple_candidates",          # the legacy line equals more than one canonical paragraph
    "no_full_paragraph_match",      # the legacy line equals no canonical paragraph
)

# The recorded size of the baseline blocker set (v1 口径: 5,714 auto + 801
# blocked over 6,515 live E-IDs). The verifier fails loudly if the partition
# stops covering exactly this many rows.
BASELINE_BLOCKER_TOTAL = 801
BASELINE_AUTO_TOTAL = 5714

# New locator kind: a chapter's own heading line. Addressable as
# EPUB:chapter_N:heading and recorded in the decisions ledger only — the
# paragraph index stays paragraph-only.
HEADING_PARAGRAPH_ID = "heading"

# Columns emitted to eid-migration-decisions.tsv. Purely internal diagnostics
# (similarity ratio, positional admission class, diff-token dump, match length)
# are deliberately kept out of the record so it stays reviewable by hand.
DECISION_COLUMNS = (
    "eid", "scope", "live_ref_count", "used_by_files_json", "old_vol", "old_line",
    "legacy_map_old_line", "legacy_map_line_matches_eid", "segment_bounds_ok",
    "old_text_sha256", "old_source_sha256", "new_source_sha256_lf",
    "extractor_version", "address_schema_version", "legacy_match_class",
    "legacy_mapped_chapter_id", "legacy_mapped_paragraph_id", "legacy_address_matches_text",
    "selected_chapter_id", "selected_paragraph_id", "selected_locator_kind",
    "canonical_locator", "paragraph_sha256", "match_class",
    "candidate_count", "candidate_addresses_json",
    "decision", "primary_blocker_class", "withheld_reason", "secondary_reason_json",
    "human_review_required", "migration_basis", "legacy_variance",
    "reviewer", "reviewed_at", "review_reason", "mapping_version",
)

# The five reasons requested by the migration order, plus two extensions that
# the evidence requires (punctuation-only swaps and genuine wording changes are
# distinct signals and must not be silently merged into either bucket).
REASON_LEGACY_TYPO = "legacy_typo"
REASON_LEGACY_REDACTION = "legacy_redaction"
REASON_SEGMENTATION = "paragraph_segmentation_difference"
REASON_CONTENT_MISSING = "legacy_content_missing"
REASON_TRUE_AMBIGUITY = "true_ambiguity"
REASON_PUNCTUATION = "punctuation_variant"
REASON_CONTENT_DIVERGENCE = "content_divergence"

# EPUB-internal duplicate / alternate-version regions. These must never be
# machine-resolved: chapter_61 is a byte-identical repeat of chapter_62, and
# 836/837 and 879/880 are two renderings of the same 节.
AMBIGUOUS_CHAPTERS = frozenset({61, 62, 836, 837, 879, 880})

# Diagnostic-only thresholds. Nothing here can promote a blocked row to
# auto_verified; the constants only describe *how* a legacy line differs from
# the paragraph its locator points at.
PUNCT_CHARS = frozenset("，。！？；：、“”‘’（）《》〈〉…—·,.!?;:\"'()[]{}<>~- ")
VARIANT_FOLD = str.maketrans({"黒": "黑", "夭": "天", "曰": "日", "盅": "蛊", "姓": "性"})
VARIANT_FOLD_DESC = "黒→黑, 夭→天, 曰→日, 盅→蛊, 姓→性"
CONTACT_PREFIX_LADDER = (40, 30, 24, 18, 12, 8, 5, 3)
MAX_DIFF_TOKENS = 12
MAX_DIFF_FRAGMENT = 160
REDACTION_MARKERS = ("**", "8 9 阅 读 网", "阅读网", "更新最快")

# —— Context alignment (positional rule) ——
# The old source interleaves blank lines, section headings, TOC lines and site
# watermarks between prose lines, so a legacy index is not a paragraph index.
# A slot is therefore *proved* only when the closed interval between two
# verified anchors is an exact 1:1 bijection of prose lines onto paragraphs
# (span <= MAX_CONTEXT_SPAN legacy lines). SIMILARITY_FLOOR only guards that proof against a
# misclassified structural line; it never selects a "most similar" paragraph.
# ponytail: 12 covers the reviewed live intervals; review longer gaps before raising it.
MAX_CONTEXT_SPAN = 12
SIMILARITY_FLOOR = 0.90
MIN_BOUNDARY_CHARS = 8

# Decorative markup the redistribution sites added around single characters,
# e.g. "保留在方源的〖体〗内". Folding it is a comparison-only normalization and
# never rewrites the canonical EPUB text.
LEGACY_MARKUP = re.compile(r"[〖〗]")
LEGACY_MARKUP_DESC = "〖〗 removed"

STRUCTURAL_MARKERS = (
    "阅读网", "更新最快", "本章未完", "未完待续", "全文阅读", "首发", "笔趣阁",
    "月票", "推荐票", "各位书友", "求收藏", "订阅", "章节目录", "www.", "http",
    "请记住", "手机阅读",
)
# A legacy line may be a 节 heading either plainly or as a table-of-contents
# entry ("章节目录 第九十二节：仙僵议事"). Both resolve by the 节 title.
HEADING_TEXT_RE = re.compile(
    r"^(?:章节目录\s*)?第[0-9一二三四五六七八九十百千万]+节[：:]\s*(.*)$")
HEADING_PREFIX_RE = re.compile(r"^(?:章节目录\s*)?第[0-9一二三四五六七八九十百千万]+节[：:]")


def strip_punctuation(value: str) -> str:
    return "".join(ch for ch in value if ch not in PUNCT_CHARS)


def structural_line(value: str) -> bool:
    """True for legacy lines that carry no canonical paragraph of their own.

    Section headings, table-of-contents entries and site watermarks interleave
    the old source and would otherwise shift the prose-to-paragraph alignment.
    """
    stripped = value.strip()
    return bool(HEADING_PREFIX_RE.match(stripped)) or any(
        marker in stripped for marker in STRUCTURAL_MARKERS)


def boundary_match(legacy: str, paragraph: str) -> bool:
    """True when one text is a truncated/watermarked rendering of the other."""
    if min(len(legacy), len(paragraph)) < MIN_BOUNDARY_CHARS:
        return False
    return legacy in paragraph or paragraph in legacy


# Variance kinds that are proved by a character-level normalization rather than
# by similarity, so a positional slot carrying one of them is admitted outright.
STRONG_VARIANCE_KINDS = frozenset({
    "identical", "legacy_markup", "punctuation", "orthographic_variant", "legacy_redaction",
})


def legacy_variance_kind_of(legacy: str, reference: str) -> str:
    """Deterministic classification of how a legacy line differs from a paragraph.

    Every branch is a reproducible string transformation; none of them searches
    for the closest paragraph, and none of them rewrites the canonical text.
    """
    if legacy == reference:
        return "identical"
    if LEGACY_MARKUP.sub("", legacy) == LEGACY_MARKUP.sub("", reference):
        return "legacy_markup"
    if any(marker in legacy for marker in REDACTION_MARKERS):
        return "legacy_redaction"
    if strip_punctuation(legacy) == strip_punctuation(reference):
        return "punctuation"
    if (strip_punctuation(LEGACY_MARKUP.sub("", legacy)).translate(VARIANT_FOLD)
            == strip_punctuation(LEGACY_MARKUP.sub("", reference)).translate(VARIANT_FOLD)):
        return "orthographic_variant"
    if legacy in reference or reference in legacy:
        return "paragraph_boundary"
    return "wording"


def diff_tokens(left: str, right: str) -> list[list[str]]:
    """Raw opcode evidence for a divergent locator; bounded but never summarised away."""
    tokens: list[list[str]] = []
    matcher = difflib.SequenceMatcher(None, left, right)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        tokens.append([tag, left[i1:i2][:MAX_DIFF_FRAGMENT], right[j1:j2][:MAX_DIFF_FRAGMENT]])
        if len(tokens) >= MAX_DIFF_TOKENS:
            break
    return tokens



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

    # Ordered view of the canonical text for containment/contact probing. The
    # "\x00" separator guarantees a substring search can never straddle two
    # paragraphs, so a hit is always inside exactly one paragraph.
    ordered_keys = list(paragraphs)
    normalized_paragraphs = {key: normalized_text(paragraphs[key]) for key in ordered_keys}
    paragraph_blob_parts: list[str] = []
    paragraph_span_starts: list[int] = []
    cursor = 0
    for key in ordered_keys:
        value = normalized_paragraphs[key]
        paragraph_span_starts.append(cursor)
        paragraph_blob_parts.append(value)
        cursor += len(value) + 1
    paragraph_blob = "\x00".join(paragraph_blob_parts)

    def paragraph_at(position: int) -> tuple[int, int]:
        index = bisect.bisect_right(paragraph_span_starts, position) - 1
        return ordered_keys[index]

    def resolve_contact(value: str) -> tuple[tuple[int, int] | None, int]:
        for length in CONTACT_PREFIX_LADDER:
            if len(value) < length:
                continue
            found = paragraph_blob.find(value[:length])
            if found != -1:
                return paragraph_at(found), length
        return None, 0

    # —— Monotone anchor backbone ——
    # The legacy source interleaves blank lines with prose, so raw line offsets
    # are NOT paragraph offsets: line 6814 is two lines before 6816 but only one
    # paragraph before it. Alignment therefore runs over the *non-blank* legacy
    # sequence. Every legacy line whose normalized text uniquely equals a
    # canonical paragraph is an anchor candidate (190,619 of 215,231 lines).
    # A forward greedy filter is not safe here: one spurious hit early in the
    # file poisons the running maximum and discards the remaining ~183k anchors.
    # The longest strictly increasing subsequence keeps 186,936 of them, so the
    # enclosing anchors of a blocked line are only a line or two away.
    paragraph_ordinal = {key: index for index, key in enumerate(ordered_keys)}
    legacy_logical = [(number, line) for number, line in enumerate(old_lines, 1) if line.strip()]
    legacy_logical_index = {number: index for index, (number, _) in enumerate(legacy_logical)}
    anchor_pairs: list[tuple[int, int]] = []
    for logical, (_number, line) in enumerate(legacy_logical):
        hits = text_addresses.get(normalized_text(line), [])
        if len(hits) == 1:
            anchor_pairs.append((logical, paragraph_ordinal[hits[0]]))
    tails: list[int] = []
    tail_index: list[int] = []
    predecessor = [-1] * len(anchor_pairs)
    for index, (_logical, ordinal) in enumerate(anchor_pairs):
        position = bisect.bisect_left(tails, ordinal)
        if position == len(tails):
            tails.append(ordinal)
            tail_index.append(index)
        else:
            tails[position] = ordinal
            tail_index[position] = index
        predecessor[index] = tail_index[position - 1] if position > 0 else -1
    backbone: list[tuple[int, int]] = []
    cursor = tail_index[-1] if tail_index else -1
    while cursor != -1:
        backbone.append(anchor_pairs[cursor])
        cursor = predecessor[cursor]
    backbone.reverse()
    backbone_logicals = [entry[0] for entry in backbone]
    backbone_dropped = len(legacy_logical) - len(backbone)

    def ordinal_chapter(ordinal: int) -> int:
        return ordered_keys[ordinal][0]

    def backbone_window(logical: int) -> tuple[tuple[int, int] | None, tuple[int, int] | None]:
        """The enclosing backbone anchors (logical index, ordinal) around a legacy index."""
        position = bisect.bisect_left(backbone_logicals, logical)
        low = backbone[position - 1] if position > 0 else None
        high = backbone[position] if position < len(backbone) else None
        return low, high

    def backbone_bounds(logical: int) -> tuple[int, int]:
        """Ordinal window (exclusive) enclosing a legacy logical index."""
        low, high = backbone_window(logical)
        return (low[1] if low else -1, high[1] if high else len(ordered_keys))

    # —— Heading locators ——
    # EPUB chapter titles carry their 节 label ("第一百八十五节：炼道杀招转金钟"),
    # so a legacy heading line resolves by its 节 title. Section numbers restart
    # per volume in the legacy source but are global in the EPUB, so the title —
    # not the number — is the join key.
    heading_by_name: dict[str, list[int]] = collections.defaultdict(list)
    for chapter_id, title in titles.items():
        match = HEADING_TEXT_RE.match(title)
        if match:
            heading_by_name[match.group(1)].append(chapter_id)
    heading_hashes = {
        chapter_id: sha(f"=== chapter_{chapter_id:04d}｜{titles[chapter_id]} ===".encode("utf-8"))
        for chapter_id in titles
    }


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
    other_live_paths.extend(path for path in (ROOT / "lore/runtime").rglob("*.json")
                            if path.name != "evidence-locators.json")
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
        old_norm = normalized_text(old_text) if old_text.strip() else ""
        candidate_addresses = text_addresses.get(old_norm, []) if old_norm else []
        candidate_count = len(candidate_addresses)
        line_is_heading = bool(HEADING_PREFIX_RE.match(old_text.strip()))
        current_live = eid in live_eids

        # —— Classification v3: resolve the locator, then record why it failed ——
        # "Blocker" keeps the v1 meaning: a live E-ID the old rule could not
        # auto-verify. The taxonomy below is the strict, mutually exclusive
        # partition of exactly those rows.
        baseline_auto = (segment_ok and old_norm != "" and candidate_count == 1
                         and not line_is_heading)
        primary_blocker_class = ""
        if current_live and not baseline_auto:
            if line_is_heading:
                primary_blocker_class = "heading_anchor"
            elif not segment_ok:
                primary_blocker_class = "segment_label_out_of_range"
            elif old_norm == "":
                primary_blocker_class = "legacy_blank_or_out_of_range"
            elif candidate_count > 1:
                primary_blocker_class = "multiple_candidates"
            else:
                primary_blocker_class = "no_full_paragraph_match"

        selected_chapter: int | None = None
        selected_para: int | None = None
        selected_heading = False
        migration_basis = ""
        withheld = ""
        reason = ""
        reasons: list[str] = []
        tokens: list[list[str]] = []
        segment_label_flag = False
        admission = ""

        logical = legacy_logical_index.get(old_line)
        anchor_low, anchor_high = backbone_window(logical) if logical is not None else (None, None)
        low_ordinal = anchor_low[1] if anchor_low else -1
        high_ordinal = anchor_high[1] if anchor_high else len(ordered_keys)
        in_window = [
            address for address in candidate_addresses
            if low_ordinal < paragraph_ordinal[address] < high_ordinal
        ]

        if not current_live:
            decision = DECISION_OUT_OF_SCOPE
            reason = "legacy map row is not referenced by current live Wiki/runtime/Web scope"
        elif baseline_auto:
            decision = DECISION_AUTO
            selected_chapter, selected_para = candidate_addresses[0]
            migration_basis = "exact_full_paragraph"
            reason = "legacy line uniquely equals a canonical paragraph under whitespace-only normalization"
        elif old_norm == "":
            # Blank and out-of-range legacy lines always go to human review, even
            # when the anchor window could pin their position.
            decision, withheld = DECISION_BLOCKED, "blank_or_out_of_range"
            reason = "legacy E-ID line is empty or past end of file"
            reasons.append(REASON_CONTENT_MISSING)
        elif line_is_heading:
            name = HEADING_TEXT_RE.match(old_norm).group(1)
            low_chapter = ordinal_chapter(low_ordinal) if low_ordinal >= 0 else -1
            high_chapter = (ordinal_chapter(high_ordinal)
                            if high_ordinal < len(ordered_keys) else 10 ** 9)
            # The heading precedes its own chapter's first paragraph, so the
            # chapter it belongs to is at the inclusive end of the window.
            bounded = [c for c in heading_by_name.get(name, []) if low_chapter <= c <= high_chapter]
            if len(bounded) == 1:
                decision = DECISION_AUTO
                selected_chapter, selected_heading = bounded[0], True
                migration_basis = "heading_locator"
                reason = f"legacy heading line resolves to the unique chapter heading {name!r}"
            else:
                decision, withheld = DECISION_BLOCKED, "heading_unresolved"
                reason = (f"legacy heading matches {len(bounded)} chapters inside the anchor window"
                          if bounded else f"no EPUB chapter title carries the 节 name {name!r}")
                reasons.append(REASON_TRUE_AMBIGUITY if bounded else REASON_CONTENT_MISSING)
        elif len(in_window) == 1 or (candidate_count == 1 and not segment_ok):
            decision = DECISION_AUTO
            selected_chapter, selected_para = (in_window or candidate_addresses)[0]
            segment_label_flag = not segment_ok
            migration_basis = "exact_full_paragraph"
            reason = ("legacy line uniquely equals a canonical paragraph under whitespace-only normalization"
                      + ("; E-ID line falls outside the declared volume segment" if segment_label_flag else ""))
        elif len(in_window) > 1:
            decision, withheld = DECISION_BLOCKED, "multiple_candidates"
            reason = f"legacy line equals {len(in_window)} canonical paragraphs inside the anchor window"
            reasons.append(REASON_TRUE_AMBIGUITY)
        elif anchor_low is None or anchor_high is None:
            decision, withheld = DECISION_BLOCKED, "unbounded_window"
            reason = "no anchor on both sides; the position is not pinned"
            reasons.append(REASON_TRUE_AMBIGUITY)
        else:
            # —— Positional rule (migration order requirement 4) ——
            # The old source interleaves headings, TOC lines and watermarks with
            # prose. Once those are set aside, the closed interval between the two
            # enclosing verified anchors must biject onto the canonical paragraphs
            # of the same closed ordinal interval. When the two counts agree the
            # slot is *forced* by order alone: no text comparison of the target
            # line takes part in locating it. The similarity check below only
            # guards the proof against a misclassified structural line.
            span_lines = anchor_high[0] - anchor_low[0] + 1
            structural = sum(
                1 for index in range(anchor_low[0], anchor_high[0] + 1)
                if structural_line(legacy_logical[index][1]))
            prose = span_lines - structural
            paras = anchor_high[1] - anchor_low[1] + 1
            rank = sum(
                1 for index in range(anchor_low[0], logical + 1)
                if not structural_line(legacy_logical[index][1]))
            slot = anchor_low[1] + rank - 1
            if prose != paras:
                decision, withheld = DECISION_BLOCKED, "segment_alignment"
                reason = (f"the closed anchor interval holds {prose} prose lines but {paras} "
                          "canonical paragraphs; alignment is not one-to-one")
                reasons.append(REASON_SEGMENTATION)
            elif span_lines > MAX_CONTEXT_SPAN:
                decision, withheld = DECISION_BLOCKED, "context_too_wide"
                reason = (f"the nearest anchors are {span_lines} legacy lines apart, beyond the "
                          f"{MAX_CONTEXT_SPAN}-line reviewed context window")
                reasons.append(REASON_TRUE_AMBIGUITY)
            elif not anchor_low[1] <= slot < anchor_high[1]:
                decision, withheld = DECISION_BLOCKED, "slot_outside_anchor_window"
                reason = "the aligned slot collides with an anchor; the line has no paragraph of its own"
                reasons.append(REASON_SEGMENTATION)
            else:
                slot_address = ordered_keys[slot]
                slot_text = normalized_paragraphs[slot_address]
                kind = legacy_variance_kind_of(old_norm, slot_text)
                ratio = 1.0 if kind in ("identical", "legacy_markup") else round(
                    difflib.SequenceMatcher(None, old_norm, slot_text).ratio(), 4)
                if slot_address in candidate_addresses:
                    admitted, admission = True, "candidate_membership"
                elif kind in STRONG_VARIANCE_KINDS:
                    admitted, admission = True, kind
                elif boundary_match(old_norm, slot_text):
                    admitted, admission = True, "paragraph_boundary"
                elif ratio >= SIMILARITY_FLOOR:
                    admitted, admission = True, "similarity_floor"
                else:
                    admitted, admission = False, ""
                if admitted and slot_address[0] in AMBIGUOUS_CHAPTERS:
                    admitted, admission = False, ""
                    reasons.append(REASON_TRUE_AMBIGUITY)
                if admitted:
                    decision = DECISION_AUTO
                    selected_chapter, selected_para = slot_address
                    segment_label_flag = not segment_ok
                    migration_basis = "positional_alignment"
                    reason = (f"enclosing anchor interval is a one-to-one match; slot admitted by "
                              f"{admission}")
                else:
                    decision, withheld = DECISION_BLOCKED, "positional_text_divergence"
                    reason = (f"the one-to-one interval pins ordinal {slot}, but the canonical "
                              f"paragraph diverges in wording (similarity {ratio})")
                    reasons.append(REASON_CONTENT_DIVERGENCE)

        if selected_chapter is not None and selected_chapter in AMBIGUOUS_CHAPTERS:
            ambiguous_chapter = selected_chapter
            decision, withheld = DECISION_BLOCKED, "ambiguous_region"
            selected_chapter = selected_para = None
            selected_heading = False
            migration_basis = ""
            reasons.append(REASON_TRUE_AMBIGUITY)
            reason = (f"resolved into duplicate/alternate-version chapter_{ambiguous_chapter:04d}; "
                      "not machine-resolved")

        # —— legacy_variance: descriptive evidence only ——
        # It records how the legacy line differs from the paragraph its locator
        # points at. It can never promote or demote a decision. The contact probe
        # is only consulted for rows that have no resolved paragraph, so it never
        # influences an auto_verified outcome.
        reference_address = (
            (selected_chapter, selected_para) if selected_para is not None else None
        )
        if reference_address is None and old_norm and not selected_heading:
            contact_address, _contact_prefix = resolve_contact(old_norm)
            reference_address = contact_address
        legacy_variance_kind = ""
        legacy_variance = ""
        similarity_ratio: float | str = ""
        if old_norm and selected_heading:
            legacy_variance_kind = "heading"
        elif old_norm and reference_address is not None:
            reference_norm = normalized_paragraphs[reference_address]
            legacy_variance_kind = legacy_variance_kind_of(old_norm, reference_norm)
            if legacy_variance_kind == "legacy_redaction":
                reasons.append(REASON_LEGACY_REDACTION)
            elif legacy_variance_kind == "punctuation":
                reasons.append(REASON_PUNCTUATION)
            elif legacy_variance_kind in ("orthographic_variant", "legacy_markup"):
                reasons.append(REASON_LEGACY_TYPO)
            elif legacy_variance_kind == "paragraph_boundary":
                reasons.append(REASON_SEGMENTATION)
            elif legacy_variance_kind == "wording":
                similarity_ratio = round(
                    difflib.SequenceMatcher(None, old_norm, reference_norm).ratio(), 4)
                reasons.append(REASON_CONTENT_DIVERGENCE)
            if legacy_variance_kind != "identical":
                tokens = diff_tokens(old_norm, reference_norm)
                legacy_variance = " ".join(
                    f"{tag}:{left or '∅'}->{right or '∅'}" for tag, left, right in tokens
                ) or legacy_variance_kind
        elif old_norm:
            legacy_variance_kind = "no_counterpart"
            legacy_variance = "legacy line has no canonical counterpart"
            reasons.append(REASON_CONTENT_MISSING)
        reasons = list(dict.fromkeys(reasons))

        target = paragraphs.get((selected_chapter, selected_para)) if selected_para is not None else None
        if selected_para is not None and target is None:
            selected_chapter = selected_para = None
        selected_heading = bool(selected_heading and selected_chapter is not None)
        reviewer = reviewed_at = ""
        prior = prior_approvals.get(eid)
        prior_chapter = int(prior["selected_chapter_id"].removeprefix("chapter_")) if prior and prior.get("selected_chapter_id", "").startswith("chapter_") else None
        prior_para = int(prior["selected_paragraph_id"].removeprefix("para_")) if prior and prior.get("selected_paragraph_id", "").startswith("para_") else None
        prior_target = paragraphs.get((prior_chapter, prior_para)) if prior_chapter is not None and prior_para is not None else None
        prior_target_hash = paragraph_hashes.get((prior_chapter, prior_para), "") if prior_chapter is not None and prior_para is not None else ""
        if (prior and prior_target is not None and current_live and decision != DECISION_AUTO
                and prior.get("old_source_sha256") == old_source_sha
                and prior.get("old_text_sha256") == (sha(old_text.encode("utf-8")) if old_text else "")
                and prior.get("new_source_sha256_lf") == rendered_hash
                and prior.get("paragraph_sha256") == prior_target_hash
                and prior.get("reviewer") and prior.get("reviewed_at") and prior.get("review_reason")):
            decision = DECISION_HUMAN
            selected_chapter, selected_para, target = prior_chapter, prior_para, prior_target
            selected_heading = False
            migration_basis = "human_approved"
            withheld = ""
            legacy_variance_kind = prior.get("legacy_variance_kind", legacy_variance_kind)
            reviewer = prior["reviewer"]
            reviewed_at = prior["reviewed_at"]
            reason = prior["review_reason"]
        if selected_heading:
            canonical_locator = f"EPUB:chapter_{selected_chapter:04d}:{HEADING_PARAGRAPH_ID}"
            target_hash = heading_hashes[selected_chapter]
        elif selected_chapter is not None and selected_para is not None and target is not None:
            canonical_locator = f"EPUB:chapter_{selected_chapter:04d}:para_{selected_para:03d}"
            target_hash = paragraph_hashes.get((selected_chapter, selected_para), "")
        else:
            canonical_locator = ""
            target_hash = ""
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
            "address_schema_version": "epub-chapter-para-heading-v1",
            "legacy_match_class": row["class"] if row else "not_in_legacy_map",
            "legacy_mapped_chapter_id": f"chapter_{mapped_chapter:04d}" if mapped_chapter is not None and mapped_target else "",
            "legacy_mapped_paragraph_id": f"para_{mapped_para:03d}" if mapped_para is not None and mapped_target else "",
            "legacy_address_matches_text": str(mapped_target_matches).lower(),
            "selected_chapter_id": (f"chapter_{selected_chapter:04d}"
                                    if selected_chapter is not None and (target or selected_heading) else ""),
            "selected_paragraph_id": (f"para_{selected_para:03d}"
                                      if selected_para is not None and target else ""),
            "selected_locator_kind": HEADING_PARAGRAPH_ID if selected_heading else ("para" if target else ""),
            "canonical_locator": canonical_locator,
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
            "primary_blocker_class": primary_blocker_class,
            "withheld_reason": withheld,
            "secondary_reason_json": json.dumps(reasons, ensure_ascii=False),
            "human_review_required": str(current_live and decision == DECISION_BLOCKED).lower(),
            "migration_basis": migration_basis,
            "legacy_variance": legacy_variance,
            "legacy_variance_kind": legacy_variance_kind,
            "similarity_ratio": similarity_ratio,
            "legacy_variance_tokens_json": json.dumps(tokens, ensure_ascii=False),
            "segment_label_flag": str(segment_label_flag).lower(),
            "positional_admission": admission,
            "reviewer": reviewer,
            "reviewed_at": reviewed_at,
            "review_reason": reason,
            "mapping_version": "1",
        }
        decisions.append(item)
        decision_by_eid[eid] = item

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_tsv(
        args.out_dir / "eid-migration-decisions.tsv",
        list(DECISION_COLUMNS),
        [{key: item[key] for key in DECISION_COLUMNS} for item in decisions],
    )
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
    live_items = [item for item in decisions if item["scope"] == "live"]
    # —— Invariants: the blocker partition must be strict and complete ——
    blocker_partition = collections.Counter(
        item["primary_blocker_class"] for item in live_items if item["primary_blocker_class"])
    if sum(blocker_partition.values()) != BASELINE_BLOCKER_TOTAL:
        raise ValueError(
            f"baseline blocker partition covers {sum(blocker_partition.values())} rows, "
            f"expected {BASELINE_BLOCKER_TOTAL}")
    unknown = set(blocker_partition) - set(BLOCKER_CLASS_ORDER)
    if unknown:
        raise ValueError(f"unclassified blocker classes: {sorted(unknown)}")
    # Rows with no blocker class are exactly the baseline auto-verified set; a
    # few of those may still be withheld when their only candidate sits in a
    # duplicate / alternate-version chapter.
    baseline_auto_rows = sum(1 for item in live_items if not item["primary_blocker_class"])
    if baseline_auto_rows != BASELINE_AUTO_TOTAL:
        raise ValueError(
            f"baseline auto_verified set is {baseline_auto_rows} rows, expected {BASELINE_AUTO_TOTAL}")
    baseline_demoted = sum(
        1 for item in live_items
        if not item["primary_blocker_class"] and item["decision"] != DECISION_AUTO)
    terminal = collections.Counter(item["decision"] for item in live_items)
    if sum(terminal.values()) != len(live_items):
        raise ValueError("live decisions do not partition the live E-ID set")
    if baseline_auto_rows + sum(blocker_partition.values()) != len(live_items):
        raise ValueError("auto-verified and blocker rows do not partition the live E-ID set")
    unresolved = [item for item in live_items if item["decision"] == DECISION_BLOCKED]
    if any(item["canonical_locator"] for item in unresolved):
        raise ValueError("a blocked row still carries a canonical locator")
    # Every blocked row must be explained: either by its baseline blocker class, or
    # by the duplicate/alternate-version demotion (which can also catch rows that
    # were baseline auto-verified and therefore carry no blocker class).
    stray = [item for item in unresolved
             if not item["primary_blocker_class"] and item["withheld_reason"] != "ambiguous_region"]
    if stray:
        raise ValueError(
            f"{len(stray)} blocked rows lack both a locator and a blocker class: "
            f"{[item['eid'] for item in stray[:5]]}")
    demoted_rows = [item for item in unresolved
                    if item["withheld_reason"] == "ambiguous_region"
                    and not item["primary_blocker_class"]]
    if len(demoted_rows) != baseline_demoted:
        raise ValueError("ambiguous-region demotions do not reconcile with baseline_withheld count")

    coverage = []
    for page, page_eids in sorted(wiki_pages.items()):
        counts = collections.Counter(decision_by_eid[eid]["decision"] for eid in page_eids)
        block_classes = collections.Counter(
            decision_by_eid[eid]["primary_blocker_class"] for eid in page_eids
            if decision_by_eid[eid]["decision"] == DECISION_BLOCKED)
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
            "auto_verified": counts[DECISION_AUTO],
            "human_approved": counts[DECISION_HUMAN],
            "human_review_required": counts[DECISION_BLOCKED],
            "blocked_by_primary_class_json": json.dumps(
                sorted(block_classes.items()), ensure_ascii=False),
            "unmapped_eids_json": json.dumps(unmapped, ensure_ascii=False),
            "coverage_scope": "unique E-IDs extracted from current active Wiki content",
        })
    write_tsv(args.out_dir / "migration-page-coverage.tsv", list(coverage[0].keys()) if coverage else [], coverage)

    index_digest = hashlib.sha256()
    index_path = args.out_dir / "chapter-paragraph-index.tsv"
    paragraphs_by_chapter: dict[int, list[tuple[int, str]]] = collections.defaultdict(list)
    for (chapter_id, para_id), paragraph_hash in paragraph_hashes.items():
        paragraphs_by_chapter[chapter_id].append((para_id, paragraph_hash))
    with index_path.open("w", encoding="utf-8", newline="\n") as index_stream:
        header = "chapter_id\tchapter_title\tparagraph_id\tparagraph_sha256\n"
        index_stream.write(header)
        index_digest.update(header.encode("utf-8"))
        for chapter_id in sorted(titles):
            for para_id, paragraph_hash in sorted(paragraphs_by_chapter[chapter_id]):
                line = (f"chapter_{chapter_id:04d}\t{titles[chapter_id]}\t"
                        f"para_{para_id:03d}\t{paragraph_hash}\n")
                index_stream.write(line)
                index_digest.update(line.encode("utf-8"))

    withheld_counts = collections.Counter(
        item["withheld_reason"] for item in live_items if item["withheld_reason"])
    basis_counts = collections.Counter(item["migration_basis"] for item in live_items)
    variance_counts = collections.Counter(
        item["legacy_variance_kind"] for item in live_items if item["legacy_variance_kind"])
    reason_counts = collections.Counter(
        reason for item in live_items for reason in json.loads(item["secondary_reason_json"]))
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
        "address_schema": "EPUB:chapter_N:para_M | EPUB:chapter_N:heading (paragraph IDs are per chapter, 1-based)",
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
        "eids_auto_verified": sum(item["decision"] == DECISION_AUTO for item in live_items),
        "eids_human_approved": sum(item["decision"] == DECISION_HUMAN for item in live_items),
        "eids_blocked": sum(item["decision"] == DECISION_BLOCKED for item in live_items),
        "eids_human_review_required": sum(
            item["human_review_required"] == "true" for item in live_items),
        "baseline_blocker_total": BASELINE_BLOCKER_TOTAL,
        "baseline_blocker_partition": dict(sorted(blocker_partition.items())),
        "baseline_auto_total": BASELINE_AUTO_TOTAL,
        "baseline_auto_withheld_ambiguous_region": baseline_demoted,
        "migration_basis_counts": dict(sorted(basis_counts.items())),
        "blocked_by_withheld_reason": dict(sorted(withheld_counts.items())),
        "legacy_variance_by_kind": dict(sorted(variance_counts.items())),
        "secondary_reason_counts": dict(sorted(reason_counts.items())),
        "backbone_anchor_count": len(backbone),
        "backbone_dropped_legacy_lines": backbone_dropped,
        "ambiguous_chapters": sorted(AMBIGUOUS_CHAPTERS),
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
        "decision_policy": (
            "auto_verified = the E-ID's locator is uniquely determined and order-consistent. The EPUB is "
            "the text truth and the old TXT is only a legacy evidence-recovery source, so wording that "
            "differs between them does NOT by itself withhold a row; it is recorded in legacy_variance. "
            "Resolution bases: exact_full_paragraph (the legacy line uniquely equals a canonical paragraph), "
            "positional_alignment (the closed interval between two verified anchors is an exact one-to-one "
            "match of prose lines onto paragraphs, so the slot is forced by order alone; the canonical text "
            "is never normalized towards the legacy wording), heading_locator (the legacy 节 heading resolves "
            "to a unique chapter heading), human_approved (human reviewed). blocked = no position could be "
            "pinned, or the resolution landed in a duplicate/alternate-version chapter; every blocked live "
            "row carries human_review_required=true."
        ),
        "blocker_class_priority": list(BLOCKER_CLASS_ORDER),
        "withheld_reason_vocabulary": [
            "blank_or_out_of_range", "heading_unresolved", "multiple_candidates", "unbounded_window",
            "segment_alignment", "context_too_wide", "slot_outside_anchor_window",
            "positional_text_divergence", "ambiguous_region",
        ],
        "context_alignment": {
            "max_context_span_lines": MAX_CONTEXT_SPAN,
            "similarity_floor": SIMILARITY_FLOOR,
            "min_boundary_chars": MIN_BOUNDARY_CHARS,
            "legacy_markup_fold": LEGACY_MARKUP_DESC,
            "structural_markers": list(STRUCTURAL_MARKERS),
        },
        "secondary_reason_vocabulary": [
            REASON_LEGACY_TYPO, REASON_LEGACY_REDACTION, REASON_SEGMENTATION,
            REASON_CONTENT_MISSING, REASON_TRUE_AMBIGUITY,
            REASON_PUNCTUATION, REASON_CONTENT_DIVERGENCE,
        ],
        "variant_fold": VARIANT_FOLD_DESC,
    }
    (args.out_dir / "epub-canonical-build-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
