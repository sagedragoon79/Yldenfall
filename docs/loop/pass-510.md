# Pass 510: foreground silhouette layers that pass in front of the camera

## Category

Lighting / depth, from Sean's own queue item (2026-11-07), not the rubric rotation. The art loop stays
**blocked** — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK, the
limit of three, and no note frees a slot — so the headline PixelLab work cannot move. (Pass 508, PR #569,
the four-tall passages for the 2x hero, is Sean's own merge, held; this is the next loop number.)

Sean's top-queue request is a lighting-and-depth pass. Pass 505 shipped the **distance-fog colour**,
pass 507 the **per-zone whole-scene colour grade**, pass 509 **room light sources** — all behind or over
the play field. This pass takes the piece that passes *in front* of it, which pass 509's "Next" named:
**dark foreground silhouette layers**. Sean named Blasphemous and The Last Faith, which get much of their
depth from a dark near-ground layer sliding past in the foreground. Fully code-first: the art is painted
by `tilegen` (deterministic Pillow, no PixelLab), drawn by a GPU parallax layer, no per-frame cost.

## What was built

A new **foreground parallax layer** (design bible 12.11), the layer in front of the play field:

**The art** — `tools/art/tilegen.py` paints one `<zone>_fore.png` per shipped zone (`FORE_KIND`): a
near-black silhouette (`night-0` body, a faint `night-1` top/leading rim) of the zone's own material,
rising from a solid ground band over an otherwise transparent canvas.

- **Ferns** (Heartwood, the High Boughs) — tapering fronds with leaflets.
- **Reeds with cattails** (the Haar, the Sunken Spring).
- **Crystal shards** (the Evercrown, Vorrhallow) — sharp faceted spikes.
- **Rock rubble** (the Tower, the Trials) — jagged stone mounds.
- **Timber posts** (Hearthroot, the Spires) — the hearth-village fence line.

The shapes keep to the bottom third, so the centre stays clear, and the band and protrusions are drawn
slightly see-through (alphas 242 / 206), so a telegraph behind a reed still reads.

**The layer** — `Backdrop.fore_layer(zone)` builds it as a `Parallax2D` and `set_zone` adds it after the
back layers:

- **Near and in front.** It scrolls faster than the camera horizontally (`FORE_SCROLL.x` = 1.5), so it
  reads as close and slides past as the player walks, and is locked to the camera vertically
  (`FORE_SCROLL.y` = 1), so the ground band always frames the view bottom with no gap — whatever the
  room's height. Its `z_index` is an absolute `FORE_Z` (5, with `z_as_relative` off so the backdrop
  node's own `z_index` −50 does not drag it back), above the atmosphere overlays (fog, motes, rain at 4)
  and every actor and projectile (≤ 3): the nearest thing on screen.
- **No haze.** Unlike the receding back layers it carries no atmosphere material; a near foreground is
  sharp and dark, not greyed into the distance.
- **Only where art exists.** A zone with no `<zone>_fore.png` (the gym, any new zone) gets no layer and
  draws exactly as before.

Verified by eye at 1x in Heartwood (deep_roots), the Haar (drowned_stair), the Evercrown (drift_well)
and the Haar Wyrm arena (spring_of_haar): the silhouette frames the bottom, slides in front of the floor
and decor, and the play field, platforms, lamps and player stay clearly readable.

## Tests

`tests/test_backdrop.gd` (3 new tests): the scroll/z contract (fast horizontal, locked vertical, z above
the overlays and the actors), the layer build for a zone with art (absolute high z, the foreground
scroll, the silhouette sprite, no haze material), and no layer for a zone without art (gym, unknown).

`tools/art/test_tilegen.py` (4 new tests, run locally — CI runs no Python): every shipped zone has a
foreground and the gym none; the silhouette is bottom-weighted and clear up top (combat readability); the
ground band reaches the very bottom edge; and no opaque pixel is brighter than the night shades (a dark
silhouette).

**Mutation-checked:** filling the top band instead of the bottom fails the bottom-weighting guard;
painting the body in a lit colour fails the darkness guard; turning `z_as_relative` on, or dropping
`FORE_Z` to 3, fails the backdrop scroll/z tests.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The foreground keeps to the bottom edge, is thin and see-through, and leaves the centre clear, so foes and telegraphs still pop (checked in the Haar Wyrm arena). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 93 | The scene now has a near layer passing in front of the play field — the depth cue Blasphemous and The Last Faith lean on — on top of the receding fog (505), whole-scene grade (507) and room-light pools (509). Each zone's foreground is its own material, so it belongs to its world. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged; the Haar Wyrm arena stays fully readable with the reed foreground. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A static parallax sprite layer per room; GPU-only, no per-frame CPU cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.10.

## Next

Pass 511: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The last unblocked
pieces of Sean's lighting/depth request are **rim light on figures** (a directional key edge on the
player and foes, so a lit figure separates from its backdrop) and **more parallax layers** (a third
painted layer between far and mid, or a second foreground band). Rim light on figures is the natural next
step and the one that most lifts the hero's read, but it must be judged hard against combat readability.
The queued **midground-variant** pass (vary `<zone>_mid.png` so the backdrop brick stops repeating) is the
strongest non-lighting code-first item. The hero sprite (the grade's top defect) needs PixelLab and would
be a fourth base — held until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
