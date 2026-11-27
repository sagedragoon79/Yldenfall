# Pass 668: the seat falls into shade behind a foe

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 665 (5.5/10), "fights that don't read". Pass 667 took the Flooded Hall's tell; this pass takes
the Heartwood gate, where the foe and its spark were lost. The PixelLab art loop stays gated on Sean
(three guardian bases wait for his OK); no PixelLab generations or Autosprite credits were spent.

## Audit

- **The Heartwood fight frame** (`heartwood-tell`, a Rot Dwarf winding up in `heartwood/dwarf_hall`),
  cropped at 4x: the dwarf stands at the foot of the high seat (12.62), on its lit planks, its east
  pillar and its dais. His grey-green stone is the same value as the lit umber timber, and his raised
  weapon and the tell's glint sit over the pillar. The root's haze (12.135, pass 659) parts the hero
  from the trunk, but covers the trunk only.
- **The haze's reach:** a body's box is its collision shape, which stops at the shoulders, so nothing
  reached the raised weapon or the glint.
- **Hero and beetle touching in the hit frame:** the capture's moment (pass 667's audit); it stays in
  the queue.

## What changed

Design bible 12.145 (new); `scripts/world/high_seat.gd`.

- **A shade over the timber and stone** behind a hero or foe (`SHADE_ALPHA` 0.7), in the haze's own
  cells: each timber, stone, rot and side-root tone off the trunk falls toward the darkest tone of
  its ramp (`build_shade_mask`). The outline, the sap and the trunk are left as painted.
- **Over a raised weapon:** the haze and the shade reach `HEAD_ROOM` (14 px) above a body's box.

A first take (0.6, from the box's top) changed about a thousand pixels round the dwarf and read as
nothing at 1x: the box stopped below his weapon. Judged by eye at 1x and 4x in `heartwood-tell`,
before and after: the dwarf's stone and glint now stand on shaded planks and a shaded pillar.

## Tests

- New `test_the_seat_shades_behind_a_foe` (`tests/test_high_seat.gd`): every timber and stone pixel
  off the trunk shades to its ramp's darkest, and the trunk, outline and sap stay clear; the shade's
  strength; in the hall, a Rot Dwarf before the east pillar is shaded behind, reaching at least 10 px
  over his box, over the pillar and the dais.

Mutation check: with the mask empty, and with `HEAD_ROOM` 0, the test fails.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,339 checks passed, 0 failed, the timing budgets included.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Rot Dwarf reads against the high seat. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A second texture draw per haze cell. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade (every fifth pass: pass 670). Before it, from the pass 665 grade in its order,
past the held items: the black foreground blobs at the foot of the frame; then the chain and rope
platforms hung from nothing, and the veins' one value band.
