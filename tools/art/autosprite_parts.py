#!/usr/bin/env python3
"""Turns an Autosprite still into the frames of a rigged part (design bible 13.2).

A boss part like Gnarlmaw's bark plate or tail needs a second look for a state rather
than an animation: the plate cracked while he is staggered, the tail glowing when it is
open to hits. One pro still per part is cheaper than a clip, and the state frames are
drawn over it here. The output is an ordinary source sheet for autosprite_import.py.

Usage: python3 tools/art/autosprite_parts.py SRC DEST --box X0,Y0,X1,Y1 [--cut Y]
                                             --states plain,crack|glow [--size 512]
       SRC and DEST are under art/autosprite/. --box crops the part (square), --cut clears
       everything below source row Y (a tail tip under the round segment). States:
       plain   the still as drawn
       crack   pale fissures across it (cracked plates)
       glow    lifted toward a hot yellow (the weak point pulsing)
       --dress makes a second look of the same still, so a chain of one part is not one
       stamp (design bible 8.1, pass 562). It costs no credits:
       spines  the part shrunk in its cell with three bark thorns raked back along its top
       moss    clumps of moss over its top and back, inside its outline
       sting   the part shrunk, with a blunt horn curving back from its rear (a tail tip)
       spines and sting print the "height", "lower" and "feet_x" the manifest needs so the
       round part keeps the size and the middle it has in the plain sheet.
"""
import argparse
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

from autosprite_spin import SOURCES, ROOT, key_background

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelrig import PAL  # noqa: E402


def crack(img, seed=7):
    """Jagged pale fissures with a dark rim, on the opaque part only."""
    w, h = img.size
    rng = random.Random(seed)
    lines = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    for _ in range(3):
        x, y = rng.uniform(0.25, 0.75) * w, rng.uniform(0.1, 0.25) * h
        pts = [(x, y)]
        for _ in range(9):
            x += rng.uniform(-0.12, 0.12) * w
            y += rng.uniform(0.04, 0.08) * h
            pts.append((x, y))
        d.line(pts, (40, 18, 14, 255), max(4, w // 40), joint="curve")
        d.line(pts, (246, 222, 170, 255), max(2, w // 90), joint="curve")
    out = img.copy()
    out.alpha_composite(Image.composite(lines, Image.new("RGBA", img.size, (0, 0, 0, 0)), img.split()[3]))
    return out


def glow(img):
    lit = ImageEnhance.Brightness(img).enhance(1.35)
    tint = Image.new("RGBA", img.size, (255, 236, 150, 0))
    tint.putalpha(img.split()[3].point(lambda a: a * 0.25))
    lit.alpha_composite(tint)
    return lit


def _tones(img, rows=(0.0, 0.6)):
    """Dark, mid and light colours of the part itself (its upper rows: the bark, not the belly)."""
    w, h = img.size
    px = [p for p in img.crop((0, int(h * rows[0]), w, int(h * rows[1]))).get_flattened_data() if p[3] > 200]
    px.sort(key=lambda p: p[0] * 0.3 + p[1] * 0.59 + p[2] * 0.11)
    return [px[int(len(px) * q)][:3] + (255,) for q in (0.12, 0.5, 0.88)]


def _shrunk(part, f, align_x):
    """The part at `f` of its size on the cell's bottom edge; returns it and where its box went."""
    size = part.width
    small = part.resize((int(size * f), int(size * f)), Image.LANCZOS)
    ox = int((size - small.width) * align_x)
    oy = size - small.height
    out = Image.new("RGBA", part.size, (0, 0, 0, 0))
    out.paste(small, (ox, oy))
    x0, y0, x1, y1 = part.getbbox()
    return out, (ox + x0 * f, oy + y0 * f, ox + x1 * f, oy + y1 * f)


def _thorn(d, base, tip, width, tones):
    """A raked thorn: dark along its back edge, a light line under its front edge."""
    dark, mid, light = tones
    ax, ay = tip[0] - base[0], tip[1] - base[1]
    n = math.hypot(ax, ay)
    tx, ty = -ay / n * width / 2, ax / n * width / 2
    back, front = (base[0] - tx, base[1] - ty), (base[0] + tx, base[1] + ty)
    d.polygon([back, tip, front], mid)
    d.polygon([back, tip, (base[0] - tx * 0.3, base[1] - ty * 0.3)], dark)
    d.polygon([(base[0] + tx * 0.45, base[1] + ty * 0.45), (base[0] + ax * 0.72, base[1] + ay * 0.72),
               (base[0] + tx * 0.75, base[1] + ty * 0.75)], light)


def _report(name, part, out, box, world_height):
    """The manifest numbers that keep the round part where and as big as the plain sheet has it."""
    x0, y0, x1, y1 = out.getbbox()
    lower = (y0 + y1) / 2.0 - (box[1] + box[3]) / 2.0
    line = '  %s: "lower": %.1f, "feet_x": %.1f' % (name, lower, (box[0] + box[2]) / 2.0)
    if world_height:
        line += ', "height": %.1f' % (world_height * (y1 - y0) / (box[3] - box[1]))
    print(line)


def spines(part, world_height=None):
    out, box = _shrunk(part, 0.84, 0.5)
    cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
    r = (box[3] - box[1]) / 2.0
    under = Image.new("RGBA", part.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(under)
    # Degrees from straight up (negative: toward the rear, the part travels toward +x), length, width.
    for ang, length, width in ((-46, 0.26, 0.34), (-14, 0.32, 0.38), (20, 0.24, 0.32)):
        a, lean = math.radians(ang), math.radians(ang - 9)
        base = (cx + math.sin(a) * r * 0.86, cy - math.cos(a) * r * 0.86)
        tip = (cx + math.sin(lean) * r * (1.0 + length), cy - math.cos(lean) * r * (1.0 + length))
        _thorn(d, base, tip, r * width, _tones(part))
    under.alpha_composite(out)
    _report("spines", part, under, box, world_height)
    return under


def moss(part, seed=11):
    """Moss over the top and back, clipped to the part: its outline does not change."""
    w, h = part.size
    x0, y0, x1, y1 = part.getbbox()
    cx, cy, r = (x0 + x1) / 2.0, (y0 + y1) / 2.0, (y1 - y0) / 2.0
    rng = random.Random(seed)
    layer = Image.new("RGBA", part.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    tones = [tuple(PAL[k][:3]) + (255,) for k in ("moss-1", "moss-2", "moss-3", "moss-4")]
    # Patches of small tufts, matte: thick on the crest, thinning down the back.
    tufts = []
    for _ in range(7):
        a = math.radians(rng.uniform(-80, 12))
        k = rng.uniform(0.66, 0.98)
        px, py = cx + math.sin(a) * r * k, cy - math.cos(a) * r * k
        for _ in range(rng.randint(14, 26)):
            q = r * rng.uniform(0.028, 0.05)
            tufts.append((px + rng.gauss(0, r * 0.09), py + rng.gauss(0, r * 0.06), q, rng.random()))
    for x, y, q, _ in tufts:
        d.ellipse((x - q, y - q * 0.2, x + q, y + q * 1.9), tones[0])
    for x, y, q, v in tufts:
        d.ellipse((x - q, y - q, x + q, y + q), tones[1] if v < 0.3 else (tones[2] if v < 0.85 else tones[3]))
    for x, y, q, v in tufts:
        if v > 0.93:
            # A strand hanging off the patch.
            d.line([(x, y + q), (x + q * 0.3, y + q * rng.uniform(3.0, 5.0))], tones[1], max(4, w // 90))
    out = part.copy()
    out.alpha_composite(Image.composite(layer, Image.new("RGBA", part.size, (0, 0, 0, 0)), part.split()[3]))
    return out


def sting(part):
    out, box = _shrunk(part, 0.82, 1.0)
    cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
    r = (box[2] - box[0]) / 2.0
    under = Image.new("RGBA", part.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(under)
    # A blunt horn out of the rear, curving up and back, in the colours of the husk under the sac.
    tones = _tones(part, (0.62, 0.8))
    base = (cx - r * 0.8, cy + r * 0.2)
    mid = (cx - r * 1.16, cy + r * 0.1)
    tip = (cx - r * 1.4, cy - r * 0.22)
    _thorn(d, base, (mid[0] - r * 0.12, mid[1] - r * 0.04), r * 0.6, tones)
    _thorn(d, (mid[0] + r * 0.14, mid[1] + r * 0.06), tip, r * 0.36, tones)
    under.alpha_composite(out)
    _report("sting", part, under, box, None)
    return under


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dest")
    ap.add_argument("--box", required=True)
    ap.add_argument("--cut", type=int)
    ap.add_argument("--states", required=True)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--dress", choices=["spines", "moss", "sting"])
    ap.add_argument("--height", type=float, help="the plain part's manifest height, for --dress spines")
    a = ap.parse_args()
    img = key_background(Image.open(SOURCES / a.src))
    if a.cut is not None:
        img.paste(Image.new("RGBA", (img.width, img.height - a.cut), (0, 0, 0, 0)), (0, a.cut))
    part = img.crop(tuple(int(v) for v in a.box.split(","))).resize((a.size, a.size), Image.LANCZOS)
    if a.dress == "spines":
        part = spines(part, a.height)
    elif a.dress == "moss":
        part = moss(part)
    elif a.dress == "sting":
        part = sting(part)
    make = {"plain": lambda i: i, "crack": crack, "glow": glow}
    states = a.states.split(",")
    sheet = Image.new("RGBA", (a.size * len(states), a.size), (0, 0, 0, 0))
    for k, state in enumerate(states):
        sheet.paste(make[state](part), (k * a.size, 0))
    dest = SOURCES / a.dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(dest, optimize=True)
    print(f"{dest.relative_to(ROOT)}: {', '.join(states)}")


if __name__ == "__main__":
    main()
