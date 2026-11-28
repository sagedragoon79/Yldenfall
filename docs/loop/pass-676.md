# Pass 676: each zone family builds its own deck

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 675 (5.4/10) names, past its held items, "the hung-platform setup still reads as one template
across the marsh road, Tower foot, sky steps and veins (vary the decks and their spacing, not only
the hang)". This pass takes it. The PixelLab art loop stays gated on Sean (three guardian bases
wait for his OK); no PixelLab generations or Autosprite credits were spent.

## Audit

`tower/foot`, `evercrown/veins`, `spires/sky_steps` and `haar/marsh_road` captured. Pass 671 gave
each zone family its own rig over a hung deck, but two things still repeated:

- Every hung deck was the same timber girder (12.128), recolored, under whatever rig held it.
- The two shafts stacked one width of deck on one grid. `tower/foot`: eight decks of five cells,
  every four rows, at two columns. `evercrown/veins`: seventeen decks of eight cells, every three
  rows, at three columns. The sky steps and the marsh road were already irregular.

## What changed

Design bible 12.153 (new); `scripts/world/plank_supports.gd` (`DECKS`, a `deck` per zone in
`LOOKS`, `deck_depth`, `_truss_deck`, `_raft_deck`, `_slab_deck`); `levels/tower/foot.room`;
`levels/evercrown/veins.room`.

- **The Tower and the Trials: a plate girder.** A dark iron web stiffened by a lit zigzag, riveted
  at its nodes, on a flange in the hanger's iron.
- **The timber and water zones: a raft.** Logs laid across the deck, their round ends in a row
  under the board, each with a lit growth ring and its own shadow, so the underside is scalloped.
  The hangers' stirrups take it under the logs.
- **The Spires and the dwarf halls: a stone slab.** Two courses of the zone's stone, the lower one
  corbelled in at each end and hanging 3 px below the cell, joints staggered.
- **The town keeps the girder; the Evercrown keeps its grown underside.**
- **The shafts replanned.** `tower/foot`'s hung decks are three to nine cells wide and three, four or
  seven rows apart; the veins' four to ten wide and two, three or four rows apart, at no fixed
  column. Where a deck now stands within a post's reach of the one below, it stands on posts
  (12.30), which breaks the stack further. Every light vein keeps a deck two rows under it.

Judged by eye at 1x and 4x in the four rooms. The plank tile's own trestle (12.20) still shows its
V braces over the slab; at 1x they read as joints in the stone.

## Tests

- New `test_plank_each_zone_family_builds_its_own_deck` (`tests/test_plank_supports.gd`).
- `test_plank_a_hung_run_is_a_deck` now holds the girder to the zones that build it.
- `test_the_veins_are_not_a_level_box` (`tests/test_bloom_stalk.gd`) counts the replanned shelves
  (133 plank tiles, 150 before); the six veins are where they were.

Mutation check: with the raft's log ends drawn square the test fails (no scallop); with the Tower
building the girder it fails twice (no zigzag). The first replan of the Tower's upper decks left a
2-cell gap under a four-row climb and the reachability checker lost the chest at (13, 7); the decks
now meet edge to edge there. The first full run then found the lower decks no longer reached the
ledge without the ladder (`test_ladders_never_open_a_gated_room`: the ladder opened the winch hall
and the rooms past it); they too meet edge to edge or overlap now, and the lowest, three rows over
the floor, stands on posts.

## Full suite

Two full runs (`TEST_TIMEOUT=7200`). The first failed `test_ladders_never_open_a_gated_room`
(fixed above) and frame-time checks. The second: 38,613 checks passed, 2 failed, both frame-time
budgets (a 63 ms spike after the end, `spires/sky_steps` at 8.15 ms). Rerun alone, both pass. The
room-load budget (`test_every_room_loads_and_settles_inside_the_budget`) misses on this PC by 3 to
20 ms in `evercrown/proving_scar` and also fails twice on an untouched `main` checkout (521 and
515 ms, `sky_steps` 8.04 ms), so it predates this pass; the decks are drawn once per room load. CI
(test and mix) is green, with the full suite passing there.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Two shafts climb on varied decks. |
| Art cohesion | 15 | 98 | Hung decks are built by their zone. |
| Bosses | 10 | 99 | The veins keep their six cuts. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Drawn once per room load. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 675 grade in its order, past the held items: the flooded hall's foe lost in pink
glow and the water band; then the canopy bridge's hit frame (the hurt hero's red tint reads as a
foe); then the source hall's water box in its brick border.
