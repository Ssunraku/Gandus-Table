extends GutTest


func _button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _all_text(root: Node) -> String:
	var parts: Array[String] = []
	for l in root.find_children("*", "Label", true, false):
		parts.append((l as Label).text)
	for b in root.find_children("*", "Button", true, false):
		parts.append((b as Button).text)
	return " | ".join(parts)


# ---------- BidPanel ----------

func test_bid_panel_without_nil_has_no_nil_button() -> void:
	var p: BidPanel = BidPanel.new()
	add_child_autofree(p)
	p.show_bidding(false)
	assert_null(_button(p, "Nil"))
	assert_not_null(_button(p, "7"))


func test_bid_panel_number_button_emits_that_bid() -> void:
	var p: BidPanel = BidPanel.new()
	add_child_autofree(p)
	p.show_bidding(true)
	watch_signals(p)
	_button(p, "7").pressed.emit()
	assert_signal_emitted(p, "bid_chosen")
	var b: Bid = get_signal_parameters(p, "bid_chosen")[0]
	assert_eq(b.kind, Bid.Kind.NUMBER)
	assert_eq(b.tricks, 7)


func test_bid_panel_nil_button_emits_nil() -> void:
	var p: BidPanel = BidPanel.new()
	add_child_autofree(p)
	p.show_bidding(true)
	watch_signals(p)
	_button(p, "Nil").pressed.emit()
	var b: Bid = get_signal_parameters(p, "bid_chosen")[0]
	assert_eq(b.kind, Bid.Kind.NIL)


func test_bid_panel_has_buttons_1_to_13() -> void:
	var p: BidPanel = BidPanel.new()
	add_child_autofree(p)
	p.show_bidding(true)
	for n in range(1, 14):
		assert_not_null(_button(p, str(n)), "button %d" % n)
	assert_null(_button(p, "0"))
	assert_null(_button(p, "14"))


func test_blind_choice_emits_blind_nil_or_look() -> void:
	var p: BidPanel = BidPanel.new()
	add_child_autofree(p)
	p.show_blind_choice()
	watch_signals(p)
	_button(p, "Blind Nil").pressed.emit()
	var b: Bid = get_signal_parameters(p, "bid_chosen")[0]
	assert_eq(b.kind, Bid.Kind.BLIND_NIL)
	_button(p, "Look at my cards").pressed.emit()
	assert_signal_emitted(p, "look_requested")


func test_bid_buttons_wrap_inside_a_narrow_panel() -> void:
	var holder: Control = Control.new()
	holder.size = Vector2(360, 700)
	add_child_autofree(holder)
	var p: BidPanel = BidPanel.new()
	holder.add_child(p)
	p.show_bidding(true)
	p.size = Vector2(360, 10)
	await wait_frames(3)
	var panel_rect: Rect2 = p.get_global_rect()
	for n in range(1, 14):
		var r: Rect2 = _button(p, str(n)).get_global_rect()
		assert_lte(r.end.x, panel_rect.end.x + 1.0, "button %d runs off the right edge" % n)
		assert_gte(r.position.x, panel_rect.position.x - 1.0, "button %d runs off the left edge" % n)


# ---------- PartnerPicker ----------

func test_partner_picker_never_allows_more_than_the_maximum() -> void:
	var pk: PartnerPicker = PartnerPicker.new()
	add_child_autofree(pk)
	pk.size = Vector2(600, 100)
	pk.setup(13, 2)
	pk.toggle(3)
	pk.toggle(9)
	pk.toggle(1)
	assert_eq(pk.selected_positions(), [3, 9] as Array[int])
	pk.toggle(3)
	assert_eq(pk.selected_positions(), [9] as Array[int])


func test_partner_picker_positions_are_sorted() -> void:
	var pk: PartnerPicker = PartnerPicker.new()
	add_child_autofree(pk)
	pk.size = Vector2(600, 100)
	pk.setup(13, 2)
	pk.toggle(9)
	pk.toggle(3)
	assert_eq(pk.selected_positions(), [3, 9] as Array[int])


# ---------- SwapPanel ----------

func _swap_setup() -> Dictionary:
	var cards: Array[Card] = []
	var deck: Array[Card] = Deck.shuffled(3)
	for i in range(13):
		cards.append(deck[i])
	cards = Deck.sort_hand(cards)
	var hand: HandView = HandView.new()
	add_child_autofree(hand)
	hand.show_hand(cards, Rect2(0, 0, 700, 260), Vector2(150, 210))
	hand.set_multi_select(2)
	var pk: PartnerPicker = PartnerPicker.new()
	add_child_autofree(pk)
	pk.size = Vector2(600, 100)
	pk.setup(13, 2)
	var sp: SwapPanel = SwapPanel.new()
	add_child_autofree(sp)
	sp.setup(hand, pk)
	return {"cards": cards, "hand": hand, "picker": pk, "panel": sp}


func test_swap_confirm_only_enabled_when_counts_match() -> void:
	var d: Dictionary = _swap_setup()
	var hand: HandView = d["hand"]
	var pk: PartnerPicker = d["picker"]
	var sp: SwapPanel = d["panel"]
	assert_eq(sp.confirm_button.text, "Skip swap")
	assert_false(sp.confirm_button.disabled)
	hand.handle_tap(hand.card_rect(0).position + Vector2(5, 100))
	assert_true(sp.confirm_button.disabled)
	assert_string_contains(sp.status_label.text, "Giving 1")
	pk.toggle(4)
	assert_false(sp.confirm_button.disabled)
	assert_eq(sp.confirm_button.text, "Confirm swap")


func test_swap_confirm_emits_the_picked_cards_and_positions() -> void:
	var d: Dictionary = _swap_setup()
	var hand: HandView = d["hand"]
	var pk: PartnerPicker = d["picker"]
	var sp: SwapPanel = d["panel"]
	var cards: Array[Card] = d["cards"]
	hand.handle_tap(hand.card_rect(2).position + Vector2(5, 100))
	pk.toggle(7)
	watch_signals(sp)
	sp.confirm_button.pressed.emit()
	assert_signal_emitted(sp, "confirmed")
	var params: Array = get_signal_parameters(sp, "confirmed")
	assert_eq((params[0] as Array)[0], cards[2])
	assert_eq(params[1], [7] as Array[int])


# ---------- RoundSummary ----------

func test_round_summary_shows_points_and_game_scores_for_both_teams() -> void:
	var rs: RoundSummary = RoundSummary.new()
	add_child_autofree(rs)
	var result: Dictionary = {"points": [81, 140], "bags": [4, 1], "nil_results": {1: true}}
	var bids: Dictionary = {0: Bid.number(5), 1: Bid.nil(), 2: Bid.number(3), 3: Bid.number(4)}
	var tricks: Dictionary = {0: 5, 1: 0, 2: 4, 3: 4}
	rs.show_result(result, bids, tricks, [201, 230] as Array[int], [4, 1] as Array[int], 4)
	var text: String = _all_text(rs)
	assert_string_contains(text, "Round 4")
	assert_string_contains(text, "+81")
	assert_string_contains(text, "+140")
	assert_string_contains(text, "201")
	assert_string_contains(text, "230")
	assert_string_contains(text, "Tin made Nil")
	assert_not_null(_button(rs, "Next round"))


func test_round_summary_next_button_emits_signal() -> void:
	var rs: RoundSummary = RoundSummary.new()
	add_child_autofree(rs)
	rs.show_result({"points": [0, 0], "bags": [0, 0], "nil_results": {}}, {}, {}, [0, 0] as Array[int], [0, 0] as Array[int], 1)
	watch_signals(rs)
	_button(rs, "Next round").pressed.emit()
	assert_signal_emitted(rs, "next_round_pressed")


# ---------- InfoPanel ----------

func test_info_panel_lists_all_four_bids_and_the_last_trick() -> void:
	var ip: InfoPanel = InfoPanel.new()
	add_child_autofree(ip)
	var bids: Dictionary = {0: Bid.number(5), 1: Bid.nil(), 2: Bid.number(3), 3: Bid.blind_nil()}
	var names: Dictionary = {0: "You", 1: "Tin", 2: "Partner", 3: "Cherry"}
	var trick: Dictionary = {"cards": [
		{"seat": 1, "card": Card.make(Card.Suit.CLUBS, Card.Rank.SEVEN)},
		{"seat": 2, "card": Card.make(Card.Suit.CLUBS, Card.Rank.TEN)},
		{"seat": 3, "card": Card.make(Card.Suit.CLUBS, Card.Rank.KING)},
		{"seat": 0, "card": Card.make(Card.Suit.CLUBS, Card.Rank.TWO)},
	] as Array[Dictionary], "winner": 3}
	ip.show_info(bids, names, trick)
	var text: String = _all_text(ip)
	for n in ["You", "Tin", "Partner", "Cherry", "Nil", "Blind Nil", "5", "3"]:
		assert_string_contains(text, n)
	assert_eq(ip.find_children("*", "CardView", true, false).size(), 4)
	watch_signals(ip)
	_button(ip, "Close").pressed.emit()
	assert_signal_emitted(ip, "closed")


func test_info_panel_without_a_last_trick_says_so() -> void:
	var ip: InfoPanel = InfoPanel.new()
	add_child_autofree(ip)
	ip.show_info({}, {0: "You"}, {})
	assert_string_contains(_all_text(ip), "No trick yet")
	assert_eq(ip.find_children("*", "CardView", true, false).size(), 0)
