extends GutTest


func _labels(cards: Array[Card]) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		out.append(c.label())
	return out


func test_standard_has_52_unique_cards() -> void:
	var deck: Array[Card] = Deck.standard_52()
	assert_eq(deck.size(), 52)
	var seen: Dictionary = {}
	for c in deck:
		seen[c.label()] = true
	assert_eq(seen.size(), 52)


func test_same_seed_same_order() -> void:
	assert_eq(_labels(Deck.shuffled(7)), _labels(Deck.shuffled(7)))


func test_different_seed_different_order() -> void:
	assert_ne(_labels(Deck.shuffled(7)), _labels(Deck.shuffled(8)))


func test_shuffle_keeps_all_52() -> void:
	var a: Array[String] = _labels(Deck.shuffled(3))
	a.sort()
	var b: Array[String] = _labels(Deck.standard_52())
	b.sort()
	assert_eq(a, b)


func test_sort_hand_orders_by_suit_then_rank() -> void:
	var hand: Array[Card] = [
		Card.make(Card.Suit.SPADES, Card.Rank.ACE),
		Card.make(Card.Suit.CLUBS, Card.Rank.TWO),
		Card.make(Card.Suit.HEARTS, Card.Rank.KING),
		Card.make(Card.Suit.CLUBS, Card.Rank.THREE),
	]
	assert_eq(_labels(Deck.sort_hand(hand)), ["2C", "3C", "KH", "AS"])


func test_sort_hand_does_not_change_input() -> void:
	var hand: Array[Card] = [
		Card.make(Card.Suit.SPADES, Card.Rank.ACE),
		Card.make(Card.Suit.CLUBS, Card.Rank.TWO),
	]
	Deck.sort_hand(hand)
	assert_eq(_labels(hand), ["AS", "2C"])
