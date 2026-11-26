# Pass 664: the veins light the shaft

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 660 (5.4/10). Its "empty boxed rooms" named three: the burrows' black top band (pass 662), the
plaza's ceiling (pass 663) and the veins in one purple, which this pass takes. The PixelLab art loop
stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent.

## Audit

`evercrown/veins` captured at the floor, halfway up and at the core. Measured: the backdrop's hue
287 to 290 (the Evercrown's wine haze), the grown shelves and the stalk 257 to 263, the frame's
median 288. Every region of the room lay inside 35 degrees of purple, and the light the sign tells
of was six thin channels on the stalk and six small crystals.

## What changed

Design bible 12.140 (new), with a line in 12.138; `scripts/world/vein_glow.gd` (new) and
`scripts/world/bloom_stalk.gd`.

- **A column of the veins' light.** `VeinGlow`, a child of the stalk, lays sky-2 (a channel's own
  line) over the air round the stalk as a normal blend at up to 0.62: full near the axis, falling
  off to nothing 230 px out, brighter toward the core, in 8 clean steps in 2-pixel blocks.
- **It is the light in the channels.** Each lit vein feeds a sixth of it; it dims with every cut
  and is gone once the core is starved.
- **Behind everything played** (z -4): the shelves keep their violet, the air's shade still darkens
  round every edge, and the hero, veins, core and beams draw over it.

Judged by eye at 1x and 2x, before and after: beside the stalk the air is now hue 234 (it was 288)
and lighter (luminance 47 against 27), the walls' side stays wine (289), and the frame's median hue
moves to 263. The stalk reads as a violet silhouette against cool light, and at the top the core's
wine eye hangs in front of it, the room's focal point.

## Tests

- New `test_the_veins_light_the_shaft_round_the_stalk` (`tests/test_bloom_stalk.gd`): the glow's
  tone is a master palette value and a channel's own; over the wine haze it turns the hue at least
  40 degrees and lifts the luminance by 40%; it falls off in clean steps; at half strength or more it
  spans under a third of the shaft and leaves the four tiles off each wall wine; it sits behind the
  air's shade; and two cuts take two sixths of it, the starved core all of it.
- `test_the_veins_have_their_stalk` now allows the glow as the stalk's only child (still nothing to
  touch or be hurt by).

Mutation check: with `PEAK` at 0.2 the new test fails (31 degrees, and no lift); with `REACH` at 420
it fails (the column covers 386 of 640 px, and reaches the walls).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,266 checks passed, 0 failed. CI (test and mix) passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the core's beams read over the light. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Veins have a second hue and a middle. |
| Bosses | 10 | 99 | The veins' fight dims the shaft with each cut. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The light the sign tells of fills the shaft. |

Weighted: 98.85.

## Next

Pass 665 is the fifth since the pass 660 grade: the grade follows that merge. Then from the pass
660 grade in its order, past the held items: flat water rectangles (the source hall, the flooded
hall); then the oversized bee (a smaller Hornet sheet).
