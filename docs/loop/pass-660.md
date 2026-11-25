# Pass 660: the air's shade follows a vault's slope

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 655 (5.0/10). Passes 656 to 659 took its items ahead of this one; the next not held is "the
canopy's dithered tile edges against its soft backdrop, and an oversized bee". The PixelLab art
loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or
Autosprite credits were spent.

## Audit

`boughs/canopy_bridge` at 1x, 2x and 3x. Every vault of the bark canopy wore a staircase of grey
boxes on the day air beside its drawn diagonal, in four hard steps. Hiding the room's layers one at
a time (`LightShaft`, `AirShade`, `Backdrop`, `RoomLight`, with a throwaway switch in the shot
script that was not kept) showed the boxes to be `AirShade` (12.129): it took a haunch (12.78) for
open air, so the square cells behind each slope cast square shadows across the slope's open half.

The bee is the Hornet's 2x-detail Autosprite sheet (80 x 64 cells, about 37 x 30 world px drawn)
over a 16 x 12 hurtbox. Shrinking it cleanly needs a redrawn sheet (a fractional density would
break its pixels), and its tell point, light bands and hit box move with it, so it is left for a
pass of its own and put in the queue.

## What changed

Design bible 12.136 (new), and 12.129's numbers; `scripts/world/air_shade.gd`, `scripts/world/room.gd`.

- **A haunch casts from its diagonal.** `AirShade` takes the room's haunches (`Room._haunch_cells`)
  as two more kinds, `HAUNCH_WEST` and `HAUNCH_EAST`, and measures the air's distance to a haunch's
  solid triangle (`haunch_distance`), each axis against its own reach as for a block. The falloff
  runs parallel to the slope the tile draws. The haunch's own cell is painted whole (its solid half
  is behind the tile): a first take skipped the blocks inside the triangle and left a dotted pale
  seam along every diagonal.
- **Softer steps.** `LEVELS` 8, from 4: at 0.15 a step each band showed as a line; at 0.075 the
  falloff reads as a gradient in 2-pixel blocks, still with no dither. Alone, this changed little
  in the canopy; with the haunches it reads as a soft shadow.
- **It fades out inside its reach.** `DOWN_REACH` 16, from 18: a cell's pattern sees only its
  neighbours, so the falloff under an underside was cut at 16 px on a visible step. It now ends on
  its lightest step.

Judged by eye at 1x, 2x and 3x in `boughs/canopy_bridge` (the vaults are clean slopes over the day
air), `tower/foot` and `evercrown/veins` (unchanged in shape, softer under the decks).

## Tests

- New `test_air_a_haunch_casts_from_its_diagonal`: two points the same way off a west haunch's
  diagonal, near its two ends, are one step; the air just past the diagonal is at its darkest; it
  is gone well off the slope; an east haunch mirrors it.
- New `test_air_a_room_passes_its_haunches`: a Boughs room with a `` ` `` darkens the air just past
  its diagonal.
- `test_air_shade_falls_off_in_clean_steps` now walks 8 steps.

Mutation checks: with the room not passing its haunches, 1 check fails; with the haunches left out
of the grid, 4; with a haunch casting nothing, 4.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,873 checks passed, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The canopy's vaults lose their grey stairs; the bee is still oversized. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a few more cached patterns at load). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 660 is the fifth since the pass 655 grade: the grade follows this merge. Then, from the
pass 655 grade in its order: the oversized bee (a smaller Hornet sheet); the large empty
chained-platform rooms in one hue (the Tower foot, the Evercrown veins); the dead black band over
the grub burrows. Held as before: the hero's size, the sword's flat bar, the Haar's dither halos
and fog; foes in mixed styles stays with the art loop.
