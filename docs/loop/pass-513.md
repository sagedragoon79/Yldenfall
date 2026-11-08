# Pass 513: ease the two murkiest zones toward a paler, neutral haze

## Category

Art cohesion / combat readability, from the queue — pass 512's named next item, the
**haar/sunken low-contrast pass** (independent grade, pass 505: the swamp and underwater zones
collapse into grey-green / grey-teal so the play field does not separate from the backdrop). The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three, and no new note frees a slot, so the headline
guardian/hero work cannot move. This pass takes the strongest code-first, fully testable item left:
a self-contained tune to two `ZONE_HAZE` entries, judged by the same contrast concern the grade
raised.

Sean's own top queue item (lighting/depth) is parked on its last piece, **rim light on figures**,
which the run of passes 505/507/509/510/511 left as the one piece best landed when combat
readability can be watched live, not in an unattended loop pass.

## What was built

The per-zone distance fog (`Backdrop.ZONE_HAZE`, bible 12.5, pass 505) gives each zone its own
colour to fade the painted parallax backdrop into. The two murkiest zones — the **Haar** and the
**Sunken Spring** — had the darkest, most saturated fogs of the ten (`haar` a saturated dark blue,
`sunken` a dark grey-teal). The independent grade (pass 505) read both as a low-contrast
grey-green / grey-teal where the dark play field merged into the dark backdrop.

Both entries are now **desaturated toward neutral** (`scripts/world/backdrop.gd`, bible 12.5):

- `haar`: `Color8(44, 60, 92)` → `Color8(74, 84, 98)` — a saturated dark blue becomes a paler slate.
- `sunken`: `Color8(37, 43, 68)` → `Color8(56, 62, 80)` — a dark grey-teal becomes a lighter mist.

Pulling the saturation out lifts each colour's luminance while its HSV **value stays under the
`.v < 0.4` dark-tone cap** (the existing `test_every_zone_haze_is_a_dark_tone` still holds), so the
backdrop recedes as a paler mist and separates from the dark play field without the night mood
breaking. Both keep their **cool-blue lean** (blue is still the strongest channel), so the Haar and
the Sunken still read cold, not washed grey.

Readability is untouched **by construction**: only the backdrop parallax layers carry the haze
(`atmos_material`); the tiles, hazards and foes are drawn in front of it and keep their own
contrast. The change moves the far backdrop's value, not the play field's.

Verified by eye: screenshots of the Haar (`haar/marsh_road`) and the Sunken Spring
(`sunken/source_hall`), before and after — the backdrop glow pools and arches sit back as a paler,
more neutral haze and the reeds, platforms, hero and foe in front of them read with more
separation, while the zones stay cold and night-dark.

## Tests

`tests/test_backdrop.gd` gains `test_the_murkiest_zones_are_eased_toward_neutral`, which holds both
eased zones to the rule:

- **Eased toward neutral.** Saturation `< 0.38` (the old saturated murk fails this).
- **Still dark.** HSV value `< 0.4` (the dark-tone cap is not broken).
- **Lifted to a paler mist.** Rec. 601 luminance `> 0.22` (not a dark merge).
- **Still cool-blue.** Blue is the strongest channel (the cold lean is kept).

**Mutation-checked:** reverting `haar` to its old `Color8(44, 60, 92)` fails the test (saturation
0.52 > 0.38); verified by patching and running the filtered suite, then reverted. The existing
`test_every_zone_haze_is_a_dark_tone` and the fade tests stay green (17 + 8 checks across the haze
filter).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the haze lives only on the backdrop parallax, behind the play field — tiles, hazards and foes keep their contrast by construction. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 96 | The two murkiest zones no longer collapse the backdrop into the play field — the grade's haar/sunken low-contrast flag (pass 505). Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511) and carved-sign (512) work. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged; the Drowned Warden's Sunken arena reads with a cleaner backdrop separation. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two constants changed; no new work per frame. |
| Story and world | 5 | 99 | Unchanged; the Haar and Sunken stay cold and night-dark. |

Weighted: 98.6.

## Next

Pass 514: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab
key is set, so the moment a base is approved the Haar Wyrm animation can begin). The strongest
remaining code-first item is the **midground-variant masonry** pass — vary `<zone>_mid.png` and the
far layers' masonry so the backdrop brick/column field stops reading as one repeated stamp (scatter
wear, shade variation, broken courses; grade pass 504). Sean's **rim light on figures** is the
highest-value lighting piece but wants a watched session, not an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take
a thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires
it in.
