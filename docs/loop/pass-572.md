# Pass 572: the Everbloom's stalk stands up the back of the Veins

## Category

World and art cohesion, the other half of the defect pass 571 began on. The independent grade
taken after pass 570 (4.7/10): "Hearthroot plaza and Evercrown veins: mostly empty dark space
with flat silhouette backdrops and a handful of tiny props; no midground, no focal point". The
plaza has the Three Mouths (12.58); this is the Veins.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) waits until the hydra and steam branches
merge; this is the next one that can be done unattended, and pass 571 named it under "Next". The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no
Autosprite credits. The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- Pass 569's rule: the cheapest set piece is one a room already promises. The Veins' sign has
  read "The light that fled the throne runs up these veins to the core" since pass 82. The room
  is a shaft 40 tiles wide and 68 high, the second hall of the last fight. It shows zigzag
  shelves on sinew, six `LightVein` crystals 14 px wide, the zone's far tendrils, and at the top
  a core 96 px across. Nothing joins the veins to the core, and between the shelves the middle
  of every frame is the dark far layer.
- Looked at from the foot (tile 3,65), the middle (16,37) and the head (20,8): the same frame
  three times, and only the head has anything to look at.
- The fight's health bar is "the veins still lit" (8.9), told only by the bar at the bottom of
  the view.

## What was built

- **`BloomStalk`** (`scripts/world/bloom_stalk.gd`, room prop `bloom_stalk`), painted like the
  crucible (12.35) and the Three Mouths (12.58): whole world pixels on master palette ramps,
  lit from the upper left, baked once for the whole run.
  - Three strands of stillglass flesh, braided, stand up the middle of the shaft's back wall
    for all of its 992 px. Each strand is 24 px across and the braid about 50, about as thick
    as the hero is tall. Each strand passes in front of the others and behind them in turn (one
    full turn in 232 px), and throws its shadow on the strand behind it.
  - At the floor the strands swing wide and thicken into roots, with a lesser root running out
    to either side. In the vault they spread the same way into a crown round the core, with two
    buttresses.
  - Flesh on the night ramp: night-1 its body, night-2 on each strand's left side, a broken
    glint of night-3, crystal-0 in shadow. Creases of crystal-1 ring each strand, bowed like
    the folds of a stem. Nothing on the ember ramp (12.48).
- **It carries the light, and loses it** (drawn live). Six channels are cut along the strands,
  two a strand, one for each vein in the room, the lowest vein first. A whole vein's channel
  carries a dim line (sky-2) with seven beads (sky-3, sky-4) climbing it to the core, stepped
  at 10 frames a second like the veins' own light. Cut the vein and its channel goes dark.
  After the fight the veins stay cut, so the stalk is dark for good. The Stillstone holds the
  light, as it holds the core and its beams.
- **The room** (`levels/evercrown/veins.room`): `prop: 19, 65, bloom_stalk`. Nothing that is
  solid changed, so reachability and the fight are as they were.
- Design bible 12.59; `levels/README.md` lists the prop.

Scenery only: z -2, no collision, no sound. One image of 256 x 992 px, baked row by row (only
each limb's span is painted), and the lit lines are drawn in runs, redrawn only when the light
steps or a vein is cut.

Looked at in `evercrown/veins` at the foot, the middle and the head, lit and dark, at the
capture's 2x and cropped closer, two drafts. The first had strands 18 px across that left the
braid thin and gappy, a dither wide enough to speckle every strand, and side roots that ran out
132 px as straight thin lines, like wires. The second has strands 24 px across, a dither a
pixel wide at each step of tone, and shorter, thicker side limbs that curve. It is the one
kept: the stalk is the first thing the eye lands on in each of the three frames, it leads up to
the core, the hero's green cloak and the cyan veins stay clear of it, and the shelves' lit tops
stay brighter than it. Seen and left: the lit left side of a strand (night-2) is close to the
shelves' own violet where a shelf crosses the stalk; the side roots still end in long thin
tips; the core itself is still flat discs in colours of its own (its repaint belongs with the
Everbloom's PixelLab remake, the last guardian in the order).

## Tests

`tests/test_bloom_stalk.gd` (six tests, 149 checks): every tone is a master palette value and
the baked image holds nothing else, none of it a hazard's red or as bright as a vein; three
strands that each cross in front and behind, unbroken from the floor to the vault, a trunk
about as thick as the hero is tall, roots and a crown more than two and a half times as wide,
and an outline wherever the flesh meets the air; the trunk's left edge is lit and its right in
shadow, with creases and a broken glint; six channels, each showing for most of the height,
running from the roots to the crown in grooves of the baked stalk, with seven beads that stay
on it, apart, and climb; in the Veins every channel is lit before a cut, the lowest vein's
channel alone goes dark when it is cut, another follows, the light moves and the Stillstone
holds it, and after the fight every channel is dark; the stalk's axis is the middle of the
shaft, its roots on the floor and its crown at the vault, inside the walls, behind the veins,
scenery only, and the sign still tells of the light that runs up to the core.

Mutation check, each restored from a copy and compared byte for byte: channels that never go
dark fail the room test (three checks); the veins counted from the top fail it (five); a
strand lit from the right fails the lit test and the palette test's tone count; light that
ignores the Stillstone fails the room test; an off-palette crease fails the palette test; beads
that fall fail the channel test (six checks); strands that never cross fail the braid test and
the channel test; the room without its prop fails both room tests; the prop three tiles east
fails the room test.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | The Veins have a midground and a line to the core; the Evercrown's other halls are still flat. |
| Art cohesion | 15 | 98 | The stalk is on the zone's own ramps and the light of the other set pieces. The independent grade is the real measure. |
| Bosses | 10 | 99 | The core's health now shows on the room itself; the core's own picture is still crude. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The room budget test flakes on a loaded PC; see the tooling item. |
| Story and world | 5 | 99 | What the sign says of the veins and the core can now be seen. |

Weighted: 98.85.

## Next

The next one-template rooms (the Tower's Rail Gallery has no rails or cart, the Ore Bin no bin;
the Heartwood's Dwarf Hall and Hornet Gallery likewise). The Evercrown's other halls (the
Threshold, the Proving Scar) have no midground either. Code-first liquids and hazards (the
amber pool, the lava column, the Boughs' wind dashes). The mouths, the gears and the bell would
be worth sounds in an audio pass. Tooling worth a short pass: the room budget test measures
wall-clock time and fails whenever another session is busy; the test runner's shared `user://`;
`tools/art/test_tilegen.py` in CI. The sword in the hit frames waits for a watched feel call.
The Haar items wait until the hydra and steam branches merge; the Blinkhop waits for a free base
slot. The next independent grade is due after pass 575.
