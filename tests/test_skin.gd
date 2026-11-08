extends GutTest

const DIR: String = "user://skin_test"


func before_each() -> void:
	_remove_dir(DIR)


func after_each() -> void:
	_remove_dir(DIR)
	GameSkin.reset_current()


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(d))
	DirAccess.remove_absolute(path)


func _write_png(rel: String) -> void:
	var full: String = DIR.path_join(rel)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var img: Image = Image.create(20, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(full)


func test_missing_folder_gives_default_colors_and_no_textures() -> void:
	var s: GameSkin = GameSkin.load_from_folder("user://does_not_exist")
	assert_null(s.card_texture(Card.make(Card.Suit.SPADES, Card.Rank.ACE)))
	assert_null(s.back_texture())
	assert_eq(s.color("card_red"), GameSkin.DEFAULT_COLORS["card_red"])


func test_card_texture_found_by_card_label() -> void:
	_write_png("cards/AS.png")
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	var tex: Texture2D = s.card_texture(Card.make(Card.Suit.SPADES, Card.Rank.ACE))
	assert_not_null(tex)
	assert_eq(tex.get_width(), 20)


func test_ten_uses_two_digit_label() -> void:
	_write_png("cards/10H.png")
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	assert_not_null(s.card_texture(Card.make(Card.Suit.HEARTS, Card.Rank.TEN)))


func test_cards_without_an_image_return_null() -> void:
	_write_png("cards/AS.png")
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	assert_null(s.card_texture(Card.make(Card.Suit.CLUBS, Card.Rank.TWO)))


func test_back_texture_found() -> void:
	_write_png("cards/back.png")
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	assert_not_null(s.back_texture())


func test_colors_can_be_overridden_in_skin_cfg() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("colors", "card_red", "#00ff00")
	cfg.save(DIR.path_join("skin.cfg"))
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	assert_eq(s.color("card_red"), Color("#00ff00"))
	assert_eq(s.color("card_black"), GameSkin.DEFAULT_COLORS["card_black"])


func test_unknown_color_key_is_obvious_magenta() -> void:
	var s: GameSkin = GameSkin.load_from_folder("user://does_not_exist")
	assert_eq(s.color("no_such_color"), Color.MAGENTA)


func test_font_falls_back_to_default_without_a_font_file() -> void:
	var s: GameSkin = GameSkin.load_from_folder("user://does_not_exist")
	assert_eq(s.get_font(), ThemeDB.fallback_font)


func test_current_skin_can_be_set_and_reset() -> void:
	var s: GameSkin = GameSkin.load_from_folder(DIR)
	GameSkin.set_current(s)
	assert_eq(GameSkin.get_current(), s)
	GameSkin.reset_current()
	assert_ne(GameSkin.get_current(), s)
	assert_not_null(GameSkin.get_current())


func test_shipped_classic_skin_loads() -> void:
	var s: GameSkin = GameSkin.load_from_folder("res://skins/classic")
	assert_eq(s.skin_name, "Classic")
	assert_ne(s.color("felt_center"), Color.MAGENTA)


func test_shipped_classic_skin_has_its_own_font() -> void:
	var s: GameSkin = GameSkin.load_from_folder("res://skins/classic")
	assert_not_null(s.font)
	assert_ne(s.get_font(), ThemeDB.fallback_font)
	assert_gt(s.get_font().get_string_size("Cherry", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 10.0)


func test_font_is_loaded_through_the_import_system_so_exports_keep_it() -> void:
	# A font made from the raw .ttf has no resource path and would be missing
	# from an exported (Android) build, which only contains imported data.
	var s: GameSkin = GameSkin.load_from_folder("res://skins/classic")
	var variation: FontVariation = s.font as FontVariation
	assert_not_null(variation)
	assert_eq(variation.base_font.resource_path, "res://skins/classic/fonts/font.ttf")


func test_classic_font_is_set_to_a_bolder_weight_than_the_thin_default() -> void:
	var s: GameSkin = GameSkin.load_from_folder("res://skins/classic")
	var variation: FontVariation = s.font as FontVariation
	assert_not_null(variation)
	var text: String = "Cherry Partner"
	var thin: float = variation.base_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var bold: float = variation.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	assert_gt(bold, thin)


func test_card_view_uses_image_when_the_skin_has_one() -> void:
	_write_png("cards/AS.png")
	GameSkin.set_current(GameSkin.load_from_folder(DIR))
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(Card.make(Card.Suit.SPADES, Card.Rank.ACE), true, Vector2(100, 140))
	assert_true(v.is_drawn_from_image())


func test_card_view_draws_by_code_when_image_missing() -> void:
	GameSkin.set_current(GameSkin.load_from_folder("user://does_not_exist"))
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(Card.make(Card.Suit.SPADES, Card.Rank.ACE), true, Vector2(100, 140))
	assert_false(v.is_drawn_from_image())


func test_card_back_uses_image_when_the_skin_has_one() -> void:
	_write_png("cards/back.png")
	GameSkin.set_current(GameSkin.load_from_folder(DIR))
	var v: CardView = CardView.new()
	add_child_autofree(v)
	v.setup(null, false, Vector2(100, 140))
	assert_true(v.is_drawn_from_image())
