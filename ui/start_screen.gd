class_name StartScreen
extends MenuScreen
## First screen: Join Game, Host Game, Settings, Exit.

signal join_pressed
signal host_pressed
signal settings_pressed
signal exit_pressed

var notice_label: Label  # a plain-language message such as "The host ended the game"
var join_button: Button
var host_button: Button
var settings_button: Button
var exit_button: Button


func _init() -> void:
	super()
	light_label("Gandus Table", 64, true)
	light_label("Spades", 28)
	notice_label = light_label("", 18, true)
	notice_label.visible = false
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.custom_minimum_size = Vector2(300, 0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(gap)
	join_button = add_button("Join Game", "dark", 340)
	join_button.pressed.connect(func() -> void: join_pressed.emit())
	host_button = add_button("Host Game", "primary", 340)
	settings_button = add_button("Settings", "dark", 340)
	exit_button = add_button("Exit", "dark", 340)
	host_button.pressed.connect(func() -> void: host_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())


## Shows a message under the title ("" hides it).
func set_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = text != ""
