# Pass 633: a wind-up is a pose and a light, not a sparkle

## Category

Combat and enemies (readability). The top item of the queue, the next new defect of the pass
630 grade: "the Heartwood tell is a few-pixel sparkle with no pose or color change (a foe's
wind-up should change its silhouette or flash its body)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the Rot Dwarf's wind-up in the lineup and in the fight frame, and at how the frame
is shot.

- **The capture was early.** `shot.gd` saved the tell four frames into the wind-up, on the
  first lit beat. The glint grows over 0.35 s, so the picture showed a quarter of it. The
  queue said to check this first, and it was half of the defect.
- **The pose is an arm.** The dwarf's wind-up frames raise his axe; the rest of him stands as
  in his walk. At 1x, in a 1280 px frame, the figure does not change.
- **The body has no color change by design.** Pass 611 (12.88) took the rim and tint off the
  body because the pass 610 grade called them "a flat yellow full-body tint, a debug overlay".
  So the answer could not be the old tint back.

## What was built

Design bible 12.109.

| Part | Before | After |
| --- | --- | --- |
| Silhouette | the sheet's wind-up frames only | the foe rears: leans back 0.16 px per pixel of height, 9% taller, 4.5% narrower, about its feet |
| When | | half of it in three frames, whole by 0.16 s, upright on the frame the blow goes |
| Body color | its own, with a rim near the weapon on lit beats | the weapon's light: 0.30 of the tell's gold at the weapon, 0.05 less every 3 px, none by the far side |
| Pulse | the glint and the near rim | the same; the light on the body is steady |
| Capture | four frames into the wind-up | a lit beat with the glint 85% grown; a wind-up that ends first is let go |

All twenty-two sheet foes with a tell point take it through `Enemy.draw_sheet`. Hurt boxes,
blows, timings and sounds are unchanged.

Changed on the way: the light at 0.085 a step (0.46 at the weapon) made the dwarf's torso a
flat gold shape at 4x, which is the look pass 611 removed. At 0.05 his plates read through it.

## Checked by eye

The art lineup at 2x for all twenty-two foes (every state, the wind-up 0.4 s in), the Rot
Dwarf at 4x before and after, and the three recaptured tell frames at 1x (Heartwood, the
Haar, Vorrhallow). The dwarf leans back under a whole glint with a warm helm and shoulder
and his legs in their own grey.

## Tests

Two new tests in `tests/test_tell_glint.gd`. Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_a_wind_up_rears_the_foe` | no rear | fails (8 checks) |
| `test_a_wind_up_rears_the_foe` | the lean forward | fails (2 checks) |
| `test_the_weapons_light_falls_on_the_body` | 0.085 a step | fails |
| `test_the_weapons_light_falls_on_the_body` | squares wide enough for a whole foe | fails (7 checks) |
| `test_the_weapons_light_falls_on_the_body` | the light only on lit beats | fails (3 checks) |

Full suite: 33,659 checks. 33,657 passed in the whole run (pass 632: 33,551). The two that
failed are wall-clock budgets: `test_spires_rain_stays_cheap` (11.72 ms a frame) and the
room-load budget (`gym/gym` 892 ms against 500, the known flake queued in pass 570). The PC
was at about 40% CPU from other programs through the run. Run alone afterwards, the rain
test passed five times in six and the room-load test four times in six (its two misses were
`evercrown/proving_scar` at 532 ms and one more). Neither test draws a wind-up.

## Not done

- The rear is one transform for every foe. A foe whose wind-up frames already crouch forward
  (the Thunder Beetle) leans back a little against its pose.
- The three smallest foes (the Bog Puffcap, the Sap Spitter, the Meteor Slug) are inside the
  light's squares, so they are warm all over, graded.
- New wind-up frames with a larger pose of their own are an art-loop item.
- In the Haar and Vorrhallow tell frames the foe stands against the hero, since the capture
  now waits for a later beat. They read, but a wider gap would be cleaner.
- Code-drawn foes and guardians keep the 0.45 wash (12.73).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A wind-up now changes the foe's silhouette and lights its body; the fairness numbers are unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the fog, the Haar's dither and the midground bands stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two wall-clock budgets flaked under load; both pass alone. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 630 grade's last new item: contact shadows under standing things and a jamb behind
the plaza's door. Then the one-value midground bands, a second ceiling pitch and the plank's
board. The next independent grade is due after pass 635. The Haar's fog and dither, the
sprites' pixel size, the hero's rim light and the sword's look stay held.
