# Pass 536: the foreground is a low, fog-tinted fringe

## Category

The top defect of the pass 535 independent grade (workbench queue): the foreground silhouettes stand
over the play layer. The black posts, reeds and thorn stalks in front of the hero, foes and ground
read as vertical black bars or rendering glitches. Art cohesion / combat readability.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, so this was the
first item an unattended pass could do. No PixelLab generations were spent.

## Audit

`tools/art/tilegen.py` painted each zone's `<zone>_fore.png` with protrusions up to 128 world px tall
(reeds 60 to 128, posts 55 to 118, ferns 40 to 108, crystals 34 to 88) rising from the view's bottom
edge (`Backdrop` seats the band just below it, 12.25). In a room where the camera rests on the floor,
the floor's top is about 45 px above the view's bottom, so the posts stood 70 px or more over the
ground and the play layer: in `spires/sky_steps` and `hearthroot/plaza` a row of near-black columns
cut across the hero's band, platforms and the beetle. The reveal (12.26) thins them in front of
actors only, so the bars stayed across everything else. They were drawn in `night-0`, the darkest
shade, the same in every zone.

## What was built

- **Low.** Every silhouette rises at most `FORE_MAX_RISE` (36 world px) above the band, mirrored by
  `Backdrop.FORE_MAX_RISE`. Ferns are 14 to 34 px with 2 to 3 px stalks, reeds 18 to 36 px with 2 px
  stalks and smaller cattails, crystals 12 to 34 px, rubble 10 to 26 px, and all are spaced further
  apart.
- **No posts.** Hearthroot and the Spires draw a broken fence (`_fore_fence`): two to four short
  stubs (12 to 30 px) joined by a sagging rail.
- **Tinted.** `shaders/fore_reveal.gdshader` leans the art toward the zone's fog colour
  (`Backdrop.haze_for`) by `FORE_TINT` (0.55); `Backdrop.fore_material(haze)` passes both, and
  `Backdrop.fore_color` mirrors the maths for the tests. The protrusions are more see-through
  (alpha 176, rim 196, from 206 and 224); the band keeps a 224 rim so its top still marks
  `FORE_GROUND`.

Only the ten `assets/bg/*_fore.png` change. The tilegen run also re-encoded six mid layers
byte-for-byte differently but pixel-identically; those were reverted.

## By eye, at 1x and 2x

Before and after in `hearthroot/plaza`, `spires/sky_steps`, `haar/marsh_road` and `evercrown/veins`
(local captures). Before: a picket of black columns across the lower third in every room, over the
hero, the beetle and the ground. After: a faint fringe of fence stubs, reeds and shards over the
ground tiles, in the zone's own tint (warm brown in Hearthroot and the Spires, blue-grey in the Haar,
violet in the Evercrown). Nothing stands over the hero, the foes or the platforms when the camera
rests on a floor. The nearest layer is now a quiet depth cue, as the bible meant it.

## Tests

`tests/test_backdrop.gd`:

- **`test_fore_silhouettes_stay_a_low_fringe`** (new): for every zone with foreground art, the
  highest visible pixel is no more than `FORE_MAX_RISE` above `FORE_GROUND`.
- **`test_fore_leans_toward_the_zone_fog`** (new): the material of a real foreground layer carries
  its zone's fog colour and `FORE_TINT`, and `fore_color` keeps alpha and moves a colour
  `FORE_TINT` of the way to the fog.

`tools/art/test_tilegen.py`, **`test_foreground_stays_a_low_fringe`** (new): the painter's own output
for every zone stays under `FORE_MAX_RISE`.

Mutations: the old `haar_fore.png` fails the fringe test (it rose 127.5 px); dropping the tint
parameter from `fore_material` fails the fog test. The existing `test_fore_ground_line_matches_the_painted_art`
caught the first try, which had lowered the band's rim alpha too.

Bible: 12.11 notes the fence, the new alphas and the cap; new section 12.29.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Foes and the hero no longer stand behind black columns. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The grade's top defect is gone; the nearest layer sits in each zone's air. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Smaller foreground textures. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 537: the art loop stays **gated** on Sean (three guardian bases wait). Next from the pass 535
grade: the swing smear's timing against the hero's windup, then platform supports and set pieces. The
VFX-tool trials continue on the dash afterimage, then the enemy death dissolve. Rim light on figures
and the Boughs painterly clash stay parked for a watched session.
