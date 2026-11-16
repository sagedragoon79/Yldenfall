# Pass 574: Ore Bin 3 stands half full

## Category

World and art cohesion, from the independent grades taken after passes 565 and 570 ("nearly
every room uses one kit on a dead-flat floor"; the Gear Pit, a set piece, was named the best
frame of the pass 570 set) and the pass 540 grade before them ("rooms read as one template ...
give rooms a landmark set piece").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the Haar fog item waits for the hydra and steam branches; this is the
next one that can be done unattended, as pass 573 named under "Next". The PixelLab art loop stays
**gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his
OK, the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.
`README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- 12.56's rule: the cheapest set piece is one a room already promises. `tower/ore_bin` is named
  for a bin, and its sign reads "ORE BIN 3. Raw ore down the chute, sorted ore up the winch. The
  bin is half full still. Nobody came to empty it." The room held a flat floor, two hung ledges,
  a chest, a Gear Bat, a Minecart Rider and a secret behind a fake wall. No bin, chute or winch.
- The room is 38 tiles wide and 16 high inside. The ledges hang over tiles 10 to 21; tiles 22 to
  30 are open from floor to ceiling, and a shelf of solid stone stands east of tile 30 from row
  14 down. A bin 7 tiles wide fits between the high ledge and the shelf without crossing either.
- The Ore Chute is two rooms west on the map, so a chute into the bin should lean from the west.

## What was built

- **`OreBin`** (`scripts/world/ore_bin.gd`, room prop `ore_bin`), painted like the ore road
  (bible 12.60): whole world pixels on master palette ramps, lit from the upper left, baked once.
  - A box of nine planks (96 by 72 px) under a cap beam, on two posts with stone footings, a
    cross and a low tie between them; two riveted iron straps down its front.
  - An iron hopper under it, narrowing to a spout 52 px over the floor, with a plate seam, rust
    in its shade and a slide gate with a lever.
  - A boxed chute, bound with iron, down from the ceiling into the bin's mouth from the west.
  - The sign's words: four sprung planks with ragged ends, one hanging by a nail; through the
    breach the ore lies to half the box's height, heaped a little under the chute, with the dark
    of the empty half over it. A thread of ore falls from the gate to a spill 8 px high.
  - The winch's kibble, an empty iron bucket, hangs on a chain from the ceiling east of the bin
    and sways at its end (drawn live).
- **The room** (`levels/tower/ore_bin.room`): `prop: 26, 19, ore_bin`. Nothing that is solid
  changed, so reachability is as it was.
- Design bible 12.61; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound.

Looked at in `tower/ore_bin` at 1x from the west door and beside the bin, and at 2x on the bin.
The first take drew the empty half as speckled blocks of two darks, which read as a glitch; it
is now flat stone-1 with the back wall's plank seams and night-0 above. The hopper's rust was
thinned. The half-full line reads at 1x. The room's own decor (two picks) lands in the spill by
chance and looks placed. One thing for Sean to judge in play: whether the spill reads as a step
(it is 8 px high and nothing on it is solid).

## Tests

`tests/test_ore_bin.gd`, seven tests, 135 checks: the palette (every tone a master value, no
stray pixel, every tone used); nine planks each lit above, shaded below and seamed, two whole
posts lit down the left on footings, the cap, a rivet a plank in each strap; the half-full bin
(the ore line at half height, three to five sprung planks with ragged ends, ore below its top
and none above, no hole in it, a lit and slightly heaped top that is highest under the chute);
the hopper that only narrows, lit left and rusted in its shade only, its gate, lever, thread of
ore and low spill between the posts; the chute whole from the ceiling to the cap, leaning from
the west, bound with iron; the kibble's chain that sways at its end only, clear of the bin and
over every head; and in the room, both posts on solid floor in open air, the chute out of the
ceiling, the kibble in open air, no wall or ledge across the bin, the sign's words, scenery only.

Mutation check, each restored from a copy and compared byte for byte: a nearly full bin fails
the half-full test (three checks); no breach fails it (six); a hopper lit from the right fails
the hopper test; a spill 20 px high fails it; a chute from the east fails the chute test (two);
an off-palette rust fails the palette test; a chain that sways along its whole length fails the
kibble test; the room without its prop fails the room test; the bin under the ledges fails the
room test (30 points covered).

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Ore Bin has its landmark; the Heartwood's Dwarf Hall and Hornet Gallery are still one template. |
| Art cohesion | 15 | 98 | The bin is on the master ramps and the light of the other set pieces. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | What the sign says of the bin, the chute and the winch can now be seen. |

Weighted: 98.85.

## Next

The independent grade is due after pass 575; include `tower/ore_bin` and `tower/rail_gallery` in
its set. The next one-template rooms by the same rule: the Heartwood's Dwarf Hall and Hornet
Gallery; then varied spawn sides. The Evercrown's other halls (the Threshold, the Proving Scar)
have no midground either. Code-first liquids and hazards (the amber pool, the lava column, the
Boughs' wind dashes). The mouths, the gears, the bell and now the bin's falling ore would be
worth sounds in an audio pass. Tooling worth a short pass: the room budget test measures
wall-clock time; the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The
sword in the hit frames waits for a watched feel call. The Haar items wait until the hydra and
steam branches merge; the Blinkhop waits for a free base slot.
