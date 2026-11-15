# Pass 570: the Gear Pit's great gears stand in its back wall

## Category

World and art cohesion, from the independent grade taken after pass 565 (4.6/10): "nearly every
room uses one kit (rope or chain swings, a four-legged table platform, one chest) on a dead-flat
floor; zones differ by palette more than architecture", and the pass 540 grade before it ("rooms
read as one template ... give rooms a landmark set piece").

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one that can be done unattended, as pass 569 named under
"Next". The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- Pass 569's rule: the cheapest set piece is one a room already promises. `tower/gear_pit`'s sign
  has read "The great gears turned the winch from here. Their teeth still bite." since the room
  was made. The room held a table over a bed of spikes, two bats and a water drop. No gears,
  apart from a faint silhouette in the zone's far layer that every Tower room shares.
- Winch Hall lies under the room's floor door, so the sign's "from here" is true on the map.
- The wall east of the floor door (tiles 23 to 31) is empty from the floor to the ceiling, 16
  tiles of air: room for wheels taller than the hero, clear of the bed of spikes.

## What was built

- **`GearTrain`** (`scripts/world/gear_train.gd`, room prop `gear_train`), painted like the
  crucible (bible 12.35) and the bell (12.56): whole world pixels on master palette ramps, lit
  from the upper left, baked once.
  - Three wheels in mesh on the back wall: a great gear 112 px across its tips (26 teeth, six
    spokes), a second of 16 teeth and five spokes up and to its left, a pinion of 9 teeth above
    that. One pitch for all three; each stands off its driver by the sum of their radii with its
    tooth in the driver's gap, so no two wheels ever share a pixel.
  - The great gear sinks 8 px into the floor, toward the winch below. The upper two hang from
    the ceiling in riveted iron hangers; a post carries the great one.
  - Iron on the stone ramp, lighter to each wheel's upper left, with lit and shaded edges, a
    groove round each rim, and two pixels of dark side down and to the right so each wheel is a
    slab. Brass caps on the bearings.
  - Seized: rust in streaks that run round the wheels, only in the shade; one tooth of the great
    gear, on its upper side, snapped to a stub and lying on the floor; the drive chain hanging
    parted from the pinion, swaying at its end (drawn live).
  - "Their teeth still bite": every 7 s the train strains a sixth of a tooth and falls back,
    twice. Each wheel turns against its driver, faster by the ratio of their teeth. It is a
    second baked image, so the wheels stay whole pixels.
- **The room** (`levels/tower/gear_pit.room`): `prop: 27, 19, gear_train`. Nothing that is solid
  changed, so reachability is as it was.
- Design bible 12.57; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound. Both images are baked once for the whole run (a
static cache), about 30 rectangles a frame for the chain. One image costs about 0.1 s to bake on
this PC, a little more than the bell's. Two in the room's load put the Gear Pit over the 500 ms
load budget once in a loaded run, so the image at rest is baked as the room loads and the
strained one on a worker thread; the train shows the image at rest until it arrives.

Looked at in `tower/gear_pit` at 1x and 3x, three drafts. The first had a dither so wide that
every face was a checkerboard, rust in square blotches that read as camouflage, and near-black
hangers that read as holes in the wall. The second narrowed the dither, ran the rust round the
wheels in streaks, gave each wheel its dark side and the chain real links. The third narrowed the
teeth, since the test found a few pixels where meshing teeth overlapped. It is the one kept: at
1x the wheels are the first thing the eye lands on in the room, they read as a gear train, and
the hero and the room's spikes stay the brightest things near the floor. Seen and left: a decor
crate stands in front of the great gear's lower rim (the decor is seeded per room), and the
lower right of the great gear is close to the wall's value, which reads as its shade.

## Tests

`tests/test_gear_train.gd` (seven tests, 71 checks): every tone is a master palette value and
both baked images hold nothing else; three wheels of one pitch, each with its teeth, each a sum
of radii from its driver, no two sharing a pixel at rest, half strained or strained, and each
with a tooth between the other's; the great gear's upper left is brighter than its lower right
(by the test's own measure of upper left), all four irons and the brass are used, rust is in
streaks and only in shade, and each wheel shows its dark side; one tooth is a stub under the
pitch circle on the wheel's upper side, the other 25 are whole, and the tooth lies on the floor;
the train strains a sixth of a tooth, each wheel against its driver and faster by the ratio of
their teeth, in two short bites a cycle; the chain is still at the pinion's rim, sways 3 to 8 px
at its end, keeps its length and ends clear of the great gear; in the room the great gear stands
over solid floor and sinks into it, no wheel stands in a wall, both hangers are bolted into
solid ceiling, the sign stands clear and still tells of the gears, the train is behind the
actors with nothing to touch, and the strained image arrives after the room has loaded.

Mutation check, each restored from a copy and compared byte for byte: no broken tooth fails the
tooth test (and the tooth count); teeth set tip to tip fail the mesh test (six checks); no strain
fails the strain test (four checks); a still chain fails the chain test; an off-palette rust
fails the palette test; rust all over the shade fails the lit test; no slab side fails it too;
the room without its prop fails the room test; the train moved into the east wall fails it too
(two checks). The light from the lower right first passed: the test split the wheel by the
painter's own light. It now uses its own upper left, and the mutation fails it (0.55 over 1.48).

Full suite: 15988 checks passed, 1 failed, a wall-clock budget
(`test_every_room_loads_and_settles_inside_the_budget`: `spires/sky_steps` at 8.14 ms a frame)
while other sessions held this PC's processor at about 83%. Run alone five times it failed each
time on different rooms (Kettleforge, the Old Flue, the Proving Scar, the gym), and once on the
Gear Pit's load (509 ms), which is what moved the second bake off the load. That change came
after the full run. After it: the gear tests, every test with "tower", "landmark" or "reachab" in
its name, and the every-room tests pass (270 checks), except the same budget test, on
`evercrown/proving_scar` (522 ms) alone. CI's full suite on a quiet machine is the check.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | A second room has something of its own; 20 Tower rooms are still the template. |
| Art cohesion | 15 | 98 | The gears are on the same ramps and light as the crucible and the bell. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged; the gears are silent. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | The room now shows what its sign tells. |

Weighted: 98.85.

## Next

The independent grade taken after this pass is in `workbench/grades.json`; its top defects go to
the queue. Of the queue: the next one-template room by the same rule (the Tower's Rail Gallery
has no rails or cart, the Ore Bin no bin; the Heartwood's Dwarf Hall and Hornet Gallery
likewise), and a varied spawn side. The gears' bite would be worth a sound (a dull iron knock)
in an audio pass, with the bell's clank. Then the rest of the Sunken item (the open water, a
third face tile). Tooling worth a short pass: the room budget test measures wall-clock time and
fails whenever another session is busy (measure against a calibration room, or retry a room that
misses); the test runner's shared `user://`; `tools/art/test_tilegen.py` in CI. The sword in the
hit frames waits for a watched feel call. The Haar items wait until the hydra and steam branches
merge; the Blinkhop waits for a free base slot.
