extends GutTest

const S: int = TableState.Seat.SOUTH
const W: int = TableState.Seat.WEST
const N: int = TableState.Seat.NORTH
const E: int = TableState.Seat.EAST

var settings: SpadesSettings


func before_each() -> void:
	settings = SpadesSettings.new()


## Bids and tricks are given as [S, W, N, E]. Bids: int = number bid, "nil", or "blind".
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


func test_made_bid_scores_ten_per_trick_plus_bags() -> void:
	# South+North bid 4+3=7 and win 5+3=8 tricks -> 70 + 1.
	var r: Dictionary = _score([4, 2, 3, 2], [5, 2, 3, 3])
	assert_eq(r["points"][0], 71)
	assert_eq(r["bags"][0], 1)


func test_missed_bid_loses_ten_per_bid_and_no_bags() -> void:
	var r: Dictionary = _score([4, 2, 3, 2], [3, 5, 2, 3])
	assert_eq(r["points"][0], -70)
	assert_eq(r["bags"][0], 0)


func test_exact_bid_scores_with_no_bags() -> void:
	var r: Dictionary = _score([4, 2, 3, 2], [4, 3, 3, 3])
	assert_eq(r["points"][0], 70)
	assert_eq(r["bags"][0], 0)


func test_other_team_is_scored_too() -> void:
	var r: Dictionary = _score([4, 2, 3, 2], [4, 3, 3, 3])
	# West+East bid 4, won 6 -> 40 + 2 bags.
	assert_eq(r["points"][1], 42)
	assert_eq(r["bags"][1], 2)


func test_made_nil_scores_plus_100() -> void:
	# South bids Nil and wins 0; North bids 5 and wins 6 -> 100 + 50 + 1.
	var r: Dictionary = _score(["nil", 3, 5, 3], [0, 3, 6, 4])
	assert_eq(r["points"][0], 151)
	assert_true(r["nil_results"][S])


func test_failed_nil_costs_100_and_adds_no_bags() -> void:
	# South fails Nil with 1 trick; North bids 4 and wins 4. Partner's tricks only count.
	var r: Dictionary = _score(["nil", 3, 4, 3], [1, 4, 4, 4])
	assert_eq(r["points"][0], -60)
	assert_eq(r["bags"][0], 0)
	assert_false(r["nil_results"][S])


func test_nil_bidders_tricks_do_not_help_the_bid() -> void:
	# North bids 4 but wins only 3; South's failed-Nil trick must not rescue the bid.
	var r: Dictionary = _score(["nil", 3, 4, 3], [1, 5, 3, 4])
	assert_eq(r["points"][0], -140)


func test_made_blind_nil_scores_plus_200() -> void:
	var r: Dictionary = _score(["blind", 3, 5, 3], [0, 3, 5, 5])
	assert_eq(r["points"][0], 250)


func test_failed_blind_nil_costs_200() -> void:
	var r: Dictionary = _score(["blind", 3, 5, 3], [2, 3, 5, 3])
	assert_eq(r["points"][0], 50 - 200)


func test_blind_nil_is_worth_100_when_normal_nil_is_off() -> void:
	settings.nil_enabled = false
	var r: Dictionary = _score(["blind", 3, 5, 3], [0, 3, 5, 5])
	assert_eq(r["points"][0], 150)


func test_both_partners_nil_scores_each_nil_alone() -> void:
	# South made Nil, North failed Nil: +100 - 100, no numbered bid, no bags.
	var r: Dictionary = _score(["nil", 3, "nil", 3], [0, 4, 2, 7])
	assert_eq(r["points"][0], 0)
	assert_eq(r["bags"][0], 0)


func test_ten_bags_cost_100_and_drop_by_ten() -> void:
	# Team already has 9 bags; wins 1 extra trick -> 10 bags -> -100, bags become 0.
	var r: Dictionary = _score([4, 2, 3, 2], [4, 3, 4, 2], [9, 0])
	assert_eq(r["points"][0], 70 + 1 - 100)
	assert_eq(r["bags"][0], 0)


func test_bags_carry_over_below_ten() -> void:
	var r: Dictionary = _score([4, 2, 3, 2], [4, 3, 4, 2], [5, 0])
	assert_eq(r["bags"][0], 6)


func test_bags_penalty_off_keeps_the_extra_point_but_no_penalty() -> void:
	settings.bags_penalty_enabled = false
	var r: Dictionary = _score([4, 2, 3, 2], [4, 3, 4, 2], [9, 0])
	assert_eq(r["points"][0], 71)


func test_game_continues_below_the_target() -> void:
	assert_eq(SpadesScoring.game_winner([300, 200], settings), -1)


func test_first_to_reach_target_wins() -> void:
	assert_eq(SpadesScoring.game_winner([510, 200], settings), 0)
	assert_eq(SpadesScoring.game_winner([100, 505], settings), 1)


func test_both_over_target_higher_score_wins() -> void:
	assert_eq(SpadesScoring.game_winner([520, 560], settings), 1)


func test_both_over_target_and_equal_means_play_on() -> void:
	assert_eq(SpadesScoring.game_winner([520, 520], settings), -1)


func test_team_at_losing_score_loses() -> void:
	assert_eq(SpadesScoring.game_winner([-210, 100], settings), 1)
	assert_eq(SpadesScoring.game_winner([100, -200], settings), 0)


func test_custom_target_is_used() -> void:
	settings.win_score = 250
	assert_eq(SpadesScoring.game_winner([260, 100], settings), 0)
