extends GutTest

const HUMAN: int = 0


func _new_session(seed_value: int, settings: SpadesSettings = null) -> SpadesSession:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	var session: SpadesSession = SpadesSession.new(s, seed_value)
	session.start()
	return session


## Lets the bots act until it is the human's turn (or nothing more can happen).
func _bots_until_human(session: SpadesSession) -> int:
	var moves: int = 0
	while moves < 200:
		var r: Dictionary = session.advance_bots()
		if r.is_empty():
			break
		assert_ne(r["seat"], HUMAN, "a bot action must never be for the human seat")
		moves += 1
	return moves


## One step of a scripted human. Returns false if the game cannot continue.
func _human_step(session: SpadesSession) -> bool:
	if session.trick_pending():
		session.clear_trick()
		return true
	if session.game_over():
		return true
	if session.round_over():
		return session.next_round()
	if session.human_must_bid():
		return session.submit_bid(Bid.number(3))
	if session.human_must_swap():
		return session.submit_swap([] as Array[Card], [] as Array[int])
	if session.human_must_play():
		var legal: Array[Card] = session.view()["legal"]
		return session.submit_play(legal[0])
	return not session.advance_bots().is_empty()


func _play_game(session: SpadesSession) -> bool:
	for i in range(6000):
		if session.game_over() and not session.trick_pending():
			return true
		if not _human_step(session):
			return false
	return false


func test_bots_bid_until_it_is_the_humans_turn() -> void:
	for seed_value in range(1, 9):
		var session: SpadesSession = _new_session(seed_value)
		_bots_until_human(session)
		assert_true(session.human_must_bid(), "seed %d: human should be asked to bid" % seed_value)
		assert_eq(session.phase(), SpadesGame.Phase.BIDDING)


func test_bid_on_a_bots_turn_is_rejected_and_changes_nothing() -> void:
	var session: SpadesSession = _new_session(1)  # dealer West, North bids first
	assert_false(session.human_must_bid())
	assert_false(session.submit_bid(Bid.number(3)))
	assert_eq((session.view()["bids"] as Dictionary).size(), 0)


func test_human_bid_is_accepted_on_the_humans_turn() -> void:
	var session: SpadesSession = _new_session(1)
	_bots_until_human(session)
	assert_true(session.submit_bid(Bid.number(3)))
	assert_true((session.view()["bids"] as Dictionary).has(HUMAN))
	assert_false(session.human_must_bid())


func test_illegal_card_is_rejected_and_changes_nothing() -> void:
	var session: SpadesSession = _new_session(1)
	var found: bool = false
	for i in range(400):
		if session.human_must_play():
			var hand: Array[Card] = session.view()["hand"]
			var legal: Array[Card] = session.view()["legal"]
			for c in hand:
				var is_legal: bool = false
				for l in legal:
					if l.suit == c.suit and l.rank == c.rank:
						is_legal = true
				if not is_legal:
					var before: int = hand.size()
					assert_false(session.submit_play(c))
					assert_eq((session.view()["hand"] as Array).size(), before)
					assert_true(session.human_must_play())
					found = true
					break
		if found:
			break
		assert_true(_human_step(session))
	assert_true(found, "never met a turn with an illegal card in hand")


func test_finished_trick_stays_visible_and_blocks_play_until_cleared() -> void:
	var session: SpadesSession = _new_session(2)
	for i in range(400):
		if session.trick_pending():
			break
		assert_true(_human_step(session))
	assert_true(session.trick_pending())
	assert_eq(session.shown_trick().size(), 4)
	assert_eq(session.advance_bots(), {})
	assert_false(session.human_must_play())
	var winner: int = session.last_trick()["winner"]
	var hand: Array[Card] = session.view()["hand"]
	if hand.size() > 0:
		assert_false(session.submit_play(hand[0]))
	session.clear_trick()
	assert_false(session.trick_pending())
	assert_eq(session.shown_trick().size(), 0)
	assert_eq(session.turn_seat(), winner)


func test_scripted_human_finishes_20_games_with_every_action_accepted() -> void:
	var failures: Array[int] = []
	for seed_value in range(100, 120):
		var settings: SpadesSettings = SpadesSettings.new()
		settings.win_score = 100
		settings.lose_score = -100
		var session: SpadesSession = _new_session(seed_value, settings)
		if not _play_game(session):
			failures.append(seed_value)
		elif not session.game_over():
			failures.append(seed_value)
	assert_eq(failures, [] as Array[int], "games that broke or did not end")


func test_human_blind_nil_then_skip_swap_continues_to_play() -> void:
	var session: SpadesSession = _new_session(3)
	_bots_until_human(session)
	assert_true(session.submit_bid(Bid.blind_nil()))
	_bots_until_human(session)
	assert_eq(session.phase(), SpadesGame.Phase.SWAP)
	assert_true(session.human_must_swap())
	assert_eq((session.view()["hand"] as Array).size(), 13)
	assert_true(session.submit_swap([] as Array[Card], [] as Array[int]))
	assert_eq(session.phase(), SpadesGame.Phase.PLAYING)
	assert_false(session.human_must_swap())


func test_human_blind_nil_swapping_two_cards_keeps_13_cards() -> void:
	var session: SpadesSession = _new_session(3)
	_bots_until_human(session)
	assert_true(session.submit_bid(Bid.blind_nil()))
	_bots_until_human(session)
	var hand: Array[Card] = session.view()["hand"]
	var give: Array[Card] = [hand[0], hand[1]]
	assert_true(session.submit_swap(give, [0, 5] as Array[int]))
	assert_eq((session.view()["hand"] as Array).size(), 13)
	assert_eq(session.phase(), SpadesGame.Phase.PLAYING)


func test_swap_with_unequal_counts_is_rejected() -> void:
	var session: SpadesSession = _new_session(3)
	_bots_until_human(session)
	session.submit_bid(Bid.blind_nil())
	_bots_until_human(session)
	var hand: Array[Card] = session.view()["hand"]
	assert_false(session.submit_swap([hand[0]] as Array[Card], [0, 1] as Array[int]))
	assert_true(session.human_must_swap())


func test_view_exposes_only_public_information_and_the_humans_own_hand() -> void:
	var session: SpadesSession = _new_session(4)
	_bots_until_human(session)
	session.submit_bid(Bid.number(3))
	var v: Dictionary = session.view()
	var allowed: Array[String] = ["phase", "turn_seat", "dealer_seat", "hand", "hand_counts", "bids", "trick",
		"spades_broken", "tricks_won", "team_scores", "team_bags", "swap", "legal", "last_trick", "names"]
	for key in v.keys():
		assert_true(allowed.has(String(key)), "unexpected key in view: %s" % key)
	var counts: Dictionary = v["hand_counts"]
	for seat in counts.keys():
		assert_true(typeof(counts[seat]) == TYPE_INT)
	var own: Array[Card] = session.view()["hand"]
	assert_lte(own.size(), 13)
	for c in own:
		var in_real_hand: bool = false
		for r in session._game.hand_of(HUMAN):
			if r.suit == c.suit and r.rank == c.rank:
				in_real_hand = true
		assert_true(in_real_hand)
	assert_lte((v["trick"] as Array).size(), 4)


func test_next_round_only_after_a_finished_round_and_moves_the_dealer() -> void:
	var session: SpadesSession = _new_session(5)
	assert_false(session.next_round())
	var dealer_before: int = session.view()["dealer_seat"]
	for i in range(2000):
		if session.round_over():
			break
		assert_true(_human_step(session))
	assert_true(session.round_over())
	assert_true(session.next_round())
	assert_eq(session.view()["dealer_seat"], (dealer_before + 1) % 4)
	assert_eq(session.phase(), SpadesGame.Phase.BIDDING)


# ---------- review fixes ----------

func _hand_strings(session: SpadesSession) -> Array[String]:
	var out: Array[String] = []
	for seat in range(4):
		var labels: Array[String] = []
		for c in session._game.hand_of(seat):
			labels.append(c.label())
		out.append(",".join(labels))
	return out


func test_the_next_round_never_replays_the_previous_deal_after_a_redeal() -> void:
	var checked: int = 0
	for seed_value in range(1, 150):
		var session: SpadesSession = _new_session(seed_value)
		if session._game.redeal_log.is_empty():
			continue
		var first: Array[String] = _hand_strings(session)
		for i in range(2000):
			if session.round_over():
				break
			assert_true(_human_step(session))
		if not session.next_round():
			continue  # the game ended in one round
		var second: Array[String] = _hand_strings(session)
		for a in first:
			assert_false(second.has(a), "seed %d: round 2 reuses a round-1 hand" % seed_value)
		checked += 1
	assert_gt(checked, 5, "not enough redealt games were checked")


func test_the_blind_swap_pick_is_not_in_sorted_order() -> void:
	var total: int = 0
	var differing: int = 0
	for seed_value in range(1, 31):
		var session: SpadesSession = _new_session(seed_value)
		_bots_until_human(session)
		if not session.submit_bid(Bid.blind_nil()):
			continue
		_bots_until_human(session)
		if not session.human_must_swap():
			continue
		var partner_sorted: Array[Card] = session._game.hand_of(2).duplicate()
		var give: Array[Card] = [(session.view()["hand"] as Array)[0]]
		assert_true(session.submit_swap(give, [0] as Array[int]))
		var received: Array = session.view()["swap"]["received"]
		total += 1
		if received[0] != partner_sorted[0]:
			differing += 1
	assert_gt(total, 10)
	assert_gt(differing, total / 2, "position 0 must not always mean the partner's lowest card")


func test_swap_positions_outside_the_partners_hand_are_rejected() -> void:
	var session: SpadesSession = _new_session(3)
	_bots_until_human(session)
	session.submit_bid(Bid.blind_nil())
	_bots_until_human(session)
	var give: Array[Card] = [(session.view()["hand"] as Array)[0]]
	assert_false(session.submit_swap(give, [13] as Array[int]))
	assert_true(session.human_must_swap())


func test_redeal_messages_name_the_player_and_the_missing_suit() -> void:
	var with_redeal: int = 0
	for seed_value in range(1, 60):
		var session: SpadesSession = _new_session(seed_value)
		var messages: Array[String] = session.redeal_messages()
		if session._game.redeal_log.is_empty():
			assert_eq(messages.size(), 0)
		else:
			with_redeal += 1
			assert_gt(messages.size(), 0)
			for m in messages:
				assert_string_contains(m, " has no ")
	assert_gt(with_redeal, 3)
