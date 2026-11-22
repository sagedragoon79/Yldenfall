# Pass 636: a sunlit zone's woods recede into light

## Category

Combat readability and art cohesion. The top item of the queue, the pass 635 grade's first
new defect: "the canopy bridge's foes are small and low-contrast against the foliage, while
the bee is brighter and more detailed (canopy bridge)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

Captured `boughs/canopy_bridge` and measured luma (0 to 255) at 1x.

- **The Bark Knight was the woods' own value.** Behind him the backdrop's middle pixel was 64;
  his crop's was 64. At 3x he is a dark green figure on dark green firs.
- **The Leaf Mantis was a lighter green on green**, its outline the only edge.
- **Why.** Every parallax layer fades toward its zone's dark haze (12.5); the Boughs' haze is
  a dark green (43, 83, 53), and since pass 635 the woods are rows of firs a step darker each.
  The band behind the play line had sunk to the value the room light (12.43, 12.89) gives a
  foe's body. Measured on the art, the lower half of the ridge sat at 0.28 to 0.32; the
  knight's lit body at 0.31.
- The bee reads because it is the only warm, light thing in the room.
- A rim light on the foes would also do it, but stays Sean's call (12.5).

## What was built

Design bible 12.112, in `scripts/world/backdrop.gd` and `shaders/atmosphere.gdshader`.

| Part | Before | After |
| --- | --- | --- |
| What the Boughs' ridge and mid fade into | the dark green haze | the day air: the sky at the horizon, greyed to mist (116, 141, 130) |
| How far | one fade (0.37, 0.24) | a valley mist: 0.45 and 0.3 at the top, 0.75 and 0.5 at the foot |
| The far layer (the sky), every other zone | the haze | unchanged |
| The woods behind a foe (art, lower half) | 0.28 to 0.32 | 0.41 |

Thrown out on the way:

- **One stronger fade** (0.55 ridge, 0.4 mid, no mist) lifted the woods but kept their lower
  rows at the knight's value (0.32 against 0.31) and flattened the crests' forms.
- **The sky's own green** (104, 145, 120) as the air left the mist as saturated as the mantis
  (0.29 against 0.36); a greyer air is how distance looks and lets the mantis's green stand.

## Checked by eye

At 1x and 3x: the canopy bridge (the knight a dark figure on pale mist, the mantis a saturated
green with a closed outline, the forest's tiered crests still lit), the sunlit bough and the
thorn yard (airy woods; the foes, planks and swings stand clear). The bee and the chest are
unchanged.

## Tests

`test_a_sunlit_zones_woods_recede_into_light` (`tests/test_backdrop.gd`, 24 checks): the air is
light, the ridge and mid take it at their own fade and mist, the sky and roofed zones keep the
haze, the mist's curve, and, measured on the shipped ridge art and the two sheets, each foe a
step off the woods by value (0.08) or by saturation (0.15) with a dark outline.

| Mutation | Result |
| --- | --- |
| the air is the dark haze again | fails (the air, both outlines) |
| no mist (mist equal to the fade) | fails (the mist, the knight's step, both outlines) |
| `fade_at` ignores the mist | fails (the curve, the knight's step, both outlines) |

Full suite: 33,725 checks run. The first run failed 44 checks in five tests that read the bible's tables, because my edit had left the working copy of the bible with CRLF line endings (the committed file was LF); with LF restored, those five tests pass (342 checks), and every other check passed in the full run (pass 635: 33,701).

## Not done

- The Spires are open to a storm sky and keep their haze.
- The rest of the pass 635 grade: the orange trestle repeated across zones and lone chests on
  plinths, the flooded hall's floating shards and its water, the aqueduct's flat water and its
  waterfall, light that rarely shapes surfaces.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Boughs' foes stand clear of their woods. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Boughs read as sunlit air in depth; the town's skyline, the Spires' terraces, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One more uniform in an existing shader. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 635 grade's next item: the orange A-frame trestle repeated across zones and the lone
chests on featureless plinths. Then the flooded hall's shards and water, the aqueduct's water
and waterfall. The Haar's fog and dither, the sprites' pixel size, the hero's rim light and the
sword's look stay held.
