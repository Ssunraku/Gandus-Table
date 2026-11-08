class_name TrickRules
extends RefCounted
## Which cards a player may play, and who wins a trick. Pure rules, no state.


## `trick` is the cards already played in this trick, in order (empty when leading).
static func legal_cards(hand: Array[Card], trick: Array[Card], spades_broken: bool, is_first_trick: bool, settings: SpadesSettings) -> Array[Card]:
	if trick.is_empty():
		return _legal_lead(hand, spades_broken)
	var led: Card.Suit = trick[0].suit
	var of_led: Array[Card] = _cards_of_suit(hand, led)
	if not of_led.is_empty():
		if settings.play_higher_enabled:
			var higher: Array[Card] = _beating_cards(of_led, trick, led)
			if not higher.is_empty():
				return higher
		return of_led
	# No card of the led suit: anything goes, except no spade in the first trick.
	if is_first_trick:
		var no_spades: Array[Card] = _without_spades(hand)
		if not no_spades.is_empty():
			return no_spades
	return hand.duplicate()


## Index (into `trick`) of the winning card: highest spade, else highest of the led suit.
static func trick_winner_index(trick: Array[Card]) -> int:
	var led: Card.Suit = trick[0].suit
	var best: int = 0
	for i in range(1, trick.size()):
		if _beats(trick[i], trick[best], led):
			best = i
	return best


static func _legal_lead(hand: Array[Card], spades_broken: bool) -> Array[Card]:
	if spades_broken:
		return hand.duplicate()
	var no_spades: Array[Card] = _without_spades(hand)
	if no_spades.is_empty():
		return hand.duplicate()  # only spades left: allowed to lead one
	return no_spades


## Cards of the led suit that beat the best led-suit card played, or empty if a spade
## already cut (then nothing of the led suit can win, so nothing is forced).
static func _beating_cards(of_led: Array[Card], trick: Array[Card], led: Card.Suit) -> Array[Card]:
	var best_rank: int = 0
	for c in trick:
		if c.suit == Card.Suit.SPADES and led != Card.Suit.SPADES:
			return []
		if c.suit == led and int(c.rank) > best_rank:
			best_rank = int(c.rank)
	var out: Array[Card] = []
	for c in of_led:
		if int(c.rank) > best_rank:
			out.append(c)
	return out


static func _beats(challenger: Card, current: Card, led: Card.Suit) -> bool:
	var spade: Card.Suit = Card.Suit.SPADES
	if challenger.suit == current.suit:
		return int(challenger.rank) > int(current.rank)
	if challenger.suit == spade:
		return true
	return false


static func _cards_of_suit(hand: Array[Card], suit: Card.Suit) -> Array[Card]:
	var out: Array[Card] = []
	for c in hand:
		if c.suit == suit:
			out.append(c)
	return out


static func _without_spades(hand: Array[Card]) -> Array[Card]:
	var out: Array[Card] = []
	for c in hand:
		if c.suit != Card.Suit.SPADES:
			out.append(c)
	return out
