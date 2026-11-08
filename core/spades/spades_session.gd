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

var _game: SpadesGame
var _bot: SpadesBot
var _seed: int
var _round: int = 0
var _pending: bool = false  # four cards are on the table waiting to be cleared
var _shown: Array[Dictionary] = []
var _last_trick: Dictionary = {}
var _swap_order: Array[int] = []  # shuffled: which real card each of your partner's face-down cards is


func _init(game_settings: SpadesSettings, seed_value: int, human: int = 0) -> void:
	settings = game_settings
	human_seat = human
	_seed = seed_value
	_game = SpadesGame.new(settings, posmod(seed_value, 4))
	_bot = SpadesBot.new(seed_value)


static func seat_name(seat: int) -> String:
	return NAMES.get(seat, "")


## The seed for one round's first deal. A redeal adds 1 or 2 to it, so rounds are spaced
## 10 apart: a redeal in one round can never reproduce the next round's deal.
static func round_seed(seed_value: int, round_index: int) -> int:
	return seed_value * 1000 + round_index * 10


## "Tin has no hearts" for every hand that forced a redeal this round (empty if none).
func redeal_messages() -> Array[String]:
	var words: Dictionary = {Card.Suit.CLUBS: "clubs", Card.Suit.DIAMONDS: "diamonds", Card.Suit.HEARTS: "hearts", Card.Suit.SPADES: "spades"}
	var out: Array[String] = []
	for e in _game.redeal_log:
		out.append("%s has no %s" % [seat_name(e["seat"]), words[e["suit"]]])
	return out


func start() -> void:
	_round = 0
	_game.start_round(round_seed(_seed, 0))


func phase() -> int:
	return _game.phase


func turn_seat() -> int:
	return _game.turn_seat


func human_must_bid() -> bool:
	return _game.phase == SpadesGame.Phase.BIDDING and _game.turn_seat == human_seat


func human_must_play() -> bool:
	return _game.phase == SpadesGame.Phase.PLAYING and _game.turn_seat == human_seat and not _pending


func human_must_swap() -> bool:
	return _must_swap(human_seat)


func _must_swap(seat: int) -> bool:
	if _game.phase != SpadesGame.Phase.SWAP:
		return false
	var b: Bid = _game.bids.get(seat)
	return b != null and b.kind == Bid.Kind.BLIND_NIL and not _game.last_swaps.has(seat)


func submit_bid(b: Bid) -> bool:
	if not human_must_bid():
		return false
	return _game.bid(human_seat, b)


func submit_swap(give: Array[Card], positions: Array[int]) -> bool:
	if not human_must_swap():
		return false
	if _swap_order.is_empty():
		_swap_order = _shuffled_positions(_game.hand_of(SpadesGame.partner_of(human_seat)).size())
	# The positions you tap are shuffled, so "the left-most card" is not the partner's lowest.
	var real: Array[int] = []
	for p in positions:
		if p < 0 or p >= _swap_order.size():
			return false
		real.append(_swap_order[p])
	var ok: bool = _game.swap(human_seat, give, real)
	if ok:
		_swap_order.clear()
	return ok


func _shuffled_positions(count: int) -> Array[int]:
	var order: Array[int] = []
	for i in range(count):
		order.append(i)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + _round
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


func submit_play(card: Card) -> bool:
	if not human_must_play():
		return false
	return _play(human_seat, card)


## Runs exactly one bot action. Returns {} when nothing is waiting on a bot.
func advance_bots() -> Dictionary:
	if _pending:
		return {}
	match _game.phase:
		SpadesGame.Phase.BIDDING:
			var seat: int = _game.turn_seat
			if seat == human_seat:
				return {}
			var b: Bid = _bot.choose_bid(_game, seat)
			if not _game.bid(seat, b):
				return {}
			return {"seat": seat, "kind": "bid", "bid": b, "card": null}
		SpadesGame.Phase.SWAP:
			for seat in range(4):
				if seat != human_seat and _must_swap(seat):
					var choice: Dictionary = _bot.choose_swap(_game, seat)
					if _game.swap(seat, choice["give"], choice["positions"]):
						return {"seat": seat, "kind": "swap", "bid": null, "card": null}
			return {}
		SpadesGame.Phase.PLAYING:
			var seat: int = _game.turn_seat
			if seat == human_seat:
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
	_swap_order.clear()
	return _game.next_round(round_seed(_seed, _round))


## Everything a screen may know: the human's own hand plus public information.
func view() -> Dictionary:
	var v: Dictionary = _game.view_for(human_seat)
	v["trick"] = shown_trick()
	var legal: Array[Card] = []
	if human_must_play():
		legal = _game.legal_cards_for(human_seat)
	v["legal"] = legal
	v["last_trick"] = last_trick()
	v["names"] = NAMES.duplicate()
	return v
