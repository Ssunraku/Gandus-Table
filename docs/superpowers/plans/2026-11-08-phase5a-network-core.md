# Phase 5A — Network Core (no screens, no real Wi-Fi) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything a Wi-Fi game needs except the screens and the real network: message format, a swappable transport contract with an in-memory fake, a host that runs lobby + game for several humans (bots in the other seats), a client that turns the host's messages into the table's `TableState`, and drop-and-rejoin. Proven by whole games played by four fake clients on one computer.

**Architecture:** `SpadesHost` (host-authoritative, owns a `SpadesSession` that now supports several human seats) talks to players only through a `Transport` carrying JSON text messages. Each human, including the host's own player, is a `SpadesClient` connected through a transport (the host's own player uses an in-process loopback). After every change the host sends each human a full `game_view` snapshot containing only what that seat may know. `SpadesClient` rotates the snapshot so the player's own seat is South and fills a `TableState`.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1. No real networking in this plan.

**Spec:** `docs/superpowers/specs/2026-11-08-phase5-wifi-multiplayer-design.md` (approved). Rules: `docs/SPADES_RULES.md`. Plan 5B (Wi-Fi transport, discovery, Join/Lobby/Paused screens, phone test) is written after this plan is finished.

## Global Constraints
- Seats are ints equal to `TableState.Seat` (SOUTH 0, WEST 1, NORTH 2, EAST 3) everywhere on the host and on the wire; only `SpadesClient.to_table_state()` rotates so the viewer is South. Teams: seat % 2.
- Typed GDScript; new files under `net/` (pure logic, no UI, no engine networking). Offline play must not change: every existing test keeps passing, and `SpadesSession(settings, seed)` with one human behaves as before.
- Private cards: a message to one player contains only that seat's own hand, other seats' card counts, and public facts. A Blind Nil bidder's hand stays hidden while bidding (already done by `SpadesGame.view_for`).
- Wire format: one JSON object per message: `{"v": 1, "type": String, "seq": int, ...fields}`. Cards are `{"s": suit int, "r": rank int}`; bids `{"k": kind int, "n": tricks int}`. JSON turns ints into floats, so every decode path converts back with `int()`.
- The host decides the seat from the connection, never from a field in the message (a player cannot act for another seat).
- Any malformed, unknown, oversized (> 16 KB) or wrong-version message is ignored without a crash.
- Names: `PlayerProfile.clean` then `PlayerProfile.unique` against names already seated.
- Test command (project folder, PowerShell): `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (add `-gselect=<script name without .gd>`). After adding a `class_name` file run `--headless --path . --import --quit` once. Engine warnings count as test failures.
- `CLAUDE.md`: never commit, push or delete branches without the owner's explicit approval; checkpoints say "stop for owner approval". Creating a branch is allowed: work on `phase-5a-network-core` cut from `main`. Do not stage stray line-ending-only `.import` changes.
- Rulings made while planning (owner may overrule): the host sends full snapshots instead of small updates (simpler, and a rejoining phone just gets the latest one); "Next round" is accepted from any seated human and is idempotent; the host's own player is recognised by `Transport.is_local_peer`.

## Review Focus
1. A client sends a `play_card`/`bid` with someone else's seat, out of turn, or a card it does not hold: refused with `action_rejected`, no state change (Task 6).
2. Garbage, truncated, huge or wrong-version text arrives from a peer: ignored, host keeps running (Task 2, Task 5).
3. Two players ask for the same seat in the same moment; a join after the game started; the same name twice (Task 5).
4. A player drops during bidding, during the Blind Nil swap, and mid-trick; rejoins with the right token, a wrong token, and after being replaced by a bot (Task 8).
5. Whole-game privacy: across every message of a full game, no player ever receives a card that is in another player's hand at that moment (Task 9).

---

### Task 1: Wire codec for cards, bids and settings

**Files:**
- Create: `net/wire.gd` (`class_name Wire`, `extends RefCounted`)
- Test: `tests/net/test_wire.gd`

**Interfaces:**
- Produces (all static): `card_to_dict(c: Card) -> Dictionary`, `card_from_dict(d: Dictionary) -> Card` (null if invalid suit/rank), `cards_to_array(cs: Array[Card]) -> Array`, `cards_from_array(a: Array) -> Array[Card]`, `bid_to_dict(b: Bid) -> Dictionary`, `bid_from_dict(d: Dictionary) -> Bid` (null if invalid, tricks 1–13 for NUMBER), `settings_to_dict(s: SpadesSettings) -> Dictionary`, `settings_from_dict(d: Dictionary) -> SpadesSettings` (every field of `SpadesSettings` incl. `exact_mode`; missing fields keep defaults; `bags_penalty_enabled` forced off when `exact_mode != OFF`).

- [ ] **Step 1: Write the failing tests** — `test_card_round_trip_through_json` (all 52 cards: `to_dict` → `JSON.stringify` → `JSON.parse_string` → `from_dict` equals original suit and rank); `test_invalid_card_is_null` (`{"s": 9, "r": 2}`, `{}`, rank 1 and 15); `test_bid_round_trip_for_number_nil_and_blind_nil`; `test_invalid_bid_is_null` (tricks 0, 14, kind 7); `test_settings_round_trip_keeps_every_option` (non-default value for each field incl. `ExactMode.HARD` and win/lose scores); `test_settings_from_empty_dict_gives_defaults`.
- [ ] **Step 2: Run** `-gselect=test_wire` — Expected: FAIL (script cannot load: `Wire` missing).
- [ ] **Step 3: Implement `Wire`** with the signatures above; read every number through `int()`.
- [ ] **Step 4: Run** `-gselect=test_wire` — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 2: Protocol messages

**Files:**
- Create: `net/protocol.gd` (`class_name Protocol`, `extends RefCounted`)
- Test: `tests/net/test_protocol.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `const VERSION: int = 1`, `const MAX_BYTES: int = 16384`, `const TYPES: Array[String]` = `["join_request","join_accepted","join_refused","seat_request","lobby_state","add_bots","start_game","leave","rejoin_request","game_view","game_paused","game_resumed","bid","swap","play_card","next_round","replace_with_bot","action_rejected","game_closed"]`; `static func make(type: String, fields: Dictionary = {}, seq: int = 0) -> Dictionary`; `static func encode(msg: Dictionary) -> String`; `static func decode(text: String) -> Dictionary` (returns `{}` unless valid JSON object, `v == VERSION`, `type` in `TYPES`, size ≤ `MAX_BYTES`; `seq` and `v` converted to int).

- [ ] **Step 1: Write the failing tests** — `test_make_adds_version_type_and_seq`; `test_encode_decode_round_trip`; `test_decode_rejects_garbage_text` (`"hello"`, `""`, `"[1,2]"`, `"{"`); `test_decode_rejects_unknown_type`; `test_decode_rejects_wrong_version`; `test_decode_rejects_oversized_text` (17,000 characters); `test_decoded_numbers_are_ints` (`typeof(msg["seq"]) == TYPE_INT`).
- [ ] **Step 2: Run** `-gselect=test_protocol` — Expected: FAIL.
- [ ] **Step 3: Implement `Protocol`.**
- [ ] **Step 4: Run** `-gselect=test_protocol` — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 3: Transport contract and fake network

**Files:**
- Create: `net/transport.gd` (`class_name Transport`, `extends RefCounted`), `net/fake_network.gd` (`class_name FakeNetwork`), `net/fake_transport.gd` (`class_name FakeTransport`, `extends Transport`)
- Test: `tests/net/test_fake_network.gd`

**Interfaces:**
- Produces `Transport` (base, methods overridden by implementations): `signal peer_connected(peer_id: int)`, `signal peer_disconnected(peer_id: int)`, `signal message_received(peer_id: int, text: String)`; `func send_to(peer_id: int, text: String) -> void`, `func broadcast(text: String) -> void`, `func is_local_peer(peer_id: int) -> bool`, `func close() -> void`. On a client transport the only peer is the host (id 1); on a host transport peers are clients (ids 2, 3, …).
- Produces `FakeNetwork`: `func host_transport() -> FakeTransport` (one per network); `func connect_client(local: bool = false) -> FakeTransport` (a client; `local = true` is the host's own in-process player; emits `peer_connected` on both sides); `func drop(client: FakeTransport) -> void` (simulates a lost connection: both sides get `peer_disconnected`); `func pump() -> int` (delivers every queued message and connection event, including ones queued during delivery, returns how many; delivery is never synchronous inside `send_to`).

- [ ] **Step 1: Write the failing tests** — `test_client_message_reaches_host_with_the_client_peer_id`; `test_host_send_to_reaches_only_that_client`; `test_broadcast_reaches_every_client`; `test_nothing_is_delivered_until_pump`; `test_messages_arrive_in_the_order_sent`; `test_drop_tells_both_sides_and_stops_delivery`; `test_is_local_peer_true_only_for_the_local_client`; `test_pump_handles_messages_sent_while_delivering`.
- [ ] **Step 2: Run** `-gselect=test_fake_network` — Expected: FAIL.
- [ ] **Step 3: Implement** the three classes (a single queue of events inside `FakeNetwork`).
- [ ] **Step 4: Run** `-gselect=test_fake_network` — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 4: SpadesSession supports several human seats

**Files:**
- Modify: `core/spades/spades_session.gd`
- Test: `tests/spades/test_session_multi.gd` (existing `tests/spades/test_session.gd` must stay green untouched)

**Interfaces:**
- Consumes: `SpadesGame`, `SpadesBot`, `SpadesSettings`.
- Produces on `SpadesSession` (existing single-human methods and `_init(settings, seed, human = 0)` unchanged and delegate to these): `var human_seats: Array[int]` (initially `[human]`); `func set_human_seats(seats: Array[int]) -> void` (call before `start()`); `func make_human(seat: int) -> void`, `func make_bot(seat: int) -> void` (change who controls a seat at any time); `func is_human(seat: int) -> bool`; `func must_bid(seat: int) -> bool`, `func must_play(seat: int) -> bool`, `func must_swap(seat: int) -> bool`; `func bid_for(seat: int, b: Bid) -> bool`, `func swap_for(seat: int, give: Array[Card], positions: Array[int]) -> bool`, `func play_for(seat: int, card: Card) -> bool`; `func view_for_seat(seat: int) -> Dictionary` (same keys as `view()` plus `legal` for that seat, `names`); `func set_names(names: Dictionary) -> void` (seat -> String; `view` uses it instead of `NAMES`). `advance_bots()` only acts for seats that are not human. Swap position shuffling is kept per seat.

- [ ] **Step 1: Write the failing tests** — `test_two_humans_each_only_act_on_their_own_turn` (seats 0 and 2 human; seat 2 cannot bid when it is seat 0's turn; `bid_for` returns false and changes nothing); `test_bots_play_the_other_seats_and_never_the_humans` (loop `advance_bots()` until it returns `{}`, it stops at a human's turn, never plays for a human seat); `test_view_for_seat_only_has_that_seats_cards` (hand of seat 2 differs from seat 0's, other seats appear only in `hand_counts`); `test_make_bot_hands_a_seat_to_the_bot_in_the_middle_of_a_round`; `test_make_human_takes_a_seat_back`; `test_set_names_changes_view_names`; `test_swap_for_second_human_uses_its_own_shuffle`; `test_single_human_session_still_behaves_as_before` (offline path through `view()`).
- [ ] **Step 2: Run** `-gselect=test_session_multi` — Expected: FAIL.
- [ ] **Step 3: Implement** by generalising `human_must_*` / `submit_*` onto the seat-parameterised methods; do not change `SpadesGame`.
- [ ] **Step 4: Run** the full suite — Expected: all previous tests plus the new ones pass (306+ → no regressions).
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 5: SpadesHost lobby

**Files:**
- Create: `net/spades_host.gd` (`class_name SpadesHost`, `extends RefCounted`)
- Test: `tests/net/test_host_lobby.gd`

**Interfaces:**
- Consumes: `Transport`, `Protocol`, `Wire`, `PlayerProfile`, `SpadesSettings`.
- Produces: `func _init(transport: Transport, settings: SpadesSettings, game_seed: int)`; the host connects to `transport.message_received`/`peer_disconnected`. Public state for tests/UI: `seats: Array[Dictionary]` (4 entries `{"kind": "empty"|"human"|"bot", "name": String, "peer": int, "token": String}`), `phase_name() -> String` (`"lobby"`, `"playing"`, `"closed"`), `host_peer: int`.
- Messages handled in lobby: `join_request {name, as_host?: bool}` → `join_accepted {token, name}` (name made unique; `as_host` honoured only if `is_local_peer`) or `join_refused {reason}` (game started, or no free seat while all four taken and the joiner has no seat: spectators are not supported) then a `lobby_state`; `seat_request {seat}` (seat 0–3, must be empty; a player who already sits moves, freeing the old seat); `leave`; `add_bots` (host peer only: every empty seat becomes `bot`); `start_game` (host peer only, every seat non-empty). `lobby_state {seats: [{kind, name}], settings: Wire.settings_to_dict, you: seat or -1}` is sent to every connected peer after every change (each message's `you` is that peer's own seat).
- Rejects with `action_rejected {reason}` otherwise.

- [ ] **Step 1: Write the failing tests** (each uses `FakeNetwork`, `SpadesHost`, raw `Protocol.encode` messages from `connect_client()` transports and `pump()`): `test_join_gets_a_token_and_a_lobby_state_with_the_hosts_options`; `test_same_name_twice_gets_a_number`; `test_player_picks_a_free_seat_and_everyone_sees_it`; `test_two_players_asking_for_the_same_seat_only_one_wins`; `test_player_can_move_to_another_empty_seat`; `test_only_the_local_host_player_can_add_bots_and_start`; `test_start_needs_every_seat_filled`; `test_add_bots_fills_only_the_empty_seats`; `test_join_after_start_is_refused`; `test_leave_in_the_lobby_frees_the_seat`; `test_garbage_and_oversized_messages_are_ignored_and_the_host_keeps_working`; `test_a_join_request_with_a_hostile_name_is_cleaned` (control characters, 200 characters).
- [ ] **Step 2: Run** `-gselect=test_host_lobby` — Expected: FAIL.
- [ ] **Step 3: Implement the lobby half of `SpadesHost`** (tokens: 16 random hex characters from `Crypto`/`RandomNumberGenerator`; keep game start for Task 6).
- [ ] **Step 4: Run** `-gselect=test_host_lobby` — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 6: SpadesHost game flow and snapshots

**Files:**
- Modify: `net/spades_host.gd`
- Test: `tests/net/test_host_game.gd`

**Interfaces:**
- Consumes: Task 4 `SpadesSession` multi-human API, Task 5 `SpadesHost`.
- Produces: `start_game` creates `SpadesSession(settings, game_seed)` with `set_human_seats` (seats whose kind is `human`), `set_names`, `start()`, then broadcasts `game_view` to each human. `func step() -> bool` does exactly one automatic thing like `GameScreen.step()` (clear a finished trick, advance one bot action, or note the round is over) and sends fresh snapshots; returns false when waiting for a human or finished; the app (later) supplies the pauses. Handles `bid {bid}`, `swap {give, positions}`, `play_card {card}`, `next_round`, always using the seat bound to the sender's connection.
- `game_view` message fields: `seat` (the receiver's seat), `phase`, `turn_seat`, `dealer_seat`, `hand` (cards, receiver's only), `hand_counts` (seat -> int, strings as keys because JSON), `trick` (`[{seat, card}]`), `last_trick` (`{cards, winner}` or `{}`), `bids` (seat -> bid dict), `tricks_won`, `team_scores`, `team_bags`, `spades_broken`, `legal` (cards, only when it is the receiver's turn to play), `must_bid`/`must_play`/`must_swap` (bools), `names` (seat -> String), `swap` (the receiver's own swap view or `{}`), `round_over`, `game_over`, `winner_team`, `round_result` (when round over), `round_number`, `redeal` (messages), `event` (`{"kind": "bid"|"play"|"trick"|"deal", "seat": int}` of the latest change, `{}` if none), `paused` (bool).
- Rejections: wrong turn, wrong seat, card not in hand, illegal card, bid not allowed by settings → `action_rejected {reason}` to that peer only; no snapshot changes.

- [ ] **Step 1: Write the failing tests** — `test_start_sends_each_human_a_snapshot_with_only_their_own_hand` (2 humans + 2 bots; seat 0 and seat 2 hands differ; each message lists only its own cards); `test_snapshot_never_contains_other_seats_cards_in_any_field` (collect every card in the encoded text of one player's snapshot and check each is either in their hand or on the table/last trick); `test_a_bid_out_of_turn_is_rejected_and_changes_nothing`; `test_a_play_for_another_seat_is_ignored_because_the_seat_comes_from_the_connection` (message has `"seat": 2` field sent by the seat-0 peer); `test_playing_a_card_not_in_hand_is_rejected`; `test_playing_an_illegal_card_is_rejected_and_the_legal_list_is_unchanged`; `test_step_advances_bots_and_stops_at_a_humans_turn`; `test_a_legal_play_updates_every_players_snapshot_with_an_event`; `test_next_round_is_idempotent_and_only_works_when_the_round_is_over`; `test_blind_nil_swap_between_two_humans_hides_the_partners_cards` (partner's hand never in the bidder's messages, only the swap view).
- [ ] **Step 2: Run** `-gselect=test_host_game` — Expected: FAIL.
- [ ] **Step 3: Implement** the game half of `SpadesHost`; build snapshots from `SpadesSession.view_for_seat` + `Wire`.
- [ ] **Step 4: Run** `-gselect=test_host_game` then the full suite — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 7: SpadesClient and the table view

**Files:**
- Create: `net/spades_client.gd` (`class_name SpadesClient`, `extends RefCounted`)
- Test: `tests/net/test_client.gd`

**Interfaces:**
- Consumes: `Transport`, `Protocol`, `Wire`, `TableState`, `Deck.sort_hand`.
- Produces: `func _init(transport: Transport)`; `func join(player_name: String, as_host: bool = false) -> void`; `func request_seat(seat: int)`, `leave()`, `add_bots()`, `start_game()`, `send_bid(b: Bid)`, `send_swap(give: Array[Card], positions: Array[int])`, `send_play(card: Card)`, `next_round()`, `rejoin(token: String)`; read-only `token: String`, `my_seat: int` (-1 until seated), `lobby: Dictionary` (last `lobby_state`), `view: Dictionary` (last `game_view`, decoded: ints, `Card`/`Bid` objects), `last_rejection: String`, `connected: bool`; signals `lobby_changed`, `view_changed`, `rejected(reason: String)`, `paused_changed(paused: bool, who: String)`, `closed(reason: String)`; `func to_table_state() -> TableState` — own seat becomes South, others by `(seat - my_seat + 4) % 4`; `team_scores`/`team_bags` ordered `[own team, other team]`; `seat_names[SOUTH] = "You"`, others their names; `can_play`, `legal_cards`, `phase`, `bids`, `tricks_won`, `last_trick` (seats rotated), dealer and turn rotated.

- [ ] **Step 1: Write the failing tests** — `test_join_stores_the_token_and_seat`; `test_to_table_state_puts_my_seat_at_the_bottom_for_each_seat` (loop my_seat 0..3: own hand real, South name "You", partner at North); `test_scores_are_listed_own_team_first_for_the_other_team_too` (seat 1 sees team 1 first); `test_played_cards_and_turn_are_rotated`; `test_legal_cards_and_can_play_only_when_it_is_my_turn`; `test_rejection_is_reported`; `test_garbage_from_the_host_is_ignored`.
- [ ] **Step 2: Run** `-gselect=test_client` — Expected: FAIL.
- [ ] **Step 3: Implement `SpadesClient`.**
- [ ] **Step 4: Run** `-gselect=test_client` — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 8: Drop, pause, rejoin, replace, leave

**Files:**
- Modify: `net/spades_host.gd`, `net/spades_client.gd`
- Test: `tests/net/test_host_reconnect.gd`

**Interfaces:**
- Produces on the host: when a seated human's peer disconnects during `playing`, the host sets `paused`, broadcasts `game_paused {seat, name}`, and `step()` returns false until resumed. `rejoin_request {token}` from a new peer whose token matches a disconnected human seat rebinds that seat to the new peer, sends it the latest `game_view`, and when no human is missing broadcasts `game_resumed`. A wrong or unknown token gets `join_refused`. `replace_with_bot {seat}` (host peer only) makes that seat a bot (`SpadesSession.make_bot`), invalidates its token, and resumes if nobody else is missing. `leave` during a game turns that seat into a bot immediately (no pause). If the host's own peer disconnects (or the host calls `close()`), `game_closed {reason}` goes to everyone and `phase_name()` is `"closed"`.
- Client: `rejoin(token)` sends `rejoin_request`; `paused_changed` and `closed` fire from the messages; `connected` turns false on `peer_disconnected`.

- [ ] **Step 1: Write the failing tests** — `test_a_drop_pauses_the_game_for_everyone_and_bots_stop`; `test_rejoin_with_the_right_token_restores_the_same_seat_and_hand`; `test_rejoin_with_a_wrong_token_is_refused_and_the_game_stays_paused`; `test_rejoin_after_being_replaced_by_a_bot_is_refused`; `test_host_can_replace_a_dropped_player_with_a_bot_and_the_game_resumes`; `test_only_the_host_can_replace_with_a_bot`; `test_leaving_on_purpose_hands_the_seat_to_a_bot_without_pausing`; `test_drop_during_bidding`; `test_drop_during_the_blind_nil_swap`; `test_drop_in_the_middle_of_a_trick`; `test_host_disconnect_closes_the_game_for_everyone`; `test_two_players_dropped_game_resumes_only_when_both_are_back`.
- [ ] **Step 2: Run** `-gselect=test_host_reconnect` — Expected: FAIL.
- [ ] **Step 3: Implement** pause/rejoin/replace/leave/close.
- [ ] **Step 4: Run** `-gselect=test_host_reconnect` then the full suite — Expected: all pass.
- [ ] **Step 5: Stop for owner approval** before any commit.

### Task 9: Whole games over the fake network

**Files:**
- Create: `tests/net/auto_player.gd` (`class_name AutoPlayer`, test helper: given a `SpadesClient`, when it is that player's turn it bids 3, swaps 0 cards if Blind Nil never offered, and plays the first legal card)
- Test: `tests/net/test_net_full_games.gd`
- Modify: `docs/PROJECT_PLAN.md` (Phase 5 row: 5A built, 5B next), `docs/ARCHITECTURE.md` (replace the "draft idea" protocol/transport wording with what was built, and say snapshots are used)

**Interfaces:**
- Consumes: Tasks 1–8.

- [ ] **Step 1: Write the failing tests** — `test_four_humans_play_a_whole_game_to_the_end` (host's local player + 3 remote clients; loop `network.pump()`, `host.step()`, auto players until `game_over`; assert each client's final `team_scores` equal the host session's, and `winner_team` agrees); `test_two_humans_and_two_bots_play_a_whole_game`; `test_no_player_ever_receives_a_card_from_another_hand` (record every message text sent to each peer during a full game; for each `game_view`, every card in `hand` is in that seat's real hand at that moment, and no card string appears in any other field except `trick`, `last_trick`, `swap` for the right seats; assert the check actually ran on at least 100 messages); `test_a_player_drops_and_rejoins_in_the_middle_and_the_game_still_finishes`; `test_exact_bids_mode_works_over_the_network` (settings with `ExactMode.EASY`, game finishes, `round_result` carries `player_points`).
- [ ] **Step 2: Run** `-gselect=test_net_full_games` — Expected: FAIL until `AutoPlayer` exists, then fix any real defect it reveals with systematic debugging (new regression test first).
- [ ] **Step 3: Update the two docs** (short; plain language).
- [ ] **Step 4: Run** the full suite — Expected: every test passes; report the total.
- [ ] **Step 5: Stop for owner approval**; offer the commit, and say plainly that nothing has been tried on real phones yet.
