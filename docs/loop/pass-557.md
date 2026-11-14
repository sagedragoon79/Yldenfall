# Pass 557: a wall stands on a footing

## Category

Art cohesion, the rest of the pass 555 grade's brick item (4.2/10: "brick fields (Spires,
Vorrhallow, Sunken, Trials) read as a flat tile-editor fill ... and no structure"), which pass 556
left open: a plinth where a wall meets a floor, cracks and moss in the field, and Vorrhallow and the
Sunken Spring.

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session. Its second and third (the Haar Wyrm fight frame, the Haar's fog on the drowned stair) still
touch files that two unmerged branches of other sessions change (`hydra-cistern-fight`,
`haar-steam`), so the pass took the fourth. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No
PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still down (its
Vercel Blob store is suspended: `push.py` answers HTTP 500); it stays under "stuck" for Sean.

## Audit

- Shot `vorrhallow/gate_hall`, `sunken/source_hall` and `trials/walls`. Vorrhallow's floor was a
  block fill that ran up to the tide-blue cap and stopped; the Sunken Spring's the same under its
  moss.
- In the Inner Rings the string course of pass 556 stopped dead at the face of every pillar: four
  separate strips of floor between the pillars, and each pillar read as pasted on.
- Looked for where a plinth could go. In the 47-tile blob set the bottom tile of a wall's face is
  the same tile as the rest of the face (a diagonal bit only counts when both its sides are solid),
  so only the tile under the wall's foot (the inner corner) can tell it is at a wall's base.

## What was built

- **`tools/art/tilegen.py`**: `COURSE_ZONES` gains Vorrhallow and the Sunken Spring. `footing`
  carries the course through the tile under a wall's foot and closes it with a head joint
  (`FOOT_JOINT`, one world pixel) on the side that runs on into the wall. `crack` (taken out of
  `paint_shrine`, same marks) and `field_wear`: a hairline crack in about four in ten of the
  scattered variants of `paint_bricks` and `paint_drowned`, and a tuft of moss in a bed joint of
  the gym's surface variants.
- `assets/tiles/gym.png`, `spires.png`, `sunken.png`, `trials.png` and `vorrhallow.png`
  regenerated. The script again rewrote five `assets/bg/*_mid.png` files that differ from run to
  run; those were put back.
- Design bible 12.47 (new).

## Judged by eye

Looked at `vorrhallow/gate_hall`, `vorrhallow/flooded_hall`, `sunken/source_hall`, `trials/walls`
and `gym/gym` at 1x, before and after. Vorrhallow's floor has a pale coping that runs under both
pillar stubs, and it is the lightest line in a dark room, so the floor reads first. In the Inner
Rings and the gym the course runs unbroken under every pillar, with a small joint at each foot. The
Sunken Spring's course is quiet (cream on cream) and shows mostly on the step by the stele. The
first take closed a footing with a joint two world pixels wide, which left a dark notch four wide
under a two-tile pillar; it is one now.

Not done: a plinth that projects from the wall above the floor (it needs a new tile and a rule in
`TilesetFactory`; bible 12.47 says so). The cracks are faint at 1x, and the gym's moss tufts sit
mostly in fields the camera rarely frames. There is no test of the cracks themselves.

## Tests

`tests/test_brick_structure.gd`: the string-course test now covers five zones (15 checks), and two
new tests. A foot tile's lit line runs the tile but for its joint, the joint is dark, the mirrored
foot closes on its other side, and a ceiling's inner corner carries no course (20 checks). Moss is
in the gym's surface variants only, and the Inner Rings have none (6 checks).

Mutation check: with the five old atlases put back, the three tests fail (5, 10 and 1 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Every code-painted masonry floor has a course, and walls stand on it. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 15,160 checks passed, 0 failed.

## Next

Art cohesion again, by the pass 555 grade: Vorrhallow and the Evercrown's narrow value range with
one accent reserved for hazards. The Haar items wait until the hydra and steam branches merge.
