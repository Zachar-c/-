"""Build a read-only view of the existing Wiki and game art snapshots."""
from __future__ import annotations

import html
import json
import re
import shutil
from collections import Counter
from pathlib import Path, PurePosixPath

import yaml
from bs4 import BeautifulSoup
from markdown_it import MarkdownIt
from PIL import Image, ImageOps

PROJECT = Path(__file__).resolve().parents[3]
WIKI = PROJECT / "lore/wiki"
ART = PROJECT / "game/assets/wenzhen"
ROOT = Path(__file__).resolve().parent
WEB = ROOT / "app"
DIST = WEB / "dist"

CATEGORIES = {
    "characters": "人物", "gu": "蛊虫", "events": "事件", "world": "世界",
    "rules": "规则", "themes": "主题", "source": "来源说明", "paths": "阅读路径",
}
ART_GROUPS = {"bg": "背景", "enemies": "敌人", "gu": "蛊虫美术", "hall": "场景", "npc": "人物美术", "web": "网页场景", "textures": "纹理", "icons": "图标"}

# 旧 slug → 当前 canonical 路由。页面按游戏 id 口径改名后，旧链接只做跳转，不复制页面内容。
# 来源：2026-09-28 白豕蛊/驭犬蛊/月旋蛊/春秋蝉 四页由语义 slug 改为游戏 id 口径；
# 前两对经站点仓库 dist/data.json 历史比对（页面标题一致）确证，后两对据上一轮构建的旧路由记录。
ROUTE_ALIASES = {
    "/gu/white-boar-gu": "/gu/white-boar-strength-gu",
    "/gu/beast-taming-gu": "/gu/slave-atk-1-03-gu",
    "/gu/moon-spin-gu": "/gu/light-atk-1-01-gu",
    "/gu/spring-autumn-cicada": "/gu/spring-autumn-cicada-gu",
}

# L1 DECISION 2026-09-30：仅此 10 kind；frontmatter.kind 为准
KINDS = {
    "character": "人物", "gu": "蛊虫", "event": "事件", "world": "世界",
    "path": "流派", "rule": "规则", "theme": "主题",
    "index": "总表", "relation": "关系", "reference": "资料",
}
KIND_GROUP_KNOWLEDGE = ["character", "gu", "event", "world", "path", "rule", "theme"]
KIND_GROUP_META = ["index", "relation", "reference"]
META_TITLE_RE = re.compile(r"总表|名录|索引|总览|骨架|名单|图谱")
RELATION_TITLE_RE = re.compile(r"关系|能力来源|原著边界")
SCHOOL_SLUG_RE = re.compile(r"-path$|^path-roster$")


def infer_kind(category: str, route: str, title: str) -> str:
    slug = route.rsplit("/", 1)[-1]
    if category == "home" or slug == "wiki-home":
        return "index"
    if category in ("paths", "source"):
        return "reference"
    if slug == "index" or route.endswith("/index"):
        return "index"
    if slug.startswith("visual-"):
        return "reference"
    if category == "rules":
        return "rule"
    if category == "themes":
        return "theme"
    if category == "world":
        if slug == "path-roster":
            return "index"
        if SCHOOL_SLUG_RE.search(slug):
            return "path"
        if META_TITLE_RE.search(title):
            return "index"
        return "world"
    if category == "events":
        if slug == "story-arc-overview" or META_TITLE_RE.search(title):
            return "index"
        return "event"
    if category == "characters":
        if META_TITLE_RE.search(title) or slug.startswith("roster") or slug == "enemy-roster":
            return "index"
        return "character"
    if category == "gu":
        if RELATION_TITLE_RE.search(title) or slug in ("gu-relations", "cultivator-effects-and-scouting", "m0-six-gu"):
            return "relation"
        if META_TITLE_RE.search(title) or slug.startswith("roster"):
            return "index"
        return "gu"
    return "reference"


def page_kind(category: str, route: str, title: str, fm_kind) -> str:
    if fm_kind and fm_kind in KINDS:
        return fm_kind
    return infer_kind(category, route, title)


GAME = PROJECT / "game/data"
md = MarkdownIt("default", {"html": False, "linkify": False}).enable("table")

# 「主题档案」页型（提案结构）：每个主题内按三层知识区分
THEME_LAYERS = {"原著事实": "canon", "合理推导": "research", "《问真》实现": "game"}
BULLET_RE = re.compile(r"^-\s+\*\*(原著事实|合理推导|《问真》实现)\*\*")
# 主题内的三层也可以用 H4 小标题写（`#### 原著事实`），与 `- **原著事实**` 等价，两种写法都要认
THEME_HEAD_RE = re.compile(r"^#{4}\s+(原著事实|合理推导|《问真》实现)\s*(.*)$")
# 章节名可能带括注（如「原著明确内容（本批取证窗口登记）」）：层归属只认主名，
# 括注属批次/说明信息，不改变该章属于哪一层
HEAD_NOTE_RE = re.compile(r"^(.*?)\s*（[^（）]*）\s*$")
SECTION_LAYER = {
    "主题档案": "mixed", "状态时间线": "canon", "原著明确内容": "canon", "事件链": "canon",
    "资料整理": "notes", "分析与解读": "research", "待核对": "gap", "模板扩展建议": "meta",
}
SECTION_KIND = {
    "主题档案": "themes", "状态时间线": "state", "原著明确内容": "canon", "事件链": "events",
    "资料整理": "notes", "分析与解读": "analysis", "待核对": "gaps", "模板扩展建议": "proposal",
}


def section_key(title: str) -> str:
    """章节名的主名：去掉尾部括注后再查层归属表。"""
    m = HEAD_NOTE_RE.match(title)
    return m.group(1) if m else title


GU_STAT_KEYS = ["rank", "rarity", "school", "role", "slot_role", "value", "feeding_cost", "feed_points",
                "essence_cost", "true_qi_cost", "replace_value", "v1_effect", "buildRole", "buildTags",
                "synergy_hooks", "combat", "field_actions", "canon_refs", "canon_anchors", "source_class"]
EV_RE = re.compile(r"E:V(\d)-(\d{6})(?:(（)(\d{4,6})[–\-—](\d{4,6})\s*行(）)|(?=，(\d{4,6})[–\-—](\d{4,6})\s*行))?")
STATE_RE = re.compile(r"\[(已确认|待取证|尚未整理|原著未明确|合理推导|存在冲突)\]")


def state_chips(fragment: str) -> str:
    """把 6 状态词表的 [状态] 写法转成可见的标记。"""
    return STATE_RE.sub(lambda m: f'<span class="st st-{m.group(1)}">{m.group(1)}</span>', fragment)


def render_md(text: str) -> str:
    return ev_buttons(state_chips(md.render(text)))


def ev_buttons(fragment: str) -> str:
    """把正文中的证据 ID 转成可点开的按钮，行号作为并列文本保留。"""
    def rep(m: re.Match) -> str:
        ev = f"E:V{m.group(1)}-{m.group(2)}"
        start, end = m.group(4), m.group(5)
        if start:
            span = f'<span class="ev-lines">{start}–{end} 行</span>'
        else:
            start, end = m.group(7), m.group(8)
            span = ""
        range_attr = f' data-from="{start}" data-to="{end}"' if start else ""
        return (f'<button type="button" class="ev" data-ev="{ev}"{range_attr} '
                f'aria-expanded="false">{ev}</button>{span}')
    return EV_RE.sub(rep, fragment)


def split_md(body: str) -> tuple[str, list[dict]]:
    """按 H2 切分正文；返回 (导语, 章节列表)。H1 由网页单独渲染，这里丢弃。"""
    intro: list[str] = []
    sections: list[dict] = []
    cur = None
    for line in body.split("\n"):
        if re.match(r"^##\s+", line):
            cur = {"title": re.sub(r"^##\s+|\s+$", "", line), "lines": []}
            sections.append(cur)
        elif re.match(r"^#\s+", line):
            continue
        elif cur is None:
            intro.append(line)
        else:
            cur["lines"].append(line)
    return "\n".join(intro).strip(), sections


def split_theme_item(title: str, text: str) -> dict:
    blocks: list[dict] = []
    buf: list[str] = []
    layer: str | None = None

    def flush() -> None:
        nonlocal buf, layer
        if any(l.strip() for l in buf):
            blocks.append({"layer": layer or "mixed", "html": render_md("\n".join(buf).strip())})
        buf = []

    for line in text.split("\n"):
        bullet = BULLET_RE.match(line)
        head = None if bullet else THEME_HEAD_RE.match(line)
        match = bullet or head
        if match:
            flush()
            layer = THEME_LAYERS[match.group(1)]
            # 层名由网页标题栏呈现，正文里去掉重复的标签，只留下状态词与子条目
            rest = (head.group(2) if head else line[match.end():]).strip()
            buf = ["- " + rest] if rest else []
        else:
            buf.append(line)
    flush()
    return {"title": title, "blocks": blocks}


def build_doc(body: str) -> dict | None:
    """仅对含「主题档案」的页面生成结构化 doc，供网页做分层渐进披露。"""
    intro, sections = split_md(body)
    if not any(s["title"] == "主题档案" for s in sections):
        return None
    out = []
    for i, sec in enumerate(sections):
        title = sec["title"]
        text = "\n".join(sec["lines"]).strip()
        if title == "主题档案":
            items = []
            cur_title, cur_lines = None, []
            for line in sec["lines"]:
                if re.match(r"^###\s+", line):
                    if cur_title is not None:
                        items.append(split_theme_item(cur_title, "\n".join(cur_lines)))
                    cur_title = re.sub(r"^###\s+|\s+$", "", line)
                    cur_lines = []
                elif cur_title is not None:
                    cur_lines.append(line)
            if cur_title is not None:
                items.append(split_theme_item(cur_title, "\n".join(cur_lines)))
            out.append({"title": title, "id": f"sec-{i}", "kind": "themes", "layer": "mixed", "items": items})
        else:
            key = section_key(title)
            out.append({"title": title, "id": f"sec-{i}", "kind": SECTION_KIND.get(key, "other"),
                        "layer": SECTION_LAYER.get(key, "meta"), "html": render_md(text)})
    return {"intro": render_md(intro) if intro else "", "sections": out}


def load_json_tolerant(path: Path) -> tuple[object | None, str | None]:
    """宽容读取游戏仓库 JSON：若存在未解决的 git 合并冲突，只采用冲突标记之前的完好片段。"""
    text = path.read_text(encoding="utf-8-sig")
    try:
        return json.loads(text), None
    except json.JSONDecodeError:
        marker = re.search(r"^(?:<{7}|={7}|>{7})", text, re.M)
        if not marker:
            return None, f"{path.name}: JSON 解析失败，已跳过该数据源"
        prefix = re.sub(r",\s*$", "", text[:marker.start()].rstrip())
        head = prefix.lstrip()
        prefix += "\n]" if head.startswith("[") else "\n}"
        try:
            return json.loads(prefix), f"{path.name}: 存在未解决的合并冲突，仅采用冲突标记之前的完好片段（其后条目未纳入）"
        except json.JSONDecodeError as exc:
            return None, f"{path.name}: 存在未解决的合并冲突且截断片段不可解析，已跳过（{exc}）"


def build_game_index() -> tuple[dict, dict]:
    """构建期读取游戏仓库数据，生成只读投影。游戏仓库是唯一真相源，此处不写入任何数据。"""
    warnings: list[str] = []
    loaded = {}
    for name in ("gu.json", "gu_names.json", "gu_lore.json", "refinement_recipes.json", "shops.json", "loot_tables.json"):
        data, warn = load_json_tolerant(GAME / name)
        if warn:
            warnings.append(warn)
        loaded[name] = data

    lore_by_id = {}
    for g in (loaded["gu_lore.json"] or {}).get("gu", []):
        if isinstance(g, dict) and g.get("id"):
            lore_by_id[g["id"]] = {"name": g.get("name"), "gameRank": g.get("game_rank"),
                                   "loreRank": g.get("lore_rank"), "status": g.get("status"),
                                   "anchor": g.get("anchor"), "note": g.get("note")}
    # 显示名分级回退：gu_lore 人工对照 > gu_names 全量 id→名映射 > 原始 id。
    # gu_names.json 覆盖全部蛊虫 id（含只出现在炼蛊链里、尚无 Wiki 页的），此前未读取，
    # 会让炼蛊链节点把内部 id 直接当名称显示在阅读界面上。
    names = {gid: v["name"] for gid, v in lore_by_id.items() if v.get("name")}
    for gid, label in (loaded["gu_names.json"] or {}).items():
        if isinstance(label, str) and label and gid not in names:
            names[gid] = label

    index: dict[str, dict] = {}

    def slot(gid: str) -> dict:
        return index.setdefault(gid, {"id": gid, "stats": None, "lore": None,
                                      "recipes": [], "shops": [], "lootTiers": []})

    for g in (loaded["gu.json"] or []):
        if isinstance(g, dict) and g.get("id"):
            slot(g["id"])["stats"] = {k: g[k] for k in GU_STAT_KEYS if k in g}
    for gid, lore in lore_by_id.items():
        slot(gid)["lore"] = lore

    for r in list((loaded["refinement_recipes.json"] or {}).get("recipes", [])) + \
            list((loaded["refinement_recipes.json"] or {}).get("caravan_offers", [])):
        if not isinstance(r, dict):
            continue
        def link(gid: str) -> dict:
            return {"id": gid, "name": names.get(gid, gid), "route": "/gu/" + gid.replace("_", "-")}
        record = {
            "id": r.get("id"), "kind": r.get("kind"),
            "inputs": [link(i) for i in (r.get("input_gu_ids") or [])],
            "output": link(r["output_gu_id"]) if r.get("output_gu_id") else None,
            "outputRank": r.get("output_rank"), "materials": r.get("materials") or {},
            "stoneCost": r.get("stone_cost", 0), "branchLabel": r.get("branch_label"),
            "retired": bool(r.get("retired")), "retireReason": r.get("retire_reason"),
        }
        for gid in {i["id"] for i in record["inputs"]} | ({record["output"]["id"]} if record["output"] else set()):
            slot(gid)["recipes"].append(record)

    for o in (loaded["shops.json"] or {}).get("offers", []):
        if isinstance(o, dict) and o.get("gu_id"):
            slot(o["gu_id"])["shops"].append({"id": o.get("id"), "kind": o.get("kind"),
                                              "stoneCost": o.get("stone_cost"), "tier": o.get("tier")})

    for tier, table in ((loaded["loot_tables.json"] or {}).get("loot") or {}).items():
        if not isinstance(table, dict):
            continue
        for rarity, ids in ((table.get("gu_pool") or {}).get("by_rarity") or {}).items():
            for gid in ids:
                slot(gid)["lootTiers"].append({"tier": tier, "rarity": rarity,
                                               "chancePct": table.get("gu_chance_pct")})

    for gid, entry in index.items():
        entry["name"] = names.get(gid) or gid
    meta = {"sources": ["game/data/" + n for n in loaded], "warnings": warnings}
    return index, meta


def split_frontmatter(raw: str) -> tuple[dict, str]:
    match = re.match(r"\A---\s*\n(.*?)\n---\s*\n", raw, flags=re.S)
    if not match:
        return {}, raw
    return yaml.safe_load(match.group(1)) or {}, raw[match.end():]


def text_section(body: str, heading: str) -> str:
    match = re.search(rf"^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)", body, re.M | re.S)
    return match.group(1).strip() if match else ""


def route_for(source: Path) -> str:
    if source == WIKI / "index.md":
        return "/wiki-home"
    rel = source.relative_to(WIKI).with_suffix("")
    return "/" + rel.as_posix()


def link_gu(index: dict, gid: str, known: set[str]) -> dict:
    route = "/gu/" + gid.replace("_", "-")
    return {"id": gid, "name": (index.get(gid) or {}).get("name") or gid,
            "route": route, "linked": route in known}


def render_page(source: Path, known: set[str], game_index: dict) -> dict:
    raw = source.read_text(encoding="utf-8-sig")
    meta, body = split_frontmatter(raw)
    route = route_for(source)
    category = source.relative_to(WIKI).parts[0] if source != WIKI / "index.md" else "home"
    title = str(meta.get("name") or re.search(r"^#\s+(.+)$", body, re.M).group(1) if re.search(r"^#\s+(.+)$", body, re.M) else source.stem)
    soup = BeautifulSoup(md.render(body), "html.parser")
    for link in soup.find_all("a", href=True):
        href = link["href"]
        if href.startswith(("http:", "https:", "mailto:", "#")):
            continue
        target = (source.parent / href.split("#", 1)[0]).resolve()
        if target.is_relative_to(WIKI.resolve()) and target.suffix.lower() == ".md":
            target_route = route_for(target)
            if target_route in known:
                link["href"] = "#" + target_route
            else:
                link["href"] = "#" + target_route
                link["class"] = link.get("class", []) + ["unavailable-link"]
                link["title"] = "此目标未收录在知识页面中"
        else:
            link["href"] = "#" + route
            link["class"] = link.get("class", []) + ["unavailable-link"]
            link["title"] = "本网站未包含该本地资料"
    for node in soup.find_all("h2"):
        label = node.get_text(strip=True)
        key = section_key(label)
        # 层归属由构建期统一标注：网页只读该属性做渐进披露，不复制一份结构映射
        if key in SECTION_LAYER:
            node["data-layer"] = SECTION_LAYER[key]
            node["data-kind"] = SECTION_KIND.get(key, "other")
        if key in ("原著明确内容", "资料整理", "分析与解读", "待核对"):
            node["data-section"] = key
    gap = text_section(body, "待核对")
    gap_items = len(re.findall(r"^\s*[-*]\s+", gap, re.M))
    evidence_ids = sorted(set(re.findall(r"E:V\d-\d{6}", body)))
    raw_refs = len(re.findall(r"蛊真人-clean\.txt(?::\d+|[^\n]{0,30}\d+\s*行)", body))
    notes = bool(re.search(r"notes:|memory:", raw))
    inferred = len(re.findall(r"\[(?:[^\]]*\|)?推断\]|待推断|推测", body))
    unresolved = len(re.findall(r"\[(?:[^\]]*\|)?未决\]|待核对|未检得明文|原文未言", body))
    evidence = "有原文锚点" if evidence_ids or raw_refs else ("仅见二级资料" if notes else "未识别原文锚点")
    plain = BeautifulSoup(str(soup), "html.parser").get_text(" ", strip=True)
    page = {
        "route": route, "category": category, "title": title,
        "kind": page_kind(category, route, title, meta.get("kind")),
        "description": str(meta.get("description") or ""),
        "date": str(meta.get("date") or ""),
        "schema": meta.get("schema"), "sources": meta.get("sources") or [],
        "html": state_chips(ev_buttons(str(soup))), "text": plain,
        "audit": {"gapItems": gap_items, "hasGapSection": bool(gap), "inferred": inferred,
                  "unresolved": unresolved, "evidenceIds": len(evidence_ids), "rawRefs": raw_refs,
                  "evidence": evidence},
    }
    doc = build_doc(body)
    if doc:
        page["doc"] = doc
    if category == "gu":
        entry = game_index.get(route.rsplit("/", 1)[-1].replace("-", "_"))
        if entry:
            projection = {k: v for k, v in entry.items() if k != "id"}
            projection["recipes"] = [
                {**rec, "inputs": [{**i, **link_gu(game_index, i["id"], known)} for i in rec["inputs"]],
                 "output": {**rec["output"], **link_gu(game_index, rec["output"]["id"], known)} if rec["output"] else None}
                for rec in entry["recipes"]
            ]
            page["game"] = projection
    return page


def resolve_aliases(known: set[str]) -> dict[str, str]:
    """只放行「旧 slug 已不存在、目标路由确实存在」的兼容入口，其余如实报错、不静默吞掉。"""
    out: dict[str, str] = {}
    for old, new in ROUTE_ALIASES.items():
        if old in known:
            print(f"ALIAS WARN: {old} 已是现有路由，它不是兼容入口，已忽略")
        elif new not in known:
            print(f"ALIAS WARN: {old} 的目标 {new} 不在本次构建中，已忽略该兼容入口")
        else:
            out[old] = new
    return out


def sync_web_assets() -> int:
    """把 web/ 下的前端源文件同步进 dist/：正确性修复只写在源文件里，dist 一律由构建产出。"""
    DIST.mkdir(parents=True, exist_ok=True)
    assets = [p for p in sorted(WEB.glob("*")) if p.is_file()]
    for asset in assets:
        shutil.copyfile(asset, DIST / asset.name)
    return len(assets)


def main() -> None:
    paths = [WIKI / "index.md"]
    for folder in CATEGORIES:
        paths.extend(sorted((WIKI / folder).glob("*.md")))
    known = {route_for(p) for p in paths}
    route_aliases = resolve_aliases(known)
    game_index, game_meta = build_game_index()
    for warn in game_meta["warnings"]:
        print(f"GAME WARN: {warn}")
    pages = [render_page(p, known, game_index) for p in paths]
    art = []
    out_art = DIST / "art"
    out_art.mkdir(parents=True, exist_ok=True)
    sources = [p for p in sorted(ART.rglob("*")) if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")]
    old_names = Counter((p.relative_to(ART).with_suffix(".webp")).as_posix() for p in sources)
    wanted = set()
    for source in sources:
        rel = source.relative_to(ART)
        target = out_art / (rel.as_posix() + ".webp")
        wanted.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            old_target = out_art / rel.with_suffix(".webp")
            if old_names[rel.with_suffix(".webp").as_posix()] == 1 and old_target.exists():
                shutil.copyfile(old_target, target)
            else:
                with Image.open(source) as original:
                    image = ImageOps.exif_transpose(original)
                    image.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
                    if image.mode not in ("RGB", "RGBA"):
                        image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
                    image.save(target, "WEBP", quality=78, method=6)
        group = rel.parts[0]
        with Image.open(target) as built:
            width, height = built.size
        art.append({"path": "art/" + rel.as_posix() + ".webp",
                    "name": source.stem.replace("_", " ").replace("-", " "),
                    "original": rel.as_posix(), "group": group,
                    "groupName": ART_GROUPS.get(group, group),
                    "w": width, "h": height})
    for old_file in out_art.rglob("*"):
        if old_file.is_file() and old_file not in wanted:
            old_file.unlink()
    (DIST / "data.json").write_text(json.dumps({"pages": pages, "art": art, "categories": CATEGORIES, "kinds": KINDS, "kindGroups": {"knowledge": KIND_GROUP_KNOWLEDGE, "meta": KIND_GROUP_META}, "gameMeta": game_meta, "routeAliases": route_aliases}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    synced = sync_web_assets()
    print(f"Built {len(pages)} Wiki pages and {len(art)} optimized images")
    print(f"Synced {synced} frontend assets from web/ · route aliases {len(route_aliases)}")
    print(f"Data size: {(DIST / 'data.json').stat().st_size / 1024 / 1024:.2f} MB")
    print(f"Art size: {sum(p.stat().st_size for p in out_art.rglob('*') if p.is_file()) / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
