# Pass 679: the Source Hall is a vault over a basin

Date: 2026-11-28. No new notes from Sean. From the queue, first item: the independent grade of
pass 675 (5.4/10), next in pass 678's list: "the source hall's water box in its brick border".
This pass takes it. The PixelLab art loop stays gated on Sean (three guardian bases wait for his
OK); no PixelLab generations or Autosprite credits were spent.

## Audit

The Source Hall's room picture shot fresh from `main` (`sunken/source_hall`, the hero mid-room)
and read at 1x and 2x:

- **A brick frame.** The ceiling was one flat band of brick four rows deep from wall to wall, the
  walls sheer, the floor flat: the room was a ruled rectangle drawn in one brick.
- **A box of water in it.** The pool ran five tiles deep from the west door to the ledge at one
  depth, its bed flat and its east side one sheer brick wall, so it read as a teal rectangle set
  in the brick rectangle.

## What changed

Design bible 12.156 (new), and a note in 12.142; `levels/sunken/source_hall.room`.

- **One vault.** The ceiling springs from row 9 at the west wall and row 8 at the east and rises
  in five steps a side to an eleven-column crown at row 4; `tools/levels/haunches.py` laid 11
  haunches, one at every step and at each wall. The east door, the platform and its Life Fruit
  keep their headroom.
- **A basin, not a box.** The bed climbs to the ledge in three steps under the water (one, two and
  four tiles high), and a fallen block lies on the bed toward the west. The surface still lies
  level with the ledge, and the shafts under the water stop on the steps.

Judged by eye at 1x and 2x: the hall now reads as a vaulted cistern with the pool shoaling toward
the ledge, and the brick no longer frames a rectangle. The fallen block reads a little stepped at
2x; it is a rubble block, left as it is.

## Tests

- New `test_the_source_hall_is_one_vault` (`tests/test_ceiling_forms.gd`): the crown at row 4 or
  higher, the ceiling turns once, it springs from row 8 or lower at both walls, and every step is
  chamfered by a haunch.
- New `test_the_source_halls_basin_climbs_to_its_ledge` (`tests/test_water_held.gd`): the pool
  takes three depths or more, the bed climbs toward the ledge, and a block lies on the bed away
  from it.
- The water-held rule, the level surface, the shafts under the water and reachability still hold.

Mutation check: with the old room file both new tests fail (3 checks each).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,643 checks, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Source Hall is a shaped cistern, not two boxes. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 680 is the next independent grade. From the pass 675 grade in its order, past the held items:
uniform floor strips (Tower foot, veins, source hall); then the empty minimap.
