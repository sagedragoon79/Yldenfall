# Yldenfall

An original 2D action metroidvania, built in Godot 4.7 with HD pixel art. Nine years ago the leaves of the
great tree Ylden stopped falling; a stranger climbs it to cut out the flower that will not die.
The full design lives in [docs/design-bible.md](docs/design-bible.md).

## Status

**M3: vertical slice, done (pass 03 in docs/loop).** A title menu starts a new game at the West Gate of
Hearthroot. Six Hearthroot rooms (Reeve, Ringreader, shops, townsfolk) and nine Heartwood rooms (sap
pools, Blinkhops, Hornets, Rot Dwarves, the Climbing Glove, secrets, save shrines) are
connected by doors, with a map, saving, ranks, a skill tree, shops and Copper doors. The Root
Chamber holds Gnarlmaw, a three-phase boss; beating it wins the Thaw Seed and opens the
Heartwood Spring, which hardens the sap into amber and starts filling the Hearthroot fountain.
Final art and music come next. The movement and combat gym is still there:
`godot --path . -- --room=gym/gym`.

## Running

**Playtest build:** every push to `main` exports a Windows build to the rolling
[playtest release](https://github.com/sagedragoon79/Yldenfall/releases/tag/playtest)
(see [docs/playtest.md](docs/playtest.md) for controls, debug keys and launch options).
To export locally: `godot --headless --path . --export-debug "Windows Desktop" builds/windows/Yldenfall.exe`
(needs the 4.7.2 export templates).

From source:

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in Godot and press F5, or run `godot --path .`.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | Arrows / WASD | Left stick / D-pad |
| Jump | Space / Z / K | A |
| Attack (hold down in the air to pogo) | X / J | X |
| Dash | C / L / Shift | B / RB / RT |
| Block (tap to parry) | V / I | LB |
| Cast spell (Deluge) | F / U | Y |
| Drink Sapflask | Q / H | LT |
| Drop through a platform | Down + Jump | Down + A |
| Talk, read, use doors, rest at shrines | Up | Up |
| Map | Tab / M | Back |
| Toggle Glove, Delver's Pick, Featherstep Boots, Elven Stride, Deluge (debug builds) | F1 to F4, F7 | |
| Refill and go back to where you enter the room (debug builds) | F5 | |
| Toggle debug HUD | F6 | |
| Fullscreen | F11 / Alt+Enter | |

## Tests

```bash
GODOT=/path/to/godot tools/run_tests.sh            # all tests
GODOT=/path/to/godot tools/run_tests.sh --filter=jump
```

The tests drive a scripted player and assert the numbers from the design bible (jump
height, coyote time, dash distance, combo damage, parry, guard, potion, spells, enemy
telegraphs and more), plus a random-input soak run through the gym.
CI runs them on every push and pull request and uploads gym screenshots.

## Layout

| Path | What |
| --- | --- |
| `docs/` | Design bible, architecture notes, iteration-loop pass records |
| `scripts/` | Game code (player, world, camera, effects, UI, autoloads) |
| `levels/` | Rooms as text files (see `levels/README.md`) |
| `tests/` | Headless test suites |
| `tools/` | Test and screenshot scripts, art and audio generators |
| `assets/` | Generated and imported game assets |
| `art/` | Source art: master palette, Autosprite credit ledger |
