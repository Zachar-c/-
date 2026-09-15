# -*- coding: utf-8 -*-
"""Idempotent update of assets/wenzhen/assets_manifest.json.

Appends registry entries (skipping existing ids) for:
- assets/wenzhen/textures/*.png  (E1 paper, E2 seal ink; texturize.app royalty-free)
- assets/wenzhen/icons/game-icons/*.svg  (52 icons, game-icons.net CC BY 3.0)
"""
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "wenzhen" / "assets_manifest.json"


def sha256(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest().upper()


def entry(id_: str, path: str, kind: str, source: str, license_: str, author: str) -> dict:
    return {
        "id": id_,
        "path": path,
        "kind": kind,
        "source": source,
        "license": license_,
        "author": author,
        "facing": "not_applicable",
        "sha256": sha256(ROOT / path),
    }


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    existing = {a["id"] for a in manifest["assets"]}
    added = []

    textures = ROOT / "assets" / "wenzhen" / "textures"
    for png in sorted(textures.glob("*.png")):
        id_ = "texture_" + png.stem
        if id_ in existing:
            continue
        added.append(entry(
            id_, "assets/wenzhen/textures/" + png.name, "texture_background",
            "https://texturize.app (royalty-free, no attribution; no standalone texture-pack redistribution)",
            "texturize_royalty_free",
            "texturize.app procedural generator",
        ))
        existing.add(id_)

    gi = ROOT / "assets" / "wenzhen" / "icons" / "game-icons"
    for svg in sorted(gi.glob("*.svg")):
        id_ = "game_icon_" + svg.stem
        if id_ in existing:
            continue
        added.append(entry(
            id_, "assets/wenzhen/icons/game-icons/" + svg.name, "icon_game",
            "https://game-icons.net/",
            "CC BY 3.0",
            "game-icons.net contributors (lorc, Delapouite, carl-olsen, etc.)",
        ))
        existing.add(id_)

    manifest["assets"].extend(added)
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("added", len(added), "total", len(manifest["assets"]))


if __name__ == "__main__":
    main()
