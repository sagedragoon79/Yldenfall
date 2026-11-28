# Pass 681: the ground under a floor is one fall into shadow

Date: 2026-11-28. No new notes from Sean. From the queue, first item: the independent grade of
pass 680 (5.2/10), its first named defect past the held items: "the source hall's heavy dark
ellipse under its floor, where the pass 680 floor shade lies on the deep shade". The PixelLab
art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or
Autosprite credits were spent.

## Audit

The Source Hall shot fresh from `main` and read at 1x and 2x. Under the east ledge the ground
stood at 6 to 12 of 255 over most of eight tiles: a black blob with no brickwork, bounded by
the lit steps of the pool's bed. Two shades met there:

- `DeepShade` (12.38) sank the ground radially, by its distance from the pool and the walking
  line, to 0.86 of near-black. That radial falloff is the ellipse's shape.
- `FloorShade` (12.157, pass 680) laid its own 0.7 over it: 0.96 together.

A first fix that only eased `FloorShade` off the deep shade (no stacking) moved the deepest
ground from 8 to 9 of 255: the blob was mostly the deep shade's own. So the ground under a floor
now stops at the floor shade's full darkness as well.

## What changed

Design bible 12.158 (new), notes in 12.38 and 12.157; `scripts/world/deep_shade.gd`,
`scripts/world/floor_shade.gd`, `scripts/world/room.gd`.

- **`DeepShade.cap_under_floors`.** With `floors` set (the room sets it), every cell at or under
  a floor's top (`FloorShade.floor_tops`) is held at a field of 0.7 / 0.86, the floor shade's
  full. Walls, hanging mass and the secret layer's shade are untouched; the deep forms need a
  full field, so they stay out of that ground. `DeepShade.field()` exposes the field.
- **`FloorShade.eased`.** The floor shade adds only `(want - deep) / (1 - deep)`, so the two
  together are as dark as the darker of them. Drawn as one triangle list (four strips to a
  column, a row every half tile below the falloff), coloured at the corners.

After: the deepest ground under the ledge rose to about 20 of 255, and the brick courses read
down to the frame. Judged by eye at 1x and 2x beside the picture from before: the black hole is
now brown ground in shadow, grading by depth under the walking line. Checked at 1x in the Tower
foot, the veins and the Hearthroot plaza: their floors are thin and unchanged.

## Tests

`tests/test_floor_shade.gd`:

- `test_the_floor_shade_only_adds_what_the_deep_shade_has_not_given`: the easing reaches the
  floor's darkness and no more, nothing over a deeper shade.
- `test_the_ground_under_a_floor_sinks_no_darker_than_the_floor_shade`: the ground under a
  thick floor stops at the cap and reaches it; without `floors` it sinks to full; mass hanging
  over the room still sinks to full.
- `test_the_source_hall_has_no_dark_ellipse_under_its_floor`: over 2,500 samples under the
  hall's floors, the two shades never stack and never pass the floor shade's full.
- `test_the_named_floors_fall_into_shade` now checks the two shades together.

`tests/test_deep_shade.gd`: the built room's mass under its floor is dark but held at the cap,
and `test_ground_held_under_a_floor_is_one_rect_a_cell` keeps a held cell to one rect.

Mutation check: with the cap off, three tests fail; with `eased` returning the floor's own
darkness, the easing test fails 11 checks and the Source Hall test 1,562; without the one-rect
shortcut the held-cell test fails both checks (5,600 rects for 400 cells).

## Load cost

The first full run showed the cap's cost: the held ground sat between two shade steps, so every
deep cell under a floor broke into 64 dithered blocks, and the Proving Scar, the gym and the
Stillness loaded in 560 to 700 ms against the 500 ms budget. A held cell is now one rect at the
floor shade's full, which also leaves fewer rects than before the pass (Proving Scar 26,249
against 28,768). The floor shade's draw was rewritten the same pass: one triangle list built from
shared corners, stopping where the deep shade already covers the column (about 5 to 10 ms a room).

## Full suite

Two-hour run before the load fix: 41,389 checks passed, 5 failed, all timing checks on a busy PC
(the Spires rain at 9.23 ms, the Sky Steps frame at 10 ms, the room-load budget above, and a stray
`save_8.json` from the save-failure test caught by the fog test's global-state check). Each passes
on its own: the rain (5/5), the fog (1/1), the foes' spoils (3/3), and the room-load budget twice
in a row (3/3) after the fix. After the fix every shade, deep, dark, mass, secret and floor test
passes (8,578 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The ground under a deep floor reads as brick in shadow, not a black blob. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 680 grade, past the held items: the canopy bridge's hit frame (the red ring stacked
on the mantis under the 24; try a thinner or partial ring); then foes in different styles (the
snake floats with no contact, the harpy a grey lump).
