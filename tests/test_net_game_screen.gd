extends GutTest
## The table screen driven by a host over the fake network (host's player = seat 0, Ann = seat 2,
## two bots). pace = 0 and no timers: the test pumps the network and steps the host itself.

var rig: NetRig
var me: SpadesClient
var ann: SpadesClient
var src: RemoteSource
var screen: GameScreen
var ann_player: AutoPlayer
var me_auto: AutoPlayer = null  # set when the host's own player should play by itself
var finished: Array = []


func _start(settings: SpadesSettings = null) -> void:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	if settings == null:
		s.blind_nil_enabled = false
	rig = NetRig.new(s, 8)
	me = SpadesClient.new(rig.net.connect_client(true))
	ann = SpadesClient.new(rig.net.connect_client())
	me.join("Host", true)
	me.request_seat(0)
	ann.join("Ann")
	ann.request_seat(2)
	rig.pump()
	me.add_bots()
	me.start_game()
	rig.pump()
	src = RemoteSource.new(me)
	screen = GameScreen.new()
	screen.pace = 0.0
	add_child_autofree(screen)
	screen.size = Vector2(1280, 720)
	screen.start_online(src)
	ann_player = AutoPlayer.new(ann)
	finished = []
	screen.game_finished.connect(func(w: int, sc: Array[int]) -> void: finished.append([w, sc]))


## Advances the world until `me` has to act (or `cond` is true). Returns false if stuck.
func _until(cond: Callable, limit: int = 3000) -> bool:
	for i in range(limit):
		rig.pump()
		if cond.call():
			return true
		var did: bool = rig.host.step()
		rig.pump()
		if ann_player.act():
			did = true
			rig.pump()
		if me_auto != null and me_auto.act():
			did = true
			rig.pump()
		if not did:
			return cond.call()
	return false


func _bid_my_turn() -> void:
	assert_true(_until(func() -> bool: return src.human_must_bid()))
	assert_true(screen.bid_panel.visible, "the bid panel opens on my turn")
	screen.bid_panel.bid_chosen.emit(Bid.number(3))
	rig.pump()


func test_net_screen_shows_the_players_hand_and_turn() -> void:
	_start()
	assert_eq(screen.table.state.own_hand.size(), 13)
	assert_eq(screen.table.state.seat_names[TableState.Seat.NORTH], "Ann", "partner Ann sits opposite me")
	_bid_my_turn()
	assert_true(_until(func() -> bool: return src.human_must_play()))
	assert_true(screen.table.state.can_play)
	assert_gt(screen.table.state.legal_cards.size(), 0)


func test_net_screen_animates_a_remote_card_play() -> void:
	_start()
	_bid_my_turn()
	# run until someone else has put a card on the table
	assert_true(_until(func() -> bool: return (src.view()["trick"] as Array).size() >= 1 and not src.human_must_play() or src.human_must_play()))
	assert_true(_until(func() -> bool: return screen.table.played_view_count() + screen.table.flying_count() >= 1))


func test_my_own_play_goes_through_the_host() -> void:
	_start()
	_bid_my_turn()
	assert_true(_until(func() -> bool: return src.human_must_play()))
	var card: Card = screen.table.state.legal_cards[0]
	var before: int = (src.view()["trick"] as Array).size()
	screen.table.human_played.emit(card)
	rig.pump()
	assert_eq((src.view()["trick"] as Array).size(), before + 1, "the host accepted it")
	assert_eq(screen.table.state.own_hand.size(), 12)


func test_an_illegal_play_is_refused_by_the_host_and_the_hand_is_redrawn() -> void:
	_start()
	_bid_my_turn()
	assert_true(_until(func() -> bool: return src.human_must_play()))
	var legal: Array[Card] = screen.table.state.legal_cards
	var illegal: Card = null
	for c in screen.table.state.own_hand:
		var is_legal: bool = false
		for l in legal:
			if l.suit == c.suit and l.rank == c.rank:
				is_legal = true
		if not is_legal:
			illegal = c
			break
	assert_not_null(illegal, "this seed gives a hand with an illegal card")
	src.client.send_play(illegal)  # (the screen would not offer it; ask the host directly)
	rig.pump()
	assert_eq(src.client.last_rejection, "illegal_card")
	assert_eq(screen.table.state.own_hand.size(), 13)


func test_net_screen_shows_the_summary_and_next_round_sends_a_request() -> void:
	_start()
	me_auto = AutoPlayer.new(me)
	me_auto.auto_next_round = false  # the button must start the next round
	var ok: bool = _until(func() -> bool: return src.round_over() and screen.summary.visible, 6000)
	assert_true(ok, "the round ends and the summary shows")
	assert_true(screen.summary.visible)
	var round_before: int = src.round_number()
	screen.summary.next_button.pressed.emit()
	rig.pump()
	assert_eq(src.round_number(), round_before + 1, "the host dealt the next round")
	assert_false(screen.summary.visible)


func test_net_screen_pause_notice_shows_and_hides() -> void:
	_start()
	var token: String = ann.token
	rig.net.drop(ann.transport as FakeTransport)
	rig.pump()
	assert_true(screen.notice_panel.visible)
	assert_string_contains(screen.notice_label.text, "Ann")
	var back: SpadesClient = SpadesClient.new(rig.net.connect_client())
	rig.pump()
	back.rejoin(token)
	rig.pump()
	assert_false(screen.notice_panel.visible)


func test_net_screen_game_over_emits_game_finished() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	s.win_score = 100
	_start(s)
	me_auto = AutoPlayer.new(me)
	var ok: bool = _until(func() -> bool:
		if screen.summary.visible and src.game_over():
			screen.summary.next_button.pressed.emit()
		return not finished.is_empty(), 20000)
	assert_true(ok, "the game ends")
	assert_eq(finished.size(), 1)
	assert_true(int(finished[0][0]) in [0, 1])
