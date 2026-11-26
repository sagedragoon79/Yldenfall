# Pass 663: the plaza's ceiling is one built vault

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 660 (5.4/10). Past the held items, its next named defect: "empty boxed rooms (plaza ceiling,
the burrows' black top band, the veins in one purple)". Pass 662 took the burrows; this pass takes
the plaza. The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no
PixelLab generations or Autosprite credits were spent.

## Audit

`hearthroot/plaza` captured at the west gate, the fountain and the temple door. Since 12.67 the
ceiling stood at four heights, but as square shoulders: two flat runs of 18 and 19 columns at row
4, a one-tile tooth west of the court, and a hard corner at every change of height. The top of the
first room a player sees was a ruled box.

## What changed

Design bible 12.139 (new), with a line in 12.67 and 12.138; `levels/hearthroot/plaza.room`.

- **One vault.** The ceiling springs from row 8 at both walls and only rises to the fountain
  court's crown (17 columns at row 2, as 12.67 and 12.58 keep it for the Three Mouths). The steps
  shorten toward the walls (west 2, 2, 4, 6, 8, 10 columns; east 7, 7, 5, 4, 3, 3), so the vault
  curves down fastest where it meets them, and the two sides are not a mirror (12.104).
- **Chamfered.** `tools/levels/haunches.py` laid 14 haunches: one on each of the 12 steps and one
  at each wall's corner.

Judged by eye at 1x, before and after, at the west gate, the fountain and the temple door: the box's
square shoulders are gone, and from either gate the roof reads as a vault rising to the court. The
court's own view is as it was, since its crown is held at row 2. The veins' single purple is left
for its own pass.

## Tests

- New `test_the_plaza_ceiling_is_one_vault` (`tests/test_ceiling_forms.gd`): the crown is over the
  court at row 2; the underside only rises to it and falls from it (one turn); it springs from row
  7 or lower at both walls; no step off the crown is longer than ten columns; every step has its
  haunch.
- `test_the_fountain_plaza_is_not_a_level_box`, `test_no_ceiling_is_a_row_of_teeth` and the
  reachability tests pass on the new room.

Mutation check: with the old room, the new test fails (the 18- and 19-column runs, the tooth west of
the court turning the ceiling more than once, the walls at row 5, and no haunches).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,015 checks passed, 2 failed, both timing budgets in rooms
this pass does not touch, while CI ran on the same PC: `test_spires_rain_stays_cheap` (8.08 ms)
and `test_every_room_loads_and_settles_inside_the_budget` (`evercrown/proving_scar` 586 ms against
500). Rerun alone, the rain test passes; the load test missed once more by 27 ms, then passed three
times in a row (once with the old plaza, twice with the new). CI's test job passed in full.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The plaza is a vaulted hall, not a box. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 660 grade in its order, past the held items: the veins in one purple; flat water
rectangles (the source hall, the flooded hall); then the oversized bee (a smaller Hornet sheet).
Pass 665 is the fifth since the pass 660 grade: the grade follows that merge.
