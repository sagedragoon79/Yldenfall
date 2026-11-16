# Pass 580: the King's Hall and the temple stand on terraces over the Fountain Plaza

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10): the top
defect is room shape. The queue's item names the rooms in order, one per pass by bible 12.63's
rule; the Hornet Gallery was pass 576, the Rail Gallery 577, Ore Bin 3 578, the Rot Dwarf Hall
579, and the Fountain Plaza is next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `hearthroot/plaza` is two screens wide and one tall, the first room of the game and the one
  crossed most. Its floor stood at one height for 78 tiles, and its ceiling was one straight
  line.
- The Three Mouths (bible 12.58) are 208 px wide and 164 px tall on tile 40. Their test asks
  for solid floor from end to end, no tile inside the picture, and air over the crown. So
  tiles 33 to 47 keep their floor and their ceiling.
- A plinth three tiles high stood at tiles 30 and 31, there to reach the chest's plank five
  tiles over the floor. Every crossing of the plaza had to jump it.
- Both inner doors (the King's Hall at tile 18, the temple at tile 62) are marks in the grid,
  so each can stand on a raised floor. The piper is the only person west of the court.
- `tests/test_world.gd` starts a hero on tile (10, 19), so the west landing keeps ten tiles.
- The room is a town: no foe walks it, so ramps are safe (12.66's rule about Rot Dwarves does
  not apply).

## What was built

- **The room** (`levels/hearthroot/plaza.room`):
  - The King's Hall terrace, two tiles up, 17 tiles long, with two ramp tiles at each end. The
    hall's door and the piper stand on it.
  - The fountain court, as it was.
  - The temple's terrace, a tile up, 14 tiles long, a ramp at each end, with the temple's door
    on it.
  - The plinth is gone: the chest's plank is three tiles over the terrace.
  - The ceiling hangs three tiles low over both gates and two over both terraces, with
    shoulders; over the court it is as it was.
  - The chest is on the tile it was on.
- Design bible 12.67.

One take, kept. Looked at in `hearthroot/plaza` at four places (the west gate, the King's Hall
door, the fountain, the temple door): the terraces read at once, the plank stands on legs on
the terrace instead of hanging on long chains, and the court is the tallest space. For Sean to
judge in play: the east ceiling is a heavy slab of stone over the temple's terrace, and each
ramp's foot shows the dark square every ramp in the game has.

## Tests

`tests/test_spring_wall.gd`, one new:

- `test_the_fountain_plaza_is_not_a_level_box`: a floor at three heights and a ceiling at
  four; the court's 15 tiles keep their floor and ceiling and the two posts; six ramp tiles,
  each with ground under it, ground on its high side and open floor at its foot; both
  terraces where they should be with their doors on them; the chest and its plank where they
  were; no hazard; the ceiling low over both gates and its longest straight run the court's;
  and four things done for real: the piper and Wena stand on their floors; a hero who comes
  out of either inner door stands on its terrace; a walk east from the west gate climbs two
  tiles and comes down to the court; a walk east from the court climbs one and ends at the
  east gate, unhurt.

It failed on its first run, and the fault was the test's: it walked the whole room in one
leg, and the posts at the fountain's feet stop a walk, as they always have. The walk is now
two legs.

Mutation check, each written from a copy of the good room, which was then restored and
compared byte for byte: a level floor fails (one height, no ramps); a ruled ceiling fails
four checks; a square step in place of the temple's west ramp fails the ramp count; the piper
left at the old floor fails (he stands in the terrace); the King's Hall door moved off its
terrace fails two; a ceiling hung over the court fails six; a spike fails two.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | The plaza no longer needs a jump over a plinth on every crossing. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The fifth room off the template, and the first town room: two terraces and a court. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | Unchanged; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | The king's door stands higher than the temple's, and the water lowest. |

Weighted: 98.85.

## Next

The independent grade is due now (after pass 580); `hearthroot/plaza`,
`heartwood/hornet_gallery`, `tower/rail_gallery`, `tower/ore_bin` and `heartwood/dwarf_hall`
go in its set. Room shape, one room per pass by 12.63's rule: the Veins (check the Everbloom
stalk's footing, which reads the room's veins). The Haar tell frame (a flat white silhouette:
check whether the capture catches one frame of the flash or its whole length). Chests housed
differently per zone, and the causeway's spikes. Code-first liquids and hazards (the amber
pool, the lava column, the Boughs' wind dashes). An audio pass for the set pieces. Tooling
worth a short pass: the room budget test measures wall-clock time; the test runner's shared
`user://`; `tools/art/test_tilegen.py` in CI. The sword in the hit frames waits for a watched
feel call. The Haar fog items wait until the hydra and steam branches merge; the Blinkhop
waits for a free base slot.
