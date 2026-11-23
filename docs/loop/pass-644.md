# Pass 644: the mid columns break

## Category

Art cohesion and environments. The top item of the queue, from pass 643's Next: after the far
columns broke (pass 643), the mid layers' columns still ran the room's height, the Tower's
girders and Vorrhallow's colonnade.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

Measured as the longest run, in one column of pixels, of anything drawn on the (transparent)
mid layer, bridging gaps of up to 12 world px:

- **The Tower's girders** (`tower_mid`): five bolted girders from roof to floor, with diagonal
  braces between them at every height. 1.00 of the layer's height.
- **Vorrhallow's colonnade** (`vorrhallow_mid`): six columns from 0.25 to 0.62 of the way down
  the hall to the water, each with a small crenellated break. 0.72; in the room's view the
  tallest stood from just under the arches to the floor.

## What was built

Design bible 12.120, in `tools/art/tilegen.py`. No mid column now runs more than
`MID_RUN_MAX` (0.7) of its layer's height.

- **The Tower: trusses and posts** (`_hanging_truss`, `_rising_post`). Five lattice trusses hang
  from the roof, each to its own depth (0.32 to 0.65): two chords, a zigzag web with a strut at
  each joint, and at the foot a bracket plate, a pulley wheel and a hook. Four bolted posts rise
  from the floor between them (0.26 to 0.44) and carry a riveted beam on two knee braces; one
  bay stands open to the far wall. Longest run: 0.69.
- **Vorrhallow: a ruin** (`vorrhallow_mid`). The columns break off between 0.35 and 0.6 of the
  hall's height, each across a slanted, chipped fracture of its own with its broken face lit.
  The stillglass seats sit lower to stay below each break, and the vault's chains end well
  above the columns. Longest run: 0.60.

Thrown out on the way:

- **Vorrhallow's columns broken between 0.35 and 0.68 of the height.** The tallest still stood
  from under the arches to the floor in the room's view. The highest break is now 0.6.

## Checked by eye

At 1x and 2x in `tower/foot` and `vorrhallow/alpha_den`, before and after (after a Godot
reimport). The Tower's mid layer is hanging trusses ending in pulleys over beam-topped posts,
with no bar from top to bottom; Vorrhallow's colonnade is broken stumps at four or five
heights, the glass seated below the breaks. No foreground layer frames the rooms yet; see Next.

## Tests

`test_no_mid_column_runs_the_height_of_the_room` in `tools/art/test_tilegen.py`: in both mid
layers no column runs more than `MID_RUN_MAX` of the height, and something still stands near
the floor in a share of the width (so an empty layer does not pass).

| Mutation | Result |
| --- | --- |
| the trusses run the full height | fails (1.00) |
| the posts rise to the roof | fails (1.00) |
| no trusses or posts drawn | fails (stand in 0 of the width) |
| Vorrhallow's columns topped from 60 world px | fails (0.84) |

## Full suite

Pending.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | No column in the far or mid layers of the Tower or Vorrhallow runs the room's height now. No foreground layer frames the rooms; the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (baked pictures). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

No foreground layer frames the rooms. Then: foes in two styles (the knight's grey-green blends
in); set dressing pasted on (crystals, the tree through the shrine gate, identical islands);
spikes that read as grass or railings; light as additive circles; ground strip tiling. Held as
before: the Haar's fog and dither, the sword's slab and the hero's attack pose, the hero's size,
the shop portrait. The next independent grade is due after pass 645.
