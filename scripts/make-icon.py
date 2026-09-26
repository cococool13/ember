#!/usr/bin/env python3
"""Draw the Ember icon at every Mac icon size, plus the site favicon set.

The mark is a phase disc: daylight on the lit limb cooling into ember at the
tips, a dark side held by a faint rim, tilted like the sun going down. It sits
on a void squircle with a warm haze, a top-edge highlight, and the macOS drop
shadow.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SET = ROOT / "Ember/Assets.xcassets/AppIcon.appiconset"
SITE = ROOT / "site"

VOID = np.array([11, 11, 11], float)
TOP = np.array([34, 35, 35], float)
EMBER = np.array([204, 100, 55], float)
DEEP = np.array([122, 42, 18], float)
DAYLIGHT = np.array([255, 226, 188], float)
DARK_SIDE = np.array([22, 22, 22], float)

TILT = np.radians(-28)  # lit side faces lower right
PHASE = 0.42  # terminator: 0 is half lit, 1 is new


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t[..., None]


def render(size: int, *, bleed: bool) -> Image.Image:
    """`bleed` fills the canvas (favicons, touch icons); otherwise the macOS
    grid: an 824/1024 squircle with room for its shadow."""
    ss = 4 if size < 256 else 2
    n = size * ss
    y, x = np.mgrid[0:n, 0:n].astype(float)
    u = (x + 0.5) / n - 0.5
    v = (y + 0.5) / n - 0.5
    aa = 1.5 / n  # one output pixel of antialiasing, in canvas units

    half = 0.5 if bleed else 412 / 1024
    # Superellipse n=5: the continuous-corner shape of a Mac icon.
    sq = (np.abs(u / half) ** 5 + np.abs(v / half) ** 5) ** (1 / 5)
    tile = 1 - smooth(1 - aa / half, 1 + aa / half, sq)
    if bleed:
        tile[:] = 1

    # Background: charcoal at the top into void, with a warm haze near the lit side.
    ty = np.clip((v + half) / (2 * half), 0, 1)
    rgb = mix(np.broadcast_to(TOP, (n, n, 3)), np.broadcast_to(VOID, (n, n, 3)), smooth(0, 1, ty))
    ca, sa = np.cos(TILT), np.sin(TILT)
    r = 0.66 * half  # same mark-to-tile ratio at every size and bleed
    cx, cy = 0.0, 0.0
    hx, hy = cx + ca * r * 0.9, cy - sa * r * 0.9
    haze = np.exp(-(((u - hx) ** 2 + (v - hy) ** 2) / (2 * 0.26**2)))
    rgb = mix(rgb, np.broadcast_to(EMBER, (n, n, 3)), haze * 0.16)

    # Disc coordinates: xr toward the lit limb, yr along the terminator.
    dx, dy = u - cx, v - cy
    xr = dx * ca - dy * sa
    yr = dx * sa + dy * ca
    dist = np.hypot(dx, dy)
    disc = 1 - smooth(r - aa, r + aa, dist)

    # Elliptical terminator, as on a real sphere, feathered like real light.
    chord = np.sqrt(np.clip(r * r - yr * yr, 0, None))
    term = PHASE * chord
    feather = max(0.012, aa)
    lit = disc * smooth(term - feather, term + feather, xr)

    # Dark side: a shade above the void so the whole disc reads.
    rgb = mix(rgb, np.broadcast_to(DARK_SIDE, (n, n, 3)), disc * 0.9)

    # Bloom under the crescent.
    lit_img = Image.fromarray((lit * 255).astype(np.uint8))
    glow = np.asarray(lit_img.filter(ImageFilter.GaussianBlur(n * 0.045)), float) / 255
    rgb = mix(rgb, np.broadcast_to(EMBER, (n, n, 3)), np.clip(glow * 0.55, 0, 1) * (1 - disc * 0.85))

    # Crescent colour: ember, deepening toward the tips, with a soft daylight
    # hot spot on the middle of the limb.
    along = np.clip(1 - np.abs(yr) / r, 0, 1)
    body = mix(np.broadcast_to(DEEP, (n, n, 3)), np.broadcast_to(EMBER, (n, n, 3)), smooth(0.0, 0.55, along))
    hot = np.exp(-(((xr - r * 0.92) ** 2) / (2 * (r * 0.26) ** 2) + (yr**2) / (2 * (r * 0.36) ** 2)))
    body = mix(body, np.broadcast_to(DAYLIGHT, (n, n, 3)), np.clip(hot * 1.05, 0, 1) ** 1.3)
    rgb = mix(rgb, body, lit)

    # Rim on the dark side: a hairline of ember so the full circle is there.
    rim_w = max(1.2 / (size * 1.0), 0.004)
    rim = (1 - smooth(rim_w * 0.5, rim_w * 0.5 + aa, np.abs(dist - r + rim_w * 0.5))) * (1 - lit)
    rgb = mix(rgb, np.broadcast_to(EMBER, (n, n, 3)), rim * 0.45)

    # Top-edge highlight inside the squircle.
    if not bleed:
        inner = smooth(1 - (aa * 2.5) / half, 1 - aa / half, sq) * tile
        rgb = mix(rgb, np.broadcast_to(np.array([255.0, 255, 255]), (n, n, 3)), inner * smooth(0.35, 0, ty) * 0.22)

    alpha = tile
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")

    if not bleed:
        # macOS drop shadow: soft, a little below the tile.
        shadow_a = Image.fromarray((tile * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(n * 0.012))
        shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        shadow.putalpha(shadow_a.point(lambda p: int(p * 0.42)))
        base = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        base.alpha_composite(shadow, (0, int(n * 0.012)))
        base.alpha_composite(img)
        img = base

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
    cache: dict[int, Image.Image] = {}
    for name, size in sizes.items():
        if size not in cache:
            cache[size] = render(size, bleed=False)
        cache[size].save(SET / name, "PNG")

    (SITE / "assets").mkdir(parents=True, exist_ok=True)
    cache[512].save(SITE / "assets/icon.png", "PNG")
    # iOS masks its own corners, so the touch icon fills the square.
    render(180, bleed=True).convert("RGB").save(SITE / "apple-touch-icon.png", "PNG")
    cache[32].save(SITE / "favicon.png", "PNG")
    print("icons written")


if __name__ == "__main__":
    main()
