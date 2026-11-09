# Pass 526: a running bond breaks the stacked-column grid in the solid play tiles

## Category

Art cohesion, from the independent grade (pass 525) and the queue. Pass 525 broke the stamped-lattice
read in the **backdrop** masonry (12.14); the grade then read the same repetition one layer forward,
in the **gameplay** solid tiles at play scale — a stacked stone/brick column reads as one 32 px tile
copy-pasted down its length (queue item: "gameplay masonry still tiles"). It is the first actionable
queue item: items 0–1 are parked for a watched combat-readability call (the letterbox band and rim
light on figures), and the PixelLab art loop below them is gated.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK — the limit of three — and no new note frees a slot, so no new base or
animation can begin (the key is set; the moment a base is approved the Haar Wyrm animation can start).
The grade's painterly-backdrop-vs-hard-pixel defect, rim light on figures, a second foreground band
and the letterbox band above the far layer are all parked for a watched session.

## What was built (design bible 12.23)

`TilesetFactory.ground` already scatters a FULL-solid field across four variants, each painted with a
fresh seed (12.8), but the variants differed only in **shade**, not in where the brick lattice or the
strata fell. Every tile placed its joints and courses at the same positions, so a column still lined
up on the 32 px grid. Rendered as the factory assembles a solid field, the two painted masonry
painters were the offenders:

- **`paint_bricks`** (gym, trials; hearthroot's tiles are PixelLab art, `PIXELLAB_SETS`, and are
  untouched) laid its brick lattice from the local `x`/`y` with a fixed half-brick alternation, so the
  vertical mortar joints fell at the same x (0, 16) in every tile and the horizontal courses at the
  same y. It now gives the lattice a **per-tile vertical phase** (`voff`) and a **per-course
  horizontal jitter**, both keyed to the seed. Across the scattered variants the courses and joints
  land at different places in each tile, so the field reads as organic coursed masonry rather than an
  aligned grid with a joint at every tile edge. The measured peak interior joint-column share falls
  from ~0.52 on the old fixed bond to ~0.37.
- **`paint_spring`** (sunken) made its wavy limestone strata from the local `x` and the seed, so the
  wave phase **jumped at every tile boundary** and the strata broke into hard vertical seams — the
  clearest "stacked column" offender. The wave now **wraps seamlessly across the tile width**: both
  sine terms complete a whole number of cycles over `T` and the seed only shifts their phase, so a
  tile's left and right edges always match and the strata flow across neighbours as one continuous
  bed. The mean luminance step across the wrap seam falls from ~30–45 (a hard seam) to ~2–10 (below
  the interior baseline).

Code-first and deterministic: only `assets/tiles/gym.png`, `assets/tiles/trials.png` and
`assets/tiles/sunken.png` regenerate. No `.gd` or gameplay change.

## Verified by eye (1x and 2x)

Rendered as the factory scatters a solid field, before and after, and in-game in `sunken/wellspring`
and a trials room:

- **Trials / gym bricks:** the bond steps between blocks and the rigid horizontal course march is
  gone; adjacent tiles no longer share a joint at their shared edge, so the field reads as weathered
  coursed masonry instead of a 32 px checker.
- **Sunken Spring:** the dramatic vertical tile seams are gone — the limestone strata run on across
  the field as a continuous sedimentary bed, the "copy-pasted columns" the grade named.

Combat readability is untouched by construction: these are solid-field art behind the actors; hazards,
foes and telegraphs are separate sprites in front of the tiles.

## Tests

`tools/art/test_tilegen.py` gains two mutation-checked guards (these Python guards run locally, like
the moire/moss/masonry guards before them):

- **`test_paint_bricks_does_not_stack_its_vertical_joints_across_a_field`** — over a tall scattered
  field, no interior pixel column (the tile-seam columns at `x % T == 0` are skipped, their edge being
  inherent to the atlas) is a vertical joint in more than 0.45 of its rows (the bond holds it ~0.37).
  Mutation: dropping the vertical phase and the horizontal jitter (the old fixed half-brick bond)
  re-aligns the joints to ~0.52 and fails.
- **`test_paint_spring_strata_wrap_across_the_tile_width`** — the mean luminance step across the wrap
  seam (column `T-1` → column `0`) is no worse than a typical interior step. Mutation: the old
  `x + seed` wave makes the wrap seam jump far past the interior baseline and fails.

All 48 Python guards pass. The full Godot suite is unaffected (no `.gd` or gameplay change; only three
static atlases regenerated) and was run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; solid-field art only — hazards, foes and telegraphs are separate sprites in front of the tiles. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The gameplay brick and limestone fields stop reading as one 32 px tile copy-pasted down a column — the grade's "gameplay masonry still tiles" closed, the play-scale companion to pass 525's backdrop bond. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Three static atlases regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the Sunken terraces stay the spring's own limestone, now a continuous bed rather than a stencil. |

Weighted: 98.7.

## Next

Pass 527: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab key
is set, so the moment a base is approved the Haar Wyrm animation can begin). The grade's top open
code-first defect is the **painterly far backdrops vs the hard-pixel foreground** — a per-painter
pixel-grain call parked for a watched session (with rim light, the letterbox band and a second
foreground band). The strongest remaining unattended item is the queued **VFX pass**: try PixelLab's
free VFX tool on one code-drawn effect (a sword hit or a guardian death burst), play it in Godot next
to the current effect, and keep it only if it reads better against the enemy style guide. The grade's
other code-first items — dark-on-dark hazard readability and the Boughs painterly/pixel clash — both
coordinate with parked watched-session calls.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
