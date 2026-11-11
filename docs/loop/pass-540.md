# Pass 540: thorn bulbs grow from a bramble

## Category

A defect from the pass 535 independent grade (workbench queue): "placeholder-looking set pieces",
next among them the "Spires red orb columns". Art cohesion, and Environments in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do. No PixelLab generations were spent.

## Audit

The red orbs down both walls of `spires/sky_steps` are thorn bulbs (`o`), the Delver's Pick pogo
hazard: 52 of them in that room, and 191 in 12 rooms across the game (the Boughs' canopy bridge floor,
the Evercrown's proving scar, the Trials' walls and thorns rooms, the Tower). `ThornBulb` drew each as a
flat red circle (`c8323a`, not a master palette tone) with a soft pink highlight and six dark lines,
the same whether it hung on a wall, sat on a floor or floated. Stacked a tile apart down a shaft wall,
they read as a column of red balls bolted to the stone. Of the 191, 166 touch a surface: 127 a wall
and 39 a floor; 25 float free.

## What was built

- The pod is a pixel bramble bud built once per pod: round at the stem and tapering to its tip,
  outlined (`1f0a11`), lit from the upper left on the master palette's red ramp (`501623` to
  `e55439`) with a glint, its tip glowing and pulsing between `e55439` and `ecbdac`, and seven hooked
  thorns with bone-pale tips (eight on a free pod).
- `ThornBulb.anchor_for` picks the surface a pod grows from: a wall to the west or east first, then
  the floor, then the ceiling (cells `#`, `u`, `C`, `%`, `Room.THORN_HOLDS`). A rooted pod sits on a
  two-pixel woody stem and points away from its surface; a pod with nothing beside it floats free.
- `Room` links each pod to the neighbours that grow from the same surface; a linked pod's bramble vine
  runs along the surface to its cell's edges, so a column shares one unbroken thorny vine. Its wobble
  and thorns follow room pixels, so neighbouring vines meet without a jog. A lone pod's vine is a short
  root clutch.
- Alternate pods along a surface droop opposite ways (`TILT`, 0.45 rad), so a column or row never
  stands in step.
- The hitbox is unchanged: a circle of radius 6 at the cell's center, inside which the bud sits.

## By eye, at 1x and 4x

`spires/sky_steps` at play scale and its two wall columns at 4x, `boughs/canopy_bridge` (a floor row
of 22) and `trials/thorns` (free pods). The first take kept the pods upright and gave each a pale seam
across its middle: the column still read as a stack of red ovals, and the seam read as a mouth. The
glow moved to the bud's tip, the thorns grew longer and gained pale tips, and alternate pods now droop
up and down the vine. The shaft walls now read as brambles with thorned red buds, the canopy floor as
a thorn hedge, and the free pods in the Trials as thorned seeds. At play scale every pod stays as
readable a hazard as before: the same red, the same size, glowing.

## Tests

`tests/test_thorn_bulb.gd`, five new tests: every tone is a master palette value; a pod picks its
surface in order (west or east wall, floor, ceiling, else free); the bud stays in its cell, covers the
hitbox's center, leans to its tip and points away from its surface, and neighbours droop opposite
ways; a room roots a column in its wall, links it, and its vine runs unbroken along the cell (an
unlinked one stops short); most of the game's bulbs are rooted and most rooted ones linked.

Mutations: dropping the links in `Room` fails the room test (the vine breaks and the column links
nothing); making every pod tilt the same way fails the fit test. The first run of the fit test also
caught that the bud was nearly symmetric on the pixel grid, so the bud was moved toward its tip and
its tip lengthened until it reaches clearly farther that way than toward its stem.

Bible: 12.32 (thorn bulbs grow from a bramble).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the hazard's hitbox is the same. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground remains. |
| Art cohesion | 15 | 98 | The red orb columns are brambles now. The flat grotto liquid, the Evercrown diamonds, the Haar glyph blocks, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; each pod builds its pixels once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

GRADE

## Next

Pass 541: the art loop stays **gated** on Sean (three guardian bases wait). Next from the pass 535
grade's placeholder set pieces: the flat Heartwood grotto liquid, the Evercrown's flat cyan diamonds
and the Haar's orange glyph blocks; then the dressed mid-ground. The VFX-tool trials continue on the
dash afterimage, then the enemy death dissolve. Rim light on figures and the Boughs painterly clash
stay parked for a watched session.
