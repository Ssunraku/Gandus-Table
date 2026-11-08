# Phase 5B — Wi-Fi, Screens and the First APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four phones play Spades over local Wi-Fi: real ENet transport, finding games (room code, nearby list, typed address), Join and Lobby screens, a networked game screen, pause / reconnect handling in the app, and a first Android APK installed on the owner's devices.

**Architecture:** Phase 5A's `SpadesHost` / `SpadesClient` / `Transport` stay as they are. 5B adds: `WifiTransport` (Godot ENet), `LocalLink` (the host's own player inside the host phone), `LanDiscovery` (UDP broadcast), a `GameSource` seam so `GameScreen` can run on either a local `SpadesSession` (as today, used by tests) or a `RemoteSource` built from the host's snapshots, a `HostRunner` node (polling + the bot/trick pauses), and the Join / Lobby screens. The app always plays through the host path: Host Game -> options -> Lobby -> game.

**Tech Stack:** Godot 4.7.2 (ENetMultiplayerPeer, PacketPeerUDP), typed GDScript, GUT 9.7.1, Godot Android export (JDK 17, Android SDK and export templates are already installed on this PC).

**Spec:** `docs/superpowers/specs/2026-11-08-phase5-wifi-multiplayer-design.md` (approved). Builds on `docs/superpowers/plans/2026-11-08-phase5a-network-core.md` (done, commit 3165a8a).

## Global Constraints
- Ports: game `24680` (UDP, ENet), discovery `24681` (UDP). The host peer id seen by a client is always `Transport.HOST_ID` (1); ENet gives clients large random ids, so ids are opaque everywhere.
- Room code: 4 letters from `ABCDEFGHJKLMNPQRSTUVWXYZ` (no I, no O), shown upper-case, accepted in any case.
- Discovery packets are small JSON: `{"gt": 1, ...}`; anything else, any packet over 512 bytes, or the wrong version is ignored silently.
- The host's own player is `LocalLink`'s local client (reserved peer id `0`, `is_local_peer(0)` true). Joiners cannot use that id.
- Screens never touch `SpadesHost` internals; the app wiring (Main) owns the host, runner and client objects.
- Typed GDScript, logic in `net/` and `core/`, drawing in `ui/`. Offline-only logic is untouched: `SpadesSession`, `SpadesGame`, rules, scoring.
- Seats on screen are always rotated so you are South (done in `RemoteSource`, as `SpadesClient.to_table_state` does).
- Pacing constants stay `BOT_PAUSE 0.7`, `TRICK_HOLD 1.2`, deal wait `1.8`; tests use `pace = 0`.
- No sound or animation change beyond reusing the existing ones; one soft tap on a played card.
- Test command (project folder, PowerShell): `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (add `-gselect=<script name>`). After adding a `class_name` file run `--headless --path . --import --quit`. Engine warnings and printed errors count as test failures.
- Git: never commit, push or delete branches without the owner's explicit approval ("stop for owner approval"). Branch: `phase-5b-wifi-screens` from `phase-5a-network-core` (owner has not merged 5A yet). Do not stage stray line-ending-only `.import` changes. Android SDK / JDK / system settings: do not install or change anything; if something is missing, stop and tell the owner.
- Rulings made while planning (owner may overrule): all hosted games, including playing alone with bots, go through the host path; "Play again" is hidden for network games (deferred); the Android package name is `com.gandustable.game`; ports above; the first APK is a debug build.

## Review Focus
1. Offline behaviour must not regress: every Phase 4 `GameScreen` test still passes with `LocalSource` (Task 4).
2. Garbage, oversized or hostile UDP packets and half-open connections do not crash the host or the finder (Tasks 2, 3).
3. A phone that sleeps or loses Wi-Fi mid-game reconnects by itself with its token and lands back on the table; if the host is gone it returns to the start screen with a plain message (Task 8).
4. Joining a full, started, or wrong-version game, or an unreachable address, shows a plain-language message and never a stuck "connecting" screen (Tasks 7, 8).
5. Host phone leaving (menu -> exit, or app killed) ends the game for everyone with a clear message; a joiner leaving gives their seat to a bot (Task 8).

---

### Task 1: LocalLink (the host's own player)

**Files:**
- Create: `net/local_link.gd` (`class_name LocalLink`, `extends Transport`)
- Test: `tests/net/test_local_link.gd`

**Interfaces:**
- Consumes: `Transport`.
- Produces: `LocalLink` is the transport handed to `SpadesHost`. `func _init(inner: Transport = null)` (the network transport, or null for no network); `func local_client() -> Transport` (the transport handed to the host's own `SpadesClient`; its only peer is `Transport.HOST_ID`); `const LOCAL_PEER: int = 0`; `func poll() -> void` (delivers queued local messages in order, never re-entrantly, then polls `inner` if it has a `poll()`); `is_local_peer(id)` true only for `LOCAL_PEER`; `send_to(id, text)` / `broadcast(text)` route to the local client for id 0 and to `inner` otherwise; messages and connect/disconnect events from `inner` are re-emitted unchanged; `close()` closes `inner`.

- [ ] **Step 1: Write the failing tests** — `test_local_client_reaches_the_host_as_peer_0`; `test_host_message_to_peer_0_reaches_the_local_client`; `test_broadcast_reaches_the_local_client_and_the_inner_transport` (inner is a `FakeNetwork` host transport with one client); `test_inner_peers_appear_with_their_own_ids`; `test_nothing_is_delivered_until_poll`; `test_is_local_peer_only_for_the_local_client`; `test_a_whole_lobby_and_game_start_works_with_only_a_local_client` (SpadesHost on `LocalLink(null)`, the local client joins as host, adds bots, starts, gets `game_view`; loop `poll()` + `host.step()` until the first human turn).
- [ ] **Step 2: Run** `-gselect=test_local_link` — Expected: FAIL (class missing).
- [ ] **Step 3: Implement `LocalLink`.**
- [ ] **Step 4: Run** `-gselect=test_local_link` then the full suite — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 2: WifiTransport (ENet)

**Files:**
- Create: `net/wifi_transport.gd` (`class_name WifiTransport`, `extends Transport`)
- Test: `tests/net/test_wifi_transport.gd`

**Interfaces:**
- Produces: `const GAME_PORT: int = 24680`; `func start_host(port: int = GAME_PORT) -> Error` (up to 3 clients); `func connect_to(address: String, port: int = GAME_PORT) -> Error`; `func poll() -> void` (must be called every frame; emits `peer_connected`, `peer_disconnected`, `message_received`; messages are the UTF-8 text of reliable, ordered packets); `send_to`, `broadcast`, `close()`; `var status: String` (`"idle"`, `"hosting"`, `"connecting"`, `"connected"`, `"failed"`, `"closed"`) so screens can show progress; on a client the host is `Transport.HOST_ID`.

- [ ] **Step 1: Write the failing tests** (real loopback on `127.0.0.1`, test port `24700`, a helper `_poll_until(callable, 2.0)` that calls `poll()` on every transport every 5 ms): `test_client_connects_and_messages_flow_both_ways`; `test_messages_keep_their_order`; `test_a_client_closing_is_reported_to_the_host`; `test_host_close_is_reported_to_the_client`; `test_starting_a_second_host_on_a_busy_port_fails_with_an_error_code`; `test_connecting_to_nothing_ends_as_failed_not_stuck` (port with no host: status becomes `"failed"` within 5 s); `test_large_message_of_10000_characters_arrives_intact`; `test_four_clients_are_refused_when_three_are_connected`.
- [ ] **Step 2: Run** `-gselect=test_wifi_transport` — Expected: FAIL.
- [ ] **Step 3: Implement `WifiTransport`** with `ENetMultiplayerPeer`, reliable ordered mode, polling its signals and packet queue (no `SceneMultiplayer`).
- [ ] **Step 4: Run** `-gselect=test_wifi_transport` — Expected: all pass, no leaked-resource errors.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 3: Room codes and LAN discovery

**Files:**
- Create: `net/room_code.gd` (`class_name RoomCode`), `net/lan_discovery.gd` (`class_name LanDiscovery`, `extends RefCounted`)
- Test: `tests/net/test_room_code.gd`, `tests/net/test_lan_discovery.gd`

**Interfaces:**
- Produces `RoomCode`: `static func generate(rng: RandomNumberGenerator) -> String`; `static func normalize(text: String) -> String` (trim, upper-case; returns `""` unless exactly 4 allowed letters); `static func is_valid(text: String) -> bool`.
- Produces `LanDiscovery`: `const DISCOVERY_PORT: int = 24681`; `var query_address: String = "255.255.255.255"` (tests use `127.0.0.1`); host side: `func advertise(info: Dictionary, port: int = DISCOVERY_PORT) -> Error` (`info` keys: `code`, `name`, `game_port`, `free_seats`, `exact`), `func update_info(info: Dictionary)`, `func stop_advertising()`; finder side: `func search(code: String = "") -> Error` (an empty code finds every game), `func poll() -> void` (host: answers queries that match; finder: re-sends the query about every 1.5 s and collects answers), `var found: Array[Dictionary]` (`code`, `name`, `address`, `port`, `free_seats`, `exact`; no duplicates, newest data wins, entries expire after 6 s without an answer), `func stop_searching()`; `static func local_addresses() -> Array[String]` (private IPv4 addresses of this phone, e.g. 192.168.x.x, 10.x.x.x, 172.16-31.x.x).

- [ ] **Step 1: Write the failing tests** — room code: `test_generated_codes_are_4_allowed_letters` (500 codes, never I or O); `test_normalize_accepts_any_case_and_spaces`; `test_normalize_rejects_wrong_length_and_bad_letters` (`"ABC"`, `"ABCDE"`, `"AB1D"`, `"ABOD"`, `""`); discovery over loopback: `test_a_search_finds_the_advertising_host`; `test_a_search_with_the_right_code_finds_it_and_a_wrong_code_finds_nothing`; `test_an_updated_free_seat_count_is_seen`; `test_stopping_the_advertiser_makes_the_game_expire_from_the_list`; `test_garbage_and_oversized_packets_are_ignored` (send raw junk, `"{}"`, a 2000-byte packet to the discovery port; host still answers a real query); `test_local_addresses_are_private_ipv4_only`.
- [ ] **Step 2: Run** `-gselect=test_room_code` and `-gselect=test_lan_discovery` — Expected: FAIL.
- [ ] **Step 3: Implement both** (`PacketPeerUDP`; finder enables broadcast; host binds the discovery port and replies unicast to the sender).
- [ ] **Step 4: Run** both selects — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 4: GameSource seam (no behaviour change)

**Files:**
- Create: `core/game_source.gd` (`class_name GameSource`, `extends RefCounted`), `core/local_source.gd` (`class_name LocalSource`, `extends GameSource`)
- Modify: `ui/game_screen.gd`, `core/spades/spades_table_view.gd`
- Test: `tests/test_local_source.gd` (existing `test_game_screen.gd`, `test_table_live.gd`, `test_main_flow.gd` must stay green)

**Interfaces:**
- Produces `GameSource` (abstract; the same method names `SpadesSession` already has): `phase() -> int`, `turn_seat() -> int`, `human_must_bid() / human_must_play() / human_must_swap() -> bool`, `submit_bid(Bid) -> bool`, `submit_swap(give: Array[Card], positions: Array[int]) -> bool`, `submit_play(Card) -> bool`, `advance_bots() -> Dictionary`, `trick_pending() -> bool`, `shown_trick() -> Array[Dictionary]`, `last_trick() -> Dictionary`, `clear_trick()`, `round_over() -> bool`, `game_over() -> bool`, `winner_team() -> int`, `round_result() -> Dictionary`, `round_number() -> int`, `next_round() -> bool`, `view() -> Dictionary` (the `SpadesSession.view()` shape, seats relative to the viewer), `redeal_messages() -> Array[String]`, `is_online() -> bool` (false for local).
- Produces `LocalSource.new(session: SpadesSession)`: forwards everything to the session; `session` stays public for tests. `GameScreen` gets `var source: GameSource` and `start(settings, seed)` builds `LocalSource(SpadesSession.new(...))`; `GameScreen.session` remains as a read accessor returning the local session when the source is a `LocalSource` (so existing tests keep working). `SpadesTableView.build(source: GameSource)`.

- [ ] **Step 1: Write the failing tests** — `test_local_source_forwards_view_and_actions` (same view keys and the same hand as the session); `test_game_screen_still_plays_a_whole_round_through_a_local_source`.
- [ ] **Step 2: Run** `-gselect=test_local_source` — Expected: FAIL.
- [ ] **Step 3: Implement** the two classes and switch `GameScreen` / `SpadesTableView` to the source with the smallest possible edit.
- [ ] **Step 4: Run** the full suite — Expected: every existing test plus the new ones pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 5: RemoteSource and the networked GameScreen

**Files:**
- Create: `net/remote_source.gd` (`class_name RemoteSource`, `extends GameSource`)
- Modify: `ui/game_screen.gd`
- Test: `tests/net/test_remote_source.gd`, `tests/test_net_game_screen.gd`

**Interfaces:**
- Consumes: `SpadesClient` (`view`, `my_seat`, signals), Task 4 `GameSource`.
- Produces `RemoteSource.new(client: SpadesClient)`: implements `GameSource` from the latest snapshot, with every seat rotated to the viewer (own seat = 0), team arrays own-team first, `names` rotated (own seat "You"); `submit_*` send a request and return true (the host answers with a snapshot; a refusal arrives as `client.rejected`); `advance_bots()` returns `{}`; `trick_pending()` is true while the snapshot's trick has 4 cards; `clear_trick()` is a no-op; `next_round()` sends the request; `signal changed`, `signal event(kind: String, seat: int, card: Card)` (seat rotated; `card` set for `"play"`), `signal paused_changed(paused: bool, who: String)`, `signal closed(reason: String)`; `is_online()` true.
- `GameScreen.start_online(source: RemoteSource)`: connects to `changed` and calls `refresh()`; on `event "play"` runs `table.animate_card_played`, on `"trick"` `table.sweep_trick(winner)`, on `"deal"` the deal animation; sound events as offline; shows the round summary when `round_over` (its "Next round" button sends `next_round`; "See result" at game over emits `game_finished`); shows the redeal notice; `step()` returns false in online mode and no timers run (the host paces). A "Waiting for <name> to come back..." notice shows while paused.

- [ ] **Step 1: Write the failing tests** — `test_remote_source_rotates_seats_for_each_viewer` (4 clients over the fake network; each source's `view()["hand_counts"]`, `["trick"]` seats, `["names"]` are viewer-relative); `test_remote_source_team_scores_are_own_team_first`; `test_remote_source_view_matches_the_local_view_shape` (same keys as `SpadesSession.view()`); `test_remote_events_fire_for_play_trick_and_deal`; `test_submit_play_sends_a_request_and_the_host_answers`. GameScreen: `test_net_screen_shows_the_players_hand_and_turn`; `test_net_screen_animates_a_remote_card_play` (an opponent's play shows a card in flight / on the table); `test_net_screen_shows_the_summary_and_next_round_sends_a_request`; `test_net_screen_pause_notice_shows_and_hides`; `test_net_screen_game_over_emits_game_finished`.
- [ ] **Step 2: Run** `-gselect=test_remote_source` and `-gselect=test_net_game_screen` — Expected: FAIL.
- [ ] **Step 3: Implement** `RemoteSource` and the online mode of `GameScreen`.
- [ ] **Step 4: Run** the full suite — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 6: HostRunner (polling and pauses)

**Files:**
- Create: `net/host_runner.gd` (`class_name HostRunner`, `extends Node`)
- Modify: `net/spades_host.gd` (add `func next_delay() -> float`)
- Test: `tests/net/test_host_runner.gd`

**Interfaces:**
- Produces `SpadesHost.next_delay() -> float`: seconds to wait before the next `step()`: `TRICK_HOLD` (1.2) when a trick is pending, `BOT_PAUSE` (0.7) when a bot is to act, 1.8 right after a deal, `-1.0` when waiting for a person, paused, finished or closed.
- Produces `HostRunner(host: SpadesHost, link: LocalLink, discovery: LanDiscovery = null)`: a `Node` whose `_process` calls `link.poll()`, `discovery.poll()` and runs `host.step()` when `next_delay() * pace` has elapsed; `var pace: float = 1.0` (0 = step every frame); `func stop()`.

- [ ] **Step 1: Write the failing tests** — `test_next_delay_values` (waiting for a person gives -1, a pending trick gives 1.2, a bot to bid gives 0.7); `test_runner_steps_bots_until_a_human_is_needed` (pace 0; call `_process` in a loop); `test_runner_does_not_step_while_paused`; `test_runner_polls_the_link` (a local client message is handled without any manual poll); `test_stop_ends_all_activity`.
- [ ] **Step 2: Run** `-gselect=test_host_runner` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `-gselect=test_host_runner` then the full suite — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 7: Join and Lobby screens

**Files:**
- Create: `ui/join_screen.gd` (`class_name JoinScreen`, `extends MenuScreen`), `ui/lobby_screen.gd` (`class_name LobbyScreen`, `extends MenuScreen`)
- Modify: `ui/start_screen.gd` (enable the Join Game button, remove the "Coming soon" note)
- Test: `tests/test_join_lobby_screens.gd`

**Interfaces:**
- Produces `JoinScreen`: `signal join_chosen(address: String, port: int)`, `signal back_pressed`; `func show_games(games: Array[Dictionary])` (rows: host name, code, free seats; tapping a row emits `join_chosen`); `code_edit: LineEdit` + `join_code_button` (emits `code_chosen(code: String)` with the normalised code, or shows "Type the 4 letters" if invalid); `address_edit: LineEdit` + `join_address_button` (accepts `a.b.c.d` or `a.b.c.d:port`, rejects anything else with a message); `func set_status(text: String)` (Searching... / No games found yet. If your Wi-Fi is a guest or public network, phones may be blocked from seeing each other; try the address below.).
- Produces `LobbyScreen`: `signal seat_chosen(seat: int)`, `signal add_bots_pressed`, `signal start_pressed`, `signal leave_pressed`; `func show_lobby(lobby: Dictionary, is_host: bool, room_code: String, addresses: Array[String])` (four seat buttons: Free / player name / Bot, your own seat highlighted; the host's options as read-only lines: Blind Nil, Nil, Redeal, Bags penalty or Exact bids mode, Play higher, win and lose scores; host sees the room code and the typed address and the "Fill with bots" and "Start game" buttons, the Start button enabled only when no seat is free; joiners see "Waiting for the host to start").

- [ ] **Step 1: Write the failing tests** — `test_start_screen_join_button_is_enabled`; `test_join_screen_lists_games_and_tapping_a_row_joins`; `test_join_by_code_normalises_and_rejects_bad_codes`; `test_join_by_address_accepts_ip_and_ip_port_only` (`"192.168.1.5"`, `"192.168.1.5:24680"` ok; `"hello"`, `"1.2.3"`, `"1.2.3.4:99999"`, `""` rejected); `test_lobby_shows_seats_names_and_the_hosts_options_read_only`; `test_tapping_a_free_seat_emits_seat_chosen_but_a_taken_seat_does_not`; `test_only_the_host_sees_bots_and_start_and_start_waits_for_full_seats`; `test_lobby_fits_a_portrait_phone_without_overflow` (360 x 780 window: every button inside the screen).
- [ ] **Step 2: Run** `-gselect=test_join_lobby_screens` — Expected: FAIL.
- [ ] **Step 3: Implement both screens**, reusing `UiStyle`.
- [ ] **Step 4: Run** `-gselect=test_join_lobby_screens` then the full suite — Expected: all pass (test_main_flow may need the Task 8 update; do not edit it here).
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 8: Main wiring: hosting, joining, reconnecting, leaving

**Files:**
- Modify: `ui/main.gd`, `ui/winner_screen.gd` (hide "Play again" for network games), `ui/game_screen.gd` (host-only "Replace with bot" button on the pause notice)
- Test: `tests/test_main_network.gd`; update `tests/test_main_flow.gd` where the Host Game flow now goes to the lobby

**Interfaces:**
- Consumes: Tasks 1-7, `PlayerProfile`.
- Produces in `Main`: `var net_mode: String` (`"fake"` for tests: uses an injected `FakeNetwork` via `main.test_network`, `"wifi"` for the app); `Host Game` -> options -> hosting starts (`WifiTransport.start_host`, `LanDiscovery.advertise` with a new room code, `LocalLink`, `SpadesHost`, `HostRunner`, the host's own `SpadesClient` joins as host with the profile name and sits South) -> Lobby; `Start game` from the lobby starts the table (`GameScreen.start_online`). `Join Game` -> JoinScreen searching continuously; choosing a game / code / address connects a `WifiTransport` client, joins with the profile name, shows the Lobby; the lobby's seat taps send `seat_request`. Errors become plain messages on the Join screen (full, game started, unreachable after 6 s, wrong version). A joiner who loses connection keeps the host address and token and retries every 2 s (the table shows "Reconnecting..."); after 30 s without success it returns to the start screen with "Could not reach the host". `game_closed` / host gone -> start screen with "The host ended the game". Menu -> Exit to start for a joiner sends `leave`; for the host closes the game for everyone. The winner screen for a network game shows only "Exit to start".

- [ ] **Step 1: Write the failing tests** (fake network, `pace = 0`) — `test_hosting_shows_the_lobby_with_a_room_code_and_the_host_seated_south`; `test_a_joiner_sees_the_lobby_and_can_take_a_seat`; `test_host_fills_bots_and_starts_and_everyone_sees_the_table`; `test_joining_a_started_game_shows_a_message_not_a_stuck_screen`; `test_a_full_game_with_four_fake_phones_reaches_the_winner_screen` (auto-play through the screens' signals; the final screen is the winner screen with no "Play again"); `test_a_dropped_joiner_reconnects_by_itself_and_the_game_goes_on`; `test_giving_up_after_30_seconds_returns_to_the_start_screen_with_a_message`; `test_host_leaving_ends_the_game_for_everyone_with_a_message`; `test_a_joiner_leaving_gives_the_seat_to_a_bot`; `test_host_can_replace_a_dropped_player_with_a_bot_from_the_pause_notice`; `test_each_phone_keeps_its_own_name_from_its_profile` (profile names appear at the other phones' tables).
- [ ] **Step 2: Run** `-gselect=test_main_network` — Expected: FAIL.
- [ ] **Step 3: Implement the wiring**; update `test_main_flow.gd` for the new Host Game -> lobby step (record each changed expectation in the ledger).
- [ ] **Step 4: Run** the full suite — Expected: all pass. Then run the app headless-with-window once on this computer (host and a second instance is not possible in one window): screenshot Start, Host options, Lobby, Join screen, and the table in a hosted game with 3 bots at 1280x720 and 360x780.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 9: Android export preset and the first APK

**Files:**
- Create: `export_presets.cfg` (Android, debug), `.gitignore` entry for `build/`, `docs/PHONE_TEST_CHECKLIST.md`
- Modify: `docs/PROJECT_PLAN.md`, `docs/ASSETS.md` only if needed

**Interfaces:**
- Produces: a debug APK at `build/GandusTable.apk`. Preset values: name `Android`, package `com.gandustable.game`, version name `0.1.0`, arm64-v8a only, permissions `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`; screen orientation sensor (portrait and landscape); "Filters to export non-resource files": `*.cfg`; export the whole project but exclude `tests/*`, `addons/gut/*`, `docs/*`. Editor settings already contain the JDK 17 path, Android SDK path and debug keystore: do not change them.
- Produces `docs/PHONE_TEST_CHECKLIST.md`: install steps (USB debugging, `adb install -r build/GandusTable.apk`, or copy the APK to the phone), then a numbered test list: first-launch name, host + join by nearby list, by code, by typed address, seats, bots, a full game, phone screen sleep and reconnect, host leaving, guest-network failure message, portrait and landscape, touch feel and fonts on the tablet, the card tap sound.

- [ ] **Step 1: Create the preset** and run `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-debug "Android" build/GandusTable.apk`. Expected: exit code 0 and the file exists. If Godot reports a missing SDK component or template, stop and report exactly what is missing; do not install anything.
- [ ] **Step 2: Verify the APK** with the SDK's `aapt2 dump badging build/GandusTable.apk` (build-tools folder): package name, the four permissions, `native-code: 'arm64-v8a'`, size in MB.
- [ ] **Step 3: Write the checklist** in plain language for a beginner.
- [ ] **Step 4: Stop for owner approval**; then, only with a phone connected and USB debugging on, run `adb devices` and `adb install -r build/GandusTable.apk` for each device the owner names (explain each command first), and confirm the app starts (`adb shell monkey -p com.gandustable.game 1`).
- [ ] **Step 5: Owner runs the checklist on real phones.** Record the results (what worked, what failed) in `docs/PROJECT_PLAN.md`; each failure becomes a bug fixed with a test first.
