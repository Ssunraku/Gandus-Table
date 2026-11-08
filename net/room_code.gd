class_name RoomCode
extends RefCounted
## The 4-letter code a host shows so friends can find the game. No I and no O, so it can
## be read out loud without mixing them up with 1 and 0.

const LETTERS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
const LENGTH: int = 4


static func generate(rng: RandomNumberGenerator) -> String:
	var out: String = ""
	for i in range(LENGTH):
		out += LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
	return out


## Trimmed and upper-case, or "" if it is not exactly 4 allowed letters.
static func normalize(text: String) -> String:
	var t: String = text.strip_edges().to_upper()
	return t if is_valid(t) else ""


static func is_valid(text: String) -> bool:
	if text.length() != LENGTH:
		return false
	for i in range(LENGTH):
		if not LETTERS.contains(text[i]):
			return false
	return true
