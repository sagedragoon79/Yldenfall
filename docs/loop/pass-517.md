# Pass 517: the Evercrown drift pockets read as columns of light, not glass slabs

## Category

Art cohesion / combat readability, from the queue — the pass-503 independent grade flagged the
Evercrown's wrong-gravity pockets (`evercrown/drift_well`) as "large teal semi-transparent
rectangles" that look like unstyled collision volumes, confusing what is solid versus background in
a combat room. Pass 516's "Next" named this as the strongest remaining code-first item.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot. Sean's own top
queue item (lighting/depth) is down to **rim light on figures** and **a second foreground band**,
both parked for a watched session, and the grade's **letterbox** band above the far layer (pass 516's
parked half) also wants a watched readability call. This pass takes a fully-testable, behind-the-play-field,
no-readability-risk slice.

## What the grade saw, and what this fixes

`GravityDrift` (bible 8.9, legend `v`) is a pocket where the player keeps 40% of their weight —
a plain jump rises ~11 tiles and a fall drifts down, carrying you up ledges no jump could reach.
Bible 8.9 says they should "read as violet columns with cyan motes rising through them." The old
`_draw()` did not deliver that: it filled the whole cell rectangle with one flat `0.22` violet wash
and drew the only hard edges as two full-height 1 px side lines. The result read as a solid glass
box with crisp rectangular boundaries — exactly the "collision volume / placeholder" the grade saw.

`GravityDrift._draw()` now paints each pocket as a feathered shaft of light:

- **`column_alpha(x, w)`** — the horizontal profile. The wash feathers to nothing at the two sides
  (no hard box edge), carries across the interior, and brightens toward a core down the centre.
- **`rise_alpha(y, h)`** — the vertical envelope. The shaft fades in at the floor and out at the
  crown, so it is not read as a capped rectangle.
- The wash is drawn as feathered vertical strips (`STRIP` = 4 px) with floor/crown fade bands; a
  pulsing `MOTE`-cyan core streak runs up the centre ("where the light drifts upward, so will you"
  — the Drift Well's sign); the climbing light bands are kept inside the feathered interior so their
  ends never draw a hard edge; the rising motes are unchanged.

Judged by eye at 1x and 2x in `evercrown/drift_well`: the three pockets now read as rising light —
soft-edged columns of cyan motes with a bright core — rather than flat glass slabs.

## Combat is untouched

The pocket still sits behind the play field (`z_index = -1`) and still affects only the player (the
`_physics_process` gravity logic is unchanged). Foes, hazards and telegraphs read over it exactly as
before; this pass changes only how the pocket paints itself.

## Tests (mutation-checked)

`tests/test_movement.gd` — `test_the_drift_pocket_reads_as_a_feathered_column`:

- `column_alpha` feathers to ~0 at both sides, carries the interior (`> 0.5` at the core), and the
  core is brighter than the interior's edge.
- `rise_alpha` fades to ~0 at the crown and the floor and is full (`> 0.99`) through the body.

Mutation: a flat `column_alpha` (a constant profile) fails the feathered-edge guards; a flat
`rise_alpha` fails the crown/floor fade. The existing behavioural drift tests
(`test_wrong_gravity_lifts_a_jump_and_slows_a_fall`, `test_the_drift_well_lifts_you_up_its_ledges`)
are untouched and still green — the draw change does not touch the physics.

Bible 12.16 added; the 8.9 pocket description is unchanged (the new look matches what it already
promised).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged — the drift physics are untouched. |
| Combat and enemies | 15 | 99 | Unchanged; the pocket stays behind the play field (`z_index = -1`) and affects only the player, so foes and telegraphs read over it as before. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The Evercrown drift pockets stop reading as flat teal collision slabs and read as the "violet columns with cyan motes rising through them" bible 8.9 promised. Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511), masonry (514/515) and far-mote (516) depth work. The letterbox band and the HD hero/guardian bases remain open. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A slightly larger `_draw()` (feathered strips over a flat rect), still static per redraw and bounded by the pocket size; no new per-frame simulation. |
| Story and world | 5 | 99 | Unchanged — the core streak echoes the Drift Well's own sign. |

Weighted: 98.7.

## Next

Pass 518: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The next
code-first grade items are the remaining **stamp repetition** (the Spires brick field and Hearthroot's
distant buildings — a third masonry/variation sweep) and the **zone-to-zone style incohesion** between
the painterly Market/Plaza and the flat tile-grass zones. Sean's **rim light on figures**, a **second
foreground band**, and the **empty band above the far layer** all still want a watched session for the
combat-readability call, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
