#!/usr/bin/env python3
"""Deterministic gu catalog expander (Task C1).

Reads the curated harvest, appends new gu/name entries until every
school reaches QUOTA_PER_SCHOOL total gu, keeping legacy entries untouched.
Re-running on an already-expanded catalog is a no-op.

Usage (from repo root):  python tools/generate_gu_catalog.py [--harvest PATH]
Outputs: updated data/gu.json, data/gu_names.json and a counts report on stdout.
(B2 2026-09-06: the card-blueprint layer exited; gu entries no longer carry
card references and no card file is written.)
"""
import argparse
import collections
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
DEFAULT_HARVEST = os.path.join(ROOT, "..", ".superpowers", "sdd", "gu-name-harvest.txt")

SCHOOLS = ["blood", "qi", "force", "soul", "refine"]
QUOTA_PER_SCHOOL = 40
RARITY_TARGETS = {"common": 24, "rare": 12, "epic": 4}
LEGACY_GU_COUNT = 20

BUCKET_PATTERNS = {
    "blood": re.compile(r"血"),
    "qi": re.compile(r"[气风]"),
    "force": re.compile(r"[力熊石岩铁骨筋拳钧牛鹰鳄]"),
    "soul": re.compile(r"[魂魄幽梦怨影诗]"),
    "refine": re.compile(r"[炼炉火淬材合墨蛹引]"),
}

NOISE_PREFIX = re.compile(
    r"^(转|的|购|算|么|到|过|些|为|少|易|杀|命|搭配|催动|加大|成为|改良|上古|用|出|次|只|有|以|加|下|中|一)"
)
GENERIC_SUFFIX = re.compile(r"(仙蛊|道蛊|道仙蛊)$")
ROLE_CYCLE = ["attack", "attack", "defense", "movement", "healing", "recon", "logistics"]

ROLE_TAGS = {
    "attack": ["attack", "projectile", "poison", "power"],
    "defense": ["defense", "guard", "earth"],
    "movement": ["movement", "escape", "mist"],
    "healing": ["healing", "drain", "wood"],
    "recon": ["scout", "reveal", "tracking"],
    "logistics": ["tempo", "subtle", "sound"],
}
ROLE_ACTIONS = {
    "attack": ["attack"],
    "defense": ["guard"],
    "movement": ["escape", "signal"],
    "healing": ["heal"],
    "recon": ["scout", "disguise"],
    "logistics": ["feed", "store"],
}
ROLE_EFFECTS = {
    "attack": ["strike_enemy"],
    "defense": ["guard_self"],
    "movement": ["preserve_retreat"],
    "healing": ["relief_injury"],
    "recon": ["reveal_hidden"],
    "logistics": ["slow_enemy"],
}
COMBAT_TEMPLATES = {
    "attack": [{"kind": "strike", "amount": 2}],
    "defense": [{"kind": "add_flag", "flag": "guarded"}],
    "movement": [{"kind": "add_flag", "flag": "retreat_preserved"}],
    "healing": [{"kind": "heal_injury", "amount": 1}],
    "recon": [{"kind": "add_flag", "flag": "revealed"}, {"kind": "delay_progress", "amount": 1}],
    "logistics": [{"kind": "delay_progress", "amount": 1}],
}
RARITY_SCALE = {
    "common": {"rank": 1, "value": 3, "essence_cost": 1},
    "rare": {"rank": 2, "value": 5, "essence_cost": 1},
    "epic": {"rank": 3, "value": 8, "essence_cost": 2},
}
MATERIALS = ["beast_blood", "beast_bone", "venom_sac", "moon_dew"]


def load_json(path):
    with io.open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def dump_json(path, payload):
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")


def curate(harvest_path):
    names = collections.OrderedDict()
    bucket = None
    with io.open(harvest_path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if line.startswith("== "):
                bucket = line[3:-3]
                continue
            if "\t" not in line or bucket not in BUCKET_PATTERNS:
                continue
            name, freq = line.rsplit("\t", 1)
            freq = int(freq)
            cleaned = NOISE_PREFIX.sub("", name).strip()
            if GENERIC_SUFFIX.search(cleaned) or len(cleaned) < 2 or not cleaned.endswith("蛊"):
                continue
            key = cleaned
            score = freq
            if key not in names or names[key][0] < score:
                names[key] = (score, bucket)
    curated = collections.defaultdict(list)
    for name, (score, bucket) in sorted(names.items(), key=lambda kv: (-kv[1][0], kv[0])):
        curated[bucket].append((name, score))
    return curated


def slugify(index, school, role):
    return "gen_%s_%s_%03d_gu" % (school, role, index)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--harvest", default=DEFAULT_HARVEST)
    args = parser.parse_args()

    harvest_path = os.path.normpath(os.path.join(ROOT, args.harvest))
    gu_entries = load_json(os.path.join(DATA, "gu.json"))

    existing_by_school = collections.Counter(g["school"] for g in gu_entries)
    existing_rarity = collections.Counter(
        (g["school"], g["rarity"]) for g in gu_entries
    )
    taken_names = set()
    names_path = os.path.join(DATA, "gu_names.json")
    if os.path.exists(names_path):
        taken_names.update(load_json(names_path).values())

    curated = curate(harvest_path)
    consumed = set()

    def take_from(pool):
        for zh_name, freq in pool:
            if zh_name not in taken_names and zh_name not in consumed:
                consumed.add(zh_name)
                return zh_name
        return None

    SCHOOL_CHARS = {
        "blood": ["血", "赤", "殷"],
        "qi": ["气", "风", "岚"],
        "force": ["力", "岩", "熊"],
        "soul": ["魂", "幽", "魄"],
        "refine": ["炼", "炉", "淬"],
    }

    def synth_variant(school, index):
        chars = SCHOOL_CHARS[school]
        base_char = chars[index % len(chars)]
        tail_chars = ["纹", "鳞", "芽", "须", "珠", "壳", "须", "蔓", "棘", "茧"]
        return "%s%s蛊" % (base_char, tail_chars[(index // len(chars)) % len(tail_chars)])

    new_gu, new_names = [], {}
    seq = 0
    for school in SCHOOLS:
        while existing_by_school[school] < QUOTA_PER_SCHOOL:
            zh_name = take_from(curated.get(school, []))
            if zh_name is None:
                others = []
                for other_school in SCHOOLS:
                    if other_school == school:
                        continue
                    others.extend(curated.get(other_school, []))
                    others.extend(curated.get("unsorted", []))
                zh_name = take_from(others)
            if zh_name is None:
                zh_name = synth_variant(school, seq)
                while zh_name in taken_names or zh_name in consumed:
                    seq += 1
                    zh_name = synth_variant(school, seq)
                consumed.add(zh_name)
            rarity = None
            for tier in ("common", "rare", "epic"):
                if existing_rarity[(school, tier)] < RARITY_TARGETS[tier]:
                    rarity = tier
                    break
            if rarity is None:
                rarity = "common"
            role = ROLE_CYCLE[seq % len(ROLE_CYCLE)]
            seq += 1
            scale = RARITY_SCALE[rarity]
            gu_id = slugify(seq, school, role)
            template = [dict(e) for e in COMBAT_TEMPLATES[role]]
            if rarity == "epic":
                for effect in template:
                    if effect["kind"] == "strike":
                        effect["amount"] += 1
            material = MATERIALS[seq % len(MATERIALS)]
            gu_entry = {
                "id": gu_id,
                "rank": scale["rank"],
                "feeding_cost": 1,
                "feeding_need": {material: 1},
                "value": scale["value"],
                "essence_cost": scale["essence_cost"],
                "slot_role": role,
                "combat": "%s_%s_pattern" % (school, role),
                "field_actions": ROLE_ACTIONS[role],
                "synergy_hooks": ROLE_EFFECTS[role],
                "replace_value": max(1, scale["value"] - 1),
                "tags": [school] + ROLE_TAGS[role][:2],
                "school": school,
                "role": role,
                "rarity": rarity,
                "combat_effects": template,
                "source": "game_new",
            }
            gu_entries.append(gu_entry)
            new_names[gu_id] = zh_name
            taken_names.add(zh_name)
            existing_by_school[school] += 1
            existing_rarity[(school, rarity)] += 1
            new_gu.append(gu_id)

    dump_json(os.path.join(DATA, "gu.json"), gu_entries)
    names_path = os.path.join(DATA, "gu_names.json")
    merged = load_json(names_path) if os.path.exists(names_path) else {}
    merged.update(new_names)
    dump_json(names_path, merged)

    per_school = collections.Counter(g["school"] for g in gu_entries)
    per_rarity = collections.Counter(g["rarity"] for g in gu_entries)
    report_lines = [
        "new gu: %d" % len(new_gu),
        "total gu: %d (target %d)" % (len(gu_entries), LEGACY_GU_COUNT + 180),
        "per-school: %s" % dict(per_school),
        "per-rarity: %s" % dict(per_rarity),
    ]
    print("\n".join(report_lines))
    if len(gu_entries) != LEGACY_GU_COUNT + 180:
        sys.exit(1)


if __name__ == "__main__":
    main()
