#!/usr/bin/env python3
"""Generates the shop's pictures (design bible 12.44 and 13.3): one icon for every
item in data/items.json and one portrait for every person in data/npcs.json who
has a "look", drawn with tools/art/pixelrig.py on the master palette.

Both are drawn at 2x density, like the HUD's icons: an icon is 14 UI pixels
square (28 texels), a portrait 40 (80 texels). A portrait faces left, toward the
list it sits beside, and is lit from the top left like everything else.

Writes assets/ui/item_icons.png and .json ({"cell", "columns", "items": {id: index}})
and assets/ui/portraits.png and .json ({"cell", "columns", "people": {id: index}}).
A new item needs a painter here (by id, or its kind's); a test checks that every
item and every shopkeeper has a picture. Rerun after adding an item or a person.

Usage: python3 tools/art/icongen.py [--sheet OUT.png]   (a 4x contact sheet to look at)
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelrig import PAL, ROOT, Canvas, mat, mat_from  # noqa: E402

UI = ROOT / "assets" / "ui"
ICON = 14        # UI pixels
PORTRAIT = 40
SCALE = 2
ICON_COLUMNS = 8
PORTRAIT_COLUMNS = 8
DARK = PAL["night-1"]

STEEL = mat("stone", 7, 6, 4, 2)
IRON = mat("stone", 5, 4, 3, 1)
GOLD = mat("gold", 6, 5, 3, 1)
WOOD = mat("bark", 4, 3, 2, 0)
LEATHER = mat("umber", 4, 3, 2, 0)
PARCHMENT = mat("ochre", 7, 6, 4, 2)
GLASS = mat("sky", 7, 6, 5, 3)
CORK = mat("bark", 5, 4, 3, 1)


def icon():
    return Canvas(ICON, ICON, (0, 0), SCALE)


# --- Blades -------------------------------------------------------------------

def blade(length, width, steel=STEEL, guard=GOLD, grip=WOOD, guard_len=2.0, fuller=None):
    """A sword laid from the lower left to the upper right."""
    def paint():
        cv = icon()
        hx, hy = 4.2, 9.8                      # where blade meets guard
        tx, ty = hx + length * 0.7071, hy - length * 0.7071
        cv.part(cv.capsule((hx - 0.6, hy + 0.6), (hx - 2.2, hy + 2.2), 0.75), grip)
        cv.part(cv.ellipse((hx - 2.6, hy + 2.6), 1.0, 1.0), guard)
        w = width * 0.7071
        body = cv.polygon([(hx - w, hy - w), (hx + w, hy + w), (tx + w - 1.0, ty + w + 1.0), (tx + 0.6, ty - 0.6),
                           (tx - w - 1.0, ty - w + 1.0)])
        cv.part(body, steel)
        if fuller is not None:
            cv.flat(cv.capsule((hx + 0.6, hy - 0.6), (tx - 1.6, ty + 1.6), 0.3) & body, fuller)
        g = guard_len * 0.7071
        cv.part(cv.capsule((hx - g, hy - g), (hx + g, hy + g), 0.8), guard)
        return cv.finish()[0]
    return paint


# --- Armor --------------------------------------------------------------------

def armor(body, trim=None, rivets=None, pauldrons=None, band=None):
    """A sleeveless coat seen from the front."""
    def paint():
        cv = icon()
        torso = cv.polygon([(3.0, 2.5), (5.2, 1.5), (7.0, 3.0), (8.8, 1.5), (11.0, 2.5), (12.2, 5.0), (10.4, 6.0),
                            (10.6, 12.5), (3.4, 12.5), (3.6, 6.0), (1.8, 5.0)])
        cv.part(torso, body, deep=True)
        if band is not None:
            cv.part(torso & cv.below(9.6) & ~cv.below(11.0), band)
        if trim is not None:
            cv.part(cv.polygon([(5.2, 1.5), (7.0, 3.0), (8.8, 1.5), (8.2, 1.5), (7.0, 4.4), (5.8, 1.5)]) & torso, trim)
            cv.part(cv.capsule((7.0, 4.4), (7.0, 12.0), 0.3) & torso, trim)
        if pauldrons is not None:
            cv.part(cv.ellipse((3.2, 3.6), 2.2, 1.7), pauldrons)
            cv.part(cv.ellipse((10.8, 3.6), 2.2, 1.7), pauldrons)
        if rivets is not None:
            for x, y in ((4.5, 7.5), (9.0, 7.5), (4.5, 10.5), (9.0, 10.5), (5.5, 5.0), (8.0, 5.0)):
                cv.flat(cv.ellipse((x + 0.25, y + 0.25), 0.3, 0.3), rivets)
        return cv.finish()[0]
    return paint


# --- Shields and the helm -----------------------------------------------------

def buckler():
    cv = icon()
    cv.part(cv.ellipse((7, 7), 5.6, 5.6), WOOD, deep=True)
    ring = cv.ellipse((7, 7), 5.6, 5.6) & ~cv.ellipse((7, 7), 4.4, 4.4)
    cv.part(ring, IRON)
    cv.part(cv.ellipse((7, 7), 1.9, 1.9), STEEL)
    return cv.finish()[0]


def kite(face, rim, device=None, glow=None):
    def paint():
        cv = icon()
        outer = [(2.2, 1.6), (11.8, 1.6), (11.8, 6.5), (7.0, 13.2), (2.2, 6.5)]
        inner = [(3.4, 2.8), (10.6, 2.8), (10.6, 6.2), (7.0, 11.4), (3.4, 6.2)]
        cv.part(cv.polygon(outer), rim)
        cv.part(cv.polygon(inner), face, deep=True)
        if device is not None:
            cv.part(cv.capsule((7.0, 3.6), (7.0, 9.6), 0.55), device)
            cv.part(cv.capsule((4.6, 5.2), (9.4, 5.2), 0.55), device)
        if glow is not None:
            cv.part(cv.polygon([(7.0, 3.8), (9.0, 6.0), (7.0, 9.0), (5.0, 6.0)]), glow)
            cv.flat(cv.ellipse((6.5, 5.6), 0.5, 0.5), PAL["crystal-7"])
        return cv.finish()[0]
    return paint


def helm():
    cv = icon()
    metal = mat("sky", 6, 5, 3, 1)
    # A swept wing behind the dome, then the dome, brow band and cheek guard.
    cv.part(cv.polygon([(8.5, 6.0), (13.2, 1.0), (12.2, 4.6), (13.0, 5.0), (10.5, 7.5)]), mat("stone", 7, 6, 5, 3))
    cv.part(cv.ellipse((6.4, 7.2), 4.8, 5.2) & ~cv.below(9.0), metal, deep=True)
    cv.part(cv.polygon([(1.6, 8.2), (11.2, 8.2), (11.2, 9.6), (1.6, 9.6)]), GOLD)
    cv.part(cv.polygon([(7.6, 9.6), (10.8, 9.6), (10.2, 12.6), (8.6, 12.6)]), metal)
    cv.part(cv.capsule((2.8, 9.6), (2.8, 11.6), 0.6), metal)
    cv.flat(cv.ellipse((6.2, 5.0), 0.6, 0.6), PAL["crystal-6"])
    return cv.finish()[0]


# --- Keys, fruit, dew, balm and draught ----------------------------------------

def key(metal, teeth=2, thorn=False):
    def paint():
        cv = icon()
        bow = cv.ellipse((4.2, 4.2), 3.0, 3.0) & ~cv.ellipse((4.2, 4.2), 1.3, 1.3)
        cv.part(bow, metal)
        cv.part(cv.capsule((6.2, 6.2), (11.6, 11.6), 0.85), metal)
        for i in range(teeth):
            a = 9.2 + i * 2.0
            cv.part(cv.capsule((a, a), (a - 1.7, a + 1.7), 0.6), metal)
        if thorn:
            # Three thorns off the bow, each a short spike pointing away from its center.
            for dx, dy in ((-0.7071, -0.7071), (0.5, -0.866), (-0.866, 0.5)):
                bx, by = 4.2 + dx * 2.6, 4.2 + dy * 2.6
                cv.part(cv.polygon([(bx - dy * 0.9, by + dx * 0.9), (bx + dy * 0.9, by - dx * 0.9),
                                    (4.2 + dx * 4.4, 4.2 + dy * 4.4)]), mat("ember", 5, 4, 3, 1))
        return cv.finish()[0]
    return paint


def life_fruit():
    cv = icon()
    cv.part(cv.capsule((7.0, 4.0), (8.2, 1.6), 0.5), WOOD)
    cv.part(cv.ellipse((10.0, 2.6), 2.2, 1.2), mat("leaf", 6, 5, 3, 1))
    fruit = cv.ellipse((5.4, 8.2), 3.9, 4.3) | cv.ellipse((8.6, 8.2), 3.9, 4.3)
    cv.part(fruit, mat("ember", 6, 5, 3, 1), deep=True)
    cv.flat(cv.ellipse((4.6, 6.4), 0.9, 1.2), PAL["ember-7"])
    return cv.finish()[0]


def mana_dew():
    cv = icon()
    drop = cv.ellipse((7.0, 8.6), 4.2, 4.2) | cv.polygon([(7.0, 1.2), (10.4, 6.6), (3.6, 6.6)])
    cv.part(drop, mat("sky", 6, 5, 3, 1), deep=True)
    cv.flat(cv.capsule((5.2, 7.2), (4.8, 9.2), 0.6), PAL["sky-7"])
    cv.flat(cv.ellipse((8.6, 10.8), 0.6, 0.6), PAL["sky-6"])
    return cv.finish()[0]


def balm():
    """Barkbalm: a squat bark tin with a leaf pressed into the lid."""
    cv = icon()
    cv.part(cv.polygon([(2.0, 6.5), (12.0, 6.5), (11.4, 12.4), (2.6, 12.4)]), WOOD, deep=True)
    cv.part(cv.polygon([(1.4, 3.6), (12.6, 3.6), (12.6, 6.6), (1.4, 6.6)]) | cv.ellipse((7.0, 3.8), 5.6, 1.6), CORK)
    cv.part(cv.ellipse((7.0, 4.4), 2.8, 1.2), mat("leaf", 6, 5, 3, 1))
    cv.part(cv.polygon([(2.3, 8.6), (11.7, 8.6), (11.6, 10.0), (2.4, 10.0)]), mat("leaf", 5, 4, 2, 1))
    return cv.finish()[0]


def flask(liquid, glint):
    """A round-bellied flask, corked."""
    def paint():
        cv = icon()
        cv.part(cv.polygon([(5.8, 1.2), (8.2, 1.2), (8.2, 3.0), (5.8, 3.0)]), CORK)
        neck = cv.polygon([(5.6, 3.0), (8.4, 3.0), (8.4, 6.0), (5.6, 6.0)])
        belly = cv.ellipse((7.0, 9.0), 4.6, 4.0)
        cv.part(neck | belly, GLASS)
        fill = cv.ellipse((7.0, 9.0), 3.7, 3.1) & cv.below(7.4)
        cv.part(fill, liquid)
        cv.flat(cv.capsule((4.6, 8.6), (4.8, 10.0), 0.4), glint)
        return cv.finish()[0]
    return paint


def dye(color):
    """A stoppered dye pot with a cloth swatch of the color over its lip."""
    def paint():
        tint = mat_from(color) if color else mat("leaf", 5, 4, 3, 1)
        cv = icon()
        cv.part(cv.polygon([(3.0, 5.4), (11.0, 5.4), (12.0, 8.0), (11.0, 12.6), (3.0, 12.6), (2.0, 8.0)]),
                mat("ash", 6, 5, 3, 1), deep=True)
        cv.part(cv.polygon([(3.6, 3.4), (10.4, 3.4), (10.4, 5.6), (3.6, 5.6)]), mat("ash", 5, 4, 3, 1))
        cv.part(cv.ellipse((7.0, 3.4), 2.9, 1.3), tint)
        # The swatch hangs down the front.
        cv.part(cv.polygon([(5.0, 3.6), (9.2, 3.6), (9.6, 10.4), (7.4, 9.4), (5.2, 10.6)]), tint, deep=True)
        return cv.finish()[0]
    return paint


# --- The smith's tempers, charts and scrolls -----------------------------------

def temper(level):
    def paint():
        cv = icon()
        cv.part(cv.polygon([(1.4, 6.2), (12.4, 6.2), (11.4, 8.6), (8.8, 8.6), (8.8, 10.6), (10.6, 12.6), (3.4, 12.6),
                            (5.2, 10.6), (5.2, 8.6), (3.8, 8.6)]), IRON, deep=True)
        # A hammer over the anvil, and a spark for each fold.
        cv.part(cv.capsule((8.4, 4.6), (12.2, 1.6), 0.55), WOOD)
        cv.part(cv.polygon([(5.4, 2.6), (8.0, 1.2), (9.4, 3.6), (6.8, 5.0)]), STEEL)
        sparks = [(3.2, 3.6)] + ([(1.8, 1.6)] if level > 1 else [])
        for sx, sy in sparks:
            cv.part(cv.capsule((sx - 1.0, sy), (sx + 1.0, sy), 0.3) | cv.capsule((sx, sy - 1.0), (sx, sy + 1.0), 0.3),
                    mat("crystal", 7, 6, 5, 3) if level > 1 else mat("gold", 7, 6, 5, 3))
        return cv.finish()[0]
    return paint


ZONE_INK = {"hearthroot": "gold", "heartwood": "leaf", "tower": "stone", "haar": "sky", "boughs": "moss",
            "spires": "crystal", "vorrhallow": "night", "sunken": "sky"}


def chart(zone):
    """An unrolled chart, inked in its zone's color."""
    def paint():
        ink = mat(ZONE_INK.get(zone, "bark"), 5, 4, 3, 1)
        cv = icon()
        cv.part(cv.polygon([(2.2, 2.6), (11.8, 2.6), (11.8, 11.4), (2.2, 11.4)]), PARCHMENT, deep=True)
        cv.part(cv.capsule((1.6, 2.2), (12.4, 2.2), 0.9), mat("ochre", 6, 5, 3, 1))
        cv.part(cv.capsule((1.6, 11.8), (12.4, 11.8), 0.9), mat("ochre", 6, 5, 3, 1))
        # A road, a ridge and the place it marks.
        cv.flat(cv.capsule((3.6, 9.4), (6.0, 7.2), 0.3) | cv.capsule((6.0, 7.2), (8.2, 8.0), 0.3)
                | cv.capsule((8.2, 8.0), (10.2, 5.0), 0.3), ink[2])
        cv.flat(cv.polygon([(3.6, 6.4), (5.0, 4.4), (6.4, 6.4)]), ink[1])
        cv.flat(cv.ellipse((10.2, 5.0), 0.8, 0.8), PAL["ember-4"])
        return cv.finish()[0]
    return paint


def scroll(seal):
    """A rolled scroll, tied and sealed in its spell's color."""
    def paint():
        wax = mat(seal, 6, 5, 3, 1)
        cv = icon()
        cv.part(cv.capsule((3.0, 10.6), (10.6, 3.0), 2.5), PARCHMENT, deep=True)
        cv.part(cv.ellipse((11.0, 2.8), 1.9, 1.9), mat("ochre", 6, 5, 3, 1))
        cv.flat(cv.ellipse((11.0, 2.8), 0.8, 0.8), PAL["ochre-2"])
        cv.part(cv.capsule((4.6, 5.4), (8.4, 9.2), 0.6), wax)
        cv.part(cv.ellipse((6.6, 7.4), 1.7, 1.7), wax)
        cv.flat(cv.ellipse((6.2, 7.0), 0.4, 0.4), PAL[f"{seal}-7"])
        return cv.finish()[0]
    return paint


def ring(metal, stone, lit):
    """A finger ring seen from the front, its stone set on top."""
    def paint():
        cv = icon()
        cv.part(cv.ellipse((7.0, 8.6), 4.2, 4.2) & ~cv.ellipse((7.0, 8.6), 2.7, 2.7), metal)
        cv.part(cv.ellipse((7.0, 3.9), 2.2, 1.9), stone, deep=True)
        cv.flat(cv.ellipse((6.4, 3.4), 0.5, 0.5), lit)
        return cv.finish()[0]
    return paint


def torc():
    """An open collar, its two ends each a small cup."""
    cv = icon()
    metal = mat("stone", 7, 6, 4, 2)
    band = cv.ellipse((7.0, 6.4), 5.2, 5.0) & ~cv.ellipse((7.0, 6.4), 3.7, 3.5)
    gap = cv.polygon([(7.0, 6.4), (4.4, 13.6), (9.6, 13.6)])
    cv.part(band & ~gap, metal)
    for x in (4.9, 9.1):
        cv.part(cv.ellipse((x, 10.9), 1.5, 1.5), metal, deep=True)
        cv.flat(cv.ellipse((x, 10.7), 0.6, 0.5), PAL["sky-6"])
    return cv.finish()[0]


def knot():
    """A cord tied in a loop, both ends hanging."""
    cv = icon()
    cord = mat("ochre", 6, 5, 3, 1)
    cv.part(cv.ellipse((7.0, 5.0), 3.8, 3.4) & ~cv.ellipse((7.0, 5.0), 2.2, 1.9), cord)
    cv.part(cv.capsule((6.2, 8.2), (3.6, 12.6), 0.8), cord)
    cv.part(cv.capsule((7.8, 8.2), (10.4, 12.6), 0.8), cord)
    cv.part(cv.ellipse((7.0, 8.2), 1.5, 1.3), mat("leaf", 6, 5, 3, 1), deep=True)
    return cv.finish()[0]


BY_ID = {
    "amber_band": ring(GOLD, mat("gold", 7, 6, 4, 2), PAL["gold-7"]),
    "whetstone_ring": ring(mat("stone", 6, 5, 3, 1), mat("ash", 5, 4, 3, 1), PAL["ash-6"]),
    "dewcatch_torc": torc,
    "stride_knot": knot,
    "short_sword": blade(7.0, 0.9),
    "long_sword": blade(9.6, 0.95, fuller=PAL["stone-5"], guard_len=2.4),
    "dwarvish_broad_sword": blade(10.0, 1.7, steel=mat("stone", 6, 5, 3, 1), guard=mat("ember", 5, 4, 3, 1),
                                  fuller=PAL["gold-4"], guard_len=3.0),
    "severance": blade(9.6, 1.0, steel=mat("crystal", 7, 6, 4, 2), guard=mat("night", 5, 4, 3, 1),
                       grip=mat("night", 4, 3, 2, 0), fuller=PAL["crystal-7"], guard_len=2.6),
    "leather_armor": armor(LEATHER, band=mat("bark", 4, 3, 2, 0)),
    "riveted_coat": armor(mat("umber", 5, 4, 2, 0), rivets=PAL["stone-6"], band=mat("bark", 3, 2, 1, 0)),
    "full_plate": armor(mat("stone", 6, 5, 3, 1), trim=mat("stone", 7, 6, 5, 2), pauldrons=mat("stone", 7, 6, 4, 2)),
    "elven_plate": armor(mat("sky", 6, 5, 3, 1), trim=GOLD, pauldrons=mat("sky", 7, 6, 4, 2), band=GOLD),
    "small_shield": buckler,
    "large_shield": kite(mat("ember", 5, 4, 3, 1), IRON, device=mat("stone", 7, 6, 5, 3)),
    "magic_shield": kite(mat("night", 5, 4, 3, 1), GOLD, glow=mat("crystal", 7, 6, 4, 2)),
    "elven_helm": helm,
    "copper_key": key(mat("ember", 6, 5, 3, 1), teeth=1),
    "silver_key": key(mat("stone", 7, 6, 4, 2)),
    "gold_key": key(mat("gold", 7, 5, 3, 1)),
    "thorn_key": key(mat("leaf", 5, 4, 2, 0), thorn=True),
    "life_fruit": life_fruit,
    "mana_dew": mana_dew,
    "ointment": balm,
    "elixir": flask(mat("gold", 6, 5, 4, 2), PAL["gold-7"]),
    "fire_scroll": scroll("ember"),
    "wisplight_scroll": scroll("sky"),
    "fracture_scroll": scroll("crystal"),
}


def painter(item_id, item):
    if item_id in BY_ID:
        return BY_ID[item_id]
    kind = item.get("kind", "")
    if kind == "dye":
        return dye(item.get("color", ""))
    if kind == "chart":
        return chart(item.get("zone", ""))
    if kind == "temper":
        return temper(int(item.get("level", 1)))
    raise SystemExit(f"icongen: no painter for item '{item_id}' (kind '{kind}'). Add one to BY_ID.")


# --- Portraits ----------------------------------------------------------------

def portrait(look):
    """Head and shoulders, facing left."""
    robe = mat_from(look.get("robe", "#6b6380"))
    trim = mat_from(look.get("trim", "#c9b98f"))
    skin = mat_from(look.get("skin", "#e8c9a0"), ["bark"])
    hair = mat_from(look.get("hair", "#3a2a1e"))
    hat = look.get("hat", "none")
    dwarf = look.get("build", "") == "dwarf"
    beard = look.get("beard", False) or dwarf
    ears = look.get("ears", False)

    cv = Canvas(PORTRAIT, PORTRAIT, (0, 0), SCALE)
    hx, hy = (19.5, 19.5) if dwarf else (19.5, 16.0)
    rx, ry = (10.0, 9.5) if dwarf else (8.6, 10.2)
    sh = 34.0 if dwarf else 31.5                      # shoulder line
    half = 17.5 if dwarf else 14.5

    # Hair that falls behind the neck, then shoulders and collar.
    if hat != "hood" and not dwarf:
        cv.part(cv.polygon([(hx + 1.0, hy - 6.0), (hx + rx + 1.6, hy - 2.0), (hx + rx + 1.0, hy + 11.0),
                            (hx + 2.0, hy + 12.0)]), (hair[1], hair[2], hair[3], hair[3]))
    shoulders = cv.ellipse((20.5, sh + 5.0), half, 7.5) | cv.polygon([(20.5 - half, sh + 5.0), (20.5 + half, sh + 5.0),
                                                                      (20.5 + half, 41.0), (20.5 - half, 41.0)])
    cv.part(shoulders, robe, deep=True)
    cv.part(cv.capsule((hx - 1.0, hy + ry - 3.0), (hx + 0.5, sh + 2.0), 3.6 if not dwarf else 4.6), (skin[1], skin[2], skin[3], skin[3]))
    collar = cv.polygon([(hx - 7.5, sh - 0.5), (hx - 0.5, sh + 5.5), (hx + 7.5, sh - 0.5), (hx + 9.0, sh + 1.5),
                         (hx - 0.5, sh + 9.0), (hx - 9.0, sh + 1.5)])
    cv.part(collar & shoulders, trim)
    cv.part(cv.capsule((hx - 0.5, sh + 8.0), (hx - 0.5, 41.0), 0.8) & shoulders, trim)

    # Head: skull, then the jaw pushed forward (left).
    head = cv.ellipse((hx, hy), rx, ry) | cv.ellipse((hx - 2.2, hy + 3.2), rx - 2.2, ry - 2.6)
    cv.part(head, skin, deep=True)
    # Nose and brow.
    nose_r = 2.3 if dwarf else 1.6
    cv.part(cv.ellipse((hx - rx - 0.2, hy + 2.2), nose_r, nose_r * 0.9), skin)
    # Eye, brow and mouth.
    eye = (hx - 4.4, hy + 0.2)
    cv.flat(cv.ellipse(eye, 1.7, 1.35), PAL["stone-7"])
    cv.flat(cv.ellipse((eye[0] - 0.5, eye[1] + 0.1), 0.95, 1.2), DARK)
    cv.pixel((eye[0] - 1.0, eye[1] - 0.9), PAL["stone-7"])
    cv.flat(cv.capsule((eye[0] - 2.2, eye[1] - 2.6), (eye[0] + 2.2, eye[1] - 2.9), 0.55), hair[2])
    if not beard:
        cv.flat(cv.capsule((hx - 6.6, hy + 6.0), (hx - 3.4, hy + 6.3), 0.35), skin[3])

    # Beard: a dwarf's is long and full; a tall man's is close.
    if beard:
        if dwarf:
            b = cv.polygon([(hx - rx + 1.0, hy + 5.6), (hx - 2.0, hy + 4.6), (hx + 5.0, hy + 2.0), (hx + 6.5, hy + 9.0),
                            (hx + 2.5, hy + 16.5), (hx - 3.0, hy + 19.0), (hx - 8.0, hy + 14.5), (hx - rx - 0.5, hy + 9.0)])
            cv.part(b, hair, deep=True)
            # A moustache under the nose, and one tie where the beard narrows.
            cv.part(cv.capsule((hx - rx + 1.0, hy + 5.8), (hx - 2.6, hy + 6.2), 1.2), (hair[0], hair[0], hair[1], hair[3]))
            cv.part(cv.capsule((hx - 4.6, hy + 15.6), (hx - 0.6, hy + 15.6), 0.7), trim)
        else:
            b = cv.polygon([(hx - rx + 0.5, hy + 4.2), (hx + 3.5, hy + 3.4), (hx + 3.0, hy + 8.6), (hx - 2.5, hy + 13.0),
                            (hx - 7.0, hy + 10.5)])
            cv.part(b, hair, deep=True)
            cv.part(cv.capsule((hx - rx + 1.0, hy + 4.8), (hx - 3.0, hy + 5.2), 0.9), (hair[0], hair[0], hair[1], hair[3]))

    # Hair over the skull (not under a hood).
    if hat != "hood":
        top = cv.ellipse((hx + 1.2, hy - 3.6), rx + 0.6, ry - 3.2) & ~cv.polygon(
            [(hx - rx - 2.0, hy - 3.2), (hx + 1.5, hy - 4.6), (hx + 2.5, hy + 12.0), (hx - rx - 2.0, hy + 12.0)])
        side = cv.polygon([(hx + 2.0, hy - 6.0), (hx + rx + 0.8, hy - 4.0), (hx + rx + 0.6, hy + 4.5), (hx + 5.6, hy + 3.4),
                           (hx + 5.2, hy - 1.6)])
        cv.part(top | side, hair, deep=True)

    # Ear, on the far (right) side of the face, over the hair.
    ex, ey = hx + 3.6, hy + 1.0
    if ears:
        cv.part(cv.polygon([(ex - 1.6, ey + 2.4), (ex - 1.0, ey - 2.0), (ex + 8.5, ey - 7.5), (ex + 2.4, ey + 1.6)]), skin)
        cv.flat(cv.capsule((ex + 0.2, ey + 0.2), (ex + 4.0, ey - 3.2), 0.4), skin[2])
    else:
        cv.part(cv.ellipse((ex, ey), 1.9, 2.6), skin)
        cv.flat(cv.ellipse((ex + 0.2, ey + 0.2), 0.7, 1.3), skin[2])

    if hat == "crown":
        band = cv.polygon([(hx - rx + 0.5, hy - 8.8), (hx + rx - 0.5, hy - 8.8), (hx + rx - 0.2, hy - 4.6), (hx - rx + 0.2, hy - 4.6)])
        pts = [(hx - rx + 0.5, hy - 8.8)]
        for i in range(4):
            x0 = hx - rx + 0.5 + i * (2 * rx - 1.0) / 4
            pts += [(x0 + 1.0, hy - 13.2), (x0 + (2 * rx - 1.0) / 4, hy - 8.8)]
        cv.part(band | cv.polygon(pts), mat("gold", 7, 5, 3, 1), deep=True)
        cv.flat(cv.ellipse((hx - 3.0, hy - 6.6), 1.0, 1.0), PAL["ember-4"])
        cv.flat(cv.ellipse((hx + 3.0, hy - 6.6), 1.0, 1.0), PAL["sky-4"])
    elif hat == "hood":
        outer = cv.ellipse((hx + 1.8, hy - 0.5), rx + 3.6, ry + 3.6) | cv.polygon(
            [(hx - 4.0, hy + ry + 1.0), (hx + rx + 5.4, hy + 2.0), (hx + rx + 4.0, sh + 3.0), (hx - 6.0, sh + 2.0)])
        face = cv.ellipse((hx - 2.6, hy + 1.6), rx - 1.4, ry - 1.2) | cv.polygon(
            [(hx - rx - 4.0, hy - 2.0), (hx - 2.0, hy - 2.0), (hx - 2.0, hy + ry + 4.0), (hx - rx - 4.0, hy + ry + 4.0)])
        cv.part(outer & ~face, robe, deep=True)
        # A lock of hair under the hood's lip.
        cv.part(cv.capsule((hx - 5.6, hy - 6.6), (hx - 0.6, hy - 7.6), 1.1) & ~(outer & ~face), hair)
        cv.flat(cv.capsule((hx - 6.4, hy - 9.6), (hx + 4.0, hy - 12.2), 0.35) & (outer & ~face), trim[1])
    elif hat == "cap":
        dome = cv.ellipse((hx + 0.8, hy - 6.2), rx + 0.8, 5.6) & ~cv.below(hy - 4.4)
        cv.part(dome, trim, deep=True)
        cv.part(cv.capsule((hx - rx - 3.6, hy - 4.6), (hx + rx + 0.6, hy - 5.2), 1.15), trim)
        cv.flat(cv.capsule((hx - rx + 1.0, hy - 6.4), (hx + rx - 0.6, hy - 6.8), 0.35) & dome, trim[2])
    elif hat == "helm":
        metal = mat("stone", 6, 5, 3, 1)
        dome = cv.ellipse((hx + 0.6, hy - 3.8), rx + 1.3, ry - 1.0) & ~cv.below(hy - 2.6)
        cv.part(dome, metal, deep=True)
        cv.part(cv.capsule((hx - rx - 1.0, hy - 2.8), (hx + rx + 1.6, hy - 3.2), 1.05), mat("stone", 7, 6, 4, 2))
        cv.part(cv.polygon([(hx - rx - 0.6, hy - 2.4), (hx - rx + 1.6, hy - 2.4), (hx - rx + 1.2, hy + 2.6), (hx - rx - 0.2, hy + 2.6)]), metal)
        cv.part(cv.capsule((hx + 0.4, hy - 12.0), (hx + 0.8, hy - 4.6), 0.6) & dome, mat("stone", 7, 6, 5, 2))
        for x in (-5.0, 5.6):
            cv.flat(cv.ellipse((hx + x, hy - 3.0), 0.45, 0.45), PAL["gold-5"])
    return cv.finish()[0]


# --- Sheets -------------------------------------------------------------------

def pack(images, cell, columns):
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell * columns, cell * max(rows, 1)), (0, 0, 0, 0))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % columns) * cell, (i // columns) * cell))
    return sheet


def contact(sheets, out, k=4):
    w = max(s.width for s in sheets) * k
    h = sum(s.height for s in sheets) * k + 8 * (len(sheets) - 1)
    im = Image.new("RGBA", (w, h), (28, 26, 40, 255))
    y = 0
    for s in sheets:
        big = s.resize((s.width * k, s.height * k), Image.NEAREST)
        im.alpha_composite(big, (0, y))
        y += big.height + 8
    im.save(out)


def main():
    items = json.loads((ROOT / "data" / "items.json").read_text(encoding="utf-8"))
    people = json.loads((ROOT / "data" / "npcs.json").read_text(encoding="utf-8"))
    UI.mkdir(parents=True, exist_ok=True)

    icons = [painter(i, v)() for i, v in items.items()]
    icon_sheet = pack(icons, ICON * SCALE, ICON_COLUMNS)
    icon_sheet.save(UI / "item_icons.png")
    (UI / "item_icons.json").write_text(json.dumps(
        {"cell": ICON * SCALE, "columns": ICON_COLUMNS, "items": {k: n for n, k in enumerate(items)}}, indent=1) + "\n",
        encoding="utf-8")

    who = [k for k, v in people.items() if v.get("look")]
    busts = [portrait(people[k]["look"]) for k in who]
    bust_sheet = pack(busts, PORTRAIT * SCALE, PORTRAIT_COLUMNS)
    bust_sheet.save(UI / "portraits.png")
    (UI / "portraits.json").write_text(json.dumps(
        {"cell": PORTRAIT * SCALE, "columns": PORTRAIT_COLUMNS, "people": {k: n for n, k in enumerate(who)}}, indent=1) + "\n",
        encoding="utf-8")
    print(f"{len(icons)} item icons, {len(busts)} portraits")
    if "--sheet" in sys.argv:
        contact([icon_sheet, bust_sheet], sys.argv[sys.argv.index("--sheet") + 1])


if __name__ == "__main__":
    main()
