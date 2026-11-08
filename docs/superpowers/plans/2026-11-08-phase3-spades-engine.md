# Phase 3: Spades Rules Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pure game logic for Spades (all rules in `docs/SPADES_RULES.md`) with automated tests, finishing with full simulated games played by bots.

**Architecture:** Layer 2 only: no UI, no networking, no Godot nodes. Small `RefCounted` classes in `core/spades/`, each doing one job (settings, hand checks, legal plays, scoring, bidding, game flow, bot). `SpadesGame` is the host-side authority: it owns every hand and exposes only validated actions (`bid`, `swap`, `play`). A separate method returns what one seat is allowed to see, so the later network layer never leaks private cards.

**Tech Stack:** Godot 4.7 GDScript with static typing; GUT 9.7.1 tests. Reuses `Card`, `Deck` and `TableState.Seat`.

**Spec:** `docs/SPADES_RULES.md` (approved by the owner 2026-11-08; the three marked [ASSUMPTION] items stand unless the owner changes them).

## Global Constraints

- Typed GDScript everywhere (`var x: int`, `func f(a: String) -> bool`); `class_name` per file.
- Files live in `core/spades/`; nothing in `core/spades/` may reference `Control`, `Node`, `Input`, network or UI classes. (Tested: the folder scripts extend `RefCounted`.)
- Seats: `TableState.Seat` (SOUTH, WEST, NORTH, EAST), clockwise order S, W, N, E. Teams: SOUTH+NORTH = team 0, WEST+EAST = team 1.
- Deterministic: every random choice takes an explicit integer seed so tests can replay games.
- Rule defaults (from the spec): Blind Nil on, normal Nil on, redeal on, bags penalty on, "play higher" off, win 500, lose -200.
- Test command: `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (after adding `class_name` files, run `--headless --path . --import --quit` once).
- No commit without the owner's approval (CLAUDE.md); tasks end with a "ready to commit" point, not a commit.

## Review Focus

- A hand that is exactly 13 spades: redeal (void in three suits), and the 3rd deal is accepted even if void.
- Nil bidder wins tricks while partner makes bid: team bid result uses the partner's tricks only; failed Nil adds no bags.
- Both partners bid normal Nil (allowed): no numeric team bid; each Nil scored on its own; no divide-by-zero or "bid 0 made" score of 0 mistaken for a bag.
- Bags crossing 10 in the same round that also scores a made bid: penalty applies once, count drops by 10, can cross twice only if bags reach 20.
- Illegal actions never change state: wrong turn, wrong phase, card not in hand, leading an unbroken spade, spade on first trick, Blind Nil when disabled, both partners Blind Nil.

## File Structure

- `core/spades/spades_settings.gd` - host options and defaults.
- `core/spades/hand_check.gd` - void detection, suit counts.
- `core/spades/trick_rules.gd` - legal cards, trick winner (static functions).
- `core/spades/spades_scoring.gd` - round and game scoring (static functions).
- `core/spades/bid.gd` - one player's bid value (number, nil, blind nil).
- `core/spades/spades_game.gd` - state machine: deal, bidding, swap, play, scoring, game over.
- `core/spades/spades_bot.gd` - simple bot choosing legal actions.
- `tests/spades/test_*.gd` - one test file per source file, plus `test_full_games.gd`.

---

### Task 1: SpadesSettings and Bid

**Files:** Create `core/spades/spades_settings.gd`, `core/spades/bid.gd`; Test `tests/spades/test_settings_bid.gd`.

**Interfaces:**
- Produces: `SpadesSettings` fields `blind_nil_enabled: bool = true`, `nil_enabled: bool = true`, `redeal_enabled: bool = true`, `bags_penalty_enabled: bool = true`, `play_higher_enabled: bool = false`, `win_score: int = 500`, `lose_score: int = -200`; `func nil_value() -> int` (100); `func blind_nil_value() -> int` (200, or 100 when `nil_enabled` is false).
- Produces: `Bid` with `enum Kind {NUMBER, NIL, BLIND_NIL}`, `var kind`, `var tricks: int`, `static func number(n: int) -> Bid`, `static func nil() -> Bid`, `static func blind_nil() -> Bid`.

- [ ] **Step 1:** Write tests: defaults equal the spec table; `blind_nil_value()` is 200 normally and 100 when `nil_enabled = false`; `Bid.number(5).tricks == 5`; `Bid.nil().kind == NIL`.
- [ ] **Step 2:** Run the new test file; expected FAIL (classes missing).
- [ ] **Step 3:** Implement both classes.
- [ ] **Step 4:** Run; expected PASS.

### Task 2: HandCheck (void detection)

**Files:** Create `core/spades/hand_check.gd`; Test `tests/spades/test_hand_check.gd`.

**Interfaces:** Produces `static func has_void(hand: Array[Card]) -> bool` (true if any of the 4 suits has zero cards), `static func count_suit(hand: Array[Card], suit: Card.Suit) -> int`, `static func has_only_spades(hand: Array[Card]) -> bool`.

- [ ] **Step 1:** Tests: 13 spades -> void; a hand with all four suits -> not void; `has_only_spades` true for 3 spades, false for empty? (empty hand returns false).
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS.

### Task 3: TrickRules (legal plays and trick winner)

**Files:** Create `core/spades/trick_rules.gd`; Test `tests/spades/test_trick_rules.gd`.

**Interfaces:** Produces
- `static func legal_cards(hand: Array[Card], trick: Array[Card], spades_broken: bool, is_first_trick: bool, settings: SpadesSettings) -> Array[Card]` where `trick` holds the cards already played in order (empty when leading).
- `static func trick_winner_index(trick: Array[Card]) -> int` (index into `trick`; highest spade wins, else highest card of the led suit).

- [ ] **Step 1:** Write failing tests, each named for the rule:
  - `test_must_follow_suit`; `test_void_player_may_play_anything_after_first_trick`
  - `test_cannot_lead_spade_until_broken`; `test_may_lead_spade_when_only_spades`; `test_cannot_play_spade_on_first_trick_even_when_void`
  - `test_play_higher_rule_forces_a_higher_card_when_able`; `test_play_higher_not_forced_when_cannot_beat`; `test_play_higher_not_forced_when_a_spade_has_cut` (the [ASSUMPTION]); `test_play_higher_off_by_default`
  - `test_trick_winner_highest_of_led_suit`; `test_trick_winner_spade_beats_led_suit`; `test_trick_winner_highest_spade`
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement the two static functions. **Step 4:** Run, expect PASS.

### Task 4: SpadesScoring

**Files:** Create `core/spades/spades_scoring.gd`; Test `tests/spades/test_scoring.gd`.

**Interfaces:** Produces
- `static func score_round(bids: Dictionary, tricks_by_seat: Dictionary, bags_before: Array[int], settings: SpadesSettings) -> Dictionary` where `bids` is seat -> `Bid`, `tricks_by_seat` is seat -> `int`, `bags_before` is `[team0, team1]`. Returns `{points: [int, int], bags: [int, int], nil_results: Dictionary}` (`nil_results` seat -> bool made).
- `static func game_winner(scores: Array[int], settings: SpadesSettings) -> int` returns team 0, 1, or `-1` if the game continues.

Rule decisions (recorded as rulings): team tricks for the bid check = tricks of that team's non-Nil players only; if both partners bid Nil there is no numeric bid and only the two Nil results score; a missed bid collects no bags.

- [ ] **Step 1:** Write failing tests with the spec's exact numbers: bid 7 won 8 = 71; bid 7 won 5 = -70; failed Nil -100 and adds no bags; made Nil +100; Blind Nil +200; Blind Nil with Nil disabled +100; ten bags -100 and drops by 10; bags penalty off keeps +1 per extra trick but no -100; both-partners-Nil case; partner's tricks count when the other bids Nil (e.g. partner bids 4 wins 4, Nil bidder wins 1 and fails: 40 - 100 = -60 and no bags).
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS.
- [ ] **Step 5 (game_winner):** Tests: first to 500 wins; both over 500 -> higher wins; at -200 the other team wins; nothing reached -> `-1`; exactly equal scores over the target -> `-1` (play another round). Implement and pass.

### Task 5: SpadesGame - dealing and redeals

**Files:** Create `core/spades/spades_game.gd`; Test `tests/spades/test_game_deal.gd`.

**Interfaces:** Produces
- `enum Phase {BIDDING, SWAP, PLAYING, ROUND_OVER, GAME_OVER}`
- `func _init(settings: SpadesSettings, first_dealer: TableState.Seat)`
- `func start_round(seed_value: int) -> void` deals 13 cards per seat; if `settings.redeal_enabled` and any hand has a void, redeals with `seed_value + n` up to 2 times, then accepts the 3rd deal.
- `var redeal_log: Array[Dictionary]` entries `{seat, suit}` for each redeal reason (UI message later).
- `func hand_of(seat) -> Array[Card]` (host-only), `func view_for(seat) -> Dictionary` (own hand, public state only: phase, turn, bids made, trick on table, scores).
- `var phase: Phase`, `var turn_seat: TableState.Seat`, `var dealer_seat`.

- [ ] **Step 1:** Failing tests: each hand has 13 unique cards, all 52 dealt exactly once; with redeal enabled and seed whose first deal has a void (search seeds in the test), `redeal_log` is non-empty and final hands are void-free unless 2 redeals happened; the 3rd deal is accepted (force with a helper that always yields a void); with redeal disabled no redeal happens; dealer unchanged by a redeal; `view_for(WEST)` never contains cards of other seats.
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS.

### Task 6: SpadesGame - bidding and Blind Nil

**Files:** Modify `core/spades/spades_game.gd`; Test `tests/spades/test_game_bidding.gd`.

**Interfaces:** Produces `func bid(seat: TableState.Seat, b: Bid) -> bool` (false and no state change when illegal). First bidder is left of the dealer (next clockwise), then clockwise. Legal: correct seat and phase; number 0-13 is invalid as `Bid.number` (use `Bid.nil()` for Nil); `number(n)` requires 1-13 (so 1-13 also when Nil is disabled); `nil()` needs `nil_enabled`; `blind_nil()` needs `blind_nil_enabled` and the partner must not have bid Blind Nil. After the fourth bid the phase becomes SWAP if a Blind Nil exists, otherwise PLAYING with `turn_seat` = left of dealer.

- [ ] **Step 1:** Failing tests: out-of-turn bid rejected; `number(0)` rejected; Nil rejected when disabled; Blind Nil rejected when disabled; both partners Blind Nil rejected (second one); order is clockwise from dealer's left; phase moves on after 4 bids; a Blind Nil bidder's `view_for` shows no hand until bidding is complete.
- [ ] **Step 2-4:** Run fail, implement, run pass.

### Task 7: SpadesGame - Blind Nil swap

**Files:** Modify `core/spades/spades_game.gd`; Test `tests/spades/test_game_swap.gd`.

**Interfaces:** Produces `func swap(bidder: TableState.Seat, give: Array[Card], take_positions: Array[int]) -> bool` with 0, 1 or 2 cards; `give.size() == take_positions.size()`; positions index the partner's current hand order (as shown face down); cards must be in the bidder's hand; only valid in SWAP phase from the Blind Nil bidder. Records `last_swap` `{bidder, given, received}` so the partner's view can show what they got. After the swap, phase becomes PLAYING.

- [ ] **Step 1:** Failing tests: swap of 0 cards just starts play; 1 and 2 card swaps move exactly the right cards both ways; mismatched counts rejected; card not in hand rejected; position out of range rejected; non-bidder rejected; hands remain 13 cards each; the partner's `view_for` lists received and taken cards; opponents' views do not.
- [ ] **Step 2-4:** Run fail, implement, run pass.

### Task 8: SpadesGame - playing tricks and round end

**Files:** Modify `core/spades/spades_game.gd`; Test `tests/spades/test_game_play.gd`.

**Interfaces:** Produces `func play(seat: TableState.Seat, card: Card) -> bool` using `TrickRules.legal_cards`; tracks `spades_broken`, trick number, tricks won per seat; trick winner leads next; after trick 13 calls `SpadesScoring.score_round`, updates `team_scores`, `team_bags`, and sets phase ROUND_OVER or GAME_OVER (`winner_team`). `func next_round(seed_value: int)` rotates the dealer clockwise and starts the round.

- [ ] **Step 1:** Failing tests: illegal plays rejected without state change (wrong turn, card not in hand, unbroken spade lead, spade on first trick); a cut breaks spades; trick winner leads next; after 13 tricks the round scores and each seat has played exactly 13 cards; dealer rotates on `next_round`; game over when a team passes 500.
- [ ] **Step 2-4:** Run fail, implement, run pass.

### Task 9: Bot and full simulated games

**Files:** Create `core/spades/spades_bot.gd`; Test `tests/spades/test_full_games.gd`.

**Interfaces:** Produces `static func choose_bid(game: SpadesGame, seat: TableState.Seat) -> Bid` (counts likely tricks; never Blind Nil), `static func choose_swap(...)` (always swaps 0), `static func choose_card(game: SpadesGame, seat: TableState.Seat) -> Card` (a random legal card using a seeded `RandomNumberGenerator` stored in the bot instance - make these instance methods if seeding needs state).

- [ ] **Step 1:** Failing test: play 200 complete games with seeds 1..200 and default settings; every game ends with a winner; no action the bot picks is ever rejected; every round deals 52 distinct cards; total tricks per round is 13.
- [ ] **Step 2:** Same with unusual settings: nil disabled, blind nil enabled; bags penalty off; play-higher on; redeal off.
- [ ] **Step 3:** Run fail, implement bot, run pass. Run the whole suite and read the result (must still include the 84 older tests passing).
- [ ] **Step 4:** Update `README.md` status and `docs/PROJECT_PLAN.md` (Phase 3 done) and stop at "ready to commit" for the owner.
