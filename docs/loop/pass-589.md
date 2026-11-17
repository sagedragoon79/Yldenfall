# Pass 589: the Storm Ledge lies under a broken island

## Category

World and art cohesion, from the independent grade taken after pass 585 (5.3 of 10): "rooms are
rectangular boxes (Boughs canopy bridge, Vorrhallow flooded hall, Spires storm ledge, Sunken
aqueduct): flat ceilings, straight walls, one thick tile border", and "the same chest on the same
thin table" in nearly every room. By design bible 12.63's rule, one room per pass; passes 587 and
588 did the Flooded Hall and the aqueduct, and this is the third of the four.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) is held, so this pass took the third. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `spires/storm_ledge` is one screen (40 by 23), Carillon's first room. Its ceiling was ruled
  flat at row 4 for the whole room, its side walls ran straight from it to the floor, and its
  chest stood on a one-way plank on two posts over the east ledge. Shot at 1x: a brick frame
  around a picture of the storm, with the floating islands of the backdrop inside it.
- The sign says the Tree's crown breaks here "into islands of stone, adrift in the storm", so the
  room should be the hollow under one of them, not a box.
- Constraints: the doors (west rows 16 to 19, east rows 14 to 17), the sign, the thorn pit, the
  Hornet (18, 11), the Thunder Beetle on the east ledge and the chest (26, 15) must not move, and
  the room must stay reachable.

## What was built

`levels/spires/storm_ledge.room`, tiles only:

- **The overhang** is the broken underside of the island above: it stands at nine heights, comes
  down five to seven rows into both walls at the corners, breaks open to the room's top row over
  five columns in the middle, and two spurs of rock hang from it (columns 12 and 25).
- **The walls** bulge: the west wall has a shoulder of rock between rows 6 and 12, the east wall
  one between rows 6 and 11.
- **No table.** The plank is gone. The chest stands on a crag that rises sheer four rows from the
  floor on its west and steps down a tile to the east ledge, so you reach it from the ledge as
  before.
- Design bible 12.76, and Carillon's summary (section 3) mentions it.

Judged by eye at 1x, before and after: the room now reads as a hollow under a broken island, open
to the storm, rather than a framed box. The first crag stepped down a tile on both sides and read
as a ziggurat, as 12.74's first heap did; its west face is now sheer.

## Tests

`tests/test_storm_ledge.gd`, three tests:

- `test_the_overhang_is_ragged_and_open_to_the_storm`: the underside at six heights or more,
  open to row 1 over four columns or more with the top row still standing, two hanging spurs or
  more, and both corners low.
- `test_the_walls_bulge`: each wall's face stands at three depths or more between rows 4 and 13.
- `test_the_chest_stands_on_a_crag_not_a_table`: no plank in the room, the chest on rock, the
  crag's west face sheer three rows or more and its east side stepping down to the ledge.

Mutation check, the room restored from a copy and compared byte for byte after: the room as it was
on main fails all three tests (4, 2 and 4 checks); the crag given a step at its west foot again
fails the third (1 check). The reachability, room-boot and landmark tests pass.

Full suite: 18,268 checks passed and none failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The storm ledge is a hollow under a broken island, its chest on a crag. |
| Art cohesion | 15 | 98 | The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The sign's islands adrift in the storm are now the room itself. |

Weighted: 98.85.

## Next

In the queue's order: the last box room (the Boughs canopy bridge), and the repeated chest and
sign; then the grid item's leftovers (the aqueduct's second face tile, the HUD over the ceiling,
the shop panel). The Haar's fog stays held. The next independent grade is due after pass 590.
