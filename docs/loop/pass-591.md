# Pass 591: a vault curves into its wall (the haunches)

## Category

World and art cohesion, from the independent grade taken after pass 590 (5.3 of 10, level with
pass 585). The four rooms passes 587 to 590 reshaped are no longer called boxes, but "their
ceilings read as stair-stepped tile blocks (canopy bridge, flooded hall, storm ledge, aqueduct):
give the tilesets slope and corner pieces so a vault or canopy curves instead of stepping." That
is the grade's first defect, and the one a pass can close unattended.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, so this pass took the second, the pass 590 grade. Its other parts (the
hit frames' sword and spark, the thorn bulbs, the Boughs' leaves, the plaza, the shop labels) stay
in the queue. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- The tilesets have two slopes, both for floors (`/`, `\`, bible 6.1): solid below a diagonal.
  A ceiling has nothing but square tiles, so a vault that rises one tile per column is a stair,
  and so is every place a wall meets a ceiling. Shot at 1x and 2x, the four rooms' vaults are
  shapes of the right size drawn in square steps.
- Every painted atlas is 8 tiles by 9; rows 0 to 8 are all used. Hearthroot's atlas comes from
  Sean's PixelLab set and has no painted rows of its own.
- The ambient-occlusion rim (`EdgeShade`, bible 12.3) rims each solid cell's air-facing sides with
  square bands, so a cell solid only above a diagonal would get a dark square in its open half.

## What was built

- **The haunches** (bible 12.78): row 9 of every painted atlas (`tools/art/tilegen.py`,
  `paint_haunch`). Each is the zone's ceiling tile, soffit, trim and outline, sheared up along the
  diagonal, the mirror of how a floor slope is drawn. Legend `` ` `` keeps the top-left half (a
  west wall meets the ceiling), `'` the top-right. `TilesetFactory` gives them triangle collision
  (`HAUNCH_WEST`, `HAUNCH_EAST`, `has_haunches`, `is_haunch`); `Room` lays them, counts them as
  ground for their neighbours' tiles and answers `is_solid_at` above the diagonal; a zone with no
  row 9 (Hearthroot) lays plain ground in their place.
- **The rim** of a haunch runs along its diagonal: four bands parallel to it, darkest at the edge,
  fading into the solid half (`EdgeShade._diagonal_band`).
- **The checkers.** `reach.gd` and `tools/levels/raise_passages.py` count a haunch as a whole
  block, so a passage keeps four tiles of headroom under it.
- **`tools/levels/haunches.py`** lays them into a room: in each open cell of a ceiling's inner
  corner, and at each outer corner of a hanging mass unless an inner haunch already runs the
  diagonal past it. Never on the frame, beside a door, or beside anything but plain air (a cut
  corner beside water would show a dry triangle).
- **The four rooms**: the Canopy Bridge (28), the Flooded Hall (33), the Drowned Aqueduct (28) and
  the Storm Ledge (29). Nothing else in them moved.
- `levels/README.md` has the legend row; design bible 12.78.

Judged by eye at 1x and 2x, before and after, in all four rooms: each vault reads as a curve, the
diagonals join the soffit trim of the flat ceiling beside them, and the aqueduct's arches read as
arches. The first haunches kept the square rim, a dark block in the open half under every
diagonal; the rim now follows the cut. The first version of the tool also cut the outer corners of
one-tile stairs, which would have drawn a sawtooth; outer corners next to an inner haunch are left
whole. The aqueduct's piers keep their steps under the water.

## Tests

`tests/test_haunches.gd`, four tests:

- `test_every_painted_atlas_has_both_haunches`: seven zones' atlases carry row 9, each haunch solid
  on its side and clear on the other, its edge one diagonal; Hearthroot's has none.
- `test_a_haunch_collides_as_a_triangle`: both collide as triangles, the legend lays the right
  tile, and `is_solid_at` is solid above the diagonal and open below it.
- `test_a_jump_into_a_haunch_slides_along_it`: a jump straight up against a wall into a square
  corner stays where it is; into a haunch it slides out from the wall along the slope.
- `test_the_four_vaults_curve_instead_of_stepping`: each of the four rooms carries 25 haunches or
  more, each hanging from ground on its solid side, and no square inner corner is left in a
  ceiling.

`tests/test_rooms.gd`'s legend test reads a double-backtick code span, so the README can name the
backtick. `tools/art/test_tilegen.py` expects the 10-row atlas (76 checks pass).

Mutation check, each restored from a copy after: the west haunch given a square collision fails
the triangle and the jump tests (moved 0.0 px); the Storm Ledge as it was on main fails the vault
test (no haunches, 29 square corners). The reachability, soft-lock and room tests pass.

Full suite: 18,559 checks passed and 13 failed. One was this pass's: `test_tiles_are_drawn_at_double_density`
held every atlas to 8 or 9 rows, and now takes the 10-row atlas too. The other twelve failed only
on "saves changed (save_1.json, save_9.json)": the save files in the game's user folder were
rewritten at 19:17 while the suite ran, from outside it. Each of the twelve passes on its own
rerun, as does the atlas test.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | A sloped ceiling turns a jump instead of stopping it. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The four vaults curve; any room can take haunches with one command. |
| Art cohesion | 15 | 98 | The grade's first defect is closed; its combat-readability items are next. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 590 grade, in its order: combat readability (the hit frames' sword, the small
spark, the struck foe's flash and knockback pose; the sword's look is a watched-session call, the
spark is not), then the thorn bulbs that read as strawberries, and the shop's control labels. Then
the queue: the repeated chest and sign, the grid item's leftovers. Haunches in other rooms whose
ceilings step, one zone at a time, when the grade names them. The Haar's fog stays held.
