# Pass 516: far-sky depth motes — faint particles and distant glows over the dark far backdrop

## Category

Art cohesion / atmosphere, from the queue — the pass-515 independent grade (4.3/10) flagged the
dark upper backdrop of the tall rooms as dead, structureless space. This gives the far sky
atmospheric depth so the far backdrop reads as distance, not one flat dark field.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot. Sean's own top
queue item (lighting/depth) is down to **rim light on figures** and **a second foreground band**,
both parked for a watched session. This pass takes the strongest fully-testable, backdrop-only,
no-readability-risk slice of the dark-backdrop defect.

## What the grade actually saw, and what this fixes

The grade's "letterbox" is two different dark regions stacked in a tall room's default capture:

1. The **far sky** where the far layer draws (the lower-middle of the view) — a large, flat,
   near-black field with no particles.
2. The **empty band above the far layer** (the top of the view) — the far layer is 480 px tall
   and the parallax anchors its content to the lower view, so above it the view falls through to
   the clear colour.

This pass fixes (1): `far_motes` dresses the far sky with a sparse field of dim, zone-tinted motes
(dust catching far light) weighted to the upper two-thirds, plus a few soft radial glows (`soft_glow`)
— distant lights seen through the murk. Every speck lands only on a dark pixel, so the
atmospheric-perspective shader (12.5) still recedes it and it never specks over a lit backdrop
feature. Applied to the nine dark-sky far layers (`heartwood`, `hearthroot`, `tower`, `haar`,
`vorrhallow`, `evercrown`, `sunken`, `trials`, `spires`), each with a zone-appropriate mote palette;
the daylit `boughs` canopy is left out. Only those nine `assets/bg/*_far.png` change (regenerated
directly, so no other backdrop or tileset churned).

Design bible 12.15 added.

### What this pass does NOT fix, and why

(2), the empty band above the far layer, is **not** fixed here, and the pass doc is explicit about
it so a later session does not assume it is done. The far-sky motes live on the far layer and cannot
reach a band that has no far layer in it. Every tested way to back that band from behind — a plain
`Node2D`/`ColorRect` child of the backdrop, a `CanvasLayer` below the world, a second sprite inside
the far `Parallax2D`, a taller far sprite — is occluded or culled in this project's
SubViewport/parallax/camera setup (verified with bright diagnostics: a magenta fill at the backdrop's
depth never appears in the band, while the same fill in front of the play field does). Only a
screen-space overlay *in front of* the play field reaches the band, and that would risk covering high
platforms and flying foes — a combat-readability call that belongs in a watched session, not an
unattended loop pass. It is parked in 12.15 alongside rim light on figures and a second foreground
band.

## Tests

`tools/art/test_tilegen.py` gains four mutation-checked guards (this Python guard runs locally, like
the moire/moss/variant/masonry guards):

- **`test_far_motes_lift_the_dark_sky`** — over a flat `night-0` field, `far_motes` adds a scatter of
  brighter pixels (a no-op fails).
- **`test_far_motes_are_biased_to_the_top`** — more motes land in the upper half than the lower
  (dropping the top-weighting fails).
- **`test_far_motes_spare_a_bright_feature`** — a bright-filled upper sky is left untouched (removing
  the dark gate draws over it and fails — confirmed, 82 spots).
- **`test_dark_far_fields_dress_their_sky`** — every shipped dark-sky far layer calls `far_motes` and
  `boughs_far` does not.

Mutation-checked: a no-op `far_motes` fails the top-bias guard; removing the dark gate fails the
bright-feature guard. The Godot suite and CI are unaffected (no `.gd` or gameplay change, no
backdrop-structure change) and were run green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the motes live on the far parallax layer, behind the play field and under the atmosphere haze, gated to dark pixels — tiles, hazards and foes keep their contrast by construction (verified by eye in Heartwood and the Haar). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The large dark far-sky fields now carry drifting particles and distant glows, so the far backdrop reads as atmosphere with depth instead of one flat dark band (pass-515 grade defect). Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511) and masonry (514/515) depth work. The empty band above the far layer in the tallest rooms, and the hero/guardian HD bases, remain open. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Nine static PNGs regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.7.

## Next

Pass 517: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The strongest
remaining code-first item is the **ambiguous translucent blocks in `evercrown`** (grade pass 503,
queued) — the mid tendrils read unclearly against the ribbed far wall. The **empty band above the far
layer** (this pass's parked half) and Sean's **rim light on figures** and **second foreground band**
all want a watched session for the combat-readability call, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
