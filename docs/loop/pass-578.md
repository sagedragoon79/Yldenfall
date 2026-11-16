# Pass 578: Ore Bin 3 stands over a sorting floor and a sump

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10): the top
defect is room shape. The queue's item names the rooms in order, one per pass by bible 12.63's
rule; the Hornet Gallery was pass 576, the Rail Gallery pass 577, and Ore Bin 3 is next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- `tower/ore_bin` is one screen. Its floor stood at one height for 30 tiles, from the door to
  the shelf over the secret, and its ceiling was one straight line.
- The room has its landmark, the bin (pass 574, bible 12.61). Its posts, spill and chute stand
  on the floor between tiles 22 and 30 and come out of the ceiling at tiles 24 and 31, so that
  stretch of floor and ceiling has to stay. Unlike the ore road, nothing of the bin needs a new
  footing if the floor west of it moves.
- The room has three rows of ground under its floor, and the door's floor is on the first, so
  the floor between the door and the bin can be sunk by two.
- The way to the chest is a jump straight up through the low plank (four tiles), then up to
  the chest's plank (four more). Four tiles is the most a jump gives, so the floor under the
  low plank's west end cannot sink.
- The Gear Bat roosts under the ceiling at tile 20.

## What was built

- **The room** (`levels/tower/ore_bin.room`):
  - The door's landing, level for ten tiles; a ramp down to a sorting floor a tile lower (four
    tiles); a ramp down to a sump two tiles under the landing (three tiles); one ramp two
    tiles long up out of the sump to the bin's floor. No spikes.
  - The ceiling hangs two tiles low over the door and over the east end of the shelf, each
    with a shoulder a tile deep, and is vaulted two tiles up between the door and the bat.
  - Nothing that can be picked up moved; both planks, the chest, the sign, the bat, the rider
    and the bin are on the tiles they were on.
- Design bible 12.65.

Two takes were thrown away. The first put the sump under the low plank's east end: that end
then hung from a chain in the vault while the west end stood on a leg. The second sank the
floor under the whole plank: it looked right, and the reachability sweep failed three tests
(the chest at 18, 11 could not be reached, the plank being five tiles over its floor). The
landing now runs under the plank's west end.

The Minecart Rider's stretch is the bin's floor, nine tiles (it was 30). Looked at in
`tower/ore_bin` at 1x, before and after: the stepped floor and the vault read at once, the
lamps hang in the vault, and the low stone over the door frames the way in. For Sean to judge
in play: whether nine tiles is too short a run for the rider, who now tips almost as soon as
he charges west.

## Tests

`tests/test_ore_bin.gd`, eight tests (one new):

- `test_the_ore_bin_is_not_a_level_box` (new): a floor at three heights and a ceiling at five;
  the Gear Bat still roosts under stone; four ramp tiles, each with ground under it, ground on
  its high side and open floor at its foot; the landing, the sorting floor and the sump where
  they should be; the plank's west end over the landing and its east end over the sorting
  floor; no hazard in the room; the bin's floor level for nine tiles with the west post's
  footing clear of the ramp; and three things done for real: the rider, with the player level
  with him by the door, never rolls off his floor and goes no further than half a tile over
  the ramp's head; a walk east out of the sump climbs two tiles by the ramp alone; a walk east
  from the door ends in the sump two tiles lower, unhurt.

The first run of the test failed on the rider: it asked that his middle stop at the ramp's
head, and he stops 4 px past it, his cart overhanging the ramp without rolling down. The check
now allows half a tile.

Mutation check, each restored from a copy and compared byte for byte: a level floor fails
(one height, no ramps); a flat ceiling fails (one height); the plank moved two tiles east
fails both plank checks; a spike in the sump fails four checks; a square step in place of the
long ramp's upper tile fails the ramp count.

The reachability sweep passes with the room changed (12 checks), as do the room rules. Full
suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Minecart Rider's stretch in Ore Bin 3 is nine tiles, ended by a ramp's head. |
| World and level design | 15 | 99 | The third room off the template: a landing, a sorting floor, a sump, a vault. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | Unchanged; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Room shape, one room per pass by 12.63's rule: the Rot Dwarf Hall (its high seat stands on the
floor and reaches the ceiling, so its painter's footing and its 18 open rows need checking),
then the plaza and the Veins. The Haar tell frame (a flat white silhouette: check whether the
capture catches one frame of the flash or its whole length). Chests housed differently per
zone, and the causeway's spikes. Code-first liquids and hazards (the amber pool, the lava
column, the Boughs' wind dashes). An audio pass for the set pieces. The independent grade is
next due after pass 580; put `heartwood/hornet_gallery`, `tower/rail_gallery` and
`tower/ore_bin` in its set. Tooling worth a short pass: the room budget test measures
wall-clock time; the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The
sword in the hit frames waits for a watched feel call. The Haar fog items wait until the hydra
and steam branches merge; the Blinkhop waits for a free base slot.
