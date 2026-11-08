extends GutTest

var finished: bool = false


func before_each() -> void:
	finished = false


func _screen(settings: SpadesSettings, seed_value: int, pace: float = 0.0) -> GameScreen:
	var gs: GameScreen = GameScreen.new()
	gs.pace = pace
	add_child_autofree(gs)
	gs.size = Vector2(1280, 720)
	gs.game_finished.connect(func(_w: int, _s: Array[int]) -> void: finished = true)
	gs.start(settings, seed_value)
	return gs


func _button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


## Does whatever a person would do next. Returns false if nothing at all can be done.
func _human_step(gs: GameScreen) -> bool:
	if gs.step():
		return true
	if gs.bid_panel.visible:
		var look: Button = _button(gs.bid_panel, "Look at my cards")
		if look != null:
			look.pressed.emit()
			return true
		var three: Button = _button(gs.bid_panel, "3")
		three.pressed.emit()
		return true
	if gs.swap_panel.visible:
		gs.swap_panel.confirm_button.pressed.emit()
		return true
	if gs.summary.visible:
		gs.summary.next_button.pressed.emit()
		return true
	if gs.session.human_must_play():
		var legal: Array[Card] = gs.session.view()["legal"]
		gs.table.human_played.emit(legal[0])
		return true
	return false


func _fast_settings() -> SpadesSettings:
	var s: SpadesSettings = SpadesSettings.new()
	s.win_score = 100
	s.lose_score = -100
	return s


func test_a_whole_game_can_be_played_through_the_screen() -> void:
	var gs: GameScreen = _screen(_fast_settings(), 7)
	var n: int = 0
	while not finished and n < 4000:
		assert_true(_human_step(gs), "the screen got stuck")
		n += 1
	assert_true(finished, "game_finished was never emitted")


func test_hand_is_face_down_until_you_choose_when_blind_nil_is_on() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1)
	while gs.step():
		pass
	assert_true(gs.bid_panel.visible)
	assert_false((gs.table.hand.get_child(0) as CardView).face_up)
	_button(gs.bid_panel, "Look at my cards").pressed.emit()
	assert_true((gs.table.hand.get_child(0) as CardView).face_up)
	assert_not_null(_button(gs.bid_panel, "3"))
	assert_null(_button(gs.bid_panel, "Blind Nil"))


func test_hand_is_face_up_from_the_start_when_blind_nil_is_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	var gs: GameScreen = _screen(s, 1)
	while gs.step():
		pass
	assert_true((gs.table.hand.get_child(0) as CardView).face_up)
	assert_not_null(_button(gs.bid_panel, "3"))


func test_tapping_a_greyed_card_changes_nothing() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	var gs: GameScreen = _screen(s, 2)
	var found: bool = false
	for i in range(600):
		if gs.session.human_must_play():
			var hand: Array[Card] = gs.session.view()["hand"]
			var legal: Array[Card] = gs.session.view()["legal"]
			for idx in range(hand.size()):
				var ok: bool = false
				for l in legal:
					if l.suit == hand[idx].suit and l.rank == hand[idx].rank:
						ok = true
				if not ok:
					var pt: Vector2 = gs.table.hand.card_rect(idx).position + Vector2(5, 100)
					var turn_before: int = gs.session.turn_seat()
					gs.table.hand.handle_tap(pt)
					gs.table.hand.handle_tap(pt)
					assert_eq(gs.session.view()["hand"].size(), hand.size())
					assert_eq(gs.session.turn_seat(), turn_before)
					assert_eq(gs.table.hand.selected_index, -1)
					found = true
					break
		if found:
			break
		assert_true(_human_step(gs))
	assert_true(found)


func test_blind_nil_then_swapping_two_cards_keeps_13_cards_and_starts_play() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 3)
	while gs.step():
		pass
	_button(gs.bid_panel, "Blind Nil").pressed.emit()
	while gs.step():
		pass
	assert_true(gs.swap_panel.visible)
	assert_true(gs.partner_picker.visible)
	gs.table.hand.handle_tap(gs.table.hand.card_rect(0).position + Vector2(5, 100))
	gs.table.hand.handle_tap(gs.table.hand.card_rect(4).position + Vector2(5, 100))
	gs.partner_picker.toggle(1)
	gs.partner_picker.toggle(6)
	assert_eq(gs.swap_panel.confirm_button.text, "Confirm swap")
	gs.swap_panel.confirm_button.pressed.emit()
	assert_false(gs.swap_panel.visible)
	assert_eq(gs.session.phase(), SpadesGame.Phase.PLAYING)
	assert_eq(gs.session.view()["hand"].size(), 13)
	assert_eq(gs.table.hand.card_count(), 13)


func test_blind_nil_then_skipping_the_swap_continues() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 3)
	while gs.step():
		pass
	_button(gs.bid_panel, "Blind Nil").pressed.emit()
	while gs.step():
		pass
	assert_eq(gs.swap_panel.confirm_button.text, "Skip swap")
	gs.swap_panel.confirm_button.pressed.emit()
	assert_eq(gs.session.phase(), SpadesGame.Phase.PLAYING)
	assert_eq(gs.table.hand.card_count(), 13)


func test_resizing_between_steps_never_changes_card_counts() -> void:
	var gs: GameScreen = _screen(_fast_settings(), 9)
	var sizes: Array[Vector2] = [Vector2(720, 1280), Vector2(1280, 720), Vector2(800, 600), Vector2(2000, 1200)]
	for i in range(300):
		if finished:
			break
		assert_true(_human_step(gs))
		gs.size = sizes[i % sizes.size()]
		gs.table.relayout()
		assert_eq(gs.table.hand.card_count(), gs.session.view()["hand"].size())
		assert_eq(gs.table.hand.get_child_count(), gs.table.hand.card_count())


func test_menu_exit_emits_the_signal_and_stops_the_game() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1)
	watch_signals(gs)
	gs.table.menu_button.pressed.emit()
	assert_true(gs.menu_panel.visible)
	_button(gs.menu_panel, "Exit to start").pressed.emit()
	assert_signal_emitted(gs, "exit_to_start")
	assert_false(gs.step())


func test_menu_resume_continues_the_game() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1)
	gs.table.menu_button.pressed.emit()
	assert_false(gs.step(), "the game is paused while the menu is open")
	_button(gs.menu_panel, "Resume").pressed.emit()
	assert_false(gs.menu_panel.visible)
	assert_true(gs.step())


func test_a_timer_that_fires_after_leaving_does_nothing() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1, 0.02)
	gs.table.menu_button.pressed.emit()
	_button(gs.menu_panel, "Exit to start").pressed.emit()
	var before: int = (gs.session.view()["bids"] as Dictionary).size()
	await wait_seconds(0.4)
	assert_eq((gs.session.view()["bids"] as Dictionary).size(), before)


func test_info_button_opens_and_closes_the_info_panel() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1)
	gs.table.info_button.pressed.emit()
	assert_true(gs.info_panel.visible)
	_button(gs.info_panel, "Close").pressed.emit()
	assert_false(gs.info_panel.visible)


func test_partner_picker_stays_clear_of_the_corner_widgets_in_portrait() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 3)
	gs.size = Vector2(720, 1280)
	while gs.step():
		pass
	_button(gs.bid_panel, "Blind Nil").pressed.emit()
	while gs.step():
		pass
	assert_true(gs.partner_picker.visible)
	var l: Dictionary = TableLayout.compute(gs.size)
	var fan: Rect2 = l["opponent_fan_rects"][TableState.Seat.NORTH]
	var r: Rect2 = gs.partner_picker.get_rect()
	assert_gte(r.position.x, fan.position.x - 1.0)
	assert_lte(r.end.x, fan.end.x + 1.0)


func _seed_with_redeal(has_redeal: bool) -> int:
	for s in range(1, 200):
		var probe: SpadesSession = SpadesSession.new(SpadesSettings.new(), s)
		probe.start()
		if probe.redeal_messages().is_empty() != has_redeal:
			return s
	return -1


func test_a_redeal_is_announced_to_the_player() -> void:
	var s: int = _seed_with_redeal(true)
	assert_ne(s, -1)
	var gs: GameScreen = _screen(SpadesSettings.new(), s)
	assert_true(gs.notice_panel.visible)
	assert_string_contains(gs.notice_label.text, "Redeal")
	assert_string_contains(gs.notice_label.text, " has no ")


func test_no_redeal_means_no_announcement() -> void:
	var s: int = _seed_with_redeal(false)
	assert_ne(s, -1)
	var gs: GameScreen = _screen(SpadesSettings.new(), s)
	assert_false(gs.notice_panel.visible)


func test_the_pause_menu_blocks_taps_on_the_table() -> void:
	var gs: GameScreen = _screen(SpadesSettings.new(), 1)
	assert_false(gs.input_blocker.visible)
	gs.table.menu_button.pressed.emit()
	assert_true(gs.input_blocker.visible)
	assert_eq(gs.input_blocker.mouse_filter, Control.MOUSE_FILTER_STOP)
	for b in gs.menu_panel.find_children("*", "Button", true, false):
		if (b as Button).text == "Resume":
			(b as Button).pressed.emit()
	assert_false(gs.input_blocker.visible)


func test_a_finished_trick_is_swept_to_its_winner_when_cleared() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	var gs: GameScreen = _screen(s, 2)
	for i in range(400):
		if gs.session.trick_pending():
			break
		assert_true(_human_step(gs))
	assert_true(gs.session.trick_pending())
	await wait_seconds(Table.PLAY_FLIGHT + 0.2)
	assert_eq(gs.table.played_view_count(), 4)
	assert_true(gs.step())
	assert_eq(gs.table.played_view_count(), 0)
	assert_eq(gs.table.sweeping_count(), 4)
