class_name HandCheck
extends RefCounted
## Small questions about a hand of cards (used for redeals and play rules).

const ALL_SUITS: Array[Card.Suit] = [Card.Suit.CLUBS, Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES]


static func count_suit(hand: Array[Card], suit: Card.Suit) -> int:
	var n: int = 0
	for c in hand:
		if c.suit == suit:
			n += 1
	return n


## The suits of which the hand has no card at all.
static func void_suits(hand: Array[Card]) -> Array[Card.Suit]:
	var out: Array[Card.Suit] = []
	for s in ALL_SUITS:
		if count_suit(hand, s) == 0:
			out.append(s)
	return out


static func has_void(hand: Array[Card]) -> bool:
	return not void_suits(hand).is_empty()


static func has_only_spades(hand: Array[Card]) -> bool:
	if hand.is_empty():
		return false
	return count_suit(hand, Card.Suit.SPADES) == hand.size()
