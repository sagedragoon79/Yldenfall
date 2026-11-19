# Pass 610: a bounce-pod is a ripe gourd

## Category

Art cohesion, from the independent grade taken after pass 605 (5.3 of 10): "a flat green
placeholder block (canopy bridge)". It was on pass 609's "Next", after this pass's grade.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The block on the Canopy Bridge's deck is the bounce-pod (legend `@`, bible 3.2 and 6.6).
`BouncePod._draw` drew it as eleven rectangles: a 36 by 17 half-pixel slab in one leaf green with a
lighter bar, a darker bar and two yellow squares. Its room is green from backdrop to foes, so
nothing set it apart, and at any zoom it is a rectangle. The same pod stands in Leaf Landing, the
North Bough, the Sunlit Bough and the Windward Climb.

## What was built

- **`BouncePod.pixels`** builds the pod once as pixel art in code, the way the thorn bulb is
  (12.32): a plump round gourd shaded as a ball lit from the upper left over a six-step pale gold
  ramp, four ribs that follow its curve, the dried flower's nub on its crown, and three green
  sepals at its foot with a midrib and a lit edge each, inside one dark line. Every tone is a
  master palette value.
- The size (34 by 20 half-pixels), the top, the catch, the throw and the squash at a launch are
  unchanged, so no room or route moves.
- Bible 12.87 says so.

Judged by eye at 1x, 2x and 6x in the Canopy Bridge. The first shading bands left the bulb nearly
all cream; they were moved so the gold base tone carries it and the shine is a small patch.

## Tests

`tests/test_bounce_pod.gd` (three tests): the tones are master palette values and all are used;
the pod narrows to its crown over at least five widths with the block's corners empty, no tone
covers half the bulb, the upper left is lit and the lower right in shade, the bulb is warm and the
sepals are a collar at its foot; a pod in a room keeps its top.

Mutation check: with the bulb filled as a flat 34 by 20 slab of its base gold, five checks fail (8 of
13 tones used, a crown 36 wide against 42, one width in the upper half, the corners filled, one
tone on all 540 bulb pixels); with the gourd back they pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The last rectangle prop in the Boughs is drawn; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is taken after this pass merges (every fifth pass). Then, from the pass 605
grade and whatever the new one names: foes that blend into their backgrounds (the Boughs' mantis
and archer, the flooded hall's shade, the gear pit's ceiling creatures). The sword's look, the
Haar's fog and dither and the sprites' pixel size stay held.
