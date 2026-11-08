#!/usr/bin/env python3
"""Generates the 96-color master palette (design bible section 12.2).

12 ramps of 8 shades: 8 saturated ramps and 4 muted ones (pass 506). Shadows hue-shift toward blue-violet and highlights toward
warm yellow; no pure black or white. Writes art/palette/master.gpl (GIMP/Aseprite)
art/palette/master.png (one 8x8 swatch per color, ramps in rows) and
art/palette/master.json, the colors as hex in PixelLab's target_palette shape
({"name", "colors"}), to pass with every PixelLab call that takes one, and art/palette/master.hex
(Lospec's format, one color per line, no #) for editors and web tools that import palettes.
Usage: python3 tools/art/palette.py
"""
import colorsys
import json
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "art" / "palette"

# (name, base hue in degrees, saturation)
RAMPS = [
    ("night", 255, 0.30),   # outlines, deep shadows, the Evercrown
    ("stone", 250, 0.14),   # masonry, Hearthroot, Vorrhallow
    ("bark", 28, 0.45),     # wood, leather, Heartwood
    ("leaf", 105, 0.45),    # foliage, the hero's tunic
    ("sky", 205, 0.45),     # sky, water, High Boughs
    ("ember", 8, 0.62),     # scarf, thorns, fire, blood
    ("gold", 45, 0.70),     # sap, lanterns, gold, UI
    ("crystal", 300, 0.45), # stillglass, magic
    # Muted ramps (Sean, 2026-11-07, pass 506): without them, dull browns snapped to
    # bark and ember (leather turned red), grey stone to the cool stone ramp (lavender),
    # and moss and dry grass broke into speckles. New ramps go at the end so the
    # names and order of the first eight never change.
    ("umber", 32, 0.20),    # leather, rope, old wood
    ("ash", 60, 0.07),      # weathered stone, dust, ash
    ("moss", 80, 0.12),     # lichen, roof moss, dull foliage
    ("ochre", 46, 0.34),    # dry grass, autumn brush, straw
]

# The muted ramps are for materials. Sky and haze gradients keep to the eight
# saturated ramps, so the night stays deep blue-violet (12.2) instead of picking
# the muted near-blacks, which sit closer to a neutral black.
MUTED = ("umber", "ash", "moss", "ochre")


def shade(hue, sat, i, n=8):
    k = i / (n - 1)                       # 0 = darkest, 1 = lightest
    light = 0.08 + 0.84 * k
    # Hue shift: darks toward 250 (blue-violet), lights toward 50 (warm).
    target = 250 if k < 0.5 else 50
    amount = abs(k - 0.5) * 0.5
    dh = ((target - hue + 180) % 360) - 180
    h = (hue + dh * amount) % 360
    s = sat * (0.75 + 0.5 * (1 - abs(k - 0.55) * 1.6))
    r, g, b = colorsys.hls_to_rgb(h / 360, light, max(0.0, min(1.0, s)))
    return tuple(int(round(c * 255)) for c in (r, g, b))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    colors = []
    for name, hue, sat in RAMPS:
        for i in range(8):
            colors.append((f"{name}-{i}", shade(hue, sat, i)))
    lines = ["GIMP Palette", "Name: Yldenfall Master", "Columns: 8", "#"]
    for name, (r, g, b) in colors:
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (OUT / "master.gpl").write_text("\n".join(lines) + "\n")
    img = Image.new("RGB", (64, 8 * len(RAMPS)))
    for idx, (_, rgb) in enumerate(colors):
        x, y = idx % 8, idx // 8
        for dy in range(8):
            for dx in range(8):
                img.putpixel((x * 8 + dx, y * 8 + dy), rgb)
    img.save(OUT / "master.png")
    target = {"name": "Yldenfall Master", "colors": ["#%02x%02x%02x" % rgb for _, rgb in colors]}
    (OUT / "master.json").write_text(json.dumps(target, indent=1) + "\n")
    (OUT / "master.hex").write_bytes(("\n".join(c[1:] for c in target["colors"]) + "\n").encode())


if __name__ == "__main__":
    main()
