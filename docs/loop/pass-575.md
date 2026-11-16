# Pass 575: the high seat of the Rot Dwarf Hall is split by the root

## Category

World and art cohesion, from the independent grades taken after passes 565 and 570 ("nearly
every room uses one kit on a dead-flat floor"; the Gear Pit, a set piece, was named the best
frame of the pass 570 set) and the pass 540 grade before them ("rooms read as one template ...
give rooms a landmark set piece").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the Haar fog item waits for the hydra and steam branches; this is the
next one that can be done unattended, as pass 574 named under "Next" (the Heartwood's Dwarf Hall
and Hornet Gallery). The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store
is suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- 12.56's rule: the cheapest set piece is one a room already promises. `heartwood/dwarf_hall` is
  the Rot Dwarf Hall, and its sign reads "These were Amberlee dwarves once. The rot came up
  through the roots with the sap." The hall held a flat floor 78 tiles long, four ledges, a
  chest, two Rot Dwarves and a moth. Nothing of the dwarves', no root, no sap.
- The hall is 18 tiles high inside. Its ledges hang over tiles 36 to 72; tiles 1 to 35 are open
  from floor to ceiling, and the sign stands on tile 10. A piece 11 tiles wide fits between the
  sign and the first ledge, and it is the first thing seen on the way in from the Fungus Shaft.
- The Hornet Gallery is left for the next pass by the same rule: one room, one landmark, one
  pull request.

## What was built

- **`HighSeat`** (`scripts/world/high_seat.gd`, room prop `high_seat`), painted like the ore bin
  (bible 12.61): whole world pixels on master palette ramps, lit from the upper left, baked once.
  - The hall's frame: a low stone dais (6 px), two carved timber pillars with ringed shafts and
    foot blocks, and a lintel 168 px long with a zigzag carved along its face.
  - The seat: a plank box, a seat board, two arms, and a tall board back with a stepped crest.
  - Two round shields, iron-rimmed with an iron boss, hung either side of the seat.
  - The sign's words: one root from the floor into the ceiling, thick and flared at its foot,
    wandering and thinning as it climbs. The dais is heaved up on both sides of it; the seat's
    back is split and its east half has dropped 5 px; the lintel is snapped and lifted 10 px on
    the west and 4 px on the east; the east shield has fallen from its nail and lies against the
    east pillar. One side root sags across to the east pillar, another comes up beside the seat
    and grips its arm.
  - "With the sap": seven threads of sap down the root's lit side, a pool on the seat board, a
    puddle on the dais, and a drop that swells under the east side root and falls every 3.2 s
    (drawn live). The timber rots within 14 px of the root and nowhere else.
- **The room** (`levels/heartwood/dwarf_hall.room`): `prop: 22, 19, high_seat`. Nothing that is
  solid changed, so reachability is as it was.
- Design bible 12.62; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound.

Looked at in `heartwood/dwarf_hall` at 1x from the west door and beside the seat, and at 2x on
the seat. The first take drew the root on bark-1 to bark-3 as a straight tapered pole down the
seat's middle: it was the brightest thing in the hall, brighter than the hero, and it hid the
seat. It is now one step darker (bark-0 to bark-2), it wanders and swells, and it goes up through
the west third of a wider back so both halves of the seat show. The rot was thinned; at the first
density it read as green noise. Two things for Sean to judge in play: whether the rot still reads
as noise at 1x, and whether the seat reads as a seat with a Rot Dwarf standing in front of it.

## Tests

`tests/test_high_seat.gd`, six tests, 146 checks: the palette (every tone a master value, no
stray pixel, every tone used); the dais, the two whole pillars lit down the left, the hung shield
and its nail, the bare nail and the fallen shield under it; the root (whole and outlined from the
floor to the ceiling, lit left and shaded right, thinning, flared at its foot, wandering between
the pillars and through the seat's back, darker than the timber, the heaved slabs, the side root
that sags to the east pillar); the split seat (the east half dropped by the same step in every
column, the back showing on both sides of the root) and the snapped lintel (gone at the root,
lying on both pillars, each half rising toward the break, the west more than the east, lit,
outlined and carved); the sap and the rot (gold only on the root, the pool and the puddle, seven
runs each begun with a glint, rot only within reach of the root, a drop that hangs, only falls
and lands on the puddle clear of the seat and the shield); and in the room, the dais on solid
floor, the root into the ceiling, no wall or ledge across it, the sign's words, the sign clear of
it, scenery only.

Mutation check, each restored from a copy and compared byte for byte: the room without its prop
fails the room test; the seat under the ledges fails it (36 points covered); a back that has not
dropped fails the split test; a lintel that is not lifted fails it (two checks); a gold boss on
the shields fails the frame test and the sap test (14 px astray); a root lit from the right fails
the root test (two); an off-palette rot fails the palette test; rot painted 60 px from the root
fails the sap test (1,878 px too far); a drop that rises fails it (three); a root that stops
under the lintel fails the root test (three); a fallen shield still hanging fails the frame test
(two). Two mutations of the rot painter survived at first because each still obeyed the rule (the
painter's threshold also falls off with distance); the one above breaks the rule itself.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Rot Dwarf Hall has its landmark; the Hornet Gallery is still the template. |
| Art cohesion | 15 | 98 | The seat is on the master ramps and the light of the other set pieces. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | What the sign says of the dwarves, the root, the rot and the sap can now be seen. |

Weighted: 98.85.

## Next

The independent grade is due now (every fifth pass): its set includes `tower/ore_bin`,
`tower/rail_gallery` and `heartwood/dwarf_hall`. The next one-template room by the same rule: the
Heartwood's Hornet Gallery (its sign promises nests "where the sap runs thickest"); then varied
spawn sides. The Evercrown's other halls (the Threshold, the Proving Scar) have no midground
either. Code-first liquids and hazards (the amber pool, the lava column, the Boughs' wind
dashes). The mouths, the gears, the bell, the bin's falling ore and now the seat's dripping sap
would be worth sounds in an audio pass. Tooling worth a short pass: the room budget test measures
wall-clock time; the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The sword
in the hit frames waits for a watched feel call. The Haar items wait until the hydra and steam
branches merge; the Blinkhop waits for a free base slot.
