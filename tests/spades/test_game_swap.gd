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
	game = SpadesGame.new(settings, S)  # West bids first
	game.start_round(21)


## West bids Blind Nil (partner is East); everyone else bids 3.
func _to_swap_phase() -> void:
	game.bid(W, Bid.blind_nil())
	game.bid(N, Bid.number(3))
	game.bid(E, Bid.number(3))
	game.bid(S, Bid.number(3))


func test_swap_phase_is_reached_after_a_blind_nil() -> void:
	_to_swap_phase()
	assert_eq(game.phase, SpadesGame.Phase.SWAP)


func test_swapping_zero_cards_just_starts_play() -> void:
	_to_swap_phase()
	var before: Array[String] = TestCards.labels(game.hand_of(W))
	assert_true(game.swap(W, [] as Array[Card], [] as Array[int]))
	assert_eq(game.phase, SpadesGame.Phase.PLAYING)
	assert_eq(TestCards.labels(game.hand_of(W)), before)


func test_swapping_one_card_moves_exactly_the_right_cards() -> void:
	_to_swap_phase()
	var given: Card = game.hand_of(W)[2]
	var taken: Card = game.hand_of(E)[5]
	assert_true(game.swap(W, [given] as Array[Card], [5] as Array[int]))
	assert_true(game.hand_of(W).has(taken))
	assert_false(game.hand_of(W).has(given))
	assert_true(game.hand_of(E).has(given))
	assert_false(game.hand_of(E).has(taken))
	assert_eq(game.hand_of(W).size(), 13)
	assert_eq(game.hand_of(E).size(), 13)


func test_swapping_two_cards_works() -> void:
	_to_swap_phase()
	var given: Array[Card] = [game.hand_of(W)[0], game.hand_of(W)[12]]
	var taken: Array[Card] = [game.hand_of(E)[1], game.hand_of(E)[7]]
	assert_true(game.swap(W, given, [1, 7] as Array[int]))
	for c in taken:
		assert_true(game.hand_of(W).has(c))
	for c in given:
		assert_true(game.hand_of(E).has(c))


func test_counts_must_match() -> void:
	_to_swap_phase()
	assert_false(game.swap(W, [game.hand_of(W)[0]] as Array[Card], [1, 2] as Array[int]))
	assert_eq(game.phase, SpadesGame.Phase.SWAP)


func test_more_than_two_cards_rejected() -> void:
	_to_swap_phase()
	var give: Array[Card] = [game.hand_of(W)[0], game.hand_of(W)[1], game.hand_of(W)[2]]
	assert_false(game.swap(W, give, [0, 1, 2] as Array[int]))


func test_card_not_in_the_bidders_hand_is_rejected() -> void:
	_to_swap_phase()
	var foreign: Card = game.hand_of(N)[0]
	assert_false(game.swap(W, [foreign] as Array[Card], [0] as Array[int]))


func test_position_out_of_range_is_rejected() -> void:
	_to_swap_phase()
	assert_false(game.swap(W, [game.hand_of(W)[0]] as Array[Card], [13] as Array[int]))
	assert_false(game.swap(W, [game.hand_of(W)[0]] as Array[Card], [-1] as Array[int]))


func test_duplicate_positions_are_rejected() -> void:
	_to_swap_phase()
	var give: Array[Card] = [game.hand_of(W)[0], game.hand_of(W)[1]]
	assert_false(game.swap(W, give, [4, 4] as Array[int]))


func test_only_the_blind_nil_bidder_may_swap() -> void:
	_to_swap_phase()
	assert_false(game.swap(N, [] as Array[Card], [] as Array[int]))
	assert_false(game.swap(E, [] as Array[Card], [] as Array[int]))


func test_swap_is_rejected_outside_the_swap_phase() -> void:
	assert_false(game.swap(W, [] as Array[Card], [] as Array[int]))


func test_partner_sees_what_was_given_and_taken() -> void:
	_to_swap_phase()
	var given: Card = game.hand_of(W)[2]
	var taken: Card = game.hand_of(E)[5]
	game.swap(W, [given] as Array[Card], [5] as Array[int])
	var swap_view: Dictionary = game.view_for(E)["swap"]
	assert_eq(swap_view["received"][0].label(), given.label())
	assert_eq(swap_view["lost"][0].label(), taken.label())


func test_opponents_do_not_see_the_swap_cards() -> void:
	_to_swap_phase()
	game.swap(W, [game.hand_of(W)[2]] as Array[Card], [5] as Array[int])
	assert_true((game.view_for(N)["swap"] as Dictionary).is_empty())
	assert_true((game.view_for(S)["swap"] as Dictionary).is_empty())


func test_two_blind_nil_bidders_on_different_teams_must_both_swap() -> void:
	game.bid(W, Bid.blind_nil())
	game.bid(N, Bid.blind_nil())
	game.bid(E, Bid.number(3))
	game.bid(S, Bid.number(3))
	assert_eq(game.phase, SpadesGame.Phase.SWAP)
	game.swap(W, [] as Array[Card], [] as Array[int])
	assert_eq(game.phase, SpadesGame.Phase.SWAP)
	game.swap(N, [] as Array[Card], [] as Array[int])
	assert_eq(game.phase, SpadesGame.Phase.PLAYING)


func test_a_bidder_cannot_swap_twice() -> void:
	game.bid(W, Bid.blind_nil())
	game.bid(N, Bid.blind_nil())
	game.bid(E, Bid.number(3))
	game.bid(S, Bid.number(3))
	game.swap(W, [] as Array[Card], [] as Array[int])
	assert_false(game.swap(W, [] as Array[Card], [] as Array[int]))
