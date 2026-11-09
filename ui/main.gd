class_name Main
extends Control
## The whole app: swaps between the screens and runs the network side of a game: hosting
## (this phone is the host AND a player), joining, reconnecting and leaving.

## Emitted when Exit is pressed on the start screen.
signal quit_requested

const RECONNECT_EVERY: float = 2.0
const RECONNECT_GIVE_UP: float = 30.0
const JOIN_TIMEOUT: float = 8.0
const CODE_SEARCH_TIMEOUT: float = 6.0

## Tests can switch quitting off so Exit does not close the test run.
var quit_enabled: bool = true
## Multiplies the host's pauses and the table's animations (tests use 0).
var game_pace: float = 1.0
## false = an in-memory network (tests, nothing touches the real network); the real app
## sets it to true in main.tscn.
@export var real_network: bool = false
## The in-memory network used when real_network is false. Tests that need several phones
## give them all the same one.
var test_network: FakeNetwork
## When true, the app picks its design size by orientation (1280x720 sideways, 720x1280
## upright) so everything keeps a readable size on a phone held upright. The real app
## sets it in main.tscn; tests leave it off.
@export var adapt_scale: bool = false
## Where the player's saved name lives. Empty = no saving and no name prompt (tests use this).
## The real app sets it in main.tscn.
@export var profile_path: String = ""
var profile: PlayerProfile = PlayerProfile.new()

var name_screen: NameScreen
var start_screen: StartScreen
var host_screen: HostOptionsScreen
var join_screen: JoinScreen
var pregame_screen: PreGameScreen
var settings_screen: SettingsScreen
var winner_screen: WinnerScreen
var game: GameScreen = null
var sound: SoundBank

var _last_settings: SpadesSettings = null
var _clock: float = 0.0

# hosting
var _host: SpadesHost
var _link: LocalLink
var _runner: HostRunner
var _discovery: LanDiscovery
var _room_code: String = ""
var _is_hosting: bool = false

# this phone's own player (the host's local player, or a joiner)
var _client: SpadesClient
var _wifi: WifiTransport
var _addr: String = ""
var _port: int = 0
var _in_net_game: bool = false
var _stopping: bool = false
var _connect_started: float = 0.0
var _reconnecting: bool = false
var _reconnect_started: float = 0.0
var _last_attempt: float = -100.0

# finding games
var _finder: LanDiscovery
var _finder_signature: String = ""
var _search_started: float = 0.0
var _wanted_code: String = ""
var _code_deadline: float = 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound = SoundBank.new()
	add_child(sound)
	name_screen = NameScreen.new()
	start_screen = StartScreen.new()
	host_screen = HostOptionsScreen.new()
	join_screen = JoinScreen.new()
	pregame_screen = PreGameScreen.new()
	settings_screen = SettingsScreen.new()
	winner_screen = WinnerScreen.new()
	for s in _screens():
		add_child(s)
	name_screen.name_chosen.connect(_on_name_chosen)
	settings_screen.name_changed.connect(_on_name_changed)
	start_screen.host_pressed.connect(func() -> void: _show(host_screen))
	start_screen.join_pressed.connect(_open_join)
	start_screen.settings_pressed.connect(func() -> void: _show(settings_screen))
	start_screen.exit_pressed.connect(_quit)
	host_screen.back_pressed.connect(func() -> void: _show(start_screen))
	host_screen.start_pressed.connect(_start_hosting)
	join_screen.back_pressed.connect(_close_join)
	join_screen.join_chosen.connect(_join)
	join_screen.code_chosen.connect(_search_code)
	pregame_screen.seat_chosen.connect(func(seat: int) -> void: _client.request_seat(seat))
	pregame_screen.bot_add_chosen.connect(func(seat: int) -> void: _client.add_bot(seat))
	pregame_screen.bot_remove_chosen.connect(func(seat: int) -> void: _client.remove_bot(seat))
	pregame_screen.leave_pressed.connect(func() -> void: _leave_network(""))
	settings_screen.back_pressed.connect(func() -> void: _show(start_screen))
	settings_screen.sound_toggled.connect(func(on: bool) -> void: sound.enabled = on)
	settings_screen.volume_changed.connect(func(percent: float) -> void: sound.volume = percent / 100.0)
	winner_screen.exit_pressed.connect(func() -> void: _leave_network(""))
	_show(start_screen)


func _screens() -> Array:
	return [name_screen, start_screen, host_screen, join_screen, pregame_screen, settings_screen, winner_screen]


func _ready() -> void:
	if adapt_scale:
		get_window().size_changed.connect(_update_scale)
		_update_scale()
	get_window().size_changed.connect(_refresh_build_info)
	_refresh_build_info()
	if profile_path == "":
		return
	profile.load_from(profile_path)
	settings_screen.name_edit.text = profile.player_name
	if not profile.has_name():
		_show(name_screen)  # first launch: ask who the player is


func _process(delta: float) -> void:
	net_tick(delta)


const VERSION: String = "0.1.2"


## The line at the bottom of Settings: what this build is and how it is running.
func build_info_text() -> String:
	var w: Window = get_window()
	return "Version %s · Wi-Fi: %s · name saved: %s · screen %dx%d (design %dx%d)" % [
		VERSION, "real" if real_network else "test only", "yes" if profile_path != "" else "no",
		w.size.x, w.size.y, w.content_scale_size.x, w.content_scale_size.y]


func _refresh_build_info() -> void:
	settings_screen.build_label.text = build_info_text()


## The design size that suits a window of this shape.
static func design_size_for(window_size: Vector2) -> Vector2i:
	return Vector2i(720, 1280) if window_size.y > window_size.x else Vector2i(1280, 720)


func _update_scale() -> void:
	var w: Window = get_window()
	var wanted: Vector2i = design_size_for(Vector2(w.size))
	if w.content_scale_size != wanted:
		w.content_scale_size = wanted
	pregame_screen.set_ui_scale(1.4 if wanted.x < wanted.y else 1.0)


## One beat of the network side: delivers messages, runs the host's steps, checks timers.
## The app calls it every frame; tests call it themselves (a big `delta` skips waiting time).
func net_tick(delta: float = 0.016) -> void:
	_clock += delta
	if not real_network and test_network != null:
		test_network.pump()
	if _wifi != null:
		_wifi.poll()
	if _runner != null:
		_runner._process(delta)
	if not real_network and test_network != null:
		test_network.pump()
	_update_finder()
	_check_joining()
	_check_reconnect()


# ---------- names ----------

func _my_name() -> String:
	return profile.player_name if profile.has_name() else PlayerProfile.DEFAULT_NAME


func _on_name_chosen(player_name: String) -> void:
	_on_name_changed(player_name)
	_show(start_screen)


func _on_name_changed(player_name: String) -> void:
	profile.set_name(player_name)
	settings_screen.name_edit.text = profile.player_name
	if profile_path != "":
		profile.save_to(profile_path)


# ---------- screens ----------

func _show(screen: Control) -> void:
	for s in _screens():
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


func _go_start(message: String) -> void:
	start_screen.set_notice(message)
	_show(start_screen)


# ---------- hosting ----------

func _start_hosting(settings: SpadesSettings) -> void:
	_stop_network()
	_drop_game()
	_last_settings = settings
	var inner: Transport
	if real_network:
		var w: WifiTransport = WifiTransport.new()
		if w.start_host() != OK:
			_go_start("Could not start hosting. Is another game already running on this phone?")
			return
		inner = w
		_wifi = null
	else:
		if test_network == null:
			test_network = FakeNetwork.new()
		inner = test_network.host_transport()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_room_code = RoomCode.generate(rng)
	_link = LocalLink.new(inner)
	_host = SpadesHost.new(_link, settings, int(Time.get_ticks_usec() % 1000000))
	_host.room_code = _room_code
	if real_network:
		_host.host_addresses = LanDiscovery.local_addresses()
	if real_network:
		_discovery = LanDiscovery.new()
		_discovery.advertise(_discovery_info())
	_client = SpadesClient.new(_link.local_client())
	_hook_client()
	_runner = HostRunner.new(_host, _link, _discovery)
	_runner.pace = game_pace
	_runner.set_process(false)  # Main drives it from net_tick
	add_child(_runner)
	_is_hosting = true
	_in_net_game = false
	_client.join(_my_name(), true)  # (the host is seated at the bottom automatically)
	_show(pregame_screen)
	net_tick(0.0)


func _discovery_info() -> Dictionary:
	var free: int = 0
	for s in _host.seats:
		if s["kind"] == "empty":
			free += 1
	return {
		"code": _room_code,
		"name": _my_name(),
		"game_port": WifiTransport.GAME_PORT,
		"free_seats": free,
		"exact": int(_last_settings.exact_mode) if _last_settings != null else 0,
	}


func _refresh_lobby() -> void:
	pregame_screen.show_state(_client.lobby, _is_hosting)
	if _discovery != null and _host != null:
		_discovery.update_info(_discovery_info())


# ---------- joining ----------

func _open_join() -> void:
	_stop_network()
	start_screen.set_notice("")
	join_screen.show_games([] as Array[Dictionary])
	join_screen.set_status("Searching for games on your Wi-Fi...")
	_show(join_screen)
	_search_started = _clock
	_wanted_code = ""
	_finder_signature = ""
	if real_network:
		_finder = LanDiscovery.new()
		_finder.search("")


func _close_join() -> void:
	_stop_finder()
	_show(start_screen)


func _stop_finder() -> void:
	if _finder != null:
		_finder.stop_searching()
		_finder = null
	_wanted_code = ""


func _update_finder() -> void:
	if _finder == null:
		return
	_finder.poll()
	if _wanted_code != "":
		if not _finder.found.is_empty():
			var g: Dictionary = _finder.found[0]
			_join(g["address"], int(g["port"]))
		elif _clock > _code_deadline:
			join_screen.set_status("No game with the code %s was found. Check the letters and that you are on the same Wi-Fi." % _wanted_code)
			_stop_finder()
		return
	var sig: String = str(_finder.found.size())
	for g in _finder.found:
		sig += "|%s%s%d" % [g["code"], g["address"], int(g["free_seats"])]
	if sig != _finder_signature:
		_finder_signature = sig
		join_screen.show_games(_finder.found)
	if _finder.found.is_empty():
		if _clock - _search_started > 8.0:
			join_screen.set_status("No games found yet. If this Wi-Fi is a guest or public network, phones may be blocked from seeing each other: ask the host for the address and type it below.")
		else:
			join_screen.set_status("Searching for games on your Wi-Fi...")
	else:
		join_screen.set_status("Tap a game to join it.")


func _search_code(code: String) -> void:
	if not real_network:
		_join("", 0)  # (tests: there is only one game)
		return
	_stop_finder()
	_finder = LanDiscovery.new()
	_finder.search(code)
	_wanted_code = code
	_code_deadline = _clock + CODE_SEARCH_TIMEOUT
	join_screen.set_status("Looking for the game %s..." % code)


func _join(address: String, port: int) -> void:
	_stop_finder()
	_stop_network()
	_addr = address
	_port = port
	var transport: Transport
	if real_network:
		_wifi = WifiTransport.new()
		if _wifi.connect_to(address, port) != OK:
			_wifi = null
			join_screen.set_status("Could not connect to that address.")
			return
		transport = _wifi
	else:
		if test_network == null:
			test_network = FakeNetwork.new()
		transport = test_network.connect_client()
	_is_hosting = false
	_in_net_game = false
	_client = SpadesClient.new(transport)
	_hook_client()
	transport.peer_connected.connect(_on_joiner_connected)
	join_screen.set_status("Connecting...")
	_show(join_screen)
	_connect_started = _clock


func _on_joiner_connected(_peer: int) -> void:
	if _client == null:
		return
	if _reconnecting:
		_client.rejoin(_client.token)
	else:
		_client.join(_my_name())


func _check_joining() -> void:
	if _client == null or _is_hosting or _in_net_game or _reconnecting:
		return
	if pregame_screen.visible:
		return
	var failed: bool = _wifi != null and _wifi.status == "failed"
	var stuck: bool = _clock - _connect_started > JOIN_TIMEOUT
	if failed or stuck:
		_stop_network()
		join_screen.set_status("Could not reach that game. Check that you are on the same Wi-Fi as the host.")


# ---------- client signals ----------

func _hook_client() -> void:
	_client.lobby_changed.connect(_on_lobby_changed)
	_client.view_changed.connect(_on_view_changed)
	_client.refused.connect(_on_refused)
	_client.rejected.connect(_on_rejected)
	_client.closed.connect(_on_closed)
	_client.connection_lost.connect(_on_connection_lost)


func _on_lobby_changed() -> void:
	if _in_net_game or _client == null:
		return
	pregame_screen.set_notice("")
	_refresh_lobby()
	if not _is_hosting and join_screen.visible:
		_show(pregame_screen)


func _on_view_changed() -> void:
	if _client == null:
		return
	if _reconnecting:
		_reconnecting = false
		if game != null:
			game.set_notice("")
	if not _in_net_game:
		_open_net_game()


func _open_net_game() -> void:
	_in_net_game = true
	_drop_game()
	game = GameScreen.new()
	game.pace = game_pace
	add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.game_finished.connect(_on_game_finished)
	game.exit_to_start.connect(func() -> void: _leave_network(""))
	game.sound_event.connect(func(e: String) -> void: sound.play(e))
	_show(game)
	game.start_online(RemoteSource.new(_client))


func _on_game_finished(winner_team: int, scores: Array[int]) -> void:
	var names: Dictionary = game.source.view()["names"] if game != null else {}
	var teams: Array[String] = ["%s and %s" % [names.get(0, "You"), names.get(2, "Partner")], "%s and %s" % [names.get(1, "?"), names.get(3, "?")]]
	var win_score: int = _client.view["settings"].win_score
	winner_screen.show_result(winner_team, scores, win_score, teams)
	winner_screen.play_again_button.visible = false  # (not for network games yet)
	_drop_game()
	_show(winner_screen)


## The host said no to a request made at the table before the game.
func _on_rejected(reason: String) -> void:
	if _in_net_game or not pregame_screen.visible:
		return
	match reason:
		"seat_taken":
			pregame_screen.set_notice("That seat was just taken. Pick another one.")
		"starting":
			pregame_screen.set_notice("The game is about to start.")
		_:
			pregame_screen.set_notice("")


func _on_refused(reason: String) -> void:
	var text: String = "Could not join: %s" % reason
	match reason:
		"full":
			text = "That game is full."
		"game_started":
			text = "That game has already started."
		"bad_token", "no_game":
			text = "You were replaced by a bot, so you cannot rejoin that game."
	if _reconnecting or _in_net_game:
		_leave_network(text)
	else:
		_stop_network()
		join_screen.set_status(text)
		_show(join_screen)


func _on_closed(_reason: String) -> void:
	if _stopping:
		return
	if winner_screen.visible or start_screen.visible:
		return
	_leave_network("The host ended the game.")


func _on_connection_lost() -> void:
	if _stopping or _is_hosting or _client == null:
		return
	if winner_screen.visible:
		return
	if _in_net_game and game != null:
		_reconnecting = true
		_reconnect_started = _clock
		_last_attempt = -100.0
		game.set_notice("Connection lost. Reconnecting...")
	else:
		_leave_network("Lost the connection to the host.")


# ---------- reconnecting ----------

func _check_reconnect() -> void:
	if not _reconnecting or _client == null:
		return
	if _clock - _reconnect_started > RECONNECT_GIVE_UP:
		_leave_network("Could not reach the host.")
		return
	if _clock - _last_attempt < RECONNECT_EVERY:
		return
	_last_attempt = _clock
	var transport: Transport
	if real_network:
		if _wifi != null:
			_wifi.close()
		_wifi = WifiTransport.new()
		if _wifi.connect_to(_addr, _port) != OK:
			return
		transport = _wifi
	else:
		transport = test_network.connect_client()
	_client.replace_transport(transport)
	transport.peer_connected.connect(_on_joiner_connected)


# ---------- leaving ----------

## Stops all networking (no screen change).
func _stop_network() -> void:
	_stopping = true
	if _client != null and not _is_hosting and _client.connected:
		_client.leave()
	if _runner != null:
		_runner.stop()
		remove_child(_runner)
		_runner.queue_free()
		_runner = null
	if _discovery != null:
		_discovery.stop_advertising()
		_discovery = null
	if _wifi != null:
		_wifi.close()
		_wifi = null
	_stop_finder()
	_link = null
	_host = null
	_client = null
	_is_hosting = false
	_in_net_game = false
	_reconnecting = false
	_stopping = false


## Ends the game for this phone (a host's leaving ends it for everybody) and shows the
## start screen, with an optional plain-language message.
func _leave_network(message: String) -> void:
	_stop_network()
	_drop_game()
	_go_start(message)
