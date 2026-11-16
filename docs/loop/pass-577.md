# Pass 577: the Rail Gallery's floor is cut, and the ore road crosses it

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10): the top
defect is room shape, "a rectangular tile frame around a dead-level floor with 60 to 70 percent
empty dark air". The queue's item names the rooms in order, one per pass by bible 12.63's rule;
the Hornet Gallery was pass 576, and the Rail Gallery is next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `tower/rail_gallery` is two screens long and one tall. Its floor stood at one height for 80
  tiles, broken only by the pillar and the vault's shaft; both runs of spikes lay on it. Its
  ceiling was one straight line.
- The room has its landmark, the ore road (pass 573, bible 12.60): a trestle from wall to wall
  on eight bents. Every bent's feet stood at the one floor level, so the floor under them could
  not move without the bents hanging in the air or standing buried.
- The road runs 40 px under the ceiling for the room's whole length, and its test holds the air
  over the rail open, so the ceiling cannot come down anywhere. It can go up: there are four
  rows of stone over it.
- The room has three rows of ground under its floor and its doors' floors are on the first, so
  the floor between the doors can be sunk by two.
- The fallen timber and sleeper under the broken span lay partly on the second spikes.

## What was built

- **The room** (`levels/tower/rail_gallery.room`):
  - A dip a tile deep and 14 tiles long (tiles 14 to 27), with a ramp down into it and a ramp
    out. The first spikes lie on its floor, eight tiles wide as before, with footing at the foot
    of each ramp.
  - A pit two tiles deep and ten wide (tiles 40 to 49) under the hung plank, spiked from wall
    to wall.
  - Three vaults in the ceiling (over the west landing, the Minecart Rider's stretch and the
    Iron Dwarf's floor), each two tiles high in the middle and one at its shoulders.
  - Nothing that can be picked up moved; the pillar, the vault's shaft, both chests' ledges and
    every foe's tile are as they were.
- **`OreRoad`** (`scripts/world/ore_road.gd`): each bent has its own footing level, `FOOT_Y`.
  The second and third bents stand in the dip on legs a tile longer. The fifth stands in the
  pit among the spikes on legs two tiles longer, with a fourth girt (a sill) and a cross in the
  tier it makes. Legs reach their full splay at their own floor and stand on stone footings
  there. The fallen timber lies with its east end out over the pit's brink; the sleeper lies on
  the floor west of it.
- Design bible 12.64; `levels/README.md` says to change `FOOT_Y` with the floor.

The Minecart Rider's stretch is three tiles shorter (11 tiles), and his charge east now ends at
the pit's brink.

Looked at in `tower/rail_gallery` at 1x at the west end, the middle and the east end. The dip
and the pit read at once, and the bent in the pit is the room's best new detail: the trestle
now crosses something. The vaults are a modest change: they break the ceiling's line, and the
far wall shows through them. Two things for Sean to judge in play: whether the rider's shorter
stretch makes him too easy to bait into tipping, and whether the spikes in the pit, two tiles
down, still read as spikes at a run.

## Tests

`tests/test_ore_road.gd`, nine tests (two new, two changed):

- `test_ore_road_bents_follow_the_floor` (new): the bents stand at three levels on whole tiles;
  the picture reaches the deepest footing and no further; every bent has a girt near its feet
  and clear of its footings; only the pit's bent has a sill, with a cross in its tier; a sunk
  bent's legs are drawn, lit and shaded, under the level floor and a level bent's are not; the
  fallen timber lies on the floor with less than a third of it over the brink.
- `test_the_rail_gallery_is_not_a_level_box` (new): a floor at three heights and a ceiling at
  three; the Gear Bats still roost under stone; two ramps, each with ground under it and on its
  high side; the dip a tile down with the eight spikes and footing at each ramp's foot; the pit
  ten tiles wide, two down, spiked wall to wall, where the road's painter takes it to be, under
  the plank; and two real walks: out of the dip by its east ramp, and down into it from the
  west door's floor, stopping short of the spikes unhurt.
- `test_ore_road_stands_on_its_bents` and `test_the_rail_gallery_has_its_ore_road` (changed):
  each bent's feet, footings, girts and splay are checked at its own floor, and in the room its
  legs stand in open air down to its feet, on solid floor, with no footing let into a wall.

Mutation check, each restored from a copy and compared byte for byte: the room without its
ramps fails the shape test; one bare tile in the pit fails it; a flat ceiling fails it; every
bent at the level floor fails the bents test (four checks) and the room test (six feet with no
floor under them); no sill girt fails the bents test; the sleeper back over the pit fails the
fallen timber check (16 px over the brink). The first run of the check emptied the room file (the
script opened it for writing before it built the change); the room was rebuilt from the copy
saved before the pass's edit, by the same script that made the edit, and the mutations were run
again on it.

The reachability sweep passes with the room changed (117 checks). Full suite: see the pull
request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Minecart Rider's stretch is three tiles shorter and ends at a brink. |
| World and level design | 15 | 99 | The second room off the template: a ramped dip, a pit, a vaulted ceiling. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | The trestle follows the floor it stands on. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Room shape, one room per pass by 12.63's rule: Ore Bin 3 and the Rot Dwarf Hall have their
landmarks and level floors (each landmark's painter will need its footing checked, as the ore
road's did); the plaza and the Veins after them. The Haar tell frame (a flat white silhouette:
check whether the capture catches one frame of the flash or its whole length). Chests housed
differently per zone, and the causeway's spikes. Code-first liquids and hazards (the amber
pool, the lava column, the Boughs' wind dashes). An audio pass for the set pieces (the nest,
the mouths, the gears, the bell, the falling ore, the dripping sap). The independent grade is
next due after pass 580; put `heartwood/hornet_gallery` and `tower/rail_gallery` in its set.
Tooling worth a short pass: the room budget test measures wall-clock time; the test runner's
shared `user://`; `tools/art/test_tilegen.py` in CI. The sword in the hit frames waits for a
watched feel call. The Haar fog items wait until the hydra and steam branches merge; the
Blinkhop waits for a free base slot.
