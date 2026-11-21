# Pass 627: the top of the ground is not a ruled line

## Category

Art cohesion (environments). The top item of the queue, the rest of the first defect of the
pass 625 grade: "terrain is a uniform fill cut into 45-degree stairs, with no top-lip
variation, no shadowed underside and no large form". Pass 626 did the underside. This pass
does the top lip.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the storm ledge, the drowned aqueduct and the canopy bridge at 1x and 4x. The moss
cap (12.7) varies in tone tile by tile, but its top row is the tile's top row. Every floor ends
in one level line across the room, and every ledge ends in a square corner with the wall's
outline running straight down from it. The only breaks are the scattered grass tufts of the
decor, a few to a room.

## What was built

Design bible 12.103.

- **`TopLip`** (`scripts/world/top_lip.gd`), built by `Room` straight after the tile layer and
  set up once the ground is known.
- **Hummocks.** Moss mounds on the top line of a walking surface, in the open cell above it:
  a mound may start in each 16-texel slot of a row, 0.6 of the slots grow one, and they come
  2 to 7 texels tall (1 to 3.5 world pixels), each a dome with ragged blades. A tip that faces
  the key light is lit, the east flank is in shade, and a tall mound is dark at its root.
- **Drapes.** At a surface's end over open air, moss hangs down the wall face in strands up to
  16 texels long, shorter away from the corner, and stands one or two texels proud of the
  face.
- **Tones.** Three steps of the zone's cap ramp. Eight moss-capped zones take the lip;
  Hearthroot, the Tower and the Trials grow none.
- **Drawn** as one mesh per room load, under the room's light and every actor. A slope, a
  secret's cover and ground under water take none; a torn floor grows it again.

Thrown out or fixed on the way:

- The first shading put the dark tone through each mound on a fixed beat. It read as dither.
  The dark tone now sits on the lee flank and the root.
- The first tones were read from the atlas's top-edge tile by brightness. Stone and outline
  colours share the cap's rows, so Heartwood, the Haar and the Sunken Spring came out wrong or
  empty. The tones come from the ramp, and a test checks each is a colour of the cap tiles.

## Checked by eye

The storm ledge and the drowned aqueduct before and after at 3x and 2x; the canopy bridge, the
flooded hall, the Drift Well, the root shrine and the Lampwick causeway after, at 1x, with a
3x strip of five of them. Floors rise and fall, ledge corners carry a lip, and no mound covers
a foot, a chest or a sign. The change is small at 1x: mounds are at most 7 screen pixels tall.
The zoomed crops of the root shrine and the causeway missed their floors, so those two zones
were judged at 1x only.

## Tests

`tests/test_top_lip.gd` (nine tests, 128 checks). Mutation-checked:

| Mutation | Result |
| --- | --- |
| `GROWN` 0 (no hummocks) | fails four tests (11 checks) |
| the lee flank ignored | fails `..._a_hummock_is_lit_from_the_west` |
| no ledge has an end | fails three tests (4 checks) |
| `skip` ignored | fails the surface test and the water test (3 checks) |
| `Room` never grows it | fails the room test and the water test (5 checks) |
| `MAX_PEAK` 2 | fails two tests (4 checks) |

Full suite: 32,664 checks passed, 0 failed (pass 626: 32,536).

## Not done

- The stair's "larger shapes": ceilings are still cut along the tile grid and its haunches.
- A slope has no lip, so a ramp's top is a straight diagonal.
- Stone-capped zones (Hearthroot, the Tower, the Trials) have no lip of their own.
- The lip does not follow a secret wall once it opens.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Ground tops rise and fall; the stair, the fog and the dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 625 grade's items, in its order: the stair's larger shapes; the plank on
two posts (vary the board, the posts and the run's outline by zone, or carry runs on ledges,
boughs or chains); chests, signs and pickups against the scenery; the rain's splash and wet
stone and the lightning's light; the one-value midground bands. The next independent grade is
due after pass 630. The Haar's fog and dither, the sprites' pixel size, the hero's rim light
and the sword's look stay held.
