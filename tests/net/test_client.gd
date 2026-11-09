extends GutTest
## SpadesClient against a real SpadesHost over the fake network.

var rig: NetRig
var clients: Array[SpadesClient] = []


## Four humans, one per seat; client 0 is the host's own player.
func _four(seed_value: int = 8) -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	rig = NetRig.new(s, seed_value)
	clients = []
	for i in range(4):
		var c: SpadesClient = SpadesClient.new(rig.net.connect_client(i == 0))
		clients.append(c)
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
		clients[t].send_bid(Bid.number(3))
		rig.pump()


func test_join_stores_the_token_and_seat() -> void:
	_four()
	for i in range(4):
		assert_eq(clients[i].my_seat, i)
		assert_eq(clients[i].token.length(), 16)
		assert_eq(clients[i].player_name, "P%d" % i)
	assert_true(clients[0].is_host)
	assert_false(clients[1].is_host)
	assert_true(clients[2].connected)


func test_to_table_state_puts_my_seat_at_the_bottom_for_each_seat() -> void:
	_four()
	for i in range(4):
		var st: TableState = clients[i].to_table_state()
		assert_eq(st.own_hand.size(), 13)
		assert_eq(st.seat_names[TableState.Seat.SOUTH], "P%d" % i, "your own seat shows your own name")
		assert_eq(st.seat_names[TableState.Seat.NORTH], "P%d" % ((i + 2) % 4), "partner opposite")
		assert_eq(st.seat_names[TableState.Seat.WEST], "P%d" % ((i + 1) % 4))
		assert_eq(st.seat_names[TableState.Seat.EAST], "P%d" % ((i + 3) % 4))
		assert_eq(st.get_card_count(TableState.Seat.WEST), 13)


func test_scores_are_listed_own_team_first_for_the_other_team_too() -> void:
	_four()
	rig.host.session._game.team_scores = [120, -40] as Array[int]
	rig.host._send_views({"kind": "x", "seat": -1})
	rig.pump()
	assert_eq(clients[0].to_table_state().team_scores, [120, -40] as Array[int])
	assert_eq(clients[2].to_table_state().team_scores, [120, -40] as Array[int])
	assert_eq(clients[1].to_table_state().team_scores, [-40, 120] as Array[int])
	assert_eq(clients[3].to_table_state().team_scores, [-40, 120] as Array[int])


func test_played_cards_and_turn_are_rotated() -> void:
	_four()
	_bid_everyone()
	var leader: int = rig.host.session.turn_seat()
	var card: Card = clients[leader].view["legal"][0]
	clients[leader].send_play(card)
	rig.pump()
	for i in range(4):
		var st: TableState = clients[i].to_table_state()
		var rel_leader: int = posmod(leader - i, 4)
		var shown: Card = st.get_played(rel_leader as TableState.Seat)
		assert_not_null(shown)
		assert_eq(shown.rank, card.rank)
		assert_eq(shown.suit, card.suit)
		assert_eq(int(st.turn_seat), posmod(rig.host.session.turn_seat() - i, 4))


func test_legal_cards_and_can_play_only_when_it_is_my_turn() -> void:
	_four()
	_bid_everyone()
	var turn: int = rig.host.session.turn_seat()
	for i in range(4):
		var st: TableState = clients[i].to_table_state()
		assert_eq(st.can_play, i == turn)
		assert_eq(st.legal_cards.size() > 0, i == turn)


func test_rejection_is_reported() -> void:
	_four()
	watch_signals(clients[3])
	clients[3].send_play(Card.make(Card.Suit.SPADES, Card.Rank.ACE))  # still bidding: not a play yet
	rig.pump()
	assert_signal_emitted(clients[3], "rejected")
	assert_eq(clients[3].last_rejection, "not_your_turn")


func test_garbage_from_the_host_is_ignored() -> void:
	_four()
	var before: Dictionary = clients[1].view
	var host_t: FakeTransport = rig.net.host_transport()
	for id in rig.net.clients.keys():
		host_t.send_to(id, "garbage")
		host_t.send_to(id, '{"v":1,"type":"game_view","seq":1}')
	rig.pump()
	assert_eq(clients[1].view, before, "a half-empty snapshot is not accepted")


func test_a_dropped_connection_marks_the_client_disconnected() -> void:
	_four()
	rig.net.drop(clients[2].transport as FakeTransport)
	rig.pump()
	assert_false(clients[2].connected)
