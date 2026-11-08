extends GutTest
## Whole games over the fake network: real host, real clients, no screens.

var rig: NetRig
var clients: Array[SpadesClient] = []
var players: Array[AutoPlayer] = []
var seat_of_client: Array[int] = []
var checked_messages: int = 0
var saw_player_points: bool = false


## `humans` are the seats played by people; the rest become bots. Seat 0 is the host's player.
func _setup(humans: Array[int], settings: SpadesSettings = null, seed_value: int = 8) -> void:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	s.blind_nil_enabled = false
	rig = NetRig.new(s, seed_value)
	clients = []
	players = []
	seat_of_client = []
	for seat in humans:
		var c: SpadesClient = SpadesClient.new(rig.net.connect_client(seat == 0))
		clients.append(c)
		players.append(AutoPlayer.new(c))
		seat_of_client.append(seat)
		c.join("P%d" % seat, seat == 0)
		c.request_seat(seat)
		rig.pump()
	clients[0].add_bots()
	clients[0].start_game()
	rig.pump()


## Cards ({"s","r"} dictionaries) found anywhere inside a value, as "s,r" strings.
func _cards_in(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("s") and d.has("r") and d.size() == 2:
			out.append("%d,%d" % [int(d["s"]), int(d["r"])])
		else:
			for k in d.keys():
				out.append_array(_cards_in(d[k]))
	elif v is Array:
		for x in v:
			out.append_array(_cards_in(x))
	return out


## Every game_view a client has just received must hold only cards that client may see.
func _check_privacy(client: SpadesClient, seat: int, seen: Dictionary) -> void:
	var raws: Array = seen[client]
	for text in raws:
		var m: Dictionary = Protocol.decode(text)
		if m.get("type") != "game_view":
			continue
		checked_messages += 1
		var game: SpadesGame = rig.host.session._game
		for j in range(4):
			if j == seat:
				continue
			var other_hand: Array[String] = []
			for c in game.hand_of(j):
				other_hand.append("%d,%d" % [int(c.suit), int(c.rank)])
			for key in m.keys():
				if key in ["trick", "last_trick", "swap"]:
					continue
				for card in _cards_in(m[key]):
					# a card in another seat's real hand must never be in a private field
					assert_false(other_hand.has(card), "seat %d was sent seat %d's card in field %s" % [seat, j, key])
	raws.clear()


## Plays until every client sees game over (or nothing can move). Returns true if finished.
func _play(max_rounds_of_loop: int = 30000, drop_at: int = -1, drop_client: int = -1) -> bool:
	var seen: Dictionary = {}
	for c in clients:
		seen[c] = []
		var list: Array = seen[c]
		c.transport.message_received.connect(func(_p: int, t: String) -> void: list.append(t))
	var token: String = ""
	for i in range(max_rounds_of_loop):
		rig.pump()
		for k in range(clients.size()):
			_check_privacy(clients[k], seat_of_client[k], seen)
			var v: Dictionary = clients[k].view
			if not v.is_empty() and (v["round_result"] as Dictionary).has("player_points"):
				saw_player_points = true
		var done: bool = true
		for c in clients:
			if c.view.is_empty() or not c.view["game_over"]:
				done = false
		if done:
			return true
		if i == drop_at and drop_client >= 0:
			token = clients[drop_client].token
			rig.net.drop(clients[drop_client].transport as FakeTransport)
			rig.pump()
			assert_true(rig.host.paused, "the game pauses while a player is away")
			assert_false(rig.host.step())
			# the player comes back on a new connection and takes the same seat
			var back: SpadesClient = SpadesClient.new(rig.net.connect_client())
			rig.pump()
			back.rejoin(token)
			rig.pump()
			assert_eq(back.my_seat, seat_of_client[drop_client])
			assert_false(rig.host.paused)
			clients[drop_client] = back
			players[drop_client] = AutoPlayer.new(back)
			var list2: Array = []
			seen[back] = list2
			back.transport.message_received.connect(func(_p: int, t: String) -> void: list2.append(t))
		var did: bool = false
		if rig.host.step():
			did = true
		rig.pump()
		for p in players:
			if p.act():
				did = true
				rig.pump()
		if not did:
			return false
	return false


func _assert_scores_agree() -> void:
	var game: SpadesGame = rig.host.session._game
	for k in range(clients.size()):
		var v: Dictionary = clients[k].view
		assert_eq(v["team_scores"], game.team_scores, "client %d final scores" % k)
		assert_eq(v["winner_team"], game.winner_team)
	assert_ne(game.winner_team, -1)


func test_four_humans_play_a_whole_game_to_the_end() -> void:
	_setup([0, 1, 2, 3] as Array[int])
	assert_true(_play(), "the game reaches the end")
	_assert_scores_agree()
	assert_gt(checked_messages, 100, "the privacy check really ran")


func test_two_humans_and_two_bots_play_a_whole_game() -> void:
	_setup([0, 2] as Array[int])
	assert_true(_play())
	_assert_scores_agree()
	assert_gt(checked_messages, 100)


func test_a_player_drops_and_rejoins_in_the_middle_and_the_game_still_finishes() -> void:
	_setup([0, 1, 2, 3] as Array[int])
	assert_true(_play(30000, 150, 2))
	_assert_scores_agree()


func test_exact_bids_mode_works_over_the_network() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.exact_mode = SpadesSettings.ExactMode.EASY
	_setup([0, 2] as Array[int], s)
	assert_true(_play())
	_assert_scores_agree()
	assert_true(saw_player_points, "round results carried each player's points")
