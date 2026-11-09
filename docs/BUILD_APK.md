# Building the Android APK

Run these in the project folder (`C:\Claude-Code\Card-Game`), in PowerShell or Git Bash.

1. **Clear Godot's saved scene copies** (a generated cache, rebuilt automatically). Skipping this once left an old, wrong copy of the main scene inside the APK, so the app ran without real Wi-Fi, without the name prompt and without the portrait size:
   ```bash
   rm -rf .godot/exported
   ```
2. **Raise the version** in `export_presets.cfg` (`version/code` +1 and `version/name`) and in `Main.VERSION` (`ui/main.gd`), so Settings shows which build a phone has.
3. **Run the tests** (all must pass).
4. **Export:**
   ```bash
   "D:/Downloads/ALL SETUPS/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-debug "Android" build/GandusTable.apk
   ```
   Expected last lines: `Signing debug APK...` and `Signed`. The file is `build/GandusTable.apk` (about 28 MB).
5. **Check the result** (optional, quick): the Android SDK tool `aapt2 dump badging build/GandusTable.apk` should show the package `com.gandustable.game`, the new `versionName`, and the four network permissions.

Settings that the app needs on a phone (real network, saved name, portrait size) are `@export` variables on `Main`; the test `tests/test_app_scene.gd` packs the scene the way the export does and checks them. A variable in the scene file that is not `@export` is silently dropped from the APK.

On the phone: Settings -> bottom line shows `Version ... · Wi-Fi: real · name saved: yes · screen ...`. If it says "Wi-Fi: test only", the build is wrong.
