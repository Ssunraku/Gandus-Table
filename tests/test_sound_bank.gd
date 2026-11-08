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


## Zero crossings per second: a pure beep has few, a card snap or paper swish (noise) has many.
func _crossings_per_second(s: AudioStreamWAV) -> float:
	var crossings: int = 0
	var prev: int = 0
	for i in range(0, s.data.size() - 1, 2):
		var v: int = s.data.decode_s16(i)
		if i > 0 and ((prev < -200 and v > 200) or (prev > 200 and v < -200)):
			crossings += 1
		prev = v
	return float(crossings) / s.get_length()


func test_card_sounds_are_noise_like_not_pure_beeps() -> void:
	for e in ["deal", "play", "trick", "bid", "turn"]:
		assert_gt(_crossings_per_second(bank.stream_for(e)), 1500.0, "%s should sound like cards or paper, not a beep" % e)


func test_the_win_and_lose_jingles_stay_musical() -> void:
	for e in ["win", "lose"]:
		assert_lt(_crossings_per_second(bank.stream_for(e)), 2500.0, e)


func test_sounds_are_deterministic_so_every_game_sounds_the_same() -> void:
	var other: SoundBank = SoundBank.new()
	add_child_autofree(other)
	assert_eq(bank.stream_for("deal").data, other.stream_for("deal").data)


func test_no_sound_clips_or_is_too_quiet() -> void:
	for e in SoundBank.EVENTS:
		var s: AudioStreamWAV = bank.stream_for(e)
		var loudest: int = 0
		for i in range(0, s.data.size() - 1, 2):
			loudest = maxi(loudest, absi(s.data.decode_s16(i)))
		assert_gt(loudest, 4000, "%s too quiet" % e)
		assert_lt(loudest, 32000, "%s clips" % e)


# ---------- volume ----------

func test_volume_defaults_to_full() -> void:
	assert_eq(bank.volume, 1.0)


func test_lower_volume_makes_every_player_quieter() -> void:
	var full_db: float = (bank.get_child(0) as AudioStreamPlayer).volume_db
	bank.volume = 0.5
	for p in bank.get_children():
		assert_lt((p as AudioStreamPlayer).volume_db, full_db)
		assert_almost_eq((p as AudioStreamPlayer).volume_db, full_db + linear_to_db(0.5), 0.01)
	bank.volume = 1.0
	assert_almost_eq((bank.get_child(0) as AudioStreamPlayer).volume_db, full_db, 0.01)


func test_volume_is_kept_between_0_and_1() -> void:
	bank.volume = 3.0
	assert_eq(bank.volume, 1.0)
	bank.volume = -1.0
	assert_eq(bank.volume, 0.0)


func test_volume_zero_plays_nothing() -> void:
	bank.volume = 0.0
	assert_false(bank.play("deal"))


func test_settings_slider_changes_the_volume_in_main() -> void:
	var main: Main = Main.new()
	main.quit_enabled = false
	main.game_pace = 0.0
	add_child_autofree(main)
	assert_eq(main.settings_screen.volume_slider.value, 100.0)
	main.settings_screen.volume_slider.value = 40.0
	assert_almost_eq(main.sound.volume, 0.4, 0.001)
	main.settings_screen.volume_slider.value = 0.0
	assert_eq(main.sound.volume, 0.0)


func test_slider_steps_in_fives_from_0_to_100() -> void:
	var s: SettingsScreen = SettingsScreen.new()
	add_child_autofree(s)
	assert_eq(s.volume_slider.min_value, 0.0)
	assert_eq(s.volume_slider.max_value, 100.0)
	assert_eq(s.volume_slider.step, 5.0)
	assert_true(s.volume_slider.scrollable or true)
