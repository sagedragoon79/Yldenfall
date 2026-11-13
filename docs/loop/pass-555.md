# Pass 555: calm frame tiles

## Category

Art cohesion, from the independent grade taken after pass 550 (5.3/10): "frame tiles repeat on a
loud grid (Tower and Vorrhallow checkered stone, Heartwood/Boughs striped dirt) and overpower the
playfield". The pass 540 grade said the same of the Tower and Vorrhallow brick. Pass 554's "Next"
named it.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for
a watched session, so the pass took the top open art defect instead. The PixelLab art loop stays
**gated** on him: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK,
the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.
README's playtest link already points at sagedragoon79/Yldenfall.

## Audit

- Shot `tower/foot` and `vorrhallow/gate_hall`. The floor and ceiling fields read as a
  checkerboard, loudest two and three tiles in.
- Measured the mean brightness of each 16 px block of the twelve interior tiles of each atlas. In
  both zones about half the blocks sat a whole ramp step (about 23 of 255) under the other half:
  `paint_plates` and `paint_drowned` each chose a block's value with a coin toss.
- Vorrhallow's teal tide line crossed every tile at the same height, edge tiles included, so it
  ruled dashes down every pillar.
- `paint_bough` (the High Boughs) drew a sine grain down every column and a dark line every 6 world
  pixels. The Heartwood's `paint_wood` has been calm since pass 534 and needed nothing.
- With the checker gone, the worn blocks that remained fell on a fixed beat: `TilesetFactory.ground`
  took `hash % 4` of a hash whose low bits follow the cell's own, so every fourth cell along a row
  drew the same tile.

## What was built

- **`tools/art/tilegen.py`**: plates and blocks share one body value and about one in seven is worn
  a step darker (`WORN_BLOCK`); the tide stain marks about a third of the interior tiles and no
  edge tile (`TIDE_TILES`, `INTERIOR_SEED`); `paint_bough` calls `paint_wood` two steps up the bark
  ramp (a new `lo` argument) and keeps its sprigs.
- **`TilesetFactory.scatter`**: a mixed hash of the cell for choosing a variant. Every zone's solid
  fields are rescattered; the tiles are the same.
- `assets/tiles/tower.png`, `vorrhallow.png` and `boughs.png` regenerated. The script also rewrote
  five `assets/bg/*_mid.png` files with no change in the painters behind them (they differ from
  run to run); those were put back.
- Design bible 12.45 (new).

## Judged by eye

Looked at `tower/foot`, `vorrhallow/gate_hall` and `boughs/thicket_road` at 1x before and after,
and at crops of the fields. The Tower floor reads as riveted plate with the odd dark plate, and the
Vorrhallow ceiling as coursed block with the odd worn block; neither pulls the eye from the room.
The Boughs wood reads as broad sunlit strands. Two retakes: the first version left the worn blocks
on a four-cell beat (hence `scatter`), and the tide stain still dashed down each pillar (hence no
edge tiles).

Not done: the interior tiers still step in whole tiles, which shows as square contours inside a
thick Boughs trunk; the Tower's plate bevel is still a 16 px grid by design (it is riveted iron).

## Tests

`tests/test_calm_frame_tiles.gd`, five tests: under a quarter of each zone's interior blocks are
worn, at least two are, and none stands brighter than the body; the tide stain is on at most half
the interior tiles and on no wall face; the bough fill changes colour between under 23% of
neighbouring pixels and under 6% down a column; cells one to eight apart along a row or down a
column match about as often as chance; each depth still draws its four tiles about equally.
`tools/art/test_tilegen.py` adds the Boughs to its calm-fill guard.

Mutation check: `WORN_BLOCK` back at 0.5 fails 17 checks; the tide stain on every tile fails 3;
the old `boughs.png` fails both bough checks; the old hash fails 26.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms, the empty mid-ground and the Proving Scar's framing remain. |
| Art cohesion | 15 | 98 | The frame tiles of three zones are quiet. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: SUITE_LINE

## Next

Pass 556: the art loop stays **gated** on Sean. From the independent grade taken after this pass,
its top defect that needs no watched session. Otherwise, still open from the pass 550 grade: the
Proving Scar's framing. From the pass 545 grade: the uniform rain over the Spires. The item icons
on the Equipment and Inventory pages are a follow-on to pass 554.
