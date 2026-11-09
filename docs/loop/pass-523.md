# Pass 523: the Evercrown tendrils read against the ribbed far wall

## Category

Art cohesion / combat-readability, from the queue and the latest independent grade. The grade
(pass 520, 4.7/10) raised three real defects: the painterly-vs-hard-pixel style clash, the
copy-pasted floating planks, and the cheap radial lantern glow. Passes 521 (#582) and 522 (#583)
took the plank and glow defects. The remaining top defect — **painterly backdrops vs the hard-pixel
foreground** — is an all-backdrop pixel-grain call (see "What was attempted and parked" below); so
this pass took the strongest **contained, testable, unattended** item left, the one pass 520's
"Next" named: the grade's **ambiguous translucent blocks in `evercrown`** (pass 503, queued) — the
mid tendrils read unclearly against the ribbed far wall.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot, so no new base or
animation can begin. Sean's lighting/depth item is down to **rim light on figures** and a **second
foreground band**, and the grade's dark-band-above-the-far-layer defect is parked — all want a
watched session for the combat-readability call.

## What was built (design bible 12.21)

`evercrown_mid` painted each nearer stillglass tendril in the far wall's own two rib shades
(`night-1` body, `crystal-1` core), so a tendril had the same value and hue as the dark ribs it hung
in front of and camouflaged into them (verified by eye: in the before composite only the cyan bulb
tips read; the stalks vanished into the wall). The tendril cross-section is now a **lit, outlined
glass form**:

- a one-world-pixel **`night-0` silhouette rim** on each edge, giving the tendril a crisp outline
  against the wall;
- a **`crystal-2` body** and a **`crystal-3` core highlight** down the centre — a clear luminance
  step brighter than the wall's `crystal-1`/`night-1` ribs (≈73–101 vs ≈46), so the nearer flesh
  reads forward (the atmospheric-perspective cue the depth-collapse notes keep asking for);
- the ember bead and the cyan bulb tip are unchanged.

The tendrils stay magenta stillglass, consistent with the zone's crystal and the guardians'
stillglass growths. Only `assets/bg/evercrown_mid.png` is regenerated (deterministic: rendered twice
to identical bytes). The `mid` layer sits behind the play field under the atmosphere shader
(`desat` 0.3 / `fade` 0.24), and nothing gameplay-facing changes, so **combat is untouched by
construction** — hazards, foes and telegraphs keep their contrast; verified by eye at 1x and 2x in
`evercrown/drift_well` (the tendrils now stand forward of the ribbed wall; the hero, foes, pickups
and the drift pockets still pop).

## What was attempted and parked

The grade's top defect, **painterly/anti-aliased far backdrops vs the hard-pixel foreground**, was
attempted first as the queue names it ("bring the far layers' edges/dither into the pixel grid"): a
deterministic `D`-grid snap that collapses every 2×2 texture cell of a far layer to one colour, so
the backgrounds (painted at 2 texture-px per world pixel and displayed at scale 0.5, the same density
as the tiles) share the foreground's whole-world-pixel grain. By eye it **regressed**: vertical-fibre
zones (Heartwood) were unchanged, but zones with thin diagonal linework and soft clouds (Boughs)
eroded into dashed, speckled branches and gained 2×2 sky noise. A snap that helps some painters and
harms others needs per-painter tuning and an aesthetic eye — the same watched-session call as rim
light and the letterbox band — so it was not kept and is parked for a watched session, not
re-attempted unattended.

## Tests

`tools/art/test_tilegen.py` gains one mutation-checked guard (this Python guard runs locally, like
the moire/moss/variant/masonry/plank guards before it):

- **`test_evercrown_mid_tendrils_read_against_the_ribbed_far_wall`** — the rendered `evercrown_mid`
  carries `crystal-2`, `crystal-3` and a `night-0` rim, and its tendril-body luminance reads a clear
  step (>20) above the far wall's brightest rib shade. Mutation: reverting the body to
  `night-1`/`crystal-1` drops the bright shades and fails the membership and margin checks.

All 44 Python guards pass. The full Godot suite is unaffected (no `.gd` or gameplay change) and was
run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; texture-only on one backdrop layer behind the play field — hazards, foes and telegraphs keep their contrast by construction (verified in `evercrown/drift_well`). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The Evercrown's nearer tendrils now read as lit glass forward of the ribbed wall instead of camouflaging into it — the grade's "ambiguous translucent blocks" closed. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One static asset regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the tendrils stay the Evercrown's magenta stillglass flesh. |

Weighted: 98.7.

## Next

Pass 524: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). The grade's top
open defect — **painterly far backdrops vs the hard-pixel foreground** — wants a watched session for
the per-painter pixel-grain call (parked above with rim light, the letterbox band and a second
foreground band). The strongest remaining code-first item is the grade's **haar/sunken low-contrast
platform read** (pass 505, queued): lift the gameplay-tile contrast against the backdrop in those two
murkiest zones, keeping hazards and foes readable.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it
in.
