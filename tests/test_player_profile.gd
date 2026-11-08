extends GutTest
## The player's saved name: cleaning, duplicates, saving, first-launch and Settings screens.

const TEMP_PATH: String = "user://test_profile.cfg"


func before_each() -> void:
	_delete_temp()


func after_each() -> void:
	_delete_temp()


func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _main() -> Main:
	var m: Main = Main.new()
	m.quit_enabled = false
	m.game_pace = 0.0
	m.profile_path = TEMP_PATH
	add_child_autofree(m)
	return m


# ---------- the name rules ----------

func test_clean_trims_spaces() -> void:
	assert_eq(PlayerProfile.clean("  Sam  "), "Sam")


func test_clean_limits_the_length_to_12() -> void:
	assert_eq(PlayerProfile.clean("Alexandria the Great").length(), 12)


func test_empty_or_blank_becomes_player() -> void:
	assert_eq(PlayerProfile.clean(""), "Player")
	assert_eq(PlayerProfile.clean("    "), "Player")


func test_clean_removes_line_breaks_and_control_characters() -> void:
	assert_eq(PlayerProfile.clean("Sa\nm\t"), "Sam")


func test_unique_leaves_a_free_name_alone() -> void:
	assert_eq(PlayerProfile.unique("Sam", ["Tin"] as Array[String]), "Sam")


func test_unique_numbers_a_duplicate() -> void:
	assert_eq(PlayerProfile.unique("Sam", ["Sam"] as Array[String]), "Sam 2")
	assert_eq(PlayerProfile.unique("sam", ["Sam", "Sam 2"] as Array[String]), "sam 3", "case does not matter")


func test_unique_names_still_fit_in_12_characters() -> void:
	var long_name: String = "ABCDEFGHIJKL"
	var r: String = PlayerProfile.unique(long_name, [long_name] as Array[String])
	assert_lte(r.length(), 12)
	assert_ne(r, long_name)


# ---------- saving ----------

func test_a_new_profile_has_no_name() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	assert_false(p.has_name())
	assert_false(p.load_from(TEMP_PATH), "no file yet")
	assert_false(p.has_name())


func test_the_name_survives_saving_and_loading() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.set_name("  Mira ")
	assert_true(p.save_to(TEMP_PATH))
	var q: PlayerProfile = PlayerProfile.new()
	assert_true(q.load_from(TEMP_PATH))
	assert_eq(q.player_name, "Mira")
	assert_true(q.has_name())


# ---------- the screens ----------

func test_name_screen_emits_the_cleaned_name() -> void:
	var s: NameScreen = NameScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.name_edit.text = "  Zed "
	s.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(s, "name_chosen", ["Zed"])


func test_name_screen_with_nothing_typed_gives_player() -> void:
	var s: NameScreen = NameScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(s, "name_chosen", ["Player"])


func test_first_launch_asks_for_a_name_then_saves_it() -> void:
	var m: Main = _main()
	assert_true(m.name_screen.visible)
	assert_false(m.start_screen.visible)
	m.name_screen.name_edit.text = "Rafi"
	m.name_screen.continue_button.pressed.emit()
	assert_true(m.start_screen.visible)
	assert_false(m.name_screen.visible)
	assert_eq(m.profile.player_name, "Rafi")
	var saved: PlayerProfile = PlayerProfile.new()
	saved.load_from(TEMP_PATH)
	assert_eq(saved.player_name, "Rafi")


func test_a_returning_player_goes_straight_to_the_start_screen() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.set_name("Rafi")
	p.save_to(TEMP_PATH)
	var m: Main = _main()
	assert_true(m.start_screen.visible)
	assert_false(m.name_screen.visible)
	assert_eq(m.settings_screen.name_edit.text, "Rafi")


func test_the_name_can_be_changed_in_settings_and_is_saved() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.set_name("Rafi")
	p.save_to(TEMP_PATH)
	var m: Main = _main()
	m.settings_screen.name_edit.text = "  Rafi K "
	m.settings_screen.name_edit.text_submitted.emit(m.settings_screen.name_edit.text)
	assert_eq(m.profile.player_name, "Rafi K")
	assert_eq(m.settings_screen.name_edit.text, "Rafi K", "the box shows the cleaned name")
	var saved: PlayerProfile = PlayerProfile.new()
	saved.load_from(TEMP_PATH)
	assert_eq(saved.player_name, "Rafi K")


func test_without_a_profile_path_the_app_does_not_ask_for_a_name() -> void:
	var m: Main = Main.new()
	m.quit_enabled = false
	add_child_autofree(m)
	assert_true(m.start_screen.visible)
