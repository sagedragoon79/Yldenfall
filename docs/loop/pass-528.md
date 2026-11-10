# Pass 528: the foreground is locked to the camera, so no black band crosses the screen

## Category

Sean's note (7a4f9ac9, 2026-11-09, on the Haar Wyrm), which outranks the queue and the rubric:

> There is a dark band of nearly opaque black that goes across the top and bottom of the screen,
> even when you travel up and down from screen to screen

Combat readability / art cohesion. It also closes two independent-grade items that had been parked
for a watched session on a wrong diagnosis: the "letterbox" band above the far layer (pass 515, 12.15)
and the "crushed-black dead zones" in the upper bands of dark rooms (pass 525).

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and this note does not approve one.

## Audit

Screenshots of three Haar rooms showed the band at once:

- `haar/spring_of_haar` (the Wyrm's room, one screen tall): a flat near-black strip along the bottom
  16 world pixels of the screen, over the floor.
- `haar/drowned_stair` (two screens tall), seen from the lower screen: the top **third** of the screen
  solid near-black, hiding the platforms at rows 14 to 16.
- `evercrown/veins` (the Everbloom's shaft, three screens): the same band across the top of the
  second screen, over a platform.

The colour (`night-0` at alpha 242) and the height (136 px) are the solid ground strip of the
foreground silhouette art (`<zone>_fore.png`, bible 12.11), which draws at `FORE_Z`, in front of
everything. It sat at world y 344..480 in every room of every zone with foreground art.

The cause is one number. A `Parallax2D` axis with no repeat sits at
`screen_offset * (1 - scroll_scale)`: scale 1 pins the layer to the **world**, scale 0 pins it to the
**camera**. `FORE_SCROLL.y` was 1, on the belief that 1 meant "locked to the camera", and a test
asserted it. So the layer never followed the camera vertically. In a one-screen room that looked
nearly right (a strip at the bottom); in a taller room the strip became a band across the room: at the
bottom of the upper screen and the top of the next, as Sean describes.

This is also why pass 516 found that "nothing at the backdrop's depth renders" in the letterbox band:
an opaque layer in front covered it. The backdrop itself was never empty there.

## What was built (design bible 12.25)

`scripts/world/backdrop.gd`:

- `FORE_SCROLL` is `(1.5, 0.0)`: fast horizontally (near, in front), locked to the camera vertically.
- `Backdrop.fore_offset(view_height)` seats the art's ground line (`FORE_GROUND`, y 344 in the art's
  world pixels) on the bottom edge of the view. `_process` measures the view each frame, so it holds
  at the normal framing (360 px) and in a wide room (450 px).
- The silhouettes now rise from the screen's bottom edge; the solid strip under them stays off screen
  and only guarantees no gap under their roots. The 16 px strip that used to cover the floor is gone
  too (the "bottom" half of the note).

The art is unchanged (`tilegen.py` gets a corrected comment only). Bible 12.11 and 12.15 are corrected
and 12.25 records the rule: nothing opaque may cross the play field.

A design choice, made without Sean: the silhouettes frame the bottom of **every** screen, mid-shaft
included, as 12.11 always intended. The alternative (root them to each room's floor, so upper screens
of a shaft have no foreground) is a small change if he prefers it.

## Verified by eye (1x and 2x)

- `haar/spring_of_haar`: the bottom strip is gone, the floor tiles read to the screen edge, the reeds
  rise from the edge.
- `haar/drowned_stair`, lower screen and mid-shaft: the band is gone; the three platforms and the
  chest it hid are visible; reeds frame the bottom at both heights.
- `evercrown/veins` at top, middle and bottom, against the "before" middle: the band is gone, the
  platform under it is back, and the far, ridge and mid layers fill the view at every height (no
  empty region remains above the far layer).
- `spires/roost`: timber posts seated on the bottom edge, no strip.

## Tests

`tests/test_backdrop.gd`:

- **`test_fore_ground_band_stays_off_screen_at_any_camera_height`** (new): builds a real backdrop,
  moves the viewport's canvas transform through camera tops 0, 8, 360 and 1234 at zoom 2 and 1.6, and
  checks the band's top sits on the view's bottom edge each time.
- **`test_fore_ground_line_matches_the_painted_art`** (new): `FORE_GROUND` equals the first solid row
  of the painted art in five zones.
- **`test_fore_scroll_reads_as_near_and_in_front`**: now asserts the vertical scale is 0, with the
  reason.

Mutations: `FORE_SCROLL.y` back to 1.0 fails the first and third (7 checks); putting the 16 px strip
back in `fore_offset` fails the first (8 checks).

The full Godot suite ran with 9467 checks passed and 4 failed. All four failures were the runner's
leak guard reporting "saves changed (save_1.json, save_1.json.bak)": Sean was playing the installed
game during the run, and its saves in the shared `user://` folder changed under the tests. Each of the
four passes when rerun alone. CI (test + mix), which has no live game beside it, is the clean run.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Platforms, pickups and foes in the second screen of every tall room are no longer hidden behind an opaque band. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The black band and bottom strip are gone in every zone; the foreground frames each screen as designed. The HD hero and guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | The Everbloom's shaft and the Wyrm's room lose the band. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One sprite position set per frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.8.

## Next

Pass 529: the art loop stays **gated** on Sean (three guardian bases wait). An independent grade is
due (the last was pass 525, and this pass changes every tall room's look). Then the queued **VFX
pass** (PixelLab's free VFX tool on one code-drawn effect). The far-layer pixel-grain family (the
Boughs painterly clash) and rim light on figures stay parked for a watched session.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain. Say the word and a pass wires it in.
