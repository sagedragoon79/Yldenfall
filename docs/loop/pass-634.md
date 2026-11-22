# Pass 634: what stands on the ground is grounded

## Category

Art and cohesion (environments). The top item of the queue, the last new defect of the
pass 630 grade: "props are not grounded: no contact shadows under chests, steles, the hero
or foes, and the plaza's doorway is an orange frame floating on the skyline (a soft contact
shadow under standing things, and a wall or jamb behind the door)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

- **Nothing cast a shadow.** The only contact shadow in the game was the floor spikes' one
  dark row (12.24). The hero, foes, chests, steles, shrines and people stood on the ground
  line with the background showing right down to their feet.
- **The plaza's door was a frame.** `DoorMarker` drew a 28 by 42 px frame and its dark
  inside, and nothing round it, so against the plaza's far skyline it read as a cut-out
  stood on the floor. Every inner doorway in the game is drawn the same way.

## What was built

Design bible 12.110.

| Part | Before | After |
| --- | --- | --- |
| Contact shadow | none | a pool of four whole-pixel rows, one above the ground line and three on its top, tapering 0.6, 1.0, 0.78, 0.45; a band at 0.36 and a core at 0.34 more |
| Who casts it | | the hero, every foe but the guardians, chests, steles, shrines, people, inner doorways |
| In the air | | the pool stays on the ground below, fades with height and narrows to half by 72 px; none past that or over a pit |
| A dead foe | | casts nothing until it comes back |
| Inner doorway | a frame | a wall of the zone's stone round it: 48 by 56 px of 8 px courses with a broken top, jambs, a lintel with a keystone, a threshold step |

The pool draws in front of the tiles (absolute z 0) and behind its body, so it darkens the
lip a body stands on and never the body.

Changed on the way: the first pool (alphas 0.22 and 0.26, rows from an ellipse) was a near
rectangle three rows tall and could not be seen on the Heartwood's moss. A red test pool
showed it was in the right place, so the rows now taper harder and the band is darker.

## Checked by eye

The plaza at 1x and 4x (the door in its wall, the chest on the trestle, the hero on the lit
lip) and the fight frames at 1x and 3x (the hero and the Rot Dwarf in the Heartwood, the
Vorrhallow flooded hall). The pool reads clearly on pale and stone lips and faintly on dark
moss.

## Tests

Six new tests in `tests/test_contact_shadow.gd`. Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_standing_things_cast_a_pool` | no shadow on foes | fails (3 checks) |
| `test_the_pool_tapers` | every row full width | fails (4 checks) |
| `test_the_pool_tapers` | the band at 0.12 | fails |
| `test_a_jump_leaves_a_fainter_pool_below` | the pool always at the feet | fails (2 checks) |
| `test_a_doorway_stands_in_a_wall` | the room does not hand the door its zone | fails |
| `test_a_dead_foe_casts_nothing` | a dead foe still casts | fails |

Full suite: see the pull request.

## Not done

- Decor that stands on the floor (statues, the fountain, set pieces) and the guardians have
  no pool.
- On the darkest floors (the Heartwood's moss, the Haar's mire) the pool is faint by nature.
- The door's wall is one shape everywhere; a zone's doors could differ (timber in the
  Boughs, bark in Amberlee).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A foe now stands on the floor it fights on. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Standing things are grounded and the door is set in a wall; the fog, the Haar's dither and the midground bands stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One ray a physics frame for each moving body. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 630 grade's queued items: the one-value midground bands, a second
ceiling pitch and the plank's board. An independent grade is due after pass 635. The Haar's
fog and dither, the sprites' pixel size, the hero's rim light and the sword's look stay held.
