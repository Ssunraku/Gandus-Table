extends GutTest


func test_card_round_trip_through_json() -> void:
	for s in range(4):
		for r in range(2, 15):
			var c: Card = Card.make(s as Card.Suit, r as Card.Rank)
			var text: String = JSON.stringify(Wire.card_to_dict(c))
			var back: Card = Wire.card_from_dict(JSON.parse_string(text))
			assert_not_null(back)
			assert_eq(back.suit, c.suit)
			assert_eq(back.rank, c.rank)


func test_invalid_card_is_null() -> void:
	assert_null(Wire.card_from_dict({"s": 9, "r": 2}))
	assert_null(Wire.card_from_dict({}))
	assert_null(Wire.card_from_dict({"s": 1, "r": 1}))
	assert_null(Wire.card_from_dict({"s": 1, "r": 15}))
	assert_null(Wire.card_from_dict({"s": "x", "r": 5}))


func test_cards_array_round_trip_skips_nothing_valid() -> void:
	var cs: Array[Card] = [Card.make(Card.Suit.SPADES, Card.Rank.ACE), Card.make(Card.Suit.CLUBS, Card.Rank.TWO)]
	var back: Array[Card] = Wire.cards_from_array(JSON.parse_string(JSON.stringify(Wire.cards_to_array(cs))))
	assert_eq(back.size(), 2)
	assert_eq(back[0].rank, Card.Rank.ACE)


func test_bid_round_trip_for_number_nil_and_blind_nil() -> void:
	for b in [Bid.number(5), Bid.nil(), Bid.blind_nil()]:
		var back: Bid = Wire.bid_from_dict(JSON.parse_string(JSON.stringify(Wire.bid_to_dict(b))))
		assert_not_null(back)
		assert_eq(back.kind, b.kind)
		assert_eq(back.tricks, b.tricks)


func test_invalid_bid_is_null() -> void:
	assert_null(Wire.bid_from_dict({"k": 0, "n": 0}))
	assert_null(Wire.bid_from_dict({"k": 0, "n": 14}))
	assert_null(Wire.bid_from_dict({"k": 7, "n": 3}))
	assert_null(Wire.bid_from_dict({}))


func test_settings_round_trip_keeps_every_option() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	s.nil_enabled = false
	s.redeal_enabled = false
	s.play_higher_enabled = true
	s.win_score = 300
	s.lose_score = -350
	s.exact_mode = SpadesSettings.ExactMode.HARD
	var b: SpadesSettings = Wire.settings_from_dict(JSON.parse_string(JSON.stringify(Wire.settings_to_dict(s))))
	assert_false(b.blind_nil_enabled)
	assert_false(b.nil_enabled)
	assert_false(b.redeal_enabled)
	assert_true(b.play_higher_enabled)
	assert_eq(b.win_score, 300)
	assert_eq(b.lose_score, -350)
	assert_eq(b.exact_mode, SpadesSettings.ExactMode.HARD)
	assert_false(b.bags_penalty_enabled)


func test_bags_penalty_survives_when_exact_bids_is_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.bags_penalty_enabled = false
	var b: SpadesSettings = Wire.settings_from_dict(JSON.parse_string(JSON.stringify(Wire.settings_to_dict(s))))
	assert_false(b.bags_penalty_enabled)


func test_settings_from_empty_dict_gives_defaults() -> void:
	var d: SpadesSettings = SpadesSettings.new()
	var b: SpadesSettings = Wire.settings_from_dict({})
	assert_eq(b.win_score, d.win_score)
	assert_eq(b.exact_mode, d.exact_mode)
	assert_eq(b.bags_penalty_enabled, d.bags_penalty_enabled)
