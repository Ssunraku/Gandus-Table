# Phase 2 Card Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Gandus Table card-table screen with dummy cards (fanned hand, card backs for opponents, tap-to-play, deal animation, portrait and landscape layouts), with no game rules or networking.

**Architecture:** Plain data scripts (`Card`, `Deck`, `TableState`) hold what the screen shows and contain no UI code. A pure-maths `TableLayout` turns a screen size into positions. Thin Control scenes (`CardView`, `HandView`, `SeatView`, `Table`) only *draw* a `TableState` and emit signals. The owner's later network layer will fill `TableState`; the screen never owns game state.

**Tech Stack:** Godot 4.7.2 stable, GDScript with static typing, Compatibility renderer, GUT (Godot unit test add-on, needs owner approval, see Task 1).

**Spec:** `docs/superpowers/specs/2026-11-08-phase2-card-table-design.md`

## Global Constraints

- Godot 4.7.2 stable, GDScript with static typing (`var x: int`, `func f(a: String) -> bool`), 2D only, Compatibility renderer.
- Cards are drawn by code (shapes and a free font); no imported card artwork in Phase 2.
- Placeholder avatars are coloured circles with initials.
- Layout is computed from the screen size, never hard-coded pixel positions. It must work in portrait and landscape, including 2000x1200 (Galaxy Tab S6 Lite).
- Opponent and partner seats receive only a card **count**, never `Card` objects. The player only ever sees their own faces.
- No game rules, bidding, scoring logic, networking, sound or tablet run in Phase 2.
- Every outside file (add-on, font) is recorded in `docs/ASSETS.md` with source and licence.
- Never commit or push without owner approval. Explain code in beginner-friendly language.
- Test command (from project folder): `& "D:\Downloads\ALL SETUPS\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

## Review Focus

1. **Empty or one-card hand** (after playing cards): fan and tap handling must not crash or divide by zero. Owner expects an empty hand to just look empty.
2. **13 cards on a narrow portrait screen (720x1200)**: all cards stay on screen and each remains tappable. Owner expects to see every card's corner.
3. **Overlapping cards**: a tap on the overlap area picks the card drawn on top (the right-hand one), not the one underneath.
4. **Window resize or rotation mid-game**: positions recompute and no card is lost or duplicated; a selected card stays selected.
5. **Hidden hands**: opponents' data can only be a count; a test proves `TableState` has no way to hand out an opponent `Card`.

---

## File Structure

| File | Responsibility |
|---|---|
| `core/cards/card.gd` | `Card`: suit, rank, short label. No UI. |
| `core/cards/deck.gd` | `Deck`: builds 52 cards, seeded shuffle, deal 13 to a seat. |
| `core/table_state.gd` | `TableState`: what the screen draws (own hand, opponent counts, played cards, scores, turn, dealer, names). |
| `ui/layout/table_layout.gd` | `TableLayout`: pure maths: screen size to rectangles and fan positions. |
| `ui/card_view.gd` | `CardView`: draws one card (face or back) with code. |
| `ui/hand_view.gd` | `HandView`: fans own hand, lift on tap, emits `card_played`. |
| `ui/opponent_hand_view.gd` | `OpponentHandView`: fan of backs from a count. |
| `ui/seat_view.gd` | `SeatView`: name bar, avatar, dealer badge, trick counter. |
| `ui/score_box.gd` | `ScoreBox`: score and bags display. |
| `ui/table.gd` + `ui/table.tscn` | `Table`: assembles everything, deal animation, play-to-centre; main scene. |
| `tests/test_*.gd` | GUT tests. |
| `docs/ASSETS.md` | Source and licence for every outside file. |

---

### Task 1: Test framework (needs owner approval first)

**Files:**
- Create: `addons/gut/` (downloaded), `tests/test_smoke.gd`, `docs/ASSETS.md`
- Modify: `project.godot` (plugin enabled)

**Interfaces:** Produces: the test command in Global Constraints.

- [ ] **Step 1: Ask the owner for approval to download GUT** (a free Godot unit-test add-on, outside code). State its source (official GUT GitHub or Godot Asset Library page), licence (check, expected MIT), and why. Do not proceed without a yes.
- [ ] **Step 2: Confirm the GUT release supports Godot 4.7** by reading its release notes. If not, stop and report to the owner with alternatives (a tiny home-made test script).
- [ ] **Step 3: Download into `addons/gut/`** and enable the plugin in Project Settings; record name, version, URL, licence in `docs/ASSETS.md`.
- [ ] **Step 4: Write `tests/test_smoke.gd`** (`extends GutTest`) with `test_true_is_true()` asserting `assert_true(true)`.
- [ ] **Step 5: Run the test command.** Expected: 1 passing test, exit code 0.
- [ ] **Step 6: Show diff and ask the owner before committing** (`git add addons docs/ASSETS.md tests project.godot`).

### Task 2: Card and Deck

**Files:**
- Create: `core/cards/card.gd`, `core/cards/deck.gd`
- Test: `tests/test_card.gd`, `tests/test_deck.gd`

**Interfaces:**
- Produces: `class_name Card extends RefCounted` with `enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }`, `enum Rank { TWO = 2, ..., TEN = 10, JACK = 11, QUEEN = 12, KING = 13, ACE = 14 }`, `var suit: Suit`, `var rank: Rank`, `static func make(s: Suit, r: Rank) -> Card`, `func label() -> String` (rank symbol then suit letter C/D/H/S, for example `"AS"`, `"QH"`, `"10H"`; 2 to 10 use the digits, J/Q/K/A use the letter).
- Produces: `class_name Deck extends RefCounted` with `static func standard_52() -> Array[Card]` (order: clubs, diamonds, hearts, spades; ranks ascending), `static func shuffled(seed_value: int) -> Array[Card]` (same seed = same order), `static func sort_hand(cards: Array[Card]) -> Array[Card]` (by suit order above, then rank ascending; returns a new array).

- [ ] **Step 1: Write failing tests.** `test_card.gd`: `test_label_for_ace_of_spades` asserts `"AS"`; `test_label_for_ten_of_hearts` asserts `"10H"`. `test_deck.gd`: `test_standard_has_52_unique_cards` (52 items, 52 distinct labels); `test_same_seed_same_order`; `test_different_seed_different_order`; `test_shuffle_keeps_all_52`; `test_sort_hand_orders_by_suit_then_rank` (hand `[AS, 2C, KH, 3C]` becomes `[2C, 3C, KH, AS]`); `test_sort_hand_does_not_change_input`.
- [ ] **Step 2: Run tests, expect FAIL** (classes not defined).
- [ ] **Step 3: Implement `Card` and `Deck`** as specified. Shuffle with a `RandomNumberGenerator` whose `seed` is `seed_value`.
- [ ] **Step 4: Run tests, expect all PASS.**
- [ ] **Step 5: Show diff and ask the owner before committing.**

### Task 3: TableState

**Files:**
- Create: `core/table_state.gd`
- Test: `tests/test_table_state.gd`

**Interfaces:**
- Consumes: `Card`, `Deck` (Task 2).
- Produces: `class_name TableState extends RefCounted` with `enum Seat { SOUTH, WEST, NORTH, EAST }` (SOUTH = the local player, NORTH = partner), `var own_hand: Array[Card]`, `var seat_names: Dictionary` (Seat to String), `var dealer_seat: Seat`, `var turn_seat: Seat`, `var team_scores: Array[int]` (`[us, them]`), `var team_bags: Array[int]`, `var tricks_won: Dictionary` (Seat to int), `func get_card_count(seat: Seat) -> int` (SOUTH returns `own_hand.size()`, others return stored count), `func set_card_count(seat: Seat, n: int) -> void` (error and ignore if seat is SOUTH), `func get_played(seat: Seat) -> Card` (null when none), `func set_played(seat: Seat, card: Card) -> void`, `func play_own_card(card: Card) -> bool` (removes from `own_hand`, sets played for SOUTH, returns false if not in hand), `static func dummy() -> TableState` (seeded deck 1, SOUTH gets the first 13 cards sorted, others count 13, names `"You"`, `"Tin"`, `"Partner"`, `"Cherry"`, dealer WEST).

- [ ] **Step 1: Write failing tests:** `test_dummy_has_13_cards_for_south_and_13_counts_for_others`; `test_play_own_card_moves_card_to_played`; `test_play_card_not_in_hand_returns_false`; `test_cannot_set_count_for_south`; `test_playing_all_cards_leaves_empty_hand` (Review Focus 1); and `test_no_method_returns_opponent_card_faces` (Review Focus 5): assert the only public method returning `Card` for a seat is `get_played`, and that `get_card_count(Seat.WEST)` is an `int` (use `typeof`).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `TableState`** as specified.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Show diff and ask the owner before committing.**

### Task 4: TableLayout (pure maths)

**Files:**
- Create: `ui/layout/table_layout.gd`
- Test: `tests/test_table_layout.gd`

**Interfaces:**
- Consumes: `TableState.Seat`.
- Produces: `class_name TableLayout extends RefCounted` with `static func compute(screen: Vector2) -> Dictionary` returning keys `"is_portrait": bool`, `"card_size": Vector2` (about 1:1.4 ratio, scaled from the screen), `"hand_rect": Rect2` (bottom area for own hand), `"seat_rects": Dictionary` (Seat to Rect2 for each name bar), `"opponent_fan_rects": Dictionary` (Seat to Rect2 for WEST, NORTH, EAST), `"play_spots": Dictionary` (Seat to Vector2 centre of the played card), `"deck_spot": Vector2`, `"score_rect": Rect2`, `"button_rect_left": Rect2`, `"button_rect_right": Rect2`; and `static func fan(count: int, area: Rect2, card_size: Vector2) -> Array[Dictionary]` where each item is `{"position": Vector2, "rotation": float}` (top-left of the card and a small tilt in radians, increasing left to right, centred on the area; count 0 returns `[]`; count 1 returns one centred item).

- [ ] **Step 1: Write failing tests** with sizes `[Vector2(1280,720), Vector2(720,1280), Vector2(2000,1200), Vector2(1200,2000)]`: `test_hand_cards_fit_on_screen` (for count 13, every card's unrotated Rect2 lies within `Rect2(Vector2.ZERO, screen)`, so Review Focus 2); `test_seat_rects_do_not_overlap_hand_rect`; `test_play_spots_inside_screen`; `test_portrait_flag`; `test_fan_zero_returns_empty` and `test_fan_one_is_centred` (Review Focus 1); `test_fan_positions_increase_left_to_right`; `test_fan_overlap_leaves_rightmost_card_fully_visible` (consecutive position.x difference is less than `card_size.x` and greater than 0).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `TableLayout`.** Use proportions of `screen` only. In landscape: hand at the bottom, partner top, opponents left and right. In portrait: same arrangement with smaller opponent fans and a taller bottom hand. Cap the hand fan width to `screen.x` minus margins and compress the spacing for 13 cards.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Show diff and ask the owner before committing.**

### Task 5: CardView (drawn by code)

**Files:**
- Create: `ui/card_view.gd`, `ui/card_view.tscn`
- Modify: `docs/ASSETS.md` (font, only if one is used)

**Interfaces:**
- Consumes: `Card`.
- Produces: `class_name CardView extends Control` with `var card: Card` (null means face-down), `var face_up: bool`, `func setup(c: Card, face_up_value: bool, size_px: Vector2) -> void`, `func set_selected(v: bool) -> void` (lifts the card upward by 15 percent of its height, animated), `var selected: bool`. Draws a rounded white rectangle with a corner rank and a suit symbol drawn from shapes (red for diamonds/hearts, black for clubs/spades); a back is a blue patterned rounded rectangle.

- [ ] **Step 1: Write a failing test** `tests/test_card_view.gd`: `test_setup_sets_size_and_face` (after `setup(Card.make(SPADES, ACE), true, Vector2(100,140))`, `size == Vector2(100,140)` and `face_up` is true) and `test_set_selected_toggles_flag`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `CardView`** with `_draw()`; draw suit symbols with `draw_circle` and `draw_colored_polygon` (no font needed for symbols). Use the project's default font for rank text, and record it in `docs/ASSETS.md` only if a different font is added.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Owner visual check.** Create a throwaway scene showing the 4 suits face up and one back. Ask the owner to open it in Godot and describe what they see; do not claim it looks right before they confirm. Delete the throwaway scene afterwards.
- [ ] **Step 6: Show diff and ask the owner before committing.**

### Task 6: HandView (fan, lift, play)

**Files:**
- Create: `ui/hand_view.gd`, `ui/hand_view.tscn`
- Test: `tests/test_hand_view.gd`

**Interfaces:**
- Consumes: `CardView`, `TableLayout.fan`, `Card`.
- Produces: `class_name HandView extends Control` with `signal card_played(card: Card)`, `func show_hand(cards: Array[Card], area: Rect2, card_size: Vector2) -> void` (rebuilds `CardView`s in order, fan positions from `TableLayout.fan`), `func pick_index_at(point: Vector2) -> int` (index of the topmost card under the point, the rightmost wins on overlap; `-1` if none), `var selected_index: int` (`-1` = none), `func handle_tap(point: Vector2) -> void` (tapping a different card selects it; tapping the selected card emits `card_played` and removes it; tapping empty space clears the selection).

- [ ] **Step 1: Write failing tests:** `test_tap_card_selects_it`; `test_tap_selected_card_plays_it_and_emits_signal` (use `watch_signals`); `test_tap_overlap_picks_rightmost_card` (Review Focus 3); `test_tap_empty_space_clears_selection`; `test_show_hand_with_empty_list_does_not_crash` (Review Focus 1); `test_reshow_hand_keeps_selected_card` (Review Focus 4: after `show_hand` with the same cards in a different `area`, the selected card is still selected).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `HandView`.** Use `_gui_input` to forward taps (mouse click and touch) to `handle_tap`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Show diff and ask the owner before committing.**

### Task 7: Opponent hands, seats, score box

**Files:**
- Create: `ui/opponent_hand_view.gd`, `ui/seat_view.gd`, `ui/score_box.gd` (each with a small `.tscn`)
- Test: `tests/test_seat_view.gd`

**Interfaces:**
- Consumes: `CardView`, `TableState.Seat`, `TableLayout`.
- Produces: `OpponentHandView.show_count(count: int, area: Rect2, card_size: Vector2, seat: TableState.Seat) -> void` (card backs only; rotated 90 degrees for WEST and EAST); `SeatView.setup(seat_name: String, is_dealer: bool, is_turn: bool, tricks: int) -> void` (name bar, circle avatar with the initial, dealer badge "D", highlight when it is that seat's turn); `ScoreBox.show_scores(scores: Array[int], bags: Array[int]) -> void`.

- [ ] **Step 1: Write failing tests:** `test_seat_view_shows_dealer_badge_only_when_dealer`; `test_opponent_view_with_zero_count_shows_no_cards`; `test_opponent_view_with_13_count_shows_13_backs` (child count of face-down `CardView`s).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the three views.** Avatar colour from a fixed list indexed by seat.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Show diff and ask the owner before committing.**

### Task 8: Table scene, deal animation, resize

**Files:**
- Create: `ui/table.gd`, `ui/table.tscn`
- Modify: `project.godot` (main scene; window stretch so the layout controls sizes; allow portrait and landscape)
- Test: `tests/test_table.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: `class_name Table extends Control` with `var state: TableState`, `func set_state(s: TableState) -> void` (redraw everything), `func relayout() -> void` (called on the `resized` signal; recomputes `TableLayout.compute(size)` and repositions every view), `func play_deal_animation() -> void` (cards fly from `deck_spot` to each seat, then the hand is shown; takes 2 seconds or less), and when the local hand emits `card_played`, call `state.play_own_card(card)`, animate the card to `play_spots[SOUTH]`, and redraw.

- [ ] **Step 1: Write failing tests:** `test_set_state_creates_13_card_views_for_south`; `test_playing_a_card_leaves_12_in_hand`; `test_relayout_at_new_size_keeps_card_count_and_selection` (Review Focus 4); `test_table_has_no_card_faces_for_opponent_seats` (inspect opponent views: none face up, Review Focus 5).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `Table`.** Set `ui/table.tscn` as the main scene using `TableState.dummy()` at start. Dark-green felt background with a subtle radial gradient drawn in code.
- [ ] **Step 4: Run the full test command, expect all PASS.**
- [ ] **Step 5: Headless launch check:** `& "...console.exe" --headless --path . --quit-after 120`. Expected: no script errors in output, exit code 0.
- [ ] **Step 6: Show diff and ask the owner before committing.**

### Task 9: Owner visual verification and docs

**Files:**
- Modify: `README.md`, `docs/PROJECT_PLAN.md`, `docs/ASSETS.md`

- [ ] **Step 1: Ask the owner to open the project in Godot, press Play (F5), and try:** deal animation, tapping a card (it lifts), tapping again (it slides to centre), resizing the window to landscape, portrait and a very small size. Ask them to report what they see, and to name anything that feels wrong compared with the site.
- [ ] **Step 2: Fix anything the owner reports,** each as a small change with a test where it is logic.
- [ ] **Step 3: Update docs:** mark Phase 2 done in `PROJECT_PLAN.md`; note in `README.md` how to run the tests and the table; confirm `ASSETS.md` is complete.
- [ ] **Step 4: Run the full test command and show the passing output.**
- [ ] **Step 5: Ask the owner before the final commit and again before pushing.**
