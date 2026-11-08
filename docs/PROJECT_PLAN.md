# Project Plan

Each phase ends with something we can run and verify. Phases are proposals; order may change after owner discussion.

## Phase 0 — Foundation (DONE on PC; first run on the tablet postponed by the owner)
- Inspect environment, write docs.
- Install Godot 4, Android tools (with approval), create Git repo + GitHub remote.
- Create an empty Godot project; confirm it opens and runs on the PC.
- **Done when:** empty project runs on PC and Git/GitHub work.

## Phase 1 — "Hello phone"
- Build an empty Godot app and run it on a real Android phone (USB debugging).
- **Done when:** a trivial screen shows on the phone. Proves the toolchain end to end.
- Checklist for the first Android export: add `*.cfg` to the export preset's "Filters to export non-resource files" (skins need it, see `skins/README.md`); confirm the Nunito font and colours show on the tablet; confirm taps feel right on a touch screen.

## Phase 2 — Cards and table (UI only) — DONE on PC (2026-11-08); tablet check pending
- Card data model (suits, ranks), card drawing, a hand fanned on screen, tap to select, simple animations.
- Portrait/landscape and varied screen sizes.
- **Done when:** a dummy hand displays well on PC and phone.
- Built: Card/Deck, TableState (hidden hands: opponents are only a count), TableLayout (pure maths), CardView, HandView (tap to lift, tap to play), opponent fans, name bars, score box, Table with deal and play animations.
- Added at the owner's request: a skin system (`skins/`, see `skins/README.md`) so card pictures and colours can be swapped later without code changes, smoother drawing (anti-aliasing), a new colour palette and the Nunito font.
- Verified: 80 automated tests, and screenshots at four screen sizes. Not yet verified: running on the tablet; sound (none yet).
- Still to do for the look: real card artwork (owner to supply), avatars and table images as skins, sounds.

## Phase 3 — Spades rules engine (no UI, no network) — DONE on PC (2026-11-08)
- Rules written down and approved first: `docs/SPADES_RULES.md`.
- Pure game logic with automated tests: deal and redeal, bid (Nil, Blind Nil), Blind Nil card swap, play tricks, score, game end. Code in `core/spades/`, tests in `tests/spades/`.
- **Done when:** tests pass for full simulated games with bots. Verified: 200 default games plus 180 games with unusual host settings, all finished with no rejected bot action; 188 tests pass in total.
- Not covered yet: bots never bid Blind Nil, so the swap is tested by unit tests only; disconnect handling and chat belong to later phases.

## Phase 4 — Single-device playable Spades — BUILT and tested on PC (2026-11-08); owner play test pending
- UI connected to rules engine, 1 human + 3 bots. Design: `docs/superpowers/specs/2026-11-08-phase4-playable-spades-design.md`; plan: `docs/superpowers/plans/2026-11-08-phase4-playable-spades.md`; screen designs in Figma (linked from the design doc).
- Built: `SpadesSession` (host-side driver, the seam for Phase 5), `SpadesTableView`, `GameScreen` (bot pacing, panels), start / host options / settings / winner screens, bid / swap / round summary / info panels, greyed illegal cards, placeholder sounds.
- **Done when:** a full game can be played offline.
- Verified: 266 automated tests pass; a whole game ran to the end in the real window with the real pause timers; screenshots checked at 1280x720, 720x1280 and 800x600.
- Not verified yet: the owner playing a game by hand, the tablet (touch feel, fonts), real card art and sounds. In portrait the panels look small (they scale with the window); polish later.

## Phase 5 — Network protocol + Wi-Fi transport
- Define message set (join, deal, your-turn, play-card, state-update, etc.).
- Host-authoritative flow; private hands only sent to their owner.
- Wi-Fi: host discovery on local network and connection.
- Disconnect and reconnect handling.
- **Done when:** 4 phones play Spades over Wi-Fi.
- **5A (network core) BUILT, not yet tried on phones:** message format (`net/protocol.gd`, `net/wire.gd`), the swappable transport contract with an in-memory fake (`net/transport.gd`, `net/fake_network.gd`), the host (`net/spades_host.gd`: lobby, game, pause / rejoin / bot replacement) and the client (`net/spades_client.gd`). `SpadesSession` now supports several human seats. Whole games with 4 fake clients pass, including a drop and rejoin and a check that nobody is ever sent another player's cards. Plan: `docs/superpowers/plans/2026-11-08-phase5a-network-core.md`.
- **5B BUILT, phone test pending:** real Wi-Fi transport (`net/wifi_transport.gd`, ENet, tested over real connections on this computer), finding games (`net/lan_discovery.gd`: nearby list, 4-letter room code, typed address), the host's own player inside the host phone (`net/local_link.gd`), the host's pacing (`net/host_runner.gd`), Join and Lobby screens, the table driven over the network (`net/remote_source.gd`, `GameScreen.start_online`), reconnect-by-itself, "Replace with a bot", leaving. Every hosted game (even alone with bots) now goes Host Game -> options -> Lobby -> table. "Play again" is hidden after a network game (deferred). The app picks a portrait design size (720x1280) when held upright so it stays readable on phones.
- **First APK built:** `build/GandusTable.apk` (debug, 28.6 MB, package `com.gandustable.game`, arm64, permissions INTERNET / ACCESS_NETWORK_STATE / ACCESS_WIFI_STATE / CHANGE_WIFI_MULTICAST_STATE). Not yet installed on any device. Next: the owner runs `docs/PHONE_TEST_CHECKLIST.md` on real phones and the tablet; each failure becomes a test first, then a fix.

## Phase 6 — Bluetooth transport
- Godot has no built-in Bluetooth. Needs an Android plugin written in Kotlin/Java (spike first).
- Same protocol messages as Wi-Fi, behind the same transport interface.
- **Done when:** 4 Android phones play over Bluetooth.

## Phase 7 — Game #2: 29
- Only after rules and variants are confirmed (OPEN_QUESTIONS).
- Reuses table UI, protocol and transports.

## Phase 8 — Settings and rule customization
- Per-game rule options chosen by host, shared with all players.

## Phase 9 — Polish and stability
- Animations, sound, lobby UX, error messages, reconnect testing, performance, release build.

## Phase 10 — iOS
- Wi-Fi first. Bluetooth on iOS needs separate research and testing; Android↔iOS Bluetooth is not assumed to work.

## Risks to tackle early
1. Bluetooth plugin (Phase 6) is the biggest unknown; a small spike should happen before Phase 5 is finalized so the transport interface fits both.
2. Android toolchain setup (Java version, SDK) for beginners.
3. 29 rule variants.
