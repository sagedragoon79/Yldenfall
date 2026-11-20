# Pass 614: a wall is relaid in patches

## Category

Art cohesion, and world and level design, from the independent grade taken after pass 610 (5.6
of 10): "terrain tiles repeat visibly: uniform brick and cobble fills ... little edge variation
(plaza, flooded hall, storm ledge, aqueduct)". Pass 613 did the plaza. This is the rest of the
item, and it was the top of the queue.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The three rooms are painted tiles in three zones (Vorrhallow, the Spires, the Sunken Spring).
Their fields already scatter variants: the head joints move, a block is worn or cracked, moss
sits in a joint, the tiers darken with depth (bible 12.8, 12.45, 12.55, 12.70). Looking at the
rooms at 1x, what repeats is not a tile but the **coursing**: every tile of a zone has the same
course heights, so a ceiling or a floor thirty tiles long is one texture from end to end. No
amount of variant scatter changes that.

A patch of another value was ruled out: 12.45 took the two-value checker out of these same
fields. The variation here is in how the wall is laid, not in how light it is.

## What was built

- **A second coursing per zone** (`tilegen.PATCHES`, `paint_patch`): small brick in Vorrhallow
  (four courses to a tile where the usual is two), great blocks in the Spires (two courses for
  three, no gold), thin courses in the Sunken Spring (three for two). Each in the zone's own
  tones and line weight, one body value.
- **Laid in stretches** (`TilesetFactory.in_patch`): a slow value noise over the cells, wide and
  low, about a quarter of a field. Only a cell inside the wall is drawn as a patch, so every
  edge, cap, trim and corner is unchanged.
- **A patch closes its blocks where it stops**: the tile at a patch's west or east end carries
  a head joint down that edge. `Room._ground_tile` asks the neighbours; the four places that
  laid a ground tile now go through it.
- **The atlas**: rows 10 to 12 of the three zones' atlases (24 tiles each: three tiers, two
  variants, four ends). Atlases of ten rows have no patches, so no other zone changed.
- Bible 12.91 (new).

Judged by eye at 1x and 3x in the Flooded Hall, the storm ledge and the drowned aqueduct: the
Flooded Hall's ceiling has stretches of small brick between its squat blocks, the aqueduct's
pier and ceiling have thin-coursed stretches, and the storm ledge's left wall has great blocks.
The joints close at every patch end. The change is clearest in Vorrhallow and the Sunken
Spring; in the Spires the great blocks are close in scale to the ashlar and read more quietly.

Not done: Hearthroot's stones, the gym, the Inner Rings and the Tower keep one coursing. The
darker tiers still step by the tile, which is now the louder tell in the Flooded Hall's
ceiling (single dark tiles inside the field). For Sean to judge in play: whether the small
brick in Vorrhallow reads as a repair or as noise.

## Tests

`tools/art/test_tilegen.py` (run by hand; CI runs no Python tests): each coursing fills a tile
and is not the zone's usual one, a patch tile uses only its stone's colors, no joint sits at a
tile's edge unless an end is asked for, the small brick does not stack its joints, and the
shipped rows are what the generator makes.

`tests/test_stone_patches.gd` (new, four tests): the noise covers 15 to 40 percent of a field
in patches wider than tall; a patch tile is its tier's row and its ends' column; the three
atlases carry the rows with the right bed joints, end joints, tiers and body value, and four
other zones have none; in the three rooms some of the wall is patch, most is not, every patch
cell is inside the wall and has its end joints exactly where the patch stops; 12.91 names the
test.

Mutation check: with `PATCH_LEVEL` at 2.0 (no patches) 6 checks fail; with the end joints not
asked for 3 checks fail (34, 37 and 57 cells wrong in the three rooms); with both back all
pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Three zones' fields carry a second coursing; the tiers' tile steps remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The same grade's remaining unheld items, in order: the canopy's striped bark terrain, the shop
panel's dead area and no comparison with equipped gear, and the plaza skyline's gridded
windows. Seen in this pass and worth an item: the darker tiers step by the tile, so a single
dark tile sits inside a lit field (the Flooded Hall's ceiling). The next independent grade is
due after pass 615. The Haar's fog and dither, the sprites' pixel size, the hero's rim light
and the sword's look stay held.
