extends GutTest


func test_setup_sets_size_and_face() -> void:
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(Card.make(Card.Suit.SPADES, Card.Rank.ACE), true, Vector2(100, 140))
	assert_eq(v.size, Vector2(100, 140))
	assert_true(v.face_up)
	assert_eq(v.card.label(), "AS")


func test_setup_face_down_without_a_card() -> void:
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(null, false, Vector2(80, 112))
	assert_false(v.face_up)
	assert_null(v.card)


func test_set_selected_toggles_flag() -> void:
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(Card.make(Card.Suit.HEARTS, Card.Rank.TEN), true, Vector2(100, 140))
	assert_false(v.selected)
	v.set_selected(true)
	assert_true(v.selected)
	v.set_selected(false)
	assert_false(v.selected)
