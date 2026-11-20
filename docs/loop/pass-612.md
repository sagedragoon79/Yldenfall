# Pass 612: a foe's body is lit by a fill

## Category

Art cohesion, and combat and enemies, from the independent grade taken after pass 610 (5.6 of
10): "foes and the hero sink into dark rooms (the armored foe against the trunk, the flooded
hall's foe a dark smudge)". It was the next unheld item of that grade and the top of the queue,
and it closes the last item left of the pass 605 grade (foes that blend into their backgrounds).

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Pass 553 (bible 12.43) put every foe in its room's light, because the pass 550 grade saw foes
"pasted in": a shared material mutes a foe and sinks its darks toward the zone's haze. Pass 582
(12.69) left one accent color out of that. Since then four grades have said the opposite of
pass 550: dark on dark, blends in, a smudge.

Measured on the idle frame of every sheet foe in every zone it lives in (41 pairs), after the
room's light: the middle pixel of a foe was at or under the value of its zone's haze for twelve
pairs (the Drowned Dwarf and the Marsh Hag in the Haar by 0.09, the Bark Knight in the Boughs
by 0.07) and within 0.05 of it for most others. The sink is right for the line and the deep
shadows; it also took the body's planes down to the room's own shadow value.

## What was built

- **A fill on a foe's mid tones** in the shared material (`shaders/foe_light.gdshader`,
  `FoeLight.lit`): a pixel painted between an outline and a light is multiplied by 1.4 and
  takes 0.05 of the zone's own light (its haze at full value, halfway to white).
- **The outline and the lights are as they were.** Nothing under 0.06 of painted luma or over
  0.7 takes any, so the line still closes the figure, and a flash, a tell and an accent are
  unchanged. No tone passes another.
- **Not a rim light.** Nothing is drawn round or over a figure; the rim light and the hero
  stay calls for Sean in a watched session. The hero is unchanged.
- The Shade Knight's accent lift rose from 0.4 to 0.5 so his plate's lights stay a step above
  his lighter body.
- After it the middle pixel of all 41 pairs stands above its zone's haze, by 0.05 to 0.25.
- Bible 12.89 says so, with a pointer in 12.43; the enemy style guide tells a new sheet to
  paint its body as mid tones.

Judged by eye at 2x on a sheet of all 41 pairs over each zone's dark, before and after, and at
1x and 4x in the Heartwood and Flooded Hall fight frames: the Rot Dwarf's plate and the Crystal
Dwarf's torso now read as lit steel, and neither looks pasted in. Fight pictures refreshed.

For Sean to judge in play: whether foes now read too bright for the muted rooms. The numbers
are `FILL_GAIN` and `FILL_ADD` in `scripts/enemies/foe_light.gd`.

## Tests

`tests/test_foe_light.gd`, new `test_a_foes_body_stands_above_the_rooms_dark`: the band (none
for an outline or a light, the whole for a mid tone); in every zone a mid grey is lit by more
than 0.08, stands above the haze and stays a mid tone, the tint is a pale light in the zone's
hue, and 101 greys keep their order; the shader has the gain, the tint and the band; and for
every sheet foe, half its body stands 0.06 above Vorrhallow's dark, is not washed out, and its
darkest pixel is still an outline.

One older check changed: "a strong colour is muted" measured chroma (max minus min), which
rises with value; it now measures saturation, which is what the rule is about.

Mutation check: with `FILL_GAIN` and `FILL_ADD` at 0, the new test fails 22 checks; with them
back it passes (131 checks).

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A foe's body reads against a dark room; code-drawn tells remain. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Foes stand a step above their rooms' shadows; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 610 grade: the visible tile repeats (uniform brick and cobble fills, one vine
overlay on every block: plaza, flooded hall, storm ledge, aqueduct). Then the canopy's striped
bark, the shop panel's dead area and the plaza skyline's gridded windows. The next independent
grade is due after pass 615. The Haar's fog and dither, the sprites' pixel size, the hero's rim
light and the sword's look stay held.
