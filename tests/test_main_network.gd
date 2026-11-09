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


## The host taps every free seat (a bot sits there) and the countdown starts the game.
func _start_with_bots(host: Main) -> void:
	for seat in range(1, 4):
		if host._host.seats[seat]["kind"] == "empty":
			host.pregame_screen.bot_add_chosen.emit(seat)
			_tick(2)
	_tick(10)


## A joiner picks a free seat on the table and presses Join table.
func _sit(m: Main, seat: int) -> void:
	m.pregame_screen.seat_buttons[seat].pressed.emit()
	m.pregame_screen.join_button.pressed.emit()
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


func test_hosting_goes_straight_to_the_table_with_the_other_seats_free() -> void:
	var host: Main = _phone("Hosty")
	_host(host)
	var p: PreGameScreen = host.pregame_screen
	assert_true(p.visible)
	assert_true(RoomCode.is_valid(host._room_code))
	assert_string_contains(p.code_label.text, host._room_code)
	assert_eq(p.name_labels[0].text, "Hosty", "the host sits at the bottom with their own name")
	assert_eq(p.avatars[0].kind, "human")
	for seat in [1, 2, 3]:
		assert_eq(p.avatars[seat].kind, "empty")
		assert_eq(p.name_labels[seat].text, "Tap to add a bot")
	assert_null(host.game, "the cards are not dealt until all four seats are taken")


func test_the_host_taps_a_free_seat_and_a_bot_sits_there_and_taps_it_again_to_remove_it() -> void:
	var host: Main = _phone("Hosty")
	_host(host)
	host.pregame_screen.seat_buttons[2].pressed.emit()
	_tick()
	assert_eq(host._host.seats[2]["kind"], "bot")
	assert_eq(host.pregame_screen.avatars[2].kind, "bot")
	assert_eq(host._host.seats[1]["kind"], "empty", "one bot per tap")
	host.pregame_screen.seat_buttons[2].pressed.emit()
	_tick()
	assert_eq(host._host.seats[2]["kind"], "empty")


func test_a_joiner_sees_the_table_and_takes_a_seat() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	var p: PreGameScreen = ann.pregame_screen
	assert_true(p.visible)
	assert_eq(p.title_label.text, "Join Hosty's game")
	assert_true(p.join_button.visible)
	assert_true(p.join_button.disabled, "pick a seat first")
	assert_eq(p.name_labels[0].text, "Hosty")
	assert_string_contains(p.options_label.text, "Blind Nil: off")
	_sit(ann, 2)
	assert_eq(p.name_labels[2].text, "Ann")
	assert_false(p.join_button.visible, "now seated")
	assert_eq(host.pregame_screen.name_labels[2].text, "Ann", "the host's table shows Ann live")


func test_a_joiner_can_move_to_another_free_seat_before_the_game_starts() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	_sit(ann, 2)
	ann.pregame_screen.seat_buttons[1].pressed.emit()
	_tick()
	assert_eq(host._host.seats[1]["name"], "Ann")
	assert_eq(host._host.seats[2]["kind"], "empty")


func test_taking_the_last_seat_starts_a_countdown_and_then_everyone_sees_the_table() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	_sit(ann, 2)
	host.pregame_screen.bot_add_chosen.emit(1)
	_tick(2)
	host.pregame_screen.bot_add_chosen.emit(3)
	net.pump()
	host.net_tick(0.0)
	assert_string_contains(host.pregame_screen.centre_label.text, "Starting in")
	_tick(10)
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
	_sit(ann, 1)
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
	for i in range(3):
		var p: Main = _phone("P%d" % i)
		_join(p)
		p.pregame_screen.seat_chosen.emit(i + 1)  # (the last seat starts the countdown)
		net.pump()
	var extra: Main = _phone("E")
	_join(extra)
	var text: String = extra.join_screen.status_label.text
	assert_true(text.contains("full") or text.contains("already started"), text)


func test_a_full_game_with_four_fake_phones_reaches_the_winner_screen() -> void:
	var host: Main = _phone("Hosty")
	_host(host, 8)  # win at 100
	for n in ["Ann", "Bo", "Cy"]:
		_join(_phone(n))
	for i in range(1, 4):
		phones[i].pregame_screen.seat_chosen.emit(i)
	_tick(10)  # the countdown starts the game by itself
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
	_sit(ann, 2)
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


func test_leaving_the_table_as_a_joiner_frees_the_seat() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	_host(host)
	_join(ann)
	_sit(ann, 3)
	ann.pregame_screen.leave_pressed.emit()
	_tick()
	assert_true(ann.start_screen.visible)
	assert_eq(host.pregame_screen.name_labels[3].text, "Tap to add a bot")


func test_a_picked_seat_that_someone_else_takes_is_forgotten() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	var bo: Main = _phone("Bo")
	_host(host)
	_join(ann)
	_join(bo)
	bo.pregame_screen.seat_buttons[2].pressed.emit()
	assert_false(bo.pregame_screen.join_button.disabled)
	_sit(ann, 2)
	assert_true(bo.pregame_screen.join_button.disabled, "seat 2 is gone, pick again")


func test_two_joiners_asking_for_the_same_seat_at_once_the_loser_gets_a_message() -> void:
	var host: Main = _phone("Hosty")
	var ann: Main = _phone("Ann")
	var bo: Main = _phone("Bo")
	_host(host)
	_join(ann)
	_join(bo)
	ann.pregame_screen.seat_chosen.emit(2)  # both ask before either hears the answer
	bo.pregame_screen.seat_chosen.emit(2)
	_tick()
	assert_eq(host._host.seats[2]["name"], "Ann")
	assert_string_contains(bo.pregame_screen.notice_label.text, "taken")
	assert_true(bo.pregame_screen.join_button.visible, "Bo can pick another seat")


func test_a_joiner_who_never_sat_is_told_the_game_started_without_them() -> void:
	var host: Main = _phone("Hosty")
	var watcher: Main = _phone("Watcher")
	_host(host)
	_join(watcher)
	_start_with_bots(host)
	assert_true(watcher.join_screen.visible)
	assert_string_contains(watcher.join_screen.status_label.text, "already started")


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
