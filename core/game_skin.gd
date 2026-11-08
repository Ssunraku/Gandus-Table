class_name GameSkin
extends RefCounted
## One "look" for the game, loaded from a folder such as res://skins/classic/.
## It supplies card pictures, a colour palette and an optional font.
## Anything missing falls back to the built-in look, so the game never breaks.
##
## Folder layout (all parts optional):
##   skin.cfg            [skin] name="..." and [colors] key="#rrggbb" overrides
##   cards/AS.png        one picture per card: rank letter/number + suit letter
##   cards/10H.png       (C=clubs D=diamonds H=hearts S=spades; J Q K A for faces)
##   cards/back.png      the card back
##   fonts/font.ttf      the font used for text on the table

const SKINS_DIR: String = "res://skins"
const ACTIVE_FILE: String = "res://skins/active.cfg"
const DEFAULT_SKIN: String = "classic"
const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg"]
const FONT_FILES: Array[String] = ["fonts/font.ttf", "fonts/font.otf"]
const DEFAULT_FONT_WEIGHT: int = 700

## Built-in colours (the hex value is in the comment). skin.cfg can override any.
const DEFAULT_COLORS: Dictionary = {
	"felt_center": Color(0.114, 0.435, 0.306),   # #1D6F4E
	"felt_edge": Color(0.039, 0.180, 0.133),     # #0A2E22
	"card_face": Color(0.984, 0.973, 0.945),     # #FBF8F1
	"card_border": Color(0.812, 0.784, 0.722),   # #CFC8B8
	"card_red": Color(0.784, 0.157, 0.227),      # #C8283A
	"card_black": Color(0.106, 0.125, 0.188),    # #1B2030
	"back_base": Color(0.106, 0.184, 0.420),     # #1B2F6B
	"back_pattern": Color(0.890, 0.757, 0.435),  # #E3C16F
	"back_frame": Color(0.984, 0.973, 0.945),    # #FBF8F1
	"bar_own": Color(0.812, 0.886, 0.980),       # #CFE2FA
	"bar_other": Color(0.980, 0.827, 0.812),     # #FAD3CF
	"bar_text": Color(0.106, 0.133, 0.251),      # #1B2240
	"accent": Color(0.949, 0.757, 0.306),        # #F2C14E
	"button_bg": Color(0.059, 0.165, 0.129, 0.85),  # #0F2A21
	"button_text": Color(0.957, 0.937, 0.890),   # #F4EFE3
	"score_bg": Color(0.969, 0.957, 0.925),      # #F7F4EC
	"score_us": Color(0.122, 0.310, 0.659),      # #1F4FA8
	"score_them": Color(0.784, 0.157, 0.227),    # #C8283A
	"score_label": Color(0.353, 0.373, 0.431),   # #5A5F6E
}

static var current: GameSkin = null

var skin_name: String = DEFAULT_SKIN
var folder: String = ""
var colors: Dictionary = {}
var font: Font = null

var _textures: Dictionary = {}  # relative path -> Texture2D or null (remembered)


## The skin the game is using now (loaded from skins/active.cfg on first use).
static func get_current() -> GameSkin:
	if current == null:
		current = load_active()
	return current


static func set_current(skin: GameSkin) -> void:
	current = skin


static func reset_current() -> void:
	current = null


static func load_active() -> GameSkin:
	var name: String = DEFAULT_SKIN
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(ACTIVE_FILE) == OK:
		name = str(cfg.get_value("skin", "name", DEFAULT_SKIN))
	return load_from_folder(SKINS_DIR.path_join(name))


## Never fails: a missing folder just gives the built-in look.
static func load_from_folder(path: String) -> GameSkin:
	var skin: GameSkin = GameSkin.new()
	skin.folder = path
	skin.skin_name = path.get_file()
	skin.colors = DEFAULT_COLORS.duplicate()
	var weight: int = DEFAULT_FONT_WEIGHT
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path.path_join("skin.cfg")) == OK:
		skin.skin_name = str(cfg.get_value("skin", "name", skin.skin_name))
		weight = int(cfg.get_value("font", "weight", DEFAULT_FONT_WEIGHT))
		if cfg.has_section("colors"):
			for key in cfg.get_section_keys("colors"):
				skin.colors[key] = Color(str(cfg.get_value("colors", key)))
	for rel in FONT_FILES:
		var base: FontFile = _load_font_file(path.path_join(rel))
		if base != null:
			# Variable fonts start at their thinnest weight, so pick one (400 normal, 700 bold).
			var variation: FontVariation = FontVariation.new()
			variation.base_font = base
			var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
			variation.variation_opentype = {tag: weight}
			skin.font = variation
			break
	return skin


## An exported (Android) game only contains fonts Godot has imported, so try the
## import system first; read the raw file only for a font not imported yet.
static func _load_font_file(font_path: String) -> FontFile:
	if ResourceLoader.exists(font_path):
		var res: Resource = load(font_path)
		if res is FontFile:
			return res
	if FileAccess.file_exists(font_path):
		var raw: FontFile = FontFile.new()
		if raw.load_dynamic_font(font_path) == OK:
			return raw
	return null


func color(key: String) -> Color:
	return colors.get(key, Color.MAGENTA)


func get_font() -> Font:
	return font if font != null else ThemeDB.fallback_font


func card_texture(card: Card) -> Texture2D:
	return _find_texture("cards/" + card.label())


func back_texture() -> Texture2D:
	return _find_texture("cards/back")


func _find_texture(rel: String) -> Texture2D:
	if _textures.has(rel):
		return _textures[rel]
	var tex: Texture2D = null
	for ext in IMAGE_EXTENSIONS:
		tex = _load_texture(folder.path_join("%s.%s" % [rel, ext]))
		if tex != null:
			break
	_textures[rel] = tex
	return tex


static func _load_texture(path: String) -> Texture2D:
	# Pictures Godot has already imported load normally; a freshly dropped-in
	# picture that has not been imported yet is read straight from the file.
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null
