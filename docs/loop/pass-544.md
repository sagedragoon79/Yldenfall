# Pass 544: fire seals are one sheet of pixel fire

## Category

A defect from the pass 540 independent grade (workbench queue): "flat single-fill props", "the
Haar's orange blocks", the last of that list after the Spires' sky islands (pass 541), the
Evercrown's shelves (pass 542) and the Smelter's crucible (pass 543). Art cohesion, and Environments
in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, and the third
(one-template rooms) is a level-design rework, so this was the first art item an unattended pass could
finish. No PixelLab generations were spent.

The hosted workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for
Sean.

## Audit

The orange blocks are the fire seals (`FireSeal`, `scripts/world/fire_seal.gd`, legend `Z`): the
column of four in `haar/marsh_road` that the grade saw, and the two-wide wall of seven rows in
`evercrown/proving_scar`. Every tile drew the same four rectangle tongues (red, orange, cream, in
half-pixels) and the same rune, so a column read as a stack of identical lit crates with a hard seam
at every tile edge. Each tile also left its own strip of ash when doused, so a doused column was a
ladder of ash lines in mid-air.

## What was built

- `cells(origin, step, joined, out)` paints a tile's part of one sheet of fire in whole world
  pixels on the heat ramp (red-1 to red-4, gold-4, gold-5, gold-7):
  - The field is two octaves of value noise, sampled once into a 50 x 100 table that tiles
    (`field`), read in world coordinates and scrolling up a pixel and a half a frame, so tiles join
    without a seam and no two tiles are one stamp.
  - Fire runs hotter the deeper it is from an open side. Each open side is ragged on its own (one
    noise value per row and side) with a dark red fringe; a side joined to another seal is filled.
  - Only a column's top licks above its tile (up to 5 pixels, each lick its own height every
    frame), and only its foot stands on a bed of coals.
  - Every other tile down a seal's left edge carries one dark rune (red-0) from a set of three,
    ringed with gold that pulses.
  - Doused, the fire sinks while steam rises; once out, only the column's foot keeps a socket of ash.
- `joined()` finds the seals beside a tile on its first draw. The flames step at 10 frames a
  second and redraw only when the step changes; each row is drawn as runs of one colour.
- The collision, the burn, the light radius and the douse are unchanged.

## By eye, at 1x and 3x

`haar/marsh_road` and `evercrown/proving_scar`, before and after. The first take kept a rune on
every tile with a three-by-three white halo: the halos stacked into four white blocks, the same
repeat the grade complained of. The second ringed each rune in a one-pixel gold ring and let only
every other tile carry one, so the Proving Scar wall shows four runes, not fourteen. That take also
showed pale specks along both edges: the steam branch ran on every rune-less tile while burning (the
test now guards it). The third raised the edge's rag and lowered the base heat so the sides break up
and licks of cooler fire run through the core. Both seals now read at 1x as a curtain of fire under
their arches; they are still the brightest things in their rooms.

## The frame budget

The first full suite failed two checks: `evercrown/proving_scar` (fourteen seal tiles) settled at
9.6 ms a frame against the 8 ms budget, because every tile computed three noise samples per pixel ten
times a second. The noise is now read from the table, the rag is computed once per row and side, the
tongue heights once per column, the heat steps are a constant, and the draw walks the rows instead of
sorting a dictionary. The room settles at 4.2 ms (`haar/marsh_road` 1.5 ms). A last look showed the
lone Marsh Road column too thin after the rag change, so the rag came down to three pixels and the
fire's body widened.

## Tests

`tests/test_fire_seal_art.gd`, seven tests: the tones are master palette; every frame is opaque,
on the seal's own tones and inside the tile's width; a column is one sheet (no thin row at a seam,
neighbouring tiles not one stamp, tongues only at the top, coals only at the foot); the core is
hotter than the edges, an open side is ragged and a joined side filled; the fire moves (frames
differ, cells inside a wall of seals jump two tones within four frames) with licks of several tones
through the core; a few runes, each closed in its gold ring; steam only while dying, and ash only at
the foot. The douse tests in `test_world.gd` and `test_reachability.gd` still pass.

Mutations, each caught: sampling in tile coordinates (a stamp), steam while burning, no rag, a
joined left or right side treated as open, tongues on every tile, a rune on every tile, a frozen
field, a flat heat with no licks, blended colours.

Full suite: 13,509 checks passed (the second run, after the frame-budget fix).

Bible: 12.36 (fire seals are one sheet of pixel fire).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | The fire seals are on the pixel grain, the last of the pass 540 grade's flat props. The flat cyan diamonds in the Evercrown veins, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; a seal redraws ten times a second instead of every frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 545: the art loop stays **gated** on Sean (three guardian bases wait). The independent grade is
due at pass 545. Then the pass 535 grade's flat cyan diamonds in the Evercrown veins, the stray black
bars in the shop and the one-template rooms. The VFX-tool trials continue on the dash afterimage, then
the enemy death dissolve. Rim light on figures and the Boughs painterly clash stay parked for a
watched session.
