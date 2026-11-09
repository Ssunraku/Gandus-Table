class_name SettingsScreen
extends MenuScreen
## App settings. For now just the sound switch.

signal back_pressed
signal sound_toggled(on: bool)
## Volume as a percentage, 0 to 100.
signal volume_changed(percent: float)

## The player finished editing their name (already cleaned).
signal name_changed(player_name: String)

var name_edit: LineEdit
var build_label: Label  # "Version 0.1.1 · Wi-Fi: real · ..." (helps when something looks wrong on a device)
var back_button: Button
var sound_button: Button
var volume_slider: HSlider


func _init() -> void:
	super()
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(480, 0)
	column.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiStyle.label("Settings", 30))
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	var nl: Label = UiStyle.label("Your name", 20)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.custom_minimum_size = Vector2(110, 0)
	name_row.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.max_length = PlayerProfile.MAX_LENGTH
	name_edit.custom_minimum_size = Vector2(190, 40)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 20)
	_style_name_box(name_edit)
	name_edit.text_submitted.connect(func(_t: String) -> void: _commit_name())
	name_edit.focus_exited.connect(_commit_name)
	name_row.add_child(name_edit)
	box.add_child(name_row)
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = UiStyle.label("Sound", 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	sound_button = Button.new()
	sound_button.toggle_mode = true
	sound_button.button_pressed = true
	sound_button.custom_minimum_size = Vector2(84, 38)
	sound_button.add_theme_font_size_override("font_size", 18)
	sound_button.toggled.connect(func(on: bool) -> void:
		_style()
		sound_toggled.emit(on))
	row.add_child(sound_button)
	box.add_child(row)
	var volume_row: HBoxContainer = HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 14)
	var vl: Label = UiStyle.label("Volume", 20)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vl.custom_minimum_size = Vector2(110, 0)
	volume_row.add_child(vl)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0
	volume_slider.value = 100.0
	volume_slider.custom_minimum_size = Vector2(190, 40)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(volume_slider)
	volume_row.add_child(volume_slider)
	var percent: Label = UiStyle.label("100%", 18)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.custom_minimum_size = Vector2(56, 0)
	volume_row.add_child(percent)
	volume_slider.value_changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % int(v)
		volume_changed.emit(v))
	box.add_child(volume_row)
	build_label = UiStyle.label("", 14, true, true)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_label.custom_minimum_size = Vector2(420, 0)
	box.add_child(build_label)
	var note: Label = UiStyle.label("More options (card style, table colour) will come later.", 16, true, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(420, 0)
	box.add_child(note)
	back_button = add_button("Back", "paper_outline", 200, box)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void:
		_commit_name()
		back_pressed.emit())
	_style()


## Cleans the typed name, shows the cleaned version and tells the app to save it.
func _commit_name() -> void:
	name_edit.text = PlayerProfile.clean(name_edit.text)
	name_changed.emit(name_edit.text)


## A light box with a thin outline, so the name field matches the cream settings panel.
func _style_name_box(e: LineEdit) -> void:
	var skin: GameSkin = GameSkin.get_current()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.99, 0.96)
	box.border_color = Color(0.55, 0.53, 0.5)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	var focused: StyleBoxFlat = box.duplicate()
	focused.border_color = skin.color("accent")
	e.add_theme_stylebox_override("normal", box)
	e.add_theme_stylebox_override("focus", focused)
	e.add_theme_color_override("font_color", skin.color("bar_text"))
	e.add_theme_color_override("caret_color", skin.color("bar_text"))


## Gold fill up to the handle, a soft track behind it, and a handle big enough for a finger.
func _style_slider(s: HSlider) -> void:
	var skin: GameSkin = GameSkin.get_current()
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.82, 0.80, 0.74)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = skin.color("accent")
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: ImageTexture = _round_knob(30, skin.color("bar_text"))
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)


## A smooth filled circle used as the slider handle.
static func _round_knob(diameter: int, colour: Color) -> ImageTexture:
	var img: Image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r: float = float(diameter) / 2.0
	for y in range(diameter):
		for x in range(diameter):
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(r, r))
			var a: float = clampf(r - d, 0.0, 1.0)  # soft one-pixel edge
			img.set_pixel(x, y, Color(colour.r, colour.g, colour.b, a))
	return ImageTexture.create_from_image(img)


func _style() -> void:
	sound_button.text = "On" if sound_button.button_pressed else "Off"
	UiStyle.style_button(sound_button, "primary" if sound_button.button_pressed else "paper_outline")
