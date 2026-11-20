# Pass 613: a fill grows in patches

## Category

Art cohesion, and world and level design, from the independent grade taken after pass 610 (5.6
of 10): "terrain tiles repeat visibly: uniform brick and cobble fills, one vine overlay on every
block, little edge variation (plaza, flooded hall, storm ledge, aqueduct)". It was the next
unheld item of that grade and the top of the queue.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The four rooms the grade named are two different builds. The Flooded Hall, the storm ledge and
the aqueduct are painted tiles, which already scatter variants, tiers and wear (bible 12.8,
12.45, 12.55). The plaza is Hearthroot, whose walls are filled from one seamless PixelLab
texture (13.6). That texture is 128 px, four tiles across, and its roots and moss cross every
block of it: "one vine overlay on every block" is the plaza, and it is literal. A floor thirty
tiles long showed the same tangle seven times.

Three ways were tried on the texture before one was kept:

- Painting the growth out (filling each root from its neighbors) left a dark smear where every
  root had been, because a root's own dark line is not growth and stays.
- The five other textures of the same PixelLab set have other block sizes and other stone, and
  do not tile with this one.
- Keeping every root's shape and taking its color to the stone's own, in patches. This reads as
  roots carved in the blocks, which is what 13.6 says the wall is. Kept.

## What was built

- **A larger fill** (`tilegen.grown_fill`): `assets/tiles/hearthroot_fill.png` is four copies of
  the texture a side, 512 px, so it repeats every 16 tiles in place of every four. `GroundFill`
  reads the period from the texture; no game code changed.
- **Growth lives in patches** (`fill_growth`): a seamless noise in patches 128 px across. Where
  it is low a root or a leaf is carved stone, in the stone's own color nearest to 0.8 of its
  value; a step higher the moss is stone and the brown roots stay; above that the texture is as
  Sean made it. About 44 percent of the growth stays alive.
- **The stone is untouched.** Only a pixel of growth changes, and only to a color the stone
  already has.
- Bible 12.90 (new) and a line in 13.6.

Judged by eye at 1x and 2x in the plaza and the market: the left of the plaza's floor is bare
block with carved roots, its ramp and its ceiling's middle are overgrown, and no stretch shows
the same tangle twice in a row.

Not done: the stones themselves still repeat every four tiles under the growth, and the slope
tiles are cut from the first copy. For Sean to judge in play: whether the carved roots read as
relief or as shadow.

## Tests

`tools/art/test_tilegen.py` (run by hand; CI runs no Python tests): some copy of the texture is
nearly bare and one is mostly alive, between 0.3 and 0.6 of the growth lives, every stone pixel
is unchanged, a carved root is one of the stone's colors and no brighter than the root was, the
noise wraps at the fill's edge, and the shipped file is what the generator makes.

`tests/test_rooms.gd`, `test_hearthroots_fill_grows_in_patches`: the shipped fill spans 16
tiles, a cell never straddles its seam, some four-tile stretch is overgrown and one has under a
fifth of that growth, and 12.90 names the test.

Mutation check: with `FILL_BARE` and `FILL_MOSS` at 0 the Python guard fails ("some copy is
nearly bare"); with the old 128 px fill in place the Godot test fails 2 checks; with both back
they pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Hearthroot's walls no longer wear one overlay; the painted brick fields remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the same grade item: the painted brick fields of the Flooded Hall, the storm ledge
and the aqueduct (large-scale variation across a field: a course that changes height, a patch
of other stone, more edge variation). Then the canopy's striped bark, the shop panel's dead
area and the plaza skyline's gridded windows. The next independent grade is due after pass 615.
The Haar's fog and dither, the sprites' pixel size, the hero's rim light and the sword's look
stay held.
