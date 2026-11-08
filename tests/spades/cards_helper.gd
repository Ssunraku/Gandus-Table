class_name TestCards
extends RefCounted
## Test helper: build cards from short text such as "AS 10H 2C".


static func card(text: String) -> Card:
	var suit_char: String = text.substr(text.length() - 1)
	var rank_text: String = text.substr(0, text.length() - 1)
	var suit: Card.Suit = ["C", "D", "H", "S"].find(suit_char) as Card.Suit
	var rank: int
	match rank_text:
		"J":
			rank = Card.Rank.JACK
		"Q":
			rank = Card.Rank.QUEEN
		"K":
			rank = Card.Rank.KING
		"A":
			rank = Card.Rank.ACE
		_:
			rank = int(rank_text)
	return Card.make(suit, rank as Card.Rank)


static func hand(text: String) -> Array[Card]:
	var out: Array[Card] = []
	for part in text.split(" ", false):
		out.append(card(part))
	return out


static func labels(cards: Array[Card]) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		out.append(c.label())
	out.sort()
	return out
