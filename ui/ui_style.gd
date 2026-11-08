class_name UiStyle
extends RefCounted
## Shared look for buttons, panels and labels so every screen matches the skin.


## kind: "dark" (default pill), "primary" (gold), "paper_outline" (for cream panels),
## "number" (round bid button).
static func style_button(b: Button, kind: String = "dark") -> void:
	var skin: GameSkin = GameSkin.get_current()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	var text_colour: Color = skin.color("button_text")
	var pressed_text: Color = skin.color("accent")
	bg.set_corner_radius_all(20)
	bg.anti_aliasing = true
	match kind:
		"primary":
			bg.bg_color = skin.color("accent")
			text_colour = skin.color("bar_text")
			pressed_text = skin.color("bar_text")
		"paper_outline":
			bg.bg_color = Color(0, 0, 0, 0)
			bg.border_color = skin.color("bar_text")
			bg.border_color.a = 0.6
			bg.set_border_width_all(2)
			text_colour = skin.color("bar_text")
			pressed_text = skin.color("bar_text")
		"number":
			bg.bg_color = Color(0.90, 0.88, 0.82)
			bg.set_corner_radius_all(100)
			text_colour = skin.color("bar_text")
			pressed_text = skin.color("bar_text")
		_:
			bg.bg_color = skin.color("button_bg")
			bg.border_color = skin.color("accent")
			bg.border_color.a = 0.55
			bg.set_border_width_all(2)
	var hover: StyleBoxFlat = bg.duplicate()
	hover.bg_color = bg.bg_color.lightened(0.15) if bg.bg_color.a > 0.0 else Color(0, 0, 0, 0.06)
	var pressed: StyleBoxFlat = bg.duplicate()
	pressed.bg_color = bg.bg_color.darkened(0.2) if bg.bg_color.a > 0.0 else Color(0, 0, 0, 0.12)
	var off: StyleBoxFlat = bg.duplicate()
	off.bg_color = Color(bg.bg_color.r, bg.bg_color.g, bg.bg_color.b, bg.bg_color.a * 0.45)
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", text_colour)
	b.add_theme_color_override("font_hover_color", text_colour)
	b.add_theme_color_override("font_pressed_color", pressed_text)
	var dim: Color = text_colour
	dim.a = 0.5
	b.add_theme_color_override("font_disabled_color", dim)
	b.add_theme_font_override("font", skin.get_font())


## The cream rounded panel used by the bid, swap, summary and info boxes.
static func panel_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GameSkin.get_current().color("score_bg")
	box.set_corner_radius_all(24)
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 22.0
	box.content_margin_bottom = 22.0
	box.anti_aliasing = true
	return box


## A label in the skin font. `ink` true = dark text for cream panels.
static func label(text: String, font_size: int, bold_ink: bool = true, muted: bool = false) -> Label:
	var skin: GameSkin = GameSkin.get_current()
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", skin.get_font())
	l.add_theme_font_size_override("font_size", font_size)
	var col: Color = skin.color("score_label") if muted else (skin.color("bar_text") if bold_ink else skin.color("button_text"))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## The green table cloth as a texture (centre lighter than the edges).
static func felt_texture() -> GradientTexture2D:
	var skin: GameSkin = GameSkin.get_current()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([skin.color("felt_center"), skin.color("felt_edge")])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t
