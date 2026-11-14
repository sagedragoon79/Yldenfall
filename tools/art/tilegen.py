#!/usr/bin/env python3
"""Generates the zone tilesets and parallax backgrounds (design bible 13.3).

Every color comes from the master palette (tools/art/palette.py). Each zone is a
material spec: a texture painter for the ground, edge rules for exposed sides
(a cap on top, a lip underneath, outlines on the sides), and background layers.

Tileset atlas (16 world px tiles at 2x render density, so 32 px each; 8 columns):
  rows 0-5: the 47 "blob" autotiles, in the order of blob_masks() below
            (scripts/world/tileset_factory.gd computes the same list)
  row 6:    one-way platform, amber, 2 interior tiles one shade darker (two
            tiles from open air) and 2 two shades darker (three or more), then
            the two 45-degree slopes: "/" rising to the east, "\\" rising to the west
  row 7:    extra masonry variants so large solid fields stop reading as a 32 px
            grid (bible 12.8): 3 full-solid surface variants, then 2 more of each
            darker interior tile (MID one shade, DEEP two). The factory picks one
            per cell by position, so adjacent same-mask cells draw a different
            pattern and the repeat unit no longer bands.
Backgrounds: <zone>_far.png, <zone>_ridge.png and <zone>_mid.png, 640x480, tile
horizontally (far, a distant ridgeline, then the near parallax).

Usage: python3 tools/art/tilegen.py
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TILES = ROOT / "assets" / "tiles"
BG = ROOT / "assets" / "bg"
## Render density (design bible 12.1): tiles are 16 world pixels drawn with
## two pixels per world pixel, so the atlas holds 32 px tiles.
D = 2
T = 16 * D
COLS = 8
## Backgrounds are 640x480 world pixels, painted at the same density.
BG_W, BG_H = 640 * D, 480 * D

PAL = {}
for _name, _hue, _sat in palette.RAMPS:
    for _i in range(8):
        PAL[f"{_name}-{_i}"] = palette.shade(_hue, _sat, _i) + (255,)
CLEAR = (0, 0, 0, 0)


def c(name, alpha=255):
    r, g, b, _ = PAL[name]
    return (r, g, b, alpha)


# --- Blob autotile masks -------------------------------------------------------------
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128


def reduce_mask(m):
    """Corners only count when both sides next to them are solid."""
    if not (m & N and m & E):
        m &= ~NE
    if not (m & S and m & E):
        m &= ~SE
    if not (m & S and m & W):
        m &= ~SW
    if not (m & N and m & W):
        m &= ~NW
    return m


def blob_masks():
    return sorted({reduce_mask(m) for m in range(256)})


# --- Materials ---------------------------------------------------------------------------
def hash2(x, y, seed):
    h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 0xFFFF


# --- Weathered masonry (design bible 12.14) ------------------------------------
# The backdrop's brick and column fields used to draw their mortar courses on a
# fixed vertical period (``y % spacing``) over a single flat body colour, so the
# independent grade kept reading them as one repeated stamp (passes 497, 502,
# 504). These two helpers break that lattice: courses land on jittered, partly
# worn-away rows, and each stone takes a slightly different value, so a wall reads
# as real coursed masonry instead of a stencil.


def masonry_courses(top, bottom, seed, spacing):
    """The y rows of weathered mortar courses between ``top`` and ``bottom``.

    Gaps jitter between 0.5x and 1.5x ``spacing`` (so there is no fixed vertical
    period), a course is one or two render pixels thick, and roughly one course in
    six is worn away (a gap of two courses or more). Deterministic from ``seed``;
    returns a set for fast membership in a pixel loop."""
    ys = set()
    y = top + spacing
    i = 0
    while y < bottom:
        if hash2(i, 1, seed) > 0.16:  # ~1 course in 6 worn away
            for k in range(2 if hash2(i, 2, seed) > 0.7 else 1):
                ys.add(y + k)
        y += spacing + int((hash2(i, 0, seed) - 0.5) * spacing)  # gap 0.5x..1.5x
        i += 1
    return ys


def masonry_shade(x, y, seed, dark, body, light, cell=16):
    """A per-stone shade for a masonry field: most cells draw ``body``, a few drop
    to ``dark`` or lift to ``light``, keyed by a coarse ``cell`` grid so adjacent
    stones differ in value and the field stops reading as one flat colour.

    The stones are laid in a running bond: every course shifts horizontally — half
    a stone on alternate rows, plus a per-course jitter — so same-value stones (and
    the recessed dark ones) never stack into the straight vertical columns that
    made the mid column/pier fields read as one stamped lattice (independent grade,
    passes 497/502/504; bible 12.14).

    Each accent stone is a brick, ``cell`` wide and half as tall, and it is drawn
    as a deliberate shape rather than a flat square of another value (bible 12.27):
    a lighter stone stands proud, its face lit with its shadow along its foot and
    its right side; a darker one is a recess (a slot window or a missing stone),
    shadowed inside with a lit sill along its foot. The flat squares read as
    "random 'missing pixel' blocks" in the tower, Vorrhallow and Hearthroot ruins
    (independent grade, pass 529)."""
    bh = max(2, cell // 2)
    row = y // bh
    off = (row % 2) * (cell // 2) + int(hash2(row, 5, seed) * cell)
    sx = x + off
    h = hash2(sx // cell, row, seed)
    ly, lx = y % bh, sx % cell
    if h > 0.93:  # a proud stone: lit face, shadow along its foot and right side
        return dark if (ly == bh - 1 or lx == cell - 1) else light
    if h < 0.12:  # a recess: shadowed inside, a lit sill along its foot
        return light if ly == bh - 1 else dark
    return body


# One body value, the odd worn block (design bible 12.45, pass 555). The Tower's
# plates and Vorrhallow's blocks used to take one of two values on a coin toss,
# so a field read as a checkerboard a whole shade deep, loudest in the darkened
# interior tiers (independent grade, passes 540 and 550: "frame tiles repeat on a
# loud grid, Tower and Vorrhallow checkered stone"). Most blocks now share the
# body value and about one in seven is worn a shade darker.
WORN_BLOCK = 0.86
# The share of Vorrhallow's tiles that carry the teal tide stain. Drawn in every
# tile it ruled a stripe across the field every 16 world pixels.
TIDE_TILES = 0.35
# build_tileset paints the 47 blob tiles with seeds 11 to 57 and the interior
# tiles (MID, DEEP and the row-7 variants) with seeds from 101. Only those carry
# the tide stain: an edge tile has no variants, so a stain on one repeats down
# every wall face and pillar.
INTERIOR_SEED = 101


# The share of bricks that stand a shade proud (paint_bricks).
PROUD_BRICK = 0.92
# Set by paint_tile for the zone in hand: whether its brick grows moss.
BRICK_MOSS = False


def is_interior(seed):
    """True for the seeds build_tileset gives the darkened interior tiers (MID
    and DEEP in row 6, and their row-7 variants). The surface tiles and their
    row-7 variants (201 to 203) are not interior."""
    return INTERIOR_SEED <= seed < 200 or seed >= 211


# A string course under the cap of a masonry floor (design bible 12.46, pass
# 556): a lit line, a band of dressed stone and a shadow line, straight across
# every top tile, so a floor reads as built (a coping on a wall) and not as a
# brick fill that stops at the grass. World-pixel rows from the tile's top.
COURSE_TOP = 7
COURSE_ROWS = 3
COURSE_ZONES = ("spires", "trials", "gym", "vorrhallow", "sunken")
# A footing (design bible 12.47, pass 557): where a wall or a pillar stands on a
# masonry floor, the floor's course carries on under its foot, through the
# inner-corner tile, and ends inside the wall at a head joint. Without it the
# course stopped dead at the wall's face and the wall read as pasted on.
FOOT_JOINT = 1  # world px of joint where a footing ends inside a wall


def string_course(img, ox, oy, seed, x0, x1, ramp):
    y0 = COURSE_TOP * D
    y1 = y0 + COURSE_ROWS * D
    for x in range(x0, x1):
        for y in range(y0, y1):
            if y < y0 + D:
                col = f"{ramp}-6"
            elif y >= y1 - D:
                col = f"{ramp}-1"
            else:
                col = f"{ramp}-5" if hash2(x // 2, y // 2, seed + 41) > 0.12 else f"{ramp}-4"
            img.putpixel((ox + x, oy + y), c(col))
        # A butt joint now and then, so the course is laid stones and not a pipe.
    for x in range(x0, x1):
        if hash2(x // D, 3, seed + 43) > 0.95:
            for y in range(y0 + D, y1 - D):
                img.putpixel((ox + x, oy + y), c(f"{ramp}-2"))


def footing(img, ox, oy, seed, mask, ramp):
    """The string course under the foot of a wall: an interior tile with solid
    above it and open air on an upper diagonal. With both diagonals open (a
    pillar one tile wide) it runs the whole tile; with one, it ends in a head
    joint on the side that goes on into the wall."""
    if not mask & N or not mask & E or not mask & W or (mask & NE and mask & NW):
        return False
    string_course(img, ox, oy, seed, 0, T, ramp)
    y0, y1 = COURSE_TOP * D, (COURSE_TOP + COURSE_ROWS) * D
    for side_open, x0 in ((mask & NE, T - FOOT_JOINT * D), (mask & NW, 0)):
        if side_open:  # this side is under the wall: close the course here
            for x in range(x0, x0 + FOOT_JOINT * D):
                for y in range(y0, y1):
                    img.putpixel((ox + x, oy + y), c(f"{ramp}-1"))
    return True


def crack(img, ox, oy, seed, k, col, length=T // 2):
    """A hairline crack one render pixel wide, running down and wandering
    sideways from a seeded point in the tile's upper half."""
    x, y = int(hash2(seed, k, 32) * (T - 6)) + 3, int(hash2(seed, k, 33) * (T // 2))
    for step in range(length):
        if 0 <= x < T and 0 <= y < T:
            img.putpixel((ox + x, oy + y), col)
        y += 1
        x += 1 if hash2(seed, step, 34 + k) > 0.6 else (-1 if hash2(seed, step, 35 + k) > 0.7 else 0)


# Cracks and moss in a brick field (design bible 12.47). Only the scattered
# variants carry them (an edge tile has no variants, so a mark on one repeats
# down every wall face): a crack in about four variants in ten, and a tuft of
# moss in a joint of a surface variant in the zones that grow moss.
FIELD_CRACK = 0.6
MOSS_ZONES_RAMP = "leaf"
SURFACE_VARIANT_SEEDS = (201, 202, 203)


def field_wear(img, ox, oy, seed, ramp, moss):
    if seed < INTERIOR_SEED:
        return
    if hash2(seed, 0, 31) > FIELD_CRACK:
        crack(img, ox, oy, seed, 0, c(f"{ramp}-1"))
    if moss and seed in SURFACE_VARIANT_SEEDS:
        # A tuft sitting in a bed joint: a run of blocks one world pixel tall,
        # the odd one hanging a pixel lower. Whole world pixels, so it stays calm.
        n = 3 + int(hash2(seed, 1, 61) * 4)                       # 3..6 world px
        mx = int(hash2(seed, 2, 61) * (T // D - n - 2)) + 1
        my = (4 * (1 + int(hash2(seed, 3, 61) * 3)) - 1) * D      # a bed joint row
        for i in range(n):
            drop = 2 if hash2(seed, i, 62) > 0.6 else 1
            for j in range(drop):
                name = f"{MOSS_ZONES_RAMP}-{3 if j == 0 else 2}"
                for dy in range(D):
                    for dx in range(D):
                        yy = my + j * D + dy - (D - 1)
                        if 0 <= yy < T:
                            img.putpixel((ox + (mx + i) * D + dx, oy + yy), c(name))


def paint_bricks(img, ox, oy, seed, ramp):
    """Masonry: rows of 8x4 world-pixel bricks offset per row, lit from the top
    left, with a one-render-pixel mortar line and a grain of tiny pits.

    Running bond (design bible 12.23): the brick lattice carries a per-tile
    vertical phase (``voff``) and a per-course horizontal jitter on top of the
    half-brick alternation, both keyed to ``seed``. The factory scatters this
    painter's variants across a solid field (each a fresh seed), so these phases
    land the courses and the vertical joints at different places in every tile —
    the field stops reading as one stamped 32 px lattice marching down a column
    (independent grade pass 525; the play-scale companion to the pass-525
    backdrop running bond, bible 12.14)."""
    bw, bh = 8 * D, 4 * D
    voff = int(hash2(0, 3, seed) * bh)       # whole lattice shifts up per tile
    for y in range(T):
        yy = y + voff
        for x in range(T):
            row = yy // bh
            # Half-brick alternation plus a per-course horizontal jitter, so the
            # vertical joints do not stack at the same x in every scattered tile.
            sx = x + (row % 2) * (bw // 2) + int(hash2(row, 6, seed) * bw)
            bx = sx // bw
            by = row
            lx, ly = sx % bw, yy % bh
            # One body value, the odd worn or proud brick (bible 12.46).
            shade = 2 if hash2(bx, by, seed) > WORN_BLOCK else 3
            if hash2(bx, by, seed + 9) > PROUD_BRICK:
                shade = 4
            if ly == bh - 1 or lx == 0:
                col = f"{ramp}-1"
            elif ly == 0 or lx == 1:
                col = f"{ramp}-{shade + 1}"
            elif ly == bh - 2 or lx == bw - 1:
                col = f"{ramp}-{shade - 1}"
            else:
                col = f"{ramp}-{shade}"
                if hash2(x, y, seed + 3) > 0.93:
                    col = f"{ramp}-{shade - 1}"
                elif hash2(x, y, seed + 4) > 0.97:
                    col = f"{ramp}-{shade + 1}"
            img.putpixel((ox + x, oy + y), c(col))
    field_wear(img, ox, oy, seed, ramp, BRICK_MOSS)


def paint_shrine(img, ox, oy, seed, ramp):
    """Carillon's ruined elf shrines: big pale ashlar blocks, weathered and
    cracked, some still carrying a groove of gold inlay along their face.

    The block scale, the per-stone weathering and the gold inlay are all keyed to
    ``seed``, so the factory's scattered row-7 variants (each a fresh seed) read as
    differently-coursed masonry instead of one repeated stamp — the independent
    grade's recurring "Spires brick field reads as one repeated stamp" (passes
    497/502/504/515, bible 12.8)."""
    # Course scale varies with the seed so adjacent scattered variants differ.
    bw = (10 + int(hash2(seed, 7, 91) * 5)) * D  # 10..14 blocks wide
    bh = (5 + int(hash2(seed, 8, 92) * 3)) * D   # 5..7 blocks tall
    gold = not is_interior(seed)  # the inlay is surface dressing (bible 12.46)
    for y in range(T):
        row = y // bh
        for x in range(T):
            sx = x + (row % 2) * (bw // 2) + int(hash2(row, 0, seed) * 4) * D
            bx, ly, lx = sx // bw, y % bh, sx % bw
            # One body value, the odd worn block (bible 12.46): a coin toss between
            # two values made the darkened deep tiers a checkerboard.
            shade = 3 if hash2(bx, row, seed) > WORN_BLOCK else 4
            if ly == bh - 1 or lx == 0:
                col = f"{ramp}-1"
            elif ly == 0 or lx == 1:
                col = f"{ramp}-{shade + 1}"
            elif ly == bh - 2:
                col = f"{ramp}-{shade - 1}"
            else:
                col = f"{ramp}-{shade}"
                if hash2(x // 2, y // 2, seed + 5) > 0.9:
                    col = f"{ramp}-{shade - 1}"
            # Gold inlay: a groove across the middle of a few blocks. Rare and
            # keyed per block (not a regular course), so it reads as scattered
            # accents, never a gold dash marching across every row.
            if gold and ly == bh // 2 and 3 <= lx < bw - 3 and hash2(bx, row, seed + 7) > 0.82:
                col = "gold-4" if lx % 4 else "gold-5"
            img.putpixel((ox + x, oy + y), c(col))
    # A crack or two, running down and sideways.
    for k in range(2):
        if hash2(seed, k, 31) > 0.55:
            crack(img, ox, oy, seed, k, c(f"{ramp}-1"))


def paint_drowned(img, ox, oy, seed, ramp):
    """Vorrhallow's drowned masonry: squat dwarven blocks, dark and water-worn,
    a teal tide stain on some where the flood stood, and veins of magenta
    stillglass forcing their way through the joints of some blocks. The blocks
    share one body value; the odd one is worn a shade darker (WORN_BLOCK)."""
    bw, bh = 16 * D, 8 * D
    tide = seed >= INTERIOR_SEED and hash2(seed, 7, 31) < TIDE_TILES
    for y in range(T):
        row = y // bh
        for x in range(T):
            sx = x + (row % 2) * (bw // 2)
            bx, ly, lx = sx // bw, y % bh, sx % bw
            shade = 2 if hash2(bx, row, seed) > WORN_BLOCK else 3
            if ly == bh - 1 or lx == 0:
                col = "night-1"
            elif ly == 0 or lx == 1:
                col = f"{ramp}-{shade + 1}"
            elif ly >= bh - 2:
                col = f"{ramp}-{shade - 1}"
            else:
                col = f"{ramp}-{shade}"
                if hash2(x // 2, y // 2, seed + 5) > 0.88:
                    col = f"{ramp}-{shade - 1}"
            # The tide line: a band of teal stain across some tiles (TIDE_TILES).
            if not tide:
                pass
            elif 11 * D <= y < 12 * D and hash2(x // 3, 0, seed + 9) > 0.2:
                col = "sky-2"
            elif 12 * D <= y < 13 * D and hash2(x // 2, 1, seed + 9) > 0.6:
                col = "sky-1"
            img.putpixel((ox + x, oy + y), c(col))
    field_wear(img, ox, oy, seed, ramp, False)


MEAT_CELLS = 3


def paint_meteor(img, ox, oy, seed, ramp):
    """the Evercrown, the inside of the Everbloom: organic stone grown in rounded cells
    like a honeycomb of scar tissue, black-violet, with blood-red sinew in the
    seams and the odd pore of alien cyan light.

    Calm fill (design bible 12.28, pass 534): the cells are broad (two per tile, not
    three) and wrap across tile edges, each a flat body of one value with a lit rim only
    along its upper side, under a seam one world pixel wide. The older small cells
    with a bright blob at every centre read as "busy cobble" (independent grade,
    pass 529)."""
    # The cells wrap: two across and two down each tile, their centres keyed to
    # the zone (MEAT_CELLS), not the tile, so every tile meets its neighbours
    # with the seams joined and a run of ledge tiles reads as one grown mass.
    n = 2
    cell = T // n
    pts = []
    for gy in range(-1, n + 1):
        for gx in range(-1, n + 1):
            wx, wy = gx % n, gy % n
            pts.append(((gx + 0.2 + 0.6 * hash2(wx, wy, MEAT_CELLS + 1)) * cell,
                        (gy + 0.2 + 0.6 * hash2(wx, wy, MEAT_CELLS + 2)) * cell, wx, wy))
    for y in range(T):
        for x in range(T):
            d = sorted(((x - px) ** 2 + (y - py) ** 2, gx, gy, py) for px, py, gx, gy in pts)
            d1, d2 = math.sqrt(d[0][0]), math.sqrt(d[1][0])
            gx, gy, py = d[0][1], d[0][2], d[0][3]
            edge = d2 - d1
            shade = 2  # one flat body; the lit rims and seams give the form
            if edge < 1.0 * D:
                col = "ember-1" if hash2(gx + gy, 0, MEAT_CELLS + 4) > 0.55 else f"{ramp}-1"
            elif edge < 2.0 * D and y < py:
                col = f"{ramp}-{shade + 1}"   # the lit upper rim of the cell
            else:
                col = f"{ramp}-{shade}"
            if d1 < 1.0 * D and hash2(gx, gy, seed + 6) > 0.95:
                col = "sky-6"
            img.putpixel((ox + x, oy + y), c(col))


def paint_spring(img, ox, oy, seed, ramp):
    """The Sunken Spring: the dwarves' aqueduct masonry, dressed travertine
    ashlar laid in a broken bond, the spring's blue-green mineral bleeding down
    from the joints.

    Ashlar, not strata (design bible 12.39, pass 548). The older painter laid two
    wavy strata per tile at the same heights in every tile, the layers alternating
    in value, so a pillar read as continuous horizontal stripes: "striped
    wallpaper" (independent grade, pass 545). Now:

    - two courses per tile (``SPRING_COURSE``, 8 world px), so the courses meet
      the tiles above and below;
    - one or two head joints per course (``spring_joints``), at an x keyed to the
      seed and the course, so across the scattered variants the blocks run 6 to
      24 world px long and no joint lines up down a pillar;
    - every block is one body value with a lit top, a lit left edge and a shadow
      before the next joint (light from the upper left), so the wall has depth
      without a second body value to band;
    - travertine pores: a short horizontal void in some courses;
    - mineral drips: a run of the spring's stain hangs down from a joint here and
      there, the only vertical marks besides the joints.

    Everything is a run at least one world pixel thick, so the fill stays calm
    (12.28). The tile wraps on itself sideways: its joints are placed modulo the
    tile width and
    every block carries the same body value."""
    ch = SPRING_COURSE * D
    body, lit, shade, joint = f"{ramp}-4", f"{ramp}-5", f"{ramp}-3", f"{ramp}-1"
    for course in range(T // ch):
        y0 = course * ch
        joints = spring_joints(seed, course)
        for ly in range(ch):
            for x in range(T):
                lx = min((x - j) % T for j in joints)          # 0 at a joint
                rx = min((j - x - 1) % T for j in joints)      # 0 just before one
                if ly >= ch - D or lx < D:
                    col = joint                               # bed and head joints
                elif ly < D or lx < 2 * D:
                    col = lit                                 # lit top and left
                elif rx < D or ly >= ch - 2 * D:
                    col = shade                               # shadow before a joint
                else:
                    col = body
                img.putpixel((ox + x, oy + y0 + ly), c(col))
        j = joints[0]
        # A travertine pore: a long horizontal void inside a block.
        if hash2(seed, course, 52) > 0.4:
            plen = (2 + int(hash2(seed, course, 53) * 3)) * D
            py = y0 + (3 + int(hash2(seed, course, 54) * 2)) * D
            px0 = j + 3 * D + int(hash2(seed, course, 55) * 4) * D
            if all((jj - px0) % T >= plen + 2 * D for jj in joints):
                for x in range(px0, px0 + plen):
                    for dy in range(D):
                        img.putpixel((ox + x % T, oy + py + dy), c(shade))
        # A mineral drip hanging from the bed joint above this course.
        if hash2(seed, course, 56) > 0.7:
            dx = j + 4 * D + int(hash2(seed, course, 57) * (T - 9 * D)) // D * D
            dlen = (2 + int(hash2(seed, course, 58) * 4)) * D
            for y in range(y0, min(y0 + dlen, y0 + ch - D)):
                for k in range(D):
                    img.putpixel((ox + (dx + k) % T, oy + y), c("sky-3" if y < y0 + D else "moss-3"))


SPRING_COURSE = 8


def spring_joints(seed, course):
    """The head joints of one course of ``paint_spring``, in render px: one at a
    seeded x 4 to 12 world px in, and in about a third of courses a second one,
    also 4 to 12 in and at least 6 from the first, so blocks run 6 to 24 world px
    long across the scattered variants and no sliver forms at a tile seam (the
    nearest two joints across a seam are 8 world px apart)."""
    j = 4 + int(hash2(seed, course, 51) * 9)               # 4..12 world px
    joints = [j * D]
    pair = [v for v in range(4, 13) if abs(v - j) >= 6]
    if pair and hash2(seed, course, 59) > 0.66:
        joints.append(pair[int(hash2(seed, course, 60) * len(pair))] * D)
    return joints


def crystal_vein(img, ox, oy, seed):
    """Vorrhallow: a vein of stillglass, a jagged run of shards up through the
    joints. Only on tiles with an open face, so the solid fill doesn't repeat it."""
    if hash2(seed, 3, 41) <= 0.6:
        return
    x, y = int(hash2(seed, 1, 42) * (T - 10)) + 5, T - 2
    for step in range(int(T * 0.6)):
        for k in range(-1, 2):
            if 0 <= x + k < T and 0 <= y < T:
                img.putpixel((ox + x + k, oy + y), c("crystal-4" if k else "crystal-6"))
        y -= 1
        x += 1 if hash2(seed, step, 43) > 0.65 else (-1 if hash2(seed, step, 44) > 0.65 else 0)
        x = max(1, min(T - 2, x))


WOOD_STRANDS = 5


def paint_wood(img, ox, oy, seed, ramp, lo=1):
    """Living wood: broad vertical strands of two values, long grain lines running
    down them, a long highlight here and there, and the odd knot.

    Calm fill (design bible 12.28, pass 534): every mark is long. A strand is 4 to
    9 render pixels wide and one flat value; a grain line or a highlight runs
    6 to 20 pixels down; there are no single-pixel flecks. The older face mixed a
    fine sine grain, a 6-pixel patch grid and random flecks, and read as "static-
    like dirt" in the Heartwood and the Haar (independent grade, pass 529). The
    strands still give the face three values with none swamping it (pass 520)."""
    # Strands: walk across the tile in runs of 4..9 columns, alternating value.
    # The layout is the same in every tile (WOOD_STRANDS, not ``seed``), so a
    # strand runs on unbroken from one tile to the one below it; the seed varies
    # only the grain lines, highlights and knots laid over it. ``lo`` is the
    # darker strand's step on the ramp (the High Boughs' sunlit wood sits at 3).
    strand = []
    k = 0
    while len(strand) < T:
        w = 4 + int(hash2(WOOD_STRANDS, len(strand), 18) * 6)
        strand += [(k % 2, len(strand))] * w
        k += 1
    for x in range(T):
        val, start = strand[x]
        base = lo + 1 if val else lo
        edge = x == start and x > 0              # a dark seam between strands
        for y in range(T):
            col = base
            if edge:
                col = base - 1
            img.putpixel((ox + x, oy + y), c(f"{ramp}-{col}"))
    # Long grain lines a shade darker, and the odd long highlight a shade lighter.
    for i in range(6):
        gx = int(hash2(seed, i, 19) * T)
        y0 = int(hash2(seed, i, 20) * T)
        length = 6 * D + int(hash2(seed, i, 21) * 7 * D)
        lift = hash2(seed, i, 22) > 0.6
        for y in range(y0, min(T, y0 + length)):
            nm = img.getpixel((ox + gx, oy + y))
            here = lo + 1 if nm[:3] == c(f"{ramp}-{lo + 1}")[:3] else lo
            col = min(here + 1, lo + 2) if lift else max(here - 1, lo - 1)
            img.putpixel((ox + gx, oy + y), c(f"{ramp}-{col}"))
    if hash2(seed, 7, 3) > 0.92:  # rare: the few interior tiles repeat a lot
        # A knot: a dark eye in a lighter ring of grain.
        kx, ky = 8 + int(hash2(seed, 1, 5) * 14), 8 + int(hash2(seed, 2, 5) * 14)
        for dy in range(-3, 4):
            for dx in range(-2, 3):
                r = (dx / 2.5) ** 2 + (dy / 3.5) ** 2
                if r <= 1.0:
                    col = f"{ramp}-{lo - 1}" if r < 0.35 else (f"{ramp}-{lo + 2}" if dx < 0 or dy < 0 else f"{ramp}-{lo}")
                    img.putpixel((ox + kx + dx, oy + ky + dy), c(col))


def paint_limb(img, ox, oy, seed, ramp):
    """A drowned limb of the Tree: pale, fog-bleached grain like old bone, wet dark
    streaks running down it, and patches of grey-green lichen."""
    paint_wood(img, ox, oy, seed, ramp)
    for x in range(T):
        if hash2(x // 2, 9, seed) > 0.95:
            # A wet streak, darker where the water gathers at its foot.
            y0 = int(hash2(x, 10, seed) * T * 0.5)
            for y in range(y0, min(T, y0 + 6 * D + int(hash2(x, 11, seed) * 8 * D))):
                img.putpixel((ox + x, oy + y), c(f"{ramp}-1"))
    for k in range(3):
        if hash2(seed, k, 12) > 0.55:
            cx, cy = int(hash2(seed, k, 13) * (T - 6)) + 3, int(hash2(seed, k, 14) * (T - 6)) + 3
            for dy in range(-2, 3):
                for dx in range(-3, 4):
                    if abs(dx) + abs(dy) <= 3:
                        img.putpixel((ox + cx + dx, oy + cy + dy), c("leaf-1" if dy > 0 else "leaf-2"))


def paint_bough(img, ox, oy, seed, ramp):
    """A sunlit bough high in the canopy: The Heartwood's strands two shades
    lighter, and the odd sprig of young leaves.

    It shares paint_wood's calm strands (design bible 12.28 and 12.45). The older
    face drew a sine grain down every column and a dark line every 6 world
    pixels, and read as "striped dirt" (independent grade, pass 550)."""
    paint_wood(img, ox, oy, seed, ramp, lo=3)
    for k in range(2):
        if hash2(seed, k, 21) > 0.6:
            # A sprig: a short stem and two bright leaves.
            cx, cy = int(hash2(seed, k, 22) * (T - 8)) + 4, int(hash2(seed, k, 23) * (T - 8)) + 4
            for dy in range(4):
                img.putpixel((ox + cx, oy + cy + dy), c("leaf-3"))
            for dx, dy in [(-1, 0), (-2, 0), (-2, -1), (1, 1), (2, 1), (2, 0)]:
                img.putpixel((ox + cx + dx, oy + cy + dy), c("leaf-5" if dy < 1 else "leaf-4"))


def cap_moss(img, ox, oy, seed, x0, x1, light="leaf", glow=None, top=5, sculpt=False):
    """A ragged cap of moss over the top edge: blades of uneven height whose
    tips catch the light, a body that deepens shade by shade into a dark root
    line where it meets the ground, and a per-tile value shift so a run of
    ground tiles never paints one flat bright band.

    ``sculpt`` (pass 520, the procedural flat-tile zones heartwood and haar):
    carves a dip of a world pixel between tufts so a run of ledge tops reads as
    an uneven mossy crown rather than one razor-straight shelf, and runs the
    upper fringe a shade deeper so the bright grass trim reads as a shaded lip
    closer to the dressed-stone zones (the pass-515 "flat cartoon tile-grass
    with straight-shelf platform tops" zone-cohesion defect)."""
    def shade(k):
        return c(f"{light}-{max(0, top - k)}")
    # A per-tile value shift (lush / normal / sparse patches) breaks the uniform
    # stripe that read as a single bright fringe across a whole floor: about half
    # the tiles sit a shade deeper and a fifth two shades deeper.
    t = hash2(seed, 0, 44)
    tilt = 2 if t > 0.80 else 1 if t > 0.45 else 0
    for x in range(x0, x1):
        depth = 6 + (2 if hash2(x // 2, 0, seed) > 0.55 else 0) + (1 if hash2(x, 5, seed) > 0.85 else 0)
        blade = 1 if hash2(x, 6, seed) > 0.7 else 0
        # Only taller, lit blades catch the brightest shade on their very tip.
        tip_lit = blade and hash2(x, 8, seed) > 0.5
        col_jit = 1 if hash2(x, 4, seed) > 0.78 else 0  # the odd deeper blade
        # A sculpted crown dips one world pixel between tufts, in clumps of a few
        # columns; tall blades keep their full height and stand proud of the dips.
        # A muted upper fringe pulls the neon grass toward a dressed, shaded lip.
        crown = 1 if (sculpt and not blade and hash2(x // 3, 2, seed) > 0.5) else 0
        mute = 1 if sculpt else 0
        for y in range(depth):
            if y < crown:
                img.putpixel((ox + x, oy + y), CLEAR)  # carve the dip in the silhouette
                continue
            if y == 0 and blade == 0 and hash2(x, 7, seed) > 0.6:
                continue  # a ragged top
            if y == 0 and tip_lit:
                k = 0               # a lit tip, the only truly bright pixels
            elif y <= 1:
                k = 1 + mute        # upper blade
            elif y < depth - 3:
                k = (2 if (x + y) % 4 else 1) + mute   # mid body, mostly a shade down
            elif y < depth - 1:
                k = 3               # lower body, in shadow
            else:
                k = 4               # a dark root line into the soil
            img.putpixel((ox + x, oy + y), shade(k + tilt + col_jit))
        if glow and hash2(x // 2, 3, seed) > 0.88:
            img.putpixel((ox + x, oy + depth), c(glow))
            if x % 2 == 0:
                img.putpixel((ox + x, oy + depth + 1), c(glow, 160))


def cap_stone(img, ox, oy, seed, x0, x1, ramp="stone"):
    """A dressed stone lip: bright rim, a mid band, then a shadow line, a few moss tufts."""
    for x in range(x0, x1):
        for y, col in enumerate([f"{ramp}-6", f"{ramp}-6", f"{ramp}-5", f"{ramp}-4", f"{ramp}-2", f"{ramp}-1"]):
            img.putpixel((ox + x, oy + y), c(col))
        if hash2(x // 3, 9, seed) > 0.8:
            img.putpixel((ox + x, oy), c("leaf-5" if x % 2 else "leaf-4"))
            img.putpixel((ox + x, oy + 1), c("leaf-4"))
            img.putpixel((ox + x, oy + 2), c("leaf-3"))


def paint_plates(img, ox, oy, seed, ramp):
    """Dwarven iron: square plates of 8x8 world pixels, bevelled and lit from the
    top left, a rivet at each corner, and rust bleeding down from the odd rivet.
    The plates share one body value; the odd one is worn a shade darker
    (WORN_BLOCK, design bible 12.45)."""
    pw = 8 * D
    for y in range(T):
        for x in range(T):
            px, py = x // pw, y // pw
            lx, ly = x % pw, y % pw
            shade = 2 if hash2(px + ox // T * 2, py + oy // T * 2, seed) > WORN_BLOCK else 3
            if lx == 0 or ly == 0:
                col = f"{ramp}-1"
            elif lx == 1 or ly == 1:
                col = f"{ramp}-{shade + 2}"
            elif lx == pw - 1 or ly == pw - 1:
                col = f"{ramp}-{shade - 1}"
            else:
                col = f"{ramp}-{shade}"
                # Brushed grain across the plate.
                if (y * 7 + x // 5) % 13 == 0:
                    col = f"{ramp}-{shade + 1}"
                elif hash2(x, y, seed + 2) > 0.96:
                    col = f"{ramp}-{shade - 1}"
            img.putpixel((ox + x, oy + y), c(col))
    for py in range(T // pw):
        for px in range(T // pw):
            for rx, ry in [(3, 3), (pw - 4, 3), (3, pw - 4), (pw - 4, pw - 4)]:
                x, y = px * pw + rx, py * pw + ry
                img.putpixel((ox + x, oy + y), c(f"{ramp}-6"))
                img.putpixel((ox + x + 1, oy + y + 1), c(f"{ramp}-1"))
                if hash2(x, y, seed + 5) > 0.82:
                    # A rust streak running down from the rivet.
                    for k in range(2, 2 + int(hash2(x, y, seed + 6) * 9)):
                        if y + k < T and (x, y + k) != (x, py * pw + pw - 1):
                            img.putpixel((ox + x, oy + y + k), c("bark-2" if k % 3 else "bark-3"))


def cap_girder(img, ox, oy, seed, x0, x1, ramp="stone"):
    """An iron girder along the top: a lit rim, a riveted web, a shadow, and rust."""
    rows = [f"{ramp}-6", f"{ramp}-5", f"{ramp}-4", f"{ramp}-3", f"{ramp}-3", f"{ramp}-2", "night-0", f"{ramp}-1"]
    for x in range(x0, x1):
        for y, col in enumerate(rows):
            if 2 <= y <= 4 and hash2(x, y, seed + 8) > 0.9:
                col = "bark-3"
            img.putpixel((ox + x, oy + y), c(col))
        if x % 8 == 4:
            img.putpixel((ox + x, oy + 3), c(f"{ramp}-7"))
            img.putpixel((ox + x + 1 if x + 1 < x1 else ox + x, oy + 4), c(f"{ramp}-1"))


ZONES = {
    "gym": {"painter": paint_bricks, "ramp": "stone", "cap": "moss", "light": "leaf", "glow": None,
            "under": "stone-1", "outline": "night-0"},
    "hearthroot": {"painter": paint_bricks, "ramp": "stone", "cap": "stone", "light": "leaf", "glow": None,
              "under": "stone-1", "outline": "night-0"},
    "heartwood": {"painter": paint_wood, "ramp": "bark", "cap": "moss", "light": "leaf", "glow": "sky-6", "cap_top": 4,
              "under": "bark-1", "outline": "night-0", "cap_sculpt": True},
    "tower": {"painter": paint_plates, "ramp": "stone", "cap": "girder", "light": "leaf", "glow": None,
              "under": "night-1", "outline": "night-0"},
    # haar and sunken play-field tiles warm from the cool "stone" lavender to the
    # warm "umber" ramp (pass 524). The independent grade (pass 505) read these two
    # murkiest zones as a low-contrast grey-green / grey-teal where the standable
    # geometry merged into the cool backdrop and mist. Pass 513 receded the mist;
    # this separates the play field by HUE: both painters already describe a warm
    # material (paint_limb "old bone", paint_spring "pale limestone"), so the warm
    # umber body reads as lit bone / travertine against each zone's cool backdrop,
    # while the mist, backdrop masonry, cool night outline/shadow (night-0/night-1)
    # and the moss/sky caps stay cool — a temperature split the eye reads instantly.
    "haar": {"painter": paint_limb, "ramp": "umber", "cap": "moss", "light": "leaf", "glow": "gold-5", "cap_top": 3,
             "under": "night-1", "outline": "night-0", "cap_sculpt": True},
    "boughs": {"painter": paint_bough, "ramp": "bark", "cap": "moss", "light": "leaf", "glow": None, "cap_top": 6,
                 "under": "bark-2", "outline": "night-0"},
    "vorrhallow": {"painter": paint_drowned, "ramp": "stone", "cap": "moss", "light": "sky", "glow": "crystal-6", "cap_top": 4,
                 "under": "night-1", "outline": "night-0"},
    "evercrown": {"painter": paint_meteor, "ramp": "night", "cap": "moss", "light": "crystal", "glow": "sky-6", "cap_top": 4,
              "under": "night-0", "outline": "night-0"},
    "sunken": {"painter": paint_spring, "ramp": "umber", "cap": "moss", "light": "sky", "glow": "sky-6", "cap_top": 3,
               "under": "night-1", "outline": "night-0"},  # warm limestone, pass 524 (see haar)
    # The Inner Rings' inner rings (pass 113): pale grey blocks with no moss and
    # no warmth, a place made of nothing but footholds.
    "trials": {"painter": paint_bricks, "ramp": "stone", "cap": "stone", "light": "stone", "glow": None,
               "under": "night-1", "outline": "night-0"},
    "spires": {"painter": paint_shrine, "ramp": "stone", "cap": "moss", "light": "leaf", "glow": "gold-6", "cap_top": 5,
                 "under": "night-1", "outline": "night-0"},
}


def paint_tile(img, ox, oy, mask, zone, seed):
    global BRICK_MOSS
    z = ZONES[zone]
    BRICK_MOSS = z["cap"] == "moss"  # the Inner Rings grow nothing (pass 113)
    z["painter"](img, ox, oy, seed, z["ramp"])
    if zone == "vorrhallow" and (mask & (N | E | S | W)) != (N | E | S | W):
        crystal_vein(img, ox, oy, seed)
    ramp = z["ramp"]
    out = c(z["outline"])
    # Sides: a dark outline one world pixel thick, then a soft shade.
    if not mask & W:
        for y in range(T):
            for k in range(D):
                img.putpixel((ox + k, oy + y), out)
            img.putpixel((ox + D, oy + y), c(f"{ramp}-1"))
            if hash2(0, y // 3, seed) > 0.5:
                img.putpixel((ox + D + 1, oy + y), c(f"{ramp}-1"))
    if not mask & E:
        for y in range(T):
            for k in range(D):
                img.putpixel((ox + T - 1 - k, oy + y), out)
            img.putpixel((ox + T - 1 - D, oy + y), c(f"{ramp}-1"))
            if hash2(1, y // 3, seed) > 0.5:
                img.putpixel((ox + T - 2 - D, oy + y), c(f"{ramp}-1"))
    # Underside: outline, a dark lip, and the odd hanging root tip.
    if not mask & S:
        for x in range(T):
            for k in range(D):
                img.putpixel((ox + x, oy + T - 1 - k), out)
            img.putpixel((ox + x, oy + T - 1 - D), c(z["under"]))
            img.putpixel((ox + x, oy + T - 2 - D), c(z["under"]))
        for x in range(2, T - 2):
            if hash2(x, 11, seed) > 0.93:
                img.putpixel((ox + x, oy + T - 1), c(z["under"]))
    # Top: the zone's cap.
    if not mask & N:
        x0 = 0 if mask & W else D
        x1 = T if mask & E else T - D
        if z["cap"] == "moss":
            cap_moss(img, ox, oy, seed, x0, x1, z["light"], z["glow"], z.get("cap_top", 5),
                     z.get("cap_sculpt", False))
        elif z["cap"] == "girder":
            cap_girder(img, ox, oy, seed, x0, x1, ramp)
        else:
            cap_stone(img, ox, oy, seed, x0, x1, ramp)
        if zone in COURSE_ZONES:
            string_course(img, ox, oy, seed, x0, x1, ramp)
    elif zone in COURSE_ZONES:
        footing(img, ox, oy, seed, mask, ramp)
    # Inner corners: a dark notch where two solid sides meet an open diagonal.
    for bit, a, b, px, py in [(NE, N, E, T - D, 0), (SE, S, E, T - D, T - D), (SW, S, W, 0, T - D), (NW, N, W, 0, 0)]:
        if mask & a and mask & b and not mask & bit:
            for dy in range(D):
                for dx in range(D):
                    img.putpixel((ox + px + dx, oy + py + dy), out)
            nx = px - 1 if px else px + D
            ny = py - 1 if py else py + D
            for k in range(D):
                img.putpixel((ox + nx, oy + py + k), c(f"{ramp}-1"))
                img.putpixel((ox + px + k, oy + ny), c(f"{ramp}-1"))
    # Outer corners: round them off (a 2x2 notch and its diagonal neighbours).
    for a, b, px, py, sx, sy in [(N, W, 0, 0, 1, 1), (N, E, T - 1, 0, -1, 1), (S, W, 0, T - 1, 1, -1), (S, E, T - 1, T - 1, -1, -1)]:
        if not mask & a and not mask & b:
            for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (0, 2)]:
                img.putpixel((ox + px + sx * dx, oy + py + sy * dy), CLEAR)
            img.putpixel((ox + px + sx * 2, oy + py + sy * 1), out)
            img.putpixel((ox + px + sx * 1, oy + py + sy * 2), out)
            img.putpixel((ox + px + sx * 3, oy + py), out)
            img.putpixel((ox + px, oy + py + sy * 3), out)


def darken(img, ox, oy, steps):
    """Shifts every pixel of a tile `steps` shades down its palette ramp."""
    names = {v[:3]: k for k, v in PAL.items()}
    for y in range(T):
        for x in range(T):
            px = img.getpixel((ox + x, oy + y))
            name = names.get(px[:3])
            if name is None or px[3] == 0:
                continue
            ramp, i = name.rsplit("-", 1)
            j = int(i) - steps
            img.putpixel((ox + x, oy + y), c("night-0") if j < 0 else c(f"{ramp}-{j}"))


# Per-zone one-way plank material and fastener accent (design bible 12.20, pass
# 521). The plank used one hardcoded `bark` board with a stubby bracket in every
# zone, so the independent grade read it as a copy-pasted prototyping block that
# floats with nothing holding it up. Each zone now carries its own board tone,
# fastener colour and support tone, so a run of ledges no longer looks identical
# from zone to zone, and the stub becomes a drawn trestle so the ledge reads as
# built. `metal` gives the board a brighter catch-light (the iron Tower). The
# families: warm wood (gym, heartwood, boughs), grey driftwood (haar, sunken),
# pale stone (vorrhallow, trials, tower), dry timber (spires), and a grown
# shelf (evercrown, 12.34: paint_grown_shelf). hearthroot's plank is PixelLab art (pixellab_tileset.atlas) and
# does not use this painter.
PLANK = {
    "gym": {"wood": "bark", "nail": "stone-5", "strut": "bark"},
    "heartwood": {"wood": "bark", "nail": "gold-4", "strut": "bark"},
    "boughs": {"wood": "bark", "nail": "leaf-5", "strut": "bark"},
    "haar": {"wood": "umber", "nail": "ash-4", "strut": "umber"},
    "sunken": {"wood": "umber", "nail": "sky-5", "strut": "umber"},
    "vorrhallow": {"wood": "ash", "nail": "crystal-5", "strut": "ash"},
    "trials": {"wood": "ash", "nail": "ash-5", "strut": "ash"},
    "spires": {"wood": "ochre", "nail": "gold-5", "strut": "umber"},
    "tower": {"wood": "ash", "nail": "sky-5", "strut": "ash", "metal": True},
    "evercrown": {"wood": "night", "nail": "sky-6", "strut": "night", "grown": True},
    "hearthroot": {"wood": "bark", "nail": "gold-4", "strut": "bark"},
}


def paint_one_way(img, ox, oy, zone):
    """A plank on a trestle (design bible 12.20): 6 world pixels of board whose
    material and fastener accent are set per zone (PLANK), carried by a drawn
    trestle below so the ledge reads as built, not floated. hearthroot's plank is
    PixelLab art and does not use this."""
    spec = PLANK.get(zone, PLANK["gym"])
    if spec.get("grown"):
        paint_grown_shelf(img, ox, oy, spec)
        return
    wood, nail, strut = spec["wood"], spec["nail"], spec["strut"]
    metal = spec.get("metal", False)
    period = 8 * D
    for x in range(T):
        for y in range(6 * D):
            if y < 2:
                col = f"{wood}-6" if metal else f"{wood}-5"
            elif y < 3:
                col = f"{wood}-4"
            elif y < 8:
                col = f"{wood}-3" if (x + y * 3) % 11 else f"{wood}-2"
            elif y < 10:
                col = f"{wood}-2"
            else:
                col = "night-0"
            # A dark groove every `period` so a run of boards reads as laid
            # planks, not one slab.
            if x % period == 0 and 2 <= y <= 9:
                col = f"{wood}-1"
            # Fastener heads flanking each groove, in the zone's accent.
            if x % period in (3, 12) and y == 4:
                col = nail
            img.putpixel((ox + x, oy + y), c(col))
    # A trestle under each board groove: a short post with two splayed legs, so
    # the ledge reads as carried rather than floating. Kept within the lower half
    # of the tile so it never implies a floor below.
    leg = 4 * D
    for gx in range(0, T, period):
        # The post, two pixels wide, straight down from the groove.
        for x in (gx, gx + 1):
            xx = x % T
            for y in range(6 * D, 6 * D + leg):
                img.putpixel((ox + xx, oy + y), c(f"{strut}-2"))
        # Two legs splaying out from the post foot, a shade darker for depth.
        foot = 6 * D + leg
        for k in range(leg):
            y = foot + k - 1
            for sgn in (-1, 1):
                xx = (gx + (1 if sgn > 0 else 0) + sgn * k) % T
                shade = "night-0" if k >= leg - 1 else f"{strut}-1"
                img.putpixel((ox + xx, oy + y), c(shade))


# The Evercrown's shelf (design bible 12.34, pass 542). Its plank was a stillglass
# board in the hot crystal ramp, hung on crystal chains: the independent grade (pass
# 540) read it as a flat single-fill magenta prop. It is now grown from the zone's
# own matter: a row of rounded cell segments on the night ramp, lit from the upper
# left, with sinew (ember-1) in the seams, a cyan pore in some segments, a thin
# crystal glaze only on the lit rim, a night-0 outline under the shadow side, and
# short tendrils hanging from its underside. Painted in whole world pixels.
SHELF_SEGS = (7, 9)     # world px per segment; they sum to the tile so runs tile seamlessly
SHELF_SEED = 542
SHELF_LIGHT = (-0.55, -0.6, 0.58)   # from the upper left, toward the viewer


def _shelf_px(img, ox, oy, wx, wy, col):
    for dy in range(D):
        for dx in range(D):
            img.putpixel((ox + wx * D + dx, oy + wy * D + dy), c(col))


def shelf_cells():
    """{(wx, wy): name} for one tile of the grown shelf, in world pixels."""
    ramp, pore = PLANK["evercrown"]["wood"], PLANK["evercrown"]["nail"]
    lx, ly, lz = SHELF_LIGHT
    ll = math.sqrt(lx * lx + ly * ly + lz * lz)
    out = {}
    body = set()
    W = T // D
    x0 = 0
    for seg, w in enumerate(SHELF_SEGS):
        # one lobe per segment, hanging under a continuous top: the shelf reads as
        # one grown ledge with a lumpy underside, not a string of beads
        cx, cy, rx, ry = x0 + (w - 1) / 2, 1.0, w / 2 + 0.4, 4.6
        for wx in range(x0, x0 + w):
            for wy in range(6):
                nx, ny = (wx - cx) / rx, (wy - cy) / ry
                if wy >= 2 and nx * nx + ny * ny > 1.0:
                    continue
                if wy == 0:
                    col = f"{ramp}-5"
                elif wy == 1:
                    col = f"{ramp}-4"
                else:
                    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                    lit = (nx * lx + max(ny, 0.0) * ly + nz * lz) / ll
                    col = f"{ramp}-{4 if lit > 0.7 else 3 if lit > 0.35 else 2}"
                out[(wx, wy)] = col
                body.add((wx, wy))
        # a short glaze of stillglass where the light first catches the lobe
        gx = x0 + max(1, w // 3)
        out[(gx, 0)] = "crystal-3"
        if w > 7:
            out[(gx + 1, 0)] = "crystal-3"
        # a cyan pore in the wide lobe only, so a run doesn't dot a regular row
        if w > 7:
            px = x0 + w // 2 + 1
            out[(px, 2)] = pore
            out[(px, 3)] = "sky-4"
        x0 += w
    # sinew in the notches between the lobes
    for wx in range(W):
        for wy in range(2, 5):
            if (wx, wy) not in body and (((wx - 1) % W, wy) in body or ((wx + 1) % W, wy) in body):
                out[(wx, wy)] = "ember-1"
    # selective outline: under the body and down its shaded right side only
    for (wx, wy) in list(body):
        below = (wx, wy + 1) in body
        right = ((wx + 1) % W, wy) in body
        if not below or (not right and wy >= 2):
            out[(wx, wy)] = "night-0"
    # one tendril per tile hangs from the wider lobe: a fleshy root that pales
    # toward its tip, with a bead of cyan sap on the longer ones
    x0 = SHELF_SEGS[0]
    w = SHELF_SEGS[1]
    wx = x0 + w // 2 - 1 + int(hash2(1, 0, SHELF_SEED + 1) * 3)
    top = max(y for (bx, y) in body if bx == wx) + 1
    n = 3 + int(hash2(1, 0, SHELF_SEED + 2) * 3)
    for i in range(n):
        out[(wx, top + i)] = f"{ramp}-2" if i < n - 1 else "crystal-2"
    out[(wx, top + n)] = "sky-4"
    # and a stub on the narrow lobe
    sx = 2
    stop = max(y for (bx, y) in body if bx == sx) + 1
    out[(sx, stop)] = f"{ramp}-2"
    out[(sx, stop + 1)] = "crystal-2"
    return out


def paint_grown_shelf(img, ox, oy, spec):
    for (wx, wy), col in shelf_cells().items():
        _shelf_px(img, ox, oy, wx, wy, col)


def paint_amber(img, ox, oy):
    for y in range(T):
        for x in range(T):
            col = "gold-3"
            if y < 2:
                col = "gold-5"
            elif y < 4:
                col = "gold-4"
            elif hash2(x, y, 41) > 0.95:
                col = "gold-2"
            elif (x + y * 2) % 23 == 0:
                col = "gold-4"
            img.putpixel((ox + x, oy + y), c(col))
    # Bubbles trapped in the amber, each with a highlight.
    for bx, by in [(8, 10), (22, 18), (14, 25)]:
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
            img.putpixel((ox + bx + dx, oy + by + dy), c("gold-5"))
        img.putpixel((ox + bx, oy + by), c("gold-7"))


def paint_slope(img, ox, oy, zone, rising_east, seed):
    """A 45-degree slope (design bible 6.1): the zone's capped ground tile,
    sheared down column by column so its cap runs along the diagonal. Solid
    below the diagonal, clear above; it meets ground on its high side and below."""
    tmp = Image.new("RGBA", (T, T), CLEAR)
    paint_tile(tmp, 0, 0, E | S | W | SE | SW, zone, seed)
    for x in range(T):
        drop = T - 1 - x if rising_east else x
        for y in range(T):
            sy = y - drop
            img.putpixel((ox + x, oy + y), tmp.getpixel((x, sy)) if sy >= 0 else CLEAR)
    # A dark outline one world pixel thick just above the cap, so the diagonal
    # reads against the sky the way a flat top's moss does.
    out = c(ZONES[zone]["outline"])
    for x in range(T):
        drop = T - 1 - x if rising_east else x
        for k in range(1, D):
            if drop - k >= 0:
                img.putpixel((ox + x, oy + drop - k), out)


# Zones built from Sean's PixelLab work (design bible 13.6) instead of painted here:
# a side-scroller tileset for the edges, a seamless fill texture for wall interiors
# (copied to assets/tiles/<zone>_fill.png for GroundFill) and a one-way ledge piece.
PIXELLAB_SETS = {
    "hearthroot": {
        "set": "hearthroot/tilesets/town_ground",
        "fill": ROOT / "art/pixellab/hearthroot/textures/wall1/tile_4.png",
        "ledge": ROOT / "art/pixellab/hearthroot/ledge/mid.png",
    },
}


def build_tileset(zone):
    if zone in PIXELLAB_SETS:
        import shutil
        import pixellab_tileset
        cfg = PIXELLAB_SETS[zone]
        TILES.mkdir(parents=True, exist_ok=True)
        pixellab_tileset.atlas(cfg["set"], cfg["fill"], TILES / f"{zone}.png", cfg["ledge"])
        shutil.copy(cfg["fill"], TILES / f"{zone}_fill.png")
        return
    masks = blob_masks()
    assert len(masks) == 47
    img = Image.new("RGBA", (T * COLS, T * 8), CLEAR)
    for i, m in enumerate(masks):
        paint_tile(img, (i % COLS) * T, (i // COLS) * T, m, zone, 11 + i)
    paint_one_way(img, 0, 6 * T, zone)
    paint_amber(img, T, 6 * T)
    # Wall interiors away from open air: one shade darker two tiles in, two
    # shades from three tiles in, so rooms read as space rather than texture.
    for k in range(4):
        paint_tile(img, (2 + k) * T, 6 * T, 255, zone, 101 + k)
        darken(img, (2 + k) * T, 6 * T, 1 if k < 2 else 2)
    paint_slope(img, 6 * T, 6 * T, zone, True, 121)
    paint_slope(img, 7 * T, 6 * T, zone, False, 122)
    # Row 7: masonry variants so solid fields stop reading as a 32 px grid
    # (bible 12.8). Each is a full-solid tile painted with a fresh seed, so its
    # brick courses and pits land differently; the factory scatters them by cell
    # position. Cols 0-2 are surface-bright variants (match the FULL blob tile);
    # cols 3-4 are MID (one shade down) and 5-6 DEEP (two) so a darkened interior
    # field varies too. The brightness darkening mirrors the row-6 interiors.
    for k in range(3):
        paint_tile(img, k * T, 7 * T, 255, zone, 201 + k)
    for k in range(2):
        paint_tile(img, (3 + k) * T, 7 * T, 255, zone, 211 + k)
        darken(img, (3 + k) * T, 7 * T, 1)
    for k in range(2):
        paint_tile(img, (5 + k) * T, 7 * T, 255, zone, 221 + k)
        darken(img, (5 + k) * T, 7 * T, 2)
    TILES.mkdir(parents=True, exist_ok=True)
    img.save(TILES / f"{zone}.png")


# --- Backgrounds ---------------------------------------------------------------------
def wrap_noise(x, y, seed, period):
    """Smooth value noise that tiles horizontally with `period`."""
    def v(ix, iy):
        return hash2(ix % period, iy, seed)
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * fx
    b = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * fx
    return a + (b - a) * fy


def gradient_ramp(top, bottom, stops=8):
    """A ramp of master-palette colours from `top` to `bottom`, each the nearest
    palette match to an even RGB step between them. Several solid value steps mean
    the gradient dithers only between adjacent, near-identical colours, so the mix
    reads as a soft grain instead of a 50/50 screen of the two far-apart endpoints
    — the moire dot-grid the independent grade flagged (pass 500/501, bible 12.6)."""
    tr, br = c(top)[:3], c(bottom)[:3]
    # Atmosphere, not material: only the saturated ramps (palette.MUTED, pass 506).
    sky = [n for n in PAL if n.split("-")[0] not in palette.MUTED]
    ramp = []
    for s in range(stops):
        t = s / (stops - 1)
        target = tuple(tr[i] + (br[i] - tr[i]) * t for i in range(3))
        name = min(sky, key=lambda n: sum((PAL[n][i] - target[i]) ** 2 for i in range(3)))
        if not ramp or ramp[-1] != name:
            ramp.append(name)
    return ramp


def gradient_pixel(ramp, x, y, h, dither=True):
    """The palette colour name for one pixel of a `ramp` gradient `h` tall. The
    seam between two ramp steps is dithered from value noise (hash2), not a fixed
    ordered grid, so a transition reads as grain and never as a rigid screen door."""
    n = len(ramp)
    if n == 1:
        return ramp[0]
    p = (y / (h - 1)) * (n - 1)
    lo = min(int(p), n - 2)
    frac = p - lo
    thr = hash2(x, y, 9) if dither else 0.5
    return ramp[lo + 1] if frac > thr else ramp[lo]


def gradient(img, top, bottom, dither=True):
    ramp = gradient_ramp(top, bottom) if dither else [top, bottom]
    for y in range(BG_H):
        for x in range(BG_W):
            img.putpixel((x, y), c(gradient_pixel(ramp, x, y, BG_H, dither)))


def put(img, x, y, col):
    """Sets a pixel, wrapping sideways (the layers repeat) and clipping vertically."""
    if 0 <= y < BG_H:
        img.putpixel((int(x) % BG_W, int(y)), col)


def glow_dot(img, x, y, core, rim, r=1):
    """A small light: a bright core with a dimmer rim (atlas pixels)."""
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            d = abs(dx) + abs(dy)
            if d <= r:
                put(img, x + dx, y + dy, c(core))
            elif d == r + 1:
                put(img, x + dx, y + dy, c(rim))


def soft_glow(img, cx, cy, name, r):
    """A soft, dim radial glow: a distant light seen through atmosphere. Alpha
    falls off with distance (squared), so it reads as a haze-blurred point, not a
    hard dot. Wraps sideways (the layers repeat) and clips vertically."""
    over = c(name)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = math.sqrt(dx * dx + dy * dy)
            if d > r:
                continue
            a = int(190 * (1 - d / r) ** 2)
            if a <= 0:
                continue
            y = cy + dy
            if 0 <= y < BG_H:
                x = (cx + dx) % BG_W
                img.putpixel((x, y), blend(img.getpixel((x, y)), over, a))


def far_motes(img, rng, cols, glows=5):
    """Faint distant light over the dark far sky of a far layer (design bible 12.15).
    The independent grade (pass 515) read the dark upper backdrop of tall rooms as
    dead, structureless space. This gives the far sky atmospheric depth: a sparse
    field of dim, zone-tinted motes — dust catching far light — weighted to the
    upper two-thirds, plus a few soft haloed glows (distant lights seen through the
    murk), so the far backdrop reads as receding atmosphere with particles instead
    of one flat dark field.

    Everything is dim and lands only on a dark pixel (the running RGB sum of the
    under-colour stays low), so the atmospheric-perspective shader (12.5) still
    recedes it and it never specks over a bright backdrop feature. The whole field
    lives on the far parallax layer behind the play field, so combat is untouched.
    This dresses the far sky where the far layer draws; it does not fill the empty
    band above the far layer in the very tallest rooms (that would need a
    screen-space sky overlay in front of the play field, left for a watched session).
    """
    dark = 360  # only draw where the far sky is dark (0-765 running RGB sum)
    # Soft distant glows high in the band: far lights seen through the murk, bright
    # enough to read after the atmosphere shader (12.5) fades the far layer halfway
    # toward the dark haze.
    for _ in range(glows):
        x, y = rng.randrange(BG_W), rng.randrange(BG_H // 12, int(BG_H * 0.6))
        if sum(img.getpixel((x, y))[:3]) <= dark:
            soft_glow(img, x, y, rng.choice(cols), rng.choice([6, 8, 11]))
    # Drifting dust motes over the dark sky, weighted toward the top (a power of a
    # uniform sits high) and gated to dark pixels so they fall in the dead band and
    # never over a bright backdrop feature. A quarter are haloed so a few catch the
    # eye as nearer specks; the rest are single pixels, at full palette value so
    # they survive the haze.
    for k in range(180):
        x = rng.randrange(BG_W)
        y = int((rng.random() ** 1.5) * BG_H * 0.78)
        base = img.getpixel((x, y))
        if sum(base[:3]) > dark:
            continue
        col = rng.choice(cols)
        if k % 4 == 0:
            glow_dot(img, x, y, col, "night-1", 0)
        else:
            img.putpixel((x, y), c(col))


def heartwood_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "bark-0")
    rng = random.Random(5)
    # Great fibres of the trunk's heartwood, far away, with a streaked grain.
    for i in range(14):
        x0 = rng.randrange(BG_W)
        w = rng.randrange(10, 26) * D
        col = "bark-1" if i % 3 else "night-1"
        for y in range(BG_H):
            sway = int(math.sin(y * 0.01 + i) * 6 * D)
            for dx in range(w):
                if hash2(dx // 2, y // 9, i) > 0.08:
                    put(img, x0 + sway + dx, y, c(col))
            # Grain lines down the fibre.
            for g in range(3, w - 2, 7):
                if hash2(g, y // 40, i + 50) > 0.45:
                    put(img, x0 + sway + g, y, c("night-0" if col == "bark-1" else "bark-0"))
    # Faint glowing spores, a few of them larger and haloed.
    for k in range(240):
        x, y = rng.randrange(BG_W), rng.randrange(BG_H)
        col = rng.choice(["sky-4", "gold-3", "sky-3"])
        if k % 12 == 0:
            glow_dot(img, x, y, col, "sky-1", 0)
        else:
            put(img, x, y, c(col))
    far_motes(img, rng, ["sky-3", "gold-3", "sky-4"], glows=5)
    return img


def heartwood_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(9)
    # Hanging roots from the top, rooted columns from the bottom.
    for i in range(18):
        x0 = rng.randrange(BG_W)
        length = rng.randrange(60, 260) * D
        w = rng.choice([2, 3, 3, 4]) * D
        tip_x = x0
        for y in range(length):
            sway = int(math.sin(y * 0.025 + i * 1.7) * 5 * D)
            taper = max(1, int(w * (1 - y / length) + 0.5))
            for dx in range(taper):
                col = "bark-2" if dx == 0 else ("night-1" if dx == taper - 1 and taper > 2 else "bark-1")
                put(img, x0 + sway + dx, y, c(col))
            tip_x = x0 + sway
            # Thin rootlets curling off the main root.
            if y > 20 and hash2(i, y, 7) > 0.985:
                d = 1 if hash2(i, y, 8) > 0.5 else -1
                for k in range(rng.randrange(10, 26)):
                    put(img, x0 + sway + (taper if d > 0 else -1) + d * k, y + k * k // 14, c("bark-1"))
        # A glowing fungus cap at some root tips.
        if i % 3 == 0:
            for dy in range(4):
                half = 5 - dy
                for dx in range(-half, half + 1):
                    put(img, tip_x + dx, length + 3 - dy, c("sky-5" if dy else "sky-4"))
            put(img, tip_x - 2, length + 1, c("sky-7"))
            put(img, tip_x - 1, length + 1, c("sky-6"))
            for dx in range(-5, 6, 2):
                put(img, tip_x + dx, length + 4, c("sky-2"))
    for i in range(7):
        x0 = rng.randrange(BG_W)
        w = rng.randrange(18, 40) * D
        h = rng.randrange(80, 200) * D
        for y in range(BG_H - h, BG_H):
            k = (y - (BG_H - h)) / h
            ww = int(w * (0.5 + 0.5 * k))
            for dx in range(-ww // 2, ww // 2):
                edge = ww // 2 - abs(dx)
                col = "night-1" if edge <= 4 else "bark-1"
                # Bark ridges running up the column.
                if edge > 4 and (dx + ww) % 9 == 0 and hash2(dx, y // 14, i) > 0.3:
                    col = "night-1"
                if edge == 5 and dx < 0:
                    col = "bark-2"
                put(img, x0 + dx, y, c(col))
    return img


def hearthroot_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "night-1")
    rng = random.Random(3)
    # Distant houses carved into the roots, with lit windows.
    x = 0
    while x < BG_W:
        w = rng.randrange(40, 80) * D
        h = rng.randrange(80, 200) * D
        top = BG_H - 120 * D - h
        cs = masonry_courses(top, BG_H, 300 + (x % 97), 22)
        for yy in range(top, BG_H):
            for xx in range(x, min(x + w, BG_W)):
                col = "stone-1" if (xx - x) < 2 * D else masonry_shade(xx, yy, 3, "night-0", "night-1", "stone-2")
                # Weathered courses of stone: jittered rows, still broken horizontally.
                if (xx - x) > 2 * D and yy in cs and hash2(xx // 12, yy, 3) > 0.4:
                    col = "night-0"
                img.putpixel((xx, yy), c(col))
        # Roofline: one of several silhouettes per house, so a row of distant
        # houses stops reading as the same arch copied across (independent grade,
        # pass 515: "Hearthroot background buildings are the same two silhouettes").
        style = rng.choice(("arch", "gable", "battlement", "stepped", "arch"))
        peak = rng.randrange(10, 22) * D
        for xx in range(x, min(x + w, BG_W)):
            k = (xx - x) / max(w - 1, 1)
            if style == "arch":
                rise = int(math.sin(k * math.pi) * peak)
            elif style == "gable":
                rise = int((1 - abs(2 * k - 1)) * peak)  # a triangular peak
            elif style == "stepped":
                step = int(abs(2 * k - 1) * 4)  # 0 at centre, up to 4 steps out
                rise = max(0, peak - step * (peak // 5 + 1))
            else:  # battlement: a flat parapet with square merlons
                rise = peak // 2 if ((xx - x) // (5 * D)) % 2 == 0 else peak // 2 - 4 * D
                rise = max(0, rise)
            for yy in range(top - rise, top):
                img.putpixel((xx, yy), c("stone-1" if yy - (top - rise) < 2 else "night-1"))
        # A chimney on some houses, a little smoke-dark stack above the roof.
        if rng.random() < 0.4:
            cx = x + rng.randrange(6, max(7, w // D - 6)) * D
            ch = rng.randrange(6, 14) * D
            for yy in range(top - peak - ch, top - peak // 2):
                for xx in range(cx, min(cx + 4 * D, BG_W)):
                    img.putpixel((xx, yy), c("stone-1" if yy < top - peak - ch + 2 else "night-1"))
        wstride = rng.randrange(14, 22) * D
        for wy in range(top + 14 * D, BG_H - 140 * D, 26 * D):
            for wx in range(x + 8 * D, x + w - 12 * D, wstride):
                if rng.random() < 0.22:
                    ww, wh = 6 * D, 9 * D
                    for yy in range(wy, wy + wh):
                        for xx in range(wx, wx + ww):
                            if xx >= BG_W:
                                continue
                            col = "gold-4" if yy < wy + 3 else "gold-3"
                            # A cross of mullions and a dark sill.
                            if xx == wx + ww // 2 or yy == wy + wh // 2:
                                col = "bark-1"
                            if yy == wy + wh - 1:
                                col = "stone-1"
                            img.putpixel((xx, yy), c(col))
                    # Rounded window top.
                    for xx in range(wx + 2, wx + ww - 2):
                        put(img, xx, wy - 1, c("gold-3"))
        x += w + rng.randrange(6, 24) * D
    far_motes(img, rng, ["gold-3", "ember-2", "gold-4"], glows=6)
    return img


def hearthroot_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(4)
    # Great roots arching overhead, and hanging lanterns.
    for i in range(4):
        cx = (i * 160 + rng.randrange(-20, 20)) * D
        for x in range(cx - 120 * D, cx + 120 * D):
            k = (x - (cx - 120 * D)) / (240 * D)
            y0 = int((30 + math.sin(k * math.pi) * -20 + 40) * D)
            for y in range(0, y0):
                col = "night-1"
                if y > 6 and hash2(x // 3, y // 10, i) > 0.93:
                    col = "bark-0"
                put(img, x, y, c(col))
            for y in range(y0, y0 + 3 * D):
                put(img, x, y, c("bark-2" if y == y0 else "bark-1"))
            put(img, x, y0 + 3 * D, c("night-1"))
    for i in range(6):
        x = rng.randrange(BG_W)
        length = rng.randrange(60, 130) * D
        for y in range(40 * D, length):
            put(img, x, y, c("stone-2"))
            put(img, x + 1, y, c("stone-1" if (y // 3) % 2 else "stone-2"))
        # Lantern: a cap, glass panes with a frame, a base.
        for dx in range(-5, 7):
            put(img, x + dx, length, c("stone-2"))
            put(img, x + dx, length + 1, c("stone-3"))
        for dy in range(2, 14):
            for dx in range(-6, 8):
                frame = dx in (-6, 7, 1) or dy in (2, 13)
                col = "stone-2" if frame else ("gold-6" if abs(dx - 0.5) < 3 and 5 < dy < 11 else "gold-5")
                put(img, x + dx, length + dy, c(col))
        for dx in range(-4, 6):
            put(img, x + dx, length + 14, c("stone-2"))
        put(img, x, length + 15, c("stone-2"))
        put(img, x + 1, length + 15, c("stone-2"))
        # A faint ring of lamplight around the lantern.
        for r, alpha in ((18, 120), (24, 70)):
            for k in range(96):
                ang = k / 96 * math.tau
                px = x + int(math.cos(ang) * r)
                py = length + 8 + int(math.sin(ang) * r)
                if k % 2 == 0 and 0 <= py < BG_H and img.getpixel((px % BG_W, py))[3] == 0:
                    put(img, px, py, c("gold-3", alpha))
    return img


def gear(img, cx, cy, r, teeth, col, hub_col, alpha=255):
    """A gear silhouette: a toothed rim, spokes and a hub (atlas pixels)."""
    for y in range(int(cy - r - 6), int(cy + r + 7)):
        for x in range(int(cx - r - 6), int(cx + r + 7)):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            tooth = r + (5 if math.cos(ang * teeth) > 0.3 else 0)
            if d > tooth:
                continue
            inner = r * 0.72
            if d > inner or d < r * 0.22:
                put(img, x, y, c(col, alpha))
            elif min(abs(math.sin(ang * 3)), 1.0) * d < 4:
                put(img, x, y, c(col, alpha))  # spokes
            if d < r * 0.12:
                put(img, x, y, c(hub_col, alpha))


def tower_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "ember-0")
    rng = random.Random(21)
    # The tower's far shafts: tall stone columns with lit slit windows.
    for i in range(6):
        x0 = rng.randrange(BG_W)
        w = rng.randrange(30, 60) * D
        cs = masonry_courses(0, BG_H, 210 + i, 12 * D)
        for y in range(BG_H):
            for dx in range(w):
                col = masonry_shade(x0 + dx, y, 210 + i, "night-0", "night-1", "stone-2")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                elif dx % (16 * D) == 0 and hash2(dx // D, y // (10 * D), i) > 0.45:
                    col = "night-0"  # a worn vertical joint, broken by height
                put(img, x0 + dx, y, c(col))
        for wy in range(rng.randrange(20, 60) * D, BG_H, rng.randrange(60, 110) * D):
            wx = x0 + w // 2 - 2 * D
            for yy in range(wy, wy + 8 * D):
                for xx in range(wx, wx + 3 * D):
                    put(img, xx, yy, c("gold-3" if yy > wy + 2 else "gold-4"))
    # Great gears turning in the dark.
    for i in range(4):
        gear(img, rng.randrange(BG_W), rng.randrange(80, BG_H - 80), rng.randrange(50, 110), rng.choice([10, 12, 14]),
             "night-1", "ember-1")
    # Sparks and lamp glints.
    for _ in range(140):
        put(img, rng.randrange(BG_W), rng.randrange(BG_H), c(rng.choice(["ember-3", "gold-3", "ember-2"])))
    far_motes(img, rng, ["ember-2", "gold-3", "ember-3"], glows=5)
    return img


def tower_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(22)
    # Cross-braced girders bolted between the walls.
    for i in range(5):
        x0 = i * BG_W // 5 + rng.randrange(-40, 40)
        w = 10 * D
        cs = masonry_courses(0, BG_H, 500 + i, 24 * D)
        for y in range(BG_H):
            for dx in range(w):
                edge = dx in (0, w - 1)
                col = "night-0" if edge else ("stone-1" if dx < 3 else "night-1")
                if (not edge) and y in cs:
                    col = "stone-2"  # a bolt course, weathered off the fixed period
                put(img, x0 + dx, y, c(col))
        # A diagonal brace to the next girder.
        x1 = x0 + BG_W // 5
        for k in range(0, BG_H, 160 * D):
            y0 = k + rng.randrange(0, 40) * D
            for t in range(x1 - x0):
                yy = y0 + t * 60 * D // max(1, (x1 - x0))
                for th in range(4 * D):
                    put(img, x0 + t, yy + th, c("night-1" if 0 < th < 4 * D - 1 else "night-0"))
    # Chains and hanging lamps.
    for i in range(7):
        x = rng.randrange(BG_W)
        length = rng.randrange(60, 220) * D
        for y in range(0, length):
            if (y // 4) % 2 == 0:
                put(img, x, y, c("stone-2"))
                put(img, x + 1, y, c("stone-1"))
            else:
                put(img, x - 1, y, c("stone-2"))
                put(img, x + 2, y, c("stone-1"))
        for dy in range(12):
            half = 3 + dy // 3 if dy < 9 else 6
            for dx in range(-half, half + 1):
                col = "stone-2" if dy < 3 or abs(dx) == half or dy > 9 else ("gold-6" if abs(dx) < 2 else "ember-4")
                put(img, x + dx, length + dy, c(col))
        for r, alpha in ((20, 110), (28, 60)):
            for k in range(96):
                ang = k / 96 * math.tau
                px = x + int(math.cos(ang) * r)
                py = length + 8 + int(math.sin(ang) * r)
                if k % 2 == 0 and 0 <= py < BG_H and img.getpixel((px % BG_W, py))[3] == 0:
                    put(img, px, py, c("ember-3", alpha))
    return img


def fog_color():
    """Grey-green fog (bible 12: The Haar is grey-green, bone and lantern yellow)."""
    return blend(c("stone-4"), c("leaf-4"), 70)


def fog_band(img, y0, h, alpha, seed):
    """A drifting band of fog: soft noise, thinning at its top and bottom, in
    three dithered steps of density."""
    col = fog_color()
    for y in range(max(0, y0), min(BG_H, y0 + h)):
        k = 1 - abs((y - y0) / h * 2 - 1)
        for x in range(BG_W):
            n = wrap_noise(x / (90 * D), y / (20 * D), seed, BG_W // (90 * D)) * (0.4 + 0.6 * k)
            if n < 0.3:
                continue
            step = 1 if n < 0.42 else (2 if n < 0.55 else 3)
            if step == 1 and (x + y) % 2:
                continue
            a = alpha * step // 3
            under = img.getpixel((x % BG_W, y))
            put(img, x, y, (col[0], col[1], col[2], a) if under[3] == 0 else blend(under, col, a))


def blend(under, over, alpha):
    k = alpha / 255
    return tuple(int(under[i] * (1 - k) + over[i] * k) for i in range(3)) + (max(under[3], alpha),)


def dead_limb(img, x0, y0, length, w, ang, col, rng, depth=0):
    """A bare, crooked limb with twigs forking off it."""
    x, y = float(x0), float(y0)
    for t in range(length):
        ang += rng.uniform(-0.04, 0.04)
        x += math.cos(ang)
        y += math.sin(ang)
        ww = max(1, int(w * (1 - t / length)))
        ww = max(ww, D)
        for d in range(-ww // 2, ww - ww // 2):
            put(img, x - math.sin(ang) * d, y + math.cos(ang) * d, c(col))
        if depth < 2 and t > length // 4 and rng.random() < 0.006:
            dead_limb(img, x, y, length // 2, max(1, ww - 1), ang + rng.choice([-0.8, 0.7]), col, rng, depth + 1)


def haar_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-1"))
    gradient(img, "night-1", "stone-1")
    # Steep the whole sky in a green murk.
    murk = c("leaf-0")
    for y in range(BG_H):
        for x in range(BG_W):
            img.putpixel((x, y), blend(img.getpixel((x, y)), murk, 90 + 50 * y // BG_H))
    rng = random.Random(31)
    # Far limbs of the Tree, drowned in fog: the lower, the paler.
    for i in range(9):
        x0 = rng.randrange(BG_W)
        y0 = BG_H - rng.randrange(0, 140) * D
        dead_limb(img, x0, y0, rng.randrange(200, 380) * D, rng.randrange(10, 22) * D,
                  -math.pi / 2 + rng.uniform(-0.6, 0.6), "night-0" if i % 3 else "night-1", rng)
    for k, y in enumerate(range(60 * D, BG_H, 70 * D)):
        fog_band(img, y, 50 * D, 130, 40 + k)
    # Will-o'-lanterns, far off in the murk.
    for _ in range(26):
        glow_dot(img, rng.randrange(BG_W), rng.randrange(BG_H // 3, BG_H), "gold-5", "gold-2", rng.choice([0, 0, 1]))
    far_motes(img, rng, ["leaf-2", "gold-4", "sky-2"], glows=4)
    return img


def haar_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(32)
    # Limbs reaching in from the sides, hung with moss.
    for i in range(6):
        left = i % 2 == 0
        x0 = rng.randrange(BG_W)
        y0 = rng.randrange(40, 380) * D
        ang = rng.uniform(-0.35, 0.25) + (0 if left else math.pi)
        dead_limb(img, x0, y0, rng.randrange(140, 260) * D, rng.randrange(6, 12) * D, ang, "night-0", rng)
        # Moss beards dripping off the limb.
        for k in range(rng.randrange(6, 12)):
            t = rng.randrange(20, 140) * D
            hx = x0 + math.cos(ang) * t
            hy = y0 + math.sin(ang) * t + 4 * D
            length = rng.randrange(14, 50) * D
            for yy in range(length):
                sway = int(math.sin(yy * 0.05 + k) * 2 * D)
                col = "leaf-1" if yy < length * 0.7 else "stone-2"
                if hash2(k, yy // 3, i) > 0.15:
                    put(img, hx + sway, hy + yy, c(col))
                    if yy < length // 2:
                        put(img, hx + sway + 1, hy + yy, c("night-1"))
    # Lanterns on cords, each with a soft halo.
    for i in range(5):
        x = rng.randrange(BG_W)
        length = rng.randrange(40, 200) * D
        for y in range(length):
            put(img, x, y, c("stone-2" if y % 6 else "stone-3"))
        for dy in range(14):
            half = 4 if 2 < dy < 12 else 2
            for dx in range(-half, half + 1):
                col = "night-0" if dy in (0, 13) or abs(dx) == half else ("gold-6" if abs(dx) < 2 and 4 < dy < 10 else "gold-4")
                put(img, x + dx, length + dy, c(col))
        for r, alpha in ((22, 90), (32, 45)):
            for k in range(120):
                ang = k / 120 * math.tau
                px, py = x + int(math.cos(ang) * r), length + 7 + int(math.sin(ang) * r)
                if k % 2 == 0 and 0 <= py < BG_H and img.getpixel((px % BG_W, py))[3] == 0:
                    put(img, px, py, c("gold-3", alpha))
    # Wisps of near fog.
    for k, y in enumerate(range(30 * D, BG_H, 110 * D)):
        fog_band(img, y + rng.randrange(0, 30) * D, 34 * D, 80, 60 + k)
    return img


def cloud(img, cx, cy, w, h, rng, top="sky-7", body="sky-6", shade="sky-5"):
    """A flat-bottomed cumulus: overlapping puffs, lit on top, shaded underneath."""
    puffs = [(cx + rng.uniform(-0.5, 0.5) * w, cy - rng.uniform(0, 0.6) * h, rng.uniform(0.3, 0.55) * h) for _ in range(9)]
    for y in range(int(cy - h * 1.3), int(cy + 1)):
        for x in range(int(cx - w * 0.8), int(cx + w * 0.8)):
            inside = [p for p in puffs if (x - p[0]) ** 2 + (y - p[1]) ** 2 <= p[2] ** 2]
            if not inside:
                continue
            p = inside[0]
            dy = (y - p[1]) / p[2]
            col = top if dy < -0.45 else (shade if y > cy - h * 0.25 else body)
            if col == body and (x + y) % 2 and dy < -0.3:
                col = top
            put(img, x, y, c(col))


def leaf_shape(img, cx, cy, length, width, ang, col, vein, rng):
    """One great leaf of the canopy: a pointed oval with a midrib."""
    ca, sa = math.cos(ang), math.sin(ang)
    for t in range(-length // 2, length // 2):
        k = 1 - (2 * t / length) ** 2
        half = int(width * 0.5 * math.sqrt(max(0.0, k)))
        for d in range(-half, half + 1):
            x = cx + ca * t - sa * d
            y = cy + sa * t + ca * d
            put(img, x, y, c(vein if d == 0 or (half and abs(d) == half) else col))


def boughs_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("sky-6"))
    gradient(img, "sky-5", "sky-7")
    rng = random.Random(41)
    for _ in range(9):
        cloud(img, rng.randrange(BG_W), rng.randrange(120, 420) * D, rng.randrange(50, 110) * D, rng.randrange(24, 50) * D, rng)
    # Far boughs of the Tree in the haze, leaves bunched along them.
    for i in range(6):
        x0 = rng.randrange(BG_W)
        y0 = BG_H - rng.randrange(0, 200) * D
        dead_limb(img, x0, y0, rng.randrange(240, 420) * D, rng.randrange(10, 18) * D,
                  -math.pi / 2 + rng.uniform(-0.9, 0.9), "sky-4", rng)
    for _ in range(40):
        leaf_shape(img, rng.randrange(BG_W), rng.randrange(BG_H // 3, BG_H), rng.randrange(16, 34) * D,
                   rng.randrange(8, 14) * D, rng.uniform(0, math.pi), "sky-4", "sky-5", rng)
    return img


def boughs_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(42)
    # Boughs crossing in from the sides, hung with enormous leaves.
    for i in range(5):
        left = i % 2 == 0
        x0 = rng.randrange(BG_W)
        y0 = rng.randrange(60, 420) * D
        ang = rng.uniform(-0.4, 0.2) + (0 if left else math.pi)
        dead_limb(img, x0, y0, rng.randrange(180, 300) * D, rng.randrange(8, 14) * D, ang, "bark-2", rng)
        for k in range(rng.randrange(4, 8)):
            t = rng.randrange(20, 160) * D
            hx = x0 + math.cos(ang) * t
            hy = y0 + math.sin(ang) * t
            leaf_shape(img, hx, hy + 20 * D, rng.randrange(40, 80) * D, rng.randrange(18, 30) * D,
                       ang + rng.uniform(0.8, 2.2), rng.choice(["leaf-2", "leaf-3"]), "leaf-1", rng)
    return img


def lightning(img, x, y0, y1, rng, col="gold-7", glow="crystal-6"):
    """A jagged bolt from y0 down to y1, with a faint halo and a fork or two."""
    pts = [(x, y0)]
    while pts[-1][1] < y1:
        px, py = pts[-1]
        pts.append((px + rng.randrange(-8, 9) * D, py + rng.randrange(6, 16) * D))
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(abs(bx - ax), abs(by - ay))
        for t in range(n + 1):
            xx = ax + (bx - ax) * t / max(n, 1)
            yy = ay + (by - ay) * t / max(n, 1)
            for dx in (-D, D):
                put(img, xx + dx, yy, c(glow, 120))
            for k in range(D):
                put(img, xx + k, yy, c(col))
    if len(pts) > 3:
        fx, fy = pts[len(pts) // 2]
        lightning_fork = [(fx, fy)]
        for _ in range(3):
            px, py = lightning_fork[-1]
            lightning_fork.append((px + rng.choice([-1, 1]) * rng.randrange(4, 10) * D, py + rng.randrange(6, 12) * D))
        for (ax, ay), (bx, by) in zip(lightning_fork, lightning_fork[1:]):
            n = max(abs(bx - ax), abs(by - ay))
            for t in range(n + 1):
                put(img, ax + (bx - ax) * t / max(n, 1), ay + (by - ay) * t / max(n, 1), c(glow))


def block(img, wx, wy, col):
    """Fills one world pixel (a D x D block) at world-pixel coordinates wx, wy, so a
    painted prop keeps the game's pixel grain instead of half-size atlas pixels."""
    for dy in range(D):
        for dx in range(D):
            put(img, wx * D + dx, wy * D + dy, col)


ISLAND_ROCK = ("crystal-3", "crystal-2", "crystal-1", "night-1")  # rim, lit, mid, shadow
ISLAND_LINE = "night-0"
ISLAND_GRASS = ("leaf-3", "leaf-2", "leaf-1")  # tip, blade, root


def island_cells(cx, cy, w, depth, seed):
    """The silhouette of a sky island on the world-pixel grid: {(x, y): k}, k the
    cell's depth below the lip (0 to 1). Built a column at a time: a rounded belly
    of earth under the lip, and beneath it a main point of rock leaning off
    centre with two to four lesser points beside it, so the underside is a ragged
    cluster of hanging spurs and no two islands are the same triangle."""
    rng = random.Random(seed)
    x0, y0 = int(cx) // D, int(cy) // D
    half, rows = max(5, w // (2 * D)), max(8, depth // D)
    spurs = [(rng.uniform(-0.25, 0.25), rng.uniform(0.18, 0.3), 1.0)]
    for _ in range(rng.randint(2, 4)):
        spurs.append((rng.uniform(-0.75, 0.75), rng.uniform(0.08, 0.18), rng.uniform(0.35, 0.7)))
    cells = {}
    for x in range(x0 - half, x0 + half + 1):
        u = (x - x0) / half
        belly = 0.32 * max(0.0, 1 - abs(u) ** 2) ** 0.7
        drop = belly
        for at, wd, ht in spurs:
            a = 1 - abs(u - at) / wd
            if a > 0:
                drop = max(drop, belly + (ht - belly) * a ** 1.6)
        drop *= 1 + 0.08 * (hash2(x, 0, seed) - 0.5)
        bottom = max(1, int(rows * drop))
        if abs(u) > 0.92:
            bottom = min(bottom, 2)  # a rounded shoulder under the lip's ends
        for j in range(bottom):
            cells[(x, y0 + j)] = j / rows
    return cells


def _stones(cells, seed, size=8):
    """Splits the rock into chunky stones (a jittered Voronoi), returning for each
    cell its stone's centre and whether it sits on a seam between two stones."""
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    centres = []
    for gy in range(min(ys) // size - 1, max(ys) // size + 2):
        for gx in range(min(xs) // size - 1, max(xs) // size + 2):
            centres.append((gx * size + hash2(gx, gy, seed) * size, gy * size + hash2(gy, gx, seed + 9) * size))
    out = {}
    for (x, y) in cells:
        best = sorted(((x - a) ** 2 + ((y - b) * 1.9) ** 2, (a, b)) for a, b in centres)[:2]
        (d1, c1), (d2, _) = best
        out[(x, y)] = (c1, d2 ** 0.5 - d1 ** 0.5 < 0.8)
    return out


def island(img, cx, cy, w, rng, rock=ISLAND_ROCK, line=ISLAND_LINE, grass=ISLAND_GRASS):
    """A floating sky island (design bible 12.33), painted on the world-pixel grid
    as a lit pixel prop, not one flat fill: its rock is a cluster of chunky stones
    shaded on a four-tone ramp lit from the upper left (each stone lit on its
    upper-left face, seams one step darker, the right flank and the hanging spurs
    in shadow), closed by a dark selective outline on its shadow side and
    underside only. A three-tone grass lip caps it, blades poke above, tufts and
    moss hang over its edges and roots dangle from its belly."""
    depth = int(w * rng.uniform(0.6, 0.9))
    seed = int(cx) * 7919 + int(cy)
    loc = random.Random(seed + 1)
    cells = island_cells(cx, cy, w, depth, seed)
    stones = _stones(cells, seed)
    y0 = int(cy) // D
    xs = [x for x, _ in cells]
    lo, hi = min(xs), max(xs)
    tones = (rock[0], rock[1], rock[2], rock[3], line)
    for (x, y), k in cells.items():
        out_l = (x - 1, y) not in cells
        out_r = (x + 1, y) not in cells
        out_d = (x, y + 1) not in cells
        if out_r or out_d:
            block(img, x, y, c(line))  # the selective outline: shadow side and underside
            continue
        (sx, sy), seam = stones[(x, y)]
        u = (sx - lo) / max(1, hi - lo)
        v = u * 0.7 + min(1.0, (sy - y0) / 10.0) * 0.35 + k * 0.45
        level = 1 if v < 0.55 else 2 if v < 1.0 else 3
        if seam:
            level = min(3, level + 1)  # a seam between stones, one step darker
        elif (x - sx) + (y - sy) * 1.3 < -2.2 and level < 3:
            level -= 1  # the stone's lit upper-left face
        if out_l:
            level = 0 if k < 0.25 else min(level, 1)  # a rim of light down the lit flank
        block(img, x, y, c(tones[max(0, level)]))
    # The grass lip: a three-tone cap a pixel wider than the rock, its top ragged.
    tip, blade, root = grass
    for x in range(lo - 1, hi + 2):
        h = hash2(x, 0, seed)
        block(img, x, y0 - 2, c(tip if h > 0.35 else blade))
        block(img, x, y0 - 1, c(blade if h > 0.15 else tip))
        block(img, x, y0, c(root))
        if hash2(x, 1, seed) > 0.7:
            block(img, x, y0 - 3, c(tip))  # a blade standing up
            if hash2(x, 2, seed) > 0.75:
                block(img, x, y0 - 4, c(blade))
    # Tufts hanging over both ends of the lip, and moss down the rock's top.
    for edge in (lo - 1, hi + 1):
        for d in range(loc.randint(2, 4)):
            block(img, edge, y0 + 1 + d, c(blade if d < 1 else root))
    for x in range(lo + 1, hi):
        if hash2(x, 3, seed) > 0.78:
            for d in range(1, 1 + loc.randint(1, 3)):
                if (x, y0 + d) in cells and (x + 1, y0 + d) in cells:
                    block(img, x, y0 + d, c(blade if d == 1 else root))
    # Roots dangling from the belly between the spurs, darkening as they fall.
    bottoms = {}
    for (x, y) in cells:
        bottoms[x] = max(bottoms.get(x, y), y)
    belly = sorted(x for x in bottoms if lo + 2 < x < hi - 2)
    for _ in range(loc.randint(2, 4)):
        x = loc.choice(belly)
        y = bottoms[x]
        ln = loc.randint(3, 8)
        for t in range(1, ln):
            if t == ln // 2:
                x += loc.choice([-1, 1])
            block(img, x, y + t, c(root if t < ln // 2 else line))


def ruined_spire(img, sx, base, sh):
    """A ruined tower on an island, on the world-pixel grid: lit on its left, a
    shadow column and outline on its right, mortar courses, a broken crown of
    battlements and one warm window."""
    x0, top, bot = int(sx) // D - 5, (int(base) - int(sh)) // D, int(base) // D - 2
    rim, lit, midt, shade = ISLAND_ROCK
    for y in range(top, bot):
        crown = y < top + 5
        for i in range(10):
            if crown and (i // 3) % 2:
                continue  # a broken crown of battlements
            if i == 9 or y == top or (crown and i % 3 == 2):
                col = ISLAND_LINE
            elif i == 0:
                col = rim
            elif i < 4:
                col = lit
            elif i < 7:
                col = midt
            else:
                col = shade
            if (y - top) % 4 == 3 and 0 < i < 9 and hash2(i, y, 3) > 0.3:
                col = shade if col != shade else ISLAND_LINE  # a mortar course
            block(img, x0 + i, y, c(col))
    wy = top + int((bot - top) * 0.4)
    for dy in range(2):
        block(img, x0 + 4, wy + dy, c("gold-6"))
    block(img, x0 + 5, wy, c("gold-4"))
    block(img, x0 + 5, wy + 1, c(ISLAND_LINE))


def spires_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("crystal-1"))
    gradient(img, "night-1", "crystal-2")
    rng = random.Random(51)
    # Storm banks rolling across a violet sky, lit gold along their tops.
    for _ in range(12):
        cloud(img, rng.randrange(BG_W), rng.randrange(80, 460) * D, rng.randrange(60, 130) * D, rng.randrange(26, 54) * D, rng,
              top="crystal-3", body="crystal-2", shade="night-2")
    for _ in range(3):
        x = rng.randrange(BG_W)
        lightning(img, x, rng.randrange(60, 160) * D, rng.randrange(260, 400) * D, rng)
    # The far spires of the Tree's crown, faint against the storm.
    for _ in range(5):
        x0 = rng.randrange(BG_W)
        dead_limb(img, x0, BG_H, rng.randrange(260, 420) * D, rng.randrange(8, 14) * D,
                  -math.pi / 2 + rng.uniform(-0.3, 0.3), "night-2", rng)
    far_motes(img, rng, ["crystal-2", "sky-2", "gold-3"], glows=5)
    return img


def spires_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(52)
    # Sky islands adrift at middle distance, a ruined spire on one or two.
    for i in range(6):
        cx = (i + rng.uniform(0.1, 0.9)) * BG_W / 6
        cy = rng.randrange(140, 400) * D
        w = rng.randrange(50, 110) * D
        island(img, cx, cy, w, rng)
        if rng.random() > 0.5:
            sx, sh = cx + rng.uniform(-0.2, 0.2) * w, rng.randrange(40, 90) * D
            ruined_spire(img, sx, cy, sh)
    return img


def vorrhallow_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "sky-1")
    rng = random.Random(61)
    # The drowned capital's great hall: rows of colossal pillars and arches
    # sunk to their knees in dark water, crystal light glowing between them.
    water = int(BG_H * 0.72)
    for i in range(7):
        x0 = int((i + rng.uniform(0.0, 0.4)) * BG_W / 7)
        w = rng.randrange(24, 40) * D
        cs = masonry_courses(0, BG_H, 440 + i, 18 * D)
        for y in range(BG_H):
            for dx in range(w):
                # The far pillars: weathered courses on a jittered period, each
                # stone a touch lighter or darker, so the great hall stops reading
                # as one stamped column (bible 12.14). Muted (stone-1, no stone-2)
                # to stay behind vorrhallow_mid.
                col = "stone-1" if dx <= w * 0.3 else masonry_shade(x0 + dx, y, 440 + i, "night-0", "night-1", "stone-1")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                put(img, x0 + dx, y, c(col))
        # An arch springing to the next pillar.
        span = BG_W // 7
        for dx in range(span):
            k = dx / span
            top = int(60 * D + math.sin(k * math.pi) * -40 * D) + 90 * D
            for y in range(top - 10 * D, top):
                put(img, x0 + w + dx, y, c("night-1"))
    # Crystal clusters on the far walls, glowing magenta.
    for _ in range(9):
        cx, cy = rng.randrange(BG_W), rng.randrange(80, water // D - 20) * D
        for k in range(rng.randint(3, 6)):
            h = rng.randrange(10, 34) * D
            ang = rng.uniform(-0.7, 0.7)
            for t in range(h):
                wdt = max(D, int((h - t) / h * 9 * D))
                x = cx + int(math.sin(ang) * t) - wdt // 2
                y = cy - int(math.cos(ang) * t)
                for dx in range(wdt):
                    put(img, x + dx, y, c("crystal-5" if dx < D else ("crystal-2" if dx >= wdt - D else "crystal-3")))
    # Dark water with glints and the crystals' smeared reflections.
    for y in range(water, BG_H):
        for x in range(BG_W):
            col = "night-0" if (x // (6 * D) + y // D) % 9 else "sky-1"
            put(img, x, y, c(col))
    for _ in range(220):
        x, y = rng.randrange(BG_W), rng.randrange(water, BG_H)
        put(img, x, y, c(rng.choice(["sky-3", "crystal-3", "sky-2"])))
    far_motes(img, rng, ["sky-2", "crystal-2", "sky-3"], glows=5)
    return img


def vorrhallow_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(62)
    # Broken colonnades and toppled statues of dwarf kings, nearer and darker,
    # with crystal spears grown through them.
    for i in range(6):
        x0 = int((i + rng.uniform(0.1, 0.7)) * BG_W / 6)
        w = rng.randrange(14, 24) * D
        top = rng.randrange(120, 300) * D
        cs = masonry_courses(top, BG_H, 620 + i, 24 * D)
        for y in range(top, BG_H):
            for dx in range(w):
                if y < top + 8 * D and (dx // (4 * D)) % 2 and rng.random() > 0.3:
                    continue  # a broken top
                col = "stone-1" if dx < w * 0.25 else masonry_shade(x0 + dx, y, 620 + i, "night-0", "night-1", "stone-2")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                put(img, x0 + dx, y, c(col))
        # A crystal spear through the column.
        sx, sy = x0 + w // 2, top + rng.randrange(20, 80) * D
        ln = rng.randrange(30, 70) * D
        ang = rng.choice([-1, 1]) * rng.uniform(0.4, 0.9)
        for t in range(ln):
            x = sx + int(math.sin(ang) * t)
            y = sy - int(math.cos(ang) * t)
            wdt = max(D, int((ln - t) / ln * 7 * D))
            for k in range(wdt):
                put(img, x + k - wdt // 2, y, c("crystal-6" if k < D else ("crystal-2" if k >= wdt - D else "crystal-4")))
    # Hanging chains from the vault.
    for _ in range(8):
        x = rng.randrange(BG_W)
        for y in range(0, rng.randrange(60, 180) * D):
            if (y // (3 * D)) % 2 == 0:
                put(img, x, y, c("night-1"))
    return img


def evercrown_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "crystal-1")
    rng = random.Random(77)
    # The stillglass's hollow heart: vast ribbed walls curving away like the inside
    # of a shell, cyan veins of light pulsing through them toward a red glow.
    for i in range(9):
        cx = int((i + rng.uniform(0.0, 0.5)) * BG_W / 9)
        w = rng.randrange(30, 60) * D
        bend = rng.uniform(-60, 60) * D
        for y in range(BG_H):
            k = y / BG_H
            x0 = cx + int(math.sin(k * math.pi) * bend)
            for dx in range(w):
                col = "night-1" if dx > w * 0.35 else "crystal-1"
                if (y + dx) % (22 * D) < D:
                    col = "night-0"
                put(img, x0 + dx, y, c(col))
    # Veins: wandering lines of cyan light.
    for _ in range(14):
        x, y = rng.randrange(BG_W), rng.randrange(BG_H)
        for t in range(rng.randrange(80, 240) * D // 2):
            put(img, x, y, c("sky-5" if t % 7 else "sky-6"))
            put(img, x + 1, y, c("sky-3"))
            x += rng.choice([-1, 0, 1])
            y += 1 if rng.random() > 0.3 else -1
    # A red glow far below: the core.
    for y in range(int(BG_H * 0.8), BG_H):
        for x in range(BG_W):
            if hash2(x // (4 * D), y // (4 * D), 7) > 0.55 - (y - BG_H * 0.8) / BG_H:
                put(img, x, y, c("ember-1"))
    far_motes(img, rng, ["crystal-2", "sky-2", "crystal-3"], glows=6)
    return img


def evercrown_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(78)
    # Nearer: tendrils of stillglass flesh hanging and rising, crystal growing on them.
    for i in range(8):
        x0 = int((i + rng.uniform(0.1, 0.8)) * BG_W / 8)
        down = rng.random() > 0.5
        ln = rng.randrange(120, 320) * D
        w0 = rng.randrange(10, 20) * D
        for t in range(ln):
            y = t if down else BG_H - 1 - t
            wdt = max(D, int(w0 * (1 - t / ln)))
            sway = int(math.sin(t / (30 * D) + i) * 8 * D)
            for dx in range(wdt):
                # A lit stillglass tendril, not another dark rib: a crisp night-0
                # silhouette edge, a crystal-2 glass body and a crystal-3 core
                # highlight down the centre. The far wall's ribs are night-1 and
                # crystal-1, so the nearer flesh reads a clear step brighter and
                # outlined against it instead of camouflaging into it (the grade's
                # 'ambiguous translucent blocks / mid tendrils unclear against the
                # ribbed far wall', pass 503/520; design bible 12.20).
                edge = min(dx, wdt - 1 - dx)
                if wdt <= 2 * D:
                    col = "crystal-2"
                elif edge < D:
                    col = "night-0"
                elif edge < wdt * 0.42:
                    col = "crystal-2"
                else:
                    col = "crystal-3"
                if (t // (6 * D)) % 5 == 0 and dx == wdt // 2:
                    col = "ember-2"
                put(img, x0 + sway + dx - wdt // 2, y, c(col))
        # A cyan bulb at the tip.
        tip_y = ln if down else BG_H - 1 - ln
        for dy in range(-3 * D, 3 * D):
            for dx in range(-3 * D, 3 * D):
                if dx * dx + dy * dy < 9 * D * D:
                    put(img, x0 + int(math.sin(ln / (30 * D) + i) * 8 * D) + dx, tip_y + dy, c("sky-6" if dx * dx + dy * dy < 2 * D * D else "sky-3"))
    return img


def sunken_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "sky-2")
    rng = random.Random(86)
    # Deep under the water: a vast flooded cavern of terraced limestone pools
    # stepping down into the dark, shafts of pale light falling from far above.
    for i in range(10):
        y0 = int((i + rng.uniform(0.0, 0.5)) * BG_H / 10)
        x0 = rng.randrange(-BG_W // 4, BG_W // 2)
        wdt = rng.randrange(BG_W // 3, BG_W)
        for dx in range(wdt):
            x = x0 + dx
            bump = int(math.sin(dx / (14.0 * D) + i) * 3 * D)
            for dy in range(3 * D):
                put(img, x, y0 + bump + dy, c("sky-2" if dy < D else "night-1"))
            for dy in range(3 * D, 14 * D):
                if hash2(x // (3 * D), (y0 + dy) // (3 * D), 86 + i) > 0.25:
                    put(img, x, y0 + bump + dy, c("stone-1" if dy < 6 * D else "night-1"))
    # Light falling from far above, in slanted shafts.
    for _ in range(6):
        x = rng.randrange(BG_W)
        w = rng.randrange(12, 30) * D
        for y in range(BG_H):
            for dx in range(w):
                if (dx + y // 3) % (6 * D) < D and hash2(x + dx, y // (2 * D), 87) > 0.5:
                    put(img, x + dx + y // 4, y, c("sky-3"))
    # Specks drifting in the water.
    for _ in range(260):
        put(img, rng.randrange(BG_W), rng.randrange(BG_H), c(rng.choice(["sky-4", "sky-3", "stone-3"])))
    far_motes(img, rng, ["sky-2", "sky-3", "sky-1"], glows=5)
    return img


def sunken_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(87)
    # Nearer: the dwarves' drowned aqueduct, a line of arches on piers, and
    # long weed swaying up from the bottom.
    deck = int(BG_H * 0.42)
    span = BG_W // 5
    for i in range(5):
        x0 = i * span
        pw = rng.randrange(16, 24) * D
        cs = masonry_courses(deck, BG_H, 560 + i, 16 * D)
        for y in range(deck, BG_H):
            for dx in range(pw):
                # The aqueduct piers: weathered courses on a jittered period with
                # per-stone value, so the arcade stops reading as one stamped pier
                # (bible 12.14).
                col = "stone-2" if dx < pw * 0.25 else masonry_shade(x0 + dx, y, 560 + i, "night-0", "night-1", "stone-2")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                put(img, x0 + dx, y, c(col))
        for dx in range(span - pw):
            k = dx / (span - pw)
            top = deck + 30 * D - int(math.sin(k * math.pi) * 34 * D)
            for y in range(deck - 10 * D, top):
                put(img, x0 + pw + dx, y, c("night-1" if y > deck - 8 * D else "stone-2"))
    for _ in range(22):
        x = rng.randrange(BG_W)
        h = rng.randrange(60, 220) * D
        for t in range(h):
            sx = x + int(math.sin(t / (18.0 * D) + x) * 5 * D)
            put(img, sx, BG_H - 1 - t, c("leaf-2" if t % (7 * D) else "leaf-3"))
            put(img, sx + D, BG_H - 1 - t, c("night-1"))
    return img


def trials_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "stone-1")
    rng = random.Random(113)
    # A void with great faint ring rings turning in it, each a circle of
    # broken strokes like letters seen from far off.
    for _ in range(7):
        cx, cy = rng.randrange(BG_W), rng.randrange(BG_H)
        r = rng.randrange(40, 140) * D
        for k in range(int(r * 0.9)):
            a = k / (r * 0.9) * math.tau
            if (k // (6 * D)) % 3 == 2:
                continue
            for w in range(D):
                put(img, cx + int(math.cos(a) * (r + w)), cy + int(math.sin(a) * (r + w)), c("stone-2"))
    far_motes(img, rng, ["sky-1", "stone-2", "gold-2"], glows=4)
    return img


def trials_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(114)
    # Nearer: pale slabs hanging in the void, each with a darker underside.
    for _ in range(18):
        w = rng.randrange(14, 60) * D
        h = rng.randrange(4, 10) * D
        x0, y0 = rng.randrange(BG_W), rng.randrange(BG_H - h)
        for y in range(h):
            for x in range(w):
                put(img, x0 + x, y0 + y, c("stone-3" if y < D else ("stone-2" if y < h - 2 * D else "night-1")))
    return img


def gym_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "night-1")
    return img


# --- Foreground silhouette layers (design bible 12.11) -------------------------
# A near-black silhouette band hugging the bottom of the view, drawn by Backdrop
# as a fast horizontal-parallax layer in front of the play field. Mostly
# transparent so the centre of the screen stays clear for combat; the shapes
# differ by zone material so each foreground belongs to its world. The solid band
# only backs the protrusion roots: Backdrop locks this layer vertically to the
# camera and seats the band's top (FORE_FLOOR - FORE_BAND, Backdrop.FORE_GROUND)
# on the view's bottom edge, so the band itself stays off screen (bible 12.25).
FORE_KIND = {
    "heartwood": "fern", "boughs": "fern",
    "haar": "reed", "sunken": "reed",
    "evercrown": "crystal", "vorrhallow": "crystal",
    "tower": "rubble", "trials": "rubble",
    "hearthroot": "fence", "spires": "fence",
}
FORE_BODY = "night-0"  # the darkest night shade: an unlit near-black silhouette
FORE_RIM = "night-1"   # one step up, a faint top/leading edge so a shape reads
FORE_FLOOR = 360 * D   # the view bottom in canvas pixels (bible: BASE_SIZE.y)
FORE_BAND = 16 * D     # solid ground strip above the floor line
BAND_A, PART_A, RIM_A = 242, 176, 196  # band / protrusion / rim alphas (see-through foreground)
BAND_RIM_A = 224  # the band's own top rim stays solid enough to mark FORE_GROUND
# The tallest a silhouette may rise above the band (world pixels; Backdrop.FORE_MAX_RISE).
# The grade of pass 535: posts and reeds up to 128 px tall stood over the play layer
# as black bars. The view's bottom 36 px is the ground the hero stands on when the
# camera rests (bible 12.29), so the silhouettes now stay a low fringe below that line.
FORE_MAX_RISE = 36


def _fore_fill(img):
    """The solid ground band, from the floor line down past the view bottom."""
    top = FORE_FLOOR - FORE_BAND
    for y in range(top, BG_H):
        col = c(FORE_RIM, BAND_RIM_A) if y < top + D else c(FORE_BODY, BAND_A)
        for x in range(BG_W):
            put(img, x, y, col)


def _fore_stalk(img, cx, base, h, w, lean, taper_to_point):
    """A tapering stalk/shard rising `h` from `base` at `cx`, leaning by `lean`.
    Width `w` at the base narrows to a point (shards/blades) or 1 px (stalks)."""
    for i in range(h):
        t = i / max(1, h)
        y = base - i
        half = max(0 if taper_to_point else 0, int((w * (1.0 - t)) / 2))
        x0 = cx + int(lean * t)
        for dx in range(-half, half + 1):
            put(img, x0 + dx, y, c(FORE_BODY, PART_A))
        put(img, x0 - half, y, c(FORE_RIM, RIM_A))
        if taper_to_point:
            put(img, x0 + half, y, c(FORE_RIM, RIM_A))


def _fore_fern(img, x, base, rng):
    spread = rng.randint(10, 20) * D
    for _ in range(rng.randint(3, 6)):
        cx = x + rng.randint(0, spread)
        h = rng.randint(14, 34) * D
        w = rng.choice([2, 3]) * D
        lean = rng.randint(-10, 10) * D
        _fore_stalk(img, cx, base, h, w, lean, False)
        for j in range(4 * D, h - 3 * D, 7 * D):  # leaflets off the frond
            t = j / h
            lx, ly = cx + int(lean * t), base - j
            d = rng.choice([-1, 1])
            for m in range(rng.randint(3, 6) * D):
                put(img, lx + d * m, ly + m // 2, c(FORE_BODY, PART_A))
    return spread + rng.randint(16, 34) * D


def _fore_reed(img, x, base, rng):
    spread = rng.randint(8, 16) * D
    for _ in range(rng.randint(2, 4)):
        cx = x + rng.randint(0, spread)
        h = rng.randint(18, 36) * D
        lean = rng.randint(-6, 6) * D
        _fore_stalk(img, cx, base, h, 2 * D, lean, False)
        if rng.random() < 0.5:  # a cattail tip, hung below the stalk's end
            tx, ty = cx + int(lean * 0.85), base - h + rng.randint(6, 9) * D
            for dy in range(-4 * D, 4 * D):
                for dx in range(-2 * D, 2 * D):
                    if (dx / (1.6 * D)) ** 2 + (dy / (4.0 * D)) ** 2 <= 1.0:
                        put(img, tx + dx, ty + dy, c(FORE_BODY, PART_A))
    return spread + rng.randint(16, 32) * D


def _fore_crystal(img, x, base, rng):
    spread = rng.randint(10, 18) * D
    for _ in range(rng.randint(2, 4)):
        cx = x + rng.randint(0, spread)
        h = rng.randint(12, 34) * D
        w = rng.randint(6, 12) * D
        _fore_stalk(img, cx, base, h, w, rng.randint(-5, 5) * D, True)
    return spread + rng.randint(18, 32) * D


def _fore_rubble(img, x, base, rng):
    span = rng.randint(24, 46) * D
    peak = rng.randint(10, 26) * D
    steps = rng.randint(4, 7)
    pts = [rng.randint(peak // 3, peak) for _ in range(steps + 1)]
    for i in range(span):
        fi = (i / span) * steps
        a = int(fi)
        b = min(a + 1, steps)
        f = fi - a
        hgt = int(pts[a] * (1 - f) + pts[b] * f)
        for j in range(hgt):
            put(img, x + i, base - j, c(FORE_BODY, PART_A))
        put(img, x + i, base - hgt, c(FORE_RIM, RIM_A))
    return span + rng.randint(8, 18) * D


def _fore_fence(img, x, base, rng):
    """A run of short timber stubs joined by a sagging rail (Hearthroot, the
    Spires): low and broken, so it never stands over the play layer as a bar."""
    stubs = rng.randint(2, 4)
    gap = rng.randint(12, 20) * D
    tops = []
    for k in range(stubs):
        sx = x + k * gap
        w = rng.choice([3, 4]) * D
        h = rng.randint(12, 30) * D
        lean = rng.randint(-2, 2) * D
        for i in range(h):
            t = i / h
            x0 = sx + int(lean * t)
            for dx in range(w):
                put(img, x0 + dx, base - i, c(FORE_BODY, PART_A))
            put(img, x0, base - i, c(FORE_RIM, RIM_A))
        tops.append((sx + int(lean) + w // 2, base - h))
    for (ax, ay), (bx, by) in zip(tops, tops[1:]):  # the rail sags between stubs
        rail_y = max(ay, by) + 3 * D
        for px in range(ax, bx + 1):
            f = (px - ax) / max(1, bx - ax)
            sag = int(4 * D * 4 * f * (1 - f))
            for dy in range(D):
                put(img, px, rail_y + sag + dy, c(FORE_BODY, PART_A))
    return (stubs - 1) * gap + rng.randint(40, 70) * D


FORE_SHAPE = {
    "fern": _fore_fern, "reed": _fore_reed, "crystal": _fore_crystal,
    "rubble": _fore_rubble, "fence": _fore_fence,
}


def foreground(zone):
    """The near-black foreground silhouette for `zone`: protrusions of the zone's
    material rising from a solid ground band at the view bottom, over a mostly
    transparent canvas (bible 12.11)."""
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    shape = FORE_SHAPE[FORE_KIND[zone]]
    rng = random.Random(sum(ord(ch) for ch in zone) + 700)
    base = FORE_FLOOR - FORE_BAND
    x = -rng.randint(10, 30) * D
    while x < BG_W + 20 * D:
        x += shape(img, x, base, rng)
    _fore_fill(img)  # the band last, so it covers the protrusion roots cleanly
    return img


# --- Ridge parallax layer (design bible 12.12) ---------------------------------
# A distant silhouette ridgeline between the far backdrop and the mid layer, so
# the parallax recedes through three depths instead of two (the independent
# grade's recurring "depth collapse"). Backdrop draws it with atmospheric-
# perspective knobs between far and mid (bible 12.5), so it sits back in the haze
# and never competes with the play field — a pure depth cue, behind everything
# the player touches, combat untouched. One parametrized painter (like the
# foreground, bible 12.11): a seamless rolling ridgeline whose crest profile is
# the zone's distant material — firs over the woods, jagged shards over the
# crystal halls, broken crags over the stone towers, battlemented roofs over the
# hearth towns, low mounds over the marsh springs.
RIDGE_KIND = {
    "heartwood": "fir", "boughs": "fir",
    "haar": "mound", "sunken": "mound",
    "evercrown": "shard", "vorrhallow": "shard",
    "tower": "crag", "trials": "crag",
    "hearthroot": "roof", "spires": "roof",
}
# Body silhouette and a one-step-lighter crest rim: a dark shade of each zone's
# dominant ramp, so the ridge belongs to its world even before the haze recedes
# it (the warm hearth and cold spring never share one ridge colour).
RIDGE_COLOR = {
    "heartwood": ("bark-1", "bark-2"), "boughs": ("leaf-1", "leaf-2"),
    "haar": ("sky-1", "sky-2"), "sunken": ("sky-1", "sky-2"),
    "evercrown": ("crystal-1", "crystal-2"), "vorrhallow": ("crystal-1", "crystal-2"),
    "tower": ("stone-1", "stone-2"), "trials": ("stone-1", "stone-2"),
    "hearthroot": ("stone-1", "stone-2"), "spires": ("stone-1", "stone-2"),
}
RIDGE_BASE = int(BG_H * 0.56)  # the ridgeline's resting canvas y (the horizon)
RIDGE_A = 236                  # a touch see-through, so the far sky grades through
RIDGE_RIM_A = 212


def _ridge_roll(rng):
    """A seamless rolling baseline, canvas px above RIDGE_BASE per column, summed
    from sines with whole-number cycle counts so the left and right edges meet
    (the layer repeats sideways)."""
    h = [0.0] * BG_W
    for cyc, lo, hi in ((rng.randint(2, 3), 10, 16), (rng.randint(4, 6), 5, 9), (rng.randint(8, 11), 2, 4)):
        amp = rng.uniform(lo, hi) * D
        ph = rng.uniform(0, 2 * math.pi)
        for x in range(BG_W):
            h[x] += amp * math.sin(2 * math.pi * cyc * x / BG_W + ph)
    return h


def _tri(teeth, cx, half, peak, lean=0):
    """A triangular crest `half` wide, `peak` tall, into `teeth` (indices wrap)."""
    for dx in range(-half, half + 1):
        t = 1.0 - abs(dx) / max(1, half)
        i = (cx + int(lean * (1 - t)) + dx) % BG_W
        teeth[i] = max(teeth[i], peak * t)


def _block(teeth, cx, half, peak):
    """A flat-topped block (a battlement), into `teeth` (indices wrap)."""
    for dx in range(-half, half + 1):
        teeth[(cx + dx) % BG_W] = max(teeth[(cx + dx) % BG_W], peak)


def _jag(teeth, cx, half, peak, rng):
    """A random-walk crest for broken rock, into `teeth` (indices wrap)."""
    steps = rng.randint(3, 6)
    pts = [rng.uniform(0.3, 1.0) * peak for _ in range(steps + 1)]
    for dx in range(-half, half + 1):
        f = (dx + half) / max(1, 2 * half) * steps
        a = int(f)
        fr = f - a
        v = pts[a] * (1 - fr) + pts[min(a + 1, steps)] * fr
        teeth[(cx + dx) % BG_W] = max(teeth[(cx + dx) % BG_W], v)


def _ridge_profile(kind, rng):
    """The crest height (canvas px above RIDGE_BASE) per column: a rolling
    baseline with the zone's teeth raised onto it, seamless across the seam."""
    roll = _ridge_roll(rng)
    teeth = [0.0] * BG_W
    x = rng.randint(0, 20) * D
    while x < BG_W:
        if kind == "mound":
            _tri(teeth, x, rng.randint(14, 26) * D, rng.randint(4, 10) * D)
            x += rng.randint(30, 60) * D
        elif kind == "fir":
            _tri(teeth, x, rng.randint(5, 10) * D, rng.randint(22, 46) * D)
            x += rng.randint(10, 20) * D
        elif kind == "shard":
            _tri(teeth, x, rng.randint(4, 9) * D, rng.randint(26, 54) * D, lean=rng.randint(-4, 4) * D)
            x += rng.randint(12, 24) * D
        elif kind == "crag":
            _jag(teeth, x, rng.randint(10, 22) * D, rng.randint(14, 40) * D, rng)
            x += rng.randint(14, 30) * D
        else:  # roof
            _block(teeth, x, rng.randint(9, 18) * D, rng.randint(18, 44) * D)
            x += rng.randint(16, 32) * D
    return [roll[i] + teeth[i] for i in range(BG_W)]


def ridge(zone):
    """The distant ridgeline silhouette for `zone` (design bible 12.12): the
    zone's far crest filled from the horizon down, over a transparent sky, so
    Backdrop can recede it into the haze between the far and mid layers."""
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    body, rim = RIDGE_COLOR[zone]
    rng = random.Random(sum(ord(ch) for ch in zone) + 1300)
    h = _ridge_profile(RIDGE_KIND[zone], rng)
    for x in range(BG_W):
        top = RIDGE_BASE - int(round(h[x]))
        for y in range(top, BG_H):
            put(img, x, y, c(body, RIDGE_A))
        put(img, x, top, c(rim, RIDGE_RIM_A))
    return img


BACKGROUNDS = {
    "heartwood": (heartwood_far, heartwood_mid),
    "hearthroot": (hearthroot_far, hearthroot_mid),
    "tower": (tower_far, tower_mid),
    "haar": (haar_far, haar_mid),
    "boughs": (boughs_far, boughs_mid),
    "spires": (spires_far, spires_mid),
    "vorrhallow": (vorrhallow_far, vorrhallow_mid),
    "evercrown": (evercrown_far, evercrown_mid),
    "sunken": (sunken_far, sunken_mid),
    "trials": (trials_far, trials_mid),
    "gym": (gym_far, None),
}


def main():
    for zone in ZONES:
        build_tileset(zone)
    BG.mkdir(parents=True, exist_ok=True)
    for zone, (far, mid) in BACKGROUNDS.items():
        far().save(BG / f"{zone}_far.png")
        if mid:
            mid().save(BG / f"{zone}_mid.png")
    for zone in RIDGE_KIND:
        ridge(zone).save(BG / f"{zone}_ridge.png")
    for zone in FORE_KIND:
        foreground(zone).save(BG / f"{zone}_fore.png")


if __name__ == "__main__":
    main()
