class_name TableState
extends RefCounted
## Everything the table screen needs to DRAW. It holds no rules.
## Privacy rule: only the local player's (SOUTH) cards are real Card objects.
## Other seats are just a number of cards. A Card for another seat exists only
## once it has been played face-up on the table (get_played).

enum Seat { SOUTH, WEST, NORTH, EAST }  # SOUTH = you, NORTH = your partner

var own_hand: Array[Card] = []
var seat_names: Dictionary = {}  # Seat -> String
var dealer_seat: Seat = Seat.WEST
var turn_seat: Seat = Seat.SOUTH
var team_scores: Array[int] = [0, 0]  # [your team, other team]
var team_bags: Array[int] = [0, 0]
var tricks_won: Dictionary = {}  # Seat -> int
# Extra public information for a live game (all empty/false in the dummy table).
var bids: Dictionary = {}  # Seat -> Bid, only for seats that have bid
var spades_broken: bool = false
var can_play: bool = false  # it is your turn to play a card
var legal_cards: Array[Card] = []  # the cards you may play right now
var phase: int = 0  # a SpadesGame.Phase value
var last_trick: Dictionary = {}  # {"cards": [{"seat","card"}], "winner": Seat}

var _counts: Dictionary = {}  # Seat -> int (never SOUTH)
var _played: Dictionary = {}  # Seat -> Card


func get_card_count(seat: Seat) -> int:
	if seat == Seat.SOUTH:
		return own_hand.size()
	return _counts.get(seat, 0)


## Returns false (and changes nothing) for SOUTH, whose count is its real hand.
func set_card_count(seat: Seat, n: int) -> bool:
	if seat == Seat.SOUTH:
		return false
	_counts[seat] = maxi(n, 0)
	return true


## The card a seat has played face-up on the table, or null.
func get_played(seat: Seat) -> Card:
	return _played.get(seat, null)


func set_played(seat: Seat, card: Card) -> void:
	_played[seat] = card


## Moves a card from your hand to the table. False if it is not in your hand.
func play_own_card(card: Card) -> bool:
	var idx: int = own_hand.find(card)
	if idx == -1:
		return false
	own_hand.remove_at(idx)
	_played[Seat.SOUTH] = card
	return true


## Fixed fake data so the screen can be seen and tested.
static func dummy() -> TableState:
	var s: TableState = TableState.new()
	var deck: Array[Card] = Deck.shuffled(1)
	var hand: Array[Card] = []
	for i in range(13):
		hand.append(deck[i])
	s.own_hand = Deck.sort_hand(hand)
	s.seat_names = {
		Seat.SOUTH: "You",
		Seat.WEST: "Tin",
		Seat.NORTH: "Partner",
		Seat.EAST: "Cherry",
	}
	s.dealer_seat = Seat.WEST
	s.turn_seat = Seat.SOUTH
	for seat in [Seat.WEST, Seat.NORTH, Seat.EAST]:
		s.set_card_count(seat, 13)
	for seat in [Seat.SOUTH, Seat.WEST, Seat.NORTH, Seat.EAST]:
		s.tricks_won[seat] = 0
	return s
