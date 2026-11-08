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
