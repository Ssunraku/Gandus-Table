extends GutTest
## The table you see before a game starts: four seats with avatars and name bars.

func _lobby(you: int = -1, kinds: Array = ["human", "empty", "empty", "empty"], countdown: int = 0) -> Dictionary:
	var seats: Array = []
	for i in range(4):
		var kind: String = kinds[i]
		seats.append({"kind": kind, "name": "P%d" % i if kind != "empty" else ""})
	return {
		"seats": seats, "you": you, "is_host": false,
		"settings": Wire.settings_to_dict(SpadesSettings.new()),
		"countdown": countdown, "room_code": "KFDM", "addresses": [],
	}


func _screen() -> PreGameScreen:
	var p: PreGameScreen = PreGameScreen.new()
	add_child_autofree(p)
	return p


func test_the_bars_show_names_and_tap_prompts() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(1, ["human", "human", "bot", "empty"]), false)
	assert_eq(p.name_labels[0].text, "P0")
	assert_eq(p.name_labels[1].text, "P1")
	assert_eq(p.name_labels[2].text, "P2")
	assert_eq(p.name_labels[3].text, "Tap to sit")
	p.show_state(_lobby(0, ["human", "empty", "empty", "empty"]), true)
	assert_eq(p.name_labels[1].text, "Tap to add a bot")


func test_avatars_show_what_sits_in_each_seat() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(0, ["human", "bot", "empty", "human"]), true)
	assert_eq(p.avatars[0].kind, "human")
	assert_eq(p.avatars[1].kind, "bot")
	assert_eq(p.avatars[2].kind, "empty")
	assert_true(p.avatars[0].is_host, "the host has the star")
	assert_false(p.avatars[3].is_host)


func test_the_host_taps_a_free_seat_to_add_a_bot_and_a_bot_to_remove_it() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(0, ["human", "bot", "empty", "human"]), true)
	watch_signals(p)
	p.seat_buttons[0].pressed.emit()
	p.seat_buttons[3].pressed.emit()
	assert_signal_not_emitted(p, "bot_add_chosen")
	assert_signal_not_emitted(p, "bot_remove_chosen")
	p.seat_buttons[2].pressed.emit()
	assert_signal_emitted_with_parameters(p, "bot_add_chosen", [2])
	p.seat_buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(p, "bot_remove_chosen", [1])
	assert_signal_not_emitted(p, "seat_chosen", "the host never moves seats")


func test_a_new_player_taps_a_seat_then_presses_join_table() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(-1, ["human", "bot", "empty", "empty"]), false)
	assert_true(p.join_button.visible)
	assert_true(p.join_button.disabled, "pick a seat first")
	watch_signals(p)
	p.seat_buttons[0].pressed.emit()
	p.seat_buttons[1].pressed.emit()
	assert_true(p.join_button.disabled, "taken seats cannot be picked")
	p.seat_buttons[3].pressed.emit()
	assert_signal_not_emitted(p, "seat_chosen", "tapping only picks")
	assert_false(p.join_button.disabled)
	assert_true(p.avatars[3].selected)
	p.join_button.pressed.emit()
	assert_signal_emitted_with_parameters(p, "seat_chosen", [3])


func test_a_picked_seat_that_gets_taken_is_forgotten() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(-1, ["human", "empty", "empty", "empty"]), false)
	p.seat_buttons[2].pressed.emit()
	p.show_state(_lobby(-1, ["human", "empty", "human", "empty"]), false)
	assert_true(p.join_button.disabled)
	assert_false(p.avatars[2].selected)


func test_a_seated_player_moves_by_tapping_another_free_seat() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(1, ["human", "human", "empty", "empty"]), false)
	assert_false(p.join_button.visible, "already at the table")
	watch_signals(p)
	p.seat_buttons[1].pressed.emit()
	p.seat_buttons[0].pressed.emit()
	assert_signal_not_emitted(p, "seat_chosen")
	p.seat_buttons[3].pressed.emit()
	assert_signal_emitted_with_parameters(p, "seat_chosen", [3])


func test_the_table_turns_so_you_are_at_the_bottom_with_your_partner_opposite() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(2, ["human", "human", "human", "human"]), false)
	await get_tree().process_frame
	var mine: float = p.seat_buttons[2].get_global_rect().position.y
	var partner: float = p.seat_buttons[0].get_global_rect().position.y
	var left_y: float = p.seat_buttons[3].get_global_rect().position.x
	var right_x: float = p.seat_buttons[1].get_global_rect().position.x
	assert_gt(mine, partner, "you are below your partner")
	assert_lt(left_y, right_x, "the seat after you (clockwise) is on your left")


func test_before_sitting_the_table_is_shown_from_the_hosts_side() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(-1, ["human", "empty", "empty", "empty"]), false)
	await get_tree().process_frame
	var host_y: float = p.seat_buttons[0].get_global_rect().position.y
	var opposite_y: float = p.seat_buttons[2].get_global_rect().position.y
	assert_gt(host_y, opposite_y)


func test_your_team_is_one_colour_and_the_opponents_the_other() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(1, ["human", "human", "human", "human"]), false)
	var skin: GameSkin = GameSkin.get_current()
	assert_eq(p.bar_color_of(1), skin.color("bar_own"))
	assert_eq(p.bar_color_of(3), skin.color("bar_own"))
	assert_eq(p.bar_color_of(0), skin.color("bar_other"))
	assert_eq(p.bar_color_of(2), skin.color("bar_other"))


func test_the_title_the_room_code_and_the_countdown() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(-1, ["human", "empty", "empty", "empty"]), false)
	assert_eq(p.title_label.text, "Join P0's game")
	assert_false(p.code_label.visible)
	p.show_state(_lobby(0, ["human", "empty", "empty", "empty"]), true)
	assert_eq(p.title_label.text, "Waiting for players")
	assert_true(p.code_label.visible)
	assert_string_contains(p.code_label.text, "KFDM")
	assert_string_contains(p.centre_label.text, "Waiting")
	var full: Dictionary = _lobby(0, ["human", "bot", "bot", "bot"], 3)
	p.show_state(full, true)
	assert_string_contains(p.centre_label.text, "3")
	assert_string_contains(p.centre_label.text, "Starting")
	assert_eq(p.title_label.text, "Starting...")


func test_the_hosts_rules_are_shown_read_only() -> void:
	var p: PreGameScreen = _screen()
	var settings: SpadesSettings = SpadesSettings.new()
	settings.exact_mode = SpadesSettings.ExactMode.HARD
	settings.win_score = 300
	var lobby: Dictionary = _lobby(1, ["human", "human", "empty", "empty"])
	lobby["settings"] = Wire.settings_to_dict(settings)
	p.show_state(lobby, false)
	assert_string_contains(p.options_label.text, "Exact bids: Hard")
	assert_string_contains(p.options_label.text, "Win at 300")
	assert_false(p.options_label.text.contains("Bags penalty"), "no bags under Exact bids")
	var plain: Array[String] = PreGameScreen.option_lines(SpadesSettings.new())
	assert_true("\n".join(plain).contains("Bags penalty: on"))


func test_leave_and_notice() -> void:
	var p: PreGameScreen = _screen()
	p.show_state(_lobby(1), false)
	watch_signals(p)
	p.leave_button.pressed.emit()
	assert_signal_emitted(p, "leave_pressed")
	p.set_notice("That seat was just taken.")
	assert_eq(p.notice_label.text, "That seat was just taken.")


func _inside(c: Control, screen: Vector2) -> bool:
	var r: Rect2 = c.get_global_rect()
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= screen.x + 0.5 and r.end.y <= screen.y + 0.5


func test_it_fits_a_portrait_phone_and_a_landscape_screen() -> void:
	for screen in [Vector2(360, 780), Vector2(1280, 720)]:
		var holder: Control = Control.new()
		holder.size = screen
		add_child_autofree(holder)
		var p: PreGameScreen = PreGameScreen.new()
		holder.add_child(p)
		var lobby: Dictionary = _lobby(-1, ["human", "empty", "empty", "empty"])
		lobby["addresses"] = ["192.168.100.200"]
		p.show_state(lobby, false)
		await get_tree().process_frame
		await get_tree().process_frame
		for b in p.seat_buttons:
			assert_true(_inside(b, screen), "seat inside %s" % str(screen))
		assert_true(_inside(p.join_button, screen), "join button inside %s" % str(screen))
		assert_true(_inside(p.leave_button, screen), "leave button inside %s" % str(screen))
		p.show_state(_lobby(0, ["human", "empty", "empty", "empty"]), true)
		await get_tree().process_frame
		assert_true(_inside(p.code_label, screen), "code inside %s" % str(screen))
		assert_true(_inside(p.leave_button, screen), "leave (host) inside %s" % str(screen))


func test_it_can_be_drawn_bigger_for_an_upright_phone() -> void:
	var screen: Vector2 = Vector2(720, 1280)
	var holder: Control = Control.new()
	holder.size = screen
	add_child_autofree(holder)
	var p: PreGameScreen = PreGameScreen.new()
	holder.add_child(p)
	var normal_width: float = p.table_panel.custom_minimum_size.x
	p.set_ui_scale(1.4)
	p.show_state(_lobby(-1, ["human", "empty", "empty", "empty"]), false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(p.table_panel.custom_minimum_size.x, normal_width * 1.4, 0.5)
	for b in p.seat_buttons:
		assert_true(_inside(b, screen), "seat inside")
	assert_gt(p.seat_buttons[0].size.x, PreGameScreen.SLOT_SIZE.x * 1.3, "the seats grew too")
	assert_true(_inside(p.join_button, screen))
	assert_true(_inside(p.leave_button, screen))
