#!/usr/bin/env python3
"""Generates the player sprite sheet (design bible 12.4 and 13.3).

The elf is posed with a tiny 2D rig: each frame gives the hip, the feet, the
hands and the head, and two-bone IK places the knees and elbows. Every part is
rasterized at 1x into its own mask, shaded with a top-left key light (highlight,
base, shadow from one master-palette ramp), separated from the parts behind it
by a darker line of its own ramp, and the whole figure gets a full outline.
No anti-aliasing, no dithering: every pixel is a master-palette color.

The blade, the shield and the potion are drawn in-game from each frame's hand
position (so the four blades share these animations), and the scarf hangs
from each frame's neck point.

Writes:
  assets/sprites/player.png       the sheet: one row per animation, 64x64 cells
  assets/sprites/player_mask.png  the same frames as a flat white silhouette
                                  (afterimages and hit flashes)
  assets/sprites/player.json      animations: row, frame count, playback
                                  sequence, fps, loop; per-frame hand, blade
                                  angle and neck point, relative to the feet

Usage: python3 tools/art/spritegen.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelrig  # noqa: E402
from pixelrig import PAL, Canvas, ik, mat, reach, write_sheet  # noqa: E402

CELL = 64
# The feet sit on this point of each cell (the node's origin in game).
ORIGIN = (32, 61)

# (highlight, base, shadow, separating line)
TUNIC = mat("leaf", 3, 2, 1, 0)
TUNIC_BACK = mat("leaf", 2, 1, 1, 0)
TROUSERS = mat("bark", 3, 2, 1, 0)
TROUSERS_BACK = mat("bark", 2, 1, 1, 0)
BOOTS = mat("bark", 2, 1, 0, 0)
BOOTS_BACK = mat("bark", 1, 1, 0, 0)
SKIN = mat("bark", 7, 6, 5, 3)
SKIN_BACK = mat("bark", 6, 5, 4, 3)
GLOVE = mat("bark", 4, 3, 2, 1)
HAIR = mat("gold", 6, 5, 4, 2)
EYE = PAL["night-1"]
BELT = PAL["bark-1"]
BUCKLE = PAL["gold-4"]

THIGH, SHIN = 8.0, 8.5
UPPER_ARM, FOREARM = 6.0, 6.0


# --- The rig ------------------------------------------------------------------

def pose(hip=(0, -18), lean=0, bob=0, feet=((3, 0), (-3, 0)), knees=(1, 1),
         hands=((3, -19), (-3, -19)), elbows=(-1, -1), head=(0, 0), blade=None,
         fist=False):
    """One frame. Points are relative to the feet, facing right.
    feet/hands/knees/elbows are (front, back). blade is the angle in degrees of
    the sword held in the front hand (0 = forward, 90 = down), or None."""
    return dict(hip=hip, lean=lean, bob=bob, feet=feet, knees=knees, hands=hands,
                elbows=elbows, head=head, blade=blade, fist=fist)


def render(f):
    cv = Canvas(CELL, CELL, ORIGIN)
    hx, hy = f["hip"]
    sx, sy = hx + f["lean"], hy - 12 + f["bob"]          # shoulder line
    neck = (sx, sy - 1)
    head = (sx + 1 + f["head"][0], sy - 6 + f["head"][1])
    shoulder_f = (sx + 1, sy + 2)
    shoulder_b = (sx - 2, sy + 2)
    hip_f = (hx + 1.5, hy)
    hip_b = (hx - 1.5, hy)

    def leg(hip, foot, bend, trousers, boots):
        foot = reach(hip, foot, THIGH + SHIN - 0.2)
        knee = ik(hip, foot, THIGH, SHIN, bend)
        m = cv.capsule(hip, knee, 2.4) | cv.capsule(knee, foot, 2.0)
        cv.part(m, trousers)
        boot = cv.capsule((foot[0] - 1, foot[1] - 3), (foot[0] + 2.5, foot[1] - 2), 2.1) | cv.capsule(
            (foot[0] - 0.5, foot[1] - 5), (foot[0] - 0.5, foot[1] - 2), 2.0)
        cv.part(boot, boots)

    def arm(shoulder, hand, bend, sleeve, skin, glove=False):
        hand = reach(shoulder, hand, UPPER_ARM + FOREARM - 0.2)
        elbow = ik(shoulder, hand, UPPER_ARM, FOREARM, bend)
        cv.part(cv.capsule(shoulder, elbow, 1.9), sleeve)
        cv.part(cv.capsule(elbow, hand, 1.5), skin)
        cv.part(cv.ellipse(hand, 1.9, 1.9), GLOVE if glove else skin)
        return hand

    # Back limbs first, one shade darker.
    arm(shoulder_b, f["hands"][1], f["elbows"][1], TUNIC_BACK, SKIN_BACK)
    leg(hip_b, f["feet"][1], f["knees"][1], TROUSERS_BACK, BOOTS_BACK)
    # Torso: tunic from shoulders to a hem below the hips, then the belt.
    torso = cv.polygon([(sx - 4.5, sy), (sx + 4.5, sy), (hx + 5, hy + 1), (hx + 5.5, hy + 4),
                        (hx - 5.5, hy + 4), (hx - 5, hy + 1)]) | cv.ellipse((sx, sy + 1.5), 5.0, 2.5)
    leg(hip_f, f["feet"][0], f["knees"][0], TROUSERS, BOOTS)
    cv.part(torso, TUNIC, deep=True)
    for x in range(-5, 5):
        bx = hx + x + 0.5
        cv.pixel((bx + (hx - hx), hy - 1 + 0.5), BELT)
    cv.pixel((hx + 2.5, hy - 0.5), BUCKLE)
    # Head: face, hair over the top and back, the long elf ear, one eye.
    hcx, hcy = head
    cv.part(cv.ellipse(head, 4.6, 5.0), SKIN)
    hair = cv.ellipse((hcx - 1.0, hcy - 2.0), 5.2, 4.0) | cv.capsule((hcx - 3.5, hcy - 2), (hcx - 4.5, hcy + 4.5), 1.8)
    face = cv.right_of(hcx - 0.5) & cv.below(hcy - 2.0)
    cv.part(hair & ~face, HAIR)
    cv.part(cv.capsule((hcx - 2.0, hcy + 0.5), (hcx - 5.5, hcy - 2.0), 0.9), SKIN)
    cv.pixel((hcx + 2.0, hcy - 0.5), EYE)
    cv.pixel((hcx + 2.0, hcy + 0.5), EYE)
    # Front arm last; a gloved fist when it holds something.
    hand = arm(shoulder_f, f["hands"][0], f["elbows"][0], TUNIC, SKIN, glove=f["fist"])
    sheet, mask = cv.finish()
    meta = {"hand": [round(hand[0], 1), round(hand[1], 1)],
            "neck": [round(neck[0], 1), round(neck[1], 1)]}
    if f["blade"] is not None:
        meta["blade"] = f["blade"]
    return sheet, mask, meta


# --- Animations ---------------------------------------------------------------

def idle():
    frames = []
    for bob in (0, 0, 1, 1):
        frames.append(pose(bob=bob, hands=((3, -19 + bob), (-3, -19 + bob))))
    return frames


def run():
    frames = []
    for i in range(8):
        t = i / 8 * math.tau
        fx = 6.0 * math.cos(t)
        lift_f = max(0.0, 4.5 * math.sin(t))
        lift_b = max(0.0, -4.5 * math.sin(t))
        hip_y = -18 + (1 if i % 4 == 0 else 0)
        frames.append(pose(
            hip=(0, hip_y), lean=2,
            feet=((fx, -lift_f), (-fx, -lift_b)),
            hands=((2 - 5.0 * math.cos(t), -20 + abs(math.cos(t))), (-1 + 5.0 * math.cos(t), -20)),
            elbows=(-1, -1)))
    return frames


def rise():
    return [pose(hip=(0, -19), lean=1, feet=((3, -6), (-3, -2)), hands=((5, -27), (-5, -24)), elbows=(-1, -1))]


def apex():
    return [pose(hip=(0, -18), lean=0, feet=((3, -4), (-2, -3)), hands=((7, -25), (-6, -25)), elbows=(-1, 1))]


def fall():
    return [pose(hip=(0, -18), lean=-1, feet=((3, 0), (-2, -2)), hands=((6, -31), (-5, -30)), elbows=(-1, 1)),
            pose(hip=(0, -18), lean=-1, feet=((2, 0), (-3, -1)), hands=((7, -30), (-6, -31)), elbows=(-1, 1))]


def dash():
    return [pose(hip=(-1, -16), lean=5, feet=((6, -2), (-9, -3)), knees=(1, 1), hands=((-4, -21), (-8, -22)),
                 elbows=(-1, -1), head=(1, 0)),
            pose(hip=(-1, -16), lean=5, feet=((7, -1), (-10, -4)), knees=(1, 1), hands=((-5, -22), (-9, -23)),
                 elbows=(-1, -1), head=(1, 0))]


def wall():
    # Facing away from the wall, which is behind (-x).
    return [pose(hip=(-1, -18), lean=-1, feet=((4, -3), (-5, -4)), knees=(1, 1), hands=((5, -22), (-6, -32)),
                 elbows=(-1, -1)),
            pose(hip=(-1, -18), lean=-1, feet=((4, -2), (-5, -5)), knees=(1, 1), hands=((5, -21), (-6, -33)),
                 elbows=(-1, -1))]


def slash1():
    # An overhand cut: the blade comes over and down in front.
    lunge = dict(hip=(1, -17), feet=((6, 0), (-5, 0)), knees=(1, 1))
    return [pose(lean=3, hands=((9, -26), (-5, -21)), blade=-20, fist=True, **lunge),
            pose(lean=3, hands=((9, -22), (-5, -21)), blade=25, fist=True, **lunge),
            pose(lean=2, hands=((6, -19), (-4, -20)), blade=65, fist=True, **lunge)]


def slash2():
    # The backhand: low to high.
    lunge = dict(hip=(1, -17), feet=((5, 0), (-5, 0)), knees=(1, 1))
    return [pose(lean=2, hands=((9, -21), (-5, -20)), blade=15, fist=True, **lunge),
            pose(lean=2, hands=((8, -27), (-5, -21)), blade=-35, fist=True, **lunge),
            pose(lean=1, hands=((5, -30), (-4, -21)), blade=-70, fist=True, elbows=(1, -1), **lunge)]


def slash3():
    # The heavy finisher: a deep lunge and a flat thrust-cut.
    lunge = dict(hip=(2, -15), feet=((8, 0), (-7, 0)), knees=(1, 1))
    return [pose(lean=5, hands=((11, -22), (-7, -24)), blade=-5, fist=True, head=(1, 0), **lunge),
            pose(lean=5, hands=((11, -20), (-7, -24)), blade=20, fist=True, head=(1, 0), **lunge),
            pose(lean=3, hands=((8, -18), (-6, -22)), blade=55, fist=True, **lunge)]


def slash_up():
    base = dict(hip=(0, -18), feet=((3, 0), (-3, 0)))
    return [pose(lean=0, hands=((5, -33), (-4, -21)), blade=-55, fist=True, **base),
            pose(lean=0, hands=((2, -36), (-4, -21)), blade=-95, fist=True, **base),
            pose(lean=-1, hands=((-1, -34), (-4, -21)), blade=-130, fist=True, elbows=(1, -1), **base)]


def strike_down():
    tuck = dict(hip=(0, -19), feet=((3, -6), (-3, -4)), knees=(1, 1))
    return [pose(lean=1, hands=((3, -16), (-5, -24)), blade=80, fist=True, **tuck),
            pose(lean=1, hands=((2, -13), (-5, -25)), blade=90, fist=True, **tuck)]


def block():
    return [pose(hip=(-1, -17), lean=-1, feet=((4, 0), (-5, 0)), hands=((6, -25), (-4, -20)), elbows=(-1, -1),
                 fist=True)]


def drink():
    return [pose(lean=-1, hands=((4, -33), (-3, -19)), elbows=(1, -1), head=(-1, -1), fist=True),
            pose(lean=-1, hands=((4, -34), (-3, -19)), elbows=(1, -1), head=(-1, -1), fist=True)]


def cast():
    return [pose(hip=(0, -18), lean=1, feet=((4, 0), (-4, 0)), hands=((8, -27), (-4, -21)), elbows=(-1, -1)),
            pose(hip=(1, -18), lean=2, feet=((5, 0), (-4, 0)), hands=((11, -26), (-5, -22)), elbows=(-1, -1))]


def hurt():
    return [pose(hip=(-1, -18), lean=-3, feet=((3, -1), (-4, 0)), hands=((5, -31), (-7, -29)), elbows=(1, 1),
                 head=(-1, 0))]


# name: (frames, playback sequence, fps, loop)
ANIMATIONS = [
    ("idle", idle, [0, 1, 2, 3], 5, True),
    ("run", run, list(range(8)), 14, True),
    ("rise", rise, [0], 1, False),
    ("apex", apex, [0], 1, False),
    ("fall", fall, [0, 1], 8, True),
    ("dash", dash, [0, 1], 16, False),
    ("wall", wall, [0, 1], 6, True),
    # Attacks: the strike shows at once (the hitbox is live on the press), the
    # follow-through, then recovery frames held so the swing reads.
    ("slash1", slash1, [0, 1, 2, 2], 20, False),
    ("slash2", slash2, [0, 1, 2, 2], 20, False),
    ("slash3", slash3, [0, 0, 1, 2, 2, 2], 20, False),
    ("slash_up", slash_up, [0, 1, 2, 2], 20, False),
    ("strike_down", strike_down, [0, 1], 14, False),
    ("block", block, [0], 1, False),
    ("drink", drink, [0, 1], 4, True),
    ("cast", cast, [0, 1, 1, 1], 16, False),
    ("hurt", hurt, [0], 1, False),
    # Code fallback only: the Autosprite clip (art/autosprite/manifest.json) is the real one.
    ("death", hurt, [0], 1, False),
]


# The hero's body sets (paper doll, design bible 13.4): one sheet per armor, each holding only
# the clips imported for it (art/autosprite/manifest.json); the game falls back to "player".
BODY_SETS = ["hero_base", "hero_leather", "hero_riveted", "hero_plate", "hero_battle", "hero_battle_helm"]
# Each set's attacks with the other blades (design bible 13.5), e.g. hero_plate_long_sword.
BLADES = ["long_sword", "broad_sword", "severance"]
SHIELDS = ["small_shield", "large_shield", "magic_shield"]
ARMOR_SHEETS = BODY_SETS + [f"{s}_{b}" for s in BODY_SETS for b in BLADES] + [f"{s}_{h}" for s in BODY_SETS for h in SHIELDS]
# Their cells run 20 px deeper under the feet than the code rig's, for the Delver's Pick's head on a pogo.
ARMOR_CELL = (CELL, CELL + 20)
# The 128 px hero (one body, design bible 5.6 and 12.1): about 59 px tall, so a cell of its own with
# room over the head for an up-slash and to the sides for the cloak and a lunge.
HERO_SHEET = "hero128"
HERO_CELL = (112, 96)
HERO_ORIGIN = (56, 84)


def main():
    anims = [(name, fn(), seq, fps, loop) for name, fn, seq, fps, loop in ANIMATIONS]
    write_sheet("player", (CELL, CELL), ORIGIN, anims, render)
    manifest = pixelrig.autosprite_import.load_manifest()
    for sheet in ARMOR_SHEETS:
        clips = manifest.get(sheet, {}).get("animations", {})
        if clips:
            write_sheet(sheet, ARMOR_CELL, ORIGIN, [a for a in anims if a[0] in clips], render)
    clips = manifest.get(HERO_SHEET, {}).get("animations", {})
    if clips:
        write_sheet(HERO_SHEET, HERO_CELL, HERO_ORIGIN, [a for a in anims if a[0] in clips], render)


if __name__ == "__main__":
    main()
