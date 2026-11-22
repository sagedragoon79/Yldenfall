# Pass 639: the still water mirrors the hall, and its glass grows through the stone

## Category

Art cohesion and environments. The top item of the queue, from the pass 635 grade: "the
flooded hall's purple shards float with no anchoring and its water has no reflection".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

- **The water.** Vorrhallow's tide (4.4) is a dithered teal band, lighter under its breathing
  surface line, with ripples and a waterline where something wades (pass 550). Nothing above
  it shows in it: the hero's legs, the pillars and the Crystal Dwarf's glow stop at the line.
- **The glass.** Three passes have anchored it (12.51 seats, 12.82 light on the stone, 12.100
  habits). What still reads as floating, looked at layer by layer: the far glass is drawn in
  crystal-5/3/2 on pillars that stop at stone-1, so it stands a value step in front of its own
  pillar; and each near growth meets its column at one dark crust, with the stone a hand's
  width off untouched. The bright shards the grader saw at 1x are the near ones.

## What was built

Design bible 12.115, in `scripts/world/tide.gd` and `tools/art/tilegen.py`.

- **A mirror in the still water.** `Tide` lays a `ColorRect` over each run of the surface row,
  from 2 px under the line to the row's floor. Its shader reads the screen behind it and
  samples, for the row `k` px under the line, the row `k + 1` px above it. Mixed 0.22 toward the
  water's teal, at alpha 0.5 just under the line and fading to nothing at the floor; past 4 px
  down a row sways by up to one whole pixel on the tide's clock. The line, glints, ripples and
  waterline stay on top. Gone once the hall drains.
- **The far glass sits as deep as its pillars.** `FAR_STILLGLASS` (crystal-4/2/1), each tone
  darker than the near ramp's, and a faint glow on its own stone only (the sky between the far
  pillars keeps its gradient). No chips on the far layer, so its rng and layout are unchanged.
- **The near glass grows through its stone.** `stillglass_veins`: three lit seams of glass
  (crystal-3, crystal-1 edge) from each root back into its column, up and down the courses for
  18 to 36 px, drawn under the glass and crust, seeded by the seat.

Thrown out on the way:

- **Seams drawn last.** Over the crust they were clear, but they crossed the shards' faces and
  read as cracks in the glass. Drawn under the glass instead; they still reach past the crust.
- **Seams of 10 to 26 px.** Mostly buried under the crust at 1x. Lengthened to 18 to 36.
- **Chips on the far glass.** They drew on the layer's rng and moved every far growth after the
  first. Left out of the far layer.
- **The mirror at 0.42 alpha, 0.3 tint.** The pillars' reflection barely showed. 0.5 and 0.22.

## Checked by eye

At 1x and 3x in the flooded hall: the hero wading (his legs and cloak mirrored, swaying under
4 px), a Crystal Dwarf wading (its body and its pink glow mirrored), the far and near glass
before and after side by side.

## Tests

`test_the_still_water_mirrors_what_stands_over_it` (`tests/test_tide_wake.gd`): one mirror per
surface run, spanning it exactly, under the line to the row's floor, covering the whole surface
row; it reads the screen and is mirrored about the line; clear above 2 px, strongest there,
only fading, gone at the floor; it runs on the tide's clock; none once drained.
`test_vorrhallows_far_glass_sits_as_deep_as_its_pillars` and
`test_vorrhallows_near_glass_grows_through_its_stone` (`tools/art/test_tilegen.py`).

`tools/art/test_tilegen.py` ran no test defined after its `if __name__ == "__main__"` block
(it sat in the middle of the file, so passes 637 and 638's guards never ran from the command
line). It is at the end now (the far-glow guard first counted night-1 in open air and failed
on the far layer's own arches; it now compares the layer painted with and without its glow), and the module imports `math` and `random as _r`, which one
island test used without importing.

| Mutation | Result |
| --- | --- |
| the tide lays no mirror | fails (3 checks) |
| the mirror does not fade with depth | fails (2 checks) |
| a mirror one tile wider than its run | fails (3 checks) |
| the drained hall keeps its mirror | fails (1 check) |
| the far glass in the near ramp | fails (far crystal-6 as bright as near) |
| the far glow on any colour (sky included) | fails (736 px of open air) |
| no seams | fails (a growth with no seam past its crust) |

Full suite: 35,741 checks, 35,740 passed (pass 638: 35,716). The one failure was
`test_every_foes_spoils_rest_in_its_room`'s frame budget in `spires/sky_steps` (8.37 ms), a room
this pass does not touch; the same test fails on main on this PC in another room
(`heartwood/hornet_gallery` 8.17 ms), and on this branch it passed twice when run again. The suite
needs `TEST_TIMEOUT=7200` here: at the runner's default 2,700 s it is cut off before its summary.
The four bible-table checks that failed on the first run were this pass's own doing (its Python
edits wrote the bible in CRLF) and pass with LF restored.

## Not done

- The deep swim water (the Sunken Spring, the aqueduct) has no mirror yet.
- The aqueduct's flat water and its waterfall; light that rarely shapes surfaces.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The tide mirrors the hall and the glass grows through its stone; the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One screen read per surface run in two halls. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The aqueduct's water and its waterfall (and a mirror for the deep swim water). An independent
grade is due after pass 640. The Haar's fog and dither, the sprites' pixel size, the hero's rim
light and the sword's look stay held.
