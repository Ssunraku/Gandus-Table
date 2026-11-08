extends GutTest

const SIZES: Array[Vector2] = [
	Vector2(1280, 720),
	Vector2(720, 1280),
	Vector2(2000, 1200),
	Vector2(1200, 2000),
	Vector2(720, 1200),
]
const SEATS: Array[int] = [
	TableState.Seat.SOUTH,
	TableState.Seat.WEST,
	TableState.Seat.NORTH,
	TableState.Seat.EAST,
]


func _screen_rect(s: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, s)


func test_portrait_flag() -> void:
	assert_false(TableLayout.compute(Vector2(1280, 720))["is_portrait"])
	assert_true(TableLayout.compute(Vector2(720, 1280))["is_portrait"])


func test_hand_cards_fit_on_screen() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var card_size: Vector2 = l["card_size"]
		var fan: Array[Dictionary] = TableLayout.fan(13, l["hand_rect"], card_size)
		assert_eq(fan.size(), 13, "13 items at %s" % size)
		for item in fan:
			var r: Rect2 = Rect2(item["position"], card_size)
			assert_true(_screen_rect(size).encloses(r), "card %s inside screen %s" % [r, size])


func test_seat_rects_do_not_overlap_hand_rect() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var seat_rects: Dictionary = l["seat_rects"]
		for seat in SEATS:
			var r: Rect2 = seat_rects[seat]
			assert_false(r.intersects(l["hand_rect"]), "seat %s vs hand at %s" % [seat, size])


func test_seat_rects_do_not_overlap_each_other() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		for a in SEATS:
			for b in SEATS:
				if a < b:
					assert_false((l["seat_rects"][a] as Rect2).intersects(l["seat_rects"][b]), "seats %s and %s at %s" % [a, b, size])


func test_seat_bars_do_not_overlap_opponent_fans() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		for seat in SEATS:
			for fan_seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
				assert_false((l["seat_rects"][seat] as Rect2).intersects(l["opponent_fan_rects"][fan_seat]), "bar %s vs fan %s at %s" % [seat, fan_seat, size])


func test_seat_bars_do_not_overlap_played_cards() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var card_size: Vector2 = l["play_card_size"]
		for seat in SEATS:
			for spot_seat in SEATS:
				var spot: Vector2 = l["play_spots"][spot_seat]
				var card_rect: Rect2 = Rect2(spot - card_size / 2.0, card_size)
				assert_false((l["seat_rects"][seat] as Rect2).intersects(card_rect), "bar %s vs card %s at %s" % [seat, spot_seat, size])


func test_north_fan_and_bar_clear_of_buttons_and_score_box() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var blockers: Array[Rect2] = [l["button_rect_left"], l["button_rect_right"], l["score_rect"]]
		for r in blockers:
			assert_false(r.intersects(l["opponent_fan_rects"][TableState.Seat.NORTH]), "fan vs %s at %s" % [r, size])
			assert_false(r.intersects(l["seat_rects"][TableState.Seat.NORTH]), "north bar vs %s at %s" % [r, size])


func test_all_rects_inside_screen() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var screen: Rect2 = _screen_rect(size)
		var rects: Array[Rect2] = [l["hand_rect"], l["score_rect"], l["button_rect_left"], l["button_rect_right"]]
		for seat in SEATS:
			rects.append(l["seat_rects"][seat])
		for seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
			rects.append(l["opponent_fan_rects"][seat])
		for r in rects:
			assert_true(screen.encloses(r), "%s inside %s" % [r, size])


func test_play_spots_inside_screen() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var card_size: Vector2 = l["play_card_size"]
		for seat in SEATS:
			var spot: Vector2 = l["play_spots"][seat]
			var r: Rect2 = Rect2(spot - card_size / 2.0, card_size)
			assert_true(_screen_rect(size).encloses(r), "spot %s at %s" % [seat, size])


func test_fan_zero_returns_empty() -> void:
	assert_eq(TableLayout.fan(0, Rect2(0, 0, 500, 200), Vector2(100, 140)).size(), 0)


func test_fan_one_is_centred() -> void:
	var area: Rect2 = Rect2(0, 0, 500, 200)
	var items: Array[Dictionary] = TableLayout.fan(1, area, Vector2(100, 140))
	assert_eq(items.size(), 1)
	var p: Vector2 = items[0]["position"]
	assert_almost_eq(p.x, 200.0, 0.01)


func test_fan_positions_increase_left_to_right() -> void:
	var items: Array[Dictionary] = TableLayout.fan(13, Rect2(10, 0, 700, 240), Vector2(150, 210))
	for i in range(1, items.size()):
		var a: Vector2 = items[i - 1]["position"]
		var b: Vector2 = items[i]["position"]
		assert_gt(b.x, a.x)


func test_fan_overlap_leaves_rightmost_card_fully_visible() -> void:
	var card_size: Vector2 = Vector2(150, 210)
	var items: Array[Dictionary] = TableLayout.fan(13, Rect2(10, 0, 700, 240), card_size)
	for i in range(1, items.size()):
		var a: Vector2 = items[i - 1]["position"]
		var b: Vector2 = items[i]["position"]
		assert_lt(b.x - a.x, card_size.x)
		assert_gt(b.x - a.x, 0.0)


func test_south_name_bar_is_centred_just_above_your_hand() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var bar: Rect2 = l["seat_rects"][TableState.Seat.SOUTH]
		var north: Rect2 = l["seat_rects"][TableState.Seat.NORTH]
		assert_almost_eq(bar.get_center().x, size.x / 2.0, 1.0, "centred at %s" % size)
		assert_lte(bar.end.y, (l["hand_rect"] as Rect2).position.y, "above the hand at %s" % size)
		assert_eq(bar.size, north.size, "same size as the partner's bar at %s" % size)


func test_played_cards_are_clear_of_opponent_fans() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		var card_size: Vector2 = l["play_card_size"]
		for seat in SEATS:
			var spot: Vector2 = l["play_spots"][seat]
			var card_rect: Rect2 = Rect2(spot - card_size / 2.0, card_size)
			for fan_seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
				assert_false(card_rect.intersects(l["opponent_fan_rects"][fan_seat]), "card %s vs fan %s at %s" % [seat, fan_seat, size])


func test_played_cards_are_not_bigger_than_hand_cards() -> void:
	for size in SIZES:
		var l: Dictionary = TableLayout.compute(size)
		assert_lte((l["play_card_size"] as Vector2).y, (l["card_size"] as Vector2).y + 0.01)
		assert_gt((l["play_card_size"] as Vector2).y, 20.0)
