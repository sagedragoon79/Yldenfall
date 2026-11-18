# Pass 601: the Spires stand on a ridge of their own

## Category

Art cohesion and zone identity, from the independent grade taken after pass 600 (5.2 of 10): "the
same X-braced trestle and the same skyline of window-dotted rectangles repeat across areas (skyline
in the plaza, the storm ledge, the shop and the Spires hit frame)". The skyline is this loop's own
doing: pass 598 gave Hearthroot and the Spires one roofline ridge. It was pass 600's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
600 waited for CI, on top of pass 600's commit. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No
PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still down (its
Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- `RIDGE_KIND` gave both Hearthroot and the Spires the "roof" kind, and pass 598 dressed every roofline
  block as a house with rows of windows. In the grade's set that skyline stands behind the plaza, the
  shop (in the plaza) and both Spires frames, so a frame of the storm reads as the town.
- The Spires' own far layer draws ruined towers on its sky islands (`ruined_spire`): tall, narrow,
  with a broken crown and one warm window. Nothing in the ridge echoed them.

## What was built

- **Ruined spires** (bible 12.84, `tools/art/tilegen.py`): a ridge kind for the Spires alone. Tall
  narrow towers (6 to 12 px wide, 30 to 60 px above the roll) stand level at their centres' ground,
  under a steep point or a broken, notched crown, 26 to 48 px apart over rolling ground. Each has a
  lit west wall, a shadowed east edge and one or two slit windows high up, some lit ember-2. The
  nearer plane repeats them lower and darker.
- Hearthroot keeps the roofline and its rows of windows, so the window-dotted skyline is the town's
  alone.

Judged by eye at 1x and 2x in the storm ledge and the Fallen Bridge: a field of ruined spires stands
behind the sky islands, with red slits, and a darker row in front.

## Tests

`tools/art/test_tilegen.py` (84 checks pass), `test_the_spires_stand_on_a_ridge_of_their_own`: the
Spires' ridge kind is not the town's, its tall runs are all narrow (six or more), and its lit windows
are fewer than a quarter of the town's. The pass 598 ridge guards still pass for every zone. Mutation
check: giving the Spires the roofline again fails it.

Full suite: 21,890 checks passed and 4 failed, all wall-clock budgets on a busy PC (two Unity editors
were open): `test_a_journey_after_the_end_stays_lean` (three lone frames past 100 ms) and
`test_every_room_loads_and_settles_inside_the_budget` (`evercrown/proving_scar` loaded in 584 ms). This
pass changes one backdrop picture and its painter, no game code; pass 600's CI passed the same tests.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Spires stand on their own ridge; the shop panel and the trestle's repeats remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 600 grade: the struck foe that goes semi-transparent at impact and merges with the
white sword and arc (find why the soft wash reads as see-through, and keep the body opaque); then the
minimap's single rectangle and plain HUD box, and the X-braced trestle repeated across zones. The
Haar's fog, the sword's look and the sprites' pixel size stay held.
