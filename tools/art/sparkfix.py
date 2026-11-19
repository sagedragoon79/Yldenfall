#!/usr/bin/env python3
"""Takes the clock face out of the hit spark sheets (design bible 6.7, pass 609).

PixelLab's VFX tool drew the blade's hit spark (pass 529) as a hot star that opens
into a ring, and the ring came with tick marks inside it and crosshair spikes at
twelve and nine o'clock: a clock face, or a lock-on reticle. The pass 605 grade
read the spark as "a clock-face lock-on marker" rather than a blade striking.

This script rebuilds assets/vfx/blade_spark.png and heavy_spark.png from the
tool's own export, kept in art/vfx-raw/, so it can run again:
  - frame 0, the hot star, is kept as it is;
  - on every later frame the ring, its ticks and its spikes are erased, all but
    the spray of hot sparks thrown forward along the swing (+x, falling);
  - the star stays lit on frame 1 and burns down to its core on frame 2, so the
    flash fades rather than opening into a circle.
The JSON beside each sheet (frames, pivots, timing) is unchanged.

Usage: python3 tools/art/sparkfix.py
"""
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art" / "vfx-raw"
OUT = ROOT / "assets" / "vfx"
SHEETS = ("blade_spark", "heavy_spark")

# The spray leaves the contact forward and falls: angles (degrees, y down) kept
# outside the ring. Everything else near the ring is the clock face.
CONE = (-40.0, 45.0)
# How far past the ring its spikes and studs reach, in sheet pixels.
SPIKES = 20
# The ring is this thick past its radius (its outline included); inside it, in
# the cone too, are only the clock's ticks.
BAND = 5
# How much of the star burns on: frame 1 keeps it whole, frame 2 its core.
STAR_KEEP = {1: (99, 1.0), 2: (6, 1.0)}


def frames(meta):
    for f in meta["frames"]:
        r = f["frame"]
        piv = (round(f["pivot"]["x"] * r["w"]), round(f["pivot"]["y"] * r["h"]))
        yield (r["x"], r["y"], r["w"], r["h"]), piv


def ring_radius(img, box, piv):
    """The ring's radius: the distance from the pivot that holds the most lit pixels."""
    x0, y0, w, h = box
    counts = {}
    for y in range(h):
        for x in range(w):
            if img.getpixel((x0 + x, y0 + y))[3] == 0:
                continue
            d = round(math.hypot(x - piv[0], y - piv[1]))
            if 8 <= d <= 60:
                counts[d] = counts.get(d, 0) + 1
    if not counts:
        return 0
    best = max(counts, key=counts.get)
    # A ring is a full circle: at least half its circumference lit.
    return best if counts[best] >= math.pi * best else 0


def in_cone(dx, dy):
    a = math.degrees(math.atan2(dy, dx))
    return CONE[0] <= a <= CONE[1]


def fix(name):
    meta = json.loads((OUT / f"{name}.json").read_text())
    src = Image.open(RAW / f"{name}.png").convert("RGBA")
    img = src.copy()
    boxes = list(frames(meta))
    star_box, star_piv = boxes[0]
    rings = []
    for i, (box, piv) in enumerate(boxes):
        if i == 0:
            continue
        r = ring_radius(src, box, piv)
        rings.append(r)
        x0, y0, w, h = box
        for y in range(h):
            for x in range(w):
                dx, dy = x - piv[0], y - piv[1]
                d = math.hypot(dx, dy)
                if r == 0 or d > r + SPIKES:
                    continue
                spray = in_cone(dx, dy) and d > r + BAND
                if not spray:
                    img.putpixel((x0 + x, y0 + y), (0, 0, 0, 0))
        if i in STAR_KEEP:
            reach, alpha = STAR_KEEP[i]
            sx0, sy0, sw, sh = star_box
            for y in range(sh):
                for x in range(sw):
                    dx, dy = x - star_piv[0], y - star_piv[1]
                    p = src.getpixel((sx0 + x, sy0 + y))
                    if p[3] == 0 or math.hypot(dx, dy) > reach:
                        continue
                    tx, ty = piv[0] + dx, piv[1] + dy
                    if 0 <= tx < w and 0 <= ty < h:
                        img.putpixel((x0 + tx, y0 + ty), (p[0], p[1], p[2], round(p[3] * alpha)))
    img.save(OUT / f"{name}.png")
    print(f"{name}: rings erased at radius {rings}")


def main():
    for name in SHEETS:
        fix(name)


if __name__ == "__main__":
    main()
