# Pass 573: the ore road runs the length of the Rail Gallery

## Category

World and art cohesion, from the independent grades taken after passes 565 and 570 ("nearly
every room uses one kit on a dead-flat floor"; the Gear Pit, a set piece, was named the best
frame of the pass 570 set) and the pass 540 grade before them ("rooms read as one template ...
give rooms a landmark set piece").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one that can be done unattended, as pass 572 named under
"Next". The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- 12.56's rule: the cheapest set piece is one a room already promises. `tower/rail_gallery`'s
  sign has read "ORE ROAD. Carts run east to the Haar cut." since the room was made. The room is
  80 tiles long and held a flat floor, two beds of spikes, two tables, a pillar and a chest. No
  rail, and no cart but the one its guard rides.
- From the ceiling (row 4) to the highest ledge (row 9, at the east end only) the room is empty
  along its whole length: room for a road overhead that crosses no ledge.
- The pillar (tiles 56 to 60) and the way down to the vault (tiles 70 to 72) break the floor, so
  supports cannot stand at one even step.

## What was built

- **`OreRoad`** (`scripts/world/ore_road.gd`, room prop `ore_road`), painted like the crucible
  (bible 12.35) and the great gears (12.57): whole world pixels on master palette ramps, lit from
  the upper left, baked once.
  - A rail on sleepers and a heavy stringer, from wall to wall (1248 px), its head 216 px over
    the floor and 40 px under the ceiling.
  - Eight timber bents carry it: two splayed legs on stone footings, three bolted girts, a cross
    brace in each tier, a knee out to the stringer on each side, an iron-strapped cap. They stand
    128 to 176 px apart, clear of the pillar and the way down, each with both feet on solid floor.
  - One cart on the rail west of the middle: a riveted iron tub on two wheels, rusted in its
    shade, heaped with ore.
  - A fallen span east of the cart, 60 px wide: the stringer snapped and splintered at both
    ends, the rail hanging bent 18 px into the gap, a stub standing out from the east, a timber
    and a sleeper on the floor below.
  - A hoist chain with a hook hangs from the stringer and sways at its end (drawn live).
- **The room** (`levels/tower/rail_gallery.room`): `prop: 1, 19, ore_road`. Nothing that is solid
  changed, so reachability is as it was.
- Design bible 12.60; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound. The image is baked once for the whole run with
rectangle fills, not a pixel at a time, so it adds little to the room's load (the load budget
test is the one that fails on a busy PC; see the tooling item in the queue).

Looked at in `tower/rail_gallery` at 1x at the west end, the middle and the east end, and at 4x
at the cart and the fallen span. Timber on the wood ramp stands apart from the Tower's violet
stone and from the green-grey tables that can be stood on. The one doubt is whether the deck
reads as a ledge to reach: it is higher than any ledge, 2.5 tiles under the ceiling, and drawn
in a material no platform uses. Worth a look from Sean in play.

## Tests

`tests/test_ore_road.gd`, seven tests, 185 checks: the palette (every tone a master value, no
stray pixel, every tone used); the rail whole from wall to wall but for the fallen span, on its
sleepers, the stringer lit above and shaded below; eight bents a span apart with splayed legs
lit down the left, three girts and feet on the floor; one loaded cart on whole rail under the
ceiling, and nothing else on the road; the bent rail that only falls, and the timber under the
gap; the chain that sways at its hook only; and in the room, both ends let into the walls, the
road and every bent in open air, every foot on solid floor, scenery only.

Mutation check, each restored from a copy and compared byte for byte: no fallen span fails the
length test and the span test (four checks); legs lit from the right fail the bent test (16);
no cart fails the palette test and the cart test (eight); a bent over the way down fails the
room test (both feet); an off-palette rust fails the palette test; a chain that sways along its
whole length fails the chain test; a rail that rises fails the cart test and the span test
(three); the room without its prop fails the room test.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Rail Gallery has a midground and a landmark; the Ore Bin and the Heartwood's halls are still one template. |
| Art cohesion | 15 | 98 | The road is on the master ramps and the light of the other set pieces. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | What the sign says of the ore road can now be seen, and the road is cut like the rest of the Tower. |

Weighted: 98.85.

## Next

The next one-template rooms (the Tower's Ore Bin has no bin; the Heartwood's Dwarf Hall and
Hornet Gallery likewise). The Evercrown's other halls (the Threshold, the Proving Scar) have no
midground either. Code-first liquids and hazards (the amber pool, the lava column, the Boughs'
wind dashes). The mouths, the gears and the bell would be worth sounds in an audio pass. Tooling
worth a short pass: the room budget test measures wall-clock time and fails whenever another
session is busy; the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The
sword in the hit frames waits for a watched feel call. The Haar items wait until the hydra and
steam branches merge; the Blinkhop waits for a free base slot. The next independent grade is due
after pass 575.
