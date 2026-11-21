# Pass 632: a soft light and a gust, not dither and dashes

## Category

Art cohesion (effects). The top item of the queue, the first new defect of the pass 630
grade: "a square of magenta dither round the foe in the flooded hall, white dash clusters in
the canopy sky" read as artifacts.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at both rooms at 1x and 4x and found what draws each.

- **The flooded hall.** The square is the Crystal Dwarf's `FoeGlow` (12.52): four tones through
  a 4 x 4 ordered dither in 2-pixel blocks. Two neighbouring blocks differ by up to a quarter
  of the peak, so at 4x it is a magenta checkerboard, and the water covers its lower half, so
  its bottom edge is ruled.
- **The canopy.** The dashes are the `WindCurrent` (6.9): one-pixel lines at 0.85 white over a
  blue under-line, every one the same brightness from end to end, on a flat wash whose
  rectangle shows against the sky.

Both are things the game means. Neither was dropped; each was redrawn.

## What was built

Design bible 12.108.

| Part | Before | After |
| --- | --- | --- |
| Glow tones | 4, a quarter of the peak apart | 14; one tone is 0.04 of alpha in a tell, neighbours never more than 0.1 apart |
| Glow falloff | `CURVE` 1.15 | 1.5: the outer half of the reach holds under half the light |
| Wind line | a dash at 0.85 with a blue under-line | a gust in five pieces, faint tail to a head at 0.62 downwind, bowed a pixel |
| Wind count | one to 12 px of band | one to 22 px |
| Wind wash | one box at 0.07 | four nested boxes adding to 0.05, stepping down over 8 px at each edge |

The glow's peak, breath, tell, reach and place are unchanged, and so is how the wind carries
the hero.

Changed on the way: the first gusts (a head at 0.5, a steeper fade) were hard to find at 1x,
and a current has to read for play. The head went to 0.62 and the fade was eased.

## Checked by eye

At 1x and 4x, before and after: the dwarf wading in the flooded hall (a soft pocket of light
behind the crystal, no checkerboard, the rim fades out) and the canopy bridge's sky (thin
gusts with a direction, no rectangle, the leaves as before).

## Tests

`tests/test_wind_look.gd` (four new tests) and one new test in `tests/test_foe_glow.gd`.
Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_the_glow_is_a_soft_light_not_a_checkerboard` | four tones again | fails (3 checks) |
| `test_wind_look_a_gust_thins_out_behind_its_head` | no taper | fails (84 checks) |
| `test_wind_look_the_wash_has_no_ruled_border` | the wash as one box | fails |
| `test_wind_look_gusts_are_soft_thin_and_inside_the_band` | a head at 0.85 | fails |
| `test_wind_look_gusts_are_soft_thin_and_inside_the_band` | no bow | fails |

Full suite: 33,552 checks. 33,551 passed in the whole run (pass 631: 33,365); the one that failed was the
wall-clock room-load budget (`evercrown/proving_scar` 515 ms against 500, the known flake
queued in pass 570), which passed three times in a row run alone.

## Not done

- The Inner Rings' currents take the same gusts and were not looked at one by one.
- The water still cuts the glow at the waterline; a reflection belongs with the waterline item.
- The Haar's unlit lava pillar, the third thing in the same grade line, is under the held fog.
- The Haar's dithered lamp halos break the new rule and stay held with the fog.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Two effects no longer read as faults; the fog, the Haar's dither and the midground bands stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 630 grade's other new items, in its order: the Heartwood tell that is a few-pixel
sparkle (check that the capture catches the tell's strongest frame first); contact shadows
under standing things and a jamb behind the plaza's door. Then the one-value midground bands,
a second ceiling pitch and the plank's board. The next independent grade is due after pass
635. The Haar's fog and dither, the sprites' pixel size, the hero's rim light and the sword's
look stay held.
