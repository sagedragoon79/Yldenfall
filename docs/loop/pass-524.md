# Pass 524: warm play tiles in the murkiest zones (Haar and Sunken Spring)

## Category

Art cohesion / combat-readability, from the queue and the latest independent grade. Pass 523's
"Next" named the strongest remaining **code-first, unattended-safe** item: the grade's **haar/sunken
low-contrast platform read** (pass 505, queued) — in the two murkiest zones the standable geometry
merged into the cool backdrop and mist. It is also the first actionable queue item: queue items 0–1
are parked for a watched combat-readability call, and item 2 (the PixelLab art loop) is gated.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK — the limit of three — and no new note frees a slot, so no new base
or animation can begin (the key is set; the moment a base is approved the Haar Wyrm animation can
start). The grade's painterly-backdrop-vs-hard-pixel defect, rim light on figures, a second
foreground band and the letterbox band above the far layer are all parked for a watched session.

## What was built (design bible 12.22)

The Haar and the Sunken Spring were read by the independent grade (pass 505) as a low-contrast
grey-green / grey-teal where the play field and backdrop merged. Pass 513 eased the **backdrop**
half (desaturating those two `ZONE_HAZE` entries so the mist recedes paler, 12.5). This pass eased
the **play-field** half, by temperature.

Both zones painted their solid tiles on the cool `"stone"` ramp (a blue-violet lavender) — the same
temperature as their cool mist and backdrop masonry, so the play field had no hue to separate it. In
the Sunken Spring the pale limestone terraces read as the same material as the aqueduct piers behind
them; in the Haar the whole scene was one green-grey wash where only the warm planks read. Their
`ZONES` entry (`tools/art/tilegen.py`) now uses the warm `"umber"` ramp. Both painters already
describe a warm material — `paint_limb` a drowned limb's "old bone", `paint_spring` "pale limestone"
— so umber reads as lit bone and travertine, warm against each zone's cool backdrop.

Untouched, so the split is purely a play-field-vs-backdrop temperature contrast: the night-cool
outline and underside (`night-0` / `night-1`), the moss and sky caps, the Sunken's cyan mineral
stain, and every hazard and foe (drawn separately as sprites). The one-way planks keep their own
per-zone material (12.20).

Measured on the solid fill tile, the body is warm (mean R − B ≈ **+23** Haar, **+26** Sunken)
against each zone's cool haze (R − B = **−24**) — a ~47–50 point temperature split the eye reads at
a glance.

## Verified by eye (1x and 2x)

`haar/drowned_stair` and `sunken/wellspring`, before and after:

- **Sunken Spring:** the limestone terraces now read as warm travertine clearly forward of the cool
  teal aqueduct piers and the cyan water line; the player, platforms and plank all separate.
- **The Haar:** the drowned bone-limb walls and ground read warm against the green mist instead of
  dissolving into it; the moss cap line and lantern pools are unchanged.

Combat readability is untouched by construction: hazards, foes and telegraphs are separate sprites
and the backdrop is drawn behind the play field.

## Tests

`tools/art/test_tilegen.py` gains one mutation-checked guard (this Python guard runs locally, like
the moire/moss/variant/masonry/plank/tendril guards before it):

- **`test_haar_and_sunken_play_tiles_read_warm_against_their_cool_backdrop`** — the fully-solid
  interior tile for each of `haar` and `sunken` reads warm (mean R − B ≥ +10) against the zones' cool
  `ZONE_HAZE` (R − B = −24). Mutation: reverting either ramp to `"stone"` makes the body cool (Haar
  R − B = −13.6) and fails.

All 45 Python guards pass. The full Godot suite is unaffected (no `.gd` or gameplay change; only two
static tilesets regenerated) and was run green; CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; texture-only on two backdrop-adjacent tilesets — hazards, foes and telegraphs are separate sprites and keep their contrast by construction (verified in `haar/drowned_stair`, `sunken/wellspring`). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The two murkiest zones' play tiles now separate from their cool backdrops by temperature — the grade's "haar/sunken low-contrast platform read" closed (pass 513 did the backdrop half). The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two static assets regenerated; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the tiles stay drowned bone (Haar) and spring limestone (Sunken), now the warm materials their painters already describe. |

Weighted: 98.7.

## Next

Pass 525: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). The grade's top open
defect — **painterly far backdrops vs the hard-pixel foreground** — wants a watched session for the
per-painter pixel-grain call (parked with rim light, the letterbox band and a second foreground
band). The strongest remaining code-first item is the queued **mid-ground / backdrop brick still
tiles** (pass 504, queue): vary the `<zone>_mid` painters so the parallax brick/column fields stop
reading as one repeated 32 px stamp (a companion to the far-layer masonry sweeps of passes 514/515/519).

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it
in.

## Pre-existing drift noticed (not touched)

Re-running `tools/art/tilegen.py` (deterministic) regenerates six `*_mid` backdrops
(`boughs`, `haar`, `hearthroot`, `heartwood`, `spires`, `trials`) that differ from the committed
PNGs — the committed versions are stale relative to the current generator. This pass restored those
six to `origin/main` to stay scoped to the two tilesets it actually changes; the drift is left for a
dedicated regen pass to avoid bundling unrelated backdrop churn here.
