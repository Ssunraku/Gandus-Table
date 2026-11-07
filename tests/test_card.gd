extends GutTest


func test_label_for_ace_of_spades() -> void:
	var c: Card = Card.make(Card.Suit.SPADES, Card.Rank.ACE)
	assert_eq(c.label(), "AS")


func test_label_for_ten_of_hearts() -> void:
	var c: Card = Card.make(Card.Suit.HEARTS, Card.Rank.TEN)
	assert_eq(c.label(), "10H")


func test_label_for_two_of_clubs() -> void:
	var c: Card = Card.make(Card.Suit.CLUBS, Card.Rank.TWO)
	assert_eq(c.label(), "2C")


func test_label_for_queen_of_diamonds() -> void:
	var c: Card = Card.make(Card.Suit.DIAMONDS, Card.Rank.QUEEN)
	assert_eq(c.label(), "QD")
