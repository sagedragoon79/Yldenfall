# Pass 611: a tell gathers on the weapon

## Category

Combat and enemies, and art cohesion, from the independent grade taken after pass 610 (5.6 of
10): "the armored foe's tell in the Heartwood is a flat yellow full-body tint that reads as a
debug overlay". It was the first unheld item of that grade and the top of the queue.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The foe is the Rot Dwarf in the Heartwood's Dwarf Hall (`heartwood-tell` in the fight set).
Passes 585 and 586 took the tell from a white cutout to a gold rim one pixel wide round the
whole foe and a 20 percent gold tint over it (bible 12.72, 12.73). The grader still read it as
an overlay, and at 1x it is one: a figure about 20 pixels wide with a gold line on every edge
and a gold cast, blinking eight times a second. `Enemy.draw_sheet` draws it, so every sheet foe
shared the look.

## What was built

- **The body keeps its own colors.** A sheet foe with a point in `Enemy.TELL_POINTS` wears no
  tint through a wind-up.
- **A glint on the weapon.** A four-point star with a hot core sits on the striking end (the
  axe's head, the lance's tip, the horn, the jaws) and grows from 2.5 to 7 pixels an arm over
  0.35 s, the shortest wind-up in the game, and is longer on the pulse's lit beats. It shows
  on every frame of the wind-up.
- **The rim stays near the weapon.** On lit beats the gold rim is drawn only inside three
  squares about the point (`Sheet.draw_part`, new), so it is solid at the weapon and gone a
  shoulder away. A small foe's squares shrink with its cell.
- **Twenty-two foes have a point**, each placed by eye on its wind-up frames. Two have a point
  per frame, because the weapon travels: the Spire Sentinel's halberd and the Leaf Mantis's
  claws. The new test found the mantis: its first point was right on two frames of four.
- **Unchanged:** the sheet guardians, the three foes that draw their own overlay, and every
  code-drawn foe and guardian keep the old rim, tint or wash until their art is remade. The
  beat, length and sound of every tell are as they were.
- Bible 12.88 says so, with a clause in 7; the enemy style guide tells a new sheet to add its
  point.

Judged by eye at 2x in the art lineup for all twenty-two foes, and at 1x and 3x in the three
tell frames of the fight set (Heartwood, the Haar, Vorrhallow). The first rim squares closed
round the small foes, so they were made smaller and scaled to the cell.

For Sean to judge in play: whether a glint warns as fast as the whole-body pulse did. The
sizes are `GLINT_MIN`, `GLINT_MAX` and `GLINT_PULSE` in `scripts/enemies/enemy.gd`.

## Tests

`tests/test_tell_glint.gd` (four tests): every point names a wind-up of a real sheet and sits
within 6 sheet pixels of the foe on every frame; the glint starts at its least, grows at every
step and is whole within `Enemy.MIN_TELEGRAPH`; the rim's widest square is under half of every
foe's cell; a Rot Dwarf in a room wears no tint, a glint above his head on every frame that
grows and mirrors with him, a pulse that still beats, and no glint under a blow's flash.
`tests/test_hit_flash.gd`: the hornet's pulse is now the longer glint with no tint.

Mutation check: with `Enemy.has_tell_point` returning false (the old whole rim and tint), three
tests fail (51, 24 and 2 checks); with it back they pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A sheet foe's tell is a glint on its weapon; code-drawn tells remain. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | No whole-body gold over a sheet foe; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 610 grade: foes and the hero sink into dark rooms (the armored foe against the
trunk, the flooded hall's foe a dark smudge; with the pass 605 foes-blend item). Then the
visible tile repeats, the canopy's striped bark, the shop panel's dead area and the plaza
skyline's gridded windows. The next independent grade is due after pass 615. The Haar's fog and
dither, the sprites' pixel size and the sword's look stay held.
