# Pass 595: every zone houses its own chest

## Category

Art cohesion and world, from the independent grade taken after pass 585 (5.3 of 10): "repeated set
dressing: the same chest on the same thin table and the same sign in nearly every room". Pass 594
named it next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for a
watched session. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- **The chest.** One brown domed trunk stood in all 68 chest cells (`$`) across ten zones, drawn in
  nine colors of which only the outline was a master palette value.
- **The table.** 24 of the 68 chests stand on a one-way plank, 44 on solid ground. Passes 575 to 590
  already moved the canopy bridge's and the crags' chests off their tables (tests
  `test_the_chest_stands_on_a_bough_not_a_table` and `..._on_a_crag_not_a_table`). The planks are
  platforms the routes need, so this pass leaves them.
- **The sign.** Pass 539 already gave each zone its own stele (bible 12.31): five silhouettes in
  eleven looks. Not changed.

## What was built

`Chest` (bible 12.80) draws a chest in its room's zone look. `Room` hands the chest its zone, as it
does a sign's. Eight kinds:

| Zone | Kind |
| --- | --- |
| Gym, Trials | Domed oak trunk, brass band, iron corners |
| Heartwood | Root coffer: red root-wood, moss on the lid, roots coiled round its feet |
| High Boughs | Woven hamper: wicker, leaf strap, flat lid, cane handle |
| Haar | Sea chest: salt-grey driftwood, tarnished bands, rope handle, barnacles |
| Hearthroot, Sunken, Vorrhallow | Dwarf strongbox: riveted stone, overhanging lid, zone metal band |
| Tower | Ore crate: boards and two iron straps |
| Spires | Sandstone reliquary: carved arcade, pitched roof, gold finial |
| Evercrown | Geode casket: violet stone, cyan crystal shards through the lid |

Each lock glows in its zone's accent. The chest is now data (`Chest.parts`, half-pixel rects), so
the tests read exactly what is drawn. Every tone is a master palette value.

Judged by eye on a contact sheet of every zone at 2x and 4x (new: `tools/art/chest_sheet.tscn`,
closed and open), and in game at 1x in `boughs/leaf_landing` (the hamper reads clearly on its
plank) and `haar/marsh_road` (the sea chest; the Haar's fog still greys it, the held fog item).
The first ore crate drew its last board line a pixel under the ground; the new test caught it.

## Tests

`tests/test_chest.gd`: every zone has a look, every look a known kind, and every tone drawn is a
palette value; the zones use at least seven kinds and no two kinds draw the same silhouette; every
part stays in the chest's box and on its ground line, the lock's light sits on its plate, and
opening changes the shape; a room's chest takes its zone.

Mutation check, each restored from a copy after: every zone a trunk fails it (9 checks); the room
not handing over its zone fails it (2 checks); an off-palette inside tone fails it (11 checks).

Full suite: 21,228 checks passed, 0 failed. (The first run failed 44 checks in five tests that read the bible: this pass had saved it with Windows line endings. Saved with LF, those five tests pass on their own.)

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | A chest belongs to its zone. |
| Art cohesion | 15 | 98 | Chests are in the palette and per zone; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (every fifth pass): take it after this merge and queue its top
defects. Then, from the queue: the grid item's leftovers (the plaza's chest table and flat grey
city). The shop's plain panel and crude portrait stay with the pass 584 shop item. The sword's look
and the Haar's fog stay held.
