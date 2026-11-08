extends GutTest
## SpadesSession with more than one human seat (used by the network host).

var settings: SpadesSettings


func before_each() -> void:
	settings = SpadesSettings.new()
	settings.blind_nil_enabled = false


func _session(humans: Array[int], seed_value: int = 5) -> SpadesSession:
	var s: SpadesSession = SpadesSession.new(settings, seed_value)
	s.set_human_seats(humans)
	s.start()
	return s


## Lets the bots act until a human is needed (or nothing is left to do).
func _run_bots(s: SpadesSession) -> void:
	var guard: int = 0
	while guard < 500:
		guard += 1
		if s.trick_pending():
			s.clear_trick()
			continue
		if s.advance_bots().is_empty():
			return


func test_two_humans_each_only_act_on_their_own_turn() -> void:
	var s: SpadesSession = _session([0, 2])
	_run_bots(s)
	var turn: int = s.turn_seat()
	assert_true(s.is_human(turn), "the bots stop at a human")
	var other: int = 2 if turn == 0 else 0
	assert_false(s.must_bid(other))
	assert_false(s.bid_for(other, Bid.number(3)))
	assert_true(s.must_bid(turn))
	assert_true(s.bid_for(turn, Bid.number(3)))


func test_bots_play_the_other_seats_and_never_the_humans() -> void:
	var s: SpadesSession = _session([0, 2], 8)  # seed 8: a bot bids first
	var acted: int = 0
	for i in range(50):
		var r: Dictionary = s.advance_bots()
		if r.is_empty():
			break
		acted += 1
		assert_false(s.is_human(r["seat"]))
	assert_gt(acted, 0, "at least one bot acted")


func test_view_for_seat_only_has_that_seats_cards() -> void:
	var s: SpadesSession = _session([0, 2])
	var v0: Dictionary = s.view_for_seat(0)
	var v2: Dictionary = s.view_for_seat(2)
	assert_eq((v0["hand"] as Array).size(), 13)
	assert_eq((v2["hand"] as Array).size(), 13)
	var a: Array[String] = []
	for c in v0["hand"]:
		a.append((c as Card).label())
	for c in v2["hand"]:
		assert_false(a.has((c as Card).label()), "seat 2 hand must differ from seat 0 hand")
	assert_eq(int(v0["hand_counts"][1]), 13)


func test_make_bot_hands_a_seat_to_the_bot_in_the_middle_of_a_round() -> void:
	var s: SpadesSession = _session([0, 2])
	_run_bots(s)
	var turn: int = s.turn_seat()
	assert_true(s.is_human(turn))
	s.make_bot(turn)
	assert_false(s.is_human(turn))
	var r: Dictionary = s.advance_bots()
	assert_false(r.is_empty(), "the bot now acts for that seat")
	assert_eq(r["seat"], turn)


func test_make_human_takes_a_seat_back() -> void:
	var s: SpadesSession = _session([0])
	assert_false(s.is_human(2))
	s.make_human(2)
	assert_true(s.is_human(2))
	s.make_bot(2)
	assert_false(s.is_human(2))


func test_set_names_changes_view_names() -> void:
	var s: SpadesSession = _session([0, 2])
	s.set_names({0: "Ann", 1: "Tin", 2: "Raf", 3: "Cherry"})
	assert_eq(s.view_for_seat(2)["names"][2], "Raf")


func test_must_play_and_legal_cards_only_for_the_seat_to_play() -> void:
	var s: SpadesSession = _session([0, 2])
	# bid until play starts
	var guard: int = 0
	while s.phase() == SpadesGame.Phase.BIDDING and guard < 40:
		guard += 1
		_run_bots(s)
		if s.phase() != SpadesGame.Phase.BIDDING:
			break
		assert_true(s.bid_for(s.turn_seat(), Bid.number(3)))
	_run_bots(s)
	var turn: int = s.turn_seat()
	assert_eq(s.phase(), SpadesGame.Phase.PLAYING)
	assert_true(s.must_play(turn))
	assert_gt((s.view_for_seat(turn)["legal"] as Array).size(), 0)
	var other: int = 2 if turn == 0 else 0
	assert_eq((s.view_for_seat(other)["legal"] as Array).size(), 0)
	var c: Card = (s.view_for_seat(turn)["legal"] as Array)[0]
	assert_false(s.play_for(other, c))
	assert_true(s.play_for(turn, c))


func test_blind_nil_swap_for_a_second_human() -> void:
	settings.blind_nil_enabled = true
	var s: SpadesSession = _session([0, 2])
	var guard: int = 0
	while s.phase() == SpadesGame.Phase.BIDDING and guard < 40:
		guard += 1
		_run_bots(s)
		if s.phase() != SpadesGame.Phase.BIDDING:
			break
		var t: int = s.turn_seat()
		assert_true(s.bid_for(t, Bid.blind_nil() if t == 2 else Bid.number(3)))
	assert_true(s.must_swap(2))
	assert_false(s.must_swap(0))
	var hand: Array[Card] = s.view_for_seat(2)["hand"]
	var give: Array[Card] = [hand[0]]
	assert_true(s.swap_for(2, give, [0] as Array[int]))
	assert_false(s.must_swap(2))


func test_single_human_session_still_behaves_as_before() -> void:
	var s: SpadesSession = SpadesSession.new(settings, 5)
	s.start()
	assert_true(s.is_human(0))
	assert_false(s.is_human(1))
	var v: Dictionary = s.view()
	assert_eq(v["names"][0], "You")
	assert_eq(v["names"][1], "Tin")
