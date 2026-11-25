# Pass 655: the root through the high seat is round

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 650 (5.2/10). Passes 651 to 654 took its foreground, hung platforms, value split, spark and
damage numbers; the next item in its order is "the gate tree in the Heartwood tell, a flat
unshaded band". The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK);
no PixelLab generations or Autosprite credits were spent.

## Audit

The "gate tree" is the root that has come up through the Rot Dwarf Hall's high seat (`HighSeat`,
12.62), the landmark behind the `heartwood-tell` fight frame. The seat's frame (pillars, lintel,
back) is what reads as a gate. The root was drawn one row at a time as three straight strips: a
lit strip a third of its width on the west, the mid tone, a dark strip on the east, with a 1-in-7
speck for bark. At 1x, down 288 px of height, that is a flat painted band; nothing turns it.

## What changed

Design bible 12.131 (new) and 12.62 (a pointer); `scripts/world/high_seat.gd`.

- **Round.** Each pixel's tone comes from a round trunk's normal against a light from the upper
  left and toward the viewer (`LIGHT`), leaning with the root where it wanders: a lit band west of
  the middle, the mid tone, a shaded east third, the mid-to-shade edge broken in a checker. The
  outermost pixels keep 12.62's rule (lit west edge, shaded east edge).
- **Barked.** Furrows run all the way round, `FURROW_STEP` (0.72 rad) apart, twisting as the root
  climbs; seen from the front they bunch toward the edges, which turns the trunk. Each is broken
  here and there. Between them the bark lies in plates 14 to 24 rows tall, with a shaded foot and
  a bark-3 lip on the lit side (`BARK_LIT`, still darker than the timber's lit edge). Two knots.
- **Its shadow.** The root throws a 5 px shadow east on the seat's back and the lintel (`CAST`).

Tried and dropped: plates every 6 to 11 rows with most of the width lit (a brick wall). A first
furrow rule numbered five furrows and let the twist carry them all off the trunk's face in its
upper half; the furrows now repeat round it. Judged by eye at 1x and 2x in `heartwood/dwarf_hall`.

## Tests

- New `test_the_root_is_round_and_barked` (`tests/test_high_seat.gd`): lit west of its middle and
  shaded east of it in at least four rows of five; bark marks at least half the rows; the plate lips
  only where the trunk faces the light; at least four furrows on its face, closer at the edge than
  the middle; its shadow on the seat's back.
- The other high seat tests (palette, frame, split, sap, the room) pass unchanged.

Mutation check: with the old three strips and no cast shadow, the new test fails 2 checks
(roundness 4 of 229 rows; the shadow 3 of 5 px).

## Full suite

One full run (`TEST_TIMEOUT=7200`) on a busy PC: 37,683 checks passed, 3 failed, all frame-time or
load-time budgets in two tests: the Spires' rain (8.18 ms) and every room's load and settled frame
(four rooms loaded in 549 to 669 ms against 500; two settled rooms at 9.9 and 10.6 ms against 8).
Run alone, the rain passed. The room budget failed again, on a different set of rooms (the gym, the
Evercrown's proving scar and the Hearthroot plaza loading in 535 to 626 ms; the Haar's Polesend at
8.04 ms). It never named the Rot Dwarf Hall, the only room with the high seat, and the seat is baked
once a run. Pass 654 found the same test failing the same way with main's code on this PC. A run with
main's `high_seat.gd` was tried again and printed no result. Every high seat test passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Heartwood's landmark root is round and barked, not a flat band. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (the seat is baked once). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (pass 655), after the merge. Then, from the pass 650 grade in its
order unless the new grade reorders it: repeated skyline and ruin cut-outs; flat ceiling bands; the
minimap's empty frame and plain health and mana; stamped spike rows. The floor's level top line
(12.127) waits behind them. Held as before: the Haar's fog, the hero's size, the sword's flat bar;
foes in mixed styles stays with the art loop.
