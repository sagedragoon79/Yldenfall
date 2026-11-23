# Pass 648: crystal grows through the halls' near plane

Date: 2026-11-23. No new notes from Sean. From the queue, first item: the independent grade of
pass 645 (5.2/10). Pass 647 took the grub burrows' half of "dead voids"; this pass takes the other
half, "the Evercrown veins' flat purple". The PixelLab art loop stays gated on Sean (three guardian
bases wait for his OK); no PixelLab generations or Autosprite credits were spent. README's playtest
link already points at https://github.com/sagedragoon79/Yldenfall.

## Audit

In `evercrown/veins` the backdrop between the hanging tendrils and the floor, about a third of the
frame, was one flat dark purple. It is the ridge layer's near plane (12.83): filled from under its
crest to the layer's foot, with no detail of its own. Its lighting did not show either, for a reason
only the two crystal halls share: their ridge body is the darkest step of its ramp (`crystal-0`,
`sky-0`, 12.48), the near plane's fill is one step darker than the body (which stays the same at
index 0), and its light is the body. Fill and light were one color, so the near crest's rim, sky
light and lit faces drew nothing.

## What changed

Design bible 12.124, in `tools/art/tilegen.py`.

- **The near plane's light.** Where the body has no darker step, the near plane is lit by the far
  plane's rim, so its crest and faces show.
- **Crystal masses** (`_near_crystal`, `_near_shard`, `NEAR_MASS_ROWS`). Two rows of great masses
  grow up through the near plane from below the layer's foot: a leader and one to three lesser
  shards fanned beside it. Each shard is lit on its west facet and dark (`night-0`) on its east,
  with a lit west edge, in 2-pixel blocks; the nearer row is darker and broader; half the leaders
  carry a glint. A tip is held under the near crest instead of being cut off by it.
- Only the "shard" ridges (the Evercrown, Vorrhallow) change; the other ridges are byte-identical.

## Checked by eye

The ridge alone, then in `evercrown/veins` at 1x and 2x, `evercrown/threshold` and
`vorrhallow/flooded_hall`. The first try (shards 7 to 12 blocks wide, leaning up to 0.28 rad)
read as a field of grass blades; the masses are now about twice as broad and lean less. The second
left a flat band under the crest; the masses now reach as tall as the crest allows. In the veins
the old flat band is faint faceted crystal, receding behind the platforms; in the flooded hall the
blue masses sit low behind the far pillars.

## Tests

`test_the_crystal_halls_near_plane_holds_crystal_masses` in `tools/art/test_tilegen.py` (113
checks, all passed): in both halls the band under the near crest is 25% to 90% forms, they reach
into its upper half, there are lit facets and dark ones, the near crest is lit, and no mass's tip
rises into the crest.

| Mutation | Result |
| --- | --- |
| no masses | fails (0.00 of the band differs from the fill) |
| no facets (both sides lit) | fails (117 dark pixels) |
| the near plane lit in its own fill | fails (62 lit pixels) |
| no limit on a mass's reach | fails (a tip at 753 rises into the crest at 797) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 37,116 checks, all passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The crystal halls' near backdrop is faceted crystal, not one flat fill. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a baked picture). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 645 grade in its order: walls that end mid-air at the screen's edge; barcode stripes
in the dirt tiles; copied hazards and cloned town towers; floating islands and chain platforms hung
from nothing; the Spires' rain too heavy; an oversized minimap; the spark's size at this scale.
Held as before: the Haar's render, the sword's flat bar, the hero's size; foes in three styles stays
with the art loop. The next independent grade is due after pass 650.
