extends GutTest


func test_dummy_has_13_cards_for_south_and_13_counts_for_others() -> void:
	var s: TableState = TableState.dummy()
	assert_eq(s.own_hand.size(), 13)
	assert_eq(s.get_card_count(TableState.Seat.SOUTH), 13)
	assert_eq(s.get_card_count(TableState.Seat.WEST), 13)
	assert_eq(s.get_card_count(TableState.Seat.NORTH), 13)
	assert_eq(s.get_card_count(TableState.Seat.EAST), 13)


func test_play_own_card_moves_card_to_played() -> void:
	var s: TableState = TableState.dummy()
	var card: Card = s.own_hand[0]
	assert_true(s.play_own_card(card))
	assert_eq(s.own_hand.size(), 12)
	assert_eq(s.get_card_count(TableState.Seat.SOUTH), 12)
	assert_eq(s.get_played(TableState.Seat.SOUTH), card)


func test_play_card_not_in_hand_returns_false() -> void:
	var s: TableState = TableState.dummy()
	var removed: Card = s.own_hand[0]
	s.own_hand.erase(removed)
	assert_false(s.play_own_card(removed))
	assert_eq(s.own_hand.size(), 12)


func test_cannot_set_count_for_south() -> void:
	var s: TableState = TableState.dummy()
	assert_false(s.set_card_count(TableState.Seat.SOUTH, 5))
	assert_eq(s.get_card_count(TableState.Seat.SOUTH), 13)


func test_set_count_works_for_other_seats() -> void:
	var s: TableState = TableState.dummy()
	assert_true(s.set_card_count(TableState.Seat.WEST, 7))
	assert_eq(s.get_card_count(TableState.Seat.WEST), 7)


func test_playing_all_cards_leaves_empty_hand() -> void:
	var s: TableState = TableState.dummy()
	while s.own_hand.size() > 0:
		assert_true(s.play_own_card(s.own_hand[0]))
	assert_eq(s.own_hand.size(), 0)
	assert_eq(s.get_card_count(TableState.Seat.SOUTH), 0)


func test_opponent_counts_are_plain_integers() -> void:
	var s: TableState = TableState.dummy()
	assert_eq(typeof(s.get_card_count(TableState.Seat.WEST)), TYPE_INT)


func test_only_get_played_returns_a_card_for_a_seat() -> void:
	# Hidden hands: the only way to get a Card out of TableState by seat is
	# get_played (a card already played face-up on the table).
	var card_returning: Array[String] = []
	for m in TableState.new().get_script().get_script_method_list():
		var ret: Dictionary = m["return"]
		if ret.get("class_name", "") == "Card":
			card_returning.append(m["name"])
	assert_eq(card_returning, ["get_played"])
