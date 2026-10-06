#!/usr/bin/env python3
"""Retina Finder backdrop. Icons are real draggable files, not painted artwork."""
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2
image = Image.new("RGB", (640 * SCALE, 400 * SCALE), "#f2f2f0")
draw = ImageDraw.Draw(image)


def font(name, size):
    return ImageFont.truetype(str(ROOT / "Ember/Fonts" / name), size * SCALE)


def text(value, y, face, color):
    draw.text((320 * SCALE, y * SCALE), value, font=face, fill=color, anchor="mt")


text("DRAG EMBER TO APPLICATIONS", 36, font("BarlowCondensed-Regular.ttf", 30), "#161817")
text("Then open Ember from Applications.", 82, font("RobotoMono-Regular.ttf", 12), "#545752")
# Clear space around both real Finder icons; the arrow explains the drag.
draw.line([(282 * SCALE, 205 * SCALE), (358 * SCALE, 205 * SCALE)], fill="#cc6437", width=2 * SCALE)
draw.line([(348 * SCALE, 195 * SCALE), (358 * SCALE, 205 * SCALE), (348 * SCALE, 215 * SCALE)], fill="#cc6437", width=2 * SCALE)
text("Look for the crescent in your menu bar.", 333, font("RobotoMono-Regular.ttf", 12), "#545752")
path = ROOT / "build/dmg-background.png"
path.parent.mkdir(parents=True, exist_ok=True)
image.save(path)
image.resize((640, 400), Image.Resampling.LANCZOS).save(ROOT / "build/dmg-background-1x.png")
# Finder does not infer Retina scale from a PNG. Supply 1x/2x TIFF reps.
output = ROOT / "build/dmg-background.tiff"
subprocess.run(["tiffutil", "-cathidpicheck", str(ROOT / "build/dmg-background-1x.png"), str(path), "-out", str(output)], check=True)
print(output)
