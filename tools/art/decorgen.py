#!/usr/bin/env python3
"""Generates the small decor sprites that dress room surfaces (design bible 12.5:
the decor layer between the tiles and the foreground).

Each zone gets an atlas of cells, one cell per 16x32 world pixels, drawn at the
2x render density (design bible 12.1), so a cell is 32x64 atlas pixels. Four rows:
  row 0  floor pieces, standing on the bottom of the cell
  row 1  ceiling pieces, hanging from the top of the cell
  row 2  pieces on a wall to the left (attached at x = 0)
  row 3  the same, mirrored, for a wall to the right
and a JSON file: the cell size in world pixels, the density, how many variants
each row has, and the glow points (world pixels within the cell) of the pieces
that give off light (the Heartwood's cyan fungus, Hearthroot's sconces).

Pieces are painted in atlas pixels: strokes are one atlas pixel wide, half a
world pixel, which is where the extra detail comes from.

scripts/world/decor.gd scatters them over a room's open cells. Every color is
from the master palette. Usage: python3 tools/art/decorgen.py
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "decor"
## Atlas pixels per world pixel.
D = 2
CELL_W, CELL_H = 16, 32
W, H = CELL_W * D, CELL_H * D
COLS = 6

PAL = {}
for _name, _hue, _sat in palette.RAMPS:
    for _i in range(8):
        PAL[f"{_name}-{_i}"] = palette.shade(_hue, _sat, _i) + (255,)


class Cell:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.glow = []

    def px(self, x, y, color):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.img.putpixel((x, y), PAL[color])

    def rect(self, x, y, w, h, color):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, color)

    def line(self, pts, color):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for i in range(n + 1):
                t = i / n
                self.px(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, color)

    def disc(self, cx, cy, rx, ry, color):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, color)

    def opaque(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.img.getpixel((x, y))[3] > 0

    def outline(self, color):
        """A one pixel outline of `color` around everything drawn so far."""
        src = self.img.copy()
        for y in range(H):
            for x in range(W):
                if src.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and src.getpixel((nx, ny))[3]:
                        self.img.putpixel((x, y), PAL[color])
                        break

    def add_glow(self, x, y):
        """A light source at atlas pixel (x, y), stored in world pixels."""
        self.glow.append([round(x / D, 1), round(y / D, 1)])


def blade(c, x, h, lean, dark, light, tip):
    """A grass blade from the floor: two pixels wide at the root, one at the tip."""
    pts = [(x + lean * (k / h) ** 1.6, H - 1 - k) for k in range(h)]
    for k, (px, py) in enumerate(pts):
        c.px(px, py, light if k > h * 0.55 else dark)
        if k < h * 0.4:
            c.px(px + 1, py, dark)
    c.px(pts[-1][0], pts[-1][1], tip)


# --- Heartwood -------------------------------------------------------------

def heartwood_tuft(rng):
    c = Cell()
    for i in range(rng.randint(8, 12)):
        x = rng.randint(5, 25)
        h = rng.randint(5, 15)
        blade(c, x, h, rng.uniform(-4, 4), "leaf-1", "leaf-2" if i % 3 else "leaf-3", "leaf-4")
    # A few seed heads.
    for _ in range(rng.randint(0, 2)):
        x = rng.randint(8, 22)
        h = rng.randint(14, 19)
        c.line([(x, H - 1), (x + 1, H - h)], "leaf-2")
        c.rect(x, H - h - 3, 2, 3, "gold-3")
        c.px(x, H - h - 3, "gold-5")
    return c


def heartwood_fungus(rng, big):
    """Cyan glowing caps on thin stems: the zone's light sources."""
    c = Cell()
    caps = 3 if big else 2
    for i in range(caps):
        x = 8 + i * (8 if big else 12) + rng.randint(-2, 2)
        h = rng.randint(6, 16 if big else 10)
        r = 4 if i == 1 and big else 3
        top = H - 1 - h
        c.line([(x, H - 1), (x, top)], "stone-5")
        c.line([(x + 1, H - 1), (x + 1, top + 2)], "stone-3")
        # Domed cap: a dark rim, a bright body, a near-white glint.
        for dy in range(r):
            span = r + 1 - dy // 2 if dy else r + 2
            c.rect(x - span + 1, top - dy, span * 2, 1, "sky-4" if dy == 0 else "sky-5")
        c.rect(x - r, top + 1, 2 * r + 2, 1, "sky-2")
        c.px(x - r + 1, top - r + 1, "sky-6")
        c.px(x - r + 2, top - r + 1, "sky-7")
        c.px(x - r + 1, top - r + 2, "sky-6")
        for k in range(-r + 1, r + 1, 2):
            c.px(x + k, top + 1, "sky-3")
        c.add_glow(x + 0.5, top - 1)
    c.outline("sky-1")
    # Spores drifting off the caps (left outside the outline).
    for _ in range(rng.randint(1, 3)):
        c.px(rng.randint(4, W - 5), rng.randint(H - 34, H - 22), "sky-5")
    return c


def heartwood_mushroom(rng):
    c = Cell()
    x = rng.randint(12, 18)
    h = rng.randint(8, 12)
    top = H - 1 - h
    c.rect(x, top, 4, h + 1, "bark-6")
    c.rect(x + 3, top, 1, h + 1, "bark-5")
    c.rect(x - 1, H - 2, 6, 2, "bark-5")
    c.disc(x + 2, top - 1, 8, 4.5, "bark-3")
    c.disc(x + 1, top - 2, 6, 3.2, "bark-4")
    c.rect(x - 5, top + 1, 14, 2, "bark-2")
    for k in range(-5, 9, 2):
        c.px(x + k + 1, top + 2, "bark-5")
    # Pale spots on the cap.
    for dx, dy in ((-3, -3), (3, -4), (0, -5), (5, -2)):
        c.px(x + dx, top + dy, "gold-6")
    c.outline("bark-1")
    return c


def heartwood_twig(rng):
    c = Cell()
    y = H - 2
    x0 = rng.randint(2, 7)
    c.line([(x0, y), (x0 + 20, y - 1), (x0 + 24, y - 5)], "bark-3")
    c.line([(x0, y + 1), (x0 + 20, y)], "bark-1")
    c.line([(x0 + 8, y), (x0 + 12, y - 6), (x0 + 14, y - 7)], "bark-2")
    c.rect(x0 + 13, y - 9, 3, 2, "leaf-2")
    c.px(x0 + 15, y - 10, "leaf-3")
    for _ in range(5):
        c.rect(rng.randint(3, 26), H - 1, rng.randint(1, 3), 1, rng.choice(("stone-3", "stone-2", "bark-2")))
    return c


def heartwood_roots(rng, glow):
    c = Cell()
    strands = rng.randint(2, 3)
    for s in range(strands):
        x = 6 + s * 10 + rng.randint(-2, 2)
        length = rng.randint(20, 56)
        phase = rng.random() * math.tau
        pts = [(x + math.sin(phase + y * 0.17) * 2.4, y) for y in range(length)]
        for y, (px, _) in enumerate(pts):
            w = 3 if y < length * 0.3 else (2 if y < length * 0.75 else 1)
            c.rect(px, y, w, 1, "bark-2" if s % 2 == 0 else "bark-1")
            if w > 1:
                c.px(px, y, "bark-3")
        # Rootlets branching off.
        for _ in range(rng.randint(1, 2)):
            k = rng.randint(6, max(7, length - 8))
            bx, by = pts[k]
            d = rng.choice((-1, 1))
            c.line([(bx, by), (bx + 3 * d, by + 3), (bx + 4 * d, by + 7)], "bark-1")
        if glow and s == strands - 1:
            tx, ty = pts[-1]
            c.rect(tx - 1, ty + 1, 3, 3, "sky-5")
            c.px(tx, ty + 2, "sky-7")
            c.px(tx, ty + 4, "sky-4")
            c.add_glow(tx + 0.5, ty + 2)
    return c


def heartwood_moss(rng):
    c = Cell()
    for x in range(W):
        h = rng.randint(2, 8) if 4 < x < 28 else rng.randint(0, 2)
        for y in range(h):
            c.px(x, y, "leaf-1" if y < h - 2 else ("leaf-2" if y < h - 1 else "leaf-3"))
    # Drips of moss hanging lower.
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(6, 25)
        n = rng.randint(8, 14)
        c.line([(x, 0), (x, n)], "leaf-1")
        c.px(x, n + 1, "leaf-3")
    return c


def heartwood_shelf(rng, glow):
    """A bracket fungus growing out of a wall on the left."""
    c = Cell()
    y = rng.randint(24, 44)
    for i, w in enumerate((14, 13, 11, 8)):
        c.rect(0, y + i * 2, w, 2, "gold-3" if i == 0 else ("bark-4" if i == 1 else "bark-3"))
    c.rect(0, y - 2, 12, 2, "gold-4")
    c.rect(2, y - 3, 7, 1, "gold-5")
    # Growth rings along the edge.
    for i in range(4):
        c.px(13 - i * 2, y + 2 + i, "bark-2")
    c.rect(0, y + 8, 6, 2, "bark-2")
    if glow:
        c.rect(9, y + 7, 2, 2, "sky-5")
        c.px(9, y + 7, "sky-7")
        c.add_glow(10, y + 8)
    c.outline("bark-1")
    return c


# --- Hearthroot ---------------------------------------------------------------------

def hearthroot_weeds(rng):
    c = Cell()
    for i in range(rng.randint(6, 9)):
        x = rng.randint(4, 26)
        h = rng.randint(4, 11)
        blade(c, x, h, rng.uniform(-3, 3), "leaf-1", "leaf-2", "leaf-3")
    if rng.random() < 0.6:
        # A small yellow flower.
        x, y = rng.randint(8, 22), H - 11
        c.line([(x, H - 1), (x, y)], "leaf-2")
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            c.px(x + dx, y + dy, "gold-5")
        c.px(x, y, "ember-4")
    return c


def hearthroot_stones(rng):
    c = Cell()
    for _ in range(2):
        x = rng.randint(3, 20)
        w = rng.randint(5, 9)
        h = rng.randint(3, 5)
        c.disc(x + w / 2, H - h / 2, w / 2, h / 2 + 0.5, "stone-3")
        c.rect(x + 1, H - h, w - 3, 1, "stone-5")
        c.px(x + 1, H - h + 1, "stone-6")
        c.rect(x, H - 1, w, 1, "stone-2")
    c.outline("night-1")
    return c


def hearthroot_crate(rng):
    c = Cell()
    x0 = rng.randint(4, 8)
    w, h = 18, 16
    top = H - h
    for y in range(top, H):
        c.rect(x0, y, w, 1, "bark-2" if (y - top) % 5 == 4 else "bark-3")
    # Grain on each plank, corner posts and a brace.
    for y in range(top + 1, H, 5):
        c.rect(x0 + rng.randint(2, 10), y + 1, rng.randint(3, 6), 1, "bark-4")
    c.rect(x0, top, 2, h, "bark-2")
    c.rect(x0 + w - 2, top, 2, h, "bark-2")
    c.line([(x0 + 2, top + 1), (x0 + w - 3, H - 2)], "bark-2")
    c.line([(x0 + 2, top + 2), (x0 + w - 4, H - 2)], "bark-4")
    c.rect(x0, top, w, 1, "bark-5")
    for nx in (x0 + 1, x0 + w - 2):
        c.px(nx, top + 1, "stone-5")
        c.px(nx, H - 2, "stone-5")
    c.outline("bark-1")
    return c


def hearthroot_ivy(rng):
    c = Cell()
    for _ in range(rng.randint(2, 3)):
        x = rng.randint(4, 26)
        length = rng.randint(10, 32)
        for y in range(length):
            xx = x + round(math.sin(y * 0.3) * 1.5)
            c.px(xx, y, "leaf-1")
            if y % 6 == 3:
                # A leaf on alternating sides.
                d = 1 if (y // 6) % 2 else -1
                c.rect(xx + d, y - 1, 2 * d if d > 0 else 1, 2, "leaf-2")
                c.px(xx + 2 * d, y - 1, "leaf-3")
                c.px(xx + d, y + 1, "leaf-2")
    return c


def hearthroot_chain(rng):
    c = Cell()
    x = rng.randint(13, 18)
    length = rng.randint(12, 24)
    for y in range(0, length, 4):
        # Alternating links: an oval face-on, then one edge-on.
        if (y // 4) % 2 == 0:
            c.rect(x - 1, y, 1, 4, "stone-3")
            c.rect(x + 1, y, 1, 4, "stone-4")
            c.px(x, y, "stone-5")
            c.px(x, y + 3, "stone-3")
        else:
            c.rect(x, y, 1, 4, "stone-5")
    # A hook at the end.
    c.rect(x - 1, length, 3, 1, "stone-4")
    c.line([(x + 1, length), (x + 1, length + 4), (x - 1, length + 5), (x - 2, length + 3)], "stone-3")
    c.px(x + 1, length + 1, "stone-6")
    c.outline("night-1")
    return c


def hearthroot_banner(rng):
    c = Cell()
    color, shade = rng.choice((("ember-2", "ember-1"), ("sky-2", "sky-1")))
    for y in range(2, 26):
        for x in range(8, 24):
            if y < 22 or abs(x - 15.5) > (y - 22) * 2 + 0.5:
                c.px(x, y, shade if x > 20 or (x + y) % 9 == 0 else color)
    c.rect(8, 2, 2, 22, "gold-3")
    c.rect(22, 2, 1, 20, "gold-3")
    c.rect(6, 0, 20, 2, "bark-2")
    c.rect(6, 0, 20, 1, "bark-3")
    # An emblem: a small golden tree.
    c.rect(15, 8, 2, 7, "gold-4")
    c.disc(16, 8, 4, 3, "gold-4")
    c.px(14, 7, "gold-6")
    c.outline("night-1")
    return c


def hearthroot_sconce(rng):
    c = Cell()
    y = 28
    c.rect(0, y, 7, 2, "stone-2")
    c.rect(0, y, 6, 1, "stone-4")
    c.rect(5, y - 3, 3, 3, "stone-3")
    c.rect(5, y - 3, 3, 1, "stone-5")
    # The flame: a teardrop with a white-hot core.
    c.disc(6.5, y - 6, 2.2, 3, "ember-4")
    c.disc(6.5, y - 6, 1.4, 2.2, "gold-5")
    c.rect(6, y - 10, 1, 2, "ember-4")
    c.px(6, y - 6, "gold-7")
    c.add_glow(6.5, y - 6)
    c.outline("night-1")
    return c


# --- Hollin Tower ------------------------------------------------------------

def tower_rubble(rng):
    c = Cell()
    for _ in range(rng.randint(3, 5)):
        x = rng.randint(3, 24)
        w = rng.randint(5, 9)
        h = rng.randint(4, 7)
        col = rng.choice(("stone-3", "stone-2", "stone-4"))
        c.disc(x + w / 2, H - h / 2, w / 2, h / 2 + 0.5, col)
        c.rect(x + 1, H - h, w - 3, 1, "stone-5")
        c.px(x + 1, H - h + 1, "stone-6")
    # A bent rivet or two among the stones.
    c.px(rng.randint(5, 25), H - 1, "bark-3")
    c.outline("night-0")
    return c


def tower_lantern(rng):
    """A dwarf's oil lantern left on the floor: the zone's warm light."""
    c = Cell()
    x = rng.randint(10, 18)
    c.rect(x, H - 2, 8, 2, "stone-2")
    c.rect(x + 1, H - 12, 6, 10, "stone-2")
    c.rect(x + 2, H - 11, 4, 8, "ember-4")
    c.rect(x + 3, H - 10, 2, 5, "gold-6")
    c.px(x + 3, H - 9, "gold-7")
    c.rect(x, H - 14, 8, 2, "stone-3")
    c.line([(x + 2, H - 14), (x + 4, H - 18), (x + 6, H - 14)], "stone-3")
    c.add_glow(x + 4, H - 8)
    c.outline("night-0")
    return c


def tower_pick(rng):
    """A worn delvers_pick leaning on a crate of ore."""
    c = Cell()
    c.rect(14, H - 9, 12, 9, "bark-3")
    c.rect(14, H - 9, 12, 1, "bark-4")
    c.rect(14, H - 5, 12, 1, "bark-2")
    for k in range(4):
        c.px(16 + k * 3, H - 10, rng.choice(("crystal-4", "gold-4", "stone-4")))
    c.line([(6, H - 1), (14, H - 22)], "bark-4")
    c.line([(7, H - 1), (15, H - 22)], "bark-2")
    c.line([(9, H - 24), (14, H - 22), (19, H - 19)], "stone-4")
    c.line([(10, H - 25), (15, H - 23), (20, H - 20)], "stone-5")
    c.outline("night-0")
    return c


def tower_hanging_lamp(rng):
    c = Cell()
    x = rng.randint(13, 18)
    length = rng.randint(8, 20)
    c.line([(x, 0), (x, length)], "stone-3")
    c.rect(x - 4, length, 9, 2, "stone-3")
    c.rect(x - 3, length + 2, 7, 6, "stone-2")
    c.rect(x - 2, length + 3, 5, 4, "ember-4")
    c.rect(x - 1, length + 3, 3, 3, "gold-6")
    c.rect(x - 2, length + 8, 5, 1, "stone-3")
    c.add_glow(x + 0.5, length + 5)
    c.outline("night-0")
    return c


def tower_pipe(rng):
    """A pipe out of the ceiling with a rusted joint and a slow drip."""
    c = Cell()
    x = rng.randint(8, 18)
    n = rng.randint(10, 18)
    c.rect(x, 0, 5, n, "stone-3")
    c.rect(x, 0, 1, n, "stone-5")
    c.rect(x + 4, 0, 1, n, "stone-2")
    c.rect(x - 1, n - 4, 7, 3, "stone-4")
    c.rect(x - 1, n - 2, 7, 1, "bark-2")
    c.px(x + 2, n, "stone-2")
    c.px(x + 2, n + 4, "sky-4")
    c.outline("night-0")
    return c


def tower_wall_lamp(rng):
    c = Cell()
    y = 28
    c.rect(0, y, 8, 2, "stone-3")
    c.rect(0, y, 7, 1, "stone-5")
    c.rect(6, y - 7, 5, 7, "stone-2")
    c.rect(7, y - 6, 3, 5, "ember-4")
    c.rect(8, y - 5, 1, 3, "gold-7")
    c.rect(5, y - 8, 7, 1, "stone-3")
    c.add_glow(8.5, y - 4)
    c.outline("night-0")
    return c


def tower_gear_plate(rng):
    """A small cog bolted to the wall, left from some long-stopped machine."""
    c = Cell()
    cx, cy = 3, rng.randint(22, 40)
    c.disc(cx, cy, 8, 8, "stone-3")
    for k in range(10):
        ang = k / 10 * math.tau
        c.rect(cx + math.cos(ang) * 9 - 1, cy + math.sin(ang) * 9 - 1, 3, 3, "stone-3")
    c.disc(cx, cy, 5, 5, "stone-2")
    c.disc(cx, cy, 2, 2, "stone-5")
    c.px(cx - 4, cy - 5, "stone-5")
    c.outline("night-0")
    return c


# --- The Haar ------------------------------------------------------------------

def haar_reeds(rng):
    """Marsh reeds, grey-green, a few with seed heads like bone beads."""
    c = Cell()
    for i in range(rng.randint(7, 11)):
        x = rng.randint(4, 27)
        h = rng.randint(8, 22)
        blade(c, x, h, rng.uniform(-3, 3), "leaf-0", "leaf-1" if i % 3 else "stone-3", "stone-4")
    for _ in range(rng.randint(1, 3)):
        x = rng.randint(7, 24)
        h = rng.randint(18, 26)
        c.line([(x, H - 1), (x, H - h)], "leaf-1")
        c.rect(x - 1, H - h - 4, 3, 4, "stone-5")
        c.px(x, H - h - 4, "stone-6")
    return c


def haar_toadstools(rng):
    """Pale bone-white toadstools with gold-flecked gills."""
    c = Cell()
    for i in range(rng.randint(2, 3)):
        x = 7 + i * 9 + rng.randint(-2, 2)
        h = rng.randint(4, 12)
        c.rect(x, H - h, 2, h, "stone-4")
        r = rng.randint(3, 5)
        c.disc(x + 1, H - h - 1, r, 2.2, "stone-5")
        c.rect(x + 1 - r, H - h - 2, r * 2, 1, "stone-6")
        c.rect(x + 1 - r + 1, H - h, r * 2 - 2, 1, "gold-2")
    c.outline("night-0")
    return c


def haar_lantern_post(rng):
    """A boardwalk post with a soul-lantern hooked to it: the zone's light."""
    c = Cell()
    x = rng.randint(10, 14)
    c.rect(x, H - 34, 4, 34, "bark-2")
    c.rect(x, H - 34, 1, 34, "bark-3")
    c.rect(x + 3, H - 34, 1, 34, "bark-1")
    c.rect(x - 1, H - 36, 6, 2, "bark-1")
    c.line([(x + 4, H - 30), (x + 9, H - 30), (x + 9, H - 27)], "stone-3")
    c.rect(x + 6, H - 27, 7, 9, "stone-2")
    c.rect(x + 7, H - 26, 5, 7, "gold-4")
    c.rect(x + 8, H - 25, 3, 4, "gold-6")
    c.px(x + 9, H - 24, "gold-7")
    c.rect(x + 7, H - 18, 5, 1, "stone-3")
    c.add_glow(x + 9.5, H - 22)
    c.outline("night-0")
    return c


def haar_stake(rng):
    """A rotted boardwalk stake, snapped, with a rag of moss."""
    c = Cell()
    x = rng.randint(8, 18)
    h = rng.randint(10, 20)
    c.rect(x, H - h, 5, h, "bark-1")
    c.rect(x + 1, H - h, 2, h, "bark-2")
    c.line([(x, H - h), (x + 2, H - h - 3), (x + 4, H - h + 1)], "bark-2")
    c.rect(x - 1, H - h + 3, 7, 2, "leaf-1")
    c.line([(x + 1, H - h + 5), (x + 1, H - h + 9)], "leaf-1")
    c.outline("night-0")
    return c


def haar_beard(rng):
    """A beard of grey moss hanging from a limb."""
    c = Cell()
    for _ in range(rng.randint(5, 8)):
        x = rng.randint(4, 27)
        n = rng.randint(10, 40)
        ph = rng.random() * math.tau
        for y in range(n):
            col = "leaf-1" if y < n * 0.6 else ("stone-3" if y < n - 2 else "stone-4")
            c.px(x + math.sin(ph + y * 0.2) * 1.5, y, col)
    for x in range(4, 28):
        for y in range(rng.randint(1, 4)):
            c.px(x, y, "leaf-0")
    return c


def haar_hanging_lantern(rng):
    """A lantern on a long cord, the light of a drowned soul inside."""
    c = Cell()
    x = rng.randint(13, 18)
    n = rng.randint(14, 30)
    c.line([(x, 0), (x, n)], "stone-3")
    c.rect(x - 3, n, 7, 2, "stone-3")
    c.rect(x - 3, n + 2, 7, 9, "stone-2")
    c.rect(x - 2, n + 3, 5, 7, "gold-4")
    c.rect(x - 1, n + 4, 3, 4, "gold-6")
    c.px(x, n + 5, "gold-7")
    c.rect(x - 2, n + 11, 5, 1, "stone-3")
    c.add_glow(x + 0.5, n + 6)
    c.outline("night-0")
    return c


def haar_drip(rng):
    """Dead rootlets with a bead of water at the tip."""
    c = Cell()
    for s in range(rng.randint(2, 3)):
        x = 6 + s * 9 + rng.randint(-2, 2)
        n = rng.randint(10, 30)
        c.line([(x, 0), (x + rng.randint(-2, 2), n)], "stone-2")
        c.px(x, n + 3, "sky-4")
    return c


def haar_bracket(rng):
    """A pale bracket fungus on a wall, ringed like old bone."""
    c = Cell()
    y = rng.randint(24, 44)
    for i, w in enumerate((12, 11, 9, 6)):
        c.rect(0, y + i * 2, w, 2, "stone-5" if i == 0 else ("stone-4" if i == 1 else "stone-3"))
    c.rect(0, y - 1, 10, 1, "stone-6")
    for i in range(4):
        c.px(11 - i * 2, y + 2 + i, "stone-2")
    c.outline("night-0")
    return c


def haar_wall_lantern(rng):
    c = Cell()
    y = 30
    c.rect(0, y, 9, 2, "bark-2")
    c.line([(8, y), (8, y - 3)], "stone-3")
    c.rect(5, y - 11, 7, 8, "stone-2")
    c.rect(6, y - 10, 5, 6, "gold-4")
    c.rect(7, y - 9, 3, 3, "gold-6")
    c.px(8, y - 8, "gold-7")
    c.add_glow(8.5, y - 7)
    c.outline("night-0")
    return c


def boughs_litter(rng):
    """Fallen leaves on the bough, green and gold, one curled up."""
    c = Cell()
    for _ in range(rng.randint(3, 5)):
        x = rng.randint(4, 26)
        w = rng.randint(4, 7)
        col = rng.choice(["leaf-3", "leaf-4", "gold-4"])
        c.disc(x, H - 2, w, 1.6, col)
        c.line([(x - w + 1, H - 2), (x + w - 1, H - 2)], "leaf-2" if col != "gold-4" else "gold-3")
    c.outline("night-0")
    return c


def boughs_flowers(rng):
    """Small sky-blue canopy flowers on thin stems among grass."""
    c = Cell()
    for i in range(rng.randint(5, 8)):
        blade(c, rng.randint(3, 28), rng.randint(5, 12), rng.uniform(-2, 2), "leaf-2", "leaf-4", "leaf-5")
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(5, 26)
        h = rng.randint(8, 16)
        c.line([(x, H - 1), (x, H - h)], "leaf-3")
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            c.px(x + dx, H - h + dy, "sky-6")
        c.px(x, H - h, "gold-6")
    return c


def boughs_sprout(rng):
    """A young shoot unfurling from the bark: two broad leaves."""
    c = Cell()
    x = rng.randint(12, 18)
    h = rng.randint(14, 22)
    c.line([(x, H - 1), (x + 1, H - h)], "leaf-2")
    c.disc(x - 4, H - h + 2, 5, 2.5, "leaf-4")
    c.disc(x + 6, H - h + 5, 5, 2.5, "leaf-3")
    c.line([(x - 8, H - h + 2), (x - 1, H - h + 2)], "leaf-2")
    c.outline("night-0")
    return c


def boughs_hanging_leaves(rng):
    """A spray of leaves hanging from the bough above."""
    c = Cell()
    for _ in range(rng.randint(3, 5)):
        x = rng.randint(5, 26)
        n = rng.randint(6, 26)
        c.line([(x, 0), (x + rng.randint(-2, 2), n)], "leaf-2")
        c.disc(x, n + 3, 2.5, 4.5, rng.choice(["leaf-3", "leaf-4"]))
        c.px(x, n + 2, "leaf-5")
    c.outline("night-0")
    return c


def boughs_vine(rng):
    """A creeper vine trailing down, leaves every few pixels."""
    c = Cell()
    x = rng.randint(8, 22)
    n = rng.randint(30, 60)
    ph = rng.random() * math.tau
    for y in range(n):
        xx = x + math.sin(ph + y * 0.15) * 3
        c.px(xx, y, "leaf-1")
        if y % 7 == 3:
            c.disc(xx + (2 if y % 14 == 3 else -2), y, 2, 1.4, "leaf-3")
    return c


def boughs_wall_shelf(rng):
    """A sun-yellow bracket fungus on a wall of bark."""
    c = Cell()
    y = rng.randint(24, 44)
    for i, w in enumerate((11, 10, 8, 5)):
        c.rect(0, y + i * 2, w, 2, "gold-5" if i == 0 else ("gold-4" if i == 1 else "bark-4"))
    c.rect(0, y - 1, 9, 1, "gold-6")
    c.outline("night-0")
    return c


def boughs_wall_sprig(rng):
    """A sprig of leaves growing out of a crack in the bark."""
    c = Cell()
    y = rng.randint(20, 44)
    c.line([(0, y), (6, y - 3), (10, y - 4)], "leaf-2")
    c.disc(7, y - 6, 3, 2, "leaf-4")
    c.disc(11, y - 3, 3, 2, "leaf-3")
    c.outline("night-0")
    return c


def spires_rubble(rng):
    """Fallen shrine stone: pale blocks, one with a run of gold inlay."""
    c = Cell()
    for _ in range(rng.randint(2, 3)):
        w, h = rng.randint(5, 9), rng.randint(3, 6)
        x = rng.randint(2, 30 - w)
        c.rect(x, H - h, w, h, "stone-4")
        c.rect(x, H - h, w, 1, "stone-6")
        c.rect(x + w - 1, H - h + 1, 1, h - 1, "stone-2")
        if rng.random() > 0.5:
            c.rect(x + 1, H - h + h // 2, w - 2, 1, "gold-5")
    c.outline("night-0")
    return c


def spires_grass(rng):
    """Wind-bent sky grass, pale and gold-tipped, all leaning one way."""
    c = Cell()
    lean = rng.uniform(3, 6)
    for _ in range(rng.randint(7, 11)):
        blade(c, rng.randint(2, 28), rng.randint(6, 14), lean, "leaf-3", "leaf-5", "gold-6")
    return c


def spires_pillar(rng):
    """The broken stump of a shrine pillar, fluted, its top sheared off."""
    c = Cell()
    x, h = rng.randint(9, 13), rng.randint(20, 34)
    c.rect(x - 2, H - 3, 14, 3, "stone-3")
    for k in range(h):
        y = H - 3 - k
        top = h - 1 - (k * 3 // h if x % 2 else 0)
        c.rect(x, y, 10, 1, "stone-4")
        c.px(x + 2, y, "stone-2")
        c.px(x + 5, y, "stone-2")
        c.px(x, y, "stone-5")
        c.px(x + 9, y, "stone-2")
    c.line([(x, H - 3 - h), (x + 4, H - 1 - h), (x + 9, H - 5 - h)], "stone-6")
    c.rect(x, H - 3 - h * 2 // 3, 10, 1, "gold-5")
    c.outline("night-0")
    return c


def spires_conduit(rng):
    """A dead lightning conduit: a bronze rod on a stone foot, a dull crystal at its tip."""
    c = Cell()
    x = rng.randint(13, 17)
    h = rng.randint(26, 36)
    c.rect(x - 4, H - 4, 10, 4, "stone-3")
    c.rect(x - 4, H - 4, 10, 1, "stone-5")
    c.rect(x, H - 4 - h, 2, h, "bark-4")
    c.rect(x, H - 4 - h, 1, h, "gold-4")
    for k in range(3, h, 7):
        c.rect(x - 1, H - 4 - k, 4, 1, "gold-3")
    c.disc(x + 1, H - 7 - h, 2.5, 3.5, "crystal-3")
    c.px(x, H - 8 - h, "crystal-5")
    c.outline("night-0")
    return c


def spires_roots(rng):
    """Pale air-roots trailing from an island's underside."""
    c = Cell()
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(4, 26)
        n = rng.randint(10, 40)
        ph = rng.random() * math.tau
        for y in range(n):
            c.px(x + math.sin(ph + y * 0.2) * 1.5, y, "stone-5" if y % 5 else "stone-4")
    return c


def spires_crystals(rng):
    """Storm crystals grown down from the stone, faintly lit."""
    c = Cell()
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(5, 26)
        n = rng.randint(5, 14)
        for y in range(n):
            w = max(1, (n - y) * 3 // n)
            c.rect(x - w // 2, y, w, 1, "crystal-4" if y < n - 2 else "crystal-6")
    c.outline("night-0")
    if rng.random() > 0.5:
        c.add_glow(16, 8)
    return c


def spires_wall_rune(rng):
    """A gold rune plaque set into the shrine wall, still warm with light."""
    c = Cell()
    y = rng.randint(22, 40)
    c.rect(0, y, 8, 12, "stone-5")
    c.rect(0, y, 8, 1, "stone-6")
    c.line([(2, y + 2), (5, y + 5), (2, y + 9)], "gold-6")
    c.px(5, y + 9, "gold-6")
    c.add_glow(3, y + 5)
    c.outline("night-0")
    return c


def spires_wall_ledge(rng):
    """A cracked cornice jutting from the wall, grass along its top."""
    c = Cell()
    y = rng.randint(24, 44)
    c.rect(0, y, 11, 3, "stone-4")
    c.rect(0, y, 11, 1, "stone-6")
    c.rect(0, y + 3, 8, 2, "stone-2")
    for x in range(0, 10, 2):
        c.px(x, y - 1, "leaf-4")
    c.outline("night-0")
    return c


def vorrhallow_shards(rng):
    """Stillglass crystal shards pushing up through the floor, lit from within."""
    c = Cell()
    base = rng.randint(8, 22)
    for _ in range(rng.randint(2, 4)):
        x = base + rng.randint(-6, 6)
        h = rng.randint(6, 18)
        lean = rng.uniform(-0.5, 0.5)
        for k in range(h):
            w = max(1, (h - k) * 4 // h)
            xx = x + int(lean * k)
            c.rect(xx - w // 2, H - 1 - k, w, 1, "crystal-4" if k < h - 3 else "crystal-6")
            c.px(xx - w // 2, H - 1 - k, "crystal-2")
    c.outline("night-0")
    c.add_glow(base, H - 8)
    return c


def vorrhallow_rubble(rng):
    """Dark dwarf masonry fallen in the flood, slick with teal weed."""
    c = Cell()
    for _ in range(rng.randint(2, 3)):
        w, h = rng.randint(6, 10), rng.randint(3, 6)
        x = rng.randint(2, 30 - w)
        c.rect(x, H - h, w, h, "stone-2")
        c.rect(x, H - h, w, 1, "stone-4")
        c.rect(x + w - 1, H - h + 1, 1, h - 1, "night-1")
        for k in range(0, w, 2):
            c.px(x + k, H - h - 1, "sky-3")
    c.outline("night-0")
    return c


def vorrhallow_helm(rng):
    """A drowned dwarf helm, horned and rusted, half sunk in silt."""
    c = Cell()
    x = rng.randint(10, 18)
    c.disc(x + 4, H - 3, 5, 4, "bark-2")
    c.rect(x - 1, H - 3, 11, 3, "stone-1")
    c.rect(x, H - 6, 9, 1, "bark-4")
    c.line([(x, H - 5), (x - 3, H - 9), (x - 3, H - 11)], "stone-5")
    c.line([(x + 8, H - 5), (x + 11, H - 9), (x + 11, H - 11)], "stone-5")
    c.px(x + 4, H - 4, "night-0")
    c.outline("night-0")
    return c


def vorrhallow_weed(rng):
    """Teal waterweed left standing when the flood went down."""
    c = Cell()
    for _ in range(rng.randint(5, 9)):
        blade(c, rng.randint(2, 28), rng.randint(5, 11), rng.uniform(-1.5, 1.5), "sky-2", "sky-3", "sky-4")
    return c


def vorrhallow_stalactites(rng):
    """Crystal stalactites hanging from the vault, dripping."""
    c = Cell()
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(5, 26)
        n = rng.randint(6, 16)
        for y in range(n):
            w = max(1, (n - y) * 3 // n)
            c.rect(x - w // 2, y, w, 1, "crystal-3" if y < n - 2 else "crystal-5")
        if rng.random() > 0.5:
            c.px(x, n + 3, "sky-5")
    c.outline("night-0")
    if rng.random() > 0.4:
        c.add_glow(16, 8)
    return c


def vorrhallow_drip(rng):
    """Water seeping from the vault joints, a bead at each tip."""
    c = Cell()
    for k in range(rng.randint(2, 3)):
        x = 6 + k * 9 + rng.randint(-2, 2)
        n = rng.randint(6, 18)
        c.line([(x, 0), (x, n)], "sky-2")
        c.px(x, n + 2, "sky-5")
    return c


def vorrhallow_wall_crystal(rng):
    """A crystal cluster grown out of the wall, glowing."""
    c = Cell()
    y = rng.randint(22, 42)
    for k in range(3):
        n = 6 + k * 2
        for t in range(n):
            c.px(t, y - k * 3 + t // 2, "crystal-4" if t < n - 2 else "crystal-6")
            c.px(t, y - k * 3 + t // 2 + 1, "crystal-2")
    c.outline("night-0")
    c.add_glow(5, y)
    return c


def vorrhallow_wall_brazier(rng):
    """A dwarf wall brazier, drowned and dark, weed hanging from its lip."""
    c = Cell()
    y = rng.randint(24, 42)
    c.rect(0, y, 3, 2, "stone-3")
    c.rect(2, y - 4, 8, 4, "bark-2")
    c.rect(2, y - 4, 8, 1, "bark-4")
    for x in range(3, 10, 2):
        c.px(x, y + rng.randint(0, 3), "sky-3")
    c.outline("night-0")
    return c


def evercrown_polyps(rng):
    """Polyps of stillglass flesh budding from the floor, each tipped with a cyan eye."""
    c = Cell()
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(4, 27)
        h = rng.randint(4, 12)
        for k in range(h):
            w = 3 if k < h - 2 else 2
            c.rect(x - w // 2, H - 1 - k, w, 1, "night-2" if k % 3 else "crystal-1")
        c.rect(x - 1, H - h - 2, 3, 2, "night-1")
        c.px(x, H - h - 2, "sky-6")
        c.px(x - 1, H - h - 1, "sky-3")
    c.outline("night-0")
    c.add_glow(16, H - 8)
    return c


EVERCROWN_STUB = 8  # the tallest stub, under a floor spike's 10


def evercrown_shards(rng):
    """Black-violet crystal stubs, wine light deep inside them. Short and blunt
    (EVERCROWN_STUB world pixels at most, a flat top two wide), and no brighter
    than crystal-2: a row of tall bright splinters read as floor spikes
    (design bible 12.48)."""
    c = Cell()
    base = rng.randint(8, 22)
    for _ in range(rng.randint(2, 3)):
        x = base + rng.randint(-6, 6)
        h = rng.randint(4, EVERCROWN_STUB)
        lean = rng.uniform(-0.4, 0.4)
        for k in range(h):
            w = max(2, (h - k) * 4 // h)
            xx = x + int(lean * k)
            c.rect(xx - w // 2, H - 1 - k, w, 1, "crystal-1" if k % 4 else "crystal-2")
            c.px(xx - w // 2, H - 1 - k, "night-3")
    c.outline("night-0")
    return c


def evercrown_veins(rng):
    """Veins of light crawling over the floor, pulsing toward the core."""
    c = Cell()
    x, y = 0, H - 2
    while x < 32:
        c.px(x, y, "sky-5")
        c.px(x, y + 1, "sky-2")
        x += 1
        if rng.random() > 0.7:
            y = max(H - 4, min(H - 2, y + rng.choice([-1, 1])))
    return c


def evercrown_tendrils(rng):
    """Tendrils hanging from the vault, each ending in a bead of cyan light."""
    c = Cell()
    for _ in range(rng.randint(2, 4)):
        x = rng.randint(4, 27)
        n = rng.randint(8, 22)
        for y in range(n):
            xx = x + int(math.sin(y / 4.0) * 1.5)
            c.px(xx, y, "night-2" if y % 4 else "crystal-1")
            c.px(xx + 1, y, "night-1")
        c.px(x, n, "sky-5")
        c.px(x, n + 1, "sky-3")
    c.outline("night-0")
    return c


def evercrown_eyes(rng):
    """A cluster of lidless cyan eyes in the vault, watching."""
    c = Cell()
    for _ in range(rng.randint(2, 3)):
        x, y = rng.randint(5, 26), rng.randint(2, 10)
        c.disc(x, y, 3, 2, "night-2")
        c.rect(x - 1, y, 3, 1, "sky-5")
        c.px(x, y, "night-0")
    c.outline("night-0")
    c.add_glow(16, 6)
    return c


def evercrown_wall_eye(rng):
    """One great eye opening in the wall, wine-veined."""
    c = Cell()
    y = rng.randint(22, 42)
    c.disc(4, y, 5, 3, "night-2")
    c.rect(1, y - 1, 7, 3, "crystal-1")
    c.rect(2, y - 1, 5, 3, "sky-5")
    c.rect(4, y - 1, 1, 3, "night-0")
    c.outline("night-0")
    c.add_glow(4, y)
    return c


def evercrown_wall_growth(rng):
    """A shelf of stillglass flesh grown out of the wall."""
    c = Cell()
    y = rng.randint(24, 42)
    for k in range(4):
        c.rect(0, y + k, 9 - k * 2, 1, "night-2" if k else "crystal-2")
    c.px(3, y + 1, "sky-6")
    c.outline("night-0")
    return c


def sunken_rimstone(rng):
    """Little rimstone dams the spring built on the floor, each holding a skin of water."""
    c = Cell()
    x = rng.randint(1, 6)
    while x < 28:
        w = rng.randint(5, 9)
        h = rng.randint(2, 4)
        c.rect(x, H - h, w, h, "stone-4")
        c.rect(x + 1, H - h, w - 2, 1, "sky-4")
        c.px(x, H - h, "stone-6")
        c.px(x + w - 1, H - h, "stone-6")
        x += w + rng.randint(1, 3)
    c.outline("night-0")
    return c


def sunken_pearls(rng):
    """Spring pearls in a hollow of the floor, each glowing faintly."""
    c = Cell()
    cx = rng.randint(8, 22)
    c.rect(cx - 5, H - 2, 12, 2, "stone-2")
    for k in range(rng.randint(3, 5)):
        x = cx - 3 + k * 2 + rng.randint(0, 1)
        c.disc(x, H - 3, 1, 1, "sky-6")
        c.px(x, H - 4, "gold-7")
    c.outline("night-0")
    c.add_glow(cx, H - 4)
    return c


def sunken_straws(rng):
    """Limestone straws hanging from the vault, a drop at each tip."""
    c = Cell()
    for _ in range(rng.randint(3, 6)):
        x = rng.randint(2, 29)
        n = rng.randint(3, 14)
        c.rect(x, 0, 2 if n > 8 else 1, n, "stone-4")
        c.px(x, n, "sky-5")
    c.outline("night-0")
    return c


def sunken_wall_seep(rng):
    """The spring's light seeping out of a crack in the wall."""
    c = Cell()
    y = rng.randint(20, 40)
    for t in range(rng.randint(6, 12)):
        c.px(1 + (t % 3 == 0), y + t, "sky-6" if t % 4 else "sky-4")
        c.px(0, y + t, "night-1")
    c.add_glow(2, y + 4)
    return c


def sunken_wall_flowstone(rng):
    """A curtain of flowstone poured down the wall in pale ridges."""
    c = Cell()
    y = rng.randint(18, 36)
    for k in range(rng.randint(8, 14)):
        w = 5 - abs(k % 6 - 3)
        c.rect(0, y + k, w + 2, 1, "stone-5" if k % 3 else "stone-3")
    c.outline("night-0")
    return c


ZONES = {
    "heartwood": {
        "floor": [heartwood_tuft, heartwood_tuft, lambda r: heartwood_fungus(r, False), lambda r: heartwood_fungus(r, True),
                  heartwood_mushroom, heartwood_twig],
        "ceiling": [lambda r: heartwood_roots(r, False), lambda r: heartwood_roots(r, False),
                    lambda r: heartwood_roots(r, True), heartwood_moss],
        "wall": [lambda r: heartwood_shelf(r, False), lambda r: heartwood_shelf(r, True)],
    },
    "hearthroot": {
        "floor": [hearthroot_weeds, hearthroot_weeds, hearthroot_stones, hearthroot_weeds, hearthroot_stones, hearthroot_crate],
        "ceiling": [hearthroot_ivy, hearthroot_chain, hearthroot_banner],
        "wall": [hearthroot_sconce],
    },
    "tower": {
        "floor": [tower_rubble, tower_rubble, tower_lantern, tower_pick, tower_rubble, hearthroot_crate],
        "ceiling": [hearthroot_chain, tower_hanging_lamp, tower_pipe, hearthroot_chain],
        "wall": [tower_wall_lamp, tower_gear_plate],
    },
    "haar": {
        "floor": [haar_reeds, haar_reeds, haar_toadstools, haar_lantern_post, haar_stake, haar_reeds],
        "ceiling": [haar_beard, haar_beard, haar_hanging_lantern, haar_drip],
        "wall": [haar_bracket, haar_wall_lantern],
    },
    "boughs": {
        "floor": [boughs_litter, boughs_flowers, boughs_sprout, boughs_litter, boughs_flowers, boughs_litter],
        "ceiling": [boughs_hanging_leaves, boughs_vine, boughs_hanging_leaves, boughs_vine],
        "wall": [boughs_wall_shelf, boughs_wall_sprig],
    },
    "spires": {
        "floor": [spires_grass, spires_rubble, spires_grass, spires_pillar, spires_conduit, spires_grass],
        "ceiling": [spires_roots, spires_crystals, spires_roots, spires_crystals],
        "wall": [spires_wall_rune, spires_wall_ledge],
    },
    "vorrhallow": {
        "floor": [vorrhallow_weed, vorrhallow_rubble, vorrhallow_shards, vorrhallow_weed, vorrhallow_helm, vorrhallow_weed],
        "ceiling": [vorrhallow_drip, vorrhallow_stalactites, hearthroot_chain, vorrhallow_stalactites],
        "wall": [vorrhallow_wall_crystal, vorrhallow_wall_brazier],
    },
    "evercrown": {
        "floor": [evercrown_veins, evercrown_polyps, evercrown_shards, evercrown_veins, evercrown_polyps, evercrown_veins],
        "ceiling": [evercrown_tendrils, evercrown_eyes, evercrown_tendrils, evercrown_tendrils],
        "wall": [evercrown_wall_eye, evercrown_wall_growth],
    },
    # The inner rings keeps only stone: rubble, a hanging chain, a cold sconce.
    "trials": {
        "floor": [hearthroot_stones, vorrhallow_rubble, hearthroot_stones, vorrhallow_rubble, hearthroot_stones, hearthroot_stones],
        "ceiling": [hearthroot_chain, hearthroot_chain, sunken_straws, hearthroot_chain],
        "wall": [hearthroot_sconce, sunken_wall_flowstone],
    },
    "sunken": {
        "floor": [sunken_rimstone, vorrhallow_weed, sunken_pearls, sunken_rimstone, vorrhallow_weed, sunken_rimstone],
        "ceiling": [sunken_straws, vorrhallow_drip, sunken_straws, sunken_straws],
        "wall": [sunken_wall_seep, sunken_wall_flowstone],
    },
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for zone, rows in ZONES.items():
        rng = random.Random(zone)
        atlas = Image.new("RGBA", (COLS * W, 4 * H), (0, 0, 0, 0))
        meta = {"cell": [CELL_W, CELL_H], "density": D, "floor": [], "ceiling": [], "wall": []}
        for row, kind in enumerate(("floor", "ceiling", "wall")):
            for col, fn in enumerate(rows[kind]):
                cell = fn(rng)
                atlas.paste(cell.img, (col * W, row * H))
                meta[kind].append({"glow": cell.glow})
                if kind == "wall":
                    atlas.paste(cell.img.transpose(Image.FLIP_LEFT_RIGHT), (col * W, 3 * H))
        atlas.save(OUT / f"{zone}.png")
        (OUT / f"{zone}.json").write_text(json.dumps(meta) + "\n")
        print(zone, {k: len(v) for k, v in rows.items()})


if __name__ == "__main__":
    main()
