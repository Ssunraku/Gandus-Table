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
	game = SpadesGame.new(settings, S)  # West bids and leads first
	game.start_round(31)


func _everyone_bids(n: int) -> void:
	for i in range(4):
		assert_true(game.bid(game.turn_seat, Bid.number(n)))


## Hand of 13 cards: the given specific cards, padded with low diamonds.
func _hand(specific: String) -> Array[Card]:
	var cards: Array[Card] = TestCards.hand(specific)
	while cards.size() < 13:
		cards.append(TestCards.card("2D"))
	return cards


func _play_out_round() -> void:
	for i in range(52):
		var seat: int = game.turn_seat
		var legal: Array[Card] = game.legal_cards_for(seat)
		assert_gt(legal.size(), 0)
		assert_true(game.play(seat, legal[0]))


func test_play_is_rejected_during_bidding() -> void:
	assert_false(game.play(W, game.hand_of(W)[0]))


func test_wrong_turn_is_rejected_and_changes_nothing() -> void:
	_everyone_bids(3)
	var card: Card = game.hand_of(N)[0]
	assert_false(game.play(N, card))
	assert_eq(game.turn_seat, W)
	assert_true(game.hand_of(N).has(card))


func test_card_not_in_hand_is_rejected() -> void:
	_everyone_bids(3)
	assert_false(game.play(W, game.hand_of(N)[0]))


func test_cannot_lead_a_spade_before_spades_are_broken() -> void:
	_everyone_bids(3)
	game._hands[W] = _hand("AS 2C")
	assert_false(game.play(W, TestCards.card("AS")))
	assert_eq(game.turn_seat, W)


func test_nobody_may_play_a_spade_on_the_first_trick_even_when_void() -> void:
	_everyone_bids(3)
	game._hands[W] = _hand("2C")
	game._hands[N] = _hand("2S 2H")
	assert_true(game.play(W, TestCards.card("2C")))
	var spade: Card = game.hand_of(N).filter(func(c: Card) -> bool: return c.suit == Card.Suit.SPADES)[0]
	assert_false(game.play(N, spade))


func test_trick_winner_leads_the_next_trick() -> void:
	_everyone_bids(3)
	game._hands[W] = _hand("2C")
	game._hands[N] = _hand("2H")
	game._hands[E] = _hand("3C")
	game._hands[S] = _hand("4C")
	for pair in [[W, "2C"], [N, "2H"], [E, "3C"], [S, "4C"]]:
		assert_true(game.play(pair[0], game.hand_of(pair[0]).filter(func(c: Card) -> bool: return c.label() == pair[1])[0]))
	assert_eq(game.turn_seat, S, "South's 4C is the highest club")
	assert_eq(game.tricks_won[S], 1)
	assert_eq(game.trick_number, 1)
	assert_eq(game.trick_cards.size(), 0)


func test_a_spade_cut_breaks_spades_and_wins_the_trick() -> void:
	_everyone_bids(3)
	game.trick_number = 1  # pretend the first trick is over
	game._hands[W] = _hand("2C")
	game._hands[N] = _hand("2S")
	game._hands[E] = _hand("3C")
	game._hands[S] = _hand("4C")
	assert_false(game.spades_broken)
	for pair in [[W, "2C"], [N, "2S"], [E, "3C"], [S, "4C"]]:
		assert_true(game.play(pair[0], game.hand_of(pair[0]).filter(func(c: Card) -> bool: return c.label() == pair[1])[0]))
	assert_true(game.spades_broken)
	assert_eq(game.turn_seat, N, "the spade cut wins")


func test_a_full_round_ends_and_scores() -> void:
	_everyone_bids(3)
	_play_out_round()
	assert_true(game.phase == SpadesGame.Phase.ROUND_OVER or game.phase == SpadesGame.Phase.GAME_OVER)
	var total_tricks: int = 0
	for seat in range(4):
		assert_eq(game.hand_of(seat).size(), 0)
		total_tricks += int(game.tricks_won[seat])
	assert_eq(total_tricks, 13)
	assert_eq(game.team_scores[0], game.last_round_result["points"][0])


func test_game_ends_when_a_team_reaches_the_target() -> void:
	settings.win_score = -1000
	settings.lose_score = -5000
	_everyone_bids(1)
	_play_out_round()
	assert_eq(game.phase, SpadesGame.Phase.GAME_OVER)
	var expected: int = 0 if game.team_scores[0] > game.team_scores[1] else 1
	assert_eq(game.winner_team, expected)


func test_next_round_rotates_the_dealer_and_starts_bidding() -> void:
	_everyone_bids(3)
	_play_out_round()
	if game.phase == SpadesGame.Phase.GAME_OVER:
		pending("game ended in one round with this seed")
		return
	game.next_round(77)
	assert_eq(game.phase, SpadesGame.Phase.BIDDING)
	assert_eq(game.dealer_seat, W)
	assert_eq(game.turn_seat, N)
	assert_eq(game.bids.size(), 0)
	assert_eq(game.hand_of(S).size(), 13)


func test_actions_after_game_over_are_rejected() -> void:
	settings.win_score = -1000
	settings.lose_score = -5000
	_everyone_bids(1)
	_play_out_round()
	assert_false(game.bid(game.turn_seat, Bid.number(3)))
	assert_false(game.play(W, TestCards.card("2D")))
