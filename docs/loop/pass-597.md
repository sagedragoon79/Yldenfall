# Pass 597: a floating stone hangs on its keel

## Category

Art cohesion and world, from the independent grade taken after pass 595 (5.3 of 10): "floating
brick blocks in the Spires hit frame and unanchored crystals in the flooded hall". It was pass 596's
"Next", the first defect in the queue not held for a watched session or parked with the Haar's fog.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for a
watched session. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- **The bridge stones.** `spires/fallen_bridge` has four floating masses of masonry (its sign: "Its
  stones still float, a stride apart"). The play layer drew each as a brick block with a dark edge
  and nothing under it. The sky islands in the Spires backdrop read as floating land, because each
  hangs on a ragged keel of rock. The Roost's slabs float the same way.
- **The crystals.** The flooded hall's mid-layer stillglass has been seated on pillar faces since
  pass 563 (bible 12.51), and the guard test holds. At 3x the growths do sit on the pillars, but the
  pillar behind each stays one dark value right up to bright crystal-6 shards, so at 1x the glass
  reads as pasted on in front of the stone, not grown out of it.

## What was built

- **`StoneKeel`** (bible 12.82): every mass of solid cells in a Spires room that touches no edge of
  the room hangs on a keel: chunky stones in the islands' own ramp, lit from the upper left,
  outlined on the shadow side and underside, a main spur and two or three lesser ones, and a loose
  pebble or two under the deepest tips, bobbing a pixel. It stays in open air and stops 2 px above
  what is below it. Drawn behind the tiles; no collision.
- **Stillglass lights its stone** (tilegen `stillglass_growth`, `glow`): each mid-layer growth throws an
  ordered-dither pool of crystal-1, with crystal-2 close to the root, onto its own pillar (never the
  mortar, never open air), and chips of stone burst off the face past either end of the roots.

Judged by eye at 1x and 3x. The first keel lit its stones' upper-left faces with the rim tone
(crystal-3), which read as candy magenta beside the grey masonry. The rim tone is now kept to the lit
flank, and the faces step from crystal-2. The first glow used hash noise, which read as static on
the pillar; it is now an ordered dither. The first chips sat under the shard fan and could not be seen;
they now sit past the roots' ends. Every Spires room was screenshotted: only the Fallen Bridge and the
Roost have floating masses, and both now hang on keels.

Regenerating the tilesets also re-encoded five other zones' mid layers byte for byte differently but
pixel for pixel the same; those were put back, so only `vorrhallow_mid.png` changes.

## Tests

`tests/test_stone_keel.gd` (new): the tones are palette values; only a floating mass gets a keel (a
wall ledge and a ceiling-hung mass over a pit get none); the keel is outlined, shaded in at least four
tones, between `DEPTH_MIN` and `DEPTH_MAX` deep, with pebbles; it stops `CLEAR` px above a plank;
only Spires rooms take keels; in every Spires room no keel pixel or pebble enters a solid or plank
cell; the Fallen Bridge hangs all four stones.

`tools/art/test_tilegen.py`: every mid-layer growth lights at least 30 px of its stone, the growths
light at least 50 px each in all, stone far from any growth stays unlit, and at least two in three
growths throw chips.

Mutation check, each restored from a copy after: no `CLEAR` limit fails it (37 checks); no anchored
test fails it (4 checks; the first version of the test missed this, because a closed room's floor
shares every column with a ceiling-hung mass, so a pit was added under it); an off-palette outline
fails it (1 check); no glow fails the tilegen test.

Full suite: 21,839 checks passed and 44 failed, all in five tests that read the bible: Python had
written the bible back with Windows line endings. With the line endings put back, those five pass
(342 checks), and so do the keel tests (240 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Floating stones hang on keels. |
| Art cohesion | 15 | 98 | Stillglass lights its stone; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 595 grade's item: the flat midground and parallax layers with empty stretches (plaza,
gear pit, flooded hall), with the plaza's flat grey city; then the slash and spark covering the struck
foe. Pass 600 takes an independent grade (every fifth pass). The Haar's fog and the sword's look stay
held.
