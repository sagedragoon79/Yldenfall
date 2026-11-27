"""One value key for the cast of foes (design bible 12.149).

The pass 670 grade saw the foes "in three styles": rendered bees and snake, a
flat hero, and a third set in the beetle and the purple slug. Measured on the
sheets, the foes were painted in different keys: the Thunder Beetle's body sits
at a median value of 0.29 and a saturation of 0.66, the Hornet's at 0.47 and
0.40. Every foe is drawn through FoeLight's material, so each gets a key there:
a gamma on its painted value that brings its median to the cast's, and a scale
on its saturation that brings its mean to the cast's (inside CLAMP). A gamma
leaves black and full value where they are, so the outline stays an outline
and a light stays a light.

Run from the repository root: python tools/art/cast_key.py
It prints the `KEYS` table for scripts/enemies/foe_light.gd. The test
`test_cast_key_matches_the_sheets` reads the sheets the same way and fails when
the table and the sheets disagree, so rerun this after a foe's sheet changes.
"""
import colorsys
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# The shared key: the median value and mean saturation of a foe's body, the
# cast's own medians as painted (pass 672: 0.43 and 0.42).
TARGET_V = 0.43
TARGET_S = 0.43
# How far a key may move a sheet: a gamma and a saturation scale.
GAMMA = (0.75, 1.3)
SAT = (0.8, 1.15)
# A sheet already this close to the key gets no entry.
SLACK_V = 0.05
SLACK_S = 0.08
# Foes kept off the key: the Lantern Ghost is meant to be faint (bible 7), the
# Crystal Dwarf is a light (a FoeGlow, 12.52), the Spring Eel is seen
# through water, and the Leaf Mantis stands off the Boughs' green woods by its
# saturation (12.112).
EXEMPT = ("lantern_ghost", "crystal_dwarf", "spring_eel", "leaf_mantis")
# What counts as body: opaque, not the outline (value under OUTLINE_V).
OUTLINE_V = 0.12
STEP = 2


def foes():
    out = []
    d = os.path.join(ROOT, "scripts", "enemies")
    for f in sorted(os.listdir(d)):
        if not f.endswith(".gd") or f == "enemy.gd":
            continue
        n = f[:-3]
        src = open(os.path.join(d, f), encoding="utf-8").read()
        if n in EXEMPT:
            continue
        if "extends Enemy" in src and os.path.exists(os.path.join(ROOT, "assets", "sprites", n + ".json")):
            out.append(n)
    return out


def body_stats(name):
    im = np.asarray(Image.open(os.path.join(ROOT, "assets", "sprites", name + ".png")).convert("RGBA"))
    px = im[::STEP, ::STEP].reshape(-1, 4)
    px = px[px[:, 3] > 128][:, :3].astype(float) / 255.0
    v = px.max(axis=1)
    mn = px.min(axis=1)
    body = v >= OUTLINE_V
    s = np.where(v > 1e-5, (v - mn) / np.maximum(v, 1e-5), 0.0)
    return float(np.median(v[body])), float(s[body].mean())


def key_for(name):
    med, sat = body_stats(name)
    if abs(med - TARGET_V) <= SLACK_V and abs(sat - TARGET_S) <= SLACK_S:
        return None
    g = 1.0
    if abs(med - TARGET_V) > SLACK_V:
        g = min(max(math.log(TARGET_V) / math.log(med), GAMMA[0]), GAMMA[1])
    k = 1.0
    if abs(sat - TARGET_S) > SLACK_S and sat > 0:
        k = min(max(TARGET_S / sat, SAT[0]), SAT[1])
    return round(g, 2), round(k, 2), med, sat


def main():
    print("const KEYS := {")
    for n in foes():
        k = key_for(n)
        if k is None:
            continue
        print('\t"%s": [%.2f, %.2f],  # value %.2f, saturation %.2f as painted' % (n, k[0], k[1], k[2], k[3]))
    print("}")


if __name__ == "__main__":
    main()
