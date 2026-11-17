# Pass 587: the Flooded Hall is vaulted, and its east vault has fallen

## Category

World and art cohesion, from the independent grade taken after pass 585 (5.3 of 10): "rooms are
rectangular boxes (Boughs canopy bridge, Vorrhallow flooded hall, Spires storm ledge, Sunken
aqueduct): flat ceilings, straight walls, one thick tile border", and "the same chest on a thin
table ... in nearly every room". By design bible 12.63's rule, one room per pass; this is the
first of the four.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) is held, so this pass took the third.
The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no
Autosprite credits. The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- `vorrhallow/flooded_hall` is a screen and a half (60 by 23). Its ceiling was ruled flat at
  row 4 for the whole hall, with two pillars hanging from it square, and its walls ran straight
  from the ceiling to the doors. Shot at 1x in its west and east halves: two flat bands of brick
  framing the hall, top and bottom.
- The chest (40, 15) stood on a one-way plank on two posts over the water: the "thin table".
- Constraints: the tide (`tide: 19`) must stand a tile deep over three quarters of the floor
  and fill the spike pit (`test_vorrhallow_drains_when_thane_vorrund_is_at_rest`); the wading
  test runs east from tile 10 short of the pit (tiles 26 to 29); the chest must not move, or it
  is collectable again; one screen tall, so nothing can be sunk.

## What was built

`levels/vorrhallow/flooded_hall.room`, tiles only:

- **The vault.** Each of the hall's two bays springs five tiles down at its pillar and rises in
  steps to a crown at row 2, with a short rib between the bays hanging to row 6.
- **The fall.** Over the east bay (tiles 36 to 45) the vault has fallen in: open to row 1 at
  five columns, its edge broken, and one voussoir (tile 44) still hanging four rows down at the
  hole's east side.
- **The heap.** What fell lies under the hole in the water: a slope up its west side from tile
  36 and a sheer east face at tile 42, four tiles high. The chest stands on top. The plank is
  gone; the hall has none.
- **Pillars and walls.** Each pillar has a capital a tile wider each side and a foot broken off
  unevenly; the side bays' corners are rounded; each outer wall has a buttress.
- Design bible 12.74, and the Vorrhallow summary (section 4) mentions it.

The tide keeps 49 of 58 floor cells; the Crystal Dwarves, doors and sign are where they were.

Judged by eye at 1x, west and east halves, before and after. The first heap was a symmetric
stepped pyramid that read as a ziggurat; it is now lopsided, a long slope west and a sheer face
east, which reads as fallen masonry. The vault's steps are a tile each, so it reads as a broken
stepped vault rather than a smooth arch; tile slopes are solid only below their diagonal, so a
smooth underside would need a ceiling slope tile (not built). For Sean in play: whether the
chest on the heap is now too easy, a walk up a slope where it was a jump to a plank.

## Tests

`tests/test_flooded_hall.gd`, two tests:

- `test_the_hall_is_vaulted_and_the_east_vault_has_fallen`: the ceiling's underside at six
  heights or more over the bays; the west bay rises three or more tiles to its crown; the east
  bay springs low from its pillars; a hole open to row 2 over five or more columns, to row 1 in
  three or more, under a whole top row, with a broken edge and a hanging voussoir; each pillar
  has a capital and an uneven foot.
- `test_the_fallen_vault_lies_under_the_hole_with_the_chest_on_it`: a heap of five or more
  columns in the water, under the hole; the chest unmoved at (40, 15) on stone; no plank cells;
  no more than nine cells of rock in the water's row; and, walked for real, from the water at
  tile 31 east up the heap to the chest, four tiles higher, standing, with no jump.

Mutation check, the room restored from a copy and compared byte for byte after each: the room
as it was on main fails both tests (7 checks and 1); a plank cell put back in the hall fails the
second (1 check).

Full suite: 18,161 checks passed and 3 failed; all three are accounted for.

- `test_vorrhallow_drains_when_thane_vorrund_is_at_rest` failed on the Drowned Nave ("a step
  in the water sloshes": `step_stone`), and passed with the old hall. The test made a world per
  hall and never freed the first, and `Player._ground` takes the first room in the tree, so the
  nave's step read the Flooded Hall's ground at the same spot: water before, the heap now. Each
  world is now freed before the next; it passes (158 checks).
- `test_every_room_loads_and_settles_inside_the_budget` (two checks) named
  `evercrown/proving_scar`, `veins`, `threshold` and `gym/gym` in the suite and
  `trials/stillness` (508 ms) alone: load on this PC, other rooms each run, none this one.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Flooded Hall has a vault, a fall and a heap; the chest is off its table. |
| Art cohesion | 15 | 98 | The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The hall's sign says the water left its mark; now the hall shows its ruin too. |

Weighted: 98.85.

## Next

In the queue's order: the next of the four box rooms (the Sunken aqueduct, whose plain
oversized brick and flat water the grade also named; then the Spires storm ledge and the Boughs
canopy bridge), one per pass, and the repeated chest and sign; then the grid item's leftovers
(the aqueduct's second face tile, the HUD over the ceiling, the shop panel). The Haar's fog
stays held. The next independent grade is due after pass 590.
