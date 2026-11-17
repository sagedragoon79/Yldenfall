# Pass 588: the Drowned Aqueduct is vaulted, and its arches have broken

## Category

World and art cohesion, from the independent grade taken after pass 585 (5.3 of 10): "rooms are
rectangular boxes (Boughs canopy bridge, Vorrhallow flooded hall, Spires storm ledge, Sunken
aqueduct): flat ceilings, straight walls, one thick tile border". By design bible 12.63's rule,
one room per pass; pass 587 did the Flooded Hall, and this is the second of the four.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) is held, so this pass took the third.
The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no
Autosprite credits. The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- `sunken/drowned_aqueduct` is two screens wide (80 by 23). Its ceiling was ruled flat at row 1
  for the whole room; its two hanging walls (columns 20 to 25 and 52 to 57) hung square to row
  11; its four arch tops were 4-by-6 blocks floating in the flood; its side walls ran straight;
  and the east gallery was a straight shelf. Shot at 1x in its west and east halves: a flat band
  of brick top and bottom, with square blocks between.
- Constraints: the broken channel (`aqueduct_spill` at 40, 1) must hang under the ceiling with
  its fall clear to the water (`test_every_zone_has_its_three_landmarks`, the spill and sound
  tests); you must swim under both hanging walls; the chest, the Grain Shard (31, 7), the eels
  and the doors must not move; the water stands at row 9.

## What was built

`levels/sunken/drowned_aqueduct.room`, tiles only:

- **The vault.** Each of the three bays springs four or five tiles down at its piers and walls
  and rises in one-tile steps to a crown at row 1. The middle bay's crown is over the spill, so
  the channel keeps its ceiling and its fall.
- **The hanging piers** are broken off unevenly at the foot (rows 10 to 12); eight or more rows
  of water stay open under each.
- **The arch tops** are broken wedges: a lip a tile wider than the arch at the waterline,
  narrowing downward in three or more steps. Under each, the arch's pier stands snapped off on
  the bed as a stump with a ragged top, four or more rows below the wedge (the swimmer's height in
  the reachability checker, `Reach.BODY_ROWS`). A little rubble lies
  on the bed under the middle bay.
- **Walls and gallery.** Each side wall has a buttress under the water; the gallery stands on a
  corbel stepping into the east wall.
- Design bible 12.75, and the Sunken Spring summary (section 3) mentions it.

Judged by eye at 1x in the west and east halves, before and after: the room now reads as a
vaulted culvert with broken arches rather than a box. The vault steps a tile at a time, so it
reads as a stepped vault, like the Flooded Hall's.

## Tests

`tests/test_drowned_aqueduct.gd`, two tests:

- `test_the_aqueduct_is_vaulted_and_its_piers_are_broken_off`: the ceiling's underside at five
  heights or more; each bay rises three tiles or more from its feet to its crown and springs low
  at both sides; the spill's column keeps its ceiling at row 1; each hanging pier has a broken
  foot and eight rows of water under it; each side wall has a buttress; the gallery stands on a
  corbel.
- `test_the_arch_tops_are_broken_wedges_over_their_stumps`: each arch top is four rows deep or
  more, narrows downward in three steps or more, and has a stump with a ragged top under it with
  `Reach.BODY_ROWS` (four) rows of water or more between.

The first cut left three rows between two wedges and their stumps; the reachability checker's
swimmer is four rows tall, so the shard, the chest and the Source Hall beyond fell out of reach
(`test_the_turned_wind_reaches_the_thicket_niche`). Those stumps are a row lower, and the test now
holds the gap to `Reach.BODY_ROWS`.

Mutation check, the room restored from a copy and compared byte for byte after each: the room as
it was on main fails both tests (12 checks each); the second arch's stump raised to two rows under
its wedge fails the second (1 check).

Full suite: 18,199 checks passed and none failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The aqueduct has a vault, broken piers and broken arches over their stumps. |
| Art cohesion | 15 | 98 | The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The sign says the aqueduct carries the city down; its broken arches show it. |

Weighted: 98.85.

## Next

In the queue's order: the next two box rooms (the Spires storm ledge, then the Boughs canopy
bridge), one per pass, and the repeated chest and sign; then the grid item's leftovers (the
aqueduct's second face tile, the HUD over the ceiling, the shop panel). The Haar's fog stays
held. The next independent grade is due after pass 590.
