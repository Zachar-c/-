"""生成资产的后处理。

约定：模型吐出来的原图一律叫 `<名字>_raw.png`，处理完的成品叫 `<名字>.png`。
本脚本只处理 `*_raw.png`，所以可以反复运行——已经处理过的成品不会被二次加工。

它做两件事：
  1. 裁掉右下角的模型水印
  2. 如果主体是黑底发光体，把亮度当 alpha 转成透明贴图

用法：
    python tools/prep_assets.py            # 全部
    python tools/prep_assets.py visit      # 只处理某几个（按资产名）
"""
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

# 水印固定在右下角，统一从底部裁掉这么多像素
WATERMARK_CROP_PX = 90

# 需要做「黑底 -> 透明」的资产。其余只裁水印。
CUTOUT = {"cicada"}

# 这些名字的成品**不**由本脚本产出，别覆盖。
# stone.png 是 cut_stone.py 从一张「三颗石头合影」里抠出来的，
# 本脚本只会把那两张合影原图裁条水印，写出来不是一颗石头，会把成品砸掉。
SKIP = {"stone"}


def strip_watermark(img):
    w, h = img.size
    return img.crop((0, 0, w, h - WATERMARK_CROP_PX))


def luminance_to_alpha(img, black=18, white=190):
    """黑底发光体 -> 透明贴图。亮度当作不透明度，黑底自动消失。"""
    rgb = img.convert("RGB")
    gray = ImageOps.grayscale(rgb)
    span = max(white - black, 1)
    alpha = gray.point(lambda v: min(255, max(0, int((v - black) * 255 / span))))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def main():
    only = set(sys.argv[1:])
    log = []
    raws = sorted(ASSETS.glob("*_raw.png"))
    if not raws:
        log.append("没有 *_raw.png，无事可做")

    for raw in raws:
        name = raw.name[: -len("_raw.png")]
        if only and name not in only:
            continue
        if name in SKIP:
            log.append(f"{name}.png 跳过（由 cut_stone.py 负责）")
            continue
        img = strip_watermark(Image.open(raw))
        if name in CUTOUT:
            img = luminance_to_alpha(img)
        out = ASSETS / f"{name}.png"
        img.save(out)
        log.append(f"{out.name} <- {raw.name}  {img.size} {img.mode}")

    (ROOT / "tools" / "prep_assets.log").write_text("\n".join(log), encoding="utf-8")


if __name__ == "__main__":
    main()
