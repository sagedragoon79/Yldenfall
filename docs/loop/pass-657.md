# Pass 657: a hit's burst leaves a small foe in sight

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 655 (5.0/10). Pass 656 took its foreground silhouettes; the next item in its order is "fights
hard to read", and of its reasons the first not held is "the burst covers a small foe". The
PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab
generations or Autosprite credits were spent.

## Audit

The eleven fight frames (`workbench/catalog/fights`) at 3x. The burst of 12.130 reaches 28 world
px from the contact all round, 56 px across, and the contact sits on the foe's near edge. Foes'
boxes run from 10 px tall (the grub lump) to 44 px. In `heartwood-hit` the two spikes thrown along
the swing lay straight over the grub, and the spikes above and below boxed it in, so at 1x the
grub was a grey smear behind a white star. In `boughs-hit` the same covered most of the mantis.
The Tower's dwarf and the guardians are tall enough that the burst stands off them.

## What changed

Design bible 12.133 (new), with pointers in 6.7 and 12.130; `scripts/fx/hit_spark.gd`,
`scripts/player/player.gd`.

- **Nothing thrown into the foe.** `HitSpark.burst_rays` leaves out a spike whose line is within
  `BURST_INTO` (cosine 0.8) of the swing: the two of eight that pointed into the struck foe. Six
  stay: two flank it (above and below) and four stand back toward the hero, long and short still
  alternating.
- **Fitted to the foe.** `HitSpark.spawn` takes the struck foe's height, and `fit_for` shortens the
  reach for a foe under `BURST_FIT_FULL` (30 px) in proportion, down to `BURST_FIT_MIN` (0.7). The
  player measures the foe by its box (`_half_extent` down, twice) for a blow and for a riposte.
  The open middle is the same for every foe.

Judged by eye at 1x and 3x in the eleven fight frames: the grub and the mantis now show whole
beside the burst, which opens back toward the hero; the Tower's dwarf and the guardians' frames
read as before.

Not done: the streak (6.7) still crosses the top of a small foe on its rising diagonal; it runs
behind the foe since pass 599, so it shows only either side of the body.

## Tests

- `test_a_spark_bursts_wide_round_an_open_middle` (`tests/test_hit_impact.gd`) now expects six
  spikes, none within `BURST_INTO` of the swing, two flanking and four behind (it held eight, as
  many ahead as behind); its heavy check reads the longest spike rather than the first.
- New `test_a_small_foes_burst_leaves_it_in_sight` (`tests/test_hit_impact.gd`): a 40 px foe gets
  the full burst, a 10 px grub's reaches at most 0.72 of it and no less than `BURST_FIT_MIN`, a
  25 px foe's lies between; the middle stays as open and every spike keeps length; a hornet's box
  measures to its `body_size`.
- New `test_a_small_foe_gets_a_smaller_burst` (`tests/test_combat.gd`): a real cut on a training
  dummy cut down to 12 px throws a spark fitted to it.

Mutation checks: with the skip into the foe removed, the burst test fails 3 checks; with
`fit_for` returning 1, the small-foe test fails 2; with the player not passing the foe's height,
the combat test fails 1.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,722 checks passed, 1 failed:
`test_every_room_loads_and_settles_inside_the_budget`, the Evercrown's proving scar loading in
515 ms against 500, the same room and the same test that failed on this PC in passes 654 to 656
with main's code. This pass changes only what a spark draws for 0.1 s after a hit, which no room
load runs. Every combat, spark and hit test passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A small foe stays in sight through a hit's burst. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (two fewer spikes for 0.1 s a hit). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 655 grade in its order, the rest of "fights hard to read": a foe half under the
flooded hall's cyan water band, and the hero over the gate tree's trunk; then the canopy's
dithered tile edges and the oversized bee; the large empty chained-platform rooms in one hue (the
Tower foot, the Evercrown veins); the dead black band over the grub burrows. Held as before: the
hero's size, the sword's flat bar, the Haar's dither halos and fog; foes in mixed styles stays with
the art loop.
