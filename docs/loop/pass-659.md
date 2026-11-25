# Pass 659: the root hazes behind whoever stands before it

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 655 (5.0/10). Of its "fights hard to read" reasons, passes 657 and 658 took the burst and the
water band; the next not held is "the hero overlaps the trunk". The PixelLab art loop stays gated
on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite credits were
spent.

## Audit

`workbench/catalog/fights/heartwood-tell.png` at 2x and 4x. In the Rot Dwarf Hall the hero is set
beside a Rot Dwarf at the high seat (12.62), and stands right in front of the root that broke it.
The root is the hall's darkest and busiest piece (bark-0 to bark-2, furrows in night-0, 12.131):
the hero's night-0 outline vanished into its furrows and his green cloak sat on its mid tone, so
only his purple hair separated him from the bark.

## What changed

Design bible 12.135 (new), with a pointer in 12.62; `scripts/world/high_seat.gd`.

- **A haze behind a body.** `HighSeat._find_hazed` records the box of every hero or foe in front
  of the piece; `_draw` lays a veil of umber-2 (`HAZE`) at 0.55 (`HAZE_ALPHA`) over the trunk
  behind each box and `HAZE_PAD` 3 px past it, from a baked trunk mask (`build_trunk_mask`).
- **Inside the outline, with no edge.** The mask is the main trunk inside its outline
  (`on_trunk`), so the trunk keeps its shape. The veil is laid in 4 px cells (`haze_cells`,
  `haze_at`) and fades over two cells (`HAZE_FADE` 0.6, 0.3) round the body.

A first take hazed the outline too, in one step: it read as a lighter patch cut into the trunk,
its top edge a hard line at the hero's head. Judged by eye at 1x, 2x and 4x in `heartwood-tell`
before and after: the hero's outline, cloak edge and boots now read against the root, the root's
furrows show through the veil, and away from him the root is as painted.

## Tests

- New `test_the_root_hazes_behind_whoever_stands_before_it` (`tests/test_high_seat.gd`): whole
  behind the body, fading over two cells above it and gone past that, nothing with nobody there,
  whole cells; the mask is the trunk inside its outline and nothing else; in the dwarf hall the
  hero before the root gets a haze over the trunk, and away from it none.

Mutation checks: with no body recorded, the test fails 2 checks; with the outline hazed, 1; with
no fade, 1.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,865 checks passed, 1 failed. The one is
`test_every_room_loads_and_settles_inside_the_budget` (`evercrown/proving_scar` at 509 ms against
500, and `gym/gym` in one rerun), rooms this pass does not touch. It fails the same way with
main's `high_seat.gd`, while the Unity editor ran on the same PC; see the PR for the rerun.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The hero reads in front of the dwarf hall's root. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a few dozen 4 px draws near the root). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 660 is the fifth since the pass 655 grade: grade it. Then, from the pass 655 grade in its
order: the canopy's dithered tile edges and the oversized bee; the large empty chained-platform
rooms in one hue (the Tower foot, the Evercrown veins); the dead black band over the grub burrows.
Held as before: the hero's size, the sword's flat bar, the Haar's dither halos and fog; foes in
mixed styles stays with the art loop.
