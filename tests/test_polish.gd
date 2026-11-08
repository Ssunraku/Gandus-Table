extends GutTest


func test_2d_anti_aliasing_is_turned_on() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d"), 2)


func test_heart_outline_is_smooth_and_sized() -> void:
	var pts: PackedVector2Array = CardView.heart_points(100.0)
	assert_gte(pts.size(), 40)
	for p in pts:
		assert_lte(absf(p.x), 110.0)
		assert_lte(absf(p.y), 110.0)


func test_table_seat_bars_use_skin_colours() -> void:
	GameSkin.reset_current()
	var table: Table = Table.new()
	table.auto_start = false
	add_child_autofree(table)
	var current: GameSkin = GameSkin.get_current()
	assert_eq(table.seat_views[TableState.Seat.SOUTH].bar_color, current.color("bar_own"))
	assert_eq(table.seat_views[TableState.Seat.NORTH].bar_color, current.color("bar_own"))
	assert_eq(table.seat_views[TableState.Seat.WEST].bar_color, current.color("bar_other"))
	assert_eq(table.seat_views[TableState.Seat.EAST].bar_color, current.color("bar_other"))
