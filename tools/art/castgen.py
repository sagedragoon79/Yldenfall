#!/usr/bin/env python3
"""Generates the enemy and NPC sprite sheets in the player's style (design
bible 12.3 and 13.3), with tools/art/pixelrig.py.

Enemies: blinkhop, hornet, rot_dwarf, sap_spitter, grub_lump, iron_dwarf, gear_bat, minecart_rider, bog_puffcap, drowned_dwarf, bark_knight, seed_bomber, marsh_hag, foreman and durgan (drawn at 2x); gloamweaver (Autosprite poses only); shade_knight, thunder_beetle, storm_harpy, spire_sentinel, leaf_mantis, mothling, clockwork_hound, crystal_dwarf, meteor_slug, spring_eel and lantern_ghost (PixelLab clips only; bark_knight and seed_bomber take PixelLab clips over their rigs); the parts of the boss Gnarlmaw. Each frame's metadata gives the points
the game draws on top (the Blinkhop's eye, which tracks the player).
NPCs: one sheet per person in data/npcs.json, "npc_<id>", built from their
"look" (robe, trim, skin, hair, hat, plus optional beard, ears and build), with every
color snapped to the master palette.

Usage: python3 tools/art/castgen.py
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelrig import PAL, ROOT, Canvas, ik, mat, mat_from, reach, write_sheet  # noqa: E402

EYE_WHITE = PAL["stone-7"]
DARK = PAL["night-1"]


# --- Blinkhop: a one-eyed hopper ----------------------------------------------

MONO_BODY = mat("night", 4, 3, 2, 0)
MONO_BELLY = mat("crystal", 6, 5, 4, 2)
MONO_HORN = mat("gold", 6, 5, 4, 2)
MONO_FEET = mat("night", 2, 1, 1, 0)


def blinkhop(rx, ry, lift=0.0, horn_tilt=0.0):
    def render(_):
        cv = Canvas(40, 32, (20, 30))
        cy = -ry - lift
        for side in (-1, 1):
            cv.part(cv.ellipse((side * (rx - 3.5), -1.2 - lift * 0.6), 2.6, 1.6), MONO_FEET)
        cv.part(cv.capsule((1, cy - ry + 1), (2 + horn_tilt, cy - ry - 3), 1.2), MONO_HORN)
        cv.part(cv.ellipse((0, cy), rx, ry), MONO_BODY, deep=True)
        belly = cv.ellipse((0.5, cy + ry * 0.45), rx * 0.62, ry * 0.42) & cv.ellipse((0, cy), rx - 1.5, ry - 1.5)
        cv.part(belly, MONO_BELLY)
        eye = (1.0, cy - ry * 0.25)
        cv.flat(cv.ellipse(eye, 3.6, 3.0), EYE_WHITE)
        cv.pixel((eye[0] - 2.0, eye[1] - 2.0), PAL["stone-6"])
        img, mask = cv.finish()
        return img, mask, {"eye": [round(eye[0], 1), round(eye[1], 1)]}
    return render


BLINKHOP = [
    ("idle", [blinkhop(9.0, 7.5), blinkhop(9.3, 7.2)], [0, 1], 3, True),
    ("windup", [blinkhop(10.5, 6.0, horn_tilt=-1), blinkhop(11.0, 5.6, horn_tilt=-1)], [0, 1], 8, True),
    ("hop", [blinkhop(8.0, 9.0, lift=2.0, horn_tilt=1)], [0], 1, False),
]


# --- Hornet -------------------------------------------------------------------

H_ABDOMEN = mat("gold", 5, 4, 3, 1)
H_THORAX = mat("bark", 3, 2, 1, 0)
H_HEAD = mat("gold", 4, 3, 2, 0)
H_WING = mat("sky", 7, 6, 5, 3)
H_STING = mat("stone", 7, 6, 4, 2)


def hornet(wing, curl=0.0, tilt=0.0):
    """wing: 'up', 'down' or 'back'. curl tucks the abdomen and sting forward."""
    def render(_):
        cv = Canvas(40, 32, (20, 16))
        rot = math.radians(tilt)

        def r(p):
            return (p[0] * math.cos(rot) - p[1] * math.sin(rot), p[0] * math.sin(rot) + p[1] * math.cos(rot))
        wings = {"up": ((-1, -7), 5.0, 2.4), "down": ((-2, -3.5), 5.5, 1.6), "back": ((-5, -5), 5.5, 1.8)}
        wc, wrx, wry = wings[wing]
        cv.part(cv.ellipse(r((wc[0] + 2, wc[1] + 0.5)), wrx * 0.8, wry), mat("sky", 6, 5, 4, 2))
        abd = r((-4 + curl * 0.5, curl * 1.5))
        sting_a = r((-9 + curl * 2.5, 1 + curl * 4))
        sting_b = r((-12 + curl * 5, 2 + curl * 7))
        cv.part(cv.capsule(sting_a, sting_b, 0.8), H_STING)
        cv.part(cv.ellipse(abd, 6.0, 4.4), H_ABDOMEN, deep=True)
        stripes = (cv.right_of(abd[0] - 2.5) & ~cv.right_of(abd[0] - 1.0)) | (cv.right_of(abd[0] + 0.5) & ~cv.right_of(abd[0] + 2.0))
        cv.flat(stripes & cv.ellipse(abd, 5.6, 4.0), DARK)
        for lx in (1.5, 3.5):
            cv.part(cv.capsule(r((lx, 2)), r((lx - 1, 5)), 0.6), mat("night", 2, 1, 1, 0))
        cv.part(cv.ellipse(r((3, -1)), 3.6, 3.4), H_THORAX)
        cv.part(cv.ellipse(r((7.5, -1)), 2.8, 2.6), H_HEAD)
        e = r((8.5, -1.5))
        cv.pixel(e, PAL["ember-3"])
        cv.pixel((e[0] + 1, e[1]), PAL["ember-4"])
        cv.part(cv.ellipse(r(wc), wrx, wry), H_WING)
        img, mask = cv.finish()
        return img, mask, {}
    return render


HORNET = [
    ("fly", [hornet("up"), hornet("down")], [0, 1], 24, True),
    ("windup", [hornet("up", curl=1.0, tilt=-8), hornet("down", curl=1.0, tilt=-8)], [0, 1], 30, True),
    ("swoop", [hornet("back", curl=0.4, tilt=12), hornet("back", curl=0.4, tilt=14)], [0, 1], 16, True),
]


# --- Rot Dwarf -----------------------------------------------------------------

D_SKIN = mat("leaf", 4, 3, 2, 0)
D_SKIN_BACK = mat("leaf", 3, 2, 1, 0)
D_ARMOR = mat("stone", 4, 3, 2, 0)
D_ARMOR_BACK = mat("stone", 3, 2, 1, 0)
D_BEARD = mat("stone", 7, 6, 5, 3)
D_HELM = mat("stone", 5, 4, 3, 1)
D_BOOT = mat("bark", 2, 1, 0, 0)
D_SHIELD = mat("bark", 4, 3, 2, 1)
D_RIM = mat("stone", 7, 6, 5, 3)
D_HAFT = mat("bark", 3, 2, 1, 0)
D_AXE = mat("stone", 7, 6, 5, 3)


def dwarf(hip=(0, -9), lean=0, feet=((4, 0), (-4, 0)), axe_hand=(-6, -14), axe_angle=-100,
          shield=True, shield_hand=(7, -15), bob=0):
    """axe_angle: degrees of the axe haft from the back hand (0 = forward, -90 = up)."""
    def render(_):
        cv = Canvas(48, 48, (24, 45))
        hx, hy = hip
        sx, sy = hx + lean, hy - 12 + bob
        head = (sx + 1, sy - 6)

        def leg(h, foot, m, boot):
            foot = reach(h, foot, 9.3)
            knee = ik(h, foot, 4.8, 4.8, 1)
            cv.part(cv.capsule(h, knee, 2.6) | cv.capsule(knee, foot, 2.4), m)
            cv.part(cv.capsule((foot[0] - 1.5, foot[1] - 2), (foot[0] + 2.5, foot[1] - 1.5), 2.2), boot)

        # The axe, in the back hand.
        a = math.radians(axe_angle)
        hand_b = reach((sx - 3, sy + 2), axe_hand, 11)
        haft_end = (hand_b[0] + math.cos(a) * 14, hand_b[1] + math.sin(a) * 14)
        butt = (hand_b[0] - math.cos(a) * 3, hand_b[1] - math.sin(a) * 3)
        cv.part(cv.capsule(butt, haft_end, 1.1), D_HAFT)
        perp = (-math.sin(a), math.cos(a))
        blade = [(haft_end[0] - math.cos(a) * 5 + perp[0] * 1, haft_end[1] - math.sin(a) * 5 + perp[1] * 1),
                 (haft_end[0] + perp[0] * 1, haft_end[1] + perp[1] * 1),
                 (haft_end[0] + perp[0] * 6 + math.cos(a) * 2, haft_end[1] + perp[1] * 6 + math.sin(a) * 2),
                 (haft_end[0] - math.cos(a) * 7 + perp[0] * 6, haft_end[1] - math.sin(a) * 7 + perp[1] * 6)]
        cv.part(cv.polygon(blade), D_AXE)
        elbow = ik((sx - 3, sy + 2), hand_b, 5.5, 5.5, -1)
        cv.part(cv.capsule((sx - 3, sy + 2), elbow, 2.2) | cv.capsule(elbow, hand_b, 2.0), D_ARMOR_BACK)
        cv.part(cv.ellipse(hand_b, 2.0, 2.0), D_SKIN_BACK)
        leg((hx - 2, hy), feet[1], D_ARMOR_BACK, D_BOOT)
        leg((hx + 2, hy), feet[0], D_ARMOR, D_BOOT)
        torso = cv.polygon([(sx - 6.5, sy), (sx + 6.5, sy), (hx + 7, hy + 1), (hx - 7, hy + 1)]) | cv.ellipse((sx, sy + 2), 7, 3.2)
        cv.part(torso, D_ARMOR, deep=True)
        cv.part(cv.capsule((hx - 6.5, hy - 1), (hx + 6.5, hy - 1), 1.0), mat("bark", 3, 2, 1, 0))
        # Head under a helm, the beard over the chest.
        cv.part(cv.ellipse(head, 5.0, 4.6), D_SKIN)
        cv.part(cv.ellipse((head[0] - 0.5, head[1] - 2.5), 5.8, 3.4) & ~cv.below(head[1] - 1.0), D_HELM)
        cv.part(cv.capsule((head[0] - 5, head[1] - 2), (head[0] + 5, head[1] - 2), 1.0), D_HELM)
        cv.part(cv.capsule((head[0] - 5.5, head[1] - 3), (head[0] - 8, head[1] - 6), 0.9), mat("stone", 7, 6, 5, 3))
        beard = cv.polygon([(head[0] - 3, head[1] + 1), (head[0] + 5, head[1] + 1), (head[0] + 3, sy + 8), (head[0] - 1, sy + 9)])
        cv.part(beard, D_BEARD)
        cv.pixel((head[0] + 2.5, head[1] - 0.5), PAL["gold-5"])
        cv.pixel((head[0] + 3.5, head[1] - 0.5), PAL["gold-4"])
        # Shield arm in front.
        hand_f = reach((sx + 3, sy + 2), shield_hand, 11)
        elbow_f = ik((sx + 3, sy + 2), hand_f, 5.5, 5.5, -1)
        cv.part(cv.capsule((sx + 3, sy + 2), elbow_f, 2.2) | cv.capsule(elbow_f, hand_f, 2.0), D_ARMOR)
        if shield:
            sh = (hand_f[0] + 2, hand_f[1])
            cv.part(cv.ellipse(sh, 4.0, 9.0), D_RIM)
            cv.part(cv.ellipse(sh, 3.0, 8.0), D_SHIELD, deep=True)
            cv.part(cv.ellipse((sh[0] + 0.5, sh[1]), 1.4, 1.6), D_RIM)
        else:
            cv.part(cv.ellipse(hand_f, 2.0, 2.0), D_SKIN)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def dwarf_walk(i):
    t = i / 4 * math.tau
    fx = 3.5 * math.cos(t)
    return dwarf(hip=(0, -9 - (1 if i % 2 else 0)), feet=((fx, -max(0, 2 * math.sin(t))), (-fx, -max(0, -2 * math.sin(t)))),
                 axe_hand=(-6, -14), axe_angle=-100 + 6 * math.cos(t), bob=0)


ROT_DWARF = [
    ("walk", [dwarf_walk(i) for i in range(4)], [0, 1, 2, 3], 6, True),
    ("windup", [dwarf(lean=-2, axe_hand=(-3, -27), axe_angle=-150, shield=False, shield_hand=(5, -14)),
                dwarf(lean=-3, axe_hand=(-4, -28), axe_angle=-160, shield=False, shield_hand=(5, -13))], [0, 1], 8, True),
    ("swing", [dwarf(lean=3, feet=((6, 0), (-5, 0)), axe_hand=(9, -18), axe_angle=-10, shield=False, shield_hand=(2, -12)),
               dwarf(lean=3, feet=((6, 0), (-5, 0)), axe_hand=(10, -12), axe_angle=30, shield=False, shield_hand=(1, -12))],
     [0, 1], 14, False),
    ("recover", [dwarf(lean=1, axe_hand=(5, -8), axe_angle=70)], [0], 1, False),
    ("stagger", [dwarf(lean=-4, feet=((2, 0), (-6, 0)), axe_hand=(-8, -20), axe_angle=-170, shield=False,
                       shield_hand=(6, -24))], [0], 1, False),
]


# --- Iron Dwarf: a Kettleforge dwarf in iron plate with a two-handed hammer --------
# Drawn at the 2x render density (Canvas scale 2): world-pixel geometry, half-pixel detail.

I_PLATE = mat("stone", 5, 3, 2, 0)
I_PLATE_BACK = mat("stone", 3, 2, 1, 0)
I_HELM = mat("stone", 6, 5, 3, 1)
I_GOLD = mat("gold", 6, 5, 3, 1)
I_BEARD = mat("bark", 4, 3, 2, 0)
I_SKIN = mat_from("#f0c09a", ["ember", "bark", "gold"])
I_BOOT = mat("bark", 3, 2, 1, 0)
I_HAFT = mat("bark", 5, 4, 3, 1)
I_HEAD = mat("stone", 6, 4, 2, 0)
ID_SCALE = 2


def iron_dwarf(hip=(0, -11), lean=0, feet=((5, 0), (-5, 0)), hands=(6, -20), hammer=-140, bob=0, crouch=0):
    """hammer: degrees of the haft from the hands toward the head (0 = forward, -90 = up)."""
    def render(_):
        cv = Canvas(72, 64, (32, 61), ID_SCALE)
        hx, hy = hip[0], hip[1] + crouch
        sx, sy = hx + lean, hy - 13 + bob
        head = (sx + 1.5, sy - 6)

        def leg(h, foot, m, boot):
            foot = reach(h, foot, 10.5)
            knee = ik(h, foot, 5.5, 5.5, 1)
            cv.part(cv.capsule(h, knee, 3.2) | cv.capsule(knee, foot, 2.8), m)
            cv.part(cv.capsule((foot[0] - 2, foot[1] - 2), (foot[0] + 3, foot[1] - 1.6), 2.5), boot)
            cv.part(cv.ellipse((knee[0] + 0.5, knee[1]), 2.2, 2.0), I_GOLD)

        # The hammer, gripped in both hands.
        a = math.radians(hammer)
        grip = reach((sx, sy + 2), hands, 12)
        tip = (grip[0] + math.cos(a) * 17, grip[1] + math.sin(a) * 17)
        butt = (grip[0] - math.cos(a) * 5, grip[1] - math.sin(a) * 5)
        perp = (-math.sin(a), math.cos(a))
        leg((hx - 3, hy), feet[1], I_PLATE_BACK, I_BOOT)
        # Back arm, then the haft and head over it.
        elbow_b = ik((sx - 4, sy + 2), grip, 6.5, 6.5, -1)
        cv.part(cv.capsule((sx - 4, sy + 2), elbow_b, 2.7) | cv.capsule(elbow_b, grip, 2.4), I_PLATE_BACK)
        cv.part(cv.capsule(butt, tip, 1.2), I_HAFT)
        hw, hl = 4.2, 6.5  # half width across the haft, half length along it
        corners = [(tip[0] + perp[0] * s1 * hl + math.cos(a) * s2 * hw, tip[1] + perp[1] * s1 * hl + math.sin(a) * s2 * hw)
                   for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        cv.part(cv.polygon(corners), I_HEAD, deep=True)
        band = [(tip[0] + perp[0] * s1 * (hl - 2.2) + math.cos(a) * s2 * (hw + 0.4),
                 tip[1] + perp[1] * s1 * (hl - 2.2) + math.sin(a) * s2 * (hw + 0.4)) for s1, s2 in ((-1, -1), (-0.55, -1), (-0.55, 1), (-1, 1))]
        cv.part(cv.polygon(band), I_GOLD)
        band2 = [(tip[0] + perp[0] * s1 * (hl - 2.2) + math.cos(a) * s2 * (hw + 0.4),
                  tip[1] + perp[1] * s1 * (hl - 2.2) + math.sin(a) * s2 * (hw + 0.4)) for s1, s2 in ((0.55, -1), (1, -1), (1, 1), (0.55, 1))]
        cv.part(cv.polygon(band2), I_GOLD)
        leg((hx + 3, hy), feet[0], I_PLATE, I_BOOT)
        # A broad torso in plate, with a gold-trimmed belt.
        torso = cv.polygon([(sx - 8, sy), (sx + 8, sy), (hx + 8.5, hy + 1), (hx - 8.5, hy + 1)]) | cv.ellipse((sx, sy + 2), 8.5, 4)
        cv.part(torso, I_PLATE, deep=True)
        cv.part(cv.capsule((hx - 8, hy - 1.5), (hx + 8, hy - 1.5), 1.4), mat("bark", 4, 3, 2, 0))
        cv.part(cv.ellipse((hx + 1, hy - 1.5), 2.0, 1.8), I_GOLD)
        cv.part(cv.ellipse((sx - 5, sy + 1), 4.0, 3.2), I_PLATE)  # pauldron
        # Front arm, both hands on the haft.
        elbow_f = ik((sx + 4, sy + 2), grip, 6.5, 6.5, -1)
        cv.part(cv.capsule((sx + 4, sy + 2), elbow_f, 2.7) | cv.capsule(elbow_f, grip, 2.4), I_PLATE)
        cv.part(cv.ellipse(grip, 2.3, 2.3), I_SKIN)
        # Head, over the arms: a face under a full helm with a nose guard and a ridge.
        cv.part(cv.ellipse(head, 5.2, 4.8), I_SKIN)
        helm = cv.ellipse((head[0] - 0.3, head[1] - 2.2), 6.3, 4.2) & ~cv.below(head[1] - 0.6)
        cv.part(helm, I_HELM)
        cv.part(cv.capsule((head[0] - 6, head[1] - 1.5), (head[0] + 6, head[1] - 1.5), 1.2), I_HELM)
        cv.part(cv.capsule((head[0] + 3.2, head[1] - 1.5), (head[0] + 3.2, head[1] + 1.5), 0.8), I_HELM)
        cv.part(cv.capsule((head[0] - 4.5, head[1] - 5.8), (head[0] + 2, head[1] - 6.6), 1.0), I_GOLD)
        beard = cv.polygon([(head[0] - 1.5, head[1] + 2.2), (head[0] + 5.2, head[1] + 2.2), (head[0] + 4.2, sy + 5.5),
                            (head[0] + 1.6, sy + 7.5), (head[0] - 0.8, sy + 5)])
        cv.part(beard, I_BEARD)
        cv.part(cv.capsule((head[0] + 1.6, sy + 4), (head[0] + 1.8, sy + 8), 0.6), mat("bark", 3, 3, 2, 1))
        cv.part(cv.ellipse((head[0] + 1.8, sy + 8.4), 0.9, 0.7), I_GOLD)
        cv.part(cv.ellipse((head[0] + 4.6, head[1] + 0.8), 1.4, 1.2), I_SKIN)  # nose
        # The eye glints under the brim: something in the iron has hold of him.
        cv.pixel((head[0] + 2, head[1] - 0.4), PAL["ember-6"])
        img, mask = cv.finish()
        return img, mask, {}
    return render


def iron_walk(i):
    t = i / 4 * math.tau
    fx = 4.5 * math.cos(t)
    return iron_dwarf(hip=(0, -11 - (1 if i % 2 else 0)),
                      feet=((fx, -max(0, 2.5 * math.sin(t))), (-fx, -max(0, -2.5 * math.sin(t)))),
                      hands=(6, -13), hammer=-150 + 5 * math.cos(t))


IRON_DWARF = [
    ("walk", [iron_walk(i) for i in range(4)], [0, 1, 2, 3], 5, True),
    ("windup", [iron_dwarf(lean=-3, hands=(-1, -33), hammer=-125, feet=((6, 0), (-6, 0))),
                iron_dwarf(lean=-4, hands=(-2, -34), hammer=-118, feet=((6, 0), (-6, 0)), bob=-1)], [0, 1], 8, True),
    ("slam", [iron_dwarf(lean=3, hands=(10, -26), hammer=-25, feet=((7, 0), (-6, 0))),
              iron_dwarf(lean=5, hands=(13, -12), hammer=60, feet=((8, 0), (-6, 0)), crouch=2)], [0, 1], 16, False),
    ("stuck", [iron_dwarf(lean=6, hands=(13, -10), hammer=72, feet=((8, 0), (-6, 0)), crouch=3),
               iron_dwarf(lean=5, hands=(13, -11), hammer=70, feet=((8, 0), (-6, 0)), crouch=3, bob=1)], [0, 1], 4, True),
    ("recover", [iron_dwarf(lean=2, hands=(9, -16), hammer=10)], [0], 1, False),
    ("stagger", [iron_dwarf(lean=-5, feet=((3, 0), (-7, 0)), hands=(-4, -28), hammer=-170)], [0], 1, False),
]


# --- Minecart Rider: a Kettleforge dwarf hunched in an ore cart, riding the rails --------
# Drawn at 2x like the Iron Dwarf. The cart tips forward when it crashes into a wall.

MC_TUB = mat("ember", 4, 3, 2, 0)
MC_TUB_DARK = mat("ember", 2, 1, 1, 0)
MC_BAND = mat("stone", 6, 5, 3, 1)
MC_WHEEL = mat("night", 4, 3, 2, 0)
MC_HUB = mat("gold", 6, 5, 3, 1)
MC_ORE = mat("crystal", 6, 5, 3, 1)
MC_SCALE = 2


def minecart(wheel=0.0, tilt=0.0, rider=(0, 0), lean=0.0, pick=-70, dazed=False, sparks=False):
    """wheel: spin in turns. tilt: degrees, + tips the cart forward over its front wheel.
    rider: offset of the rider's shoulders from their seat. pick: degrees of the pick haft."""
    def render(_):
        cv = Canvas(72, 56, (36, 53), MC_SCALE)
        pivot = (13, 0)

        def R(p):
            return _rot(p, pivot, tilt)

        def wheel_at(c):
            c = R(c)
            cv.part(cv.ellipse(c, 5.2, 5.2), MC_WHEEL, deep=True)
            for k in range(3):
                a = (wheel + k / 3) * math.tau
                d = (math.cos(a) * 3.6, math.sin(a) * 3.6)
                cv.part(cv.capsule((c[0] - d[0], c[1] - d[1]), (c[0] + d[0], c[1] + d[1]), 0.6), MC_BAND)
            cv.part(cv.ellipse(c, 1.6, 1.6), MC_HUB)

        # The rider, sitting low in the tub.
        sx, sy = -2 + rider[0] + lean, -27 + rider[1]
        seat = R((sx, sy))
        head = R((sx + 2 + lean * 0.3, sy - 7))
        if dazed:
            head = R((sx + 4, sy - 5))
        # Back arm and the pick, behind the tub's lip.
        a = math.radians(pick)
        grip = R((sx + 7 + lean * 0.5, sy + 1))
        tip = (grip[0] + math.cos(a) * 14, grip[1] + math.sin(a) * 14)
        butt = (grip[0] - math.cos(a) * 4, grip[1] - math.sin(a) * 4)
        cv.part(cv.capsule(butt, tip, 1.0), I_HAFT)
        perp = (-math.sin(a), math.cos(a))
        cv.part(cv.capsule((tip[0] - perp[0] * 6, tip[1] - perp[1] * 6), (tip[0] + perp[0] * 5, tip[1] + perp[1] * 5), 1.4), I_HEAD, deep=True)
        cv.part(cv.ellipse(seat, 7.0, 6.0), I_PLATE_BACK, deep=True)
        cv.part(cv.ellipse((seat[0] - 3, seat[1] - 1), 3.5, 3.0), I_PLATE)
        cv.part(cv.capsule((seat[0] + 4, seat[1] - 1), grip, 2.3), I_PLATE)
        cv.part(cv.ellipse(grip, 2.1, 2.1), I_SKIN)
        # Head: a leather cap with goggles pushed up, a braided beard.
        cv.part(cv.ellipse(head, 4.8, 4.5), I_SKIN)
        cap = cv.ellipse((head[0] - 0.4, head[1] - 2.0), 5.6, 3.8) & ~cv.below(head[1] - 0.8)
        cv.part(cap, mat("bark", 5, 4, 3, 1))
        cv.part(cv.capsule((head[0] - 4.5, head[1] - 2.2), (head[0] + 4.5, head[1] - 2.2), 1.1), MC_BAND)
        for gx in (-1.2, 2.6):
            cv.part(cv.ellipse((head[0] + gx, head[1] - 2.6), 1.5, 1.4), mat("sky", 6, 5, 3, 1))
        beard = cv.polygon([(head[0] - 1, head[1] + 1.8), (head[0] + 5, head[1] + 1.8), (head[0] + 4, head[1] + 7),
                            (head[0] + 1.5, head[1] + 8.5), (head[0] - 0.6, head[1] + 6)])
        cv.part(beard, mat("stone", 7, 6, 5, 3))
        cv.part(cv.ellipse((head[0] + 4.4, head[1] + 0.6), 1.3, 1.1), I_SKIN)
        if dazed:
            for k in range(3):
                a2 = k / 3 * math.tau + wheel * 2
                cv.pixel((head[0] + math.cos(a2) * 6, head[1] - 7 + math.sin(a2) * 1.5), PAL["gold-7"])
        else:
            cv.pixel((head[0] + 2.5, head[1] - 0.2), PAL["ember-6"])
        # The tub: a riveted iron box, wider at the lip, ore heaped at the back.
        cv.part(cv.ellipse(R((-8, -21)), 6, 3), MC_ORE)
        tub = cv.polygon([R((-17, -21)), R((17, -21)), R((14, -6)), R((-14, -6))])
        cv.part(tub, MC_TUB, deep=True)
        cv.part(cv.capsule(R((-17.5, -21)), R((17.5, -21)), 1.3), MC_BAND)
        cv.part(cv.capsule(R((-15.5, -13)), R((15.5, -13)), 0.8), MC_TUB_DARK)
        for rx in (-10, 0, 10):
            cv.pixel(R((rx, -17)), PAL["stone-6"])
            cv.pixel(R((rx * 0.9, -9)), PAL["stone-6"])
        cv.part(cv.capsule(R((-12, -5)), R((12, -5)), 1.0), MC_BAND)
        # Front lamp: lit while it rolls.
        cv.part(cv.ellipse(R((17, -16)), 1.8, 2.2), MC_HUB if not dazed else MC_BAND)
        wheel_at((-9, -5))
        wheel_at((9, -5))
        if sparks:
            for k in range(4):
                cv.pixel(R((-14 - k * 2.5, -1 - (k % 2) * 2)), PAL["gold-7"])
                cv.pixel(R((14 + k * 0.5, -1 - k)), PAL["ember-6"])
        img, mask = cv.finish()
        return img, mask, {}
    return render


MINECART_RIDER = [
    ("roll", [minecart(wheel=i / 4, rider=(0, i % 2 * 0.5)) for i in range(4)], [0, 1, 2, 3], 8, True),
    ("rev", [minecart(wheel=0.0, rider=(-2, 0), lean=-2, pick=-110, sparks=True),
             minecart(wheel=0.1, rider=(-2, -1), lean=-3, pick=-115, tilt=-3, sparks=True)], [0, 1], 10, True),
    ("charge", [minecart(wheel=i / 4 + 0.12, rider=(2, 2), lean=3, pick=-20, sparks=i % 2 == 0) for i in range(4)],
     [0, 1, 2, 3], 16, True),
    ("crash", [minecart(tilt=14, rider=(3, -2), lean=4, pick=30, dazed=True),
               minecart(tilt=12, rider=(3, -1), lean=4, pick=35, dazed=True, wheel=0.3)], [0, 1], 4, True),
    ("stagger", [minecart(tilt=-6, rider=(-3, 0), lean=-3, pick=-150)], [0], 1, False),
]


# --- Gear Bat: a clockwork bat of riveted iron that flings the gear on its back -----
# Drawn at the 2x render density, like the Iron Dwarf. The thrown gear is drawn in code
# (scripts/enemies/gear_blade.gd) in the same gold, at the same size.

GB_IRON = mat("stone", 5, 4, 2, 0)
GB_IRON_BACK = mat("stone", 3, 2, 1, 0)
GB_WEB = mat("bark", 3, 2, 1, 0)
GB_WEB_BACK = mat("bark", 2, 1, 0, 0)
GB_GEAR = mat("gold", 6, 5, 3, 1)
GB_HUB = mat("bark", 3, 2, 1, 0)
GB_SCALE = 2
GEAR_R = 4.5


def gear_shape(cv, c, r, angle, teeth=8):
    """A gear: a disc with square teeth, rotated by `angle` degrees."""
    m = cv.ellipse(c, r - 1.0, r - 1.0)
    for i in range(teeth):
        a = math.radians(angle + i * 360 / teeth)
        u, v = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
        pts = [(c[0] + u[0] * (r - 1.5) + v[0] * s * 1.1, c[1] + u[1] * (r - 1.5) + v[1] * s * 1.1) for s in (-1, 1)]
        pts += [(c[0] + u[0] * (r + 0.6) + v[0] * s * 0.9, c[1] + u[1] * (r + 0.6) + v[1] * s * 0.9) for s in (1, -1)]
        m |= cv.polygon(pts)
    return m


def gear_bat(wing=60, gear=True, gear_angle=0, tilt=0.0, glow=False, hang=False):
    """wing: degrees of the wing's leading strut above straight back (90 = straight up,
    -40 = swept down). hang folds the wings and turns the bat upside down on its roost."""
    def render(_):
        cv = Canvas(56, 40, (28, 20), GB_SCALE)
        rot = math.radians(180 if hang else tilt)

        def r(p):
            return (p[0] * math.cos(rot) - p[1] * math.sin(rot), p[0] * math.sin(rot) + p[1] * math.cos(rot))

        def wing_part(shoulder, a, spread, material, strut, size=1.0):
            a = math.radians(a)
            elbow = (shoulder[0] - math.cos(a) * 7 * size, shoulder[1] - math.sin(a) * 7 * size)
            tips = []
            for da, ln in ((0.35, 7.5), (0.95, 8.5), (1.55, 7.0)):
                ang = a - da * spread
                tips.append((elbow[0] - math.cos(ang) * ln * size, elbow[1] - math.sin(ang) * ln * size))
            rear = (shoulder[0] - 6, shoulder[1] + 3)
            # Scalloped trailing edge: pull each span between fingers in toward the body.
            def mid(p, q, k=0.22):
                m = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
                return (m[0] + (elbow[0] - m[0]) * k, m[1] + (elbow[1] - m[1]) * k)
            pts = [shoulder, elbow, tips[0], mid(tips[0], tips[1]), tips[1], mid(tips[1], tips[2]), tips[2], mid(tips[2], rear, 0.3), rear]
            cv.part(cv.polygon([r(p) for p in pts]), material)
            cv.part(cv.capsule(r(shoulder), r(elbow), 1.1), strut)
            for t in tips:
                cv.part(cv.capsule(r(elbow), r(t), 0.55), strut)
            cv.part(cv.ellipse(r(elbow), 1.3, 1.3), GB_GEAR)

        fold = 0.2 if hang else 1.0
        wa = 95 if hang else wing
        ws = 0.8 if hang else 1.0
        wing_part((-1, -1.5), wa - 18, fold, GB_WEB_BACK, GB_IRON_BACK, ws)
        if not gear:
            cv.part(cv.capsule(r((-2.5, -4)), r((-2.5, -7)), 0.9), GB_HUB)  # the bare axle
        # Feet: little iron hooks under the body (over it when hanging).
        for fx in (-3.0, -0.5):
            cv.part(cv.capsule(r((fx, 2.5)), r((fx - 0.6, 5.5)), 0.7), GB_IRON_BACK)
        cv.part(cv.ellipse(r((-1, 0)), 6.5, 4.2), GB_IRON, deep=True)
        cv.part(cv.capsule(r((-5.5, 0.5)), r((3, 0.5)), 0.5), mat("gold", 5, 4, 3, 1))  # brass seam
        for rx in (-4, -1, 2):
            cv.pixel(r((rx, -2.2)), PAL["stone-6"])
        # Head with tall pointed ears and a snub snout.
        hd = r((5.5, -1.5))
        for ex, tip in ((4.0, (3.0, -9.0)), (6.5, (7.0, -9.5))):
            cv.part(cv.polygon([r((ex - 1.6, -3.5)), r(tip), r((ex + 1.6, -3.5))]), GB_IRON)
        cv.part(cv.ellipse(hd, 3.6, 3.2), GB_IRON)
        cv.part(cv.ellipse(r((8.6, -0.6)), 1.6, 1.3), GB_IRON_BACK)
        eye = r((6.6, -2.3))
        cv.pixel(eye, PAL["ember-6"] if glow else PAL["ember-5"])
        cv.pixel(r((7.6, -2.3)), PAL["ember-4"])
        cv.pixel(r((8.0, 1.2)), PAL["stone-7"])  # a fang
        if gear:
            # The gear rides high on the back, between the wings.
            g = r((-2.5, -7))
            cv.part(gear_shape(cv, g, GEAR_R, gear_angle), mat("gold", 7, 6, 4, 2) if glow else GB_GEAR)
            cv.part(cv.ellipse(g, 1.4, 1.4), GB_HUB)
        wing_part((0.5, -1), wa, fold, GB_WEB, GB_IRON, ws)
        img, mask = cv.finish()
        return img, mask, {}
    return render


GEAR_BAT = [
    ("roost", [gear_bat(hang=True, gear_angle=0), gear_bat(hang=True, gear_angle=8)], [0, 1], 2, True),
    ("fly", [gear_bat(80, gear_angle=0), gear_bat(30, gear_angle=11), gear_bat(-30, gear_angle=22), gear_bat(30, gear_angle=33)],
     [0, 1, 2, 3], 14, True),
    ("windup", [gear_bat(-20, tilt=-10, gear_angle=0, glow=True), gear_bat(-30, tilt=-10, gear_angle=22, glow=True)], [0, 1], 24, True),
    ("bare", [gear_bat(80, gear=False), gear_bat(30, gear=False), gear_bat(-30, gear=False), gear_bat(30, gear=False)],
     [0, 1, 2, 3], 16, True),
    ("stagger", [gear_bat(110, gear=False, tilt=25)], [0], 1, False),
]


# --- The Foreman: a rock golem the dwarves set to work the tower -------------------
# A boulder body with ore veins, a dwarf foreman's brass lamp-helm jammed on its head
# and the Delver's Pick wedged in its back (the reward). 2x render density.

FM_ROCK = mat("bark", 4, 3, 2, 0)
FM_ROCK_BACK = mat("bark", 3, 2, 1, 0)
FM_ROCK_DARK = mat("bark", 3, 2, 1, 0)
FM_CRACK = PAL["bark-1"]
FM_VEIN = mat("gold", 6, 4, 3, 1)
FM_VEIN_DIM = mat("gold", 3, 2, 2, 1)
FM_HELM = mat("stone", 6, 5, 3, 1)
FM_LAMP = mat("gold", 7, 6, 4, 2)
FM_HAFT = mat("bark", 5, 4, 3, 1)
FM_PICK = mat("stone", 7, 6, 4, 2)
FM_SCALE = 2


def foreman(lean=0.0, crouch=0.0, fist_f=(22, -22), fist_b=(-20, -24), feet=((9, 0), (-9, 0)),
            head_dy=0.0, glow=True, boulder=None, slump=False):
    """Points are relative to the feet. fist_f/fist_b: front and back fist centres."""
    def render(_):
        cv = Canvas(96, 80, (48, 76), FM_SCALE)
        hip_y = -16 + crouch * 0.6
        cx, cy = lean, -34 + crouch
        sh_f, sh_b = (cx + 13, cy - 8), (cx - 13, cy - 10)
        head = (cx + 9 + (3 if slump else 0), cy - 17 + head_dy + (5 if slump else 0))
        vein = FM_VEIN if glow else FM_VEIN_DIM

        def arm(sh, fist, m, r):
            fist = reach(sh, fist, 26)
            elbow = ik(sh, fist, 13, 13, -1 if fist[0] > sh[0] else 1)
            cv.part(cv.capsule(sh, elbow, r) | cv.capsule(elbow, fist, r - 0.5), m)
            cv.part(cv.ellipse(elbow, r * 0.8, r * 0.8), m)
            cv.part(cv.ellipse(fist, 7.5, 6.8), m, deep=True)
            cv.part(cv.capsule((fist[0] - 3, fist[1] - 1), (fist[0] + 3, fist[1] - 1), 0.6), vein)

        # Back arm and leg, then the Delver's Pick wedged in the back.
        arm(sh_b, fist_b, FM_ROCK_BACK, 5.5)
        bf = reach((cx - 7, hip_y), feet[1], 17)
        cv.part(cv.capsule((cx - 7, hip_y), bf, 6.5), FM_ROCK_BACK)
        cv.part(cv.ellipse((bf[0] + 1, bf[1] - 2.5), 8, 4), FM_ROCK_BACK)
        tip = (cx - 22, cy - 34)
        cv.part(cv.capsule((cx - 8, cy - 4), tip, 1.4), FM_HAFT)
        cv.part(cv.polygon([(tip[0] - 9, tip[1] + 4), (tip[0] - 1, tip[1] - 2.5), (tip[0] + 8, tip[1] - 3),
                            (tip[0] + 1, tip[1] + 1.5)]), FM_PICK, deep=True)
        cv.part(cv.ellipse(tip, 1.8, 1.8), FM_HELM)
        # Front leg.
        ff = reach((cx + 7, hip_y), feet[0], 17)
        cv.part(cv.capsule((cx + 7, hip_y), ff, 7), FM_ROCK)
        cv.part(cv.ellipse((ff[0] + 2, ff[1] - 2.5), 8.5, 4), FM_ROCK_DARK)
        # The boulder body: a big rounded mass with a few slabs and glowing ore veins.
        body = cv.ellipse((cx, cy), 20, 17) | cv.polygon([(cx - 16, cy + 4), (cx + 17, cy + 2), (cx + 11, cy + 17), (cx - 12, cy + 17)])
        cv.part(body, FM_ROCK, deep=True)
        cv.part(cv.ellipse((cx - 9, cy - 9), 9, 7), FM_ROCK)
        cv.part(cv.ellipse((cx + 8, cy + 6), 8, 6), FM_ROCK_DARK)
        # Facet cracks between the slabs.
        for a, b in (((cx - 18, cy - 2), (cx - 10, cy + 1)), ((cx + 1, cy - 15), (cx - 2, cy - 8)), ((cx + 15, cy + 10), (cx + 9, cy + 14)),
                     ((cx - 4, cy + 10), (cx - 9, cy + 16))):
            cv.flat(cv.capsule(a, b, 0.45), FM_CRACK)
        for a, b in (((cx - 6, cy - 2), (cx + 4, cy + 3)), ((cx + 4, cy + 3), (cx + 2, cy + 11)), ((cx - 12, cy + 4), (cx - 6, cy - 2)),
                     ((cx + 9, cy - 9), (cx + 14, cy - 3))):
            cv.part(cv.capsule(a, b, 0.9), vein)
        # Head, sunk between the shoulders, under a dented brass lamp-helm.
        cv.part(cv.ellipse(head, 9, 8), FM_ROCK)
        helm = cv.ellipse((head[0] - 0.5, head[1] - 5), 9.5, 6.5) & ~cv.below(head[1] - 4.2)
        cv.part(helm, FM_HELM)
        cv.part(cv.capsule((head[0] - 10, head[1] - 4.2), (head[0] + 10.5, head[1] - 4.2), 1.1), FM_HELM)
        cv.part(cv.ellipse((head[0] + 3.5, head[1] - 8.5), 2.4, 2.2), FM_LAMP if glow else FM_HELM)
        # Two ore-lit eyes under the brim, and a slab of a jaw.
        for ex in (head[0] + 3.5, head[0] + 7.0):
            cv.flat(cv.ellipse((ex, head[1] - 0.8), 1.4, 1.0), PAL["gold-6"] if glow else PAL["bark-1"])
        cv.flat(cv.capsule((head[0] + 1, head[1] + 4.2), (head[0] + 8, head[1] + 3.6), 0.5), FM_CRACK)
        if boulder is not None:
            cv.part(cv.ellipse(boulder, 9, 8), FM_ROCK_DARK, deep=True)
            cv.part(cv.capsule((boulder[0] - 4, boulder[1] - 2), (boulder[0] + 3, boulder[1] + 2), 0.7), FM_VEIN_DIM)
        arm(sh_f, fist_f, FM_ROCK, 6)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def foreman_walk(i):
    t = i / 4 * math.tau
    fx = 7 * math.cos(t)
    return foreman(crouch=1 if i % 2 else 0, feet=((fx + 2, -max(0, 3 * math.sin(t))), (-fx - 2, -max(0, -3 * math.sin(t)))),
                   fist_f=(20 - fx * 0.6, -18), fist_b=(-18 + fx * 0.6, -20))


FOREMAN = [
    ("idle", [foreman(), foreman(crouch=1, head_dy=0.5)], [0, 1], 3, True),
    ("walk", [foreman_walk(i) for i in range(4)], [0, 1, 2, 3], 6, True),
    ("pound_tell", [foreman(lean=-3, crouch=-2, fist_f=(6, -66), fist_b=(-6, -68), head_dy=-1),
                    foreman(lean=-4, crouch=-3, fist_f=(5, -68), fist_b=(-7, -70), head_dy=-1)], [0, 1], 10, True),
    ("pound", [foreman(lean=6, crouch=8, fist_f=(30, -6), fist_b=(22, -6), feet=((11, 0), (-10, 0)))], [0], 1, False),
    ("charge_tell", [foreman(lean=-6, crouch=7, fist_f=(4, -12), fist_b=(-24, -14), feet=((12, 0), (-13, 0))),
                     foreman(lean=-7, crouch=8, fist_f=(3, -11), fist_b=(-25, -13), feet=((12, 0), (-14, 0)))], [0, 1], 12, True),
    ("charge", [foreman(lean=8, crouch=6, fist_f=(28, -30), fist_b=(4, -26), feet=((14, -2), (-10, 0))),
                foreman(lean=8, crouch=6, fist_f=(28, -30), fist_b=(4, -26), feet=((6, 0), (-14, -2)))], [0, 1], 10, True),
    ("stunned", [foreman(lean=-4, crouch=10, fist_f=(14, -3), fist_b=(-18, -3), glow=False, slump=True),
                 foreman(lean=-3, crouch=10, fist_f=(14, -3), fist_b=(-18, -3), glow=False, slump=True, head_dy=1)], [0, 1], 2, True),
    ("throw_tell", [foreman(lean=-4, crouch=-1, fist_f=(2, -64), fist_b=(-8, -64), boulder=(-2, -74))], [0], 1, False),
    ("throw", [foreman(lean=6, crouch=3, fist_f=(30, -40), fist_b=(18, -36))], [0], 1, False),
    ("recover", [foreman(crouch=3, fist_f=(18, -12), fist_b=(-18, -14))], [0], 1, False),
]


# --- Durgan: the Hammer of Kettleforge (design bible 8.2) ------------------------
# A dwarf champion fused with a walking siege drill: an iron hull on two piston
# legs, a bronze drill out front, two exhaust stacks behind (the pogo vents) and
# a glass cockpit with the dwarf inside. "open_" frames show the hatch thrown
# back and the Everbloom-crystal harness that binds him. 2x render density.

ZD_HULL = mat("ember", 4, 3, 2, 0)
ZD_HULL_BACK = mat("ember", 2, 1, 1, 0)
ZD_LEG = mat("night", 4, 3, 2, 0)
ZD_FOOT = mat("bark", 3, 2, 1, 0)
ZD_BRASS = mat("gold", 6, 5, 3, 1)
ZD_DRILL = mat("gold", 5, 4, 3, 1)
ZD_GROOVE = PAL["gold-2"]
ZD_STACK = mat("night", 4, 3, 2, 0)
ZD_GLASS = mat("sky", 6, 5, 3, 1)
ZD_SKIN = mat_from("#f0c09a", ["ember", "bark", "gold"])
ZD_BEARD = mat("stone", 7, 6, 5, 3)
ZD_HELM = mat("gold", 5, 4, 3, 1)
ZD_CRYSTAL = mat("crystal", 7, 6, 4, 2)
ZD_FURNACE = mat("gold", 7, 6, 5, 3)
ZD_FURNACE_COLD = mat("night", 3, 2, 1, 0)
ZD_SCALE = 2


def _rot(p, c, deg):
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def durgan(crouch=0.0, lean=0.0, spin=0.0, drill_angle=0.0, extend=0.0, feet=((10, 0), (-16, 0)),
              hot=True, open_=False, slump=False):
    """Points are relative to the feet. drill_angle: degrees, + points the drill down."""
    def render(_):
        cv = Canvas(128, 88, (60, 84), ZD_SCALE)
        cx, top = lean, -50 + crouch
        bot = -20 + crouch * 0.8
        # Back leg, back exhaust stack.
        bh = (cx - 14, bot)
        bf = reach(bh, feet[1], 22)
        cv.part(cv.capsule(bh, ((bh[0] + bf[0]) / 2 - 3, (bh[1] + bf[1]) / 2), 4.2) |
                cv.capsule(((bh[0] + bf[0]) / 2 - 3, (bh[1] + bf[1]) / 2), bf, 3.6), ZD_HULL_BACK)
        cv.part(cv.ellipse((bf[0], bf[1] - 2), 7, 3.2), ZD_FOOT)
        for sx, h in ((cx - 22, 15), (cx - 13, 11)):
            cv.part(cv.capsule((sx, top + 2), (sx - 2, top - h), 3.2), ZD_STACK, deep=True)
            cv.part(cv.ellipse((sx - 2, top - h), 4.2, 2.0), ZD_BRASS)
            cv.flat(cv.ellipse((sx - 2, top - h), 2.6, 0.9), PAL["night-0"])
        # The hull: a riveted iron boiler with chamfered corners.
        hull = cv.polygon([(cx - 27, top + 6), (cx - 20, top), (cx + 14, top), (cx + 21, top + 7),
                           (cx + 21, bot - 2), (cx + 16, bot + 3), (cx - 22, bot + 3), (cx - 27, bot - 3)])
        cv.part(hull, ZD_HULL, deep=True)
        cv.part(cv.capsule((cx - 26, top + 12), (cx + 20, top + 12), 1.0), ZD_BRASS)
        for rx in range(-22, 20, 6):
            cv.pixel((cx + rx, top + 4), PAL["gold-5"])
            cv.pixel((cx + rx, bot), PAL["gold-4"])
        # The furnace grate: it glows while the engine runs.
        fur = cv.ellipse((cx - 8, top + 21), 6.5, 4.5)
        cv.part(fur, ZD_FURNACE if hot else ZD_FURNACE_COLD)
        for gx in (-11, -8, -5):
            cv.flat(cv.capsule((cx + gx, top + 18), (cx + gx, top + 24), 0.45), PAL["night-1"])
        # Front leg.
        fh = (cx + 8, bot)
        ff = reach(fh, feet[0], 22)
        mid = ((fh[0] + ff[0]) / 2 + 3, (fh[1] + ff[1]) / 2)
        cv.part(cv.capsule(fh, mid, 4.6) | cv.capsule(mid, ff, 3.9), ZD_LEG)
        cv.part(cv.ellipse(mid, 3.2, 3.2), ZD_BRASS)
        cv.part(cv.ellipse((ff[0] + 1, ff[1] - 2), 7.5, 3.4), ZD_FOOT)
        # The drill: a bronze cone with spiral grooves that crawl as it spins.
        mount = (cx + 22, top + 17)
        length = 30 + extend
        cone = [(mount[0] + 1, mount[1] - 10), (mount[0] + length, mount[1]), (mount[0] + 1, mount[1] + 10)]
        cone = [_rot(p, mount, drill_angle) for p in cone]
        cmask = cv.polygon(cone)
        cv.part(cmask, ZD_DRILL, deep=True)
        for k in range(5):
            u = (k + spin) / 5.0
            a = (mount[0] + 2 + u * (length - 4), mount[1] - 10 * (1 - u) - 1)
            b = (mount[0] + 2 + u * (length - 4) + 6, mount[1] + 10 * (1 - u) + 1)
            cv.flat(cv.capsule(_rot(a, mount, drill_angle), _rot(b, mount, drill_angle), 0.55) & cmask, ZD_GROOVE)
        cv.part(cv.ellipse(mount, 5, 11), ZD_BRASS, deep=True)
        cv.part(cv.ellipse(mount, 2.2, 2.2), ZD_HULL)
        # The cockpit and the dwarf inside it.
        head = (cx + 1 + (2 if slump else 0), top - 6 + (3 if slump else 0))
        if not open_:
            cv.part(cv.ellipse((cx + 1, top - 3), 12, 9) & ~cv.below(top + 1), ZD_GLASS)
        cv.part(cv.ellipse(head, 4.4, 4.2), ZD_SKIN)
        cv.part(cv.ellipse((head[0], head[1] - 2.6), 4.8, 3.0) & ~cv.below(head[1] - 1.5), ZD_HELM)
        cv.part(cv.polygon([(head[0] - 1, head[1] + 1.5), (head[0] + 4.5, head[1] + 1.5), (head[0] + 1.5, head[1] + 7)]), ZD_BEARD)
        cv.flat(cv.ellipse((head[0] + 2.2, head[1] - 0.2), 0.8, 0.8 if not slump else 0.35), PAL["night-0"])
        if open_:
            # The hatch thrown back, and the crystal harness clamped over his chest.
            cv.part(cv.ellipse((cx - 13, top - 6), 5, 9) & ~cv.right_of(cx - 12), ZD_GLASS)
            cv.part(cv.capsule((head[0] - 4, head[1] + 4), (head[0] + 5, head[1] + 9), 1.0), ZD_BRASS)
            hc = (head[0] - 2, head[1] + 9)
            cv.part(cv.polygon([(hc[0], hc[1] - 6), (hc[0] + 5.5, hc[1]), (hc[0], hc[1] + 6), (hc[0] - 5.5, hc[1])]), ZD_CRYSTAL, deep=True)
            cv.pixel((hc[0] - 1, hc[1] - 2), PAL["crystal-7"])
            cv.pixel((hc[0], hc[1] - 3), PAL["crystal-7"])
        else:
            cv.flat(cv.capsule((cx - 6, top - 9), (cx - 2, top - 11), 0.5), PAL["sky-7"])
        cv.part(cv.capsule((cx - 12, top + 1), (cx + 13, top + 1), 1.2), ZD_BRASS)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def durgan_walk(i, **kw):
    t = i / 4 * math.tau
    fx = 6 * math.cos(t)
    return durgan(crouch=1 if i % 2 else 0, spin=i * 0.25,
                     feet=((fx + 10, -max(0, 3 * math.sin(t))), (-fx - 16, -max(0, -3 * math.sin(t)))), **kw)


def durgan_anims(open_):
    o = {"open_": open_}
    p = "open_" if open_ else ""
    return [
        (p + "idle", [durgan(**o), durgan(crouch=1, spin=0.5, **o)], [0, 1], 3, True),
        (p + "walk", [durgan_walk(i, **o) for i in range(4)], [0, 1, 2, 3], 7, True),
        (p + "drill_tell", [durgan(crouch=3, lean=-4, spin=s, feet=((12, 0), (-19, 0)), **o) for s in (0.0, 0.33, 0.66)],
         [0, 1, 2], 18, True),
        (p + "drill", [durgan(crouch=2, lean=4, spin=s, extend=4, feet=((14, -2), (-12, 0)), **o) for s in (0.0, 0.5)],
         [0, 1], 16, True),
        (p + "stuck", [durgan(crouch=6, lean=6, drill_angle=24, extend=2, hot=False, slump=True, **o),
                       durgan(crouch=7, lean=6, drill_angle=26, extend=2, hot=False, slump=True, **o)], [0, 1], 2, True),
        (p + "slam_tell", [durgan(crouch=-7, lean=-3, drill_angle=-30, feet=((9, -3), (-15, 0)), **o),
                           durgan(crouch=-8, lean=-4, drill_angle=-32, feet=((9, -4), (-15, 0)), **o)], [0, 1], 10, True),
        (p + "slam", [durgan(crouch=8, lean=4, drill_angle=18, feet=((13, 0), (-17, 0)), **o)], [0], 1, False),
    ]


DURGAN = durgan_anims(False) + durgan_anims(True) + [
    ("freed", [durgan(crouch=9, drill_angle=30, hot=False, open_=True, slump=True)], [0], 1, False),
]


# --- Gnarlmaw: the body parts the boss script chains together ----------------

R_BARK = mat("bark", 3, 2, 1, 0)
R_CROWN = mat("bark", 5, 4, 3, 1)
R_HEAD = mat("bark", 2, 1, 1, 0)
R_MANDIBLE = mat("bark", 6, 5, 4, 2)
R_TAIL = mat("gold", 5, 4, 3, 1)
R_TAIL_HOT = mat("gold", 6, 5, 4, 2)


def roku_plate(cracked):
    """A bark-plated body segment, travelling toward +x (radius 17)."""
    def render(_):
        cv = Canvas(64, 64, (32, 32))
        body = cv.ellipse((0, 0), 17.5, 17.5)
        cv.part(body, R_BARK, deep=True)
        cv.part(cv.ellipse((0.5, 11.5), 7.0, 3.6) & body, mat("bark", 7, 6, 5, 3))
        crown = cv.ellipse((-0.5, -4.5), 14.5, 11.0) & body
        cv.part(crown, R_CROWN)
        for x in (-6.5, 5.5):
            cv.flat(cv.capsule((x, -14), (x + 1, 4), 0.6) & crown, PAL["bark-1"])
        cv.flat(cv.capsule((-12, 2), (12, 2), 0.6) & crown, PAL["bark-2"])
        if cracked:
            pts = [(-11, -9), (-6, -4), (-8, 1), (-1, -2), (3, -9), (6, -3), (11, -6)]
            for a_, b_ in zip(pts, pts[1:]):
                cv.flat(cv.capsule(a_, b_, 0.9) & crown, PAL["gold-6"])
            cv.pixel((-1, -3), PAL["gold-7"])
        img, mask = cv.finish()
        return img, mask, {}
    return render


def roku_tail(hot):
    def render(_):
        cv = Canvas(64, 64, (32, 32))
        body = cv.ellipse((0, 0), 16.5, 16.5)
        cv.part(body, R_TAIL_HOT if hot else R_TAIL, deep=True)
        for x in (-8, 0, 8):
            cv.flat(cv.capsule((x, -15), (x, 15), 0.6) & body & ~cv.ellipse((-4, -5), 6, 5), PAL["gold-3" if not hot else "gold-4"])
        cv.part(cv.ellipse((-4, -5), 5.5, 4.5), mat("gold", 7, 7 if hot else 6, 5, 4))
        cv.pixel((-6, -7), PAL["gold-7"])
        img, mask = cv.finish()
        return img, mask, {}
    return render


def roku_head(step):
    """The mandible wheel turned by `step` tenths of a sixth of a turn."""
    def render(_):
        cv = Canvas(64, 64, (32, 32))
        r = 22.0
        rot = math.radians(step * 10.0)
        mand = None
        for k in range(6):
            a = rot + k * math.tau / 6
            d = (math.cos(a), math.sin(a))
            side = (-d[1], d[0])
            base = (d[0] * (r - 6), d[1] * (r - 6))
            tri = cv.polygon([(base[0] + side[0] * 5, base[1] + side[1] * 5), (d[0] * (r + 7), d[1] * (r + 7)),
                              (base[0] - side[0] * 5, base[1] - side[1] * 5)])
            mand = tri if mand is None else mand | tri
        cv.part(mand, R_MANDIBLE)
        cv.part(cv.ellipse((0, 0), r, r), R_HEAD, deep=True)
        cv.flat(cv.ellipse((0, 0), r * 0.62, r * 0.62), PAL["ember-0"])
        cv.flat(cv.ellipse((0, 0), r * 0.3, r * 0.3), PAL["night-0"])
        for k in range(3):
            a = -rot * 0.5 + k * math.tau / 3
            e = (math.cos(a) * r * 0.45, math.sin(a) * r * 0.45)
            cv.part(cv.ellipse(e, 2.4, 2.4), mat("ember", 5, 4, 3, 1))
        img, mask = cv.finish()
        return img, mask, {}
    return render


GNARLMAW = [
    ("head", [roku_head(i) for i in range(6)], list(range(6)), 12, True),
    ("plate", [roku_plate(False), roku_plate(True)], [0], 1, False),
    ("tail", [roku_tail(False), roku_tail(True)], [0], 1, False),
    # Second looks of the plate and the tail's tip (design bible 8.1, pass 562). The art is the
    # Autosprite still dressed by autosprite_parts.py --dress; these are only its stand-ins.
    ("plate_spined", [roku_plate(False), roku_plate(True)], [0], 1, False),
    ("plate_mossy", [roku_plate(False), roku_plate(True)], [0], 1, False),
    ("tail_tip", [roku_tail(False), roku_tail(True)], [0], 1, False),
]


# --- NPCs ---------------------------------------------------------------------

def npc(look, bob=0, hand_dy=0.0):
    robe = mat_from(look.get("robe", "#6b6380"))
    trim = mat_from(look.get("trim", "#c9b98f"))
    skin = mat_from(look.get("skin", "#e8c9a0"), ["bark"])
    hair = mat_from(look.get("hair", "#3a2a1e"))
    hat = look.get("hat", "none")
    dwarf_build = look.get("build", "") == "dwarf"
    beard = look.get("beard", False) or dwarf_build
    ears = look.get("ears", False)

    def render(_):
        cv = Canvas(32, 48, (16, 46))
        top = (-22 if dwarf_build else -30) + bob
        half_hem = 9.5 if dwarf_build else 8.5
        head = (0.5, top - 5.5)
        # Back arm, robe, front arm.
        cv.part(cv.capsule((-4, top + 3), (-5.5, top + 12 + hand_dy), 2.0), robe)
        body = cv.polygon([(-5, top), (5, top), (half_hem, 0), (-half_hem, 0)]) | cv.ellipse((0, top + 1.5), 5.5, 2.6)
        cv.part(body, robe, deep=True)
        hem = body & cv.below(-3.0)
        cv.part(hem, trim)
        cv.part(cv.capsule((0.5, top + 2), (0.5, -3.5), 0.7), trim)
        cv.part(cv.ellipse(head, 4.4, 4.8), skin)
        if hat != "hood":
            hair_m = cv.ellipse((head[0] - 0.8, head[1] - 2.0), 5.0, 3.6) | cv.capsule((head[0] - 3.4, head[1] - 1), (head[0] - 3.8, head[1] + 3.5), 1.6)
            cv.part(hair_m & ~(cv.right_of(head[0] - 0.5) & cv.below(head[1] - 2.0)), hair)
        if beard:
            cv.part(cv.polygon([(head[0] - 2.5, head[1] + 1.5), (head[0] + 4.5, head[1] + 1.5), (head[0] + 2.5, top + 7),
                                (head[0] - 0.5, top + 8)]), hair)
        if ears:
            # An elf's long ear, swept back and up from the side of the head.
            ear = cv.polygon([(head[0] - 1.5, head[1] - 0.5), (head[0] - 0.5, head[1] + 1.8), (head[0] - 7.5, head[1] - 4.0)])
            cv.part(ear, skin)
        cv.pixel((head[0] + 2.0, head[1] - 0.5), DARK)
        cv.pixel((head[0] + 2.0, head[1] + 0.5), DARK)
        if hat == "crown":
            band = cv.polygon([(head[0] - 4.5, head[1] - 6), (head[0] + 4.5, head[1] - 6), (head[0] + 4.5, head[1] - 3.5),
                               (head[0] - 4.5, head[1] - 3.5)])
            spikes = cv.polygon([(head[0] - 4.5, head[1] - 6), (head[0] - 3.5, head[1] - 9), (head[0] - 2, head[1] - 6),
                                 (head[0] - 0.5, head[1] - 9.5), (head[0] + 1, head[1] - 6), (head[0] + 2.5, head[1] - 9),
                                 (head[0] + 4.5, head[1] - 6)])
            cv.part(band | spikes, mat("gold", 6, 5, 4, 2))
            cv.pixel((head[0] - 0.5, head[1] - 5), PAL["ember-3"])
        elif hat == "hood":
            hood = cv.ellipse((head[0] - 0.5, head[1] - 1), 6.0, 6.2) & ~(cv.right_of(head[0] - 1.0) & cv.below(head[1] - 2.5))
            cv.part(hood, robe)
        elif hat == "cap":
            cv.part(cv.ellipse((head[0] - 0.5, head[1] - 4), 5.0, 2.6) | cv.capsule((head[0] + 2, head[1] - 3.5), (head[0] + 6, head[1] - 3), 1.0),
                    trim)
        elif hat == "helm":
            cv.part(cv.ellipse((head[0] - 0.5, head[1] - 3), 5.6, 3.4) & ~cv.below(head[1] - 1.5), mat("stone", 5, 4, 3, 1))
        cv.part(cv.capsule((4, top + 3), (5.5, top + 11 + hand_dy), 2.0), robe)
        cv.part(cv.ellipse((5.8, top + 12 + hand_dy), 1.8, 1.8), skin)
        img, mask = cv.finish()
        return img, mask, {"head": [head[0], head[1]]}
    return render


# --- Sap Spitter: a bark-rooted turret with an amber sac -----------------------

SPIT_ROOT = mat("bark", 3, 2, 1, 0)
SPIT_SAC = mat("gold", 5, 4, 2, 1)
SPIT_SAC_HOT = mat("gold", 6, 5, 4, 2)
SPIT_LIP = mat("bark", 5, 4, 2, 0)


def sap_spitter(sac, hot=False, spout=1.0, lean=0.0):
    """sac: the sac's radius; spout: how far the mouth sticks out; lean tips it back."""
    def render(_):
        cv = Canvas(32, 32, (16, 30))
        # Roots gripping the floor.
        for a, b in (((-9, 0), (-3, -6)), ((9, 0), (3, -6)), ((-5, 0), (-1, -7)), ((5, 0), (1, -7))):
            cv.part(cv.capsule(a, b, 1.4), SPIT_ROOT)
        cv.part(cv.ellipse((0, -6), 6.5, 4.5), SPIT_ROOT, deep=True)
        cy = -8 - sac + lean * 0.3
        cv.part(cv.ellipse((-lean, cy), sac, sac * 0.92), SPIT_SAC_HOT if hot else SPIT_SAC, deep=True)
        # Veins over the sac.
        for vx in (-0.45, 0.2):
            vein = cv.ellipse((-lean + vx * sac, cy + 2), 0.6, sac * 0.45) & cv.ellipse((-lean, cy), sac - 1.5, sac - 1.5)
            cv.flat(vein, PAL["gold-2"])
        # The spout, angled forward and up.
        base = (-lean + sac * 0.55, cy - sac * 0.55)
        tip = (base[0] + 3.5 * spout, base[1] - 3.0 * spout)
        cv.part(cv.capsule(base, tip, 2.2), SPIT_LIP)
        cv.flat(cv.ellipse(tip, 1.1, 1.1), DARK)
        cv.pixel((tip[0] + 0.5, tip[1] + 1.6), PAL["gold-6"])
        img, mask = cv.finish()
        return img, mask, {"mouth": [round(tip[0], 1), round(tip[1], 1)]}
    return render


SAP_SPITTER = [
    ("idle", [sap_spitter(6.0), sap_spitter(6.4)], [0, 1], 3, True),
    ("windup", [sap_spitter(7.4, True, 0.7, 1.0), sap_spitter(8.0, True, 0.6, 1.5)], [0, 1], 8, True),
    ("spit", [sap_spitter(5.0, False, 1.5, -1.5)], [0], 1, False),
]


# --- Grub Lump: a bark-plated grub that crawls over every surface -------------

GRUB_FLESH = mat("leaf", 7, 6, 5, 3)
GRUB_PLATE = mat("bark", 4, 3, 2, 0)
GRUB_JAW = mat("gold", 5, 4, 3, 1)
GRUB_LEG = mat("bark", 2, 1, 1, 0)


def grub_lump(phase=0.0, rear=0.0, jaw=0.5, curl=0.0):
    """Drawn crawling along a floor, head toward +x; the game turns it to cling
    to walls and ceilings. phase: the crawl wave; rear: how far the front half
    lifts (the drop telegraph); jaw: how wide the mandibles open; curl: 0 lying
    flat, 1 balled up (falling)."""
    def render(_):
        cv = Canvas(32, 24, (16, 21))
        segs = []
        for i in range(4):
            x = -8.5 + i * 4.6
            lift = max(0.0, math.sin(phase - i * 1.2)) * 1.4 + rear * i * 0.9
            # Balled up, the segments gather into a ring.
            a = math.pi * (0.95 - i * 0.42)
            cx = x * (1 - curl) + math.cos(a) * 5.0 * curl
            cy = (-4.4 - lift) * (1 - curl) + (-7 - math.sin(a) * 4.5) * curl
            segs.append((cx, cy, 4.8 - abs(i - 1.5) * 0.4))
        for cx, cy, r in segs:
            cv.part(cv.ellipse((cx, cy), r, r * 0.95), GRUB_FLESH, deep=True)
        for cx, cy, r in segs:
            plate = cv.ellipse((cx - 0.6, cy - r * 0.55), r * 0.62, r * 0.42) & cv.ellipse((cx, cy), r - 0.5, r * 0.9)
            cv.part(plate, GRUB_PLATE)
        hx, hy, _ = segs[-1]
        head = (hx + 4.4 * (1 - curl) + 1.5 * curl, hy + 0.6 - rear * 1.2)
        cv.part(cv.ellipse(head, 3.4, 3.0), GRUB_PLATE, deep=True)
        for side in (-1, 1):
            tip = (head[0] + 3.2, head[1] + side * (1.0 + jaw * 2.2))
            cv.part(cv.capsule((head[0] + 1.6, head[1] + side * 0.8), tip, 0.9), GRUB_JAW)
        cv.pixel((head[0] + 0.8, head[1] - 1.2), DARK)
        cv.pixel((head[0] + 1.2, head[1] - 1.8), PAL["gold-6"])
        # Stubby legs under the front segments.
        if curl < 0.5:
            for cx, cy, r in segs[1:]:
                cv.part(cv.capsule((cx, cy + r * 0.6), (cx + 0.6, -0.6), 0.8), GRUB_LEG)
        img, mask = cv.finish()
        return img, mask, {}
    return render


GRUB_LUMP = [
    ("crawl", [grub_lump(p) for p in (0.0, 1.6, 3.2, 4.8)], [0, 1, 2, 3], 6, True),
    ("windup", [grub_lump(0.0, 1.0, 1.0), grub_lump(0.8, 1.3, 1.2)], [0, 1], 10, True),
    ("drop", [grub_lump(0.0, 0.0, 0.9, 1.0)], [0], 1, False),
]


# --- Bog Puffcap: a squat marsh mushroom that bursts into a spore cloud ----------
# Drawn at 2x like the Iron Dwarf. Its gills glow when it swells (the telegraph);
# spent, the cap sags open and soft.

BM_STALK = mat("stone", 5, 4, 3, 1)
BM_CAP = mat("leaf", 3, 2, 1, 0)
BM_CAP_HOT = mat("leaf", 4, 3, 2, 0)
BM_SPOT = mat("stone", 6, 5, 4, 2)
BM_SPOT_HOT = mat("gold", 6, 5, 4, 2)
BM_GILL = mat("night", 3, 2, 1, 0)
BM_GILL_HOT = mat("gold", 6, 6, 5, 3)
BM_ROOT = mat("bark", 3, 2, 1, 0)
BM_SCALE = 2


def bog_puffcap(swell=0.0, sag=0.0, hot=False, sway=0.0):
    """swell: 0 resting, 1 about to burst; sag: 0 firm, 1 spent and drooping; sway tilts the cap."""
    def render(_):
        cv = Canvas(40, 40, (20, 38), BM_SCALE)
        # Rootlets in the mud.
        for a, b in (((-8, 0), (-3, -4)), ((8, 0), (3, -4)), ((-4, 0), (-1, -5)), ((5, 0), (1, -5))):
            cv.part(cv.capsule(a, b, 1.1), BM_ROOT)
        top = -17 - swell * 2 + sag * 3
        stalk = cv.polygon([(-4.5, -1), (4.5, -1), (3.2 + sway * 0.5, top), (-3.2 + sway * 0.5, top)])
        cv.part(stalk | cv.ellipse((0, -2), 5.5, 2.5), BM_STALK, deep=True)
        # A face in the stalk: two hollow eyes and a slack mouth.
        ey = top + 7.5 + sag * 0.5
        cv.flat(cv.ellipse((-1.7 + sway * 0.3, ey), 0.8, 1.1), DARK)
        cv.flat(cv.ellipse((1.9 + sway * 0.3, ey), 0.8, 1.1), DARK)
        if hot:
            cv.pixel((-1.7 + sway * 0.3, ey), PAL["gold-6"])
            cv.pixel((1.9 + sway * 0.3, ey), PAL["gold-6"])
        cv.flat(cv.ellipse((0.2 + sway * 0.3, ey + 3.5 + sag), 1.2, 0.7 + sag * 0.6), DARK)
        # The cap: a dome that swells before it bursts and flattens when spent.
        cx, cy = sway, top - 1
        rx = 11 + swell * 3 - sag * 1.5
        ry = 7 + swell * 2 - sag * 3
        dome = cv.ellipse((cx, cy), rx, ry)
        under = cv.ellipse((cx, cy + ry * 0.55), rx * 0.95, ry * 0.45)
        cv.part(dome, BM_CAP_HOT if hot else BM_CAP, deep=True)
        cv.part(under, BM_GILL_HOT if hot else BM_GILL)
        for i in (-3, -1.6, -0.5, 0.7, 1.8, 3):
            gx = cx + i * rx * 0.24
            cv.flat(cv.capsule((gx, cy + ry * 0.4), (gx * 1.05 - cx * 0.05, cy + ry * 0.85), 0.35),
                    PAL["gold-4"] if hot else PAL["night-0"])
        for sx, sy, r in ((-0.5, -0.45, 1.8), (0.35, -0.6, 1.4), (0.6, -0.1, 1.1), (-0.25, -0.05, 1.0)):
            cv.part(cv.ellipse((cx + sx * rx, cy + sy * ry), r * (1 + swell * 0.3), r * (1 + swell * 0.3)), BM_SPOT_HOT if hot else BM_SPOT)
        img, mask = cv.finish()
        return img, mask, {"cap": [round(cx, 1), round(cy, 1)]}
    return render


BOG_PUFFCAP = [
    ("idle", [bog_puffcap(0.0, sway=-0.5), bog_puffcap(0.15, sway=0.5)], [0, 1], 2, True),
    ("windup", [bog_puffcap(0.7, hot=True), bog_puffcap(1.0, hot=True, sway=0.4)], [0, 1], 10, True),
    ("burst", [bog_puffcap(-0.3, 0.3)], [0], 1, False),
    ("spent", [bog_puffcap(0.0, 1.0, sway=-0.4), bog_puffcap(0.0, 0.9, sway=0.4)], [0, 1], 3, True),
]


# --- Drowned Dwarf: a Lampwick miner the marsh took, risen with his anchor -------
# Drawn at the 2x render density. `depth` sinks the whole body below the ground
# line (y = 0) and clips it there, for lying in wait and rising out of the mire.

DD_SCALE = 2
DD_SKIN = mat("sky", 7, 6, 4, 2)  # drowned pallor, gone blue-white
DD_SKIN_BACK = mat("sky", 6, 5, 3, 2)
DD_MAIL = mat("stone", 3, 2, 1, 0)
DD_MAIL_BACK = mat("stone", 2, 1, 1, 0)
DD_RUST = mat("ember", 3, 2, 1, 0)
DD_WEED = mat("leaf", 2, 1, 1, 0)
DD_HELM = mat("stone", 4, 3, 2, 0)
DD_BEARD = mat("stone", 5, 4, 3, 1)
DD_ANCHOR = mat("stone", 5, 4, 2, 0)
DD_MUD = mat("bark", 2, 1, 0, 0)
DD_BOOT = mat("bark", 3, 2, 1, 0)
DD_EYE = PAL["crystal-6"]


def drowned_dwarf(hip=(0, -11), lean=0, feet=((5, 0), (-5, 0)), hands=(7, -14), anchor=100, bob=0,
                  depth=0.0, reach_up=0.0, mire=False):
    """anchor: degrees of the shank from the hands toward the flukes (90 = hanging down,
    -90 = straight up). reach_up lifts the free hand, clawing out of the mud."""
    def render(_):
        cv = Canvas(72, 64, (32, 61), DD_SCALE)
        dy = depth
        hx, hy = hip[0], hip[1] + dy
        sx, sy = hx + lean, hy - 13 + bob
        head = (sx + 1.5, sy - 6)
        fts = [(f[0], f[1] + dy) for f in feet]

        def leg(h, foot, m):
            foot = reach(h, foot, 10.5)
            knee = ik(h, foot, 5.5, 5.5, 1)
            cv.part(cv.capsule(h, knee, 3.0) | cv.capsule(knee, foot, 2.6), m)
            cv.part(cv.capsule((foot[0] - 2, foot[1] - 2), (foot[0] + 3, foot[1] - 1.6), 2.4), DD_BOOT)

        # The anchor, by its shank: a ring at the hands, a crown of two flukes at the end.
        a = math.radians(anchor)
        grip = reach((sx, sy + 2), (hands[0], hands[1] + dy), 12)
        ring = (grip[0] - math.cos(a) * 3, grip[1] - math.sin(a) * 3)
        crown = (grip[0] + math.cos(a) * 19, grip[1] + math.sin(a) * 19)
        perp = (-math.sin(a), math.cos(a))
        leg((hx - 3, hy), fts[1], DD_MAIL_BACK)
        free = (sx - 6 - 2 * reach_up, sy + 4 - 14 * reach_up)
        elbow_b = ik((sx - 4, sy + 2), free, 6.0, 6.0, -1)
        cv.part(cv.capsule((sx - 4, sy + 2), elbow_b, 2.5) | cv.capsule(elbow_b, free, 2.2), DD_SKIN_BACK)
        cv.part(cv.ellipse(free, 2.2, 2.2), DD_SKIN_BACK)
        cv.part(cv.capsule(ring, crown, 1.7), DD_ANCHOR)
        cv.part(cv.ellipse(ring, 2.4, 2.4) & ~cv.ellipse(ring, 1.1, 1.1), DD_ANCHOR)
        stock = [(ring[0] + perp[0] * s * 5 + math.cos(a) * 2.5, ring[1] + perp[1] * s * 5 + math.sin(a) * 2.5) for s in (-1, 1)]
        cv.part(cv.capsule(stock[0], stock[1], 0.9), DD_RUST)
        for s in (-1, 1):
            tip = (crown[0] + perp[0] * s * 9 - math.cos(a) * 6, crown[1] + perp[1] * s * 9 - math.sin(a) * 6)
            mid = (crown[0] + perp[0] * s * 5.5 + math.cos(a) * 0.5, crown[1] + perp[1] * s * 5.5 + math.sin(a) * 0.5)
            cv.part(cv.capsule(crown, mid, 2.0) | cv.capsule(mid, tip, 1.5), DD_ANCHOR)
            cv.part(cv.polygon([(tip[0] - math.cos(a) * 1.5, tip[1] - math.sin(a) * 1.5), (tip[0] + math.cos(a) * 3 + perp[0] * s * 2.5, tip[1] + math.sin(a) * 3 + perp[1] * s * 2.5),
                                (tip[0] - perp[0] * s * 2.5, tip[1] - perp[1] * s * 2.5)]), DD_ANCHOR)
        cv.pixel((crown[0] + perp[0] * 2, crown[1] + perp[1] * 2), PAL["ember-3"])
        cv.pixel((grip[0] + math.cos(a) * 8, grip[1] + math.sin(a) * 8), PAL["ember-2"])
        leg((hx + 3, hy), fts[0], DD_MAIL)
        # A sodden torso in rotted mail, a rope belt and weed hanging off it.
        torso = cv.polygon([(sx - 8, sy), (sx + 8, sy), (hx + 8.5, hy + 1), (hx - 8.5, hy + 1)]) | cv.ellipse((sx, sy + 2), 8.5, 4)
        cv.part(torso, DD_MAIL, deep=True)
        cv.part(cv.capsule((hx - 8, hy - 1.5), (hx + 8, hy - 1.5), 1.2), mat("bark", 4, 3, 2, 0))
        for wx, wl in ((-5, 6), (-1, 4), (4, 7)):
            cv.part(cv.capsule((hx + wx, hy - 1), (hx + wx - 0.5, hy - 1 + wl), 0.7), DD_WEED)
        cv.part(cv.ellipse((sx + 5, sy + 1), 3.6, 3.0), DD_RUST)  # a rusted pauldron
        # Front arm on the shank.
        elbow_f = ik((sx + 4, sy + 2), grip, 6.5, 6.5, -1)
        cv.part(cv.capsule((sx + 4, sy + 2), elbow_f, 2.6) | cv.capsule(elbow_f, grip, 2.3), DD_SKIN)
        cv.part(cv.ellipse(grip, 2.3, 2.3), DD_SKIN)
        # Head: a bloated face under a dented helm, the beard matted with weed.
        cv.part(cv.ellipse(head, 5.4, 5.0), DD_SKIN)
        helm = cv.ellipse((head[0] - 0.3, head[1] - 2.2), 6.3, 4.2) & ~cv.below(head[1] - 0.8)
        cv.part(helm, DD_HELM)
        cv.part(cv.capsule((head[0] - 6, head[1] - 1.6), (head[0] + 6, head[1] - 1.6), 1.1), DD_HELM)
        cv.part(cv.capsule((head[0] - 1, head[1] - 6.2), (head[0] - 3.5, head[1] - 8.4), 0.9), DD_RUST)  # the crest
        beard = cv.polygon([(head[0] - 1.5, head[1] + 2.2), (head[0] + 5.2, head[1] + 2.2), (head[0] + 4.2, sy + 6),
                            (head[0] + 1.6, sy + 8.5), (head[0] - 0.8, sy + 5)])
        cv.part(beard, DD_BEARD)
        cv.part(cv.capsule((head[0] + 2.2, sy + 3), (head[0] + 2.8, sy + 9), 0.6), DD_WEED)
        cv.part(cv.capsule((head[0] - 0.5, head[1] + 3), (head[0] - 2.5, sy + 4), 0.6), DD_WEED)
        # Drowned eyes: a cold pale light under the brim.
        cv.pixel((head[0] + 2, head[1] - 0.2), DD_EYE)
        cv.pixel((head[0] + 4, head[1] - 0.2), DD_EYE)
        if depth > 0 or mire:
            # Cut at the ground line, with a ring of churned mud where the body breaks it.
            gone = cv.below(0.0)
            cv.filled &= ~gone
            ring_w = 11.0 if depth > 0 else 9.0
            cv.part(cv.ellipse((0, 0.6), ring_w, 2.2) & ~cv.below(1.5), DD_MUD)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def drowned_walk(i):
    t = i / 4 * math.tau
    fx = 4.0 * math.cos(t)
    return drowned_dwarf(hip=(0, -11 - (1 if i % 2 else 0)), lean=1,
                         feet=((fx, -max(0, 2 * math.sin(t))), (-fx, -max(0, -2 * math.sin(t)))),
                         hands=(7, -13), anchor=96 + 6 * math.cos(t))


DROWNED_DWARF = [
    ("sunk", [drowned_dwarf(depth=33.5, reach_up=0.0), drowned_dwarf(depth=32.5, reach_up=0.0)], [0, 1], 2, True),
    ("rise", [drowned_dwarf(depth=26, reach_up=1.0, anchor=60), drowned_dwarf(depth=18, reach_up=1.0, anchor=70),
              drowned_dwarf(depth=9, reach_up=0.6, anchor=85), drowned_dwarf(depth=2, reach_up=0.2, anchor=95, mire=True)],
     [0, 1, 2, 3], 6, False),
    ("sink", [drowned_dwarf(depth=2, reach_up=0.2, anchor=95, mire=True), drowned_dwarf(depth=9, reach_up=0.6, anchor=85),
              drowned_dwarf(depth=18, reach_up=1.0, anchor=70), drowned_dwarf(depth=26, reach_up=1.0, anchor=60)],
     [0, 1, 2, 3], 6, False),
    ("walk", [drowned_walk(i) for i in range(4)], [0, 1, 2, 3], 4, True),
    ("heave", [drowned_dwarf(lean=-3, hands=(-1, -32), anchor=-115, feet=((6, 0), (-6, 0))),
               drowned_dwarf(lean=-4, hands=(-2, -33), anchor=-108, feet=((6, 0), (-6, 0)), bob=-1)], [0, 1], 8, True),
    ("slam", [drowned_dwarf(lean=3, hands=(10, -26), anchor=-20, feet=((7, 0), (-6, 0))),
              drowned_dwarf(lean=5, hands=(13, -10), anchor=70, feet=((8, 0), (-6, 0)), hip=(0, -9))], [0, 1], 16, False),
    ("mired", [drowned_dwarf(lean=6, hands=(13, -8), anchor=80, feet=((8, 0), (-6, 0)), hip=(0, -8)),
               drowned_dwarf(lean=5, hands=(13, -9), anchor=78, feet=((8, 0), (-6, 0)), hip=(0, -8), bob=1)], [0, 1], 4, True),
    ("stagger", [drowned_dwarf(lean=-5, feet=((3, 0), (-7, 0)), hands=(-3, -26), anchor=-160)], [0], 1, False),
]


# --- Bark Knight: a knight of living bark from the High Boughs, with a growing lance -----
# Drawn at the 2x render density. `armored` False strips the bark plates to the pale
# heartwood beneath; `lance` is the length of the living branch it carries (it grows
# to its full reach in the thrust); `roots` spreads roots from the feet into the bough.

BK_SCALE = 2
BK_BARK = mat("bark", 4, 3, 2, 0)
BK_BARK_BACK = mat("bark", 3, 2, 1, 0)
BK_HEART = mat("bark", 6, 5, 4, 2)
BK_HEART_BACK = mat("bark", 5, 4, 3, 1)
BK_LEAF = mat("leaf", 5, 4, 3, 1)
BK_MOSS = mat("leaf", 3, 2, 1, 0)
BK_LANCE = mat("bark", 5, 4, 3, 1)
BK_THORN = mat("stone", 7, 6, 4, 2)
BK_EYE = PAL["gold-6"]


def bark_knight(hip=(0, -15), lean=0, feet=((4, 0), (-4, 0)), hand=(8, -22), angle=-70, lance=20,
                armored=True, roots=0.0, bob=0, glow=False):
    """angle: degrees of the lance from the hand to its tip (0 = forward, -90 = up)."""
    def render(_):
        cv = Canvas(112, 64, (36, 61), BK_SCALE)
        hx, hy = hip
        sx, sy = hx + lean, hy - 15 + bob
        head = (sx + 1, sy - 6)
        body_m = BK_BARK if armored else BK_HEART
        back_m = BK_BARK_BACK if armored else BK_HEART_BACK

        def leg(h, foot, m):
            foot = reach(h, foot, 14.5)
            knee = ik(h, foot, 7.5, 7.5, 1)
            cv.part(cv.capsule(h, knee, 2.4) | cv.capsule(knee, foot, 2.0), m)
            # Root-toes splay from each foot.
            for dx in (-3, 1, 4):
                cv.part(cv.capsule(foot, (foot[0] + dx, foot[1] + 0.5), 1.0), back_m)

        if roots > 0:
            for i, dx in enumerate((-14, -9, -4, 5, 10, 15)):
                cv.part(cv.capsule((dx * 0.25, -0.5), (dx * roots, 0.5 + (i % 2) * 0.6), 1.2), BK_BARK_BACK)
        leg((hx - 2, hy), feet[1], back_m)
        # The back arm hangs at his side.
        cv.part(cv.capsule((sx - 4, sy + 2), (sx - 6, sy + 13), 2.0), back_m)
        leg((hx + 2, hy), feet[0], body_m)
        # A lean torso, plated with bark (or bare heartwood once the plates are gone).
        torso = cv.polygon([(sx - 6, sy), (sx + 6, sy), (hx + 5, hy + 1), (hx - 5, hy + 1)]) | cv.ellipse((sx, sy + 2), 6.5, 3.2)
        cv.part(torso, body_m, deep=True)
        if armored:
            for py in (sy + 3, sy + 8, sy + 12):
                cv.part(cv.capsule((sx - 5, py), (sx + 5, py - 1), 0.6), BK_BARK_BACK)
            cv.part(cv.ellipse((sx - 4, sy + 1), 3.6, 3.0), BK_BARK)  # pauldron
            cv.part(cv.ellipse((sx - 4.5, sy - 1.5), 2.6, 1.2), BK_MOSS)
        else:
            for py in (sy + 4, sy + 9):
                cv.part(cv.capsule((sx - 3, py), (sx + 3, py + 1), 0.4), BK_HEART_BACK)
        # The lance: a living branch in the front hand, budding leaves, a thorn at its tip.
        a = math.radians(angle)
        grip = reach((sx + 4, sy + 2), hand, 13)
        tip = (grip[0] + math.cos(a) * lance, grip[1] + math.sin(a) * lance)
        butt = (grip[0] - math.cos(a) * 6, grip[1] - math.sin(a) * 6)
        cv.part(cv.capsule(butt, tip, 1.3), BK_LANCE)
        perp = (-math.sin(a), math.cos(a))
        n = max(1, int(lance // 10))
        for i in range(n):
            k = (i + 0.6) / (n + 0.4)
            bud = (grip[0] + math.cos(a) * lance * k, grip[1] + math.sin(a) * lance * k)
            side = 1 if i % 2 else -1
            cv.part(cv.ellipse((bud[0] + perp[0] * side * 2.2, bud[1] + perp[1] * side * 2.2), 1.6, 1.0), BK_LEAF)
        cv.part(cv.polygon([(tip[0] + perp[0] * 1.6, tip[1] + perp[1] * 1.6), (tip[0] - perp[0] * 1.6, tip[1] - perp[1] * 1.6),
                            (tip[0] + math.cos(a) * 5, tip[1] + math.sin(a) * 5)]), BK_THORN)
        elbow = ik((sx + 4, sy + 2), grip, 7, 7, -1)
        cv.part(cv.capsule((sx + 4, sy + 2), elbow, 2.2) | cv.capsule(elbow, grip, 1.9), body_m)
        cv.part(cv.ellipse(grip, 2.1, 2.1), back_m)
        # A knotted helm with a crest of leaves, and two amber eyes in the knot.
        cv.part(cv.ellipse(head, 4.6, 5.2), body_m)
        if armored:
            cv.part(cv.ellipse((head[0], head[1] - 2), 5.2, 3.6) & ~cv.below(head[1] - 0.5), BK_BARK_BACK)
        for i, (dx, dy) in enumerate(((-3, -7), (-1, -8.5), (1.5, -8), (3.5, -6.5))):
            cv.part(cv.ellipse((head[0] + dx, head[1] + dy), 1.8, 1.2 + 0.3 * (i % 2)), BK_LEAF)
        eye = PAL["gold-7"] if glow else BK_EYE
        cv.pixel((head[0] + 1.5, head[1] - 0.5), eye)
        cv.pixel((head[0] + 3.5, head[1] - 0.5), eye)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def bark_walk(i, armored):
    t = i / 4 * math.tau
    fx = 4.0 * math.cos(t)
    return bark_knight(hip=(0, -15 - (1 if i % 2 else 0)), armored=armored,
                       feet=((fx, -max(0, 2 * math.sin(t))), (-fx, -max(0, -2 * math.sin(t)))),
                       hand=(8, -22), angle=-72 + 4 * math.cos(t))


def bark_set(armored):
    pre = "" if armored else "bare_"
    return [
        (pre + "walk", [bark_walk(i, armored) for i in range(4)], [0, 1, 2, 3], 5, True),
        (pre + "brace", [bark_knight(lean=-3, hand=(-4, -20), angle=-8, lance=20, feet=((6, 0), (-6, 0)), armored=armored, glow=True),
                         bark_knight(lean=-4, hand=(-5, -20), angle=-6, lance=20, feet=((6, 0), (-6, 0)), armored=armored, bob=1)],
         [0, 1], 8, True),
        (pre + "thrust", [bark_knight(lean=3, hand=(10, -19), angle=0, lance=36, feet=((7, 0), (-6, 0)), armored=armored, glow=True),
                          bark_knight(lean=4, hand=(11, -18), angle=0, lance=56, feet=((8, 0), (-6, 0)), armored=armored, glow=True)],
         [0, 1], 16, False),
        (pre + "rooted", [bark_knight(lean=4, hand=(11, -18), angle=0, lance=56, feet=((8, 0), (-6, 0)), armored=armored, roots=1.0),
                          bark_knight(lean=4, hand=(11, -18), angle=0, lance=56, feet=((8, 0), (-6, 0)), armored=armored, roots=1.1, bob=1)],
         [0, 1], 3, True),
        (pre + "stagger", [bark_knight(lean=-5, feet=((2, 0), (-7, 0)), hand=(2, -30), angle=-120, armored=armored)], [0], 1, False),
    ]


BARK_KNIGHT = bark_set(True) + bark_set(False)


# --- Seed Bomber: a pod-bellied canopy bird that sows the Tree from above ---------
# Leaf wings and a husk of hard seeds for a belly; the seed it drops is drawn in code
# (scripts/enemies/bomber_seed.gd) in the same husk colors. 2x render density.

SB_LEAF = mat("leaf", 6, 5, 3, 1)
SB_LEAF_BACK = mat("leaf", 4, 3, 2, 0)
SB_RIB = mat("leaf", 2, 2, 1, 1)
SB_HUSK = mat("bark", 5, 4, 2, 0)
SB_HUSK_HOT = mat("gold", 5, 4, 3, 1)
SB_FEATHER = mat("leaf", 4, 3, 2, 0)
SB_BEAK = mat("gold", 6, 5, 4, 2)
SB_SCALE = 2


def seed_bomber(wing=40.0, swell=0.0, hot=False, empty=False, tilt=0.0, dazed=False):
    """wing: the wings' angle in degrees above straight back (up is positive); swell:
    0 resting, 1 squeezing the seeds out; empty: the husk hangs open after a drop;
    tilt turns the whole bird (downed, it lies on its back)."""
    def render(_):
        cv = Canvas(56, 44, (28, 22), SB_SCALE)
        rot = math.radians(tilt)

        def r(p):
            return (p[0] * math.cos(rot) - p[1] * math.sin(rot), p[0] * math.sin(rot) + p[1] * math.cos(rot))

        def leaf_wing(shoulder, ang, material, size):
            a = math.radians(180 - ang)
            u = (math.cos(a), -math.sin(a))
            v = (-u[1], u[0])
            ln = 15 * size
            pts = []
            for k, w in ((0.0, 0.0), (0.2, 3.2), (0.5, 4.4), (0.8, 3.0), (1.0, 0.0), (0.8, -2.0), (0.5, -2.8), (0.2, -2.0)):
                pts.append((shoulder[0] + u[0] * ln * k + v[0] * w * size, shoulder[1] + u[1] * ln * k + v[1] * w * size))
            cv.part(cv.polygon([r(q) for q in pts]), material)
            tip = (shoulder[0] + u[0] * ln * 0.92, shoulder[1] + u[1] * ln * 0.92)
            cv.flat(cv.capsule(r(shoulder), r(tip), 0.3), PAL["leaf-2"])

        leaf_wing((-1, -4), wing + 14, SB_LEAF_BACK, 0.9)
        # Tail: three leaf fronds fanned behind.
        for da, ln in ((-12, 7.0), (6, 8.0), (22, 6.5)):
            a = math.radians(180 + da)
            tip = (-6 + math.cos(a) * ln, -2 + math.sin(a) * ln)
            cv.part(cv.capsule(r((-6, -2)), r(tip), 1.4), SB_FEATHER)
        # The husk belly: a bark pod of seeds, seamed, swelling before the drop.
        bx, by = 0.0, 3.5 + swell * 0.8 + (1.5 if empty else 0.0)
        rx, ry = 7.0 + swell * 1.6 - (1.2 if empty else 0.0), 5.5 + swell * 1.6 - (1.0 if empty else 0.0)
        pod = cv.ellipse(r((bx, by)), rx, ry)
        cv.part(pod, SB_HUSK_HOT if hot else SB_HUSK, deep=True)
        for sx in (-0.45, 0.0, 0.45):
            seam = cv.capsule(r((bx + sx * rx, by - ry * 0.7)), r((bx + sx * rx * 0.8, by + ry * 0.75)), 0.35) & pod
            cv.flat(seam, PAL["gold-6"] if hot else PAL["bark-1"])
        if empty:
            # Split open along the bottom: a dark mouth where the seed fell out.
            cv.flat(cv.ellipse(r((bx, by + ry * 0.7)), rx * 0.5, 1.0) & pod, DARK)
        else:
            for sx in (-0.25, 0.25):
                cv.pixel(r((bx + sx * rx, by + ry * 0.85)), PAL["gold-6"] if hot else PAL["bark-5"])
        # Body and head: a leafy breast and a round head with a hooked gold beak.
        cv.part(cv.ellipse(r((0, -4)), 6.0, 4.2), SB_FEATHER, deep=True)
        hd = r((6.5, -7.5))
        cv.part(cv.ellipse(hd, 3.6, 3.3), SB_LEAF)
        cv.part(cv.polygon([r((9.0, -8.6)), r((12.6, -7.0)), r((10.6, -5.2)), r((9.0, -6.0))]), SB_BEAK)
        cv.part(cv.polygon([r((5.0, -10.5)), r((3.6, -14.5)), r((7.0, -10.8))]), SB_LEAF)  # a leaf crest
        eye = r((7.6, -8.4))
        if dazed:
            cv.pixel(eye, PAL["stone-6"])
            cv.pixel(r((8.4, -7.6)), PAL["stone-6"])
        else:
            cv.pixel(eye, PAL["ember-6"] if hot else DARK)
        # Feet tucked under the husk.
        for fx in (-2.5, 2.0):
            cv.part(cv.capsule(r((fx, by + ry - 0.5)), r((fx + 0.8, by + ry + 2.0)), 0.6), SB_BEAK)
        leaf_wing((0, -5), wing, SB_LEAF, 1.0)
        img, mask = cv.finish()
        return img, mask, {}
    return render


SEED_BOMBER = [
    ("fly", [seed_bomber(70), seed_bomber(25), seed_bomber(-25), seed_bomber(25)], [0, 1, 2, 3], 10, True),
    ("windup", [seed_bomber(95, 0.8, True), seed_bomber(100, 1.0, True)], [0, 1], 16, True),
    ("drop", [seed_bomber(-10, 0.0, empty=True)], [0], 1, False),
    ("empty", [seed_bomber(70, empty=True), seed_bomber(25, empty=True), seed_bomber(-25, empty=True), seed_bomber(25, empty=True)],
     [0, 1, 2, 3], 10, True),
    ("downed", [seed_bomber(-60, empty=True, tilt=170, dazed=True), seed_bomber(-50, empty=True, tilt=165, dazed=True)], [0, 1], 3, True),
    ("stagger", [seed_bomber(110, tilt=-25)], [0], 1, False),
]


# --- Marsh Hag: a bent crone of the drowned villages, with a wisp in her staff ------
# Drawn at the 2x render density. A shawl of reeds over a sodden dress, moss for hair,
# a long nose and one pale eye; she leans on a crooked willow staff. The wisp in its
# crook is drawn in code (scripts/enemies/marsh_hag.gd) so it can light the fog.

MH_SCALE = 2
MH_SHAWL = mat("gold", 3, 2, 1, 0)  # dry reeds, dull straw
MH_SHAWL_BACK = mat("gold", 2, 1, 0, 0)
MH_DRESS = mat("night", 4, 3, 2, 0)
MH_SKIN = mat("stone", 6, 5, 4, 2)  # old grey skin
MH_SKIN_BACK = mat("stone", 5, 4, 3, 1)
MH_MOSS = mat("leaf", 3, 2, 1, 0)
MH_STAFF = mat("bark", 4, 3, 2, 0)
MH_MUD = mat("bark", 2, 1, 0, 0)
MH_EYE = PAL["crystal-6"]


def marsh_hag(hunch=0.0, staff=(11, -30), feet=((4, 0), (-4, 0)), bob=0, hex_hand=0.0, dropped=False, tilt=0):
    """hunch: 0 bent over the staff, 1 drawn up straight for the hex. staff: where the
    staff's crook is (the wisp sits there). hex_hand: 0 the free hand hangs, 1 clawed
    up beside her face. dropped: the staff lies in the mud and she gropes for it."""
    def render(_):
        cv = Canvas(56, 52, (24, 49), MH_SCALE)
        hx, hy = 0.0, -9.0 + bob
        lean = 5.0 * (1.0 - hunch) + tilt
        sx, sy = hx + lean, hy - 9.0 + 3.0 * (1.0 - hunch)
        head = (sx + 3.0 + 1.5 * (1.0 - hunch), sy - 4.0 + 1.5 * (1.0 - hunch))
        # Back leg and the back of the shawl.
        cv.part(cv.capsule((hx - 2, hy), feet[1], 1.8), MH_DRESS)
        cv.part(cv.ellipse((feet[1][0] - 0.5, feet[1][1] - 1), 2.4, 1.4), MH_MUD)
        # The staff: a crooked willow stick from the ground to the crook.
        if dropped:
            cv.part(cv.capsule((-14, -1), (16, -2.5), 1.0), MH_STAFF)
            cv.part(cv.capsule((16, -2.5), (18, -6), 0.9), MH_STAFF)
        else:
            base = (staff[0] - 2.0, 0.0)
            knot = ((base[0] + staff[0]) / 2 + 1.0, (base[1] + staff[1]) / 2)
            cv.part(cv.capsule(base, knot, 1.1) | cv.capsule(knot, staff, 1.0), MH_STAFF)
            # The crook bends back over the wisp.
            cv.part(cv.capsule(staff, (staff[0] - 2.5, staff[1] - 3.0), 0.9), MH_STAFF)
            cv.part(cv.capsule((staff[0] - 2.5, staff[1] - 3.0), (staff[0] - 4.0, staff[1] - 1.0), 0.8), MH_STAFF)
        # A sodden dress in a bell to the ankles, ragged at the hem.
        dress = cv.polygon([(sx - 5, sy + 1), (sx + 4, sy + 1), (hx + 7, hy + 7), (hx + 4, hy + 9), (hx, hy + 8),
                            (hx - 4, hy + 9.5), (hx - 7.5, hy + 7)])
        cv.part(dress, MH_DRESS, deep=True)
        cv.part(cv.capsule((hx + 2, hy + 2), feet[0], 1.8), MH_DRESS)
        cv.part(cv.ellipse((feet[0][0] + 0.5, feet[0][1] - 1), 2.4, 1.4), MH_MUD)
        # The reed shawl over the hunched back, hanging in strands.
        shawl = cv.ellipse((sx - 1.5, sy + 1.5), 7.0, 5.0) | cv.polygon([(sx - 8, sy + 2), (sx + 5, sy + 2), (sx + 3, sy + 9), (sx - 7, sy + 10)])
        cv.part(shawl, MH_SHAWL, deep=True)
        for rx in (-6.0, -3.0, 0.0, 3.0):
            cv.part(cv.capsule((sx + rx, sy + 7), (sx + rx - 0.5, sy + 12.5), 0.5), MH_SHAWL_BACK)
        # Free (back) arm: hangs, or claws up beside the face for the hex.
        sh_b = (sx - 3, sy + 2)
        hand_b = (sx - 6 + 3 * hex_hand, sy + 9 - 17 * hex_hand)
        if dropped:
            hand_b = (sx + 8, -2)
        el_b = ik(sh_b, hand_b, 4.5, 4.5, 1)
        cv.part(cv.capsule(sh_b, el_b, 1.1) | cv.capsule(el_b, hand_b, 1.0), MH_SKIN_BACK)
        for k in (-1, 0, 1):
            cv.part(cv.capsule(hand_b, (hand_b[0] + k * 1.2, hand_b[1] - 2.0), 0.45), MH_SKIN_BACK)
        # Front arm on the staff.
        sh_f = (sx + 2, sy + 2)
        grip = (staff[0] - 0.5, staff[1] + 9.0) if not dropped else (sx + 9, -3)
        el_f = ik(sh_f, grip, 5.0, 5.0, -1)
        cv.part(cv.capsule(sh_f, el_f, 1.1) | cv.capsule(el_f, grip, 1.0), MH_SKIN)
        cv.part(cv.ellipse(grip, 1.3, 1.3), MH_SKIN)
        # Head: moss hair, a long hooked nose, a pointed chin, one pale eye.
        cv.part(cv.ellipse(head, 3.8, 3.6), MH_SKIN)
        cv.part(cv.polygon([(head[0] + 2.5, head[1] - 0.5), (head[0] + 6.5, head[1] + 2.2), (head[0] + 2.8, head[1] + 1.6)]), MH_SKIN)
        cv.part(cv.polygon([(head[0] + 0.5, head[1] + 2.5), (head[0] + 3.0, head[1] + 2.8), (head[0] + 2.2, head[1] + 4.8)]), MH_SKIN)
        hair = cv.ellipse((head[0] - 1.5, head[1] - 1.5), 4.8, 3.6) & ~cv.right_of(head[0] - 0.2)
        hair |= cv.capsule((head[0] - 3.5, head[1]), (head[0] - 4.5, head[1] + 7.5), 1.3)
        cv.part(hair, MH_MOSS)
        cv.pixel((head[0] + 1.8, head[1] - 0.3), MH_EYE)
        img, mask = cv.finish()
        return img, mask, {}
    return render


def hag_walk(i):
    t = i / 4 * math.tau
    fx = 3.0 * math.cos(t)
    return marsh_hag(staff=(11 + 1.5 * math.cos(t), -30), feet=((fx, -max(0, 1.5 * math.sin(t))), (-fx, -max(0, -1.5 * math.sin(t)))),
                     bob=-(1 if i % 2 else 0))


MARSH_HAG = [
    ("idle", [marsh_hag(), marsh_hag(bob=1)], [0, 1], 2, True),
    ("walk", [hag_walk(i) for i in range(4)], [0, 1, 2, 3], 4, True),
    ("hex", [marsh_hag(hunch=1.0, staff=(11, -36), hex_hand=1.0), marsh_hag(hunch=1.0, staff=(11, -37), hex_hand=0.85, bob=-1)], [0, 1], 10, True),
    ("cast", [marsh_hag(hunch=0.6, staff=(13, -30), hex_hand=0.3, feet=((5, 0), (-4, 0)))], [0], 1, False),
    ("fumble", [marsh_hag(hunch=0.0, dropped=True, tilt=2), marsh_hag(hunch=0.0, dropped=True, tilt=3, bob=1)], [0, 1], 4, True),
    ("stagger", [marsh_hag(hunch=0.4, staff=(7, -28), feet=((2, 0), (-6, 0)), tilt=-6)], [0], 1, False),
]


def autosprite_only(_):
    """An empty frame, for a sheet drawn only from Autosprite poses (Gloamweaver): every
    animation it names is swapped for the imported frames."""
    blank = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return blank, blank.copy(), {}


GLOAMWEAVER = [
    ("idle", [None, None], [0, 1], 2, True),
    ("walk", [None, None], [0, 1], 5, True),
    ("sweep_tell", [None, None], [0, 1], 6, True),
    ("sweep", [None], [0], 1, False),
    ("pounce_tell", [None, None], [0, 1], 6, True),
    ("pounce", [None], [0], 1, False),
    ("dropped", [None, None], [0, 1], 2, True),
]


# The Shade Knight (art loop pass 1, docs/art/enemy-style-guide.md): PixelLab clips only.
SHADE_KNIGHT = [
    ("idle", [None] * 2, [0, 1], 6, True),
    ("walk", [None] * 2, [0, 1], 8, True),
    ("thrust_tell", [None] * 2, [0, 1], 8, True),
    ("thrust", [None] * 2, [0, 1], 16, False),
    ("cut_tell", [None] * 2, [0, 1], 8, True),
    ("cut", [None] * 2, [0, 1], 16, False),
    ("winded", [None] * 2, [0, 1], 4, True),
    ("stagger", [None] * 2, [0, 1], 6, True),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 10, False),
]


# The Silt Adder (art loop pass 2): PixelLab clips only, drawn centred on its body.
SILT_ADDER = [
    ("float", [None] * 2, [0, 1], 7, True),
    ("coil", [None] * 2, [0, 1], 8, True),
    ("strike", [None] * 2, [0, 1], 8, False),
    ("stagger", [None] * 2, [0, 1], 4, True),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 12, False),
]

# Art loop batch 4 (Carillon, docs/art/enemy-style-guide.md): PixelLab clips only.
THUNDER_BEETLE = [
    ("idle", [None] * 2, [0, 1], 7, True),
    ("walk", [None] * 2, [0, 1], 10, True),
    ("charge", [None] * 2, [0, 1], 10, False),
    ("discharge", [None] * 2, [0, 1], 14, False),
    ("spent", [None] * 2, [0, 1], 8, False),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 14, False),
]

STORM_HARPY = [
    ("hover", [None] * 2, [0, 1], 16, True),
    ("windup", [None] * 2, [0, 1], 8, False),
    ("throw", [None] * 2, [0, 1], 15, False),
    ("recover", [None] * 2, [0, 1], 9, False),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 16, False),
]

SPIRE_SENTINEL = [
    ("idle", [None] * 2, [0, 1], 1, True),
    ("stalk", [None] * 2, [0, 1], 12, True),
    ("raise", [None] * 2, [0, 1], 7, False),
    ("slam", [None] * 2, [0, 1], 15, False),
    ("spent", [None] * 2, [0, 1], 5, False),
    ("stagger", [None] * 2, [0, 1], 6, True),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 14, False),
]


# Art loop pass 4, the High Boughs foes (docs/art/enemy-style-guide.md): PixelLab clips only.
LEAF_MANTIS = [(a, [None] * 2, [0, 1], fps, loop) for a, fps, loop in (
    ("idle", 6, True), ("stalk", 12, True), ("hide", 2, True), ("unfold", 8, True), ("lunge", 14, False),
    ("recover", 5, True), ("stagger", 3, True), ("hurt", 10, False), ("death", 12, False))]
MOTHLING = [(a, [None] * 2, [0, 1], fps, loop) for a, fps, loop in (
    ("fly", 18, True), ("windup", 8, True), ("dive", 10, True), ("hurt", 10, False), ("death", 12, False))]
# The Lantern Ghost (art loop pass 3, docs/art/enemy-style-guide.md): PixelLab clips only.
LANTERN_GHOST = [
    ("idle", [None] * 2, [0, 1], 7, True),
    ("lunge_tell", [None] * 2, [0, 1], 8, True),
    ("lunge", [None] * 2, [0, 1], 12, False),
    ("fade", [None] * 2, [0, 1], 7, False),
    ("hurt", [None] * 2, [0, 1], 10, False),
    ("death", [None] * 2, [0, 1], 12, False),
]


# Art loop pass 6 (Vorrhallow and the Sunken Spring): PixelLab clips only.
def _pixellab_only(names):
    return [(n, [None] * 2, [0, 1], 8, True) for n in names]


CLOCKWORK_HOUND = _pixellab_only(["idle", "trot", "wind", "pounce", "skid", "stagger", "hurt", "death"])
CRYSTAL_DWARF = _pixellab_only(["idle", "walk", "windup", "rooted", "recover", "hurt", "stagger", "death"])
METEOR_SLUG = _pixellab_only(["idle", "crawl", "swell", "recover", "hurt", "stagger", "death"])
SPRING_EEL = _pixellab_only(["swim", "coil", "dart", "slack", "hurt", "stagger", "death"])


def main():
    write_sheet("blinkhop", (40, 32), (20, 30), BLINKHOP, lambda r: r(None))
    write_sheet("hornet", (40, 32), (20, 16), HORNET, lambda r: r(None))
    write_sheet("rot_dwarf", (48, 48), (24, 45), ROT_DWARF, lambda r: r(None))
    write_sheet("gnarlmaw", (64, 64), (32, 32), GNARLMAW, lambda r: r(None))
    write_sheet("sap_spitter", (32, 32), (16, 30), SAP_SPITTER, lambda r: r(None))
    write_sheet("grub_lump", (32, 24), (16, 21), GRUB_LUMP, lambda r: r(None))
    write_sheet("iron_dwarf", (72, 64), (32, 61), IRON_DWARF, lambda r: r(None), density=ID_SCALE)
    write_sheet("gear_bat", (56, 40), (28, 20), GEAR_BAT, lambda r: r(None), density=GB_SCALE)
    write_sheet("minecart_rider", (72, 56), (36, 53), MINECART_RIDER, lambda r: r(None), density=MC_SCALE)
    write_sheet("foreman", (96, 80), (48, 76), FOREMAN, lambda r: r(None), density=FM_SCALE)
    write_sheet("durgan", (128, 88), (60, 84), DURGAN, lambda r: r(None), density=ZD_SCALE)
    write_sheet("bog_puffcap", (40, 40), (20, 38), BOG_PUFFCAP, lambda r: r(None), density=BM_SCALE)
    write_sheet("drowned_dwarf", (72, 64), (32, 61), DROWNED_DWARF, lambda r: r(None), density=DD_SCALE)
    write_sheet("bark_knight", (112, 64), (36, 61), BARK_KNIGHT, lambda r: r(None), density=BK_SCALE)
    write_sheet("seed_bomber", (56, 44), (28, 22), SEED_BOMBER, lambda r: r(None), density=SB_SCALE)
    write_sheet("marsh_hag", (56, 52), (24, 49), MARSH_HAG, lambda r: r(None), density=MH_SCALE)
    write_sheet("gloamweaver", (104, 76), (52, 74), GLOAMWEAVER, autosprite_only, density=2)
    write_sheet("shade_knight", (80, 56), (40, 53), SHADE_KNIGHT, autosprite_only, density=2)
    write_sheet("silt_adder", (64, 72), (32, 36), SILT_ADDER, autosprite_only, density=2)
    write_sheet("thunder_beetle", (64, 44), (32, 42), THUNDER_BEETLE, autosprite_only, density=2)
    write_sheet("storm_harpy", (72, 64), (36, 32), STORM_HARPY, autosprite_only, density=2)
    write_sheet("spire_sentinel", (96, 64), (44, 62), SPIRE_SENTINEL, autosprite_only, density=2)
    write_sheet("leaf_mantis", (96, 56), (48, 53), LEAF_MANTIS, autosprite_only, density=2)
    write_sheet("mothling", (40, 36), (20, 18), MOTHLING, autosprite_only, density=2)
    write_sheet("clockwork_hound", (72, 48), (36, 45), CLOCKWORK_HOUND, autosprite_only, density=2)
    write_sheet("crystal_dwarf", (72, 56), (36, 53), CRYSTAL_DWARF, autosprite_only, density=2)
    write_sheet("meteor_slug", (64, 44), (32, 41), METEOR_SLUG, autosprite_only, density=2)
    write_sheet("spring_eel", (56, 40), (28, 20), SPRING_EEL, autosprite_only, density=2)
    write_sheet("lantern_ghost", (80, 64), (40, 32), LANTERN_GHOST, autosprite_only, density=2)
    npcs = json.loads((ROOT / "data" / "npcs.json").read_text())
    for npc_id, info in npcs.items():
        look = info.get("look", {})
        frames = [npc(look, 0, 0), npc(look, 0, 0.5), npc(look, 1, 1), npc(look, 0, 0.5)]
        write_sheet("npc_" + npc_id, (32, 48), (16, 46), [("idle", frames, [0, 1, 2, 3], 3, True)], lambda r: r(None))


if __name__ == "__main__":
    main()
