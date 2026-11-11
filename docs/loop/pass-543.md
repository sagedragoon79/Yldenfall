# Pass 543: the Smelter's crucible is a pixel prop

## Category

A defect from the pass 540 independent grade (workbench queue): "flat single-fill props", "the
smelter's clean vector lava cauldron", next after the Spires' sky islands (pass 541) and the
Evercrown's shelves (pass 542). Art cohesion, and Environments in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, and the third
(one-template rooms) is a level-design rework, so this was the first art item an unattended pass could
finish. No PixelLab generations were spent.

The hosted workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for
Sean.

## Audit

The cauldron is `Crucible` (`scripts/world/crucible.gd`), the set piece in `tower/smelter`. It drew
itself every frame from smooth polygons: a two-tone iron bowl (one fill, four light dots for rivets,
one dark polyline for a hoop), a flat orange ellipse for the metal with five yellow ovals on it, chain
links as half-pixel rects, and a stream and channel in sub-pixel rects. Nothing sat on the world-pixel
grain the rest of the game is painted on, and the bowl had no light direction.

## What was built

- `build_image` bakes the static half once, in whole world pixels on master palette ramps:
  - The bowl, shaded as half an ellipsoid lit from the upper left on four iron tones (stone-1 to
    stone-4) with a stone-5 glint, and a narrow 2 x 2 ordered dither where tones meet.
  - Two hoops (a dark band with a lit upper edge) with rivets.
  - The metal's glow caught in bark-2 and bark-3 along the silhouette that faces the trough.
  - The lip: its far side lit, its near side in shade.
  - A night-0 selective outline on the shadow side and underside, none on the lit upper-left edge.
  - Lugs where the chains hold the rim, and chains of face-on and edge-on links lit on the left.
  - The trough: two courses of dressed ash stone, a lit top with a few chips, round a crusted channel.
- Live, on the same grain, stepped at 10 frames a second:
  - `molten_tone`: the surface on the heat ramp, cooler at the iron's edge, under an irregular skin
    of crust that rolls, with rare white-hot glints.
  - `stream_cells`: a wavering column poured over the rim, five pixels wide narrowing to three, with
    a white-hot core.
  - `channel_tone`: the channel glows hottest where the stream lands.
- The lip moved to the rim's low end, so the stream leaves the iron instead of the air above it.
- The glow layer, the sparks and the test hooks (`sparks`, `lip()`) are unchanged.

## By eye, at 1x and 3x

`tower/smelter`, before and after. The first take put a thick bark crescent along the whole lower
edge (it read as a copper band), dithered every tone boundary so the bowl looked like mesh, hid the
hoops, and spotted the metal with a regular grid of crust dots. The second thinned the glow to the
outermost pixels facing the trough, halved the dither, darkened the hoops, and broke the crust with a
second wave. The third darkened the bowl a step so mid tones lead, and thinned the metal's cool rim.
The last fix came from the test: the lit edge still carried an outline, because the silhouette there
is the third iron tone, not the fourth. At 1x the crucible now reads as a riveted iron pot in the
room's pixel grain, and the metal and the pour are still the brightest things in the room.

## Tests

`tests/test_crucible.gd`, five tests: the tones are master palette; the bake holds only the
crucible's own tones, fully opaque; the bowl uses all four iron tones, is brighter on its upper left,
and catches the glow low on the trough's side; the outline closes the shadow side and mostly not the
lit side; the metal rolls in heat-ramp steps, carries a skin of crust, pours unbroken from the lip to
the trough, and the channel is hottest where it lands. `test_the_smelter_crucible_pours` still passes.

Mutations, each caught: blended iron tones (bake and outline tests), the light from the lower right
(light and outline tests), an outline all round (outline test), a frozen surface and a stream that
stops short (metal test), no glow on the edge (light test).

Full suite: 13,427 checks passed. The first run failed 44 checks in five bible-reading tests because
the edit script had written the bible back with Windows line endings in the working copy (the commit
was LF); with the working copy back to LF those five pass. Edit files from Python in binary mode.

Bible: 12.35 (the Smelter's crucible is a pixel prop).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | The Smelter's crucible is on the pixel grain. The Haar's orange blocks, the flat cyan diamonds in the Evercrown veins, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the static half is baked once instead of redrawn every frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 544: the art loop stays **gated** on Sean (three guardian bases wait). Next, the last of the
pass 540 grade's flat props (the Haar's orange glyph blocks) and the pass 535 grade's flat cyan
diamonds in the Evercrown veins, then the stray black bars in the shop and the one-template rooms.
The VFX-tool trials continue on the dash afterimage, then the enemy death dissolve. Rim light on
figures and the Boughs painterly clash stay parked for a watched session. The next independent grade
is due at pass 545.
