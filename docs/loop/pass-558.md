# Pass 558: the crystal halls get a deep backdrop and keep red for what hurts

## Category

Art cohesion, the next item of the pass 555 grade (4.2/10): "Vorrhallow and the Evercrown are
nearly monochrome with low value contrast; crystal shards, tendrils and backdrop columns blur
together and hazards do not separate from decor."

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session; its second and third (the Haar Wyrm fight frame, the Haar's fog on the drowned stair) still
wait for the hydra and steam branches. The PixelLab art loop stays **gated** on Sean: three guardian
bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel
Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already
points at `sagedragoon79/Yldenfall`.

## Audit

- Shot `vorrhallow/flooded_hall`, `drowned_nave`, `kings_kennels` and `evercrown/veins`, `heart`,
  `threshold`, and measured regions of two of them. Backdrop median luminance 40 and 39 of 255;
  play tiles 43 to 53; every region's hue between 255 and 280 degrees. The grade was right: one
  purple at one value.
- Both halls shared one haze (crystal violet) and one ridge colour (crystal-1). The ridge fills the
  lower half of the backdrop with a single flat value, the same as the tiles' shadows.
- The Evercrown used the ember ramp in its tile seams, the shelf's sinew and hangers, polyps, wall
  eyes, tendril beads and the far wall's glow, beside red thorn bulbs and fire seals that hurt.
- The Evercrown's floor decor drew bright splinters up to 20 px tall, the shape of a row of spikes.
- The far wall's glow was random 4 px blocks: a band of checker noise behind the floor.

## What was built

- **`scripts/world/backdrop.gd`**: `ZONE_HAZE` for Vorrhallow is a drowned blue (22, 36, 56) and for
  the Evercrown a wine (44, 20, 46), after the two halls' colours on the map.
- **`tools/art/tilegen.py`**: `RIDGE_COLOR` is sky-0/sky-1 for Vorrhallow and crystal-0/crystal-1
  for the Evercrown. `paint_meteor`'s seams and the grown shelf's sinew are crystal-1; a mid
  tendril's bead is sky-3; the far wall's glow is crystal-2 in an ordered dither (`BAYER4`,
  `CORE_GLOW`).
- **`tools/art/decorgen.py`**: polyps and the wall eye lose their ember; a hanging tendril ends in a
  cyan bead; `evercrown_shards` draws stubs of at most `EVERCROWN_STUB` (8) world pixels.
- **`scripts/world/plank_supports.gd`**: the Evercrown's hangers' dark strand is crystal-1.
- Regenerated: `assets/tiles/evercrown.png`, `assets/bg/evercrown_far.png`, `evercrown_mid.png`,
  `evercrown_ridge.png`, `vorrhallow_ridge.png`, `assets/decor/evercrown.png` and `.json`. The
  tile script again rewrote five `assets/bg/*_mid.png` files that differ from run to run; those
  were put back.
- Design bible 12.48 (new); 12.34 and the Evercrown's zone entry say wine where they said red.

## Judged by eye

At 1x in the six rooms, before and after. Vorrhallow's columns and ridge are blue slate and the
lavender floor, ceiling and pillars stand off them at a glance; the magenta stillglass is now the
only magenta in the frame, so it reads as the zone's accent and not as more purple. In the Evercrown
the backdrop is a dark wine, and the shelves, tendrils, light veins and the lit rims of the cells
carry the frame; the fire seal in `proving_scar` is the only red on screen. Backdrop median
luminance after: 30 in `flooded_hall` (hue 230) and 20 in `veins`, with tiles unchanged.

A first take changed only the haze: the columns moved, but the ridge kept the lower half purple.
The first recolour of the core glow (crystal-2 in the old blocks) made the checker band louder,
hence the dither.

Not done: Vorrhallow's spikes stand in flooded pits and the water's tint dims their rim. The
Evercrown's tiles are still violet on a wine backdrop, a smaller hue step than Vorrhallow's.
`tools/art/decorgen.py` seeds each zone by its name, so the zones renamed in pass 462 no longer
regenerate to their committed atlases: only the Evercrown's atlas was regenerated, and all its
cells were redrawn from the new seed. Queued.

## Tests

`tests/test_backdrop.gd`: `test_the_crystal_halls_recede_deep_each_in_its_own_hue` (7 checks).
`tools/art/test_tilegen.py` (run by hand, 68 guards pass): no ember in the Evercrown's tiles,
backdrops or decor; the stubs' height and brightness; both ridges' colours; the glow thickens
downward with no lit run over two world pixels. The shelf's older guard now tells sinew from glaze.

Mutation check: with the old scripts and art put back, the Godot test fails all 7 checks and each
of the four new Python guards fails.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | The crystal halls have a value step and a hue step between backdrop and play layer. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,162 checks passed and 5 failed in the whole run, all five wall-clock
budgets in four tests (two journeys' frame spikes, a room's load time and settled frame time, a
room's frame time while spoils rest), while other work loaded this PC (54% processor load). Rerun
alone, the four tests pass (136, 3 and 3 checks; the room budget test failed once more on three
Tower rooms this pass does not touch, then passed three times running). The pass changes colours
only. With the reruns: 15,167 passed, 0 failed.

## Next

Art cohesion again, by the pass 555 grade: foes from different style families (an art-loop item,
code-first on outline weight and shading). The Haar items wait until the hydra and steam branches
merge. Pass 560 is due an independent grade.
