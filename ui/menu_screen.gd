class_name MenuScreen
extends Control
## Base for the menu screens: a felt background and a centred column for the content.

var _felt: GradientTexture2D
var column: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_felt = UiStyle.felt_texture()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)


func _draw() -> void:
	draw_texture_rect(_felt, Rect2(Vector2.ZERO, size), false)


## A styled button inside `parent` (default: the column).
func add_button(text: String, kind: String, min_width: float, parent: Control = null) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(b, kind)
	(parent if parent != null else column).add_child(b)
	return b


func light_label(text: String, font_size: int, gold: bool = false) -> Label:
	var l: Label = UiStyle.label(text, font_size, false)
	if gold:
		l.add_theme_color_override("font_color", GameSkin.get_current().color("accent"))
	column.add_child(l)
	return l
