# Pass 622: the Spires' skyline is a ruined city on a hill

## Category

Art cohesion (environments). The top unheld item of the queue, the last of the pass 615
grade (5.6 of 10): "the far skylines are flat one-value silhouettes (plaza, storm ledge)".
Pass 617 did the plaza's half; this is the storm ledge's.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at `assets/bg/spires_ridge.png` and at `spires/storm_ledge` at 1x, and measured the
picture:

- **One tone.** One color held 73.5 percent of the far plane; two tones held a twentieth each.
- **One form.** Every spire was a pole 6 to 12 px wide under a point or a notched crown: at
  the height the measure takes, 14 runs of 17 to 25 px in the 2x picture and four tips.
- **Poles, not towers.** A spire's lit west wall ran on down through the hill in front of it
  to the mist, so the row read as fence posts driven through the ground.
- **Pale caps.** The valley mist followed the near plane's crest, so each near spire wore a
  pale cap of mist over its top.

## What was built

All in `tools/art/tilegen.py`; only `assets/bg/spires_ridge.png` changed (the town's, the
Tower's and the Trials' ridges were regenerated and are byte for byte the same).

- **A form of its own** (`_spire`, `SPIRE_FORMS`): a needle under a cone, a notched crown, a
  tower sheared off at a slant in ragged steps, or a keep (a shaft on a broader base with a
  sloped shoulder).
- **Bridges** (`_spire_span`): about half the near pairs are joined by a bridge on a pointed
  arch. Every other one stands whole; the rest have fallen and leave a stub on each tower.
  The sky shows under a bridge. This seed gives five: three whole, two fallen.
- **More than one value** (`_spire_detail`): five wall tones, a round wall lit on the west
  and dark on the east, a cone lit on its west side, string courses, raw stone and a crack at
  a break, a lit ledge on a keep's shoulder. A wall ends at the hill it stands on.
- **Terraces**: four lines follow the hill's crest, each band of ground a little darker, with
  stretches of old walling along them.
- **The nearer row**: the mist lies on the ground, not on the spires' tops, and a near
  spire's west wall is lit.

Thrown out or fixed on the way, each by eye or by a measure:

- The ground under a whole bridge was a level block: the hill's height was floored at zero
  where no tower stood, and the hill dips below the horizon. It now takes the hill as it is.
- Two bridges on one spire, at one height, made a cross of it: a spire carries one at most.
- Bridges were whole or fallen by a draw, and this seed drew three fallen out of three: every
  other bridge now stands whole.
- A bridge was cut before the spire it runs to was raised, so it could cut the sky into that
  keep's base: the spire is raised first.

## Checked by eye

`spires/storm_ledge` and `spires/fallen_bridge` at 1x with the HUD, beside the pass 621
pictures: a terraced hill with ruined towers of several shapes and a bridge where the row of
posts was; the nearer row no longer wears pale caps. The haze still recedes all of it behind
the islands and the rain. The first shot showed the old picture: the capture does not reimport
a changed picture by itself (`--headless --import` first).

## Tests

`tests/test_spires_skyline.gd` (four tests, reading the shipped picture). Mutation-checked
against the pass 621 picture:

| Test | With the old picture |
| --- | --- |
| `test_the_spires_far_plane_is_more_than_one_value` | fails (one color at 73 percent) |
| `test_the_spires_are_not_one_pole` | fails (no narrow, broad or ragged runs) |
| `test_the_spires_bridges_stand_over_open_sky` | fails (no column with sky under masonry) |
| `test_the_spires_slit_windows_stay_few` | passes: a ceiling the old row also kept (360 px lit, 200 now) |

`tools/art/test_tilegen.py` (run by hand, not in CI): `test_the_spires_stand_on_a_ridge_of_their_own`
now allows a broad run for a keep or a bridged pair (26 px at most); new
`test_a_spire_has_a_form_of_its_own` holds the four forms, whole and fallen bridges, a keep's
base, a bridge's thickness and clearance, the far plane's tones and the seam.

Full suite: see the pull request.

## Not done

- The near plane is still one tone under its lit walls.
- Whether the row is too busy behind a fight is for Sean to judge in play.
- The mid layer's sky islands and their own ruined spires (`ruined_spire`) are unchanged.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Spires' skyline has forms, tones and bridges; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 620 grade's items, in its order: the large rectangular dark blotches and
stair-stepped tone patches in brick and earth (aqueduct, canopy bridge, flooded hall, storm
ledge), copied props, foes' contrast with their backdrops, the empty minimap and the coin
count's glyph, the fire seal's color against the Haar's fog, the shop description that repeats
the stat lines. The independent grade is next due after pass 625. The Haar's fog and dither,
the sprites' pixel size, the hero's rim light and the sword's look stay held.
