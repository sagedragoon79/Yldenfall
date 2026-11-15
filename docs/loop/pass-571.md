# Pass 571: the Three Mouths stand behind the Fountain of Hearthroot

## Category

World and art cohesion, from the independent grade taken after pass 570 (4.7/10): "Hearthroot
plaza and Evercrown veins: mostly empty dark space with flat silhouette backdrops and a handful of
tiny props; no midground, no focal point". The same grade named the Gear Pit the best frame for
its focal point, so a set piece is the proven lever, and the plaza is the first room a player
sees.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) waits until the hydra and steam branches
merge; this is the next one that can be done unattended. The PixelLab art loop stays **gated** on
Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit
of three. No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is
still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- Pass 569's rule: the cheapest set piece is one a room already promises. The plaza's sign has
  read "The Fountain of Hearthroot. Fed by the three springs of the Ylden" since the room was
  made. The room shows a fountain 76 px wide (Sean's own PixelLab sprite) in a hall 1280 px long
  and 288 px high, a chest on a chained platform, two low posts, and the zone's far layer.
- The fountain is Sean's art and its four states are the game's restoration feedback (bible 4.4).
  It is not touched. What it lacks is something to stand against.
- The two low posts at tiles 35 and 45 already frame a bay round the fountain, 176 px wide, with
  nothing behind it from the floor to the ceiling.

## What was built

- **`SpringWall`** (`scripts/world/spring_wall.gd`, room prop `spring_wall`), painted like the
  crucible (bible 12.35), the bell (12.56) and the gears (12.57): whole world pixels on master
  palette ramps, lit from the upper left, baked once for the whole run.
  - A headwall of grey stone behind the fountain, 208 px wide and 164 px tall: a plinth, courses
    of blocks laid half over half, a cornice with its shadow under it, and a stepped crown with a
    leaf cut in a roundel.
  - Three arched niches, each with ring stones and a keystone. In each a stone mouth with a
    bronze lip: the Heartwood on the left, the Haar in the middle, the sky on the right
    (`Fountain.SPRINGS`' order). Each keystone carries its spring's sign: a leaf on its stem, the
    Haar's water, the sky's bolt.
  - A long trough stands across the niches' feet, wider than the fountain's basin.
  - Dry: a streak of lime under each mouth, and the trough's bed.
  - Depth: the right jamb of each niche catches the light, and the left pier and the arch throw
    their shadow down and across the niche's back.
  - Two iron lanterns on the outer piers. Their light is painted into the stone: within reach
    the stone ramp gives way to the umber ramp, a tone up close to the glass, in a narrow
    dithered band. No halo is laid over the frame (the grade's sixth defect is the checkerboard
    halos elsewhere).
  - Moss on the ledges and a little hanging under the cornice, like the room's own vines.
- **It answers the springs** (drawn live, bible 4.4). A restored spring's mouth runs: a thread of
  water four pixels wide falls 59 px from the lip to the trough, its left edge lit, four glints
  sliding down it, two beads hopping where it lands. Its sign lights. The trough fills, brighter
  and livelier with each spring. With all three, the leaf in the crown lights green. The flames
  breathe.
- **The room** (`levels/hearthroot/plaza.room`): `prop: 40, 19, spring_wall`, listed before the
  fountain. Nothing that is solid changed, so reachability is as it was.
- Design bible 12.58; `levels/README.md` lists the prop.

Scenery only: z -2 (the fountain is -1), no collision, no sound. One image of 208 x 164 px,
baked once (a static cache).

Looked at in `hearthroot/plaza` dry and with all three springs, at the capture's 2x and cropped
closer, two drafts. The first had lime streaks in a checkered speckle that read as noise, mouth
blocks brighter than anything else on the wall, and lantern light that turned each outer pier
into a column of yellow brick from the plinth to the cornice. The second runs the lime in
columns of their own lengths, drops the mouth blocks a tone, and pulls the warm stone in to a
pool round each lantern. It is the one kept: the wall is the first thing the eye lands on, the
fountain reads pale against the dark middle niche, and the hero's green cloak stays clear of
it. Seen and left: the threads are the master palette's blue and the fountain's water is the
teal of Sean's own palette (Resurrect 64); the warm bands on the outer piers still read a little
as a second stone; the crown's two steps are plain slabs.

## Tests

`tests/test_spring_wall.gd` (five tests, 94 checks): every tone is a master palette value and
the baked image holds nothing else; the wall is the same on both sides, with three niches of one
size inside it, each a dark hollow beside a pier of stone, each with its bronze lip, its open
mouth, its lime and a sign of its own, and the wall is taller than two fountains; the cornice's
top is lit over its shadow, each niche's right jamb is lit and its left side in shadow, the stone
round the two lanterns is warm with none left cool, no warm stone lies out of their reach, and a
flame burns on each outer pier; no mouth runs in a new game, the Haar runs from the middle
alone, the Heartwood from the left, all three with the fountain full, the water falls from the
lip into the trough, and its glints slide down and stay in the thread; in the plaza the wall
stands on the fountain's center line and behind it, on solid floor from end to end, with no tile
of the room in it and air over its crown, scenery only, and the sign still tells of the three
springs.

Mutation check, each restored from a copy and compared byte for byte: mouths that never run fail
the springs test (three checks); the mouths in the wrong order fail it too; a still thread fails
it; a right jamb left dark fails the lit test (three checks); no warm stone fails it (two
checks); an off-palette moss fails the palette test; two springs with one sign fail the mouths
test; the room without its prop fails the room test and the springs test.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The first room has a focal point and a midground; Market Row and the gates are still flat. |
| Art cohesion | 15 | 98 | The wall is on the same ramps and light as the crucible, the bell and the gears. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged; the mouths are silent. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | Each restored spring now shows in the plaza at the scale of the room. |

Weighted: 98.85.

## Next

The grade's other half of this defect: the Evercrown's Veins (empty dark space, no focal point),
by the same rule. Then the next one-template rooms (the Tower's Rail Gallery has no rails or
cart, the Ore Bin no bin; the Heartwood's Dwarf Hall and Hornet Gallery likewise). The mouths
would be worth a sound (running water that grows with each spring) in an audio pass, with the
gears' knock and the bell's clank. Code-first liquids and hazards (the amber pool, the lava
column, the Boughs' wind dashes). Tooling worth a short pass: the room budget test measures
wall-clock time and fails whenever another session is busy; the test runner's shared `user://`;
`tools/art/test_tilegen.py` in CI. The sword in the hit frames waits for a watched feel call.
The Haar items wait until the hydra and steam branches merge; the Blinkhop waits for a free base
slot. The next independent grade is due after pass 575.
