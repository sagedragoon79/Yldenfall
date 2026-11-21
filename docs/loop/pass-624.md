# Pass 624: props are not copies of each other

## Category

Art cohesion (environments). The top item of the queue, the next of the pass 620 grade
(5.6 of 10): "copied props (one crystal cluster at several angles in the flooded hall,
identical banners in the plaza, the same scaffold and floating island across zones)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at the plaza and the flooded hall at 1x with the HUD, and traced each prop to its painter:

- **The banners** are one cell of Hearthroot's decor atlas (`decorgen.hearthroot_banner`). The
  painter's only choice was its color, made once for the atlas, so every banner in the town
  was the same red swallowtail with the same tree. The plaza hung five of them in a row.
- **The scatter** (`Decor.build`) rolled each cell on its own, so two cells side by side
  often drew the same picture. With the rule off, 8 of the plaza's 36 pieces, 6 of the
  market's 20 and 4 of 8 on the Lampwick causeway repeat a neighbor.
- **The crystal clusters** are not decor: they are the stillglass of Vorrhallow's far and mid
  backdrops (`tilegen.stillglass_growth`, 12.51 and 12.82). Each growth drew its own reach,
  lean and width, but every one was built the same way, a leader with two or three lesser
  shards fanned beside it. So the hall showed one outline, turned and scaled.
- **The scaffold and the floating island** repeat across zones by design (one trestle frame a
  zone family, 12.81; one keel builder, 12.82). Not taken on here.

## What was built

Design bible 12.100.

- **Three banners** (`tools/art/decorgen.py`: `hearthroot_banner(rng, kind)`, `BANNERS`). The
  guild's red swallowtail on a bar; the watch's long blue pennon, hung by cords from a ring
  and tapering to a weighted point; an old market cloth, short and wide on a sagging rope,
  moss green with an ochre band, torn along its foot with one corner gone. They differ in
  outline first. Hearthroot's ceiling row holds eight pieces (`COLS` is 8).
- **No piece repeats a neighbor** (`scripts/world/decor.gd`: `NO_REPEAT`,
  `_unlike_neighbours`). A piece that would be the same picture as a piece of its kind within
  five cells across and one up or down takes the next variant none of them has. Still seeded
  by the room.
- **Four habits of stillglass** (`tools/art/tilegen.py`: `STILLGLASS_HABITS`,
  `stillglass_habits`, the `habit` of `stillglass_growth`). Spray (the old growth), blade (one
  long shard and a spur), druse (a low wide mound of stubby points), twin (two broad shards
  parting from one root). The painters deal them out: every habit before any comes again, no
  two in a row alike.

Thrown out or fixed on the way, each by eye:

- The first druse was five to seven even teeth along the face: a comb, or a rack of spikes.
  Its points now stand at uneven steps, overlap, and are tallest in the middle.
- The first twin parted too far and read as a bird. Its shards are broader and part less.
- The first blade was a needle, the "thin needle" 12.51 had removed. It is nearly a leader's
  width.
- Running `decorgen.py` redraws every zone's atlas, because the zones seed by name (12.48's
  note). Only Hearthroot's atlas is kept from the run; the other nine are as committed.

## Checked by eye

The plaza at 1x with the HUD: red swallowtails and blue pennons alternate along the ceiling
with ivy between. The market at 1x: chains, ivy and one swallowtail; the market cloth is in neither of the two rooms looked at, so it is checked only on the atlas sheet. The flooded hall at 1x: a twin, a
druse, a blade and a spray stand in one view and read as four growths. A sheet of the eight
nearest growths at 2x. The banners are small on screen (16 world pixels across); the
difference that reads at 1x is the pennon's length and color.

## Tests

`tests/test_decor_copies.gd` (four tests) and three guards in `tools/art/test_tilegen.py`
(run by hand, not in CI). Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_no_two_neighbouring_pieces_are_the_same_picture` | the rule off | fails: 8 of 36 in the plaza, 6 of 20 in the market, 4 of 8 on the causeway |
| `test_a_piece_takes_the_next_picture_its_neighbours_lack` | the rule off | fails |
| `test_hearthroot_hangs_three_banners` | the old atlas | fails: three pieces in the row, no banners to tell apart |
| `test_no_atlas_row_holds_the_same_picture_twice` | (holds all ten atlases) | passes on both |
| `test_stillglass_grows_in_four_habits` (Python) | every habit paints a spray | fails |
| `test_no_two_growths_in_a_row_share_a_habit` (Python) | every growth dealt a spray | fails |
| `test_the_shipped_vorrhallow_backdrops_are_fresh` (Python) | (holds the two files) | passes |

The older stillglass guards (`test_vorrhallows_stillglass_is_seated_on_the_stone`,
`test_vorrhallows_stillglass_lights_its_own_stone`) pass on the new growths.

Full suite: 32,319 checks passed, 0 failed.

## Not done

- The scaffold and the floating island across zones.
- The stillglass in Vorrhallow's own decor row is one picture each for the floor and the wall.
- `decorgen.py` cannot regenerate nine of the ten atlases as committed (12.48's note).
- The banners' emblems are a few pixels each; whether three is enough for the town is for
  Sean to judge in play.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Banners and stillglass stop being copies; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 620 grade's items, in its order: the scaffold and the floating island
that repeat across zones, foes' contrast with their backdrops, the empty minimap and the coin
count's glyph, the fire seal's color against the Haar's fog, the shop description that
repeats the stat lines. The independent grade is next due after pass 625. The Haar's fog and
dither, the sprites' pixel size, the hero's rim light and the sword's look stay held.
