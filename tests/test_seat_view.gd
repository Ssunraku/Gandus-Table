extends GutTest


func _backs(v: Control) -> Array[CardView]:
	var out: Array[CardView] = []
	for child in v.get_children():
		out.append(child as CardView)
	return out


func test_seat_view_shows_dealer_badge_only_when_dealer() -> void:
	var v: SeatView = SeatView.new()
	add_child_autofree(v)
	v.setup("Tin", true, false, 0)
	assert_true(v.shows_dealer_badge())
	v.setup("Tin", false, false, 0)
	assert_false(v.shows_dealer_badge())


func test_fit_font_size_keeps_size_when_text_fits() -> void:
	assert_eq(SeatView.fit_font_size("A", 500.0, 20), 20)


func test_fit_font_size_shrinks_long_text_to_fit() -> void:
	var fitted: int = SeatView.fit_font_size("Cherry the Magnificent", 60.0, 40)
	assert_lt(fitted, 40)
	var w: float = ThemeDB.fallback_font.get_string_size("Cherry the Magnificent", HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	assert_true(w <= 60.0 or fitted == SeatView.MIN_FONT_SIZE)


func test_seat_view_remembers_name_turn_and_tricks() -> void:
	var v: SeatView = SeatView.new()
	add_child_autofree(v)
	v.setup("Cherry", false, true, 3)
	assert_eq(v.seat_name, "Cherry")
	assert_true(v.is_turn)
	assert_eq(v.tricks, 3)


func test_opponent_view_with_zero_count_shows_no_cards() -> void:
	var v: OpponentHandView = OpponentHandView.new()
	add_child_autofree(v)
	v.show_count(0, Rect2(0, 0, 400, 100), Vector2(60, 84), TableState.Seat.NORTH)
	assert_eq(v.get_child_count(), 0)


func test_opponent_view_with_13_count_shows_13_backs() -> void:
	var v: OpponentHandView = OpponentHandView.new()
	add_child_autofree(v)
	v.show_count(13, Rect2(0, 0, 400, 100), Vector2(60, 84), TableState.Seat.NORTH)
	var backs: Array[CardView] = _backs(v)
	assert_eq(backs.size(), 13)
	for b in backs:
		assert_false(b.face_up)
		assert_null(b.card)


func test_side_opponent_cards_stay_inside_their_area() -> void:
	for seat in [TableState.Seat.WEST, TableState.Seat.EAST]:
		var v: OpponentHandView = OpponentHandView.new()
		add_child_autofree(v)
		var area: Rect2 = Rect2(0, 0, 84, 300)
		v.show_count(13, area, Vector2(60, 84), seat)
		for b in _backs(v):
			assert_true(area.has_point(b.position + b.size / 2.0), "centre inside for seat %s" % seat)


func test_changing_the_count_rebuilds_the_backs() -> void:
	var v: OpponentHandView = OpponentHandView.new()
	add_child_autofree(v)
	v.show_count(13, Rect2(0, 0, 400, 100), Vector2(60, 84), TableState.Seat.NORTH)
	v.show_count(5, Rect2(0, 0, 400, 100), Vector2(60, 84), TableState.Seat.NORTH)
	assert_eq(v.get_child_count(), 5)


func test_score_box_remembers_scores() -> void:
	var b: ScoreBox = ScoreBox.new()
	add_child_autofree(b)
	var scores: Array[int] = [120, 80]
	var bags: Array[int] = [2, 1]
	b.show_scores(scores, bags)
	assert_eq(b.scores, [120, 80])
	assert_eq(b.bags, [2, 1])
