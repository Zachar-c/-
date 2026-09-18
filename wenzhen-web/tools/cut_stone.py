"""把「一颗元石」的生成图抠成透明贴图。

原料：assets/stone_raw.png —— 黑底上一颗石头，右下角有水印。
产出：assets/stone.png   —— 1024 见方，带 alpha，只留石头自己的光和透明。

只切一颗：屏幕上一颗元石只有 60~80px，
三颗用同一张贴图配合镜像/旋转就已经看不出是同一个了。
从「三颗石头合影」里抠三颗反而抠不干净——矩形框不开前后遮挡的两颗。

用法：
    python tools/cut_stone.py
"""
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
WATERMARK_CROP_PX = 80

# 石头在原图（1024×1024）里的区域
REGION = (150, 200, 870, 830)


def main():
    src = ASSETS / "stone_raw.png"
    if not src.exists():
        raise SystemExit(f"找不到 {src}")

    img = Image.open(src)
    w, h = img.size
    img = img.crop((0, 0, w, h - WATERMARK_CROP_PX))
    img = img.crop(REGION)

    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=2, percent=90, threshold=3))
    gray = ImageOps.grayscale(rgb)
    black, white = 30, 190
    span = max(white - black, 1)
    alpha = gray.point(lambda v: min(255, max(0, int((v - black) * 255 / span))))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)

    # 按亮部收紧，甩掉周围那圈若隐若现的灰雾
    box = out.getchannel("A").point(lambda v: 255 if v > 70 else 0).getbbox()
    if box:
        l, t, r, b = box
        pad = 4
        out = out.crop((max(0, l - pad), max(0, t - pad),
                        min(out.width, r + pad), min(out.height, b + pad)))

    # 补成正方形，方便 CSS 里等比缩放
    s = max(out.size)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(out, ((s - out.width) // 2, (s - out.height) // 2))
    sq = sq.resize((512, 512), Image.LANCZOS)
    sq.save(ASSETS / "stone.png")

    hist = sq.getchannel("A").histogram()
    cover = sum(hist[40:]) * 100 // (512 * 512)
    (ROOT / "tools" / "cut_stone.log").write_text(
        f"stone.png {sq.size} alpha_cover={cover}%", encoding="utf-8")


if __name__ == "__main__":
    main()
