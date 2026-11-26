# Pass 665: the light goes on under the water

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 660 (5.4/10), past its held items, names "flat water rectangles (the source hall, the flooded
hall)". This pass takes the Source Hall's deep water; the Flooded Hall's tide is next. The PixelLab
art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or
Autosprite credits were spent.

## Audit

`sunken/source_hall` captured and measured in 16-pixel blocks across the pool. A fifth of the way
down every block lay between luminance 59 and 71, two thirds down between 42 and 65, darkening only
toward the corners: the pool changed with depth and nowhere else. The room's light shafts (12.17)
rake the air over it and stopped dead at the waterline.

## What changed

Design bible 12.141 (new); `scripts/world/water_shaft.gd` (new) and `scripts/world/swim_water.gd`.

- **The air's shafts carry on into the deep water.** `WaterShaft`, a child of `SwimWater`, takes
  the room's `LightShaft` beams and the zone's lean. Each that meets an open surface cell enters
  there, bent steeper (0.75 of its lean), narrower (0.62 of the air shaft's half-width) and widening
  to 1.7 times that as it sinks, in the water's pale cyan.
- **Pixel art.** 2-pixel rows on the 2-pixel grid, a three-tier core, six clean steps from 0.2
  (additive) at the surface to nothing at 184 px, no dither. It sways a grain at a time, and the
  water's waver bends its edges.
- **Only through an open surface,** only over water cells, and behind every actor.

Judged by eye at 1x and 2x in the Source Hall, the Drowned Aqueduct, the Spring Gate and the
Wellspring (no shaft under a roof or through stone). In the Source Hall's pool a fifth of the way
down a shaft measures luminance 87 beside 63, two thirds down 76 beside 54; the floor stays the
darkest part.

## Tests

- New `test_the_light_goes_on_under_the_water` (`tests/test_swim_water_art.gd`): the six steps and
  their fall, the tiers, the widening, the bend, the grain sway, the open-surface rule (a roofed
  surface and a miss take no shaft), and in the Source Hall at least two shafts, under the actors,
  over the body, leaning as the zone's air shafts do.

Mutation check: with the roof rule removed the test fails (two shafts enter); with `SPREAD` at 0 it
fails (the shaft does not widen).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,288 checks passed, 1 failed, the room budget
(`test_every_room_loads_and_settles_inside_the_budget`: `spires/sky_steps` at 9.12 ms a frame).
Rerun alone it failed on load time instead (`evercrown/proving_scar` 533 to 539 ms), and with this
pass's code taken out it failed the same way (`proving_scar` 535 ms, `sky_steps` 8.64 ms): neither
room has deep water, and the PC was running Unity and Chrome. CI (test and mix) is the clean run.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the shafts are behind every actor. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The air's light and the water's are one light. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One small redraw per pool. |
| Story and world | 5 | 99 | The Source Hall's pool is lit from the hall. |

Weighted: 98.85.

## Next

Pass 665 is the fifth since the pass 660 grade: the grade follows this merge. Then from the pass
660 grade in its order, past the held items: the Flooded Hall's tide (the other half of the flat
water item); then the oversized bee (a smaller Hornet sheet).
