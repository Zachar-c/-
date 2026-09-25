#!/usr/bin/env python3
"""编译 lore/wiki + canon-index → lore/runtime/（Canon Runtime Projection）。

数据流：Wiki（Source of Truth）→ 本编译器 → lore/runtime/*.json（生成物，不人工维护）。
IR 设计见 docs/design/canon-runtime/2026-09-25-p1-ir.md；审计见同目录 2026-09-25-p0-audit.md。

用法：py -3 lore/wiki/tools/compile_runtime.py

诚实边界：
- 本脚本只做结构化搬运与校验，不产生任何新设定；statement/证据均取自 wiki 行原文。
- Relation 的结构（from/to/inputs/output）在 RELATION_SOURCES 配置中显式声明并锚定到
  具体 ST-/CAN- 行；行文本缺失或措辞漂移导致解析失败时编译报错退出（强迫人工复核），
  不静默产出。自由文本关系挖掘是后续里程碑。
- E-ID 只做「段号↔行号区间」校验（与 check.ps1 check9 同款），不做行内容比对；
  原文身份由 manifest.source.sha256 保护——原文缺失或 hash 变化时拒绝编译。
- 原文蛊真人-clean.txt 不入 Git。查找顺序：仓库根 → （在 .worktrees/* 内时）主检出根。
  也可用 --source 显式指定。
- 「转数未核」段只有蛊名无 id，本版跳过并在 manifest 登记 coverage；
  转数一律取 roster-3「原文转」（Canon 口径），游戏生效值属 Game Projection，不进 runtime。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
OUT_DIR = REPO / "lore" / "runtime"
WIKI = REPO / "lore" / "wiki"
CANON_INDEX = REPO / "game" / "docs" / "lore" / "canon-index.md"
SECTION_INDEX = WIKI / "source" / "section-index.md"

SOURCE_NAME = "蛊真人-clean.txt"
EID_RE = re.compile(r"E:V([1-6])-(\d{5,6})")
CANREF_RE = re.compile(r"CAN-[A-Z0-9]+(?:-[A-Z0-9]+)*")

# —— Relation 结构配置（锚定到 wiki 行；行文本与证据在编译时现取）——
RELATION_SOURCES = [
    {
        "id": "REL-SMALLLIGHT-MOONLIGHT-SUPPORT",
        "source_page": "lore/wiki/gu/small-light-gu.md",
        "st_id": "ST-SMALLLIGHT-03",
        "relation": "supports",
        "from_name": "小光蛊",
        "to_name": "月光蛊",
    },
    {
        "id": "REL-MOONLIGHT-SMALLLIGHT-COCAST",
        "source_page": "lore/wiki/gu/moonlight-gu.md",
        "st_id": "ST-MOONLIGHT-06",
        "relation": "supports",
        "from_name": "小光蛊",
        "to_name": "月光蛊",
        "dedupe_of": "REL-SMALLLIGHT-MOONLIGHT-SUPPORT",
    },
    {
        "id": "REL-REFINE-MOONGLOW",
        "source_page": "lore/wiki/gu/small-light-gu.md",
        "st_id": "ST-SMALLLIGHT-04",
        "relation": "refinement",
        "inputs": [{"name": "月光蛊", "count": 1}, {"name": "小光蛊", "count": 2}],
        "output_name": "月芒蛊",
        "output_rank_from_statement": True,
    },
]

# —— Context Pack 配置（P4；实体用 roster-3 id，规则按 domain / 显式 id 选装）——
PACKS = {
    "south_border_rank1_combat": {
        "description": "南疆一转战斗场景最小知识包：MVP 四蛊 + 修炼/资质/真元/南疆/养蛊/战力阶梯规则 + 基础杀招边界",
        "entities": ["moonlight_gu", "small_light_gu", "moon_glow_gu", "white_boar_strength_gu"],
        "rule_domains": ["cultivation", "aptitude", "true-qi", "nanjiang", "gu-care",
                         "small-light", "rank-ladder", "beast-tier", "beast-tide"],
        "rule_ids": ["REF-001", "REF-002", "REF-004", "REF-005", "REF-008", "KM-001", "KM-002", "KM-003"],
        "rule_exclude_ids": ["PE-006", "PE-007"],  # 仙元属蛊仙层，不进凡人一转场景
        "with_relations": True,
    },
    "rank1_refinement": {
        "description": "一转炼蛊节点最小知识包：炼蛊术语规则 + 养蛊压力 + 小光蛊合炼事实",
        "entities": ["moonlight_gu", "small_light_gu", "moon_glow_gu"],
        "rule_domains": ["gu-care", "small-light", "economy"],
        "rule_ids": [f"REF-{n:03d}" for n in range(1, 13)],
        "with_relations": True,
    },
}

BANNED_KEYS = {"damage", "cooldown", "drop_rate", "success_rate", "value", "cost",
               "price", "balance_value", "hp", "probability"}

CN_NUM = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}


def fail(msg: str) -> None:
    print(f"[compile_runtime] 错误：{msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg: str) -> None:
    print(f"[compile_runtime] 警告：{msg}")


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_source(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit)
        if not p.is_file():
            fail(f"--source 指定的原文不存在：{p}")
        return p
    candidates = [REPO / SOURCE_NAME]
    if REPO.parent.name == ".worktrees":
        candidates.append(REPO.parents[1] / SOURCE_NAME)
    for p in candidates:
        if p.is_file():
            return p
    fail(f"未找到原文 {SOURCE_NAME}（候选：{', '.join(str(c) for c in candidates)}）；"
         f"E-ID 无原文可校验，拒绝编译。")


# ---------- 通用解析 ----------

def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    fm: dict = {}
    key: str | None = None
    for line in text[4:end].splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m and not line.startswith((" ", "\t")):
            key, val = m.group(1), m.group(2).strip()
            if val == "":
                fm[key] = []  # 可能是块列表
            elif val.startswith("[") and val.endswith("]"):
                fm[key] = [v.strip().strip("\"'") for v in val[1:-1].split(",") if v.strip()]
            else:
                fm[key] = val.strip("\"'")
        elif key is not None and line.lstrip().startswith("-"):
            item = line.lstrip()[1:].strip().strip("\"'")
            if isinstance(fm[key], list):
                fm[key].append(item)
    return fm


def split_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def iter_tables(text: str):
    """yield (header_cells, rows)——跳过分隔行；连续 | 行聚为一张表。"""
    block: list[list[str]] = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|"):
            cells = split_row(s)
            if all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                continue
            block.append(cells)
        elif block:
            yield block[0], block[1:]
            block = []
    if block:
        yield block[0], block[1:]


def section_blocks(text: str) -> list[tuple[str, str]]:
    """按 H2 切分正文，返回 [(标题, 块文本)]；H2 之前的前言标题为 ''。"""
    parts = re.split(r"^## +(.+?)\s*$", text, flags=re.M)
    out: list[tuple[str, str]] = [("", parts[0])]
    for i in range(1, len(parts), 2):
        out.append((parts[i].strip(), parts[i + 1]))
    return out


# ---------- section-index 段域 ----------

def load_segment_ranges() -> dict[int, tuple[int, int]]:
    text = SECTION_INDEX.read_text(encoding="utf-8")
    ranges: dict[int, tuple[int, int]] = {}
    cn = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6}
    for header, rows in iter_tables(text):
        if header and header[0] == "段":
            for cells in rows:
                if len(cells) < 2 or cells[0] not in cn:
                    continue
                lo, hi = cells[1].replace(",", "").split("–")
                ranges[cn[cells[0]]] = (int(lo), int(hi))
    if len(ranges) != 6:
        fail(f"section-index.md 段级摘要解析异常：仅得 {len(ranges)} 段")
    return ranges


def validate_eids(eids: list[str], ranges: dict[int, tuple[int, int]]) -> list[str]:
    errors = []
    for eid in sorted(set(eids)):
        m = EID_RE.fullmatch(eid)
        if not m:
            errors.append(f"E-ID 格式异常：{eid}")
            continue
        seg, line = int(m.group(1)), int(m.group(2))
        lo, hi = ranges[seg]
        if not (lo <= line <= hi):
            errors.append(f"E-ID 越段：{eid} 不在段{seg}范围 {lo}-{hi}")
    return errors


# ---------- canon-index（CAN-*）----------

GRADE_RE = re.compile(r"[，,]\s*(A|用户裁定|待原文复核)\s*$")


def compile_canon_rules() -> list[dict]:
    text = CANON_INDEX.read_text(encoding="utf-8")
    rules = []
    for header, rows in iter_tables(text):
        if not header or header[0] != "ID":
            continue
        col = {name: i for i, name in enumerate(header)}
        for cells in rows:
            if len(cells) < len(header) or not cells[0].startswith("CAN-"):
                continue
            cid = cells[col["ID"]]
            evidence_raw = cells[col["证据"]]
            grade_m = GRADE_RE.search(evidence_raw)
            rules.append({
                "id": cid,
                "prefix": "CAN",
                "domain": cid[4:cid.rfind("-")].lower(),
                "statement": cells[col["事实摘要"]],
                "forbidden_misreading": cells[col["禁止误读"]] if "禁止误读" in col else "",
                "grade": grade_m.group(1) if grade_m else "",
                "evidence": [m.group(0) for m in EID_RE.finditer(evidence_raw)],
                "source_line_refs": [seg for m in re.findall(r"蛊真人-clean\.txt:([\d,\-–]+)", evidence_raw)
                                     for seg in re.split(r"[,，]", m) if seg],
                "evidence_raw": evidence_raw,
                "provenance": {"wiki_page": "game/docs/lore/canon-index.md",
                               "applicable_systems": cells[col["适用系统"]] if "适用系统" in col else ""},
            })
    if not rules:
        fail("canon-index.md 未解析到任何 CAN-* 行")
    return rules


# ---------- roster-3（Entity 骨架）----------

ROSTER_STATUS = {
    "转数分叉·未决": "divergence",
    "命名重用异常": "name_reuse",
    "品阶上限压缩": "rank_cap",
    "多时点口径": "timepoint",
    "一致": "verified",
    "裁定已改": "verified",
    "命名碰撞待核": "collision",
}


def compile_roster_entities() -> tuple[list[dict], dict[str, str], int]:
    text = (WIKI / "gu" / "roster-3.md").read_text(encoding="utf-8")
    entities: list[dict] = []
    name_to_id: dict[str, str] = {}
    unverified_count = 0
    for title, block in section_blocks(text):
        status = None
        for key, st in ROSTER_STATUS.items():
            if title.startswith(key):
                status = st
                break
        if status is None:
            if title.startswith("转数未核"):
                for m in re.finditer(r"（(\d+)）", block):
                    unverified_count += int(m.group(1))
            continue
        for header, rows in iter_tables(block):
            col = {name: i for i, name in enumerate(header)}
            if "id" not in col or "蛊名" not in col:
                continue
            for cells in rows:
                if len(cells) < len(header) or not cells[col["id"]].endswith("_gu"):
                    continue
                gid = cells[col["id"]]
                name = cells[col["蛊名"]]
                lore_rank = cells[col["原文转"]] if "原文转" in col else ""
                rank = int(lore_rank) if lore_rank.isdigit() else None
                anchor = cells[col["锚点"]] if "锚点" in col else ""
                if gid in {e["id"] for e in entities}:
                    fail(f"roster-3 出现重复 id：{gid}")
                if name in name_to_id and name_to_id[name] != gid:
                    warn(f"蛊名重用：{name} 同时对应 {name_to_id[name]} 与 {gid}（Relation 配置勿引用歧义名）")
                entities.append({
                    "id": gid,
                    "type": "gu",
                    "name": name,
                    "aliases": [],
                    "description": "",
                    "properties": {"rank": rank, "rank_status": status},
                    "evidence": [m.group(0) for m in EID_RE.finditer(anchor)],
                    "provenance": {"wiki_pages": ["lore/wiki/gu/roster-3.md"], "canon_refs": []},
                })
                name_to_id[name] = gid
    if len(entities) < 100:
        fail(f"roster-3 解析异常：仅得 {len(entities)} 个实体")
    return entities, name_to_id, unverified_count


# ---------- 实体页合并（description/aliases/canon_refs）----------

def merge_entity_pages(entities: list[dict]) -> list[str]:
    by_id = {e["id"]: e for e in entities}
    merged = []
    for page in sorted((WIKI / "gu").glob("*.md")):
        if page.name in ("index.md",) or page.name.startswith(("roster", "m0-")):
            continue
        fm = parse_frontmatter(page.read_text(encoding="utf-8"))
        if fm.get("type") != "gu":
            continue
        eid = page.stem.replace("-", "_")
        ent = by_id.get(eid)
        if ent is None:
            warn(f"实体页 {page.name} 的 id {eid} 不在 roster-3 解析结果中，跳过")
            continue
        ent["name"] = fm.get("name", ent["name"])
        ent["aliases"] = [a for a in fm.get("aliases", []) if a != ent["name"]]
        ent["description"] = fm.get("description", "")
        ent["provenance"]["wiki_pages"].append(f"lore/wiki/gu/{page.name}")
        ent["provenance"]["canon_refs"] = [
            s.split(":", 1)[1] for s in fm.get("sources", []) if s.startswith("canon-index:")]
        merged.append(eid)
    return merged


# ---------- 规则页（REF/KM/无 ID 规则表）----------

RULE_PAGES = [
    ("lore/wiki/rules/refinement.md", "refinement", "REF"),
    ("lore/wiki/rules/killer-moves.md", "killer-move", "KM"),
]
GENERATED_PREFIX = {"lore/wiki/world/primeval-essence.md": ("PE", "true-qi")}


def compile_page_rules() -> list[dict]:
    rules: list[dict] = []
    st_index: dict[str, dict] = {}
    for rel, domain, prefix in RULE_PAGES:
        text = (REPO / rel).read_text(encoding="utf-8")
        for header, rows in iter_tables(text):
            if "ID" not in header:
                continue
            col = {name: i for i, name in enumerate(header)}
            stmt_col = next((c for c in ("内容", "规则") if c in col), None)
            if stmt_col is None:
                continue
            for cells in rows:
                if len(cells) < len(header) or not re.fullmatch(r"[A-Z]{2,4}-\d{3}", cells[col["ID"]]):
                    continue
                rid = cells[col["ID"]]
                if not rid.startswith(prefix):
                    warn(f"{rel}: 行 {rid} 前缀与页面预期 {prefix} 不符，仍收录")
                ev_raw = cells[col["证据"]] if "证据" in col else ""
                rules.append({
                    "id": rid,
                    "prefix": prefix,
                    "domain": domain,
                    "term": cells[col["术语/规则"]] if "术语/规则" in col else "",
                    "statement": cells[col[stmt_col]],
                    "forbidden_misreading": cells[col["禁止误读"]] if "禁止误读" in col else "",
                    "evidence": [m.group(0) for m in EID_RE.finditer(ev_raw)],
                    "evidence_raw": ev_raw,
                    "provenance": {"wiki_page": rel, "generated_id": False},
                })
    for rel, (prefix, domain) in GENERATED_PREFIX.items():
        text = (REPO / rel).read_text(encoding="utf-8")
        for header, rows in iter_tables(text):
            if "规则" not in header or "ID" in header:
                continue
            col = {name: i for i, name in enumerate(header)}
            n = 0
            for cells in rows:
                if len(cells) < len(header):
                    continue
                n += 1
                ev_raw = cells[col["证据"]] if "证据" in col else ""
                rules.append({
                    "id": f"{prefix}-{n:03d}",
                    "prefix": prefix,
                    "domain": domain,
                    "term": cells[col["规则"]],
                    "statement": cells[col["内容"]],
                    "forbidden_misreading": "",
                    "evidence": [m.group(0) for m in EID_RE.finditer(ev_raw)],
                    "evidence_raw": ev_raw,
                    "provenance": {"wiki_page": rel, "generated_id": True},
                })
    return rules


# ---------- 状态行索引（供 Relation 取文本/证据）----------

def index_state_rows() -> dict[str, dict]:
    idx: dict[str, dict] = {}
    for rel in ("lore/wiki/gu/moonlight-gu.md", "lore/wiki/gu/small-light-gu.md"):
        text = (REPO / rel).read_text(encoding="utf-8")
        for header, rows in iter_tables(text):
            if not header or header[0] != "状态 ID":
                continue
            col = {name: i for i, name in enumerate(header)}
            for cells in rows:
                if len(cells) < len(header) or not cells[0].startswith("ST-"):
                    continue
                idx[cells[0]] = {
                    "page": rel,
                    "stage": cells[col["阶段"]],
                    "statement": cells[col["状态"]],
                    "evidence": [m.group(0) for m in EID_RE.finditer(cells[col["证据"]])],
                    "canon_refs": CANREF_RE.findall(cells[col["证据"]]),
                }
    return idx


def compile_relations(name_to_id: dict[str, str], st_index: dict[str, dict]) -> list[dict]:
    relations = []
    seen: set[str] = set()
    for cfg in RELATION_SOURCES:
        if cfg.get("dedupe_of"):
            continue  # 同一事实的第二处 ST 行仅作交叉确认（存在性已在 st_index 校验），不重复产出
        st = st_index.get(cfg["st_id"])
        if st is None:
            fail(f"Relation 配置引用的状态行不存在：{cfg['st_id']}（{cfg['source_page']}）")
        rel: dict = {
            "id": cfg["id"],
            "relation": cfg["relation"],
            "statement": st["statement"],
            "evidence": st["evidence"],
            "provenance": {"wiki_page": cfg["source_page"], "state_ids": [cfg["st_id"]],
                           "canon_refs": st["canon_refs"]},
        }
        if cfg["relation"] == "supports":
            for key in ("from_name", "to_name"):
                if cfg[key] not in name_to_id:
                    fail(f"Relation {cfg['id']}：名称「{cfg[key]}」无法解析为实体 id")
            rel["from"] = name_to_id[cfg["from_name"]]
            rel["to"] = name_to_id[cfg["to_name"]]
        else:  # refinement
            inputs, out = [], name_to_id.get(cfg["output_name"])
            if out is None:
                fail(f"Relation {cfg['id']}：产物「{cfg['output_name']}」无法解析为实体 id")
            for item in cfg["inputs"]:
                iid = name_to_id.get(item["name"])
                if iid is None:
                    fail(f"Relation {cfg['id']}：材料「{item['name']}」无法解析为实体 id")
                inputs.extend([iid] * item["count"])
            rel["inputs"] = inputs
            rel["output"] = out
            m = re.search(r"([一二三四五六七八九])转", st["statement"])
            if cfg.get("output_rank_from_statement") and m:
                rel["output_rank"] = CN_NUM[m.group(1)]
        if rel["id"] in seen:
            fail(f"Relation id 重复：{rel['id']}")
        seen.add(rel["id"])
        relations.append(rel)
    return relations


# ---------- Context Pack ----------

def build_packs(entities: list[dict], rules: list[dict], relations: list[dict],
                source_info: dict) -> dict[str, dict]:
    by_id = {e["id"]: e for e in entities}
    packs = {}
    for pid, cfg in PACKS.items():
        missing = [eid for eid in cfg["entities"] if eid not in by_id]
        if missing:
            fail(f"Pack {pid} 引用不存在的实体：{missing}")
        pack_entities = [by_id[eid] for eid in cfg["entities"]]
        excluded = set(cfg.get("rule_exclude_ids", []))
        pack_rules = [r for r in rules
                      if r["id"] not in excluded
                      and (r["domain"] in cfg["rule_domains"] or r["id"] in cfg["rule_ids"])]
        got_ids = {r["id"] for r in pack_rules}
        lack = [rid for rid in cfg["rule_ids"] if rid not in got_ids]
        if lack:
            fail(f"Pack {pid} 请求的规则未编译出来：{lack}")
        pack_rels = []
        if cfg.get("with_relations"):
            ent_set = set(cfg["entities"])
            pack_rels = [r for r in relations if
                         (r.get("from") in ent_set and r.get("to") in ent_set)
                         or (r.get("output") in ent_set and set(r.get("inputs", [])) <= ent_set)]
        packs[pid] = {
            "id": pid,
            "description": cfg["description"],
            "source": {k: source_info[k] for k in ("id", "sha256", "lines")},
            "entities": pack_entities,
            "rules": pack_rules,
            "relations": pack_rels,
        }
    return packs


# ---------- 校验与输出 ----------

def scan_banned_keys(obj, path="$") -> list[str]:
    errors = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k.lower() in BANNED_KEYS:
                errors.append(f"{path}.{k}：禁入字段（Game Projection 专属）")
            errors.extend(scan_banned_keys(v, f"{path}.{k}"))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            errors.extend(scan_banned_keys(v, f"{path}[{i}]"))
    return errors


def write_json(path: Path, data) -> bytes:
    text = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")
    return text.encode("utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", help="显式指定蛊真人-clean.txt 路径（默认自动查找）")
    args = ap.parse_args()

    src = find_source(args.source)
    digest = sha256_of(src)
    lines = len(src.read_text(encoding="utf-8").splitlines())
    source_info = {"id": "gu_zhenren_clean", "path": str(src), "sha256": digest,
                   "lines": lines}
    print(f"[compile_runtime] 原文：{src}")
    print(f"[compile_runtime] sha256={digest[:16]}… 行数={lines}")

    ranges = load_segment_ranges()
    canon_rules = compile_canon_rules()
    entities, name_to_id, unverified = compile_roster_entities()
    merged_pages = merge_entity_pages(entities)
    page_rules = compile_page_rules()
    st_index = index_state_rows()
    relations = compile_relations(name_to_id, st_index)
    rules = canon_rules + page_rules

    # 规则 id 唯一性
    ids = [r["id"] for r in rules]
    if len(ids) != len(set(ids)):
        dup = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"规则 id 重复：{dup}")

    # E-ID 段域校验（全对象收集）
    all_eids = [e for ent in entities for e in ent["evidence"]]
    all_eids += [e for r in rules for e in r["evidence"]]
    all_eids += [e for r in relations for e in r["evidence"]]
    eid_errors = validate_eids(all_eids, ranges)
    if eid_errors:
        fail("E-ID 校验失败：\n  " + "\n  ".join(eid_errors))

    # CAN 原始行号引用不超过原文总行数
    line_errors = []
    for r in rules:
        for ref in r.get("source_line_refs", []):
            end_line = int(ref.split("-")[-1])
            if not (0 < end_line <= lines):
                line_errors.append(f"{r['id']} 原文行号越界：{ref}")
    if line_errors:
        fail("原文行号校验失败：\n  " + "\n  ".join(line_errors))

    # 引用完整性
    ent_ids = {e["id"] for e in entities}
    for r in relations:
        refs = [r.get("from"), r.get("to"), r.get("output"), *r.get("inputs", [])]
        bad = [x for x in refs if x is not None and x not in ent_ids]
        if bad:
            fail(f"Relation {r['id']} 引用不存在的实体：{bad}")
    compiled_cans = {r["id"] for r in rules if r["prefix"] == "CAN"}
    for ent in entities:
        bad = [c for c in ent["provenance"]["canon_refs"] if c not in compiled_cans]
        if bad:
            fail(f"实体 {ent['id']} 引用未登记的 CAN：{bad}")

    entities.sort(key=lambda e: e["id"])
    rules.sort(key=lambda r: (r["prefix"], r["id"]))
    relations.sort(key=lambda r: r["id"])

    banned = scan_banned_keys({"entities": entities, "rules": rules, "relations": relations})
    if banned:
        fail("禁入字段扫描失败：\n  " + "\n  ".join(banned))

    counts = {
        "entities": len(entities),
        "rules_can": len(canon_rules),
        "rules_page": len(page_rules),
        "rules_total": len(rules),
        "relations": len(relations),
    }
    manifest = {
        "manifest_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "compiler": "lore/wiki/tools/compile_runtime.py",
        "ir_spec": "docs/design/canon-runtime/2026-09-25-p1-ir.md",
        "source": source_info,
        "scope": {
            "canon_index": "game/docs/lore/canon-index.md（全部 CAN-*）",
            "roster": "lore/wiki/gu/roster-3.md（六个 id 分段；「转数未核」仅蛊名无 id，跳过）",
            "entity_pages": merged_pages,
            "rule_pages": [rel for rel, _, _ in RULE_PAGES] + list(GENERATED_PREFIX),
        },
        "counts": counts,
        "coverage_notes": (
            f"rank 覆盖 {counts['entities']}/270（转数未核 {unverified} 只仅有蛊名无 id，未编译）；"
            "rank 取 roster-3「原文转」口径；游戏生效值（gu.json.rank）属 Game Projection 不在本层。"
        ),
        "rule": "Wiki = Source of Truth；本目录全部为生成物，重跑编译器完全重建，不人工维护。",
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    blobs = [
        write_json(OUT_DIR / "entities.json", {"entities": entities}),
        write_json(OUT_DIR / "rules.json", {"rules": rules}),
        write_json(OUT_DIR / "relations.json", {"relations": relations}),
    ]
    packs = build_packs(entities, rules, relations, source_info)
    pack_dir = OUT_DIR / "packs"
    pack_dir.mkdir(exist_ok=True)
    for pid, data in packs.items():
        blobs.append(write_json(pack_dir / f"{pid}.json", data))
    manifest["content_version"] = hashlib.sha256(b"".join(blobs)).hexdigest()
    write_json(OUT_DIR / "manifest.json", manifest)

    print(f"[compile_runtime] 完成：{counts}，packs={list(packs)}，"
          f"content_version={manifest['content_version'][:16]}…")
    print(f"[compile_runtime] 输出：{OUT_DIR}")


if __name__ == "__main__":
    main()
