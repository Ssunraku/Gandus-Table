extends GutTest

var rig: NetRig
var clients: Array[SpadesClient] = []
var sources: Array[RemoteSource] = []
var events: Array = []  # [client index, kind, seat]


## Four humans, one per seat. Sources exist before the game starts so they see the deal.
func _four(seed_value: int = 8) -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	rig = NetRig.new(s, seed_value)
	clients = []
	sources = []
	events = []
	for i in range(4):
		var c: SpadesClient = SpadesClient.new(rig.net.connect_client(i == 0))
		clients.append(c)
		var src: RemoteSource = RemoteSource.new(c)
		sources.append(src)
		var idx: int = i
		src.event.connect(func(kind: String, seat: int, _card: Card) -> void: events.append([idx, kind, seat]))
		c.join("P%d" % i, i == 0)
		c.request_seat(i)
		rig.pump()
	clients[0].start_game()
	rig.pump()


func _bid_everyone() -> void:
	var guard: int = 0
	while rig.host.session.phase() == SpadesGame.Phase.BIDDING and guard < 10:
		guard += 1
		var t: int = rig.host.session.turn_seat()
		assert_true(sources[t].submit_bid(Bid.number(3)))
		rig.pump()


func test_remote_source_rotates_seats_for_each_viewer() -> void:
	_four()
	for i in range(4):
		var v: Dictionary = sources[i].view()
		assert_eq(v["names"][0], "You")
		assert_eq(v["names"][2], "P%d" % ((i + 2) % 4), "partner is opposite")
		assert_eq(v["names"][1], "P%d" % ((i + 1) % 4))
		assert_eq(v["names"][3], "P%d" % ((i + 3) % 4))
		assert_eq((v["hand"] as Array).size(), 13)
		assert_eq(int(v["hand_counts"][2]), 13)
		assert_eq(int(v["dealer_seat"]), posmod(int(rig.host.session.view_for_seat(i)["dealer_seat"]) - i, 4))


func test_remote_source_team_scores_are_own_team_first() -> void:
	_four()
	rig.host.session._game.team_scores = [120, -40] as Array[int]
	rig.host._send_views({"kind": "x", "seat": -1})
	rig.pump()
	assert_eq(sources[0].view()["team_scores"], [120, -40] as Array[int])
	assert_eq(sources[1].view()["team_scores"], [-40, 120] as Array[int])


func test_remote_source_view_matches_the_local_view_shape() -> void:
	_four()
	var local: SpadesSession = SpadesSession.new(SpadesSettings.new(), 3)
	local.start()
	var remote_view: Dictionary = sources[0].view()
	for key in local.view().keys():
		assert_true(remote_view.has(key), "missing key %s" % key)


func test_remote_events_fire_for_deal_play_and_trick() -> void:
	_four()
	var kinds: Array = events.map(func(e: Array) -> String: return e[1])
	assert_has(kinds, "deal")
	_bid_everyone()
	var guard: int = 0
	var saw_trick: bool = false
	while guard < 60 and not saw_trick:
		guard += 1
		var t: int = rig.host.session.turn_seat()
		if rig.host.session.trick_pending():
			assert_true(rig.host.step())
			rig.pump()
			saw_trick = true
			break
		var card: Card = (sources[t].view()["legal"] as Array)[0]
		assert_true(sources[t].submit_play(card))
		rig.pump()
	var kinds2: Array = events.map(func(e: Array) -> String: return e[1])
	assert_has(kinds2, "play")
	assert_has(kinds2, "trick")
	# the play event's seat is relative to each viewer: the seat that played is 0 for itself
	var leader_events: Array = events.filter(func(e: Array) -> bool: return e[1] == "play")
	var first: Array = leader_events[0]
	var first_players: Array = leader_events.filter(func(e: Array) -> bool: return e[2] == 0)
	assert_gt(first_players.size(), 0)
	assert_not_null(first)


func test_submit_play_sends_a_request_and_the_host_answers() -> void:
	_four()
	_bid_everyone()
	var t: int = rig.host.session.turn_seat()
	assert_true(sources[t].human_must_play())
	var other: int = (t + 1) % 4
	assert_false(sources[other].submit_play((sources[other].view()["hand"] as Array)[0]), "not your turn: nothing is sent")
	var card: Card = (sources[t].view()["legal"] as Array)[0]
	assert_true(sources[t].submit_play(card))
	rig.pump()
	assert_eq(sources[t].view()["trick"].size(), 1)
	assert_eq(sources[t].view()["trick"][0]["seat"], 0, "my own card is at my seat")
	assert_eq(sources[other].view()["trick"][0]["seat"], posmod(t - other, 4))


func test_remote_source_has_no_bots_and_never_clears_the_trick_itself() -> void:
	_four()
	assert_true(sources[0].advance_bots().is_empty())
	assert_true(sources[0].is_online())
	sources[0].clear_trick()  # no-op, must not crash


func test_pause_signals_reach_the_source() -> void:
	_four()
	var seen: Array = []
	sources[0].paused_changed.connect(func(p: bool, who: String) -> void: seen.append([p, who]))
	rig.net.drop(clients[2].transport as FakeTransport)
	rig.pump()
	assert_eq(seen, [[true, "P2"]])
	assert_true(sources[0].is_paused())
