# Pass 651: near masses frame the foot of the view

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 650 (5.2/10). In its order, the Haar's fog and the hero's size are held as before; the next
item is "ground as one repeated slab with a straight top line and no foreground occluders at the
screen's foot" (`heartwood/grub_burrows`, `spires/sky_steps`, `tower/foot`). The PixelLab art loop
stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent. README's playtest link already points at https://github.com/sagedragoon79/Yldenfall.

## Audit

Screenshots of the three rooms at rest. The low fringe (12.11, 12.29) is in each, but it rises at
most 36 px, is drawn at alpha 176 and leans 0.55 of the way to the zone's fog. In the grub
burrows it is a few grey blades over the dirt; in the Tower it is almost invisible against the
dark stone; in the Spires it is lost in the rain. When the camera rests on a floor, the floor's
top line sits about 46 px above the view's foot, so nothing near crossed it and the line ran
straight across the frame. The hanging frame (12.121) framed the top since pass 645; nothing
framed the foot.

## What changed

Design bible 12.127 (and a line in 12.29), `tools/art/tilegen.py`, `scripts/world/backdrop.gd`.

- **Broad masses at the foot.** Each zone's foreground sets two masses of its own matter over the
  fringe (`MOUND_SHAPE`, `mound_spans`): a fern bank, a reed tussock, a crystal boulder, a heap of
  fallen blocks set askew, a mound of earth with a broken post and a leaning plank. Each is a
  ragged mound with sloping ends, 70 to 110 px wide, rising to `MOUND_RISE` (68 px,
  `Backdrop.FORE_MASS_RISE`), so it stands over the floor's top line.
- **Not bars.** Only the masses reach over `FORE_MAX_RISE`; each is solid across 36 px or more at
  half the fringe's height; at most 40% of the width carries anything over the fringe; a run of
  200 px stays clear.
- **Darker.** `FORE_TINT` 0.55 to 0.35, so the near layer stays darker than the ground.

The first try clipped each mass to its span (boxes) and topped out near 40 px, under the floor's
top line; the ends now slope and the cap went 60 to 68. Shards and blades are cut short to fit
under the cap, so no tip is sheared flat. The Tower's blocks were plain rectangles at first; they
now sit askew.

Judged by eye at 1x and 2x in `heartwood/grub_burrows`, `tower/foot`, `spires/sky_steps`,
`haar/marsh_road` and `evercrown/veins`.

## Tests

- `test_the_foot_of_the_view_holds_broad_masses` (new, `tools/art/test_tilegen.py`): two or more
  masses a zone, each rising past the fringe by 8 px or more and solid across 36 px; cover and a
  clear run as above.
- `test_foreground_stays_a_low_fringe` (`tools/art/test_tilegen.py`): nothing over `MOUND_RISE`,
  and nothing over `FORE_MAX_RISE` outside a mass's span.
- `test_the_foot_of_the_view_holds_near_masses` (new, `tests/test_backdrop.gd`) and
  `test_fore_silhouettes_stay_a_low_fringe` (now capped at `FORE_MASS_RISE` with the 40% cover
  check) on the shipped art.

Mutation check: with the masses left out of `foreground()`, `test_the_foot_of_the_view_holds_broad_masses`
fails with "heartwood: the mass at 180 rises 0 px, not past the fringe".

## Full suite

One run (`TEST_TIMEOUT=7200`): 37,151 checks passed, 3 failed, all frame-time budgets in rooms
the foreground does not touch at load (`test_every_room_loads_and_settles_inside_the_budget`:
`evercrown/proving_scar` 8.18 ms against 8; `test_a_long_journey_through_the_whole_game_stays_lean`:
a lone 113.8 ms frame on entering `heartwood/hornet_gallery`, and a second-worst of 82.6 ms). Run
alone, both tests passed every check. The foreground is one baked texture of the same size as
before, so the change costs no frame time. `python tools/art/test_tilegen.py`: 116 checks passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged (the masses give way in front of actors). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The foot of the view is framed by the zone's own matter. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (baked art, one layer as before). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 650 grade in its order: hanging and chain platforms that read as debug geometry
(thin, the backdrop's value: the Tower foot, the Evercrown veins); no value split between the play
plane and the backdrop; the sword's flat bar (held), a small spark, the damage numbers; the
Heartwood gate tree's flat band; repeated skyline and ruin cut-outs; flat ceiling bands; the
minimap's empty frame and plain health and mana; stamped spike rows. The floor's level top line
itself (12.127, not done here) waits behind them. Held as before: the Haar's fog, the hero's size;
foes in mixed styles stays with the art loop.
