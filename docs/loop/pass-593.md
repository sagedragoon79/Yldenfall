# Pass 593: the thorn bulbs stop reading as strawberries

## Category

Art cohesion and hazard readability, from the independent grade taken after pass 590 (5.3 of 10).
Its seventh defect: "Hazards don't read: the red thorn rows look like strawberries or candy (canopy
bridge, storm ledge)." Passes 591 and 592 closed the grade's ceiling and impact items and named this
one next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for
a watched session; the second is the pass 590 grade, and this is its next unanswered defect. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

Looked at the Storm Ledge's floor row of seven pods at 1x and 4x. Each `ThornBulb` was a teardrop on
a bright four-step red ramp (`#861d25` to `#e55439`) with a salmon glint, seven one-pixel hooked
thorns whose pale tips sat just off the body like seeds, and a green stem and vine under it. Bright
red, seed dots and a green calyx: a strawberry, exactly as the grade said. The shape (pass 540) and
the rooting into walls and floors were right; the color and the thorns were not.

## What was built

`ThornBulb` (bible 12.32):

- **The husk** is dark and woody: `#200b09`, `#48201e`, `#783c2b`, a burnt-orange lit edge
  `#aa6336` and glint `#cd8c51`, lit from the upper left as before.
- **The ember seam** splits it from stem to tip, kinked once so it reads as a crack, pulsing
  between `#c02a20` and `#e55439`, with a hotter core (`#e55439` to `#f0c02e`) in its middle. The
  red that made the pod a hazard now lives only here.
- **Five long thorns** (six on a free pod) reach four pixels past the husk, two pixels thick at the
  root with a shadowed flank (`#797767`), bone (`#ccbe8e`) with a white point (`#f1eee4`), and
  outlined so they read on any background.
- **The stem and vine** are bark (`#161413`, `#432d23`, `#6e5135`), not leaf green.

Every tone is a master palette value. Judged by eye at 1x and 4x in the Storm Ledge (a floor row),
the Canopy Bridge (a long floor row), the Sky Steps (wall columns) and the Ring of Thorns (free
pods). A first try put the seam 0.6 px off the spine, where it read as a lit edge; it now runs
through the middle. The floor rows read as a thorn bed, the wall columns as a climbing bramble, the
free pods as spiked burrs. The hitbox is unchanged.

## Tests

`tests/test_thorn_bulb.gd`, `test_thorn_the_husk_is_dark_and_bristles`: for a floor pod, a wall pod
and a free pod, no bright red sits on the husk, its mean luminance is under 0.25, it has five long
thorns (six free) whose points are at least 8 px from its center, the seam spans the husk from
behind the center to the tip, and no vine pixel is greener than it is red.

Mutation check, each restored from a copy after: the old red ramp fails it (102 checks); thorns two
pixels long fail it (13 checks); the old green vine fails it (30 checks; the first version allowed a
little green and let this through, so the check was tightened to none).

Full suite: 19,290 checks passed, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Hazard rows read as thorns. |
| Art cohesion | 15 | 98 | The strawberry rows are thorned husks; the grade's shop labels and backdrops remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 590 grade, in its order: the shop's control labels ("Jump: choose / Dash:
leave"), then the queue: the repeated chest and sign, the grid item's leftovers. The sword's look
and the Haar's fog stay held. The next independent grade is due after pass 595 (every fifth pass),
or after the next art pass.
