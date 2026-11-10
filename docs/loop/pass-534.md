# Pass 534: the play tiles' fill is drawn in long, flat marks

## Category

A defect from the pass-529 independent grade, the next queue item an unattended pass could do:
"noisy high-frequency terrain fill (static-like dirt in the Haar and Heartwood, zig-zag strata in the
Sunken, busy cobble in the Evercrown). Flatten interior fill to two or three values with a strong lit
top edge." Environments and art cohesion.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first item (rim
light on figures and the rest of the lighting pass) stays parked for a watched session.

## Audit

A measure of the noise: the share of neighbouring pixel pairs in a zone's full interior tile (and its
scattered variants) that change colour.

| Zone | Painter | Before | After |
| --- | --- | --- | --- |
| Haar | `paint_limb` over `paint_wood` | 0.334 | 0.176 |
| Heartwood | `paint_wood` | 0.327 | 0.155 |
| Sunken | `paint_spring` | 0.257 | 0.127 |
| Evercrown | `paint_meteor` | 0.304 | 0.215 |

The sources: the wood mixed a fine sine grain, a 6-pixel patch grid and random flecks; the limestone
drew thin layers with a two-pixel wave, a pore scatter and stain flecks; the Evercrown drew small cells
with a bright blob at every centre. The caps (moss, the strong lit top edge the item asks for) were
already there and are unchanged.

## What was built (design bible 12.28)

- **Wood:** vertical strands 4 to 9 render pixels wide in two values with a dark seam between them,
  and a few long grain lines and highlights. Once the noise was gone, a per-tile strand layout cut a
  hard seam across every tile row of the Heartwood walls, so the layout is now shared by every tile
  (`WOOD_STRANDS`) and strands run on into the tile below. Knots are rarer (they repeat on the few
  interior tiles). The Haar's lichen patches are solid instead of speckled.
- **Limestone:** two layers per tile, flat bodies with a one-pixel lit top and shadow, a one-world-
  pixel wave, and the stain as long runs. The first try varied each layer's value per tile, which
  made a checkerboard across the aqueduct piers; the value now alternates by layer, so the strata run
  across the wall.
- **Grown cells:** the first try used broad per-tile cells, and a run of one-tile ledges in
  `drift_well` showed the same cut-off cells every 32 px. The cells now wrap over the tile (two
  across, two down) and share one layout (`MEAT_CELLS`): one flat body value, a lit rim along each
  cell's upper side, a seam one world pixel wide, and rare cyan pores.

Only the four atlases change. `tilegen.py` also rewrote six `*_mid.png` backdrops byte-differently
but pixel-identically; they were left as committed.

## By eye

`shots/terrain-fill/pass534-{haar,heartwood,sunken,evercrown}-2x.png` (top before, bottom after, at
2x). The Sunken piers read as banded travertine instead of static; the Heartwood walls as bark
strands; the Haar ground as calm bleached limb under its moss; the Evercrown ledges as one grown mass
of cells. Each was also checked at 1x in the full room shot.

## Tests

`tools/art/test_tilegen.py` (run with `python tools/art/test_tilegen.py`, 53 checks):

- `test_graded_play_fill_is_calm`: in the four zones, under 23% of neighbour pairs change and under
  1% of pixels stand alone.
- `test_wood_strands_run_on_from_tile_to_tile`: the bottom row of one wood tile matches the top row of
  a tile of another seed over at least 75% of its columns.
- `test_evercrown_cells_join_across_tile_edges`: Evercrown tiles of different seeds agree on at least
  95% of their pixels (only the pores differ).

Mutations: the old painters fail the first (Haar 0.334); keying the strands on the seed fails the
second (8 of 32); keying the cell centres on the seed fails the third (489 of 1024). The older wood
value-variation test (`test_paint_wood_has_surface_value_variation`) and the strata wrap test still
pass.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The four noisiest play fills are calm; the HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 535: the art loop stays **gated** on Sean (three guardian bases wait). Pass 535 is due an
independent grade (every fifth pass). Next in the queue: the Boughs style incoherence (soft vector
foliage against the hard pixel tiles), then further VFX-tool trials (the slash smear, the dash
afterimage, the enemy death dissolve).
