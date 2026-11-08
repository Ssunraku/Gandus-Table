# Gandus Table

A mobile multiplayer card game for Android (iOS later), built with Godot 4 and GDScript.

**Planned games:** Spades, 29 (Twenty-Nine).
**Planned multiplayer:** 4 phones, one acting as host and player, over local Wi-Fi and Bluetooth.

## Status
You can play a full game of Spades on the PC against three simple computer players (Phase 4): start screen, host options, bidding (including Nil and Blind Nil with the card swap), play, round summary and winner screen. The rules are in `docs/SPADES_RULES.md`. Cards are still placeholder drawings and sounds are placeholder beeps. There is no multiplayer yet, and the game has not been run on the tablet yet. See `docs/PROJECT_PLAN.md` for the roadmap.

## Play a game
1. Open Godot 4.7.2 and import `project.godot` from this folder.
2. Press **F5**. Choose **Host Game**, pick your rules (or keep the defaults) and press **Start game**.
3. Bid with the number buttons (or Nil / Blind Nil). Tap a card to lift it, tap it again to play it. Greyed-out cards cannot be played right now. **Info** shows the bids and the last trick; **Menu** pauses the game.
4. Resize the window to try portrait and landscape.

## Run the automated tests
In PowerShell, from this folder:
```
& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
The summary at the end should say "All tests passed!".

## Change the look
Card pictures, colours and the font live in `skins/`. See `skins/README.md`.

## Documents
- `CLAUDE.md` — rules for Claude Code sessions
- `docs/PROJECT_PLAN.md` — phases and roadmap
- `docs/ARCHITECTURE.md` — proposed technical design
- `docs/OPEN_QUESTIONS.md` — decisions waiting for the owner
- `docs/ASSETS.md` — every outside file (add-ons, fonts) with its source and licence
- `docs/superpowers/specs/` and `docs/superpowers/plans/` — the approved design and build plan for each phase

## Setup checklist (as of 2026-11-07)
| Tool | State |
|---|---|
| Git 2.54 | Installed |
| VS Code 1.142 | Installed |
| Godot 4 | Installed: 4.7.2 stable, at `D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64.exe` (verified) |
| JDK (Java) | JDK 17.0.21 installed at `C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot` (verified, use this for Android); JDK 25 also present |
| Android SDK / adb | Installed (build-tools 35.0.1, platform 35, NDK 28.1.13356709, CMake 3.10.2.4988404); Godot paths set |
| Godot export templates | 4.7.2 Android templates installed |
| Test tablet | Galaxy Tab S6 Lite; USB debugging not enabled yet (postponed) |
| GitHub remote | Private repo `Ssunraku/Gandus-Table`, connected |
| Codex CLI | **Not found yet** |

Nothing is installed without the owner's approval.
