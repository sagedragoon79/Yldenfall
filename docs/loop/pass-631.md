# Pass 631: rain lands, and lightning lights the stone

## Category

Art cohesion (weather). The top item of the queue, the next unheld defect of the pass 625
grade: "the rain is one even overlay with no splash or wet stone, and the lightning lights
nothing" (the storm ledge, the Spires hit).

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the storm ledge at 1x and 4x. Carillon's rain is `SheetRain`: two tiled layers of a
PixelLab sheet drawn across the whole screen in front of the play field (12.71). Nothing in a
room knew it was raining. A drop crossed a floor and went on through it, the top of the ground
was the same dry moss as in any zone, and the three bolts baked into the far layer lit neither
the sky round them nor a single stone.

## What was built

Design bible 12.107. `RainLanding` (`scripts/world/rain_landing.gd`), built by every room of a
zone it rains in (the Spires), draws on the ground the rain can reach:

| Part | What it is |
| --- | --- |
| Wet tops | Level ground or a board with nothing over it for four cells. Under an overhang or a board a top is dry. |
| Wet stone | A broken line of pale sheen along a wet top, a dash or two a cell, shimmering over 2.6 s. |
| Splashes | A streak, a crown 5 px wide, four droplets 7 px apart, in a fifth of a second. About a third of wet cells show one at a time; a third as many in the drizzle after the Sky Spring. |
| Lightning | A far stroke every 3 to 11 seconds: two beats and a fade in half a second. The sky behind the ground lifts by up to 0.16 in the far bolts' hue and every wet top takes a rim. |

The stroke is scaled by the flashes option, and there is none once the Sky Spring has broken
the storm. Splashes and strokes are worked out from the clock and the cell, with nothing stored
per drop. `--storm-at=T` starts the storm's clock at T seconds so a capture can catch a stroke.

Thrown out or fixed on the way:

- The first sheen (0.26) and the first splash (a pixel, three, two) could not be seen: the
  sheen sat in the moss cap and the splash behind the hummocks and the grass. The sheen went
  to 0.6, the splash grew to a 7 px spread, and the layer draws a step over the moss.
- The sky's lift was first the rain's cool white, which turned the maroon sky a grey green. It
  is the far bolts' own crystal hue now, so the light matches what is seen to cast it.

## Checked by eye

At 1x, 2x and 4x: the storm ledge at rest (glints along both floors, a few splashes on each)
and in a stroke (the sky lifts and the arch, the crag and the floors stand dark against it,
each top with a pale edge), the sky steps in a stroke, and the broken shrine at rest. The
splashes are small in a still; they are made to be seen moving.

## Tests

`tests/test_rain_landing.gd`, six new tests, 72 checks. Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_rain_landing_rain_lands_only_where_the_sky_is_open` | a roof shelters nothing | fails (with the Spires rooms' test, 12 checks) |
| `test_rain_landing_wet_stone_is_a_broken_line` | a solid line on every cell | fails (41 checks) |
| `test_rain_landing_drops_splash_and_thin_with_the_rain` | the drizzle splashes like the storm | fails |
| `test_rain_landing_lightning_is_two_beats_seconds_apart` | no dip between the beats | fails |
| `test_rain_landing_lightning_obeys_the_flashes_option_and_the_spring` | the flashes option ignored | fails |
| `test_rain_landing_only_the_spires_rooms_catch_rain` | it rains in every zone | fails |

Full suite: 33,365 checks, all passed in the whole run (pass 630: 33,293), with no rerun.

## Not done

- No thunder: a stroke is silent. Queued as an audio item.
- The stroke lights no figure or prop and casts no shadow.
- The Spires' floating islands are scenery in the backdrop, so no rain lands on them.
- A room with a whole ceiling still has the rain sheet over it; `SHELTER` decides only where
  it lands.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The rain lands and the storm lights the room; the fog, the dither and the midground bands stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 630 grade's new items, in its order: the square of magenta dither round the wading
foe in the flooded hall and the white dash clusters in the canopy sky; the Heartwood tell that
is a few-pixel sparkle; contact shadows under standing things and a jamb behind the plaza's
door. Then the one-value midground bands, a second ceiling pitch and the plank's board. The
next independent grade is due after pass 635. The Haar's fog and dither, the sprites' pixel
size, the hero's rim light and the sword's look stay held.
