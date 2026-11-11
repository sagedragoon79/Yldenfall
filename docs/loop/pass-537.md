# Pass 537: the swing smear starts with the blade's travel

## Category

A defect from the pass 535 independent grade (workbench queue): the swing smear against the blade.
The smear spawned on the press while the hero's sprite was still in its windup, so one frame showed
a full crescent with the sword raised. Combat readability (3.5, the grade's lowest area).

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do. No PixelLab generations were spent.

## Audit

`Player._try_attack` adds the `SlashFx` on the press, and since pass 535 it plays its 3-frame sheet at
30 fps (0.1 s). Every hero body sheet (all 24 `hero_*` sets, and the `player` fallback) plays its
swings at 20 fps with a windup first:

| Clip | Windup | Strike frame (the sheet's own blur of the blade) |
| --- | --- | --- |
| `slash1`, `slash2`, `slash_up` | frame 0, sword out or drawn back | frame 1, from 0.05 s |
| `slash3` (heavy finisher) | frames 0 and 1, sword raised overhead | frame 2, from 0.1 s |

So a light cut's crescent was a third gone before the blade moved, and the heavy finisher's crescent
played out **entirely** over the raised sword and was gone by the downswing (local film of a three-cut
combo in `hearthroot/plaza`, frames 58 to 65).

## What was built

- `PlayerVisual.STRIKE_FRAME` names each swing clip's strike frame, and `strike_step(name)` finds its
  sequence step and fps in the sheet that plays it (the worn armor and blade's set). `strike_time`
  gives it in seconds.
- `SlashFx.wait_for_strike(fps, step, clip_time)`: the smear runs the clip's own clock and draws
  nothing until `int(clock * fps)` reaches the strike step, then shows its first frame on that step.
  Summing the same step deltas as `PlayerVisual.anim_time` matters: a plain countdown landed a step
  late on light cuts (the smear is born mid-step, after the sprite has already stepped once) and a
  step early on the heavy one (the sprite's own 6 x 1/60 sums to just under 0.1 s).
- The blow still lands on the press; only the smear waits. The down strike and the thrust have no
  windup and start at once, and the riposte is unchanged.

## By eye, at 1x and 2x

Film of the three-cut combo (`--shot-attack=14 --film`), before and after, cropped on the hero.
Before: a cream crescent hangs in front of the outstretched or raised sword for the first frames of
every cut, and on the heavy finisher it fades out just as the sword comes down. After: the windup
frames are clean, and every crescent appears on the same frame as the sprite's own blade blur (light
cuts at film frames 32 and 46, the heavy at 64), so the downswing finally carries its smear.

The crescent still sits about 20 px in front of the hero's hand; that is its placement from pass 535,
not this pass's timing, and is left as is.

## Tests

`tests/test_combat.gd`, **`test_the_smear_waits_for_the_blade_to_travel`** (new): the strike times
(0.05 s for the light and up cuts, 0.1 s for the heavy, 0 for the down strike); then a side cut, an
up cut and a heavy finisher swung in the arena: the smear waits while the sprite is in its windup,
and steps forward one physics step at a time until it opens on exactly the step the sprite reaches
its strike frame, on its own first frame. The thrust still starts at once.
`test_the_slash_smear_plays_the_vfx_sheet` waits out the windup before checking the smear is gone.

Mutations: dropping the wait fails 6 checks; starting the smear's clock at 0 instead of one step in
fails 3 (one step late). A mapping with the light cuts' strike at frame 0 fails it too.

Bible: 6.7 (the swing smear) says when it opens.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The heavy finisher's downswing now carries its smear; no crescent over a raised sword. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 538: the art loop stays **gated** on Sean (three guardian bases wait). Next from the pass 535
grade: platform supports and dressed mid-ground, then the placeholder set pieces. The VFX-tool trials
continue on the dash afterimage, then the enemy death dissolve. Rim light on figures and the Boughs
painterly clash stay parked for a watched session. Pass 540 is the fifth since the last grade.
