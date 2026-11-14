# Pass 559: what hurts shows through Vorrhallow's water

## Category

Art cohesion and combat readability, an item left by the pass 555 grade (4.2/10): "hazards do not
separate from decor" in the crystal halls. Pass 558 left this half open: Vorrhallow's floor spikes
stand in flooded pits and the water's tint dims their steel rim.

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session; its second and third (the Haar Wyrm fight frame, the Haar's fog on the drowned stair) still
wait for the hydra and steam branches. This was the next. The PixelLab art loop stays **gated** on
Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of
three. No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s playtest
link already points at `sagedragoon79/Yldenfall`.

## Audit

- Shot the spike pits of `vorrhallow/flooded_hall` and `vorrhallow/drowned_nave` (the two rooms
  with a `tide:` header; each has one pit of spikes under the water).
- `Tide` is drawn at z 1, in front of the spikes. The pit's water is one flat dark tone at about
  0.55 alpha, so the near-white rim of bible 12.24 came out a blue-grey and the teeth's dark body
  vanished into the pit. At 1x the pit read as a dark box with a faint grey fringe.
- Design bible 4.4 and `Tide`'s own comment both say the spikes under the water "still show".

## What was built

- **`scripts/world/spikes.gd`**: the rim (catchlight and tip cap) is `Spikes.draw_rim`, a static
  function that draws on any canvas; `far_edge` also traces the shaded edge. `TEETH` names the 4.
- **`scripts/world/tide.gd`**: `sunk_spikes()` gathers the clusters standing in water cells, again
  whenever the room's child count changes. Over its body the water draws a faint pale band over
  each cluster (`SUNK_GLOW`) and its rim with both edges (`SUNK_RIM`, 0.9). `pit_color()` and
  `sunk_rim_color()` name the tones for the test. Drained, it draws none of this.
- Design bible 12.49 (new).

## Judged by eye

At 1x and 4x in both rooms, before and after. Before: a faint grey fringe. A first take drew only
the lit edge again; it was bright, but with the body lost it read as a row of white slashes, not
teeth. With the shaded edge traced as well, each tooth is a point and the row reads as spikes at
1x, the brightest thing in the lower frame, as a hazard should be. The pale band has a visible top
edge at 4x; at 1x it reads as lit water over the teeth.

Not done: the Evercrown's tiles are still violet on a wine backdrop (kept in the queue).

## Tests

`tests/test_tide_wake.gd`: `test_spikes_under_the_water_keep_their_rim` (12 checks).

Mutation check: with `SUNK_RIM` at 0.3 and the gathering switched off, 6 of its checks fail.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The hazard in Vorrhallow's flooded pits reads at a glance. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Unchanged in score. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,179 checks passed, 0 failed, in one run.

## Next

Art cohesion, by the pass 555 grade: foes from different style families (an art-loop item,
code-first on outline weight and shading). The Haar items wait until the hydra and steam branches
merge. Pass 560 is due an independent grade.
