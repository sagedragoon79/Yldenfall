# Pass 538: every plank is held up

## Category

A defect from the pass 535 independent grade (workbench queue): "rooms read as empty boxes of
unsupported floating planks." World and level design, and Art cohesion (Environments in the grade).

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do. No PixelLab generations were spent.

## Audit

The one-way plank (`-`) is a single atlas tile (`TilesetFactory.ONE_WAY`) drawn by
`tilegen.paint_one_way`. Since pass 521 (bible 12.20) it carries a small trestle, but that trestle
deliberately stays inside the tile's lower half, so it never meets anything. In `spires/sky_steps`
eight runs of planks float in the rain with nothing above or below them; the Tower, Heartwood and Haar
rooms are the same. The grade's shots (01, 04, 07) are these rooms.

## What was built

- `PlankSupports` (`scripts/world/plank_supports.gd`), a new per-room layer drawn behind the tiles. It
  groups the room's `-` cells into horizontal runs and plans one support for each (bible 12.30):
  a knee brace into a wall a run's end touches; posts down to footing at most 4 tiles below; otherwise
  hangers up to the first solid cell or plank above, fixed under that plank's board. A hanger with
  nothing within 22 tiles above fades out over 5 tiles.
- Rope (a twisted strand with a knot at the board) in the timber and water zones; chain (face-on and
  edge-on links, a ring at the board) in the stone, iron and glass zones; posts and braces in the
  plank's own strut timber. Every colour is a palette ramp value the zone's plank already uses.
- `Room` records `-` cells separately from other one-way cells (ladder tops, boardwalks, hidden planks
  stay as they were) and adds the layer after the edge shade.

## By eye, at 1x and 2x

Before and after in `spires/sky_steps`, `tower/bat_belfry`, `haar/drowned_stair`,
`heartwood/amber_falls`, `evercrown/drift_well` and `sunken/drowned_aqueduct`. The Sky Steps now read
as rope-hung swings in a chain down from the ceiling, the low step stands on two posts like a trestle
table, and the Tower's ledges hang on iron chains from the vault. A first take hung the lower planks
from the empty air under the upper plank's trestle; they now take the upper board itself. The first
chain read as a dashed line at 2x and was widened to 3 px links. Foes, pickups and the hero all pass in
front of the supports, which stay thin and dark enough not to compete with the play layer.

The dressed mid-ground half of the grade item (the Spires sky steps, the Evercrown veins, the Haar marsh
road) is left for a later pass.

## Tests

`tests/test_plank_supports.gd` (new, 9 tests): runs are found in reading order; an open-air run hangs
two anchored hangers from the ceiling; a low run stands on posts, and never past `POST_MAX`; a run
against a wall is braced (short runs need nothing more, long ones hang their free end, a wall-to-wall
run is two braces); a hanger under another plank is fixed at its board; a lone, far run fades out;
every plank run in every room of the game is held up, and fewer than a quarter fade out; a built room
adds the layer behind the tiles with the zone's look.

Mutations: dropping the hanger branch fails 6 of the 9 tests (182 checks); anchoring under the plank
above at its cell edge instead of its board fails the board test.

Bible: 12.30 (every plank is held up).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Planks now hang, stand or brace; the empty mid-ground remains. |
| Art cohesion | 15 | 98 | Supports share the planks' ramps. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the layer draws once per room load. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 539: the art loop stays **gated** on Sean (three guardian bases wait). Next from the pass 535
grade: the placeholder set pieces (the Spires red orb columns, the grey sign slabs, the flat Heartwood
liquid, the Evercrown diamonds, the Haar glyph blocks), then the dressed mid-ground. The VFX-tool
trials continue on the dash afterimage, then the enemy death dissolve. Rim light on figures and the
Boughs painterly clash stay parked for a watched session. Pass 540 is the fifth since the last grade.
