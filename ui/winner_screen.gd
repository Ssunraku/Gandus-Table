class_name WinnerScreen
extends MenuScreen
## Shown when a game is over.

signal play_again_pressed
signal exit_pressed

var title_label: Label
var score_label: Label
var target_label: Label
var play_again_button: Button
var exit_button: Button


func _init() -> void:
	super()
	title_label = light_label("", 56, true)
	score_label = light_label("", 36)
	target_label = light_label("", 20)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(gap)
	play_again_button = add_button("Play again", "primary", 340)
	exit_button = add_button("Exit to start", "gold", 340)
	play_again_button.pressed.connect(func() -> void: play_again_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())


## winner_team 0 = you and your partner, 1 = the other team.
## `team_names`: the two sides as text (default: the offline bots' names).
func show_result(winner_team: int, scores: Array[int], win_score: int, team_names: Array[String] = ["You and Partner", "Tin and Cherry"]) -> void:
	title_label.text = "%s win!" % team_names[0] if winner_team == 0 else "%s win" % team_names[1]
	score_label.text = "Us  %d    Them  %d" % [scores[0], scores[1]]
	target_label.text = "First to %d points" % win_score
