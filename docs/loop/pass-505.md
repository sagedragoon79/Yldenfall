# Pass 505: per-zone distance-fog colour on the parallax back layers

## Category

Lighting / depth, from Sean's own queue item (2026-11-07), not the rubric rotation. The art loop is
**blocked** — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK, the
limit of three, and no note frees a slot — so the headline PixelLab work cannot move. Sean's top-queue
request is a lighting-and-depth pass whose two worst grade defects are **flat lighting** and **depth
collapse**; he listed several code-first pieces (per-zone colour grade and tint, room light sources with
directional and rim light, distance fog that fades the parallax toward each zone's fog colour, more
parallax layers, foreground silhouette layers) and stressed combat must stay readable.

This pass takes the **distance-fog-colour** piece — the natural extension of pass 501's atmospheric
perspective, fully code-first and GPU-only, and the one that lifts both depth and zone-to-zone identity
at once. The other pieces (whole-scene colour grade, room lights, foreground silhouettes, extra layers)
are larger and riskier for combat readability; they are named in "Next" and the queue item stays.

No PixelLab generations.

## What was built

Pass 501 recedes the two painted parallax layers (`<zone>_far.png`, `<zone>_mid.png`) by pulling each
toward grey (`desat`) and then toward a dark haze (`fade`) in `shaders/atmosphere.gdshader`, applied per
layer in `Backdrop`. The haze was **one shared colour** for every zone: `night-1` (`Color8(44, 37, 65)`).
So every zone faded into the same blue-violet night — the backdrops receded, but a warm hearth and a cold
spring looked out of the same window, reinforcing the "zone-to-zone incoherence" and "flat, uniform"
reads the grade keeps flagging.

**Per-zone fog colour.** `Backdrop.ZONE_HAZE` now maps each shipped zone to its own distance-fog colour,
with the old `HAZE` kept as the fallback for the gym and any new zone. Each colour is a low shade of the
zone's dominant master-palette hue, blended halfway toward `night-1` — tinted for identity, anchored to
the shared night so the zones still cohere:

| Family | Zones | Fog colour |
| --- | --- | --- |
| Warm hearth | Hearthroot `(58,34,48)`, Spires `(64,37,42)` | ember/gold-warmed brown |
| Green wood | Heartwood `(37,54,51)`, Boughs `(43,83,53)` | mossy / canopy green |
| Cold spring | Haar `(44,60,92)`, Sunken `(37,43,68)` | steam-blue / deep water |
| Crystal | Evercrown `(55,34,68)`, Vorrhallow `(46,39,69)` | stillglass violet |
| Bare stone | Tower `(46,40,62)`, Trials `(46,40,62)` | cold grey |

`Backdrop.haze_for(zone)` resolves the colour (entry or fallback); `set_zone` passes it into
`atmos_material`, which now takes a `haze` argument (defaulting to `HAZE`, so the existing
`atmos_material("far")` call and its test are unchanged). `far` still recedes harder than `mid`; only
the colour each layer lands on is now the zone's own.

The colours are computed from `tools/art/palette.py` (`palette.shade` of the chosen ramp, blended toward
`night-1`); the constant carries a comment to mirror any palette change there.

This is **code-first and GPU-only**: no art is repainted or regenerated, the shader is unchanged, and
there is no per-frame CPU cost — only the colour constant the shader fades toward differs by zone.

## Checks

- **Verified by eye** at 1x and 2x (see captures): across Haar, Heartwood, the Spires and the Evercrown
  the backdrops now recede into visibly different light — Haar cold and steam-blue, Heartwood green, the
  Spires warm, the Evercrown violet — where before every zone faded into the same night. The lit,
  rim-shaded gameplay tiles still pop (the fade strengths are unchanged), so combat stays readable.
- **`tests/test_backdrop.gd`** gains six checks over the existing atmosphere maths: `atmos_material`
  carries the zone haze (not the default); `haze_for` returns a zone's entry and falls back for the gym;
  every shipped zone has a fog colour; every fog colour is dark enough to recede into (not brighten);
  and a warm zone, a cold zone and a green zone are visibly apart in colour. **Mutation-checked:** making
  `haze_for` ignore the zone and always return the default fails both the fallback test and the
  zones-differ test.
- The pure colour maths (`Backdrop.haze_color`) and the shader are untouched, so pass 501's atmosphere
  behaviour is preserved.
- Full local Godot suite green (below); CI test + mix green. No test loads the background PNGs; the
  change is a per-zone constant plus the one call that threads it through, both driven by the new tests.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; fade strengths unchanged, so telegraphs still pop. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 92 | Each zone now recedes into its own distance fog instead of one shared night, so a warm hearth and a cold spring read as different places — lifting zone-to-zone identity on top of passes 500–504's rim shading, atmospheric perspective, softened sky, grass fringe and tile variants. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Pure per-zone colour constant; GPU-only, no per-frame cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 97.95.

## Next

Pass 506: the art loop stays **gated** on Sean — three guardian bases wait for his OK, the limit, so no
new base until he approves one. The rest of Sean's lighting/depth request is the strongest unblocked,
code-first work and splits into coherent passes: a **per-zone whole-scene colour grade** (a subtle
`CanvasModulate` tint per zone, tuned to keep foes and telegraphs popping — the companion to this pass's
fog colour); **room light sources** (`PointLight2D` or drawn emissive glows at lanterns, windows, shrines
and spell light, with gradient falloff, directional key light and rim light on figures, and a contact
shadow under platforms); **foreground silhouette layers** that pass in front of the camera; and the
queued **midground-variant** pass (vary `<zone>_mid.png` so its brick/column field stops repeating). The
whole-scene grade is the natural next step but must be judged hard against combat readability. The hero
sprite (the grade's top defect) needs PixelLab and would be a fourth base — held until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
