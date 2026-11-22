# Pass 640: the fall breaks where it lands, and the deep water mirrors the room

## Category

Art cohesion and environments. The top item of the queue, from the pass 635 grade: "the
aqueduct's water is a flat teal gradient; the waterfall has no splash or mist".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

- **The fall's foot.** 12.55 gave it every part a fall should have: a plunge, mist, foam, spray
  and rings. At 1x none of them read. The foam was a strip two or three pixels high, the mist
  three bands at 0.1 that stopped 16 px up the sheet, the spray six specks, and the plunge three
  pale boxes stacked like a ladder.
- **The water.** `SwimWater`'s body is a dithered depth with caustics and a swell (12.39,
  12.97). Nothing standing over it shows in it, so the band under the arches was one flat teal.
  Pass 639 gave Vorrhallow's tide a mirror; the deep water had none.

## What was built

Design bible 12.116, in `scripts/world/aqueduct_spill.gd` and `scripts/world/swim_water.gd`.

- **A boil.** Nine rounded lumps of white water across 21 px either side of the fall, over a
  pale band, shaded at the foot and each heaving on its own beat. The middle stands up to 12 px.
- **Spray on arcs.** Fourteen drops leap up to 24 px and out to 30 px, both sides, and fall
  back into the boil.
- **Mist that climbs.** Five rounded flat bands at 0.07 each, 68 px wide at the foot and 46 px
  up the sheet at the top; puffs break off, swell and drift up 54 px as they thin.
- **Foam lace** drifts off the boil along the surface to 64 px, past the rings.
- **A cone under the surface.** Four rounded bands at 0.13 each, narrower and deeper each step
  to 38 px down; 18 bubbles are driven to its tip and wander back out.
- **The deep water mirrors the room.** `SwimWater` lays the tide's mirror shader over each run of
  its surface cells, at 0.45 under open air and half that under a roof, drawn behind its crest
  and caustics.

Thrown out on the way:

- **Plume bands as plain boxes** (the first try, alphas 0.42 to 0.12). They read as a pale
  ladder under the fall. Rounded and laid over each other instead, like the mist.
- **A heave of 0.55 to 1.0 on the lumps, with the edges at 35% of the height.** At some moments
  an edge lump stood over the middle and the boil read as a row of teeth. The heave is now 0.7 to
  1.0 and the edges a quarter of the height, so it is always a mound.

## Checked by eye

At 1x and 3x in `sunken/drowned_aqueduct`, the fall's foot before and after and the water by the
first pier (the lit band of the far wall now lies in the water's top rows).

## Tests

In `tests/test_aqueduct_fall.gd`: `test_the_fall_boils_where_it_lands`,
`test_spray_is_thrown_up_and_falls_back`, `test_lace_drifts_off_and_mist_climbs_the_fall` and
`test_the_plunge_is_a_cone_of_white_water`. In `tests/test_water_edge.gd`:
`test_the_deep_water_mirrors_what_stands_over_it` (four runs in the test pool, one mirror each,
spanning it under the line to the row's floor, drawn behind the front, the tide's shader, every
surface cell covered once, a run lit or shaded all along, dimmer under a roof, on the water's
clock).

| Mutation | Result |
| --- | --- |
| the deep water lays no mirror | fails (5 checks) |
| no dimming under a roof | fails (1 check) |
| runs ignore the roof | fails (5 checks) |
| a flat boil (every lump the same height) | fails (tallest in the middle) |
| spray that leaps 8 px | fails (it first passed: the check scaled with the constant; it is absolute now) |
| spray that dips under the surface | fails (49 checks) |
| the plume a column, not a cone | fails (1 check) |
| the old mist, 16 px high | fails (climbs a third of the fall) |

## Full suite

FULL_SUITE

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The fall boils, sprays and mists where it lands, and the deep water mirrors the room; the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One screen read per surface run in the Sunken Spring's four rooms. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (after pass 640). Then its top unheld items; still queued from
the pass 635 grade: light that shapes the surfaces it falls on, the town skyline and the Spires'
bands, uniform tile fills, a second ceiling pitch and the plank's board. The Haar's fog and
dither, the sprites' pixel size, the hero's rim light and the sword's look stay held.
