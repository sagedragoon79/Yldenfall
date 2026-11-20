# Pass 617: the town's skyline is a row of houses

## Category

Art cohesion (environments), from the independent grade taken after pass 610 (5.6 of 10):
"the plaza skyline's gridded windows", with the pass 615 grade's "the far skylines are flat
one-value silhouettes (plaza, storm ledge)". It was the top of the queue, the last unheld item
of the pass 610 grade.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Hearthroot's ridge layer (bible 12.12 and 12.83) was a row of flat-topped blocks. Every block
carried one lattice of windows, 8 px apart along the wall and 12 px down it (at 1x), and 95
percent of the crest was level. Behind the plaza it read as modern tower blocks. One body
color held 73 percent of the far plane.

## What was built

- **A roof of its own** (`tools/art/tilegen.py`: `_house`, `HOUSE_FORMS`): a gable, a hipped
  roof, a lean-to, or a narrow tower under a point or a notched crown; some carry a chimney.
- **More than one value** (`_town_detail`): four wall tones, a roof lit on its west slope and
  dark on its east, a shadow line at the eave.
- **A few windows a house**: one on about six storeys in ten, where the house's own hash puts
  it (a small one, a pair, an arched one), a third of them lit with a faint glow; slits in a
  tower, an attic light in some gables, a jetty beam on some walls.
- Only `assets/bg/hearthroot_ridge.png` changed; every other generated picture is byte for
  byte the same.
- Bible 12.94 (new); 12.12's list of ridge kinds says so.

Looked at in the plaza and the market, beside the picture from before. The grid is gone and
the row reads as an old town on a hill, with 48 warm lights in place of 80.

Not done: the Spires' ridge (the storm ledge half of the pass 615 item) is unchanged. The near
plane has no detail of its own. The houses run tall under their eaves, because the far plane
is filled down to the near crest; for Sean to judge in play whether they read as a hill town
or as towers.

## Tests

`tests/test_town_skyline.gd`, three new, reading the shipped picture:
`test_the_roofline_is_pitched`, `test_no_lattice_of_windows_runs_through_the_row`,
`test_the_far_plane_is_more_than_one_value`.

Mutation check: with the pass 616 picture put back, all three fail (2 percent of the crest
sloped; 45 of 80 lit windows a lattice step from another; one color at 73 percent). Restored,
they pass.

`tools/art/test_tilegen.py` (run by hand, not in CI): `test_ridge_houses_have_level_roofs`
became `test_ridge_houses_stand_level_under_roofs_of_their_own`; the lit-pixel count now
matches a light laid over a wall tone; the Spires' "fewer lights than the town" bound moved
from a quarter to two thirds, since the town no longer shows rows.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The town's skyline is houses; the Spires' ridge and the portraits remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The tiers that step by the tile (seen in pass 614), then the pass 615 grade's new items: the
Haar's lava column, the water's hard top line, the hit's missing flash in the fight captures,
and the Spires' ridge as more than one value. The next independent grade is due after pass
620. The Haar's fog and dither, the sprites' pixel size, the hero's rim light and the sword's
look stay held.
