# Pass 590: the Canopy Bridge crosses a hollow in the crown

## Category

World and art cohesion, from the independent grade taken after pass 585 (5.3 of 10): "rooms are
rectangular boxes (Boughs canopy bridge, Vorrhallow flooded hall, Spires storm ledge, Sunken
aqueduct): flat ceilings, straight walls, one thick tile border", and the hanging chest platform
"the same gimmick in five rooms" (the pass 575 grade). By design bible 12.63's rule, one room per
pass; passes 587 to 589 did the other three, and this is the last of the four.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) is held, so this pass took the third. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `boughs/canopy_bridge` is one screen (40 by 23), the bridge over a thorn pit at Sylvarre's shut
  gate. Its ceiling was ruled flat at row 4 for the whole room, its side walls ran straight from
  it to the doors, and its chest stood on a one-way plank hung by two ropes. Shot at 1x: a timber
  frame around a picture of the forest.
- The room lies in the High Boughs, the crown of the Tree, so its frame should be the crown's own
  wood: a hollow in it, not a box.
- Constraints: the wind band (`>`, rows 4 to 6, columns 10 to 30) must stay a whole rectangle over
  open air (levels/README.md), so nothing may hang into it. The doors (both at rows 16 to 19), the
  sign, the bridge, the pit, the Leaf Mantis, the Bark Knight, the bounce-pod (22, 16) and the
  chest (26, 9) stay, and the room must stay reachable.

## What was built

`levels/boughs/canopy_bridge.room`, tiles and one foe moved:

- **The canopy** is the underside of the crown's wood: it stands at nine heights, notches up to
  the room's top row in three places, comes down to row 9 into the west trunk and row 8 into the
  east, and three knots hang from it (columns 17, 25 and 26), each tapering to a point just above
  the wind band.
- **The trunk walls** bulge: the west wall has a shoulder between rows 9 and 13, and the east
  wall's face steps in and out above the bough.
- **No table.** The plank and its ropes are gone. The chest stands on the tip of a bough that grows
  out of the east trunk, one tile thick at the tip and six at the root, with vines hanging from its
  underside. The bounce-pod still throws you up beside its tip, so you reach it as before.
- **The Hornet** sat at (33, 10), now inside the bough; it hovers at (31, 7), over the bough, and
  guards the chest.
- Design bible 12.77.

Judged by eye at 1x, before and after: the room now reads as a hollow in the Tree's crown with the
bridge strung across it, rather than a framed box. The first canopy had square notches of equal
width and square two-column knots, and read as battlements; the knots now taper to single columns
and the notches vary in width.

## Tests

`tests/test_canopy_bridge.gd`, four tests:

- `test_the_canopy_is_ragged_and_hung_with_knots`: the underside at six heights or more, notched
  up to row 1 over four columns or more with the top row still standing, two hanging knots or
  more, and both corners low.
- `test_the_wind_still_blows_through_open_air`: the band is whole (63 cells) and nothing lies
  outside its rectangle.
- `test_the_trunk_walls_bulge`: each wall's face stands at four depths or more between rows 4
  and 15.
- `test_the_chest_stands_on_a_bough_not_a_table`: no plank over the bridge, the chest on wood, the
  bough unbroken from the chest to the east wall, one tile thick at its tip and four or more at
  its root.

Mutation check, the room restored from a copy and compared byte for byte after: the room as it was
on main fails the canopy, walls and bough tests (4, 2 and 5 checks); the bough cut off from the
trunk fails the bough test (1 check); a knot dropped into the wind band fails the wind test
(1 check). The wind test passes on main by design: it guards the band, which the old room kept.
The reachability and soft-lock tests pass.

Full suite: 18,395 checks passed and none failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The last of the grade's four box rooms is a hollow in the crown, its chest on a bough. |
| Art cohesion | 15 | 98 | The independent grade is the real measure; one is due now. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due after this pass (every fifth pass). Then, in the queue's order: the
repeated chest and sign; the grid item's leftovers (the aqueduct's second face tile, the HUD over
the ceiling, the shop panel). The Haar's fog stays held.
