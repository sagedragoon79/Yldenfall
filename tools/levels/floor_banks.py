"""Raises a bank in a room whose floor is one flat line (design bible 12.150).

A room's lowest floor that runs flat from wall to wall reads as a box with a line drawn across
it. This finds such a floor and raises one bank on it: a mound two tiles high (one where the
headroom is short) with a 45-degree slope at each end (`/` and `\\`), so the floor rises and
falls once across the room. The bank sits off the room's middle, at least three tiles from a wall,
a door or a pit, and clear of every sign, prop, person, chest and lock in the header and of
anything in the grid on the floor (foes, pickups). Over its whole width, and a tile each side,
four rows above its top are plain air (`.`), so no ledge or foe comes within a hero's height of it.

Boss arenas (`boss:`) are left flat, since their fights are tuned on that floor; so are rooms
with standing water (`tide:`), whose wading reads the floor's depth, and towns (a `house` or a
`shop_` prop), whose street runs level under its buildings.

Usage: python3 tools/levels/floor_banks.py ROOM_ID [ROOM_ID ...] [--all] [--dry-run]
  ROOM_ID is zone/room (levels/zone/room.room). --all takes every room whose floor is flat.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Cells the floor profile counts as ground (the reachability checker's solids).
SOLID = set("#/\\`'CRZkw[J")
FLAT = 0.9          # a floor this much one height is "one flat line" (the test's bound)
CLEAR = 4           # plain air over a bank's top: the hero is 2.5 tiles tall
MARGIN = 3          # tiles from a wall, door or pit
HEADER_KEYS = ("sign", "prop", "npc", "chest", "lock", "label")


def parse(path):
    text = path.read_text(encoding="utf-8")
    head, sep, grid = text.partition("\n---\n")
    return head, grid


def floor_profile(rows):
    """For each inner column, the row of the lowest floor's top (ground under air), or None."""
    h = len(rows)
    out = []
    for x in range(1, len(rows[0]) - 1):
        fy = None
        for y in range(h - 1, 0, -1):
            if rows[y][x] in SOLID and rows[y - 1][x] not in SOLID:
                fy = y
                break
        out.append(fy)
    return out


def flat_run(rows):
    """(fraction of the inner width, floor row, first x, last x) of the longest flat stretch."""
    prof = floor_profile(rows)
    best = (0, None, 0, 0)
    i = 0
    while i < len(prof):
        j = i
        while j + 1 < len(prof) and prof[j + 1] == prof[i] and prof[i] is not None:
            j += 1
        if prof[i] is not None and j - i + 1 > best[0]:
            best = (j - i + 1, prof[i], i + 1, j + 1)
        i = j + 1
    return best[0] / max(1, len(prof)), best[1], best[2], best[3]


def header_spots(head):
    """(x, y) of each sign, prop, person, chest, lock and label, and the boxes of bare, grate and secret."""
    spots, boxes = [], []
    for line in head.splitlines():
        k, _, v = line.partition(":")
        parts = [p.strip() for p in v.split(",")]
        try:
            if k in HEADER_KEYS:
                spots.append((int(parts[0]), int(parts[1])))
            elif k in ("bare", "grate", "secret"):
                boxes.append(tuple(int(p) for p in parts[:4]))
        except (ValueError, IndexError):
            pass
    return spots, boxes


def skipped(head):
    """Boss arenas, rooms with standing water and towns keep a level floor."""
    keys = {line.partition(":")[0].strip() for line in head.splitlines()}
    props = [line.rpartition(",")[2].strip() for line in head.splitlines() if line.startswith("prop:")]
    return "boss" in keys or "tide" in keys or any(p == "house" or p.startswith("shop_") for p in props)


def bank_cells(x0, x1, s, h):
    """{(x, y): char} for a bank from x0 to x1 standing on row s+1, h rows high."""
    cells = {}
    for k in range(h):
        a, b = x0 + k, x1 - k
        y = s - k
        cells[(a, y)] = "/"
        cells[(b, y)] = "\\"
        for x in range(a + 1, b):
            cells[(x, y)] = "#"
    return cells


def place(rows, head):
    """The cells of the best bank for this room, or {} when none fits."""
    frac, fy, rx0, rx1 = flat_run(rows)
    if fy is None or frac < FLAT:
        return {}
    w = len(rows[0])
    s = fy - 1
    spots, boxes = header_spots(head)
    doors = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c.isdigit()]
    width = max(6, min(12, w // 5))
    target = w * 0.62
    for h in (2, 1):
        for bw in range(width, 5, -1):
            starts = sorted(range(rx0 + MARGIN, rx1 - MARGIN - bw + 2), key=lambda a: (abs(a + bw / 2 - target), a))
            for x0 in starts:
                x1 = x0 + bw - 1
                if fits(rows, x0, x1, s, h, spots, boxes, doors):
                    return bank_cells(x0, x1, s, h)
    return {}


def fits(rows, x0, x1, s, h, spots, boxes, doors):
    top = s - h + 1
    for x in range(x0 - 1, x1 + 2):
        if rows[s + 1][x] != "#":
            return False
        for y in range(top - CLEAR, s + 1):
            if y < 1 or rows[y][x] != ".":
                return False
    for (x, y) in spots:
        if x0 - 2 <= x <= x1 + 2 and top - CLEAR <= y <= s + 1:
            return False
    for (a, b, c, d) in boxes:
        if not (c < x0 - 1 or a > x1 + 1 or d < top - CLEAR or b > s + 1):
            return False
    for (x, y) in doors:
        if x0 - MARGIN <= x <= x1 + MARGIN and y >= top - CLEAR:
            return False
    return True


def main(argv):
    ids = [a for a in argv if not a.startswith("--")]
    if "--all" in argv:
        ids = sorted(str(p.relative_to(ROOT / "levels"))[:-5].replace("\\", "/") for p in (ROOT / "levels").glob("*/*.room"))
    dry = "--dry-run" in argv
    for rid in ids:
        path = ROOT / "levels" / (rid + ".room")
        head, grid = parse(path)
        if skipped(head):
            continue
        rows = grid.rstrip("\n").split("\n")
        w = max(len(r) for r in rows)
        rows = [r.ljust(w, "#") for r in rows]
        if flat_run(rows)[0] < FLAT:
            continue
        cells = place(rows, head)
        if not cells:
            print("%s: flat, but no bank fits" % rid)
            continue
        xs = sorted({x for x, _ in cells})
        print("%s: bank x %d-%d, %d high" % (rid, xs[0], xs[-1], len({y for _, y in cells})))
        if dry:
            continue
        grid_rows = [list(r) for r in grid.rstrip("\n").split("\n")]
        for (x, y), ch in cells.items():
            grid_rows[y][x] = ch
        tail = grid[len(grid.rstrip("\n")):]
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(head + "\n---\n" + "\n".join("".join(r) for r in grid_rows) + tail)


if __name__ == "__main__":
    main(sys.argv[1:])
