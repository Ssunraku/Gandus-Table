class_name SettingsScreen
extends MenuScreen
## App settings. For now just the sound switch.

signal back_pressed
signal sound_toggled(on: bool)

var back_button: Button
var sound_button: Button


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
	var note: Label = UiStyle.label("More options (card style, table colour) will come later.", 16, true, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(420, 0)
	box.add_child(note)
	back_button = add_button("Back", "paper_outline", 200, box)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	_style()


func _style() -> void:
	sound_button.text = "On" if sound_button.button_pressed else "Off"
	UiStyle.style_button(sound_button, "primary" if sound_button.button_pressed else "paper_outline")
