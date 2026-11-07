extends GutTest

var table: Table


func before_each() -> void:
	table = Table.new()
	table.auto_start = false
	add_child_autofree(table)
	table.size = Vector2(1280, 720)
	table.set_state(TableState.dummy())


func _point_on(i: int) -> Vector2:
	return table.hand.card_rect(i).position + Vector2(5, 100)


func test_set_state_creates_13_card_views_for_south() -> void:
	assert_eq(table.hand.card_count(), 13)
	assert_eq(table.hand.get_child_count(), 13)


func test_playing_a_card_leaves_12_in_hand() -> void:
	var chosen: Card = table.state.own_hand[2]
	table.hand.handle_tap(_point_on(2))
	table.hand.handle_tap(_point_on(2))
	assert_eq(table.hand.card_count(), 12)
	assert_eq(table.state.own_hand.size(), 12)
	assert_eq(table.state.get_played(TableState.Seat.SOUTH), chosen)


func test_relayout_at_new_size_keeps_card_count_and_selection() -> void:
	table.hand.handle_tap(_point_on(3))
	assert_eq(table.hand.selected_index, 3)
	table.size = Vector2(720, 1280)
	table.relayout()
	assert_eq(table.hand.card_count(), 13)
	assert_eq(table.hand.get_child_count(), 13)
	assert_eq(table.hand.selected_index, 3)


func test_relayout_inside_screen_for_portrait() -> void:
	table.size = Vector2(720, 1280)
	table.relayout()
	var screen: Rect2 = Rect2(Vector2.ZERO, table.size)
	assert_true(screen.encloses(Rect2(table.hand.position, table.hand.size)))


func test_table_has_no_card_faces_for_opponent_seats() -> void:
	for seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
		var view: OpponentHandView = table.opponent_views[seat]
		assert_eq(view.get_child_count(), 13)
		for child in view.get_children():
			var cv: CardView = child as CardView
			assert_false(cv.face_up)
			assert_null(cv.card)


func test_tap_on_empty_table_puts_lifted_card_down() -> void:
	table.hand.handle_tap(_point_on(1))
	assert_eq(table.hand.selected_index, 1)
	table.clear_selection()
	assert_eq(table.hand.selected_index, -1)


func test_deal_animation_finishes_with_everything_visible() -> void:
	table.play_deal_animation()
	assert_true(table.is_dealing())
	assert_false(table.hand.visible)
	await wait_for_signal(table.deal_finished, 4.0)
	assert_false(table.is_dealing())
	assert_true(table.hand.visible)
	assert_eq(table.hand.card_count(), 13)
	assert_eq(table.temp_card_count(), 0)
