class_name Main
extends Control
## The whole app: swaps between the start, host options, settings, game and winner screens.

## Emitted when Exit is pressed on the start screen.
signal quit_requested

## Tests can switch quitting off so Exit does not close the test run.
var quit_enabled: bool = true
## Multiplies the bots' pauses (tests use 0).
var game_pace: float = 1.0

## Where the player's saved name lives. Empty = no saving and no name prompt (tests use this).
## The real app sets it in main.tscn.
var profile_path: String = ""
var profile: PlayerProfile = PlayerProfile.new()

var name_screen: NameScreen
var start_screen: StartScreen
var host_screen: HostOptionsScreen
var settings_screen: SettingsScreen
var winner_screen: WinnerScreen
var game: GameScreen = null
var sound: SoundBank

var _last_settings: SpadesSettings = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound = SoundBank.new()
	add_child(sound)
	name_screen = NameScreen.new()
	start_screen = StartScreen.new()
	host_screen = HostOptionsScreen.new()
	settings_screen = SettingsScreen.new()
	winner_screen = WinnerScreen.new()
	for s in [name_screen, start_screen, host_screen, settings_screen, winner_screen]:
		add_child(s)
	name_screen.name_chosen.connect(_on_name_chosen)
	settings_screen.name_changed.connect(_on_name_changed)
	start_screen.host_pressed.connect(func() -> void: _show(host_screen))
	start_screen.settings_pressed.connect(func() -> void: _show(settings_screen))
	start_screen.exit_pressed.connect(_quit)
	host_screen.back_pressed.connect(func() -> void: _show(start_screen))
	host_screen.start_pressed.connect(_start_game)
	settings_screen.back_pressed.connect(func() -> void: _show(start_screen))
	settings_screen.sound_toggled.connect(func(on: bool) -> void: sound.enabled = on)
	settings_screen.volume_changed.connect(func(percent: float) -> void: sound.volume = percent / 100.0)
	winner_screen.play_again_pressed.connect(func() -> void: _start_game(_last_settings))
	winner_screen.exit_pressed.connect(func() -> void: _show(start_screen))
	_show(start_screen)


func _ready() -> void:
	if profile_path == "":
		return
	profile.load_from(profile_path)
	settings_screen.name_edit.text = profile.player_name
	if not profile.has_name():
		_show(name_screen)  # first launch: ask who the player is


func _on_name_chosen(player_name: String) -> void:
	_on_name_changed(player_name)
	_show(start_screen)


func _on_name_changed(player_name: String) -> void:
	profile.set_name(player_name)
	settings_screen.name_edit.text = profile.player_name
	if profile_path != "":
		profile.save_to(profile_path)


func _show(screen: Control) -> void:
	for s in [name_screen, start_screen, host_screen, settings_screen, winner_screen]:
		s.visible = s == screen
	if game != null:
		game.visible = screen == game


func _quit() -> void:
	quit_requested.emit()
	if quit_enabled:
		get_tree().quit()


func _drop_game() -> void:
	if game != null:
		game.queue_free()
		game = null


func _start_game(settings: SpadesSettings) -> void:
	_drop_game()
	_last_settings = settings
	game = GameScreen.new()
	game.pace = game_pace
	add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.game_finished.connect(_on_game_finished)
	game.exit_to_start.connect(_leave_game)
	game.sound_event.connect(func(e: String) -> void: sound.play(e))
	_show(game)
	game.start(settings, int(Time.get_ticks_usec() % 1000000))


func _leave_game() -> void:
	_drop_game()
	_show(start_screen)


func _on_game_finished(winner_team: int, scores: Array[int]) -> void:
	winner_screen.show_result(winner_team, scores, _last_settings.win_score)
	_drop_game()
	_show(winner_screen)
