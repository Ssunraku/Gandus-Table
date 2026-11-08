extends GutTest
## The "exact bids" rule: every player is judged alone on their own number bid.

var settings: SpadesSettings


func before_each() -> void:
	settings = SpadesSettings.new()
	settings.exact_mode = SpadesSettings.ExactMode.NORMAL


## Bids and tricks are given as [S, W, N, E]. Bids: int, "nil" or "blind".
func _score(bids: Array, tricks: Array, bags: Array[int] = [0, 0]) -> Dictionary:
	var bid_map: Dictionary = {}
	var trick_map: Dictionary = {}
	for i in range(4):
		var b: Variant = bids[i]
		if b is int:
			bid_map[i] = Bid.number(b)
		elif b == "nil":
			bid_map[i] = Bid.nil()
		else:
			bid_map[i] = Bid.blind_nil()
		trick_map[i] = tricks[i]
	return SpadesScoring.score_round(bid_map, trick_map, bags, settings)


## Score of South alone: South bids `bid`, wins `won`; everyone else is parked on 0-bids safely.
func _south(mode: int, bid: int, won: int) -> int:
	settings.exact_mode = mode
	var r: Dictionary = _score([bid, 1, 1, 1], [won, 1, 1, 1])
	return r["player_points"][0]


func test_off_by_default() -> void:
	assert_eq(SpadesSettings.new().exact_mode, SpadesSettings.ExactMode.OFF)


func test_easy_safe_band_is_one_below_to_one_above() -> void:
	var E: int = SpadesSettings.ExactMode.EASY
	assert_eq(_south(E, 4, 3), 30)
	assert_eq(_south(E, 4, 4), 40)
	assert_eq(_south(E, 4, 5), 40)
	assert_eq(_south(E, 4, 2), -40)
	assert_eq(_south(E, 4, 6), -40)


func test_normal_safe_band_is_bid_or_one_more() -> void:
	var N: int = SpadesSettings.ExactMode.NORMAL
	assert_eq(_south(N, 4, 4), 40)
	assert_eq(_south(N, 4, 5), 40)
	assert_eq(_south(N, 4, 3), -40)
	assert_eq(_south(N, 4, 6), -40)


func test_hard_safe_only_when_exact() -> void:
	var H: int = SpadesSettings.ExactMode.HARD
	assert_eq(_south(H, 4, 4), 40)
	assert_eq(_south(H, 4, 3), -40)
	assert_eq(_south(H, 4, 5), -40)


func test_easy_bid_of_one_with_no_tricks_is_safe_and_scores_zero() -> void:
	assert_eq(_south(SpadesSettings.ExactMode.EASY, 1, 0), 0)


func test_players_are_judged_separately_and_added_to_the_team() -> void:
	# South bids 4 wins 4 (+40); North bids 3 wins 5 under Normal (minus: -30). Team = +10.
	var r: Dictionary = _score([4, 1, 3, 1], [4, 1, 5, 1])
	assert_eq(r["player_points"][0], 40)
	assert_eq(r["player_points"][2], -30)
	assert_eq(r["points"][0], 10)


func test_no_bags_and_no_bag_penalty_while_the_rule_is_on() -> void:
	var r: Dictionary = _score([4, 1, 3, 1], [5, 1, 4, 1], [9, 9])
	assert_eq(r["bags"][0], 9, "bag count is left alone")
	assert_eq(r["points"][0], 70, "no bag points and no -100 penalty")


func test_nil_and_blind_nil_are_unchanged() -> void:
	var r: Dictionary = _score(["nil", 1, "blind", 1], [0, 1, 2, 1])
	assert_eq(r["points"][0], 100 - 200)
	assert_true(r["nil_results"][0])
	assert_false(r["nil_results"][2])


func test_results_are_reported_per_player() -> void:
	var r: Dictionary = _score([4, 1, 3, 1], [4, 1, 5, 1])
	assert_eq(r["player_results"][0], "safe")
	assert_eq(r["player_results"][2], "minus")


func test_rule_off_keeps_the_old_team_scoring() -> void:
	settings.exact_mode = SpadesSettings.ExactMode.OFF
	var r: Dictionary = _score([4, 2, 3, 2], [5, 2, 3, 3])
	assert_eq(r["points"][0], 71)
	assert_false(r.has("player_points"))


func test_turning_the_rule_on_switches_the_bags_penalty_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	assert_true(s.bags_penalty_enabled)
	s.exact_mode = SpadesSettings.ExactMode.EASY
	assert_false(s.bags_penalty_enabled)
