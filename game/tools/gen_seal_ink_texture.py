# -*- coding: utf-8 -*-
"""Generate Wenzhen-style seal-ink texture (cinnabar grunge overlay).

Source: texturize.app grunge-heavy-grunge (royalty-free, no attribution).
Luminance is inverted into the alpha channel; RGB is fixed to the project
SEAL_CINNABAR (#8c5850) so dark cracks render as ink, light areas transparent.
"""
from PIL import Image

SEAL = (140, 88, 80)
SRC = "assets/wenzhen/textures/_grunge_src.png"
OUT = "assets/wenzhen/textures/seal_ink_texture.png"

img = Image.open(SRC).convert("L")
alpha = img.point(lambda v: 255 - v)
r = Image.new("L", img.size, SEAL[0])
g = Image.new("L", img.size, SEAL[1])
b = Image.new("L", img.size, SEAL[2])
out = Image.merge("RGBA", (r, g, b, alpha))
out.save(OUT)
print("saved", OUT, out.size)
