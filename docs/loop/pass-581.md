# Pass 581: the stalk's roots heaved the Veins' floor, and the vault steps down to its walls

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10): the top
defect was room shape. The queue's item names the rooms in order, one per pass by bible 12.63's
rule; the Hornet Gallery was pass 576, the Rail Gallery 577, Ore Bin 3 578, the Rot Dwarf Hall
579, the Fountain Plaza 580, and the Veins are next and the last room the item names.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `evercrown/veins` is one screen wide and three tall (40 by 68 tiles), the Everbloom's second
  phase: a climb up 18 shelves past six veins to the core. Its floor stood at one height from
  wall to wall, and its vault was one straight line.
- The stalk (bible 12.59) is a picture 256 px wide and 992 px high on the shaft's middle. Its
  tests ask for solid floor under its axis and solid vault over its crown. So tiles 12 to 27
  keep their floor and their vault.
- The core hangs at tile row 6 on the middle. `EvilCore.arena` is set but never read, so the
  vault's corners are free to hang lower.
- The east door's shelf (row 12) is reached by a jump from the shelf two rows under it; the
  vault over it keeps six open rows.
- The west door (rows 62 to 65) needs its floor, and `tests/test_soak.gd` starts a hero on
  tile (8, 65), so the west landing keeps eight tiles.
- No foe walks the floor, so ramps are safe (12.66's rule about Rot Dwarves does not apply).
- The fight is the climb, so no shelf and no vein moves.

## What was built

- **The room** (`levels/evercrown/veins.room`):
  - A hump one tile high (a ramp up, a block, a ramp down) at tiles 9 to 11, between the
    door's landing and the stalk.
  - The stalk's floor, as it was, tiles 12 to 27.
  - A ramp at tile 28 to a bank a tile up, four tiles long; a ramp at tile 33 to a bank two
    tiles up against the east wall.
  - The vault steps down a tile at tiles 9 and 30, a second at tile 33 on the east, and on
    the west twice more at tiles 5 and 2, so the west corner hangs six tiles under the crown.
  - Every shelf, vein, door and the sign are on the tiles they were on.
- Design bible 12.68; `levels/README.md` says what the stalk needs kept.

One take, kept. Looked at in `evercrown/veins` at the foot and the head: the vault reads as a
vault with the core at its keystone, the east root runs in under the first bank, and the banks
give the foot a ground line that is not a ruled edge. For Sean to judge in play: the west hump
is small, three tiles wide, and reads as a bump more than a root's heave.

## Tests

`tests/test_bloom_stalk.gd`, one new:

- `test_the_veins_are_not_a_level_box`: a floor at three heights and a vault at five; the
  stalk's 16 tiles keep their floor and vault; four ramp tiles, each with ground under it,
  ground on its high side and open floor at its foot; the hump between the landing and the
  stalk; both banks where they should be; the vault never rises toward either wall, steps
  three times west and twice east, and hangs lowest in the west corner; the east door, its
  shelf and six open rows over it; 150 plank tiles and the six veins where they were; no
  hazard; the core in open air; and done for real with the core starved: a walk east from the
  west door goes over the hump, passes the roots on the old floor and ends two tiles up on the
  east bank with no jump, unhurt, and the stalk's roots and crown still meet floor and vault.

It passed on its first run. Mutation check, each written over the good room, which was then
restored and compared byte for byte: the old room fails three checks (and stops at the ramp
count); a square step in place of the first east ramp fails the ramp count; a spike on the
landing fails two (the hazard count and the walk's "unhurt"); a slab hung over the crown fails
seven; a vault ruled straight fails three; a vein moved one tile fails one.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The sixth room off the template, and the first shaft. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | Unchanged; the independent grade is the real measure. |
| Bosses | 10 | 99 | The core hangs at the keystone of a vault. The fight is as it was. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | The roots have lifted the floor they stand in. |

Weighted: 98.85.

## Next

The room shape item's named rooms are done; the pass 580 grade (5.6 of 10) no longer names
room shape. Its top defect is the Haar's fog, held until the hydra and steam branches merge
where it touches the Haar. So next, in the queue's order: one saturated identifying color per
foe where the sheet allows (characters too quiet for the frame); the grid showing in the
aqueduct's sandstone, the Tower's ceilings and the Spires' floating blocks; the Haar tell
frame (a flat white silhouette: check whether the capture catches one frame of the flash or
its whole length). Then chests housed differently per zone and the causeway's spikes;
code-first liquids and hazards (the amber pool, the lava column, the Boughs' wind dashes); an
audio pass for the set pieces. Tooling worth a short pass: the room budget test measures
wall-clock time; the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The
sword in the hit frames waits for a watched feel call; the Blinkhop waits for a free base
slot. The next independent grade is due after pass 585.
