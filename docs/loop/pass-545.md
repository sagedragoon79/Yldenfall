# Pass 545: the Everbloom's veins are crystal knots

## Category

A defect from the pass 535 independent grade, carried in pass 544's "Next": "flat cyan diamonds" in
the Evercrown veins. Art cohesion, and Characters and foes in the grade (the veins are the targets of
the Everbloom's second phase).

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, and the third
(one-template rooms) is a level-design rework. No PixelLab generations were spent.

This pass was cut off by an app restart on 2026-11-11 with the art written but untested; the run on
2026-11-12 resumed it. The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean.

## Audit

The veins are `LightVein` (`scripts/bosses/light_vein.gd`, legend `x`), the six targets climbing the
`evercrown/veins` shaft. Each drew one smooth pentagon in a single cyan, a lighter inner diamond that
faded with a sine, and a translucent blue thread above it: vector shapes with sub-pixel edges and
blended alpha, off the master palette, redrawn every frame.

## What was built

- The knot is baked once into an image (`build_image`) in whole world pixels on master palette ramps
  (sky-1 to sky-7, night-0 to night-4), lit from the upper left:
  - Three shards, back to front, each a faceted prism: a lit left face, a front face, a shaded right
    face and a pointed cap (`face`, `crystal_tone`), a step darker toward the root; the side shards sit
    a step or two darker than the main one; a glint on the lit edge of each cap.
  - A fleshy node of the Evercrown's night ramp with four root hairs.
  - One outline closes every shape.
- The light is stepped at 10 frames a second: a bright head climbs the main shard's front face every
  15 steps (`pulse_cells`), and beads run up the vein toward the core (`thread_cells`). Neighbouring
  veins start out of step. A vein redraws only when its step changes or its cut flash ends.
- Cut: the main shard snaps off along a jagged line, the side shards lose their tips, a crack runs
  down the stump, the crystal goes dead night-violet and the vein hangs short and slack
  (`slack_cells`). The white cut flash is drawn on the remaining cells.
- The hitbox, the pogo, the cut signal and the fight are unchanged. `LIGHT`, `CYAN`, `DEEP` and `DEAD`
  stay as constants for older callers, now on the palette.

## By eye, at 1x and 4x

`evercrown/veins` at two heights in the shaft. At 1x each vein reads as a small cluster of blue
crystal on a violet root, the brightest cool thing against the shaft's purple, and the beads on the
vein are visible as a faint climbing line. At 4x the facets, the outline and the glints are clean
whole pixels with no blended edge. The first test run caught two root hairs touching the image's
bottom row, so their outline was cut off; the image grew by two rows.

## Tests

`tests/test_light_vein_art.gd`, six tests: the tones are master palette; the baked image (lit and cut)
is opaque pixels on its own tones with an outline that closes every shape; the crystal uses at least
five tones, its left face is lighter than its right and its cap lighter than its root, the side shards
no lighter than the main one, on a node of flesh; the pulse's head climbs and the beads move every
step, in the crystal's tones, over the vein's full height; cut, no light is left, the main shard is
snapped off above the break and the vein hangs short; the step advances at about 10 frames a second.
The Everbloom vein tests in `test_boss.gd` still pass.

Mutations, each caught: a flat tone for every face, a frozen pulse, a cut crystal that keeps its
light, no outline, no snap.

Full suite: see the pull request.

Bible: 12.37 (the Everbloom's veins are crystal knots).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | The Everbloom's veins are on the pixel grain. The HD hero, the stray black bars in the shop and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged; the Veins' targets now read as crystal. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; a vein redraws ten times a second instead of every frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 546: the art loop stays **gated** on Sean (three guardian bases wait). The independent grade
taken after this pass sets the next art items; until then, the stray black bars in the shop and the
pass 540 grade's repeating tiles. The VFX-tool trials continue on the dash afterimage, then the enemy
death dissolve. Rim light on figures and the Boughs painterly clash stay parked for a watched session.
