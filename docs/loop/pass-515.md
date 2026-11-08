# Pass 515: second masonry sweep — weathered courses on the drowned-capital pillars and the sunken aqueduct piers

## Category

Art cohesion, from the queue — the **midground / backdrop masonry** item (independent grade,
passes 497, 502, 504: the backdrop brick and column fields read as one repeated stamp, a "regular
mortar lattice"). Pass 514's named next (the second masonry sweep for the far layers' painted
courses in the other zones and the mid brick/column fields that still read as lattice), and the
queue item below Sean's lighting/depth request.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot, so the headline
guardian/hero work cannot move. Sean's own top queue item (lighting/depth) is down to **rim light on
figures** and **a second foreground band** — both touch what passes in front of the play field and
want a watched session for the combat-readability call, not an unattended loop pass (the deferral
passes 505/507/509/510/511/513/514 applied). This pass takes the strongest fully-testable,
backdrop-only item left, with no readability risk.

## What was built

Pass 514 added two shared helpers (design bible 12.14) that break the mortar lattice —
`masonry_courses(top, bottom, seed, spacing)` (jittered, partly-worn course rows, no fixed vertical
period) and `masonry_shade(x, y, seed, dark, body, light)` (a per-stone value so the field is not
one flat colour) — and applied them to four fields (`tower_far`, `tower_mid`, `vorrhallow_mid`,
`hearthroot_far`). Two more painted brick/column fields still drew their courses on a fixed period
over one flat body colour:

- **`vorrhallow_far`** — the drowned capital's great-hall pillars drew a course on `y % (18·D)` with
  a flat `night-1` body. Now the courses come from `masonry_courses` and the body from
  `masonry_shade` (kept muted — `stone-1`, no `stone-2` accent — so the far layer stays behind
  `vorrhallow_mid`). The lit near-edge, the arches, the crystal clusters and the dark water are
  unchanged.
- **`sunken_mid`** — the drowned aqueduct's piers drew a course on `(y − deck) % (16·D)` with a flat
  `night-1` body. Now `masonry_courses` (anchored at the deck line) and `masonry_shade`. The pier
  caps, the arch spans and the swaying weed are unchanged.

Only those two `assets/bg/*.png` were regenerated (directly, not via a full `tilegen` run, so no
byte-only churn touched the other backdrops or any tileset).

`evercrown` was left out on purpose: its far layer is a ribbed shell wall (organic, not masonry) and
its mid layer is hanging flesh tendrils — neither is a brick/column field, so the lattice helpers do
not apply. `sunken_far` is terraced limestone scattered by value noise, not a coursed field, and is
also untouched. The grade's separate "ambiguous translucent blocks in evercrown" item (pass 503)
stays queued.

No design-bible change: this pass applies the existing 12.14 behaviour to two more fields; it adds no
rule and changes no behaviour.

Combat is untouched by construction: these are the receding parallax layers behind the play field,
muted further by the atmospheric-perspective shader (12.5), never the gameplay tiles, hazards or
foes. Verified by eye — in-game at 1x in Vorrhallow (`gate_hall`) and Sunken (`drowned_aqueduct`),
the gameplay masonry (the pale pier/brick tileset) and the hero, foes and hazards keep full
contrast; and in before/after crops of the raw layers (the 2x render density), where the fixed
course lattice is gone and the weathered courses and per-stone value read clearest before the haze
mutes them.

## Tests

`tools/art/test_tilegen.py` gains one mutation-checked guard (this Python guard runs locally, like
the moire/moss/variant/masonry guards before it):

- **`test_flagged_backdrop_fields_use_weathered_courses`** — every field the grade called a mortar
  lattice (`tower_far`, `tower_mid`, `hearthroot_far`, `vorrhallow_mid`, `vorrhallow_far`,
  `sunken_mid`) draws its courses through `masonry_courses` and holds no vertical-period course
  lattice (`y % …` / `(y − deck) % …`); a horizontal `dx %` window/bolt stride stays allowed.

Mutation confirmed: reverting `vorrhallow_far` to its old `y % (18·D)` course drops the
`masonry_courses` call and fails the guard; restoring passes. The pass 514 helper-level guards
(course period, wear, overlap, shade spread, body dominance) still cover the behaviour these two
fields now rely on. The full Godot suite is unaffected (no `.gd` or gameplay change) and was run
green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the masonry lives only on the parallax backdrop, behind the play field and under the atmosphere haze — tiles, hazards and foes keep their contrast by construction (verified in Vorrhallow and Sunken). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The last two painted brick/column fields the grade named — the drowned-capital pillars and the aqueduct piers — no longer read as one repeated stamp, completing the masonry sweep begun in pass 514 (tower/vorrhallow_mid/hearthroot_far). Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511), carved-sign (512), murky-zone (513) and masonry (514) work. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two static PNGs regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; Vorrhallow and Sunken keep their materials and lights. |

Weighted: 98.7.

## Next

Pass 516: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). With the painted
masonry lattice now swept across every flagged brick/column/pier field, the strongest remaining
code-first item is the **ambiguous translucent blocks in `evercrown`** (grade pass 503, queued) —
the mid tendrils read unclearly against the ribbed far wall. Sean's **rim light on figures** and a
**second foreground band** stay the highest-value lighting pieces but want a watched session for the
combat-readability call, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires
it in.
