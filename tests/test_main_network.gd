extends GutTest
## Several "phones" (Main instances) sharing one in-memory network: hosting, joining,
## the lobby, a whole game, dropping and coming back, giving up, leaving.

var net: FakeNetwork
var phones: Array[Main] = []


func before_each() -> void:
	net = FakeNetwork.new()
	phones = []


func _phone(player_name: String) -> Main:
	var m: Main = Main.new()
	m.quit_enabled = false
	m.game_pace = 0.0
	m.test_network = net
	m.profile.set_name(player_name)
	add_child_autofree(m)
	phones.append(m)
	return m


func _tick(n: int = 8, delta: float = 0.016) -> void:
	for i in range(n):
		for m in phones:
			m.net_tick(delta)


func _host(m: Main, win_steps_down: int = 0) -> void:
	m.start_screen.host_button.pressed.emit()
	for i in range(win_steps_down):
		m.host_screen.step_win(-1)
	m.host_screen.toggle("blind_nil").button_pressed = false
	m.host_screen.start_button.pressed.emit()
	_tick()


func _join(m: Main) -> void:
	m.start_screen.join_button.pressed.emit()
	m.join_screen.join_chosen.emit("fake", 1)
	_tick()


func _start_with_bots(host: Main) -> void:
	host.lobby_screen.bots_button.pressed.emit()
	_tick()
	host.lobby_screen.start_button.pressed.emit()
	_tick()


## Plays one action for a phone if it has one. Returns true if it did something.
func _auto(m: Main) -> bool:
	if m.game == null or not m.game.visible:
		return false
	var g: GameScreen = m.game
	var src: GameSource = g.source
	if g.summary.visible:
		if src.game_over() or m._is_hosting:
			g.summary.next_button.pressed.emit()
			return true
		return false
	if src.human_must_bid():
		g.bid_panel.bid_chosen.emit(Bid.number(3))
		return true
	if src.human_must_play() and not (src.view()["legal"] as Array).is_empty():
		g.table.human_played.emit((src.view()["legal"] as Array)[0])
		return true
	return false


func _play_until(done: Callable, limit: int = 30000) -> bool:
	for i in range(limit):
		_tick(1)
		if done.call():
			return true
		var any: bool = false
		for m in phones:
			if _auto(m):
				any = true
		if not any and i > 50 and done.call():
			return true
	return done.call()


func test_hosting_shows_the_lobby_with_a_room_code_and_the_host_seated_south() -> void:
	var host: Main = _phone("Hosty")
	_host(host)
	assert_true(host.lobby_screen.visible)
	assert_true(RoomCode.is_valid(host._room_code))
	assert_string_contains(host.lobby_screen.code_label.text, host._room_code)
	assert_string_contains(host.lobby_screen.seat_buttons[0].text, "Hosty")
	assert_string_contains(host.lobby_screen.seat_buttons[0].text, "(you)")
	assert_true(host.lobby_screen.start_button.disabled, "seats are free")


func test_a_joiner_sees_the_lobby_and_can_take_a_seat() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	assert_true(ann.lobby_screen.visible)
	assert_false(ann.lobby_screen.start_button.visible, "only the host can start")
	assert_string_contains(ann.lobby_screen.seat_buttons[0].text, "Hosty")
	assert_string_contains(ann.lobby_screen.options_label.text, "Blind Nil: off")
	ann.lobby_screen.seat_chosen.emit(2)
	_tick()
	assert_string_contains(ann.lobby_screen.seat_buttons[2].text, "(you)")
	assert_string_contains(host.lobby_screen.seat_buttons[2].text, "Ann")


func test_host_fills_bots_and_starts_and_everyone_sees_the_table() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	ann.lobby_screen.seat_chosen.emit(2)
	_tick()
	_start_with_bots(host)
	for m in [host, ann]:
		assert_not_null(m.game)
		assert_true(m.game.visible)
		assert_true(m.game.source.is_online())
	assert_eq(ann.game.source.view()["names"][2], "Hosty", "Ann sits opposite the host: the partner")
	assert_eq(host.game.source.view()["names"][2], "Ann")


func test_each_phone_keeps_its_own_name_from_its_profile() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	ann.lobby_screen.seat_chosen.emit(1)
	_tick()
	_start_with_bots(host)
	var names: Dictionary = host.game.source.view()["names"]
	assert_eq(names[0], "Hosty", "your own name, not You")
	assert_eq(names[1], "Ann", "Ann sat at West, the seat after the host's")


func test_joining_a_started_game_shows_a_message_not_a_stuck_screen() -> void:
	var host: Main = _phone("Hosty")
	_host(host)
	_start_with_bots(host)
	var late: Main = _phone("Late")
	_join(late)
	assert_true(late.join_screen.visible)
	assert_string_contains(late.join_screen.status_label.text, "already started")


func test_a_fifth_player_is_told_the_game_is_full() -> void:
	var host: Main = _phone("Hosty")
	_host(host)
	for n in ["A", "B", "C"]:
		_join(_phone(n))
	var extra: Main = _phone("E")
	_join(extra)
	assert_string_contains(extra.join_screen.status_label.text, "full")


func test_a_full_game_with_four_fake_phones_reaches_the_winner_screen() -> void:
	var host: Main = _phone("Hosty")
	_host(host, 8)  # win at 100
	for n in ["Ann", "Bo", "Cy"]:
		_join(_phone(n))
	for i in range(1, 4):
		phones[i].lobby_screen.seat_chosen.emit(i)
	_tick()
	host.lobby_screen.start_button.pressed.emit()
	_tick()
	assert_true(host.game.visible)
	var done: Callable = func() -> bool:
		for m in phones:
			if not m.winner_screen.visible:
				return false
		return true
	assert_true(_play_until(done), "all four phones reach the winner screen")
	for m in phones:
		assert_false(m.winner_screen.play_again_button.visible)
		assert_string_contains(m.winner_screen.title_label.text, "win")
	# everyone agrees on the score, each from their own side
	assert_eq(phones[0].winner_screen.score_label.text.replace("Us", "A").replace("Them", "B"), phones[2].winner_screen.score_label.text.replace("Us", "A").replace("Them", "B"))


func _two_phone_game() -> Array[Main]:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	ann.lobby_screen.seat_chosen.emit(2)
	_tick()
	_start_with_bots(host)
	return [host, ann] as Array[Main]


func test_a_dropped_joiner_reconnects_by_itself_and_the_game_goes_on() -> void:
	var pair: Array[Main] = _two_phone_game()
	var host: Main = pair[0]
	var ann: Main = pair[1]
	_tick(30)
	net.drop(ann._client.transport as FakeTransport)
	net.pump()  # the news arrives; nobody has had time to react yet
	assert_true(host._host.paused, "the host pauses the game")
	assert_true(ann._reconnecting)
	assert_true(ann.game.notice_panel.visible)
	assert_string_contains(ann.game.notice_label.text, "Reconnecting")
	host.net_tick(0.0)  # the host's own player hears about it through the local link
	assert_true(host.game.notice_panel.visible)
	assert_string_contains(host.game.notice_label.text, "Ann")
	_tick(6)  # Ann tries again at once and gets her seat back
	assert_false(host._host.paused, "Ann is back")
	assert_false(ann._reconnecting)
	assert_false(ann.game.notice_panel.visible)
	assert_false(host.game.notice_panel.visible)
	assert_eq(ann._client.my_seat, 2, "same seat")
	# and the game really goes on: somebody can act again
	var moved: bool = _play_until(func() -> bool: return host.game.source.round_number() >= 1 and (host.game.source.view()["trick"] as Array).size() > 0, 3000)
	assert_true(moved)


func test_giving_up_after_30_seconds_returns_to_the_start_screen_with_a_message() -> void:
	var pair: Array[Main] = _two_phone_game()
	var ann: Main = pair[1]
	_tick(20)
	ann.test_network = FakeNetwork.new()  # from now on the host cannot be reached
	net.drop(ann._client.transport as FakeTransport)
	net.pump()
	assert_true(ann._reconnecting)
	for i in range(10):
		ann.net_tick(4.0)  # 40 seconds of failed attempts
	assert_true(ann.start_screen.visible, "gave up")
	assert_string_contains(ann.start_screen.notice_label.text, "Could not reach the host")


func test_host_leaving_ends_the_game_for_everyone_with_a_message() -> void:
	var pair: Array[Main] = _two_phone_game()
	var host: Main = pair[0]
	var ann: Main = pair[1]
	_tick(20)
	host.game.exit_to_start.emit()
	_tick(4)
	assert_true(host.start_screen.visible)
	assert_true(ann.start_screen.visible)
	assert_string_contains(ann.start_screen.notice_label.text, "host ended")


func test_a_joiner_leaving_gives_the_seat_to_a_bot() -> void:
	var pair: Array[Main] = _two_phone_game()
	var host: Main = pair[0]
	var ann: Main = pair[1]
	_tick(20)
	var host_core: SpadesHost = host._host
	ann.game.exit_to_start.emit()
	_tick(4)
	assert_true(ann.start_screen.visible)
	assert_eq(host_core.seats[2]["kind"], "bot")
	assert_false(host_core.paused)


func test_host_can_replace_a_dropped_player_with_a_bot_from_the_pause_notice() -> void:
	var pair: Array[Main] = _two_phone_game()
	var host: Main = pair[0]
	var ann: Main = pair[1]
	_tick(20)
	var host_core: SpadesHost = host._host
	net.drop(ann._client.transport as FakeTransport)
	ann.test_network = FakeNetwork.new()  # Ann cannot come back
	net.pump()
	_tick(2)
	assert_true(host.game.replace_button.visible, "the host sees the button")
	assert_false(ann.game.replace_button.visible if ann.game != null else false, "joiners never do")
	host.game.replace_button.pressed.emit()
	_tick(4)
	assert_eq(host_core.seats[2]["kind"], "bot")
	assert_false(host_core.paused)
	assert_false(host.game.notice_panel.visible)


func test_leaving_the_lobby_as_a_joiner_frees_the_seat() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	ann.lobby_screen.seat_chosen.emit(3)
	_tick()
	ann.lobby_screen.leave_pressed.emit()
	_tick()
	assert_true(ann.start_screen.visible)
	assert_string_contains(host.lobby_screen.seat_buttons[3].text, "free")


func test_design_size_follows_the_window_shape() -> void:
	assert_eq(Main.design_size_for(Vector2(1280, 720)), Vector2i(1280, 720))
	assert_eq(Main.design_size_for(Vector2(2400, 1080)), Vector2i(1280, 720), "a phone held sideways")
	assert_eq(Main.design_size_for(Vector2(1080, 2400)), Vector2i(720, 1280), "a phone held upright")
	assert_eq(Main.design_size_for(Vector2(360, 780)), Vector2i(720, 1280))
	assert_eq(Main.design_size_for(Vector2(800, 800)), Vector2i(1280, 720), "square counts as sideways")


func test_the_info_screen_shows_the_room_code_on_every_phone() -> void:
	var pair: Array[Main] = _two_phone_game()
	var host: Main = pair[0]
	var ann: Main = pair[1]
	_tick(10)
	for m in [host, ann]:
		m.game.table.info_button.pressed.emit()
		var text: String = ""
		for l in m.game.info_panel.find_children("*", "Label", true, false):
			text += (l as Label).text + " | "
		assert_string_contains(text, host._room_code)
		assert_string_contains(text, "Room code")
