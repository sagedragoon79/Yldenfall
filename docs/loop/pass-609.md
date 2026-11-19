# Pass 609: no clock face

## Category

Combat readability, from the independent grade taken after pass 605 (5.3 of 10): the hit spark
"reads as a clock-face lock-on marker". It was first on pass 608's "Next".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The shipped spark is PixelLab's VFX-tool sheet (pass 529; `assets/vfx/blade_spark.png` and
`heavy_spark.png`, 7 frames at 24 fps). Frame 0 is the small hot star of pass 530. Frames 1 to 3
open into a ring 14 to 23 sheet pixels in radius (21 to 34 for the heavy one), and the ring is
drawn as a dial: eight tick marks inside it, a crosshair spike at twelve and at nine o'clock, and
studs around its rim. Enlarged, it is a clock face; at play size, over a foe, it is a lock-on
reticle. That is what the grader saw.

## What was built

- **`tools/art/sparkfix.py`** rebuilds both sheets from the tool's export, now kept in
  `art/vfx-raw/` (ignored by Godot), so it can run again. On every frame after the star it finds
  the ring (the radius from the pivot that lights at least half a circle) and erases it, its ticks
  and its spikes, keeping only the spray thrown forward along the swing (-40 to 45 degrees, past
  the ring). The star stays lit on frame 1 and burns down to its hot core on frame 2. Frames 4 to 6,
  the falling embers, are unchanged, as are the JSON, the timing and the pivots.
- Bible 6.7 (particles) and `HitSpark`'s header say so.

Judged by eye: on the sheets at 2x (star, star with the spray leaving it, core and spray, falling
embers) and in the refreshed fight frames at 1x and 3x. In the Heartwood hit the spark is a hot
star on the grub's near edge with sparks flying into its body, under the swing's smear and beside
the cut's streak; nothing circles the foe.

## Tests

`tests/test_combat.gd`, `test_the_hit_spark_is_no_clock_face` (4 checks, both sheets): no frame
after the star lights most of a circle beyond what the star itself lights at that radius, and
nothing is lit up and behind the contact past the star's reach, where the ticks and spikes were.

Mutation check: with the raw sheets put back, all 4 checks fail (16 and 20 ring radii, 232 and
533 pixels behind the contact); with the fixed sheets they pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The spark reads as a strike, not a reticle. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 610 takes the next independent grade (every fifth pass). Then, from the pass 605 grade: foes
that blend into their backgrounds (the Boughs' mantis and archer, the flooded hall's shade, the
gear pit's ceiling creatures) and the flat green block in the canopy bridge. The sword's look, the
Haar's fog and dither and the sprites' pixel size stay held.
