# Pass 666: the water is held, and climbs round a wader

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 665 (5.5/10). Past its held items, its note names the Flooded Hall's tide band "with nothing
round the feet" as next, with the Source Hall's water "a hard-edged box ending in a vertical line".
This pass takes both. The PixelLab art loop stays gated on Sean (three guardian bases wait for his
OK); no PixelLab generations or Autosprite credits were spent.

## Audit

- **The Source Hall.** Captured and cropped at 2x: the pool's top two rows (13 and 14) stood two
  tiles over the ledge beside them (row 15), so its right side was a wall of water against open
  air from the surface down to the ledge. That is the vertical line the grader saw.
- **Every room's swim water,** scanned for a water cell with open air at its side: besides the
  Source Hall, the Spring Gate had three dry cells inside its water. A chest (`$`) and a figure
  (`F`) set in the water each kept a dry cell, because the room marks only `a` and `l` cells as
  water, and one cell under the stone by the east door was `.` with water on three sides.
- **The Flooded Hall,** captured standing and wading at 6x: a one-pixel line crosses the wader,
  and nothing else meets the water. Wading, the hero's step spray (`Dust`, "wade") came out of
  one point as seven 2-pixel drops: a flat pale square on the hip at every step.

## What changed

Design bible 12.142 and 12.143 (new); `levels/sunken/source_hall.room`,
`levels/sunken/spring_gate.room`, `scripts/world/room.gd`, `scripts/world/tide.gd`,
`scripts/fx/dust.gd`.

- **The Source Hall's pool lies level with its ledge** (row 15, five tiles deep), so it meets stone
  at both ends and laps there.
- **What is set in the water is under it.** `Room.water_holes` fills an open cell with water over
  it and water, stone, a slope, a board or a door at each side and under it, from the top down.
  `Room.unheld_water` names any water cell with open air at its side or under it; no room has one.
  The Spring Gate's cell by the door is water in the room file.
- **The water climbs round a wader** (`Tide.collar`): a meniscus at each edge of the body, two rows
  high and narrowing a pixel a row up, in the bank foam's colour; a moving wader pushes a bow wave
  six pixels out in front, fading ahead.
- **Silt off the floor:** a moving wader stirs a pale puff from behind its feet every 0.2 s that
  rises and drifts back over a second.
- **Spray in single drops:** the wade spray is 1 px drops strung 4 px either side, not a 2 px
  pile on one point. Dust off dry ground is unchanged.

Dropped on the way: a shadow of the feet on the floor under the tide (it could not be seen through
the tide's dark floor tone), and a second spray thrown by the tide itself (the step spray is one).

Judged by eye at 1x in the Source Hall and the Spring Gate (before and after), and at 1x and 6x in
the Flooded Hall, standing and wading both ways.

## Tests

- New `tests/test_water_held.gd`: `test_no_room_holds_water_up_with_nothing` (every room, and the
  rule on a small grid), `test_the_source_halls_pool_lies_level_with_its_ledge`,
  `test_what_is_set_in_the_water_is_under_it` (the holes' rule, a pocket two cells deep, an open side
  and the air over the surface left dry, and the loaded Spring Gate's chest in its water).
- New `test_the_water_climbs_round_a_wader` (`tests/test_tide_wake.gd`): the collar's place and
  shape, the bow wave in front either way and none for a drift, the silt's rise, drift and fade,
  silt behind a hero running in the hall and none standing, and the wade spray's single drops.

Mutation check: with the Source Hall's old water rows the rule and the level test fail; with the
room's filling of holes taken out the loaded Spring Gate's chest is dry and the test fails; with the
bow wave never pushed, and with the wade spray piled on one point, the collar test fails.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,315 checks passed, 3 failed, all timing budgets:
`test_spires_rain_stays_cheap` (10.84 ms) and `test_every_room_loads_and_settles_inside_the_budget`
(`evercrown/proving_scar` 506 ms and `gym/gym` 504 ms to load, `spires/sky_steps` 8.07 ms a frame).
The hole scan then returns at once in a room with no swim water. Rerun alone, the rain test passed;
the room budget failed on load time in three rooms with no swim water (`proving_scar` 543 ms,
`gym` 560 ms, `vorrhallow/throne_hall` 510 ms), as it did in pass 665 with that pass's code taken
out. The PC was running Unity and Chrome. CI (test and mix) is the clean run.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; a wader's legs meet the water. |
| World and level design | 15 | 99 | No water stands on nothing. |
| Art cohesion | 15 | 98 | The tide and the pool meet what is in them. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A few rects a wader. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 665 grade in its order, past the held items: fights that don't read (the foe and
its spark lost on the Heartwood gate, hero and beetle bodies merged on a hit, the flooded hall's
tell shows no attack); then the black foreground blobs at the foot of the frame.
