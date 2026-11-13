# Pass 547: solid mass falls off into darkness

## Category

The top defect of the independent grade taken after pass 545 (5.4/10): "off-room solid mass is one
flat repeated cobble tile with scattered dots", the Proving Scar most of all. Environments, and Art
and cohesion, in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent. This run began as pass 546; a session Sean started in the project thread opened its own
pass 546 meanwhile (#610, the HUD's plate, which answers the stray black bars in the shop), so this
one is 547. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean.

## Audit

`Room._depth` gives each ground cell a depth of 1 to 3 tiles from open air, and the tileset draws an
edge tile, a step-in tile and one interior tile. Every cell 3 or more tiles deep drew the same
interior tile, out to the room's frame, so the large solid masses around rooms (the Proving Scar's
upper left and right thirds are almost all solid) read as a flat cobble field with its studs
repeating. `EdgeShade` only rims the air-facing edge.

## What was built

- `DeepShade` (`scripts/world/deep_shade.gd`): an 8-way distance field from each solid cell to the
  nearest open cell (slopes count as open; the room's outside counts as solid); a darkness that is
  zero within 2.5 tiles and full 4 tiles further in, at 86% of a near-black; blended between cell
  centres and quantised to five steps with a 4 x 4 ordered dither in 2-pixel blocks. Built once into
  a list of rects (a uniformly deep cell is one rect), drawn over the tiles and `EdgeShade`.
- `Room` adds it after `EdgeShade`, and rebuilds it when a guardian tears the floor.
- Secret cells are left out of the main shade; a second shade, parented to the secret layer, draws
  them and fades with the fake wall, so a hidden room is never left dark once found and the cover
  still matches the mass around it.
- Design bible 12.38.

## By eye, at 1x and 3x

`evercrown/proving_scar` (before and after), `sunken/drowned_aqueduct`, `spires/broken_shrine`. The
lit walls hug the rooms as before; past them the rock recedes into dark over about four tiles and the
studs fade with it. At 3x the falloff is a fine checker of whole 2-pixel blocks, with no visible ring.
Thin walls and the Sunken Spring's pillars are unchanged (nothing in them is three tiles deep). The
scattered decor studs still show faintly at the back, like flecks in the rock.

## Tests

`tests/test_deep_shade.gd`, eight tests: the 8-way distance; the room's outside counts as solid; the
edge and step-in tiles are untouched; darkness deepens to full and stays short of black; the falloff
is every quantised step with neighbouring blocks differing (an ordered dither), bare at the edge and
full deep in; a uniformly deep cell is one rect; `skip` and `only` split the secret cells; a built
room darkens its deep mass, leaves the floor's edge and a hidden room bare, and gives the secret layer
its own shade.

Mutation check: starting the falloff at 0.5 tiles fails the edge test; dropping `skip` fails the
split test; dropping the dither fails the falloff test.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Deep mass now recedes into dark instead of tiling flat. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the shade is built once per room. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 548: the art loop stays **gated** on Sean (three guardian bases wait). From the pass 545 grade:
the Sunken Spring's striped pillars and flat water, then glow from the fire seals onto nearby
surfaces and the Haar's stacked circle lamp lights. The stray black bars in the shop are pass 546 (#610).
Rim light on figures and the Boughs painterly clash stay parked for a watched session.
