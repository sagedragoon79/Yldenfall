# Pass 519: varied ashlar and distant rooflines — the Spires brick and the Hearthroot skyline

## Category

Art cohesion, from the queue — the first unblocked item, the independent grade's (pass 515)
**remaining stamp repetition** that the masonry sweep (passes 514/515) did not reach: "Spires brick
field reads as one repeated stamp, and Hearthroot's background buildings are the same two
silhouettes copied across the row." These are the two surfaces the sweep left untouched — one play
surface (the Carillon ashlar gameplay tileset, `paint_shrine`) and one painted backdrop (the distant
houses of `hearthroot_far`).

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot, so the headline
guardian/hero work cannot move. Sean's own top queue item (lighting/depth) is down to **rim light on
figures** and **a second foreground band** — both touch what passes in front of the play field and
want a watched session for the combat-readability call, not an unattended loop pass. The grade's #1
defect at pass 515 (the dark empty band above the far layer) is likewise parked for a watched session
(12.15). This pass takes the strongest fully-testable item left, with no readability risk.

## What was built (design bible 12.18)

- **Spires ashlar (`paint_shrine`).** The ashlar used a fixed block scale (12×6 cells) and gilded a
  mid-course groove on ~38% of blocks, so a wall drew the same brick courses with a gold dash
  marching across every row — read as one repeated stamp. Three things now vary with the seed:
  - **Course scale is seed-keyed** — block width 10–14 and height 5–7 render cells from
    `hash2(seed, …)` — so the factory's scattered row-7 variants (12.8), each a fresh seed, read as
    differently-coursed masonry rather than one scale repeating.
  - **A weathered stone here and there drops a shade**, giving the field block-scale value variation
    instead of a flat two-tone repeat.
  - **The gold inlay is rare** (threshold 0.82, roughly one block in five) and keyed per block, so it
    reads as scattered accents, never a gold groove on every course — the strongest "stamp" signal.

  Pale-ashlar colour, outlines and the masonry caps/slopes are unchanged.

- **Hearthroot skyline (`hearthroot_far`).** The distant houses all drew the same sine-arch roof.
  Each house now picks one of several roof silhouettes — a rounded arch, a triangular gable, a
  crenellated battlement parapet, or a stepped gable — with a per-house peak height, and some carry a
  chimney and a varied window stride. A row of houses reads as a varied drowned-town skyline rather
  than the same arch copied across. The masonry body and weathered courses of 12.14 are unchanged.

Only `assets/tiles/spires.png` and `assets/bg/hearthroot_far.png` were regenerated (directly, not via
a full `tilegen` run, so no byte-only churn touched the other tilesets or backdrops). `paint_shrine`
is used by the Spires zone alone, so no other zone's tileset changes.

Combat is untouched by construction: the Hearthroot change is a receding parallax layer behind the
play field and under the atmosphere haze (12.5); the Spires change is texture-only on the ashlar
tileset — same pale colour, outlines and silhouette, so hazards, foes and telegraphs (which hold
reserved accent colours) keep their contrast. Verified by eye at 1x/2x in `spires/broken_shrine` (the
wall reads as weathered masonry; the cherry pickup, platforms, grass and shrine still pop) and in the
raw 2x `hearthroot_far` skyline (arches, gabled roofs, crenellated towers, chimneys, varied heights).

## Tests

`tools/art/test_tilegen.py` gains three mutation-checked guards (this Python guard runs locally, like
the moire/moss/variant/masonry guards before it):

- **`test_shrine_gold_inlay_is_sparse`** — the mean gold-inlay coverage across a range of shrine
  seeds stays under 2% of the field. Mutation: reverting the inlay threshold to the old 0.62 raises
  it to ~2.7% and fails.
- **`test_shrine_course_scale_varies_with_seed`** — the count of full mortar rows in a shrine tile
  (a `ly == bh-1` row paints the whole width `stone-1`) takes more than one value across seeds.
  Mutation: a fixed `bh` gives every seed the same course density and fails.
- **`test_hearthroot_houses_vary_rooflines`** — `hearthroot_far` draws gable, battlement and stepped
  roofs and a chimney. Mutation: collapsing the roofline back to the single sine arch fails.

The full Godot suite is unaffected (no `.gd` or gameplay change) and was run green; CI (test + mix)
green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the Spires change is texture-only on the ashlar (same pale colour, outlines and silhouette), the Hearthroot change is backdrop-only — hazards, foes and telegraphs keep their contrast by construction (verified in `spires/broken_shrine`). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The last two fields the grade called a repeated stamp — the Spires ashlar wall and the Hearthroot distant skyline — now read as varied weathered masonry and a varied town. Completes the stamp-repetition sweep begun in the tileset variants (504) and the backdrop masonry (514/515). The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two static assets regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the Spires keep their ruined-shrine ashlar and the Hearthroot its drowned-town skyline. |

Weighted: 98.7.

## Next

Pass 520: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). With the stamp
repetition now swept across the gameplay ashlar and the distant skyline, the strongest remaining
code-first item is the **ambiguous translucent blocks in `evercrown`** (grade pass 503, queued) — the
mid tendrils read unclearly against the ribbed far wall — or the grade's **zone-to-zone style
incohesion** (pass 515: the painterly Market/Plaza versus the flat cartoon tile-grass of Heartwood
and the Haar). Sean's **rim light on figures** and a **second foreground band** stay the
highest-value lighting pieces but want a watched session for the combat-readability call, not an
unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it
in.
