extends GutTest
## The real app starts from ui/main.tscn. The Android export stores that scene in a packed
## form that KEEPS ONLY "saved" (@export) variables, so settings that are not saved vanish on
## the phone (this is exactly what went wrong in the first APK: no name prompt, tiny
## portrait screens, and a fake network). These tests pack the scene the same way.


func _packed_copy() -> Main:
	var original: Node = load("res://ui/main.tscn").instantiate()
	var packed: PackedScene = PackedScene.new()
	assert_eq(packed.pack(original), OK)
	original.free()
	return packed.instantiate() as Main


func test_the_app_scene_asks_for_the_real_network_after_packing() -> void:
	var m: Main = _packed_copy()
	assert_true(m.real_network, "real Wi-Fi must be on in the app")
	m.free()


func test_the_app_scene_saves_the_name_after_packing() -> void:
	var m: Main = _packed_copy()
	assert_eq(m.profile_path, "user://profile.cfg", "so the first launch can ask for a name")
	m.free()


func test_the_app_scene_switches_the_design_size_after_packing() -> void:
	var m: Main = _packed_copy()
	assert_true(m.adapt_scale, "portrait phones need the upright design size")
	m.free()


func test_a_plain_main_still_defaults_to_the_test_settings() -> void:
	var m: Main = Main.new()
	assert_false(m.real_network)
	assert_false(m.adapt_scale)
	assert_eq(m.profile_path, "")
	m.free()


func test_settings_shows_the_build_info_line() -> void:
	var m: Main = Main.new()
	add_child_autofree(m)
	var text: String = m.settings_screen.build_label.text
	assert_string_contains(text, "Version %s" % Main.VERSION)
	assert_string_contains(text, "Wi-Fi: test only")
	assert_string_contains(text, "name saved: no")


# ---------- buttons: all gold, darker when pressed ----------

func _normal_colour(b: Button) -> Color:
	return (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color


func test_every_button_kind_is_the_host_game_gold() -> void:
	var gold: Color = GameSkin.get_current().color("accent")
	for kind in ["dark", "primary", "paper_outline", "number"]:
		var b: Button = Button.new()
		UiStyle.style_button(b, kind)
		assert_eq(_normal_colour(b), gold, kind)
		b.free()


func test_a_pressed_button_is_a_darker_gold() -> void:
	var b: Button = Button.new()
	UiStyle.style_button(b, "primary")
	var normal: Color = _normal_colour(b)
	var pressed: Color = (b.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color
	assert_lt(pressed.get_luminance(), normal.get_luminance())
	b.free()


func test_menu_and_info_buttons_are_gold() -> void:
	var t: Table = Table.new()
	add_child_autofree(t)
	var gold: Color = GameSkin.get_current().color("accent")
	assert_eq(_normal_colour(t.menu_button), gold)
	assert_eq(_normal_colour(t.info_button), gold)


func test_an_off_switch_is_still_different_from_an_on_switch() -> void:
	var on: Button = Button.new()
	var off: Button = Button.new()
	UiStyle.style_button(on, "primary")
	UiStyle.style_button(off, "off")
	assert_ne(_normal_colour(on), _normal_colour(off))
	on.free()
	off.free()
