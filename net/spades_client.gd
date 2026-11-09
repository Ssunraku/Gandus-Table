class_name SpadesClient
extends RefCounted
## One player's side of a network game. It sends requests to the host and keeps the
## latest lobby and game snapshot the host sent. `to_table_state()` turns that snapshot
## into what the table screen draws, with this player's own seat at the bottom (South).

signal lobby_changed
signal view_changed
signal rejected(reason: String)
signal refused(reason: String)
signal paused_changed(is_paused: bool, who: String)
signal closed(reason: String)
## The connection to the host dropped (not the host ending the game on purpose).
signal connection_lost

var transport: Transport
var token: String = ""
var player_name: String = ""
var my_seat: int = -1
var is_host: bool = false
var connected: bool = false
var paused: bool = false
var paused_seat: int = -1  # the seat the game is waiting for (while paused)
var lobby: Dictionary = {}
var view: Dictionary = {}
var last_rejection: String = ""

var _seq: int = 0


func _init(t: Transport) -> void:
	_attach(t)


func _attach(t: Transport) -> void:
	transport = t
	transport.message_received.connect(_on_message)
	transport.peer_connected.connect(_on_peer_connected)
	transport.peer_disconnected.connect(_on_peer_disconnected)


## Moves this client (its token, its last snapshot, everything) onto a new connection,
## for example after Wi-Fi dropped. The old connection is no longer listened to.
func replace_transport(t: Transport) -> void:
	if transport != null:
		transport.message_received.disconnect(_on_message)
		transport.peer_connected.disconnect(_on_peer_connected)
		transport.peer_disconnected.disconnect(_on_peer_disconnected)
	connected = false
	_attach(t)


func _on_peer_connected(_p: int) -> void:
	connected = true


func _on_peer_disconnected(_p: int) -> void:
	var was: bool = connected
	connected = false
	if was:
		connection_lost.emit()


# ---------- requests ----------

func join(wanted_name: String, as_host: bool = false) -> void:
	_send("join_request", {"name": wanted_name, "as_host": as_host})


func rejoin(old_token: String) -> void:
	_send("rejoin_request", {"token": old_token})


func request_seat(seat: int) -> void:
	_send("seat_request", {"seat": seat})


func leave() -> void:
	_send("leave")


func add_bot(seat: int) -> void:
	_send("add_bot", {"seat": seat})


func remove_bot(seat: int) -> void:
	_send("remove_bot", {"seat": seat})


func send_bid(b: Bid) -> void:
	_send("bid", {"bid": Wire.bid_to_dict(b)})


func send_swap(give: Array[Card], positions: Array[int]) -> void:
	_send("swap", {"give": Wire.cards_to_array(give), "positions": positions})


func send_play(card: Card) -> void:
	_send("play_card", {"card": Wire.card_to_dict(card)})


func next_round() -> void:
	_send("next_round")


func replace_with_bot(seat: int) -> void:
	_send("replace_with_bot", {"seat": seat})


func _send(type: String, fields: Dictionary = {}) -> void:
	_seq += 1
	transport.send_to(Transport.HOST_ID,Protocol.encode(Protocol.make(type, fields, _seq)))


# ---------- receiving ----------

func _on_message(_peer: int, text: String) -> void:
	var m: Dictionary = Protocol.decode(text)
	if m.is_empty():
		return
	match m["type"]:
		"join_accepted":
			token = str(m.get("token", ""))
			player_name = str(m.get("name", ""))
			is_host = m.get("is_host", false) == true
			if m.get("seat") is float or m.get("seat") is int:
				my_seat = int(m["seat"])
		"join_refused":
			refused.emit(str(m.get("reason", "")))
		"lobby_state":
			lobby = m
			if m.get("you") is float or m.get("you") is int:
				my_seat = int(m["you"])
			lobby_changed.emit()
		"game_view":
			var v: Dictionary = _decode_view(m)
			if v.is_empty():
				return
			view = v
			my_seat = int(v["seat"])
			paused = v["paused"]
			view_changed.emit()
		"game_paused":
			paused = true
			paused_seat = _num(m.get("seat"), -1)
			paused_changed.emit(true, str(m.get("name", "")))
		"game_resumed":
			paused = false
			paused_changed.emit(false, "")
		"action_rejected":
			last_rejection = str(m.get("reason", ""))
			rejected.emit(last_rejection)
		"game_closed":
			connected = false  # (set first so the disconnect that follows is not "lost")
			closed.emit(str(m.get("reason", "")))


static func _int_keys(d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k in (d as Dictionary).keys():
			out[int(str(k))] = d[k]
	return out


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if (v is float or v is int) else fallback


static func _trick(entries: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entries is Array:
		for e in entries:
			if e is Dictionary and e.get("card") is Dictionary:
				var c: Card = Wire.card_from_dict(e["card"])
				if c != null:
					out.append({"seat": _num(e.get("seat")), "card": c})
	return out


static func _ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for x in a:
			out.append(_num(x))
	return out


## Turns the host's text snapshot into real objects (Card, Bid, int keys). {} if it is
## not a snapshot we can use.
static func _decode_view(m: Dictionary) -> Dictionary:
	for key in ["seat", "phase", "turn_seat", "hand", "team_scores"]:
		if not m.has(key):
			return {}
	var v: Dictionary = {}
	v["seat"] = _num(m["seat"])
	v["phase"] = _num(m["phase"])
	v["turn_seat"] = _num(m["turn_seat"])
	v["dealer_seat"] = _num(m.get("dealer_seat"))
	v["hand"] = Wire.cards_from_array(m["hand"]) if m["hand"] is Array else ([] as Array[Card])
	var counts: Dictionary = {}
	for k in _int_keys(m.get("hand_counts")).keys():
		counts[k] = _num(m["hand_counts"][str(k)])
	v["hand_counts"] = counts
	v["trick"] = _trick(m.get("trick"))
	var last: Dictionary = {}
	if m.get("last_trick") is Dictionary and not (m["last_trick"] as Dictionary).is_empty():
		last = {"cards": _trick(m["last_trick"].get("cards")), "winner": _num(m["last_trick"].get("winner"))}
	v["last_trick"] = last
	var bids: Dictionary = {}
	var raw_bids: Dictionary = _int_keys(m.get("bids"))
	for k in raw_bids.keys():
		if raw_bids[k] is Dictionary:
			var b: Bid = Wire.bid_from_dict(raw_bids[k])
			if b != null:
				bids[k] = b
	v["bids"] = bids
	var won: Dictionary = {}
	var raw_won: Dictionary = _int_keys(m.get("tricks_won"))
	for k in raw_won.keys():
		won[k] = _num(raw_won[k])
	v["tricks_won"] = won
	v["team_scores"] = _ints(m["team_scores"])
	v["team_bags"] = _ints(m.get("team_bags"))
	v["spades_broken"] = m.get("spades_broken", false) == true
	v["legal"] = Wire.cards_from_array(m["legal"]) if m.get("legal") is Array else ([] as Array[Card])
	v["must_bid"] = m.get("must_bid", false) == true
	v["must_play"] = m.get("must_play", false) == true
	v["must_swap"] = m.get("must_swap", false) == true
	var names: Dictionary = {}
	var raw_names: Dictionary = _int_keys(m.get("names"))
	for k in raw_names.keys():
		names[k] = str(raw_names[k])
	v["names"] = names
	var swap: Dictionary = {}
	if m.get("swap") is Dictionary:
		for k in (m["swap"] as Dictionary).keys():
			if m["swap"][k] is Array:
				swap[str(k)] = Wire.cards_from_array(m["swap"][k])
	v["swap"] = swap
	v["round_over"] = m.get("round_over", false) == true
	v["game_over"] = m.get("game_over", false) == true
	v["winner_team"] = _num(m.get("winner_team"), -1)
	v["round_number"] = _num(m.get("round_number"), 1)
	var redeal: Array[String] = []
	if m.get("redeal") is Array:
		for x in m["redeal"]:
			redeal.append(str(x))
	v["redeal"] = redeal
	v["event"] = m["event"] if m.get("event") is Dictionary else {}
	v["paused"] = m.get("paused", false) == true
	v["room_code"] = str(m["room_code"]) if m.get("room_code") is String else ""
	var addresses: Array[String] = []
	if m.get("addresses") is Array:
		for a in m["addresses"]:
			if a is String:
				addresses.append(a)
	v["addresses"] = addresses
	v["settings"] = Wire.settings_from_dict(m["settings"] if m.get("settings") is Dictionary else {})
	var rr: Dictionary = {}
	if m.get("round_result") is Dictionary:
		var src: Dictionary = m["round_result"]
		rr["points"] = _ints(src.get("points"))
		rr["bags"] = _ints(src.get("bags"))
		var nils: Dictionary = {}
		var raw_nils: Dictionary = _int_keys(src.get("nil_results"))
		for k in raw_nils.keys():
			nils[k] = raw_nils[k] == true
		rr["nil_results"] = nils
		if src.has("player_points"):
			var pp: Dictionary = {}
			var raw_pp: Dictionary = _int_keys(src["player_points"])
			for k in raw_pp.keys():
				pp[k] = _num(raw_pp[k])
			rr["player_points"] = pp
			var pr: Dictionary = {}
			var raw_pr: Dictionary = _int_keys(src.get("player_results"))
			for k in raw_pr.keys():
				pr[k] = str(raw_pr[k])
			rr["player_results"] = pr
	v["round_result"] = rr
	return v


# ---------- what the table draws ----------

## Seat as seen from this player: own seat = SOUTH, then clockwise.
func relative(seat: int) -> int:
	return posmod(seat - my_seat, 4)


## The TableState for the table screen. Empty (default) before the first snapshot.
func to_table_state() -> TableState:
	var st: TableState = TableState.new()
	if view.is_empty():
		return st
	st.own_hand = Deck.sort_hand(view["hand"])
	for seat in range(4):
		var rel: int = relative(seat)
		if rel != TableState.Seat.SOUTH:
			st.set_card_count(rel as TableState.Seat, int(view["hand_counts"].get(seat, 0)))
		st.seat_names[rel] = str(view["names"].get(seat, ""))
	for entry in view["trick"]:
		st.set_played(relative(entry["seat"]) as TableState.Seat, entry["card"])
	st.dealer_seat = relative(int(view["dealer_seat"])) as TableState.Seat
	st.turn_seat = relative(int(view["turn_seat"])) as TableState.Seat
	var mine: int = my_seat % 2
	var scores: Array[int] = view["team_scores"]
	var bags: Array[int] = view["team_bags"]
	var own_first_scores: Array[int] = [scores[mine], scores[1 - mine]]
	st.team_scores = own_first_scores
	var own_first_bags: Array[int] = [0, 0]
	if bags.size() == 2:
		own_first_bags = [bags[mine], bags[1 - mine]]
	st.team_bags = own_first_bags
	var won: Dictionary = {}
	for seat in view["tricks_won"].keys():
		won[relative(seat)] = view["tricks_won"][seat]
	st.tricks_won = won
	var bids: Dictionary = {}
	for seat in view["bids"].keys():
		bids[relative(seat)] = view["bids"][seat]
	st.bids = bids
	st.spades_broken = view["spades_broken"]
	st.phase = view["phase"]
	st.can_play = view["must_play"]
	st.legal_cards = view["legal"]
	var last: Dictionary = view["last_trick"]
	if not last.is_empty():
		var cards: Array[Dictionary] = []
		for e in last["cards"]:
			cards.append({"seat": relative(e["seat"]), "card": e["card"]})
		st.last_trick = {"cards": cards, "winner": relative(int(last["winner"]))}
	return st
