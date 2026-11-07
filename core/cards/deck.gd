class_name Deck
extends RefCounted
## Builds and shuffles a standard 52-card deck. Pure data, no drawing code.


## All 52 cards: clubs, diamonds, hearts, spades; each suit low to high.
static func standard_52() -> Array[Card]:
	var cards: Array[Card] = []
	for s in [Card.Suit.CLUBS, Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES]:
		for r in range(int(Card.Rank.TWO), int(Card.Rank.ACE) + 1):
			cards.append(Card.make(s, r as Card.Rank))
	return cards


## The same seed always gives the same order (useful for tests and replays).
static func shuffled(seed_value: int) -> Array[Card]:
	var cards: Array[Card] = standard_52()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Card = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	return cards


## Returns a new array sorted by suit (clubs, diamonds, hearts, spades), then rank.
static func sort_hand(cards: Array[Card]) -> Array[Card]:
	var out: Array[Card] = cards.duplicate()
	out.sort_custom(func(a: Card, b: Card) -> bool:
		if a.suit != b.suit:
			return int(a.suit) < int(b.suit)
		return int(a.rank) < int(b.rank))
	return out
