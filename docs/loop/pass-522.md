# Pass 522: the lantern and mushroom glow pools on the ground

## Category

Atmosphere and lighting, from the queue — the independent grade's (pass 520)
flagged **cheap radial lantern/mushroom glow**: "lantern and glow-mushroom light
is drawn as soft circular gradients that ignore the surfaces they sit on
(heartwood, haar), reading as pasted-on blobs rather than integrated light. Shape
the glow to its source/surface … so it looks lit, not stamped." This is the pick
pass 521's *Next* named as the strongest remaining fully code-first, unattended
item.

The higher queue items stay blocked for an unattended pass: the far-sky empty band
(0) and rim light on figures / a second foreground band (1) are parked for a
watched combat-readability call; the PixelLab art loop (2) is gated on Sean, with
three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) already awaiting
his OK — the limit of three — and no new note frees a slot. No PixelLab spend this
pass.

## What was built (design bible 12.10)

`RoomLight` drew every fixed source's pool as a **symmetric radial disc** centred
on the source (`pool_texture` filled from `falloff(distance)`). A lamp, a shrine
rune or a glow-mushroom therefore glowed as far up into the empty air as down onto
the ground — a disc floating over the scene, the grade's "pasted-on blob". The
fix shapes the falloff so the glow hugs its surface:

- **`shaped_alpha(nx, ny)`** replaces the plain radial sample. With `ny` positive
  downward (toward the ground), the air above the source (`ny < 0`) is tightened
  hard (`UP_TIGHTEN` 2.1, so the upward reach is less than half a disc's), and
  below it (`ny > 0`) the pool reaches the floor (`DOWN_REACH` 0.94) and widens
  across it (`GROUND_SPREAD` 0.7, easing the x-distance down for the rows below the
  source). A lantern or glow-mushroom now casts a pool *on the ground* that spreads
  where it lands, instead of a ring floating in the air.
- **The cap and ordering are untouched.** The source still sits at the texture
  centre (`nx = ny = 0` is full brightness), so each pool's centre still adds
  exactly `colour * peak` with `peak ≤ READABLE_CAP` (0.16), and the overlay still
  draws under every actor. Only the *shape* of the light changed — not how bright
  it is, nor what it sits over — so combat readability is unchanged by
  construction.

GPU/texture-only, static (gathered once per room, no per-frame cost), no art
regenerated and no gameplay touched. The bible's 12.10 was also brought current: it
still described the pre-pass-509 "`STEPS` concentric filled circles / `rings`"
implementation that the single-quad `falloff`/`pool_texture` had already replaced.

Judged by eye at 1x and 2x in `heartwood/lantern_grotto` (wall lantern + cyan
fungus) and `heartwood/deep_roots` (a gold ledge lantern + floor fungus), before
and after: the gold lantern now casts its light down onto the wall and floor
beneath it rather than ballooning symmetrically, and the cyan fungus reads as a
flatter pool on the ground. Foes, pickups and telegraphs keep their contrast (the
pools are still capped and under the actors).

## Tests

`tests/test_room_light.gd` gains four tests that drive the pure shaping maths
directly (as the existing `falloff` test does), all mutation-checked against
flattening the shaping (`UP_TIGHTEN = DOWN_REACH = 1.0`, `GROUND_SPREAD = 0.0`):

- **`test_roomlight_pool_peaks_at_its_source`** — `shaped_alpha(0, 0) == 1`, so the
  centre still adds the capped peak. (Holds under the mutation — the cap contract is
  independent of the shaping, as intended.)
- **`test_roomlight_pool_casts_down_not_up`** — at equal distance the pool is
  brighter below the source than above it. Mutation: a symmetric disc makes them
  equal and fails.
- **`test_roomlight_pool_tightens_above_the_source`** — the upward reach is strictly
  less than a plain circle's. Mutation: `UP_TIGHTEN = 1` makes it equal and fails.
- **`test_roomlight_pool_widens_across_the_floor`** — at equal distance a point out
  across the floor stays lit where a point straight down has faded. Mutation:
  `GROUND_SPREAD = 0` makes the sideways point the dimmer of the two and fails.

The RoomLight suite runs 10 tests / 47 checks green; under the flattening mutation
the three shaping tests fail (7 checks), confirming the guards bite. The full Godot
suite was run green (below); CI (test + mix) green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the pools are still capped at `READABLE_CAP` and drawn under every actor — only the shape of a pool changed, never its brightness or what it sits over, so foes and telegraphs keep their read (verified by eye). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | Unchanged; the shaping keeps the lit look consistent. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Still gathered once per room, no per-frame cost; one shared texture, now shaped. |
| Story and world | 5 | 99 | Unchanged. |
| Atmosphere and lighting | — | — | The grade's "cheap radial lantern/mushroom glow" is addressed: a source's pool now casts onto the surface below it and spreads across the floor, reading as integrated light rather than a floating disc. |

Weighted: 98.7 (lighting read lifted within Atmosphere; the headline gap stays the
gated HD art).

## Next

Pass 523: the art loop stays **gated** on Sean (three guardian bases wait, the
limit; the PixelLab key is set, so the moment a base is approved the Haar Wyrm
animation can begin). With the lantern glow shaped, the strongest remaining
code-first, unattended items from the pass-520 grade are the **painterly backdrops
vs hard pixel foreground** (queued) — bring the anti-aliased far layers' dither
into the pixel grid so background and foreground read as one medium — and the
older **zone-to-zone style incoherence** (unify outline weight and light direction
across zone tilesets, pull base hues toward the master palette), both chipped at
but not closed. Sean's **rim light on figures** and a **second foreground band**
stay the highest-value lighting pieces but want a watched session for the
combat-readability call.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar
marshes** could take a thin, slow drizzle and the High Boughs an even fainter
mist-rain — say the word and a pass wires it in.
