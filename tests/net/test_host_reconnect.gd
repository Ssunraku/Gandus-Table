extends GutTest
## Drops, pauses, rejoining, bot replacement and leaving. Seat 0 = host's player, 2 = Ann,
## and (in some tests) seat 1 = Bo. Seed 8: bot seat 1 would bid first if it is a bot.

var rig: NetRig
var me: TestPeer
var ann: TestPeer
var bo: TestPeer


func _start(with_bo: bool = false, settings: SpadesSettings = null) -> void:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	if settings == null:
		s.blind_nil_enabled = false
	rig = NetRig.new(s, 8)
	me = rig.joined("Host", 0, true)
	ann = rig.joined("Ann", 2)
	if with_bo:
		bo = rig.joined("Bo", 1)
	me.send("add_bots")
	me.send("start_game")


func _token(p: TestPeer) -> String:
	return str(p.last("join_accepted")["token"])


func _drop(p: TestPeer) -> void:
	rig.net.drop(p.transport)
	rig.pump()


func _peer_of(seat: int) -> TestPeer:
	return [me, bo, ann][seat] if seat < 3 else null


func _bid_all(blind_nil_seat: int = -1) -> void:
	var guard: int = 0
	while rig.host.session.phase() == SpadesGame.Phase.BIDDING and guard < 40:
		guard += 1
		rig.run_bots()
		if rig.host.session.phase() != SpadesGame.Phase.BIDDING:
			break
		var t: int = rig.host.session.turn_seat()
		var b: Bid = Bid.blind_nil() if t == blind_nil_seat else Bid.number(3)
		_peer_of(t).send("bid", {"bid": Wire.bid_to_dict(b)})


func test_a_drop_pauses_the_game_for_everyone_and_bots_stop() -> void:
	_start()
	assert_true(rig.host.step(), "seat 1 bot bids first")
	_drop(ann)
	assert_true(rig.host.paused)
	assert_eq(me.last("game_paused")["name"], "Ann")
	assert_eq(int(me.last("game_paused")["seat"]), 2)
	assert_false(rig.host.step(), "bots wait while someone is missing")
	me.send("bid", {"bid": Wire.bid_to_dict(Bid.number(3))})
	assert_eq(me.last("action_rejected")["reason"], "paused")


func test_rejoin_with_the_right_token_restores_the_same_seat_and_hand() -> void:
	_start()
	rig.run_bots()
	var hand_before: Array = ann.last("game_view")["hand"]
	var token: String = _token(ann)
	_drop(ann)
	var back: TestPeer = rig.peer()
	back.send("rejoin_request", {"token": token})
	assert_eq(int(back.last("join_accepted")["seat"]), 2)
	assert_eq(back.last("game_view")["hand"], hand_before)
	assert_false(rig.host.paused)
	assert_eq(me.of_type("game_resumed").size(), 1)
	assert_true(rig.host.session.is_human(2))


func test_rejoin_with_a_wrong_token_is_refused_and_the_game_stays_paused() -> void:
	_start()
	_drop(ann)
	var imposter: TestPeer = rig.peer()
	imposter.send("rejoin_request", {"token": "0000000000000000"})
	assert_eq(imposter.last("join_refused")["reason"], "bad_token")
	imposter.send("rejoin_request", {})
	imposter.send("rejoin_request", {"token": 5})
	assert_eq(imposter.of_type("join_refused").size(), 3)
	assert_true(rig.host.paused)
	assert_true(imposter.of_type("game_view").is_empty(), "no snapshot for an imposter")


func test_a_token_cannot_be_used_while_its_owner_is_still_connected() -> void:
	_start()
	var token: String = _token(ann)
	var thief: TestPeer = rig.peer()
	thief.send("rejoin_request", {"token": token})
	assert_eq(thief.last("join_refused")["reason"], "bad_token")
	assert_true(thief.of_type("game_view").is_empty())


func test_rejoin_after_being_replaced_by_a_bot_is_refused() -> void:
	_start()
	var token: String = _token(ann)
	_drop(ann)
	me.send("replace_with_bot", {"seat": 2})
	var back: TestPeer = rig.peer()
	back.send("rejoin_request", {"token": token})
	assert_eq(back.last("join_refused")["reason"], "bad_token")


func test_host_can_replace_a_dropped_player_with_a_bot_and_the_game_resumes() -> void:
	_start()
	_drop(ann)
	me.send("replace_with_bot", {"seat": 2})
	assert_false(rig.host.paused)
	assert_eq(rig.host.seats[2]["kind"], "bot")
	assert_false(rig.host.session.is_human(2))
	assert_eq(me.of_type("game_resumed").size(), 1)
	assert_true(rig.host.step(), "the bots play on")


func test_replacing_a_connected_player_is_refused() -> void:
	_start()
	me.send("replace_with_bot", {"seat": 2})
	assert_eq(me.last("action_rejected")["reason"], "seat_not_dropped")
	assert_eq(rig.host.seats[2]["kind"], "human")


func test_only_the_host_can_replace_with_a_bot() -> void:
	_start(true)
	_drop(ann)
	bo.send("replace_with_bot", {"seat": 2})
	assert_eq(rig.host.seats[2]["kind"], "human")
	assert_true(rig.host.paused)


func test_leaving_on_purpose_hands_the_seat_to_a_bot_without_pausing() -> void:
	_start()
	ann.send("leave")
	assert_false(rig.host.paused)
	assert_eq(rig.host.seats[2]["kind"], "bot")
	assert_false(rig.host.session.is_human(2))
	assert_true(rig.host.step() or rig.host.session.must_bid(0) or rig.host.session.must_play(0))


func test_drop_during_bidding() -> void:
	_start()
	assert_eq(rig.host.session.phase(), SpadesGame.Phase.BIDDING)
	var token: String = _token(ann)
	_drop(ann)
	var back: TestPeer = rig.peer()
	back.send("rejoin_request", {"token": token})
	assert_eq(back.last("game_view")["phase"], SpadesGame.Phase.BIDDING)
	assert_false(rig.host.paused)


func test_drop_during_the_blind_nil_swap_keeps_the_swap_pending() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = true
	_start(false, s)
	_bid_all(2)
	assert_eq(rig.host.session.phase(), SpadesGame.Phase.SWAP)
	var token: String = _token(ann)
	_drop(ann)
	assert_true(rig.host.paused)
	var back: TestPeer = rig.peer()
	back.send("rejoin_request", {"token": token})
	assert_true(back.last("game_view")["must_swap"])
	var mine: Array = back.last("game_view")["hand"]
	back.send("swap", {"give": [mine[0]], "positions": [0]})
	assert_false(back.last("game_view")["must_swap"])


func test_drop_in_the_middle_of_a_trick() -> void:
	_start()
	_bid_all()
	rig.run_bots()
	var turn: int = rig.host.session.turn_seat()
	var p: TestPeer = _peer_of(turn)
	var card: Dictionary = (p.last("game_view")["legal"] as Array)[0]
	p.send("play_card", {"card": card})
	var on_table: int = (rig.host.session.shown_trick() as Array).size()
	var token: String = _token(ann)  # (never drop the host: that ends the game)
	_drop(ann)
	assert_true(rig.host.paused)
	assert_eq(rig.host.session.shown_trick().size(), on_table, "the table is untouched while paused")
	var back: TestPeer = rig.peer()
	back.send("rejoin_request", {"token": token})
	assert_eq((back.last("game_view")["trick"] as Array).size(), on_table)
	assert_false(rig.host.paused)


func test_host_disconnect_closes_the_game_for_everyone() -> void:
	_start()
	_drop(me)
	assert_eq(rig.host.phase_name(), "closed")
	assert_eq(ann.last("game_closed")["reason"], "host_left")
	assert_false(rig.host.step())


func test_two_players_dropped_game_resumes_only_when_both_are_back() -> void:
	_start(true)
	var t_ann: String = _token(ann)
	var t_bo: String = _token(bo)
	_drop(ann)
	_drop(bo)
	var a2: TestPeer = rig.peer()
	a2.send("rejoin_request", {"token": t_ann})
	assert_true(rig.host.paused, "Bo is still missing")
	var b2: TestPeer = rig.peer()
	b2.send("rejoin_request", {"token": t_bo})
	assert_false(rig.host.paused)
