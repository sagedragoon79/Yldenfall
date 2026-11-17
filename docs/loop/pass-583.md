# Pass 583: sheets and blocks run through the tile seams

## Category

Art cohesion and environments, from the independent grade taken after pass 580 (5.6 of 10):
"tile repetition that shows the grid (the aqueduct's sandstone, the Tower's ceilings, the
Spires' floating blocks)".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, the second (the Haar's fog) is held until the hydra and steam branches
merge, and the third's foe work shipped in pass 582; this is the next. The PixelLab art loop
stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait
for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite credits.
The hosted workbench is still down (its Vercel Blob store is suspended); it stays under "stuck"
for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

Looked at `sunken/drowned_aqueduct`, `tower/rail_gallery`, `tower/smelter` and
`spires/storm_ledge` at 1x and at 3x.

- **The Tower.** Pass 566 made a plate a whole tile (bible 12.54), so every tile draws its own
  seam down its west side and across its top. A ceiling four tiles thick is graph paper, and
  the scattered variants (12.8) cannot help: each one ends at the tile's edge.
- **The Spires.** `paint_shrine` keyed the block's width (10 to 14) and height (5 to 7) to the
  seed so the variants would differ (12.8, 12.18). Two variants side by side met with their bed
  joints at different heights and their blocks cut off at the seam. At 3x the wall under
  `storm_ledge`'s east floor was a quilt of 16 px patches, each with a straight edge.
- **The aqueduct.** `paint_spring` already runs its blocks through the seams (12.39). What
  repeats there is the moss mark down a pier's face (a wall face has one variant) and the open
  water behind it. Left for a later pass; see "Next".
- The "floating blocks" the grader named in the Spires fight frame are the backdrop's islands
  and the play field's wall behind them; the wall is what showed a grid.

## What was built

- **Sheets longer than a tile** (`PLATE_WIDE_SEEDS`, `paint_plates`): half the tiles of every
  set the factory scatters (the surface field, MID, DEEP, a floor's top, a ceiling's bottom)
  have no seam, bevel or rivets on their west side, so the sheet from the tile to their west
  runs on through them. A course is sheets of one, two and three tiles. The blob tiles keep
  their seam, so a corner or a wall face starts a sheet.
- **One set of courses for the Spires** (`SHRINE_COURSES`, `shrine_joints`, `paint_shrine`):
  5, 6 and 5 world pixels in every tile; one or two head joints per course, keyed to the seed
  and never within 4 world pixels of the tile's edge. A block that lies whole inside a tile
  may be worn; the gold inlay is one groove in a course; a crack is on one tile in three
  (seven in ten before, and with the blocks joined up the cracks became the mark on a beat).
- Design bible 12.70, with the rule for a painter of built material. The factory is unchanged;
  only `tower.png` and `spires.png` are regenerated.

Two takes on the Spires: the first left two whole blocks in five worn, small dark squares along
every course; now one in five of the courses that have a whole block.

For Sean to judge in play: the Spires' wall is the larger change, one wall where there were
patches. The Tower's is quieter: the horizontal seams still run every tile, so a thick ceiling
reads as courses of plating with uneven joints, not as a field with no grid at all. Sheets
that also join downward would need the factory to know a tile's neighbours (an L-shaped plate
otherwise); that is the next step if the grade names the Tower again.

## Tests

- `tests/test_tower_plates.gd`: `test_sheets_run_longer_than_a_tile` (new): each scattered set
  has a tile with no west seam and one that starts a sheet; no rivet head where there is no
  joint; a course of 200 cells has sheets of one, two and three tiles; a corner tile starts a
  sheet. `test_a_plate_is_a_whole_tile` now reads the seam from the top row.
- `tests/test_shrine_ashlar.gd` (new suite, three tests): the bed joints sit at the same three
  rows in all twelve field tiles, from edge to edge; every head joint is clear of the tile's
  edge and there are one or two to a course; the surface variants each have joints of their own.
- `tools/art/test_tilegen.py`: `test_shrine_courses_run_through_the_tile_seams` replaces
  `test_shrine_course_scale_varies_with_seed`, which asserted the old behavior (75 pass; this
  guard runs locally, not in CI).

Mutation check, restored after and the atlases compared byte for byte: no wide seeds fails 6
checks of the sheets test; courses of 6, 5 and 5 fail 204 of the bed-joint test; a joint that
may sit at x 0 fails 92 of the seam test and the Python guard.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Two tilesets no longer show their grid; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged (guardians are not in the table; their remake is the art loop's). |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the factory and the atlas layout are as they were. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

In the queue's order: what is left of the grid item (the aqueduct: a second variant for a
wall's faces so a pier's moss mark does not repeat, and something in the open water; the HUD
over the ceiling tiles; the Spires' rain and lightning); the Haar tell frame (a flat white
silhouette: check whether the capture catches one frame of the flash or its whole length);
chests housed differently per zone and the causeway's spikes; code-first liquids and hazards;
an audio pass for the set pieces. For the art loop when a base slot frees: the Bog Puffcap,
the Bark Knight and the Spring Eel have no accent color on their sheets. The Haar's fog stays
held. The next independent grade is due after pass 585.
