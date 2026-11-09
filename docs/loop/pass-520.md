# Pass 520: zone style cohesion — the procedural flat-tile zones toward the painterly bar

## Category

Art cohesion, from the queue — the independent grade's (pass 515) **zone-to-zone style
incohesion**, the first unblocked item and the one pass 519's "Next" named: "the painterly
Market/Plaza versus the flat cartoon tile-grass of Heartwood and the Haar." The grade read the game
as two different games — the PixelLab-textured painterly zones (Hearthroot's Market and Plaza,
`PIXELLAB_SETS`) against the procedural flat-tile zones **Heartwood** (`paint_wood`) and **Haar**
(`paint_limb`), whose note called them "flat cartoon tile-grass with straight-shelf platform tops."

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot, so no new base or
animation can begin. Sean's lighting/depth item is down to **rim light on figures** and a **second
foreground band**, and the grade's dark-band-above-the-far-layer defect is parked — all want a
watched session for the combat-readability call, not an unattended loop pass. This pass takes the
strongest fully-testable item left, pulling the two named flat zones toward the painterly bar
procedurally (no PixelLab spend), with no readability risk.

## What was built (design bible 12.19)

The painterly bar is set by Hearthroot's PixelLab tileset; it cannot be given to Heartwood and Haar
without PixelLab spend (and the bases are at the limit). So the two zones are pulled toward it
procedurally, on the two signals the grade named:

- **A sculpted mossy crown (`cap_moss`, new `sculpt` flag).** The flat cap left the tile's opaque
  top row intact between blades, so every ledge top read as one razor-straight shelf. The sculpted
  cap carves a one-world-pixel dip between tufts, in clumps of a few columns, while tall blades keep
  their height and stand proud — so a run of ledge tops reads as an uneven crown, not a straight
  shelf. The upper fringe also runs a shade deeper (`mute`), pulling the neon grass trim toward the
  dressed-stone lip of the painterly zones. Only Heartwood and Haar carry the new `cap_sculpt` key;
  the other six moss-capped zones keep the flat cap (12.7) unchanged.
- **A mottled wood face (`paint_wood`).** The face was one flat, low-contrast grain field. It now
  carries a low-frequency value patch (roughly 6×6 render-pixel cells lift or drop a broad region a
  shade) and the odd dark fleck, so the heartwood reads as mottled bark with surface value variation
  like the masonry zones. `paint_wood` feeds Heartwood directly and Haar through `paint_limb`, so the
  two named zones change and no other painter is touched.

Only `assets/tiles/heartwood.png` and `assets/tiles/haar.png` were regenerated. Both atlases are
deterministic (regenerated twice to identical bytes); the non-deterministic `_mid` backdrop re-saves
that a full `tilegen` run produces on this machine were reverted, so the diff is the two tile atlases
alone. The Godot import cache was refreshed (`--headless --import`) before capture, since the running
game otherwise serves the cached texture.

Combat is untouched by construction: the change is texture-only on two tilesets, and the patches are
low-contrast within the dark bark, so hazards, foes and telegraphs (which hold reserved accent
colours) keep their contrast. Verified by eye at 1x/2x in `heartwood/entrance` (the walls read as
mottled bark, the grass lip is deeper and uneven; the hero, platforms, grubs, mushrooms and pickups
still pop) and `haar/marsh_road` (the pale limb-stone walls read more textured; the fog pockets,
hazard, pickups and mushroom still pop).

## Tests

`tools/art/test_tilegen.py` gains three mutation-checked guards (this Python guard runs locally, like
the moire/moss/variant/masonry guards before it):

- **`test_cap_moss_sculpt_carves_the_silhouette`** — across a range of seeds the sculpted cap leaves
  strictly more top-row pixels transparent than the flat cap (the carved crown). Mutation: dropping
  the `crown` carve ties the two (0/12) and fails.
- **`test_cap_moss_sculpt_is_a_deeper_fringe`** — the sculpted tile's mean leaf shade is darker than
  the flat tile's on nearly every seed. Mutation: dropping `mute` ties them and fails.
- **`test_paint_wood_has_surface_value_variation`** — the wood face spans ≥3 shades with no single
  shade over 80% of the face. Mutation: removing the patch term collapses it toward two shades and
  fails the spread or the dominance.

All 40 Python guards pass. The full Godot suite is unaffected (no `.gd` or gameplay change) and was
run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; texture-only on two tilesets, low-contrast patches within the dark bark — hazards, foes and telegraphs keep their contrast by construction (verified in `heartwood/entrance`, `haar/marsh_road`). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The two procedural flat-tile zones the grade singled out — Heartwood and Haar — now carry a sculpted, deeper mossy lip and a mottled wood face, closing the biggest readable gap against the painterly PixelLab zones. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two static assets regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the Heartwood keeps its living-wood face and the Haar its fog-bleached drowned limbs. |

Weighted: 98.7.

## Next

Pass 521: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). With the flat-tile
zones now pulled toward the painterly bar, the strongest remaining code-first item is the grade's
**ambiguous translucent blocks in `evercrown`** (pass 503, queued) — the mid tendrils read unclearly
against the ribbed far wall. Sean's **rim light on figures** and a **second foreground band** stay the
highest-value lighting pieces but want a watched session for the combat-readability call, not an
unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it
in.
