"""Lays haunches (design bible 12.78) into a room's ceiling: the ceiling's slopes.

A haunch goes in each open cell (`.`) of a ceiling's inner corner: ground above it and on one
side, open below it and on the other side, and open diagonally below it on that open side. It
also replaces each ground cell (`#`) at a ceiling's outer corner, the foot of a hanging mass:
ground above it and on one side, open below it, on the other side and diagonally below there,
so a pier or a knot that steps in as it hangs tapers instead. Never on the room's frame, next
to a door, or beside anything but plain air (`.`): the open half shows what is behind it.
`` ` `` is solid in its top-left half (ground above and to the west); `'` is its mirror (ground
above and to the east). A ceiling that steps down one tile per column becomes one diagonal, and
a wall meeting a flat ceiling gets a chamfer, so a vault curves instead of stepping.

Only ceiling corners: the cell under a haunch must be open, so a floor's corner is never
touched, and a one-tile notch (open below, ground both sides) gets both halves only when it is
two cells wide or more. Cells marked by anything but `.` (wind, water, foes, pickups) are left
alone. Check the room with tests/test_reachability.gd after: the checker counts a haunch as a
whole block, so a passage keeps four tiles of headroom under it.

Usage: python3 tools/levels/haunches.py ROOM_ID [ROOM_ID ...] [--rows=A-B] [--dry-run]
  ROOM_ID is zone/room (levels/zone/room.room). --rows limits it to grid rows A to B.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOLID = set("#u")


def haunch_cells(rows, y0=0, y1=None):
    """(x, y, char) for each haunch the grid's ceilings take, rows y0..y1."""
    h = len(rows)
    y1 = h - 1 if y1 is None else y1

    def solid(x, y):
        if y < 0 or y >= h or x < 0 or x >= len(rows[y]):
            return True
        return rows[y][x] in SOLID

    def open_(x, y):
        return 0 <= y < h and 0 <= x < len(rows[y]) and not solid(x, y)

    def air(x, y):
        # Plain open air: the cut half of a cell shows what is behind it, so
        # never beside water, wind or anything else drawn per cell.
        return 0 <= y < h and 0 <= x < len(rows[y]) and rows[y][x] == "."

    def near_door(x, y):
        return any(rows[j][i].isdigit() for j in range(y - 1, y + 2) for i in range(x - 1, x + 2)
                   if 0 <= j < h and 0 <= i < len(rows[j]))

    inner = {}
    for y in range(max(1, y0), min(h - 1, y1 + 1)):
        for x in range(1, len(rows[y]) - 1):
            if rows[y][x] != "." or not solid(x, y - 1) or not open_(x, y + 1):
                continue
            if solid(x - 1, y) and open_(x + 1, y) and open_(x + 1, y + 1):
                inner[(x, y)] = "`"
            elif solid(x + 1, y) and open_(x - 1, y) and open_(x - 1, y + 1):
                inner[(x, y)] = "'"
    out = [(x, y, ch) for (x, y), ch in inner.items()]
    # Outer corners, unless an inner haunch already runs the diagonal past them (a
    # stair one tile per row: its outer corners lie on the line the inner ones draw).
    for y in range(max(1, y0), min(h - 1, y1 + 1)):
        for x in range(1, len(rows[y]) - 1):
            if rows[y][x] != "#" or not solid(x, y - 1) or not air(x, y + 1) or near_door(x, y):
                continue
            if (x, y + 1) in inner or (x - 1, y) in inner or (x + 1, y) in inner:
                continue
            # Keep the half against the ground beside it.
            if solid(x + 1, y) and air(x - 1, y) and air(x - 1, y + 1):
                out.append((x, y, "'"))
            elif solid(x - 1, y) and air(x + 1, y) and air(x + 1, y + 1):
                out.append((x, y, "`"))
    return out


def apply(path, y0=0, y1=None, dry=False):
    text = path.read_text(encoding="utf-8")
    head, sep, body = text.partition("\n---\n")
    rows = body.split("\n")
    trailing = rows and rows[-1] == ""
    grid = rows[:-1] if trailing else rows
    cells = haunch_cells(grid, y0, y1)
    for x, y, ch in cells:
        grid[y] = grid[y][:x] + ch + grid[y][x + 1:]
    if not dry and cells:
        path.write_text(head + sep + "\n".join(grid) + ("\n" if trailing else ""), encoding="utf-8", newline="\n")
    return cells


def main(argv):
    dry = "--dry-run" in argv
    y0, y1 = 0, None
    ids = []
    for a in argv:
        if a.startswith("--rows="):
            a0, a1 = a[7:].split("-")
            y0, y1 = int(a0), int(a1)
        elif not a.startswith("--"):
            ids.append(a)
    for rid in ids:
        cells = apply(ROOT / "levels" / f"{rid}.room", y0, y1, dry)
        print(f"{rid}: {len(cells)} haunches" + ("" if not dry else " (dry run)"))
        for x, y, ch in cells:
            print(f"  ({x}, {y}) {ch}")


if __name__ == "__main__":
    main(sys.argv[1:])
