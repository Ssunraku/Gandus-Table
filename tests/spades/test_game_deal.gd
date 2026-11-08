extends GutTest

var settings: SpadesSettings


func before_each() -> void:
	settings = SpadesSettings.new()


func _all_labels(game: SpadesGame) -> Array[String]:
	var out: Array[String] = []
	for seat in range(4):
		for c in game.hand_of(seat):
			out.append(c.label())
	out.sort()
	return out


func _any_void(hands: Dictionary) -> bool:
	for seat in range(4):
		if HandCheck.has_void(hands[seat]):
			return true
	return false


## First seed whose deals `count` times in a row (seed, seed+1, ...) all have a void.
func _seed_with_voids(count: int) -> int:
	for s in range(1, 20000):
		var all_void: bool = true
		for n in range(count):
			if not _any_void(SpadesGame.deal_hands(s + n, 0)):
				all_void = false
				break
		if all_void:
			return s
	return -1


## First seed whose very first deal has no void at all.
func _seed_without_void() -> int:
	for s in range(1, 1000):
		if not _any_void(SpadesGame.deal_hands(s, 0)):
			return s
	return -1


func test_every_seat_gets_13_cards_and_all_52_are_dealt_once() -> void:
	settings.redeal_enabled = false
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(5)
	for seat in range(4):
		assert_eq(game.hand_of(seat).size(), 13)
	var expected: Array[String] = TestCards.labels(Deck.standard_52())
	assert_eq(_all_labels(game), expected)


func test_same_seed_gives_the_same_deal() -> void:
	settings.redeal_enabled = false
	var a: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	var b: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	a.start_round(9)
	b.start_round(9)
	assert_eq(TestCards.labels(a.hand_of(1)), TestCards.labels(b.hand_of(1)))


func test_round_starts_in_bidding_with_the_player_left_of_the_dealer() -> void:
	settings.redeal_enabled = false
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.NORTH)
	game.start_round(1)
	assert_eq(game.phase, SpadesGame.Phase.BIDDING)
	assert_eq(game.turn_seat, TableState.Seat.EAST)


func test_a_deal_with_a_void_is_redealt_automatically() -> void:
	var seed_value: int = _seed_with_voids(1)
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(seed_value)
	assert_gt(game.redeal_log.size(), 0)
	var entry: Dictionary = game.redeal_log[0]
	assert_true(entry.has("seat"))
	assert_true(entry.has("suit"))


func test_clean_deal_is_not_redealt() -> void:
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(_seed_without_void())
	assert_eq(game.redeal_log.size(), 0)


func test_redeal_keeps_the_same_dealer() -> void:
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.WEST)
	game.start_round(_seed_with_voids(1))
	assert_eq(game.dealer_seat, TableState.Seat.WEST)


func test_third_deal_is_accepted_even_with_a_void() -> void:
	var seed_value: int = _seed_with_voids(3)
	assert_ne(seed_value, -1, "test needs a seed whose first three deals all have voids")
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(seed_value)
	var redeal_rounds: Dictionary = {}
	for e in game.redeal_log:
		redeal_rounds[e["deal"]] = true
	assert_eq(redeal_rounds.size(), 2, "exactly two redeals happened")
	for seat in range(4):
		assert_eq(game.hand_of(seat).size(), 13)


func test_no_redeal_when_the_rule_is_off() -> void:
	settings.redeal_enabled = false
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(_seed_with_voids(1))
	assert_eq(game.redeal_log.size(), 0)


func test_view_contains_only_the_own_hand() -> void:
	settings.redeal_enabled = false
	var game: SpadesGame = SpadesGame.new(settings, TableState.Seat.SOUTH)
	game.start_round(3)
	var view: Dictionary = game.view_for(TableState.Seat.WEST)
	assert_eq(TestCards.labels(view["hand"]), TestCards.labels(game.hand_of(1)))
	assert_eq(view["hand_counts"][TableState.Seat.NORTH], 13)
	assert_false(view.has("hands"), "the view must not carry all hands")
