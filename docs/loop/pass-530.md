# Pass 530: the hit spark opens on a small hot star at the blade tip

## Category

The top defect of the pass-529 independent grade (4.6/10): the new hit spark's opening frame is a
flat yellow disc that covers the target and the blade in pictures of a landed hit. Combat
readability and art cohesion.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first item
(rim light on figures and the rest of the lighting pass) is parked for a watched session, so this was
the first item an unattended pass could do.

## Audit

`assets/vfx/blade_spark.png` (pass 529) opened on a hard glow of radius 16.8 sheet pixels that lived
for almost half the effect: frame 0 was a filled disc 36 sheet pixels (18 world pixels) across with
960 solid pixels, and frames 1 and 2 were still filled discs under the ring. Hit-stop holds frame 0,
so the frozen impact was a yellow coin laid over the foe. The heavy sheet was the same at 1.5x (52
sheet pixels across, 2088 solid).

The spark was also placed at the foe's middle (`Player._contact_point`: the foe's centre clamped into
the swing), so even a small flash sat on the body rather than where the blade meets it.

## What was built

Both effects re-tuned in PixelLab's free VFX tool (no generations spent) and saved over the same
entries in Sean's My effects, so the sliders there still work:

- The flash glow shrinks from radius 16.8 to 5 (7.5 heavy) and lives 0.3 of the run instead of 0.48,
  so it is gone by frame 2. The rays' inner edge starts at 4 (6 heavy) instead of 0, so the burst is a
  star with a hot core, and the ring starts at radius 5 (7.5) and opens hollow.
- Light frame 0: 29x30 sheet pixels (15 world pixels) and 341 solid pixels, a third of before. Heavy
  frame 0: 43x43 (21.5 world) and 645 solid. Frames 3 to 6 (the ring and the falling spray) are as
  before; the canvas, pivot and timing are unchanged, so `HitSpark` needed no change.

`scripts/player/player.gd`:

- `_contact_point(rect, target, dir)` moves the spark from the foe's middle back along the swing to
  its near edge, by half the foe's box along the swing (`_half_extent`, from its first rectangle or
  capsule shape), at most `SPARK_EDGE_MAX` (14 px, so a guardian's broad body doesn't push it far
  from the blade), still clamped inside the swing. A Riposte's spark moves the same way.

The heavy sheet's ray tips still touch the canvas's top-left corner on frames 3 and 4, as they did in
pass 529 (one pixel; the VFX tool warns of it). Left as it is: growing the canvas would move the
pivot and change nothing visible at 1x.

## Trial, by eye at 1x and 4x

`shots/spark-trial/pass530-haar-old-new.png` and `pass530-boughs-old-new.png`: a spark thrown at
the training slab beside the hero in `haar/spring_of_haar` and `boughs/thorn_yard`, 1, 2, 4 and 6
frames old. Rows: old light, old heavy, new light, new heavy.

- **Old:** the impact frame is a solid orange coin that hides the slab entirely, and frames 1 and 2
  are still filled discs inside the ring.
- **New:** the impact frame is a small white-hot star; the slab reads through it and through the
  hollow ring that follows. It still reads at once on the Haar's blue-grey and the Boughs' green, and
  the heavy one is still clearly bigger.

## Tests

`tests/test_combat.gd`:

- **`test_the_hit_spark_plays_the_vfx_sheet`**: the opening flash stays small: at most 16 world
  pixels across and 120 solid world pixels for the light sheet, 24 and 220 for the heavy one.
- **`test_a_hit_sparks_where_the_blade_meets_the_foe`**: the spark sits on the training dummy's near
  edge (its box is 18 wide), within 1.5 px, unless the swing's reach stops short of that edge.

Mutations: the pass-529 sheets fail the sheet test (18 and 26 world pixels across, 240 and 522 solid);
calling `_contact_point` without the swing direction (the old middle) fails the edge check.

The full Godot suite passed: 9481 checks, 0 failed.

Bible: 6.7's particle line describes the small opening star, the hollow ring and the spark on the
foe's near edge.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The impact frame no longer hides the foe; the spark marks where the blade bites. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The spark is lighter on screen. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 531: the art loop stays **gated** on Sean (three guardian bases wait). The next grade items in
the queue: keep the near-black foreground posts out of NPC and shop spots (hearthroot/market), then
the shop footer's gold readout against the HUD's. Further VFX-tool trials (the slash smear, the dash
afterimage, the enemy death dissolve) follow. The far-layer pixel-grain family and rim light on
figures stay parked for a watched session.
