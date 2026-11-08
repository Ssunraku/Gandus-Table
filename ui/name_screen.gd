class_name NameScreen
extends MenuScreen
## Shown the first time the app opens: "What should we call you?"

signal name_chosen(player_name: String)

var name_edit: LineEdit
var continue_button: Button


func _init() -> void:
	super()
	light_label("Welcome!", 52, true)
	light_label("What should we call you?", 26)
	name_edit = LineEdit.new()
	name_edit.max_length = PlayerProfile.MAX_LENGTH
	name_edit.placeholder_text = "Your name"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(340, 56)
	name_edit.add_theme_font_size_override("font_size", 24)
	column.add_child(name_edit)
	var note: Label = light_label("You can change it later in Settings.", 16)
	note.modulate.a = 0.75
	continue_button = add_button("Continue", "primary", 340)
	continue_button.pressed.connect(_choose)
	name_edit.text_submitted.connect(func(_t: String) -> void: _choose())


func _choose() -> void:
	name_chosen.emit(PlayerProfile.clean(name_edit.text))
