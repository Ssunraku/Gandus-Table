extends GutTest

var settings: SpadesSettings


func before_each() -> void:
	settings = SpadesSettings.new()


func _legal(hand: String, trick: String, broken: bool = true, first: bool = false) -> Array[String]:
	var cards: Array[Card] = TrickRules.legal_cards(TestCards.hand(hand), TestCards.hand(trick), broken, first, settings)
	return TestCards.labels(cards)


func _sorted(text: String) -> Array[String]:
	return TestCards.labels(TestCards.hand(text))


func test_must_follow_suit() -> void:
	assert_eq(_legal("2H 9H AS 3C", "5H"), _sorted("2H 9H"))


func test_void_player_may_play_anything_after_first_trick() -> void:
	assert_eq(_legal("2C AS 3D", "5H"), _sorted("2C AS 3D"))


func test_cannot_lead_spade_until_broken() -> void:
	assert_eq(_legal("2C AS 3D", "", false), _sorted("2C 3D"))


func test_may_lead_spade_once_broken() -> void:
	assert_eq(_legal("2C AS 3D", "", true), _sorted("2C AS 3D"))


func test_may_lead_spade_when_only_spades() -> void:
	assert_eq(_legal("2S AS", "", false), _sorted("2S AS"))


func test_cannot_play_spade_on_first_trick_even_when_void() -> void:
	assert_eq(_legal("2C AS 3D", "5H", false, true), _sorted("2C 3D"))


func test_first_trick_follower_with_suit_just_follows() -> void:
	assert_eq(_legal("2H AS", "5H", false, true), _sorted("2H"))


func test_first_trick_with_only_spades_allows_them_when_redeal_is_off() -> void:
	assert_eq(_legal("2S AS", "5H", false, true), _sorted("2S AS"))


func test_play_higher_off_by_default() -> void:
	assert_eq(_legal("2H JH", "10H"), _sorted("2H JH"))


func test_play_higher_forces_a_higher_card_when_able() -> void:
	settings.play_higher_enabled = true
	assert_eq(_legal("2H JH QH", "10H"), _sorted("JH QH"))


func test_play_higher_beats_the_highest_card_so_far_not_the_last() -> void:
	settings.play_higher_enabled = true
	assert_eq(_legal("9H KH", "QH 5H"), _sorted("KH"))


func test_play_higher_not_forced_when_cannot_beat() -> void:
	settings.play_higher_enabled = true
	assert_eq(_legal("2H 9H", "10H"), _sorted("2H 9H"))


func test_play_higher_not_forced_when_a_spade_has_cut() -> void:
	settings.play_higher_enabled = true
	assert_eq(_legal("2H KH", "10H 3S"), _sorted("2H KH"))


func test_play_higher_does_not_force_cutting() -> void:
	settings.play_higher_enabled = true
	assert_eq(_legal("2C AS", "10H"), _sorted("2C AS"))


func test_trick_winner_highest_of_led_suit() -> void:
	assert_eq(TrickRules.trick_winner_index(TestCards.hand("5H KH 9H 2C")), 1)


func test_trick_winner_spade_beats_led_suit() -> void:
	assert_eq(TrickRules.trick_winner_index(TestCards.hand("5H KH 2S 9H")), 2)


func test_trick_winner_highest_spade() -> void:
	assert_eq(TrickRules.trick_winner_index(TestCards.hand("5H 2S 9S KH")), 2)


func test_off_suit_card_never_wins() -> void:
	assert_eq(TrickRules.trick_winner_index(TestCards.hand("5H AC AD 6H")), 3)
