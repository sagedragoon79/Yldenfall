# Pass 579: the root heaved the Rot Dwarf Hall's floor, and past it the floor fell in

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10): the top
defect is room shape. The queue's item names the rooms in order, one per pass by bible 12.63's
rule; the Hornet Gallery was pass 576, the Rail Gallery 577, Ore Bin 3 578, and the Rot Dwarf
Hall is next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- `heartwood/dwarf_hall` is two screens wide and one tall. Its floor stood at one height for
  78 tiles, and its ceiling was one straight line.
- The room has its landmark, the high seat (pass 575, bible 12.62), at tile 22. Its picture is
  12 tiles wide and 18 rows tall and its root goes into the ceiling, so tiles 16 to 28 keep
  their floor and their ceiling.
- The room is one screen tall with three rows of ground under its floor and two of stone over
  it. The floor can be sunk by two or raised; the ceiling can only be hung lower.
- Each low plank is four tiles over the floor, the most a jump gives, so the floor under at
  least one end of each cannot sink. It can rise.
- `RotDwarf` turns when `_wall_ahead()` or `not _floor_ahead()`. A ramp up is a wall to him.
  A ramp down is floor (the check reaches 6 px under his toes, and a 45-degree ramp drops 2 px
  there), so by the code he walks down it and cannot walk back up. This is read from the code,
  not watched in play.

## What was built

- **The room** (`levels/heartwood/dwarf_hall.room`):
  - West of tile 31 the floor is as it was: the door, the sign, the high seat, the west dwarf.
  - A bank a tile high, six tiles long, with a ramp at each end: the root has heaved the floor.
    The low plank's west leg stands on it.
  - The Blinkhop's stretch, at the old height.
  - The fall: a ramp down to a shelf a tile lower (four tiles), a ramp down to a low floor two
    tiles under the doors (five tiles), and a broken stair of two square steps up to the east
    door's floor. No spikes.
  - The ceiling hangs two tiles low over the west door and three over the east, each with
    shoulders, and steps down to three tiles low over the chest's plank. Over the seat it is
    as it was.
  - Nothing that can be picked up moved, and no ledge, foe or sign.
- Design bible 12.66.

The stair is square so that the east dwarf keeps the gate's floor (see the audit). One take,
kept. Looked at in `heartwood/dwarf_hall` at four places (the seat, the bank, the fall, the
east door): the bank and the fall read at once, the stepped ceiling frames the seat as the
tallest space in the hall, and the chest's chains now hang from stone that is near them.
For Sean to judge in play: the fall is a quiet place with nothing in it, which may want a
find or a foe of its own.

## Tests

`tests/test_high_seat.gd`, seven tests (one new):

- `test_the_rot_dwarf_hall_is_not_a_level_box` (new): a floor at four heights and
  a ceiling at four; the seat's 13 tiles keep their floor and their 18 open rows; four ramp
  tiles, each with ground under it, ground on its high side and open floor at its foot; the
  bank, the shelf, the low floor and the stair where they should be; both low planks, the
  chest, the Potion Shard and all three foes on the tiles they were on; no hazard; the ceiling
  low over both doors and its longest straight run the seat's; and three things done for
  real: over 30 seconds with the player out of sight, the west dwarf turns at the bank's ramp
  and the east dwarf at the stair's head, and neither leaves his floor; a walk east from the
  seat climbs the bank and ends in the low floor two tiles down, unhurt; the stair stops a
  walk and jumps climb it.

It passed on its first run.

Mutation check, each written from a copy of the good room, which was then restored and
compared byte for byte: a level floor fails (one height, no ramps); a ruled ceiling fails
three checks; a ramp in place of the stair fails the ramp count (the test stops there, so
the dwarf's walk down that ramp was not run); a spike in the low floor fails; the bank run
under the seat fails six checks and the older seat test; the ceiling hung over the seat fails
both tests.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Each Rot Dwarf in the hall keeps his own floor; the east one's stretch is 22 tiles. |
| World and level design | 15 | 99 | The fourth room off the template: a bank, a shelf, a low floor, a stair. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | Unchanged; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | The hall's floor now shows what its sign says the root did. |

Weighted: 98.85.

## Next

Room shape, one room per pass by 12.63's rule: the plaza (its fountain and the spring wall
stand on the floor, so check their footing), then the Veins. The independent grade is due
after pass 580; put `heartwood/hornet_gallery`, `tower/rail_gallery`, `tower/ore_bin` and
`heartwood/dwarf_hall` in its set. The Haar tell frame (a flat white silhouette: check
whether the capture catches one frame of the flash or its whole length). Chests housed
differently per zone, and the causeway's spikes. Code-first liquids and hazards (the amber
pool, the lava column, the Boughs' wind dashes). An audio pass for the set pieces. Tooling
worth a short pass: the room budget test measures wall-clock time; the test runner's shared
`user://`; `tools/art/test_tilegen.py` in CI. The sword in the hit frames waits for a watched
feel call. The Haar fog items wait until the hydra and steam branches merge; the Blinkhop
waits for a free base slot.
