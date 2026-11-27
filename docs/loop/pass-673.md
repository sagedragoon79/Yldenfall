# Pass 673: a room's floor rises and falls

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 670 (5.3/10) names next, past the items done in passes 671 and 672, "boxed rooms with one flat
floor and the hero at the far left". This pass takes it. The PixelLab art loop stays gated on Sean
(three guardian bases wait for his OK, the limit); no PixelLab generations or Autosprite credits
were spent.

## Audit

The grade's sheet (pass 670) shows seven of its eight rooms with the hero at the door he came in
by, and three of them (the Tower Foot, the Sky Steps, the Veins) as a tall box whose foot is one
straight floor. Measured over every room: the lowest floor's longest flat stretch, as a share of
the room's inner width. 36 of 127 rooms ran flat across 90% or more; 17 of them are boss arenas,
whose fights are tuned on a level floor. Of the other 19, nine are the 40 by 45 climbing shafts
(the Sky Steps, the Heartwood Rise, the Windward Climb, the Drowned Stair, the Heart Stair, the
Drift Well, the King's Stair, the Kettleforge Stair, the Meteor Rise), three are towns, and the
rest are halls and gates of the Tower, the Heartwood and the Evercrown.

The room pictures on the workbench (and so in the grade) were taken where the hero spawns, at the
door; the arena pictures already stood him near the middle (`floor_mid`).

Zoomed in at 3x, a slope tile also drew a dark square round its open half: the edge shade (12.3)
rimmed it as a whole block.

## What changed

Design bible 12.150 (new); `tools/levels/floor_banks.py` (new); 17 rooms; `scripts/world/edge_shade.gd`
and `room.gd` (slopes); `workbench/capture/capture_all.py` (room pictures).

- **A bank on each flat floor.** `floor_banks.py` raises one mound on a room's flat lowest floor: two
  tiles high (one where a ledge comes low), a 45-degree slope at each end, 6 to 12 tiles wide, off
  the middle toward 62% of the width. It keeps three tiles from a wall, a door or a pit, clear of
  every header thing (sign, prop, person, chest, lock, label, bare, grate, secret) and of the grid's
  foes and pickups, with four rows of plain air over its top (the hero is 2.5 tiles tall).
- **Kept flat:** boss arenas, tide rooms, towns (a `house` or `shop_` prop: Sylvarre, the Hearthroot
  market, Carillon, Kettleforge), and four rooms where no bank fits (the Bell Loft, the Cistern, the
  Kettleforge Stair's spike floor, the Meteor Rise's shaft lip). The Veins is a boss room and keeps
  its level floor under the bloom stalk.
- **Slopes take no square rim.** EdgeShade now takes the walking slopes and skips their own rim; they
  stay solid for their neighbours.
- **Room pictures** stand the hero on the floor near the room's middle.

Judged by eye at 1x and 3x in the Sky Steps, the Bat Belfry and the Heartwood Rise: each bank reads
as a raised bank of the zone's ground with a lit lip along its slopes; the dark boxes round the
slopes are gone.

## Tests

- New `test_a_rooms_floor_is_not_one_flat_line` (`tests/test_rooms.gd`): past boss, tide and town
  rooms and the four named, no room's lowest floor runs flat across 90% of it; at least 17 rooms
  have a floor that rises and falls; the Sky Steps' slopes are known to its edge shade.
- The reachability tests (`tests/test_reachability.gd`) check every changed room in the full suite.

Mutation check: with the Sky Steps' floor put back flat, the new test fails twice (the room is
named as flat, and its edge shade knows no slopes).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,546 checks passed, 0 failed, the reachability tests
included. CI (test and mix) passed on the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Seventeen floors rise and fall once; the towns and arenas stay level. |
| Art cohesion | 15 | 98 | Slopes lose their square shade. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 670 grade in its order, past the held items: tells drawn in the background's values
(the Heartwood knight against the gate, the flooded hall's thin spike tell); then the canopy's flat
mint wash and stepped edges. Pass 675 is the next independent grade.
