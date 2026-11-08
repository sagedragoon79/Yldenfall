#!/usr/bin/env python3
"""Gives every passage four tiles of headroom for the 2x hero (pass 508, Sean 2026-11-07).

The 128 px hero is about 60 world px tall, so his body needs four clear tiles where the old one
needed three. Every room was built for three: all 198 side doors and about 370 other standing spots
had exactly three tiles over the feet. This finds each standing spot with only three (the gates
counted open, since a passage matters once its gate has opened) and makes room, one run of
neighbouring spots at a time:

- a thick ceiling (two solid rows or more) is carved one row higher;
- a thin ceiling (a slab with air over it) over a thick floor: the floor is lowered one row and
  whatever stood in the column drops with it;
- a thin ceiling over a thin floor with air under it (a slab or one-way plank): the floor drops
  one row, with whatever stood on it;
- otherwise the ceiling slab is raised one row, with anything standing on it.

A door, gate, fake wall or ladder that filled the column's three rows is extended to fill four, so
a door opening stays one door and a gate still seals its passage. Key doors grow in code
(`KeyDoor.SIZE`). The room-by-room redesign (zone by zone, with the 32 px tiles) replaces these
layouts later; this keeps today's rooms playable for the new hero meanwhile. Rerunning it changes
nothing once every passage has four tiles. The gym is generated: edit tools/levels/gen_gym.py.

Usage: python3 tools/levels/raise_passages.py [--dry-run]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEVELS = ROOT / "levels"
HARD = set("#/u\\")
# Opened by an ability; counted as open when looking for passages (reach.gd `solid`).
GATES = set("CRQ|YZk+w[gJf")
# Column features extended to the new top row when they filled the old three.
COLUMN = GATES | set("123456789%\"")
SUPPORT = set("-i\"")
HAZARD = set("^o")
BODY = 3  # the old body, in rows


def hard(c):
    return c in HARD


# Header lines that place something at a tile: "key: x, y, ...".
PLACED = ("sign", "npc", "prop", "chest", "lock")


class Grid:
    def __init__(self, rows, items=()):
        self.rows = [list(r) for r in rows]
        # Header-placed things, [x, y] lists that follow their column when it shifts.
        self.items = list(items)

    def shift(self, x, y0, y1, d):
        """Header things in column x, rows y0..y1, move d rows (the grid is moved by the caller)."""
        for it in self.items:
            if it[0] == x and y0 <= it[1] <= y1:
                it[1] += d

    def ch(self, x, y):
        if y < 0 or y >= len(self.rows) or x < 0 or x >= len(self.rows[y]):
            return "#"
        return self.rows[y][x]

    def put(self, x, y, c):
        self.rows[y][x] = c

    def text(self):
        return "\n".join("".join(r) for r in self.rows)


def low_spots(g):
    """Standing spots with exactly BODY clear rows over the floor and a hard tile above them."""
    out = []
    for y in range(len(g.rows)):
        for x in range(len(g.rows[y])):
            if any(hard(g.ch(x, y - k)) for k in range(BODY)):
                continue
            below = g.ch(x, y + 1)
            # Falling water bears you down; only its footholds hold, and never under a ceiling.
            # A closed gate holds you up, but not from inside its own column.
            # Key doors and the Sky Key gate stand on one cell and are drawn tall: never a floor.
            gate_floor = below in GATES and below not in "fJg" and g.ch(x, y) != below
            if not (hard(below) or below in SUPPORT or gate_floor):
                continue
            # Over the top edge is a ceiling door, not a ceiling.
            if y - BODY < 0 or g.ch(x, y) in HAZARD or not hard(g.ch(x, y - BODY)):
                continue
            out.append((x, y))
    return out


def runs(spots):
    """Groups spots on the same row whose columns touch."""
    spots = sorted(spots, key=lambda p: (p[1], p[0]))
    out, cur = [], []
    for p in spots:
        if cur and (p[1] != cur[-1][1] or p[0] != cur[-1][0] + 1):
            out.append(cur)
            cur = []
        cur.append(p)
    if cur:
        out.append(cur)
    return out


def column_feature(g, x, y):
    """The door, gate or other column feature filling rows y-2..y of column x, if one does."""
    top = g.ch(x, y - (BODY - 1))
    if top in COLUMN and all(g.ch(x, y - k) == top for k in range(BODY)):
        return top
    return None


def can_carve(g, x, y):
    return y - BODY - 1 >= 0 and hard(g.ch(x, y - BODY - 1))


def can_lower(g, x, y):
    return hard(g.ch(x, y + 1)) and hard(g.ch(x, y + 2))


def can_sink(g, x, y):
    floor = g.ch(x, y + 1)
    return (floor in "-i" or hard(floor)) and g.ch(x, y + 2) == "."


def can_lift(g, x, y):
    top = y - BODY - 1  # the cell over the slab, where the slab goes
    if top < 1 or hard(g.ch(x, top)):
        return False
    over = g.ch(x, top)
    return over == "." or g.ch(x, top - 1) == "."


def carve(g, x, y):
    g.put(x, y - BODY, column_feature(g, x, y) or ".")


def lower(g, x, y):
    feature = column_feature(g, x, y)
    g.shift(x, y - BODY + 1, y, 1)
    for yy in range(y + 1, y - BODY + 1, -1):
        g.put(x, yy, g.ch(x, yy - 1))
    g.put(x, y - BODY + 1, feature or ".")


def sink(g, x, y):
    """A thin floor (a slab or one-way plank with air under it) drops a row, with whatever stood
    on it."""
    feature = column_feature(g, x, y)
    g.shift(x, y - BODY + 1, y + 1, 1)
    for yy in range(y + 2, y - BODY + 1, -1):
        g.put(x, yy, g.ch(x, yy - 1))
    g.put(x, y - BODY + 1, feature or ".")


def lift(g, x, y):
    slab, over = y - BODY, y - BODY - 1
    g.shift(x, over, over, -1)
    if g.ch(x, over) != ".":
        g.put(x, over - 1, g.ch(x, over))
    g.put(x, over, g.ch(x, slab))
    g.put(x, slab, column_feature(g, x, y) or ".")


def standable(g, x, y):
    if any(hard(g.ch(x, y - k)) for k in range(BODY)):
        return False
    below = g.ch(x, y + 1)
    return hard(below) or below in SUPPORT


def entries(g, xs, y, can):
    """The columns just outside a run that you walk in from at the same height. A lowered
    floor drops them too, so the step down comes before the doorway's lintel, not under it."""
    out = []
    for x in (xs[0] - 1, xs[-1] + 1):
        if standable(g, x, y) and can(g, x, y) and not hard(g.ch(x, y - BODY)):
            out.append(x)
    return out


def whole_plank(g, xs, y):
    """A sinking plank sinks end to end, not just under the low spots."""
    plank = g.ch(xs[0], y + 1)
    lo, hi = xs[0], xs[-1]
    while g.ch(lo - 1, y + 1) == plank and can_sink(g, lo - 1, y):
        lo -= 1
    while g.ch(hi + 1, y + 1) == plank and can_sink(g, hi + 1, y):
        hi += 1
    return list(range(lo, hi + 1))


def edges(g, xs, y):
    """The columns just past a carved run that the body moves through at the same height
    (stepping off a ledge, or in from a gap) under the same old ceiling: carved too."""
    out = []
    for x in (xs[0] - 1, xs[-1] + 1):
        if not any(hard(g.ch(x, y - k)) for k in range(BODY)) and hard(g.ch(x, y - BODY)) and can_carve(g, x, y):
            out.append(x)
    return out


# Jumps whose arc now clips a ceiling the body passes under but never stands below (found by
# tests/test_reachability.gd and tools/levels/reach_map.tscn): room -> [(row, x0, x1)], carved.
HAND = {
    "heartwood/grub_burrows": [(1, 40, 46)],
    "heartwood/hollow_knot": [(5, 14, 14), (5, 21, 27)],
    "tower/gear_pit": [(3, 24, 31)],
    "tower/gear_shaft": [(1, 13, 17)],
    "tower/winch_hall": [(4, 42, 44), (4, 56, 59)],
    "haar/feather_hollow": [(3, 22, 27)],
    "vorrhallow/kings_kennels": [(3, 30, 35)],
    "trials/walls": [(1, 23, 30)],
    "trials/falling": [(55, 18, 24)],
}
# Cells set by hand after the raise: room -> [(x, y, char)]. The Ore Vault's bump of slope
# and stone under its drop-in would have caught a four-tile body at the lintel.
SET = {
    "tower/ore_vault": [(10, 20, "."), (11, 20, ".")],
}


def by_hand(rid, g):
    done = []
    for row, x0, x1 in HAND.get(rid, []):
        for x in range(x0, x1 + 1):
            if hard(g.ch(x, row)) and hard(g.ch(x, row - 1)):
                g.put(x, row, ".")
                done.append(("hand", row, [x]))
    for x, y, c in SET.get(rid, []):
        if g.ch(x, y) != c:
            g.put(x, y, c)
            done.append(("set", y, [x]))
    return done


# Runs that take a fix other than the first that fits: room -> {feet row: fix}. Burrow Drop's high
# plank sinks a row: carving its ceiling left a slot one tile tall under the top edge, and a foe's
# spoils wedged in its corner (tests/test_soak.gd).
PREFER = {
    "heartwood/burrow_drop": {4: "sink"},
}
FIXES = (("carve", can_carve, carve), ("lower", can_lower, lower), ("sink", can_sink, sink), ("lift", can_lift, lift))


def raise_room(g, rid=""):
    """Raises every low run once; returns [(op, row, columns)] for the report."""
    done = []
    for run in runs(low_spots(g)):
        y = run[0][1]
        # An earlier fix this round may have settled some of these (a plank sinks end to end).
        still = set(low_spots(g))
        xs = [p[0] for p in run if p in still]
        if not xs:
            continue
        want = PREFER.get(rid, {}).get(y)
        order = sorted(FIXES, key=lambda f: f[0] != want)
        for name, can, op in order:
            if all(can(g, x, y) for x in xs):
                if name == "sink" and g.ch(xs[0], y + 1) in "-i":
                    xs = whole_plank(g, xs, y)
                if name in ("lower", "sink"):
                    xs = sorted(set(xs + entries(g, xs, y, can)))
                elif name == "carve":
                    xs = sorted(xs + edges(g, xs, y))
                for x in xs:
                    op(g, x, y)
                done.append((name, y, xs))
                break
        else:
            # Mixed run: each column takes the first fix it allows.
            for x in xs:
                for name, can, op in (("carve", can_carve, carve), ("lower", can_lower, lower), ("sink", can_sink, sink), ("lift", can_lift, lift)):
                    if can(g, x, y):
                        op(g, x, y)
                        done.append((name, y, [x]))
                        break
                else:
                    done.append(("STUCK", y, [x]))
    return done


def main():
    dry = "--dry-run" in sys.argv
    total = stuck = 0
    for f in sorted(LEVELS.glob("*/*.room")):
        if f.parent.name == "gym":
            continue
        text = f.read_text(encoding="utf-8")
        head, sep, grid = text.partition("\n---\n")
        lines = grid.split("\n")
        n = len([r for r in lines if r])
        hl = head.split("\n")
        items, where = [], {}
        for i, line in enumerate(hl):
            key, _, rest = line.partition(":")
            if key in PLACED:
                parts = [q.strip() for q in rest.split(",")]
                items.append([int(parts[0]), int(parts[1])])
                where[i] = (parts, items[-1])
        g = Grid(lines[:n], items)
        rid = f"{f.parent.name}/{f.stem}"
        report = by_hand(rid, g)
        for _ in range(10):  # a fix can leave a new low spot beside it
            step = raise_room(g, rid)
            if not step or all(op == "STUCK" for op, _, _ in step):
                report += step
                break
            report += step
        if not report:
            continue
        for op, y, xs in report:
            total += len(xs)
            stuck += len(xs) if op == "STUCK" else 0
            print(f"{rid}: {op} row {y} columns {xs[0]}-{xs[-1]}")
        for i, (parts, it) in where.items():
            if [int(parts[0]), int(parts[1])] != it:
                key = hl[i].partition(":")[0]
                hl[i] = f"{key}: " + ", ".join([str(it[0]), str(it[1])] + parts[2:])
                print(f"{rid}: moved {key} to {it[0]}, {it[1]}")
        # A hidden room's cover grows over any row its pocket gained, above or below.
        before = Grid(lines[:n])
        opened = lambda x, y: hard(before.ch(x, y)) and not hard(g.ch(x, y))
        for i, line in enumerate(hl):
            if line.startswith("secret:"):
                q = [int(v) for v in line.partition(":")[2].split(",")]
                r = list(q)
                if any(opened(x, r[1] - 1) for x in range(r[0], r[2] + 1)):
                    r[1] -= 1
                if any(opened(x, r[3] + 1) for x in range(r[0], r[2] + 1)):
                    r[3] += 1
                if r != q:
                    hl[i] = "secret: " + ", ".join(str(v) for v in r)
                    print(f"{rid}: secret {q} grew to {r}")
        head = "\n".join(hl)
        if not dry:
            # Bytes, so the rooms keep their LF line ends on Windows too.
            f.write_bytes((head + sep + g.text() + "\n" + "\n".join(lines[n:]).lstrip("\n")).encode("utf-8"))
    print(f"{total} spots raised, {stuck} stuck")
    return 1 if stuck else 0


if __name__ == "__main__":
    sys.exit(main())
