"""ComfyUI nodes for the Wenzhen asset pipeline.

These nodes intentionally keep GPT Image and ComfyUI separate:
GPT Image produces the frozen source image; ComfyUI owns normalization.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image


WEB_ROOT = Path(__file__).resolve().parents[3]
TOOLS = WEB_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from asset_manager import finalize_assets  # noqa: E402
from build_moonlight_poc import (  # noqa: E402
    make_activation_glow,
    make_card_portrait,
    make_collection_cover,
    make_cutout,
    make_icon,
    make_moon_blade,
    make_silhouette,
    sha256,
)


def _asset_root(value: str) -> Path:
    root = Path(value).expanduser().resolve()
    for relative in ("source", "canonical", "ui", "effect", "metadata"):
        (root / relative).mkdir(parents=True, exist_ok=True)
    return root


class WenzhenFrozenSource:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "source_path": ("STRING", {"default": "", "multiline": False}),
                "asset_root": ("STRING", {"default": str(WEB_ROOT / "assets" / "gu" / "moonlight_gu")}),
            }
        }

    RETURN_TYPES = ("WENZHEN_SOURCE",)
    FUNCTION = "load"
    CATEGORY = "Wenzhen/Asset Pipeline"

    def load(self, source_path: str, asset_root: str):
        source = Path(source_path).expanduser().resolve()
        if not source.exists():
            raise FileNotFoundError(f"Missing frozen source: {source}")
        root = _asset_root(asset_root)
        copied = root / "source" / "moonlight_gu_concept.png"
        if source != copied.resolve():
            shutil.copy2(source, copied)
        return ({"path": str(copied), "sha256": sha256(copied)},)


class WenzhenCanonicalCutout:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "source": ("WENZHEN_SOURCE",),
                "asset_root": ("STRING", {"default": str(WEB_ROOT / "assets" / "gu" / "moonlight_gu")}),
            }
        }

    RETURN_TYPES = ("WENZHEN_BODY",)
    FUNCTION = "cutout"
    CATEGORY = "Wenzhen/Asset Pipeline"

    def cutout(self, source, asset_root: str):
        root = _asset_root(asset_root)
        with Image.open(source["path"]) as image:
            body = make_cutout(image.convert("RGB"))
        body_path = root / "canonical" / "body.png"
        body_x2_path = root / "canonical" / "body@2x.png"
        body.save(body_path)
        body.save(body_x2_path)
        body.resize(
            (round(body.width * 0.62), round(body.height * 0.62)),
            Image.Resampling.LANCZOS,
        ).save(root / "canonical" / "body-small.png")
        return ({"path": str(body_path), "size": [body.width, body.height]},)


class WenzhenDeriveAssetSet:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "body": ("WENZHEN_BODY",),
                "asset_root": ("STRING", {"default": str(WEB_ROOT / "assets" / "gu" / "moonlight_gu")}),
            }
        }

    RETURN_TYPES = ("WENZHEN_ASSET_SET",)
    FUNCTION = "derive"
    CATEGORY = "Wenzhen/Asset Pipeline"

    def derive(self, body, asset_root: str):
        root = _asset_root(asset_root)
        with Image.open(body["path"]) as image:
            cutout = image.convert("RGBA")

        assets = {
            "body": root / "canonical" / "body.png",
            "body_2x": root / "canonical" / "body@2x.png",
            "silhouette": root / "canonical" / "silhouette.png",
            "icon_64": root / "ui" / "icon_64.png",
            "icon_128": root / "ui" / "icon_128.png",
            "card_portrait": root / "ui" / "card_portrait.png",
            "collection_cover": root / "ui" / "collection_cover.png",
            "moon_blade_preview": root / "effect" / "moon_blade_preview.png",
            "activation_glow": root / "effect" / "activation_glow.png",
        }
        make_silhouette(cutout).save(assets["silhouette"])
        make_icon(cutout, 64).save(assets["icon_64"])
        make_icon(cutout, 128).save(assets["icon_128"])
        make_card_portrait(cutout).save(assets["card_portrait"])
        make_collection_cover(cutout).save(assets["collection_cover"])
        make_moon_blade(cutout).save(assets["moon_blade_preview"])
        make_activation_glow(cutout).save(assets["activation_glow"])
        return ({key: str(path) for key, path in assets.items()},)


class WenzhenAssetManager:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "source": ("WENZHEN_SOURCE",),
                "assets": ("WENZHEN_ASSET_SET",),
                "asset_root": ("STRING", {"default": str(WEB_ROOT / "assets" / "gu" / "moonlight_gu")}),
            }
        }

    RETURN_TYPES = ("STRING", "STRING")
    RETURN_NAMES = ("manifest_path", "status")
    FUNCTION = "finalize"
    CATEGORY = "Wenzhen/Asset Pipeline"
    OUTPUT_NODE = True

    def finalize(self, source, assets, asset_root: str):
        root = _asset_root(asset_root)
        manifest = finalize_assets(root, Path(source["path"]))
        return (str(root / "manifest.json"), f"validated {len(manifest['assets'])} assets")


NODE_CLASS_MAPPINGS = {
    "WenzhenFrozenSource": WenzhenFrozenSource,
    "WenzhenCanonicalCutout": WenzhenCanonicalCutout,
    "WenzhenDeriveAssetSet": WenzhenDeriveAssetSet,
    "WenzhenAssetManager": WenzhenAssetManager,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "WenzhenFrozenSource": "Wenzhen Frozen Source",
    "WenzhenCanonicalCutout": "Wenzhen Canonical Cutout",
    "WenzhenDeriveAssetSet": "Wenzhen Derive Asset Set",
    "WenzhenAssetManager": "Wenzhen Asset Manager",
}
