# Pass 542: the Evercrown's shelves are grown

## Category

A defect from the pass 540 independent grade (workbench queue): "flat single-fill props", the
Evercrown's "hot-magenta platforms and chains" next after the Spires' sky islands (pass 541). Art
cohesion, and Environments in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, and the third
(one-template rooms) is a level-design rework, so this was the first art item an unattended pass could
finish. No PixelLab generations were spent.

The hosted workbench is down: its Vercel Blob store is suspended (function logs:
`BlobStoreSuspendedError`), so `push.py` gets HTTP 500 on every write and the hosted site shows no
notes. Nothing in the repository can fix it; it is under "stuck" for Sean.

## Audit

The magenta platforms are the Evercrown's one-way plank (`-`): `tilegen.paint_one_way` with
`PLANK["evercrown"]` set to the crystal ramp, a board in crystal-5 to crystal-2 on a crystal trestle.
The chains are its hangers from pass 538 (`PlankSupports.LOOKS["evercrown"]`: crystal-4, crystal-3,
crystal-1). In `evercrown/veins` six runs of them hang across the room, the brightest flat colour in a
dark violet zone, brighter than the foes.

## What was built

- `paint_grown_shelf` and `shelf_cells` (`tools/art/tilegen.py`), used when a zone's plank is marked
  `grown`. The shelf is grown from the zone's own matter: a continuous lit top band (night-5 over
  night-4) over one rounded lobe per segment (`SHELF_SEGS`, 7 and 9 world px, so the tile repeats
  seamlessly), the lobes shaded on the night ramp, lit from the upper left.
- Accents: a short crystal-3 glaze where the light first catches each lobe (the only crystal left),
  sinew in the notches between lobes, one cyan pore in the wide lobe.
- A night-0 selective outline under each lobe and down its shaded right side, never along the top.
- One fleshy tendril hangs from the wide lobe, paling to its tip, with a bead of cyan sap; a stub
  hangs from the narrow one. They replace the trestle: the shelf is grown, not built.
- Hangers are sinew (night-5, night-3, ember-1, drawn like rope); posts and braces are night tissue.
- Painted in whole world pixels (D x D), like pass 541.

## By eye, at 1x and 3x

`evercrown/veins` before and after, and `evercrown/drift_well` and `heart_stair` for the zone's other
surfaces. The first take shaded each segment as a full ellipse: at 3x the shelves read as a string of
beads or mushroom caps. The second joined the lobes under one continuous lit top: the shelf reads as
one grown ledge with a scalloped underside, of a piece with the zone's cell-stone floor. The cyan pore
in every lobe dotted a regular row and now sits in the wide lobe only. At 1x the shelves still read as
platforms against the violet backdrop (lighter than it, with a dark underside), but they are no longer
the loudest thing in the room; the cyan crystals and the foes now are.

## Tests

`tools/art/test_tilegen.py` (the art guard; CI runs only the Godot suite), four new checks: the shelf
is mostly night matter with under 8% crystal and no hot crystal (crystal-4 to 7), with sinew; every
pixel sits on the world-pixel grain; the top band is unbroken, lit and never outlined while the lobes
fall into shade and every column closes in night-0; the lobes fill the tile so it repeats. Two older
checks learned the grown shelf: the board-material check counts night when that is the zone's
material, and the trestle check leaves the Evercrown out. 63 checks pass.

`tests/test_plank_supports.gd`, one new test: the Evercrown hangs its shelves on sinew in no hot
crystal tone, and a built Evercrown room takes that look.

Mutations, each caught: the crystal board back (palette check), an outline along the top (top check),
lobes lit flat instead of shaded (shade check, after it learned to sample lobe body only and not the
outline and sinew), half-pixel blocks (grain check), lobes that don't fill the tile (seam check), the
crystal chain look back (the Godot test, 3 of 8 checks).

Bible: 12.34 (the Evercrown's shelves are grown); 12.30 now says the Evercrown hangs on sinew.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | The Evercrown's shelves are grown from the zone. The flat cyan diamonds in the Evercrown veins, the smelter cauldron, the Haar's orange blocks, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; a baked tile. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 543: the art loop stays **gated** on Sean (three guardian bases wait). Next, the rest of the
pass 540 grade's flat props (the smelter cauldron, the Haar's orange blocks) and the pass 535 grade's
flat cyan diamonds hanging in the Evercrown veins, then its stray black bars in the shop and the
one-template rooms. The VFX-tool trials continue on the dash afterimage, then the enemy death
dissolve. Rim light on figures and the Boughs painterly clash stay parked for a watched session. The
next independent grade is due at pass 545.
