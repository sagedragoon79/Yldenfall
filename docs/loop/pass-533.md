# Pass 533: the ruins' accent stones are bricks and recesses, not flat squares

## Category

A defect from the pass-529 independent grade, the first queue item an unattended pass could do:
"random square 'missing pixel' blocks in midground ruins (tower, vorrhallow, hearthroot)".
Environments and art cohesion.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first item (rim
light on figures and the rest of the lighting pass) stays parked for a watched session.

The queue item named two defects. This pass takes the ruin blocks; the noisy terrain fill (the play
tiles of the Haar, the Heartwood, the Sunken and the Evercrown) stays queued as its own pass, because
it touches every zone's tile painter and their tests.

## Audit

The blocks are `masonry_shade`'s accent stones (bible 12.14): about one cell in eight drops to the
dark value and one in fourteen lifts to the light one. Each was a square cell (8 world px) of one flat
value with no edge, so at 1x it read as a pixel missing from the picture, not as a stone. Every
backdrop that shares the helper drew them: `tower_far`, `hearthroot_far`, `vorrhallow_far`,
`vorrhallow_mid` and `sunken_mid`. Nothing else in those painters drew squares of that size.

## What was built (design bible 12.27)

`masonry_shade` gives each accent stone a shape of its own, still from the same three palette names:

- an accent stone is a brick, `cell` wide and half as tall, in the same running bond;
- a proud (lighter) stone has its shadow along its foot and its right side;
- a recess (darker stone) has a lit sill along its foot, so it reads as a slot window or a missing
  stone with depth.

Body stones stay flat, so the field gets no busier. Only the five backdrops above change (three other
`assets/bg/*.png` files came out of the generator byte-different but pixel-identical, and were left
as committed).

## By eye

`shots/ruin-blocks/pass533-tower-2x.png`, `pass533-vorrhallow-2x.png` and
`pass533-hearthroot-2x.png` (top before, bottom after, the upper-left quarter of the view at 2x). The
tower shafts' scattered squares are now coursed masonry with slot recesses; the Vorrhallow colonnade
reads as laid stone; the Hearthroot houses read as brick. The Sunken aqueduct piers were checked at
1x: the piers read as stone, and the room's busy strata are the separate terrain-fill item.

## Tests

`tools/art/test_tilegen.py` (the Python guard for the painters, run with
`python tools/art/test_tilegen.py`):

- `test_proud_stones_are_bricks_with_a_shadowed_foot`: every lit run in a field is at most half a
  cell tall and ends on its shadow.
- `test_recessed_stones_carry_a_lit_sill`: more than 15% of the lit pixels are sills under a recess
  (24% now).

Mutations: reverting to flat square stones fails the first (a 16 px lit run ending on the body);
dropping the sill fails the second (3%). The older masonry tests (running bond, varied but
body-dominant field, weathered courses) all still pass.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The ruins read as masonry; the HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 534: the art loop stays **gated** on Sean (three guardian bases wait). Next in the queue: the
noisy terrain fill (flatten the interior fill of the Haar, Heartwood, Sunken and Evercrown play tiles
to two or three values under a strong lit top edge; code-first in `tools/art/tilegen.py`). Further
VFX-tool trials (the slash smear, the dash afterimage, the enemy death dissolve) follow. Pass 535 is
due an independent grade.
