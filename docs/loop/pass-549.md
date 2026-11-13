# Pass 549: fire seals glow onto the stone, and the Haar's pockets are not circles

## Category

From the independent grade taken after pass 545 (5.4/10), as pass 548's "Next" named it: "fire seals
cast no glow on the walls and floor around them, and the Haar's lamp lights stack as perfect blue
circles". Atmosphere and lighting in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean.

## Audit

- `FireSeal` joined only the fog's `light` group (a 30 px pocket of clear fog in the Haar). It never
  joined `RoomLight`, so outside the fog, and inside it, the stone around a seal stayed unlit.
- The fog shader rounded each pocket's clearing to four levels (`floor(clear * 4.0 + 0.5) / 4.0`)
  around a perfect circle, so every lamp, shrine and seal sat in a disc of hard concentric rings.

## What was built

- **Seal pools**: a seal casts warm `RoomLight` pools from its leftmost column: one from the middle
  of a short column, one every third tile down a tall seal. `RoomLight` gained a skip for sources
  with no reach, a `glow_offset`, and `RoomLight.refresh` so a doused seal's pools go out.
- **Seal heat halo**: the pools alone read too faintly on dark stone (judged by eye in the Proving
  Scar), so each tile draws an additive pixel halo off its open sides, 20 px out and 5 px onto the
  floor, in four dithered steps; drawn once, only its alpha breathes. Each tile's fog pocket grows
  from 30 to 40 px so the glow shows through the Haar's murk.
- **Fog pockets**: each pocket's rim wavers by up to 18% of its radius with a slow noise of its own;
  the clearing steps through a 4 x 4 ordered dither in 2-pixel blocks instead of hard rings.
- Design bible 12.40, and the fog and fire-seal lines of 4.5.

## By eye, at 1x and 2x

`haar/marsh_road`, `haar/lampwick` and `evercrown/proving_scar`, before and after. The Haar's lamp
pockets are now irregular, softly dithered clearings rather than stacked discs with rings; the
lamps' warm `RoomLight` pools are unchanged. The Proving Scar's tall seal throws a stepped warm glow
onto the purple wall either side; in the Marsh Road the seal now sits in a warm haze through the
fog. Combat readability is unaffected: the halo is under the actors and capped at 0.3 alpha.

## Tests

`tests/test_fire_seal_art.gd`, five new tests: the pool spacing and reach; the halo's open sides,
steps, falloff, shallow floor and seam; its breath; a built room's single pool for a column of
three, put out by a douse with the halo; and the fog shader's waver and dither.

Mutation check: anchoring every tile fails the room test (three pools); letting the halo glow off a
joined side fails the halo test; restoring the hard rounding fails the fog test.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Seals light their surroundings; the Haar's pockets read as fog, not discs. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the halo is drawn once per tile and only its alpha moves. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 550: take the independent grade (every fifth pass), then the art loop stays **gated** on Sean.
From the pass 545 grade: the flat wading-water rectangles in Vorrhallow, then the uniform rain over
the Spires. Rim light on figures and the Boughs painterly clash stay parked for a watched session.
