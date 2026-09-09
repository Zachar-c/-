# -*- coding: utf-8 -*-
"""Generate Wenzhen-style app icons (paper + cinnabar '问真' square seal).

Tokens from wenzhen-visual-style/references/tokens.md:
- PAPER_BG #ece9df, dots RGB(200,201,190) 5x7px cycle, 1px dot
- SEAL_CINNABAR #8c5850, square corners, 2px border, 2x2 vertical text,
  clockwise tilt +3deg
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

PAPER = (236, 233, 223)
DOT = (200, 201, 190)
SEAL = (140, 88, 80)

FONT = r"C:\Windows\Fonts\simkai.ttf"


def paper_canvas(size):
    """Paper background + halftone dot texture (5px x 7px cycle)."""
    img = Image.new("RGB", (size, size), PAPER)
    d = ImageDraw.Draw(img)
    # dot radius scales with canvas: 1px dot on 1405px ref -> approx size/1405
    r = max(1, round(size / 700))
    for y in range(0, size, 7):
        for x in range(0, size, 5):
            d.ellipse([x - r, y - r, x + r, y + r], fill=DOT)
    return img


def draw_seal(img, text="问真", size_ratio=0.52, font_ratio=0.20, tilt=3.0):
    """Cinnabar square seal, 2x2 vertical text, clockwise +tilt, centered."""
    size = img.size[0]
    d = ImageDraw.Draw(img)
    box = round(size * size_ratio)
    left = (size - box) // 2
    top = (size - box) // 2

    # rotate a separate seal layer clockwise (positive angle in PIL is CCW,
    # so rotate by -tilt to get clockwise in screen terms)
    seal = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(seal)
    sd.rectangle([left, top, left + box - 1, top + box - 1], outline=SEAL, width=max(2, round(size / 220)))
    fsize = round(box * font_ratio)
    try:
        font = ImageFont.truetype(FONT, fsize)
    except OSError:
        font = ImageFont.load_default()
    # 2x2 vertical layout: '问' top, '真' bottom
    for i, ch in enumerate(text):
        chbox = sd.textbbox((0, 0), ch, font=font)
        cw = chbox[2] - chbox[0]
        chh = chbox[3] - chbox[1]
        cx = left + (box - cw) // 2 - chbox[0]
        cy = top + round(box * (0.22 + 0.36 * i)) - chbox[1] - chh // 2
        sd.text((cx, cy), ch, font=font, fill=SEAL)
    rotated = seal.rotate(-tilt, center=(size / 2, size / 2), resample=Image.BICUBIC)
    img.paste(rotated, (0, 0), rotated)
    return img


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("saved", path, img.size[0])


OUT = "assets/icon"
os.makedirs(OUT, exist_ok=True)

# Master 1024 then downscale for Windows sizes
master = paper_canvas(1024)
draw_seal(master)
for s in (256, 128, 64, 48, 32, 16):
    save(master.resize((s, s), Image.LANCZOS), os.path.join(OUT, f"app_icon_{s}.png"))

# Android launcher icons
save(master.resize((192, 192), Image.LANCZOS), os.path.join(OUT, "android_main_192.png"))
# Adaptive: foreground 432 (seal inside safe zone), background solid paper
fg = paper_canvas(432)
draw_seal(fg, size_ratio=0.60, font_ratio=0.20)
save(fg, os.path.join(OUT, "adaptive_foreground_432.png"))
bg = Image.new("RGB", (432, 432), PAPER)
save(bg, os.path.join(OUT, "adaptive_background_432.png"))
print("done")
