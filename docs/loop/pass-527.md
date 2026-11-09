# Pass 527: floor spikes read on any floor with a double rim

## Category

Combat readability / art cohesion, from the independent grade (pass 525) and the queue. The grade
flagged **dark-on-dark hazard readability**: "Ground spikes and floor blades sit dark on dark floors
and are easy to miss." It is the first actionable queue item — items 0–1 (the letterbox band above the
far layer, and rim light on figures) are parked for a watched combat-readability call, and the Boughs
painterly/pixel clash below it is the same far-layer pixel-grain family a prior pass (523) already
regressed on, so it is parked for a watched session too.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK — the limit of three — and no new note frees a slot, so no new base or
animation can begin (the key is set; the moment a base is approved the Haar Wyrm animation can start).

## What was built (design bible 12.24)

The two static floor hazards are the floor spikes (`^`, `Spikes`) and the thorn bulb (`o`,
`ThornBulb`). The thorn bulb is already a bright red glowing pod and reads fine; the floor spikes were
the offender — a pale lavender-grey body (`b9b4c4`) over a mid shade (`6f6982`), both **off the master
palette**, whose silhouette sank into the near-black floors of the Haar and the Evercrown.

A hazard has to read on *every* floor it is dropped on, so a single value shift cannot fix it:
brightening it for the Haar glares it over the pale heartwood, darkening it for the heartwood hides it
in the Haar. `Spikes._draw` is redrawn with a **double rim** that carries on any backdrop, all four
tones pulled onto the master palette's neutral ramp:

- a dark iron **silhouette** (`2f2c3a`) plus a contact shadow at the base — the read over a *pale*
  floor;
- a near-white steel **rim** down each leading edge and a hot **tip** cap (`ece8ed`) — the bright line
  the eye finds over a *dark* floor;
- a mid-steel **lit face** (`867ba2`) between them.

Pure `_draw` art: the collision shape (`14×9` at `y −4.5`), the `hazard`/`pogo` groups and the spike
geometry are untouched, so there is no change to the actor or gameplay layer — only how the tile paints
itself.

## Verified by eye (1x and 3x)

Rendered in `haar/fog_cut` (a dark zone with a long spike row), before and after:

- **Before:** a dim grey row with soft lavender tips, low-contrast against the near-black floor — the
  "easy to miss" the grade named.
- **After:** a crisp line of lit metal teeth; the near-white rims and tips pop against the dark floor,
  and the dark silhouette still seats them. The warm lamp pools and the player read unchanged around
  them.

Readability on pale floors is held by construction (the dark silhouette and base shadow) and by the
test's silhouette-value floor; nothing else in the scene changed.

## Tests

`tests/test_animation.gd` gains one mutation-checked guard (it already loads the master palette for the
sheet guards):

- **`test_floor_spikes_read_on_any_floor_and_stay_on_palette`** — every spike tone
  (`SILHOUETTE`, `FACE`, `RIM`, `BASE`) is on the master palette, the rim/tip is near-white
  (luminance ≥ 0.80) so it reads over a dark floor, the silhouette is dark (≤ 0.30) so it reads over a
  pale one, and the rim–silhouette spread is wide (≥ 0.55) so the hazard never sinks into its floor.
  Mutation: reverting the rim to the old off-palette `b9b4c4` fails three checks (palette membership,
  near-white rim, and value spread).

The full Godot suite was run green; CI (test + mix) green. No `.gd` logic, no tilegen and no gameplay
change — only `Spikes._draw` and the new guard.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 98 | The grade's dark-on-dark hazard defect closes: floor spikes read as a hazard on every floor, the dark zones included, with no change to the collision, the pogo or the geometry. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The floor spikes move from two off-palette tones to four master-palette ones, so the hazard is on the ramp as well as legible. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Pure `_draw`; no new work per frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.6.

## Next

Pass 528: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab key
is set, so the moment a base is approved the Haar Wyrm animation can begin). The strongest remaining
unattended item is the queued **VFX pass**: try PixelLab's free VFX tool on one code-drawn effect (a
sword hit or a guardian death burst), play it in Godot next to the current effect, and keep it only if
it reads better against the enemy style guide. The grade's other code-first items — the Boughs
painterly/pixel clash and the crushed-black far layers — are the far-layer pixel-grain family parked
for a watched session (pass 523 regressed on it), alongside rim light on figures, the letterbox band
and a second foreground band.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
