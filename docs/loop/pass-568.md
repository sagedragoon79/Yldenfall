# Pass 568: the aqueduct's stone is worn and mossed, and its fall is a sheet of threads

## Category

Art cohesion and environments, from the independent grade taken after pass 565 (4.6/10): "Sunken
aqueduct: brick repeats uniformly with no edge wear or moss, the waterfall is a flat cyan strip,
the underwater area an empty dithered gradient with one fish".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one that can be done unattended, as pass 567 named under
"Next". The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- `paint_spring` (12.39) gives a block a lit top, a lit left edge, a pore and the odd mineral
  drip. `field_wear` (12.47) was never called for it, so the Sunken Spring was the one masonry
  zone with no crack and no moss in its field: a pier was clean from cap to foot.
- A wall face had its row-8 variant since pass 565 (12.53), but the variant differed from the base
  only in where its joints fell.
- `AqueductSpill` drew the fall as one `WATER` rectangle per two rows with a dark pixel at each
  side, and three light dashes that all moved at 160 px/s: a strip that slid. Its foot was five
  foam blocks and four drops; nothing touched the water's surface or went under it.
- The trough was blue-grey (`5a6a78`), a colour no tile in the room has. The blocks are `umber`.
- The catalogue picture puts the fall at the frame's left edge, cut in half by it. The picture
  for this room is taken from the door; a framing fix belongs to the capture list, not the room.

## What was built

- **Wear on the ashlar** (`spring_wear`, `tools/art/tilegen.py`). Only tiles that have variants
  carry a mark, so nothing repeats down a pier: the scattered field variants and the variant of
  each wall face.
  - A chipped arris in about half of the variants (`SPRING_CHIP`): the lit corner of one block
    broken away at its head joint.
  - A hairline crack in about four field variants in ten (`FIELD_CRACK`).
  - A clump of moss in a bed joint (`SPRING_MOSS_SEEDS`), four to seven world pixels long, on two
    of the three surface variants and on both face variants. The darkened tiers grow none.
- **The fall is a sheet** (`scripts/world/aqueduct_spill.gd`), drawn a column at a time: dark
  rims, a body and a light core (`column_tone`); it spreads 4 px on the way down; every column
  runs its own light thread and dark gap at its own spacing, length and speed (`streak`); the rims
  tear into drops over the last 26 px.
- **Where it lands**: a pale plunge under the surface with bubbles carried down and out, mist in
  three flat bands, wider foam, more spray, and rings running out along the surface (`ring`).
- **The trough** is the room's travertine, jointed, with the spring sliding along its bed and
  moss hanging under it.
- Design bible 12.55; 12.47 points to it.

Only `assets/tiles/sunken.png` changed among the atlases (one zone was regenerated, not the whole
run). The fall is still scenery and its sound is unchanged.

Looked at before and after at 1x and 3x in `sunken/drowned_aqueduct`. The fall reads as falling
water with a lit middle, and the trough belongs to the room. The piers show chips and cracks in
their fields and moss on their faces. One thing seen and left: a pier's face has one variant
beside its base tile, so the same clump of moss can stand on two or three tiles in a row down a
face. A third face tile needs a ninth column in the atlas; it is in the queue.

## Tests

`tests/test_aqueduct_fall.gd` (six tests): the sheet spreads, has three tones that mirror about
the middle, and its outer columns start lower; the columns fall at four speeds or more with three
spacings and four lengths; both rims are torn at the foot, the middle lands whole and nothing is
torn higher up; a ring runs out, thins and fades, the rings are staggered, and the mist is three
bands that step; the trough's body is the colour the room's blocks are painted in; two of the
three surface variants and both face variants carry a clump of moss, no blob tile does, and the
room lays both face variants.

`tools/art/test_tilegen.py` (four tests named `test_sunken_`): wear is on tiles that have variants
only; moss lies along a bed joint, clear of a face's outline, and not in the darkened tiers; a
chip is at a head joint and on a third to four fifths of the variants; the chip and the moss are
whole world pixels. That file's `test_atlas_has_the_variant_row` had failed since pass 565 (it
held the atlas to eight rows); it now expects nine. The file is not part of the Godot suite or of
CI and is run by hand: `python tools/art/test_tilegen.py` (75 checks).

Mutation check: one streak for every column fails "every column runs its own streaks" (three
checks); one tone fails the sheet test and the tear test; the old grey trough fails the trough
test (four checks); the pass 567 atlas fails the moss test (three checks). In the generator: no
wear fails three of the four; wear on every tile fails the variants test; moss in the darkened
tiers fails the moss test; a chip on every variant fails the chip test. The script and the atlas
were restored from copies each time and compared byte for byte.

Full suite: 15836 checks passed, 6 failed, in five tests, all wall-clock budgets
(`test_a_journey_after_the_end_stays_lean`, `test_every_boss_fight_holds_the_frame_budget`,
`test_the_boss_rush_and_damage_numbers_stay_lean`,
`test_every_room_loads_and_settles_inside_the_budget`, `test_every_foes_spoils_rest_in_its_room`)
while other programs ran on this PC. None of the rooms they name is in the Sunken Spring. Each
passes when run alone right after (47 checks). CI's full suite on a quiet machine is the check.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | The Sunken Spring's stone is worn and its landmark fall reads as water. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the fall draws about 150 rectangles a frame in one room. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Of the queue: one-template rooms (a landmark set piece and a varied spawn side, room by room),
then the rest of the Sunken item: the pillars-and-water remark's underwater half (the open water
is empty but for the eels) and a third face tile so a pier's moss does not repeat. The sword in
the hit frames waits for a watched feel call. The next independent grade is due after pass 570.
The test runner's shared `user://` (found in pass 563) is still worth a short tooling pass, and
`tools/art/test_tilegen.py` should run in CI. The Haar items wait until the hydra and steam
branches merge; the Blinkhop waits for a free base slot.
