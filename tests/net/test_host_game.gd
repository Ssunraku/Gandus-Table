extends GutTest
## The host's game flow with two humans (seat 0 = host's player, seat 2 = Ann) and two bots.

var rig: NetRig
var me: TestPeer
var ann: TestPeer


func _start(settings: SpadesSettings = null, seed_value: int = 8) -> void:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	s.blind_nil_enabled = false if settings == null else s.blind_nil_enabled
	rig = NetRig.new(s, seed_value)
	me = rig.joined("Host", 0, true)
	ann = rig.joined("Ann", 2)
	rig.start_with_bots(me)


func _peer_of(seat: int) -> TestPeer:
	return me if seat == 0 else ann


## Bots act, humans bid 3, until the playing phase starts.
func _bid_all() -> void:
	var guard: int = 0
	while rig.host.session.phase() == SpadesGame.Phase.BIDDING and guard < 40:
		guard += 1
		rig.run_bots()
		if rig.host.session.phase() != SpadesGame.Phase.BIDDING:
			break
		_peer_of(rig.host.session.turn_seat()).send("bid", {"bid": Wire.bid_to_dict(Bid.number(3))})


## Everything that looks like a card ({"s":..,"r":..}) inside a value, as "s,r" strings.
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


func test_start_sends_each_human_a_snapshot_with_only_their_own_hand() -> void:
	_start()
	var a: Dictionary = me.last("game_view")
	var b: Dictionary = ann.last("game_view")
	assert_eq(int(a["seat"]), 0)
	assert_eq(int(b["seat"]), 2)
	var mine: Array[String] = _cards_in(a["hand"])
	var hers: Array[String] = _cards_in(b["hand"])
	assert_eq(mine.size(), 13)
	assert_eq(hers.size(), 13)
	for c in hers:
		assert_false(mine.has(c))
	assert_eq(a["event"]["kind"], "deal")


func test_snapshot_never_contains_other_seats_cards_in_any_field() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	for p in [me, ann]:
		var snap: Dictionary = p.last("game_view")
		var hand: Array[String] = _cards_in(snap["hand"])
		for key in snap.keys():
			if key in ["hand", "legal", "trick", "last_trick", "swap"]:
				continue
			assert_eq(_cards_in(snap[key]).size(), 0, "card found in field %s" % key)
		for c in _cards_in(snap["legal"]):
			assert_true(hand.has(c), "a legal card must be in the hand")
	assert_eq(me.last("game_view")["hand_counts"]["2"], 13, "others only appear as counts")


func test_a_bid_out_of_turn_is_rejected_and_changes_nothing() -> void:
	_start()
	rig.run_bots()  # seed 8: bot seat 1 bids, then it is Ann's (seat 2) turn
	assert_true(rig.host.session.must_bid(2))
	me.send("bid", {"bid": Wire.bid_to_dict(Bid.number(4))})
	assert_eq(me.last("action_rejected")["reason"], "bid_refused")
	assert_true(rig.host.session.must_bid(2))
	assert_false(rig.host.session.view_for_seat(0)["bids"].has(0))


func test_a_malformed_bid_is_rejected() -> void:
	_start()
	rig.run_bots()
	ann.send("bid", {"bid": {"k": 0, "n": 99}})
	ann.send("bid", {"bid": "three"})
	ann.send("bid", {})
	assert_eq(ann.of_type("action_rejected").size(), 3)
	assert_true(rig.host.session.must_bid(2))


func test_a_play_for_another_seat_is_ignored_because_the_seat_comes_from_the_connection() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	assert_true(rig.host.session.is_human(turn))
	var other: TestPeer = _peer_of(2 if turn == 0 else 0)
	var card: Dictionary = (_peer_of(turn).last("game_view")["legal"] as Array)[0]
	other.send("play_card", {"card": card, "seat": turn})
	assert_eq(other.last("action_rejected")["reason"], "not_your_turn")
	assert_true(rig.host.session.must_play(turn), "nothing changed")


func test_playing_a_card_not_in_hand_is_rejected() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	var other_hand: Array = _peer_of(2 if turn == 0 else 0).last("game_view")["hand"]
	_peer_of(turn).send("play_card", {"card": other_hand[0]})
	assert_eq(_peer_of(turn).last("action_rejected")["reason"], "not_in_hand")
	assert_true(rig.host.session.must_play(turn))


func test_playing_an_illegal_card_is_rejected_and_the_legal_list_is_unchanged() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	var p: TestPeer = _peer_of(turn)
	var snap: Dictionary = p.last("game_view")
	var legal: Array[String] = _cards_in(snap["legal"])
	var illegal: Dictionary = {}
	for c in snap["hand"]:
		if not legal.has("%d,%d" % [int(c["s"]), int(c["r"])]):
			illegal = c
			break
	assert_false(illegal.is_empty(), "this seed leads with a hand that has an illegal card (spades before broken)")
	p.send("play_card", {"card": illegal})
	assert_eq(p.last("action_rejected")["reason"], "illegal_card")
	assert_eq((rig.host.session.view_for_seat(turn)["legal"] as Array).size(), legal.size())


func test_a_garbage_card_is_rejected() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	var p: TestPeer = _peer_of(turn)
	p.send("play_card", {"card": {"s": 9, "r": 99}})
	p.send("play_card", {"card": "AS"})
	p.send("play_card", {})
	assert_eq(p.of_type("action_rejected").size(), 3)


func test_step_advances_bots_and_stops_at_a_humans_turn() -> void:
	_start()
	assert_true(rig.host.step(), "seat 1 is a bot and bids first")
	assert_false(rig.host.step(), "now it is Ann's turn")


func test_a_legal_play_updates_every_players_snapshot_with_an_event() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	var p: TestPeer = _peer_of(turn)
	var other: TestPeer = _peer_of(2 if turn == 0 else 0)
	var card: Dictionary = (p.last("game_view")["legal"] as Array)[0]
	var before: int = other.of_type("game_view").size()
	var on_table: int = (other.last("game_view")["trick"] as Array).size()  # a bot may have led
	p.send("play_card", {"card": card})
	assert_eq(other.of_type("game_view").size(), before + 1)
	var ev: Dictionary = other.last("game_view")["event"]
	assert_eq(ev["kind"], "play")
	assert_eq(int(ev["seat"]), turn)
	assert_eq((other.last("game_view")["trick"] as Array).size(), on_table + 1)
	assert_eq(_cards_in(p.last("game_view")["hand"]).size(), 12)


func test_next_round_before_the_round_is_over_changes_nothing() -> void:
	_start()
	_bid_all()
	var n: int = rig.host.session.round_number()
	me.send("next_round")
	ann.send("next_round")
	assert_eq(rig.host.session.round_number(), n)


func test_blind_nil_swap_between_two_humans_hides_the_partners_cards() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = true
	_start(s)
	# Ann (seat 2) bids Blind Nil; the others bid normally.
	var guard: int = 0
	while rig.host.session.phase() == SpadesGame.Phase.BIDDING and guard < 40:
		guard += 1
		rig.run_bots()
		if rig.host.session.phase() != SpadesGame.Phase.BIDDING:
			break
		var t: int = rig.host.session.turn_seat()
		_peer_of(t).send("bid", {"bid": Wire.bid_to_dict(Bid.blind_nil() if t == 2 else Bid.number(3))})
	assert_eq(rig.host.session.phase(), SpadesGame.Phase.SWAP)
	var hosts_hand: Array[String] = _cards_in(me.last("game_view")["hand"])
	for raw_text in ann.raw:
		var m: Dictionary = Protocol.decode(raw_text)
		if m.get("type") == "game_view":
			for c in _cards_in(m["hand"]):
				assert_false(hosts_hand.has(c), "the partner's cards are never sent")
	assert_true(ann.last("game_view")["must_swap"])
	var mine: Array = ann.last("game_view")["hand"]
	ann.send("swap", {"give": [mine[0]], "positions": [0]})
	var after: Dictionary = ann.last("game_view")
	assert_false(after["must_swap"])
	var received: Array[String] = _cards_in(after["swap"])
	assert_gt(received.size(), 0)
	assert_eq(_cards_in(after["hand"]).size(), 13)
	var from_partner: int = 0
	for c in _cards_in(after["hand"]):
		if hosts_hand.has(c):
			from_partner += 1
	assert_eq(from_partner, 1, "only the one swapped card came from the partner")


func test_every_snapshot_carries_the_room_code_and_addresses() -> void:
	_start()
	rig.host.room_code = "ABCD"
	rig.host.host_addresses = ["192.168.1.5"] as Array[String]
	rig.host._send_views({"kind": "x", "seat": -1})
	rig.pump()
	var snap: Dictionary = ann.last("game_view")
	assert_eq(snap["room_code"], "ABCD")
	assert_eq(snap["addresses"], ["192.168.1.5"])
