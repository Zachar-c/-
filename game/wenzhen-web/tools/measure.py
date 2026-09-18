"""肉眼级验证：截图的亮度分布。
纯黑 = 没渲染；有内容但均值极低 = 太暗。这两件事必须分得开。

用法：python tools/measure.py tools/shots/*.png
"""
import sys
from pathlib import Path
from PIL import Image, ImageStat


def report(p: Path) -> None:
    im = Image.open(p).convert("RGB")
    w, h = im.size
    small = im.resize((w // 4, h // 4))
    st = ImageStat.Stat(small)
    ext = small.getextrema()
    data = small.tobytes()
    n = len(data) // 3
    dark = sum(1 for i in range(0, len(data), 3) if max(data[i], data[i + 1], data[i + 2]) < 12)
    warm = sum(1 for i in range(0, len(data), 3)
               if data[i] > 120 and data[i] - data[i + 2] > 30)
    print(f"{p.name:24s} {w}x{h}  mean={[round(v, 1) for v in st.mean]}  "
          f"max={[e[1] for e in ext]}  near_black={dark * 100 / n:.1f}%  warm_px={warm * 100 / n:.2f}%")


for arg in sys.argv[1:]:
    path = Path(arg)
    if path.exists():
        report(path)
    else:
        print(f"{path.name:24s} MISSING")
