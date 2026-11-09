class_name RemoteSource
extends GameSource
## The game as seen over the network. It reads the latest snapshot the host sent to a
## SpadesClient and presents it exactly like a local game would: the same view() shape,
## with every seat turned so the viewer is seat 0 (South). Actions are sent to the host;
## the host answers with a new snapshot.

## A new snapshot has been applied.
signal changed
## What just happened (emitted before `changed`): kind is "play", "trick", "deal", "bid",
## "swap" or "seat"; seat is relative to the viewer (-1 if none); card is set for "play".
signal event(kind: String, seat: int, card: Card)
signal paused_changed(is_paused: bool, who: String)
signal closed(reason: String)

var client: SpadesClient
var _view: Dictionary = {}


func _init(c: SpadesClient) -> void:
	client = c
	client.view_changed.connect(_on_view)
	client.paused_changed.connect(func(p: bool, who: String) -> void: paused_changed.emit(p, who))
	client.closed.connect(func(reason: String) -> void: closed.emit(reason))
	if not client.view.is_empty():
		_view = _convert()


func is_online() -> bool:
	return true


func is_paused() -> bool:
	return client.paused


func settings() -> SpadesSettings:
	if client.view.is_empty():
		return SpadesSettings.new()
	return client.view["settings"]


func _on_view() -> void:
	_view = _convert()
	var ev: Dictionary = client.view["event"]
	var kind: String = str(ev.get("kind", ""))
	var abs_seat: int = int(ev.get("seat", -1)) if (ev.get("seat") is float or ev.get("seat") is int) else -1
	var rel: int = client.relative(abs_seat) if abs_seat >= 0 else -1
	var card: Card = null
	if kind == "play":
		for e in client.view["trick"]:
			if e["seat"] == abs_seat:
				card = e["card"]
	event.emit(kind, rel, card)
	changed.emit()


func _rel(seat: int) -> int:
	return client.relative(seat)


func _own_first(pair: Array[int]) -> Array[int]:
	var mine: int = client.my_seat % 2
	if pair.size() != 2:
		return [0, 0]
	return [pair[mine], pair[1 - mine]]


func _rel_trick(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		out.append({"seat": _rel(e["seat"]), "card": e["card"]})
	return out


## The host's snapshot in the shape SpadesSession.view() has, seats turned to the viewer.
func _convert() -> Dictionary:
	var v: Dictionary = client.view
	var counts: Dictionary = {}
	for seat in v["hand_counts"].keys():
		counts[_rel(seat)] = v["hand_counts"][seat]
	var bids: Dictionary = {}
	for seat in v["bids"].keys():
		bids[_rel(seat)] = v["bids"][seat]
	var won: Dictionary = {}
	for seat in v["tricks_won"].keys():
		won[_rel(seat)] = v["tricks_won"][seat]
	var names: Dictionary = {}
	for seat in range(4):
		names[_rel(seat)] = str(v["names"].get(seat, ""))  # (your own seat shows your own name, not "You")
	var last: Dictionary = {}
	if not (v["last_trick"] as Dictionary).is_empty():
		last = {"cards": _rel_trick(v["last_trick"]["cards"]), "winner": _rel(int(v["last_trick"]["winner"]))}
	return {
		"phase": v["phase"],
		"turn_seat": _rel(int(v["turn_seat"])),
		"dealer_seat": _rel(int(v["dealer_seat"])),
		"hand": v["hand"],
		"hand_counts": counts,
		"bids": bids,
		"trick": _rel_trick(v["trick"]),
		"spades_broken": v["spades_broken"],
		"tricks_won": won,
		"team_scores": _own_first(v["team_scores"]),
		"team_bags": _own_first(v["team_bags"]),
		"swap": v["swap"],
		"legal": v["legal"],
		"last_trick": last,
		"names": names,
		"room_code": v["room_code"],
		"addresses": v["addresses"],
	}


# ---------- GameSource ----------

func phase() -> int:
	return int(_view.get("phase", 0))


func turn_seat() -> int:
	return int(_view.get("turn_seat", 0))


func human_must_bid() -> bool:
	return client.view.get("must_bid", false) == true


func human_must_play() -> bool:
	return client.view.get("must_play", false) == true


func human_must_swap() -> bool:
	return client.view.get("must_swap", false) == true


func submit_bid(b: Bid) -> bool:
	if not human_must_bid():
		return false
	client.send_bid(b)
	return true


func submit_swap(give: Array[Card], positions: Array[int]) -> bool:
	if not human_must_swap():
		return false
	client.send_swap(give, positions)
	return true


func submit_play(card: Card) -> bool:
	if not human_must_play():
		return false
	client.send_play(card)
	return true


func trick_pending() -> bool:
	return (_view.get("trick", []) as Array).size() >= 4


func shown_trick() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _view.get("trick", []):
		out.append(e)
	return out


func last_trick() -> Dictionary:
	return _view.get("last_trick", {})


func round_over() -> bool:
	return client.view.get("round_over", false) == true


func game_over() -> bool:
	return client.view.get("game_over", false) == true


## 0 = your team won, 1 = the other team, -1 = not decided.
func winner_team() -> int:
	var w: int = int(client.view.get("winner_team", -1))
	if w < 0 or client.my_seat < 0:
		return -1
	return 0 if w == client.my_seat % 2 else 1


## The finished round's result with everything turned to the viewer (your team first).
func round_result() -> Dictionary:
	var src: Dictionary = client.view.get("round_result", {})
	if src.is_empty():
		return {}
	var out: Dictionary = {
		"points": _own_first(src["points"]),
		"bags": _own_first(src["bags"]),
	}
	var nils: Dictionary = {}
	for seat in src["nil_results"].keys():
		nils[_rel(seat)] = src["nil_results"][seat]
	out["nil_results"] = nils
	if src.has("player_points"):
		var pp: Dictionary = {}
		var pr: Dictionary = {}
		for seat in src["player_points"].keys():
			pp[_rel(seat)] = src["player_points"][seat]
		for seat in src["player_results"].keys():
			pr[_rel(seat)] = src["player_results"][seat]
		out["player_points"] = pp
		out["player_results"] = pr
	return out


func round_number() -> int:
	return int(client.view.get("round_number", 1))


func next_round() -> bool:
	if not round_over() or game_over():
		return false
	client.next_round()
	return true


func view() -> Dictionary:
	return _view


func redeal_messages() -> Array[String]:
	var out: Array[String] = []
	for m in client.view.get("redeal", []):
		out.append(str(m))
	return out
