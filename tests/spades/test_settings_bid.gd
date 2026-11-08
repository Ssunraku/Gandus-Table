extends GutTest


func test_defaults_match_the_rules_sheet() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	assert_true(s.blind_nil_enabled)
	assert_true(s.nil_enabled)
	assert_true(s.redeal_enabled)
	assert_true(s.bags_penalty_enabled)
	assert_false(s.play_higher_enabled)
	assert_eq(s.win_score, 500)
	assert_eq(s.lose_score, -200)


func test_nil_is_worth_100() -> void:
	assert_eq(SpadesSettings.new().nil_value(), 100)


func test_blind_nil_is_worth_200_normally() -> void:
	assert_eq(SpadesSettings.new().blind_nil_value(), 200)


func test_blind_nil_is_worth_100_when_normal_nil_is_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.nil_enabled = false
	assert_eq(s.blind_nil_value(), 100)


func test_number_bid_keeps_its_tricks() -> void:
	var b: Bid = Bid.number(5)
	assert_eq(b.kind, Bid.Kind.NUMBER)
	assert_eq(b.tricks, 5)


func test_nil_bids_have_the_right_kind_and_zero_tricks() -> void:
	assert_eq(Bid.nil().kind, Bid.Kind.NIL)
	assert_eq(Bid.nil().tricks, 0)
	assert_eq(Bid.blind_nil().kind, Bid.Kind.BLIND_NIL)
	assert_eq(Bid.blind_nil().tricks, 0)
