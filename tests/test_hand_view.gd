extends GutTest

const AREA: Rect2 = Rect2(0, 0, 700, 260)
const CARD_SIZE: Vector2 = Vector2(150, 210)

var hand: HandView
var cards: Array[Card]


func before_each() -> void:
	cards = []
	var deck: Array[Card] = Deck.shuffled(1)
	for i in range(13):
		cards.append(deck[i])
	cards = Deck.sort_hand(cards)
	hand = HandView.new()
	add_child_autofree(hand)
	hand.show_hand(cards, AREA, CARD_SIZE)


## A point on the visible left edge of card i (never covered by the next card).
func _point_on(i: int) -> Vector2:
	return hand.card_rect(i).position + Vector2(5, 100)


func test_show_hand_creates_one_view_per_card() -> void:
	assert_eq(hand.card_count(), 13)
	assert_eq(hand.get_child_count(), 13)


func test_tap_card_selects_it() -> void:
	hand.handle_tap(_point_on(3))
	assert_eq(hand.selected_index, 3)


func test_tapping_another_card_moves_the_selection() -> void:
	hand.handle_tap(_point_on(1))
	hand.handle_tap(_point_on(2))
	assert_eq(hand.selected_index, 2)


func test_tap_selected_card_plays_it_and_emits_signal() -> void:
	watch_signals(hand)
	var target: Card = cards[2]
	hand.handle_tap(_point_on(2))
	hand.handle_tap(_point_on(2))
	assert_signal_emitted_with_parameters(hand, "card_played", [target])
	assert_eq(hand.card_count(), 12)
	assert_eq(hand.get_child_count(), 12)
	assert_eq(hand.selected_index, -1)


func test_play_records_where_the_card_was() -> void:
	var before: Rect2 = hand.card_rect(4)
	hand.handle_tap(_point_on(4))
	hand.handle_tap(_point_on(4))
	assert_eq(hand.last_played_rect, Rect2(before.position + hand.global_position, before.size))


func test_tap_overlap_picks_rightmost_card() -> void:
	# This point lies inside card 3 AND card 4; card 4 is drawn on top.
	var overlap: Vector2 = hand.card_rect(4).position + Vector2(5, 100)
	assert_true(hand.card_rect(3).has_point(overlap))
	assert_eq(hand.pick_index_at(overlap), 4)


func test_tap_empty_space_clears_selection() -> void:
	hand.handle_tap(_point_on(0))
	assert_eq(hand.selected_index, 0)
	hand.handle_tap(Vector2(-50, -50))
	assert_eq(hand.selected_index, -1)


func test_raised_part_of_lifted_card_still_counts_as_the_hand() -> void:
	hand.handle_tap(_point_on(6))
	var above: Vector2 = hand.card_rect(6).position + Vector2(5, -10)
	assert_false(Rect2(Vector2.ZERO, hand.size).has_point(above))  # outside the plain rectangle
	assert_true(hand._has_point(above))


func test_tapping_the_raised_part_plays_the_lifted_card() -> void:
	hand.handle_tap(_point_on(6))
	watch_signals(hand)
	hand.handle_tap(hand.card_rect(6).position + Vector2(5, -10))
	assert_signal_emitted(hand, "card_played")


func test_a_point_far_outside_is_not_part_of_the_hand() -> void:
	hand.handle_tap(_point_on(6))
	assert_false(hand._has_point(Vector2(-500, -500)))


func test_clear_selection_puts_the_card_down() -> void:
	hand.handle_tap(_point_on(6))
	hand.clear_selection()
	assert_eq(hand.selected_index, -1)


func test_show_hand_with_empty_list_does_not_crash() -> void:
	var none: Array[Card] = []
	hand.show_hand(none, AREA, CARD_SIZE)
	assert_eq(hand.card_count(), 0)
	hand.handle_tap(Vector2(100, 100))
	assert_eq(hand.selected_index, -1)


func test_one_card_hand_can_be_played() -> void:
	var one: Array[Card] = [cards[0]]
	hand.show_hand(one, AREA, CARD_SIZE)
	watch_signals(hand)
	hand.handle_tap(_point_on(0))
	hand.handle_tap(_point_on(0))
	assert_signal_emitted(hand, "card_played")
	assert_eq(hand.card_count(), 0)


func test_reshow_hand_keeps_selected_card() -> void:
	hand.handle_tap(_point_on(5))
	var chosen: Card = cards[5]
	hand.show_hand(cards, Rect2(0, 0, 500, 200), Vector2(100, 140))
	assert_eq(hand.card_count(), 13)
	assert_eq(hand.get_child_count(), 13)
	assert_eq(hand.selected_index, 5)
	assert_eq(cards[hand.selected_index], chosen)


# --- Phase 4: legal-card greying, face-down hand, multi-select ---

func _legal_two() -> Array[Card]:
	return [cards[0], cards[1]] as Array[Card]


func test_illegal_card_is_dimmed_and_cannot_be_lifted() -> void:
	hand.set_legal(_legal_two(), true)
	assert_false((hand.get_child(0) as CardView).dimmed)
	assert_true((hand.get_child(5) as CardView).dimmed)
	hand.handle_tap(_point_on(5))
	assert_eq(hand.selected_index, -1)


func test_tapping_an_illegal_card_does_not_put_down_a_lifted_one_or_play() -> void:
	watch_signals(hand)
	hand.set_legal(_legal_two(), true)
	hand.handle_tap(_point_on(0))
	assert_eq(hand.selected_index, 0)
	hand.handle_tap(_point_on(5))
	hand.handle_tap(_point_on(5))
	assert_eq(hand.selected_index, 0)
	assert_signal_not_emitted(hand, "card_played")


func test_legal_card_still_plays_with_two_taps() -> void:
	watch_signals(hand)
	hand.set_legal(_legal_two(), true)
	hand.handle_tap(_point_on(1))
	hand.handle_tap(_point_on(1))
	assert_signal_emitted(hand, "card_played")


func test_without_restriction_nothing_is_dimmed() -> void:
	hand.set_legal(_legal_two(), true)
	hand.set_legal([] as Array[Card], false)
	for v in hand.get_children():
		assert_false((v as CardView).dimmed)


func test_face_down_hand_shows_backs_and_ignores_taps() -> void:
	hand.set_face_down(true)
	for v in hand.get_children():
		assert_false((v as CardView).face_up)
	hand.handle_tap(_point_on(3))
	assert_eq(hand.selected_index, -1)
	hand.set_face_down(false)
	for v in hand.get_children():
		assert_true((v as CardView).face_up)


func test_multi_select_allows_up_to_max_and_never_plays() -> void:
	hand.set_multi_select(2)
	watch_signals(hand)
	hand.handle_tap(_point_on(0))
	hand.handle_tap(_point_on(4))
	hand.handle_tap(_point_on(8))
	assert_eq(hand.selected_cards().size(), 2)
	assert_true(hand.selected_cards().has(cards[0]))
	assert_true(hand.selected_cards().has(cards[4]))
	assert_false(hand.selected_cards().has(cards[8]))
	assert_signal_not_emitted(hand, "card_played")
	assert_signal_emit_count(hand, "selection_changed", 2)


func test_multi_select_tap_again_deselects() -> void:
	hand.set_multi_select(2)
	hand.handle_tap(_point_on(0))
	hand.handle_tap(_point_on(0))
	assert_eq(hand.selected_cards().size(), 0)


func test_turning_multi_select_off_clears_the_picks() -> void:
	hand.set_multi_select(2)
	hand.handle_tap(_point_on(0))
	hand.set_multi_select(0)
	assert_eq(hand.selected_cards().size(), 0)
