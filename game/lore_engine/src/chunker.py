"""Deterministic source section parsing for the V1 corpus slice."""

from __future__ import annotations

import hashlib
import re
from collections.abc import Iterator

from .contracts import ChunkConfig, ChunkRecord, SectionRecord


_VOLUME_RE = re.compile(r"^第([一二三四五六七八九十百千万零〇两0-9]+)卷[:：].*$")
_SECTION_RE = re.compile(r"^第([一二三四五六七八九十百千万零〇两0-9]+)节[:：].*$")


def _number(value: str) -> int:
    if value.isdigit():
        return int(value)
    digits = {"零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}
    units = {"十": 10, "百": 100, "千": 1000, "万": 10000}
    total = 0
    current = 0
    section = 0
    for char in value:
        if char in digits:
            current = digits[char]
        elif char in units:
            unit = units[char]
            if unit == 10000:
                section = (section + current) * unit
                total += section
                section = 0
                current = 0
            else:
                section += (current or 1) * unit
                current = 0
    return total + section + current


def _offsets(text: str) -> list[int]:
    offsets = [0]
    for char in text:
        offsets.append(offsets[-1] + len(char.encode("utf-8")))
    return offsets


def parse_sections(text: str, volume_limit: int = 1, section_limit: int = 10) -> tuple[SectionRecord, ...]:
    lines = text.splitlines(keepends=True)
    starts: list[int] = []
    cursor = 0
    for line in lines:
        starts.append(cursor)
        cursor += len(line)
    byte_offsets = _offsets(text)
    volume = 0
    all_headings: list[tuple[int, int, str, str, int]] = []
    selected: list[tuple[int, int, str, int]] = []
    for index, line in enumerate(lines):
        raw = line.rstrip("\r\n")
        volume_match = _VOLUME_RE.match(raw)
        if volume_match:
            volume = _number(volume_match.group(1))
            all_headings.append((starts[index], index, "volume", raw.strip(), volume))
            continue
        section_match = _SECTION_RE.match(raw)
        if section_match:
            chapter = _number(section_match.group(1))
            if raw.startswith((" ", "\t")):
                continue
            all_headings.append((starts[index], index, "section", raw.strip(), chapter))
            if volume == volume_limit and len(selected) < section_limit:
                selected.append((starts[index], index, raw.strip(), chapter))

    records: list[SectionRecord] = []
    for position, (heading_start, line_index, title, chapter) in enumerate(selected):
        content_start = heading_start + len(lines[line_index])
        while content_start < len(text) and text[content_start] in "\r\n \t":
            content_start += 1
        next_heading = next(
            (item for item in all_headings if item[0] > heading_start),
            None,
        )
        end = next_heading[0] if next_heading is not None else len(text)
        end_line = next_heading[1] if next_heading is not None else len(lines)
        item_diagnostics = tuple(
            "indented_heading"
            for candidate_line in lines[line_index + 1 : end_line]
            if candidate_line.startswith((" ", "\t")) and _SECTION_RE.match(candidate_line.lstrip().rstrip("\r\n"))
        )
        content = text[content_start:end]
        while content.endswith(("\r", "\n", " ", "\t")):
            content = content[:-1]
            end -= 1
        source_id = f"V{volume_limit:02d}-C{chapter:03d}"
        records.append(
            SectionRecord(
                source_id=source_id,
                source_file_id="gu_zhenren_main",
                volume=volume_limit,
                chapter=chapter,
                title=title,
                sequence=position + 1,
                start_offset=content_start,
                end_offset=end,
                start_byte=byte_offsets[content_start],
                end_byte=byte_offsets[end],
                text=content,
                text_hash=hashlib.sha256(content.encode("utf-8")).hexdigest(),
                diagnostics=item_diagnostics,
            )
        )
    return tuple(records)


def iter_chunks(section: SectionRecord, text: str, config: ChunkConfig) -> Iterator[ChunkRecord]:
    """Yield contiguous, deterministic chunks without cross-section overlap."""
    if text != section.text:
        raise ValueError("chunk input must equal the section text")
    pieces: list[tuple[int, int]] = []
    paragraphs = list(re.finditer(r".*?(?:\r?\n\r?\n|$)", text, re.DOTALL))
    for match in paragraphs:
        if match.start() == match.end():
            continue
        start, end = match.start(), match.end()
        if end - start > config.max_chars:
            cursor = start
            while cursor < end:
                next_cursor = min(cursor + config.max_chars, end)
                pieces.append((cursor, next_cursor))
                cursor = next_cursor
        elif pieces and end - pieces[-1][0] <= config.target_chars:
            pieces[-1] = (pieces[-1][0], end)
        else:
            pieces.append((start, end))
    if not pieces and text:
        pieces = [(0, len(text))]

    chunks: list[ChunkRecord] = []
    for sequence, (start, end) in enumerate(pieces, start=1):
        chunk_text = text[start:end]
        chunks.append(
            ChunkRecord(
                chunk_id=f"{section.source_id}-S{sequence:02d}",
                source_id=section.source_id,
                source_file_id=section.source_file_id,
                volume=section.volume,
                chapter=section.chapter,
                title=section.title,
                sequence=section.sequence,
                chunk_sequence=sequence,
                start_offset=start,
                end_offset=end,
                start_byte=len(text[:start].encode("utf-8")),
                end_byte=len(text[:end].encode("utf-8")),
                text=chunk_text,
                chunk_hash=hashlib.sha256(chunk_text.encode("utf-8")).hexdigest(),
            )
        )
    for index, chunk in enumerate(chunks):
        yield ChunkRecord(
            **{
                **chunk.__dict__,
                "previous_id": chunks[index - 1].chunk_id if index else None,
                "next_id": chunks[index + 1].chunk_id if index + 1 < len(chunks) else None,
            }
        )
