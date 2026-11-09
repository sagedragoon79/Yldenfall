# Pass 521: the one-way plank gets a per-zone material and a trestle

## Category

Art cohesion, from the queue — the independent grade's (pass 520) top-ranked
defect, **copy-pasted floating plank platforms**: "the same one-way wooden-slat
platform repeats across many rooms (heartwood, haar, spires) with nothing holding
it up, reading as a prototyping block rather than level architecture."

The higher queue items stay blocked for an unattended pass: the far-sky empty band
(0) and rim light on figures / a second foreground band (1) are parked for a
watched combat-readability call; the PixelLab art loop (2) is gated on Sean, with
three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) already awaiting
his OK — the limit of three — and no new note frees a slot. The haar/sunken
contrast item (3) was substantially closed by pass 513's haze easing plus the
later fog, grade, room-light, foreground, ridge and light-shaft passes (judged by
eye this pass in `haar/drowned_stair` and `sunken/wellspring`: the planks and
terraces separate cleanly from the murk). So this pass takes the strongest fully
code-first, fully-testable item that most lifts the grade: the plank.

## What was built (design bible 12.20)

`tilegen.paint_one_way` painted one hardcoded `bark` board with a stubby bracket
for **every** zone, and each atlas carries a single plank tile — so a run of ledges
was the same board repeated, and every zone's ledge was identical. Both reads are
fixed procedurally (no PixelLab spend):

- **A per-zone board material and fastener (`PLANK`).** Each zone's plank draws in
  its own ramp with its own accent: warm bark (gym, Heartwood, High Boughs, with
  stone / gold / leaf fasteners), grey driftwood (`umber`) for the water zones
  (Haar, Sunken Spring), pale stone (`ash`) for Vorrhallow, the Trials and the
  Tower (the Tower's board takes a brighter catch-light via `metal`), dry timber
  (`ochre`) for the Spires, and stillglass (`crystal`) for the Evercrown. The
  grade's named trio — Heartwood, Haar, Spires — now read as three different
  materials, and no two unrelated zones share a plank. Hearthroot's plank is
  PixelLab art (`pixellab_tileset.atlas`) and is untouched.
- **A drawn trestle instead of the stub.** Under each board groove a short post
  with two splayed legs reaches into the lower half of the tile, so the ledge reads
  as carried, not floating. The legs stitch across the tile seam, so a run reads as
  one continuous truss; they never reach the tile's bottom edge, so a mid-air
  platform does not imply a floor beneath it.

Collision is untouched — the change is texture-only on the plank tile
(`TilesetFactory.ONE_WAY`), so jump-through behaviour is unchanged by construction.
The ten procedural zone atlases were regenerated (`build_tileset` per zone, so the
non-deterministic `_mid`/`_far`/`_ridge`/`_fore` backdrops were not re-saved);
`hearthroot.png` does not change. The Godot import cache was refreshed
(`--headless --import`) before capture.

Judged by eye at 1x and 2x (and 4x–6x crops) in `haar/drowned_stair`,
`heartwood/amber_falls`, `tower/bat_belfry`, `spires/broken_shrine`,
`sunken/drowned_aqueduct` and `evercrown/drift_well`, plus a cross-zone contact
sheet of the plank tile: the materials are clearly distinct, the trestle reads as a
support, and foes, pickups and telegraphs still pop against the plank, and the
plank against each backdrop.

## Tests

`tools/art/test_tilegen.py` gains three mutation-checked guards (this Python guard
runs locally, like the moire/moss/variant/masonry guards before it):

- **`test_one_way_plank_differs_across_the_graded_trio`** — Heartwood, Haar and
  Spires planks differ pairwise. Mutation: reverting to the single hardcoded `bark`
  board makes all three byte-identical and fails.
- **`test_one_way_plank_board_uses_its_zone_material`** — each plank board's
  dominant ramp matches its `PLANK` spec (`umber` for Haar, `ochre` for Spires,
  `crystal` for Evercrown, `ash` for the Tower, `bark` for Heartwood). Mutation:
  a `wood = "bark"` painter makes Haar's board bark, not umber, and fails.
- **`test_one_way_plank_rests_on_a_trestle_below_the_board`** — opaque pixels reach
  below the former stub depth (10 world px). Mutation: dropping the leg loop leaves
  nothing that deep and fails.

All 43 Python guards pass (40 before). The full Godot suite is unaffected (no `.gd`
or gameplay change) and was run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; texture-only on the plank tile, collision untouched — foes, pickups and telegraphs keep their contrast against the plank (verified across six zones). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The copy-pasted plank — the grade's top defect — now carries a per-zone material and a drawn trestle, so ledges read as built level architecture, not a floated prototyping block repeated across zones. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Ten static atlases regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; each zone's plank now reads in its own material (driftwood in the drowned zones, stillglass in the Evercrown, iron-grey in the Tower). |

Weighted: 98.7.

## Next

Pass 522: the art loop stays **gated** on Sean (three guardian bases wait, the
limit; the PixelLab key is set, so the moment a base is approved the Haar Wyrm
animation can begin). With the plank addressed, the strongest remaining code-first,
unattended item is the grade's **cheap radial lantern/mushroom glow** (pass 520,
queued, item 15): lantern and glow-mushroom light is drawn as soft circular
gradients that ignore the surfaces they sit on, reading as pasted-on blobs — shape
the glow to its source/surface (a cast pool/falloff on the ground, or a
sprite-shaped bloom). Sean's **rim light on figures** and a **second foreground
band** stay the highest-value lighting pieces but want a watched session for the
combat-readability call, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar
marshes** could take a thin, slow drizzle and the High Boughs an even fainter
mist-rain — say the word and a pass wires it in.
