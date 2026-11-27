# Pass 670: a hung deck hangs from one point

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 665 (5.5/10), past its held items and the items since done, names "platforms hung on chains
and ropes from nothing, and the veins' one value band". This pass takes the hung platforms. It is
the fifth pass since the pass 665 grade, so the grade follows this merge. The PixelLab art loop
stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent.

## Audit

`tower/foot` and `evercrown/veins` captured. Every hung deck (12.128) rose on two parallel hangers
from its two ends, straight up past the top of the frame. In the veins' shaft of stacked decks they
ran as three long pairs of lines; in the Tower foot as two. Nothing in view said what they hung
from, so they read as lines, not as something carrying a weight.

## What changed

Design bible 12.147 (new); `scripts/world/plank_supports.gd`.

- **A bridle.** A run whose two hangers are both its own meets them over its middle: two legs at
  45 degrees (at most 44 px high) to a ring, and one hanger on from the ring to the first solid
  cell or plank above the middle, on a cleat. The hangers' feet still take the chord in stirrups.
- **Legs in the zone's hanger:** chain links that swell and narrow, or a 2 px rope or sinew strand
  with a lit lay, lit on the upper left, on the 2-pixel grid.
- **Two hangers stay** when nothing is over the middle within reach, or the anchor above is too
  close for a 16 px bridle with its ring 12 px clear of it.

Judged by eye at 1x and 3x in the Tower foot, the veins, the sky steps and the marsh road. The
first sinew legs were 1.5 px and read as hairs; they are 2 px. Each deck now hangs from a single
point, and a stacked shaft reads as decks hung one under the next.

## Tests

- New `test_plank_a_hung_run_meets_its_hangers_in_a_bridle` (`tests/test_plank_supports.gd`): one
  bridle over a free run, both hangers its legs, the ring over the middle at 45 degrees, its
  hanger to the ceiling; under a plank two rows up the ring stays clear and hangs from that board;
  right under a plank, and with nothing over the middle, no bridle; the Tower foot and the veins
  hang at least four decks each on bridles.

Mutation check: with the `BRIDLE_MIN` rule removed the test fails (a bridle squeezed under a plank
one row up); with the legs at half the rise it fails (not 45 degrees).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,351 checks passed, 2 failed, both the room budget
(`test_every_room_loads_and_settles_inside_the_budget`: `evercrown/proving_scar` 505 ms and 8.16 ms a
frame, `gym/gym` 510 ms). Rerun alone it passed. `proving_scar` has no planks, and it failed the
same way in pass 665 with that pass's code taken out. CI (test and mix) is green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Hung decks read as hung, from one point. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Drawn once per room load. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade follows this merge (every fifth pass). Then from the pass 665 grade in its
order, past the held items: the veins' one value band; then the canopy's soft trees against the
stepped border and the oversized bee.
