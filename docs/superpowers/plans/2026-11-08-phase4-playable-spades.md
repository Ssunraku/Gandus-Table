# Phase 4 — Playable Offline Spades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the Phase 2 table screen to the Phase 3 Spades rules engine so one human (South) plays a whole game against 3 bots, from a start screen to a winner screen.

**Architecture:** A new non-UI `SpadesSession` owns one `SpadesGame` plus three `SpadesBot`s and is the only thing the screens talk to (the same seam Phase 5 networking will use). `SpadesTableView` turns the session's public view into the existing `TableState`. A `GameScreen` controller drives bot pacing and wires `Table`, the bid/swap/summary/info panels together; a small `Main` swaps Start, Host options, Settings, Game and Winner screens.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-11-08-phase4-playable-spades-design.md` (approved). Screen designs: https://www.figma.com/design/7RQIrZcBikcB5AexEh1pUP (10 screens). Rules: `docs/SPADES_RULES.md`.

## Global Constraints
- Seats are plain ints equal to `TableState.Seat` (SOUTH 0, WEST 1, NORTH 2, EAST 3); the human is SOUTH, partner NORTH. Names: `You`, `Tin` (West), `Partner` (North), `Cherry` (East). Team 0 = South+North ("Us"), team 1 = West+East ("Them").
- Screens only see `SpadesSession` public methods and `session.view()`; never `SpadesGame._hands` or `hand_of(other seat)`. Other seats appear only as card counts plus cards already played on the table.
- Typed GDScript everywhere; pure logic in `core/`, drawing in `ui/`; no networking.
- No invented rules: bids 1–13 plus Nil and Blind Nil buttons; "Blind Nil" and Nil only offered when the host settings allow them; a game rejected action changes nothing.
- Pacing constants: `BOT_PAUSE = 0.7` s per bot action, `TRICK_HOLD = 1.2` s before a finished trick is swept. Tests set `GameScreen.pace = 0.0`.
- Test command (project folder, PowerShell): `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (add `-gselect=<script name without .gd>` for one file). After adding a `class_name` file run `--headless --path . --import --quit` once.
- `CLAUDE.md`: do not commit, push or delete branches without the owner's explicit approval. Checkpoints below say "stop for owner approval"; until approved leave work uncommitted. Do not stage the stray line-ending-only `.import` / `project.godot` changes.
- Work on a new branch `phase-4-playable-spades` (create from `main` before Task 1; creating a branch is allowed).

## Review Focus
1. The human taps a card that is illegal (greyed): nothing lifts, nothing plays, no state change. Pinned in Task 3 and Task 6.
2. The human bids Blind Nil and then skips the swap (0 cards), or swaps 1 or 2: hand updates, game continues. Task 1 and Task 6.
3. The window is resized (including to portrait) while bots are pausing or a finished trick is shown: no crash, no lost or duplicated cards. Task 5 and Task 6.
4. Leaving a game from Menu then hosting a new one: no stale session or timer acts on the new game. Task 7.
5. Narrow portrait screen: 13 bid buttons wrap instead of running off screen; host option steppers stay in bounds (win ≥ 100 step 50 up to 1000; lose ≤ −50 down to −1000 step 50). Task 4 and Task 7.

---

### Task 1: SpadesSession (host-side game driver, no UI)

**Files:**
- Create: `core/spades/spades_session.gd` (`class_name SpadesSession`, `extends RefCounted`)
- Test: `tests/spades/test_session.gd`

**Interfaces:**
- Consumes: `SpadesGame` (`start_round`, `bid`, `swap`, `play`, `next_round`, `legal_cards_for`, `view_for`, `phase`, `turn_seat`, `last_round_result`, `winner_team`, `_swap_pending` is private: use `phase == SWAP` and the human's bid kind), `SpadesBot` (`choose_bid`, `choose_swap`, `choose_card`), `SpadesSettings`, `Bid`.
- Produces:
  - `_init(settings: SpadesSettings, seed_value: int, human_seat: int = 0)` — first dealer is `seed_value % 4`; bots seeded from `seed_value`.
  - `const HUMAN_NAMES := {0:"You",1:"Tin",2:"Partner",3:"Cherry"}` as `static func seat_name(seat: int) -> String`.
  - `start() -> void` (deals round 1 with seed `seed_value * 1000`).
  - `phase() -> int` (a `SpadesGame.Phase`), `turn_seat() -> int`, `settings: SpadesSettings`, `human_seat: int`.
  - `human_must_bid() -> bool`, `human_must_play() -> bool` (false while `trick_pending()`), `human_must_swap() -> bool` (phase SWAP and the human bid Blind Nil and has not swapped).
  - `submit_bid(b: Bid) -> bool`, `submit_swap(give: Array[Card], positions: Array[int]) -> bool`, `submit_play(card: Card) -> bool` (false while `trick_pending()`).
  - `advance_bots() -> Dictionary` — performs exactly one bot action and returns `{"seat": int, "kind": "bid"|"play"|"swap", "bid": Bid|null, "card": Card|null}`; returns `{}` when it is the human's turn, a trick is pending, or the round/game is over. In SWAP, bots with nothing to swap are skipped silently (never block).
  - `trick_pending() -> bool` (4 cards on the table awaiting `clear_trick()`), `shown_trick() -> Array[Dictionary]` (`[{"seat","card"}]` currently on the table, including the 4 of a finished trick), `last_trick() -> Dictionary` (`{"cards": Array[Dictionary], "winner": int}`, empty before the first trick finishes), `clear_trick() -> void`.
  - `round_over() -> bool`, `game_over() -> bool`, `winner_team() -> int`, `round_result() -> Dictionary` (copy of `last_round_result`), `next_round() -> bool` (seed `seed_value * 1000 + round_index`; only when `phase() == ROUND_OVER`).
  - `view() -> Dictionary` — `game.view_for(human_seat)` with `"trick"` replaced by `shown_trick()`, plus `"legal": Array[Card]` (the human's legal cards when `human_must_play()`, else empty), `"last_trick"` and `"names"`.

- [ ] **Step 1: Write failing tests** in `tests/spades/test_session.gd`: (a) `start()` then looping `advance_bots()` stops exactly when `human_must_bid()` first becomes true (or the first bot-only bidding finishes) and never returns a human seat; (b) `submit_bid(Bid.number(3))` on the human's turn is true, on a bot's turn false and changes nothing; (c) `submit_play` of a card not in `view()["legal"]` returns false and leaves `view()["hand"].size()` unchanged; (d) after the 4th card of a trick `trick_pending()` is true, `shown_trick().size() == 4`, `advance_bots()` returns `{}` and `submit_play` returns false until `clear_trick()`, after which the trick winner (`last_trick()["winner"]`) is `turn_seat()`; (e) a scripted human that always plays `view()["legal"][0]` and bids 3 finishes 20 games (`win_score` 100) with `game_over()` true and every action accepted; (f) human bids `Bid.blind_nil()`: when bidding ends `human_must_swap()` is true, `submit_swap([], [])` is true and phase becomes PLAYING; a second run swaps 2 own cards for positions `[0, 5]` and the human's hand is still 13 cards; (g) privacy: `view()` has `"hand"` of ≤13 cards, `"hand_counts"` ints only, and no key whose value contains a `Card` of another seat except inside `"trick"`/`"last_trick"`; (h) `next_round()` false in BIDDING, true in ROUND_OVER and the dealer moves one seat.
- [ ] **Step 2: Run** `-gselect=test_session`. Expected: FAIL/parse error "SpadesSession" not declared.
- [ ] **Step 3: Implement `SpadesSession`** per the Interfaces block. Capture the finished trick inside `submit_play`/`advance_bots` *before* the game clears it (read `trick_cards`/`trick_seats` + the winner via `TrickRules.trick_winner_index`) so `shown_trick()` can keep the 4 cards until `clear_trick()`.
- [ ] **Step 4: Run** `-gselect=test_session`. Expected: all pass. Then run the full suite: expected 188 + new tests all pass.
- [ ] **Step 5: Stop for owner approval before any commit** (suggested message: "Add SpadesSession: host-side driver for one human plus three bots").

### Task 2: TableState extension and SpadesTableView builder

**Files:**
- Modify: `core/table_state.gd` (add fields)
- Create: `core/spades/spades_table_view.gd` (`class_name SpadesTableView`, `extends RefCounted`)
- Test: `tests/spades/test_table_view.gd`; existing `tests/test_table_state.gd` must still pass.

**Interfaces:**
- Consumes: `SpadesSession.view()`, `SpadesSession.seat_name`.
- Produces: new `TableState` fields `bids: Dictionary` (Seat → `Bid`, empty when not yet bid), `spades_broken: bool`, `legal_cards: Array[Card]`, `phase: int`, `last_trick: Dictionary`; `static func SpadesTableView.build(session: SpadesSession) -> TableState` (sorted `own_hand` from `view()["hand"]`; `set_card_count` for the other three seats from `hand_counts`; `set_played` from `view()["trick"]`; names, dealer, turn, scores, bags, tricks_won copied; `legal_cards` from `view()["legal"]`).

- [ ] **Step 1: Write failing tests**: after dealing, `build()` gives `own_hand.size() == 13`, each other seat's count 13 and `get_played` null; after bots+human each play one card the played cards equal `shown_trick()` and counts drop by 1; `get_card_count(SOUTH)` equals own hand size; names are You/Tin/Partner/Cherry; `bids` has an entry only for seats that have bid; `legal_cards` is empty outside the human's play turn and a non-empty subset of `own_hand` on it.
- [ ] **Step 2: Run** `-gselect=test_table_view`. Expected: FAIL (SpadesTableView missing).
- [ ] **Step 3: Implement** the fields (typed, defaulted) and `build()`.
- [ ] **Step 4: Run** `-gselect=test_table_view` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 3: HandView — legal-card greying, face-down hand, multi-select

**Files:**
- Modify: `ui/hand_view.gd`, `ui/card_view.gd` (add `set_dimmed(on: bool)`; dimmed draws a dark translucent wash over the card like the Figma "greyed out")
- Test: `tests/test_hand_view.gd` (append)

**Interfaces:**
- Produces on `HandView`: `set_legal(cards: Array[Card], restrict: bool) -> void` (when `restrict` is false every card is playable; when true only cards matching suit+rank in `cards`; others dimmed and ignored by taps — a tap on one does nothing, not even clearing an existing lift), `set_face_down(on: bool) -> void` (cards drawn as backs, taps ignored), `set_multi_select(max_count: int) -> void` (0 = off: normal lift/play; >0 = a tap toggles a card's lift up to `max_count`, no play on second tap), `selected_cards() -> Array[Card]`, `signal selection_changed`.

- [ ] **Step 1: Write failing tests**: with `set_legal([only 2 cards], true)` tapping an illegal card leaves `selected_index == -1` and emits no `card_played`; tapping a legal card twice emits `card_played`; `set_face_down(true)` ignores taps and each child view reports `face_up == false`; with `set_multi_select(2)` tapping three cards leaves only the first two selected (third ignored), tapping a selected one deselects it, `selected_cards().size()` matches, `selection_changed` fires each time, nothing is ever played.
- [ ] **Step 2: Run** `-gselect=test_hand_view`. Expected: FAIL (new methods missing).
- [ ] **Step 3: Implement** the methods; keep existing tap/lift behaviour unchanged when none of the new modes is active.
- [ ] **Step 4: Run** `-gselect=test_hand_view` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 4: UiStyle and the panels (bid, swap, round summary, info)

**Files:**
- Create: `ui/ui_style.gd` (`class_name UiStyle`, static `style_button(b: Button, kind: String = "dark")` with kinds `dark`, `primary`, `paper_outline`, `number`; `static func panel_box() -> StyleBoxFlat` paper panel); `ui/bid_panel.gd` (`BidPanel`), `ui/swap_panel.gd` (`SwapPanel`), `ui/partner_picker.gd` (`PartnerPicker`), `ui/round_summary.gd` (`RoundSummary`), `ui/info_panel.gd` (`InfoPanel`)
- Modify: `ui/table.gd` (use `UiStyle.style_button` for Menu/Info instead of its private `_style_button`)
- Test: `tests/test_panels.gd`; existing `tests/test_table.gd`, `tests/test_polish.gd` must still pass.

**Interfaces:**
- Produces:
  - `BidPanel`: `show_blind_choice() -> void` (buttons "Blind Nil", "Look at my cards"), `show_bidding(nil_enabled: bool) -> void` (number buttons 1–13 in an `HFlowContainer` so they wrap on narrow screens, plus "Nil" only if `nil_enabled`), `signal bid_chosen(bid: Bid)`, `signal look_requested`.
  - `PartnerPicker`: `setup(count: int, max_count: int)` (face-down backs, tap toggles), `selected_positions() -> Array[int]` (ascending), `signal selection_changed`.
  - `SwapPanel`: `setup(hand: HandView, picker: PartnerPicker)`; shows "Giving N · taking M"; confirm button enabled only when N == M, labelled "Skip swap" when both 0; `signal confirmed(give: Array[Card], positions: Array[int])`.
  - `RoundSummary`: `show_result(result: Dictionary, bids: Dictionary, tricks_won: Dictionary, team_scores: Array[int], team_bags: Array[int], round_number: int)` using `SpadesScoring` result keys `points`, `bags`, `nil_results`; rows Bid, Tricks won, Nil result, Bags, Round points, Game score; `signal next_round_pressed`.
  - `InfoPanel`: `show_info(bids: Dictionary, names: Dictionary, last_trick: Dictionary)` and `signal closed`.

- [ ] **Step 1: Write failing tests**: `BidPanel` with `nil_enabled=false` has no Nil button; pressing number 7 emits `bid_chosen` with `Bid.Kind.NUMBER` and `tricks == 7`; Nil emits kind NIL; blind-choice mode emits `Bid.blind_nil()` kind and `look_requested`; in a 360-wide control the 13 number buttons' rects all lie within x ∈ [0, 360]; `PartnerPicker` never allows more than `max_count` picks; `SwapPanel` confirm disabled when 1 own and 0 partner picks, enabled at 1/1 and 2/2, text "Skip swap" at 0/0, and `confirmed` carries the picked cards and positions; `RoundSummary` text contains both teams' round points and game scores from a sample result; `InfoPanel` lists all four bids and four last-trick cards.
- [ ] **Step 2: Run** `-gselect=test_panels`. Expected: FAIL (classes missing). Run `--import --quit` first for the new class names.
- [ ] **Step 3: Implement** the classes following the Figma screens 4, 5, 6, 8 and 9 (cream panels, gold primary button, round number buttons). Fonts/colours via `GameSkin.get_current()`.
- [ ] **Step 4: Run** `-gselect=test_panels` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 5: Table live drawing

**Files:**
- Modify: `ui/table.gd`, `ui/seat_view.gd` (optional bid text), `core/table_state.gd` only if a field is missing
- Test: `tests/test_table_live.gd`

**Interfaces:**
- Consumes: Task 2 `TableState` fields; Task 3 `HandView` methods.
- Produces on `Table`: `show_game_state(state: TableState) -> void` (calls `set_state`, then `hand.set_legal(state.legal_cards, true)` only while the human must play, draws every seat's bid in its name bar as `"<name> · bid 3 · won 1"`, `"Nil"`, `"Blind Nil"` or just the name before bidding, a "Spades broken: yes/no" chip, and a "Last trick: won by <name>" chip when `state.last_trick` is non-empty); `animate_card_played(seat: int, card: Card)` (face-up card flies from that seat's fan to its play spot in `PLAY_FLIGHT`; for SOUTH use the existing lifted-card flight); `signal menu_pressed`, `signal info_pressed` wired to the existing buttons; `signal human_played(card: Card)` (replaces direct mutation of `TableState` when attached to a session: `Table.attached: bool`; when true the tap does not call `state.play_own_card`).

- [ ] **Step 1: Write failing tests**: after `show_game_state` with a state that has West/North/East played cards, `Table` draws 3 played views at the play spots; seat bar text for a seat with bid 3 and 1 trick contains "bid 3" and "won 1"; chip text reflects `spades_broken`; tapping a legal card emits `human_played` and does not touch `state.own_hand` when `attached`; resizing to 720×1280 and back mid-`animate_card_played` leaves exactly the right number of played views and no orphan flying card after the tween finishes (use `await get_tree().create_timer(PLAY_FLIGHT + 0.1).timeout`).
- [ ] **Step 2: Run** `-gselect=test_table_live`. Expected: FAIL.
- [ ] **Step 3: Implement**. Keep `auto_start` dummy behaviour for the existing tests.
- [ ] **Step 4: Run** `-gselect=test_table_live` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 6: GameScreen controller (session + table + panels + pacing)

**Files:**
- Create: `ui/game_screen.gd` (`class_name GameScreen`, `extends Control`)
- Test: `tests/test_game_screen.gd`

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: `signal game_finished(winner_team: int, team_scores: Array[int])`, `signal exit_to_start`; `var pace: float = 1.0` (multiplies `BOT_PAUSE`/`TRICK_HOLD`; 0 = immediate); `start(settings: SpadesSettings, seed_value: int) -> void`; `step() -> bool` (does the next automatic thing: one bot action, or clear a pending trick, or open the round summary; returns false when waiting on the human); `refresh() -> void`; `session: SpadesSession` (read-only use). Flow: Blind Nil enabled → hand face-down and `BidPanel.show_blind_choice()` on the human's first bidding turn each round until "Look at my cards" or Blind Nil; then `show_bidding`. Blind Nil → `SwapPanel` with multi-select hand and `PartnerPicker`. A `Timer` or `await get_tree().create_timer()` loop drives `step()`; Menu opens a small panel with Resume and Exit to start (stops the loop); Info opens `InfoPanel`.

- [ ] **Step 1: Write failing tests** with `pace = 0.0`: (a) a scripted driver that, each time `step()` is false, plays `session.view()["legal"][0]` or bids 3 plays a full game to `game_finished` with `win_score = 100`; (b) with Blind Nil enabled the hand is face-down until `look_requested`, then face-up; (c) tapping an illegal card (simulate via `hand.handle_tap`) changes nothing: `session.view()["hand"].size()` and turn unchanged; (d) Blind Nil bid → swap panel visible, confirming 2/2 leaves the hand at 13 cards, confirming 0/0 ("Skip swap") continues to PLAYING; (e) resizing the screen between steps never changes card counts; (f) Menu → Exit emits `exit_to_start` and a later `step()` does nothing (loop stopped).
- [ ] **Step 2: Run** `-gselect=test_game_screen`. Expected: FAIL.
- [ ] **Step 3: Implement** `GameScreen`: owns `Table` (child), the four panels (overlays), builds state with `SpadesTableView.build(session)` after every action, calls `table.animate_card_played` for each bot play, and checks `session.game_over()` → emit `game_finished` after the final summary.
- [ ] **Step 4: Run** `-gselect=test_game_screen` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 7: Main flow — start, host options, settings, winner, main scene

**Files:**
- Create: `ui/main.gd` + `ui/main.tscn` (root `Control`), `ui/start_screen.gd`, `ui/host_options_screen.gd`, `ui/settings_screen.gd`, `ui/winner_screen.gd`
- Modify: `project.godot` (`run/main_scene="res://ui/main.tscn"`)
- Test: `tests/test_main_flow.gd`

**Interfaces:**
- Produces: `StartScreen` signals `host_pressed`, `settings_pressed`, `exit_pressed`; "Join Game" button present but `disabled`, with a "Coming soon" label. `HostOptionsScreen`: `settings() -> SpadesSettings` reflecting switches (Blind Nil, Normal Nil, Redeal, Bags penalty, Play higher) and steppers (win score 100–1000 step 50, lose score −1000…−50 step 50); signals `start_pressed(settings)`, `back_pressed`. `SettingsScreen`: sound switch bound to `SoundBank.enabled` (Task 8; until then a stored bool on `Main`), `back_pressed`. `WinnerScreen`: `show_result(winner_team: int, scores: Array[int], win_score: int)`, signals `play_again_pressed`, `exit_pressed`. `Main`: `show_screen(name)`; Exit calls `get_tree().quit()` (guard so tests can stub it via `Main.quit_requested` signal); starting a game creates a fresh `GameScreen` and frees the old one; leaving frees it.

- [ ] **Step 1: Write failing tests**: default `HostOptionsScreen.settings()` equals `SpadesSettings.new()` field by field; toggling Blind Nil off and +1 step on win score gives `blind_nil_enabled == false`, `win_score == 550`; steppers clamp at both ends (win 1000, lose −1000, win 100, lose −50); Start→Host→Start Game shows a `GameScreen` with a started session using those settings; Menu→Exit to start then Host→Start Game again produces a *different* `GameScreen` instance and the old one is freed (`is_instance_valid` false) and the old session's `advance_bots` is never called again; winner flow: `game_finished(0, scores)` shows WinnerScreen with text containing "You and Partner win"; `game_finished(1, …)` shows "Tin and Cherry win"; Play again starts a new game with the same settings; Join Game is disabled.
- [ ] **Step 2: Run** `-gselect=test_main_flow`. Expected: FAIL. Run `--import --quit` first.
- [ ] **Step 3: Implement** following Figma screens 1, 2, 3 and 10.
- [ ] **Step 4: Run** `-gselect=test_main_flow` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 8: Placeholder sounds

**Files:**
- Create: `ui/sound_bank.gd` (`class_name SoundBank`, `extends Node`)
- Modify: `ui/main.gd` (add one `SoundBank` child and connect `GameScreen` events), `ui/settings_screen.gd` (bind switch)
- Test: `tests/test_sound_bank.gd`

**Interfaces:**
- Produces: `SoundBank.enabled: bool = true`; `play(event: String) -> bool` for events `deal`, `play`, `trick`, `turn`, `bid`, `win`, `lose` — each a short synthesised tone built at startup as an `AudioStreamWAV` (16-bit mono, 22050 Hz, ≤0.3 s, no files); returns false and plays nothing when `enabled` is false or the event is unknown.

- [ ] **Step 1: Write failing tests**: every event name has a non-null stream with `data.size() > 0` and length ≤ 0.35 s; `play("nope")` false; `enabled = false` makes `play("deal")` false.
- [ ] **Step 2: Run** `-gselect=test_sound_bank`. Expected: FAIL.
- [ ] **Step 3: Implement** (sine/square beeps with a short fade-out; one `AudioStreamPlayer` per event).
- [ ] **Step 4: Run** `-gselect=test_sound_bank` then the full suite. Expected: all pass.
- [ ] **Step 5: Stop for owner approval before any commit.**

### Task 9: Docs, screenshots, owner play test, final verification

**Files:**
- Modify: `README.md` (status paragraph and "See the table" → how to play a game), `docs/PROJECT_PLAN.md` (Phase 4 DONE note with evidence), `docs/OPEN_QUESTIONS.md` (add: time limit per card, host option and bot takeover — decide in Phase 5), `docs/superpowers/specs/2026-11-08-phase2-card-table-design.md` (fix the felt-tap wording: tapping empty table puts a lifted card back down)
- No new tests.

- [ ] **Step 1: Run the full test suite.** Expected: "All tests passed!" with the new total printed; record the number.
- [ ] **Step 2: Screenshots.** Run the game with `--headless`-free Godot at 1280×720, 720×1280, 800×600 and 2000×1200 (change the window size in a throwaway run script, not in `project.godot`) and capture the start, bidding, playing, swap and summary screens; compare with the Figma screens and note any defect.
- [ ] **Step 3: Owner play test.** Ask the owner to press F5 and play one whole game on the PC (explain F5 and what to look for: illegal cards greyed, bots pause, scores correct, winner screen). Fix defects found with a failing test first.
- [ ] **Step 4: Update the docs** listed above with only verified facts (counts, what was checked, what was not: tablet, real artwork, real sounds).
- [ ] **Step 5: Stop for owner approval** to commit everything on `phase-4-playable-spades` and later to merge into `main` (never push or merge without approval).
