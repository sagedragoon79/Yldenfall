# Pass 654: a hit bursts, and its number reads

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 650 (5.2/10). Passes 651 to 653 took its foreground, hung platforms and value split; the
next item in its order is "the sword's flat bar (held), a small spark and the damage numbers".
The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab
generations or Autosprite credits were spent.

## Audit

The eleven fight frames (`workbench/catalog/fights`). At 1x the spark is a star about 16 world
px across on the foe's near edge, held that small since pass 530 so the foe reads through it; the
streak (pass 592) is the only long mark of the blow. A cut's damage number draws the pixel font
at its own size (`DamageNumber.SIZES.hit` 10, scale 1): 7 px of glyph with a 1 px outline,
smaller than the struck foe's eye.

The first capture run failed every frame with `Identifier "BossPractice" not declared`: the
commit before this pass (#739) added a `class_name`, and this PC's `.godot` class cache had not
seen it. One `--editor --quit` import fixed it; nothing in the repository was wrong.

## What changed

Design bible 12.130 (new), 6.7 (the particles line) and 14 (damage numbers);
`scripts/fx/hit_spark.gd`, `scripts/fx/damage_number.gd`.

- **The burst.** Round the star, for its first 0.1 s (held through the hit-stop), eight spikes
  stand off the contact all round, from 10 to 28 world px, alternating long and short (0.62),
  3 px at the root (2 for the short ones) and pointed, white in the spark's hot rim, pulling 4 px
  outward as they fade. The middle stays open and the spikes have gaps, so the star, the blade
  and the foe show. The heavy finisher's is 1.6x. Both looks draw it.
- **The numbers.** A cut's number, and the hero's losses, draw at twice the font (14 px of
  glyph, a 2 px outline); a heavy blow's at three times.

Tried and dropped: even bars 2 px wide with a rim on both sides (they read as striped candy),
and a number that popped one size larger for its first 0.06 s (every still of a hit caught it at
its largest, 4x for a heavy blow, which dwarfed the foe). Judged by eye at 1x and 2x in every
fight frame (`heartwood-hit` and `spires-hit` looked at closest).

## Tests

- New `test_a_spark_bursts_wide_round_an_open_middle` (`tests/test_hit_impact.gd`): at full the
  moment the blade bites; eight spikes, reaching at least 26 px, none nearer than 9 px; as many
  ahead as behind; long and short alternate; the heavy one bigger; full for its first half and
  gone by 0.1 s; the code look draws it too.
- `test_damage_numbers_show_what_each_blow_dealt` (`tests/test_systems.gd`) now holds a cut's
  number at 2x, a heavy blow's at 3x and the hero's own losses at 2x.

Mutation check: with `BURST_REACH` 16 and `BURST_INNER` 0, the burst test fails 2 checks; with
the old sizes (10 and 20), the numbers test fails 2 checks.

## Full suite

FULL_SUITE_RESULT

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A landed blow reads at 1x: a burst round the contact and a number you can read. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a few polygons for 0.1 s per hit). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due at pass 655. Then, from the pass 650 grade in its order unless the
new grade reorders it: the Heartwood gate tree's flat band; repeated skyline and ruin cut-outs;
flat ceiling bands; the minimap's empty frame and plain health and mana; stamped spike rows. The
floor's level top line (12.127) waits behind them. Held as before: the Haar's fog, the hero's
size, the sword's flat bar; foes in mixed styles stays with the art loop.
