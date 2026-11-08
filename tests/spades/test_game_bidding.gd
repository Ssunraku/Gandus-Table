extends GutTest

const S: int = TableState.Seat.SOUTH
const W: int = TableState.Seat.WEST
const N: int = TableState.Seat.NORTH
const E: int = TableState.Seat.EAST

var settings: SpadesSettings
var game: SpadesGame


func before_each() -> void:
	settings = SpadesSettings.new()
	settings.redeal_enabled = false
	game = SpadesGame.new(settings, S)  # dealer South -> West bids first
	game.start_round(11)


func _bid_numbers(count: int) -> void:
	for i in range(count):
		assert_true(game.bid(game.turn_seat, Bid.number(3)))


func test_bidding_goes_clockwise_from_the_dealers_left() -> void:
	assert_eq(game.turn_seat, W)
	game.bid(W, Bid.number(3))
	assert_eq(game.turn_seat, N)
	game.bid(N, Bid.number(3))
	assert_eq(game.turn_seat, E)
	game.bid(E, Bid.number(3))
	assert_eq(game.turn_seat, S)


func test_out_of_turn_bid_is_rejected_and_changes_nothing() -> void:
	assert_false(game.bid(E, Bid.number(3)))
	assert_eq(game.turn_seat, W)
	assert_eq(game.bids.size(), 0)


func test_number_bid_must_be_1_to_13() -> void:
	assert_false(game.bid(W, Bid.number(0)))
	assert_false(game.bid(W, Bid.number(14)))
	assert_true(game.bid(W, Bid.number(13)))


func test_nil_rejected_when_disabled() -> void:
	settings.nil_enabled = false
	assert_false(game.bid(W, Bid.nil()))
	assert_true(game.bid(W, Bid.number(1)))


func test_blind_nil_rejected_when_disabled() -> void:
	settings.blind_nil_enabled = false
	assert_false(game.bid(W, Bid.blind_nil()))


func test_blind_nil_allowed_when_normal_nil_is_off() -> void:
	settings.nil_enabled = false
	assert_true(game.bid(W, Bid.blind_nil()))


func test_both_partners_may_not_bid_blind_nil() -> void:
	assert_true(game.bid(W, Bid.blind_nil()))
	game.bid(N, Bid.number(2))
	assert_false(game.bid(E, Bid.blind_nil()), "East is West's partner")
	assert_eq(game.turn_seat, E)


func test_players_on_different_teams_may_both_bid_blind_nil() -> void:
	assert_true(game.bid(W, Bid.blind_nil()))
	assert_true(game.bid(N, Bid.blind_nil()))


func test_after_four_bids_without_blind_nil_play_starts() -> void:
	_bid_numbers(4)
	assert_eq(game.phase, SpadesGame.Phase.PLAYING)
	assert_eq(game.turn_seat, W)


func test_after_four_bids_with_blind_nil_the_swap_phase_starts() -> void:
	game.bid(W, Bid.blind_nil())
	_bid_numbers(3)
	assert_eq(game.phase, SpadesGame.Phase.SWAP)


func test_blind_nil_bidder_sees_no_hand_until_bidding_is_over() -> void:
	game.bid(W, Bid.blind_nil())
	assert_eq(game.view_for(W)["hand"].size(), 0)
	assert_eq(game.view_for(N)["hand"].size(), 13)
	_bid_numbers(3)
	assert_eq(game.view_for(W)["hand"].size(), 13)


func test_bid_in_wrong_phase_is_rejected() -> void:
	_bid_numbers(4)
	assert_false(game.bid(W, Bid.number(3)))
