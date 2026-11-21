# Pass 626: mass that hangs over open air is in shadow

## Category

Art cohesion (environments). The top item of the queue, the first defect of the pass 625
grade: "terrain is a uniform fill cut into 45-degree stairs, with no top-lip variation, no
shadowed underside and no large form (aqueduct, canopy bridge, storm ledge, Spires hit,
flooded hall): give a sloped ceiling a shadowed underside".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the storm ledge and the drowned aqueduct at 1x. A ceiling's lowest course was the
lightest tier of its stone, as bright as the top of a lit floor, over a 7 px dark rim. The
cause is the lighting model: the tiers (12.8) and `DeepShade` (12.38) darken ground by its
distance from open air, whichever way the air lies. Nothing in the room knew an underside
from a floor, apart from `EdgeShade`'s rim.

## What was built

Design bible 12.102.

- **`SoffitShade`** (`scripts/world/soffit_shade.gd`), built by `Room` between the rim and the
  deep shade. A ground cell with open air under it, or a haunch, is at full shade (0.58 of
  near-black). The shade climbs the mass above it, a quarter a cell, and holds at half, so a
  ceiling is in shadow up to where the deep shade takes over. It spreads sideways, 0.3 a cell,
  so a ceiling feathers into its wall.
- **What keeps its light:** walking surfaces (a cell with air above it), floors, walking
  slopes, and a wall's face below the ceiling.
- **Drawn** as one baked texture per room load, a pixel per 2 px block, stepped to four levels
  with `DeepShade`'s dither. A second shade on the secret layer covers secret cells; a torn
  floor bakes it again.

Thrown out or fixed on the way:

- The first strength (0.44) was hard to see on the aqueduct's pale stone. 0.58 reads at 1x.
- The first build drew the shade as rects (runs of blocks), as `DeepShade` does. The room
  budget test showed a higher load time, so the shade is baked into an image with
  `Image.fill_rect` for evenly shaded cells and one blend per block elsewhere.

## Checked by eye

The storm ledge, the drowned aqueduct, the canopy bridge, the flooded hall and the Proving
Scar at 1x; the aqueduct's arch and the ledge's overhang before and after at 1.5x. Ceilings
read as shadowed mass over a lit floor, the canopy bridge's terrace is lit on top and dark
beneath, and no open half of a haunch is shaded.

## Tests

`tests/test_soffit_shade.gd` (seven tests, 51 checks). Mutation-checked:

| Mutation | Result |
| --- | --- |
| `HOLD` 0 | fails: the top of the room's ceiling is bare |
| `SPREAD` 1 (no feather) | fails `..._feathers_into_the_wall_it_springs_from` |
| walking surfaces shaded | fails `..._a_walking_surface_keeps_its_light` (3 checks) |
| a haunch shaded over its whole cell | fails the haunch test and the room test |
| `Room` never sets the shade up | fails the room test (4 checks) |
| no cell is a source | fails six tests (17 checks) |

`test_soffit_the_shade_holds_all_the_way_up_a_ceiling` compares against `HOLD` itself, so the
`HOLD` 0 mutation is caught by the room test and not by it.

Room budget (`test_every_room_loads_and_settles_inside_the_budget`): run six times while
building, three with the shade and three without. Load totals over the 127 rooms were 15.1 to
18.7 s without it and 16.4 to 17.7 s with it, and both variants went over the 500 ms mark in
some run (the wall-clock flake of passes 599 to 605 and 625). The shade's cost is inside that
noise. Headless frames do not render, so the per-frame figures say nothing about drawing; the
shade is one texture.

Full suite: 32,536 checks passed, 0 failed (pass 625: 32,484 and the one wall-clock flake).

## Not done

- The stair: ceilings are still cut along the tile grid and its haunches. The grade's "larger
  shapes" and "top-lip variation" stay in the queue.
- The shade does not follow a secret wall once it opens.
- A pier that hangs into water is shaded all the way up.
- `test_edge_shade.gd` and `EdgeShade` are unchanged; the 7 px rim stays under the new shade.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Ceilings are in shadow; the stair, the fog and the dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 625 grade's items, in its order: the stair's larger shapes and the top
lip; the plank on two posts (vary the board, the posts and the run's outline by zone, or carry
runs on ledges, boughs or chains); chests, signs and pickups against the scenery; the rain's
splash and wet stone and the lightning's light; the one-value midground bands. The next
independent grade is due after pass 630. The Haar's fog and dither, the sprites' pixel size,
the hero's rim light and the sword's look stay held.
