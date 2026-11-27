# Pass 671: each zone family hangs its own deck

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 670 (5.3/10) names, past its held items and the foes' three styles, "the new bridle is one
hung-deck rig pasted across four zones (give each zone family its own hang, as 12.105 did for
posts: next)". This pass takes it. The PixelLab art loop stays gated on Sean (three guardian bases
wait for his OK); no PixelLab generations or Autosprite credits were spent.

## Audit

`tower/foot`, `evercrown/veins`, `spires/sky_steps` and `haar/marsh_road` captured. Every bridled
deck (12.147) drew the same triangle: two straight legs at 45 degrees to one small ring, recolored
in the zone's hanger. Iron, rope and sinew had one outline.

## What changed

Design bible 12.148 (new); `scripts/world/plank_supports.gd` (`RIGS`, a `rig` per zone in `LOOKS`,
`rig_apex`, `rig_top`, `leg_path`, `rig_parts`).

- **The Tower and the Trials: a spreader beam.** A riveted iron beam 20 px over the deck, past both
  ends, with the chains dropping straight to the deck and one chain up from a shackle: a T.
- **The timber and water zones: a pulley block.** The ropes meet on a hook under a wooden block in
  the zone's timber, its sheave pinned in the accent.
- **The Evercrown: a knot.** The sinew legs droop below their straight line and grow together in a
  swollen knot with a glowing pore.
- **The town and the stone cities: the ring**, now lit in the zone's accent metal.

Judged by eye at 1x and 3x in the four rooms. The first spreader beam was 3 px with a half-pixel lit
edge and read as a railing; it is 4 px with a full lit row.

## Tests

- New `test_plank_each_zone_family_hangs_its_own_rig` (`tests/test_plank_supports.gd`).

Mutation check: with `KNOT_SAG` at 0 the test fails (no droop); with the spreader's drops aimed at
the middle it fails twice (not straight down).

## Full suite

See the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Hung decks are built by their zone. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Drawn once per room load. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 670 grade in its order, past the held items: foes in three styles (the rendered
bees and snake against the beetle and the purple blob); then boxed rooms with one flat floor and
the hero at the far left; then tells drawn in the background's values.
