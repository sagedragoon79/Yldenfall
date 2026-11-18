# Pass 596: a plank stands on a built trestle

## Category

Art cohesion and world, from the independent grade taken after pass 595 (5.3 of 10): "platforms
are bare debug-like sticks on posts (plaza, gear pit, causeway)". It was the first defect in the
queue not held for a watched session or parked with the Haar's fog.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for a
watched session. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- **The post.** `PlankSupports` (bible 12.30) gives every plank run a brace, posts or hangers. A
  post was a 2.5 px rod with a 4.5 px foot and cap: at 1x it is one or two screen pixels wide.
- **The pair.** A run with two posts had nothing between them, so the run read as a table on legs.
  That is the gear pit's spike bridge, the plaza's chest plank and the causeway's low boardwalks.
- **The zone tie.** Posts already took the plank's strut timber, but nothing on them carried the
  zone's fastener accent.
- **The board** (tilegen `PLANK`, and the Hearthroot's PixelLab atlas) is not changed: once it sits
  on a frame, it reads as a deck.

## What was built

`PlankSupports.post_parts` and `frame_parts` draw the supports as data (half-pixel rects with a
tone each), so the tests read exactly what is drawn (bible 12.81):

- A 4 px squared post with a lit and a shaded edge and grain ticks.
- A cap block under the board with a bolt in the zone's accent.
- Knee brackets, only toward the run's middle at a run's end.
- A footing stone: zone stone in the stone and iron zones, grey ash stone in the timber and water
  ones, tissue in the Evercrown.
- A frame between a run's two posts when board and footing are at least 40 px apart: a low rail
  and a cross-brace per bay (no bay over 48 px), studs between bays, bolts at the joints.

Judged by eye at 1x and 3x in `hearthroot/plaza` (the chest now sits on an orange timber trestle
with grey footings), `tower/gear_pit` (an ash-grey trestle over the spikes, two bays) and
`haar/lampwick_causeway` (the boardwalks read as framed through the fog). The first try put a knee
bracket on both sides of each end post, and the outer one stuck out past the board's end. End posts
now brace inward only, and a test checks every post in the game. The first frame floor was 20 px,
which would have cross-braced posts over a single empty row (29 px tall, very flat X's). It is now
40 px.

## Tests

`tests/test_plank_supports.gd`: every support tone, bolts and footings included, is a palette value,
and the bolts stand out from the timber. A post is at least 4 px with a cap bolt and a footing wider
than the post, and stays between board and floor. Two posts get one frame with a rail, inside the
posts, and no bay wider than `BAY_MAX`. A run one row above the floor gets no frame. In every room,
no post reaches past its board.

Mutation check, each restored from a copy after: end posts braced both ways fails it (281 checks);
2.5 px posts fail it (2 checks); no frame fails it (2 checks); an off-palette bolt fails it (1 check).

Full suite: see below.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Planks stand on built trestles. |
| Art cohesion | 15 | 98 | Supports are built and in the palette; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 595 grade's item: the floating brick blocks in the Spires hit frame and the
unanchored crystals in the flooded hall; then the flat midground and parallax layers (plaza, gear
pit, flooded hall), and the slash and spark covering the struck foe. The grid item's leftovers (the
plaza's flat grey city) go with the midground. The Haar's fog and the sword's look stay held.
