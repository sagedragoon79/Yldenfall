# Pass 561: fight frames, so the grade sees the game being played

## Category

Art cohesion and combat readability, from the independent grade taken after pass 560 (4.9/10). Its
top defect: "Seven rooms: the hero stands idle in one pose at the far left, tiny against the room;
no frame shows animation, an attack arc or hit feedback." Combat readability scored 4.3 on rooms
that hold no combat. This pass does part 1 of that queue item: fight frames for the workbench and
the grade set. Part 2 (the hero does not anchor a frame) stays with the HD hero item.

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session; the Haar items still wait for the `hydra-cistern-fight` and `haar-steam` branches. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- `workbench/capture/shot.gd` could throw a spark (`--spark`) or a smear (`--slash`) by hand, on a
  fixed frame. Neither is a frame of play: no foe is struck and nothing flashes.
- `--shot-attack=N` (the game's own option) makes the hero swing for real, but which frame to save
  was a guess. A fixed delay after the blow does not work: the hitstop runs on the wall clock, so
  the same delay gave the windup pose in five rooms and the travelled blade in one.
- A finding about the game, left alone: the blow lands on the swing's first step, the game holds
  for the hitstop on the windup pose, and only then do the blade and its smear travel (the smear
  has waited for the strike frame since pass 537). So at the instant of impact the frame shows a
  spark and a flashing foe but no arc. It is queued for a watched feel call, not changed here.

## What was built

- **`workbench/capture/shot.gd`**: `--when=hit|tell` with `--after=N`. `hit` waits until a
  `HitSpark` is in the room and a `SlashFx` on the hero has finished waiting out the windup; `tell`
  until a living foe is in a wind-up state (`TELLS`). `--frames` becomes the longest it waits; if the
  moment never comes nothing is saved and the exit code is 3. `--face-left` turns the hero first.
  The rule is one static function, `moment(tree, what)`, so a test can call it.
- **`workbench/capture/capture_all.py`**: a `fights` kind. `FIGHTS` lists ten frames across seven
  zones (seven hits, three tells). `fight_spot` finds the first such foe in the room's grid with
  floor beside it and stands the hero two tiles off (four for a tell, so the foe is not already
  touching him). Hits use `--shot-attack=24`; for a tell the hero only stands.
- **`workbench/capture/build_catalog.py`** and **`workbench/config.json`**: a Fights tab on the
  workbench (World group), and the frames on the Shots tab.
- Design bible 12.0: every grade set carries two to four fight frames, never staged. `CLAUDE.md`
  names the new kind.

## Judged by eye

All ten frames as a contact sheet and three at 3x. Each hit frame shows the cream crescent of the
smear, the gold spark on the foe's near edge and the foe washed white; each tell shows the foe's
white pulse with the hero clear of it. Two were retaken: the Spires tell caught the hero already
hurt by a second foe (red, inside the Thunder Beetle's ring), so it became a hit on the beetle; and
the first hit frames, at a fixed delay, froze on the windup pose with no arc.

What the frames show honestly, for the next grade: the hero is small in a full frame, the Haar's
frames are grey on grey, and the hero's swing frame carries a wide pale blur of the blade across
his torso that reads heavier than the crescent.

## Tests

`tests/test_combat.gd`: `test_a_fight_picture_waits_for_the_spark_and_the_smear` and
`test_a_fight_picture_of_a_tell_needs_a_living_foe_winding_up` (17 checks).

Mutation check: with the smear condition dropped from `moment`, "not while the smear waits out the
windup" fails; with the `not e.dead` guard dropped, "a dead foe tells nothing" fails.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. The blow-before-arc timing is queued for a watched call. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Unchanged: no art changed. The grade can now see combat. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,202 checks passed, 0 failed, on the second run. The first run failed three frame-time budgets (`test_spires_rain_stays_cheap`, and `evercrown/proving_scar` in `test_every_room_loads_and_settles_inside_the_budget`) while other programs loaded the PC; both tests pass alone, and this pass changes no game code.

## Next

The next independent grade (due after pass 565, or after the next art pass) uses fight frames. Of
the queue: Gnarlmaw's stamped segments (code-first), then the Boughs' painterly foliage against the
pixel tiles, then one-template rooms. The Haar items wait until the hydra and steam branches
merge; the Blinkhop waits for a free base slot.
