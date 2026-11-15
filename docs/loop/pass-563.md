# Pass 563: Vorrhallow's stillglass grows out of the stone

## Category

Art cohesion, from the independent grade taken after pass 560 (4.9/10): "Vorrhallow's magenta
stillglass shards are scattered at random angles like floating spears, attached to no rock."

No note from Sean was new. The queue's first items are parked for a watched session (lighting and
depth) or wait on the Haar branches and on Sean's OK of a base, and the Boughs' foliage and the
hero's size are watched-session or PixelLab items too, so this is the first one that can be built
unattended. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean.

## Audit

- The spears are not decor or props: they are painted into the two parallax backdrops by
  `tools/art/tilegen.py`.
- `vorrhallow_far` drew nine clusters at random points of the layer, so most hung in the open air
  between the far pillars.
- `vorrhallow_mid` drew one needle per column, 30 to 70 px long and 7 px wide at its thickest,
  starting in the middle of the column at a random angle. It touched the stone, and still read as
  a spear laid across the pillar.
- The floor shards (`decorgen.vorrhallow_shards`) and the hanging glass under the ceiling are
  seated already.

## What was built

- `stillglass_shard`: one prism in whole world pixels, broad at the root and tapering, a lit
  facet with a bright rim toward the top-left light and a facet in shade.
- `stillglass_growth`: a seated cluster. Cracks into the stone, a leader that leans up and away
  from the face, two or three shorter shards beside it with their roots spread along the face,
  and a ragged wine crust on the face across the roots.
- The far layer seats its nine clusters on the far pillars' faces. The mid layer seats one on
  each broken column and, on about half, a lesser one lower on the other face. The seats are
  recorded in `STILLGLASS_SEATS`.
- `assets/bg/vorrhallow_far.png` and `vorrhallow_mid.png` regenerated. A whole run of tilegen
  also rewrote five other mid layers (boughs, haar, hearthroot, heartwood, trials); those are not
  this pass's and were put back. It goes on the queue as a tooling item.
- Design bible 12.51.

Looked at in `vorrhallow/gate_hall` and `vorrhallow/throne_hall` at 1x and 2x, before and after. A
first take seated each cluster on a line square to its own lean, which read as a flock of birds;
the crust now lies on the pillar's face.

## Tests

`tools/art/test_tilegen.py` (71 checks): `test_vorrhallows_stillglass_is_seated_on_the_stone`
(every seat is on a pillar's face, the glass is 8 px or more across at the root, it stands out
from the face, and no lit rim lies farther from a seat than a leader reaches) and
`test_a_stillglass_shard_has_two_facets_and_a_lit_rim`.

Mutation check: far seats at a random x fail the first ("on no pillar's face"); a 3 px leader
fails it ("no lit rim"); a one-colour body fails the second ("two facets").

Full suite: 15270 checks passed and 3 failed, all three in `tests/test_reachability.gd`
(`test_the_throne_lies_behind_the_flesh_only_the_severance_cuts`,
`test_the_sunken_spring_lies_under_the_last_stone_of_the_rise`,
`test_ladders_never_open_a_gated_room`) and all with the same leak report: "saves changed
(save_8.json, save_8.json.bak)". None of them writes a save. Another worktree on this PC was
running the test runner at the same time, and the suite shares `user://` with every checkout
(pass 399), so its test saves showed up as this run's leaks in the three slowest tests. Rerun with
no other Godot process running, each of the three passes.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Vorrhallow's glass belongs to its pillars. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The next independent grade is due after pass 565, or after the next art pass, and uses fight
frames. Of the queue: one-template rooms, then the trimless floor and ceiling bands, then the
Sunken Spring's pillars and water. The Haar items wait until the hydra and steam branches merge;
the Blinkhop waits for a free base slot.
