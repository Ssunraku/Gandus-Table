class_name StartScreen
extends MenuScreen
## First screen: Join Game (not available yet), Host Game, Settings, Exit.

signal host_pressed
signal settings_pressed
signal exit_pressed

var join_button: Button
var host_button: Button
var settings_button: Button
var exit_button: Button


func _init() -> void:
	super()
	light_label("Gandus Table", 64, true)
	light_label("Spades", 28)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(gap)
	join_button = add_button("Join Game", "dark", 340)
	join_button.disabled = true
	var soon: Label = light_label("Coming soon", 15)
	soon.modulate.a = 0.7
	host_button = add_button("Host Game", "primary", 340)
	settings_button = add_button("Settings", "dark", 340)
	exit_button = add_button("Exit", "dark", 340)
	host_button.pressed.connect(func() -> void: host_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
