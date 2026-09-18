#!/usr/bin/env python3
"""Draw the Ember eclipse mark at every Mac icon size."""

from pathlib import Path
from PIL import Image, ImageDraw

VOID = (11, 11, 11, 255)
EMBER = (204, 100, 55, 255)
ROOT = Path(__file__).resolve().parents[1]
SET = ROOT / "Ember/Assets.xcassets/AppIcon.appiconset"
SITE = ROOT / "site"


def draw_icon(size: int, *, r_frac: float = 0.36, offset_frac: float = 0.36) -> Image.Image:
    scale = 8 if size <= 64 else 4
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), VOID)
    cx = cy = canvas / 2.0
    r = canvas * r_frac
    off = r * offset_frac

    mask = Image.new("L", (canvas, canvas), 0)
    m = ImageDraw.Draw(mask)
    m.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    m.ellipse([cx - r - off, cy - r, cx + r - off, cy + r], fill=0)
    img.paste(Image.new("RGBA", (canvas, canvas), EMBER), mask=mask)

    overlay = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    stroke = max(scale, int(round(canvas * (0.022 if size <= 64 else 0.0075))))
    pad = stroke / 2.0
    d.ellipse(
        [cx - r - pad, cy - r - pad, cx + r + pad, cy + r + pad],
        outline=EMBER,
        width=stroke,
    )
    img = Image.alpha_composite(img, overlay)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    SET.mkdir(parents=True, exist_ok=True)
    sizes = {
        "icon_16.png": 16,
        "icon_16@2x.png": 32,
        "icon_32.png": 32,
        "icon_32@2x.png": 64,
        "icon_128.png": 128,
        "icon_128@2x.png": 256,
        "icon_256.png": 256,
        "icon_256@2x.png": 512,
        "icon_512.png": 512,
        "icon_512@2x.png": 1024,
        "icon_1024.png": 1024,
    }
    master = None
    for name, size in sizes.items():
        im = draw_icon(size)
        im.save(SET / name, "PNG")
        if size == 1024:
            master = im
    assert master is not None
    (SITE / "assets").mkdir(parents=True, exist_ok=True)
    master.resize((512, 512), Image.Resampling.LANCZOS).save(SITE / "assets/icon.png", "PNG")
    master.save(SITE / "apple-touch-icon.png", "PNG")
    draw_icon(32).save(SITE / "favicon.png", "PNG")
    print("icons written")


if __name__ == "__main__":
    main()
