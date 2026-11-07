# Pass 504: tile variants so brick and wall fields stop reading as a 32 px grid

## Category

Art / World, from the independent-grade queue — not the rubric rotation. Art outranks the rotation
when the queue holds no fresh Sean note (none this pass; all three notes are answered), and the
headline art item (the PixelLab guardian bases) is **blocked**: three bases already wait for Sean's OK
(Haar Wyrm, Thane Vorrund, Drowned Warden), the limit of three, and no note frees a slot. The hero
sprite (the grade's top defect) would be a fourth base, also over the limit. So this pass takes the
unblocked, code-first grade defect that pass-503's "Next" named — **tile variants / grid banding**,
flagged at the pass-497/502/503 grades:

> Brick and wall fields tile obviously; add atlas variants in `tilegen` so the grid's repeat unit
> stops reading.

No generations and no base-approval gate; it touches every zone's tileset.

## What was built

A zone's atlas (`tools/art/tilegen.py`) held **one tile per blob autotile mask**, each painted with a
single seed. A large solid field is mostly full-solid (`FULL`-mask) cells, so every one drew the **same
32 px tile** — the same brick courses, pits and bright accent stones recurring every tile, a visible
grid. Only deep `FULL` interiors had any variation, and only a 2-way one (`MID`/`DEEP`).

**Row 7 masonry variants.** Every atlas now carries a new bottom row of full-solid variants painted
with fresh seeds, so their courses and pits land differently: **three surface-bright variants** (cols
0–2, matching the base `FULL` brightness) and **two more each** of the darker interior tiles (`MID`,
cols 3–4, one shade down; `DEEP`, cols 5–6, two). `TilesetFactory.ground()` scatters them across a
field by a pure hash of the cell position — a **4-way** choice at depth 1 (base plus three variants)
and across the widened 4-tile `MID`/`DEEP` sets deeper in. Adjacent same-mask cells now draw a
different pattern, so the repeat unit stops reading. Edges (non-`FULL` masks) are untouched, so
outlines and caps stay continuous, and the depth tiers (space-not-texture darkening) are preserved.

The **pixellab zones** (hearthroot) fill a solid interior from a seamless `GroundFill` texture, so
they have no 32 px grid to break; their atlas (`tools/art/pixellab_tileset.py`) grew the same row 7
only so every coord the factory can return exists — the `FULL` variants stay clear (the fill shows
through) and the `MID`/`DEEP` extras keep the same night veil as the row-6 interiors.

This is **code-first**: rows 0–6 of every atlas are unchanged (only the new row 7 is added), no art is
repainted, and the selection is deterministic. One existing room test
(`test_tiles_are_drawn_at_double_density`) asserted each atlas is exactly 7 rows tall; it now expects
8, for the variant row.

## A determinism gotcha, handled

As at pass 503, a full `python tools/art/tilegen.py` run re-encodes the backgrounds byte-differently
but pixel-identically on this PC (a Pillow quirk). So only the tileset builder was run (not the
backgrounds), and every regenerated atlas was checked against `HEAD`: **rows 0–6 are pixel-identical**
to `HEAD` across painted and pixellab zones (confirmed per-zone), so the diff is purely the added row
7. `assets/bg/` is untouched. All eleven `assets/tiles/<zone>.png` carry a real pixel change (the new
variant row); `hearthroot_fill.png` is unchanged.

One local gotcha, handled: the atlas PNGs grew from 7 to 8 rows, so Godot's import cache (`.godot/`,
not committed) had to be refreshed with `godot --headless --import` before the factory test's
`load()` saw the taller texture — otherwise `create_tile` at a row-7 coord reported "outside the
texture." CI checks out fresh and imports the committed PNGs at their true size, so it is unaffected;
the note is only for re-running the suite locally after a tileset resize.

## Checks

- **Verified by eye** at 1x and 2x. A 10×8 solid `gym` brick field rendered base-only vs
  variant-scattered side by side: the base field shows the rigid 32 px repeat (the same accent-stone
  cluster recurring every tile); the scattered field distributes the lighter stones irregularly, so it
  reads as a real wall, not a stamped texture. In-game on `trials/stillness` — a room of genuinely
  thick brick walls and a large central block — the masonry now reads as a believable wall with its
  lighter stones scattered, no 32 px banding, and **no holes or broken tiles** where the thick field's
  `FULL` cells draw the new variants. The pixellab town (`hearthroot/market`) still renders its thick
  stone border solid and correct — the critical no-breakage check for the pixellab path.
- **`tests/test_tileset_factory.gd`** (new, 6 tests, registered in the runner) guards the factory: a
  `FULL` surface field spreads over base + 3 variants; every tile used is the base or a variant; the
  `MID`/`DEEP` tiers scatter within their darker sets; edges stay stable across cells; and **every
  variant coord is a real tile** in the built atlas for a painted and a pixellab zone (so walls can
  never draw blank). **Mutation-checked:** removing the `FULL` depth-1 scatter from `ground()` fails
  the scatter test.
- **`tools/art/test_tilegen.py`** (now 13 checks, 3 new) guards the atlas: it is 8 rows tall, the three
  `FULL` variants differ from the base and from each other, and the `MID`/`DEEP` variants darken
  correctly. The game suite is Godot-only and CI runs no Python unit tests, so this is a local
  art-tool guard — run it with `python tools/art/test_tilegen.py`. **Mutation-checked:** reverting the
  atlas to 7 rows fails the row guard; making the three `FULL` variant seeds identical fails the
  distinctness guard.
- Full local Godot suite green (below); CI test + mix green; no test loads the tileset PNGs, so the
  regenerated art does not touch the game suite beyond the factory logic the new test drives.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 92 | Solid brick and wall fields no longer band on the 32 px grid: `ground()` scatters several masonry variants across a field so the repeat unit stops reading. With pass 500's rim shading, 501's atmospheric perspective, 502's softened sky and 503's shaded grass fringe, the environment art keeps tightening; the hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Pure asset + tile-selection change; the pick is a cell hash, no per-frame cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 97.95.

## Next

Pass 505: the art loop stays gated on Sean — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three, so no new base can be made until he approves one. Until
then, the larger code-first grade defects remain: **empty midgrounds** (several rooms are huge flat
backdrops with a few thin platforms — add midground structure, props and verticality in the room
layouts and decor, keeping reachability green), **flat directionless lighting** (add a directional key
light and emissive glow with gradient falloff and contact shadow), **zone-to-zone incoherence** (unify
outline weight and light direction across zone tilesets, pull base hues toward the master palette), and
**enemies camouflaged against their tiles** (reserve an accent colour or outline for foes and hazards).
Yldenfall's rooms are atmospheric-backdrop-heavy with thin solid platforms, so the biggest remaining
"tiling" the grade sees is in the parallax midground brick/column art, not the solid tiles — a
**midground-variant** pass (vary `<zone>_mid.png` so its brick/column field stops repeating) is the
natural companion to this one and may lift the grade more. The hero sprite (the grade's top defect)
needs PixelLab and would be a fourth base — held until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
