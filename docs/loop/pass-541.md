# Pass 541: sky islands are lit pixel props

## Category

A defect from the pass 540 independent grade (workbench queue): "flat single-fill props", first among
them "the Spires' floating magenta triangle islands with one green line". Art cohesion, and
Environments in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do. No PixelLab generations were spent.

## Audit

The magenta islands are not room props: they are the sky islands of the Spires' middle parallax
layer (`spires_mid` in `tools/art/tilegen.py`, `assets/bg/spires_mid.png`), seen behind the play field
in every Spires room. `island()` drew each as a cone in two tones (crystal-2 and night-1) with a
diagonal hatch every seventh pixel, under a one-tone strip of leaf-2. It painted at atlas pixels, half
a world pixel, so the hatch was finer than the game's pixel grain. Every island was the same
symmetric triangle at a different size, and the ruined towers on two of them were two flat fills.

## What was built

- `island()` paints in whole world pixels (`block`, a D x D fill), like the rest of the game.
- `island_cells` builds the silhouette a column at a time: a rounded belly of earth under the lip,
  a main spur leaning off centre, and two to four lesser spurs beside it, from the island's own seed.
- The rock is a cluster of chunky stones (a jittered Voronoi, flattened into slabs) on a four-tone
  ramp lit from the upper left (`ISLAND_ROCK`: crystal-3, crystal-2, crystal-1, night-1). Each stone
  is lit on its upper-left face, seams between stones are one step darker, and the right flank and
  spurs fall into shadow. A rim of crystal-3 runs down the lit flank.
- A night-0 selective outline closes the shadow side and the underside only.
- The grass lip is three leaf tones, a world pixel wider than the rock, with standing blades, tufts
  hanging over both ends, moss strands down the rock's top, and roots dangling from the belly.
- `ruined_spire` redraws the towers on the same grain and ramp, with mortar courses, a broken crown
  and a warm window.
- The layer's random draws are kept, so every island stays where it was.

## By eye, at 1x and 4x

The layer alone at 4x, then `spires/sky_steps` and `spires/fallen_bridge` in the game. The first take
kept a single cone and laid horizontal strata seams every few rows: it still read as a triangle, now
hatched with dashes. The second built the column silhouette with spurs and a stone cluster, but its
seams were night-0 and read as a cobbled wall. The third softened the seams to one step and stretched
the stones into slabs: the islands now read as faceted rock lit from the upper left, hanging in
spurs, with grass and roots, and the room's fog still holds them behind the play field. Platforms,
foes and pickups stand out from them as before.

## Tests

`tools/art/test_tilegen.py` (the art guard; CI runs only the Godot suite), five new checks: the
island uses every rock tone, the outline and every grass tone; every pixel sits on the world-pixel
grain; the left flank is brighter than the right and the top brighter than the spurs; the outline
closes the shadow side but not the lit flank; two seeds draw different islands and each hangs in at
least two points. 59 checks pass.

Mutations, each caught: one rock tone (fails the ramp and light checks), light from the right and no
depth term (light check), an outline all round (outline check), no lesser spurs (stamp check, after
its tip test learned to tell a spur from a bump of noise on the sloping belly), half-pixel blocks
(grain and palette checks).

Bible: 12.33 (sky islands are lit pixel props).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | The Spires' islands are lit pixel props. The Evercrown's magenta platforms and diamonds, the smelter cauldron, the Haar's orange blocks, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; a baked image. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 542: the art loop stays **gated** on Sean (three guardian bases wait). Next, the rest of the pass
540 grade's flat single-fill props (the Evercrown's magenta platforms and cyan diamonds, the smelter
cauldron, the Haar's orange blocks), then its stray black bars in the shop and the one-template rooms.
The VFX-tool trials continue on the dash afterimage, then the enemy death dissolve. Rim light on
figures and the Boughs painterly clash stay parked for a watched session. The next independent grade
is due at pass 545.
