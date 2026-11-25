# Pass 658: the water clears over what wades in it

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 655 (5.0/10). Of its "fights hard to read" reasons, pass 657 took the burst over a small foe;
the next not held is "a foe half under the flooded hall's cyan water band". The PixelLab art loop
stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent.

## Audit

`workbench/catalog/fights/vorrhallow-tell.png` at 2x. Vorrhallow's tide (12.41) stands a full
tile (32 px) deep on the floors and is drawn in front of what wades in it: its body runs from 0.45
alpha under the surface to 0.68 at the floor, and the hall's mirror (12.115) lies over it at 0.5.
The Crystal Dwarf (a 28 px box) showed only above its belt, its legs a teal smear under the mirror
of its own upper half; the hero lost his boots the same way.

## What changed

Design bible 12.134 (new), with a pointer in 12.41; `scripts/world/tide.gd`.

- **Cleared over a wader.** `Tide._wake` now records a span over each wading body (its box and
  `CLEAR_PAD` 2 px past it, snapped out to the 4 px `CHUNK`). The surface row's body is drawn at
  `CLEAR` (0.35) of its strength over a span and half way back one chunk either side
  (`clarity_at`); elsewhere it is one draw per tile as before.
- **The mirror too.** `REFLECT_SHADER` takes the spans (`clear_spans`, `clear_n`, `clear_k`,
  `left`, `width`) and clears its alpha by the same rule, in the same 4 px columns. `SwimWater`
  shares the shader and passes no spans, so the deep water is unchanged.

Judged by eye at 1x and 2x in `vorrhallow-tell` before and after: the dwarf stands whole in the
water with its feet on the floor, and the hero's boots show; the waterline, ripples and glints
still cross them, so they read as wading. The clearing has no hard edge at 1x.

## Tests

- New `test_the_water_clears_over_a_wader` (`tests/test_tide_wake.gd`): a span covers the body
  and its pad in whole chunks, the water over it is `CLEAR` (at most half), a chunk beside it is
  half way, past that it is whole; in the flooded hall the hero wading gets a span, one per wader,
  the mirror receives the same count and amount, and a drained hall clears nothing.

Mutation checks: with no span recorded for a wader, the test fails 2 checks; with the clearing
left at full strength, it fails 1.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,735 checks passed, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A foe wading in Vorrhallow's water shows whole. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a few more 4 px draws near a wader). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 655 grade in its order, the rest of "fights hard to read": the hero over the gate
tree's trunk; then the canopy's dithered tile edges and the oversized bee; the large empty
chained-platform rooms in one hue (the Tower foot, the Evercrown veins); the dead black band over
the grub burrows. Held as before: the hero's size, the sword's flat bar, the Haar's dither halos
and fog; foes in mixed styles stays with the art loop. Pass 660 is the fifth since the pass 655
grade: grade it.
