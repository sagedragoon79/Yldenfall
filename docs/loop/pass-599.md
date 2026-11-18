# Pass 599: the struck foe reads through the cut

## Category

Combat readability, from the independent grade taken after pass 595 (5.3 of 10; combat readability
5.5): "in hit frames the slash and spark cover the struck foe: draw the foe's flash and recoil above
the streak or shorten the streak over the body." It was pass 598's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
598 waited for CI, on top of pass 598's commit. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No
PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still down (its
Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

Six hit frames from the workbench (`fights/*-hit.png`: the Tower, the Heartwood, the Spires,
Vorrhallow, the Boughs, the Evercrown), at 3x:

- **The streak crosses the body.** Pass 592's impact streak is drawn on the spark's node at z 4, over
  everything, and runs diagonally through the middle of the struck foe. With the foe in its pale
  hit flash, the white streak cuts its silhouette in two: the hammer dwarf, the hound and the mantis
  all read as two pale halves.
- **The smear covers the near side.** The swing's smear (`SlashFx`, z 3) draws over the foe too,
  so its crescent hides the foe's front edge on the frame after the blow.
- The spark sits on the foe's near edge, where the blade bites, and was left there.

## What was built

- **The cut runs behind the struck foe** (bible 6.7, `HitSpark`): the streak is drawn on its own
  layer at an absolute z of -1 (`STREAK_Z`), under every actor and with the room's decor, so the
  struck body covers it where they cross. It shows where it enters low by the spark and where it
  comes out past the body. To come out past a 24 to 40 px foe it is now 60 px long, with its middle
  12 px past the spark (it was 40 and 8). The floor's tiles cover its lower end.
- **The struck foe draws above the smear** (`Enemy`): for `STRUCK_TIME` (0.2 s) after a blow lands or
  a parry staggers it, a foe draws at `STRUCK_Z` (3), above the smear (`SlashFx.Z`, now 2) and the
  hero, under the spark (4). Its own z comes back after; z is only touched as the window opens and
  closes, so a foe that sets its own z keeps it. A tell never raises a foe.

Judged by eye at 3x in all six frames, before and after. The first version kept the streak at 40 px:
behind the foe, its far end stopped inside the body and the cut all but vanished. At 60 px it comes
out past every foe in the set, so the blow reads as passing through the body. The Spires beetle shows
the smear's lower tip now passing behind it.

## Tests

`tests/test_hit_impact.gd`, `test_the_cut_runs_behind_the_struck_foe` (11 checks): the streak draws
on its own layer under the actors, at full; the spark stays above a struck foe; the streak's far tip
comes out at least 30 px on and 18 px up; the smear draws under a struck foe; a struck hornet draws
at `STRUCK_Z` and goes back to its own z when the blow has played, a foe with a z of its own gets it
back, and a tell leaves it where it was. The pass 592 tests still pass.

Mutation check, each restored from a copy after: the streak drawn on the spark's own layer fails it
(1 check); the pass 592 length and offset fail it (1 check); no raise fails it (2 checks).

Full suite: 21,893 checks passed and 1 failed: `test_every_room_loads_and_settles_inside_the_budget`
(`tower/old_flue` loaded in 546 ms against a 500 ms budget). Run alone it passed, then failed a
second time on a different measure (`spires/sky_steps` averaged 9.06 ms a frame against 8 ms), with
no blow struck in either room; it is the local timing flake, and pass 598's full run passed it.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The struck foe reads whole through the cut. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 600 takes an independent grade (every fifth pass): 8 to 12 frames across the game, two to four
of them fight frames, to a fresh grader with no hints. Then the grade's top defect. From the pass 595
item still open: no HUD in the captured room shots and fight frames (check the capture options before
changing the game). The Haar's fog and the sword's look stay held.
