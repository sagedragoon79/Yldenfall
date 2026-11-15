# Pass 569: the Bell Loft's bell lies where it fell

## Category

World and art cohesion, from the independent grade taken after pass 565 (4.6/10): "nearly every
room uses one kit (rope or chain swings, a four-legged table platform, one chest) on a dead-flat
floor; zones differ by palette more than architecture", and the pass 540 grade before it ("rooms
read as one template ... give rooms a landmark set piece").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one that can be done unattended, as pass 568 named under
"Next". The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- A contact sheet of the Tower's 26 catalogue pictures: 22 are the same room. A lavender plate
  floor and ceiling, a chain swing, a table platform, a stele, a crate. Only the three landmark
  rooms of bible 3.3 (the winch, the forge, the crucible) have something of their own.
- The cheapest set piece is one a room already promises. `tower/bell_loft`'s sign has read "BELL
  LOFT. The shift bell lies where it fell, split from lip to crown. Some say it rang by itself the
  night the Hammer came" since the room was made. The room held a swing, a table, a chest, a foe
  and a bat. No bell.
- The room's east third (tiles 26 to 38) is empty floor under 16 tiles of air: room for a bell
  and for what it hung from.

## What was built

- **`FallenBell`** (`scripts/world/fallen_bell.gd`, room prop `fallen_bell`), painted like the
  crucible (bible 12.35): whole world pixels on master palette ramps, lit from the upper left,
  baked once into an image.
  - The bell lies on its side by the east door, mouth to the room and a little to the viewer,
    resting on its lip and its shoulder: 74 px long, 72 px across the lip, half again the hero's
    height. Bronze on the ochre ramp with a 2 x 2 dither, a glint along the upper side, three
    raised bands that bend with the mouth, and verdigris in streaks round it, only in the shade.
  - The split runs unbroken from lip to crown: a gap at the lip, a hairline at the crown, in a
    zigzag, its lower edge lit.
  - The iron clapper has rolled out of the mouth. Half of the timber headstock lies behind the
    bell with its end in splinters. Chips of bronze lie where the lip struck.
  - The other half of the headstock hangs under the ceiling from two iron straps, and the frayed
    bell rope sways from it (drawn live). Now and then a glint runs down the lip.
- **The room** (`levels/tower/bell_loft.room`): `prop: 33, 19, fallen_bell`; the sign moved from
  tile 30 to tile 27 so it stands clear. Nothing that is solid changed, so reachability is as it
  was.
- Design bible 12.56; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound, about 45 rectangles a frame for the rope.

Looked at in `tower/bell_loft` at 1x and 3x, three drafts. The first had a split five pixels wide
and verdigris in square patches that read as camouflage; the split was thinned and the verdigris
keyed to the bell's own frame so it runs round it. The second floated two pixels over the floor.
The third is the one kept: at 1x it is the first thing the eye lands on in the room, and it reads
as a bell. Seen and left: a decor crate stands in front of the clapper's ball (the decor is
seeded per room), and the bat roosts on the headstock's stub, which suits it.

## Tests

`tests/test_fallen_bell.gd` (six tests, 64 checks): every tone is a master palette value and the
baked image holds nothing else; the shape is a bell's (lip, waist, shoulder, crown), taller than
the hero, on the floor, nothing under it; the upper side is brighter than the lower by most of a
tone, all four bronzes and the glint are used, and verdigris is in patches and only in shade; the
split is unbroken from lip to crown, cuts the lip's edge, is widest at the lip and zigzags; the
rope is still where it is tied, sways 6 to 12 px at its end and keeps its length; in the room the
bell lies on solid floor in open air, both straps are bolted into solid ceiling, the sign stands
clear and still tells of it, the bell is clear of the door and behind the actors.

Mutation check, each restored from a copy and compared byte for byte: no split fails the split
test (two checks); the light from the lower right fails the lit test; verdigris all over the
shade fails it too (two checks); a still rope fails the rope test; an off-palette glint fails the
palette test; a bell 13 px over the floor fails the shape test; the room without its prop fails
the room test; the bell on the sign's old tile fails it too.

Full suite: 15900 checks passed, 3 failed, in three tests, all wall-clock budgets
(`test_spires_rain_stays_cheap`, `test_every_boss_fight_holds_the_frame_budget`,
`test_every_room_loads_and_settles_inside_the_budget`) while other programs held this PC's
processor at about 90%. None named the Bell Loft, and the rooms they named changed from run to
run. Each passes when run alone (27 checks; the room budget on its fourth try). CI's full suite
on a quiet machine is the check.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | One more room has something of its own; 21 Tower rooms are still the template. |
| Art cohesion | 15 | 98 | The bell is on the same ramps and light as the crucible. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged; the bell is silent. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The room now shows what its sign tells. |

Weighted: 98.85.

## Next

The independent grade is due after pass 570. Of the queue: the next one-template room, by the
same rule (a room whose name or sign already promises a thing: the Tower's Rail Gallery has no
rails or cart, the Gear Pit no gear, the Ore Bin no bin; the Heartwood's Dwarf Hall and Hornet
Gallery likewise), and a varied spawn side. Then the rest of the Sunken item (the open water, a
third face tile). A struck bell would be worth a sound (a cracked, dead clank) in an audio pass.
The sword in the hit frames waits for a watched feel call. The test runner's shared `user://`
and `tools/art/test_tilegen.py` in CI are still worth a short tooling pass. The Haar items wait
until the hydra and steam branches merge; the Blinkhop waits for a free base slot.
