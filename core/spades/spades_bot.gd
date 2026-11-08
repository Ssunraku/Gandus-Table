class_name SpadesBot
extends RefCounted
## A simple computer player. It always chooses an action the game accepts, never
## bids Blind Nil, and plays a random legal card. It exists to fill empty seats and to
## play whole games in tests. It reads only the real hand of the seat it plays for.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## Rough guess of how many tricks the hand wins: aces and kings plus long spades.
func choose_bid(game: SpadesGame, seat: int) -> Bid:
	var hand: Array[Card] = game.hand_of(seat)
	var high: int = 0
	var any_queen_or_better: bool = false
	for c in hand:
		if c.rank >= Card.Rank.KING:
			high += 1
		if c.rank >= Card.Rank.QUEEN:
			any_queen_or_better = true
	var spades: int = HandCheck.count_suit(hand, Card.Suit.SPADES)
	if game.settings.nil_enabled and not any_queen_or_better and spades <= 2:
		return Bid.nil()
	var estimate: int = high + maxi(0, spades - 3)
	return Bid.number(clampi(estimate, 1, 13))


## Bots never swap cards (they never bid Blind Nil, so this is only for completeness).
func choose_swap(_game: SpadesGame, _seat: int) -> Dictionary:
	return {"give": [] as Array[Card], "positions": [] as Array[int]}


func choose_card(game: SpadesGame, seat: int) -> Card:
	var legal: Array[Card] = game.legal_cards_for(seat)
	return legal[_rng.randi_range(0, legal.size() - 1)]
