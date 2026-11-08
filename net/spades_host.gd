class_name SpadesHost
extends RefCounted
## The host side of a network game: a lobby (join, pick seats, add bots, start) and then
## the game itself. The host is the only place the real game exists: players send
## requests, the host checks them with the normal rules and sends each player a snapshot
## of what that player may know. A player's seat always comes from their connection,
## never from a field in their message.

const BOT_NAMES: Dictionary = {0: "Robin", 1: "Tin", 2: "Pip", 3: "Cherry"}

var transport: Transport
var settings: SpadesSettings
var game_seed: int
## 4 entries: {"kind": "empty"|"human"|"bot", "name": String, "peer": int, "token": String}.
## peer is -1 for a human whose phone has dropped.
var seats: Array[Dictionary] = []
var host_peer: int = -1
var session: SpadesSession
var paused: bool = false

var _phase: String = "lobby"
var _joined: Dictionary = {}  # peer id -> {"name": String, "token": String}
var _seq: int = 0
var _last_trick_winner: int = -1


func _init(t: Transport, game_settings: SpadesSettings, seed_value: int) -> void:
	transport = t
	settings = game_settings
	game_seed = seed_value
	for i in range(4):
		seats.append(_empty_seat())
	transport.message_received.connect(_on_message)
	transport.peer_disconnected.connect(_on_peer_disconnected)


static func _empty_seat() -> Dictionary:
	return {"kind": "empty", "name": "", "peer": -1, "token": ""}


## "lobby", "playing" or "closed".
func phase_name() -> String:
	return _phase


## Ends the game for everyone (the host left).
func close(reason: String = "host_left") -> void:
	if _phase == "closed":
		return
	_phase = "closed"
	_broadcast("game_closed", {"reason": reason})


# ---------- receiving ----------

func _on_message(peer: int, text: String) -> void:
	var m: Dictionary = Protocol.decode(text)
	if m.is_empty() or _phase == "closed":
		return
	match m["type"]:
		"join_request":
			_on_join(peer, m)
		"rejoin_request":
			_on_rejoin(peer, m)
		"seat_request":
			_on_seat_request(peer, m)
		"leave":
			_on_leave(peer)
		"add_bots":
			if peer == host_peer and _phase == "lobby":
				for i in range(4):
					if seats[i]["kind"] == "empty":
						seats[i] = {"kind": "bot", "name": BOT_NAMES[i], "peer": -1, "token": ""}
				_send_lobby()
		"start_game":
			_on_start(peer)
		"bid", "swap", "play_card", "next_round":
			_on_game_action(peer, m)
		"replace_with_bot":
			_on_replace(peer, m)


func _on_join(peer: int, m: Dictionary) -> void:
	if _phase != "lobby":
		_send(peer, "join_refused", {"reason": "game_started"})
		return
	if _joined.has(peer):
		return
	var bots: int = 0
	for s in seats:
		if s["kind"] == "bot":
			bots += 1
	if _joined.size() + bots >= 4:
		_send(peer, "join_refused", {"reason": "full"})
		return
	var taken: Array[String] = []
	for j in _joined.values():
		taken.append(j["name"])
	var raw: String = m["name"] if m.get("name") is String else ""  # only text counts as a name
	var player_name: String = PlayerProfile.unique(PlayerProfile.clean(raw), taken)
	var token: String = Crypto.new().generate_random_bytes(8).hex_encode()
	_joined[peer] = {"name": player_name, "token": token}
	var as_host: bool = m.get("as_host", false) == true and transport.is_local_peer(peer)
	if as_host:
		host_peer = peer
	_send(peer, "join_accepted", {"token": token, "name": player_name, "is_host": as_host})
	_send_lobby()


func _on_seat_request(peer: int, m: Dictionary) -> void:
	if _phase != "lobby" or not _joined.has(peer):
		return
	if not (m.get("seat") is float or m.get("seat") is int):
		_reject(peer, "bad_seat")
		return
	var seat: int = int(m["seat"])
	if seat < 0 or seat > 3:
		_reject(peer, "bad_seat")
		return
	if seats[seat]["kind"] != "empty":
		_reject(peer, "seat_taken")
		return
	var old: int = _seat_of(peer)
	if old >= 0:
		seats[old] = _empty_seat()
	var j: Dictionary = _joined[peer]
	seats[seat] = {"kind": "human", "name": j["name"], "peer": peer, "token": j["token"]}
	_send_lobby()


func _on_leave(peer: int) -> void:
	if not _joined.has(peer):
		return
	var seat: int = _seat_of(peer)
	if _phase == "lobby":
		if seat >= 0:
			seats[seat] = _empty_seat()
		_joined.erase(peer)
		if peer == host_peer:
			close("host_left")
			return
		_send_lobby()
	elif _phase == "playing":
		if peer == host_peer:
			close("host_left")
			return
		_joined.erase(peer)
		if seat >= 0:
			_turn_into_bot(seat)
		_after_seat_change()


func _on_start(peer: int) -> void:
	if peer != host_peer or _phase != "lobby":
		return
	var humans: Array[int] = []
	var names: Dictionary = {}
	for i in range(4):
		if seats[i]["kind"] == "empty":
			_reject(peer, "seats_not_full")
			return
		if seats[i]["kind"] == "human":
			humans.append(i)
		names[i] = seats[i]["name"]
	if humans.is_empty():
		_reject(peer, "no_humans")
		return
	session = SpadesSession.new(settings, game_seed)
	session.set_human_seats(humans)
	session.set_names(names)
	session.start()
	_phase = "playing"
	_send_views({"kind": "deal", "seat": -1})


func _on_game_action(peer: int, m: Dictionary) -> void:
	if _phase != "playing" or session == null:
		return
	var seat: int = _seat_of(peer)
	if seat < 0:
		_reject(peer, "not_seated")
		return
	if paused:
		_reject(peer, "paused")
		return
	match m["type"]:
		"bid":
			var b: Bid = Wire.bid_from_dict(m["bid"]) if m.get("bid") is Dictionary else null
			if b == null or not session.bid_for(seat, b):
				_reject(peer, "bid_refused")
				return
			_send_views({"kind": "bid", "seat": seat})
		"swap":
			var give: Array[Card] = Wire.cards_from_array(m["give"]) if m.get("give") is Array else ([] as Array[Card])
			var positions: Array[int] = []
			if m.get("positions") is Array:
				for p in m["positions"]:
					if p is float or p is int:
						positions.append(int(p))
			if not session.swap_for(seat, give, positions):
				_reject(peer, "swap_refused")
				return
			_send_views({"kind": "swap", "seat": seat})
		"play_card":
			var c: Card = Wire.card_from_dict(m["card"]) if m.get("card") is Dictionary else null
			if c == null:
				_reject(peer, "bad_card")
				return
			if not session.must_play(seat):
				_reject(peer, "not_your_turn")
				return
			if not _in_list(c, session.view_for_seat(seat)["hand"]):
				_reject(peer, "not_in_hand")
				return
			if not session.play_for(seat, c):
				_reject(peer, "illegal_card")
				return
			_send_views({"kind": "play", "seat": seat})
		"next_round":
			if session.round_over() and not session.game_over() and session.next_round():
				_send_views({"kind": "deal", "seat": -1})


static func _in_list(card: Card, cards: Array) -> bool:
	for x in cards:
		if (x as Card).suit == card.suit and (x as Card).rank == card.rank:
			return true
	return false


## Host only: a dropped player's seat goes to a bot.
func _on_replace(peer: int, m: Dictionary) -> void:
	if peer != host_peer or _phase != "playing":
		return
	if not (m.get("seat") is float or m.get("seat") is int):
		return
	var seat: int = int(m["seat"])
	if seat < 0 or seat > 3 or seats[seat]["kind"] != "human" or seats[seat]["peer"] != -1:
		_reject(peer, "seat_not_dropped")
		return
	_turn_into_bot(seat)
	_after_seat_change()


func _turn_into_bot(seat: int) -> void:
	seats[seat] = {"kind": "bot", "name": BOT_NAMES[seat], "peer": -1, "token": ""}
	session.make_bot(seat)
	var names: Dictionary = {}
	for i in range(4):
		names[i] = seats[i]["name"]
	session.set_names(names)


## After a seat changed hands: work out whether the game is still waiting for someone.
func _after_seat_change() -> void:
	var was_paused: bool = paused
	paused = _someone_missing()
	if paused and not was_paused:
		_broadcast("game_paused", {"seat": _missing_seat(), "name": seats[_missing_seat()]["name"]})
	elif was_paused and not paused:
		_broadcast("game_resumed", {})
	_send_views({"kind": "seat", "seat": -1})


func _someone_missing() -> bool:
	return _missing_seat() >= 0


func _missing_seat() -> int:
	for i in range(4):
		if seats[i]["kind"] == "human" and seats[i]["peer"] == -1:
			return i
	return -1


func _on_peer_disconnected(peer: int) -> void:
	if not _joined.has(peer):
		return
	if peer == host_peer:
		close("host_left")
		return
	if _phase == "lobby":
		var seat: int = _seat_of(peer)
		if seat >= 0:
			seats[seat] = _empty_seat()
		_joined.erase(peer)
		_send_lobby()
	elif _phase == "playing":
		var s: int = _seat_of(peer)
		_joined.erase(peer)
		if s >= 0:
			seats[s]["peer"] = -1  # the seat is kept for them; the game waits
			_after_seat_change()


func _on_rejoin(peer: int, m: Dictionary) -> void:
	if _phase != "playing":
		_send(peer, "join_refused", {"reason": "no_game"})
		return
	var token: String = str(m.get("token", ""))
	for i in range(4):
		var s: Dictionary = seats[i]
		if token != "" and s["kind"] == "human" and s["peer"] == -1 and s["token"] == token:
			s["peer"] = peer
			_joined[peer] = {"name": s["name"], "token": token}
			_send(peer, "join_accepted", {"token": token, "name": s["name"], "is_host": false, "seat": i})
			_after_seat_change()
			return
	_send(peer, "join_refused", {"reason": "bad_token"})


# ---------- the game loop (the app supplies the pauses) ----------

## Does exactly one automatic thing: clear a finished trick, or let one bot act.
## Returns false when the game is waiting for a person (or paused, or over).
func step() -> bool:
	if _phase != "playing" or session == null or paused:
		return false
	if session.trick_pending():
		_last_trick_winner = int(session.last_trick()["winner"])
		session.clear_trick()
		_send_views({"kind": "trick", "seat": _last_trick_winner})
		return true
	if session.round_over():
		return false
	var r: Dictionary = session.advance_bots()
	if r.is_empty():
		return false
	_send_views({"kind": str(r["kind"]), "seat": int(r["seat"])})
	return true


# ---------- sending ----------

func _send(peer: int, type: String, fields: Dictionary = {}) -> void:
	_seq += 1
	transport.send_to(peer, Protocol.encode(Protocol.make(type, fields, _seq)))


func _broadcast(type: String, fields: Dictionary = {}) -> void:
	for p in _joined.keys():
		_send(p, type, fields)


func _reject(peer: int, reason: String) -> void:
	_send(peer, "action_rejected", {"reason": reason})


func _seat_of(peer: int) -> int:
	for i in range(4):
		if seats[i]["kind"] == "human" and seats[i]["peer"] == peer:
			return i
	return -1


func _send_lobby() -> void:
	var list: Array = []
	for s in seats:
		list.append({"kind": s["kind"], "name": s["name"]})
	for p in _joined.keys():
		_send(p, "lobby_state", {
			"seats": list,
			"settings": Wire.settings_to_dict(settings),
			"you": _seat_of(p),
			"is_host": p == host_peer,
		})


func _send_views(event: Dictionary) -> void:
	for i in range(4):
		if seats[i]["kind"] == "human" and seats[i]["peer"] != -1:
			_send(seats[i]["peer"], "game_view", _snapshot(i, event))


static func _skeys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[str(k)] = d[k]
	return out


static func _trick_list(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		out.append({"seat": int(e["seat"]), "card": Wire.card_to_dict(e["card"])})
	return out


## Everything one seat may know: its own hand, the others' card counts, public facts.
func _snapshot(seat: int, event: Dictionary) -> Dictionary:
	var v: Dictionary = session.view_for_seat(seat)
	var bids: Dictionary = {}
	for s in v["bids"].keys():
		bids[str(s)] = Wire.bid_to_dict(v["bids"][s])
	var last: Dictionary = v["last_trick"]
	var last_out: Dictionary = {}
	if not last.is_empty():
		last_out = {"cards": _trick_list(last["cards"]), "winner": int(last["winner"])}
	var swap: Dictionary = {}
	for k in (v["swap"] as Dictionary).keys():
		var val: Variant = v["swap"][k]
		swap[str(k)] = Wire.cards_to_array(val) if val is Array else val
	var round_over: bool = session.round_over()
	var snap: Dictionary = {
		"seat": seat,
		"phase": int(v["phase"]),
		"turn_seat": int(v["turn_seat"]),
		"dealer_seat": int(v["dealer_seat"]),
		"hand": Wire.cards_to_array(v["hand"]),
		"hand_counts": _skeys(v["hand_counts"]),
		"trick": _trick_list(v["trick"]),
		"last_trick": last_out,
		"bids": bids,
		"tricks_won": _skeys(v["tricks_won"]),
		"team_scores": v["team_scores"],
		"team_bags": v["team_bags"],
		"spades_broken": v["spades_broken"],
		"legal": Wire.cards_to_array(v["legal"]),
		"must_bid": session.must_bid(seat),
		"must_play": session.must_play(seat),
		"must_swap": session.must_swap(seat),
		"names": _skeys(v["names"]),
		"swap": swap,
		"round_over": round_over,
		"game_over": session.game_over(),
		"winner_team": session.winner_team(),
		"round_number": session.round_number(),
		"redeal": session.redeal_messages(),
		"event": event,
		"paused": paused,
		"settings": Wire.settings_to_dict(settings),
	}
	if round_over:
		var r: Dictionary = session.round_result()
		var out: Dictionary = {"points": r["points"], "bags": r["bags"], "nil_results": _skeys(r["nil_results"])}
		if r.has("player_points"):
			out["player_points"] = _skeys(r["player_points"])
			out["player_results"] = _skeys(r["player_results"])
		snap["round_result"] = out
	return snap
