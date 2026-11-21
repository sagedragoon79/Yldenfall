# Pass 625: a zone's rooms do not share one scaffold, one island or one view

## Category

Art cohesion (environments). The top item of the queue, the part of the pass 620 grade's
copied props that pass 624 left: "the same scaffold and floating island across zones"
(storm ledge, Spires hit, canopy bridge, root shrine).

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at the four rooms the grade named, at 1x, and traced each copy to its cause:

- **The floating islands.** The storm ledge and the Fallen Bridge showed the same five sky
  islands in the same places. They are the Spires' mid backdrop layer, one painting for the
  zone, and every room started it at the same spot. This holds for every zone and layer: two
  rooms of a zone opened on the same view.
- **The islands themselves** were one build, a wedge (a main point and lesser ones beside it),
  at six sizes.
- **The scaffold.** Pass 604 gave each zone family its own frame, but the Heartwood, the High
  Boughs and the Spires shared the lashed one, so the root shrine and the canopy bridge stood
  on the same build.
- `StoneKeel`'s keels (the play layer's floating stones) are only in the Spires and already
  differ by seed. Left as they are.

## What was built

Design bible 12.101.

- **A room shows its own stretch of the backdrop** (`scripts/world/backdrop.gd`: `set_room`,
  `room_shift`, `SHIFT_STEP`, `SHIFT_SALT`; `World` calls it on every room). Each room slides
  the far, ridge and mid layers along their repeating art, each by its own multiple of 16 px,
  from an MD5 of the room's id and the layer's name. The foreground is not slid.
- **Four builds of sky island** (`tools/art/tilegen.py`: `ISLAND_HABITS`, `island_spurs`,
  `ISLAND_DEPTH`, `deal_habits`, `SPIRES_ISLANDS`). Wedge, shelf, fang and twin, dealt so every
  build turns up and no two neighbors match. The islands stay where they were. The stillglass
  dealer of pass 624 now uses the shared `deal_habits`.
- **Two new trestles** (`scripts/world/plank_supports.gd`: `_forked_parts`, `_pier_parts`).
  The Boughs prop the board on forked limbs, bound with vine and still in leaf. The Spires
  stand it on stone corbels and coursed piers, in the city's lilac stone (their footing
  stones change to it too). The Heartwood keeps the lashing.

Thrown out or fixed on the way, each by eye:

- The first shift hashed the names with a small rolling hash; two pairs of rooms got the same
  three shifts, because one layer's shift followed from another's. MD5 fixed that.
- The unsalted MD5 put the two graded Spires rooms on the very same mid shift (a 1 in 40
  chance). `SHIFT_SALT` is chosen so they start 304 px apart; a test holds it.
- The first fang was a nail: a thin lip on a needle. Its tooth is broader and its belly deeper.
- The first twin read as a table on two legs. Its points are broader over a deeper saddle.
- The first forks reached the next trunk's limbs, so the row read as a truss web again. The
  limbs stop short now, and each fork stands alone.

## Checked by eye

The storm ledge and the Fallen Bridge at 1x: different skies, and a shelf, a twin, a fang and
a wedge in one view of the ledge. The canopy bridge at 1x and 2x: eight forked trunks with
sprigs, no rail. No Spires room looked at holds a framed run, so the piers were judged at 2x
on the canopy bridge's run drawn with the Spires' look (a colonnade with corbels at the ends).
The old and new mid layers side by side on a sheet.

## Tests

`tests/test_backdrop_room_shift.gd` (four tests), the two new styles in
`test_plank_each_zone_family_frames_its_own_way`, and three guards in
`tools/art/test_tilegen.py` (run by hand, not in CI). Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_backdrop_shift_a_room_slides_each_layer_its_own_way` | every shift 0 | fails |
| `test_backdrop_shift_the_graded_spires_rooms_show_different_islands` | every shift 0 (and the unsalted hash) | fails: 0 px apart |
| `test_backdrop_shift_no_two_rooms_of_a_zone_show_the_same_backdrop` | every shift 0 (and the rolling hash) | fails |
| `test_backdrop_shift_the_world_slides_the_backdrop_for_the_room_it_enters` | `World` never calls `set_room` | fails |
| `test_plank_each_zone_family_frames_its_own_way` | the Boughs and the Spires lashed again | fails: two styles unused, three zones on one |
| `test_a_sky_island_comes_in_four_builds` (Python) | a fang built as a wedge | fails |
| `test_the_spires_sky_holds_every_build_of_island` (Python) | every island dealt a wedge | fails |
| `test_the_shipped_spires_islands_are_fresh` (Python) | the same | fails: stale |

Full suite: 32,484 checks passed and 1 failed: `test_every_room_loads_and_settles_inside_the_budget`
(`evercrown/proving_scar` settled at 8.27 ms a frame against 8), the wall-clock flake on this
busy PC that passes 599 to 605 also met. Run alone twice afterwards, it passed both times. This
pass adds no work to that room (no forked or pier frame, one `scroll_offset` set per room
load); CI is the gate. The Python painter guards: 102 passed.

## Not done

- `StoneKeel`'s keels are one build (a wedge). They differ by seed and only the Spires have
  them; a habit for keels would be the next step if a grade names them again.
- No Spires room looked at holds a framed run, so the piers are unseen by me in a real room.
  They show wherever a Spires plank run stands on two posts 40 px or more above a floor.
- The Heartwood's lashed frame is as it was.
- The shift is by room: the sky changes at a door, as any room change already changed the
  view.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Rooms, islands and trestles stop being copies; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (after pass 625). Then the rest of the pass 620 grade's
items, in its order: foes' contrast with their backdrops, the empty minimap and the coin
count's glyph, the fire seal's color against the Haar's fog, the shop description that
repeats the stat lines; and whatever the new grade names. The Haar's fog and dither, the
sprites' pixel size, the hero's rim light and the sword's look stay held.
