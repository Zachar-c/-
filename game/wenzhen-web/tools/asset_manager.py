"""Validate and index normalized Wenzhen game assets.

The asset manager is deliberately small. It does not generate art and it does
not know about ComfyUI internals. It only accepts a rendered asset set, checks
that required files exist, and writes the manifest consumed by prototypes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from pathlib import Path

from PIL import Image


REQUIRED_ASSETS = {
    "body": "canonical/body.png",
    "body_2x": "canonical/body@2x.png",
    "silhouette": "canonical/silhouette.png",
    "icon_64": "ui/icon_64.png",
    "icon_128": "ui/icon_128.png",
    "card_portrait": "ui/card_portrait.png",
    "collection_cover": "ui/collection_cover.png",
    "moon_blade_preview": "effect/moon_blade_preview.png",
    "activation_glow": "effect/activation_glow.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_image(path: Path) -> dict[str, int | str]:
    with Image.open(path) as image:
        return {
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "sha256": sha256(path),
        }


def finalize_assets(asset_root: Path, source_path: Path) -> dict:
    asset_root = asset_root.resolve()
    source_path = source_path.resolve()
    if not source_path.exists():
        raise FileNotFoundError(f"Missing frozen source: {source_path}")

    assets: dict[str, dict] = {}
    missing: list[str] = []
    for key, relative in REQUIRED_ASSETS.items():
        path = asset_root / relative
        if not path.exists():
            missing.append(relative)
            continue
        assets[key] = {
            "path": relative,
            **inspect_image(path),
        }

    if missing:
        raise FileNotFoundError("Missing normalized assets: " + ", ".join(missing))

    source_record = {
        "path": "source/moonlight_gu_concept.png",
        "sha256": sha256(source_path),
        "frozen_reference": "docs/art/references/moonlight/canonical_form.png",
    }
    manifest = {
        "id": "moonlight_gu",
        "name": "月光蛊",
        "layer": "canonical",
        "rank": 1,
        "school": "moon",
        "asset_status": "visual_poc",
        "not_production_asset": True,
        "pipeline": "gpt-image -> comfyui -> asset-manager",
        "provider": "gpt-image",
        "orchestrator": "comfyui",
        "source": source_record,
        "assets": assets,
        "generated_on": date.today().isoformat(),
    }

    metadata_dir = asset_root / "metadata"
    metadata_dir.mkdir(parents=True, exist_ok=True)
    (asset_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (metadata_dir / "moonlight_gu.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (metadata_dir / "moonlight_gu.csv").write_text(
        "id,name,rank,type,asset_path,pipeline\n"
        "moonlight_gu,月光蛊,1,attack,gu/moonlight_gu,gpt-image->comfyui->asset-manager\n",
        encoding="utf-8",
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets" / "gu" / "moonlight_gu",
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).resolve().parents[3]
        / "docs"
        / "art"
        / "references"
        / "moonlight"
        / "canonical_form.png",
    )
    args = parser.parse_args()
    manifest = finalize_assets(args.asset_root, args.source)
    print(json.dumps({"asset_root": str(args.asset_root), "assets": len(manifest["assets"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
