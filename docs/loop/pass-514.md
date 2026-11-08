# Pass 514: weathered backdrop masonry so the brick/column field stops reading as one repeated stamp

## Category

Art cohesion, from the queue — the **midground / backdrop masonry** item (independent grade, passes
497, 502, 504: the backdrop brick and column fields read as one repeated stamp, a "regular mortar
lattice"). Pass 513's named next, and queue item below Sean's lighting/depth request.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot, so the headline
guardian/hero work cannot move. Sean's own top queue item (lighting/depth) is down to its last two
pieces — **rim light on figures** and **a second foreground band** — both of which touch what passes
in front of the play field and want a watched session for the combat-readability call, not an
unattended loop pass (the same deferral logic passes 505/507/509/510/511/513 applied to rim light).
This pass takes the strongest fully-testable, backdrop-only item left, with no readability risk.

## What was built

The painted parallax backdrops (`tools/art/tilegen.py`) drew their brick and column fields on a
rigid grid: mortar courses on a fixed vertical period (`y % spacing`) over one flat body colour. Two
shared helpers break the lattice (design bible 12.14):

- **`masonry_courses(top, bottom, seed, spacing)`** — the mortar-course rows with jittered gaps
  (0.5x to 1.5x the spacing, so there is no fixed vertical period), a one- or two-pixel course
  thickness, and roughly one course in six worn away. Deterministic; a set for a pixel loop.
- **`masonry_shade(x, y, seed, dark, body, light)`** — a per-stone value: most stones draw `body`, a
  minority (thresholds >0.93 and <0.16) drop to `dark` or lift to `light`, keyed by a coarse cell
  grid, so adjacent stones differ and the field is not one flat colour.

Applied to the four brick/column fields the grade named: the Tower's far shafts and mid girders
(`tower_far`, `tower_mid`), the Vorrhallow colonnade (`vorrhallow_mid`) and the Hearthroot distant
houses (`hearthroot_far`). Only those four `assets/bg/*.png` were regenerated (directly, not via a
full `tilegen` run, so no byte-only churn touched the other backdrops or any tileset); the painters'
other features — lit windows, slit windows, gears, lanterns, crystal spears, chains — are unchanged.

Combat is untouched by construction: these are the receding parallax layers behind the play field,
muted further by the atmospheric-perspective shader (12.5), never the gameplay tiles, hazards or
foes. Verified by eye in-game at 1x in the Tower (`foot`), Vorrhallow (`gate_hall`) and Hearthroot
(`plaza`) — the backdrop masonry no longer reads as a grid, and the hero, foes, platforms and
hazards keep their full contrast — and in the raw layers (the 2x render density) for the Tower and
Hearthroot far shafts/houses, where the weathered courses and shade variation read clearest before
the haze mutes them.

## Tests

`tools/art/test_tilegen.py` gains five mutation-checked guards (this Python guard runs locally, not
in the Godot suite or CI, like the moire/moss/variant guards before it):

- the courses have no fixed period (gaps take several distinct values — removing the jitter fails),
- the courses are partly worn away (a gap wider than any jitter alone allows — removing the wear
  fails),
- the courses never overlap (every gap at least half the spacing),
- the shade varies across a field (all three of dark/body/light appear — body-only fails),
- the field stays body-dominant (body > 60%, light < 12% — widening the accent bands fails).

All four mutations above were confirmed caught. The full Godot suite is unaffected (no `.gd` or
gameplay change) and was run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the masonry lives only on the parallax backdrop, behind the play field and under the atmosphere haze — tiles, hazards and foes keep their contrast by construction (verified in the Tower, Vorrhallow and Hearthroot). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The backdrop brick/column fields no longer read as one repeated stamp — the grade's recurring "regular mortar lattice" (passes 497/502/504). Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511), carved-sign (512) and murky-zone (513) work. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Four static PNGs regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the Tower, Vorrhallow and Hearthroot keep their materials and lights. |

Weighted: 98.7.

## Next

Pass 515: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). The strongest
remaining code-first items are a second masonry sweep for the backdrops this pass left (the far
layers' painted courses in the other zones, and the mid brick/column fields in `evercrown`/`sunken`
if they read as lattice) and the **ambiguous translucent blocks in evercrown** (grade pass 503,
queued). Sean's **rim light on figures** and a **second foreground band** are the highest-value
lighting pieces but want a watched session, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires
it in.
