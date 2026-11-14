# Pass 560: the Evercrown's cells are lit by their pores

## Category

Art cohesion, the last piece of the pass 555 grade's crystal-hall item (4.2/10): "the Evercrown's
tiles are still violet on a wine backdrop, a smaller hue step than Vorrhallow's" (left open by
passes 558 and 559).

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session; its second and third (the Haar Wyrm fight frame, the Haar's fog on the drowned stair) still
wait for the `hydra-cistern-fight` and `haar-steam` branches. This was the next. Pass 559 named the
foes' style families as next: a lineup of every foe's idle (`tools/art/lineup.tscn`) shows the
outlier is the Blinkhop, a smooth round blob beside HD figures, and a remake of it is a redesign
that needs a base and Sean's OK, with three bases already waiting. It stays queued, now named. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- Shot `evercrown/threshold`, `veins` and `heart`. Every colour of the tile fill is on the night
  ramp (hue about 255); the haze is a wine at hue 295. On the committed atlas the mean hue of the
  opaque pixels was 261, 34 degrees from the haze.
- The master palette has no indigo ramp: night is 255, sky is 210.
- Trials, each shot in `threshold`: a hue shift of the atlas by 28 degrees (reads best, but off the
  palette); the body on sky-2 with a sky-3 rim (a blue cave: the largest step, but it loses the
  zone's black-violet and no longer matches the shelves, hangers and stele); the body on sky-1 (too
  dark, ledges lose their edge); a sky-3 rim on the night body (a small step); a sky-3 rim and
  sky-1 cool seams on the night body (close to the hue-shift trial, in palette).

## What was built

- **`tools/art/tilegen.py`**: `paint_meteor` keeps its night-2 body. The lit upper rim of each cell
  is `MEAT_RIM` (sky-3, where night-3 was) and the seams that are not wine sinew are
  `MEAT_SEAM_COOL` (sky-1, where night-1 was). `MEAT_SEAM_WARM` names the wine seam (crystal-1).
- Regenerated: `assets/tiles/evercrown.png`. The tile script again rewrote five
  `assets/bg/*_mid.png` files that differ from run to run; those were put back.
- Design bible 12.50 (new); the Evercrown's line in 12's zone list names it.

## Judged by eye

At 1x in `threshold`, `veins`, `heart` and `proving_scar` and at 3x on a pillar in `threshold`,
before and after. The rock reads as an indigo mass: each cell carries a cool glint along its upper
side, the light of the cyan pores beside it, and the wine tendrils, ridge and far wall fall behind
the play layer instead of sharing its purple. The floor of `threshold` measures hue 237 where it
measured 251, at the same luminance (55 against 53). At 3x the rim is a clean one-world-pixel
line; it is the most saturated thing in the fill, so it is kept to the rim and not the body.

Not done: the grown shelves, hangers and the stele are still all-violet (night ramp). They read
well against the wine, so they were left; a cool glint on the shelf's lit top is a possible
follow-on if a grade names them.

## Tests

`tests/test_backdrop.gd`: `test_the_evercrowns_tiles_stand_off_its_wine_haze` (6 checks).
`tools/art/test_tilegen.py` (run by hand, 69 guards pass):
`test_the_evercrown_cells_are_lit_by_their_pores`.

Mutation check: with the old atlas put back, 3 of the Godot test's 6 checks fail; with `MEAT_RIM`
and `MEAT_SEAM_COOL` back on the night ramp, the Python guard fails.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Unchanged in score. The Evercrown's play layer stands off its backdrop in hue as well as value. The HD hero, the Blinkhop and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,185 checks passed, 0 failed, in one run.

## Next

By the independent grade taken after this pass (see `workbench/grades.json`). Of the queue: the
Boughs' painterly foliage against the pixel tiles, then one-template rooms. The Haar items wait
until the hydra and steam branches merge; the Blinkhop waits for a free base slot.
