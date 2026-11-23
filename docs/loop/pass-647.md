# Pass 647: what the deep holds

Date: 2026-11-23. No new notes from Sean. From the queue, first item: the independent grade of
pass 645 (5.2/10). Pass 646 took its fight contact points; the items before them are held (the
Haar's render, the sword's bar, the hero's size) or belong to the art loop (foes in three styles).
This pass takes the next: "dead voids (the grub burrows' black top half, the Evercrown veins' flat
purple)".

## Audit

The two voids have different causes.

- **The grub burrows.** The room's upper left is a 36 x 11 block of solid mass over the long
  tunnel. `DeepShade` (12.38) sinks every cell more than about six tiles from air to 86% of a
  near-black, so at the top of the room view the frame was a band of flat black with a few motes
  in it. The same flat dark fills `evercrown/proving_scar` (the pass 550 grade's "over half the
  screen is empty void", left then as a room-layout item), `trials/stillness`, `trials/falling`,
  `tower/old_flue` and `vorrhallow/waterfall_stair`, the rooms with the most deep mass.
- **The Evercrown veins.** The flat purple is the ridge layer's near plane: under its crest of
  shards it is one solid fill down to the layer's foot, so in a tall room a band of the backdrop
  between the hanging tendrils and the floor is a single value. This pass leaves it for the next
  (see Next).

## What changed

- **What the deep holds** (`DeepShade.MOTIF`, `MOTIF_COLORS`, `_build_motif`). Over the full shade,
  each zone's buried matter shows faintly, in 2-pixel blocks, a dark body with a dim lit edge:
  roots hanging from the top of the deep mass in the woods and the marsh (tapering from 6 to 2
  pixels, one per three columns, some forking), zigzag crystal veins with glints in the two crystal
  halls, broken bedding seams in the stone zones. Only where the field is at least 0.8, fading in
  from there; seeded by the room's id; none in a secret's cells.
- `Room` passes its zone and id to both shades (and again when a guardian tears the floor).
- **The bible:** 12.123, and 12.42's note that the void was left as a room-layout item.

## Checked by eye

`heartwood/grub_burrows` at 1x and 2x: the first try (random starts, 2 to 4 pixel strokes) read as
red scribbles and crossed X shapes; roots now hang from the top of the mass, evenly spread, and
taper as they fall, so the band over the tunnel reads as dark soil with roots through it, of a
piece with the hanging frame (12.121) above. `evercrown/proving_scar`: the first veins curled like
worms and were too many; they are now a third as many and zigzag like cracks. `tower/old_flue`:
level seams with lit lips, faint. `vorrhallow/waterfall_stair`: blue cracks. Rooms with no deep mass
are unchanged.

## Tests

`tests/test_deep_shade.gd`: `test_the_deepest_mass_holds_its_zones_forms` (forms in the Heartwood,
the Evercrown and the Tower; every block where the shade is at or near full; between 1.5% and 30%
of the deep mass; strokes at least two tiles long; roots run down, seams run level; a root is warm,
a vein violet) and `test_the_deep_forms_are_the_rooms_own_and_only_where_meant` (no zone or the gym:
none; the same seed draws the same forms, another seed others; none in a secret's cells). The room
test checks a built Evercrown room's mass holds forms.

| Mutation | Result |
| --- | --- |
| forms drawn down to the lit edge (`MOTIF_FROM` 0) | fails (2 checks) |
| no forms drawn | fails (11 checks) |
| roots run sideways | fails (1 check) |

## Load cost

The first full suite failed one check: `trials/stillness` loaded in 502 ms against the 500 ms
budget of `test_every_room_loads_and_settles_inside_the_budget`. That room holds the most deep mass
in the game (1,557 cells), so the forms were part of it, not only the machine's load. Measured alone
(`ROOM_REPORT`), against main: stillness 417 ms (main 346), `tower/old_flue` 345 (293). Seams are now
half as many per deep cell and a room builds at most 60 forms (`MOTIF_MAX`). Then: stillness 381,
`trials/falling` 271 (237), `tower/old_flue` 303 (293), `evercrown/proving_scar` 456 (450, already the
closest to the budget on main). Building the forms takes at most 14 ms in any room (about 4,000
blocks in the Trials), once per load.

## Full suite

Pending.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The deepest mass shows its zone's roots, veins or seams instead of flat black. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Up to 14 ms more at a deep room's load, at most 60 forms a room. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The Evercrown's flat purple: the ridge's near plane under its shard crest is one fill to the
layer's foot (`tools/art/tilegen.py`, `ridge`, kind "shard", shared with Vorrhallow); give it forms
of its own (crystal masses with lit faces, glints), as pass 642 did the Heartwood's. Then, from the
pass 645 grade in its order: walls that end mid-air at the screen's edge; barcode stripes in the dirt
tiles; copied hazards and cloned town towers; floating islands and chain platforms hung from nothing;
the Spires' rain too heavy; an oversized minimap; the spark's size at this scale. Held as before: the
Haar's render, the sword's flat bar, the hero's size; foes in three styles stays with the art loop.
