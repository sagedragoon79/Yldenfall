# Pass 662: the burrows' roof is one chewed vault

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 660 (5.4/10). Past the held items, its next named defect: "empty boxed rooms (plaza ceiling,
the burrows' black top band, the veins in one purple)". This pass takes the burrows. The PixelLab
art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab generations or
Autosprite credits were spent.

## Audit

`heartwood/grub_burrows` captured from the tunnel's west end. Pass 647 (12.123) put roots into the
deep mass over the tunnel, but the band remained: west of the upper chamber the roof lay eleven
rows thick and dead flat over 35 columns, so the top third of the frame was one dark slab ruled off
by a straight line. The roots are faint by design, so they could not carry it; the layout could.

## What changed

Design bible 12.138 (new), with a line in 12.123; `levels/heartwood/grub_burrows.room`.

- **One vault** chewed into the roof: 27 columns wide where it opens off the tunnel, rising six
  rows to a crown nine columns wide at row 5. Haunches laid with `tools/levels/haunches.py`: the
  west side is one diagonal five haunches long, the east side three haunches, a sheer step and two
  more, so the sides are not a mirror (12.104). Seven columns of mass stay between the vault and
  the upper chamber.
- **The grubs keep the roof.** Of the two ceiling grubs over the old flat run, one clings to the
  roof left east of the vault and one starts on the tunnel floor under it and crawls up. A first
  take hung one from the crown, and a second from the west stretch of roof; in both, the spoils test
  saw a loaf and coins lodge in the roof (they pop from 12 px over the foe).

Judged by eye at 1x, before and after: the slab is now a thin crust over a lit, rooty vault, and
the tunnel reads as a cave instead of a box. The plaza's ceiling and the veins' single purple are
left for their own passes.

## Tests

- New `test_the_burrows_roof_is_one_chewed_vault` (`tests/test_ceiling_forms.gd`): no more than
  eight columns of that roof lie nine rows thick; the vault is one hollow, twelve columns wide at
  row 6; its crown reaches row 5.
- `test_no_ceiling_is_a_row_of_teeth` and the reachability tests (soft-locks, everything
  reachable, every room boots) pass on the new room.

Mutation check: with the old room, the new test fails all three checks (35 columns eleven rows
thick, no vault).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,875 checks passed, 1 failed:
`test_every_foes_spoils_rest_in_its_room`, the crown grub's spoils lodged in the roof. After moving
that grub, the spoils test, the burrows test, the grub tests, the reachability tests, every room's
boot and the ceiling rule were rerun and pass; nothing else touches the room.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The burrows' tunnel is a cave with a vault, not a box under a slab. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 660 grade in its order, past the held items: the rest of the empty boxed rooms (the
plaza's ceiling, the veins in one purple); flat water rectangles (the source hall, the flooded
hall); then the oversized bee (a smaller Hornet sheet). Pass 665 is the fifth since the pass 660
grade: the grade follows that merge.
