# Pass 525: a running bond breaks the mid column/pier lattice

## Category

Art cohesion, from the queue and the independent grade. Pass 524's "Next" named this as the
strongest remaining **code-first, unattended-safe** item: the grade's **mid-ground / backdrop brick
still tiles** (pass 504, queued) — the painted parallax column and pier fields still read as one
repeated 32 px stamp. It is also the first actionable queue item: queue items 0–1 are parked for a
watched combat-readability call, and item 2 (the PixelLab art loop) is gated.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK — the limit of three — and no new note frees a slot, so no new base
or animation can begin (the key is set; the moment a base is approved the Haar Wyrm animation can
start). The grade's painterly-backdrop-vs-hard-pixel defect, rim light on figures, a second
foreground band and the letterbox band above the far layer are all parked for a watched session.

## What was built (design bible 12.14)

The painted backdrops share one helper for their stone fields, `masonry_shade` (`tools/art/tilegen.py`).
It keyed each stone's value on `(x // cell, y // cell)`, so every cell boundary fell on the **same
vertical line for every course**. Same-value stones — and the recessed `dark` ones — stacked into
straight columns, and in the narrow mid piers and columns the darkest cells read as a regular grid of
punched holes. Zoomed in on `sunken_mid`'s aqueduct pier and `vorrhallow_mid`'s colonnade, the field
was a rigid rectangular lattice: exactly the grade's "mid column/pier field reads as one repeated
stamp" (pass 504).

`masonry_shade` now lays the stones in a **running bond**. Each course shifts horizontally — half a
stone on alternate rows, plus a per-course jitter keyed to the seed — so the vertical cell boundaries
no longer align between adjacent courses and no single `x` carries a shade transition on more than a
fraction of its rows. The recessed `dark` stones are also a touch sparser (the darkest ~12% of cells,
down from ~16%), so the narrow piers stop reading as holed. The mortar courses themselves
(`masonry_courses`, jittered and partly worn, 12.14) are unchanged; only the per-stone value grid is
staggered.

The change touches every `masonry_shade` field at once — the two mid fields the grade named
(`vorrhallow_mid`, `sunken_mid`) and the three far brick fields that share the helper (`tower_far`,
`hearthroot_far`, `vorrhallow_far`). Only those five `assets/bg/*.png` regenerate; the six `*_mid`
backdrops that re-running the full generator would also touch (pre-existing drift noted in pass 524)
are left alone, so the diff is exactly the five fields this pass changes plus the generator and its
test.

Measured on the pier/column seeds, the peak per-column transition fraction (how much of a single
vertical seam carries a shade change — the signature of a stacked column grid) falls from **~0.47**
on the old aligned grid to **0.10–0.15** with the bond across the sunken (560–564) and vorrhallow
(620–625) seeds.

## Verified by eye (1x and 2x)

`sunken_mid` and `vorrhallow_mid`, before and after, plus the three far fields:

- **Sunken Spring:** the aqueduct piers read as weathered coursed stone — the recessed stones scatter
  across staggered courses instead of stacking into one black column, so the arcade stops reading as
  a tiled checker.
- **Vorrhallow:** the broken colonnade's narrow columns carry irregular coursing rather than a grid
  of punched holes; the crystal spears read over them as before.
- **Tower, Hearthroot, Vorrhallow far fields:** the far brick and shaft fields pick up the same
  organic coursing with no regression — still muted behind the mid layer under the haze (12.5).

Combat readability is untouched by construction: these are the receding parallax layers behind the
play field, never the gameplay tiles, hazards or foes.

## Tests

`tools/art/test_tilegen.py` gains one mutation-checked guard (this Python guard runs locally, like
the moire/moss/masonry guards before it):

- **`test_masonry_shade_lays_a_running_bond_not_a_column_grid`** — over a tall sample of
  `masonry_shade`, the peak per-column transition fraction stays below 0.30 (the bond holds it near
  0.15). Mutation: dropping the per-course offset (the old aligned grid) pushes a vertical seam to
  ~0.47 of rows and fails.

All 46 Python guards pass. The full Godot suite is unaffected (no `.gd` or gameplay change; only five
static backdrops regenerated) and was run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; backdrop-only — hazards, foes and telegraphs are separate sprites in front of these parallax layers. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The mid column/pier fields and the shared far brick fields stop reading as one stamped lattice — the grade's "mid-ground / backdrop brick still tiles" (pass 504) closed. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Five static assets regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the piers stay the dwarves' drowned aqueduct and colonnade, now weathered coursed stone rather than a stencil. |

Weighted: 98.7.

## Next

Pass 526: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). The grade's top open
code-first defect is the **painterly far backdrops vs the hard-pixel foreground** — a per-painter
pixel-grain call parked for a watched session (with rim light, the letterbox band and a second
foreground band). The strongest remaining unattended item is the queued **VFX pass** (queue): try
PixelLab's free VFX tool on one code-drawn effect (a sword hit or a guardian death burst), play it in
Godot next to the current effect, and keep it only if it reads better against the enemy style guide.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
