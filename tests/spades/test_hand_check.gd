extends GutTest


func _spades(n: int) -> Array[Card]:
	var out: Array[Card] = []
	for r in range(2, 2 + n):
		out.append(Card.make(Card.Suit.SPADES, r as Card.Rank))
	return out


func test_thirteen_spades_has_a_void() -> void:
	assert_true(HandCheck.has_void(_spades(13)))


func test_hand_with_all_four_suits_has_no_void() -> void:
	var hand: Array[Card] = [
		Card.make(Card.Suit.CLUBS, Card.Rank.TWO),
		Card.make(Card.Suit.DIAMONDS, Card.Rank.TWO),
		Card.make(Card.Suit.HEARTS, Card.Rank.TWO),
		Card.make(Card.Suit.SPADES, Card.Rank.TWO),
	]
	assert_false(HandCheck.has_void(hand))


func test_void_suits_lists_the_missing_suits() -> void:
	var hand: Array[Card] = [
		Card.make(Card.Suit.CLUBS, Card.Rank.TWO),
		Card.make(Card.Suit.SPADES, Card.Rank.TWO),
	]
	var missing: Array[Card.Suit] = HandCheck.void_suits(hand)
	assert_eq(missing, [Card.Suit.DIAMONDS, Card.Suit.HEARTS])


func test_count_suit() -> void:
	assert_eq(HandCheck.count_suit(_spades(3), Card.Suit.SPADES), 3)
	assert_eq(HandCheck.count_suit(_spades(3), Card.Suit.HEARTS), 0)


func test_has_only_spades() -> void:
	assert_true(HandCheck.has_only_spades(_spades(3)))
	var mixed: Array[Card] = [Card.make(Card.Suit.SPADES, Card.Rank.TWO), Card.make(Card.Suit.HEARTS, Card.Rank.TWO)]
	assert_false(HandCheck.has_only_spades(mixed))


func test_empty_hand_is_not_only_spades() -> void:
	var empty: Array[Card] = []
	assert_false(HandCheck.has_only_spades(empty))
