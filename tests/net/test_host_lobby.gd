extends GutTest


func test_join_gets_a_token_and_a_lobby_state_with_the_hosts_options() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.win_score = 300
	var rig: NetRig = NetRig.new(s)
	var p: TestPeer = rig.joined("Sam")
	assert_eq(p.last("join_accepted")["name"], "Sam")
	assert_eq(str(p.last("join_accepted")["token"]).length(), 16)
	var lobby: Dictionary = p.last("lobby_state")
	assert_eq(int(lobby["settings"]["win"]), 300)
	assert_eq(int(lobby["you"]), -1)
	assert_eq((lobby["seats"] as Array).size(), 4)


func test_same_name_twice_gets_a_number() -> void:
	var rig: NetRig = NetRig.new()
	rig.joined("Sam")
	var b: TestPeer = rig.joined("sam")
	assert_eq(b.last("join_accepted")["name"], "sam 2")


func test_player_picks_a_free_seat_and_everyone_sees_it() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann", 2)
	var b: TestPeer = rig.joined("Bo")
	assert_eq(int(a.last("lobby_state")["you"]), 2)
	var seats: Array = b.last("lobby_state")["seats"]
	assert_eq(seats[2]["kind"], "human")
	assert_eq(seats[2]["name"], "Ann")
	assert_eq(int(b.last("lobby_state")["you"]), -1)


func test_two_players_asking_for_the_same_seat_only_one_wins() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann")
	var b: TestPeer = rig.joined("Bo")
	a.send("seat_request", {"seat": 1})
	b.send("seat_request", {"seat": 1})
	assert_eq(rig.host.seats[1]["name"], "Ann")
	assert_eq(b.last("action_rejected")["reason"], "seat_taken")


func test_player_can_move_to_another_empty_seat() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann", 1)
	a.send("seat_request", {"seat": 3})
	assert_eq(rig.host.seats[1]["kind"], "empty")
	assert_eq(rig.host.seats[3]["name"], "Ann")


func test_bad_seat_numbers_are_rejected() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann")
	a.send("seat_request", {"seat": 7})
	a.send("seat_request", {"seat": "two"})
	a.send("seat_request", {})
	assert_eq(a.of_type("action_rejected").size(), 3)
	assert_eq(rig.host.seats[0]["kind"], "empty")


func test_the_host_player_sits_in_seat_zero_on_joining() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.peer(true)
	me.send("join_request", {"name": "Host", "as_host": true})
	assert_eq(rig.host.seats[0]["kind"], "human")
	assert_eq(rig.host.seats[0]["name"], "Host")
	var lobby: Dictionary = me.last("lobby_state")
	assert_eq(int(lobby["you"]), 0)
	assert_true(lobby["is_host"])
	assert_eq(rig.host.seats[1]["kind"], "empty")


func test_the_host_cannot_change_seat() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	me.send("seat_request", {"seat": 2})
	assert_eq(rig.host.seats[0]["name"], "Host")
	assert_eq(rig.host.seats[2]["kind"], "empty")
	assert_eq(me.last("action_rejected")["reason"], "host_seat_fixed")


func test_the_host_adds_a_bot_to_one_free_seat_at_a_time() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	me.send("add_bot", {"seat": 2})
	assert_eq(rig.host.seats[2]["kind"], "bot")
	assert_eq(rig.host.seats[1]["kind"], "empty", "only the tapped seat gets a bot")
	assert_eq(rig.host.seats[3]["kind"], "empty")
	assert_eq(rig.host.phase_name(), "lobby")
	me.send("add_bot", {"seat": 2})
	assert_eq(me.last("action_rejected")["reason"], "seat_taken")
	me.send("add_bot", {"seat": 9})
	assert_eq(me.last("action_rejected")["reason"], "bad_seat")


func test_a_joiner_cannot_add_or_remove_bots() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	var other: TestPeer = rig.joined("Ann", 1)
	other.send("add_bot", {"seat": 2})
	assert_eq(rig.host.seats[2]["kind"], "empty")
	me.send("add_bot", {"seat": 2})
	other.send("remove_bot", {"seat": 2})
	assert_eq(rig.host.seats[2]["kind"], "bot")


func test_the_host_removes_a_bot_but_not_a_person() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	var ann: TestPeer = rig.joined("Ann", 1)
	me.send("add_bot", {"seat": 2})
	me.send("remove_bot", {"seat": 2})
	assert_eq(rig.host.seats[2]["kind"], "empty")
	me.send("remove_bot", {"seat": 1})
	assert_eq(rig.host.seats[1]["name"], "Ann")
	assert_eq(me.last("action_rejected")["reason"], "not_a_bot")
	assert_not_null(ann)


func test_a_remote_peer_cannot_claim_to_be_the_host() -> void:
	var rig: NetRig = NetRig.new()
	var p: TestPeer = rig.joined("Fake", 0, false)
	p.send("join_request", {"name": "Again", "as_host": true})
	p.send("add_bot", {"seat": 1})
	assert_eq(rig.host.seats[1]["kind"], "empty")
	var q: TestPeer = rig.peer(false)
	q.send("join_request", {"name": "Evil", "as_host": true})
	q.send("add_bot", {"seat": 1})
	assert_eq(rig.host.seats[1]["kind"], "empty")


func test_the_game_starts_by_itself_after_a_three_two_one_countdown() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	me.send("add_bot", {"seat": 1})
	me.send("add_bot", {"seat": 2})
	assert_eq(rig.host.phase_name(), "lobby")
	assert_eq(rig.host.next_delay(), -1.0, "nothing is due while seats are free")
	me.send("add_bot", {"seat": 3})
	assert_eq(rig.host.phase_name(), "starting")
	assert_eq(int(me.last("lobby_state")["countdown"]), 3)
	assert_eq(rig.host.next_delay(), 1.0)
	rig.host.step()
	rig.pump()
	assert_eq(int(me.last("lobby_state")["countdown"]), 2)
	rig.host.step()
	rig.pump()
	assert_eq(int(me.last("lobby_state")["countdown"]), 1)
	assert_eq(rig.host.phase_name(), "starting")
	rig.host.step()
	rig.pump()
	assert_eq(rig.host.phase_name(), "playing")
	assert_false(me.of_type("game_view").is_empty())


func test_removing_a_bot_during_the_countdown_cancels_it() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	for i in [1, 2, 3]:
		me.send("add_bot", {"seat": i})
	rig.host.step()
	me.send("remove_bot", {"seat": 3})
	assert_eq(rig.host.phase_name(), "lobby")
	assert_eq(int(me.last("lobby_state")["countdown"]), 0)
	assert_eq(rig.host.next_delay(), -1.0)


func test_a_player_leaving_during_the_countdown_cancels_it() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	var ann: TestPeer = rig.joined("Ann", 1)
	me.send("add_bot", {"seat": 2})
	me.send("add_bot", {"seat": 3})
	assert_eq(rig.host.phase_name(), "starting")
	ann.send("leave")
	assert_eq(rig.host.phase_name(), "lobby")
	assert_eq(rig.host.seats[1]["kind"], "empty")


func test_a_seat_cannot_be_changed_once_the_countdown_runs() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	var ann: TestPeer = rig.joined("Ann", 1)
	me.send("add_bot", {"seat": 2})
	me.send("add_bot", {"seat": 3})
	ann.send("seat_request", {"seat": 2})
	assert_eq(rig.host.seats[1]["name"], "Ann")
	assert_eq(ann.last("action_rejected")["reason"], "starting")


func test_someone_who_never_sat_is_sent_away_when_the_game_starts() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	var watcher: TestPeer = rig.joined("Watcher")
	for i in [1, 2, 3]:
		me.send("add_bot", {"seat": i})
	rig.start_countdown()
	assert_eq(rig.host.phase_name(), "playing")
	assert_eq(watcher.last("join_refused")["reason"], "game_started")


func test_the_table_state_carries_the_room_code_and_addresses() -> void:
	var rig: NetRig = NetRig.new()
	rig.host.room_code = "KFDM"
	rig.host.host_addresses = ["192.168.1.5"]
	var p: TestPeer = rig.joined("Sam")
	var lobby: Dictionary = p.last("lobby_state")
	assert_eq(lobby["room_code"], "KFDM")
	assert_eq(lobby["addresses"], ["192.168.1.5"])
	assert_eq(int(lobby["countdown"]), 0)


func test_join_after_start_is_refused() -> void:
	var rig: NetRig = NetRig.new()
	var me: TestPeer = rig.joined("Host", -1, true)
	rig.start_with_bots(me)
	var late: TestPeer = rig.joined("Late")
	assert_eq(late.last("join_refused")["reason"], "game_started")


func test_a_fifth_player_is_refused() -> void:
	var rig: NetRig = NetRig.new()
	for i in range(4):
		rig.joined("P%d" % i, i)
	var extra: TestPeer = rig.joined("Extra")
	assert_eq(extra.last("join_refused")["reason"], "full")


func test_leave_in_the_lobby_frees_the_seat() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann", 2)
	a.send("leave")
	assert_eq(rig.host.seats[2]["kind"], "empty")


func test_a_dropped_connection_in_the_lobby_frees_the_seat() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann", 2)
	rig.net.drop(a.transport)
	rig.pump()
	assert_eq(rig.host.seats[2]["kind"], "empty")


func test_garbage_and_oversized_messages_are_ignored_and_the_host_keeps_working() -> void:
	var rig: NetRig = NetRig.new()
	var a: TestPeer = rig.joined("Ann")
	a.send_raw("not json at all")
	a.send_raw("{\"v\":1,\"type\":\"seat_request\"")
	a.send_raw("[1,2,3]")
	a.send_raw("{\"v\":1,\"type\":\"join_request\",\"seq\":1,\"name\":\"%s\"}" % "x".repeat(20000))
	a.send("seat_request", {"seat": 0})
	assert_eq(rig.host.seats[0]["name"], "Ann")


func test_a_join_request_with_a_hostile_name_is_cleaned() -> void:
	var rig: NetRig = NetRig.new()
	var p: TestPeer = rig.peer()
	p.send("join_request", {"name": "A\nB\t" + "z".repeat(200)})
	var n: String = p.last("join_accepted")["name"]
	assert_lte(n.length(), 12)
	assert_false(n.contains("\n"))
	var q: TestPeer = rig.peer()
	q.send("join_request", {"name": 12345})
	assert_eq(q.last("join_accepted")["name"], "Player", "a number is not a name")
	var r: TestPeer = rig.peer()
	r.send("join_request", {})
	assert_eq(r.last("join_accepted")["name"], "Player 2", "two nameless players are told apart")
