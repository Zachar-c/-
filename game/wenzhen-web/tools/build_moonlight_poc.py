"""Build the first Moonlight Gu asset-pipeline POC.

Source of truth:
    docs/art/references/moonlight/canonical_form.png

The script never edits the frozen source. It copies it into the POC source
folder and derives normalized runtime assets from that copy.
"""
from __future__ import annotations

import csv
import hashlib
import json
from datetime import date
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps
from scipy import ndimage

from asset_manager import finalize_assets


WEB_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = WEB_ROOT.parents[1]
SOURCE = REPO_ROOT / "docs" / "art" / "references" / "moonlight" / "canonical_form.png"
OUT = WEB_ROOT / "assets" / "gu" / "moonlight_gu"


def ensure_dirs() -> None:
    for relative in (
        "source",
        "canonical",
        "ui",
        "effect",
        "metadata",
    ):
        (OUT / relative).mkdir(parents=True, exist_ok=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def make_cutout(source: Image.Image) -> Image.Image:
    """Remove the dark studio floor while preserving the luminous creature."""
    rgb = source.convert("RGB")
    gray = np.asarray(ImageOps.grayscale(rgb), dtype=np.float32)

    # The reference is lit against near-black stone. A high luminance gate
    # removes most of the floor; the closing pass keeps translucent shell
    # details connected to the main body.
    height, _ = gray.shape
    rows = np.arange(height, dtype=np.float32)[:, None]
    mask = gray > 130
    mask[980:, :] = False
    mask = ndimage.binary_closing(mask, structure=np.ones((5, 5)), iterations=2)
    labels, count = ndimage.label(mask)
    if count == 0:
        raise RuntimeError("Could not isolate the Moonlight Gu body")

    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    main = labels == (int(np.argmax(sizes)) + 1)
    main = ndimage.binary_fill_holes(main)
    main = ndimage.binary_dilation(main, iterations=2)

    # Keep a soft edge inside the silhouette instead of a hard jagged mask.
    floor_fade = np.clip((980 - rows) / 120, 0.12, 1.0)
    soft_alpha = np.clip(((gray - 20) * 255 / 170) * floor_fade, 0, 255).astype(np.uint8)
    alpha = Image.fromarray(np.where(main, soft_alpha, 0).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.15))

    cutout = rgb.convert("RGBA")
    cutout.putalpha(alpha)
    bbox = cutout.getbbox()
    if not bbox:
        raise RuntimeError("Moonlight Gu cutout produced an empty image")
    return cutout.crop(bbox)


def fit_on_canvas(
    image: Image.Image,
    size: tuple[int, int],
    fill: tuple[int, int, int, int] = (0, 0, 0, 0),
) -> Image.Image:
    canvas = Image.new("RGBA", size, fill)
    available_w = int(size[0] * 0.9)
    available_h = int(size[1] * 0.9)
    scale = min(available_w / image.width, available_h / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    x = (size[0] - resized.width) // 2
    y = (size[1] - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def make_silhouette(cutout: Image.Image) -> Image.Image:
    alpha = cutout.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > 26 else 0)
    silhouette = Image.new("RGBA", cutout.size, (239, 248, 255, 0))
    silhouette.putalpha(mask)
    return fit_on_canvas(silhouette, (512, 512))


def make_icon(cutout: Image.Image, size: int) -> Image.Image:
    return fit_on_canvas(cutout, (size, size))


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    mix = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    top_array = np.array(top, dtype=np.float32)[None, None, :]
    bottom_array = np.array(bottom, dtype=np.float32)[None, None, :]
    pixels = top_array * (1 - mix) + bottom_array * mix
    return Image.fromarray(np.repeat(pixels, width, axis=1).astype(np.uint8), "RGB").convert("RGBA")


def make_card_portrait(cutout: Image.Image) -> Image.Image:
    size = (768, 1024)
    canvas = vertical_gradient(size, (6, 14, 24), (2, 7, 13))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((80, 180, 688, 790), fill=(104, 174, 222, 46))
    draw.ellipse((148, 248, 620, 720), fill=(202, 234, 255, 24))
    glow = glow.filter(ImageFilter.GaussianBlur(42))
    canvas.alpha_composite(glow)

    scale = min(size[0] * 0.96 / cutout.width, size[1] * 0.74 / cutout.height)
    body = cutout.resize(
        (round(cutout.width * scale), round(cutout.height * scale)),
        Image.Resampling.LANCZOS,
    )
    x = (size[0] - body.width) // 2
    y = 118 + (int(size[1] * 0.74) - body.height) // 2
    canvas.alpha_composite(body, (x, y))

    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shade)
    draw.rectangle((0, 800, size[0], size[1]), fill=(1, 5, 10, 154))
    canvas.alpha_composite(shade)
    return canvas


def make_collection_cover(cutout: Image.Image) -> Image.Image:
    size = (640, 800)
    canvas = vertical_gradient(size, (4, 10, 18), (1, 5, 10))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((48, 92, 592, 636), fill=(103, 165, 213, 38))
    draw.ellipse((112, 154, 528, 570), fill=(226, 244, 255, 20))
    canvas = canvas.filter(ImageFilter.GaussianBlur(24))

    scale = min(size[0] * 0.94 / cutout.width, size[1] * 0.82 / cutout.height)
    body = cutout.resize(
        (round(cutout.width * scale), round(cutout.height * scale)),
        Image.Resampling.LANCZOS,
    )
    x = (size[0] - body.width) // 2
    y = (size[1] - body.height) // 2
    canvas.alpha_composite(body, (x, y))
    return canvas


def make_moon_blade(cutout: Image.Image) -> Image.Image:
    """Build a horizontal lunar blade from the source palette and silhouette."""
    size = (1024, 320)
    effect = Image.new("RGBA", size, (0, 0, 0, 0))
    body_pixels = np.asarray(cutout.convert("RGB"), dtype=np.float32)
    alpha = np.asarray(cutout.getchannel("A"), dtype=np.float32) / 255
    active = body_pixels[alpha > 0.45]
    color = active.mean(axis=0) if len(active) else np.array((170, 215, 245))
    color = np.clip(color * 0.72 + np.array((38, 66, 90)), 0, 255).astype(np.uint8)

    outer = Image.new("L", size, 0)
    draw = ImageDraw.Draw(outer)
    draw.polygon([(42, 206), (716, 63), (982, 150), (722, 242)], fill=255)
    inner = Image.new("L", size, 0)
    draw = ImageDraw.Draw(inner)
    draw.polygon([(122, 194), (704, 94), (930, 149), (720, 199)], fill=255)
    mask = ImageChops.subtract(outer, inner).filter(ImageFilter.GaussianBlur(1.2))

    halo = Image.new("RGBA", size, tuple(color.tolist()) + (0,))
    halo.putalpha(mask.filter(ImageFilter.GaussianBlur(19)).point(lambda value: int(value * 0.52)))
    effect.alpha_composite(halo)

    blade = Image.new("RGBA", size, tuple(color.tolist()) + (190,))
    blade.putalpha(mask)
    effect.alpha_composite(blade)

    highlight = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(highlight)
    draw.line([(78, 194), (670, 96), (914, 145)], fill=(245, 252, 255, 232), width=5, joint="curve")
    draw.line([(104, 206), (650, 112), (842, 151)], fill=(139, 204, 238, 150), width=2, joint="curve")
    effect.alpha_composite(highlight.filter(ImageFilter.GaussianBlur(1.1)))
    return effect


def make_activation_glow(cutout: Image.Image) -> Image.Image:
    size = (512, 512)
    body_pixels = np.asarray(cutout.convert("RGB"), dtype=np.float32)
    alpha = np.asarray(cutout.getchannel("A"), dtype=np.float32) / 255
    active = body_pixels[alpha > 0.35]
    color = active.mean(axis=0) if len(active) else np.array((170, 215, 245))
    color = np.clip(color * 0.68 + np.array((30, 52, 72)), 0, 255).astype(np.uint8)

    y, x = np.mgrid[0:size[1], 0:size[0]]
    cx, cy = size[0] / 2, size[1] / 2
    radius = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    glow = np.clip(1 - radius / (size[0] * 0.47), 0, 1) ** 2.2
    alpha_channel = (glow * 210).astype(np.uint8)
    rgb = np.zeros((size[1], size[0], 3), dtype=np.uint8)
    rgb[:, :] = color
    return Image.fromarray(np.dstack((rgb, alpha_channel)).astype(np.uint8), "RGBA")


def write_metadata(
    source_copy: Path,
    source_hash: str,
    body_size: tuple[int, int],
) -> None:
    payload = {
        "id": "moonlight_gu",
        "name": "月光蛊",
        "layer": "canonical",
        "rank": 1,
        "school": "moon",
        "asset_status": "visual_poc",
        "not_production_asset": True,
        "source": {
            "path": "assets/gu/moonlight_gu/source/moonlight_gu_concept.png",
            "sha256": source_hash,
            "frozen_reference": "docs/art/references/moonlight/canonical_form.png",
        },
        "assets": {
            "body": "canonical/body.png",
            "body_2x": "canonical/body@2x.png",
            "silhouette": "canonical/silhouette.png",
            "icon_64": "ui/icon_64.png",
            "icon_128": "ui/icon_128.png",
            "card_portrait": "ui/card_portrait.png",
            "collection_cover": "ui/collection_cover.png",
            "moon_blade_preview": "effect/moon_blade_preview.png",
            "activation_glow": "effect/activation_glow.png",
        },
        "body_size": {"width": body_size[0], "height": body_size[1]},
        "generated_on": date.today().isoformat(),
    }
    (OUT / "metadata" / "moonlight_gu.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    with (OUT / "metadata" / "moonlight_gu.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["id", "name", "rank", "type", "asset_path"])
        writer.writerow(["moonlight_gu", "月光蛊", "1", "attack", "gu/moonlight_gu"])


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing frozen source: {SOURCE}")

    ensure_dirs()
    source_copy = OUT / "source" / "moonlight_gu_concept.png"
    source_copy.write_bytes(SOURCE.read_bytes())
    source_hash = sha256(source_copy)

    source = Image.open(source_copy).convert("RGB")
    cutout = make_cutout(source)

    body_path = OUT / "canonical" / "body.png"
    cutout.save(body_path)
    cutout.save(OUT / "canonical" / "body@2x.png")

    body_small = cutout.resize(
        (round(cutout.width * 0.62), round(cutout.height * 0.62)),
        Image.Resampling.LANCZOS,
    )
    body_small.save(OUT / "canonical" / "body-small.png")

    make_silhouette(cutout).save(OUT / "canonical" / "silhouette.png")
    make_icon(cutout, 64).save(OUT / "ui" / "icon_64.png")
    make_icon(cutout, 128).save(OUT / "ui" / "icon_128.png")
    make_card_portrait(cutout).save(OUT / "ui" / "card_portrait.png")
    make_collection_cover(cutout).save(OUT / "ui" / "collection_cover.png")
    make_moon_blade(cutout).save(OUT / "effect" / "moon_blade_preview.png")
    make_activation_glow(cutout).save(OUT / "effect" / "activation_glow.png")

    write_metadata(source_copy, source_hash, cutout.size)
    finalize_assets(OUT, source_copy)
    print(f"built {OUT}")
    print(f"source sha256 {source_hash}")
    print(f"body {cutout.width}x{cutout.height}")


if __name__ == "__main__":
    main()
