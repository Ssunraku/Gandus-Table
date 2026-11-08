extends GutTest

const S: int = TableState.Seat.SOUTH
const W: int = TableState.Seat.WEST
const N: int = TableState.Seat.NORTH
const E: int = TableState.Seat.EAST

var table: Table


func before_each() -> void:
	table = Table.new()
	table.auto_start = false
	table.attached = true
	add_child_autofree(table)
	table.size = Vector2(1280, 720)


func _state() -> TableState:
	var st: TableState = TableState.dummy()
	st.seat_names = {S: "You", W: "Tin", N: "Partner", E: "Cherry"}
	return st


func _point_on(i: int) -> Vector2:
	return table.hand.card_rect(i).position + Vector2(5, 100)


func test_played_cards_of_other_seats_are_drawn_at_their_spots() -> void:
	var st: TableState = _state()
	st.set_played(W, Card.make(Card.Suit.HEARTS, Card.Rank.FIVE))
	st.set_played(N, Card.make(Card.Suit.HEARTS, Card.Rank.JACK))
	st.set_played(E, Card.make(Card.Suit.HEARTS, Card.Rank.TWO))
	table.show_game_state(st)
	assert_eq(table.played_view_count(), 3)


func test_seat_label_shows_the_bid() -> void:
	var st: TableState = _state()
	st.bids = {N: Bid.number(3), W: Bid.nil(), E: Bid.blind_nil()}
	st.tricks_won[N] = 1
	table.show_game_state(st)
	assert_string_contains((table.seat_views[N] as SeatView).label_text(), "bid 3")
	assert_string_contains((table.seat_views[W] as SeatView).label_text(), "Nil")
	assert_string_contains((table.seat_views[E] as SeatView).label_text(), "Blind Nil")
	assert_eq((table.seat_views[N] as SeatView).tricks, 1)
	assert_eq((table.seat_views[S] as SeatView).label_text(), "You")


func test_spades_broken_chip_follows_the_state() -> void:
	var st: TableState = _state()
	table.show_game_state(st)
	assert_string_contains(table.broken_label.text, "no")
	st.spades_broken = true
	table.show_game_state(st)
	assert_string_contains(table.broken_label.text, "yes")


func test_last_trick_chip_names_the_winner_only_when_there_is_one() -> void:
	var st: TableState = _state()
	table.show_game_state(st)
	assert_false(table.last_trick_label.get_parent().visible)
	st.last_trick = {"cards": [] as Array[Dictionary], "winner": E}
	table.show_game_state(st)
	assert_true(table.last_trick_label.get_parent().visible)
	assert_string_contains(table.last_trick_label.text, "Cherry")


func test_tapping_a_legal_card_reports_it_without_touching_the_state() -> void:
	var st: TableState = _state()
	st.can_play = true
	st.legal_cards = [st.own_hand[2]] as Array[Card]
	table.show_game_state(st)
	watch_signals(table)
	table.hand.handle_tap(_point_on(2))
	table.hand.handle_tap(_point_on(2))
	assert_signal_emitted_with_parameters(table, "human_played", [st.own_hand[2]])
	assert_eq(st.own_hand.size(), 13, "the screen must not change the state itself")


func test_illegal_cards_are_greyed_only_on_your_turn() -> void:
	var st: TableState = _state()
	st.can_play = true
	st.legal_cards = [st.own_hand[0]] as Array[Card]
	table.show_game_state(st)
	assert_true((table.hand.get_child(5) as CardView).dimmed)
	assert_false((table.hand.get_child(0) as CardView).dimmed)
	st.can_play = false
	table.show_game_state(st)
	assert_false((table.hand.get_child(5) as CardView).dimmed)


func test_menu_and_info_buttons_emit_signals() -> void:
	watch_signals(table)
	table.menu_button.pressed.emit()
	table.info_button.pressed.emit()
	assert_signal_emitted(table, "menu_pressed")
	assert_signal_emitted(table, "info_pressed")


func test_resizing_while_a_card_flies_leaves_no_duplicate_or_orphan() -> void:
	var st: TableState = _state()
	var card: Card = Card.make(Card.Suit.HEARTS, Card.Rank.FIVE)
	table.animate_card_played(W, card)
	st.set_played(W, card)
	table.show_game_state(st)
	assert_eq(table.played_view_count(), 0, "the flying card is not drawn twice")
	table.size = Vector2(720, 1280)
	table.relayout()
	assert_eq(table.played_view_count(), 0)
	await wait_seconds(Table.PLAY_FLIGHT + 0.2)
	assert_eq(table.flying_count(), 0)
	assert_eq(table.played_view_count(), 1)


# ---------- sweeping a finished trick to the winner ----------

func _four_played_state() -> TableState:
	var st: TableState = _state()
	st.set_played(S, Card.make(Card.Suit.CLUBS, Card.Rank.TWO))
	st.set_played(W, Card.make(Card.Suit.CLUBS, Card.Rank.SEVEN))
	st.set_played(N, Card.make(Card.Suit.CLUBS, Card.Rank.TEN))
	st.set_played(E, Card.make(Card.Suit.CLUBS, Card.Rank.KING))
	return st


func test_sweep_takes_the_four_cards_off_the_table_and_flies_them_to_the_winner() -> void:
	table.show_game_state(_four_played_state())
	assert_eq(table.played_view_count(), 4)
	var bar: Rect2 = Rect2(table.seat_views[E].position, table.seat_views[E].size)
	var before: float = table.played_view_centre_distance_to(bar.get_center())
	table.sweep_trick(E)
	assert_eq(table.played_view_count(), 0)
	assert_eq(table.sweeping_count(), 4)
	await wait_seconds(Table.SWEEP_TIME * 0.6)
	var midway: float = table.sweeping_centre_distance_to(bar.get_center())
	assert_lt(midway, before, "the cards should have moved towards the winner's name bar")
	await wait_seconds(Table.SWEEP_TIME + 0.2)
	assert_eq(table.sweeping_count(), 0)


func test_sweep_with_nothing_on_the_table_does_nothing() -> void:
	table.show_game_state(_state())
	table.sweep_trick(W)
	assert_eq(table.sweeping_count(), 0)


func test_resizing_during_a_sweep_leaves_no_orphans() -> void:
	table.show_game_state(_four_played_state())
	table.sweep_trick(N)
	table.show_game_state(_state())  # the game has cleared the trick, as it does in real play
	table.size = Vector2(720, 1280)
	table.relayout()
	assert_eq(table.sweeping_count(), 4)
	await wait_seconds(Table.SWEEP_TIME + 0.25)
	assert_eq(table.sweeping_count(), 0)
	assert_eq(table.played_view_count(), 0)


func test_a_cleared_state_after_the_sweep_draws_no_played_cards() -> void:
	var st: TableState = _four_played_state()
	table.show_game_state(st)
	table.sweep_trick(S)
	table.show_game_state(_state())
	assert_eq(table.played_view_count(), 0)
	assert_eq(table.sweeping_count(), 4)


func test_corner_chips_do_not_run_into_the_partners_bar_in_portrait() -> void:
	table.size = Vector2(720, 1280)
	var st: TableState = _state()
	st.spades_broken = true
	st.last_trick = {"cards": [] as Array[Dictionary], "winner": E}
	table.show_game_state(st)
	var north: Rect2 = Rect2(table.seat_views[N].position, table.seat_views[N].size)
	for chip in [table.broken_label, table.last_trick_label]:
		var pill: Control = chip.get_parent()
		assert_false(Rect2(pill.position, pill.size).intersects(north), "%s overlaps the partner's bar" % chip.text)
