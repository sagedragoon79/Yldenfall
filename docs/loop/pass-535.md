# Pass 535: the swing smear is drawn from a PixelLab VFX-tool sheet

## Category

The queued **VFX pass, continued** (workbench queue): after the hit spark (pass 529), trial the next
most-seen code effect, the blade's swing smear, in PixelLab's free VFX tool (`vfx_workbench`, no
generations spent), play it in Godot beside the code smear, and keep it only if it reads better.
Art cohesion / combat readability.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do.

## Audit

`SlashFx` (every swing, combo cut, up cut, down-strike and riposte) draws two `draw_arc` strokes: a
6 px cream band (9 px for the heavy finisher) and a 2 px white rim, fading out with alpha over
0.12 s while the arc grows from 35% to its full 140-degree sweep. In game it reads as a soft,
see-through grey band: like the old hit spark, the only shape on screen off the pixel grain, and on
the Boughs' green it washes out to a pale smudge by its third frame.

## What was built

Two effects made in the VFX tool from one `arc` layer with the `slash` profile (a swing that whips:
the head eases across the sweep, the tail chases and crumbles), centred on the cut's centre and
sweeping 144 degrees down the front, 30 fps, at density 2 (two sheet pixels to a world pixel), and
saved to Sean's My effects on pixellab.ai ("Yldenfall slash smear", "Yldenfall heavy slash smear"):

- `assets/vfx/slash_smear.png` (72x104 frames): radius 42, 12 px thick, a cream ramp
  (`#6e4e30` to white) matching the code smear's `f6eed2`.
- `assets/vfx/heavy_smear.png` (84x128 frames): radius 54, 18 px thick, the code's warmer heavy
  colour (`ffe9a8`).

The tool's first frame is always the small tip of the edge, and its last is empty. In the first
capture the tip made the cut read a frame late next to the code arc, which shows a full band at
once, so both sheets are trimmed to their middle three frames (peak, tail, crumble): 0.1 s, close to
the code smear's 0.12 s. The JSON notes the trim.

`scripts/fx/slash_fx.gd`:

- `SlashFx` plays the sheet when `SHEET_SHIPPED` is true (the kept decision) and keeps the code
  arcs as the fallback. `--slash-look=code|sheet` forces either look for a capture (`game.gd`). It
  reads the sheets with `HitSpark.load_sheet`, the VFX-tool loader from pass 529.
- `placement()`: the sheet is drawn for a side cut facing right, sweeping top to bottom. A cut facing
  left mirrors it; the second combo cut flips it across its own sweep axis, so the sweep runs the
  other way and a chain still reads as back-and-forth cuts; the up cut turns it a quarter back (over
  the head, left to right) and the down cut a quarter on (under the feet). Each keeps the code arc's
  centre, and a bigger blade's `size` scales it.
- `life` is per smear: 0.12 s for the code look, one run of the sheet (0.1 s) for the sheet.
- The thrust keeps its code streak (a straight lance, not an arc).

`workbench/capture/shot.gd` gains `--slash=KIND[,heavy,left,back]` and `--slash-age=N`, which play
the hero's smear N frames before the shot.

## Trial, by eye at 1x and 2x

`shots/slash-trial/` (local): in the Haar (`haar/spring_of_haar`) and the High Boughs
(`boughs/thorn_yard`), the side cut, the heavy finisher, the up cut and the back cut, 1, 3 and 5
frames old, code and sheet side by side.

- **Code:** a flat translucent band with a thin rim. It fades from its first frame, goes grey over
  the dark Haar walls and nearly vanishes on the Boughs' green by frame 5.
- **Sheet:** a solid crescent with a lit leading rim and a dark outline, readable on both zones from
  frame 1, then a clean taper and a crumbling tail. It is on the same grain as the hero and the
  tiles, and the heavy finisher is clearly bigger and warmer.
- Mirrored (facing left), reversed (the back cut) and turned (up) all read as the same stroke.

The sheet won, so `SHEET_SHIPPED` is true.

Noticed and left as it is: the near-black foreground stalks (bible 12.11) cross the smear where one
stands in front of the cut, as they do the hit spark.

## Tests

`tests/test_combat.gd`, **`test_the_slash_smear_plays_the_vfx_sheet`** (new): the sheet is the
shipped look; both sheets have 3 frames at 30 fps at the game's detail; each first frame is already
a long edge (28 to 44 world pixels tall, 38 to 56 for the heavy one); a real swing plays the light
sheet, lives one run of it, opens on the edge and is gone after; a left-facing cut mirrors, the back
cut flips, the up and down cuts turn a quarter, and the scale is two sheet pixels to a world pixel;
the heavy finisher plays the heavy sheet; the thrust keeps its code streak; the code look is the
fallback.

Mutations: `SHEET_SHIPPED` false fails it (2 checks); `DENSITY` 1 fails it (4); dropping the back
cut's flip fails it (1).

Bible: 6.7's particle line describes the sheet smear after the hit spark, and 13.3's VFX list counts
three effects from the VFX tool.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Every swing draws a solid, crisp crescent that reads on any zone's colours from its first frame. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The second most-seen effect is on the pixel grain. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | The capture can play a swing smear. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Frames are cut once per sheet and shared. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 536: the art loop stays **gated** on Sean (three guardian bases wait). An independent grade is
taken after this pass (due every fifth pass). The VFX-tool trials continue on the dash afterimage,
then the enemy death dissolve. Rim light on figures and the Boughs painterly clash stay parked for a
watched session.
