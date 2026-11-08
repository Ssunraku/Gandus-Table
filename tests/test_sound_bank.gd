extends GutTest

var bank: SoundBank


func before_each() -> void:
	bank = SoundBank.new()
	add_child_autofree(bank)


func test_every_event_has_a_short_non_empty_stream() -> void:
	for e in SoundBank.EVENTS:
		var s: AudioStreamWAV = bank.stream_for(e)
		assert_not_null(s, e)
		assert_gt(s.data.size(), 0, e)
		assert_lte(s.get_length(), 0.35, e)
		assert_gt(s.get_length(), 0.03, e)


func test_unknown_event_plays_nothing() -> void:
	assert_false(bank.play("nope"))


func test_known_event_plays_when_enabled() -> void:
	assert_true(bank.play("deal"))


func test_nothing_plays_when_sound_is_off() -> void:
	bank.enabled = false
	assert_false(bank.play("deal"))


func test_sounds_are_not_silent() -> void:
	var s: AudioStreamWAV = bank.stream_for("play")
	var loudest: int = 0
	for i in range(0, s.data.size() - 1, 2):
		var sample: int = s.data.decode_s16(i)
		loudest = maxi(loudest, absi(sample))
	assert_gt(loudest, 1000)


func test_main_wires_the_settings_switch_to_the_sound_bank() -> void:
	var main: Main = Main.new()
	main.quit_enabled = false
	main.game_pace = 0.0
	add_child_autofree(main)
	assert_true(main.sound.enabled)
	main.settings_screen.sound_button.button_pressed = false
	assert_false(main.sound.enabled)
	main.settings_screen.sound_button.button_pressed = true
	assert_true(main.sound.enabled)


func test_game_sound_events_reach_the_sound_bank() -> void:
	var main: Main = Main.new()
	main.quit_enabled = false
	main.game_pace = 0.0
	add_child_autofree(main)
	main.start_screen.host_button.pressed.emit()
	main.host_screen.start_button.pressed.emit()
	watch_signals(main.game)
	main.game.sound_event.emit("trick")
	assert_signal_emitted_with_parameters(main.game, "sound_event", ["trick"])
	assert_eq(main.sound.played_count, 1)
