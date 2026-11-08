class_name AutoPlayer
extends RefCounted
## Test helper: plays one client's seat by itself (bids 3, plays the first legal card).

var client: SpadesClient
## The host's player starts the next round by itself unless a test wants to press the button.
var auto_next_round: bool = true


func _init(c: SpadesClient) -> void:
	client = c


## Sends one request if the client has something to do. Returns true if it did.
func act() -> bool:
	var v: Dictionary = client.view
	if v.is_empty() or client.paused:
		return false
	if v["must_bid"]:
		client.send_bid(Bid.number(3))
		return true
	if v["must_swap"]:
		client.send_swap([] as Array[Card], [] as Array[int])
		return true
	if v["must_play"] and not (v["legal"] as Array).is_empty():
		client.send_play((v["legal"] as Array)[0])
		return true
	if auto_next_round and v["round_over"] and not v["game_over"] and client.is_host:
		client.next_round()
		return true
	return false
