# Gandus Table

A mobile multiplayer card game for Android (iOS later), built with Godot 4 and GDScript.

**Planned games:** Spades, 29 (Twenty-Nine).
**Planned multiplayer:** 4 phones, one acting as host and player, over local Wi-Fi and Bluetooth.

## Status
Phase 2 (the card table screen, with dummy cards and no game rules) is done on the PC. No game rules or multiplayer yet. See `docs/PROJECT_PLAN.md` for the roadmap.

## See the table
1. Open Godot 4.7.2 and import `project.godot` from this folder.
2. Press **F5**. The table deals 13 dummy cards. Tap a card to lift it, tap it again to play it to the middle. Resize the window to try portrait and landscape.

## Run the automated tests
In PowerShell, from this folder:
```
& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
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
