# Yldenfall: notes for agents

Sean (the owner) wants to be hands-off. Make design decisions yourself, consistent with
`docs/design-bible.md`, which is the source of truth. If you deviate from it, update the
bible in the same pull request and say why. Keep the Claude Doc version in sync when the
bible changes substantially (link in the project memory).

## Names

Yldenfall is an original game (design bible 1 and 2). It began as a remake of another game, and every
name from that game was retired in pass 461: `data/rename_map.json` lists each with its new name, and
`test_no_retired_name_is_left` fails if one comes back. Pass 462 renamed the internal ids and files the
same way (`ids` in that file; `GameState.migrate_ids` brings older saves over). Give anything new a name of its own.

## Engine and commands

- Godot **4.7.2** (pinned in `tools/godot-version.txt`). GDScript with static typing.
- Run tests: `GODOT=<godot binary> tools/run_tests.sh` (must pass before merging).
- Screenshot a room: `GODOT=<godot binary> tools/screenshot.sh out.png [tileX,tileY] [room]`.
  Uses `xvfb-run` where present (Linux, CI); elsewhere (Windows) it opens the window off-screen.
  Look at screenshots of anything visual you change.
- Regenerate sound effects: `python3 tools/audio/sfxgen.py`. Placeholder music and ambience:
  `python3 tools/audio/musicgen.py` (needs ffmpeg). A file Sean supplies with the same name in
  `assets/music/` (.ogg, .mp3 or .wav) replaces a placeholder. Check the mix for clipping and stray levels:
  `python3 tools/audio/levels.py --check`. Palette: `python3 tools/art/palette.py`.
- Regenerate zone tilesets and parallax backgrounds: `python3 tools/art/tilegen.py` (every new
  zone folder in `levels/` needs a material spec there; a test checks it).
- Player sprite sheet: `python3 tools/art/spritegen.py`. Enemy and NPC sheets (NPCs from their
  `look` in `data/npcs.json`; rerun after adding a person): `python3 tools/art/castgen.py`. Room decor atlases:
  `python3 tools/art/decorgen.py`. Screenshot one player frame with `--shot-pose=slash1:1`.
- UI pixel font (every glyph is drawn in the script; `PixelFont` loads it): `python3 tools/art/fontgen.py`.
  Draw UI text with `PixelFont.draw`, never `draw_string` with another font.
- Item icons and people's portraits (`UiArt` loads them; rerun after adding an item or a person): `python3 tools/art/icongen.py`
  (`--sheet OUT.png` writes a 4x contact sheet to look at).

## Conventions

- Most nodes are built in code (`class_name` scripts), not hand-edited `.tscn` files.
- Rooms are text files in `levels/` loaded by `scripts/world/room.gd`. Legend, doors and map
  placement in `levels/README.md`. `World` moves the player between rooms.
- Anything that must survive a room change or a save lives in `GameState.data`, not on nodes.
- New rooms must pass `tests/test_reachability.gd` (critical path, pickups, no soft-locks).
  Layout rules of thumb are at the end of `levels/README.md`.
  The gym is generated: edit `tools/levels/gen_gym.py`, then run it.
- Enemies extend `Enemy` and must telegraph attacks for at least `Enemy.MIN_TELEGRAPH`.
- Combat numbers live in `scripts/player/combat_tuning.gd` (design bible 5.3).
- Movement numbers live in `scripts/player/movement_tuning.gd` and must match design bible
  section 6. Change both together and keep `tests/` asserting them.
- The player reads intent from `PlayerInput`, never from `Input` directly, so tests can script it.
- Player options live in `Settings` (`scripts/data/settings.gd`, saved to user://settings.cfg). The game
  loads them at start; tests never do. The test runner points `Settings.path` at a test file and resets every option before each test, and it fails a test that leaves an option (or other global state) changed, so put back what you change.
- Collision layers: see `docs/architecture.md`.
- Every new mechanic gets a test in `tests/`.
- PixelLab (second art generator): `python3 tools/art/pixellab.py` (balance, post, job, get). The token is a cloud network secret for api.pixellab.ai (the proxy adds the header;
  off the cloud set `PIXELLAB_API_KEY`); never commit it. It also feeds the PixelLab MCP server in `.mcp.json`. Every call is logged in
  `art/pixellab-ledger.csv`; outputs land in `art/pixellab/`. The hero and his gear are made in PixelLab (Sean, 2026-10-30; design bible 13.5): `python3 tools/art/pixellab_sheets.py` packs the clips for the importer.
- Enemy and boss art follows `docs/art/enemy-style-guide.md` (the art loop, 2026-11-05). Review foes with
  `xvfb-run -a <godot> --path . res://tools/art/lineup.tscn -- --out=OUT.png --only=<foe>` (every state, at 2x).
- Autosprite credits are limited: log every call in `art/autosprite-ledger.csv` and spend them
  only on character animation (design bible section 13.2).

## The iteration loop

Each pass: build, run tests and screenshots, review against the bible, score the rubric
(design bible 15.3), and record it in `docs/loop/pass-NN.md`. Fix the lowest categories next.

## The workbench

`workbench/` is Sean's live window into the build (it runs on his PC; the loop moved there from
the claude.ai project on 2026-11-05). Start it with `python3 workbench/server.py` and open
http://localhost:8977.

- At the top of every pass, read `workbench/notes.json`. Set each `new` note to `seen` and put it
  at the top of `queue` in `workbench/tasks.json`. Sean's notes outrank the rubric's next category.
  When one is finished, set it to `done` with a short `reply`.
- Keep `workbench/tasks.json` current at every step (`doing`, `queue`, `done` newest first, `stuck`).
- When visuals change, refresh the pictures and catalogue (`GODOT` set as for the tests):
  `python3 workbench/capture/capture_all.py --redo --only=rooms` (or `things`, `people`, `gear`,
  `dyes`, `arenas`, `shops`), then `python3 workbench/capture/build_catalog.py`. Clips:
  `python3 workbench/capture/make_clips.py`. Look at what they captured before trusting it.
- It is also hosted at https://yldenfall-workbench.vercel.app behind one password (in
  `workbench/.wb_pass`, never committed). `python -u workbench/push.py` (with `PYTHONUTF8=1` on
  Windows) keeps it live and pulls Sean's notes from it; `workbench/deploy.py` redeploys pictures.
- After a meaningful pass, get an independent grade: 8 to 12 screenshots across the game to a
  separate agent with no hints, scored out of 10 against Hollow Knight; add it to `workbench/grades.json`.
