class_name SpadesSession
extends RefCounted
## The host side of one offline game: one human seat plus three bots.
## Screens talk ONLY to this class. It validates every action through SpadesGame, runs
## the bots one action at a time (the screen decides how long to wait between actions)
## and keeps a finished trick on the table until the screen clears it.
## Phase 5 (network) will reuse this same seam for remote players.

const NAMES: Dictionary = {0: "You", 1: "Tin", 2: "Partner", 3: "Cherry"}

var settings: SpadesSettings
var human_seat: int
## Every seat a person controls (the network host sets several; offline it is just you).
## Seats not listed here are played by the bots.
var human_seats: Array[int] = []

var _game: SpadesGame
var _bot: SpadesBot
var _seed: int
var _round: int = 0
var _pending: bool = false  # four cards are on the table waiting to be cleared
var _shown: Array[Dictionary] = []
var _last_trick: Dictionary = {}
var _swap_orders: Dictionary = {}  # seat -> shuffled: which real card each of the partner's face-down cards is
var _names: Dictionary = NAMES.duplicate()


func _init(game_settings: SpadesSettings, seed_value: int, human: int = 0) -> void:
	settings = game_settings
	human_seat = human
	human_seats = [human]
	_seed = seed_value
	_game = SpadesGame.new(settings, posmod(seed_value, 4))
	_bot = SpadesBot.new(seed_value)


static func seat_name(seat: int) -> String:
	return NAMES.get(seat, "")


## Which seats are people (call before start()). The first one is the "main" human.
func set_human_seats(seats: Array[int]) -> void:
	human_seats = seats.duplicate()
	human_seat = human_seats[0] if not human_seats.is_empty() else -1


func is_human(seat: int) -> bool:
	return human_seats.has(seat)


## Hands a seat to a person / to the bot, even in the middle of a round.
func make_human(seat: int) -> void:
	if not human_seats.has(seat):
		human_seats.append(seat)
	if human_seat < 0:
		human_seat = seat


func make_bot(seat: int) -> void:
	human_seats.erase(seat)
	_swap_orders.erase(seat)


## seat -> name shown at the table (default: You / Tin / Partner / Cherry).
func set_names(names: Dictionary) -> void:
	_names = names.duplicate()


## The seed for one round's first deal. A redeal adds 1 or 2 to it, so rounds are spaced
## 10 apart: a redeal in one round can never reproduce the next round's deal.
static func round_seed(seed_value: int, round_index: int) -> int:
	return seed_value * 1000 + round_index * 10


## "Tin has no hearts" for every hand that forced a redeal this round (empty if none).
func redeal_messages() -> Array[String]:
	var words: Dictionary = {Card.Suit.CLUBS: "clubs", Card.Suit.DIAMONDS: "diamonds", Card.Suit.HEARTS: "hearts", Card.Suit.SPADES: "spades"}
	var out: Array[String] = []
	for e in _game.redeal_log:
		out.append("%s has no %s" % [_names.get(e["seat"], seat_name(e["seat"])), words[e["suit"]]])
	return out


func start() -> void:
	_round = 0
	_game.start_round(round_seed(_seed, 0))


func phase() -> int:
	return _game.phase


func turn_seat() -> int:
	return _game.turn_seat


func human_must_bid() -> bool:
	return must_bid(human_seat)


func human_must_play() -> bool:
	return must_play(human_seat)


func human_must_swap() -> bool:
	return must_swap(human_seat)


func must_bid(seat: int) -> bool:
	return is_human(seat) and _game.phase == SpadesGame.Phase.BIDDING and _game.turn_seat == seat


func must_play(seat: int) -> bool:
	return is_human(seat) and _game.phase == SpadesGame.Phase.PLAYING and _game.turn_seat == seat and not _pending


func must_swap(seat: int) -> bool:
	return is_human(seat) and _must_swap(seat)


func _must_swap(seat: int) -> bool:
	if _game.phase != SpadesGame.Phase.SWAP:
		return false
	var b: Bid = _game.bids.get(seat)
	return b != null and b.kind == Bid.Kind.BLIND_NIL and not _game.last_swaps.has(seat)


func submit_bid(b: Bid) -> bool:
	return bid_for(human_seat, b)


func bid_for(seat: int, b: Bid) -> bool:
	if not must_bid(seat):
		return false
	return _game.bid(seat, b)


func submit_swap(give: Array[Card], positions: Array[int]) -> bool:
	return swap_for(human_seat, give, positions)


func swap_for(seat: int, give: Array[Card], positions: Array[int]) -> bool:
	if not must_swap(seat):
		return false
	if not _swap_orders.has(seat):
		_swap_orders[seat] = _shuffled_positions(_game.hand_of(SpadesGame.partner_of(seat)).size(), seat)
	var order: Array[int] = _swap_orders[seat]
	# The positions you tap are shuffled, so "the left-most card" is not the partner's lowest.
	var real: Array[int] = []
	for p in positions:
		if p < 0 or p >= order.size():
			return false
		real.append(order[p])
	var ok: bool = _game.swap(seat, give, real)
	if ok:
		_swap_orders.erase(seat)
	return ok


func _shuffled_positions(count: int, seat: int = 0) -> Array[int]:
	var order: Array[int] = []
	for i in range(count):
		order.append(i)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + _round + seat * 101
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


func submit_play(card: Card) -> bool:
	return play_for(human_seat, card)


func play_for(seat: int, card: Card) -> bool:
	if not must_play(seat):
		return false
	return _play(seat, card)


## Runs exactly one bot action. Returns {} when nothing is waiting on a bot.
func advance_bots() -> Dictionary:
	if _pending:
		return {}
	match _game.phase:
		SpadesGame.Phase.BIDDING:
			var seat: int = _game.turn_seat
			if is_human(seat):
				return {}
			var b: Bid = _bot.choose_bid(_game, seat)
			if not _game.bid(seat, b):
				return {}
			return {"seat": seat, "kind": "bid", "bid": b, "card": null}
		SpadesGame.Phase.SWAP:
			for seat in range(4):
				if not is_human(seat) and _must_swap(seat):
					var choice: Dictionary = _bot.choose_swap(_game, seat)
					if _game.swap(seat, choice["give"], choice["positions"]):
						return {"seat": seat, "kind": "swap", "bid": null, "card": null}
			return {}
		SpadesGame.Phase.PLAYING:
			var seat: int = _game.turn_seat
			if is_human(seat):
				return {}
			var card: Card = _bot.choose_card(_game, seat)
			if not _play(seat, card):
				return {}
			return {"seat": seat, "kind": "play", "bid": null, "card": card}
	return {}


## Plays a card and keeps track of the table, including a trick that has just finished
## (SpadesGame forgets it at once, but the screen wants to show it for a moment).
func _play(seat: int, card: Card) -> bool:
	var before: int = _game.trick_cards.size()
	var cards: Array[Card] = _game.trick_cards.duplicate()
	var seats: Array[int] = _game.trick_seats.duplicate()
	if not _game.play(seat, card):
		return false
	cards.append(card)
	seats.append(seat)
	if before == 3:
		var winner: int = seats[TrickRules.trick_winner_index(cards)]
		_shown = _pairs(seats, cards)
		_last_trick = {"cards": _pairs(seats, cards), "winner": winner}
		_pending = true
	else:
		_shown = _pairs(seats, cards)
	return true


func _pairs(seats: Array[int], cards: Array[Card]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(cards.size()):
		out.append({"seat": seats[i], "card": cards[i]})
	return out


func trick_pending() -> bool:
	return _pending


func shown_trick() -> Array[Dictionary]:
	return _shown.duplicate()


func last_trick() -> Dictionary:
	return _last_trick.duplicate()


func clear_trick() -> void:
	_pending = false
	_shown = []


func round_over() -> bool:
	return not _pending and (_game.phase == SpadesGame.Phase.ROUND_OVER or _game.phase == SpadesGame.Phase.GAME_OVER)


func game_over() -> bool:
	return not _pending and _game.phase == SpadesGame.Phase.GAME_OVER


func winner_team() -> int:
	return _game.winner_team


func round_result() -> Dictionary:
	return _game.last_round_result.duplicate(true)


func round_number() -> int:
	return _round + 1


func next_round() -> bool:
	if _pending or _game.phase != SpadesGame.Phase.ROUND_OVER:
		return false
	_round += 1
	_shown = []
	_last_trick = {}
	_swap_orders.clear()
	return _game.next_round(round_seed(_seed, _round))


## Everything a screen may know: the human's own hand plus public information.
func view() -> Dictionary:
	return view_for_seat(human_seat)


## Same as view(), for any seat: that seat's own hand plus public information.
func view_for_seat(seat: int) -> Dictionary:
	var v: Dictionary = _game.view_for(seat)
	v["trick"] = shown_trick()
	var legal: Array[Card] = []
	if must_play(seat):
		legal = _game.legal_cards_for(seat)
	v["legal"] = legal
	v["last_trick"] = last_trick()
	v["names"] = _names.duplicate()
	return v
