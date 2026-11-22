# Pass 635: a ridge has forms, not one value

## Category

Art and cohesion (environments). The top item of the queue, the pass 630 grade's next
queued defect: "midground layers are flat cutouts that repeat: the sawtooth band, the tower
skyline, the wavy bands (root shrine, Heartwood tell, plaza, shop, storm ledge, Spires hit)",
named before that as "muddy one-value cutouts over a third of the frame".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

Looked at the root shrine, the storm ledge, the plaza and the gear pit at 1x, and at each
zone's ridge layer on its own.

- **The sawtooth band is the woods' ridge.** Each fir was a plain triangle, a row of them a
  regular saw, and below the crest the far plane was one brown (the Heartwood) or one green
  (the High Boughs) down to the mist. The near plane was a solid dark wall.
- **One value.** Measured over the far plane between its crest and the near plane, the middle
  80 percent of its pixels spanned only 4 to 8 steps of luma in every natural ridge (the
  woods, the hills, the crystal halls, the crags): an eighth of the plane's lightest value or
  less. The lit west faces of 12.83 reach 6 to 12 px under the crest and leave the rest flat.
- **The crystal halls were striped.** A leaning shard slid each of its columns sideways,
  which left one-column gaps in its crest, and the cleft detail (12.83) drew a dark line down
  every gap: rows of thin vertical stripes on the west side of the Evercrown's and
  Vorrhallow's shards.
- The town's roofline (12.94) and the Spires' terraces (12.98) already span 13 and 20 steps;
  they keep their own painters this pass.

## What was built

Design bible 12.111, all in the ridge painter (`tools/art/tilegen.py`), for the woods, hills,
crystal and crags (`RIDGE_FORMED`).

| Part | Before | After |
| --- | --- | --- |
| A fir on the crest | a triangle | three to five drooping tiers, each flaring from a quarter of its width to its tips, widening down the tree |
| A crest tree's flanks | the same colour | the west lit (rim at 64), the east shaded (the body's shade at 120) |
| The woods below the crest | one flat colour | two inner rows of tiered firs, 26 and 50 px below the ground line, each a step darker |
| Hills, crystal, crags below the crest | one flat colour | two nearer folds of the zone's own crest, each darker, with a lit crest line |
| Upper slopes | lit faces only | the sky's light fading down 26 px under every crest, far and near |
| East faces | none | the body's shade under a falling crest, 8 to 16 px |
| A leaning shard | gaps, a cleft in each | whole: the feet slide under the apex |

Every far plane now spans at least three tenths of its lightest value (the woods a half, the
hills and crags a third, the crystal halls just over three tenths).

Thrown out or fixed on the way:

- The first tiers did not show: each tier's top was 0.42 of its bottom and the tiers widened
  in a straight line, so a tier's top was barely narrower than the one above's foot (under a
  pixel of step). The tops are a quarter now and the tiers flare by a power of 0.7.
- The east-face shadow first read one column against the next, and on a leaning shard it
  came out in stripes. Both faces now read the slope over two columns a side. That did not
  remove the old stripes, which led to the gaps in `_tri`.
- The first folds mixed in a second profile against the ground; one profile on the ground
  line reads cleaner.

## Checked by eye

At 1x and 2x: the root shrine (rows of tiered firs, lit on the west, where the sawtooth band
was; the near plane is a darker row of the same trees), the canopy bridge (a forest in depth
behind the trestle instead of a green band), the gear pit (the crags step back in three
folds), the flooded hall (shards in folds, no stripes) and the Lampwick causeway (the fog
covers the ridge, as before). The storm ledge and the plaza are unchanged but for the Spires'
lit faces, which now read the slope over two columns.

## Tests

`tools/art/test_tilegen.py`, three new tests (105 checks pass). Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_a_natural_ridge_is_not_one_value` | no sky light, no folds | fails (the Haar spans 4.4 of 50.4) |
| `test_a_natural_ridge_is_not_one_value` | no inner rows of trees | fails (the Heartwood spans 12.1 of 54.3) |
| `test_a_fir_on_the_crest_is_tiered` | a plain cone | fails (no steps) |
| `test_a_leaning_shard_has_no_gaps` | the old column slide | fails (the west side turns back) |

Full suite: see the pull request.

## Not done

- The town's tower skyline and the Spires' wavy terraces, named in the same defect.
- In the crystal halls the body is the ramp's darkest step, so a fold cannot go darker; their
  spread is the narrowest of the natural ridges.
- The mid layers (the Heartwood's hanging roots, its distant trunks) are unchanged.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The woods, hills and crags behind a room have forms and depth; the town's skyline, the Spires' terraces, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Generated art only; nothing new runs at play time. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

An independent grade is due now (after pass 635): the same spread as pass 630. Then the rest
of the pass 630 grade's queue: a second ceiling pitch and the plank's board, and the town's
skyline and the Spires' terraces. The Haar's fog and dither, the sprites' pixel size, the
hero's rim light and the sword's look stay held.
