extends GutTest

var main: Main


func before_each() -> void:
	main = Main.new()
	main.quit_enabled = false
	main.game_pace = 0.0
	add_child_autofree(main)


func _go_to_host() -> void:
	main.start_screen.host_button.pressed.emit()


# ---------- host options ----------

func test_default_host_options_equal_the_default_settings() -> void:
	var s: SpadesSettings = main.host_screen.settings()
	var d: SpadesSettings = SpadesSettings.new()
	assert_eq(s.blind_nil_enabled, d.blind_nil_enabled)
	assert_eq(s.nil_enabled, d.nil_enabled)
	assert_eq(s.redeal_enabled, d.redeal_enabled)
	assert_eq(s.bags_penalty_enabled, d.bags_penalty_enabled)
	assert_eq(s.play_higher_enabled, d.play_higher_enabled)
	assert_eq(s.win_score, d.win_score)
	assert_eq(s.lose_score, d.lose_score)


func test_toggling_and_stepping_changes_the_settings() -> void:
	main.host_screen.toggle("blind_nil").button_pressed = false
	main.host_screen.toggle("play_higher").button_pressed = true
	main.host_screen.step_win(1)
	var s: SpadesSettings = main.host_screen.settings()
	assert_false(s.blind_nil_enabled)
	assert_true(s.play_higher_enabled)
	assert_eq(s.win_score, 550)


func test_steppers_stay_inside_their_bounds() -> void:
	main.host_screen.step_win(100)
	assert_eq(main.host_screen.settings().win_score, 1000)
	main.host_screen.step_win(-100)
	assert_eq(main.host_screen.settings().win_score, 100)
	main.host_screen.step_lose(100)
	assert_eq(main.host_screen.settings().lose_score, -50)
	main.host_screen.step_lose(-100)
	assert_eq(main.host_screen.settings().lose_score, -1000)


# ---------- navigation ----------

func test_start_screen_has_a_disabled_join_button() -> void:
	assert_true(main.start_screen.join_button.disabled)
	assert_true(main.start_screen.visible)
	assert_false(main.host_screen.visible)


func test_host_game_then_start_game_shows_a_started_game_with_those_settings() -> void:
	_go_to_host()
	assert_true(main.host_screen.visible)
	assert_false(main.start_screen.visible)
	main.host_screen.toggle("blind_nil").button_pressed = false
	main.host_screen.start_button.pressed.emit()
	assert_not_null(main.game)
	assert_true(main.game.visible)
	assert_false(main.host_screen.visible)
	assert_false(main.game.settings.blind_nil_enabled)
	assert_not_null(main.game.session)


func test_settings_screen_opens_and_goes_back() -> void:
	main.start_screen.settings_button.pressed.emit()
	assert_true(main.settings_screen.visible)
	main.settings_screen.back_button.pressed.emit()
	assert_true(main.start_screen.visible)
	assert_false(main.settings_screen.visible)


func test_back_from_host_options_returns_to_the_start_screen() -> void:
	_go_to_host()
	main.host_screen.back_button.pressed.emit()
	assert_true(main.start_screen.visible)


func test_exit_button_asks_to_quit() -> void:
	watch_signals(main)
	main.start_screen.exit_button.pressed.emit()
	assert_signal_emitted(main, "quit_requested")


func test_leaving_a_game_and_hosting_again_gives_a_brand_new_game() -> void:
	_go_to_host()
	main.host_screen.start_button.pressed.emit()
	var old: GameScreen = main.game
	var old_session: SpadesSession = old.session
	old.table.menu_button.pressed.emit()
	for b in old.menu_panel.find_children("*", "Button", true, false):
		if (b as Button).text == "Exit to start":
			(b as Button).pressed.emit()
	assert_true(main.start_screen.visible)
	await wait_frames(3)
	assert_false(is_instance_valid(old), "the old game screen should be gone")
	_go_to_host()
	main.host_screen.start_button.pressed.emit()
	assert_not_null(main.game)
	assert_ne(main.game.session, old_session)


# ---------- winner screen ----------

func test_winner_screen_names_the_winning_side() -> void:
	_go_to_host()
	main.host_screen.start_button.pressed.emit()
	main.game.game_finished.emit(0, [520, 340] as Array[int])
	assert_true(main.winner_screen.visible)
	assert_string_contains(main.winner_screen.title_label.text, "You and Partner win")
	main.winner_screen.exit_button.pressed.emit()
	assert_true(main.start_screen.visible)
	_go_to_host()
	main.host_screen.start_button.pressed.emit()
	main.game.game_finished.emit(1, [300, 510] as Array[int])
	assert_string_contains(main.winner_screen.title_label.text, "Tin and Cherry win")


func test_play_again_starts_a_new_game_with_the_same_settings() -> void:
	_go_to_host()
	main.host_screen.toggle("nil").button_pressed = false
	main.host_screen.start_button.pressed.emit()
	var first_session: SpadesSession = main.game.session
	main.game.game_finished.emit(0, [520, 340] as Array[int])
	main.winner_screen.play_again_button.pressed.emit()
	assert_true(main.game.visible)
	assert_false(main.winner_screen.visible)
	assert_false(main.game.settings.nil_enabled)
	assert_ne(main.game.session, first_session)


# ---------- real window size ----------

func test_the_game_screen_fills_the_whole_window() -> void:
	var holder: Control = Control.new()
	holder.size = Vector2(1280, 720)
	add_child_autofree(holder)
	var m: Main = Main.new()
	m.quit_enabled = false
	m.game_pace = 0.0
	holder.add_child(m)
	m.start_screen.host_button.pressed.emit()
	m.host_screen.start_button.pressed.emit()
	await wait_frames(2)
	assert_eq(m.size, Vector2(1280, 720), "Main")
	assert_eq(m.game.size, Vector2(1280, 720), "GameScreen")
	assert_eq(m.game.table.size, Vector2(1280, 720), "Table")
	assert_eq(m.start_screen.size, Vector2(1280, 720), "StartScreen")
