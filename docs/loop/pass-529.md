# Pass 529: the hit spark is drawn from a PixelLab VFX-tool sheet

## Category

The queued **VFX pass** (workbench queue): try PixelLab's free VFX tool (`vfx_workbench`, no
generations spent) on one code-drawn effect, play it in Godot next to the current effect, and keep it
only if it reads better. Art cohesion / combat readability.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) are parked for a watched session, so this was the
first item an unattended pass could do.

## Audit

The blade's hit spark (`HitSpark`, pass 98, bible 6.7) is the most-seen effect in the game: every
landed cut throws one. It is drawn with `draw_line` and `draw_arc`: a white core, a ring and five
rays with an orange rim, fading out over 0.14 s. In game it reads thin and see-through: the lines are
smooth vector strokes at half-world-pixel width with alpha, the only thing on screen not on the
pixel grain.

## What was built

Two effects made in the VFX tool from its `flash_burst` and `sparks_shower` parts, sprayed to the
right (-15 degrees, 70 degree spread), 7 frames at 24 fps (0.29 s), and saved to Sean's My effects
on pixellab.ai ("Yldenfall blade hit spark", "Yldenfall heavy hit spark") so they can be re-tuned
with sliders there:

- `assets/vfx/blade_spark.png` (102x65 frames): a white-hot disc, then a ring that opens while
  hot sparks spray forward and fall, cooling from white to deep orange.
- `assets/vfx/heavy_spark.png` (147x96 frames): the same effect rendered at 1.5x for the heavy
  finisher, rendered again rather than scaled, so its pixels stay whole.

Both are rendered at density 2 (two sheet pixels to a world pixel, `GameCamera.DETAIL`), like every
sprite and tile since the 2x redo. A first export at density 1 was rejected by eye: its pixels were
twice the hero's.

`scripts/fx/hit_spark.gd`:

- `HitSpark` plays the sheet when `SHEET_SHIPPED` is true (the kept decision) and keeps the code
  rays as the fallback. `--spark-look=code|sheet` forces either look for a capture (`game.gd`).
- `load_sheet()` reads the exporter's PNG + JSON (frames, pivot, durations) and cuts the frames once.
  The JSON stores whole milliseconds (42 for 24 fps), so the fps is rounded back to the tool's 24.
- A leftward swing mirrors the sheet, so the sparks still fall. An up or down swing (the rising cut,
  the pogo) turns it a quarter, which keeps every pixel whole.
- A spark sized `HEAVY_AT` (1.3) or more plays the heavy sheet. `life` is now per spark: 0.14 s for
  the code look, one run of the sheet (0.29 s) for the sheet. It still counts down on the game clock,
  so hit-stop holds its first frame, the flash.

`workbench/capture/shot.gd` gains `--spark=X,Y[,heavy,left,up,down,hero]` and `--spark-age=N`, which
throw a hit spark N frames before the shot. That is how the trial was shot, and it stays for later
effect work.

## Trial, by eye at 1x and 4x

`shots/spark-trial/`: in the Haar (`haar/spring_of_haar`) and the High Boughs (`boughs/thorn_yard`),
the spark thrown beside the training slab at 2, 4, 6, 9 and 13 frames old: the code spark, the light
sheet and the heavy sheet, row by row.

- **Code:** thin, pale strokes that fade from the first frame. On the Boughs' green they almost
  vanish by frame 6, and at 4x they are visibly off the pixel grain.
- **Sheet:** a solid flash that reads at once on dark blue-grey and on green, then a crisp ring with a
  spray of sparks that falls past the foe. It is on the same grain as the hero and the tiles, warm
  enough to separate from both zones, and the falling sparks carry the hit a beat past the hit-stop.
- **Heavy:** clearly bigger than the light spark without looking scaled.

The sheet won, so `SHEET_SHIPPED` is true.

Two things noticed and left as they are: the near-black foreground stalks (bible 12.11, drawn in
front of everything) cross the spark when a hit lands behind one, as they did for the code spark; and
the first frame, the flash, is a plain disc, which is the impact frame hit-stop holds.

## Tests

`tests/test_combat.gd`:

- **`test_the_hit_spark_plays_the_vfx_sheet`** (new): the sheet is the shipped look; both sheets
  have 7 frames at 24 fps; a light hit plays the light sheet and the heavy finisher the heavy one; the
  light sheet spans 40 to 64 world pixels at the game's detail; a spark lives one run of the sheet,
  opens on the flash and reaches the ring and spray by frame 3 or 4; both are gone after; and the code
  look is still the fallback.
- **`test_a_hit_sparks_where_the_blade_meets_the_foe`**: waits for the spark's own `life`, and counts
  only the heavy swing's sparks for "one spark per foe per swing", since the second cut's spark may
  still be falling when the heavy cut lands.

Mutations: `SHEET_SHIPPED` set to false fails the new test (the shipped look and the sheet checks);
`DENSITY` set to 1 fails it on the span and the detail checks.

The full Godot suite ran with 9434 checks passed and 44 failed, all five failing tests ones that
parse the design bible: the edit had saved it with Windows line endings, so their table rows ended
in a stray carriage return. With the endings back to LF, each of the five passes alone, and every
test that reads the bible passes (1009 checks). Nothing else in the run failed.

Bible: 6.7's particle line describes the sheet spark, and the VFX list in 13.3 notes the two effects
that come from the VFX tool (Carillon's rain, the hit spark), each weighed against its code version
in game before it was kept.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Every landed cut throws a solid, readable spark on any zone's colours; the heavy finisher's is bigger. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The most-seen effect is on the pixel grain now, not vector strokes. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | The sheet loader reads any VFX-tool export; the capture can throw a spark. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Frames are cut once per sheet and shared. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 530: the art loop stays **gated** on Sean (three guardian bases wait). An independent grade is
taken after this pass (it was due after pass 528). Further VFX-tool trials follow the same pattern
on the next most-seen code effects: the slash smear, the dash afterimage, the enemy death dissolve.
The far-layer pixel-grain family and rim light on figures stay parked for a watched session.
