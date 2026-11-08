class_name Wire
extends RefCounted
## Turns cards, bids and game options into plain dictionaries that survive JSON text,
## and back. JSON turns whole numbers into decimals, so every read goes through int().


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func card_to_dict(c: Card) -> Dictionary:
	return {"s": int(c.suit), "r": int(c.rank)}


## Null if the dictionary is not a real card.
static func card_from_dict(d: Dictionary) -> Card:
	if not (_is_number(d.get("s")) and _is_number(d.get("r"))):
		return null
	var s: int = int(d["s"])
	var r: int = int(d["r"])
	if s < 0 or s > 3 or r < 2 or r > 14:
		return null
	return Card.make(s as Card.Suit, r as Card.Rank)


static func cards_to_array(cards: Array[Card]) -> Array:
	var out: Array = []
	for c in cards:
		out.append(card_to_dict(c))
	return out


## Invalid entries are skipped.
static func cards_from_array(a: Array) -> Array[Card]:
	var out: Array[Card] = []
	for d in a:
		if d is Dictionary:
			var c: Card = card_from_dict(d)
			if c != null:
				out.append(c)
	return out


static func bid_to_dict(b: Bid) -> Dictionary:
	return {"k": int(b.kind), "n": b.tricks}


## Null if it is not a real bid (kind unknown, or a number outside 1-13).
static func bid_from_dict(d: Dictionary) -> Bid:
	if not (_is_number(d.get("k")) and _is_number(d.get("n"))):
		return null
	match int(d["k"]):
		Bid.Kind.NUMBER:
			var n: int = int(d["n"])
			if n < 1 or n > 13:
				return null
			return Bid.number(n)
		Bid.Kind.NIL:
			return Bid.nil()
		Bid.Kind.BLIND_NIL:
			return Bid.blind_nil()
	return null


static func settings_to_dict(s: SpadesSettings) -> Dictionary:
	return {
		"blind_nil": s.blind_nil_enabled,
		"nil": s.nil_enabled,
		"redeal": s.redeal_enabled,
		"bags": s.bags_penalty_enabled,
		"play_higher": s.play_higher_enabled,
		"win": s.win_score,
		"lose": s.lose_score,
		"exact": int(s.exact_mode),
	}


## Missing or odd fields keep their defaults.
static func settings_from_dict(d: Dictionary) -> SpadesSettings:
	var s: SpadesSettings = SpadesSettings.new()
	if d.get("blind_nil") is bool:
		s.blind_nil_enabled = d["blind_nil"]
	if d.get("nil") is bool:
		s.nil_enabled = d["nil"]
	if d.get("redeal") is bool:
		s.redeal_enabled = d["redeal"]
	if d.get("bags") is bool:
		s.bags_penalty_enabled = d["bags"]
	if d.get("play_higher") is bool:
		s.play_higher_enabled = d["play_higher"]
	if _is_number(d.get("win")):
		s.win_score = int(d["win"])
	if _is_number(d.get("lose")):
		s.lose_score = int(d["lose"])
	if _is_number(d.get("exact")):
		var m: int = int(d["exact"])
		if m >= 0 and m <= 3:
			s.exact_mode = m as SpadesSettings.ExactMode  # also switches the bags penalty off
	return s
