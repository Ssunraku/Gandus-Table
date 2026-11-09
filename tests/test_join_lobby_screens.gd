extends GutTest


func _lobby(you: int = -1, kinds: Array = ["human", "empty", "empty", "empty"]) -> Dictionary:
	var seats: Array = []
	for i in range(4):
		seats.append({"kind": kinds[i], "name": "P%d" % i if kinds[i] != "empty" else ""})
	return {"seats": seats, "settings": Wire.settings_to_dict(SpadesSettings.new()), "you": you}


func test_start_screen_join_button_is_enabled_and_emits() -> void:
	var s: StartScreen = StartScreen.new()
	add_child_autofree(s)
	assert_false(s.join_button.disabled)
	watch_signals(s)
	s.join_button.pressed.emit()
	assert_signal_emitted(s, "join_pressed")


func test_join_screen_lists_games_and_tapping_a_row_joins() -> void:
	var j: JoinScreen = JoinScreen.new()
	add_child_autofree(j)
	var games: Array[Dictionary] = [
		{"code": "ABCD", "name": "Sam", "address": "192.168.1.5", "port": 24680, "free_seats": 2, "exact": 0},
		{"code": "WXYZ", "name": "Mia", "address": "192.168.1.9", "port": 24680, "free_seats": 1, "exact": 0},
	]
	j.show_games(games)
	assert_eq(j.row_count(), 2)
	assert_string_contains(j.row_button(0).text, "Sam")
	assert_string_contains(j.row_button(0).text, "ABCD")
	watch_signals(j)
	j.row_button(1).pressed.emit()
	assert_signal_emitted_with_parameters(j, "join_chosen", ["192.168.1.9", 24680])
	j.show_games([] as Array[Dictionary])
	assert_eq(j.row_count(), 0)


func test_join_by_code_normalises_and_rejects_bad_codes() -> void:
	var j: JoinScreen = JoinScreen.new()
	add_child_autofree(j)
	watch_signals(j)
	j.code_edit.text = " abcd "
	j.join_code_button.pressed.emit()
	assert_signal_emitted_with_parameters(j, "code_chosen", ["ABCD"])
	j.code_edit.text = "AB1"
	j.join_code_button.pressed.emit()
	assert_signal_emit_count(j, "code_chosen", 1)
	assert_string_contains(j.status_label.text, "4 letters")


func test_join_by_address_accepts_ip_and_ip_port_only() -> void:
	var j: JoinScreen = JoinScreen.new()
	add_child_autofree(j)
	watch_signals(j)
	j.address_edit.text = "192.168.1.5"
	j.join_address_button.pressed.emit()
	assert_signal_emitted_with_parameters(j, "join_chosen", ["192.168.1.5", 24680])
	j.address_edit.text = "192.168.1.5:24999"
	j.join_address_button.pressed.emit()
	assert_signal_emitted_with_parameters(j, "join_chosen", ["192.168.1.5", 24999])
	for bad in ["hello", "1.2.3", "1.2.3.4:99999", "", "1.2.3.4:", "256.1.1.1", "1.2.3.4.5", "a.b.c.d", "1.2.3.4:x"]:
		assert_true(JoinScreen.parse_address(bad).is_empty(), bad)
	assert_signal_emit_count(j, "join_chosen", 2)


func _inside(c: Control, screen: Vector2) -> bool:
	var r: Rect2 = c.get_global_rect()
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= screen.x + 0.5 and r.end.y <= screen.y + 0.5


func test_the_join_screen_fits_a_portrait_phone() -> void:
	var screen: Vector2 = Vector2(360, 780)
	var holder: Control = Control.new()
	holder.size = screen
	add_child_autofree(holder)
	var j: JoinScreen = JoinScreen.new()
	holder.add_child(j)
	j.visible = true
	var games: Array[Dictionary] = [{"code": "ABCD", "name": "Samanthaaaaa", "address": "192.168.1.5", "port": 24680, "free_seats": 2, "exact": 0}]
	j.show_games(games)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_inside(j.join_code_button, screen))
	assert_true(_inside(j.join_address_button, screen))
	assert_true(_inside(j.back_button, screen))
	assert_true(_inside(j.row_button(0), screen))
