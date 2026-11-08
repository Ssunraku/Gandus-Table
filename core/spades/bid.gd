class_name Bid
extends RefCounted
## One player's bid: a number of tricks (1-13), Nil, or Blind Nil.

enum Kind { NUMBER, NIL, BLIND_NIL }

var kind: Kind = Kind.NUMBER
var tricks: int = 0  # only meaningful for NUMBER bids


static func number(n: int) -> Bid:
	var b: Bid = Bid.new()
	b.kind = Kind.NUMBER
	b.tricks = n
	return b


static func nil() -> Bid:
	var b: Bid = Bid.new()
	b.kind = Kind.NIL
	return b


static func blind_nil() -> Bid:
	var b: Bid = Bid.new()
	b.kind = Kind.BLIND_NIL
	return b


func is_nil_kind() -> bool:
	return kind == Kind.NIL or kind == Kind.BLIND_NIL
