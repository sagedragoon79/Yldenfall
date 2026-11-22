# Pass 637: the Heartwood's timber is old and grown over

## Category

Art cohesion and environments. The top item of the queue, the pass 635 grade's next new
defect: "props repeat across zones: the same orange A-frame trestle, lone chests on featureless
plinths (root shrine, plaza, Heartwood tell)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

Looked at the three named frames from the pass 635 spread at 2x.

- **Two of the three are the Heartwood, one the town.** The root shrine's and the Heartwood
  tell's trestles are the Heartwood's raked, lashed frame (12.85, 12.105); the plaza's is the
  town's carpenter's trestle. Frame and post already differ.
- **What repeats is the timber.** Both zones build in fresh bark pine (`aa6336`, lit `cd8c51`),
  and in all three frames that orange is the brightest, most saturated thing on a dark ground,
  so the eye reads one orange scaffold.
- **The Heartwood's own build is grey.** The dwarf gate in the Heartwood tell is weathered grey
  timber; the trestle beside it was the only fresh wood in the zone.

## What was built

Design bible 12.113, in `scripts/world/plank_supports.gd` and `tools/art/tilegen.py`.

| Part | Before | After |
| --- | --- | --- |
| The Heartwood's posts, rail and braces | bark (`aa6336`, `783c2b`, `48201e`) | old grey timber in the moss ramp (`728061`, `4f5c47`, `2f392d`) |
| Its board | bark, gold nails | the same grey timber, gold nails |
| Its lashing and hangers | orange rope (bark ramp) | flax (umber `aa9173`, `8a6e56`, `3c2c2a`) |
| Moss | none | cushions along the rail, a strand under it now and then, and moss climbing each leg from its footing (8 px at most) |
| The town, the Boughs | bark | unchanged |

Thrown out on the way:

- **Seasoned ochre for the town's posts** (`9c7f44`, `6e5135`, `432d23`). Under the plaza's
  board, which is PixelLab art in the bark ramp, the frame read as a second material and the
  board became the orange thing. The town keeps its fresh pine.

## Checked by eye

At 1x and 3x: the root shrine (two grey, mossed trestles on the dark firs; the board and its
gold nails read as a ledge), the dwarf hall (the trestle now the same timber as the dwarf gate),
the plaza (unchanged). Only `assets/tiles/heartwood.png` changed when the atlases were rebuilt.

## Tests

`test_plank_the_heartwood_builds_in_old_grey_timber_with_moss` (`tests/test_plank_supports.gd`,
73 checks): the timber shares no tone with the town's or the Boughs', is grey and lit as the
town's is; the lashing is flax; moss grows along the rail and up a leg (raked and square), only
where it should; the town grows none. The palette test now covers moss tones too.
`test_the_heartwoods_plank_is_old_grey_timber` (`tools/art/test_tilegen.py`): the board is the
moss ramp and half as saturated as the bark board.

| Mutation | Result |
| --- | --- |
| the Heartwood's timber is bark again | fails (8 checks) |
| no moss on the rail | fails |
| no moss climbing the legs | fails (2 checks) |
| the lashing is orange rope again | fails (3 checks) |
| `PLANK["heartwood"]` is bark again | the tilegen test fails |

Full suite: 33,801 checks, every one passed (pass 636: 33,725).

## Not done

- The lone chests on bare plinths and boards, the other half of the grade's item.
- The flooded hall's floating shards and its water, the aqueduct's flat water and its
  waterfall, light that rarely shapes surfaces.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Heartwood's trestles are its own old timber; the chests' plinths, the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A few more rects per Heartwood frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The lone chests on bare plinths and boards (the plaza's chest on its trestle, the flooded hall's
heap): give a chest a setting. Then the flooded hall's shards and water, the aqueduct's water
and waterfall. An independent grade is due after pass 640. The Haar's fog and dither, the
sprites' pixel size, the hero's rim light and the sword's look stay held.
