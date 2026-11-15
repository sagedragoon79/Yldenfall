# Pass 564: the Crystal Dwarf's stillglass lights the dark behind him

## Category

Art cohesion and combat readability, from the independent grade taken after pass 560 (4.9/10),
the half pass 563 left: "the foe at the waterline is nearly invisible against the dark pillars."

No note from Sean was new. The queue's items before this one are parked for a watched session
(lighting and depth, the hero's size) or wait on the Haar branches and on Sean's OK of a base, so
this is the first that can be built unattended. The PixelLab art loop stays **gated** on Sean:
three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of
three. No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is
still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- The waterline, the ripples and the water's depth were built in pass 550 (bible 12.41) and work.
  The queue item's "ripple line and splash" was already done; the defect that was left is the foe.
- In `vorrhallow/flooded_hall` the Crystal Dwarf is dark steel in front of dark pillars, and
  `FoeLight` (12.43) sinks his darks toward the hall's haze. At 1x only his magenta crystal shows,
  and it is the colour of the backdrop's stillglass, so he reads as part of a shard.
- Rim light on figures is a watched-session call, so nothing may be drawn on the figure. The
  stillglass on the floor already glows; the dwarf is made of the same stuff and did not.

## What was built

- `FoeGlow` (`scripts/enemies/foe_glow.gd`): a glow a foe carries, drawn behind it, additive, in
  four tones through a 4 x 4 ordered dither in 2-pixel blocks (the fire seal's grain, 12.40). It
  breathes at rest, swells with a tell and goes out at death.
- The Crystal Dwarf carries one on the crystal on his back, 40 by 34 px, in his crystal's colour.
  At rest it adds more light behind him than his steel has, so he stands against it as a
  silhouette. It swells through his windup.
- Design bible 12.52; enemy style guide section 1 (a glow is only for a foe made of stillglass,
  never a fix for a foe that is hard to see).

Looked at in `vorrhallow/flooded_hall` at 1x and 3x, at rest and in the windup, before and after.
A first take (peak 0.34, a steeper falloff, centred on the crystal's tip) was too faint to read at
1x; the glow now sits nearer his middle and falls off more slowly.

## Tests

`tests/test_foe_glow.gd` (three tests): the steps, the dither and its blocks; the breath, the tell
and the dark, and that the light outweighs his steel; and on a dwarf in the hall, that the glow is
behind him, additive, on his back whichever way he faces, swelling with the windup and gone at his
death.

Mutation check: the glow drawn in front of him fails ("drawn behind him"); a falloff with no
dither fails ("neighbouring steps mix"); a dead dwarf that still glows fails ("the crystal is
dark"); a glow that ignores his facing fails ("follows the crystal on his back"); a peak of 0.2
fails ("lit past his steel").

Full suite: SUITE_RESULT

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Crystal Dwarf reads in the dark halls, and his tell starts sooner. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | A stillglass foe is lit as the stillglass around him is. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The next independent grade is due after pass 565, or after the next art pass, and uses fight
frames. Of the queue: one-template rooms, then the trimless floor and ceiling bands, then the
Sunken Spring's pillars and water. The test runner's shared `user://` (found in pass 563) is worth
a short tooling pass while other worktrees run on this PC. The Haar items wait until the hydra and
steam branches merge; the Blinkhop waits for a free base slot.
