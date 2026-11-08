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


func test_lobby_shows_seats_names_and_the_hosts_options_read_only() -> void:
	var l: LobbyScreen = LobbyScreen.new()
	add_child_autofree(l)
	var settings: SpadesSettings = SpadesSettings.new()
	settings.exact_mode = SpadesSettings.ExactMode.HARD
	settings.win_score = 300
	var lobby: Dictionary = _lobby(1, ["human", "human", "bot", "empty"])
	lobby["settings"] = Wire.settings_to_dict(settings)
	l.show_lobby(lobby, false, "", [] as Array[String])
	assert_string_contains(l.seat_buttons[0].text, "P0")
	assert_string_contains(l.seat_buttons[1].text, "(you)")
	assert_string_contains(l.seat_buttons[2].text, "bot")
	assert_string_contains(l.seat_buttons[3].text, "free")
	assert_string_contains(l.options_label.text, "Exact bids: Hard")
	assert_string_contains(l.options_label.text, "Win at 300")
	assert_false(l.options_label.text.contains("Bags penalty"), "no bags under Exact bids")
	var plain: Array[String] = LobbyScreen.option_lines(SpadesSettings.new())
	assert_true("\n".join(plain).contains("Bags penalty: on"))


func test_tapping_a_free_seat_emits_seat_chosen_but_a_taken_seat_does_not() -> void:
	var l: LobbyScreen = LobbyScreen.new()
	add_child_autofree(l)
	l.show_lobby(_lobby(0, ["human", "empty", "bot", "empty"]), false, "", [] as Array[String])
	watch_signals(l)
	l.seat_buttons[0].pressed.emit()
	l.seat_buttons[2].pressed.emit()
	assert_signal_not_emitted(l, "seat_chosen")
	l.seat_buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(l, "seat_chosen", [1])


func test_only_the_host_sees_bots_and_start_and_start_waits_for_full_seats() -> void:
	var l: LobbyScreen = LobbyScreen.new()
	add_child_autofree(l)
	l.show_lobby(_lobby(1), false, "", [] as Array[String])
	assert_false(l.bots_button.visible)
	assert_false(l.start_button.visible)
	assert_string_contains(l.info_label.text, "Waiting for the host")
	l.show_lobby(_lobby(0), true, "ABCD", ["192.168.1.5"] as Array[String])
	assert_true(l.bots_button.visible)
	assert_true(l.start_button.visible)
	assert_true(l.start_button.disabled, "seats are still free")
	assert_string_contains(l.code_label.text, "ABCD")
	assert_string_contains(l.info_label.text, "192.168.1.5")
	l.show_lobby(_lobby(0, ["human", "human", "bot", "bot"]), true, "ABCD", [] as Array[String])
	assert_false(l.start_button.disabled)
	watch_signals(l)
	l.bots_button.pressed.emit()
	l.start_button.pressed.emit()
	l.leave_button.pressed.emit()
	assert_signal_emitted(l, "add_bots_pressed")
	assert_signal_emitted(l, "start_pressed")
	assert_signal_emitted(l, "leave_pressed")


func _inside(c: Control, screen: Vector2) -> bool:
	var r: Rect2 = c.get_global_rect()
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= screen.x + 0.5 and r.end.y <= screen.y + 0.5


func test_lobby_and_join_fit_a_portrait_phone() -> void:
	var screen: Vector2 = Vector2(360, 780)
	var holder: Control = Control.new()
	holder.size = screen
	add_child_autofree(holder)
	var l: LobbyScreen = LobbyScreen.new()
	holder.add_child(l)
	l.show_lobby(_lobby(0, ["human", "empty", "empty", "empty"]), true, "ABCD", ["192.168.100.200"] as Array[String])
	await get_tree().process_frame
	await get_tree().process_frame
	for b in l.seat_buttons:
		assert_true(_inside(b, screen), "seat button inside the screen")
	assert_true(_inside(l.start_button, screen))
	assert_true(_inside(l.leave_button, screen))
	var j: JoinScreen = JoinScreen.new()
	holder.add_child(j)
	j.visible = true
	l.visible = false
	var games: Array[Dictionary] = [{"code": "ABCD", "name": "Samanthaaaaa", "address": "192.168.1.5", "port": 24680, "free_seats": 2, "exact": 0}]
	j.show_games(games)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_inside(j.join_code_button, screen))
	assert_true(_inside(j.join_address_button, screen))
	assert_true(_inside(j.back_button, screen))
	assert_true(_inside(j.row_button(0), screen))
