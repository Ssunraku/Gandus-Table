class_name Card
extends RefCounted
## One playing card: a suit and a rank. Pure data, no drawing code.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

var suit: Suit
var rank: Rank


static func make(s: Suit, r: Rank) -> Card:
	var c: Card = Card.new()
	c.suit = s
	c.rank = r
	return c


## Short text such as "AS" (ace of spades) or "10H" (ten of hearts).
func label() -> String:
	var rank_text: String
	match rank:
		Rank.JACK:
			rank_text = "J"
		Rank.QUEEN:
			rank_text = "Q"
		Rank.KING:
			rank_text = "K"
		Rank.ACE:
			rank_text = "A"
		_:
			rank_text = str(int(rank))
	var suit_text: String = ["C", "D", "H", "S"][int(suit)]
	return rank_text + suit_text
