# Pass 598: the ridge gains a body, and the town its light

## Category

Art cohesion, from the independent grade taken after pass 595 (5.3 of 10): "midground and parallax
layers are flat silhouettes with empty stretches (plaza, gear pit, flooded hall)", with the plaza's
flat grey city. It was pass 597's "Next".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for a
watched session. This pass ran from a watched Claude Code session, at Sean's request to keep the
iteration passes going, using the same lock as the scheduled task. The PixelLab art loop stays
**gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK,
the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

Shot at 1x and 2x in the three rooms the grade named:

- **The empty stretch is the ridge.** The distant ridge (bible 12.12) is one colour from its crest
  to the bottom of a 480 px layer. In the plaza it is a grey band under the town, in the gear pit a
  grey wash under a crag line, in the flooded hall a dark fill under a row of shards. In each frame
  it is the widest flat area on screen.
- **The town.** Hearthroot's far layer draws every house in the same dark masonry under grey roofs,
  so the city reads as one grey value.
- The mid layers (roots and lanterns, girders and chains, the stillglass pillars) carry detail and
  were left alone.

## What was built

- **The ridge gains a body** (bible 12.83, `tools/art/tilegen.py`): a second, nearer crest of the same
  material, one shade darker and opaque, runs the whole width 70 px below the far one; four thin
  bands of valley mist part the two planes; every face that rises to the east is lit below its crest.
- **Each zone's distant detail** in the far plane: houses standing level on a roofline (Hearthroot,
  the Spires), each with a lit west wall, a shadowed east edge and rows of windows, some lit; short
  slanting bedding ledges in crags (the Tower, the Trials), with a few lamp sparks; a cleft down each
  crystal spire with glints (Vorrhallow, the Evercrown). Every light is a dark shade, under the
  ridge's brightness guard.
- **The town is lit** (`hearthroot_far`): each house's west third is laid in lighter masonry with a
  lit corner, its east edge falls to shadow, and every roof but a battlement is tiled in a warm
  red-brown.

Judged by eye at 1x and 2x in the three rooms and in one room of every other zone. The first version
lit every rising slope of the roofline too, and with the roofs riding the ground's roll the houses
read as hanging curtains. A roofline now lights its walls instead, and its roofs are level. The first
strata were long, nearly flat lines that read as ruled paper; they are now short slanted ledges with a
lit lip. The first crystal glints were one world pixel and could not be seen; they are now two tall.

Regenerating the tilesets re-encoded five zones' mid layers byte for byte differently but pixel for
pixel the same (checked against main); those were put back, so only the ten ridges and
`hearthroot_far.png` change.

## Tests

`tools/art/test_tilegen.py` (82 checks pass), five new:

- `test_ridge_steps_into_two_planes`: in every zone the near plane starts at least 12 px below the far
  crest in every column, 50 px on average, and reaches every column.
- `test_ridge_far_plane_is_not_one_flat_colour`: at least an eighth of the far plane differs from the
  flat body (19 to 27 percent as built).
- `test_ridge_carries_the_zones_distant_lights`: the roofline zones show at least 600 px of lit
  windows, the other lit zones at least 30 px of lights, the woods and mists none, and every light is
  under the brightness guard.
- `test_ridge_houses_have_level_roofs`: a roofline has at least six level roofs 12 px wide or more.
- `test_hearthroot_town_is_lit_and_roofed`: the far town wears tiled roofs and lit west faces.

Mutation check, by swapping the old painters in at run time (no file edited): the pass 597 ridge, one
flat plane, fails the planes, the flat-colour and the lights tests; roofs riding the roll fail the
level-roof test (2 level roofs); the pass 597 town fails the town test.

Full suite: 21,883 checks passed and 0 failed (1,235 tests; the soak played 58.8 minutes of the game).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The ridges and the town have a body; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 595 grade's item: the slash and spark covering the struck foe in hit frames (draw the
foe's flash and recoil above the streak, or shorten the streak over the body), and check the capture
options for the missing HUD in the captured frames before changing the game. Pass 600 takes an
independent grade (every fifth pass). The Haar's fog and the sword's look stay held.
