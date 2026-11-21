# Pass 623: a tier ends block by block

## Category

Art cohesion (environments). The top item of the queue, the first of the pass 620 grade
(5.6 of 10): "brick and earth carry large rectangular dark blotches and stair-stepped tone
patches that look like tile errors, not weathering (aqueduct, canopy bridge, flooded hall,
storm ledge)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at the four named rooms at 1x with the HUD and measured the atlases:

- **Not the patches.** The patches of other stone (12.91) average within a twentieth of the
  field tiles of their tier in all three patch zones.
- **The tiers.** A wall's three tiers are a whole palette shade apart (the Sunken Spring's
  field tiles average 128, 95 and 68; the Boughs' 137, 100 and 64) and met along the tile
  grid. Inside a pier or a ceiling the shade was a stair of rectangles.
- **A patch in a darker tier** inside a lit pier (the aqueduct's feet) was a dark box of thin
  courses: the loudest of the "rectangular dark blotches".
- 12.95 had left this open: "a tier's edge still follows the tile grid ... softening it needs
  drawn transition tiles".

## What was built

- **Blends** (`tools/art/tilegen.py`: `tile_blocks`, `paint_blend`, `paint_blends`). Row 9 of
  every generated atlas, cols 2 to 7: field tiles in which each block (a brick, a plate of
  bark, a cobble, found as a stretch of body bounded by joints) stands in one of two
  neighbouring tiers. Three blend the surface and MID, three MID and DEEP.
- **Half and half.** The dark blocks are the first of up to 400 seeded draws that come within
  15 percent of half the area in the tile and in each of its four halves, so no half of a
  blend is one tier.
- **Big blocks.** A block over three tenths of a tile (Vorrhallow's upper course, a Tower
  plate, wood grain) is cut into soft-edged blobs instead.
- **Where** (`Room._blends`, `TilesetFactory.ground`, `BLEND_MID`, `BLEND_DEEP`,
  `has_blends`, `is_blend`, `tier_of`). A cell of a darker tier that touches a lighter one
  draws the blend. A blend cell is never a patch.

Thrown out or fixed on the way, each by eye or by a measure:

- Big blocks were first cut into square cells: the Tower's plates and Heartwood's grain came
  out as boxes. They are blobs of value noise now.
- Half the blocks by count is not half by area: some blends stood at 0.15 or 0.8 of the way
  between their tiers, and several had a half wholly in one tier (a line the width of the
  tile, the defect over again). The draw is now scored on area in five parts.
- The best-scoring draw is the same draw for a stone of few blocks: the Evercrown's three
  blends were one tile. A draw must differ from the tier's other blends over a fifth of the
  tile.
- Vorrhallow's tide stain across blocks of two tiers read as a dashed teal rule: blends
  carry none.

## Checked by eye

The four named rooms at 1x and three crops at 2x, beside the pictures from before; and at 1x
`heartwood/deep_roots`, `haar/marsh_road`, `evercrown/proving_scar` and `tower/gear_pit`. The
aqueduct's piers lose their dark boxes and the canopy's earth darkens plate by plate; the
storm ledge's rectangles are scattered dark blocks. Vorrhallow and the Tower are mottled
(blobs on their big blocks): softer than the slabs, and not rectangles.

## Tests

`tests/test_tier_blends.gd` (four tests). Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_the_named_rooms_blend_their_tiers` | `Room._blends` always false | fails: no blends, and 145 to 347 hard tier edges a room |
| `test_a_blend_stands_between_its_two_tiers` | the old atlases | fails (no blends in any zone) |
| `test_no_half_of_a_blend_is_one_tier` | the old atlases; also the first painter, which chose by count | fails |
| `test_a_darker_cell_beside_a_lighter_tier_draws_a_blend` | (holds `ground`'s contract) | passes on both |

Changed with it: `test_autotiles_match_their_neighbours` (a floor three rows thick now blends
row by row) and `test_tier_specks.gd` (a blend counts as the tier of its cell).
`tools/art/test_tilegen.py` (run by hand, not in CI): `test_a_blend_holds_two_tiers_block_by_block`
and `test_the_shipped_atlases_carry_their_blends`; 96 checks pass.

Full suite: 32,053 checks passed, 0 failed.

The first full run failed `test_every_room_loads_and_settles_inside_the_budget` (two rooms
at 501 and 554 ms against 500) and, under that load, three other timing checks that pass on
their own. The cause was older than this pass: `Room._depth` returned
`_tiers.get(cell, _raw_depth(cell))`, which works the fallback out on every call (up to 25
lookups), and a blend asks for five cells' depths. It now looks the tier up first. The
slowest room loads in 396 ms (`evercrown/proving_scar`).

## Not done

- A blend is not directional: the band is an even mix, not a gradient toward the dark side.
- A block that runs through a tile seam can change tier at the seam.
- `DeepShade`'s dithered falloff over the deepest mass (the aqueduct's middle pier) is
  unchanged: it is part of the held dither item.
- Whether the blobs on Vorrhallow's and the Tower's big blocks are too mottled is for Sean
  to judge in play.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | A wall's tiers meet block by block; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 620 grade's items, in its order: copied props (one crystal cluster at
several angles in the flooded hall, identical banners in the plaza, the same scaffold and
floating island across zones), foes' contrast with their backdrops, the empty minimap and the
coin count's glyph, the fire seal's color against the Haar's fog, the shop description that
repeats the stat lines. The independent grade is next due after pass 625. The Haar's fog and
dither, the sprites' pixel size, the hero's rim light and the sword's look stay held.
