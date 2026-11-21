# Pass 629: a zone builds its own post

## Category

Art cohesion (environments). The top item of the queue, the second defect of the pass 625
grade that is not held: "the same cross-braced plank platform in nearly every frame,
recoloured".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the plaza, the gear pit, the canopy bridge, the Lampwick causeway and the root
shrine at 1x. The frames between the posts already differ (12.85, 12.101): cross-braces,
lashing, pilings, a truss, an arch, forked limbs, piers. What is the same in every one is the
outline: a thin straight board with an upright squared post, 4 px wide, 4 px in from each end,
with the same cap block, knee bracket and footing stone. At the size a grader sees a frame,
that outline is what reads, and the frame inside it is texture.

## What was built

Design bible 12.105. `PlankSupports` takes a `post` per zone:

| Post | Zones | What changes in the outline |
| --- | --- | --- |
| Squared | Hearthroot, the gym, the Evercrown | Nothing: the pass 596 post. |
| Raked leg | The Heartwood | Legs lean in under the board; the board overhangs them like a sawhorse. |
| Cut limb | The High Boughs | A trunk that forks under the board; no cap or footing stone. |
| Driven pile | The Haar, the Sunken Spring | A round pile whose head stands 5 px above the deck. |
| Iron column | The Tower, the Trials | Columns set 8 px further in, on gusset plates; the deck overhangs. |
| Stone pier | The Spires, Vorrhallow | Coursed stone with a corbelled head; no timber. |

The plan is unchanged (which runs get posts, and where a foot stands), and so is collision.
`PlankSupports.place` moves the iron zones' columns in after planning, for runs of three cells
or more, and the lashed frame's upper corners follow raked legs.

Thrown out or fixed on the way:

- A pile head or a raked leg under a one-cell plank would stand in the middle of the foothold
  or lean to nowhere. A lone pile stops under the board and a lone leg stands square.
- A raked leg whose foot moved outward would have stood past the board's end and into a wall
  beside it. The foot stays where the plan put it and only the top leans in.
- The post test of pass 596 took the Tower's look; it takes Hearthroot's now, since the
  Tower's post is no longer timber.

## Checked by eye

At 1x and 2x: the root shrine (a sawhorse, and the tall leg under the hung shelf leans), the
gear pit (the deck overhangs both columns over the spikes), the Lampwick causeway (pile heads
above all three boardwalks, readable even in the fog), the canopy bridge (a forked limb at
each end, matching the trunks between) and the drowned market (an arch between stone piers,
which now reads as a small bridge). Not seen in a room: the Spires', the Sunken Spring's and
the Trials' posts. The two rooms shot there hang or brace every run.

## Tests

`tests/test_plank_supports.gd`, three new tests; two older ones changed (the squared post
test takes Hearthroot; the every-room check runs on the placed plan). Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_plank_each_zone_family_builds_its_own_post` | every zone squared | fails (one post in use; the six graded zones alike) |
| `test_plank_iron_columns_stand_in_from_the_boards_ends` | no `set_in` | fails |
| `test_plank_the_lashed_frame_follows_raked_legs` | the frame ignores the rake | fails both checks (138.75 px against a leg at 136) |

Full suite: 32,925 checks passed, 0 failed (pass 628: 32,859).

## Not done

- The board is still one plank tile per zone, 3 px deep and ruled straight.
- Hangers and wall braces are as they were, so a hung shelf looks the same in zones that
  share rope or chain.
- The Evercrown's posts are squared.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Six post builds; the board, the fog and the dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 625 grade's items, in its order: chests, signs and pickups against the
scenery; the rain's splash and wet stone and the lightning's light; the one-value midground
bands. Then a second ceiling pitch and the plank's board. The next independent grade is due
after pass 630. The Haar's fog and dither, the sprites' pixel size, the hero's rim light and
the sword's look stay held.
