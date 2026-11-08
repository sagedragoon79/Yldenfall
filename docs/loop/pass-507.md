# Pass 507: per-zone whole-scene colour grade (TimeTint)

## Category

Lighting / depth, from Sean's own queue item (2026-11-07), not the rubric rotation. The art loop stays
**blocked** — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK, the
limit of three, and no note frees a slot — so the headline PixelLab work cannot move. (Pass 506, the
96-colour palette, is Sean's own PR #567, awaiting his merge; this pass is the next loop number.)

Sean's top-queue request is a lighting-and-depth pass whose two worst grade defects are **flat lighting**
and **depth collapse**. Pass 505 shipped the **distance-fog-colour** piece. This pass takes the
**per-zone whole-scene colour grade** piece — the companion Sean named first and pass 505's "Next"
pointed to: where the fog recedes each zone's *distance* into its own atmosphere, the grade casts its
*light* over the whole frame. Fully code-first, GPU-only (a `CanvasModulate` multiply), no art touched.

No PixelLab generations.

## What was built

`TimeTint` is the scene's single `CanvasModulate`. Until now it was white (identity) except while the
Stillstone held time, when it drained the world to a pale blue. It now carries a **per-zone cinematic
colour grade** the rest of the time.

**`TimeTint.GRADE`** keys a grade colour by zone, in the same families as `Backdrop.ZONE_HAZE` so the
grade and the fog agree:

| Family | Zones | Grade |
| --- | --- | --- |
| Warm hearth | Hearthroot, Spires | `(1.0, 0.955, 0.86)` warm gold |
| Green wood | Heartwood, Boughs | `(0.93, 1.0, 0.92)` mossy green |
| Cold spring | Haar, Sunken | `(0.90, 0.955, 1.0)` steam-blue |
| Crystal | Evercrown, Vorrhallow | `(0.97, 0.90, 1.0)` stillglass violet |
| Bare stone | Tower, Trials | `(0.95, 0.96, 0.99)` cold grey |

`NEUTRAL` (white, an identity multiply) is the fallback for the gym and any new zone. `grade_for(zone)`
resolves the colour; `target_for(zone, stopped)` is the pure target the modulate lerps toward — the
pale-blue `STOPPED` tint overrides everything while time is held, otherwise the zone's own grade. `World`
sets the tint's zone on each room change (`set_zone`); on the very first room the tint is built with the
camera and seeded from the placed room, after `_enter` has already set the backdrop zone.

**Combat stays readable, by construction.** Two rules, both tested:

- **Every grade is high-key**: each channel `>= 0.84` and luminance `>= 0.9`, so the multiply shifts hue
  and mood without darkening the scene.
- **A uniform multiply preserves contrast ratios**: the same factor hits every pixel, so relative
  separation is untouched — foes, hazards and telegraphs keep their pop, and the grade cannot cause the
  value-collapse the request warns against.

This is **code-first and GPU-only**: no art repainted, no per-frame CPU cost beyond the existing
modulate lerp.

## Checks

- **Verified by eye** at 1x and 2x (see captures): across Hearthroot, Heartwood, the Haar and the
  Evercrown the whole frame now carries its zone's light — a warm hearth, a green wood, a cold spring and
  a violet crystal hall each read as different light — while the hero, foes and telegraphs keep their
  separation (a uniform multiply). The Stillstone still drains the world to pale blue.
- **`tests/test_time_tint.gd`** (new, 9 tests) drives the pure grade and target logic: every shipped zone
  has a grade; an unknown zone is neutral white; a grade actually tints (not white); every grade keeps
  each channel `>= 0.84` and luminance `>= 0.9`; the families are distinct (warm redder/less blue than
  cold, canopy greenest, crystal magenta); a family shares one grade; the Stillstone overrides the grade
  everywhere; without it the target is the zone grade; `set_zone` tracks the room. **Mutation-checked:**
  making `grade_for` ignore the zone (always `NEUTRAL`) fails the tint, family-distinct and family-shared
  tests; dropping any channel floor fails the readability test.
- The time-stop behaviour (8, A8) is preserved: `target_for(zone, true)` is `STOPPED` for every zone.
- Full local Godot suite green (below); CI test + mix green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; grade is a uniform multiply, so telegraphs keep their contrast. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 92 | Each zone now casts its own light over the whole frame, on top of pass 505's per-zone distance fog — the fog recedes the backdrop, the grade lights the scene, and the two share families, so a warm hearth and a cold spring read as wholly different places. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged; the Stillstone's time-stop tint still overrides the grade. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Pure per-zone colour constant; GPU-only, no per-frame cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 97.95.

## Next

Pass 508: the art loop stays **gated** on Sean — three guardian bases wait for his OK, the limit, so no
new base until he approves one. The rest of Sean's lighting/depth request is the strongest unblocked,
code-first work: **room light sources** (`PointLight2D` or drawn emissive glows at lanterns, windows,
shrines and spell light, with gradient falloff, directional key light and rim light on figures, and a
contact shadow under platforms) — the largest remaining piece and the one that most lifts "flat
lighting"; **foreground silhouette layers** that pass in front of the camera for depth; **more parallax
layers**; and the queued **midground-variant** pass (vary `<zone>_mid.png` so its brick/column field
stops repeating). Room lights are the natural next step but must be judged hard against combat
readability. The hero sprite (the grade's top defect) needs PixelLab and would be a fourth base — held
until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
