extends GutTest


func _session() -> SpadesSession:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	var session: SpadesSession = SpadesSession.new(s, 5)
	session.start()
	return session


func test_local_source_forwards_view_and_actions() -> void:
	var session: SpadesSession = _session()
	var source: LocalSource = LocalSource.new(session)
	assert_false(source.is_online())
	assert_eq(source.view().keys().size(), session.view().keys().size())
	assert_eq((source.view()["hand"] as Array).size(), 13)
	assert_eq(source.human_must_bid(), session.human_must_bid())
	assert_eq(source.turn_seat(), session.turn_seat())
	assert_eq(source.phase(), session.phase())
	assert_eq(source.round_number(), 1)


func test_the_base_game_source_is_inert() -> void:
	var g: GameSource = GameSource.new()
	assert_false(g.human_must_play())
	assert_true(g.advance_bots().is_empty())
	assert_false(g.submit_bid(Bid.number(3)))


func test_game_screen_still_plays_a_whole_round_through_a_local_source() -> void:
	var g: GameScreen = GameScreen.new()
	g.pace = 0.0
	add_child_autofree(g)
	g.size = Vector2(1280, 720)
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	g.start(s, 11)
	assert_true(g.source is LocalSource)
	var guard: int = 0
	while not g.source.round_over() and guard < 3000:
		guard += 1
		if g.step():
			continue
		if g.bid_panel.visible:
			g.bid_panel.bid_chosen.emit(Bid.number(3))
		elif g.source.human_must_play():
			g.table.human_played.emit((g.source.view()["legal"] as Array)[0])
	assert_true(g.source.round_over())
