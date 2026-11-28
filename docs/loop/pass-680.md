# Pass 680: a floor sinks into the ground under it

Date: 2026-11-28. No new notes from Sean. From the queue, first item: the independent grade of
pass 675 (5.4/10), next in pass 679's list: "uniform floor strips (Tower foot, veins, source
hall)". This pass takes it, and the independent grade follows the merge. The PixelLab art loop
stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent.

## Audit

The three named rooms shot fresh from `main` and read at 1x and 2x:

- **The Tower foot.** A riveted rail over two rows of the same square plate from wall to wall, at
  one value to the frame: the row medians stood at 96 of 255 from the lip to two tiles down.
- **The veins.** The hex cobbles of the floor and its banks at one value under the walking line.
- **The Source Hall.** Deep brick under the ledge already fell off (`DeepShade`), but the first
  three courses under the walking line stood at full value.

The cause is shared. A floor is two to four tiles of ground between the walking line and the
frame; `DeepShade` (12.38) starts 2.5 tiles from open air, so it barely reached a floor that thin.

## What changed

Design bible 12.157 (new), a note in 12.38; `scripts/world/floor_shade.gd` (new),
`scripts/world/room.gd`.

- **`FloorShade`.** The foot of each column (its run of solid cells from the bottom row up, at
  least two tiles deep, with open air over it and no secret in it) sinks into shade under its
  walking tile: the upper half of the walking tile stays lit, then a smoothstep to 0.7 of
  near-black by two and a half tiles down. Drawn in four bands with colours at their corners, so
  it grades with no dither and no steps.
- **No seams.** At each column edge the depth is measured from the lower of the two floors' tops,
  so the shade runs on across banks and slopes and never reaches into a walking tile.
- Rebuilt when a guardian tears the floor, like `DeepShade`.

After: the Tower foot's rows fall from 96 at the lip to 68 a tile down and 33 a tile and a half
down (96 and 71 before). Judged by eye at 1x and 2x beside the pictures from before: each floor
reads as a lit edge over ground going into shadow, not a strip. A first try that kept the whole
walking tile lit (FROM 1.0, SPAN 2.5, 0.6) barely showed where the frame cuts the floor after
two or three tiles, so the falloff starts half a tile down. Checked at 1x in the Hearthroot
plaza, the canopy bridge and the deep roots for side effects: none seen (the spikes under the
canopy bridge still read).

## Tests

New `tests/test_floor_shade.gd`:

- `test_only_the_foot_of_a_column_is_a_floor`: walls, pits, one-tile ground, secrets and hanging
  mass are not floors.
- `test_the_walking_tile_stays_lit_and_the_ground_falls_into_shade`: the lip is bare, the shade
  never lightens deeper in, it is well in by two tiles and full by FROM + SPAN, and the ground
  shows through.
- `test_the_shade_meets_itself_across_a_bank`: no seam at a bank's edge and no walking tile shaded.
- `test_the_named_floors_fall_into_shade`: in the three rooms most columns stand on a floor, every
  lip is lit and every flat floor is in shade two and a half tiles down.

Mutation check: with `MAX_ALPHA` at 0, three of the four fail (5 checks); with the room not
setting the shade up, the rooms' test fails 6 checks.

## Full suite

See the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Floors read as ground going into shadow, not lit strips. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade of pass 680 follows the merge; its defects go to the queue. From the
pass 675 grade, past the held items: the empty minimap; then the shop portrait and the menu's
empty middle.
