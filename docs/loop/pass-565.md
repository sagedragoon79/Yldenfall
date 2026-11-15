# Pass 565: floors and ceilings get edge variants and a trim of their zone's material

## Category

Art cohesion and environments, from the independent grade taken after pass 560 (4.9/10):
"Heartwood, Vorrhallow, Evercrown, Tower: one terrain tile repeated without variation in thick
floor and ceiling bands, with no edge pieces, cracks or trim."

No note from Sean was new. The queue's items before this one are parked for a watched session
(lighting and depth, rim light, the hero's size) or wait on the Haar branches and on Sean's OK of a
base. Pass 564 named one-template rooms first; this item was taken ahead of it because it is a
single generator change that reaches every room of ten zones, where the room item is layout work
room by room. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- The fields scatter over variants (12.8, 12.45), but `TilesetFactory.ground` returned one tile
  for every non-full mask. A floor's top row and a ceiling's bottom row, the rows the eye rests on,
  were one tile from end to end. `tests/test_tileset_factory.gd` held that as a rule.
- Only the masonry zones had a built line under a floor's cap (the string course, 12.46 and 12.47).
  The Heartwood, the Tower, the Evercrown, the Haar and the High Boughs went from the cap straight
  into the field.
- No zone drew anything on the underside of a ceiling but an outline and a dark lip. Vorrhallow
  had the course on its floors when the pass 560 grade was taken and still drew the remark: its
  ceilings were bare.

## What was built

- **Edge variants** (`tools/art/tilegen.py`, row 8 of every painted atlas): three more top tiles,
  three more bottom tiles and one more of each wall face. `TilesetFactory.ground(mask, cell, depth,
  edges)` scatters a straight edge over its base tile and its variants; `has_edges(zone)` is false
  for Hearthroot's PixelLab atlas, which is untouched. Corners stay one tile.
- **A trim in the zone's material** (`TRIM_KIND`, `trim_band`): a rind on wood (the Heartwood, the
  High Boughs, the Haar), notched where two strands meet; a riveted flange on the Tower's iron; a
  skin on the Evercrown's cells, lit by the pores and pinched every 8 pixels. A wall stands on it as
  on a course (`footing` now takes any zone's trim).
- **A soffit** on the bottom tile of every ceiling, in all ten painted zones: the same three rows,
  a step or two into the shade. A ledge one tile thick gets none.
- The Evercrown's cells are the same in every tile, so its variants were copies (a new test found
  it). An edge variant now opens more pores (`MEAT_EDGE_PORE`).
- Design bible 12.53.

Looked at before and after, at 1x and 3x: `heartwood/rootbound_hall`, `evercrown/veins`,
`tower/smelter`, `vorrhallow/flooded_hall`, and at 1x `haar/marsh_road`, `boughs/canopy_bridge`,
`spires/sky_steps` and `sunken/drowned_aqueduct`. The trims join across every run; the Tower's
ceiling and Vorrhallow's ceiling now end in a built line.

## Tests

`tests/test_edge_trim.gd` (six tests): a long edge uses its base and every variant with no beat,
and does not vary without the row; every painted zone has the tiles, they are not copies, and
Hearthroot has none; a room lays them along a floor and a ceiling and they are solid; every zone's
floor trim is one lit line over one shadow line in every variant, and no tile inside a wall has it;
the same for the soffit, dimmer than the floor's trim, and absent from a thin ledge; iron, bark and
the Evercrown's cells trim in different colours with a broken band, and the trim carries on under
a wall's foot. `test_tileset_factory.gd` and `test_rooms.gd` are updated for the reversed rule.

Mutation check: a factory that ignores `edges` fails ("draws its base tile and every variant",
"the floor's top row uses its base tile and three variants"); no soffit fails ("the soffit is one
lit line and one shadow line"); no trim in the grown zones fails ("the floor's trim is one lit
line" and "the trim carries on under a wall's foot"); a soffit on every bottom tile fails ("a
ledge one tile thick has no soffit"). The generator was restored and the atlases checked byte for
byte against the ones looked at.

The first full run failed two older tests, both rightly: `test_tiles_are_drawn_at_double_density`
held every atlas to eight rows (it now allows nine), and
`test_the_evercrowns_tiles_stand_off_its_wine_haze` found the Evercrown's trim band on `night-3`,
the violet rim that 12.50 removed. The band is now `sky-2` (the soffit's `sky-1`) and the pinch is
a shadow, looked at again at 3x.

Full suite, second run: 15718 checks passed, 3 failed. All three are wall-clock frame budgets
(`test_spires_rain_stays_cheap`, `test_every_boss_fight_holds_the_frame_budget`,
`test_every_foes_spoils_rest_in_its_room`) measured while other programs were busy on this PC.
All three passed in the first full run on the same game code, and each passes when run alone
afterwards. Nothing in this pass draws more per frame: a cell still draws one tile.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Every painted zone ends its floors and ceilings in a line of its own material, and no edge is one tile repeated. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

An independent grade is taken at the end of this pass (the fifth since pass 560). Of the queue:
one-template rooms, then the Sunken Spring's pillars and water, then cracks in the grown zones'
fields (left from this item). The test runner's shared `user://` (found in pass 563) is worth a
short tooling pass while other worktrees run on this PC. The Haar items wait until the hydra and
steam branches merge; the Blinkhop waits for a free base slot.
