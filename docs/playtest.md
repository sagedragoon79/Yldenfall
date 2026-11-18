# Yldenfall playtest build

The game is finishable end to end: Hearthroot, the Heartwood, the Tower, the Haar, the High Boughs,
Carillon, Vorrhallow and the Evercrown, every boss through the Everbloom, and the ending. Art is still
code-drawn placeholder and some music is placeholder.

## Launch (Windows)

1. Unzip `Yldenfall-windows.zip` anywhere.
2. Double-click `Yldenfall.exe`. Windows SmartScreen may warn that the app is unsigned:
   click **More info**, then **Run anyway**.
3. F11 or Alt+Enter toggles fullscreen. Options and key rebinding are on the title menu.

Saves and settings live in `%APPDATA%\Godot\app_userdata\Yldenfall\` (`save_1.json`).
Sending that save file along with a bug report helps a lot.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | Arrows / WASD | Left stick / D-pad |
| Jump (hold for height) | Space / Z / K | A |
| Attack (hold Down in the air to pogo) | X / J | X |
| Dash | C / L / Shift | B / RB / RT |
| Block (tap to parry) | V / I | LB |
| Cast spell / next spell | F / U, G / O | Y, R3 |
| Drink Sapflask | Q / H | LT |
| Stillstone (once you have it) | T / E | L3 |
| Drop through a platform | Down + Jump | Down + A |
| Talk, read, doors, rest at shrines | Up | Up |
| Map | Tab / M | Back |
| Pause | Esc / P | Start |

## Debug keys (this build only)

The playtest build is a debug build, so these work in game. Use them to get past anything
that blocks you, and say so in the report.

| Key | What |
| --- | --- |
| F1 / F2 / F3 / F4 / F7 | Toggle Climbing Glove / Delver's Pick / Featherstep Boots / Elven Stride / Torrent |
| F5 | Refill health, magic and potions, and go back to where you enter the room |
| F6 | Debug HUD (speeds, state, room) |

## Launch options

Make a shortcut to the exe and add options after ` -- ` in its Target, for example
`Yldenfall.exe -- --room=haar/lampwick`.

| Option | What |
| --- | --- |
| `--continue` | Skip the title and load the save |
| `--room=ZONE/ROOM` | Start a new game in that room (names are the files under `levels/`) |
| `--flags=a,b` | With `--room`, set story flags first |
| `--gold=N`, `--xp=N` | Give gold or experience at start |
| `--room=gym/gym` | The movement and combat test gym |

## Feedback

Post notes in the "Prepare a playtest build" thread of the project. Most useful: where you
were (the map shows the room name), what you expected, what happened, and how it felt.
