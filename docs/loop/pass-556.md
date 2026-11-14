# Pass 556: brick fields with structure

## Category

Art cohesion, from the independent grade taken after pass 555 (4.2/10): "brick fields (Spires,
Vorrhallow, Sunken, Trials) read as a flat tile-editor fill with random dark missing bricks and no
structure", and pass 555's own "Not done": the Spires' deep tiers still alternated two values.

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session. Its second and third (the Haar Wyrm fight frame, the Haar's fog on the drowned stair) touch
files that two unmerged branches of other sessions change (`hydra-cistern-fight`, `haar-steam`), so
the pass took the fourth. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended: `push.py` answers HTTP 500); it stays under "stuck" for Sean.

This pass took over a lock left at 19:16 by a run that was cut off before it branched; nothing of
it was in the working tree.

## Audit

- Shot `spires/broken_shrine` and `trials/walls`. In the Spires the wall depth under the floor and
  in the right-hand cliff was a near-black checkerboard with orange dashes: the loudest area of the
  frame, and not the play field.
- `paint_shrine` chose shade 4 or 3 with a coin toss, then dropped 18% of blocks one more. After the
  two-step darkening of the deep tier that is three values down to near-black. The gold inlay, two
  steps down, stays orange.
- Measured the share of each tier's pixels on its commonest colour. Spires: 36%, 34% and 40% (two
  values near a third each). Trials and gym brick: 32 to 33%, with two more colours at about 25%.
- No masonry floor had any built line: the fill ran up to the cap and stopped.

## What was built

- **`tools/art/tilegen.py`**: `paint_shrine` and `paint_bricks` use `WORN_BLOCK` (one body value,
  about one worn stone in seven; a brick may stand proud, `PROUD_BRICK`); `is_interior(seed)` and
  no gold inlay in the darkened tiers; `string_course` under the cap of every top tile in
  `COURSE_ZONES` (Spires, Inner Rings, gym).
- `assets/tiles/spires.png`, `trials.png` and `gym.png` regenerated. The script again rewrote five
  `assets/bg/*_mid.png` files that differ from run to run; those were put back.
- Design bible 12.46 (new).

## Judged by eye

Looked at `spires/broken_shrine` and `trials/walls` at 1x before and after. The Spires' wall depth
is coursed stone that darkens inward, with no checker and no orange in the dark; the eye goes to the
islands and the hero. In the Inner Rings each pillar has a pale capital under its cap and the floor
a coping line, and the brick is a little quieter. The Spires' course is faint under the moss and the
rain at 1x.

Not done: a plinth where a wall meets a floor, cracks and moss in the field, and Vorrhallow and the
Sunken Spring (the same grade item). The brick of the Inner Rings is still a fine uniform bond.

## Tests

`tests/test_brick_structure.gd`, four tests (24 checks): the Spires' body value takes about half of
every tier; the brick's body value leads its tier in the Inner Rings and the gym; the mid and deep
Spires tiers have no gold and the surface keeps some; a floor tile's string course is one lit line
over one shadow line across the whole tile, and no interior tile carries it.

Mutation check: with the three old atlases put back, all four tests fail (3, 6, 2 and 6 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | The Spires' wall depth is quiet and masonry floors have a course. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,098 checks passed, 0 failed.

## Next

Art cohesion again, by the pass 555 grade: the rest of this item (a plinth, cracks and moss, and
Vorrhallow and the Sunken Spring), or Vorrhallow and the Evercrown's narrow value range with one
accent reserved for hazards. The Haar items wait until the hydra and steam branches merge.
