# Pass 615: a bough's bark is plates

## Category

Art cohesion, from the independent grade taken after pass 610 (5.6 of 10): "the canopy
zone's terrain is flat vertical brown stripes with stair-stepped edges" (the canopy bridge).
It was the top of the queue after passes 611 to 614 took the items before it.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The High Boughs' tiles were `paint_wood`, the Heartwood's strands, two shades up: columns 4
to 9 pixels wide that alternate two values, laid out the same in every tile so a strand runs
on from one tile to the one below. Pass 555 made them to replace a sine grain the grade
called "striped dirt". They are calm, and they are stripes: in the canopy bridge every wall
is ruled from its top to its foot, and the darker tiers ruled the same way a shade down.

The stripes came from two things together: the two values alternate by column, and no line
ever ends. A bark that keeps one value and whose lines stop is not striped.

## What was built

- **Plates** (`tilegen.paint_bough`, `bough_plate`, `bough_furrow`): one body value (`bark-4`)
  between furrows one pixel wide and two shades down. A plate is the ground nearest one of six
  points, with a step across counted 2.5 times a step down, so a plate is tall. The furrows
  slant, fork and join; none runs straight down for more than 17 of a tile's 32 pixels.
- **One layout, wrapped**: the same in every tile, so a plate runs across every seam whichever
  variant is next to it. The seed varies only marks that stay on one plate (a check, a lit
  west edge, a sprig).
- **The trim follows**: the rind under a cap and the soffit under a ceiling are notched where
  a furrow meets them, not where a strand of the old layout was.
- **The Heartwood and the Haar are unchanged**: `paint_wood` and `paint_limb` keep the strands.
  Only `assets/tiles/boughs.png` changed.
- Bible 12.92 (new).

Three layouts were looked at in the game before one was kept. Six or seven evenly spread
points made a honeycomb (regular hexagons, loud at 1x). A stretch of 3.5 or more made the
furrows vertical lines again. The kept one has uneven points and a stretch of 2.5: plates of
129 to 218 pixels that read as furrowed bark at 1x and 2x in the canopy bridge and Sylvarre.

Not done: the darker tiers still step by the tile (its own queue item). The grade's other
half, "its smooth painterly leaf backdrop clashes with the rest", is the parked pixel-grain
call. For Sean to judge in play: whether the plates are too busy next to the leaf backdrop;
`BOUGH_PLATES` with five points would make them larger.

## Tests

`tools/art/test_tilegen.py` (run by hand; CI runs no Python tests), four new: the furrows are
lines (10 to 22 percent of the tile, none straight for two thirds of a tile down or a quarter
across), no plate is a sliver and the plates are uneven, one body value fills over 70 percent
of every tile; the layout wraps and no seed moves a furrow at a tile's edge; the trim is
notched at every furrow and nowhere else; the shipped atlas is what the generator makes.

`tests/test_bough_bark.gd` (new, four tests): one body value in the shipped field tiles (and
the Heartwood is still two); the longest straight furrow is under two thirds of a tile (a
strand's seam runs the whole tile); the variants share the layout, differ in their marks and
never move a furrow at a seam, and the darker tiers are plates too; the canopy bridge is built
of the field; 12.92 names the test. `test_the_boughs_bark_is_calm` (was
`..._wood_is_long_strands`) keeps the 23 percent measure and now asks that pixels do change
going down a column.

Mutation check: with `paint_bough` painting `paint_wood` again, the Python body-share, seam and
shipped-atlas tests fail, and the Godot body-value and straight-furrow tests fail; with the
trim's notches back at the strand starts, the notch test fails; with both back all pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Boughs' terrain is bark plates; the tiers' tile steps remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

An independent grade is due now (every fifth pass). Then the pass 610 grade's remaining
unheld items, in order: the shop panel's dead area and no comparison with equipped gear, and
the plaza skyline's gridded windows; then the tiers that step by the tile (seen in pass 614).
The Haar's fog and dither, the sprites' pixel size, the hero's rim light and the sword's look
stay held.
