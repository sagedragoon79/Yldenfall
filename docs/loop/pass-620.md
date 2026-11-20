# Pass 620: the water meets the stone

## Category

Art cohesion (environments, the Sunken Spring and Vorrhallow). The top unheld item of the
queue, from the pass 615 grade (5.6 of 10): "the water is a slab of banded dither with a hard
top line, no reflections and no interaction with the stone (aqueduct, flooded hall)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at `sunken/drowned_aqueduct` and `vorrhallow/flooded_hall` at 1x and 3x:

- **The waterline is ruled.** `SwimWater` drew it as 4 x 2 blocks at one alpha (0.75), each a
  pixel up or down, with a second flat line three pixels under it.
- **The piers are dry.** The front tint covers water cells only, so a pier under the water was
  the same stone as over it, with a hard edge against the teal: stone laid over water.
- **Nothing happens where they meet.** No foam, no damp line. The tide answers a wading body
  (12.41) but not its own walls.
- **The bands.** Five tones over 144 px, 0.155 of alpha apart, so each dithered band between
  two tones was a visible stripe of dots.

## What was built

- **`WaterEdge`** (`scripts/world/water_edge.gd`, new), shared by both waters: `banks` (where a
  surface ends against a square face of stone), `lap` (the foam's pixels at a bank: up the
  face one or two pixels, along the surface, and a fleck that drifts off), `draw_damp` (wet
  stone over the waterline) and `sunk` (the stone's bands that touch a water cell).
- **The deep water's surface** (`SwimWater.crest_lift`, `crest_alpha`, `glint`, `SHEEN`): a
  one-pixel crest on two crossing swells, thinning and thickening, a sheen in three steps under
  it, and glints. Under stone within `ROOF_REACH` (3 tiles) it is dim and has no glint.
- **Sunk stone**: every face of square stone that touches water is darkened toward teal, 12 px
  in, in four steps. Drawn once on a `Stone` layer in the deep water, and with the water in
  the tide (so it goes when Vorrhallow drains).
- **Eight tones** in the deep water's body (`LEVELS`, was 5).
- `Room._square_stone` gives both waters the room's solid cells without its slopes.
- Bible 12.97 (new), 12.39's line on `LEVELS`, and the swim table's line on feel.

A first try gave the sunk band 6 px in three steps of near-black. At 3x it could not be told
from the tile's own dark outline. It is now 12 px in four steps of teal, and a pier reads as
standing in the water.

Looked at beside the pictures from before: the aqueduct's waterline rolls and breaks into
glints, its piers go teal at their faces and underneath, and foam sits at each pier's
waterline. In the Flooded Hall the change is small: foam and a dark face on the stair's east
side, and a dark edge on the floor under the water.

Not done: a mirror image of the room on the surface (a side view shows the water in section;
the shade under a roof is what stands in for it). The Flooded Hall's stair meets the water on
a slope on its west side and gets no foam there. Bodies in deep water take no waterline.

## Tests

`tests/test_water_edge.gd`, six new: `test_water_surface_is_a_swell_not_a_ruled_line`,
`test_water_body_steps_are_close_in_tone`, `test_water_surface_is_dim_under_a_roof`,
`test_water_laps_the_stone_at_its_surface`, `test_stone_that_stands_in_water_takes_it`,
`test_standing_water_meets_the_stone_too`. The older water and tide tests pass unchanged.

Mutation check: with `crest_lift` returning 0, the first fails (one height); with `LEVELS` at
5, the second fails (0.155 a step); with `ROOF_REACH` at 0, the third fails; with slopes
counted as stone, the fourth fails (two banks at a slope); with the band's steps reversed, the
fifth fails; with the tide given no stone, the sixth fails (no banks). Restored, all pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Water meets its stone; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (after pass 620). Then the pass 615 grade's remaining items:
the hit's missing flash in the fight captures, and the Spires' ridge as more than one value;
and whatever the new grade names. The Haar's fog and dither, the sprites' pixel size, the
hero's rim light and the sword's look stay held.
