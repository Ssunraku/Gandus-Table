extends GutTest

const S: int = TableState.Seat.SOUTH
const W: int = TableState.Seat.WEST
const N: int = TableState.Seat.NORTH
const E: int = TableState.Seat.EAST


func _session(seed_value: int) -> SpadesSession:
	var session: SpadesSession = SpadesSession.new(SpadesSettings.new(), seed_value)
	session.start()
	return session


func _until_human_bid(session: SpadesSession) -> void:
	while not session.advance_bots().is_empty():
		pass


## Bids 3 and lets bots play until it is the human's turn to play a card.
func _until_human_play(session: SpadesSession) -> void:
	_until_human_bid(session)
	session.submit_bid(Bid.number(3))
	while not session.human_must_play():
		if session.advance_bots().is_empty():
			break


func test_after_dealing_south_has_13_real_cards_and_others_only_counts() -> void:
	var st: TableState = SpadesTableView.build(_session(1))
	assert_eq(st.own_hand.size(), 13)
	for seat in [W, N, E]:
		assert_eq(st.get_card_count(seat), 13)
		assert_null(st.get_played(seat))
	assert_null(st.get_played(S))


func test_names_dealer_and_scores_are_copied() -> void:
	var st: TableState = SpadesTableView.build(_session(1))
	assert_eq(st.seat_names[S], "You")
	assert_eq(st.seat_names[W], "Tin")
	assert_eq(st.seat_names[N], "Partner")
	assert_eq(st.seat_names[E], "Cherry")
	assert_eq(st.dealer_seat, 1)
	assert_eq(st.team_scores, [0, 0] as Array[int])
	assert_eq(st.team_bags, [0, 0] as Array[int])


func test_bids_appear_only_for_seats_that_have_bid() -> void:
	var session: SpadesSession = _session(1)  # dealer West: North bids first
	assert_eq(SpadesTableView.build(session).bids.size(), 0)
	session.advance_bots()
	var st: TableState = SpadesTableView.build(session)
	assert_eq(st.bids.size(), 1)
	assert_true(st.bids.has(N))


func test_played_cards_and_counts_follow_the_table() -> void:
	var session: SpadesSession = _session(1)
	_until_human_play(session)
	assert_true(session.human_must_play())
	var before: TableState = SpadesTableView.build(session)
	var legal: Array[Card] = session.view()["legal"]
	assert_true(session.submit_play(legal[0]))
	var after: TableState = SpadesTableView.build(session)
	assert_eq(after.own_hand.size(), 12)
	assert_eq(after.get_card_count(S), 12)
	var shown: Array[Dictionary] = session.shown_trick()
	for entry in shown:
		assert_eq(after.get_played(entry["seat"]), entry["card"])
	assert_true(before.get_card_count(N) >= after.get_card_count(N))


func test_legal_cards_only_on_the_humans_play_turn_and_are_a_subset_of_the_hand() -> void:
	var session: SpadesSession = _session(1)
	var st: TableState = SpadesTableView.build(session)
	assert_false(st.can_play)
	assert_eq(st.legal_cards.size(), 0)
	_until_human_play(session)
	st = SpadesTableView.build(session)
	assert_true(st.can_play)
	assert_gt(st.legal_cards.size(), 0)
	for c in st.legal_cards:
		var found: bool = false
		for h in st.own_hand:
			if h.suit == c.suit and h.rank == c.rank:
				found = true
		assert_true(found)


func test_other_seats_never_get_real_cards_for_unplayed_hands() -> void:
	var session: SpadesSession = _session(2)
	_until_human_play(session)
	var st: TableState = SpadesTableView.build(session)
	for seat in [W, N, E]:
		var played: Card = st.get_played(seat)
		if played != null:
			var in_trick: bool = false
			for entry in session.shown_trick():
				if entry["seat"] == seat and entry["card"] == played:
					in_trick = true
			assert_true(in_trick, "only cards already on the table may be known")
