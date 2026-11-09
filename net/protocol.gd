class_name Protocol
extends RefCounted
## The messages phones send each other: one small JSON object each, with a version,
## a type and a counter. Anything that does not look right is ignored (decode gives {}).

const VERSION: int = 1
const MAX_BYTES: int = 16384
const TYPES: Array[String] = [
	"join_request", "join_accepted", "join_refused", "seat_request", "lobby_state",
	"add_bot", "remove_bot", "leave", "rejoin_request", "game_view", "game_paused",
	"game_resumed", "bid", "swap", "play_card", "next_round", "replace_with_bot",
	"action_rejected", "game_closed",
]


static func make(type: String, fields: Dictionary = {}, seq: int = 0) -> Dictionary:
	var m: Dictionary = fields.duplicate()
	m["v"] = VERSION
	m["type"] = type
	m["seq"] = seq
	return m


static func encode(msg: Dictionary) -> String:
	return JSON.stringify(msg)


## {} unless the text is a valid, current-version message of a known type and not too big.
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:  # (unlike parse_string, this stays quiet on bad text)
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {}
	var m: Dictionary = parsed
	if not ((m.get("v") is float or m.get("v") is int) and int(m["v"]) == VERSION):
		return {}
	if not (m.get("type") is String and TYPES.has(m["type"])):
		return {}
	m["v"] = int(m["v"])
	m["seq"] = int(m["seq"]) if (m.get("seq") is float or m.get("seq") is int) else 0
	return m
