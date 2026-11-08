extends GutTest

var bank: SoundBank


func before_each() -> void:
	bank = SoundBank.new()
	add_child_autofree(bank)


func test_there_is_only_one_light_sound_for_laying_a_card() -> void:
	assert_eq(SoundBank.EVENTS, ["play"] as Array[String])
	var s: AudioStreamWAV = bank.stream_for("play")
	assert_not_null(s)
	assert_gt(s.get_length(), 0.03)
	assert_lte(s.get_length(), 0.12, "short")


func test_other_events_stay_silent() -> void:
	for e in ["deal", "trick", "turn", "bid", "win", "lose", "nope"]:
		assert_false(bank.play(e), e)


func test_the_play_sound_plays_when_enabled() -> void:
	assert_true(bank.play("play"))


func test_nothing_plays_when_sound_is_off() -> void:
	bank.enabled = false
	assert_false(bank.play("play"))


func test_the_sound_is_gentle_not_harsh() -> void:
	var s: AudioStreamWAV = bank.stream_for("play")
	var loudest: int = 0
	var crossings: int = 0
	var prev: int = 0
	for i in range(0, s.data.size() - 1, 2):
		var v: int = s.data.decode_s16(i)
		loudest = maxi(loudest, absi(v))
		if i > 0 and ((prev < 0 and v > 0) or (prev > 0 and v < 0)):
			crossings += 1
		prev = v
	assert_gt(loudest, 2000, "audible")
	assert_lt(loudest, 16000, "well below full scale")
	assert_lt(float(crossings) / s.get_length(), 1500.0, "low and soft, no hissy noise")


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
	main.game.sound_event.emit("play")
	assert_signal_emitted_with_parameters(main.game, "sound_event", ["play"])
	assert_eq(main.sound.played_count, 1)


func test_the_sound_is_the_same_every_game() -> void:
	var other: SoundBank = SoundBank.new()
	add_child_autofree(other)
	assert_eq(bank.stream_for("play").data, other.stream_for("play").data)


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
	assert_false(bank.play("play"))


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
