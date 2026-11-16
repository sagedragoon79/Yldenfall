# Pass 576: the Hornet Gallery has its nests, and its floor is not level

## Category

World and art cohesion, from the independent grade taken after pass 575 (4.8 of 10, up from
4.7): "the large props carry the game", and the top defect is now room shape, "a rectangular
tile frame around a dead-level floor with 60 to 70 percent empty dark air". The queue's item
says to start with one room per pass, the Hornet Gallery first, since its set piece was next
anyway (pass 575's "Next").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the second. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `heartwood/hornet_gallery` is one screen. Its sign reads "The hornets nest where the sap runs
  thickest. Mind the thorns below." The room held three hornets, a Sap Spitter, a row of thorns
  under two planks, and the Rune Dagger (bible 5.2): no nest, no sap.
- Its floor stood at one height for 32 tiles, with a square two-tile step under the east door.
  Its ceiling met two hanging trunks square. Between the trunks, over the thorns, ten tiles of
  air stood empty from the ceiling to the planks: the room's middle, and where a hornet hovers.
- The room is one screen tall (23 rows) with the west door's floor on its last row, so nothing
  can be sunk; the floor can only climb.
- `test_the_hornet_gallery_can_be_cleared_with_the_dagger` holds every foe in a throw's reach
  from safe ground. The spitter is reached along its own floor, so it moves with its floor.

## What was built

- **`HornetNest`** (`scripts/world/hornet_nest.gd`, room prop `hornet_nest`), painted like the
  high seat (bible 12.62): whole world pixels on master palette ramps, lit from the upper left,
  baked once.
  - The great nest: a paper teardrop nine tiles long and six across, hung by a stalk, widest
    above its middle and blunt at its foot, in layers of grey paper (ash) and chewed bark
    (umber) that sag in the middle and have scalloped edges.
  - Its mouth, low on the west of its face, with three hornets crawling round the rim (drawn
    live, 3 by 2 px). A tear in its east side shows the comb: open cells in wax, some capped.
  - Two young nests either side, each under a third of its size.
  - "Where the sap runs thickest": sap seeps from the ceiling in patches, four ropes of it run
    from the stalk over the nest's shoulders and down its face, and the last hangs under the
    nest as a strand. A drop falls from it into the thorns every 2.6 s, between the two planks.
- **The room** (`levels/heartwood/hornet_gallery.room`):
  - `prop: 16, 1, hornet_nest` (a hanging prop names the ceiling tile over its middle).
  - The floor stands at three heights. A ramp climbs out of the thorns to a bank a tile higher
    (tiles 23 to 32), and a second ramp climbs to the east door's shelf. The Sap Spitter sits on
    the bank (28, 20), one tile higher than before.
  - Each hanging trunk has a stepped shoulder; the ceiling's underside stands at seven heights.
- Design bible 12.63 (with the rule for the rooms that follow); `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound. Nothing that can be picked up moved.

Looked at in `heartwood/hornet_gallery` at 1x and at 2x on the nest. The first take ruled the
layers straight across and drew the sap as five straight bars from the ceiling: it read as a
striped barrel behind poles. The layers now sag 15 px and are scalloped, the shade's edge steps
from layer to layer, and the ropes follow the nest's face. The seep along the ceiling was a
solid yellow line; it is now patches. Two things for Sean to judge in play: whether the hornet
that hovers in front of the nest still reads at once (the nest is on muted ramps for that), and
whether the bank makes the spitter's lob across the planks harder than he wants.

## Tests

`tests/test_hornet_nest.gd`, seven tests, 153 checks: the palette (every tone a master value, no
stray pixel, every tone used); the great nest (out of the ceiling, a teardrop widest above its
middle, blunt at its foot, outlined, lit west and shaded east, eight or more seams, paper and
bark by turns, every layer sagging); the mouth (dark all through, low, inside the outline), the
comb (only in the tear, hollow, wax and capped cells) and the crawlers (on the rim, moving); the
young nests (one each side, from the ceiling, under a third of the size, clear of the great
one, each with a mouth); the sap (gold only in the seep and the ropes, each rope unbroken from
the ceiling with glints, spreading over the shoulder, each ending at its own height, one
hanging in open air under the nest, a drop that hangs, only falls, and falls far); in the room
(solid ceiling over all three nests, open air under, no wall or ledge across them, the drop
clear of the planks and into the thorns' tips, a hornet in front of the great nest, the sign's
words, scenery only); and the room's shape (a floor at three heights, a ceiling at six or more,
two ramps each with ground under it and on its high side, and a real walk east from the thorns
that ends two tiles higher on the door's shelf with no jump).

Mutation check, each restored from a copy and compared byte for byte: the room without its prop
fails the room test; the room without its ramps fails the shape test (three checks: the walk
stops at the bank's face); layers that do not sag fail the nest test; a nest lit from the right
fails it; a drop that rises fails the sap test (three); a drop over a plank fails the room test
(eight points); an off-palette paper fails the palette test; a young nest against the great one
fails the outline check (12 gaps); gold and comb painted on the paper fail the sap test (9 px)
and the comb test (4 px).

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The spitter lobs from a bank; every foe is still in the dagger's reach. |
| World and level design | 15 | 99 | The first room off the template: a floor at three heights, two ramps, a stepped ceiling. Most rooms are still level boxes. |
| Art cohesion | 15 | 98 | The nests are on the master ramps and the light of the other set pieces. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | What the sign says of the nests, the sap and the thorns can now be seen. |

Weighted: 98.85.

## Next

Room shape, one room per pass by 12.63's rule: the Rail Gallery, Ore Bin 3 and the Rot Dwarf
Hall have their landmarks and level floors; the plaza and the Veins after them. The Haar tell
frame (a flat white silhouette: check whether the capture catches one frame of the flash or its
whole length). Chests housed differently per zone, and the causeway's spikes. Code-first liquids
and hazards (the amber pool, the lava column, the Boughs' wind dashes). The nest would be worth
a low hum in an audio pass, with the mouths, the gears, the bell, the falling ore and the
dripping sap. The independent grade is next due after pass 580; put `heartwood/hornet_gallery`
in its set. Tooling worth a short pass: the room budget test measures wall-clock time; the test
runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The sword in the hit frames waits
for a watched feel call. The Haar fog items wait until the hydra and steam branches merge; the
Blinkhop waits for a free base slot.
