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
  row 9:    the two haunches, then the blends between the tiers (bible 12.99):
            3 field tiles whose blocks are surface or MID, 3 MID or DEEP.
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
# The Tower's plates (design bible 12.54, pass 566). Plates of 8 world pixels put
# four seams, sixteen rivets and their rust in every tile, and a floor or a
# ceiling three tiles thick read as a test pattern that fought the crucible
# (independent grade, pass 565). A plate is now a whole tile: half the seams and
# a quarter of the rivets. The rivet and the bevel sit a step lower, rust runs
# from fewer rivets. A worn plate was a whole shade darker, and a plate the size
# of a tile made that a dark square a tile wide; it is now pitted instead, the
# body value with a share of its pixels a shade down.
PLATE = 16        # world pixels to a plate's side
PLATE_RIVET = 5   # the rivet head's step on the ramp (was 6)
PLATE_RUST = 0.9  # a rivet rusts above this (was 0.82)
WORN_PLATE = 0.8  # a plate is worn above this (Vorrhallow keeps WORN_BLOCK)
PLATE_PITTED = 0.72  # a worn plate's world pixel is pitted above this (0.96 on a sound one)
# Sheets longer than a tile (design bible 12.70, pass 583). A plate to a tile
# made the frame's grid the room's own tile grid, and a ceiling four tiles thick
# was graph paper (independent grade, pass 580: "tile repetition that shows the
# grid ... the Tower's ceilings"). Half the tiles of every set the factory
# scatters (the surface field, MID, DEEP, a floor's top and a ceiling's bottom)
# carry no west seam, so a sheet runs through them from the tile to their west.
# The 47 blob tiles keep their seam: a corner or a wall face always starts a sheet.
PLATE_WIDE_SEEDS = frozenset({202, 203, 102, 212, 104, 222, 62, 63, 72, 73})
# The share of Vorrhallow's tiles that carry the teal tide stain. Drawn in every
# tile it ruled a stripe across the field every 16 world pixels.
TIDE_TILES = 0.35
# build_tileset paints the 47 blob tiles with seeds 11 to 57 and the interior
# tiles (MID, DEEP and the row-7 variants) with seeds from 101. Only those carry
# the tide stain: an edge tile has no variants, so a stain on one repeats down
# every wall face and pillar.
INTERIOR_SEED = 101
# build_tileset paints the row-8 edge variants (12.53) with seeds from 61: edge
# tiles still, so they carry no tide stain and no field wear.
EDGE_SEED = 61


# The share of bricks that stand a shade proud (paint_bricks).
PROUD_BRICK = 0.92
# Set by paint_tile for the zone in hand: whether its brick grows moss.
BRICK_MOSS = False


# The seeds build_tileset gives the DEEP tier (two in row 6, two in row 7).
DEEP_SEEDS = frozenset({103, 104, 221, 222})
# The seed of the full-solid blob tile (the last of the 47): a field tile too.
FULL_SEED = 57


def drowned_block_is_worn(bx, row, seed):
    """Whether one of Vorrhallow's blocks is worn a shade (design bible 12.95).
    A field tile (FULL_SEED, or a seed from INTERIOR_SEED) wears only the half blocks of its
    lower course: the upper course is one block the width of the tile, and with
    four tiles to a tier a worn one made every fourth tile of a field a dark
    slab. The DEEP tier wears none, since a worn block there falls to the foot
    of the ramp and reads as a hole. The other 46 blob tiles are as they were."""
    if hash2(bx, row, seed) <= WORN_BLOCK:
        return False
    if seed in DEEP_SEEDS or seed in BLEND_DEEP_SEEDS:
        return False
    field = seed == FULL_SEED or seed >= INTERIOR_SEED
    return not field or row % 2 == 1


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


def footing(img, ox, oy, seed, mask, zone, ramp):
    """The floor's trim under the foot of a wall: an interior tile with solid
    above it and open air on an upper diagonal. With both diagonals open (a
    pillar one tile wide) it runs the whole tile; with one, it ends in a head
    joint on the side that goes on into the wall."""
    if not mask & N or not mask & E or not mask & W or (mask & NE and mask & NW):
        return False
    if not floor_trim(img, ox, oy, seed, 0, T, zone, ramp):
        return False
    joint = f"{ramp}-1" if zone in COURSE_ZONES else TRIM_TONES[zone][0][2]
    y0, y1 = COURSE_TOP * D, (COURSE_TOP + COURSE_ROWS) * D
    for side_open, x0 in ((mask & NE, T - FOOT_JOINT * D), (mask & NW, 0)):
        if side_open:  # this side is under the wall: close the trim here
            for x in range(x0, x0 + FOOT_JOINT * D):
                for y in range(y0, y1):
                    img.putpixel((ox + x, oy + y), c(joint))
    return True


# A trim of the zone's own material (design bible 12.53, pass 565). The string
# course gave the masonry zones one built line under a floor's cap; the zones
# that are not masonry (the Heartwood's bark, the Tower's iron, the Evercrown's
# cells, the Haar's limbs, the High Boughs) had none, and no zone had anything
# on the underside of a ceiling, so a thick floor or ceiling band was one tile
# from its cap to the screen's edge (independent grade, pass 560). Each entry:
# the lit line, the band and the shadow line of the floor's trim, then the same
# three for a ceiling's soffit, which sits in the shade and so a step or two down.
TRIM_KIND = {"heartwood": "rind", "boughs": "rind", "haar": "rind", "tower": "flange", "evercrown": "membrane"}
TRIM_TONES = {
    "heartwood": (("bark-4", "bark-3", "bark-0"), ("bark-3", "bark-2", "bark-0")),
    "boughs": (("bark-6", "bark-5", "bark-2"), ("bark-5", "bark-4", "bark-2")),
    "haar": (("umber-4", "umber-3", "umber-0"), ("umber-3", "umber-2", "umber-0")),
    "tower": (("stone-6", "stone-4", "night-0"), ("stone-4", "stone-3", "night-0")),
    # No night-3 here: that was the cells' old violet rim (12.50).
    "evercrown": (("sky-3", "sky-2", "night-0"), ("sky-2", "sky-1", "night-0")),
}
SOFFIT_ROWS = 3    # world px, sitting on the underside's dark lip
SOFFIT_BOTTOM = 2  # world px of outline and lip under it
RIVET_STEP = 8     # world px between the rivets of the Tower's flange


def trim_band(img, ox, oy, seed, x0, x1, zone, y0, tones):
    """Three world-pixel rows from render row ``y0``: a lit line, a band and a
    shadow line, in the zone's material.

    - a rind (wood): the bark rolls over in a lip, notched where two strands meet;
    - a flange (iron): a flat bar with a rivet every RIVET_STEP world pixels;
    - a membrane (the Evercrown): the cells fuse into a skin, pinched every 8 px.
    The lit and shadow lines run straight, so the trim joins from tile to tile
    whichever variant draws it."""
    lit, band, shadow = tones
    kind = TRIM_KIND[zone]
    seams = set(wood_strand_starts()) if kind == "rind" else ()
    if zone == "boughs":
        # The High Boughs' bark is plates (12.92): the lip is notched where a
        # furrow meets it, on the row of bark the trim lies against.
        row = y0 + 3 * D if y0 < T // 2 else y0 - 1
        seams = {x for x in range(T) if bough_plate(x, row) != bough_plate((x - 1) % T, row)}
    for x in range(x0, x1):
        wx = x // D
        for row, col in enumerate((lit, band, shadow)):
            if row == 1:
                if kind == "rind" and x > 1 and (x in seams or x - 1 in seams):
                    col = shadow                      # a notch between two strands
                elif kind == "flange" and wx % RIVET_STEP == RIVET_STEP // 2:
                    col = "stone-7"                   # a rivet head
                elif kind == "membrane" and wx % 8 == 0:
                    col = shadow                      # the skin pinched between two cells
            for dy in range(D):
                img.putpixel((ox + x, oy + y0 + row * D + dy), c(col))


def floor_trim(img, ox, oy, seed, x0, x1, zone, ramp):
    """The built or grown line under a floor's cap: the string course in a
    masonry zone, the zone's own trim elsewhere. False if the zone has none."""
    if zone in COURSE_ZONES:
        string_course(img, ox, oy, seed, x0, x1, ramp)
    elif zone in TRIM_KIND:
        trim_band(img, ox, oy, seed, x0, x1, zone, COURSE_TOP * D, TRIM_TONES[zone][0])
    else:
        return False
    return True


def soffit(img, ox, oy, seed, x0, x1, zone, ramp):
    """The same line on the underside of a ceiling, a step into the shade."""
    y0 = T - (SOFFIT_BOTTOM + SOFFIT_ROWS) * D
    if zone in COURSE_ZONES:
        for x in range(x0, x1):
            for row, col in enumerate((f"{ramp}-4", f"{ramp}-3", f"{ramp}-1")):
                if row == 1 and hash2(x // D, 5, 47) > 0.93:
                    col = f"{ramp}-2"                 # a butt joint
                for dy in range(D):
                    img.putpixel((ox + x, oy + y0 + row * D + dy), c(col))
    elif zone in TRIM_KIND:
        trim_band(img, ox, oy, seed, x0, x1, zone, y0, TRIM_TONES[zone][1])
    else:
        return False
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


# The Spires' ashlar (design bible 12.70): course heights in world px, top to
# bottom, summing to a tile; the share of whole blocks left sound; and the share
# of surface courses with no gold groove.
SHRINE_COURSES = (5, 6, 5)
SHRINE_WORN = 0.8
SHRINE_GOLD = 0.8
SHRINE_CRACK = 0.66


def shrine_joints(seed, course):
    """The head joints of one course of ``paint_shrine``, in render px: one at a
    seeded x 4 to 12 world px in, and in about four courses in ten a second, at
    least 6 world px from the first. As in ``spring_joints``, no joint sits
    within 4 world px of the tile's edge, so the nearest two joints across a tile
    seam are 8 apart and a block runs 6 to 24 world px."""
    j = 4 + int(hash2(seed, course, 93) * 9)               # 4..12 world px
    joints = [j * D]
    pair = [v for v in range(4, 13) if abs(v - j) >= 6]
    if pair and hash2(seed, course, 94) > 0.6:
        joints.append(pair[int(hash2(seed, course, 95) * len(pair))] * D)
    return sorted(joints)


def paint_shrine(img, ox, oy, seed, ramp):
    """Carillon's ruined elf shrines: big pale ashlar blocks, weathered and
    cracked, some still carrying a groove of gold inlay along their face.

    The courses are the same in every tile and the blocks run through the tile
    seams (design bible 12.70, pass 583). The older painter keyed the block's
    width and height to the seed (12.8), so two scattered variants side by side
    met with their bed joints at different heights and their blocks cut off at
    the seam: every tile was a patch with a straight edge, and the wall showed
    the 16 px grid it was built on (independent grade, pass 580). Now:

    - three courses to a tile (``SHRINE_COURSES``, 5, 6 and 5 world px), at the
      same heights in every tile, so a bed joint runs the length of a wall;
    - one or two head joints per course (``shrine_joints``), keyed to the seed
      and never near the tile's edge, so the tile wraps on itself sideways and a
      block passes through the seam into whichever variant is next;
    - one body value (12.46). Only a block that lies whole inside the tile may
      be worn a shade (``SHRINE_WORN``), since a block cut by the seam belongs
      to two tiles;
    - the gold inlay (surface tiles only, 12.46) is a groove in one stretch of
      a course, ending short of the joints and of the tile's edge."""
    gold = not is_interior(seed)  # the inlay is surface dressing (bible 12.46)
    y0 = 0
    for course, rows in enumerate(SHRINE_COURSES):
        ch = rows * D
        joints = shrine_joints(seed, course)
        # The stretches of this course inside the tile: the first and the last
        # are the two ends of blocks that cross the seam.
        cuts = [0] + joints + [T]
        spans = list(zip(cuts[:-1], cuts[1:]))
        worn = len(joints) == 2 and hash2(seed, course, 96) > SHRINE_WORN
        groove = None
        if gold and hash2(seed, course, 97) > SHRINE_GOLD:
            a, b = max(spans, key=lambda sp: sp[1] - sp[0])
            groove = (a + 3 * D, b - 3 * D)
        for ly in range(ch):
            for x in range(T):
                lx = min((x - j) % T for j in joints)          # 0 at a joint
                shade = 3 if worn and joints[0] <= x < joints[1] else 4
                if ly == ch - 1 or lx == 0:
                    col = f"{ramp}-1"
                elif ly == 0 or lx == 1:
                    col = f"{ramp}-{shade + 1}"
                elif ly == ch - 2:
                    col = f"{ramp}-{shade - 1}"
                else:
                    col = f"{ramp}-{shade}"
                    if hash2(x // 2, (y0 + ly) // 2, seed + 5) > 0.9:
                        col = f"{ramp}-{shade - 1}"
                if groove and ly == ch // 2 and groove[0] <= x < groove[1]:
                    col = "gold-4" if x % 4 else "gold-5"
                img.putpixel((ox + x, oy + y0 + ly), c(col))
        y0 += ch
    # A crack or two, running down and sideways.
    # A crack in about one tile in three (SHRINE_CRACK). Two tries at 0.55 each
    # cracked seven tiles in ten, and with the blocks joined up the cracks were
    # the mark on a beat.
    if hash2(seed, 0, 31) > SHRINE_CRACK:
        crack(img, ox, oy, seed, 0, c(f"{ramp}-1"))


def paint_drowned(img, ox, oy, seed, ramp):
    """Vorrhallow's drowned masonry: squat dwarven blocks, dark and water-worn,
    a teal tide stain on some where the flood stood, and veins of magenta
    stillglass forcing their way through the joints of some blocks. The blocks
    share one body value; the odd one is worn a shade darker (WORN_BLOCK)."""
    bw, bh = 16 * D, 8 * D
    # A blend (12.99) carries none: its blocks stand in two tiers, and a stain
    # line across both reads as a dashed rule.
    tide = INTERIOR_SEED <= seed < BLEND_SEED and hash2(seed, 7, 31) < TIDE_TILES
    for y in range(T):
        row = y // bh
        for x in range(T):
            sx = x + (row % 2) * (bw // 2)
            bx, ly, lx = sx // bw, y % bh, sx % bw
            shade = 2 if drowned_block_is_worn(bx, row, seed) else 3
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
# The Evercrown's cells take their light from the cyan pores (design bible 12.50,
# pass 560): the body stays black-violet (the zone's ramp), and the lit upper rim
# and the cool seams are on the sky ramp at the values the night ramp had there.
# The tile's hue then sits a step further from the wine backdrop (12.48) without
# a colour off the master palette. The warm seams stay wine (crystal-1).
MEAT_RIM = "sky-3"
MEAT_SEAM_COOL = "sky-1"
MEAT_SEAM_WARM = "crystal-1"
MEAT_EDGE_PORE = 0.55


def paint_meteor(img, ox, oy, seed, ramp):
    """the Evercrown, the inside of the Everbloom: organic stone grown in rounded cells
    like a honeycomb of scar tissue, black-violet, with wine-dark sinew and cool
    shadow in the seams, the odd pore of alien cyan light, and that light on the
    upper rim of every cell (12.50).

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
    # The cells are the same in every tile, so only the pores tell one tile from
    # another. An edge variant (12.53) opens more of them, or a ceiling's three
    # bottom tiles would be three copies.
    pore = MEAT_EDGE_PORE if EDGE_SEED <= seed < INTERIOR_SEED else 0.95
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
                # Wine sinew, not red: in the Evercrown the ember ramp belongs to
                # what hurts (bible 12.48).
                col = MEAT_SEAM_WARM if hash2(gx + gy, 0, MEAT_CELLS + 4) > 0.55 else MEAT_SEAM_COOL
            elif edge < 2.0 * D and y < py:
                col = MEAT_RIM   # the lit upper rim of the cell, in the pores' light
            else:
                col = f"{ramp}-{shade}"
            if d1 < 1.0 * D and hash2(gx, gy, seed + 6) > pore:
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
    spring_wear(img, ox, oy, seed, ramp)


# Wear on the Sunken Spring's ashlar (design bible 12.55, pass 568). The pass 565
# grade: "brick repeats uniformly with no edge wear or moss". Only tiles that have
# variants carry a mark (12.47): the scattered field variants, and the row-8
# variant of each wall face (12.53), so nothing repeats down a pier.
# - A chipped arris: the lit corner of one block, at its head joint, broken away.
# - A hairline crack, as in the other masonry (FIELD_CRACK).
# - Moss in a bed joint: a clump a few world pixels long, creeping up over the
#   block's shadow and hanging a pixel or two below. On two of the three surface
#   variants and both face variants; the darkened tiers grow none (12.47).
SPRING_CHIP = 0.45
SPRING_FACE_SEEDS = (81, 82)
SPRING_MOSS_SEEDS = (201, 203) + SPRING_FACE_SEEDS
SPRING_MOSS = "moss"


def spring_wear(img, ox, oy, seed, ramp):
    if seed < INTERIOR_SEED and seed not in SPRING_FACE_SEEDS:
        return
    W = T // D  # the tile in world pixels

    def wp(wx, wy, name):
        if 0 <= wy < W:
            for dy in range(D):
                for dx in range(D):
                    img.putpixel((ox + (wx * D + dx) % T, oy + wy * D + dy), c(name))

    if hash2(seed, 0, 71) > SPRING_CHIP:
        course = int(hash2(seed, 1, 71) * (W // SPRING_COURSE))
        j = spring_joints(seed, course)[0] // D
        n = 2 + int(hash2(seed, 2, 71) * 2)                      # 2 or 3 world px
        for wy in range(n):
            for wx in range(n - wy):
                wp(j + 1 + wx, course * SPRING_COURSE + wy, f"{ramp}-1")
        # The broken face under the chip catches a little shade.
        for wx in range(n):
            wp(j + 1 + wx, course * SPRING_COURSE + n - wx, f"{ramp}-3")
    if seed >= INTERIOR_SEED and hash2(seed, 0, 31) > FIELD_CRACK:
        crack(img, ox, oy, seed, 0, c(f"{ramp}-1"))
    if seed in SPRING_MOSS_SEEDS:
        n = 4 + int(hash2(seed, 1, 72) * 4)                      # 4 to 7 world px
        mx = 2 + int(hash2(seed, 2, 72) * (W - n - 4))
        bed = SPRING_COURSE - 1 if hash2(seed, 3, 72) > 0.5 else 2 * SPRING_COURSE - 1
        for i in range(n):
            wp(mx + i, bed, f"{SPRING_MOSS}-3")
            if 0 < i < n - 1 and hash2(seed, i, 73) > 0.35:
                wp(mx + i, bed - 1, f"{SPRING_MOSS}-4")
            drop = int(hash2(seed, i, 74) * 3)                    # 0 to 2 world px
            for k in range(drop):
                wp(mx + i, bed + 1 + k, f"{SPRING_MOSS}-{2 if k == drop - 1 else 3}")


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


# The Heartwood's shared grain (12.126): streaks as (x, y, length, widest, lean)
# in world cells of the 16-cell tile. They wrap over the tile's edges, so the
# grain runs on from a tile into the ones beside and below it. Uneven on purpose.
WOOD_GRAIN = ((1, 3, 13, 2, 1), (6, 11, 10, 1, -1), (9, 0, 14, 2, 1), (13, 8, 11, 2, -1), (4, 14, 8, 1, 1),
              (15, 6, 12, 2, 1), (0, 12, 9, 1, -1))
WOOD_SEED_LENSES = 3   # streaks of a tile's own, inside it


def wood_lens_cells(lens):
    """The world cells of one grain streak: (x, y, w) for each row, where the
    streak covers columns x .. x + w - 1. A streak tapers from a point at each
    end to its widest at the middle and leans one cell over its length."""
    x0, y0, length, widest, lean = lens
    rows = []
    for k in range(length):
        t = (k + 0.5) / length
        w = max(1, round(widest * math.sin(math.pi * t)))
        x = x0 + round(lean * t) - (w - 1) // 2
        rows.append((x, y0 + k, w))
    return rows


def wood_seed_lenses(seed):
    """The tile's own streaks: they stay inside the tile, so they meet no seam."""
    lenses = []
    for i in range(WOOD_SEED_LENSES):
        length = 5 + int(hash2(seed, i, 31) * 7)
        widest = 1 + int(hash2(seed, i, 32) * 2)
        x0 = 2 + int(hash2(seed, i, 33) * (T // D - 5))
        y0 = 1 + int(hash2(seed, i, 34) * (T // D - length - 1))
        lean = 1 if hash2(seed, i, 35) > 0.5 else -1
        lenses.append((x0, y0, length, widest, lean))
    return lenses


def wood_strand_starts(row=None):
    """The render columns where a grain streak of the shared layout reaches a
    world row (a trim lip is notched there). ``row`` defaults to the row just
    under the floor trim."""
    row = (COURSE_TOP + 3) if row is None else row
    out = []
    for lens in WOOD_GRAIN:
        for x, y, w in wood_lens_cells(lens):
            if y % (T // D) == row:
                out.append((x % (T // D)) * D)
    return sorted(set(out))


def paint_wood(img, ox, oy, seed, ramp, lo=1):
    """Living wood: one body value cut by grain streaks a shade darker that
    taper at both ends and stop, a lit west edge on the odd streak, and the
    rare knot.

    Calm fill (design bible 12.28, pass 534) and no barcode (12.126, pass 650):
    the face was strands of two values from the top of a wall to its foot, a
    stripe on a fixed beat that the grade of pass 645 read as "barcode stripes".
    A streak now runs 5 to 14 world pixels and ends; the shared streaks
    (WOOD_GRAIN) wrap over the tile's edges so the grain runs on across every
    seam, and the tile's own (wood_seed_lenses) stay inside it."""
    W = T // D
    body, grain, lit = lo + 1, lo, lo + 2

    def put(wx, wy, step):
        for dy in range(D):
            for dx in range(D):
                img.putpixel((ox + (wx % W) * D + dx, oy + (wy % W) * D + dy), c(f"{ramp}-{step}"))

    for y in range(W):
        for x in range(W):
            put(x, y, body)
    lenses = list(WOOD_GRAIN) + wood_seed_lenses(seed)
    for i, lens in enumerate(lenses):
        rows = wood_lens_cells(lens)
        # Only a tile's own streaks catch the light: a shared one crosses a seam,
        # where the next tile's seed would cut its lit edge off. One a tile at least.
        shine = i >= len(WOOD_GRAIN) and (hash2(seed, i, 36) > 0.6 or i == len(WOOD_GRAIN))
        for k, (x, y, w) in enumerate(rows):
            for dx in range(w):
                put(x + dx, y, grain)
            if shine and 0 < k < len(rows) - 1 and w >= 2:
                put(x - 1, y, lit)         # the light, from the upper left
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


# The High Boughs' bark (design bible 12.92, pass 615). The boughs shared the
# Heartwood's strands two shades up: columns of two values from the top of a
# wall to its foot, which the independent grade read as "flat vertical brown
# stripes" (pass 610). A bough's bark is now plates of one body value, cut by
# dark furrows that fork and join, and no furrow runs straight for longer than a
# plate. A plate is the ground nearest one of BOUGH_PLATES' points (a step across
# counts BOUGH_STRETCH times a step down, so a plate is tall). The points are
# uneven on purpose: evenly spread they made a honeycomb. The layout is the same
# in every tile and wraps at its edges, so a plate runs on across every seam;
# the seed varies only the marks laid on the plates (a check, a lit edge, a
# sprig), which cannot show at a seam.
BOUGH_PLATES = ((11, 18), (2, 18), (5, 0), (23, 15), (31, 9), (19, 19))
BOUGH_STRETCH = 2.5   # a step across a plate counts as this many steps down it
BOUGH_CHECK = 0.75    # a plate carries a check above this
BOUGH_LIT = 0.55      # a plate's west edge is lit above this


def bough_plate(x, y):
    """The plate of BOUGH_PLATES a tile's pixel lies on (the layout wraps)."""
    best, at = None, 0
    for i, (px, py) in enumerate(BOUGH_PLATES):
        dx = min((x - px) % T, (px - x) % T) * BOUGH_STRETCH
        dy = min((y - py) % T, (py - y) % T)
        d = dx * dx + dy * dy
        if best is None or d < best:
            best, at = d, i
    return at


def bough_furrow(x, y):
    """True where a furrow runs: the pixel east, south or south-east is another
    plate's. The diagonal keeps a slanted furrow one joined line: without it a
    furrow that steps a pixel a row is a string of pixels touching at corners."""
    here = bough_plate(x, y)
    return any(bough_plate((x + dx) % T, (y + dy) % T) != here for dx, dy in ((1, 0), (0, 1), (1, 1)))


def paint_bough(img, ox, oy, seed, ramp, lo=3):
    """A sunlit bough high in the canopy: plates of bark two shades lighter
    than the Heartwood's wood, and the odd sprig of young leaves.

    Calm fill (design bible 12.28 and 12.45): a plate is one flat value, the
    furrows are one pixel wide and every mark on a plate is a line. The first
    face drew a sine grain down every column ("striped dirt", pass 550); the
    second shared paint_wood's strands ("vertical brown stripes", pass 610)."""
    for y in range(T):
        for x in range(T):
            col = lo - 1 if bough_furrow(x, y) else lo + 1
            img.putpixel((ox + x, oy + y), c(f"{ramp}-{col}"))
    for i, (px, py) in enumerate(BOUGH_PLATES):
        # A check: a short crack down the middle of a plate.
        if hash2(seed, i, 24) > BOUGH_CHECK:
            cx = px + int(hash2(seed, i, 25) * 5) - 2
            y0 = py - 5 + int(hash2(seed, i, 26) * 4)
            for y in range(y0, y0 + 4 + int(hash2(seed, i, 27) * 5)):
                if bough_plate(cx % T, y % T) == i and not bough_furrow(cx % T, y % T):
                    img.putpixel((ox + cx % T, oy + y % T), c(f"{ramp}-{lo - 1}"))
        # A lit edge: the plate's west side catches the sun for a few pixels.
        if hash2(seed, i, 28) > BOUGH_LIT:
            y0 = py - 4 + int(hash2(seed, i, 29) * 4)
            for y in range(y0, y0 + 4 + int(hash2(seed, i, 30) * 4)):
                for x in range(px - T // 2, px):
                    if bough_plate(x % T, y % T) == i and not bough_furrow(x % T, y % T):
                        img.putpixel((ox + x % T, oy + y % T), c(f"{ramp}-{lo + 2}"))
                        break
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
    """Dwarven iron: one square plate of 16x16 world pixels to a tile (PLATE,
    design bible 12.54), bevelled and lit from the top left, a dim rivet at each
    corner, and rust bleeding down from the odd rivet. Every plate has one body
    value; the odd one is worn, pitted with the shade below (WORN_PLATE).

    A tile in ``PLATE_WIDE_SEEDS`` has no seam, bevel or rivets on its west side
    (design bible 12.70): the sheet of the tile to its west runs on through it.
    The factory scatters these among the others, so a course of plates is made
    of sheets one, two and three tiles long, with no joint on a fixed beat."""
    pw = PLATE * D
    wide = seed in PLATE_WIDE_SEEDS
    for y in range(T):
        for x in range(T):
            px, py = x // pw, y // pw
            lx, ly = x % pw, y % pw
            worn = hash2(px + ox // T * 2, py + oy // T * 2, seed) > WORN_PLATE
            shade = 3
            if ly == 0 or (lx == 0 and not wide):
                col = f"{ramp}-1"
            elif ly == 1 or (lx == 1 and not wide):
                col = f"{ramp}-{shade + 1}"
            elif lx == pw - 1 or ly == pw - 1:
                col = f"{ramp}-{shade - 1}"
            else:
                col = f"{ramp}-{shade}"
                # Brushed grain across the plate.
                if (y * 7 + x // 5) % 13 == 0:
                    col = f"{ramp}-{shade + 1}"
                elif hash2(x // D, y // D, seed + 2) > (PLATE_PITTED if worn else 0.96):
                    col = f"{ramp}-{shade - 1}"
            img.putpixel((ox + x, oy + y), c(col))
    for py in range(T // pw):
        for px in range(T // pw):
            for rx, ry in [(3, 3), (pw - 4, 3), (3, pw - 4), (pw - 4, pw - 4)]:
                if wide and rx == 3:
                    continue  # no joint here, so nothing to rivet
                x, y = px * pw + rx, py * pw + ry
                img.putpixel((ox + x, oy + y), c(f"{ramp}-{PLATE_RIVET}"))
                img.putpixel((ox + x + 1, oy + y + 1), c(f"{ramp}-1"))
                if hash2(x, y, seed + 5) > PLATE_RUST:
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
        if mask & N:  # a ceiling, not a ledge one tile thick: its soffit
            soffit(img, ox, oy, seed, 0 if mask & W else D + 2, T if mask & E else T - D - 2, zone, ramp)
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
        floor_trim(img, ox, oy, seed, x0, x1, zone, ramp)
    else:
        footing(img, ox, oy, seed, mask, zone, ramp)
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
    # The Heartwood's boards are old grey timber, not the town's fresh bark (pass 637).
    "heartwood": {"wood": "moss", "nail": "gold-4", "strut": "moss"},
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
# left, with sinew (crystal-1, wine: bible 12.48) in the seams, a cyan pore in some segments, a thin
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
                out[(wx, wy)] = "crystal-1"  # wine, not red (bible 12.48)
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


def paint_haunch(img, ox, oy, zone, west, seed):
    """A haunch (design bible 12.78): the ceiling's slope, where a vault curves
    down into its wall. The zone's ceiling tile (soffit and all), sheared up
    column by column so its underside runs along the diagonal: solid above it,
    clear below. ``west`` keeps the top-left half (a west wall meets the
    ceiling); otherwise the top-right half."""
    tmp = Image.new("RGBA", (T, T), CLEAR)
    paint_tile(tmp, 0, 0, EDGE_BOTTOM, zone, seed)
    for x in range(T):
        # How many pixels this column's underside rises from the tile's foot.
        rise = x if west else T - 1 - x
        for y in range(T):
            sy = y + rise
            img.putpixel((ox + x, oy + y), tmp.getpixel((x, sy)) if sy < T else CLEAR)
    # A dark outline one world pixel thick just under the soffit, as the floor
    # slope has above its cap, so the diagonal reads against the open air.
    out = c(ZONES[zone]["outline"])
    for x in range(T):
        rise = x if west else T - 1 - x
        for k in range(1, D):
            if T - rise - 1 + k < T:
                img.putpixel((ox + x, oy + T - rise - 1 + k), out)


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

# --- A fill grows in patches (design bible 12.90, pass 613) ---------------------
# Hearthroot's fill was one 128 px texture with roots and moss across every block,
# so a wall showed the same growth every four tiles (independent grade, pass 610:
# "one vine overlay on every block"). The fill is now FILL_REPEAT copies a side,
# and the growth lives only where a slow seamless noise is high: elsewhere a root
# is carved stone (its own shape, in the stone's tones) and the moss is gone.
FILL_REPEAT = 4          # copies of the source a side: the fill repeats every 16 tiles
FILL_PATCH = 128         # px: the size of a patch of growth
FILL_BARE = 0.40         # below this the roots are stone too
FILL_MOSS = 0.50         # below this the moss is stone; the roots stay alive
FILL_DROP = 0.8          # a carved root sits a little under the stone's face


def is_growth(p):
    """A root, a leaf or moss in a fill texture: its blue is well under its red or
    green. Stone and mortar are grey-violet, so their blue keeps up."""
    m = max(p[0], p[1])
    return m > 35 and p[2] < 0.72 * m


def is_leaf(p):
    """Moss or a leaf (green or olive), against a brown root."""
    return is_growth(p) and p[1] >= p[0] - 14


def _lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def _loop_noise(x, y, seed, cell, cells):
    """Smooth value noise that wraps after `cells` cells of `cell` px."""
    fx, fy = x / cell, y / cell
    ix, iy = int(fx), int(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)

    def v(a, b):
        return hash2(a % cells, b % cells, seed)
    top = v(ix, iy) * (1 - tx) + v(ix + 1, iy) * tx
    bottom = v(ix, iy + 1) * (1 - tx) + v(ix + 1, iy + 1) * tx
    return top * (1 - ty) + bottom * ty


def fill_growth(x, y, size, seed=5):
    """How alive the fill is at a pixel, 0 to 1: patches FILL_PATCH across with a
    finer wobble and a grain at the edge, seamless over `size` px."""
    n = 0.75 * _loop_noise(x, y, seed, FILL_PATCH, size // FILL_PATCH)
    n += 0.25 * _loop_noise(x, y, seed + 1, FILL_PATCH // 4, size // (FILL_PATCH // 4))
    return n + (hash2(x, y, seed + 2) - 0.5) * 0.06


def grown_fill(src):
    """`src` (a seamless square texture) FILL_REPEAT times a side, alive in patches."""
    src = src.convert("RGBA")
    w = src.width
    assert src.height == w and w % FILL_PATCH == 0
    px = src.load()
    stone = sorted({px[x, y] for x in range(w) for y in range(w)
                    if not is_growth(px[x, y]) and px[x, y][2] >= px[x, y][1] - 2}, key=_lum)
    carved = {}
    size = w * FILL_REPEAT
    out = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            p = px[x % w, y % w]
            if is_growth(p):
                n = fill_growth(x, y, size)
                if n < FILL_BARE or (n < FILL_MOSS and is_leaf(p)):
                    if p not in carved:
                        target = _lum(p) * FILL_DROP
                        carved[p] = min(stone, key=lambda s: abs(_lum(s) - target))
                    p = carved[p]
            out.putpixel((x, y), p)
    return out



# Patches of other stone (design bible 12.91, pass 614). A zone's field was laid
# in one coursing from wall to wall: the scattered variants move the joints, but
# every tile has the same course heights, so a wall thirty tiles long was one
# texture (independent grade, pass 610: "uniform brick fills", the Flooded Hall,
# the storm ledge and the aqueduct). Each of those zones now has a second
# coursing, laid in stretches a few tiles tall and several wide where a slow
# noise is high (TilesetFactory.in_patch), as a wall rebuilt in another century:
# - Vorrhallow's squat blocks (16 by 8 world px) give way to small brick, four
#   courses to a tile;
# - the Spires' three courses of ashlar give way to two courses of great blocks,
#   with no gold;
# - the Sunken Spring's two courses give way to three thin ones.
# ``courses``: heights in world px, top to bottom, summing to a tile. ``joint``,
# ``body``: the joint's color and the body's step on the zone's ramp. ``thick``:
# a joint's and a highlight's thickness in render px, as the zone's own painter
# draws them. ``pit``: the share of the body's pixels left unpitted (None: calm).
# ``bricks``: two head joints a course, half a tile apart, in a running bond.
PATCHES = {
    "vorrhallow": {"courses": (4, 4, 4, 4), "joint": "night-1", "body": 3, "thick": 1, "pit": 0.88, "bricks": True},
    "spires": {"courses": (8, 8), "joint": "stone-1", "body": 4, "thick": 1, "pit": 0.9, "bricks": False, "pair": 2.0},
    "sunken": {"courses": (5, 6, 5), "joint": "umber-1", "body": 4, "thick": D, "pit": None, "bricks": False, "pair": 0.6},
}
PATCH_VARIANTS = 2
PATCH_ROW = 10
PATCH_SEED = 301


def patch_joints(spec, seed, course):
    """The head joints of one course of a patch tile, in render px. None sits
    within 2 world px of the tile's edge, so inside a patch a block runs through
    the seam into the next tile, and a joint drawn at the edge (where the patch
    ends) never makes a sliver."""
    if spec["bricks"]:
        # 2 to 6 world px in, three steps on from the course above: a running bond.
        j = 2 + (course * 3 + int(hash2(seed, 0, 131) * 5)) % 5
        return [j * D, (j + 8) * D]
    j = 4 + int(hash2(seed, course, 132) * 9)               # 4..12 world px
    joints = [j * D]
    pair = [v for v in range(4, 13) if abs(v - j) >= 6]
    if pair and hash2(seed, course, 133) > spec["pair"]:
        joints.append(pair[int(hash2(seed, course, 134) * len(pair))] * D)
    return sorted(joints)


def paint_patch(img, ox, oy, zone, seed, west_end=False, east_end=False):
    """One tile of a zone's patch: its second coursing, in the zone's own tones
    (one body value, lit from the upper left). ``west_end`` and ``east_end``
    close the blocks with a head joint at that edge, for the tile where the
    patch stops against the zone's usual stone."""
    spec = PATCHES[zone]
    ramp = ZONES[zone]["ramp"]
    t, body = spec["thick"], spec["body"]
    joint, lit, shade = spec["joint"], f"{ramp}-{body + 1}", f"{ramp}-{body - 1}"
    y0 = 0
    for course, rows in enumerate(spec["courses"]):
        ch = rows * D
        joints = patch_joints(spec, seed, course) + ([0] if west_end else [])
        for ly in range(ch):
            for x in range(T):
                lx = min((x - j) % T for j in joints)          # 0 at a joint
                rx = min((j - x - 1) % T for j in joints)      # 0 just before one
                if ly >= ch - t or lx < t or (east_end and x >= T - t):
                    col = joint
                elif ly < t or lx < 2 * t:
                    col = lit
                elif ly >= ch - 2 * t or (t > 1 and rx < t):
                    col = shade
                else:
                    col = f"{ramp}-{body}"
                    if spec["pit"] and hash2(x // 2, (y0 + ly) // 2, seed + 5) > spec["pit"]:
                        col = shade
                img.putpixel((ox + x, oy + y0 + ly), c(col))
        y0 += ch


def paint_patches(img, zone):
    """Rows 10 to 12 of a zone's atlas: the surface tier, MID and DEEP. In each,
    two variants of four tiles: no end joint, west, east, and both."""
    for tier in range(3):
        for v in range(PATCH_VARIANTS):
            for ends in range(4):
                ox, oy = (v * 4 + ends) * T, (PATCH_ROW + tier) * T
                paint_patch(img, ox, oy, zone, PATCH_SEED + 10 * tier + v, bool(ends & 1), bool(ends & 2))
                if tier:
                    darken(img, ox, oy, tier)


# Blends between the tiers (design bible 12.99, pass 623). A wall's tiers were
# three flat values that met along the tile grid, a whole shade a step, so the
# shade inside a wall was a stair of rectangles (independent grade, pass 620:
# "large rectangular dark blotches and stair-stepped tone patches that read as
# tile errors"). Row 9, cols 2 to 7, holds field tiles in which each block (a
# brick, a plate of bark, a board: a stretch of body bounded by joints) stands
# in one of two neighbouring tiers. The factory draws them where two tiers
# meet, so a tier ends block by block, as stone weathers, and not on the grid.
BLEND_ROW = 9
BLEND_COL = 2
BLEND_VARIANTS = 3
BLEND_SEED = 231          # 231 to 233: surface and MID; 234 to 236: MID and DEEP
# A pixel is a joint if it is this much darker than the tile's commonest color.
BLEND_JOINT = 0.72
# A block bigger than this share of the tile (wood with open grain, a plate with
# no seam) is cut into blobs on a lattice of BLEND_CELL render px.
BLEND_BIG = 0.3
BLEND_CELL = 8
# The seeded draws of dark blocks paint_blend chooses from.
BLEND_TRIES = 400
# How far from half a draw's dark share may stand, in the tile and in each half.
BLEND_SLACK = 0.15
# The least share of a tile's pixels by which two blends of a tier differ in tier.
BLEND_APART = 0.2
# The seeds whose blocks may reach the DEEP tier: no worn blocks (12.95).
BLEND_DEEP_SEEDS = frozenset({234, 235, 236})


def _lum3(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _blend_blob(x, y, seed):
    """True in the soft-edged blobs a big block is cut into: a value noise on a
    lattice of BLEND_CELL render px, read a world pixel at a time."""
    fx, fy = (x // D * D + D / 2) / BLEND_CELL, (y // D * D + D / 2) / BLEND_CELL
    x0, y0 = math.floor(fx), math.floor(fy)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = hash2(x0, y0, seed) + (hash2(x0 + 1, y0, seed) - hash2(x0, y0, seed)) * tx
    b = hash2(x0, y0 + 1, seed) + (hash2(x0 + 1, y0 + 1, seed) - hash2(x0, y0 + 1, seed)) * tx
    return a + (b - a) * ty > 0.5


def tile_blocks(img, ox, oy, seed, joints=True):
    """Labels a painted tile's blocks: {(x, y): label} for every pixel. A block
    is a stretch of body joined edge to edge, bounded by the joints (pixels much
    darker than the tile's commonest color); a joint pixel takes the label of
    the block nearest it. A block bigger than BLEND_BIG of the tile is cut into
    soft-edged blobs, so open grain and a plate with no seam break up too.
    ``joints`` False: the material has none (wood, 12.126: its grain is darker
    but parts nothing), so the whole tile is one block, cut into blobs."""
    px = {(x, y): img.getpixel((ox + x, oy + y)) for y in range(T) for x in range(T)}
    counts = {}
    for v in px.values():
        counts[v] = counts.get(v, 0) + 1
    body = _lum3(max(counts, key=counts.get))
    joint = {k for k, v in px.items() if joints and _lum3(v) < BLEND_JOINT * body}
    label, n = {}, 0
    for start in px:
        if start in joint or start in label:
            continue
        stack, members = [start], []
        label[start] = n
        while stack:
            x, y = stack.pop()
            members.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in px and q not in joint and q not in label:
                    label[q] = n
                    stack.append(q)
        if len(members) > BLEND_BIG * T * T:
            # Each blob is a block of its own (pass 650): wood with no joints at
            # all (12.126) is one block, and two halves of noise were too few
            # for a blend to balance its tiers in every half.
            side = {q: _blend_blob(q[0], q[1], seed + n) for q in members}
            blob = {}
            for q0 in members:
                if q0 in blob:
                    continue
                blob[q0] = len(blob)
                k, stack = blob[q0], [q0]
                while stack:
                    x, y = stack.pop()
                    label[(x, y)] = (n, k)
                    for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if q in side and q not in blob and side[q] == side[q0]:
                            blob[q] = k
                            stack.append(q)
        n += 1
    if not label:
        return {k: 0 for k in px}
    todo = set(joint)
    while todo:                     # grow the blocks over the joints
        grown = {}
        for (x, y) in todo:
            for q in ((x - 1, y), (x, y - 1), (x + 1, y), (x, y + 1)):
                if q in label:
                    grown[(x, y)] = label[q]
                    break
        if not grown:
            for k in todo:
                label[k] = 0
            break
        label.update(grown)
        todo -= set(grown)
    return label


def zone_has_joints(zone):
    """False for wood (12.126): its grain is darker but parts no blocks."""
    return ZONES[zone]["painter"] not in (paint_wood, paint_limb)


def paint_blend(img, ox, oy, zone, seed, steps, taken=()):
    """A field tile whose blocks stand `steps` or `steps + 1` shades down, half
    the tile's area each, chosen block by block. Returns the dark pixels;
    ``taken``: those of the tier's other blends, which this one stands apart from."""
    paint_tile(img, ox, oy, 255, zone, seed)
    blocks = tile_blocks(img, ox, oy, seed, zone_has_joints(zone))
    # Each block's area in the whole tile and in its west, east, upper and lower
    # halves. Of up to BLEND_TRIES seeded draws, the first whose dark blocks come
    # within BLEND_SLACK of half of all five wins (or the nearest, if none
    # does): a blend stands midway between its tiers, and no half of it is one
    # tier, so a tier never ends on a line a tile long.
    h = T // 2
    area = {}
    for (x, y), lab in blocks.items():
        a = area.setdefault(lab, [0, 0, 0, 0, 0])
        a[0] += 1
        a[1 if x < h else 2] += 1
        a[3 if y < h else 4] += 1
    labels = sorted(area, key=repr)
    total = [T * T, T * h, T * h, T * h, T * h]
    best, dark, dark_cells = None, frozenset(), frozenset()
    for k in range(BLEND_TRIES):
        pick = frozenset(lab for i, lab in enumerate(labels) if hash2(i, k, seed + 17) > 0.5)
        cells = frozenset(q for q, lab in blocks.items() if lab in pick)
        if any(len(cells ^ t) < BLEND_APART * T * T for t in taken):
            continue                # a stone of few blocks: not the same draw twice
        score = max(abs(sum(area[lab][p] for lab in pick) / total[p] - 0.5) for p in range(5))
        if best is None or score < best:
            best, dark, dark_cells = score, pick, cells
        if score <= BLEND_SLACK:    # near enough: the first such draw, so the
            break                   # three blends of a kind are three tiles
    names = {v[:3]: k for k, v in PAL.items()}
    for (x, y), lab in blocks.items():
        down = steps + (1 if lab in dark else 0)
        px = img.getpixel((ox + x, oy + y))
        name = names.get(px[:3])
        if name is None or px[3] == 0 or down == 0:
            continue
        ramp, i = name.rsplit("-", 1)
        j = int(i) - down
        img.putpixel((ox + x, oy + y), c("night-0") if j < 0 else c(f"{ramp}-{j}"))
    return dark_cells


def paint_blends(img, zone):
    """Row 9, cols 2 to 7: three blends of the surface and MID tiers, then three
    of MID and DEEP."""
    for tier in range(2):
        taken = []
        for v in range(BLEND_VARIANTS):
            k = tier * BLEND_VARIANTS + v
            taken.append(paint_blend(img, (BLEND_COL + k) * T, BLEND_ROW * T, zone, BLEND_SEED + k, tier, taken))


EDGE_VARIANTS = 3
EDGE_TOP = 255 & ~(N | NE | NW)       # a floor's top tile
EDGE_BOTTOM = 255 & ~(S | SE | SW)    # a ceiling's bottom tile
EDGE_WEST = 255 & ~(W | NW | SW)      # a wall's west face
EDGE_EAST = 255 & ~(E | NE | SE)      # a wall's east face


def build_tileset(zone):
    if zone in PIXELLAB_SETS:
        import pixellab_tileset
        cfg = PIXELLAB_SETS[zone]
        TILES.mkdir(parents=True, exist_ok=True)
        pixellab_tileset.atlas(cfg["set"], cfg["fill"], TILES / f"{zone}.png", cfg["ledge"])
        grown_fill(Image.open(cfg["fill"])).save(TILES / f"{zone}_fill.png")
        return
    masks = blob_masks()
    assert len(masks) == 47
    img = Image.new("RGBA", (T * COLS, T * (13 if zone in PATCHES else 10)), CLEAR)
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
    # Row 8: edge variants (design bible 12.53, pass 565). A floor's top tile, a
    # ceiling's bottom tile and a wall's two faces were each one tile, repeated
    # the length of the room. Each gets fresh seeds (under INTERIOR_SEED, so they
    # are painted as edge tiles); the factory scatters them by cell.
    for k in range(EDGE_VARIANTS):
        paint_tile(img, k * T, 8 * T, EDGE_TOP, zone, 61 + k)
        paint_tile(img, (3 + k) * T, 8 * T, EDGE_BOTTOM, zone, 71 + k)
    paint_tile(img, 6 * T, 8 * T, EDGE_WEST, zone, 81)
    paint_tile(img, 7 * T, 8 * T, EDGE_EAST, zone, 82)
    # Row 9: the two haunches (design bible 12.78, pass 591), the ceiling's
    # slopes, so a vault curves down into its wall instead of stepping.
    paint_haunch(img, 0, 9 * T, zone, True, 91)
    paint_haunch(img, T, 9 * T, zone, False, 92)
    # Row 9, cols 2 to 7: the blends between the tiers (design bible 12.99).
    paint_blends(img, zone)
    if zone in PATCHES:
        paint_patches(img, zone)
    TILES.mkdir(parents=True, exist_ok=True)
    save_png(img, TILES / f"{zone}.png")


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


def save_png(img, path):
    """Saves `img` to `path` unless the picture there already holds the same pixels,
    and says whether it wrote. Pillow on this PC encodes an unchanged picture to other
    bytes than the committed one, so a whole run used to rewrite five mid layers no
    painter had touched (pass 600; found in passes 563 and 584)."""
    path = Path(path)
    if path.exists():
        with Image.open(path) as old:
            if old.size == img.size and old.convert("RGBA").tobytes() == img.convert("RGBA").tobytes():
                return False
    img.save(path)
    return True


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


# The far columns break (design bible 12.119, pass 643). The pass 640 grade saw "the
# same trunk columns behind five areas": the Heartwood's far fibres, Vorrhallow's far
# pillars and the Tower's far shafts were each a row of bars running the full height
# of the layer, so three zones read as one band of stripes. Now no far column runs
# from top to bottom: the Heartwood's fibres hang from the roof or rise from the floor,
# lean, fork and taper to a tip; the Tower's shafts stand in three storeys, each on a
# gallery floor and set between the shafts of the storey under it; Vorrhallow's
# pillars carry capitals and round arches, with the vault lost in the dark above, and
# two of them are broken off.
FAR_RUN_MAX = 0.8  # the longest a far column may run, as a share of the layer's height


def _fibre(img, x0, y0, down, length, w, lean, col, seed, depth=0):
    """One fibre of the great tree, far off: from x0, y0 it runs `length` rows down
    (or up), leaning `lean` px a row and curving, from `w` wide to a tip; a streaked
    grain runs along it and its lit side is to the west. Some fibres fork."""
    grain = "night-0" if col == "bark-1" else "bark-0"
    fork = int(length * (0.4 + 0.25 * hash2(seed, 3, 77))) if depth == 0 and hash2(seed, 4, 77) > 0.4 else None
    for t in range(length):
        y = y0 + (t if down else -t)
        k = t / length
        ww = max(3 * D, int(w * (1 - 0.75 * k ** 1.3)))
        cx = x0 + lean * t + math.sin(t * 0.012 + seed) * 4 * D
        left = int(cx - ww / 2)
        for dx in range(ww):
            if hash2(dx // 2, y // 9, seed) > 0.08:
                put(img, left + dx, y, c(col))
        for g in range(3, ww - 2, 7):
            if hash2(g, y // 40, seed + 50) > 0.45:
                put(img, left + g, y, c(grain))
        if ww > 4 * D:
            put(img, left, y, c("bark-2" if col == "bark-1" else "bark-1"))
        if t == fork:
            # A strand parts from the fibre and leans away on its own.
            _fibre(img, cx, y, down, int((length - t) * 0.8), max(4 * D, int(ww * 0.55)),
                   -lean * 1.6 + (0.15 if lean <= 0 else -0.15), col, seed + 31, depth + 1)


def heartwood_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "bark-0")
    rng = random.Random(5)
    # Great fibres of the trunk's heartwood, far away (bible 12.119): half hang from
    # the hollow's roof and half rise from its floor, none runs the whole height, and
    # each leans its own way, so the far wall reads as a braid and not as a row of
    # trunks.
    for i in range(22):
        down = i % 2 == 0
        x0 = rng.randrange(BG_W)
        w = rng.randrange(16, 36) * D
        length = rng.randrange(int(BG_H * 0.4), int(BG_H * 0.7))
        lean = rng.uniform(0.12, 0.4) * rng.choice([-1, 1])
        col = "bark-1" if i % 3 else "night-1"
        _fibre(img, x0, 0 if down else BG_H - 1, down, length, w, lean, col, i)
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
                # Each house is lit on its west face and falls into shadow at its
                # east edge (pass 598): the grade read the town as one flat grey.
                lit = (xx - x) < w // 3
                if (xx - x) < 2 * D:
                    col = "stone-2"
                elif x + w - xx <= 2 * D:
                    col = "night-0"
                elif lit:
                    col = masonry_shade(xx, yy, 3, "night-1", "stone-1", "stone-2")
                else:
                    col = masonry_shade(xx, yy, 3, "night-0", "night-1", "stone-2")
                # Weathered courses of stone: jittered rows, still broken horizontally.
                if (xx - x) > 2 * D and yy in cs and hash2(xx // 12, yy, 3) > 0.4:
                    col = "night-1" if lit else "night-0"
                img.putpixel((xx, yy), c(col))
        # Roofline: one of several silhouettes per house, so a row of distant
        # houses stops reading as the same arch copied across (independent grade,
        # pass 515: "Hearthroot background buildings are the same two silhouettes").
        style = rng.choice(("arch", "gable", "battlement", "stepped", "arch"))
        # A battlement is stone; every other roof is tiled, a dark warm red-brown.
        crest, roof = ("stone-2", "night-1") if style == "battlement" else ("bark-2", "bark-1")
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
                img.putpixel((xx, yy), c(crest if yy - (top - rise) < 2 else roof))
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
    # The tower's far shafts (bible 12.119): three storeys, each standing on a
    # gallery floor, and each storey's shafts set between the shafts of the one
    # under it, so no shaft runs the height of the tower.
    floors = [0, int(BG_H * 0.34) + rng.randrange(-20, 20) * D, int(BG_H * 0.68) + rng.randrange(-20, 20) * D, BG_H]
    slot = BG_W // 5
    for tier in range(3):
        top, bottom = floors[tier], floors[tier + 1]
        for k in range(5):
            w = rng.randrange(24, 44) * D
            cx = k * slot + (slot // 2 if tier % 2 else 0) + rng.randrange(-8, 9) * D
            x0 = cx - w // 2
            seed = 210 + tier * 5 + k
            cs = masonry_courses(top, bottom, seed, 12 * D)
            for y in range(top, bottom):
                for dx in range(w):
                    col = masonry_shade(x0 + dx, y, seed, "night-0", "night-1", "stone-2")
                    if y in cs:
                        col = "night-0"  # a weathered mortar course
                    elif dx % (16 * D) == 0 and hash2(dx // D, y // (10 * D), seed) > 0.45:
                        col = "night-0"  # a worn vertical joint, broken by height
                    put(img, x0 + dx, y, c(col))
            # The shaft's head: corbels stepping out under the floor above.
            if tier:
                for step in range(3):
                    for yy in range(top + 4 * D + step * 3 * D, top + 4 * D + (step + 1) * 3 * D):
                        for dx in range(-(3 - step) * 2 * D, w + (3 - step) * 2 * D):
                            put(img, x0 + dx, yy, c("night-0" if yy == top + 4 * D + (step + 1) * 3 * D - 1 else "night-1"))
            if bottom - top > 60 * D and rng.random() < 0.7:
                wy = top + rng.randrange(20, max(21, (bottom - top) // D - 40)) * D
                wx = x0 + w // 2 - 2 * D
                for yy in range(wy, wy + 8 * D):
                    for xx in range(wx, wx + 3 * D):
                        put(img, xx, yy, c("gold-3" if yy > wy + 2 else "gold-4"))
    # The gallery floors: a lit lip over a dark slab, and a railing on it.
    for fy in floors[1:3]:
        for y in range(fy - 4 * D, fy + 4 * D):
            for x in range(BG_W):
                col = "stone-2" if y < fy - 3 * D else ("night-0" if y >= fy + 3 * D else "night-1")
                put(img, x, y, c(col))
        for x in range(0, BG_W, 14 * D):
            for y in range(fy - 14 * D, fy - 4 * D):
                put(img, x, y, c("night-1"))
                put(img, x + 1, y, c("night-1"))
        for x in range(BG_W):
            put(img, x, fy - 14 * D, c("night-1"))
    # Great gears turning in the dark.
    for i in range(4):
        gear(img, rng.randrange(BG_W), rng.randrange(80, BG_H - 80), rng.randrange(50, 110), rng.choice([10, 12, 14]),
             "night-1", "ember-1")
    # Sparks and lamp glints.
    for _ in range(140):
        put(img, rng.randrange(BG_W), rng.randrange(BG_H), c(rng.choice(["ember-3", "gold-3", "ember-2"])))
    far_motes(img, rng, ["ember-2", "gold-3", "ember-3"], glows=5)
    return img


# The mid columns break (design bible 12.120, pass 644). After the far columns broke
# (12.119), the mid layers' columns still ran the room's height: the Tower's five
# girders from roof to floor, and Vorrhallow's colonnade from high in the hall to the
# water. Now the Tower's trusses hang to their own depths and its posts rise to beams,
# and Vorrhallow's columns are broken off lower, each across its own fracture.
MID_RUN_MAX = 0.7  # the longest a mid column may run, as a share of the layer's height


def _hanging_truss(img, cx, length, seed):
    """A lattice truss hanging from the roof at `cx`: two chords with a zigzag web
    between them, `length` rows long, ending in a bracket plate, a pulley block and
    a short hook."""
    w = 14 * D
    x0 = cx - w // 2
    panel = w + 2 * D
    for y in range(length):
        for dx in (0, 1, 2, 3):
            put(img, x0 + dx, y, c("night-0" if dx == 0 else ("stone-1" if dx < 3 else "night-1")))
            put(img, x0 + w - 1 - dx, y, c("night-0" if dx == 0 else "night-1"))
        # The web: one diagonal a panel, alternating its lean, and a strut at each joint.
        k, t = divmod(y + int(hash2(seed, 5, 9) * panel), panel)
        u = t / panel if k % 2 == 0 else 1 - t / panel
        wx = x0 + 4 + int(u * (w - 10))
        for dx in range(2 * D):
            put(img, wx + dx, y, c("night-1" if dx else "stone-1"))
        if t < D:
            for dx in range(4, w - 4):
                put(img, x0 + dx, y, c("night-1"))
    # The bracket plate, the pulley block's wheel and a hook.
    for y in range(length, length + 4 * D):
        for dx in range(-2 * D, w + 2 * D):
            put(img, x0 + dx, y, c("stone-2" if y == length else ("night-0" if y >= length + 3 * D else "night-1")))
    wy = length + 10 * D
    for y in range(wy - 6 * D, wy + 6 * D):
        for x in range(cx - 6 * D, cx + 6 * D):
            r = math.hypot(x - cx + 0.5, y - wy + 0.5)
            if r < 6 * D:
                col = "night-0" if r > 5 * D or r < 1.5 * D else ("stone-1" if x < cx and y < wy else "night-1")
                put(img, x, y, c(col))
    for y in range(wy + 6 * D, wy + 10 * D):
        put(img, cx, y, c("stone-2"))
        put(img, cx + 1, y, c("stone-1"))
    for dx in range(-2 * D, D):
        put(img, cx + dx, wy + 10 * D, c("stone-2"))
    put(img, cx - 2 * D, wy + 10 * D - 1, c("stone-2"))


def _rising_post(img, cx, height, reach, cs):
    """A bolted post rising `height` rows from the floor at `cx`, with a cap plate
    and a beam `reach` either side carried on two knee braces; `cs` are its bolt
    courses."""
    w = 10 * D
    x0, top = cx - w // 2, BG_H - height
    for y in range(top, BG_H):
        for dx in range(w):
            edge = dx in (0, w - 1)
            col = "night-0" if edge else ("stone-1" if dx < 3 else "night-1")
            if (not edge) and y in cs:
                col = "stone-2"  # a bolt course, weathered off the fixed period
            put(img, x0 + dx, y, c(col))
    # The beam on the cap plate, lit on its top, riveted, dark beneath.
    by = top - 6 * D
    for y in range(by, top):
        for x in range(cx - reach, cx + reach):
            col = "stone-2" if y == by else ("night-0" if y >= top - D else "night-1")
            if by + 2 * D <= y < top - 2 * D and (x - cx) % (8 * D) == 0:
                col = "stone-1"
            put(img, x, y, c(col))
    # Knee braces from the post's sides up to the beam's underside.
    run = int(reach * 0.6)
    for side in (-1, 1):
        for t in range(run - w // 2):
            x = cx + side * (w // 2 + t)
            y = top + run - w // 2 - t
            for th in range(3 * D):
                put(img, x, y - th, c("night-0" if th in (0, 3 * D - 1) else "night-1"))


def tower_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(22)
    # The mid girders break (bible 12.120): none runs the room's height. Lattice
    # trusses hang from the roof, each to its own depth, and end in a pulley block;
    # between them, bolted posts rise from the floor and carry a beam on knee braces.
    bay = BG_W // 5
    for i in range(5):
        _hanging_truss(img, i * bay + rng.randrange(-10, 11) * D, int(BG_H * rng.uniform(0.32, MID_RUN_MAX - 0.05)), i)
    for i in range(5):
        if i == 2:
            continue  # one bay stands open to the far wall
        h = int(BG_H * rng.uniform(0.26, 0.44))
        _rising_post(img, i * bay + bay // 2 + rng.randrange(-10, 11) * D, h, rng.randrange(18, 28) * D,
                     masonry_courses(BG_H - h, BG_H, 500 + i, 24 * D))
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


# Carillon's lightning is far weather (design bible 12.71, pass 584). The bolts are
# baked into the far layer and never go out, so at gold-7 with a crystal-6 halo they
# were the brightest marks in the room: the grade (pass 580) read the fight frame as
# noisy, three white ropes hanging behind the foes. A far bolt is now a dim violet
# thread, darker than anything a foe or a tell is drawn with.
FAR_BOLT = "crystal-4"
FAR_BOLT_GLOW = "crystal-3"
FAR_BOLT_GLOW_ALPHA = 90


def lightning(img, x, y0, y1, rng, col=FAR_BOLT, glow=FAR_BOLT_GLOW):
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
                put(img, xx + dx, yy, c(glow, FAR_BOLT_GLOW_ALPHA))
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
                put(img, ax + (bx - ax) * t / max(n, 1), ay + (by - ay) * t / max(n, 1), c(glow, 160))


def block(img, wx, wy, col):
    """Fills one world pixel (a D x D block) at world-pixel coordinates wx, wy, so a
    painted prop keeps the game's pixel grain instead of half-size atlas pixels."""
    for dy in range(D):
        for dx in range(D):
            put(img, wx * D + dx, wy * D + dy, col)


ISLAND_ROCK = ("crystal-3", "crystal-2", "crystal-1", "night-1")  # rim, lit, mid, shadow
ISLAND_LINE = "night-0"
ISLAND_GRASS = ("leaf-3", "leaf-2", "leaf-1")  # tip, blade, root


# The builds a sky island comes in (design bible 12.101, pass 625). The pass 620
# grade named "floating islands" among the copied props: every island was a wedge,
# a main point under its middle with lesser points beside it, so a sky of them was
# one outline at six sizes. `wedge` is that build; a `shelf` is a wide shallow slab
# with a ragged underside and no point; a `fang` is a narrow island on one long
# tooth of rock, deeper than it is wide; a `twin` hangs two points apart with a
# saddle between. Each habit sets how deep the island hangs for its width
# (`ISLAND_DEPTH`, as a share of the wedge's).
ISLAND_HABITS = ("wedge", "shelf", "fang", "twin")
ISLAND_DEPTH = {"wedge": 1.0, "shelf": 0.5, "fang": 1.3, "twin": 0.85}


def deal_habits(rng, n, habits):
    """`n` of `habits`, every one turning up before any comes again, and no two in a
    row the same."""
    out = []
    while len(out) < n:
        deal = list(habits)
        rng.shuffle(deal)
        if out and deal[0] == out[-1]:
            deal.append(deal.pop(0))
        out += deal
    return out[:n]


def island_spurs(rng, habit):
    """The hanging points of an island of this habit, each (where along the lip,
    -1 to 1; half width; depth, 0 to 1), and how deep its belly of earth is."""
    if habit == "shelf":
        # A slab: a deep even belly and stubby uneven points along it, none a leader.
        at = -0.7
        spurs = []
        while at < 0.75:
            spurs.append((at, rng.uniform(0.1, 0.2), rng.uniform(0.62, 1.0)))
            at += rng.uniform(0.28, 0.5)
        return spurs, 0.55
    if habit == "fang":
        # One long tooth a little off centre, and a short spur or two by its root.
        lean = rng.choice([-1, 1]) * rng.uniform(0.05, 0.2)
        spurs = [(lean, rng.uniform(0.34, 0.42), 1.0)]
        for _ in range(rng.randint(1, 2)):
            spurs.append((lean + rng.choice([-1, 1]) * rng.uniform(0.35, 0.6), rng.uniform(0.12, 0.18), rng.uniform(0.34, 0.46)))
        return spurs, 0.26
    if habit == "twin":
        # Two points parted by a saddle, one the longer.
        a, b = rng.uniform(-0.55, -0.38), rng.uniform(0.34, 0.52)
        long_first = rng.random() < 0.5
        spurs = [(a, rng.uniform(0.3, 0.38), 1.0 if long_first else 0.75),
                 (b, rng.uniform(0.3, 0.38), 0.75 if long_first else 1.0)]
        return spurs, 0.42
    spurs = [(rng.uniform(-0.25, 0.25), rng.uniform(0.18, 0.3), 1.0)]
    for _ in range(rng.randint(2, 4)):
        spurs.append((rng.uniform(-0.75, 0.75), rng.uniform(0.08, 0.18), rng.uniform(0.35, 0.7)))
    return spurs, 0.32


def island_cells(cx, cy, w, depth, seed, habit="wedge"):
    """The silhouette of a sky island on the world-pixel grid: {(x, y): k}, k the
    cell's depth below the lip (0 to 1). Built a column at a time: a rounded belly
    of earth under the lip, and beneath it the habit's points of rock
    (`island_spurs`), so the underside is a ragged cluster of hanging spurs and no
    two islands are the same triangle."""
    rng = random.Random(seed)
    x0, y0 = int(cx) // D, int(cy) // D
    half, rows = max(5, w // (2 * D)), max(8, depth // D)
    spurs, deep = island_spurs(rng, habit)
    cells = {}
    for x in range(x0 - half, x0 + half + 1):
        u = (x - x0) / half
        belly = deep * max(0.0, 1 - abs(u) ** 2) ** 0.7
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


def island(img, cx, cy, w, rng, rock=ISLAND_ROCK, line=ISLAND_LINE, grass=ISLAND_GRASS, habit="wedge"):
    """A floating sky island (design bible 12.33), painted on the world-pixel grid
    as a lit pixel prop, not one flat fill: its rock is a cluster of chunky stones
    shaded on a four-tone ramp lit from the upper left (each stone lit on its
    upper-left face, seams one step darker, the right flank and the hanging spurs
    in shadow), closed by a dark selective outline on its shadow side and
    underside only. A three-tone grass lip caps it, blades poke above, tufts and
    moss hang over its edges and roots dangle from its belly."""
    depth = int(w * rng.uniform(0.6, 0.9) * ISLAND_DEPTH[habit])
    seed = int(cx) * 7919 + int(cy)
    loc = random.Random(seed + 1)
    cells = island_cells(cx, cy, w, depth, seed, habit)
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


SPIRES_SKY = ("night-0", "crystal-1")
SPIRES_CLOUD = ("crystal-2", "crystal-1", "night-1")


def spires_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("crystal-1"))
    # A step darker than it was (night-1 to crystal-2, pass 584): the storm sky is the
    # ground the fight is read against, so it stays below the play field's values.
    gradient(img, *SPIRES_SKY)
    rng = random.Random(51)
    # Storm banks rolling across a violet sky, a step darker with it.
    for _ in range(12):
        cloud(img, rng.randrange(BG_W), rng.randrange(80, 460) * D, rng.randrange(60, 130) * D, rng.randrange(26, 54) * D, rng,
              top=SPIRES_CLOUD[0], body=SPIRES_CLOUD[1], shade=SPIRES_CLOUD[2])
    for _ in range(3):
        x = rng.randrange(BG_W)
        lightning(img, x, rng.randrange(60, 160) * D, rng.randrange(260, 400) * D, rng)
    # The far spires of the Tree's crown, faint against the storm.
    for _ in range(5):
        x0 = rng.randrange(BG_W)
        dead_limb(img, x0, BG_H, rng.randrange(260, 420) * D, rng.randrange(8, 14) * D,
                  -math.pi / 2 + rng.uniform(-0.3, 0.3), "night-1", rng)
    far_motes(img, rng, ["crystal-2", "sky-2", "gold-3"], glows=5)
    return img


# Where spires_mid put its islands, each (cx, cy, w, habit), for the guard in test_tilegen.py.
SPIRES_ISLANDS = []


def spires_mid():
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    rng = random.Random(52)
    # Sky islands adrift at middle distance, a ruined spire on one or two. Each is
    # dealt a habit (12.101): a rng of their own, so the islands stay where they were.
    habits = deal_habits(random.Random(1052), 6, ISLAND_HABITS)
    SPIRES_ISLANDS.clear()
    for i in range(6):
        cx = (i + rng.uniform(0.1, 0.9)) * BG_W / 6
        cy = rng.randrange(140, 400) * D
        w = rng.randrange(50, 110) * D
        if habits[i] == "fang":
            w = int(w * 0.7)  # a fang is a narrow island
        elif habits[i] == "shelf":
            w = int(w * 1.2)
        SPIRES_ISLANDS.append((cx, cy, w, habits[i]))
        island(img, cx, cy, w, rng, habit=habits[i])
        if rng.random() > 0.5:
            sx, sh = cx + rng.uniform(-0.2, 0.2) * w, rng.randrange(40, 90) * D
            ruined_spire(img, sx, cy, sh)
    return img


# Vorrhallow's stillglass grows out of the stone (design bible 12.51, pass 563). The
# independent grade (pass 560) read the backdrops' crystals as "floating spears,
# attached to no rock": the far layer scattered its clusters anywhere, sky included,
# and the mid layer ran one thin needle from the middle of each column. A growth now
# has a seat (a point on a pillar's face and the way the face looks), a fan of
# broad-based shards around that normal, cracks run back into the stone, and a dark
# crust across the root. The painters record their seats here so the guard in
# test_tilegen.py can find them.
STILLGLASS_SEATS = {}


def stillglass_shard(img, rx, ry, ang, length, width, cols):
    """One faceted shard in world pixels: rooted at rx, ry, pointing along `ang`
    (0 is up, positive leans right), `width` across at the root and tapering to a
    point. The facet turned to the top-left light is `cols[1]` with a rim of
    `cols[0]`; the facet turned away is `cols[2]`."""
    ax, ay = math.sin(ang), -math.cos(ang)
    px, py = math.cos(ang), math.sin(ang)
    lit_side = -1 if (px + py) > 0 else 1
    steps = int(length * 2)
    for i in range(-4, steps + 1):  # starts two pixels inside the stone
        t = i / 2
        half = max(0.5, (1 - max(t, 0) / length) * width / 2)
        n = int(half * 2)
        for j in range(-n, n + 1):
            k = j / 2
            edge = half - abs(k) < 1.0 and half > 1.0
            # Two facets meet on a ridge down the middle: the one turned to the
            # light is the body colour with a bright rim, the other is in shade.
            col = cols[1] if k * lit_side >= 0 else cols[2]
            if edge and k * lit_side > 0:
                col = cols[0]
            block(img, int(round(rx + ax * t + px * k)), int(round(ry + ay * t + py * k)), c(col))


# Glass grows through its stone (design bible 12.115, pass 639). The pass 635 grade
# still read the hall's near shards as floating: each growth met its column at one
# dark crust, and the stone a hand's width away was untouched, so nothing said the
# glass had come from inside the column. Lit seams now run from each root back into
# the stone, up and down the column along its courses, thinning as they go.
VEIN_COUNT = 3
VEIN_REACH = (18, 36)


def stillglass_veins(img, rx, ry, face, cols):
    """Seams of glass from a root at world pixel rx, ry on a face whose normal is
    `face`, running back into the stone: `cols` is the seam's lit body and its dark
    edge. Their own rng (seeded by the seat), so a layer's other draws keep theirs.
    Returns the world pixels of the lit body."""
    rng = random.Random(rx * 7919 + ry * 104729)
    nx = round(math.sin(face))  # out of the face: +1 a right face, -1 a left one
    lit = []
    for k in range(VEIN_COUNT):
        x, y = rx - nx * (1 + k), ry + rng.randint(-2, 2)
        up = -1 if k % 2 == 0 else 1
        length = rng.randint(*VEIN_REACH)
        for t in range(length):
            # Mostly along the column (its courses run down it), now and then a step
            # further into the stone; never back out of the face.
            if rng.random() < 0.3:
                x -= nx
            else:
                y += up
            edge = t > length * 0.6
            block(img, x, y, c(cols[1] if edge else cols[0]))
            if not edge:
                lit.append((x, y))
                block(img, x - nx, y, c(cols[1]))  # its shadowed side, deeper in
    return lit


# A growth has a habit (design bible 12.100, pass 624). The independent grade (pass
# 620) read the hall's stillglass as "one crystal cluster at several angles": every
# growth was a leader with two or three lesser shards fanned beside it, so each was
# the same outline turned. There are four habits now, and they differ in outline:
#   spray  a leader with lesser shards fanned beside it (the old growth)
#   blade  one long narrow shard and a short spur at its root
#   druse  a low, wide crust of short stubby points, none of them a leader
#   twin   two shards of nearly one length, parting from one root
# A painter deals them out with `stillglass_habits`, so no two growths in a row
# share one.
STILLGLASS_HABITS = ("spray", "blade", "druse", "twin")


def stillglass_habits(rng, n):
    """`n` habits in which every habit turns up before any comes again, and no two
    in a row are the same."""
    return deal_habits(rng, n, STILLGLASS_HABITS)


def stillglass_growth(img, rx, ry, face, lean, rng, reach, width, cols, crust="crystal-1", glow=None, habit="spray",
                      stone=None, chip="stone-2", veins=None):
    """A seated cluster of stillglass at world pixel rx, ry on a stone face whose
    normal is `face` (0 is up, positive turns right; a pillar's right face is pi/2):
    the glass's light on the stone round its root (`glow`: far and near tones, or
    None), cracks into the stone, chips of stone burst out of the face, a leader
    along `lean` with shorter shards fanned beside it, their roots spread along the
    face, and a crust laid on the face over them. `stone`, if given, is the set of
    colours the glow may fall on (a layer drawn over its own sky), and `chip` the
    tone of the burst stone (None: no chips, and no draws on `rng` for them).
    `veins` (a body and an edge tone, or None) runs lit seams of glass from the
    root back through the stone (see `stillglass_veins`)."""
    tx, ty = math.cos(face), math.sin(face)  # along the face
    nx, ny = math.sin(face), -math.cos(face)  # out of it
    span = width * 0.9
    if glow:
        # The glass lights its own stone (bible 12.82, pass 597): the pass 595 grade
        # still read the hall's crystals as unanchored, because the pillar behind each
        # stayed one dark value right up to the glass. A dithered pool of wine light
        # now falls on the stone (only where there is stone) round the root, the near
        # tone close in, thinning out to `reach`.
        r = reach * 0.9
        for wy in range(int(ry - r), int(ry + r) + 1):
            for wx in range(int(rx - r), int(rx + r) + 1):
                d = math.hypot(wx - rx, (wy - ry) * 0.8) / r
                if d >= 1 or not (0 <= wx * D < img.width and 0 <= wy * D < img.height):
                    continue
                here = img.getpixel((wx * D, wy * D))
                if here[3] == 0 or here == c("night-0"):
                    continue  # open air, and the mortar courses, stay as they are
                if stone is not None and here[:3] not in stone:
                    continue  # the sky behind a far pillar stays sky
                # An ordered dither, so the pool reads as light and not as noise.
                bayer = BAYER4[wy % 4][wx % 4] / 16
                lit = (1 - d) ** 1.2
                if lit > bayer + 0.5:
                    block(img, wx, wy, c(glow[1]))
                elif lit > bayer * 0.8:
                    block(img, wx, wy, c(glow[0]))
    if veins:
        # Under the glass and its crust, so no seam is drawn over a shard; they
        # reach past the crust's ends.
        stillglass_veins(img, rx, ry, face, veins)
    # Cracks run back into the stone from the root.
    for _ in range(3):
        a = face + math.pi + rng.uniform(-0.9, 0.9)
        u = rng.uniform(-span, span)
        for t in range(rng.randint(3, 7)):
            block(img, int(round(rx + tx * u + math.sin(a) * t)), int(round(ry + ty * u - math.cos(a) * t)), c("night-0"))
    # The lesser shards first, so the leader lies over them. None leans back into
    # the stone: each stays within 1.2 rad of the face's normal.
    def shard(f, length, wide, u=None):
        """A shard turned `f` from the lean, its root `u` along the face (by
        default as far along as it is turned)."""
        ang = face + max(-1.2, min(1.2, lean + f - face))
        u = (f / 0.7) * span if u is None else u
        stillglass_shard(img, rx + tx * u, ry + ty * u, ang, length, wide, cols)

    if habit == "blade":
        # One long narrow shard, and a short spur beside its root on the side it
        # leans away from.
        side = -1 if (lean - face) > 0 else 1
        shard(side * rng.uniform(0.5, 0.8), reach * rng.uniform(0.3, 0.4), width * 0.6)
        stillglass_shard(img, rx, ry, lean, reach * 1.1, width * 0.88, cols)
    elif habit == "druse":
        # A low wide mound of stubby points grown into each other: four to six along
        # the face at uneven steps, broad enough to overlap, the middle ones the
        # tallest (half a leader's reach) and the end ones splayed along the face.
        n = rng.randint(4, 6)
        at = sorted(rng.uniform(-1, 1) for _ in range(n))
        for k in sorted(range(n), key=lambda k: abs(at[k]), reverse=True):
            f = face - lean + (lean - face) * 0.35 + at[k] * 0.8 + rng.uniform(-0.1, 0.1)
            tall = 0.52 - abs(at[k]) * 0.24 + rng.uniform(-0.05, 0.05)
            shard(f, reach * tall, width * rng.uniform(0.7, 0.95), at[k] * span * 1.1)
    elif habit == "twin":
        # Two broad shards of nearly one length parting a little from one root, and
        # a short third low on the far side of the lean.
        part = rng.uniform(0.2, 0.28)
        low = 1 if (lean - face) > 0 else -1
        shard(low * rng.uniform(0.75, 0.95), reach * rng.uniform(0.3, 0.42), width * 0.6)
        shard(part, reach * rng.uniform(0.8, 0.9), width * 0.85, span * 0.4)
        shard(-part, reach, width * 0.9, -span * 0.4)
    else:
        for f in sorted((rng.uniform(-0.7, 0.7) for _ in range(rng.randint(2, 3))), key=abs, reverse=True):
            shard(f, reach * rng.uniform(0.45, 0.7), width * rng.uniform(0.55, 0.8))
        stillglass_shard(img, rx, ry, lean, reach, width, cols)
    if glow and chip:
        # Chips of stone burst out of the face where the glass broke through: small
        # lit-topped blocks just off the face, past either end of the roots.
        for k in range(rng.randint(3, 5)):
            u = (1 if k % 2 else -1) * rng.uniform(span * 1.1, span * 1.7)
            out = rng.randint(1, 3)
            cw = rng.randint(2, 3)
            bx, by = int(round(rx + tx * u + nx * out)), int(round(ry + ty * u + ny * out))
            if nx < 0:
                bx -= cw - 1  # on a left face, the chip grows out to the left
            for i in range(cw):
                block(img, bx + i, by, c(chip))
                block(img, bx + i, by + 1, c("night-0"))
    # The crust: a ragged dark knuckle of wine glass on the face, across the roots.
    for h in range(int(-span * 2) - 4, int(span * 2) + 5):
        u = h / 2
        for t in range(-1, rng.randint(2, 4)):
            block(img, int(round(rx + tx * u + nx * t)), int(round(ry + ty * u + ny * t)), c(crust))


# The far glass sits as deep as its pillars (design bible 12.115, pass 639). The pass
# 635 grade still read the hall's shards as floating: the far layer's glass was drawn
# in nearly the near layer's tones (crystal-5 rim, crystal-3 body) on pillars that
# stop at stone-1, so it stood a value step in front of everything round it and the
# eye put it in the air before the pillars. It now takes the ramp two steps down from
# the mid layer's, and lights its own stone as the mid's does, more faintly.
FAR_STILLGLASS = ("crystal-4", "crystal-2", "crystal-1")
MID_STILLGLASS = ("crystal-6", "crystal-4", "crystal-2")
FAR_STILLGLASS_GLOW = ("night-1", "crystal-1")
MID_STILLGLASS_GLOW = ("crystal-1", "crystal-2")
MID_STILLGLASS_VEIN = ("crystal-3", "crystal-1")


def vorrhallow_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "sky-1")
    rng = random.Random(61)
    # The drowned capital's great hall: rows of colossal pillars and arches
    # sunk to their knees in dark water, crystal light glowing between them.
    water = int(BG_H * 0.72)
    # The arcade (bible 12.119): the pillars carry capitals at one spring line and
    # round arches between them, the vault above is lost in the dark, and two of the
    # pillars are broken off, the arches beside them fallen.
    spring = int(BG_H * 0.38)
    broken = set(rng.sample(range(7), 2))
    pillars, tops = [], []
    for i in range(7):
        x0 = int((i + rng.uniform(0.0, 0.4)) * BG_W / 7)
        w = rng.randrange(24, 40) * D
        top = spring + rng.randrange(30, 90) * D if i in broken else spring
        pillars.append((x0, w))
        tops.append(top)
        cs = masonry_courses(top, BG_H, 440 + i, 18 * D)
        for y in range(top, BG_H):
            for dx in range(w):
                if i in broken and y < top + int(hash2(dx // (3 * D), 1, 440 + i) * 14 * D):
                    continue  # the broken top, jagged
                # The far pillars: weathered courses on a jittered period, each
                # stone a touch lighter or darker, so the great hall stops reading
                # as one stamped column (bible 12.14). Muted (stone-1, no stone-2)
                # to stay behind vorrhallow_mid.
                col = "stone-1" if dx <= w * 0.3 else masonry_shade(x0 + dx, y, 440 + i, "night-0", "night-1", "stone-1")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                put(img, x0 + dx, y, c(col))
        if i not in broken:
            # The capital: a block stepped out over the shaft, lit on its top.
            for y in range(spring - 8 * D, spring):
                for dx in range(-3 * D, w + 3 * D):
                    col = "stone-1" if y < spring - 6 * D else ("night-0" if y >= spring - D else "night-1")
                    put(img, x0 + dx, y, c(col))
    # Round arches from each capital to the next; one beside a broken pillar has
    # fallen, leaving its springing on the standing side as a stub.
    for i in range(7):
        x0, w = pillars[i]
        x1 = pillars[(i + 1) % 7][0] + (BG_W if i == 6 else 0)
        a, b = x0 + w + 3 * D, x1 - 3 * D
        span = b - a
        if span < 20 * D:
            continue
        for dx in range(-3 * D, span + 3 * D):
            if i in broken and dx < span * 0.6 or (i + 1) % 7 in broken and dx > span * 0.4:
                continue
            u = min(1.0, max(-1.0, (dx - span / 2) / (span / 2 + 3 * D)))
            inner = spring - 8 * D - int(math.sqrt(1 - u * u) * (span / 2) * 0.8)
            for y in range(inner - 10 * D, inner):
                joint = int(math.atan2(spring - y, dx - span / 2) / 0.16) != int(math.atan2(spring - y, dx + D - span / 2) / 0.16)
                col = "night-0" if joint or y == inner - 10 * D else ("night-1" if y >= inner - 2 * D else "stone-1")
                put(img, a + dx, y, c(col))
    # Stillglass grown out of the far pillars' faces, glowing magenta: each cluster
    # is seated on a pillar's face and leans up and away from it (bible 12.51).
    seats = []
    habits = stillglass_habits(rng, 9)
    for k in range(9):
        x0, w = pillars[(k * 3 + rng.randrange(2)) % len(pillars)]
        side = rng.choice([-1, 1])
        rx = (x0 if side < 0 else x0 + w - D) // D
        ry = rng.randrange(tops[pillars.index((x0, w))] // D + 24, water // D - 30)
        seats.append((rx, ry, side))
        stillglass_growth(img, rx, ry, side * math.pi / 2, side * rng.uniform(0.5, 1.0), rng,
                          rng.randrange(14, 27), rng.randrange(6, 9),
                          FAR_STILLGLASS, glow=FAR_STILLGLASS_GLOW, habit=habits[k],
                          stone={c(n)[:3] for n in ("stone-1", "night-1")}, chip=None)
    STILLGLASS_SEATS["vorrhallow_far"] = {"pillars": [(x // D, w // D) for x, w in pillars], "seats": seats, "habits": habits}
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
    # A broken colonnade, nearer and darker, with stillglass grown out of it. The
    # columns are broken off well below the vault (bible 12.120), none within
    # MID_RUN_MAX of the hall's height, each across a fracture of its own: a slant
    # one way or the other, chipped, its broken face lit.
    columns = []
    for i in range(6):
        x0 = int((i + rng.uniform(0.1, 0.7)) * BG_W / 6)
        w = rng.randrange(14, 24) * D
        top = rng.randrange(int(BG_H * (1 - MID_RUN_MAX)) // D + 46, 310) * D
        slant = rng.choice([-1, 1]) * rng.uniform(0.4, 1.0)
        cs = masonry_courses(top, BG_H, 620 + i, 24 * D)
        for dx in range(w):
            u = dx / w if slant > 0 else 1 - dx / w
            brk = top + int(abs(slant) * u * 18 * D + hash2(dx // D, 3, 620 + i) * 6 * D)
            for y in range(brk, BG_H):
                col = "stone-1" if dx < w * 0.25 else masonry_shade(x0 + dx, y, 620 + i, "night-0", "night-1", "stone-2")
                if y in cs:
                    col = "night-0"  # a weathered mortar course
                if y < brk + D:
                    col = "stone-2"  # the broken face, catching the light
                put(img, x0 + dx, y, c(col))
        columns.append((x0, w, top))
    # Stillglass bursting from the columns' faces: a broad-based cluster seated on
    # the stone, leaning up and out, and on some columns a lesser one lower down on
    # the other face (bible 12.51). Drawn after every column so none is painted over.
    seats = []
    habits = []
    deal = stillglass_habits(rng, 2 * len(columns))
    for x0, w, top in columns:
        side = rng.choice([-1, 1])
        ry = top // D + rng.randrange(34, 70)
        for n, s_ in enumerate((side, -side)):
            if n and rng.random() < 0.45:
                continue
            rx = (x0 if s_ < 0 else x0 + w - D) // D
            seats.append((rx, ry, s_))
            habits.append(deal[len(habits)])
            stillglass_growth(img, rx, ry, s_ * math.pi / 2, s_ * rng.uniform(0.5, 0.95), rng,
                              rng.randrange(12, 18) if n else rng.randrange(22, 33),
                              rng.randrange(7, 10) if n else rng.randrange(12, 17),
                              MID_STILLGLASS, glow=MID_STILLGLASS_GLOW, habit=habits[-1], veins=MID_STILLGLASS_VEIN)
            ry += rng.randrange(40, 80)
    STILLGLASS_SEATS["vorrhallow_mid"] = {"pillars": [(x // D, w // D) for x, w, _ in columns], "seats": seats, "habits": habits}
    # Hanging chains from the vault, ending well above the broken columns.
    for _ in range(8):
        x = rng.randrange(BG_W)
        for y in range(0, rng.randrange(40, 130) * D):
            if (y // (3 * D)) % 2 == 0:
                put(img, x, y, c("night-1"))
    return img


BAYER4 = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
CORE_GLOW = 0.5  # the most of the core glow's pixels that are lit, at the foot


def evercrown_far():
    img = Image.new("RGBA", (BG_W, BG_H), c("night-0"))
    gradient(img, "night-0", "crystal-1")
    rng = random.Random(77)
    # The stillglass's hollow heart: vast ribbed walls curving away like the inside
    # of a shell, cyan veins of light pulsing through them toward a wine glow.
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
    # A wine glow far below: the core. Not red (bible 12.48), and an ordered
    # dither one world pixel fine that thickens downward to CORE_GLOW of the
    # pixels: the older random 4 px blocks read as a band of checker noise
    # behind the floor.
    for y in range(int(BG_H * 0.8), BG_H):
        k = (y - BG_H * 0.8) / (BG_H * 0.2) * CORE_GLOW
        for x in range(BG_W):
            if k > (BAYER4[(y // D) % 4][(x // D) % 4] + 0.5) / 16.0:
                put(img, x, y, c("crystal-2"))
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
                    col = "sky-3"  # a bead of the bulb's light, not red (bible 12.48)
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


# --- The hanging frame (design bible 12.121) ------------------------------------
# The independent grade of pass 640: no foreground layer frames the rooms. The
# low fringe (12.11, 12.29) only edges the bottom of the view. This is its
# partner at the top: the zone's own material hanging into the view from above
# (root tangles, leaf clumps, moss beards, crystal stalactites, a broken lintel
# with chains, a rafter with ropes), in clusters with clear air between them, so
# the play field is seen through a near frame the way Hollow Knight and
# Blasphemous frame theirs. Backdrop locks it to the view's top edge and slides
# it a little slower than the low fringe (HANG_SCROLL), so the two near layers
# shear against each other. No band: nothing runs the width (Sean's note of
# 2026-11-09 on the dark band, 12.25), and nothing drops below HANG_MAX_DROP.
HANG_KIND = {
    "heartwood": "roots", "boughs": "leaves",
    "haar": "moss", "sunken": "moss",
    "evercrown": "shards", "vorrhallow": "shards",
    "tower": "chains", "trials": "chains",
    "hearthroot": "rafter", "spires": "rafter",
}
# The deepest a hanging shape reaches below the view's top, world pixels
# (Backdrop.HANG_MAX_DROP mirrors it): a sixth of the 360 px view.
HANG_MAX_DROP = 60
# The share of the top row the clusters may cover at most, so air shows between.
HANG_MAX_COVER = 0.5
# More solid than the low fringe (176): a frame is the darkest thing on screen,
# where a see-through fringe over the ground washed out into the fog.
MASS_A, STRAND_A, HANG_RIM_A = 224, 200, 212


def _hang_put(img, x, y, alpha=STRAND_A, rim=False):
    if 0 <= y < HANG_MAX_DROP * D:
        put(img, x, y, c(FORE_RIM if rim else FORE_BODY, HANG_RIM_A if rim else alpha))


def _hang_mass(img, x0, w, depth, rng, lumps=None):
    """An irregular clump hugging the top edge: overlapping half-ellipses at most
    `depth` deep across `w`, with a faint rim along its lower edge. Returns the
    lowest y of the mass in each column, for strands to hang from."""
    lumps = lumps or max(2, w // (14 * D))
    low = {}
    for k in range(lumps):
        cx = x0 + int((k + 0.5) * w / lumps) + rng.randint(-3, 3) * D
        rx = max(4 * D, int(w / lumps * rng.uniform(0.6, 0.95)))
        ry = max(3 * D, int(depth * rng.uniform(0.45, 1.0)))
        for dx in range(-rx, rx + 1):
            f = 1.0 - (dx / rx) ** 2
            if f <= 0:
                continue
            low[cx + dx] = max(low.get(cx + dx, 0), int(ry * f ** 0.5))
    # A ragged underside, not a clean scallop: the edge wanders by a smoothed
    # random walk, and short tips (hairs, leaf points, grit) hang off it.
    walk = 0.0
    for col in sorted(low):
        walk = max(-2.5 * D, min(2.5 * D, walk + rng.uniform(-0.9, 0.9) * D))
        if low[col] > 2 * D:
            low[col] = max(D, low[col] + int(walk))
            if rng.random() < 0.18:
                low[col] += rng.randint(1, 4) * D
    for col, yb in low.items():
        for y in range(yb):
            _hang_put(img, col, y, MASS_A)
        _hang_put(img, col, yb, rim=True)
    return low


def _hang_strand(img, x, y0, length, w, rng, sway=None, rim=True):
    """A tapering strand hanging from (x, y0), bending in one gentle curve."""
    sway = rng.uniform(-6, 6) * D if sway is None else sway
    for i in range(length):
        t = i / max(1, length)
        half = int(w * (1.0 - 0.75 * t) / 2)
        cx = x + int(sway * math.sin(t * math.pi * 0.5))
        for dx in range(-half, half + 1):
            _hang_put(img, cx + dx, y0 + i)
        if rim:
            _hang_put(img, cx + half + 1, y0 + i, rim=True)
    return x + int(sway)


def _hang_roots(img, x, rng):
    """A root tangle: a knotted clump with thick roots hanging out of it, some forked."""
    w = rng.randint(40, 90) * D
    low = _hang_mass(img, x, w, rng.randint(8, 16) * D, rng)
    for _ in range(rng.randint(3, 6)):
        cx = x + rng.randint(4, w // D - 4) * D
        top = low.get(cx, 0)
        length = rng.randint(16, 44) * D
        end = _hang_strand(img, cx, top, length, rng.randint(2, 4) * D, rng)
        if rng.random() < 0.5:  # a fork, thinner and shorter
            _hang_strand(img, (cx + end) // 2, top + length // 2, length // 2, 2 * D, rng,
                         sway=rng.choice([-1, 1]) * 5 * D)
    return w + rng.randint(60, 140) * D


def _hang_leaves(img, x, rng):
    """A leaf clump with vines hanging out of it, leaf pairs down each vine."""
    w = rng.randint(50, 100) * D
    low = _hang_mass(img, x, w, rng.randint(14, 26) * D, rng, lumps=rng.randint(4, 7))
    for _ in range(rng.randint(2, 4)):
        cx = x + rng.randint(6, w // D - 6) * D
        top = low.get(cx, 0)
        length = rng.randint(14, 34) * D
        sway = rng.uniform(-5, 5) * D
        _hang_strand(img, cx, top, length, D, rng, sway=sway, rim=False)
        side = rng.choice([-1, 1])
        for j in range(3 * D, length, 5 * D):  # leaves alternate down the vine, drooping
            lx = cx + int(sway * math.sin(j / length * math.pi * 0.5)) + side * 2 * D
            ly = top + j + 3 * D
            for dy in range(-4 * D, 4 * D + 1):
                for dx in range(-2 * D, 2 * D + 1):
                    if (dx / (2.2 * D)) ** 2 + (dy / (4.2 * D)) ** 2 <= 1.0:
                        _hang_put(img, lx + dx + (side * dy) // 3, ly + dy)
            side = -side
    return w + rng.randint(90, 160) * D  # wide clumps, so wider air between


def _hang_moss(img, x, rng):
    """A moss beard: a thin clump with many ragged strands, longest in its middle."""
    w = rng.randint(40, 80) * D
    low = _hang_mass(img, x, w, rng.randint(5, 11) * D, rng)
    for _ in range(rng.randint(8, 14)):
        cx = x + rng.randint(2, w // D - 2) * D
        mid = abs((cx - x) / w - 0.5)
        length = max(4 * D, int(rng.randint(8, 46) * D * (1.0 - mid)))
        _hang_strand(img, cx, low.get(cx, 0), length, rng.choice([1, 2, 2]) * D, rng,
                     sway=rng.uniform(-2, 2) * D, rim=False)
    return w + rng.randint(60, 140) * D


def _hang_shards(img, x, rng):
    """A rock lip with crystal stalactites: straight tapering points."""
    w = rng.randint(36, 70) * D
    low = _hang_mass(img, x, w, rng.randint(6, 12) * D, rng)
    for _ in range(rng.randint(2, 5)):
        cx = x + rng.randint(4, w // D - 4) * D
        top = low.get(cx, 0)
        length = rng.randint(12, 42) * D
        half0 = rng.randint(3, 7) * D
        lean = rng.randint(-3, 3) * D
        for i in range(length):
            t = i / length
            half = int(half0 * (1.0 - t))
            ox = cx + int(lean * t)
            for dx in range(-half, half + 1):
                _hang_put(img, ox + dx, top + i)
            _hang_put(img, ox - half - 1, top + i, rim=True)
    return w + rng.randint(60, 140) * D


def _hang_chains(img, x, rng):
    """A broken stone lintel at the top edge, with a chain or two hanging from it."""
    w = rng.randint(40, 80) * D
    depth = rng.randint(10, 16) * D
    chip_l, chip_r = rng.randint(2, 8) * D, rng.randint(2, 8) * D
    for i in range(w):  # flat underside, chipped at both ends
        yb = depth
        if i < chip_l:
            yb = int(depth * (0.3 + 0.7 * i / chip_l))
        elif i > w - chip_r:
            yb = int(depth * (0.3 + 0.7 * (w - i) / chip_r))
        for y in range(yb):
            _hang_put(img, x + i, y, MASS_A)
        _hang_put(img, x + i, yb, rim=True)
    for _ in range(rng.randint(1, 2)):
        cx = x + rng.randint(8, w // D - 8) * D
        length = rng.randint(16, 40) * D
        link = 5 * D
        for j in range(0, length, link):
            y = depth + j
            if (j // link) % 2 == 0:  # a link face on: an open oval
                for a in range(32):
                    ang = a / 32 * math.tau
                    _hang_put(img, cx + int(2 * D * math.cos(ang)), y + link // 2 + int(link / 2 * math.sin(ang)))
            else:  # a link edge on: a short bar
                for yy in range(link):
                    _hang_put(img, cx, y + yy)
                    _hang_put(img, cx + 1, y + yy)
        if rng.random() < 0.6:  # a hook at the end
            y = depth + length + D
            for a in range(20):
                ang = a / 20 * math.pi
                _hang_put(img, cx + int(3 * D * math.cos(ang)), y + int(3 * D * math.sin(ang)))
    return w + rng.randint(60, 140) * D


def _hang_rafter(img, x, rng):
    """A rafter's end slanting down out of the top edge, with ropes off it."""
    w = rng.randint(60, 110) * D
    drop = rng.randint(14, 26) * D
    thick = rng.randint(5, 8) * D
    d = rng.choice([-1, 1])
    for i in range(w):
        yc = int(drop * (i / w if d > 0 else 1.0 - i / w))
        for y in range(max(0, yc - thick), yc):
            _hang_put(img, x + i, y, MASS_A)
        _hang_put(img, x + i, yc, rim=True)
    for _ in range(rng.randint(1, 3)):  # ropes, frayed at the end
        i = rng.randint(8, w // D - 8) * D
        yc = int(drop * (i / w if d > 0 else 1.0 - i / w))
        length = rng.randint(10, 30) * D
        _hang_strand(img, x + i, yc, length, D, rng, sway=rng.uniform(-2, 2) * D, rim=False)
        for f in (-1, 0, 1):
            for m in range(3 * D):
                _hang_put(img, x + i + f * (m // 2), yc + length + m)
    return w + rng.randint(70, 150) * D


HANG_SHAPE = {
    "roots": _hang_roots, "leaves": _hang_leaves, "moss": _hang_moss,
    "shards": _hang_shards, "chains": _hang_chains, "rafter": _hang_rafter,
}


def hanging(zone):
    """The near frame hanging into the top of the view for `zone` (bible
    12.121): clusters of the zone's material over a transparent canvas the size
    of the other layers, wrapping sideways."""
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    shape = HANG_SHAPE[HANG_KIND[zone]]
    rng = random.Random(sum(ord(ch) for ch in zone) + 1211)
    x = rng.randint(0, 60) * D
    while x < BG_W - 40 * D:
        x += shape(img, x, rng)
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
    # The Heartwood stands on great arching roots of its own (pass 642, 12.118): it
    # shared the High Boughs' firs, and the pass 640 grade saw one pine band behind both.
    "heartwood": "root", "boughs": "fir",
    "haar": "mound", "sunken": "mound",
    "evercrown": "shard", "vorrhallow": "shard",
    "tower": "crag", "trials": "crag",
    # The Spires stand on ruined spires of their own (pass 601): with one roofline
    # each, the town's window-dotted skyline repeated in the storm (pass 600 grade).
    "hearthroot": "roof", "spires": "spire",
}
# Body silhouette and a one-step-lighter crest rim: a dark shade of each zone's
# dominant ramp, so the ridge belongs to its world even before the haze recedes
# it (the warm hearth and cold spring never share one ridge colour).
RIDGE_COLOR = {
    "heartwood": ("bark-1", "bark-2"), "boughs": ("leaf-1", "leaf-2"),
    "haar": ("sky-1", "sky-2"), "sunken": ("sky-1", "sky-2"),
    # The two crystal halls sit a shade deeper, each in its own hue (bible 12.48):
    # Vorrhallow's drowned blue, the Evercrown's wine.
    "evercrown": ("crystal-0", "crystal-1"), "vorrhallow": ("sky-0", "sky-1"),
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
    """A triangular crest `half` wide, `peak` tall, into `teeth` (indices wrap). A
    `lean` slides both feet that far sideways under the apex at `cx`. (Until pass 635
    each column was slid instead, which left gaps in a leaning shard's crest, and each
    gap drew a cleft: the crystal halls' ridge was striped.)"""
    left, right = min(-1, lean - half), max(1, lean + half)
    for o in range(left, right + 1):
        v = peak * (o - left) / -left if o <= 0 else peak * (right - o) / right
        i = (cx + o) % BG_W
        teeth[i] = max(teeth[i], v)


FIR_TIP = 0.25   # a tier's top width, as a share of its drooping bottom
FIR_FLARE = 0.7  # how fast the tiers widen down the tree (1 is a straight cone)


def _fir_height(half, peak, tiers, d):
    """The top of a tiered fir at `d` px out from its trunk (-1 past its widest tier):
    each tier flares from a narrow top to drooping tips at its bottom, wider tier by
    tier down the tree (bible 12.111)."""
    th = peak / tiers
    best = -1.0
    for k in range(tiers):  # 0 is the top tier
        low = peak - (k + 1) * th
        bot = half * ((k + 1) / tiers) ** FIR_FLARE
        top = bot * FIR_TIP if k else 0.0
        if d <= top:
            best = max(best, low + th)
        elif d <= bot:
            best = max(best, low + th * (bot - d) / (bot - top))
    return best


def _fir(teeth, cx, half, peak, tiers):
    """A fir of `tiers` drooping tiers, `half` wide at its foot and `peak` tall, into
    `teeth` (indices wrap): the crest is a row of stepped trees, not a sawtooth."""
    for dx in range(-half, half + 1):
        v = _fir_height(half, peak, tiers, abs(dx))
        if v >= 0:
            i = (cx + dx) % BG_W
            teeth[i] = max(teeth[i], v)


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


# The town's houses (design bible 12.94, pass 617). Until then every house was a
# flat-topped block set with one lattice of windows, and two grades read the row as
# gridded tower blocks. A house now has a roof of its own: a gable, a hipped roof, a
# lean-to, or a narrow tower under a point or a notched crown, and some carry a chimney.
HOUSE_FORMS = (("gable", 0.46), ("hip", 0.2), ("lean", 0.14), ("tower", 0.2))


def _house(rng, cx, ground):
    """One house of the town's roofline, standing level at `ground`: its form, its
    wall top (`eave`), and its roof height per column offset (`roof`, no chimney)."""
    r, form = rng.random(), "tower"
    for name, share in HOUSE_FORMS:
        if r < share:
            form = name
            break
        r -= share
    if form == "tower":
        half, wall = rng.randint(4, 6) * D, rng.randint(34, 50) * D
    else:
        half, wall = rng.randint(7, 14) * D, rng.randint(14, 34) * D
    roof = {}
    pointed = rng.random() < 0.5
    pitch = half * rng.uniform(0.55, 0.95)
    west = rng.random() < 0.5
    for dx in range(-half - D, half + D + 1):
        t = 1.0 - abs(dx) / (half + D)
        if form == "gable":
            v = wall + pitch * t
        elif form == "hip":
            v = wall + min(pitch * 0.6, (half + D - abs(dx)) * 1.0)
        elif form == "lean":
            v = wall + pitch * 0.7 * ((dx + half + D) if west else (half + D - dx)) / (2 * (half + D))
        elif pointed:
            v = wall + (half + D - abs(dx)) * 1.7
        else:
            if abs(dx) > half:
                continue
            v = wall - (2 * D if (dx + half) // (2 * D) % 2 else 0)
        roof[dx] = ground + v
    chimney = None
    if form in ("gable", "hip") and rng.random() < 0.5:
        at = rng.choice((-1, 1)) * rng.randint(half // 3, half * 2 // 3)
        chimney = (at, roof[at] + rng.randint(4, 6) * D)
    return {"cx": cx, "half": half, "form": form, "eave": ground + wall, "roof": roof, "chimney": chimney}


# The Spires' ruined towers (design bible 12.98, pass 622). Until then every spire
# was one pole 6 to 12 px wide under a point or a notched crown, in one tone, and the
# pass 615 grade read the storm ledge's skyline as a flat one-value silhouette (in the
# room, a row of fence posts). A spire now has a form of its own: a needle under a
# cone, a notched crown, a tower sheared off at a slant, or a keep (a broad base with
# a shaft standing on it); and some pairs are joined by a bridge, whole or fallen.
SPIRE_FORMS = (("needle", 0.3), ("crown", 0.16), ("broken", 0.27), ("keep", 0.27))
SPIRE_SPAN_SHARE = 0.5         # the share of near pairs of spires that a bridge joins (every other one still whole)
SPIRE_SPAN_GAP = (10 * D, 40 * D)  # how far apart two spires' walls may be for a bridge


def _spire(rng, cx, ground):
    """One ruined spire, standing level at `ground`: its form, its shaft's half
    width and wall height, its base (a keep's: half width and height) and its crest
    height per column offset (`roof`)."""
    r, form = rng.random(), "keep"
    for name, share in SPIRE_FORMS:
        if r < share:
            form = name
            break
        r -= share
    half, wall = rng.randint(3, 5) * D, rng.randint(34, 68) * D
    if form == "broken":
        half, wall = rng.randint(4, 7) * D, rng.randint(30, 58) * D
    top, base = form, None
    if form == "keep":
        base = (half + rng.randint(4, 6) * D, int(wall * rng.uniform(0.4, 0.58)))
        top = rng.choice(("needle", "broken"))
    lean, drop = rng.choice((-1, 1)), rng.randint(8, 15) * D
    roof = {}
    for dx in range(-half, half + 1):
        if top == "needle":
            v = wall + (half - abs(dx)) * 1.6
        elif top == "crown":
            v = wall - (2 * D if (dx + half) // (2 * D) % 2 else 0)
        else:
            # Sheared off at a slant, in ragged steps two pixels wide.
            t = (dx + half) / (2 * half)
            step = (dx + half) // (2 * D)
            v = wall - drop * (t if lean > 0 else 1 - t) + (hash2(cx // D, step, 131) - 0.5) * 6 * D
            v = D * round(v / D)
        roof[dx] = ground + v
    if base:
        for dx in range(-base[0], base[0] + 1):
            if abs(dx) > half:
                # The base's shoulder: a short slope up to the shaft.
                roof[dx] = ground + base[1] + min(3 * D, base[0] - abs(dx))
    return {"cx": cx, "half": half, "form": form, "top": top, "ground": ground, "wall": wall,
            "base": base, "roof": roof}


def _spire_span(rng, a, b, roll, roofs, whole):
    """A bridge from spire `a` to spire `b`, or None where none can stand: its deck's
    height, and per column its underside and the ground or masonry below it. A
    fallen bridge leaves a stub on each tower and open sky between."""
    x0, x1 = a["cx"] + a["half"] + 1, b["cx"] - b["half"] - 1
    # A spire carries one bridge at most: two make a cross of it.
    if a.get("bridged") or not SPIRE_SPAN_GAP[0] <= x1 - x0 <= SPIRE_SPAN_GAP[1] or rng.random() >= SPIRE_SPAN_SHARE:
        return None
    lowest = min(min(a["roof"][dx] for dx in range(-a["half"], a["half"] + 1)),
                 min(b["roof"][dx] for dx in range(-b["half"], b["half"] + 1)))
    solid = {x: roll[x % BG_W] if roofs[x % BG_W] is None else max(roll[x % BG_W], roofs[x % BG_W])
             for x in range(x0, x1 + 1)}
    floor = max(solid.values())
    deck = floor + (lowest - floor) * rng.uniform(0.45, 0.7)
    if lowest - deck < 6 * D or deck - floor < 9 * D:
        return None
    hole = (rng.uniform(0.3, 0.45), rng.uniform(0.55, 0.75))
    rise = min((x1 - x0) * 0.4, deck - floor - 5 * D)
    under = {}
    for x in range(x0, x1 + 1):
        t = (x - x0) / (x1 - x0)
        if not whole and hole[0] < t < hole[1]:
            continue
        # A pointed arch: thin at the crown, deep where it springs from a tower.
        under[x] = deck - 3 * D - rise * abs(2 * t - 1) ** 1.6
    return {"form": "span", "deck": deck, "under": under, "solid": solid, "whole": whole}


# The Heartwood's roots (bible 12.118, pass 642). The pass 640 grade saw "the same pine
# band" behind five areas: the Heartwood, a hollow under one great tree, stood on the
# High Boughs' firs. It now stands on a row of great roots, each arching out of the
# ground and back in, broad at its buttressed feet and thin at its crown. The root is
# darker than the plane and the far haze shows through the arch under it, with
# rootlets hanging into it and fungus glowing at its feet; two inner rows of smaller
# roots stand lower in the plane, each darker than the last.
ROOT_HALF = (24, 52)    # an arch's half-width to each foot, px at 1x (each side its own)
ROOT_PEAK = (18, 44)    # its crown's height above the ground
ROOT_THICK = (4, 7)     # the root's thickness at the crown; its feet flare to more than twice that
ROOT_STEP = (30, 56)    # from one arch to the next, so neighbours cross at the feet
ROOT_FLARE = 1.6        # how much thicker a root grows toward its feet
ROOT_BODY_A = (70, 120, 160)  # a root's body, the seam over the plane: the crest row, then the inner rows
ROOT_ROW_DROP = (22 * D, 44 * D)  # the inner rows: how far below the ground line they stand
ROOT_ROW_SCALE = 0.7    # their size, as a share of a crest root's
ROOT_HAZE_A = 44        # the far haze in the arch under a root, in the rim
ROOT_LIT_A = 90         # the west half of a root's back catches the light
ROOTLET_A = 110         # the rootlets hanging into the arch, in the seam
ROOT_SEE_A = 48         # the plane's alpha in the arch under a crest root: the far layer shows through


def _root_crown(r, dx):
    """A root arch's back, px above the ground at `dx` from its crown (-1 past its feet)."""
    half = r["west"] if dx < 0 else r["east"]
    k = abs(dx) / half
    if k > 1:
        return -1.0
    return r["peak"] * (1 - k * k) ** 0.55 + r["knots"].get(dx, 0.0)


def _root_under(r, dx):
    """The underside of the arch at `dx`: the crown less the root's thickness, which
    flares toward the feet (a buttress), never under the ground."""
    half = r["west"] if dx < 0 else r["east"]
    k = abs(dx) / half
    return max(0.0, _root_crown(r, dx) - r["thick"] * (1 + ROOT_FLARE * k * k))


def _root_make(cx, rng, scale=1.0):
    r = {"form": "root", "x": cx, "west": int(rng.randint(*ROOT_HALF) * D * scale),
         "east": int(rng.randint(*ROOT_HALF) * D * scale), "peak": int(rng.randint(*ROOT_PEAK) * D * scale),
         "thick": max(2 * D, int(rng.randint(*ROOT_THICK) * D * scale)), "knots": {}}
    for _ in range(rng.randint(0, 2)):
        at, w, hgt = rng.randint(-r["west"] // 2, r["east"] // 2), rng.randint(3, 5) * D, rng.randint(1, 2) * D
        for o in range(-w, w + 1):
            r["knots"][at + o] = max(r["knots"].get(at + o, 0.0), hgt * (1 - (o / w) ** 2))
    return r


def _root_arch(teeth, cx, rng):
    """A great root arching from the ground to its crown at `cx` and back, into `teeth`
    (indices wrap); each side has its own reach, so it leans, and a knot or two swells
    its back."""
    r = _root_make(cx, rng)
    for dx in range(-r["west"], r["east"] + 1):
        v = _root_crown(r, dx)
        if v >= 0:
            i = (cx + dx) % BG_W
            teeth[i] = max(teeth[i], v)
    return r


def _root_paint(img, r, foot, far_tops, near_tops, rim, seam, body_a, rng):
    """One root standing on canvas row `foot`: its body in the seam, its west back lit,
    the far haze in the arch under it, rootlets hanging into the arch."""
    for dx in range(-r["west"], r["east"] + 1):
        v = _root_crown(r, dx)
        if v < 0:
            continue
        x = (r["x"] + dx) % BG_W
        top, under = foot - int(round(v)), foot - int(round(_root_under(r, dx)))
        lo = min(foot, near_tops[x] - 2 * D, BG_H)
        for y in range(max(top, far_tops[x] + 1, 0), lo):
            if not img.getpixel((x, y))[3]:
                continue
            if y > under:
                _over(img, x, y, rim, ROOT_HAZE_A)
                continue
            _over(img, x, y, seam, body_a)
            if dx < 0 and y < top + max(D, (under - top) // 2):
                _over(img, x, y, rim, ROOT_LIT_A)
        if far_tops[x] < top < lo and img.getpixel((x, top))[3]:
            _over(img, x, top, rim if dx < 0 else seam, 170)
        if under < lo and hash2(x // D, r["x"], 78) > 0.94:
            for y in range(under + 1, min(lo, under + 1 + rng.randint(3, 9) * D)):
                _over(img, x, y, seam, ROOTLET_A)


def _root_detail(img, roots, ground, far_tops, near_tops, rim, seam, light, rng):
    """The roots in the far plane (12.118): the crest's roots, then two inner rows of
    smaller ones lower and darker, and fungus glowing at a foot or two. Only inside
    the plane, under its crest and above the valley mist."""
    rows = [[(r, RIDGE_BASE - int(round(ground[r["x"] % BG_W]))) for r in roots]]
    for drop in ROOT_ROW_DROP:
        row, x = [], rng.randint(0, 20) * D
        while x < BG_W:
            row.append((_root_make(x, rng, ROOT_ROW_SCALE), RIDGE_BASE - int(round(ground[x % BG_W])) + drop))
            x += int(rng.randint(*ROOT_STEP) * D * ROOT_ROW_SCALE)
        rows.append(row)
    # Under a crest root's arch the plane thins, so the far layer shows through it,
    # except where another root's body crosses the arch.
    body, hollow = [set() for _ in range(BG_W)], [set() for _ in range(BG_W)]
    for r, foot in rows[0]:
        for dx in range(-r["west"], r["east"] + 1):
            v = _root_crown(r, dx)
            if v < 0:
                continue
            x = (r["x"] + dx) % BG_W
            top, under = foot - int(round(v)), foot - int(round(_root_under(r, dx)))
            body[x].update(range(top, under + 1))
            hollow[x].update(range(under + 1, foot))
    for x in range(BG_W):
        for y in hollow[x] - body[x]:
            if far_tops[x] < y < near_tops[x] - 2 * D and 0 <= y < BG_H:
                p = img.getpixel((x, y))
                if p[3]:
                    img.putpixel((x, y), p[:3] + (min(p[3], ROOT_SEE_A),))
    for k, row in enumerate(rows):
        for r, foot in row:
            _root_paint(img, r, foot, far_tops, near_tops, rim, seam, ROOT_BODY_A[k], rng)
    if not light:
        return
    for r, foot in rows[0]:
        for side in (-1, 1):
            if rng.random() < 0.4:
                continue
            half = r["west"] if side < 0 else r["east"]
            fx = r["x"] + side * int(half * rng.uniform(0.5, 0.75))
            fy = foot - D
            if far_tops[fx % BG_W] + 6 * D < fy < near_tops[fx % BG_W] - 2 * D:
                for xx in range(fx - D, fx + 2 * D):
                    _over(img, xx, fy, light, 230)
                    _over(img, xx, fy - D, light, 230)


def _ridge_profile(kind, rng, houses=None, ground=None):
    """The crest height (canvas px above RIDGE_BASE) per column: a rolling
    baseline with the zone's teeth raised onto it, seamless across the seam.
    A roofline's houses (or a row of spires and their bridges) are added to `houses`
    when a list is given, and the bare baseline to `ground`."""
    roll = _ridge_roll(rng)
    if ground is not None:
        ground.extend(roll)
    last = None
    teeth = [0.0] * BG_W
    roofs = [None] * BG_W
    x = rng.randint(0, 20) * D
    while x < BG_W:
        if kind == "mound":
            _tri(teeth, x, rng.randint(14, 26) * D, rng.randint(4, 10) * D)
            x += rng.randint(30, 60) * D
        elif kind == "fir":
            # A tiered tree (pass 635, 12.111); until then a plain triangle, and a
            # row of them read as a sawtooth band.
            half, peak, tiers = rng.randint(7, 12) * D, rng.randint(22, 46) * D, rng.randint(3, 5)
            _fir(teeth, x, half, peak, tiers)
            if houses is not None:
                houses.append({"form": "fir", "x": x, "half": half, "peak": peak, "tiers": tiers})
            x += rng.randint(10, 20) * D
        elif kind == "root":
            # A great root arching out of the ground and back in (pass 642, 12.118).
            root = _root_arch(teeth, x, rng)
            if houses is not None:
                houses.append(root)
            x += rng.randint(*ROOT_STEP) * D
        elif kind == "shard":
            _tri(teeth, x, rng.randint(4, 9) * D, rng.randint(26, 54) * D, lean=rng.randint(-4, 4) * D)
            x += rng.randint(12, 24) * D
        elif kind == "crag":
            _jag(teeth, x, rng.randint(10, 22) * D, rng.randint(14, 40) * D, rng)
            x += rng.randint(14, 30) * D
        elif kind == "spire":
            # A ruined spire, standing level on the ground at its centre (12.98).
            spire = _spire(rng, x, roll[x % BG_W])
            for dx, v in spire["roof"].items():
                i = (x + dx) % BG_W
                roofs[i] = max(roofs[i] or 0.0, v)
            # (After the spire is raised, so a bridge clears no part of its base.)
            whole = houses is not None and sum(1 for h in houses if h["form"] == "span") % 2 == 0
            span = _spire_span(rng, last, spire, roll, roofs, whole) if houses is not None and last else None
            if span:
                spire["bridged"] = True
                for sx in span["under"]:
                    roofs[sx % BG_W] = max(roofs[sx % BG_W] or 0.0, span["deck"])
                houses.append(span)
            if houses is not None:
                houses.append(spire)
            last = spire
            x += rng.randint(24, 46) * D
        else:  # roof
            # A house stands level (pass 598) at its centre's ground, not riding the
            # roll, so a row of houses never reads as waving cloth.
            house = _house(rng, x, roll[x % BG_W])
            for dx, v in house["roof"].items():
                i = (x + dx) % BG_W
                roofs[i] = max(roofs[i] or 0.0, v)
            if house["chimney"]:
                at, top = house["chimney"]
                for dx in range(at, at + 2 * D):
                    i = (x + dx) % BG_W
                    roofs[i] = max(roofs[i] or 0.0, top)
            if houses is not None:
                houses.append(house)
            x += rng.randint(14, 28) * D
    return [max(roll[i], roofs[i]) if roofs[i] is not None else roll[i] + teeth[i] for i in range(BG_W)]


# The ridge's body (design bible 12.83, pass 598). The grade after pass 595 read
# the ridge as a flat silhouette with an empty stretch under its crest (the plaza,
# the gear pit, the flooded hall): one colour from the crest to the bottom edge.
# Below the far crest a second, nearer crest of the same material now steps the
# ground into two planes, a band of valley mist parts them, each crest's west
# faces catch the light, and the zone's own distant detail sits in the far plane.
RIDGE_NEAR_DROP = 70 * D       # the near crest's resting y, below RIDGE_BASE
RIDGE_NEAR_SCALE = 0.55        # the near crest's height, as a share of the far one's
RIDGE_MIST = (3 * D, 3 * D, 3 * D, 4 * D)  # the mist bands above the near crest, nearest first
RIDGE_MIST_A = (88, 64, 42, 22)            # their rim alpha, thinning upward
RIDGE_FACE = 6 * D             # how far a lit west face reaches below its crest
RIDGE_FACE_A = 96
# Form in a natural ridge (bible 12.111, pass 635). The pass 630 grade still read the
# woods, mounds and crags as one-value cutouts: past the thin lit faces each plane was
# a single colour. Now the upper slopes catch the sky and fade, each east face falls
# into shadow, and the woods are rows of trees, each lit on its west flank.
RIDGE_FORMED = ("fir", "mound", "shard", "crag", "root")
RIDGE_SKY = 26 * D             # how far the sky's light reaches below a crest
RIDGE_SKY_A = (78, 46)         # its alpha at the crest, on the far plane and the near one
RIDGE_SHADE = 8 * D            # how far an east face's shadow reaches below its crest
RIDGE_SHADE_A = 150
FIR_FLANK_A = (64, 120)        # a tree's lit west flank (the rim) and shaded east one (the seam)
FIR_ROW_DROP = (26 * D, 50 * D)  # the inner rows of trees: how far below the ground line they stand
FIR_ROW_FILL_A = 96            # an inner tree's body, the seam over the plane
RIDGE_FOLD_DROP = (24 * D, 46 * D)  # the nearer folds of hills, crystal and crags, below the ground line
RIDGE_FOLD_SCALE = 0.45        # their height, as a share of the crest's
RIDGE_FOLD_FILL_A = (64, 104)  # each fold's body, the seam over the plane, darker nearer
RIDGE_FOLD_SKY = 12 * D        # the sky's light below a fold's crest
RIDGE_FOLD_SKY_A = 90
## The distant lights in a ridge's far plane, by zone: lit windows in the town and
## the Spires' halls, forge lamps in the Tower, crystal glints in the two crystal
## halls. Dark shades (index 2), so the ridge stays under the haze.
RIDGE_LIGHT = {
    "hearthroot": "gold-2", "spires": "ember-2", "tower": "ember-2", "trials": "gold-2",
    "vorrhallow": "crystal-2", "evercrown": "crystal-2",
    # Glowing fungus in the hollows under the Heartwood's roots (12.118).
    "heartwood": "sky-2",
}


def _over(img, x, y, name, alpha):
    """Lays palette colour `name` at `alpha` over what is there (wrapping sideways)."""
    if not 0 <= y < BG_H:
        return
    x = int(x) % BG_W
    under = img.getpixel((x, int(y)))
    img.putpixel((x, int(y)), blend(under, c(name), alpha) if under[3] else c(name, alpha))


def _ridge_shade(name):
    """One step darker on `name`'s ramp (index 0 stays itself)."""
    ramp, i = name.rsplit("-", 1)
    return f"{ramp}-{max(0, int(i) - 1)}"


def _ridge_plane(img, h, base, body, rim, body_a, faces=True, sky=0):
    """One crest plane: `h` (canvas px above `base` per column) filled down to the
    bottom edge in `body`, rimmed in `rim`, with each west face lit below the crest
    (unless `faces` is off: a roofline's houses light their walls instead). With
    `sky`, the upper slopes catch the sky's light at that alpha, fading downward, and
    each east face falls into shadow (12.111), so the plane is not one value."""
    seam = _ridge_shade(body)
    for x in range(BG_W):
        top = base - int(round(h[x]))
        for y in range(max(0, top), BG_H):
            put(img, x, y, c(body, body_a))
        if sky:
            for y in range(top + 1, min(BG_H, top + RIDGE_SKY)):
                _over(img, x, y, rim, sky * (top + RIDGE_SKY - y) // RIDGE_SKY)
            # (Over two columns a side, so a leaning shard's ragged edge shades whole.)
            fall = (h[x - 2] + h[x - 1] - h[x] - h[(x + 1) % BG_W]) / 2
            if fall > 0.5:
                depth = min(RIDGE_SHADE * 2, int(RIDGE_SHADE * (1 + min(fall, 4) / 4)))
                for y in range(top + 1, min(BG_H, top + depth)):
                    _over(img, x, y, seam, RIDGE_SHADE_A * (top + depth - y) // depth)
        # A face that rises to the east looks west, toward the light: it is lit
        # for RIDGE_FACE below the crest, deeper on a steep face.
        # (Over two columns a side since pass 635, so a leaning shard's ragged edge,
        # whose columns rise and fall in turn, lights whole instead of in stripes.)
        rise = (h[x] + h[(x + 1) % BG_W] - h[x - 1] - h[x - 2]) / 2
        if faces and rise > 0.5:
            depth = min(RIDGE_FACE * 2, int(RIDGE_FACE * (1 + min(rise, 4) / 4)))
            for y in range(top + 1, min(BG_H, top + depth)):
                _over(img, x, y, rim, RIDGE_FACE_A * (top + depth - y) // depth)
        put(img, x, top, c(rim, RIDGE_RIM_A))


TOWN_WALL = ((None, 0), ("seam", 56), ("rim", 30), ("seam", 28))  # a house's own wall tone
TOWN_ROOF_A = (40, 124)        # a roof's west slope (lit, the rim) and its east slope (the seam)
TOWN_FLOOR = 11 * D            # a storey's height
TOWN_WINDOW_SHARE = 0.62       # the share of storeys that show a window at all
TOWN_LIT_SHARE = 0.36          # and of windows that are lit
TOWN_GLOW_A = 46               # a lit window's glow on the wall round it


def _town_window(img, x, y, w, h, name, alpha, arched=False):
    for yy in range(h):
        for xx in range(w):
            if arched and yy < D and (xx < D or xx >= w - D):
                continue
            _over(img, x + xx, y + yy, name, alpha)


def _town_detail(img, houses, far_h, far_tops, near_tops, rim, seam, light):
    """The town's far plane (design bible 12.94): each house has a wall tone of its
    own, a roof lit on its west slope and dark on its east, a lit west wall and a
    shadowed east one, and a few windows of its own: no lattice runs through the row."""
    # A column belongs to the house whose roof is the crest there.
    owner = [None] * BG_W
    for k, hs in enumerate(houses):
        for dx, v in hs["roof"].items():
            i = (hs["cx"] + dx) % BG_W
            if abs(v - far_h[i]) < 0.5:
                owner[i] = k
    for k, hs in enumerate(houses):
        cols = [dx for dx in sorted(hs["roof"]) if owner[(hs["cx"] + dx) % BG_W] == k]
        if len(cols) < 4 * D:
            continue
        eave_y = RIDGE_BASE - int(round(hs["eave"]))
        peak_dx = max(cols, key=lambda dx: hs["roof"][dx])
        tone, tone_a = TOWN_WALL[int(hash2(hs["cx"] // D, k, 71) * len(TOWN_WALL)) % len(TOWN_WALL)]
        tone = {"seam": seam, "rim": rim, None: None}[tone]
        lean_west = hs["roof"][cols[0]] < hs["roof"][cols[-1]]
        for n, dx in enumerate(cols):
            x = (hs["cx"] + dx) % BG_W
            foot = near_tops[x] - 10 * D
            # The roof, from the crest down to the eave.
            lit_side = lean_west if hs["form"] == "lean" else dx < peak_dx
            for y in range(far_tops[x] + 1, min(eave_y, foot)):
                _over(img, x, y, rim if lit_side else seam, TOWN_ROOF_A[0 if lit_side else 1])
            if abs(dx) <= hs["half"] and eave_y > far_tops[x]:
                _over(img, x, eave_y, seam, 150)   # the eave's shadow line
            # The wall under it.
            for y in range(max(eave_y + 1, far_tops[x] + 1), foot):
                if tone:
                    _over(img, x, y, tone, tone_a)
                if n < 2 * D:
                    _over(img, x, y, rim, 64 - n * 8)          # the west wall, lit
                elif n >= len(cols) - D:
                    _over(img, x, y, seam, 150)                # the east edge, in shadow
        # Windows: a house's own few, storey by storey, never on a shared lattice.
        x0, x1 = hs["cx"] + cols[0] + 3 * D, hs["cx"] + cols[-1] - 3 * D
        foot = min(near_tops[(hs["cx"] + dx) % BG_W] for dx in cols) - 14 * D
        if hs["form"] == "tower":
            for n in range(2):
                wy = eave_y + (5 + n * 13) * D + int(hash2(k, n, 73) * 3) * D
                if wy + 4 * D < foot and hash2(k, n, 79) > 0.3:
                    lit = light and hash2(k, n, 83) > 0.55
                    _town_window(img, hs["cx"] - D // 2, wy, D, 4 * D, light if lit else seam, 230 if lit else 170)
            continue
        if hs["form"] == "gable" and hash2(k, 5, 89) > 0.6 and peak_dx in cols:
            # A small attic light under the peak.
            ay = RIDGE_BASE - int(round(hs["roof"][peak_dx])) + max(4 * D, int((hs["roof"][peak_dx] - hs["eave"]) * 0.45))
            if ay + 2 * D < eave_y:
                _town_window(img, hs["cx"] + peak_dx - D, ay, 2 * D, 2 * D, seam, 190)
        if hash2(k, 6, 97) > 0.55 and eave_y + TOWN_FLOOR < foot:
            # A jetty: the upper storey's beam across the wall.
            for x in range(x0 - 2 * D, x1 + 2 * D + 1):
                _over(img, x, eave_y + TOWN_FLOOR, seam, 96)
        floor = 0
        wy = eave_y + 3 * D
        while wy + 5 * D < foot and x1 - x0 >= 4 * D:
            floor += 1
            if hash2(k, floor, 101) < TOWN_WINDOW_SHARE:
                span = x1 - x0 - 3 * D
                wx = x0 + int(hash2(k, floor, 103) * (span // D + 1)) * D
                wyy = wy + int(hash2(k, floor, 107) * 3) * D
                kind = hash2(k, floor, 109)
                lit = light and hash2(k, floor, 113) < TOWN_LIT_SHARE
                name, alpha = (light, 230) if lit else (seam, 170)
                if kind < 0.55:
                    boxes = [(wx, wyy, 2 * D, 3 * D, False)]
                elif kind < 0.8:
                    boxes = [(wx, wyy, D, 3 * D, False), (wx + 2 * D, wyy, D, 3 * D, False)]
                else:
                    boxes = [(wx, wyy, 3 * D, 4 * D, True)]
                if lit:
                    # Its glow on the wall round it.
                    gx0, gx1 = boxes[0][0] - D, boxes[-1][0] + boxes[-1][2] + D
                    for yy in range(wyy - D, wyy + boxes[0][3] + D):
                        for xx in range(gx0, gx1):
                            _over(img, xx, yy, light, TOWN_GLOW_A)
                for bx, by, bw, bh, arched in boxes:
                    _town_window(img, bx, by, bw, bh, name, alpha, arched)
            wy += TOWN_FLOOR


SPIRE_WALL = ((None, 0), ("seam", 64), ("rim", 36), ("seam", 32), ("rim", 18))  # a spire's own wall tone
SPIRE_ROOF_A = (56, 132)       # a cone's west side (lit, the rim) and its east side (the seam)
SPIRE_LIT_A, SPIRE_SHADE_A = 96, 170  # a round wall: its lit west edge and its shadowed east edge
SPIRE_TERRACE = (8 * D, 19 * D, 32 * D, 47 * D)  # the hill's terraces, below its crest
SPIRE_NEAR_LIT_A = 120         # a near spire's lit west wall
SPIRE_TERRACE_A = 26           # how much darker each terrace's ground is than the one above


def _spire_detail(img, things, roll, far_h, far_tops, near_tops, rim, seam, light):
    """The Spires' far plane (design bible 12.98): the hill steps down in terraces of
    old walling, each spire stands on it with a wall tone of its own, round (lit on
    the west, dark on the east), banded by string courses, with a slit or two, and a
    bridge keeps a lit deck over a dark underside."""
    hill = [RIDGE_BASE - int(round(v)) for v in roll]
    # The hill: terraces that follow its crest, each band a little darker.
    for x in range(BG_W):
        foot = near_tops[x] - 10 * D
        lines = [hill[x] + off + int(round(math.sin(2 * math.pi * 3 * x / BG_W + k * 1.7) * 2 * D))
                 for k, off in enumerate(SPIRE_TERRACE)]
        for y in range(hill[x] + 1, foot):
            band = sum(1 for ly in lines if y >= ly)
            if band:
                _over(img, x, y, seam, SPIRE_TERRACE_A * band)
        for k, ly in enumerate(lines):
            # Stretches of walling still stand along a terrace: a lit lip over a dark line.
            if ly + D < foot and hash2(x // (22 * D), k, 137) > 0.38:
                for th in range(D):
                    _over(img, x, ly - D + th, rim, 52)
                    _over(img, x, ly + th, seam, 130)
    spires = [t for t in things if t["form"] != "span"]
    # A column belongs to the spire whose roof is the crest there.
    owner = [None] * BG_W
    for k, sp in enumerate(spires):
        for dx, v in sp["roof"].items():
            i = (sp["cx"] + dx) % BG_W
            if abs(v - far_h[i]) < 0.5:
                owner[i] = k
    for k, sp in enumerate(spires):
        cols = [dx for dx in sorted(sp["roof"]) if owner[(sp["cx"] + dx) % BG_W] == k]
        if len(cols) < 3 * D:
            continue
        half = sp["half"]
        tone, tone_a = SPIRE_WALL[int(hash2(sp["cx"] // D, k, 139) * len(SPIRE_WALL)) % len(SPIRE_WALL)]
        tone = {"seam": seam, "rim": rim, None: None}[tone]
        eave_y = RIDGE_BASE - int(round(sp["ground"] + sp["wall"]))
        base_y = RIDGE_BASE - int(round(sp["ground"] + sp["base"][1])) if sp["base"] else None
        for dx in cols:
            x = (sp["cx"] + dx) % BG_W
            foot = min(near_tops[x] - 10 * D, hill[x] + 1)
            for y in range(far_tops[x] + 1, foot):
                if tone:
                    _over(img, x, y, tone, tone_a)
                if sp["top"] == "needle" and abs(dx) <= half and y < eave_y:
                    # The cone, lit on its west side.
                    _over(img, x, y, rim if dx < 0 else seam, SPIRE_ROOF_A[0 if dx < 0 else 1])
                    continue
                # A round wall: the base's below its shoulder, the shaft's above.
                reach = sp["base"][0] if base_y is not None and (y > base_y or abs(dx) > half) else half
                u = (dx + reach) / (2 * reach)
                if u < 0.34:
                    _over(img, x, y, rim, int(SPIRE_LIT_A * (1 - u / 0.34)) + 10)
                elif u > 0.58:
                    _over(img, x, y, seam, int(50 + (SPIRE_SHADE_A - 50) * (u - 0.58) / 0.42))
            if abs(dx) <= half:
                if sp["top"] == "needle" and eave_y < foot:
                    _over(img, x, eave_y, seam, 160)        # the cone's eave
                if sp["top"] == "broken":
                    for th in range(1, D + 1):
                        _over(img, x, far_tops[x] + th, rim, 120)  # raw stone at the break
                if base_y is not None and far_tops[x] < base_y < foot:
                    _over(img, x, base_y, rim, 90)          # the shoulder's ledge under the shaft
                    _over(img, x, base_y + 1, seam, 150)
        shaft = [dx for dx in cols if abs(dx) <= half]
        if len(shaft) < 3 * D:
            continue
        low = min(near_tops[(sp["cx"] + dx) % BG_W] - 10 * D for dx in shaft)
        low = min(low, min(hill[(sp["cx"] + dx) % BG_W] for dx in shaft), base_y if base_y is not None else BG_H)
        # String courses band the shaft, at the spire's own spacing.
        y = eave_y + int(8 + hash2(k, 1, 149) * 8) * D
        n = 0
        while y + 2 * D < low:
            for dx in shaft:
                x = (sp["cx"] + dx) % BG_W
                if y > far_tops[x] + D:
                    _over(img, x, y - 1, rim, 44)
                    for th in range(D):
                        _over(img, x, y + th, seam, 120)
            n += 1
            y += int(11 + hash2(k, n, 151) * 9) * D
        # A crack runs down from a break.
        if sp["top"] == "broken":
            cx = sp["cx"] + min(shaft, key=lambda dx: sp["roof"][dx])
            cy = max(far_tops[(sp["cx"] + dx) % BG_W] for dx in shaft) + D
            for step in range(int(5 + hash2(k, 2, 157) * 6)):
                if cy + D >= low:
                    break
                for th in range(D):
                    _over(img, cx, cy + th, seam, 190)
                cy += D
                if hash2(k, step, 163) > 0.6:
                    cx += D // 2 if hash2(k, step, 167) > 0.5 else -D // 2
        # One or two slit windows high in the shaft, some lit; never the town's rows.
        sx = sp["cx"] - D // 2
        top = max(far_tops[(sp["cx"] + dx) % BG_W] for dx in shaft)
        for n, wy in enumerate((max(top, eave_y) + 5 * D, max(top, eave_y) + 19 * D)):
            if wy + 5 * D >= low - 2 * D or (n and hash2(sp["cx"] // D, 7, 61) < 0.5):
                continue
            lit = light and hash2(sp["cx"] // D, n, 67) > 0.45
            if lit:
                for yy in range(wy - D, wy + 6 * D):
                    for xx in range(sx - D, sx + 2 * D):
                        _over(img, xx, yy, light, 40)
            for yy in range(wy, wy + 5 * D):
                for xx in range(sx, sx + D):
                    _over(img, xx, yy, light if lit else seam, 230 if lit else 170)
    # Bridges: open sky under each, a lit deck and a dark underside.
    for span in (t for t in things if t["form"] == "span"):
        deck_y = RIDGE_BASE - int(round(span["deck"]))
        for x, v in span["under"].items():
            if abs(far_h[x % BG_W] - span["deck"]) > 0.5:
                continue
            under_y = RIDGE_BASE - int(round(v))
            solid_y = RIDGE_BASE - int(round(span["solid"][x]))
            for y in range(deck_y + 1, min(under_y, solid_y)):
                _over(img, x, y, seam, 70)
            for th in range(1, D + 1):
                _over(img, x, deck_y + th, rim, 70)
            if solid_y - under_y > 2 * D:
                for y in range(under_y, solid_y):
                    put(img, x, y, CLEAR)
                for th in range(1, D + 1):
                    _over(img, x, under_y - th, seam, 170)
                put(img, x, solid_y, c(rim, RIDGE_RIM_A))


def _fir_tree(img, cx, foot, half, peak, tiers, rim, seam, fill_a, below):
    """One tiered fir standing on canvas row `foot` at column `cx`: its west flank lit,
    its east flank shaded, and with `fill_a` its body laid in the seam first (a tree of
    an inner row, standing out from the plane behind it). Paints only inside the
    plane, and only below row `below[x]` (the plane's crest)."""
    for dx in range(-half, half + 1):
        v = _fir_height(half, peak, tiers, abs(dx))
        if v < 0:
            continue
        x = (cx + dx) % BG_W
        top = foot - int(round(v))
        for y in range(max(top, below[x] + 1, 0), min(foot, BG_H)):
            if not img.getpixel((x, y))[3]:
                continue
            if fill_a:
                _over(img, x, y, seam, fill_a)
            if dx < 0:
                _over(img, x, y, rim, FIR_FLANK_A[0])
            elif dx > half // 6:
                _over(img, x, y, seam, FIR_FLANK_A[1])
        if fill_a and top > below[x] and 0 <= top < BG_H and img.getpixel((x, top))[3]:
            # An inner tree's own edge: lit on the west, dark on the east.
            _over(img, x, top, rim if dx < 0 else seam, 170)


def _fir_detail(img, trees, ground, far_tops, rim, seam, rng):
    """The woods (12.111): every tree on the crest is lit on its west flank and shaded
    on its east, and two inner rows of trees stand lower in the plane, each darker
    than the last, so the far plane is a forest in depth rather than one flat band."""
    for t in trees:
        foot = RIDGE_BASE - int(round(ground[t["x"] % BG_W]))
        _fir_tree(img, t["x"], foot, t["half"], t["peak"], t["tiers"], rim, seam, 0, far_tops)
    for row, drop in enumerate(FIR_ROW_DROP):
        x = rng.randint(0, 12) * D
        while x < BG_W:
            half, peak, tiers = rng.randint(6, 10) * D, rng.randint(18, 34) * D, rng.randint(3, 4)
            foot = RIDGE_BASE - int(round(ground[x % BG_W])) + drop
            _fir_tree(img, x, foot, half, peak, tiers, rim, seam, FIR_ROW_FILL_A + 40 * row, far_tops)
            x += rng.randint(14, 26) * D


def _ridge_folds(img, kind, ground, far_tops, rim, seam, rng):
    """Hills, crystal and crags (12.111): two nearer folds of the same material stand
    lower in the far plane, each darker than the last, with a lit crest line and the
    sky's light fading below it, so the plane steps back in depth instead of being
    one flat band."""
    for row, drop in enumerate(RIDGE_FOLD_DROP):
        h = [v * RIDGE_FOLD_SCALE for v in _ridge_profile(kind, rng)]
        for x in range(BG_W):
            top = RIDGE_BASE - int(round(ground[x] + h[x])) + drop
            for y in range(max(top, far_tops[x] + 1, 0), BG_H):
                if not img.getpixel((x, y))[3]:
                    continue
                _over(img, x, y, seam, RIDGE_FOLD_FILL_A[row])
                if y < top + RIDGE_FOLD_SKY:
                    _over(img, x, y, rim, RIDGE_FOLD_SKY_A * (top + RIDGE_FOLD_SKY - y) // RIDGE_FOLD_SKY)
            if far_tops[x] < top < BG_H and img.getpixel((x, top))[3]:
                _over(img, x, top, rim, 150)


def _ridge_detail(img, zone, far_h, near_tops, rng, houses=None, ground=None):
    """The zone's distant detail in the far plane, between its crest and the mist."""
    kind = RIDGE_KIND[zone]
    body, rim = RIDGE_COLOR[zone]
    seam = _ridge_shade(body)
    light = RIDGE_LIGHT.get(zone)
    far_tops = [RIDGE_BASE - int(round(v)) for v in far_h]
    if kind == "roof":
        _town_detail(img, houses or [], far_h, far_tops, near_tops, rim, seam, light)
        return
    if kind == "spire":
        _spire_detail(img, houses or [], ground, far_h, far_tops, near_tops, rim, seam, light)
        return
    if kind == "root":
        _root_detail(img, houses or [], ground, far_tops, near_tops, rim, seam, light, rng)
        return
    if kind == "fir":
        _fir_detail(img, houses or [], ground, far_tops, rim, seam, rng)
    elif kind in RIDGE_FORMED:
        _ridge_folds(img, kind, ground, far_tops, rim, seam, rng)
    if kind == "crag":
        # Strata: short broken ledges slanting through the rock, each a dark
        # bedding line under a lit lip.
        for k in range(5):
            y0 = RIDGE_BASE - 24 * D + k * 18 * D + rng.randint(-5, 5) * D
            slope = rng.choice((-0.3, -0.2, 0.2, 0.3))
            for x in range(BG_W):
                y = int(y0 + slope * (((x + k * 97 * D) % (90 * D)) - 45 * D))
                if far_tops[x] + 6 * D < y < near_tops[x] - 12 * D and hash2(x // (14 * D), k, 41) > 0.5:
                    _over(img, x, y - D, rim, 56)
                    for th in range(D):
                        _over(img, x, y + th, seam, 170)
    elif kind == "shard":
        # Facets: a dark cleft down the middle of each spire of crystal.
        for x in range(1, BG_W - 1):
            if far_h[x] > far_h[x - 1] and far_h[x] >= far_h[x + 1] and far_h[x] > 18 * D:
                for y in range(far_tops[x] + 3 * D, min(near_tops[x] - 8 * D, far_tops[x] + int(far_h[x] * 0.8))):
                    _over(img, x, y, seam, 220)
                    _over(img, x + 1, y, seam, 140)
    if not light:
        return
    # Distant lights: small and few, a dark shade that the haze recedes further.
    count = 14
    placed = 0
    for _ in range(count * 20):
        if placed >= count:
            break
        x = rng.randrange(BG_W)
        y = rng.randrange(RIDGE_BASE - 100 * D, RIDGE_BASE + RIDGE_NEAR_DROP)
        if not (far_tops[x] + 6 * D < y < near_tops[x] - 12 * D):
            continue
        w, hh = (D, 2 * D) if kind == "shard" else (D, D)
        for yy in range(y, y + hh):
            for xx in range(x, x + w):
                _over(img, xx, yy, light, 230)
        placed += 1


# The crystal halls' near plane (design bible 12.124, pass 648). The pass 645 grade read
# the Evercrown's backdrop as a dead void of flat purple: under its shard crest the near
# plane was one fill to the layer's foot, and its lights did not show, since its body is
# the darkest step of the ramp and the plane's rim was that same step. The near plane is
# now lit in the next step up, and two rows of great crystal masses grow up through it
# from below, each a leader and lesser shards, lit on the west facet, dark on the east,
# with a lit west edge and a few glints, the nearer row darker.
NEAR_MASS_ROWS = (  # per row: the foot (canvas px below the near crest's base), height range, alpha of body, lit facet, edge, dark facet
    {"foot": 150 * D, "tall": (105 * D, 150 * D), "half": (16, 26), "step": (30, 52), "body": 34, "lit": 72, "edge": 120, "dark": 70},
    {"foot": 172 * D, "tall": (60 * D, 92 * D), "half": (18, 30), "step": (40, 70), "body": 16, "lit": 44, "edge": 84, "dark": 110},
)
NEAR_MASS_CLEAR = 8 * D   # a mass's tip stays this far under the near crest
NEAR_GLINT_SHARE = 0.5    # the share of masses with a glint on their lit facet


def _near_shard(img, fx, fy, half, length, ang, row, rim, seam, glint, tops, rng):
    """One great shard of the near plane, rooted at fx, fy (canvas px) and pointing
    along `ang` (radians from straight up, east positive): its west facet lit, its
    east facet dark, its west edge lit, laid in D-pixel blocks over the plane only."""
    ux, uy = math.sin(ang), -math.cos(ang)       # along the shard, foot to tip
    px, py = -uy, ux                              # across it, west to east (for a shard pointing up)
    tx, ty = fx + ux * length, fy + uy * length
    cut = []
    xs = [fx - px * half, fx + px * half, tx]
    ys = [fy - py * half, fy + py * half, ty]
    x0, x1 = int(min(xs)) // D * D, int(max(xs)) + D
    y0, y1 = max(0, int(min(ys)) // D * D), min(BG_H, int(max(ys)) + D)
    for by in range(y0, y1, D):
        for bx in range(x0, x1, D):
            cx, cy = bx + D / 2 - fx, by + D / 2 - fy
            along = cx * ux + cy * uy
            if not 0 <= along <= length:
                continue
            across = cx * px + cy * py
            w = half * (1 - along / length)
            if abs(across) > w:
                continue
            if by < tops[bx % BG_W] + NEAR_MASS_CLEAR:
                continue
            cut.append((bx, by, across, w))
    for bx, by, across, w in cut:
        name, alpha = (rim, row["lit"]) if across < 0 else (seam, row["dark"])
        if across < 0 and across < -w + D:
            alpha = row["edge"]                   # the lit west edge
        for yy in range(by, by + D):
            for xx in range(bx, bx + D):
                if img.getpixel((xx % BG_W, yy))[3]:
                    _over(img, xx, yy, rim, row["body"])
                    _over(img, xx, yy, name, alpha)
    if glint and cut and rng.random() < NEAR_GLINT_SHARE:
        lit = [k for k in cut if k[2] < -k[3] * 0.3]
        if lit:
            bx, by, _, _ = lit[rng.randrange(len(lit))]
            for yy in range(by, by + 2 * D):
                for xx in range(bx, bx + D):
                    _over(img, xx, yy, glint, 200)
    return len(cut)


def _near_crystal(img, near_tops, near_base, rim, seam, glint, rng):
    """Two rows of great crystal masses through the crystal halls' near plane (12.124).
    Returns each mass: its foot, lean, reach and how many blocks it laid."""
    masses = []
    for row in NEAR_MASS_ROWS:
        x = rng.randint(0, 20) * D
        while x < BG_W:
            fy = near_base + row["foot"] + rng.randint(-6, 6) * D
            lean = rng.uniform(-0.18, 0.18)
            # Its tip stays under the near crest rather than being cut off by it.
            room = (fy - near_tops[x % BG_W] - 2 * NEAR_MASS_CLEAR) / math.cos(lean)
            reach = min(rng.randint(*row["tall"]), int(room))
            half = rng.randint(*row["half"]) * D
            mass = {"x": x, "foot": fy, "lean": lean, "reach": reach, "blocks": 0}
            # The lesser shards first, fanned beside the leader, so it lies over them.
            for _ in range(rng.randint(1, 3)):
                f = lean + rng.choice((-1, 1)) * rng.uniform(0.2, 0.45)
                at = x + rng.randint(-half // D, half // D) * D
                mass["blocks"] += _near_shard(img, at, fy, half * rng.uniform(0.5, 0.75), reach * rng.uniform(0.45, 0.75),
                                              f, row, rim, seam, None, near_tops, rng)
            mass["blocks"] += _near_shard(img, x, fy, half, reach, lean, row, rim, seam, glint, near_tops, rng)
            masses.append(mass)
            x += rng.randint(*row["step"]) * D
    return masses


def ridge(zone):
    """The distant ridgeline silhouette for `zone` (design bible 12.12): the
    zone's far crest filled from the horizon down, over a transparent sky, so
    Backdrop can recede it into the haze between the far and mid layers. Its
    body (12.83) is two planes, the near one under a band of valley mist, with
    lit west faces and the zone's distant detail."""
    img = Image.new("RGBA", (BG_W, BG_H), CLEAR)
    body, rim = RIDGE_COLOR[zone]
    rng = random.Random(sum(ord(ch) for ch in zone) + 1300)
    houses, ground = [], []
    h = _ridge_profile(RIDGE_KIND[zone], rng, houses, ground)
    faces = RIDGE_KIND[zone] != "roof"  # a roofline lights its walls, not its slopes
    formed = RIDGE_KIND[zone] in RIDGE_FORMED
    _ridge_plane(img, h, RIDGE_BASE, body, rim, RIDGE_A, faces, RIDGE_SKY_A[0] if formed else 0)
    # The nearer crest, of the same material and lower, and its own seed.
    near_rng = random.Random(sum(ord(ch) for ch in zone) + 2600)
    near_ground = []
    near = [v * RIDGE_NEAR_SCALE for v in _ridge_profile(RIDGE_KIND[zone], near_rng, None, near_ground)]
    near_base = RIDGE_BASE + RIDGE_NEAR_DROP
    near_tops = [near_base - int(round(v)) for v in near]
    # The mist lies on the near plane's crest; under a row of spires, on the ground
    # they stand on (12.98), or every near spire would wear a pale cap of it.
    spires = RIDGE_KIND[zone] == "spire"
    mist_tops = [near_base - int(round(v * RIDGE_NEAR_SCALE)) for v in near_ground] if spires else near_tops
    _ridge_detail(img, zone, h, mist_tops, near_rng, houses, ground)
    # Valley mist over the far plane's foot, thinning upward from the near crest.
    for x in range(BG_W):
        y = mist_tops[x]
        for band, alpha in zip(RIDGE_MIST, RIDGE_MIST_A):
            for yy in range(max(0, y - band), y):
                under = img.getpixel((x, yy))
                if under[3]:
                    img.putpixel((x, yy), blend(under, c(rim), alpha))
            y -= band
    # A body at the bottom of its ramp has no darker step, so the near plane's light is
    # the far plane's rim (12.124): until pass 648 the crystal halls' near plane was lit
    # in its own fill and showed nothing.
    near_body = _ridge_shade(body)
    near_rim = rim if near_body == body else body
    _ridge_plane(img, near, near_base, near_body, near_rim, 255, faces, RIDGE_SKY_A[1] if formed else 0)
    if RIDGE_KIND[zone] == "shard":
        _near_crystal(img, near_tops, near_base, near_rim, "night-0", RIDGE_LIGHT.get(zone), near_rng)
    if spires:
        # A near spire's west wall catches the light down to the ground it stands on.
        for x in range(BG_W):
            if near[x] - near[x - 1] > 3 * D:
                for k in range(D):
                    for y in range(near_tops[(x + k) % BG_W] + 1, mist_tops[(x + k) % BG_W]):
                        _over(img, x + k, y, body, SPIRE_NEAR_LIT_A)
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
        save_png(far(), BG / f"{zone}_far.png")
        if mid:
            save_png(mid(), BG / f"{zone}_mid.png")
    for zone in RIDGE_KIND:
        save_png(ridge(zone), BG / f"{zone}_ridge.png")
    for zone in FORE_KIND:
        save_png(foreground(zone), BG / f"{zone}_fore.png")
    for zone in HANG_KIND:
        save_png(hanging(zone), BG / f"{zone}_hang.png")


if __name__ == "__main__":
    main()
