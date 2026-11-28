# Pass 675: the sun falls through the canopy

Date: 2026-11-27. No new notes from Sean. The pass 674 doc names this pass the independent grade,
then "the canopy's flat mint wash and stepped edges" from the pass 670 grade. This pass takes the
mint wash and the grade follows the merge. The PixelLab art loop stays gated on Sean (three
guardian bases wait for his OK); no PixelLab generations or Autosprite credits were spent.

## Audit

`boughs/canopy_bridge`, `boughs/sunlit_bough` and `boughs/crown_leaf` captured. The open air of
every Boughs room was one pale mint, top to bottom. Measured in the canopy bridge in 8-pixel steps
across the air, every row from the canopy's underside to the woods' crests had a median luminance
of 136; only the valley mist below changed it. The room's light shafts (12.17), additive at 0.085,
did not show over air that pale. The day air (12.112) keeps the foes off the woods, so the fix had
to leave the mist at the play line as it is.

## What changed

Design bible 12.152 (new), 12.17 amended; `scripts/world/light_shaft.gd`.

- **A shade under the leaves** (`LightShaft.CANOPY`, `CanopyShade`): the Boughs' open air is
  multiplied by (0.70, 0.80, 0.76) at the room's top, clearing by 55% of the way down. Drawn behind
  the tiles, under the beams, so walls, planks and actors keep their values.
- **The sun through it:** the Boughs' shafts are a warm gold at peak 0.2 and 44 px half-width
  (`SHAFTS` entries may carry their own `peak` and `half`).
- **No steps:** beams and shade are drawn with colours at their corners, so they grade smoothly.
  The first capture at the new peak showed the old stepped strips as seams.

After: the same rows lie between medians 103 and 132, and each beam stands 20 to 30 above the air
beside it. Judged by eye at 1x and 2x in the canopy bridge, the sunlit bough and the root shrine (a
roofed zone, unchanged but for smoother beams).

## Tests

- New `test_the_canopys_air_is_shaded_and_the_sun_falls_through_it`: every canopy zone is sunlit
  and has shafts; the shade darkens the top (luminance between 0.6 and 0.85), only lightens going
  down and clears by its depth; its shafts are at least twice the default peak and no narrower;
  other zones keep the defaults.
- New `test_a_canopy_zones_shafts_carry_a_multiplied_shade_behind_them`: the Boughs' shafts build a
  multiplied shade under the beams; the Tower's build none.
- Mutation check: with the Boughs' own peak removed and the shade drawn additive, both new tests
  fail (2 failed); restored, both pass.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,610 checks passed, 1 failed: the room-load budget timing
(`spires/sky_steps` 9.15 ms against 8), a room this pass does not touch; rerun alone it passes, as
in pass 670. CI (test and mix) passed on the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Boughs' air has light and shade. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade follows this merge. Then, from the pass 670 grade in its order: the canopy's
stepped edges (its ceiling and walls cut in 45-degree tile stairs); generic grey skylines.
