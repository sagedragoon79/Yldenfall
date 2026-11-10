# Pass 531: the foreground thins in front of actors

## Category

A defect from the pass-529 independent grade, the first queue item an unattended pass could do:
near-black foreground posts and stalks cut across the play layer and cover actors. In the
Hearthroot market they sliced through all four shopkeepers and the hero. Combat readability and
art cohesion.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first item
(rim light on figures and the rest of the lighting pass) is parked for a watched session.

## Audit

`hearthroot/market` from the workbench's shot route: the merchant stood behind a timber post from
head to feet, and posts crossed the arms dealer, the cartographer and the hero at the door. The
foreground layer (12.11) slides past at 1.5x the camera (`FORE_SCROLL.x`) and repeats every 640 px,
so the posts cross every spot on screen at some camera position. No placement of the silhouettes in
the art can keep them off a person; moving the art would only move the problem to another room or
another step of the walk.

## What was built (design bible 12.26)

- `shaders/fore_reveal.gdshader` on the foreground sprite: inside each actor's box the silhouettes'
  alpha drops to `REVEAL_KEEP` (0.2) and eases back to full over `REVEAL_SOFT` (8 px). A faint ghost
  of the post stays, so the band still reads as one near layer. The hole's distance wraps across the
  art's 640 px repeat.
- `Backdrop._process` gathers the actors in view (groups `player`, `npc`, `enemy`, `boss`), nearest
  the view's centre first, at most `MAX_HOLES` (16), and feeds their boxes to the shader in the
  sprite's UV. `Backdrop.actor_box` measures the first rectangle or capsule collision shape, or
  `PERSON_BOX` (24 by 46, on the feet) for a townsperson, padded by 4 px.
  `Backdrop.reveal_mask` mirrors the shader for the tests.
- `Npc._ready` adds townspeople to the `npc` group.

A design choice, made without Sean: only actors are revealed, not the shop buildings. A post across a
shop front is ordinary depth; one across a person hides what the player must read.

## By eye, at 1x and 4x

`shots/fore-reveal/pass531-market-before-after.png` (top before, bottom after) and
`pass531-merchant-4x.png`: the merchant, the dyer and the hero stand clear; the post over the
merchant fades above his hat over a few pixels and carries on as before. `boughs/thorn_yard`: the
hero and the training slab stand clear of the thorn stalks, which stay dense everywhere else.

## Tests

`tests/test_backdrop.gd`:

- **`test_the_reveal_mask_thins_only_around_an_actor`**: full inside the box, a soft edge, untouched
  beyond it and above the actor, nothing with no actors, and the hole wraps across the seam.
- **`test_actor_box_measures_the_collision_shape_or_a_person`**.
- **`test_the_foreground_thins_in_front_of_actors_in_view`**: a real Hearthroot backdrop at three
  camera positions; the hole lands on a townsperson (measured from the sprite's origin, independently
  of `holes_for`) and not a quarter screen away, a foe off screen gets none, and 20 actors are capped
  at 16.
- **`test_townspeople_join_the_npc_group`**.
- `test_fore_layer_builds_in_front_for_a_zone_with_art` now expects the reveal shader.

Mutations: feeding no holes (`hole_count` 0) fails the end-to-end test 7 times; dropping the in-view
check fails it 3 times (the off-screen foe opens a hole); placing the holes by world position instead
of the sprite's slid, repeating position fails it 3 times; dropping the seam wrap fails the mask test.

The first full run caught two mistakes of this pass, both fixed: the edits had saved four files with
CRLF line endings (the repository is LF), which broke five tests that read the bible's tables, and the
end-to-end test's camera framed y 40 to 220 while the townsperson stood at y 300, so it never saw him.
Run alone by its full name it now passes; the earlier filter (`fore_`) had not matched it.

The full Godot suite passed: 9506 checks, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Foes and the hero are no longer hidden behind a near post mid-fight. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | The foreground keeps its depth without covering people. The HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One small shader loop of at most 16 boxes on one layer. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 532: the art loop stays **gated** on Sean (three guardian bases wait). Next in the queue: the
shop footer's gold readout against the HUD's (and one backdrop for the shop), then the noisy terrain
fill and the square "missing pixel" blocks in the midground ruins. Further VFX-tool trials (the slash
smear, the dash afterimage, the enemy death dissolve) follow. Pass 535 is due an independent grade.
