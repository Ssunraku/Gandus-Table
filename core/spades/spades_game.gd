class_name SpadesGame
extends RefCounted
## One game of Spades, from the host's point of view: the host owns every hand and
## accepts only legal actions. Seats are TableState.Seat values (ints), clockwise
## South, West, North, East. Pure logic: no UI, no networking.
## Rules: docs/SPADES_RULES.md.

enum Phase { BIDDING, SWAP, PLAYING, ROUND_OVER, GAME_OVER }

const MAX_REDEALS: int = 2
const TRICKS_PER_ROUND: int = 13

var settings: SpadesSettings
var phase: Phase = Phase.BIDDING
var dealer_seat: int = 0
var turn_seat: int = 0
var team_scores: Array[int] = [0, 0]
var team_bags: Array[int] = [0, 0]
## One entry per hand that caused a redeal: {deal: int, seat: int, suit: Card.Suit}.
var redeal_log: Array[Dictionary] = []
## seat -> Bid, filled in as players bid.
var bids: Dictionary = {}
## seat -> tricks won this round.
var tricks_won: Dictionary = {}
## How many tricks of this round are finished (0 = the first trick is being played).
var trick_number: int = 0
## The trick on the table, in play order (cards and who played them).
var trick_cards: Array[Card] = []
var trick_seats: Array[int] = []
var spades_broken: bool = false
## 0 or 1 once the game is over, otherwise -1.
var winner_team: int = -1
## Result of the last finished round: {points, bags, nil_results}.
var last_round_result: Dictionary = {}
## Blind Nil bidder seat -> {lost: Array[Card], received: Array[Card]}.
var last_swaps: Dictionary = {}

var _hands: Dictionary = {}  # seat -> Array[Card]; host-only, never sent to others
var _swap_pending: Array[int] = []  # Blind Nil bidders who still have to swap


func _init(game_settings: SpadesSettings, first_dealer: int) -> void:
	settings = game_settings
	dealer_seat = first_dealer


static func next_seat(seat: int) -> int:
	return (seat + 1) % 4


static func partner_of(seat: int) -> int:
	return (seat + 2) % 4


## Deal 52 shuffled cards: 13 each, sorted. Starts with the player left of the dealer.
static func deal_hands(seed_value: int, dealer: int) -> Dictionary:
	var deck: Array[Card] = Deck.shuffled(seed_value)
	var piles: Dictionary = {0: [] as Array[Card], 1: [] as Array[Card], 2: [] as Array[Card], 3: [] as Array[Card]}
	var seat: int = next_seat(dealer)
	for card in deck:
		(piles[seat] as Array[Card]).append(card)
		seat = next_seat(seat)
	for s in range(4):
		piles[s] = Deck.sort_hand(piles[s])
	return piles


## Deal a new round. A hand missing a suit triggers an automatic redeal (at most
## MAX_REDEALS in a row; the next deal then stands).
func start_round(seed_value: int) -> void:
	redeal_log.clear()
	bids.clear()
	last_swaps.clear()
	_swap_pending.clear()
	tricks_won = {0: 0, 1: 0, 2: 0, 3: 0}
	trick_number = 0
	trick_cards.clear()
	trick_seats.clear()
	spades_broken = false
	var attempt: int = 0
	while true:
		_hands = deal_hands(seed_value + attempt, dealer_seat)
		if not settings.redeal_enabled or attempt >= MAX_REDEALS:
			break
		var voids: Array[Dictionary] = _find_voids(attempt)
		if voids.is_empty():
			break
		redeal_log.append_array(voids)
		attempt += 1
	phase = Phase.BIDDING
	turn_seat = next_seat(dealer_seat)


## The real hand of a seat. HOST ONLY: never send this to another player.
func hand_of(seat: int) -> Array[Card]:
	return _hands[seat]


## Place a bid. Returns false (and changes nothing) if it is not allowed.
func bid(seat: int, b: Bid) -> bool:
	if phase != Phase.BIDDING or seat != turn_seat:
		return false
	match b.kind:
		Bid.Kind.NUMBER:
			if b.tricks < 1 or b.tricks > 13:
				return false
		Bid.Kind.NIL:
			if not settings.nil_enabled:
				return false
		Bid.Kind.BLIND_NIL:
			if not settings.blind_nil_enabled:
				return false
			var partner_bid: Bid = bids.get(partner_of(seat))
			if partner_bid != null and partner_bid.kind == Bid.Kind.BLIND_NIL:
				return false
	bids[seat] = b
	if bids.size() < 4:
		turn_seat = next_seat(seat)
	else:
		_finish_bidding()
	return true


## The Blind Nil bidder swaps 0, 1 or 2 of their own cards with the partner's cards at the
## given positions in the partner's (face-down) hand. Returns false if not allowed.
func swap(bidder: int, give: Array[Card], take_positions: Array[int]) -> bool:
	if phase != Phase.SWAP or not _swap_pending.has(bidder):
		return false
	if give.size() != take_positions.size() or give.size() > 2:
		return false
	var partner: int = partner_of(bidder)
	var own: Array[Card] = _hands[bidder]
	var theirs: Array[Card] = _hands[partner]
	var given: Array[Card] = []
	for c in give:
		var found: Card = _find_in(own, c)
		if found == null or given.has(found):
			return false
		given.append(found)
	var taken: Array[Card] = []
	var used_positions: Array[int] = []
	for p in take_positions:
		if p < 0 or p >= theirs.size() or used_positions.has(p):
			return false
		used_positions.append(p)
		taken.append(theirs[p])
	var new_own: Array[Card] = []
	for c in own:
		if not given.has(c):
			new_own.append(c)
	new_own.append_array(taken)
	var new_theirs: Array[Card] = []
	for c in theirs:
		if not taken.has(c):
			new_theirs.append(c)
	new_theirs.append_array(given)
	_hands[bidder] = Deck.sort_hand(new_own)
	_hands[partner] = Deck.sort_hand(new_theirs)
	last_swaps[bidder] = {"lost": given, "received": taken}
	_swap_pending.erase(bidder)
	if _swap_pending.is_empty():
		phase = Phase.PLAYING
		turn_seat = next_seat(dealer_seat)
	return true


## The cards `seat` may legally play right now (empty outside the playing phase).
func legal_cards_for(seat: int) -> Array[Card]:
	if phase != Phase.PLAYING:
		return []
	return TrickRules.legal_cards(_hands[seat], trick_cards, spades_broken, trick_number == 0, settings)


## Play a card. Returns false (and changes nothing) if it is not that seat's turn or not legal.
func play(seat: int, card: Card) -> bool:
	if phase != Phase.PLAYING or seat != turn_seat:
		return false
	var in_hand: Card = _find_in(_hands[seat], card)
	if in_hand == null or _find_in(legal_cards_for(seat), card) == null:
		return false
	(_hands[seat] as Array[Card]).erase(in_hand)
	trick_cards.append(in_hand)
	trick_seats.append(seat)
	if in_hand.suit == Card.Suit.SPADES:
		spades_broken = true
	if trick_cards.size() < 4:
		turn_seat = next_seat(seat)
	else:
		_finish_trick()
	return true


## Start the next round (dealer moves one seat clockwise). Only after a finished round.
func next_round(seed_value: int) -> bool:
	if phase != Phase.ROUND_OVER:
		return false
	dealer_seat = next_seat(dealer_seat)
	start_round(seed_value)
	return true


## What one seat is allowed to know: its own hand plus public information.
func view_for(seat: int) -> Dictionary:
	var own: Array[Card] = _hands[seat].duplicate()
	var own_bid: Bid = bids.get(seat)
	if phase == Phase.BIDDING and own_bid != null and own_bid.kind == Bid.Kind.BLIND_NIL:
		own = []  # a Blind Nil bidder may not look until bidding is over
	var counts: Dictionary = {}
	for s in range(4):
		counts[s] = _hands[s].size()
	var table: Array[Dictionary] = []
	for i in range(trick_cards.size()):
		table.append({"seat": trick_seats[i], "card": trick_cards[i]})
	return {
		"phase": phase,
		"turn_seat": turn_seat,
		"dealer_seat": dealer_seat,
		"hand": own,
		"hand_counts": counts,
		"bids": bids.duplicate(),
		"trick": table,
		"spades_broken": spades_broken,
		"tricks_won": tricks_won.duplicate(),
		"team_scores": team_scores.duplicate(),
		"team_bags": team_bags.duplicate(),
		"swap": _swap_view_for(seat),
	}


## Only the Blind Nil bidder and their partner may know which cards moved.
func _swap_view_for(seat: int) -> Dictionary:
	if last_swaps.has(seat):
		return (last_swaps[seat] as Dictionary).duplicate()
	var partner: int = partner_of(seat)
	if last_swaps.has(partner):
		var s: Dictionary = last_swaps[partner]
		return {"lost": s["received"], "received": s["lost"]}
	return {}


## The card object in `cards` with the same suit and rank as `card`, or null.
func _find_in(cards: Array[Card], card: Card) -> Card:
	for c in cards:
		if c.suit == card.suit and c.rank == card.rank:
			return c
	return null


func _finish_trick() -> void:
	var winner: int = trick_seats[TrickRules.trick_winner_index(trick_cards)]
	tricks_won[winner] = int(tricks_won[winner]) + 1
	trick_cards.clear()
	trick_seats.clear()
	trick_number += 1
	turn_seat = winner
	if trick_number == TRICKS_PER_ROUND:
		_finish_round()


func _finish_round() -> void:
	last_round_result = SpadesScoring.score_round(bids, tricks_won, team_bags, settings)
	for team in range(2):
		team_scores[team] += last_round_result["points"][team]
		team_bags[team] = last_round_result["bags"][team]
	winner_team = SpadesScoring.game_winner(team_scores, settings)
	phase = Phase.GAME_OVER if winner_team != -1 else Phase.ROUND_OVER


func _find_voids(deal_number: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seat in range(4):
		for suit in HandCheck.void_suits(_hands[seat]):
			out.append({"deal": deal_number, "seat": seat, "suit": suit})
	return out


func _finish_bidding() -> void:
	for s in range(4):
		if (bids[s] as Bid).kind == Bid.Kind.BLIND_NIL:
			_swap_pending.append(s)
	phase = Phase.SWAP if not _swap_pending.is_empty() else Phase.PLAYING
	turn_seat = next_seat(dealer_seat)
